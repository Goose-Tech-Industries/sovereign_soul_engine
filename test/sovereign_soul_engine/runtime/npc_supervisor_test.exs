defmodule SovereignSoulEngine.Runtime.NPCSupervisorTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Runtime.{NPCRegistry, NPCSupervisor, NPCServer, SceneServer}

  setup do
    ensure_infrastructure_started!()
    :ok
  end

  describe "starting NPC processes" do
    test "starts an NPC process under the supervisor" do
      char_id = Ecto.UUID.generate()

      {:ok, pid} = NPCSupervisor.start_npc(char_id, idle_timeout_ms: :timer.hours(1))
      assert Process.alive?(pid)

      assert {:ok, ^pid} = NPCRegistry.lookup_npc(char_id)
      assert NPCSupervisor.child_count() >= 1
    end

    test "prevents duplicate NPC starts" do
      char_id = Ecto.UUID.generate()

      {:ok, _} = NPCSupervisor.start_npc(char_id, idle_timeout_ms: :timer.hours(1))
      assert {:error, :already_running} = NPCSupervisor.start_npc(char_id)
    end

    test "starts multiple NPCs without conflict" do
      id1 = Ecto.UUID.generate()
      id2 = Ecto.UUID.generate()

      {:ok, pid1} = NPCSupervisor.start_npc(id1, idle_timeout_ms: :timer.hours(1))
      {:ok, pid2} = NPCSupervisor.start_npc(id2, idle_timeout_ms: :timer.hours(1))

      assert Process.alive?(pid1)
      assert Process.alive?(pid2)
      assert pid1 != pid2
    end

    test "child count reflects active processes" do
      initial = NPCSupervisor.child_count()

      {:ok, _} = NPCSupervisor.start_npc(Ecto.UUID.generate(), idle_timeout_ms: :timer.hours(1))
      assert NPCSupervisor.child_count() == initial + 1

      {:ok, _} = NPCSupervisor.start_npc(Ecto.UUID.generate(), idle_timeout_ms: :timer.hours(1))
      assert NPCSupervisor.child_count() == initial + 2
    end
  end

  describe "starting scene processes" do
    test "starts a scene process under the supervisor" do
      scene_id = Ecto.UUID.generate()

      {:ok, pid} = NPCSupervisor.start_scene(scene_id, idle_timeout_ms: :timer.hours(1))
      assert Process.alive?(pid)

      assert {:ok, ^pid} = NPCRegistry.lookup_scene(scene_id)
    end

    test "prevents duplicate scene starts" do
      scene_id = Ecto.UUID.generate()

      {:ok, _} = NPCSupervisor.start_scene(scene_id, idle_timeout_ms: :timer.hours(1))
      assert {:error, :already_running} = NPCSupervisor.start_scene(scene_id)
    end

    test "list_children shows all active processes" do
      {:ok, _} = NPCSupervisor.start_npc(Ecto.UUID.generate(), idle_timeout_ms: :timer.hours(1))
      {:ok, _} = NPCSupervisor.start_scene(Ecto.UUID.generate(), idle_timeout_ms: :timer.hours(1))

      children = NPCSupervisor.list_children()
      assert length(children) >= 2
    end
  end

  describe "supervised crash recovery" do
    test "NPC process crash triggers deregistration" do
      char_id = Ecto.UUID.generate()

      {:ok, pid} = NPCSupervisor.start_npc(char_id, idle_timeout_ms: :timer.hours(1))
      assert Process.alive?(pid)
      assert {:ok, ^pid} = NPCRegistry.lookup_npc(char_id)

      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      assert_unregistered_npc(char_id)
    end
  end

  describe "termination" do
    test "stop_npc terminates and unregisters the process" do
      char_id = Ecto.UUID.generate()

      {:ok, pid} = NPCSupervisor.start_npc(char_id, idle_timeout_ms: :timer.hours(1))

      ref = Process.monitor(pid)
      NPCSupervisor.stop_npc(char_id)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      assert_unregistered_npc(char_id)
    end

    test "stop_scene terminates and unregisters the process" do
      scene_id = Ecto.UUID.generate()

      {:ok, pid} = NPCSupervisor.start_scene(scene_id, idle_timeout_ms: :timer.hours(1))

      ref = Process.monitor(pid)
      NPCSupervisor.stop_scene(scene_id)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      assert_unregistered_scene(scene_id)
    end

    test "stopping one NPC does not affect others" do
      id1 = Ecto.UUID.generate()
      id2 = Ecto.UUID.generate()

      {:ok, pid1} = NPCSupervisor.start_npc(id1, idle_timeout_ms: :timer.hours(1))
      {:ok, pid2} = NPCSupervisor.start_npc(id2, idle_timeout_ms: :timer.hours(1))

      ref = Process.monitor(pid1)
      NPCSupervisor.stop_npc(id1)

      assert_receive {:DOWN, ^ref, :process, ^pid1, :normal}
      assert Process.alive?(pid2)
      assert_unregistered_npc(id1)
      assert {:ok, ^pid2} = NPCRegistry.lookup_npc(id2)
    end
  end

  describe "restart after stop allows rehydration" do
    test "an NPC can be restarted after stopping" do
      char_id = Ecto.UUID.generate()

      {:ok, pid1} = NPCSupervisor.start_npc(char_id, idle_timeout_ms: :timer.hours(1))
      NPCSupervisor.stop_npc(char_id)

      assert_unregistered_npc(char_id)

      {:ok, pid2} = NPCSupervisor.start_npc(char_id, idle_timeout_ms: :timer.hours(1))
      assert Process.alive?(pid2)
      assert pid1 != pid2

      {:ok, state} = NPCServer.get_state(char_id)
      assert state.character_id == char_id
    end

    test "a scene can be restarted after stopping" do
      scene_id = Ecto.UUID.generate()

      {:ok, pid1} = NPCSupervisor.start_scene(scene_id, idle_timeout_ms: :timer.hours(1))
      NPCSupervisor.stop_scene(scene_id)

      assert_unregistered_scene(scene_id)

      {:ok, pid2} = NPCSupervisor.start_scene(scene_id, idle_timeout_ms: :timer.hours(1))
      assert Process.alive?(pid2)
      assert pid1 != pid2

      {:ok, state} = SceneServer.get_state(scene_id)
      assert state.scene_id == scene_id
    end
  end

  defp ensure_infrastructure_started! do
    unless Process.whereis(NPCRegistry) do
      start_supervised!({NPCRegistry, []})
    end

    unless Process.whereis(NPCSupervisor) do
      start_supervised!({NPCSupervisor, []})
    end
  end

  defp assert_unregistered_npc(char_id) do
    Enum.find_value(1..20, fn _ ->
      case NPCRegistry.lookup_npc(char_id) do
        {:error, :not_found} -> true
        _ -> Process.sleep(5)
      end
    end) || flunk("Expected NPC #{char_id} to be unregistered")
  end

  defp assert_unregistered_scene(scene_id) do
    Enum.find_value(1..20, fn _ ->
      case NPCRegistry.lookup_scene(scene_id) do
        {:error, :not_found} -> true
        _ -> Process.sleep(5)
      end
    end) || flunk("Expected scene #{scene_id} to be unregistered")
  end
end
