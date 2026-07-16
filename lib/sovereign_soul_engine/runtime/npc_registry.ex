defmodule SovereignSoulEngine.Runtime.NPCRegistry do
  @moduledoc """
  Local partitioned registry for looking up NPC runtime processes by character_id.

  NPC Servers are registered under this registry with key `{:npc, character_id}`.
  Scene Servers are registered under this registry with key `{:scene, scene_id}`.
  """

  @doc """
  Returns the Registry child spec for inclusion in the supervision tree.
  """
  def child_spec(_opts \\ []) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__,
      partitions: System.schedulers_online()
    )
  end

  @doc """
  Looks up the PID of an NPC process by character_id.
  """
  def lookup_npc(character_id) do
    case Registry.lookup(__MODULE__, {:npc, character_id}) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Looks up the PID of a scene process by scene_id.
  """
  def lookup_scene(scene_id) do
    case Registry.lookup(__MODULE__, {:scene, scene_id}) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns all registered NPC keys.
  """
  def list_npcs do
    __MODULE__
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.filter(fn {type, _id} -> type == :npc end)
  end

  @doc """
  Returns all registered scene keys.
  """
  def list_scenes do
    __MODULE__
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.filter(fn {type, _id} -> type == :scene end)
  end

  @doc """
  Checks whether an NPC is registered.
  """
  def npc_registered?(character_id) do
    match?({:ok, _}, lookup_npc(character_id))
  end

  @doc """
  Checks whether a scene is registered.
  """
  def scene_registered?(scene_id) do
    match?({:ok, _}, lookup_scene(scene_id))
  end

  @doc """
  Registers via the registry. Used internally by the supervisor.
  """
  def register_npc(character_id, pid) do
    Registry.register(__MODULE__, {:npc, character_id}, %{})
    pid
  end

  def register_scene(scene_id, pid) do
    Registry.register(__MODULE__, {:scene, scene_id}, %{})
    pid
  end
end
