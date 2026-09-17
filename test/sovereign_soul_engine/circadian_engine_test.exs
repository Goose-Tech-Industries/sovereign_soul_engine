defmodule SovereignSoulEngine.Souls.CircadianEngineTest do
  use SovereignSoulEngine.DataCase, async: true

  alias SovereignSoulEngine.Souls.CircadianEngine

  describe "current_state/2" do
    test "evaluates night_owl chronotype accurately during nighttime hours" do
      # 02:00 AM UTC
      {:ok, night_time, _} = DateTime.from_iso8601("2026-09-16T02:00:00Z")
      settings = %{"chronotype" => "night_owl", "circadian_enabled" => true}

      state = CircadianEngine.current_state(settings, night_time)

      assert state.state == :night_focus
      assert state.chronotype == :night_owl
      assert state.alertness >= 85.0
      assert state.melatonin <= 15.0
      assert state.is_sleeping == false
    end

    test "evaluates early_bird chronotype during 02:00 AM UTC as deep sleep" do
      {:ok, night_time, _} = DateTime.from_iso8601("2026-09-16T02:00:00Z")
      settings = %{"chronotype" => "early_bird", "circadian_enabled" => true}

      state = CircadianEngine.current_state(settings, night_time)

      assert state.state == :deep_sleep
      assert state.chronotype == :early_bird
      assert state.alertness <= 15.0
      assert state.melatonin >= 85.0
      assert state.is_sleeping == true
    end

    test "evaluates balanced chronotype during midday as wide awake" do
      {:ok, day_time, _} = DateTime.from_iso8601("2026-09-16T14:00:00Z")
      settings = %{"chronotype" => "balanced", "circadian_enabled" => true}

      state = CircadianEngine.current_state(settings, day_time)

      assert state.state == :wide_awake
      assert state.is_sleeping == false
    end

    test "returns wide awake when circadian_enabled is false" do
      {:ok, night_time, _} = DateTime.from_iso8601("2026-09-16T03:00:00Z")
      settings = %{"chronotype" => "early_bird", "circadian_enabled" => false}

      state = CircadianEngine.current_state(settings, night_time)

      assert state.state == :wide_awake
      assert state.is_sleeping == false
    end
  end

  describe "apply_modifiers/2" do
    test "modulates neurochemistry for night-owl focus" do
      base_neurochem = %{
        valence: 50.0,
        arousal: 50.0,
        cortisol: 20.0,
        dopamine: 50.0,
        serotonin: 50.0
      }

      circadian = %{
        state: :night_focus,
        alertness: 90.0,
        melatonin: 12.0
      }

      modified = CircadianEngine.apply_modifiers(base_neurochem, circadian)

      assert modified.dopamine > base_neurochem.dopamine
      assert modified.serotonin > base_neurochem.serotonin
    end

    test "suppresses arousal during deep sleep" do
      base_neurochem = %{
        valence: 50.0,
        arousal: 60.0,
        cortisol: 20.0,
        dopamine: 50.0,
        serotonin: 50.0
      }

      circadian = %{
        state: :deep_sleep,
        alertness: 10.0,
        melatonin: 92.0
      }

      modified = CircadianEngine.apply_modifiers(base_neurochem, circadian)

      assert modified.arousal <= 20.0
    end
  end

  describe "prompt_directive/1" do
    test "generates night-owl late-night directive" do
      directive = CircadianEngine.prompt_directive(%{state: :night_focus})
      assert directive =~ "NIGHT-OWL COGNITIVE FLOW"
      assert directive =~ "nocturnal thinkers"
    end

    test "generates deep sleep groggy interrupt directive" do
      directive = CircadianEngine.prompt_directive(%{state: :deep_sleep})
      assert directive =~ "DEEP SLEEP / GROGGY INTERRUPT"
    end
  end
end
