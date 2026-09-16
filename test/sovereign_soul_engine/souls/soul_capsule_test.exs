defmodule SovereignSoulEngine.Souls.SoulCapsuleTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.SoulCapsule
  alias SovereignSoulEngine.Memories

  setup do
    {:ok, character} =
      Characters.create_character(%{
        name: "Aethelgard",
        slug: "aethelgard",
        kind: "npc",
        status: "active",
        description: "An ancient sovereign scholar"
      })

    {:ok, _profile} =
      Souls.create_soul_profile(%{
        character_id: character.id,
        identity_summary: "An ancient sovereign scholar of forgotten libraries",
        attachment_style: "secure",
        personality_traits: %{"curiosity" => 95, "stoicism" => 80, "archetype" => "Scholar"}
      })

    {:ok, _emotional} =
      Souls.create_emotional_state(%{
        character_id: character.id,
        stress: 15,
        curiosity: 90,
        confidence: 85,
        attachment: 60
      })

    {:ok, _somatic} =
      Souls.create_somatic_state(%{
        character_id: character.id,
        fatigue: 20,
        pain: 0,
        circadian_chronotype: "night_owl"
      })

    {:ok, _mem} =
      Memories.create_memory(%{
        owner_character_id: character.id,
        category: "core",
        summary: "The Great Library was lost",
        details: %{"narrative" => "Watched the burning of the parchment arches in youth."},
        emotional_intensity: 90,
        valence: -0.8,
        importance: 95,
        tags: ["origins", "library", "loss"],
        occurred_at: DateTime.utc_now()
      })

    %{character: character}
  end

  describe "export_capsule/1 and import_capsule/2" do
    test "exports full digital soul with valid HMAC checksum", %{character: character} do
      assert {:ok, capsule} = SoulCapsule.export_capsule(character)
      assert capsule["format"] == "sovereign_soul_capsule/v1"
      assert is_binary(capsule["checksum"])
      assert is_map(capsule["soul"])

      soul = capsule["soul"]
      assert soul["character"]["name"] == "Aethelgard"
      assert soul["soul_profile"]["personality_traits"]["archetype"] == "Scholar"
      assert soul["soul_profile"]["personality_traits"]["curiosity"] == 95
      assert length(soul["memories"]) >= 1

      json = SoulCapsule.to_json(capsule)
      assert is_binary(json)
    end

    test "reconstitutes soul with identical attributes and memories from capsule", %{character: character} do
      {:ok, capsule} = SoulCapsule.export_capsule(character)
      json = SoulCapsule.to_json(capsule)

      assert {:ok, imported_char} = SoulCapsule.import_capsule(json, overwrite: false)
      assert String.starts_with?(imported_char.slug, "aethelgard")
      assert imported_char.name == "Aethelgard"

      profile = Souls.get_soul_profile_by_character(imported_char.id)
      assert profile.personality_traits["archetype"] == "Scholar"
      assert profile.attachment_style == "secure"

      emotional = Souls.get_emotional_state_by_character(imported_char.id)
      assert emotional.curiosity == 90

      memories = Memories.list_memories_for_character(imported_char.id)
      assert Enum.any?(memories, &(&1.summary == "The Great Library was lost"))
    end

    test "detects corrupted capsule checksum tampering", %{character: character} do
      {:ok, capsule} = SoulCapsule.export_capsule(character)

      # Tamper with soul data without updating checksum
      tampered_soul = put_in(capsule, ["soul", "character", "name"], "Corrupted Doppelganger")

      assert {:error, :checksum_mismatch_corrupted_capsule} =
               SoulCapsule.import_capsule(tampered_soul)
    end
  end
end
