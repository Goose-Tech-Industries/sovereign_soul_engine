defmodule SovereignSoulEngine.Souls.PTSDFlashbackTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.PTSDFlashback
  alias SovereignSoulEngine.Memories.Memory

  defp traumatic_memory(overrides \\ %{}) do
    struct!(
      Memory,
      Map.merge(
        %{
          status: "active",
          valence: -0.8,
          emotional_intensity: 80,
          summary: "watched his brother drown in the flood",
          tags: ["trauma"]
        },
        overrides
      )
    )
  end

  describe "detect_flashback/3" do
    test "returns no flashback with no memories" do
      f = PTSDFlashback.detect_flashback([])

      refute f.triggered?
      assert f.memory == nil
    end

    test "returns no flashback for non-traumatic memories" do
      benign = traumatic_memory(%{valence: 0.5, emotional_intensity: 20})

      f = PTSDFlashback.detect_flashback([benign], %{}, "the weather is nice")

      refute f.triggered?
    end

    test "returns no flashback when no cue matches" do
      f = PTSDFlashback.detect_flashback([traumatic_memory()], %{}, "we had lunch at the cafe")

      refute f.triggered?
    end

    test "triggers on a matching summary word in dialogue" do
      f = PTSDFlashback.detect_flashback([traumatic_memory()], %{}, "I nearly drowned last night")

      assert f.triggered?
      assert f.trigger_cue == "drown"
      assert f.heart_rate_surge == 80
      assert f.stress_surge == 56
      assert f.prompt_directive =~ "FLASHBACK"
    end

    test "triggers on a universal trauma cue" do
      f = PTSDFlashback.detect_flashback([traumatic_memory()], %{}, "there was blood everywhere")

      assert f.triggered?
      assert f.trigger_cue == "blood"
    end

    test "matches cues in scene context" do
      f =
        PTSDFlashback.detect_flashback(
          [traumatic_memory()],
          %{"narrative" => "the river rose and they drowned"},
          ""
        )

      assert f.triggered?
    end
  end
end
