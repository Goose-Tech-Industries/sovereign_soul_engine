defmodule SovereignSoulEngineWeb.WorldLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.World

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "world:feed")
    end

    {:ok, assign(socket, :feed, World.feed())}
  end

  @impl true
  def handle_info({:world_event, _event}, socket) do
    {:noreply, assign(socket, :feed, World.feed())}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <header class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold tracking-tight text-base-content">
              Soul Society
            </h1>
            <p class="mt-1 text-sm text-base-content/60">
              The living world — souls meeting, gossiping, and drifting. Live.
            </p>
          </div>
          <div class="flex gap-2">
            <span class="text-sm px-3 py-1 rounded-full bg-purple-500/15 text-purple-300">
              {@feed.souls} souls
            </span>
            <span class="text-sm px-3 py-1 rounded-full bg-pink-500/15 text-pink-300">
              {@feed.relationships} relationships
            </span>
          </div>
        </header>

        <section>
          <h2 class="text-xl font-semibold text-base-content mb-4">Recent events</h2>

          <div :if={@feed.recent_events == []} class="text-sm text-base-content/50 italic">
            The world is quiet. Seed it with
            <code class="text-xs bg-base-300 px-1.5 py-0.5 rounded">
              mix run priv/repo/seeds/seed_souls.exs
            </code>
            and trigger a tick.
          </div>

          <div class="space-y-2">
            <%= for event <- @feed.recent_events do %>
              <div class="p-3 rounded-lg border border-base-300 bg-base-200/30">
                <div class="flex items-start justify-between gap-4">
                  <div class="min-w-0">
                    <p class="text-sm font-medium text-base-content truncate">
                      {format_event(event)}
                    </p>
                    <%= if event.payload["resonance"] do %>
                      <p class="text-xs text-base-content/50 mt-0.5">
                        resonance {event.payload["resonance"]}
                      </p>
                    <% end %>
                  </div>
                  <div class="shrink-0 text-right">
                    <span class="text-xs px-2 py-0.5 rounded bg-base-300 text-base-content/70">
                      {event.kind}
                    </span>
                    <p class="text-xs text-base-content/40 mt-1">{format_time(event.at)}</p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp format_event(event) do
    from = short_did(event.from)
    to = short_did(event.to)

    case event.kind do
      "encounter" -> "#{from} encountered #{to}"
      "gossip" -> "#{from} gossiped about #{to}"
      "world_summary" -> "Daily summary: #{event.payload["summarized_count"] || 0} events folded"
      "world_post" -> "#{from} posted to the world"
      _ -> event.kind
    end
  end

  defp short_did(nil), do: "the world"
  defp short_did("did:soul:z" <> rest), do: "Soul " <> String.slice(rest, 0, 6)
  defp short_did(other), do: other

  defp format_time(dt) do
    Calendar.strftime(dt, "%H:%M:%S")
  end
end
