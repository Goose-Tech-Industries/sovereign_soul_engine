defmodule SovereignSoulEngine.Memories.MemoryConsolidation do
  @moduledoc """
  Deterministic consolidation engine for promoting memories between categories.

  Consolidation rules:
    - Repeated episodic memories (recall_count >= 5, importance >= 70)
      → relationship memory
    - High-emotional-intensity memories from harmful events (emotional_intensity >= 80,
      harmful event, valence < 0) → wound memory
    - High-importance memory (importance >= 90) → core memory
    - Frequently recalled core memory (category == core, recall_count >= 10) → belief memory
    - Contradictory memories do not overwrite each other; they coexist unless resolved.
  """

  @harmful_event_types ~w(betrayed_me attacked_me insulted_me threatened_me abandoned_me lied_to_me)a

  @doc """
  Evaluates whether a memory should be promoted to a different category.

  Returns a list of consolidation results: `{:promote, new_category, reason}`
  or an empty list if no promotion is recommended.

  Options:
    - `:related_memory_count` — number of similar episodic memories (for relationship promotion)
    - `:event_type` — the associated soul event type for harmful-event checks

  Returns `[{:promote, new_category, reason}]` or `[]`.
  """
  @spec evaluate(map(), keyword()) :: [{:promote, atom(), String.t()}]
  def evaluate(memory, opts \\ []) do
    category = normalize_category(Map.get(memory, :category))
    importance = Map.get(memory, :importance, 1)
    emotional_intensity = Map.get(memory, :emotional_intensity, 0)
    recall_count = Map.get(memory, :recall_count, 0)
    valence = Map.get(memory, :valence, 0.0)
    event_type = Keyword.get(opts, :event_type)
    related_memory_count = Keyword.get(opts, :related_memory_count, 0)

    promotions = []

    promotions =
      case maybe_promote_to_belief(category, recall_count) do
        nil -> promotions
        {cat, reason} -> [{:promote, cat, reason} | promotions]
      end

    promotions =
      case maybe_promote_to_core(category, importance) do
        nil -> promotions
        {cat, reason} -> [{:promote, cat, reason} | promotions]
      end

    promotions =
      case maybe_promote_to_wound(category, emotional_intensity, valence, event_type) do
        nil -> promotions
        {cat, reason} -> [{:promote, cat, reason} | promotions]
      end

    promotions =
      case maybe_promote_to_relationship(category, recall_count, importance, related_memory_count) do
        nil -> promotions
        {cat, reason} -> [{:promote, cat, reason} | promotions]
      end

    Enum.reverse(promotions)
  end

  @doc """
  Checks if two memories are contradictory (describe opposing interpretations of the same event).

  Two memories are contradictory if they share the same event_id but have opposing valences
  (one positive, one negative) with significant emotional intensity difference.
  Returns `true` if contradictory, `false` otherwise.
  """
  @spec contradictory?(map(), map()) :: boolean()
  def contradictory?(memory_a, memory_b) do
    event_a = Map.get(memory_a, :event_id)
    event_b = Map.get(memory_b, :event_id)
    same_event? = not is_nil(event_a) and event_a == event_b

    va = Map.get(memory_a, :valence, 0.0)
    vb = Map.get(memory_b, :valence, 0.0)
    opposite_valence? = (va > 0.1 and vb < -0.1) or (va < -0.1 and vb > 0.1)

    same_event? and opposite_valence?
  end

  defp maybe_promote_to_belief(:core, recall_count) when recall_count >= 10,
    do: {:belief, "Core memory recalled #{recall_count} times; promoted to belief"}

  defp maybe_promote_to_belief(_, _), do: nil

  defp maybe_promote_to_core(category, importance)
       when category not in [:core, :belief] and importance >= 90,
       do: {:core, "Importance #{importance} >= 90; promoted to core memory"}

  defp maybe_promote_to_core(_, _), do: nil

  defp maybe_promote_to_wound(category, emotional_intensity, valence, event_type)
       when category not in [:wound, :core, :belief] do
    is_harmful = not is_nil(event_type) and event_type in @harmful_event_types

    if emotional_intensity >= 80 and is_harmful and valence < -0.1 do
      {:wound,
       "Emotional intensity #{emotional_intensity} >= 80 with harmful event #{event_type}; promoted to wound"}
    end
  end

  defp maybe_promote_to_wound(_, _, _, _), do: nil

  defp maybe_promote_to_relationship(category, recall_count, importance, related_count)
       when category not in [:relationship, :wound, :core, :belief] do
    if recall_count >= 5 and importance >= 70 do
      {:relationship,
       "Recalled #{recall_count} times with importance #{importance} and #{related_count} related memories; promoted to relationship"}
    end
  end

  defp maybe_promote_to_relationship(_, _, _, _), do: nil

  defp normalize_category(cat) when is_atom(cat), do: cat
  defp normalize_category(cat) when is_binary(cat), do: String.to_existing_atom(cat)
  defp normalize_category(_), do: :episodic
end
