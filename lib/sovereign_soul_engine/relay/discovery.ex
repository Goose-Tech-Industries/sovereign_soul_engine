defmodule SovereignSoulEngine.Relay.Discovery do
  @moduledoc """
  Transitive peer discovery for the Soul Society relay (RFC-0002 §3).

  A node knows its configured peers; by asking each of them for *their* peers, it
  learns the wider network without a central registry. Discovered peers are kept
  in a public ETS table read by `Forwarder.peers/0`.
  """

  use GenServer

  @table :sse_discovered_peers
  @refresh_ms :timer.minutes(5)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Returns the transitively discovered peer URLs."
  def discovered_peers do
    case :ets.whereis(@table) do
      :undefined -> []
      _ -> :ets.tab2list(@table) |> Enum.map(fn {peer, _} -> peer end)
    end
  end

  @doc "Runs a discovery pass synchronously; returns the current discovered set."
  def discover_now(opts \\ []), do: GenServer.call(__MODULE__, {:discover, opts})

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])

    if Mix.env() != :test do
      Process.send_after(self(), :discover, @refresh_ms)
    end

    {:ok, %{}}
  end

  @impl true
  def handle_call({:discover, opts}, _from, state) do
    {:reply, do_discover(opts), state}
  end

  @impl true
  def handle_info(:discover, state) do
    _ = do_discover([])
    Process.send_after(self(), :discover, @refresh_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp do_discover(opts) do
    Application.get_env(:sovereign_soul_engine, :relay_peers, [])
    |> Enum.each(&query_peer(&1, opts))

    discovered_peers()
  end

  defp query_peer(peer, opts) do
    url = String.trim_trailing(peer, "/") <> "/sse/api/relay/peers"

    request_options =
      [retry: false, receive_timeout: 3000, connect_options: [timeout: 1500]]
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.get(url, request_options) do
      {:ok, %{status: 200, body: %{"peers" => peers}}} when is_list(peers) ->
        Enum.each(peers, fn p -> :ets.insert(@table, {p, true}) end)

      _ ->
        :ok
    end
  end
end
