defmodule SovereignSoulEngine.Memories.MemoryRetrieval do
  @moduledoc """
  Deterministic memory retrieval using scoring and ranking.

  Filters memories by subject, category, tags, or resolution status,
  then scores and ranks them using MemoryScoring.

  Includes context-aware retrieval that factors in the current scene,
  active relationships, and character's core beliefs for relevance boosts.
  """

  alias SovereignSoulEngine.Memories.MemoryScoring

  @doc """
  Retrieves and ranks memories for a character.

  Accepts a list of memory maps and optional filters/context.

  Filters:
    - `:subject_character_id` — filter to memories about a specific character
    - `:categories` — list of category strings/atoms to include
    - `:tags` — list of tags; memory must have at least one matching tag
    - `:unresolved_only` — only include unresolved memories (default: false)
    - `:min_importance` — minimum importance threshold

  Context (passed to MemoryScoring):
    - `:now` — reference time for recency
    - `:core_belief_relevance` — 0..1 for belief boost
    - `:relationship_relevance` — 0..1 for relationship boost
    - `:recency_halflife_days` — recency halflife

  Returns list of scored memory maps, sorted by score descending.
  """
  @spec retrieve(list(map()), keyword()) :: [map()]
  def retrieve(memories, opts \\ []) do
    scored = apply_context_scoring(memories, opts)
    scored |> Enum.sort_by(& &1.score, :desc)
  end

  @doc """
  Same as retrieve/2 but also returns category-level breakdowns and aggregate stats.
  """
  @spec retrieve_with_stats(list(map()), keyword()) :: %{
          results: [map()],
          stats: map()
        }
  def retrieve_with_stats(memories, opts \\ []) do
    results = retrieve(memories, opts)

    stats =
      if results != [] do
        %{
          total: length(results),
          avg_score: avg(results, :score),
          top_score: hd(results).score,
          by_category: group_by_category(results)
        }
      else
        %{total: 0, avg_score: 0.0, top_score: 0.0, by_category: %{}}
      end

    %{results: results, stats: stats}
  end

  defp apply_context_scoring(memories, opts) do
    subject_id = Keyword.get(opts, :subject_character_id)
    categories = Keyword.get(opts, :categories)
    tags = Keyword.get(opts, :tags)
    unresolved_only = Keyword.get(opts, :unresolved_only, false)
    min_importance = Keyword.get(opts, :min_importance, 0)

    scoring_opts =
      opts
      |> Keyword.take([
        :now,
        :core_belief_relevance,
        :relationship_relevance,
        :recency_halflife_days
      ])

    memories
    |> Enum.filter(fn m -> not unresolved_only or not Map.get(m, :is_resolved, false) end)
    |> Enum.filter(fn m -> is_nil(subject_id) or m[:subject_character_id] == subject_id end)
    |> Enum.filter(fn m ->
      is_nil(categories) or normalize_category(m[:category]) in categories
    end)
    |> Enum.filter(fn m ->
      is_nil(tags) or has_any_tag?(m[:tags], tags)
    end)
    |> Enum.filter(fn m -> Map.get(m, :importance, 0) >= min_importance end)
    |> MemoryScoring.rank(scoring_opts)
  end

  defp has_any_tag?(nil, _), do: false
  defp has_any_tag?(mem_tags, filter_tags), do: Enum.any?(mem_tags, &(&1 in filter_tags))

  defp avg(list, key) do
    sum = Enum.reduce(list, 0.0, fn m, acc -> acc + Map.get(m, key, 0.0) end)
    Float.round(sum / max(length(list), 1), 2)
  end

  defp group_by_category(results) do
    results
    |> Enum.group_by(fn m -> to_string(m[:category]) end)
    |> Enum.map(fn {cat, mems} -> {cat, length(mems)} end)
    |> Map.new()
  end

  defp normalize_category(cat) when is_atom(cat), do: cat
  defp normalize_category(cat) when is_binary(cat), do: String.to_existing_atom(cat)
  defp normalize_category(_), do: :episodic
end
