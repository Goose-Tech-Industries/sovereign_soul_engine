defmodule SovereignSoulEngine.Memories do
  @moduledoc """
  Context for managing Memories — episodic, core, wound, belief, relationship, and working memories.
  """

  alias SovereignSoulEngine.Memories.Memory
  alias SovereignSoulEngine.Memories.MemoryRetrieval
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  def list_memories do
    Repo.all(Memory)
  end

  def get_memory!(id), do: Repo.get!(Memory, id)

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
    now = DateTime.utc_now()

    Repo.update_all(
      from(m in Memory, where: m.id in ^memory_ids),
      set: [last_recalled_at: now],
      inc: [recall_count: 1]
    )
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
    Repo.update_all(
      from(m in Memory, where: m.id in ^memory_ids),
      set: [status: "consolidated", consolidated_into_id: consolidated_into_id]
    )
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
    %Memory{}
    |> Memory.changeset(attrs)
    |> Repo.insert()
  end

  def update_memory(%Memory{} = memory, attrs) do
    memory
    |> Memory.changeset(attrs)
    |> Repo.update()
  end

  def delete_memory(%Memory{} = memory) do
    Repo.delete(memory)
  end

  def change_memory(%Memory{} = memory, attrs \\ %{}) do
    Memory.changeset(memory, attrs)
  end
end
