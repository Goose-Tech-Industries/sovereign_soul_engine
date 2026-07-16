defmodule SovereignSoulEngine.Memories.MemoryScoringTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Memories.MemoryScoring

  @now ~U[2026-07-14 12:00:00Z]

  @base_memory %{
    importance: 50,
    emotional_intensity: 60,
    category: :episodic,
    decay_rate: 1.0,
    recall_count: 0,
    is_resolved: false,
    valence: 0.0,
    occurred_at: @now,
    last_recalled_at: nil,
    id: nil
  }

  describe "scoring basics" do
    test "returns a score and explanation" do
      result = MemoryScoring.score(@base_memory, now: @now)

      assert is_map(result)
      assert Map.has_key?(result, :score)
      assert Map.has_key?(result, :explanation)
      assert is_float(result.score)
      assert result.score > 0
    end

    test "high importance yields higher score" do
      low = MemoryScoring.score(%{@base_memory | importance: 10}, now: @now)
      high = MemoryScoring.score(%{@base_memory | importance: 90}, now: @now)

      assert high.score > low.score
    end
  end

  describe "category weights" do
    test "core memories score higher than episodic" do
      episodic = MemoryScoring.score(%{@base_memory | category: :episodic}, now: @now)
      core = MemoryScoring.score(%{@base_memory | category: :core}, now: @now)

      assert core.score > episodic.score
    end

    test "wound memories score higher than working" do
      working = MemoryScoring.score(%{@base_memory | category: :working}, now: @now)
      wound = MemoryScoring.score(%{@base_memory | category: :wound}, now: @now)

      assert wound.score > working.score
    end

    test "belief memories score higher than episodic" do
      episodic = MemoryScoring.score(%{@base_memory | category: :episodic}, now: @now)
      belief = MemoryScoring.score(%{@base_memory | category: :belief}, now: @now)

      assert belief.score > episodic.score
    end
  end

  describe "recency" do
    test "recent memories score higher than old ones" do
      recent = MemoryScoring.score(%{@base_memory | occurred_at: @now}, now: @now)

      old =
        MemoryScoring.score(%{@base_memory | occurred_at: DateTime.add(@now, -30, :day)},
          now: @now
        )

      assert recent.score > old.score
    end

    test "last_recalled_at takes precedence over occurred_at" do
      never_recalled =
        MemoryScoring.score(
          Map.put(@base_memory, :occurred_at, DateTime.add(@now, -60, :day)),
          now: @now
        )

      frequently_recalled =
        MemoryScoring.score(
          @base_memory
          |> Map.put(:occurred_at, DateTime.add(@now, -60, :day))
          |> Map.put(:last_recalled_at, @now),
          now: @now
        )

      assert frequently_recalled.score > never_recalled.score
    end
  end

  describe "recall reinforcement" do
    test "more recalls increase score" do
      zero = MemoryScoring.score(%{@base_memory | recall_count: 0}, now: @now)
      many = MemoryScoring.score(%{@base_memory | recall_count: 20}, now: @now)

      assert many.score > zero.score
    end

    test "recall bonus demonstrates diminishing returns" do
      once = MemoryScoring.score(%{@base_memory | recall_count: 1}, now: @now)
      twice = MemoryScoring.score(%{@base_memory | recall_count: 2}, now: @now)
      three = MemoryScoring.score(%{@base_memory | recall_count: 3}, now: @now)

      diff_1_2 = twice.score - once.score
      diff_2_3 = three.score - twice.score

      assert diff_2_3 < diff_1_2
    end
  end

  describe "unresolved bonus" do
    test "unresolved high-intensity memories get a bonus" do
      resolved =
        MemoryScoring.score(%{@base_memory | is_resolved: true, emotional_intensity: 80},
          now: @now
        )

      unresolved =
        MemoryScoring.score(%{@base_memory | is_resolved: false, emotional_intensity: 80},
          now: @now
        )

      assert unresolved.score > resolved.score
    end

    test "unresolved low-intensity memories do not get bonus" do
      resolved =
        MemoryScoring.score(%{@base_memory | is_resolved: true, emotional_intensity: 10},
          now: @now
        )

      unresolved =
        MemoryScoring.score(%{@base_memory | is_resolved: false, emotional_intensity: 10},
          now: @now
        )

      assert_in_delta resolved.score, unresolved.score, 0.01
    end
  end

  describe "decay penalty" do
    test "higher decay_rate reduces score" do
      slow = MemoryScoring.score(%{@base_memory | decay_rate: 0.5}, now: @now)
      fast = MemoryScoring.score(%{@base_memory | decay_rate: 3.0}, now: @now)

      assert slow.score > fast.score
    end
  end

  describe "valence boost" do
    test "strongly valenced memories score higher" do
      neutral = MemoryScoring.score(%{@base_memory | valence: 0.0}, now: @now)
      positive = MemoryScoring.score(%{@base_memory | valence: 0.9}, now: @now)
      negative = MemoryScoring.score(%{@base_memory | valence: -0.9}, now: @now)

      assert positive.score > neutral.score
      assert negative.score > neutral.score
    end
  end

  describe "core belief relevance" do
    test "core belief relevance boosts score" do
      no_relevance = MemoryScoring.score(@base_memory, now: @now, core_belief_relevance: 0.0)
      high_relevance = MemoryScoring.score(@base_memory, now: @now, core_belief_relevance: 1.0)

      assert high_relevance.score > no_relevance.score
    end
  end

  describe "relationship relevance" do
    test "relationship relevance boosts score" do
      no_relevance = MemoryScoring.score(@base_memory, now: @now, relationship_relevance: 0.0)
      high_relevance = MemoryScoring.score(@base_memory, now: @now, relationship_relevance: 1.0)

      assert high_relevance.score > no_relevance.score
    end
  end

  describe "ranking" do
    test "rank returns memories sorted by score descending" do
      memories = [
        Map.put(@base_memory, :importance, 10),
        Map.put(@base_memory, :importance, 50),
        Map.put(Map.put(@base_memory, :category, :core), :importance, 90)
      ]

      ranked = MemoryScoring.rank(memories, now: @now)

      assert length(ranked) == 3
      assert Enum.at(ranked, 0).importance == 90
      assert Enum.at(ranked, 2).importance == 10

      Enum.each(ranked, fn m ->
        assert Map.has_key?(m, :score)
        assert Map.has_key?(m, :score_explanation)
      end)
    end

    test "rank produces deterministic ordering" do
      memories =
        for _i <- 1..10 do
          Map.put(@base_memory, :importance, :rand.uniform(100))
        end

      ranked1 = MemoryScoring.rank(memories, now: @now)
      ranked2 = MemoryScoring.rank(memories, now: @now)

      assert Enum.map(ranked1, & &1.score) == Enum.map(ranked2, & &1.score)
    end
  end

  describe "explanation integrity" do
    test "explanation contains all expected fields" do
      result = MemoryScoring.score(@base_memory, now: @now)

      expected = ~w(
        base_importance emotional_intensity category category_weight
        recency_factor recall_count recall_bonus unresolved unresolved_bonus
        decay_rate decay_penalty belief_relevance belief_boost
        relationship_relevance relationship_boost valence valence_boost
      )a

      Enum.each(expected, fn field ->
        assert Map.has_key?(result.explanation, field), "Missing explanation field: #{field}"
      end)
    end
  end
end
