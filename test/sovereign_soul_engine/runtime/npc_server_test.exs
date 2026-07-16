defmodule SovereignSoulEngine.Runtime.NPCServerTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Runtime.{NPCRegistry, NPCServer}

  setup do
    ensure_registry_started!()
    :ok
  end

  describe "process startup and state" do
    test "starts an NPCServer and returns initial state" do
      character = character_fixture()

      {:ok, pid} = start_npc(character.id)

      assert Process.alive?(pid)

      {:ok, state} = NPCServer.get_state(character.id)
      assert state.character_id == character.id
      assert state.status == :observing
      assert state.scene_id == nil
      assert state.current_focus == nil
      assert state.recent_context == []
      assert state.pending_intention == nil
      assert state.immediate_state == %{}

      stop_and_await(pid)
    end

    test "rehydrates character name from database on start" do
      character = character_fixture(%{name: "Vael"})

      {:ok, pid} = start_npc(character.id)

      {:ok, state} = NPCServer.get_state(character.id)
      assert state.character_name == "Vael"

      stop_and_await(pid)
    end

    test "rehydrates soul profile and emotional state references" do
      character = character_fixture()
      soul = soul_profile_fixture(character.id)
      emotional = emotional_state_fixture(character.id)

      {:ok, pid} = start_npc(character.id)

      {:ok, state} = NPCServer.get_state(character.id)
      assert state.soul_profile_id == soul.id
      assert state.emotional_state_id == emotional.id

      stop_and_await(pid)
    end

    test "returns error when looking up non-existent NPC" do
      assert {:error, :not_found} = NPCServer.get_state(Ecto.UUID.generate())
    end
  end

  describe "scene management" do
    test "enters a scene" do
      character = character_fixture()
      {:ok, pid} = start_npc(character.id)

      scene_id = Ecto.UUID.generate()
      assert :ok = NPCServer.enter_scene(character.id, scene_id)

      {:ok, state} = NPCServer.get_state(character.id)
      assert state.scene_id == scene_id

      stop_and_await(pid)
    end

    test "leaves a scene" do
      character = character_fixture()
      {:ok, pid} = start_npc(character.id)

      scene_id = Ecto.UUID.generate()
      NPCServer.enter_scene(character.id, scene_id)
      assert :ok = NPCServer.leave_scene(character.id)

      {:ok, state} = NPCServer.get_state(character.id)
      assert state.scene_id == nil
      assert state.current_focus == nil

      stop_and_await(pid)
    end
  end

  describe "focus and context" do
    test "sets and reads current focus" do
      character = character_fixture()
      {:ok, pid} = start_npc(character.id)

      focus = %{target_character_id: Ecto.UUID.generate()}
      assert :ok = NPCServer.set_focus(character.id, focus)

      {:ok, state} = NPCServer.get_state(character.id)
      assert state.current_focus == focus

      stop_and_await(pid)
    end

    test "pushes context events" do
      character = character_fixture()
      {:ok, pid} = start_npc(character.id)

      event = %{type: :dialogue, content: "Hello"}
      assert :ok = NPCServer.push_context(character.id, event)

      {:ok, state} = NPCServer.get_state(character.id)
      assert [^event | _] = state.recent_context

      stop_and_await(pid)
    end

    test "context is limited to 50 entries" do
      character = character_fixture()
      {:ok, pid} = start_npc(character.id)

      Enum.each(1..60, fn i ->
        NPCServer.push_context(character.id, %{type: :event, n: i})
      end)

      {:ok, state} = NPCServer.get_state(character.id)
      assert length(state.recent_context) == 50

      stop_and_await(pid)
    end

    test "sets pending intention" do
      character = character_fixture()
      {:ok, pid} = start_npc(character.id)

      intention = %{action: :speak, text: "Greetings"}
      assert :ok = NPCServer.set_intention(character.id, intention)

      {:ok, state} = NPCServer.get_state(character.id)
      assert state.pending_intention == intention

      stop_and_await(pid)
    end
  end

  describe "immediate state" do
    test "updates and merges immediate state" do
      character = character_fixture()
      {:ok, pid} = start_npc(character.id)

      assert :ok = NPCServer.update_immediate_state(character.id, %{mood: "curious"})
      {:ok, state} = NPCServer.get_state(character.id)
      assert state.immediate_state.mood == "curious"

      assert :ok = NPCServer.update_immediate_state(character.id, %{energy: 75})
      {:ok, state} = NPCServer.get_state(character.id)
      assert state.immediate_state.mood == "curious"
      assert state.immediate_state.energy == 75

      stop_and_await(pid)
    end
  end

  describe "process teardown" do
    test "stop terminates the process" do
      character = character_fixture()

      {:ok, pid} = start_npc(character.id)

      ref = Process.monitor(pid)
      NPCServer.stop(character.id)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      assert_unregistered(character.id)
    end

    test "stop returns error when NPC not found" do
      assert {:error, :not_found} = NPCServer.stop(Ecto.UUID.generate())
    end
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp start_npc(char_id, opts \\ [idle_timeout_ms: :timer.hours(1)]) do
    NPCServer.start_link(char_id, opts)
  end

  defp stop_and_await(pid) do
    ref = Process.monitor(pid)
    GenServer.stop(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  defp ensure_registry_started! do
    unless Process.whereis(NPCRegistry) do
      start_supervised!({NPCRegistry, []})
    end
  end

  defp assert_unregistered(char_id) do
    Enum.find_value(1..20, fn _ ->
      case NPCRegistry.lookup_npc(char_id) do
        {:error, :not_found} -> true
        _ -> Process.sleep(5)
      end
    end) || flunk("Expected NPC #{char_id} to be unregistered")
  end

  defp character_fixture(attrs \\ %{}) do
    defaults = %{
      name: "Test NPC #{System.unique_integer()}",
      slug: "test-npc-#{System.unique_integer()}",
      kind: "npc",
      status: "active"
    }

    {:ok, character} = Characters.create_character(Map.merge(defaults, attrs))
    character
  end

  defp soul_profile_fixture(character_id) do
    {:ok, profile} =
      Souls.create_soul_profile(%{
        character_id: character_id,
        identity_summary: "A test soul",
        personality_traits: %{bravery: 0.8},
        speech_style: "reserved"
      })

    profile
  end

  defp emotional_state_fixture(character_id) do
    {:ok, state} =
      Souls.create_emotional_state(%{
        character_id: character_id,
        anger: 10,
        fear: 5,
        stress: 20,
        gratitude: 5,
        confidence: 50,
        sadness: 10,
        curiosity: 50,
        attachment: 10
      })

    state
  end
end
