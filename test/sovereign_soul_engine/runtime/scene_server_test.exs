defmodule SovereignSoulEngine.Runtime.SceneServerTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Runtime.{NPCRegistry, SceneServer}

  setup do
    ensure_infrastructure_started!()
    :ok
  end

  describe "process startup and state" do
    test "starts a SceneServer with initial state" do
      scene = scene_fixture()

      {:ok, pid} = start_scene(scene.id)

      assert Process.alive?(pid)

      {:ok, state} = SceneServer.get_state(scene.id)
      assert state.scene_id == scene.id
      assert state.participants == %{}
      assert state.event_sequence_number == 0

      stop_and_await(pid)
    end

    test "rehydrates existing participants from database" do
      scene = scene_fixture()
      character = character_fixture()
      {:ok, _} = Scenes.add_participant(%{scene_id: scene.id, character_id: character.id})

      {:ok, pid} = start_scene(scene.id)

      {:ok, state} = SceneServer.get_state(scene.id)
      assert map_size(state.participants) == 1
      assert Map.has_key?(state.participants, character.id)

      stop_and_await(pid)
    end

    test "returns error when looking up non-existent scene" do
      assert {:error, :not_found} = SceneServer.get_state(Ecto.UUID.generate())
    end
  end

  describe "participant management" do
    test "adds a participant" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      assert :ok = SceneServer.add_participant(scene.id, char1.id)

      {:ok, state} = SceneServer.get_state(scene.id)
      assert Map.has_key?(state.participants, char1.id)

      stop_and_await(pid)
    end

    test "removes a participant" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)
      assert :ok = SceneServer.remove_participant(scene.id, char1.id)

      {:ok, state} = SceneServer.get_state(scene.id)
      refute Map.has_key?(state.participants, char1.id)

      stop_and_await(pid)
    end

    test "lists all participants" do
      scene = scene_fixture()
      char1 = character_fixture()
      char2 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)
      SceneServer.add_participant(scene.id, char2.id)

      {:ok, participants} = SceneServer.list_participants(scene.id)
      assert char1.id in participants
      assert char2.id in participants
      assert length(participants) == 2

      stop_and_await(pid)
    end
  end

  describe "event processing" do
    test "processes an event and returns a correlation ID" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)

      {:ok, correlation_id, seq} =
        SceneServer.process_event(scene.id, char1.id, :dialogue, %{text: "Hello"})

      assert is_binary(correlation_id)
      assert seq == 1

      stop_and_await(pid)
    end

    test "increments sequence number for each event" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)

      {:ok, _corr_id, seq1} =
        SceneServer.process_event(scene.id, char1.id, :dialogue, %{text: "First"})

      {:ok, _corr_id, seq2} =
        SceneServer.process_event(scene.id, char1.id, :dialogue, %{text: "Second"})

      assert seq2 > seq1

      stop_and_await(pid)
    end

    test "prevents duplicate events using correlation IDs" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)

      corr_id = Ecto.UUID.generate()

      {:ok, ^corr_id, _seq} =
        SceneServer.process_event(scene.id, char1.id, :dialogue, %{
          text: "Hello",
          correlation_id: corr_id
        })

      assert {:error, :duplicate_event} =
               SceneServer.process_event(scene.id, char1.id, :dialogue, %{
                 text: "Hello again",
                 correlation_id: corr_id
               })

      stop_and_await(pid)
    end

    test "uses provided correlation ID when given" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)

      custom_id = Ecto.UUID.generate()

      {:ok, ^custom_id, _seq} =
        SceneServer.process_event(scene.id, char1.id, :dialogue, %{
          text: "Custom",
          correlation_id: custom_id
        })

      stop_and_await(pid)
    end
  end

  describe "PubSub broadcasts" do
    test "broadcast sends a message to subscribers" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)

      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scene:#{scene.id}")

      SceneServer.broadcast(scene.id, :custom_event, %{data: "test"})

      assert_receive {:custom_event, %{data: "test"}}, 500

      stop_and_await(pid)
    end

    test "participant joining broadcasts to scene topic" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)

      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scene:#{scene.id}")

      char2 = character_fixture()
      SceneServer.add_participant(scene.id, char2.id)

      assert_receive {:participant_joined, data}, 500
      assert data.character_id == char2.id

      stop_and_await(pid)
    end

    test "participant leaving broadcasts to scene topic" do
      scene = scene_fixture()

      {:ok, pid} = start_scene(scene.id)

      char2 = character_fixture()
      SceneServer.add_participant(scene.id, char2.id)

      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scene:#{scene.id}")
      SceneServer.remove_participant(scene.id, char2.id)

      assert_receive {:participant_left, data}, 500
      assert data.character_id == char2.id

      stop_and_await(pid)
    end

    test "event processing broadcasts to scene topic" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)

      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scene:#{scene.id}")

      SceneServer.process_event(scene.id, char1.id, :dialogue, %{text: "Hello"})

      assert_receive {:scene_event, data}, 500
      assert data.scene_id == scene.id
      assert data.source_character_id == char1.id
      assert data.event_type == :dialogue
      assert is_integer(data.sequence_number)

      stop_and_await(pid)
    end

    test "scene close broadcasts on termination" do
      scene = scene_fixture()
      char1 = character_fixture()

      {:ok, _pid} = start_scene(scene.id)

      SceneServer.add_participant(scene.id, char1.id)

      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scene:#{scene.id}")
      SceneServer.stop(scene.id)

      assert_receive {:scene_closed, data}, 500
      assert data.scene_id == scene.id
    end
  end

  describe "error handling" do
    test "process_event returns error for non-existent scene" do
      assert {:error, :not_found} =
               SceneServer.process_event(
                 Ecto.UUID.generate(),
                 Ecto.UUID.generate(),
                 :dialogue,
                 %{}
               )
    end

    test "add_participant returns error for non-existent scene" do
      assert {:error, :not_found} =
               SceneServer.add_participant(Ecto.UUID.generate(), Ecto.UUID.generate())
    end

    test "stop returns error for non-existent scene" do
      assert {:error, :not_found} = SceneServer.stop(Ecto.UUID.generate())
    end
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp start_scene(scene_id, opts \\ [idle_timeout_ms: :timer.hours(1)]) do
    SceneServer.start_link(scene_id, opts)
  end

  defp stop_and_await(pid) do
    ref = Process.monitor(pid)
    GenServer.stop(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  defp ensure_infrastructure_started! do
    unless Process.whereis(NPCRegistry) do
      start_supervised!({NPCRegistry, []})
    end

    unless Process.whereis(SovereignSoulEngine.PubSub) do
      start_supervised!({Phoenix.PubSub, name: SovereignSoulEngine.PubSub})
    end
  end

  defp scene_fixture(attrs \\ %{}) do
    defaults = %{
      title: "Test Scene #{System.unique_integer()}",
      status: "active"
    }

    {:ok, scene} = Scenes.create_scene(Map.merge(defaults, attrs))
    scene
  end

  defp character_fixture(attrs \\ %{}) do
    alias SovereignSoulEngine.Characters

    defaults = %{
      name: "Test Char #{System.unique_integer()}",
      slug: "test-char-#{System.unique_integer()}",
      kind: "npc",
      status: "active"
    }

    {:ok, character} = Characters.create_character(Map.merge(defaults, attrs))
    character
  end
end
