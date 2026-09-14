defmodule SovereignSoulEngine.Souls.BeliefEvolutionTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.BeliefEvolution
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Souls.ConsequenceEngine

  describe "BeliefEvolution — Epigenetic shifts under extreme psychological conditions" do
    setup do
      {:ok, char_a} =
        Characters.create_character(%{
          name: "Vael",
          slug: "vael-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active"
        })

      {:ok, char_b} =
        Characters.create_character(%{
          name: "Goose",
          slug: "goose-#{System.unique_integer([:positive])}",
          kind: "player",
          status: "active"
        })

      {:ok, profile} =
        Souls.create_soul_profile(%{
          character_id: char_a.id,
          core_values: ["Always protect the weak", "Strength is self-reliance"],
          version: 1
        })

      {:ok, rel} =
        Relationships.create_relationship(%{
          source_character_id: char_a.id,
          target_character_id: char_b.id,
          trust: 50,
          affinity: 20,
          wound: 0
        })

      %{char_a: char_a, char_b: char_b, profile: profile, relationship: rel}
    end

    test "traumatic betrayal (wound >= 80) shifts idealistic values to hardened ones", %{
      profile: profile
    } do
      betrayal_rel = %{wound: 85, trust: 5, affinity: -60}

      assert {:ok, result} = BeliefEvolution.evaluate_shift(profile, betrayal_rel)
      assert result.type == :betrayal
      assert result.shifted_from =~ "protect the weak"
      assert result.shifted_to =~ "prove their loyalty"

      reloaded = Souls.get_soul_profile_by_character(profile.character_id)
      assert "Only protect those who prove their loyalty" in reloaded.core_values
      assert reloaded.version == 2
    end

    test "profound bonding (trust >= 90, affinity >= 70) softens solitary cynicism", %{
      char_a: char_a
    } do
      # Set up profile with cynical solitary belief
      profile = Souls.get_soul_profile_by_character(char_a.id)
      {:ok, updated_profile} =
        Souls.update_soul_profile(profile, %{
          core_values: ["Strength is self-reliance", "Watch your own back"]
        })

      bonding_rel = %{trust: 95, affinity: 80, wound: 5}

      assert {:ok, result} = BeliefEvolution.evaluate_shift(updated_profile, bonding_rel)
      assert result.type == :bonding
      assert result.shifted_to =~ "shared vulnerability"

      reloaded = Souls.get_soul_profile_by_character(char_a.id)
      assert Enum.any?(reloaded.core_values, &(&1 =~ "shared vulnerability"))
    end

    test "normal interactions (wound < 80, trust < 90) do not trigger belief shifts", %{
      profile: profile
    } do
      normal_rel = %{trust: 60, affinity: 40, wound: 20}
      assert {:no_shift, _} = BeliefEvolution.evaluate_shift(profile, normal_rel)
    end

    test "ConsequenceEngine triggers belief evolution when betrayal event shatters trust", %{
      char_a: char_a,
      char_b: char_b
    } do
      {:ok, scene} =
        SovereignSoulEngine.Scenes.create_scene(%{
          title: "Betrayal Scene",
          status: "active"
        })

      # Set initial high wound so the betrayal pushes it over 80
      rel = Relationships.get_relationship(char_a.id, char_b.id)
      Relationships.update_relationship(rel, %{wound: 60})

      params = %{
        character_id: char_a.id,
        source_character_id: char_b.id,
        target_character_id: char_a.id,
        scene_id: scene.id,
        event_type: :betrayed_me,
        event_intensity: 90
      }

      assert {:ok, result} = ConsequenceEngine.resolve(params)
      assert Map.has_key?(result, :belief_evolution)
    end
  end
end
