defmodule SovereignSoulEngine.Souls.IntentEngineTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.IntentEngine

  @calm_emotional %{fear: 10, stress: 20, curiosity: 30}
  @calm_somatic %{hunger: 10, pain: 0, fatigue: 10, illness_severity: 0}

  test "high fear overrides everything else and flees" do
    emotional = %{@calm_emotional | fear: 80}
    result = IntentEngine.decide(emotional, @calm_somatic)
    assert result.intent == "flee"
  end

  test "high pain idles even when otherwise calm" do
    somatic = %{@calm_somatic | pain: 75}
    result = IntentEngine.decide(@calm_emotional, somatic)
    assert result.intent == "idle"
  end

  test "high illness idles" do
    somatic = %{@calm_somatic | illness_severity: 60}
    result = IntentEngine.decide(@calm_emotional, somatic)
    assert result.intent == "idle"
  end

  test "high fatigue idles" do
    somatic = %{@calm_somatic | fatigue: 90}
    result = IntentEngine.decide(@calm_emotional, somatic)
    assert result.intent == "idle"
  end

  test "high hunger seeks, and takes priority over generic distress" do
    somatic = %{@calm_somatic | hunger: 85}
    result = IntentEngine.decide(@calm_emotional, somatic)
    assert result.intent == "seek"
  end

  test "high stress without fear idles rather than wanders" do
    emotional = %{@calm_emotional | stress: 70}
    result = IntentEngine.decide(emotional, @calm_somatic)
    assert result.intent == "idle"
  end

  test "high curiosity and low stress wanders" do
    emotional = %{@calm_emotional | curiosity: 80, stress: 10}
    result = IntentEngine.decide(emotional, @calm_somatic)
    assert result.intent == "wander"
  end

  test "calm baseline state defaults to wander" do
    result = IntentEngine.decide(@calm_emotional, @calm_somatic)
    assert result.intent == "wander"
  end

  test "nil emotional and somatic state still resolves deterministically" do
    result = IntentEngine.decide(nil, nil)
    assert result.intent == "wander"
  end

  test "fear threat takes priority over hunger" do
    emotional = %{@calm_emotional | fear: 90}
    somatic = %{@calm_somatic | hunger: 95}
    result = IntentEngine.decide(emotional, somatic)
    assert result.intent == "flee"
  end

  test "every branch returns a non-empty reason" do
    for {emotional, somatic} <- [
          {%{@calm_emotional | fear: 90}, @calm_somatic},
          {@calm_emotional, %{@calm_somatic | pain: 90}},
          {@calm_emotional, %{@calm_somatic | hunger: 90}},
          {%{@calm_emotional | stress: 90}, @calm_somatic},
          {%{@calm_emotional | curiosity: 90, stress: 10}, @calm_somatic}
        ] do
      result = IntentEngine.decide(emotional, somatic)
      assert is_binary(result.reason) and result.reason != ""
    end
  end
end
