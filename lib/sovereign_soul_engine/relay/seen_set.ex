defmodule SovereignSoulEngine.Relay.SeenSet do
  @moduledoc """
  Bounded per-DID replay protection (RFC-0002 §4.2).

  Tracks seen `{from, nonce}` pairs so a replayed message is rejected. Each
  DID's set is capped via FIFO eviction to bound memory.
  """

  use GenServer

  @max_per_did 1_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Returns :ok for a new nonce, or {:error, :replayed} for a duplicate."
  @spec check_and_mark(String.t(), String.t()) :: :ok | {:error, :replayed}
  def check_and_mark(from_did, nonce) do
    GenServer.call(__MODULE__, {:check_and_mark, from_did, nonce})
  end

  @impl true
  def init(:ok), do: {:ok, %{}}

  @impl true
  def handle_call({:check_and_mark, from_did, nonce}, _from, state) do
    entry = Map.get(state, from_did, %{set: MapSet.new(), queue: :queue.new()})

    if MapSet.member?(entry.set, nonce) do
      {:reply, {:error, :replayed}, state}
    else
      {:reply, :ok, Map.put(state, from_did, add(entry, nonce))}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp add(entry, nonce) do
    {set, queue} =
      if MapSet.size(entry.set) >= @max_per_did do
        case :queue.out(entry.queue) do
          {{:value, oldest}, rest} -> {MapSet.delete(entry.set, oldest), rest}
          {:empty, _} -> {entry.set, entry.queue}
        end
      else
        {entry.set, entry.queue}
      end

    %{set: MapSet.put(set, nonce), queue: :queue.in(nonce, queue)}
  end
end
