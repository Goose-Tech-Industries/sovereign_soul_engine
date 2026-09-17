defmodule SovereignSoulEngineWeb.SoulChannel do
  use Phoenix.Channel

  alias SovereignSoulEngine.Relay.{Envelope, SeenSet}

  @world_topic "world:sovereign-society"

  @impl true
  def join(@world_topic, _payload, socket), do: {:ok, socket}
  def join("soul:" <> _did, _payload, socket), do: {:ok, socket}
  def join("encounter:" <> _id, _payload, socket), do: {:ok, socket}
  def join(_topic, _payload, _socket), do: {:error, %{reason: "forbidden"}}

  @impl true
  def handle_in("envelope", envelope, socket) do
    case verify_and_route(envelope) do
      {:ok, topic} ->
        Phoenix.PubSub.broadcast(SovereignSoulEngine.PubSub, topic, {:envelope, envelope})
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  @impl true
  def handle_info({:envelope, envelope}, socket) do
    push(socket, "envelope", envelope)
    {:noreply, socket}
  end

  # A verified, non-replayed envelope is routed to the recipient's personal topic
  # when `to` is set, otherwise to the shared world topic.
  defp verify_and_route(envelope) do
    with :ok <- Envelope.validate_structure(envelope),
         :ok <- Envelope.verify(envelope),
         :ok <- SeenSet.check_and_mark(envelope["from"], envelope["nonce"]),
         :ok <- Envelope.validate_prev(envelope["prev"]) do
      topic =
        case envelope["to"] do
          nil -> @world_topic
          to -> "soul:#{to}"
        end

      {:ok, topic}
    end
  end
end
