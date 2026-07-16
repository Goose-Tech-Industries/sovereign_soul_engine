defmodule SovereignSoulEngine.Runtime.NPCSupervisor do
  @moduledoc """
  DynamicSupervisor for NPC and Scene runtime processes.

  Manages the lifecycle of NPCServer and SceneServer processes.
  Crashing one process does not affect others. On crash, the
  character's state is rehydrated from PostgreSQL.

  ## Supervision tree

      NPCSupervisor (DynamicSupervisor)
      ├── NPCServer (for each active NPC)
      └── SceneServer (for each active scene)
  """

  use DynamicSupervisor

  require Logger

  # ── Client API ──────────────────────────────────────────────

  @doc """
  Starts the DynamicSupervisor.
  """
  def start_link(_opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Starts an NPCServer for the given character under the supervisor.

  Returns `{:ok, pid}` or `{:error, reason}`.
  If an NPC process for this character is already running,
  returns `{:error, :already_running}`.
  """
  def start_npc(character_id, opts \\ []) do
    alias SovereignSoulEngine.Runtime.NPCRegistry

    if NPCRegistry.npc_registered?(character_id) do
      Logger.warning("NPCServer for character_id=#{inspect(character_id)} is already running")

      {:error, :already_running}
    else
      child_spec = %{
        id: {:npc, character_id},
        start: {SovereignSoulEngine.Runtime.NPCServer, :start_link, [character_id, opts]},
        restart: :temporary
      }

      case DynamicSupervisor.start_child(__MODULE__, child_spec) do
        {:ok, pid} ->
          Logger.info(
            "NPCServer started for character_id=#{inspect(character_id)} (pid=#{inspect(pid)})"
          )

          {:ok, pid}

        {:ok, pid, _info} ->
          Logger.info(
            "NPCServer started for character_id=#{inspect(character_id)} (pid=#{inspect(pid)})"
          )

          {:ok, pid}

        {:error, {:already_started, pid}} ->
          Logger.warning(
            "NPCServer for character_id=#{inspect(character_id)} is already running (pid=#{inspect(pid)})"
          )

          {:error, :already_running}

        {:error, reason} ->
          Logger.error(
            "Failed to start NPCServer for character_id=#{inspect(character_id)}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  end

  @doc """
  Starts a SceneServer for the given scene under the supervisor.

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  def start_scene(scene_id, opts \\ []) do
    alias SovereignSoulEngine.Runtime.NPCRegistry

    if NPCRegistry.scene_registered?(scene_id) do
      Logger.warning("SceneServer for scene_id=#{inspect(scene_id)} is already running")

      {:error, :already_running}
    else
      child_spec = %{
        id: {:scene, scene_id},
        start: {SovereignSoulEngine.Runtime.SceneServer, :start_link, [scene_id, opts]},
        restart: :temporary
      }

      case DynamicSupervisor.start_child(__MODULE__, child_spec) do
        {:ok, pid} ->
          Logger.info(
            "SceneServer started for scene_id=#{inspect(scene_id)} (pid=#{inspect(pid)})"
          )

          {:ok, pid}

        {:ok, pid, _info} ->
          Logger.info(
            "SceneServer started for scene_id=#{inspect(scene_id)} (pid=#{inspect(pid)})"
          )

          {:ok, pid}

        {:error, {:already_started, pid}} ->
          Logger.warning(
            "SceneServer for scene_id=#{inspect(scene_id)} is already running (pid=#{inspect(pid)})"
          )

          {:error, :already_running}

        {:error, reason} ->
          Logger.error(
            "Failed to start SceneServer for scene_id=#{inspect(scene_id)}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  end

  @doc """
  Stops a running NPCServer.
  """
  def stop_npc(character_id) do
    SovereignSoulEngine.Runtime.NPCServer.stop(character_id)
  end

  @doc """
  Stops a running SceneServer.
  """
  def stop_scene(scene_id) do
    SovereignSoulEngine.Runtime.SceneServer.stop(scene_id)
  end

  @doc """
  Returns the count of active children under this supervisor.
  """
  def child_count do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> length()
  end

  @doc """
  Lists all active NPCServer and SceneServer children.
  """
  def list_children do
    DynamicSupervisor.which_children(__MODULE__)
  end

  # ── Callbacks ───────────────────────────────────────────────

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
