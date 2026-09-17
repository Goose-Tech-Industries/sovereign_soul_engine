defmodule SovereignSoulEngine.Souls.SoulCapsuleTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.SoulCapsule
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Scenes

  setup do
    {:ok, character} =
      Characters.create_character(%{
        name: "Aethelgard",
        slug: "aethelgard",
        kind: "npc",
        status: "active",
        description: "An ancient sovereign scholar"
      })

    {:ok, target} =
      Characters.create_character(%{
        name: "Sarah",
        slug: "sarah",
        kind: "npc",
        status: "active",
        description: "A wandering cartographer"
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

    {:ok, _belief} =
      Souls.create_belief(%{
        character_id: character.id,
        belief: "Knowledge is sacred",
        domain: "world",
        conviction: 85
      })

    {:ok, _desire} =
      Souls.create_desire(%{
        character_id: character.id,
        desire: "Find the lost library",
        domain: "knowledge",
        urgency: 70
      })

    {:ok, _goal} =
      Souls.create_goal(%{
        character_id: character.id,
        goal: "Rebuild the archive",
        priority: 60,
        status: "active"
      })

    {:ok, _fear} =
      Souls.create_soul_fear(%{
        character_id: character.id,
        fear_type: "fires",
        severity: 65
      })

    {:ok, scene} =
      Scenes.create_scene(%{
        title: "The Library",
        status: "active"
      })

    {:ok, _shadow} =
      Souls.create_soul_shadow(%{
        character_id: character.id,
        scene_id: scene.id,
        private_monologue: "They will never understand what I gave up.",
        repressed_motive: "A hidden yearning to burn it all again"
      })

    {:ok, _relationship} =
      Relationships.create_relationship(%{
        source_character_id: character.id,
        target_character_id: target.id,
        relationship_type: "ally",
        trust: 80,
        respect: 70,
        affinity: 60,
        fear: 10
      })

    %{character: character, target: target}
  end

  describe "export_capsule/2 and import_capsule/2" do
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

    test "emits a capsule_id UUID", %{character: character} do
      {:ok, capsule} = SoulCapsule.export_capsule(character)

      assert capsule["capsule_id"] =~
               ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    end

    test "reconstitutes soul with identical attributes, memories, and psychology", %{
      character: character
    } do
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

      beliefs = Souls.list_beliefs_for_character(imported_char.id)
      assert Enum.any?(beliefs, &(&1.belief == "Knowledge is sacred"))

      desires = Souls.list_desires_for_character(imported_char.id)
      assert Enum.any?(desires, &(&1.desire == "Find the lost library"))

      goals = Souls.list_active_goals_for_character(imported_char.id)
      assert Enum.any?(goals, &(&1.goal == "Rebuild the archive"))

      fears = Souls.list_soul_fears_for_character(imported_char.id)
      assert Enum.any?(fears, &(&1.fear_type == "fires"))

      shadows = Souls.list_soul_shadows_for_character(imported_char.id)

      assert Enum.any?(
               shadows,
               &(&1.repressed_motive == "A hidden yearning to burn it all again")
             )
    end

    test "detects corrupted capsule checksum tampering", %{character: character} do
      {:ok, capsule} = SoulCapsule.export_capsule(character)

      tampered_soul = put_in(capsule, ["soul", "character", "name"], "Corrupted Doppelganger")

      assert {:error, :checksum_mismatch_corrupted_capsule} =
               SoulCapsule.import_capsule(tampered_soul)
    end
  end

  describe "relationship graph" do
    test "resolves relationship targets by slug", %{character: character, target: target} do
      {:ok, capsule} = SoulCapsule.export_capsule(character)

      assert {:ok, imported} = SoulCapsule.import_capsule(capsule, overwrite: false)

      rels = Relationships.list_relationships_for_source(imported.id)
      assert length(rels) == 1
      assert hd(rels).target_character_id == target.id
      assert hd(rels).trust == 80
      assert hd(rels).respect == 70
      assert hd(rels).affinity == 60
    end

    test "stores unresolved relationships for later reconnection", %{
      character: character,
      target: target
    } do
      {:ok, capsule} = SoulCapsule.export_capsule(character)

      # Relocate the target so its original slug no longer resolves locally.
      {:ok, _} = Characters.update_character(target, %{slug: "sarah_relocated"})

      assert {:ok, imported} = SoulCapsule.import_capsule(capsule, overwrite: false)

      assert Relationships.list_relationships_for_source(imported.id) == []

      imported = Characters.get_character!(imported.id)
      assert [%{"target_slug" => "sarah"}] = imported.metadata["unresolved_relationships"]
    end
  end

  describe "signing key" do
    test "verifies only with the same secret key", %{character: character} do
      {:ok, capsule} = SoulCapsule.export_capsule(character, secret_key: "key-a")

      assert {:error, :checksum_mismatch_corrupted_capsule} =
               SoulCapsule.import_capsule(capsule, secret_key: "key-b")

      assert {:ok, _} = SoulCapsule.import_capsule(capsule, secret_key: "key-a", overwrite: false)
    end

    test "checksum is deterministic across exports", %{character: character} do
      {:ok, c1} = SoulCapsule.export_capsule(character, secret_key: "k")
      {:ok, c2} = SoulCapsule.export_capsule(character, secret_key: "k")

      assert c1["checksum"] == c2["checksum"]
    end
  end
end
