defmodule SovereignSoulEngineWeb.SoulLedgerLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Ledger
  alias SovereignSoulEngine.Characters

  @impl true
  def mount(_params, _session, socket) do
    entries = Ledger.list_entries() |> Enum.take(50)

    socket =
      socket
      |> assign(:page_title, "Soul Ledger — Timeline")
      |> assign(:ledger_entries, entries)
      |> assign(:filter_character_id, nil)
      |> assign(:characters, Characters.list_characters())

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "ledger")
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:ledger_updated, _entry}, socket) do
    entries = fetch_entries(socket)
    {:noreply, assign(socket, :ledger_entries, entries)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("filter_character", %{"character_id" => ""}, socket) do
    entries = Ledger.list_entries() |> Enum.take(50)
    {:noreply, assign(socket, :ledger_entries, entries) |> assign(:filter_character_id, nil)}
  end

  def handle_event("filter_character", %{"character_id" => id}, socket) do
    entries = Ledger.list_entries_for_character(id) |> Enum.take(50)
    {:noreply, assign(socket, :ledger_entries, entries) |> assign(:filter_character_id, id)}
  end

  defp fetch_entries(socket) do
    if socket.assigns.filter_character_id do
      Ledger.list_entries_for_character(socket.assigns.filter_character_id) |> Enum.take(50)
    else
      Ledger.list_entries() |> Enum.take(50)
    end
  end

  defp character_name(characters, id) do
    char = Enum.find(characters, &(&1.id == id))
    if char, do: char.name, else: nil
  end

  defp delta_display(entry) do
    delta = entry.delta || %{}
    _before_state = entry.before_state || %{}
    after_state = entry.after_state || %{}

    changes =
      Map.take(after_state, Map.keys(delta))
      |> Enum.reject(fn {k, _} -> String.contains?(to_string(k), "id") end)

    changes
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <.link
              navigate={~p"/sse"}
              class="text-sm text-base-content/60 hover:text-base-content transition-colors"
            >
              <.icon name="hero-arrow-left" class="size-4 inline" /> Dashboard
            </.link>
            <h1 class="text-2xl font-bold text-base-content mt-1">Soul Ledger</h1>
            <p class="text-sm text-base-content/50 mt-0.5">
              Immutable timeline of all canonical soul mutations
            </p>
          </div>
          <div class="flex gap-2">
            <form phx-change="filter_character" id="ledger-filter-form">
              <select
                name="character_id"
                id="ledger-filter"
                class="text-sm rounded-lg border border-base-300 bg-base-200 px-3 py-1.5 text-base-content"
              >
                <option value="">All Characters</option>
                <%= for char <- @characters do %>
                  <option value={char.id} selected={@filter_character_id == char.id}>
                    {char.name}
                  </option>
                <% end %>
              </select>
            </form>
          </div>
        </div>

        <%!-- Ledger Timeline --%>
        <div :if={@ledger_entries == []} class="p-8 text-center rounded-xl border border-base-300">
          <p class="text-base-content/50">
            No ledger entries yet. Inject events from a scene to populate the ledger.
          </p>
        </div>

        <div class="relative">
          <div class="absolute left-5 top-0 bottom-0 w-px bg-base-300"></div>
          <div class="space-y-4">
            <%= for entry <- @ledger_entries do %>
              <div class="relative pl-12">
                <div class={[
                  "absolute left-3.5 top-2 w-3 h-3 rounded-full border-2",
                  entry_type_dot(entry.entry_type)
                ]}>
                </div>

                <div class="p-3 rounded-lg border border-base-300 bg-base-200/30">
                  <div class="flex items-start justify-between gap-3">
                    <div class="min-w-0 flex-1">
                      <div class="flex items-center gap-2 mb-1">
                        <span class="text-sm font-semibold text-base-content">{entry.label}</span>
                        <span class="text-xs px-1.5 py-0.5 rounded bg-base-300 text-base-content/60">
                          {entry.entry_type}
                        </span>
                      </div>
                      <p class="text-sm text-base-content/70">{entry.summary}</p>

                      <div class="mt-2 grid grid-cols-2 sm:grid-cols-3 gap-1">
                        <%= for {key, val} <- delta_display(entry) do %>
                          <div class="text-xs">
                            <span class="text-base-content/50">{key}: </span>
                            <span class="text-base-content/80">{inspect(val)}</span>
                          </div>
                        <% end %>
                      </div>

                      <div :if={entry.reason} class="mt-1 text-xs text-base-content/40">
                        Reason: {entry.reason}
                      </div>
                    </div>

                    <div class="shrink-0 text-right">
                      <p class="text-xs text-base-content/40">
                        {format_time(entry.inserted_at)}
                      </p>
                      <p
                        :if={character_name(@characters, entry.character_id)}
                        class="text-xs text-primary/70 mt-0.5"
                      >
                        {character_name(@characters, entry.character_id)}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp entry_type_dot(type) when type in [:emotion_changed, :emotion_created],
    do: "bg-fuchsia-400 border-fuchsia-600"

  defp entry_type_dot(type) when type in [:relationship_changed, :relationship_created],
    do: "bg-blue-400 border-blue-600"

  defp entry_type_dot(:memory_created), do: "bg-emerald-400 border-emerald-600"
  defp entry_type_dot(:scene_message_created), do: "bg-amber-400 border-amber-600"
  defp entry_type_dot(:event_injected), do: "bg-orange-400 border-orange-600"

  defp entry_type_dot(type) when type in [:action_resolved, :action_proposed],
    do: "bg-cyan-400 border-cyan-600"

  defp entry_type_dot(type) when type in [:action_rejected], do: "bg-red-400 border-red-600"
  defp entry_type_dot(_), do: "bg-gray-400 border-gray-600"

  defp format_time(nil), do: "--"
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")
end
