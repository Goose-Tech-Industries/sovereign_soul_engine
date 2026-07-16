defmodule SovereignSoulEngine.Memories.MemoryScoring do
  @moduledoc """
  Deterministic scoring function for ranking memories.

  Scores are computed from:
    - Base importance
    - Emotional intensity
    - Recency (time since last recall or occurrence)
    - Category weight
    - Recall reinforcement
    - Unresolved conflict bonus
    - Decay factor

  Returns both a score and a score explanation.
  """

  @category_weights %{
    core: 2.0,
    wound: 1.8,
    belief: 1.7,
    relationship: 1.3,
    episodic: 1.0,
    working: 0.3
  }

  @default_recency_halflife_days 7

  @doc """
  Scores a memory map and returns a ranked result.

  The memory map must include at least:
    - `:importance` (integer)
    - `:emotional_intensity` (integer)
    - `:category` (string or atom)
    - `:decay_rate` (float, default 1.0)
    - `:recall_count` (integer, default 0)
    - `:is_resolved` (boolean, default false)

  Optional keys:
    - `:last_recalled_at` or `:occurred_at` — DateTime or NaiveDateTime for recency
    - `:valence` (float) — memory valence

  Options:
    - `:now` — DateTime or NaiveDateTime for recency calculation (default: DateTime.utc_now/0)
    - `:recency_halflife_days` — days until recency factor halves (default: 7)
    - `:core_belief_relevance` — 0.0..1.0 relevance to character's core beliefs (default: 0)
    - `:relationship_relevance` — 0.0..1.0 relevance to an active relationship (default: 0)
  """
  @spec score(map(), keyword()) :: %{
          score: float(),
          explanation: map()
        }
  def score(memory, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    recency_halflife = Keyword.get(opts, :recency_halflife_days, @default_recency_halflife_days)
    core_belief_rel = Keyword.get(opts, :core_belief_relevance, 0.0)
    relationship_rel = Keyword.get(opts, :relationship_relevance, 0.0)

    importance = value(memory, :importance, 1)
    emotional_intensity = value(memory, :emotional_intensity, 0)
    category = normalize_category(memory[:category])
    decay_rate = value(memory, :decay_rate, 1.0)
    recall_count = value(memory, :recall_count, 0)
    resolved? = value(memory, :is_resolved, false)
    valence = value(memory, :valence, 0.0)

    category_weight = Map.get(@category_weights, category, 1.0)

    # Recency: days elapsed since last_recall or occurrence
    last_time = memory[:last_recalled_at] || memory[:occurred_at] || now
    days_elapsed = days_between(last_time, now)
    recency_factor = :math.pow(2.0, -days_elapsed / recency_halflife)

    # Recall reinforcement: each recall adds a small bonus, diminishing
    recall_bonus = 1.0 + :math.log(max(recall_count, 1)) / 10.0

    # Unresolved conflict bonus
    unresolved_bonus = if not resolved? and emotional_intensity >= 50, do: 1.3, else: 1.0

    # Decay penalty
    decay_penalty = if decay_rate > 0, do: 1.0 / max(decay_rate, 0.1), else: 1.0

    # Core belief relevance boost
    belief_boost = 1.0 + core_belief_rel * 0.5

    # Relationship relevance boost
    rel_boost = 1.0 + relationship_rel * 0.3

    # Absolute valence weight (strong emotions, positive or negative, matter more)
    valence_boost = 1.0 + abs(valence) * 0.3

    score_num =
      (importance + emotional_intensity * 0.7) *
        category_weight *
        recency_factor *
        recall_bonus *
        unresolved_bonus *
        decay_penalty *
        belief_boost *
        rel_boost *
        valence_boost

    %{
      score: Float.round(score_num, 2),
      explanation: %{
        base_importance: importance,
        emotional_intensity: emotional_intensity,
        category: to_string(category),
        category_weight: category_weight,
        recency_factor: Float.round(recency_factor, 4),
        recall_count: recall_count,
        recall_bonus: Float.round(recall_bonus, 4),
        unresolved: not resolved?,
        unresolved_bonus: Float.round(unresolved_bonus, 4),
        decay_rate: decay_rate,
        decay_penalty: Float.round(decay_penalty, 4),
        belief_relevance: Float.round(core_belief_rel, 4),
        belief_boost: Float.round(belief_boost, 4),
        relationship_relevance: Float.round(relationship_rel, 4),
        relationship_boost: Float.round(rel_boost, 4),
        valence: Float.round(valence, 4),
        valence_boost: Float.round(valence_boost, 4)
      }
    }
  end

  @doc """
  Scores and ranks a list of memories, returning them sorted by score descending.
  Each result is enriched with `:score` and `:score_explanation`.
  """
  @spec rank(list(map()), keyword()) :: [map()]
  def rank(memories, opts \\ []) do
    memories
    |> Enum.map(fn mem ->
      result = score(mem, opts)
      Map.merge(mem, %{score: result.score, score_explanation: result.explanation})
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp value(map_or_struct, key, default) do
    case Map.get(map_or_struct, key, default) do
      nil -> default
      val -> val
    end
  end

  defp normalize_category(cat) when is_atom(cat), do: cat
  defp normalize_category(cat) when is_binary(cat), do: String.to_existing_atom(cat)
  defp normalize_category(_), do: :episodic

  defp days_between(dt1, dt2) do
    secs = abs(DateTime.diff(ensure_datetime(dt1), ensure_datetime(dt2)))
    secs / 86_400.0
  end

  defp ensure_datetime(%DateTime{} = dt), do: dt

  defp ensure_datetime(%NaiveDateTime{} = ndt) do
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  defp ensure_datetime(_), do: DateTime.utc_now()
end
