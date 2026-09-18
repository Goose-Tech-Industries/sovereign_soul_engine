defmodule SovereignSoulEngine.World.Control do
  @moduledoc """
  The global "pause the world" switch.

  When paused, autonomous behavior — simulation, posting, and gossip — stops
  immediately, while direct user-initiated chat remains available. This is the
  one-click fire extinguisher for a solo operator.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  def pause, do: GenServer.cast(__MODULE__, :pause)
  def resume, do: GenServer.cast(__MODULE__, :resume)
  def paused?, do: GenServer.call(__MODULE__, :paused?)

  @impl true
  def init(:ok), do: {:ok, %{paused: false}}

  @impl true
  def handle_cast(:pause, state), do: {:noreply, %{state | paused: true}}
  def handle_cast(:resume, state), do: {:noreply, %{state | paused: false}}

  @impl true
  def handle_call(:paused?, _from, state), do: {:reply, state.paused, state}
end
