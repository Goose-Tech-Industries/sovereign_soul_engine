defmodule SovereignSoulEngine.Memories.MemoryRetrievalTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Memories.MemoryRetrieval

  @now ~U[2026-07-14 12:00:00Z]

  defp make_mem(attrs) do
    base = %{
      importance: 50,
      emotional_intensity: 50,
      category: :episodic,
      decay_rate: 1.0,
      recall_count: 0,
      is_resolved: false,
      valence: 0.0,
      occurred_at: @now,
      tags: [],
      details: %{},
      subject_character_id: nil
    }

    Map.merge(base, attrs)
  end

  describe "retrieval ordering" do
    test "returns memories sorted by score descending" do
      memories = [
        make_mem(%{id: "a", importance: 10}),
        make_mem(%{id: "c", category: :core, importance: 90}),
        make_mem(%{id: "b", importance: 50})
      ]

      results = MemoryRetrieval.retrieve(memories, now: @now)

      assert Enum.map(results, & &1.id) == ["c", "b", "a"]
    end

    test "all returned memories have score and score_explanation" do
      memories = [make_mem(%{id: "x"}), make_mem(%{id: "y"})]

      results = MemoryRetrieval.retrieve(memories, now: @now)

      Enum.each(results, fn m ->
        assert Map.has_key?(m, :score)
        assert Map.has_key?(m, :score_explanation)
      end)
    end

    test "deterministic ordering" do
      memories = for i <- 1..5, do: make_mem(%{id: i, importance: :rand.uniform(100)})

      ranked1 = MemoryRetrieval.retrieve(memories, now: @now)
      ranked2 = MemoryRetrieval.retrieve(memories, now: @now)

      assert Enum.map(ranked1, & &1.id) == Enum.map(ranked2, & &1.id)
    end
  end

  describe "filtering — subject" do
    test "filters by subject_character_id" do
      sid = Ecto.UUID.generate()

      memories = [
        make_mem(%{id: "target", subject_character_id: sid}),
        make_mem(%{id: "other", subject_character_id: Ecto.UUID.generate()})
      ]

      results = MemoryRetrieval.retrieve(memories, now: @now, subject_character_id: sid)

      assert length(results) == 1
      assert hd(results).id == "target"
    end
  end

  describe "filtering — categories" do
    test "filters by list of categories" do
      memories = [
        make_mem(%{id: "ep", category: :episodic}),
        make_mem(%{id: "co", category: :core}),
        make_mem(%{id: "wo", category: :wound})
      ]

      results = MemoryRetrieval.retrieve(memories, now: @now, categories: [:core, :wound])

      ids = Enum.map(results, & &1.id)
      assert "co" in ids
      assert "wo" in ids
      refute "ep" in ids
    end
  end

  describe "filtering — tags" do
    test "filters by required tags" do
      memories = [
        make_mem(%{id: "has_tag", tags: ["conflict", "protection"]}),
        make_mem(%{id: "no_tag", tags: ["peaceful"]}),
        make_mem(%{id: "empty", tags: []})
      ]

      results = MemoryRetrieval.retrieve(memories, now: @now, tags: ["conflict"])

      assert length(results) == 1
      assert hd(results).id == "has_tag"
    end
  end

  describe "filtering — unresolved" do
    test "only returns unresolved when filtered" do
      memories = [
        make_mem(%{id: "open", is_resolved: false, emotional_intensity: 80}),
        make_mem(%{id: "done", is_resolved: true, emotional_intensity: 80})
      ]

      results = MemoryRetrieval.retrieve(memories, now: @now, unresolved_only: true)

      assert length(results) == 1
      assert hd(results).id == "open"
    end
  end

  describe "filtering — min importance" do
    test "filters out low importance memories" do
      memories = [
        make_mem(%{id: "low", importance: 10}),
        make_mem(%{id: "high", importance: 80})
      ]

      results = MemoryRetrieval.retrieve(memories, now: @now, min_importance: 50)

      assert length(results) == 1
      assert hd(results).id == "high"
    end
  end

  describe "retrieve_with_stats" do
    test "returns stats along with ranked results" do
      memories = [
        make_mem(%{id: "a", category: :episodic, importance: 30}),
        make_mem(%{id: "b", category: :core, importance: 90}),
        make_mem(%{id: "c", category: :episodic, importance: 50})
      ]

      result = MemoryRetrieval.retrieve_with_stats(memories, now: @now)

      assert Map.has_key?(result, :results)
      assert Map.has_key?(result, :stats)
      assert result.stats.total == 3
      assert result.stats.avg_score > 0
      assert result.stats.top_score > 0
      assert Map.has_key?(result.stats.by_category, "episodic")
      assert Map.has_key?(result.stats.by_category, "core")
    end

    test "handles empty list gracefully" do
      result = MemoryRetrieval.retrieve_with_stats([], now: @now)

      assert result.stats.total == 0
      assert result.stats.avg_score == 0.0
      assert result.stats.top_score == 0.0
    end
  end

  describe "context-aware scoring" do
    test "core belief relevance boosts scores for all memories" do
      memories = [make_mem(%{id: "x", importance: 50})]

      no_context = MemoryRetrieval.retrieve(memories, now: @now, core_belief_relevance: 0.0)
      with_context = MemoryRetrieval.retrieve(memories, now: @now, core_belief_relevance: 1.0)

      assert hd(with_context).score > hd(no_context).score
    end
  end
end
