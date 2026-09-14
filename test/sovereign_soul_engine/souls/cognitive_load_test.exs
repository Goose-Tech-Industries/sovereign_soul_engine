defmodule SovereignSoulEngine.Souls.CognitiveLoadTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.CognitiveLoad
  alias SovereignSoulEngine.Actions.ActionPolicy

  describe "CognitiveLoad & Stress Biorhythms" do
    test "computes cognitive load score and stressors correctly" do
      emotional = %{stress: 70, rumination_intensity: 60, rumination_subject: "betrayal"}
      somatic = %{pain: 60, fatigue: 40}
      grief_arcs = [%{intensity: 75}]
      active_goals = [%{blocker: "lost key", priority: 80}]

      {score, stressors} =
        CognitiveLoad.compute(emotional, somatic, grief_arcs, active_goals)

      assert score >= 50
      assert length(stressors) >= 4
    end

    test "stress_biorhythm_directives generates prompt compression and thought fragmentation over 75" do
      emotional_high = %{stress: 82, fear: 60}

      directives = CognitiveLoad.stress_biorhythm_directives(emotional_high)
      assert directives =~ "CRITICAL STRESS BIORHYTHM ACTIVE"
      assert directives =~ "PROMPT COMPRESSION"
      assert directives =~ "PRIVATE THOUGHT FRAGMENTATION"
      assert directives =~ "1 or 2 short"

      emotional_calm = %{stress: 30, fear: 20}
      assert CognitiveLoad.stress_biorhythm_directives(emotional_calm) == nil
    end

    test "ActionPolicy transforms complex actions to flee under acute fear (>= 75)" do
      scene_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]
      target_id = Enum.at(scene_ids, 1)

      assert {:ok, :transformed, reason, :flee} =
               ActionPolicy.validate(
                 proposed_action: :bargain,
                 character_status: :active,
                 target_character_id: target_id,
                 scene_participant_ids: scene_ids,
                 emotional_state: %{fear: 80}
               )

      assert reason =~ "fear"
      assert reason =~ "flee"

      assert {:ok, :transformed, _reason, :flee} =
               ActionPolicy.validate(
                 proposed_action: :assist,
                 character_status: :active,
                 target_character_id: target_id,
                 scene_participant_ids: scene_ids,
                 emotional_state: %{fear: 78}
               )
    end

    test "ActionPolicy transforms delicate actions to refuse under acute stress (>= 85)" do
      scene_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]
      target_id = Enum.at(scene_ids, 1)

      assert {:ok, :transformed, reason, :refuse} =
               ActionPolicy.validate(
                 proposed_action: :bargain,
                 character_status: :active,
                 target_character_id: target_id,
                 scene_participant_ids: scene_ids,
                 emotional_state: %{stress: 90, fear: 40}
               )

      assert reason =~ "stress"
      assert reason =~ "refuse"
    end
  end
end
