defmodule SovereignSoulEngine.Relay.Forwarder do
  @moduledoc """
  Forwards relay envelopes to peer Soul Society nodes (RFC-0002 §3 Hub relay).

  Peers are configured via `:sovereign_soul_engine, :relay_peers` (list of base
  URLs). Forwarding is hop-limited to prevent loops; the `SeenSet` suppresses
  echoes when an envelope circles back to a node that already processed it.
  """

  @doc "The statically configured peer base URLs."
  def configured_peers, do: Application.get_env(:sovereign_soul_engine, :relay_peers, [])

  @doc "The list of peer relay base URLs — configured plus transitively discovered."
  def peers do
    Enum.uniq(configured_peers() ++ discovered_peers())
  end

  @doc "The maximum forwarding depth (hop budget)."
  def max_hops, do: Application.get_env(:sovereign_soul_engine, :relay_max_hops, 2)

  @doc """
  Forwards `envelope` to all peers with the given hop count, if within budget.
  Returns a list of per-peer results (`:ok` | `{:error, term}`).
  """
  @spec forward(map(), non_neg_integer()) :: [:ok | {:error, term()}]
  def forward(envelope, hops, opts \\ []) when is_integer(hops) do
    peers_list = peers()

    if peers_list == [] or hops > max_hops() do
      []
    else
      Enum.map(peers_list, &post(&1, envelope, hops, opts))
    end
  end

  defp post(peer, envelope, hops, opts) do
    url = String.trim_trailing(peer, "/") <> "/sse/api/relay/inbound"

    headers =
      case relay_secret() do
        nil -> []
        secret -> [{"x-relay-secret", secret}]
      end

    request_options =
      [
        json: %{"envelope" => envelope, "hops" => hops},
        headers: headers,
        receive_timeout: 3000,
        connect_options: [timeout: 1500],
        retry: false
      ]
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.post(url, request_options) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      other -> {:error, other}
    end
  end

  defp relay_secret do
    Application.get_env(:sovereign_soul_engine, :relay_secret)
  end

  defp discovered_peers do
    case :ets.whereis(:sse_discovered_peers) do
      :undefined -> []
      _ -> :ets.tab2list(:sse_discovered_peers) |> Enum.map(fn {peer, _} -> peer end)
    end
  end
end
