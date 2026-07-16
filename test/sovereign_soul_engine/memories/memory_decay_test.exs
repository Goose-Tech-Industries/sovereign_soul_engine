defmodule SovereignSoulEngine.Memories.MemoryDecayTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Memories.MemoryDecay

  @now ~U[2026-07-14 12:00:00Z]

  @base_memory %{
    importance: 80,
    decay_rate: 1.0,
    category: :episodic,
    recall_count: 0,
    occurred_at: @now,
    last_recalled_at: nil
  }

  describe "basic decay" do
    test "no decay when no time has passed" do
      result = MemoryDecay.calculate(%{@base_memory | occurred_at: @now}, now: @now)

      assert result.original_importance == 80
      assert result.decayed_importance == 80
      assert result.decay_loss == 0
      assert result.decay_percentage == 100.0
    end

    test "importance decays over time" do
      old_time = DateTime.add(@now, -10, :day)
      result = MemoryDecay.calculate(%{@base_memory | occurred_at: old_time}, now: @now)

      assert result.decayed_importance < result.original_importance
      assert result.decay_loss > 0
      assert result.decay_percentage < 100.0
    end

    test "decay never reduces importance below 1" do
      ancient = DateTime.add(@now, -365 * 10, :day)

      result =
        MemoryDecay.calculate(%{@base_memory | occurred_at: ancient, importance: 5}, now: @now)

      assert result.decayed_importance >= 1
    end
  end

  describe "category decay resistance" do
    test "core memories decay very slowly" do
      old_time = DateTime.add(@now, -30, :day)

      episodic =
        MemoryDecay.calculate(%{@base_memory | category: :episodic, occurred_at: old_time},
          now: @now
        )

      core =
        MemoryDecay.calculate(%{@base_memory | category: :core, occurred_at: old_time}, now: @now)

      assert core.decayed_importance > episodic.decayed_importance
    end

    test "wound memories decay slower than episodic" do
      old_time = DateTime.add(@now, -30, :day)

      episodic =
        MemoryDecay.calculate(%{@base_memory | category: :episodic, occurred_at: old_time},
          now: @now
        )

      wound =
        MemoryDecay.calculate(%{@base_memory | category: :wound, occurred_at: old_time},
          now: @now
        )

      assert wound.decayed_importance > episodic.decayed_importance
    end

    test "belief memories decay slower than episodic" do
      old_time = DateTime.add(@now, -30, :day)

      episodic =
        MemoryDecay.calculate(%{@base_memory | category: :episodic, occurred_at: old_time},
          now: @now
        )

      belief =
        MemoryDecay.calculate(%{@base_memory | category: :belief, occurred_at: old_time},
          now: @now
        )

      assert belief.decayed_importance > episodic.decayed_importance
    end

    test "working memories decay faster than episodic" do
      old_time = DateTime.add(@now, -5, :day)

      episodic =
        MemoryDecay.calculate(%{@base_memory | category: :episodic, occurred_at: old_time},
          now: @now
        )

      working =
        MemoryDecay.calculate(%{@base_memory | category: :working, occurred_at: old_time},
          now: @now
        )

      assert working.decayed_importance < episodic.decayed_importance
    end
  end

  describe "recall protection" do
    test "frequently recalled memories decay slower" do
      old_time = DateTime.add(@now, -30, :day)

      never =
        MemoryDecay.calculate(%{@base_memory | recall_count: 0, occurred_at: old_time}, now: @now)

      often =
        MemoryDecay.calculate(%{@base_memory | recall_count: 10, occurred_at: old_time},
          now: @now
        )

      assert often.decayed_importance > never.decayed_importance
    end

    test "last_recalled_at affects decay window" do
      old_time = DateTime.add(@now, -60, :day)
      recent_recall = DateTime.add(@now, -1, :day)

      result =
        MemoryDecay.calculate(
          @base_memory
          |> Map.put(:occurred_at, old_time)
          |> Map.put(:last_recalled_at, recent_recall),
          now: @now
        )

      assert result.decayed_importance > 1
    end
  end

  describe "decay_rate impact" do
    test "higher decay_rate accelerates decay" do
      old_time = DateTime.add(@now, -10, :day)

      slow =
        MemoryDecay.calculate(%{@base_memory | decay_rate: 0.5, occurred_at: old_time}, now: @now)

      fast =
        MemoryDecay.calculate(%{@base_memory | decay_rate: 3.0, occurred_at: old_time}, now: @now)

      assert slow.decayed_importance > fast.decayed_importance
    end
  end

  describe "adjust_decay_rate_after_recall" do
    test "first recall reduces decay rate" do
      new_rate = MemoryDecay.adjust_decay_rate_after_recall(1.0, 1)

      assert new_rate < 1.0
      assert new_rate > 0.0
    end

    test "multiple recalls further reduce decay rate" do
      rate_after_1 = MemoryDecay.adjust_decay_rate_after_recall(1.0, 1)
      rate_after_5 = MemoryDecay.adjust_decay_rate_after_recall(1.0, 5)

      assert rate_after_5 < rate_after_1
    end

    test "decay rate never goes below 0.05" do
      new_rate = MemoryDecay.adjust_decay_rate_after_recall(0.1, 100)

      assert new_rate >= 0.05
    end

    test "zero recalls returns unchanged rate" do
      assert MemoryDecay.adjust_decay_rate_after_recall(1.0, 0) == 1.0
    end
  end

  describe "result structure" do
    test "returns all expected fields" do
      result = MemoryDecay.calculate(@base_memory, now: @now)

      assert Map.has_key?(result, :original_importance)
      assert Map.has_key?(result, :decayed_importance)
      assert Map.has_key?(result, :decay_loss)
      assert Map.has_key?(result, :decay_percentage)
      assert Map.has_key?(result, :effective_decay_rate)
    end
  end
end
