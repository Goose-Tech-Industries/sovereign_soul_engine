defmodule SovereignSoulEngine.Runtime.NPCServer do
  @moduledoc """
  GenServer for an active NPC runtime process.

  Permanent truth remains in PostgreSQL. This process holds temporary
  runtime state such as current scene, focus, and pending intentions.

  On crash and restart, state is rehydrated from the database.
  After a configurable idle period, the process hibernates to
  release memory.
  """

  use GenServer, restart: :temporary

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Runtime.NPCRegistry

  require Logger

  @idle_timeout_ms :timer.minutes(5)

  # ── Client API ──────────────────────────────────────────────

  @doc """
  Starts an NPCServer for the given character_id.

  Options:
    - `:idle_timeout_ms` — timeout before hibernation (default: 5 minutes)
  """
  def start_link(character_id, opts \\ []) do
    GenServer.start_link(__MODULE__, {character_id, opts})
  end

  @doc """
  Returns the current runtime state of the NPC.
  """
  def get_state(character_id) do
    call(character_id, :get_state)
  end

  @doc """
  Enters the NPC into a scene.
  """
  def enter_scene(character_id, scene_id) do
    call(character_id, {:enter_scene, scene_id})
  end

  @doc """
  Removes the NPC from its current scene.
  """
  def leave_scene(character_id) do
    call(character_id, :leave_scene)
  end

  @doc """
  Sets the NPC's current focus (e.g. a target character or object).
  """
  def set_focus(character_id, focus) do
    call(character_id, {:set_focus, focus})
  end

  @doc """
  Appends an event to the NPC's recent context.
  """
  def push_context(character_id, event) do
    call(character_id, {:push_context, event})
  end

  @doc """
  Sets a pending intention for the NPC.
  """
  def set_intention(character_id, intention) do
    call(character_id, {:set_intention, intention})
  end

  @doc """
  Updates the immediate state map (merged with existing).
  """
  def update_immediate_state(character_id, updates) do
    call(character_id, {:update_immediate_state, updates})
  end

  @doc """
  Stops the NPC process gracefully.
  """
  def stop(character_id) do
    case NPCRegistry.lookup_npc(character_id) do
      {:ok, pid} ->
        GenServer.stop(pid, :normal)
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  # ── GenServer Callbacks ─────────────────────────────────────

  @impl true
  def init({character_id, opts}) do
    idle_timeout = Keyword.get(opts, :idle_timeout_ms, @idle_timeout_ms)

    state = rehydrate_state(character_id)

    registered_state = %{
      character_id: character_id,
      idle_timeout_ms: idle_timeout,
      scene_id: state.scene_id,
      current_focus: state.current_focus,
      recent_context: state.recent_context,
      pending_intention: state.pending_intention,
      immediate_state: state.immediate_state,
      status: state.status,
      soul_profile_id: state.soul_profile_id,
      emotional_state_id: state.emotional_state_id,
      character_name: state.character_name
    }

    Logger.debug("NPCServer started for character_id=#{inspect(character_id)}")

    NPCRegistry.register_npc(character_id, self())
    schedule_idle_check(idle_timeout)
    {:ok, registered_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:enter_scene, scene_id}, _from, state) do
    new_state = %{state | scene_id: scene_id}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:leave_scene, _from, state) do
    new_state = %{state | scene_id: nil, current_focus: nil}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_focus, focus}, _from, state) do
    new_state = %{state | current_focus: focus}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:push_context, event}, _from, state) do
    max_context = 50
    context = Enum.take([event | state.recent_context], max_context)
    new_state = %{state | recent_context: context}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_intention, intention}, _from, state) do
    new_state = %{state | pending_intention: intention}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:update_immediate_state, updates}, _from, state) do
    new_immediate = Map.merge(state.immediate_state, updates)
    new_state = %{state | immediate_state: new_immediate}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:idle_check, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.debug("NPCServer terminating for character_id=#{inspect(state.character_id)}")
    :ok
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp call(character_id, message) do
    case NPCRegistry.lookup_npc(character_id) do
      {:ok, pid} -> GenServer.call(pid, message)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp schedule_idle_check(timeout_ms) do
    Process.send_after(self(), :idle_check, timeout_ms)
  end

  defp rehydrate_state(character_id) do
    %{
      scene_id: nil,
      current_focus: nil,
      recent_context: [],
      pending_intention: nil,
      immediate_state: %{},
      status: :observing,
      soul_profile_id: nil,
      emotional_state_id: nil,
      character_name: nil
    }
    |> merge_db_state(character_id)
  end

  defp merge_db_state(state, character_id) do
    character = safe_get_character(character_id)
    soul = safe_get_soul_profile(character_id)
    emotional = safe_get_emotional_state(character_id)

    %{
      state
      | status: if(character && character.status == "active", do: :observing, else: :inactive),
        soul_profile_id: soul && soul.id,
        emotional_state_id: emotional && emotional.id,
        character_name: character && character.name
    }
  end

  defp safe_get_character(character_id) do
    Characters.get_character(character_id)
  rescue
    _ -> nil
  end

  defp safe_get_soul_profile(character_id) do
    Souls.get_soul_profile_by_character(character_id)
  rescue
    _ -> nil
  end

  defp safe_get_emotional_state(character_id) do
    Souls.get_emotional_state_by_character(character_id)
  rescue
    _ -> nil
  end
end
