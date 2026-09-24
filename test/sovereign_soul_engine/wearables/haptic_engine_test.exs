defmodule SovereignSoulEngine.Wearables.HapticEngineTest do
  use SovereignSoulEngine.DataCase, async: true

  alias SovereignSoulEngine.Wearables.HapticEngine

  describe "compute/3" do
    test "returns panic_flutter when cortisol >= 75 or high stress and fear" do
      signal = HapticEngine.compute(%{stress: 85, fear: 65}, %{}, %{cortisol: 80})
      assert signal.pattern == :panic_flutter
      assert signal.priority == :high
      assert signal.bpm >= 140
      assert signal.intensity >= 90
    end

    test "returns calming_cadence when stress or cortisol are high but not in full panic" do
      signal = HapticEngine.compute(%{stress: 75, fear: 20}, %{}, %{cortisol: 40})
      assert signal.pattern == :calming_cadence
      assert signal.priority == :high
      assert signal.bpm == 65
    end

    test "returns intimacy_warmth when oxytocin or attachment is high with low stress" do
      signal = HapticEngine.compute(%{stress: 20, attachment: 80}, %{}, %{oxytocin: 70})
      assert signal.pattern == :intimacy_warmth
      assert signal.label == "Intimate Resonance"
      assert signal.priority == :normal
    end

    test "returns alert_ping on dopamine discovery spike" do
      signal =
        HapticEngine.compute(%{stress: 25}, %{}, %{dopamine: 85, cortisol: 20, oxytocin: 30})

      assert signal.pattern == :alert_ping
      assert signal.label == "Dopamine Spark"
    end

    test "returns exhausted rhythm on high fatigue" do
      signal = HapticEngine.compute(%{stress: 20}, %{fatigue: 85}, %{cortisol: 20})
      assert signal.pattern == :heartbeat
      assert signal.label == "Exhausted Rhythm"
      assert signal.bpm <= 60
    end

    test "returns resting heartbeat with default vitals" do
      signal = HapticEngine.compute(%{stress: 20}, %{fatigue: 15}, %{cortisol: 20})
      assert signal.pattern == :heartbeat
      assert signal.label == "Resting Heartbeat"
      assert signal.bpm >= 65 and signal.bpm <= 75
    end
  end

  describe "signal_for_event/2" do
    test "generates high priority panic flutter for PTSD flashback" do
      signal = HapticEngine.signal_for_event(:ptsd_flashback, bpm: 135)
      assert signal.pattern == :panic_flutter
      assert signal.bpm == 135
      assert signal.priority == :high
    end

    test "generates 4-7-8 breathing pulse for calming guidance" do
      signal = HapticEngine.signal_for_event(:calming_guidance)
      assert signal.pattern == :calming_cadence
      assert signal.priority == :high
      assert signal.bpm == 60
    end

    test "generates alert ping for proactive ping" do
      signal = HapticEngine.signal_for_event(:proactive_ping)
      assert signal.pattern == :alert_ping
    end
  end

  describe "dispatch/2" do
    test "broadcasts haptic signal on PubSub topics" do
      char_id = Ecto.UUID.generate()
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "character:#{char_id}:haptics")
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "wearables:haptics")

      signal = HapticEngine.signal_for_event(:intimacy_surge)
      assert {:ok, ^signal} = HapticEngine.dispatch(char_id, signal)

      assert_receive {:haptic_pulse, received_signal}
      assert received_signal.pattern == :intimacy_warmth

      assert_receive {:haptic_pulse, global_signal}
      assert global_signal.character_id == char_id
    end
  end
end
