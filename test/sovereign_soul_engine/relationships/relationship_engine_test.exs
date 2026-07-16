defmodule SovereignSoulEngine.Relationships.RelationshipEngineTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Relationships.RelationshipEngine

  @default_state %{
    affinity: 10,
    trust: 25,
    respect: 45,
    fear: 5,
    anger: 20,
    gratitude: 10,
    debt: 0,
    softening: 15,
    hardening: 35,
    wound: 20
  }

  describe "event rules — betrayal" do
    test "betrayed_me decreases trust, respect, affinity, gratitude, softening" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :betrayed_me)

      assert deltas.trust < 0
      assert deltas.respect < 0
      assert deltas.affinity < 0
      assert deltas.gratitude < 0
      assert deltas.softening < 0

      assert updated.trust < @default_state.trust
      assert updated.respect < @default_state.respect
      assert updated.affinity < @default_state.affinity
    end

    test "betrayed_me increases anger, hardening, wound, fear" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :betrayed_me)

      assert deltas.anger > 0
      assert deltas.hardening > 0
      assert deltas.wound > 0
      assert deltas.fear > 0

      assert updated.anger > @default_state.anger
      assert updated.hardening > @default_state.hardening
      assert updated.wound > @default_state.wound
    end
  end

  describe "event rules — protection" do
    test "ally_saved_me increases trust, respect, gratitude, softening, affinity" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :ally_saved_me)

      assert deltas.trust > 0
      assert deltas.respect > 0
      assert deltas.gratitude > 0
      assert deltas.softening > 0
      assert deltas.affinity > 0

      assert updated.trust > @default_state.trust
      assert updated.gratitude > @default_state.gratitude
    end

    test "ally_saved_me decreases anger and hardening" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :ally_saved_me)

      assert deltas.anger < 0
      assert deltas.hardening < 0

      assert updated.anger < @default_state.anger
      assert updated.hardening < @default_state.hardening
    end

    test "protected_me increases trust, respect, gratitude, softening, affinity" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :protected_me)

      assert deltas.trust > 0
      assert deltas.respect > 0
      assert deltas.gratitude > 0
      assert deltas.softening > 0
      assert deltas.affinity > 0
      assert deltas.fear < 0

      assert updated.trust > @default_state.trust
    end
  end

  describe "event rules — praise and insults" do
    test "praised_me increases affinity, respect, trust, gratitude, softening" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :praised_me)

      assert deltas.affinity > 0
      assert deltas.respect > 0
      assert deltas.trust > 0
      assert deltas.gratitude > 0
      assert deltas.softening > 0
      assert deltas.anger < 0

      assert updated.affinity > @default_state.affinity
    end

    test "insulted_me increases anger, hardening and decreases trust, respect, affinity" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :insulted_me)

      assert deltas.anger > 0
      assert deltas.hardening > 0
      assert deltas.trust < 0
      assert deltas.respect < 0
      assert deltas.affinity < 0

      assert updated.anger > @default_state.anger
      assert updated.affinity < @default_state.affinity
    end
  end

  describe "event rules — apologies" do
    test "apologized_to_me decreases anger, hardening, wound and increases trust, respect, affinity" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :apologized_to_me)

      assert deltas.anger < 0
      assert deltas.hardening < 0
      assert deltas.wound < 0
      assert deltas.trust > 0
      assert deltas.respect > 0
      assert deltas.affinity > 0
      assert deltas.gratitude > 0

      assert updated.anger < @default_state.anger
      assert updated.trust > @default_state.trust
    end
  end

  describe "event rules — abandonment" do
    test "abandoned_me severely damages trust, affinity, respect" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :abandoned_me)

      assert deltas.trust < 0
      assert deltas.affinity < 0
      assert deltas.respect < 0
      assert deltas.gratitude < 0
      assert deltas.softening < 0

      assert updated.anger > @default_state.anger
      assert updated.hardening > @default_state.hardening
      assert updated.wound > @default_state.wound
    end
  end

  describe "event rules — shared secret and lies" do
    test "shared_secret increases trust, affinity, gratitude, softening" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :shared_secret)

      assert deltas.trust > 0
      assert deltas.affinity > 0
      assert deltas.gratitude > 0
      assert deltas.softening > 0

      assert updated.trust > @default_state.trust
    end

    test "lied_to_me decreases trust, respect, affinity and increases anger, hardening, wound" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :lied_to_me)

      assert deltas.trust < 0
      assert deltas.respect < 0
      assert deltas.affinity < 0
      assert deltas.anger > 0
      assert deltas.hardening > 0
      assert deltas.wound > 0

      assert updated.trust < @default_state.trust
    end
  end

  describe "minimum clamping" do
    test "trust, respect, fear, etc. do not go below 0" do
      low_state = %{@default_state | trust: 0, respect: 0, gratitude: 0}

      {:ok, updated, _deltas} =
        RelationshipEngine.process_event(low_state, :betrayed_me, intensity: 100)

      assert updated.trust >= 0
      assert updated.respect >= 0
      assert updated.gratitude >= 0
      assert updated.fear >= 0
    end

    test "affinity does not go below -100" do
      low_aff = %{@default_state | affinity: -95}

      {:ok, updated, _deltas} =
        RelationshipEngine.process_event(low_aff, :betrayed_me, intensity: 100)

      assert updated.affinity >= -100
    end

    test "anger does not go below 0 on apology" do
      low_anger = %{@default_state | anger: 2}

      {:ok, updated, _deltas} =
        RelationshipEngine.process_event(low_anger, :apologized_to_me, intensity: 100)

      assert updated.anger >= 0
    end
  end

  describe "maximum clamping" do
    test "trust, respect, anger etc. do not exceed 100" do
      high_state = %{@default_state | trust: 95, respect: 98, anger: 95}

      {:ok, updated, _deltas} =
        RelationshipEngine.process_event(high_state, :ally_saved_me, intensity: 100)

      assert updated.trust <= 100
      assert updated.respect <= 100
      assert updated.anger <= 100
    end

    test "affinity does not exceed 100" do
      high_aff = %{@default_state | affinity: 95}

      {:ok, updated, _deltas} =
        RelationshipEngine.process_event(high_aff, :ally_saved_me, intensity: 100)

      assert updated.affinity <= 100
    end

    test "wound does not exceed 100" do
      high_wound = %{@default_state | wound: 98}

      {:ok, updated, _deltas} =
        RelationshipEngine.process_event(high_wound, :betrayed_me, intensity: 100)

      assert updated.wound <= 100
    end

    test "hardening does not exceed 100" do
      high_hard = %{@default_state | hardening: 95}

      {:ok, updated, _deltas} =
        RelationshipEngine.process_event(high_hard, :betrayed_me, intensity: 100)

      assert updated.hardening <= 100
    end
  end

  describe "personality modifiers" do
    test "forgiving personality dampens anger and hardening" do
      modifiers = %{anger: 0.3, hardening: 0.3}

      {:ok, _updated, deltas_base} =
        RelationshipEngine.process_event(@default_state, :betrayed_me)

      {:ok, _updated, deltas_mod} =
        RelationshipEngine.process_event(@default_state, :betrayed_me,
          personality_modifiers: modifiers
        )

      assert deltas_mod.anger < deltas_base.anger
      assert deltas_mod.hardening < deltas_base.hardening
    end

    test "suspicious personality amplifies fear and hardening" do
      modifiers = %{fear: 2.0, hardening: 1.5}

      {:ok, _updated, deltas_base} =
        RelationshipEngine.process_event(@default_state, :threatened_me)

      {:ok, _updated, deltas_mod} =
        RelationshipEngine.process_event(@default_state, :threatened_me,
          personality_modifiers: modifiers
        )

      assert deltas_mod.fear > deltas_base.fear
      assert deltas_mod.hardening > deltas_base.hardening
    end

    test "grateful personality amplifies positive relationship changes" do
      modifiers = %{gratitude: 2.0, trust: 1.5}

      {:ok, _updated, deltas_base} =
        RelationshipEngine.process_event(@default_state, :ally_saved_me)

      {:ok, _updated, deltas_mod} =
        RelationshipEngine.process_event(@default_state, :ally_saved_me,
          personality_modifiers: modifiers
        )

      assert deltas_mod.gratitude > deltas_base.gratitude
      assert deltas_mod.trust > deltas_base.trust
    end
  end

  describe "diminishing returns from repetition" do
    test "repeated praise has diminishing effect" do
      {:ok, _updated, deltas_first} =
        RelationshipEngine.process_event(@default_state, :praised_me, repetition_count: 0)

      {:ok, _updated, deltas_tenth} =
        RelationshipEngine.process_event(@default_state, :praised_me, repetition_count: 10)

      assert abs(deltas_tenth.affinity) < abs(deltas_first.affinity)
    end

    test "repeated betrayals still have some effect but diminished" do
      {:ok, _updated, deltas_first} =
        RelationshipEngine.process_event(@default_state, :betrayed_me, repetition_count: 0)

      {:ok, _updated, deltas_fifth} =
        RelationshipEngine.process_event(@default_state, :betrayed_me, repetition_count: 5)

      assert abs(deltas_fifth.trust) < abs(deltas_first.trust)
      assert deltas_fifth.anger > 0
    end
  end

  describe "existing wound amplification" do
    test "negative deltas are amplified by existing wounds" do
      {:ok, _updated, deltas_no_wound} =
        RelationshipEngine.process_event(@default_state, :betrayed_me, existing_wounds: 0)

      {:ok, _updated, deltas_wounded} =
        RelationshipEngine.process_event(@default_state, :betrayed_me, existing_wounds: 80)

      assert deltas_wounded.anger > deltas_no_wound.anger
      assert deltas_wounded.wound > deltas_no_wound.wound
    end

    test "positive deltas are not amplified by wounds" do
      {:ok, _updated, deltas_no_wound} =
        RelationshipEngine.process_event(@default_state, :ally_saved_me, existing_wounds: 0)

      {:ok, _updated, deltas_wounded} =
        RelationshipEngine.process_event(@default_state, :ally_saved_me, existing_wounds: 80)

      assert_in_delta deltas_wounded.trust, deltas_no_wound.trust, 0.1
      assert_in_delta deltas_wounded.gratitude, deltas_no_wound.gratitude, 0.1
    end
  end

  describe "event intensity" do
    test "high intensity produces larger relationship deltas" do
      {:ok, _updated, deltas_low} =
        RelationshipEngine.process_event(@default_state, :insulted_me, intensity: 10)

      {:ok, _updated, deltas_high} =
        RelationshipEngine.process_event(@default_state, :insulted_me, intensity: 90)

      assert abs(deltas_high.anger) > abs(deltas_low.anger)
      assert abs(deltas_high.affinity) > abs(deltas_low.affinity)
    end

    test "zero intensity produces no relationship changes" do
      {:ok, updated, _deltas} =
        RelationshipEngine.process_event(@default_state, :betrayed_me, intensity: 0)

      assert updated.trust == @default_state.trust
      assert updated.anger == @default_state.anger
      assert updated.affinity == @default_state.affinity
    end
  end

  describe "multiple sequential events" do
    test "chain of events produces reasonable cumulative state" do
      {:ok, after_betrayal, _} =
        RelationshipEngine.process_event(@default_state, :betrayed_me)

      assert after_betrayal.trust < @default_state.trust
      assert after_betrayal.wound > @default_state.wound

      {:ok, after_apology, _} =
        RelationshipEngine.process_event(after_betrayal, :apologized_to_me)

      assert after_apology.trust > after_betrayal.trust
      assert after_apology.anger < after_betrayal.anger

      {:ok, after_protection, _} =
        RelationshipEngine.process_event(after_apology, :protected_me)

      assert after_protection.gratitude > after_apology.gratitude
      assert after_protection.trust > after_apology.trust
    end

    test "repeated positive events after betrayal can rebuild trust" do
      {:ok, damaged, _} =
        RelationshipEngine.process_event(@default_state, :betrayed_me, intensity: 100)

      {:ok, r1, _} =
        RelationshipEngine.process_event(damaged, :apologized_to_me, intensity: 100)

      {:ok, r2, _} = RelationshipEngine.process_event(r1, :protected_me, intensity: 100)

      {:ok, r3, _} = RelationshipEngine.process_event(r2, :ally_saved_me, intensity: 100)

      assert r3.trust > damaged.trust
      assert r3.affinity > damaged.affinity
    end
  end

  describe "directional relationships" do
    test "event affects only the direction from source toward target" do
      base_dims = ~w(affinity trust respect fear anger gratitude debt softening hardening wound)a

      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :betrayed_me)

      Enum.each(base_dims, fn dim ->
        assert Map.has_key?(updated, dim)
        assert Map.has_key?(deltas, dim)
      end)
    end
  end

  describe "invalid inputs" do
    test "invalid event type returns error" do
      assert {:error, reason} =
               RelationshipEngine.process_event(@default_state, :bake_cake)

      assert reason =~ "unknown event_type"
    end

    test "negative intensity returns error" do
      assert {:error, reason} =
               RelationshipEngine.process_event(@default_state, :insulted_me, intensity: -10)

      assert reason =~ "intensity"
    end

    test "intensity over 100 returns error" do
      assert {:error, reason} =
               RelationshipEngine.process_event(@default_state, :insulted_me, intensity: 200)

      assert reason =~ "intensity"
    end
  end

  describe "state integrity" do
    test "all dimension keys present in output" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :ally_saved_me)

      expected = ~w(affinity trust respect fear anger gratitude debt softening hardening wound)a

      Enum.each(expected, fn dim ->
        assert Map.has_key?(updated, dim)
        assert Map.has_key?(deltas, dim)
        assert is_integer(updated[dim])
        assert is_integer(deltas[dim])
      end)
    end

    test "unknown keys in input are excluded from output" do
      state_with_extras = Map.put(@default_state, :unrelated_dim, 999)

      {:ok, updated, _deltas} =
        RelationshipEngine.process_event(state_with_extras, :praised_me)

      refute Map.has_key?(updated, :unrelated_dim)
    end

    test "applied deltas match the difference between updated and original" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :betrayed_me)

      Enum.each(updated, fn {dim, val} ->
        assert val == @default_state[dim] + deltas[dim]
      end)
    end

    test "healed_me increases trust, respect, gratitude, softening, affinity" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :healed_me)

      assert deltas.trust > 0
      assert deltas.respect > 0
      assert deltas.gratitude > 0
      assert deltas.softening > 0
      assert deltas.affinity > 0
      assert deltas.anger < 0

      assert updated.trust > @default_state.trust
    end

    test "trained_me increases respect, trust, gratitude, affinity, debt" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :trained_me)

      assert deltas.respect > 0
      assert deltas.trust > 0
      assert deltas.gratitude > 0
      assert deltas.affinity > 0
      assert deltas.debt > 0

      assert updated.respect > @default_state.respect
    end

    test "gave_item increases gratitude, affinity, debt" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :gave_item)

      assert deltas.gratitude > 0
      assert deltas.affinity > 0
      assert deltas.debt > 0

      assert updated.gratitude > @default_state.gratitude
    end

    test "threatened_me increases fear, anger, hardening and decreases trust, affinity" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :threatened_me)

      assert deltas.fear > 0
      assert deltas.anger > 0
      assert deltas.hardening > 0
      assert deltas.trust < 0
      assert deltas.affinity < 0

      assert updated.fear > @default_state.fear
    end

    test "attacked_me increases anger, fear, hardening and decreases trust, respect, affinity" do
      {:ok, updated, deltas} =
        RelationshipEngine.process_event(@default_state, :attacked_me)

      assert deltas.anger > 0
      assert deltas.fear > 0
      assert deltas.hardening > 0
      assert deltas.trust < 0
      assert deltas.respect < 0
      assert deltas.affinity < 0

      assert updated.anger > @default_state.anger
    end
  end
end
