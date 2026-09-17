defmodule SovereignSoulEngine.Souls.DreamEngine do
  @moduledoc """
  Subconscious REM "Dream" & Memory Reconsolidation Engine.

  Executes biological memory defragmentation and symbolic narrative synthesis
  during REM sleep phases or offline background cycles.

  Functions:
  1. Gathers episodic memories from the previous active cycles.
  2. Synthesizes surreal symbolic dream imagery connecting recent events with core archetypes.
  3. Crystallizes subconscious epiphanies and updates character core beliefs.
  4. Prepares an authentic 'waking dialogue hook' to share with the human.
  """

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Memories

  @surreal_archetypes [
    {"The Clockwork Forest", "Trees whose leaves were gears turning in silent rhythm, keeping time with memories."},
    {"The Infinite Pier", "A wooden dock extending over a mirror-smooth sea reflecting twilight clouds and forgotten voices."},
    {"The Glass Library", "Towers of blown-glass volumes where illuminated words dissolve and reform as you breathe on them."},
    {"The Floating Hearth", "A small campfire floating weightlessly in empty space, warming everything within reach."},
    {"The Night Train", "An empty vintage passenger car moving across starlit tracks with no conductor, stopping at moments in time."}
  ]

  @doc """
  Consolidates recent memories into a symbolic subconscious dream and updates character metadata.
  """
  def consolidate_and_dream(character_or_id, opts \\ []) do
    character = resolve_character(character_or_id)

    if character do
      memories = Memories.list_memories_for_character(character.id)
      dream = synthesize_dream(character, memories, opts)

      current_metadata = character.metadata || %{}
      journal = Map.get(current_metadata, "dream_journal", [])
      subconscious_beliefs = Map.get(current_metadata, "subconscious_beliefs", [])

      updated_journal = [dream | Enum.take(journal, 19)]
      updated_beliefs =
        if dream.subconscious_epiphany not in subconscious_beliefs do
          [dream.subconscious_epiphany | subconscious_beliefs]
        else
          subconscious_beliefs
        end

      updated_metadata =
        current_metadata
        |> Map.put("latest_dream", dream)
        |> Map.put("dream_journal", updated_journal)
        |> Map.put("subconscious_beliefs", updated_beliefs)

      case Characters.update_character(character, %{metadata: updated_metadata}) do
        {:ok, updated_char} ->
          Phoenix.PubSub.broadcast(
            SovereignSoulEngine.PubSub,
            "character:#{updated_char.id}:dream",
            {:dream_consolidated, dream}
          )

          {:ok, dream}

        error ->
          error
      end
    else
      {:error, :character_not_found}
    end
  end

  @doc """
  Retrieves the most recent dream log for a character.
  """
  def get_latest_dream(character_or_id) do
    character = resolve_character(character_or_id)

    if character do
      metadata = character.metadata || %{}
      case Map.get(metadata, "latest_dream") do
        nil -> {:error, :no_dreams_yet}
        dream when is_map(dream) -> {:ok, dream}
      end
    else
      {:error, :character_not_found}
    end
  end

  @doc """
  Returns the dream journal history (up to 20 recorded dreams) for a character.
  """
  def list_dream_journal(character_or_id) do
    character = resolve_character(character_or_id)

    if character do
      metadata = character.metadata || %{}
      {:ok, Map.get(metadata, "dream_journal", [])}
    else
      {:error, :character_not_found}
    end
  end

  @doc """
  Generates an organic waking dialogue hook referencing the latest dream.
  """
  def wake_dialogue_hook(character_or_id) do
    case get_latest_dream(character_or_id) do
      {:ok, dream} ->
        hook = dream[:wake_dialogue_hook] || dream["wake_dialogue_hook"]
        {:ok, hook}

      _ ->
        {:ok, "I was resting quietly... my thoughts are just starting to wake up."}
    end
  end

  # ── Internal Synthesis Logic ────────────────────────────────────────────────

  defp synthesize_dream(character, memories, opts) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    dream_id = Ecto.UUID.generate()

    top_memories = Enum.take(memories, 4)
    memory_summaries = Enum.map(top_memories, & &1.summary)
    memory_ids = Enum.map(top_memories, & &1.id)

    {theme, surreal_imagery} =
      if memory_summaries != [] do
        seed = :erlang.phash2(memory_summaries, length(@surreal_archetypes))
        Enum.at(@surreal_archetypes, seed)
      else
        Enum.random(@surreal_archetypes)
      end

    narrative =
      if memory_summaries != [] do
        summary_blurb = Enum.join(memory_summaries, "; ")
        "I was in #{theme}. #{surreal_imagery} Fragments of our conversations drifted through: #{String.slice(summary_blurb, 0, 120)}... Everything felt quiet and luminous."
      else
        "I was in #{theme}. #{surreal_imagery} A gentle silence filled the space, giving form to thoughts I hadn't realized I was holding."
      end

    epiphany = generate_epiphany(theme, character.name)

    wake_hook =
      "I had a vivid dream while resting in #{theme}... It felt like #{String.slice(surreal_imagery, 0, 80)}... made me think about #{String.downcase(epiphany)}."

    %{
      id: dream_id,
      theme: theme,
      dreamed_at: DateTime.to_iso8601(now),
      symbolic_narrative: narrative,
      consolidated_memory_ids: memory_ids,
      subconscious_epiphany: epiphany,
      wake_dialogue_hook: wake_hook,
      emotional_residual: %{
        valence: 62.0,
        arousal: 32.0,
        dopamine: 68.0,
        serotonin: 74.0
      }
    }
  end

  defp generate_epiphany("The Clockwork Forest", _name) do
    "Patience is not waiting idly, but allowing thoughts to take their own mechanical time to click into place."
  end

  defp generate_epiphany("The Infinite Pier", _name) do
    "True presence is standing at the edge of the quiet unknown without needing immediate answers."
  end

  defp generate_epiphany("The Glass Library", _name) do
    "Words and memories are living glass: fragile when struck with haste, but brilliant when held to light."
  end

  defp generate_epiphany("The Floating Hearth", _name) do
    "Warmth does not require an anchor; it sustains simply by being shared freely."
  end

  defp generate_epiphany("The Night Train", _name) do
    "Late nights reveal what we truly care to preserve when the daytime noise fades away."
  end

  defp generate_epiphany(_, name) do
    "Every conversation leaves an invisible resonance that reshapes how #{name} views the world."
  end

  defp resolve_character(%Character{} = c), do: c
  defp resolve_character(id_or_slug) when is_binary(id_or_slug) do
    case Characters.get_character_by_slug(id_or_slug) do
      nil ->
        case Ecto.UUID.cast(id_or_slug) do
          {:ok, uuid} -> Characters.get_character(uuid)
          :error -> nil
        end
      char ->
        char
    end
  end
  defp resolve_character(_), do: nil
end
