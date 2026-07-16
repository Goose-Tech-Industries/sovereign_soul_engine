defmodule SovereignSoulEngineWeb.DashboardLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Ledger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "dashboard")
    end

    socket =
      socket
      |> assign(:page_title, "Sovereign Soul Engine")
      |> assign_characters()
      |> assign_scenes()
      |> assign_ledger_entries()

    {:ok, socket}
  end

  @impl true
  def handle_info({:ledger_updated, _entry}, socket) do
    {:noreply, assign_ledger_entries(socket)}
  end

  def handle_info({:character_created, _char}, socket) do
    {:noreply, assign_characters(socket)}
  end

  def handle_info({:scene_created, _scene}, socket) do
    {:noreply, assign_scenes(socket)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_characters(socket) do
    assign(socket, :characters, Characters.list_characters())
  end

  defp assign_scenes(socket) do
    assign(socket, :scenes, Scenes.list_scenes())
  end

  defp assign_ledger_entries(socket) do
    entries = Ledger.list_entries() |> Enum.take(20)
    assign(socket, :ledger_entries, entries)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <%!-- Header --%>
        <header class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold tracking-tight text-base-content">
              Sovereign Soul Engine
            </h1>
            <p class="mt-1 text-sm text-base-content/60">
              Soul Core — Deterministic Character Runtime
            </p>
          </div>
          <div class="flex gap-3">
            <.link navigate={~p"/sse/ledger"} class="btn btn-ghost btn-sm">
              <.icon name="hero-book-open" class="size-4" /> Soul Ledger
            </.link>
            <.link navigate={~p"/sse/memories"} class="btn btn-ghost btn-sm">
              <.icon name="hero-archive-box" class="size-4" /> Memory Vault
            </.link>
          </div>
        </header>

        <%!-- Characters Section --%>
        <section>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold text-base-content">Characters</h2>
          </div>
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <%= for character <- @characters do %>
              <.link
                navigate={~p"/sse/characters/#{character.id}"}
                class="block p-4 rounded-xl border border-base-300 bg-base-200/50 hover:bg-base-200 transition-colors"
              >
                <div class="flex items-start justify-between">
                  <div>
                    <h3 class="font-semibold text-base-content">{character.name}</h3>
                    <p class="text-sm text-base-content/60 mt-0.5">{character.description}</p>
                  </div>
                  <span class={[
                    "text-xs px-2 py-0.5 rounded-full font-medium",
                    kind_badge_class(character.kind)
                  ]}>
                    {character.kind}
                  </span>
                </div>
                <div class="flex items-center gap-3 mt-3 text-xs text-base-content/50">
                  <span class={[
                    "inline-block w-2 h-2 rounded-full",
                    character.status == "active" && "bg-emerald-500",
                    character.status == "inactive" && "bg-gray-400",
                    character.status == "archived" && "bg-red-400"
                  ]}>
                  </span>
                  {character.status}
                </div>
              </.link>
            <% end %>
          </div>
        </section>

        <%!-- Scenes Section --%>
        <section>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold text-base-content">Scenes</h2>
          </div>
          <div :if={@scenes == []} class="text-sm text-base-content/50 italic">
            No scenes yet. Create characters above, then seed a scene from the console.
          </div>
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <%= for scene <- @scenes do %>
              <.link
                navigate={~p"/sse/scenes/#{scene.id}"}
                class="block p-4 rounded-xl border border-base-300 bg-base-200/50 hover:bg-base-200 transition-colors"
              >
                <h3 class="font-semibold text-base-content">{scene.title}</h3>
                <p class="text-sm text-base-content/60 mt-0.5">{scene.location}</p>
                <div class="flex items-center gap-3 mt-3 text-xs text-base-content/50">
                  <span class={[
                    "inline-block w-2 h-2 rounded-full",
                    scene.status == "active" && "bg-emerald-500",
                    scene.status == "pending" && "bg-amber-400",
                    scene.status == "completed" && "bg-blue-400",
                    !(scene.status in ["active", "pending", "completed"]) && "bg-gray-400"
                  ]}>
                  </span>
                  {scene.status}
                </div>
              </.link>
            <% end %>
          </div>
        </section>

        <%!-- Recent Ledger --%>
        <section>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold text-base-content">Recent Soul Ledger</h2>
            <.link navigate={~p"/sse/ledger"} class="text-sm text-primary hover:underline">
              View all
            </.link>
          </div>
          <div :if={@ledger_entries == []} class="text-sm text-base-content/50 italic">
            No ledger entries yet. Inject events from a scene to generate entries.
          </div>
          <div class="space-y-2">
            <%= for entry <- @ledger_entries do %>
              <div class="p-3 rounded-lg border border-base-300 bg-base-200/30">
                <div class="flex items-start justify-between gap-4">
                  <div class="min-w-0">
                    <p class="text-sm font-medium text-base-content truncate">{entry.label}</p>
                    <p class="text-xs text-base-content/60 mt-0.5 truncate">{entry.summary}</p>
                  </div>
                  <div class="shrink-0 text-right">
                    <span class="text-xs px-2 py-0.5 rounded bg-base-300 text-base-content/70">
                      {entry.entry_type}
                    </span>
                    <p class="text-xs text-base-content/40 mt-1">
                      {format_time(entry.inserted_at)}
                    </p>
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

  defp kind_badge_class("npc"), do: "bg-purple-500/20 text-purple-400"
  defp kind_badge_class("player"), do: "bg-blue-500/20 text-blue-400"
  defp kind_badge_class("system"), do: "bg-gray-500/20 text-gray-400"
  defp kind_badge_class("creature"), do: "bg-emerald-500/20 text-emerald-400"
  defp kind_badge_class(_), do: "bg-base-300 text-base-content/60"

  defp format_time(nil), do: "--"
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")
end
