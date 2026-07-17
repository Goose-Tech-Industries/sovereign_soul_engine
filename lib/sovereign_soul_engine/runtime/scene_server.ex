defmodule SovereignSoulEngine.Runtime.SceneServer do
  @moduledoc """
  GenServer that coordinates a bounded scene interaction.

  Controls:
    - Canonical event ordering
    - Participant membership
    - PubSub broadcasts for real-time updates
    - Correlation IDs for tracking
    - Prevention of duplicate event processing
  """

  use GenServer, restart: :temporary

  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Runtime.NPCRegistry

  require Logger

  @idle_timeout_ms :timer.minutes(5)

  # ── Client API ──────────────────────────────────────────────

  @doc """
  Starts a SceneServer for the given scene_id.
  """
  def start_link(scene_id, opts \\ []) do
    GenServer.start_link(__MODULE__, {scene_id, opts})
  end

  @doc """
  Returns the current scene runtime state.
  """
  def get_state(scene_id) do
    call(scene_id, :get_state)
  end

  @doc """
  Adds a participant to the scene.
  """
  def add_participant(scene_id, character_id, opts \\ %{}) do
    call(scene_id, {:add_participant, character_id, opts})
  end

  @doc """
  Removes a participant from the scene.
  """
  def remove_participant(scene_id, character_id) do
    call(scene_id, {:remove_participant, character_id})
  end

  @doc """
  Lists current scene participants.
  """
  def list_participants(scene_id) do
    call(scene_id, :list_participants)
  end

  @doc """
  Processes a scene event with deduplication and ordered delivery.

  Returns `{:ok, correlation_id}` or `{:error, reason}`.
  """
  def process_event(scene_id, character_id, event_type, payload \\ %{}) do
    call(scene_id, {:process_event, character_id, event_type, payload})
  end

  @doc """
  Broadcasts a message to all scene participants via PubSub.
  The topic is `"scene:<scene_id>"`.
  """
  def broadcast(scene_id, event_type, data) do
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "scene:#{scene_id}",
      {event_type, data}
    )
  end

  @doc """
  Stops the scene process gracefully.
  """
  def stop(scene_id) do
    case NPCRegistry.lookup_scene(scene_id) do
      {:ok, pid} ->
        GenServer.stop(pid, :normal)
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Enables autonomous auto-play in this scene.
  """
  def enable_auto_play(scene_id) do
    call(scene_id, :enable_auto_play)
  end

  @doc """
  Disables autonomous auto-play in this scene.
  """
  def disable_auto_play(scene_id) do
    call(scene_id, :disable_auto_play)
  end

  # ── GenServer Callbacks ─────────────────────────────────────

  @impl true
  def init({scene_id, opts}) do
    idle_timeout = Keyword.get(opts, :idle_timeout_ms, @idle_timeout_ms)

    state = %{
      scene_id: scene_id,
      idle_timeout_ms: idle_timeout,
      participants: %{},
      processed_correlation_ids: MapSet.new(),
      event_sequence_number: 0,
      auto_play: false,
      stamina: %{},
      auto_play_timer: nil
    }

    rehydrated_state = rehydrate_participants(state)

    NPCRegistry.register_scene(scene_id, self())

    Logger.debug("SceneServer started for scene_id=#{inspect(scene_id)}")

    schedule_idle_check(idle_timeout)
    {:ok, rehydrated_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:add_participant, character_id, opts}, _from, state) do
    participant = %{
      character_id: character_id,
      joined_at: DateTime.utc_now(),
      opts: opts
    }

    new_participants = Map.put(state.participants, character_id, participant)
    new_state = %{state | participants: new_participants}

    broadcast_update(state.scene_id, :participant_joined, %{
      character_id: character_id,
      participant_count: map_size(new_participants)
    })

    Logger.debug("Participant #{inspect(character_id)} joined scene #{inspect(state.scene_id)}")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:remove_participant, character_id}, _from, state) do
    new_participants = Map.delete(state.participants, character_id)
    new_state = %{state | participants: new_participants}

    broadcast_update(state.scene_id, :participant_left, %{
      character_id: character_id,
      participant_count: map_size(new_participants)
    })

    Logger.debug("Participant #{inspect(character_id)} left scene #{inspect(state.scene_id)}")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:enable_auto_play, _from, state) do
    npcs = rehydrate_npcs(state.scene_id)
    stamina = Map.new(npcs, fn npc_id -> {npc_id, 100} end)

    if state.auto_play_timer, do: Process.cancel_timer(state.auto_play_timer)

    timer = Process.send_after(self(), :tick_npc, 2000)

    broadcast_update(state.scene_id, :auto_play_started, %{active: true})

    {:reply, :ok, %{state | auto_play: true, stamina: stamina, auto_play_timer: timer}}
  end

  @impl true
  def handle_call(:disable_auto_play, _from, state) do
    if state.auto_play_timer, do: Process.cancel_timer(state.auto_play_timer)

    broadcast_update(state.scene_id, :auto_play_stopped, %{reason: "disabled"})

    {:reply, :ok, %{state | auto_play: false, auto_play_timer: nil}}
  end

  @impl true
  def handle_call(:list_participants, _from, state) do
    {:reply, {:ok, Map.keys(state.participants)}, state}
  end

  @impl true
  def handle_call({:process_event, character_id, event_type, payload}, _from, state) do
    correlation_id = payload[:correlation_id] || generate_correlation_id()

    with {:ok, state} <- ensure_not_duplicate(state, correlation_id),
         state <- validate_participant(state, character_id) do
      state = %{
        state
        | event_sequence_number: state.event_sequence_number + 1
      }

      state = track_correlation_id(state, correlation_id)

      event_data = %{
        scene_id: state.scene_id,
        source_character_id: character_id,
        event_type: event_type,
        payload: payload,
        correlation_id: correlation_id,
        sequence_number: state.event_sequence_number,
        timestamp: DateTime.utc_now()
      }

      broadcast_update(state.scene_id, :scene_event, event_data)

      Logger.debug(
        "Scene #{inspect(state.scene_id)} processed event #{event_type} " <>
          "from #{inspect(character_id)} (seq=#{state.event_sequence_number})"
      )

      {:reply, {:ok, correlation_id, state.event_sequence_number}, state}
    end
  end

  @impl true
  def handle_info(:idle_check, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:tick_npc, state) do
    if state.auto_play do
      npcs =
        rehydrate_npcs(state.scene_id)
        |> Enum.filter(fn npc_id -> Map.get(state.stamina, npc_id, 100) > 0 end)

      case npcs do
        [] ->
          broadcast_update(state.scene_id, :auto_play_stopped, %{reason: "exhausted"})

          # Log system message
          Scenes.create_message(%{
            scene_id: state.scene_id,
            character_id: nil,
            content: "*[System] The characters are exhausted and decide to rest.*",
            kind: "system"
          })

          {:noreply, %{state | auto_play: false, auto_play_timer: nil}}

        _ ->
          # Select NPC with highest remaining stamina
          npc_id = Enum.max_by(npcs, fn id -> Map.get(state.stamina, id, 100) end)

          # Spawn generation Task
          Task.start(fn ->
            SovereignSoulEngine.Souls.Generator.generate(npc_id, state.scene_id)
          end)

          # Decrement stamina by 20
          current_stamina = Map.get(state.stamina, npc_id, 100)
          new_stamina = Map.put(state.stamina, npc_id, max(current_stamina - 20, 0))

          # Schedule next tick in 6 seconds
          timer = Process.send_after(self(), :tick_npc, 6000)

          {:noreply, %{state | stamina: new_stamina, auto_play_timer: timer}}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp rehydrate_npcs(scene_id) do
    try do
      Scenes.get_scene!(scene_id)
      |> SovereignSoulEngine.Repo.preload(participants: :character)
      |> Map.get(:participants, [])
      |> Enum.filter(&(&1.character.kind == "npc"))
      |> Enum.map(& &1.character_id)
    rescue
      _ -> []
    end
  end

  @impl true
  def terminate(_reason, state) do
    Logger.debug("SceneServer terminating for scene_id=#{inspect(state.scene_id)}")

    broadcast_update(state.scene_id, :scene_closed, %{
      scene_id: state.scene_id
    })

    :ok
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp call(scene_id, message) do
    case NPCRegistry.lookup_scene(scene_id) do
      {:ok, pid} -> GenServer.call(pid, message)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp schedule_idle_check(timeout_ms) do
    Process.send_after(self(), :idle_check, timeout_ms)
  end

  defp generate_correlation_id do
    Ecto.UUID.generate()
  end

  defp ensure_not_duplicate(state, correlation_id) do
    if MapSet.member?(state.processed_correlation_ids, correlation_id) do
      {:reply, {:error, :duplicate_event}, state, :hibernate}
    else
      {:ok, state}
    end
  end

  defp validate_participant(state, character_id) do
    unless Map.has_key?(state.participants, character_id) do
      Logger.warning(
        "Non-participant #{inspect(character_id)} attempted event in scene #{state.scene_id}"
      )
    end

    state
  end

  defp track_correlation_id(state, correlation_id) do
    max_tracked = 1000
    ids = MapSet.put(state.processed_correlation_ids, correlation_id)

    ids =
      if MapSet.size(ids) > max_tracked do
        trimmed = MapSet.to_list(ids) |> Enum.drop(MapSet.size(ids) - max_tracked)
        MapSet.new(trimmed)
      else
        ids
      end

    %{state | processed_correlation_ids: ids}
  end

  defp broadcast_update(scene_id, event_type, data) do
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "scene:#{scene_id}",
      {event_type, data}
    )
  end

  defp rehydrate_participants(state) do
    participants =
      try do
        Scenes.list_participants(state.scene_id)
      rescue
        _ -> []
      end

    participant_map =
      Map.new(participants, fn p ->
        {p.character_id, %{character_id: p.character_id, joined_at: p.inserted_at, opts: %{}}}
      end)

    %{state | participants: participant_map}
  end
end
