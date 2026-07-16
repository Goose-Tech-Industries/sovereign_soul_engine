defmodule SovereignSoulEngine.Runtime.NPCRegistryTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.Runtime.NPCRegistry

  setup do
    ensure_registry_started!()
    :ok
  end

  describe "NPC registration and lookup" do
    test "registers and looks up an NPC" do
      char_id = Ecto.UUID.generate()

      pid = self()
      NPCRegistry.register_npc(char_id, pid)

      assert {:ok, ^pid} = NPCRegistry.lookup_npc(char_id)
    end

    test "returns error for unregistered NPC" do
      assert {:error, :not_found} = NPCRegistry.lookup_npc(Ecto.UUID.generate())
    end

    test "registered? returns true for registered NPC" do
      char_id = Ecto.UUID.generate()
      NPCRegistry.register_npc(char_id, self())
      assert NPCRegistry.npc_registered?(char_id)
    end

    test "registered? returns false for unregistered NPC" do
      refute NPCRegistry.npc_registered?(Ecto.UUID.generate())
    end

    test "list_npcs returns all registered NPC keys" do
      id1 = Ecto.UUID.generate()
      id2 = Ecto.UUID.generate()

      NPCRegistry.register_npc(id1, self())
      NPCRegistry.register_npc(id2, self())

      npcs = NPCRegistry.list_npcs()
      assert {:npc, id1} in npcs
      assert {:npc, id2} in npcs
    end
  end

  describe "Scene registration and lookup" do
    test "registers and looks up a scene" do
      scene_id = Ecto.UUID.generate()

      pid = self()
      NPCRegistry.register_scene(scene_id, pid)

      assert {:ok, ^pid} = NPCRegistry.lookup_scene(scene_id)
    end

    test "returns error for unregistered scene" do
      assert {:error, :not_found} = NPCRegistry.lookup_scene(Ecto.UUID.generate())
    end

    test "scene_registered? returns true for registered scene" do
      scene_id = Ecto.UUID.generate()
      NPCRegistry.register_scene(scene_id, self())
      assert NPCRegistry.scene_registered?(scene_id)
    end

    test "list_scenes returns all registered scene keys" do
      id1 = Ecto.UUID.generate()
      id2 = Ecto.UUID.generate()

      NPCRegistry.register_scene(id1, self())
      NPCRegistry.register_scene(id2, self())

      scenes = NPCRegistry.list_scenes()
      assert {:scene, id1} in scenes
      assert {:scene, id2} in scenes
    end
  end

  describe "separation" do
    test "NPC and scene registrations do not conflict" do
      npc_id = Ecto.UUID.generate()
      scene_id = Ecto.UUID.generate()

      pid = self()

      NPCRegistry.register_npc(npc_id, pid)
      NPCRegistry.register_scene(scene_id, pid)

      assert {:ok, ^pid} = NPCRegistry.lookup_npc(npc_id)
      assert {:ok, ^pid} = NPCRegistry.lookup_scene(scene_id)
    end
  end

  defp ensure_registry_started! do
    unless Process.whereis(NPCRegistry) do
      start_supervised!(NPCRegistry)
    end
  end
end
