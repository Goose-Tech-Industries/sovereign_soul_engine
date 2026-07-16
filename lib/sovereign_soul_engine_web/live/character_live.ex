defmodule SovereignSoulEngineWeb.CharacterLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Ledger

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    character = Characters.get_character!(id)

    socket =
      socket
      |> assign(:page_title, "#{character.name} — Soul Profile")
      |> assign(:character, character)
      |> assign_soul_data(character)
      |> assign(:memories, Memories.list_memories_for_character(character.id) |> Enum.take(10))
      |> assign(:ledger_entries, Ledger.list_entries_for_character(character.id) |> Enum.take(10))

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "character:#{id}")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    character = Characters.get_character!(id)
    socket = assign(socket, :character, character) |> assign_soul_data(character)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:emotion_updated, _data}, socket) do
    {:noreply, assign_soul_data(socket, socket.assigns.character)}
  end

  def handle_info({:relationship_updated, _data}, socket) do
    {:noreply, assign_soul_data(socket, socket.assigns.character)}
  end

  def handle_info({:memory_created, _mem}, socket) do
    memories = Memories.list_memories_for_character(socket.assigns.character.id) |> Enum.take(10)
    {:noreply, assign(socket, :memories, memories)}
  end

  def handle_info({:ledger_updated, _entry}, socket) do
    entries = Ledger.list_entries_for_character(socket.assigns.character.id) |> Enum.take(10)
    {:noreply, assign(socket, :ledger_entries, entries)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_soul_data(socket, character) do
    soul_profile = Souls.get_soul_profile_by_character(character.id)
    emotional_state = Souls.get_emotional_state_by_character(character.id)
    relationships = Relationships.list_relationships_for_source(character.id)

    socket
    |> assign(:soul_profile, soul_profile)
    |> assign(:emotional_state, emotional_state)
    |> assign(:relationships, relationships)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <%!-- Back nav --%>
        <div>
          <.link
            navigate={~p"/sse"}
            class="text-sm text-base-content/60 hover:text-base-content transition-colors"
          >
            <.icon name="hero-arrow-left" class="size-4 inline" /> Dashboard
          </.link>
        </div>

        <%!-- Character Header --%>
        <header>
          <div class="flex items-center gap-3">
            <h1 class="text-3xl font-bold text-base-content">{@character.name}</h1>
            <span class={[
              "text-xs px-2 py-0.5 rounded-full font-medium",
              kind_badge(@character.kind)
            ]}>
              {@character.kind}
            </span>
            <span class={[
              "inline-block w-2 h-2 rounded-full",
              @character.status == "active" && "bg-emerald-500",
              @character.status == "inactive" && "bg-gray-400"
            ]}>
            </span>
            <span class="text-xs text-base-content/50">{@character.status}</span>
          </div>
          <p class="mt-1 text-base-content/70">{@character.description}</p>
        </header>

        <div class="grid gap-6 lg:grid-cols-2">
          <%!-- Soul Profile --%>
          <%= if @soul_profile do %>
            <section class="p-4 rounded-xl border border-base-300 bg-base-200/30">
              <h2 class="text-lg font-semibold text-base-content mb-3">Soul Profile</h2>

              <div class="space-y-3">
                <div>
                  <h3 class="text-xs font-medium text-base-content/50 uppercase tracking-wider">
                    Identity
                  </h3>
                  <p class="text-sm text-base-content mt-1">{@soul_profile.identity_summary}</p>
                </div>

                <div>
                  <h3 class="text-xs font-medium text-base-content/50 uppercase tracking-wider">
                    Speech Style
                  </h3>
                  <p class="text-sm text-base-content mt-1">{@soul_profile.speech_style}</p>
                </div>

                <div>
                  <h3 class="text-xs font-medium text-base-content/50 uppercase tracking-wider">
                    Personality
                  </h3>
                  <div class="flex flex-wrap gap-1.5 mt-1">
                    <%= for {trait, val} <- @soul_profile.personality_traits || %{} do %>
                      <span class="text-xs px-2 py-0.5 rounded bg-purple-500/15 text-purple-300">
                        {trait} {val}
                      </span>
                    <% end %>
                  </div>
                </div>

                <div>
                  <h3 class="text-xs font-medium text-base-content/50 uppercase tracking-wider">
                    Core Values
                  </h3>
                  <div class="flex flex-wrap gap-1.5 mt-1">
                    <%= for val <- @soul_profile.core_values || [] do %>
                      <span class="text-xs px-2 py-0.5 rounded bg-amber-500/15 text-amber-300">
                        {val}
                      </span>
                    <% end %>
                  </div>
                </div>

                <div>
                  <h3 class="text-xs font-medium text-base-content/50 uppercase tracking-wider">
                    Fears
                  </h3>
                  <div class="flex flex-wrap gap-1.5 mt-1">
                    <%= for fear <- @soul_profile.fears || [] do %>
                      <span class="text-xs px-2 py-0.5 rounded bg-red-500/15 text-red-300">
                        {fear}
                      </span>
                    <% end %>
                  </div>
                </div>

                <div>
                  <h3 class="text-xs font-medium text-base-content/50 uppercase tracking-wider">
                    Desires
                  </h3>
                  <div class="flex flex-wrap gap-1.5 mt-1">
                    <%= for desire <- @soul_profile.desires || [] do %>
                      <span class="text-xs px-2 py-0.5 rounded bg-emerald-500/15 text-emerald-300">
                        {desire}
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            </section>
          <% end %>

          <%!-- Emotional State --%>
          <%= if @emotional_state do %>
            <section class="p-4 rounded-xl border border-base-300 bg-base-200/30">
              <h2 class="text-lg font-semibold text-base-content mb-3">Emotional State</h2>
              <div class="space-y-2">
                <%= for {label, key, color} <- emotion_fields() do %>
                  <div>
                    <div class="flex justify-between text-xs mb-1">
                      <span class="text-base-content/60">{label}</span>
                      <span class="text-base-content/80">{Map.get(@emotional_state, key) || 0}</span>
                    </div>
                    <div class="h-2 w-full rounded-full bg-base-300 overflow-hidden">
                      <div
                        class="h-full rounded-full transition-all duration-500"
                        style={"width: #{Map.get(@emotional_state, key) || 0}%; background-color: #{color}"}
                      >
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </section>
          <% end %>

          <%!-- Relationships --%>
          <section class="p-4 rounded-xl border border-base-300 bg-base-200/30">
            <h2 class="text-lg font-semibold text-base-content mb-3">Relationships</h2>
            <div :if={@relationships == []} class="text-sm text-base-content/50 italic">
              No relationships recorded.
            </div>
            <div class="space-y-3">
              <%= for rel <- @relationships do %>
                <div class="p-3 rounded-lg border border-base-300 bg-base-200/50">
                  <h3 class="text-sm font-medium text-base-content">
                    Toward {rel.target_character_id}
                  </h3>
                  <div class="grid grid-cols-5 gap-1 mt-2">
                    <%= for {label, key} <- rel_fields() do %>
                      <div class="text-center">
                        <div class="text-xs text-base-content/50">{label}</div>
                        <div class={[
                          "text-sm font-medium mt-0.5",
                          rel_val_class(Map.get(rel, key) || 0)
                        ]}>
                          {Map.get(rel, key) || 0}
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </section>

          <%!-- Recent Memories --%>
          <section class="p-4 rounded-xl border border-base-300 bg-base-200/30">
            <div class="flex items-center justify-between mb-3">
              <h2 class="text-lg font-semibold text-base-content">Recent Memories</h2>
              <.link navigate={~p"/sse/memories"} class="text-xs text-primary hover:underline">
                Memory Vault
              </.link>
            </div>
            <div :if={@memories == []} class="text-sm text-base-content/50 italic">
              No memories yet.
            </div>
            <div class="space-y-2">
              <%= for mem <- @memories do %>
                <div class="p-2.5 rounded-lg border border-base-300 bg-base-200/50">
                  <div class="flex items-start justify-between gap-2">
                    <p class="text-sm text-base-content truncate">{mem.summary}</p>
                    <span class="shrink-0 text-xs px-1.5 py-0.5 rounded bg-base-300 text-base-content/60">
                      {mem.category}
                    </span>
                  </div>
                  <div class="flex items-center gap-3 mt-1.5 text-xs text-base-content/50">
                    <span>Importance: {mem.importance || 0}</span>
                    <span>Intensity: {mem.emotional_intensity || 0}</span>
                    <span :if={mem.is_resolved} class="text-emerald-400">Resolved</span>
                    <span :if={!mem.is_resolved} class="text-amber-400">Unresolved</span>
                  </div>
                </div>
              <% end %>
            </div>
          </section>
        </div>

        <%!-- Ledger --%>
        <section class="p-4 rounded-xl border border-base-300 bg-base-200/30">
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-lg font-semibold text-base-content">Recent Ledger Entries</h2>
            <.link navigate={~p"/sse/ledger"} class="text-xs text-primary hover:underline">
              Full Timeline
            </.link>
          </div>
          <div class="space-y-1.5">
            <%= for entry <- @ledger_entries do %>
              <div class="p-2.5 rounded border border-base-300 bg-base-200/50 flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="text-sm text-base-content">{entry.label}</p>
                  <p class="text-xs text-base-content/60 mt-0.5">{entry.summary}</p>
                </div>
                <span class="shrink-0 text-xs text-base-content/40">
                  {format_time(entry.inserted_at)}
                </span>
              </div>
            <% end %>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp kind_badge("npc"), do: "bg-purple-500/20 text-purple-400"
  defp kind_badge("player"), do: "bg-blue-500/20 text-blue-400"
  defp kind_badge(_), do: "bg-base-300 text-base-content/60"

  defp emotion_fields do
    [
      {"Anger", :anger, "#ef4444"},
      {"Fear", :fear, "#a855f7"},
      {"Stress", :stress, "#f59e0b"},
      {"Gratitude", :gratitude, "#10b981"},
      {"Confidence", :confidence, "#3b82f6"},
      {"Sadness", :sadness, "#6b7280"},
      {"Curiosity", :curiosity, "#06b6d4"},
      {"Attachment", :attachment, "#ec4899"}
    ]
  end

  defp rel_fields do
    [
      {"Affinity", :affinity},
      {"Trust", :trust},
      {"Respect", :respect},
      {"Fear", :fear},
      {"Anger", :anger},
      {"Gratitude", :gratitude},
      {"Debt", :debt},
      {"Softening", :softening},
      {"Hardening", :hardening},
      {"Wound", :wound}
    ]
  end

  defp rel_val_class(val) when val > 0, do: "text-emerald-400"
  defp rel_val_class(val) when val < 0, do: "text-red-400"
  defp rel_val_class(_), do: "text-base-content/60"

  defp format_time(nil), do: "--"
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")
end
