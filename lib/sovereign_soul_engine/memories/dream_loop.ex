defmodule SovereignSoulEngine.Memories.DreamLoop do
  @moduledoc """
  The Dream Loop: Biological sleep and memory consolidation cycle.

  When an NPC rests or enters idle sleep:
  1. Emotional Residue Decay: Temporary emotional spikes (anger, fear, stress, rumination)
     decay exponentially toward the character's baseline emotional profile.
  2. Episodic Distillation: Working and low-importance episodic memories are clustered
     and distilled into long-term semantic core memories.
  3. Ledger & Pruning Commit: Distilled memories are persisted, consolidated sources are
     flagged, and raw context is pruned, preserving lightweight GenServer memory footprints.
  """

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Ledger.LedgerBuilder
  alias SovereignSoulEngine.Characters

  require Logger

  @default_decay_factor 0.35

  @doc """
  Runs a complete Dream Loop consolidation cycle for the given character.

  Options:
    - `:decay_factor` (float) - rate of decay toward baseline (default 0.35, i.e. 35% drop toward baseline)
    - `:force` (boolean) - whether to consolidate even if memory count is low
    - `:correlation_id` (string) - correlation UUID for ledger tracing
  """
  def run_cycle(character_id, opts \\ []) do
    decay_factor = Keyword.get(opts, :decay_factor, @default_decay_factor)
    correlation_id = Keyword.get(opts, :correlation_id, Ecto.UUID.generate())

    emotional_res = decay_emotional_residue(character_id, decay_factor)
    distillation_res = distill_episodic_memories(character_id, opts)

    # Commit event to SoulLedger
    commit_ledger_dream_entry(character_id, emotional_res, distillation_res, correlation_id)

    # Broadcast dream completion on PubSub
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "character:#{character_id}",
      {:dream_loop_completed,
       %{
         character_id: character_id,
         emotional_deltas: emotional_res,
         distilled_count: length(distillation_res)
       }}
    )

    {:ok,
     %{
       character_id: character_id,
       emotional_decay: emotional_res,
       distilled_memories: distillation_res
     }}
  end

  @doc """
  Applies emotional decay toward the character's baseline emotions.
  """
  def decay_emotional_residue(character_id, decay_factor \\ @default_decay_factor) do
    emotional_state = Souls.get_emotional_state_by_character(character_id)
    profile = Souls.get_soul_profile_by_character(character_id)

    if emotional_state && profile do
      baseline = profile.baseline_emotions || %{}

      decayed_attrs =
        Enum.reduce(
          [:anger, :fear, :stress, :sadness, :curiosity, :gratitude, :confidence, :attachment],
          %{},
          fn emotion, acc ->
            current = Map.get(emotional_state, emotion, 0) || 0
            base = Map.get(baseline, emotion, Map.get(baseline, Atom.to_string(emotion), current)) || current
            new_val = round(current - (current - base) * decay_factor)
            clamped = max(0, min(100, new_val))
            Map.put(acc, emotion, clamped)
          end
        )

      # Also settle rumination during sleep
      decayed_attrs =
        Map.put(
          decayed_attrs,
          :rumination_intensity,
          max(0, round((emotional_state.rumination_intensity || 0) * (1.0 - decay_factor)))
        )

      case Souls.update_emotional_state(emotional_state, decayed_attrs) do
        {:ok, updated} ->
          %{
            anger: updated.anger,
            fear: updated.fear,
            stress: updated.stress,
            rumination_intensity: updated.rumination_intensity
          }

        _ ->
          %{}
      end
    else
      %{}
    end
  end

  @doc """
  Finds low-importance episodic memories and distills them into long-term core/semantic memories.
  """
  def distill_episodic_memories(character_id, opts \\ []) do
    clusters = Memories.find_consolidation_candidates(character_id)

    clusters =
      if clusters == [] and Keyword.get(opts, :force, false) do
        # If force is requested, cluster any un-consolidated episodic memories
        memories =
          Memories.list_memories_for_character(character_id)
          |> Enum.filter(&(&1.category in ["episodic", "working"] and &1.status == "active"))
          |> Enum.take(6)

        if length(memories) >= 2, do: [memories], else: []
      else
        clusters
      end

    Enum.map(clusters, fn group ->
      consolidate_group(character_id, group)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp consolidate_group(character_id, group) when is_list(group) and length(group) > 0 do
    candidate_ids = Enum.map(group, & &1.id)
    all_tags = group |> Enum.flat_map(& &1.tags) |> Enum.uniq()

    avg_importance =
      round(Enum.sum(Enum.map(group, & &1.importance)) / max(1, length(group)))

    avg_emotional_intensity =
      round(Enum.sum(Enum.map(group, & &1.emotional_intensity)) / max(1, length(group)) * 0.7)

    subject_id =
      group
      |> Enum.map(& &1.subject_character_id)
      |> Enum.reject(&is_nil/1)
      |> List.first()

    summaries = Enum.map(group, & &1.summary) |> Enum.join(" | ")
    character = Characters.get_character(character_id)
    char_name = if character, do: character.name, else: "Character"

    distilled_summary =
      "Distilled sleep reflection: #{char_name} processed recent interactions (#{truncate_text(summaries, 120)})."

    attrs = %{
      owner_character_id: character_id,
      subject_character_id: subject_id,
      category: "core",
      summary: distilled_summary,
      details: %{"description" => "Consolidated from #{length(group)} events during dream sleep cycle."},
      importance: min(100, avg_importance + 20),
      emotional_intensity: avg_emotional_intensity,
      valence: 0.0,
      tags: Enum.uniq(all_tags ++ ["dream_distilled", "consolidated"]),
      status: "active",
      decay_rate: 0.2,
      occurred_at: DateTime.utc_now()
    }

    case Memories.create_memory(attrs) do
      {:ok, new_memory} ->
        Memories.mark_consolidated(candidate_ids, new_memory.id)
        new_memory

      {:error, reason} ->
        Logger.warning("Failed to create distilled memory: #{inspect(reason)}")
        nil
    end
  end

  defp commit_ledger_dream_entry(character_id, emotional_res, distilled, correlation_id) do
    entry =
      LedgerBuilder.build_event_entry(
        character_id: character_id,
        scene_id: nil,
        entry_type: :dream_consolidation_completed,
        source: "dream_loop",
        label: "Dream Consolidation",
        summary: "Dream loop completed: emotional residue settled, #{length(distilled)} memories distilled.",
        delta: %{
          emotional_decay: emotional_res,
          distilled_count: length(distilled)
        },
        correlation_id: correlation_id
      )

    Repo.insert(entry)
  rescue
    e ->
      Logger.warning("Could not write dream ledger entry: #{inspect(e)}")
      :ok
  end

  defp truncate_text(text, max_len) when is_binary(text) do
    if String.length(text) > max_len do
      String.slice(text, 0, max_len - 3) <> "..."
    else
      text
    end
  end

  defp truncate_text(other, _), do: to_string(other)
end
