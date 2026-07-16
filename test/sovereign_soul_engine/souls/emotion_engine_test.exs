defmodule SovereignSoulEngine.Souls.EmotionEngineTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.EmotionEngine

  @default_state %{
    anger: 10,
    fear: 5,
    stress: 20,
    gratitude: 5,
    confidence: 50,
    sadness: 10,
    curiosity: 50,
    attachment: 10
  }

  describe "positive changes" do
    test "ally_saved_me increases gratitude, confidence, attachment and decreases fear, stress, sadness" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :ally_saved_me)

      assert deltas.gratitude > 0
      assert deltas.confidence > 0
      assert deltas.attachment > 0
      assert deltas.fear < 0
      assert deltas.stress < 0
      assert deltas.sadness < 0

      assert updated.gratitude > @default_state.gratitude
      assert updated.confidence > @default_state.confidence
      assert updated.attachment > @default_state.attachment
    end

    test "healed_me increases gratitude, attachment and reduces fear, stress" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :healed_me)

      assert deltas.gratitude > 0
      assert deltas.attachment > 0
      assert deltas.fear < 0
      assert deltas.stress < 0

      assert updated.gratitude > @default_state.gratitude
      assert updated.attachment > @default_state.attachment
    end

    test "trained_me increases confidence, gratitude, curiosity" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :trained_me)

      assert deltas.confidence > 0
      assert deltas.gratitude > 0
      assert deltas.curiosity > 0

      assert updated.confidence > @default_state.confidence
      assert updated.gratitude > @default_state.gratitude
    end

    test "praised_me increases confidence, gratitude and reduces sadness, stress" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :praised_me)

      assert deltas.confidence > 0
      assert deltas.gratitude > 0
      assert deltas.sadness < 0
      assert deltas.anger < 0

      assert updated.confidence > @default_state.confidence
    end

    test "shared_secret increases attachment, gratitude, curiosity" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :shared_secret)

      assert deltas.attachment > 0
      assert deltas.gratitude > 0
      assert deltas.curiosity > 0

      assert updated.attachment > @default_state.attachment
    end

    test "protected_me increases gratitude, attachment, confidence and reduces fear, stress" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :protected_me)

      assert deltas.gratitude > 0
      assert deltas.attachment > 0
      assert deltas.confidence > 0
      assert deltas.fear < 0
      assert deltas.stress < 0

      assert updated.gratitude > @default_state.gratitude
    end
  end

  describe "negative changes" do
    test "betrayed_me increases anger, fear, stress, sadness and decreases gratitude, confidence" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :betrayed_me)

      assert deltas.anger > 0
      assert deltas.fear > 0
      assert deltas.stress > 0
      assert deltas.sadness > 0
      assert deltas.gratitude < 0
      assert deltas.confidence < 0

      assert updated.anger > @default_state.anger
      assert updated.sadness > @default_state.sadness
    end

    test "attacked_me increases anger, fear, stress and decreases confidence" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :attacked_me)

      assert deltas.anger > 0
      assert deltas.fear > 0
      assert deltas.stress > 0
      assert deltas.confidence < 0

      assert updated.anger > @default_state.anger
      assert updated.fear > @default_state.fear
    end

    test "insulted_me increases anger, sadness, stress and decreases confidence" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :insulted_me)

      assert deltas.anger > 0
      assert deltas.sadness > 0
      assert deltas.stress > 0
      assert deltas.confidence < 0

      assert updated.anger > @default_state.anger
    end

    test "threatened_me increases fear, anger, stress and decreases confidence" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :threatened_me)

      assert deltas.fear > 0
      assert deltas.anger > 0
      assert deltas.stress > 0
      assert deltas.confidence < 0

      assert updated.fear > @default_state.fear
    end

    test "abandoned_me increases sadness, anger, fear and decreases confidence, attachment" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :abandoned_me)

      assert deltas.sadness > 0
      assert deltas.anger > 0
      assert deltas.fear > 0
      assert deltas.confidence < 0
      assert deltas.attachment < 0

      assert updated.sadness > @default_state.sadness
    end

    test "lied_to_me increases anger, sadness and decreases confidence, gratitude" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :lied_to_me)

      assert deltas.anger > 0
      assert deltas.sadness > 0
      assert deltas.confidence < 0
      assert deltas.gratitude < 0

      assert updated.anger > @default_state.anger
    end
  end

  describe "minimum clamping" do
    test "emotions do not go below 0" do
      low_state = %{@default_state | anger: 0, fear: 0, gratitude: 0}

      {:ok, updated, _deltas} = EmotionEngine.process_event(low_state, :insulted_me)

      assert updated.anger >= 0
      assert updated.fear >= 0
      assert updated.stress >= 0

      Enum.each(updated, fn {_k, v} -> assert v >= 0 end)
    end

    test "gratitude does not go negative from betrayal at low starting value" do
      {:ok, updated, _deltas} = EmotionEngine.process_event(@default_state, :betrayed_me)

      assert updated.gratitude >= 0
    end

    test "confidence does not go negative from repeated harsh events" do
      low_conf = %{@default_state | confidence: 2}

      {:ok, updated, _deltas} =
        EmotionEngine.process_event(low_conf, :betrayed_me, intensity: 100)

      assert updated.confidence >= 0
    end
  end

  describe "maximum clamping" do
    test "emotions do not exceed 100" do
      high_state = %{@default_state | anger: 95, gratitude: 95}

      {:ok, updated, _deltas} =
        EmotionEngine.process_event(high_state, :betrayed_me, intensity: 100)

      assert updated.anger <= 100
      assert updated.gratitude <= 100

      Enum.each(updated, fn {_k, v} -> assert v <= 100 end)
    end

    test "gratitude clamped at 100 for repeated positive events" do
      high_grat = %{@default_state | gratitude: 98}

      {:ok, updated, _deltas} =
        EmotionEngine.process_event(high_grat, :ally_saved_me, intensity: 100)

      assert updated.gratitude <= 100
    end
  end

  describe "personality modifiers" do
    test "anger_amplified personality increases anger deltas" do
      modifiers = %{anger: 2.0}

      {:ok, _updated, deltas_base} = EmotionEngine.process_event(@default_state, :insulted_me)

      {:ok, _updated, deltas_mod} =
        EmotionEngine.process_event(@default_state, :insulted_me,
          personality_modifiers: modifiers
        )

      assert deltas_mod.anger > deltas_base.anger
      assert_in_delta deltas_mod.anger, deltas_base.anger * 2.0, 1.0
    end

    test "dampened_fear personality reduces fear deltas" do
      modifiers = %{fear: 0.5}

      {:ok, _updated, deltas_base} = EmotionEngine.process_event(@default_state, :threatened_me)

      {:ok, _updated, deltas_mod} =
        EmotionEngine.process_event(@default_state, :threatened_me,
          personality_modifiers: modifiers
        )

      assert abs(deltas_mod.fear) < abs(deltas_base.fear)
    end

    test "resilient personality reduces negative emotional impacts" do
      modifiers = %{sadness: 0.3, anger: 0.3, fear: 0.3}

      {:ok, _updated, deltas_base} = EmotionEngine.process_event(@default_state, :betrayed_me)

      {:ok, _updated, deltas_mod} =
        EmotionEngine.process_event(@default_state, :betrayed_me,
          personality_modifiers: modifiers
        )

      assert deltas_mod.sadness < deltas_base.sadness
      assert deltas_mod.anger < deltas_base.anger
    end
  end

  describe "diminishing returns from repetition" do
    test "first event has full impact" do
      {:ok, _updated, deltas_first} =
        EmotionEngine.process_event(@default_state, :praised_me, repetition_count: 0)

      assert deltas_first.confidence > 0
    end

    test "fifth repetition has reduced impact" do
      {:ok, _updated, deltas_first} =
        EmotionEngine.process_event(@default_state, :praised_me, repetition_count: 0)

      {:ok, _updated, deltas_fifth} =
        EmotionEngine.process_event(@default_state, :praised_me, repetition_count: 5)

      assert abs(deltas_fifth.confidence) < abs(deltas_first.confidence)
    end

    test "diminishing returns are proportional" do
      {:ok, _updated, deltas_once} =
        EmotionEngine.process_event(@default_state, :ally_saved_me, repetition_count: 1)

      {:ok, _updated, deltas_twice} =
        EmotionEngine.process_event(@default_state, :ally_saved_me, repetition_count: 2)

      assert abs(deltas_twice.gratitude) < abs(deltas_once.gratitude)
    end
  end

  describe "existing wound amplification" do
    test "negative events hit harder when wounds exist" do
      {:ok, _updated, deltas_no_wound} =
        EmotionEngine.process_event(@default_state, :betrayed_me, existing_wounds: 0)

      {:ok, _updated, deltas_wounded} =
        EmotionEngine.process_event(@default_state, :betrayed_me, existing_wounds: 80)

      assert deltas_wounded.anger > deltas_no_wound.anger
      assert deltas_wounded.sadness > deltas_no_wound.sadness
    end

    test "positive events are not amplified by wounds" do
      {:ok, _updated, deltas_no_wound} =
        EmotionEngine.process_event(@default_state, :protected_me, existing_wounds: 0)

      {:ok, _updated, deltas_wounded} =
        EmotionEngine.process_event(@default_state, :protected_me, existing_wounds: 80)

      assert_in_delta deltas_wounded.gratitude, deltas_no_wound.gratitude, 0.1
    end
  end

  describe "event intensity" do
    test "high intensity produces larger changes" do
      {:ok, _updated, deltas_low} =
        EmotionEngine.process_event(@default_state, :insulted_me, intensity: 25)

      {:ok, _updated, deltas_high} =
        EmotionEngine.process_event(@default_state, :insulted_me, intensity: 100)

      assert deltas_high.anger > deltas_low.anger
    end

    test "zero intensity produces no changes beyond rounding" do
      {:ok, updated, _deltas} =
        EmotionEngine.process_event(@default_state, :betrayed_me, intensity: 0)

      assert updated.anger == @default_state.anger
      assert updated.fear == @default_state.fear
    end
  end

  describe "invalid inputs" do
    test "invalid event type returns error" do
      assert {:error, reason} = EmotionEngine.process_event(@default_state, :dance_party)
      assert reason =~ "unknown event_type"
    end

    test "negative intensity returns error" do
      assert {:error, reason} =
               EmotionEngine.process_event(@default_state, :insulted_me, intensity: -5)

      assert reason =~ "intensity"
    end

    test "intensity over 100 returns error" do
      assert {:error, reason} =
               EmotionEngine.process_event(@default_state, :insulted_me, intensity: 150)

      assert reason =~ "intensity"
    end
  end

  describe "state integrity" do
    test "all dimension keys present in output" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :ally_saved_me)

      expected = ~w(anger fear stress gratitude confidence sadness curiosity attachment)a

      Enum.each(expected, fn dim ->
        assert Map.has_key?(updated, dim)
        assert Map.has_key?(deltas, dim)
      end)
    end

    test "non-emotion keys in input are excluded from output" do
      state_with_extras = Map.put(@default_state, :unrelated, 999)

      {:ok, updated, _deltas} = EmotionEngine.process_event(state_with_extras, :praised_me)

      refute Map.has_key?(updated, :unrelated)
    end

    test "applied deltas match the difference between updated and original" do
      {:ok, updated, deltas} = EmotionEngine.process_event(@default_state, :betrayed_me)

      Enum.each(updated, fn {dim, val} ->
        assert val == @default_state[dim] + deltas[dim]
      end)
    end
  end
end
