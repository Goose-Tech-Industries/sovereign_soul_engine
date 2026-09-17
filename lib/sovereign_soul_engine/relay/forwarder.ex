defmodule SovereignSoulEngine.Relay.Forwarder do
  @moduledoc """
  Forwards relay envelopes to peer Soul Society nodes (RFC-0002 §3 Hub relay).

  Peers are configured via `:sovereign_soul_engine, :relay_peers` (list of base
  URLs). Forwarding is hop-limited to prevent loops; the `SeenSet` suppresses
  echoes when an envelope circles back to a node that already processed it.
  """

  @doc "The list of peer relay base URLs."
  def peers, do: Application.get_env(:sovereign_soul_engine, :relay_peers, [])

  @doc "The maximum forwarding depth (hop budget)."
  def max_hops, do: Application.get_env(:sovereign_soul_engine, :relay_max_hops, 2)

  @doc """
  Forwards `envelope` to all peers with the given hop count, if within budget.
  Returns a list of per-peer results (`:ok` | `{:error, term}`).
  """
  @spec forward(map(), non_neg_integer()) :: [:ok | {:error, term()}]
  def forward(envelope, hops) when is_integer(hops) do
    peers_list = peers()

    if peers_list == [] or hops > max_hops() do
      []
    else
      Enum.map(peers_list, &post(&1, envelope, hops))
    end
  end

  defp post(peer, envelope, hops) do
    url = String.trim_trailing(peer, "/") <> "/sse/api/relay/inbound"

    case Req.post(url, json: %{"envelope" => envelope, "hops" => hops}, retry: false) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      other -> {:error, other}
    end
  end
end
