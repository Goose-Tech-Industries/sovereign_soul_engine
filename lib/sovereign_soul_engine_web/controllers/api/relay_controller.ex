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

  def inbound(conn, %{"envelope" => envelope, "hops" => hops})
      when is_map(envelope) and is_integer(hops) do
    with :ok <- Envelope.verify(envelope),
         :ok <- SeenSet.check_and_mark(envelope["from"], envelope["nonce"]) do
      Phoenix.PubSub.broadcast(SovereignSoulEngine.PubSub, route(envelope), {:envelope, envelope})
      Forwarder.forward(envelope, hops + 1)

      json(conn, %{status: "ok"})
    else
      {:error, :replayed} ->
        json(conn, %{status: "ok", deduped: true})

      {:error, reason} ->
        put_status(conn, :unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  def inbound(conn, _params) do
    put_status(conn, :bad_request) |> json(%{error: "malformed relay envelope"})
  end

  defp route(%{"to" => to}) when is_binary(to), do: "soul:" <> to
  defp route(_), do: @world_topic
end
