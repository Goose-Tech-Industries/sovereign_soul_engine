defmodule SovereignSoulEngine.ContextsCrudTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Scenes.{Scene, SceneMessage}
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Memories.Memory

  describe "Characters context CRUD" do
    test "create, read, update, and delete lifecycle" do
      slug = "crud_char_#{System.unique_integer([:positive])}"

      # Create
      assert {:ok, %Character{} = char} =
               Characters.create_character(%{
                 name: "Rowan Thorne",
                 slug: slug,
                 kind: "npc",
                 description: "A stoic warden of the wild",
                 status: "active"
               })

      assert char.name == "Rowan Thorne"
      assert char.slug == slug

      # Read by ID and Slug
      assert Characters.get_character(char.id).id == char.id
      assert Characters.get_character!(char.id).id == char.id
      assert Characters.get_character_by_slug(slug).id == char.id
      assert Characters.get_character_by_slug!(slug).id == char.id

      # Update
      assert {:ok, updated} = Characters.update_character(char, %{name: "Rowan the Unbroken"})
      assert updated.name == "Rowan the Unbroken"
      assert Characters.get_character(char.id).name == "Rowan the Unbroken"

      # List
      all = Characters.list_characters()
      assert Enum.any?(all, &(&1.id == char.id))

      # Delete
      assert {:ok, _deleted} = Characters.delete_character(updated)
      assert Characters.get_character(char.id) == nil
    end

    test "get_or_create_external_player/3 is idempotent on (external_source, external_id)" do
      source = "rpg_realm"
      ext_id = "hero_player_99"

      # First contact creates player
      p1 = Characters.get_or_create_external_player(source, ext_id, "Sir Galahad")
      assert p1.kind == "player"
      assert p1.external_source == source
      assert p1.external_id == ext_id

      # Read-only lookup finds player
      assert Characters.get_external_player(source, ext_id).id == p1.id

      # Second contact returns existing record
      p2 = Characters.get_or_create_external_player(source, ext_id, "Sir Galahad")
      assert p2.id == p1.id
    end
  end

  describe "Scenes context CRUD" do
    setup do
      {:ok, c1} =
        Characters.create_character(%{
          name: "Actor One",
          slug: "actor_1_#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active"
        })

      {:ok, c2} =
        Characters.create_character(%{
          name: "Actor Two",
          slug: "actor_2_#{System.unique_integer([:positive])}",
          kind: "player",
          status: "active"
        })

      %{char_a: c1, char_b: c2}
    end

    test "create, read, update, delete scene", %{char_a: _c1} do
      assert {:ok, %Scene{} = scene} =
               Scenes.create_scene(%{
                 title: "The Ruined Citadel",
                 status: "active",
                 location: "Outer Ruins"
               })

      assert scene.title == "The Ruined Citadel"
      assert Scenes.get_scene(scene.id).id == scene.id
      assert Scenes.get_scene!(scene.id).id == scene.id

      assert {:ok, updated} = Scenes.update_scene(scene, %{status: "completed"})
      assert updated.status == "completed"

      assert {:ok, _deleted} = Scenes.delete_scene(updated)
      assert Scenes.get_scene(scene.id) == nil
    end

    test "find_or_create_direct_scene/2 establishes participant links and is idempotent", %{char_a: c1, char_b: c2} do
      # Initially nil
      assert Scenes.find_direct_scene(c1, c2) == nil

      # First contact creates 1:1 direct scene
      scene1 = Scenes.find_or_create_direct_scene(c1, c2)
      assert scene1.status == "active"
      assert is_binary(scene1.id)

      # Second call returns the exact same scene
      scene2 = Scenes.find_or_create_direct_scene(c1, c2)
      assert scene2.id == scene1.id

      # Symmetrical lookup from b to a also matches
      assert Scenes.find_direct_scene(c2, c1).id == scene1.id
    end

    test "find_or_create_group_scene/2 manages ambient scenes idempotently" do
      source = "grid_world"
      key = "quadrant_7"

      # Initially nil
      assert Scenes.find_group_scene(source, key) == nil

      # First contact creates ambient group scene
      s1 = Scenes.find_or_create_group_scene(source, key)
      assert s1.external_source == source
      assert s1.external_id == key

      # Second contact returns existing
      s2 = Scenes.find_or_create_group_scene(source, key)
      assert s2.id == s1.id
    end

    test "message creation and retrieval", %{char_a: c1} do
      {:ok, scene} = Scenes.create_scene(%{title: "Dialogue Hall", status: "active"})

      {:ok, %SceneMessage{} = msg} =
        Scenes.create_message(%{
          scene_id: scene.id,
          character_id: c1.id,
          content: "The wind howls tonight.",
          message_type: "dialogue"
        })

      assert msg.content == "The wind howls tonight."
      assert Scenes.get_message!(msg.id).id == msg.id

      messages = Scenes.list_messages(scene.id)
      assert length(messages) == 1
      assert hd(messages).id == msg.id
    end
  end

  describe "Relationships context" do
    test "create, update, and lookup bidirectional metrics" do
      {:ok, c1} = Characters.create_character(%{name: "Alice", slug: "alice_#{System.unique_integer([:positive])}", kind: "npc"})
      {:ok, c2} = Characters.create_character(%{name: "Bob", slug: "bob_#{System.unique_integer([:positive])}", kind: "player"})

      # Initially nil
      assert Relationships.get_relationship(c1.id, c2.id) == nil

      # Create relationship
      {:ok, rel} =
        Relationships.create_relationship(%{
          source_character_id: c1.id,
          target_character_id: c2.id,
          affinity: 70,
          trust: 60,
          relationship_type: "ally"
        })

      assert rel.affinity == 70
      assert rel.trust == 60

      # Lookup
      found = Relationships.get_relationship(c1.id, c2.id)
      assert found.id == rel.id

      # Update
      {:ok, updated} = Relationships.update_relationship(rel, %{trust: 85})
      assert updated.trust == 85
    end
  end

  describe "Memories context" do
    test "create, list, and purge memories" do
      {:ok, char} = Characters.create_character(%{name: "Sage", slug: "sage_#{System.unique_integer([:positive])}", kind: "npc"})

      {:ok, %Memory{} = m1} =
        Memories.create_memory(%{
          owner_character_id: char.id,
          category: "episodic",
          summary: "Observed ancient ritual in the ruins.",
          importance: 50,
          emotional_intensity: 40,
          valence: 0.2,
          tags: ["ritual", "ruins"],
          status: "active",
          occurred_at: DateTime.utc_now()
        })

      {:ok, %Memory{} = m2} =
        Memories.create_memory(%{
          owner_character_id: char.id,
          category: "core",
          summary: "Sworn protector of the flame.",
          importance: 90,
          emotional_intensity: 80,
          valence: 0.8,
          tags: ["oath", "flame"],
          status: "active",
          occurred_at: DateTime.utc_now()
        })

      all_mems = Memories.list_memories_for_character(char.id)
      assert length(all_mems) == 2

      episodic_only = Memories.list_memories_by_category(char.id, "episodic")
      assert length(episodic_only) == 1
      assert hd(episodic_only).id == m1.id

      # Purge episodic memories by category
      {:ok, deleted_count} = Memories.purge_memories_for_character(char.id, category: "episodic")
      assert deleted_count == 1

      remaining = Memories.list_memories_for_character(char.id)
      assert length(remaining) == 1
      assert hd(remaining).id == m2.id
    end
  end
end
