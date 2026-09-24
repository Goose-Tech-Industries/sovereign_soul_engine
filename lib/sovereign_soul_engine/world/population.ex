defmodule SovereignSoulEngine.World.Population do
  @moduledoc """
  Keeps every soul in the Soul Society world backed by a live `NPCServer`
  process, so the town is continuously "alive" rather than only ticking on a
  schedule. The simulation (`World.Simulation`) still drives their behavior;
  this just gives each soul a resident runtime process.
  """

  use GenServer
  require Logger

  alias SovereignSoulEngine.World
  alias SovereignSoulEngine.Runtime.{NPCRegistry, NPCSupervisor}

  @ensure_ms :timer.minutes(5)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Starts NPCServers for any world soul not already running. Returns the count started."
  def ensure_population do
    World.world_souls()
    |> Enum.reduce(0, fn soul, acc ->
      if NPCRegistry.npc_registered?(soul.id) do
        acc
      else
        case NPCSupervisor.start_npc(soul.id) do
          {:ok, _pid} -> acc + 1
          {:error, _} -> acc
        end
      end
    end)
  end

  @impl true
  def init(:ok) do
    if Mix.env() != :test do
      started = ensure_population()
      Logger.info("World.Population: started #{started} resident soul processes")
      Process.send_after(self(), :ensure, @ensure_ms)
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:ensure, state) do
    _ = ensure_population()
    Process.send_after(self(), :ensure, @ensure_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
