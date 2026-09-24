defmodule SovereignSoulEngine.Memories do
  @moduledoc """
  Context for managing Memories — episodic, core, wound, belief, relationship, and working memories.
  """

  alias SovereignSoulEngine.Memories.Memory
  alias SovereignSoulEngine.Memories.MemoryOperation
  alias SovereignSoulEngine.Memories.MemoryRetrieval
  alias SovereignSoulEngine.Ledger
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  def list_memories do
    Repo.all(Memory)
  end

  def get_memory!(id), do: Repo.get!(Memory, id)

  def get_memory_for_character!(character_id, memory_id) do
    Repo.one!(
      from m in Memory,
        where: m.id == ^memory_id and m.owner_character_id == ^character_id
    )
  end

  def list_memories_for_character(character_id) do
    Repo.all(
      from m in Memory,
        where: m.owner_character_id == ^character_id and m.status == "active",
        order_by: [desc: m.importance]
    )
  end

  @doc """
  Returns up to `limit` active memories ranked by contextual relevance.

  Uses `MemoryRetrieval` + `MemoryScoring` for full scoring (recency, decay, recall
  reinforcement, category weights). Context tags bias results toward matching memories.
  Core/wound/relationship memories always anchor in the top results.
  """
  def list_relevant_memories_for_character(character_id, context_tags, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    all_memories =
      Repo.all(
        from m in Memory,
          where: m.owner_character_id == ^character_id and m.status == "active"
      )

    tagged_memories =
      if context_tags == [] do
        all_memories
      else
        MemoryRetrieval.retrieve(all_memories, tags: context_tags)
      end

    anchor_categories = ["core", "wound", "relationship"]

    anchors =
      all_memories
      |> Enum.filter(&(&1.category in anchor_categories))
      |> MemoryRetrieval.retrieve([])

    (tagged_memories ++ anchors)
    |> Enum.uniq_by(& &1.id)
    |> Enum.take(limit)
  end

  @doc """
  Increments recall_count and updates last_recalled_at for the given memory IDs.
  Called after memories are surfaced in a prompt.
  """
  def record_recalls(memory_ids) when is_list(memory_ids) do
    MemoryOperation.with_global(fn ->
      now = DateTime.utc_now()

      Repo.update_all(
        from(m in Memory, where: m.id in ^memory_ids),
        set: [last_recalled_at: now],
        inc: [recall_count: 1]
      )
    end)
  end

  @doc """
  Finds clusters of consolidation candidates: low-importance episodic/working memories
  for a character that share at least one tag with another memory in the group.
  Returns a list of clusters, each cluster being a list of Memory structs.
  Only considers groups of 3+ memories.
  """
  def find_consolidation_candidates(character_id) do
    candidates =
      Repo.all(
        from m in Memory,
          where:
            m.owner_character_id == ^character_id and
              m.status == "active" and
              m.category in ["episodic", "working"] and
              m.importance < 40,
          order_by: [asc: m.inserted_at]
      )

    cluster_by_shared_tags(candidates)
  end

  defp cluster_by_shared_tags(memories) do
    memories
    |> Enum.reduce([], fn mem, clusters ->
      matching_cluster_idx =
        Enum.find_index(clusters, fn cluster ->
          Enum.any?(cluster, fn existing ->
            not Enum.empty?(mem.tags -- (mem.tags -- existing.tags))
          end)
        end)

      if matching_cluster_idx do
        List.update_at(clusters, matching_cluster_idx, &(&1 ++ [mem]))
      else
        clusters ++ [[mem]]
      end
    end)
    |> Enum.filter(&(length(&1) >= 3))
  end

  def mark_consolidated(memory_ids, consolidated_into_id) when is_list(memory_ids) do
    MemoryOperation.with_global(fn ->
      Repo.update_all(
        from(m in Memory, where: m.id in ^memory_ids),
        set: [status: "consolidated", consolidated_into_id: consolidated_into_id]
      )
    end)
  end

  def list_memories_by_category(character_id, category) do
    Repo.all(
      from m in Memory,
        where: m.owner_character_id == ^character_id and m.category == ^category,
        order_by: [desc: m.importance]
    )
  end

  def list_unresolved_memories(character_id) do
    Repo.all(
      from m in Memory,
        where: m.owner_character_id == ^character_id and m.is_resolved == false,
        order_by: [desc: m.importance, desc: m.emotional_intensity]
    )
  end

  def create_memory(attrs \\ %{}) do
    owner_id = Map.get(attrs, :owner_character_id) || Map.get(attrs, "owner_character_id")

    MemoryOperation.with_owner(owner_id, fn ->
      %Memory{}
      |> Memory.changeset(attrs)
      |> Repo.insert()
    end)
  end

  def update_memory(%Memory{} = memory, attrs) do
    MemoryOperation.with_owner(memory.owner_character_id, fn ->
      memory
      |> Memory.changeset(attrs)
      |> Repo.update()
    end)
  end

  @doc "Corrects a memory and records the before/after states in the Soul Ledger."
  def correct_memory(%Memory{} = memory, attrs, opts \\ []) when is_map(attrs) do
    owner_id = memory.owner_character_id
    safe_attrs = Map.drop(attrs, [:owner_character_id, "owner_character_id"])
    reason = Keyword.get(opts, :reason, "memory correction")
    source = Keyword.get(opts, :source, "memory_vault")

    MemoryOperation.with_owner(owner_id, fn ->
      Repo.transaction(fn ->
        {:ok, corrected} =
          memory
          |> Memory.changeset(safe_attrs)
          |> Repo.update()

        {:ok, _entry} =
          Ledger.create_entry(%{
            character_id: owner_id,
            memory_id: corrected.id,
            entry_type: "memory_corrected",
            source: source,
            summary: "Memory corrected: #{corrected.summary}",
            before_state: memory_snapshot(memory),
            after_state: memory_snapshot(corrected),
            reason: reason
          })

        corrected
      end)
    end)
  end

  @doc "Exports a character's memories and records the export in the Soul Ledger."
  def export_memories_for_character(character_id, opts \\ []) do
    source = Keyword.get(opts, :source, "memory_vault")

    MemoryOperation.with_owner(character_id, fn ->
      Repo.transaction(fn ->
        memories = list_memories_for_character(character_id)

        {:ok, _entry} =
          Ledger.create_entry(%{
            character_id: character_id,
            entry_type: "memory_exported",
            source: source,
            summary: "Exported #{length(memories)} memories",
            delta: %{count: length(memories)}
          })

        memories
      end)
    end)
  end

  def delete_memory(%Memory{} = memory, opts \\ []) do
    reason = Keyword.get(opts, :reason, "memory deletion")
    source = Keyword.get(opts, :source, "memory_vault")

    MemoryOperation.with_owner(memory.owner_character_id, fn ->
      Repo.transaction(fn ->
        {:ok, _entry} =
          Ledger.create_entry(%{
            character_id: memory.owner_character_id,
            memory_id: memory.id,
            entry_type: "memory_deleted",
            source: source,
            summary: "Memory deleted: #{memory.summary}",
            before_state: memory_snapshot(memory),
            reason: reason
          })

        {:ok, deleted} = Repo.delete(memory)
        deleted
      end)
    end)
  end

  def change_memory(%Memory{} = memory, attrs \\ %{}) do
    Memory.changeset(memory, attrs)
  end

  @doc """
  Selectively purges memories for a character based on topic query, category, or all.
  Returns `{:ok, deleted_count}`.
  """
  def purge_memories_for_character(character_id, opts \\ []) do
    MemoryOperation.with_owner(character_id, fn ->
      with {:ok, opts} <- SovereignSoulEngine.Memories.PurgeFilters.validate(opts) do
        query = from(m in Memory, where: m.owner_character_id == ^character_id)

        query =
          cond do
            Keyword.get(opts, :all) == true ->
              query

            topic = Keyword.get(opts, :topic) || Keyword.get(opts, :query) ->
              from(m in query,
                where: fragment("strpos(lower(?), lower(?)) > 0", m.summary, ^topic)
              )

            category = Keyword.get(opts, :category) ->
              cat_str = to_string(category)
              from(m in query, where: m.category == ^cat_str)

            true ->
              query
          end

        {count, _} = Repo.delete_all(query)
        {:ok, count}
      end
    end)
  end

  # ── Temporal Fact Supersession (Graphiti / Mem0 Architecture) ───────────────

  @doc """
  Supersedes an existing fact/memory with a new one, implementing temporal fact
  supersession (Graphiti pattern).

  The previous memory is marked as status "superseded" with its validity window closed:
    - valid_until closes the prior validity window
    - superseded_by_id links to the new memory
    - supersession_reason records why this fact changed

  The new memory is inserted as status "active" with:
    - valid_from is set to the supersession timestamp
    - supersedes_id links to the previous memory
    - provenance records source_type (:witnessed, :told_by, :rumor, :inferred, etc.)

  Both changes happen atomically in a database transaction and are recorded in the Soul Ledger.
  """
  def supersede_memory(old_memory_or_id, new_attrs_or_summary, opts \\ [])

  def supersede_memory(old_memory_id, new_attrs, opts) when is_binary(old_memory_id) do
    case Repo.get(Memory, old_memory_id) do
      nil -> {:error, :memory_not_found}
      old_memory -> supersede_memory(old_memory, new_attrs, opts)
    end
  end

  def supersede_memory(%Memory{} = old_memory, summary, opts) when is_binary(summary) do
    supersede_memory(old_memory, %{summary: summary}, opts)
  end

  def supersede_memory(%Memory{} = old_memory, new_attrs, opts) when is_map(new_attrs) do
    owner_id = old_memory.owner_character_id
    reason = Keyword.get(opts, :reason, "superseded by newer event")
    source = Keyword.get(opts, :source, "world_event")
    source_type = Keyword.get(opts, :source_type, :witnessed)
    source_character_id = Keyword.get(opts, :source_character_id)
    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now())
    ts_iso = DateTime.to_iso8601(timestamp)

    new_summary =
      Map.get(new_attrs, :summary) || Map.get(new_attrs, "summary") || old_memory.summary

    new_category =
      Map.get(new_attrs, :category) || Map.get(new_attrs, "category") || old_memory.category

    new_importance =
      Map.get(new_attrs, :importance) || Map.get(new_attrs, "importance") || old_memory.importance

    new_tags = Map.get(new_attrs, :tags) || Map.get(new_attrs, "tags") || old_memory.tags

    MemoryOperation.with_owner(owner_id, fn ->
      Repo.transaction(fn ->
        # 1. Insert new memory first to obtain its canonical Ecto ID
        incoming_meta = Map.get(new_attrs, :metadata) || Map.get(new_attrs, "metadata") || %{}

        new_meta =
          incoming_meta
          |> Map.put("valid_from", ts_iso)
          |> Map.put("supersedes_id", old_memory.id)
          |> Map.put("provenance", %{
            "source_type" => to_string(source_type),
            "source_character_id" => source_character_id,
            "recorded_at" => ts_iso
          })

        new_memory_params =
          new_attrs
          |> Map.merge(%{
            owner_character_id: owner_id,
            category: new_category,
            summary: new_summary,
            importance: new_importance,
            tags: new_tags,
            occurred_at: timestamp,
            status: "active",
            metadata: new_meta,
            valid_from: timestamp,
            supersedes_id: old_memory.id,
            provenance: Map.get(new_meta, "provenance", %{})
          })

        {:ok, new_memory} =
          %Memory{}
          |> Memory.changeset(new_memory_params)
          |> Repo.insert()

        # 2. Update old memory to superseded with link to new_memory.id
        old_meta = old_memory.metadata || %{}

        updated_old_meta =
          old_meta
          |> Map.put("valid_until", ts_iso)
          |> Map.put("superseded_by_id", new_memory.id)
          |> Map.put("superseded_at", ts_iso)
          |> Map.put("supersession_reason", reason)

        old_changeset =
          old_memory
          |> Memory.changeset(%{
            status: "superseded",
            metadata: updated_old_meta,
            valid_until: timestamp,
            superseded_by_id: new_memory.id,
            supersession_reason: reason
          })

        {:ok, updated_old} = Repo.update(old_changeset)

        # 3. Record supersession in Soul Ledger
        {:ok, _ledger} =
          Ledger.create_entry(%{
            character_id: owner_id,
            memory_id: new_memory.id,
            entry_type: "fact_superseded",
            source: source,
            summary: "Fact superseded: '#{old_memory.summary}' -> '#{new_memory.summary}'",
            delta: %{
              old_memory_id: old_memory.id,
              new_memory_id: new_memory.id,
              reason: reason,
              source_type: to_string(source_type)
            },
            reason: reason
          })

        %{old_memory: updated_old, new_memory: new_memory}
      end)
    end)
  end

  @doc """
  Lists all superseded memories for a character.
  """
  def list_superseded_memories(character_id) do
    Repo.all(
      from m in Memory,
        where: m.owner_character_id == ^character_id and m.status == "superseded",
        order_by: [desc: m.occurred_at]
    )
  end

  @doc """
  Returns the complete evolutionary lineage of a fact by walking its
  `supersedes_id` ancestors and `superseded_by_id` descendants.
  """
  def get_fact_history(memory_or_id)

  def get_fact_history(memory_id) when is_binary(memory_id) do
    case Repo.get(Memory, memory_id) do
      nil -> []
      memory -> get_fact_history(memory)
    end
  end

  def get_fact_history(%Memory{} = memory) do
    fresh_memory = Repo.get(Memory, memory.id) || memory
    ancestors = walk_supersedes(fresh_memory, [])
    descendants = walk_superseded_by(fresh_memory, [])
    ancestors ++ [fresh_memory] ++ descendants
  end

  defp walk_supersedes(%Memory{} = memory, acc) do
    case Memory.supersedes_id(memory) do
      nil ->
        acc

      parent_id ->
        case Repo.get(Memory, parent_id) do
          nil -> acc
          parent -> walk_supersedes(parent, [parent | acc])
        end
    end
  end

  defp walk_superseded_by(%Memory{} = memory, acc) do
    case Memory.superseded_by_id(memory) do
      nil ->
        Enum.reverse(acc)

      child_id ->
        case Repo.get(Memory, child_id) do
          nil -> Enum.reverse(acc)
          child -> walk_superseded_by(child, [child | acc])
        end
    end
  end

  @doc """
  Temporal Query (Graphiti pattern): Returns memories that were held and valid
  for `character_id` at the given `as_of_time` DateTime.

  If a fact was superseded after `as_of_time`, its older version is returned
  and the newer version is excluded.
  """
  def list_memories_as_of(character_id, as_of_time, _opts \\ []) do
    # Fetch all candidate memories that occurred on or before as_of_time
    candidates =
      Repo.all(
        from m in Memory,
          where:
            m.owner_character_id == ^character_id and
              m.occurred_at <= ^as_of_time and
              m.status in ["active", "superseded"],
          order_by: [desc: m.importance, desc: m.occurred_at]
      )

    Enum.filter(candidates, fn m ->
      v_from = parse_datetime(Memory.valid_from(m))
      v_until = parse_datetime(Memory.valid_until(m))

      valid_from_ok = is_nil(v_from) or DateTime.compare(v_from, as_of_time) in [:lt, :eq]
      valid_until_ok = is_nil(v_until) or DateTime.compare(v_until, as_of_time) == :gt

      valid_from_ok and valid_until_ok
    end)
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(iso_str) when is_binary(iso_str) do
    case DateTime.from_iso8601(iso_str) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil

  defp memory_snapshot(%Memory{} = memory) do
    Map.take(memory, [
      :id,
      :owner_character_id,
      :category,
      :summary,
      :details,
      :importance,
      :confidence,
      :tags,
      :occurred_at,
      :status
    ])
  end
end
