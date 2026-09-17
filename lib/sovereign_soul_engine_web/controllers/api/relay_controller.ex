defmodule SovereignSoulEngineWeb.Api.RelayController do
  @moduledoc """
  Peer-to-peer relay inbound endpoint.

  Receives a forwarded envelope from a peer node, re-verifies its signature,
  deduplicates against the `SeenSet` (suppressing echoes), re-broadcasts locally,
  and forwards onward within the hop budget.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Relay.{Envelope, Forwarder, SeenSet}

  @world_topic "world:sovereign-society"

  @doc "GET /sse/api/relay/peers — advertises this node's peers for transitive discovery."
  def peers(conn, _params) do
    json(conn, %{peers: Forwarder.peers()})
  end

  def inbound(conn, %{"envelope" => envelope, "hops" => hops})
      when is_map(envelope) and is_integer(hops) do
    if authorized?(conn) do
      with :ok <- Envelope.verify(envelope),
           :ok <- SeenSet.check_and_mark(envelope["from"], envelope["nonce"]) do
        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          route(envelope),
          {:envelope, envelope}
        )

        Forwarder.forward(envelope, hops + 1)

        json(conn, %{status: "ok"})
      else
        {:error, :replayed} ->
          json(conn, %{status: "ok", deduped: true})

        {:error, reason} ->
          put_status(conn, :unprocessable_entity) |> json(%{error: to_string(reason)})
      end
    else
      put_status(conn, :unauthorized) |> json(%{error: "unauthorized"})
    end
  end

  def inbound(conn, _params) do
    put_status(conn, :bad_request) |> json(%{error: "malformed relay envelope"})
  end

  # When a shared `:relay_secret` is configured, peers must present it. Without
  # one (dev default) the endpoint is open — envelope signatures still gate the
  # actual message; the secret only gates who may relay.
  defp authorized?(conn) do
    case Application.get_env(:sovereign_soul_engine, :relay_secret) do
      nil ->
        true

      secret ->
        provided = get_req_header(conn, "x-relay-secret") |> List.first()
        Plug.Crypto.secure_compare(secret, provided || "")
    end
  end

  defp route(%{"to" => to}) when is_binary(to), do: "soul:" <> to
  defp route(_), do: @world_topic
end
