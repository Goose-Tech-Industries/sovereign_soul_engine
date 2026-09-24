defmodule SovereignSoulEngineWeb.SoulChannel do
  use Phoenix.Channel

  alias SovereignSoulEngine.Relay.{Envelope, EncounterBridge, Forwarder, SeenSet}
  alias SovereignSoulEngineWeb.Presence

  @world_topic "world:sovereign-society"

  @impl true
  def join(topic, payload, socket) do
    if valid_topic?(topic) do
      socket = assign(socket, :did, resolve_did(topic, payload))
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "forbidden"}}
    end
  end

  @impl true
  def handle_in("envelope", envelope, socket) do
    case verify_and_route(envelope) do
      {:ok, topic} ->
        Phoenix.PubSub.broadcast(SovereignSoulEngine.PubSub, topic, {:envelope, envelope})
        maybe_dispatch_encounter(envelope)
        forward_async(envelope)
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

  @impl true
  def handle_info(:after_join, socket) do
    case Map.get(socket.assigns, :did) do
      nil ->
        :ok

      did ->
        {:ok, _} =
          Presence.track(socket, did, %{
            online_at: DateTime.utc_now(),
            topic: socket.topic,
            status: "present"
          })

        push(socket, "presence_state", Presence.list(socket))
    end

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case Map.get(socket.assigns, :did) do
      nil -> :ok
      did -> Presence.untrack(socket, did)
    end

    :ok
  end

  # A verified, non-replayed envelope is routed to the recipient's personal topic
  # when `to` is set, otherwise to the shared world topic.
  defp verify_and_route(envelope) do
    with :ok <- Envelope.validate_structure(envelope),
         :ok <-
           SovereignSoulEngine.Moderation.screen(%{
             "from_did" => envelope["from"],
             "payload" => envelope["payload"]
           }),
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

  # Encounter lifecycle envelopes also drive the local MeshProtocol encounter.
  defp maybe_dispatch_encounter(envelope) do
    if EncounterBridge.encounter?(envelope) do
      EncounterBridge.process_envelope(envelope)
    end

    :ok
  end

  # Forwarding is fire-and-forget so a slow/unreachable peer never blocks the
  # channel's reply to the sending soul.
  defp forward_async(envelope) do
    Task.Supervisor.start_child(SovereignSoulEngine.TaskSupervisor, fn ->
      Forwarder.forward(envelope, 1)
    end)

    :ok
  end

  defp valid_topic?(@world_topic), do: true
  defp valid_topic?("soul:" <> _), do: true
  defp valid_topic?("encounter:" <> _), do: true
  defp valid_topic?(_), do: false

  # The DID is the soul's identity; it may arrive via the join payload or be
  # derived from a `soul:<did>` topic.
  defp resolve_did(topic, payload) do
    case payload do
      %{"did" => did} when is_binary(did) -> did
      _ -> topic_did(topic)
    end
  end

  defp topic_did("soul:" <> did), do: did
  defp topic_did(_), do: nil
end
