defmodule SovereignSoulEngine.Souls.PsychologicalEnginesTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Souls.{
    NeurosisState,
    PTSDFlashback,
    DefenseMechanisms,
    Neurochemistry
  }
  alias SovereignSoulEngine.Memories.{Memory, DreamResidue, DreamLoop}
  alias SovereignSoulEngine.{Characters, Souls}

  describe "NeurosisState Engine" do
    test "returns :normal baseline when emotions and somatic stress are balanced" do
      state = NeurosisState.evaluate(%{stress: 20, fear: 10, sadness: 10, shame: 5}, %{fatigue: 20, pain: 0})
      assert state.state == :normal
      assert state.intensity == 0
      assert state.symptoms == []
      assert state.prompt_directive == ""
    end

    test "triggers :panic_spiral under phobia trigger and acute terror" do
      state = NeurosisState.evaluate(%{stress: 70, fear: 80}, %{fatigue: 30}, 0, true)
      assert state.state == :panic_spiral
      assert state.intensity >= 80
      assert Enum.any?(state.symptoms, &(&1 =~ "Hyperarousal"))
      assert state.prompt_directive =~ "ACUTE NEUROSIS — PANIC SPIRAL"
    end

    test "triggers :dissociation under overwhelming stress and deep trauma wound" do
      state = NeurosisState.evaluate(%{stress: 85, shame: 80}, %{fatigue: 40}, 75, false)
      assert state.state == :dissociation
      assert state.intensity >= 70
      assert Enum.any?(state.symptoms, &(&1 =~ "Depersonalization"))
      assert state.prompt_directive =~ "THIRD PERSON"
    end

    test "triggers :paranoia when severe fear coincides with acute anger/wound" do
      state = NeurosisState.evaluate(%{fear: 80, anger: 70}, %{fatigue: 20}, 60, false)
      assert state.state == :paranoia
      assert state.intensity >= 60
      assert Enum.any?(state.symptoms, &(&1 =~ "Hypervigilant"))
      assert state.prompt_directive =~ "PARANOID IDEATION"
    end

    test "triggers :depressive_inertia under crushing sadness and exhaustion" do
      state = NeurosisState.evaluate(%{sadness: 85}, %{fatigue: 75, pain: 60}, 0, false)
      assert state.state == :depressive_inertia
      assert state.intensity >= 70
      assert Enum.any?(state.symptoms, &(&1 =~ "Psychomotor retardation"))
      assert state.prompt_directive =~ "DEPRESSIVE INERTIA"
    end
  end

  describe "PTSDFlashback Engine" do
    test "does not trigger when there are no traumatic memories" do
      memory = %Memory{
        summary: "Had tea in the garden",
        valence: 0.5,
        emotional_intensity: 30,
        status: "active"
      }
      res = PTSDFlashback.detect_flashback([memory], %{"mood" => "calm"}, "hello")
      assert res.triggered? == false
      assert res.memory == nil
    end

    test "triggers episodic flashback when sensory cue matches traumatic memory" do
      traumatic_memory = %Memory{
        summary: "The day the citadel burned and comrades fell in blood",
        valence: -0.9,
        emotional_intensity: 95,
        tags: ["fire", "citadel", "blood"],
        status: "active"
      }

      res = PTSDFlashback.detect_flashback([traumatic_memory], %{"weather" => "heavy smoke"}, "There is blood on the floor")
      assert res.triggered? == true
      assert res.trigger_cue in ["blood", "fire", "citadel", "burned"]
      assert res.heart_rate_surge >= 80
      assert res.stress_surge >= 60
      assert res.prompt_directive =~ "INVOLUNTARY EPISODIC PTSD FLASHBACK ACTIVATED"
      assert res.prompt_directive =~ "The day the citadel burned"
    end
  end

  describe "DefenseMechanisms Engine" do
    test "deploys :projection when internal shame or guilt is intolerable" do
      defense = DefenseMechanisms.evaluate(%{shame: 70, guilt: 30}, %{fatigue: 20})
      assert defense.defense == :projection
      assert defense.intensity == 70
      assert defense.manifestation =~ "repressed failings"
      assert defense.prompt_directive =~ "PROJECTION"
    end

    test "deploys :reaction_formation when hostility and fear co-occur with low trust" do
      rel = %{wound: 60, trust: 20}
      defense = DefenseMechanisms.evaluate(%{anger: 75, fear: 50}, %{fatigue: 20}, nil, rel)
      assert defense.defense == :reaction_formation
      assert defense.manifestation =~ "saccharine"
      assert defense.prompt_directive =~ "REACTION FORMATION"
    end

    test "deploys :intellectualization to detach from overwhelming sadness" do
      defense = DefenseMechanisms.evaluate(%{sadness: 75, fear: 20}, %{fatigue: 30})
      assert defense.defense == :intellectualization
      assert defense.manifestation =~ "clinical"
      assert defense.prompt_directive =~ "INTELLECTUALIZATION"
    end

    test "deploys :regression under extreme fatigue and fear" do
      defense = DefenseMechanisms.evaluate(%{fear: 75}, %{fatigue: 85})
      assert defense.defense == :regression
      assert defense.manifestation =~ "childlike"
      assert defense.prompt_directive =~ "REGRESSION"
    end

    test "deploys :sublimation channeling anger into lethal discipline" do
      defense = DefenseMechanisms.evaluate(%{anger: 65, confidence: 80}, %{fatigue: 10})
      assert defense.defense == :sublimation
      assert defense.manifestation =~ "Transmuting"
      assert defense.prompt_directive =~ "SUBLIMATION"
    end
  end

  describe "Neurochemistry Engine" do
    test "computes balanced baseline correctly" do
      neuro = Neurochemistry.compute(%{stress: 20, fear: 15, anger: 10}, %{fatigue: 15, pain: 0})
      assert neuro.cortisol >= 0 and neuro.cortisol <= 100
      assert neuro.oxytocin >= 0 and neuro.oxytocin <= 100
      assert neuro.dopamine >= 0 and neuro.dopamine <= 100
      assert neuro.serotonin >= 0 and neuro.serotonin <= 100
      assert is_binary(neuro.hormonal_tone)
    end

    test "modulates emotional deltas according to active hormones" do
      # High oxytocin cushions anger
      high_oxy = %Neurochemistry{oxytocin: 85, serotonin: 70, cortisol: 20, dopamine: 50}
      base_anger_delta = 20
      modulated_anger = Neurochemistry.modulate_delta(:anger, base_anger_delta, high_oxy)
      assert modulated_anger < base_anger_delta

      # High cortisol sensitizes fear
      high_cort = %Neurochemistry{cortisol: 85, oxytocin: 20, serotonin: 40, dopamine: 30}
      base_fear_delta = 10
      modulated_fear = Neurochemistry.modulate_delta(:fear, base_fear_delta, high_cort)
      assert modulated_fear > base_fear_delta
    end
  end

  describe "DreamResidue & DreamLoop Integration" do
    setup do
      {:ok, char} =
        Characters.create_character(%{
          name: "Vael Test",
          slug: "vael-test-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active"
        })

      profile =
        Souls.create_soul_profile(%{
          character_id: char.id,
          fears: ["total abandonment"],
          personality_traits: %{}
        })

      emotional =
        Souls.create_emotional_state(%{
          character_id: char.id,
          anger: 60,
          fear: 50,
          stress: 70,
          rumination_intensity: 40
        })

      %{character: char, profile: profile, emotional: emotional}
    end

    test "synthesizes dream residue and persists into personality_traits", %{character: char} do
      residue = DreamResidue.synthesize(char.id)
      assert is_binary(residue.narrative) and residue.narrative != ""
      assert is_binary(residue.primary_archetype) and residue.primary_archetype != ""
      assert is_binary(residue.residual_thought) and residue.residual_thought != ""
      assert is_map(residue.waking_emotional_delta)

      reloaded_profile = Souls.get_soul_profile_by_character(char.id)
      last_dream = get_in(reloaded_profile.personality_traits, ["last_dream_residue"])
      assert is_map(last_dream)
      assert last_dream["narrative"] == residue.narrative
    end

    test "DreamLoop.run_cycle executes full consolidation and applies waking deltas", %{character: char} do
      assert {:ok, result} = DreamLoop.run_cycle(char.id, force: true)
      assert result.character_id == char.id
      assert is_map(result.emotional_decay)
      assert is_struct(result.dream_residue, DreamResidue)

      # Waking emotional delta should be present and applied to state
      assert is_map(result.dream_residue.waking_emotional_delta)
      updated_emotional = Souls.get_emotional_state_by_character(char.id)
      assert is_number(updated_emotional.stress)
      assert is_number(updated_emotional.fear)
    end
  end
end
