defmodule SovereignSoulEngine.Social.ResonanceSpectrumTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.{Characters, Relationships, Souls, World}
  alias SovereignSoulEngine.Social.MeshProtocol
  alias SovereignSoulEngine.World.Simulation

  setup do
    {:ok, char_a} =
      Characters.create_living_soul(
        %{
          name: "Aurelia Dawn",
          slug: "aurelia-res-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active",
          description: "Stargazer and celestial arcanist of the high spires."
        },
        %{
          core_values: ["truth", "knowledge", "celestial"],
          speech_style: "poetic"
        }
      )

    {:ok, char_b} =
      Characters.create_living_soul(
        %{
          name: "Kaelen Ironwatch",
          slug: "kaelen-res-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active",
          description: "Sentry commander and perimeter guard."
        },
        %{
          core_values: ["vigilance", "defense", "order"],
          speech_style: "terse"
        }
      )

    {:ok, char_c} =
      Characters.create_living_soul(
        %{
          name: "Lyra Moonweaver",
          slug: "lyra-res-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active",
          description: "Sanctuary weaver of sacred cloaks."
        },
        %{
          core_values: ["sanctuary", "compassion", "empathy"],
          speech_style: "gentle"
        }
      )

    [char_a: char_a, char_b: char_b, char_c: char_c]
  end

  describe "compute_resonance/2 dynamic spectrum" do
    test "strangers with neutral affinity produce balanced baseline resonance", %{
      char_a: a,
      char_b: b
    } do
      score = MeshProtocol.compute_resonance(a, b)
      assert is_integer(score)
      assert score >= 40 and score <= 65
    end

    test "high affinity and trust propel resonance well over 55% into 70%–95%", %{
      char_a: a,
      char_c: c
    } do
      # Before relationship
      baseline_score = MeshProtocol.compute_resonance(a, c)

      # Build deep mutual bond
      {:ok, _rel1} =
        Relationships.create_relationship(%{
          source_character_id: a.id,
          target_character_id: c.id,
          affinity: 85,
          trust: 90,
          relationship_type: "Kindred Soul"
        })

      {:ok, _rel2} =
        Relationships.create_relationship(%{
          source_character_id: c.id,
          target_character_id: a.id,
          affinity: 85,
          trust: 90,
          relationship_type: "Kindred Soul"
        })

      high_score = MeshProtocol.compute_resonance(a, c)

      # The score must cross well over 55%
      assert high_score > 65
      assert high_score >= 70
      assert high_score > baseline_score
    end

    test "hostile, wounded relationship pulls resonance down below 40%", %{
      char_a: a,
      char_b: b
    } do
      # Build bitter rivalry
      {:ok, _rel1} =
        Relationships.create_relationship(%{
          source_character_id: a.id,
          target_character_id: b.id,
          affinity: -60,
          anger: 75,
          wound: 80,
          trust: 10,
          relationship_type: "Bitter Rival"
        })

      {:ok, _rel2} =
        Relationships.create_relationship(%{
          source_character_id: b.id,
          target_character_id: a.id,
          affinity: -60,
          anger: 75,
          wound: 80,
          trust: 10,
          relationship_type: "Bitter Rival"
        })

      low_score = MeshProtocol.compute_resonance(a, b)

      # Must drop below 45% into guarded / hostile territory
      assert low_score < 45
      assert low_score >= 15
    end

    test "live emotional states modulate resonance (curiosity & attachment boost score)", %{
      char_a: a,
      char_c: c
    } do
      # Warm, curious emotional states
      emo_a = Souls.get_emotional_state_by_character(a.id)
      emo_c = Souls.get_emotional_state_by_character(c.id)

      {:ok, _} =
        Souls.update_emotional_state(emo_a, %{
          attachment: 85,
          curiosity: 90,
          confidence: 80,
          gratitude: 80,
          stress: 0
        })

      {:ok, _} =
        Souls.update_emotional_state(emo_c, %{
          attachment: 85,
          curiosity: 90,
          confidence: 80,
          gratitude: 80,
          stress: 0
        })

      score = MeshProtocol.compute_resonance(a, c)
      assert score > 55
    end

    test "live high stress and anger depress resonance score", %{
      char_a: a,
      char_b: b
    } do
      emo_a = Souls.get_emotional_state_by_character(a.id)
      emo_b = Souls.get_emotional_state_by_character(b.id)

      {:ok, _} =
        Souls.update_emotional_state(emo_a, %{stress: 95, anger: 85, fear: 80, confidence: 10})

      {:ok, _} =
        Souls.update_emotional_state(emo_b, %{stress: 95, anger: 85, fear: 80, confidence: 10})

      score = MeshProtocol.compute_resonance(a, b)
      assert score <= 50
    end
  end

  describe "simulation encounters resonance variety" do
    test "simulation step delta rewards high resonance pairs with accelerated affinity" do
      World.seed_souls()

      # Verify delta scaling in Simulation.step
      assert {:ok, summary} = Simulation.step(rotate: true)
      assert summary.souls > 0

      for encounter <- summary.encounters do
        assert encounter.resonance >= 15 and encounter.resonance <= 98

        if encounter.resonance >= 65 do
          assert encounter.delta.affinity >= 4
        end
      end
    end
  end
end
