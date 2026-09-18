defmodule SovereignSoulEngineWeb.CharacterLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.{
    Characters,
    Souls,
    Relationships,
    Memories,
    Ledger,
    Identity,
    Repo
  }
  alias SovereignSoulEngine.Social.SocialPost

  import Ecto.Query

  @impl true
  def mount(%{"id" => id_or_slug}, _session, socket) do
    character = find_character!(id_or_slug)

    socket =
      socket
      |> assign(:page_title, "#{character.name} — Soul Profile")
      |> assign(:character, character)
      |> assign_soul_data(character)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "character:#{character.id}")
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, SovereignSoulEngine.Social.SocialFeed.pubsub_topic())
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id_or_slug}, _uri, socket) do
    character = find_character!(id_or_slug)

    socket =
      socket
      |> assign(:character, character)
      |> assign_soul_data(character)

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
    memories = Memories.list_memories_for_character(socket.assigns.character.id) |> Enum.take(8)
    {:noreply, assign(socket, :memories, memories)}
  end

  def handle_info({:ledger_updated, _entry}, socket) do
    entries = Ledger.list_entries_for_character(socket.assigns.character.id) |> Enum.take(8)
    {:noreply, assign(socket, :ledger_entries, entries)}
  end

  def handle_info({:new_social_post, post}, socket) do
    if post.character_id == socket.assigns.character.id do
      recent_posts = [post | socket.assigns.recent_posts] |> Enum.take(5)
      {:noreply, assign(socket, :recent_posts, recent_posts)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp find_character!(param) do
    case Ecto.UUID.cast(param) do
      {:ok, uuid} -> Characters.get_character(uuid) || Characters.get_character_by_slug!(param)
      _ -> Characters.get_character_by_slug!(param)
    end
  end

  defp assign_soul_data(socket, character) do
    soul_profile = Souls.ensure_soul_vitality(character)
    emotional_state = Souls.get_emotional_state_by_character(character.id)
    somatic_state = Souls.get_somatic_state_by_character(character.id)

    relationships =
      from(r in Relationships.Relationship,
        where: r.source_character_id == ^character.id,
        preload: [:target_character],
        order_by: [desc: r.affinity]
      )
      |> Repo.all()

    memories = Memories.list_memories_for_character(character.id) |> Enum.take(8)
    ledger_entries = Ledger.list_entries_for_character(character.id) |> Enum.take(8)
    did_record = Identity.get_did_for_character(character.id)

    recent_posts =
      from(p in SocialPost,
        where: p.character_id == ^character.id,
        order_by: [desc: p.posted_at],
        limit: 5,
        preload: [:character]
      )
      |> Repo.all()

    socket
    |> assign(:soul_profile, soul_profile)
    |> assign(:emotional_state, emotional_state)
    |> assign(:somatic_state, somatic_state)
    |> assign(:relationships, relationships)
    |> assign(:memories, memories)
    |> assign(:ledger_entries, ledger_entries)
    |> assign(:did_record, did_record)
    |> assign(:recent_posts, recent_posts)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100 font-sans pb-16">
      <%!-- Top Sub-Navigation Header --%>
      <header class="border-b border-slate-800 bg-slate-900/90 backdrop-blur-md sticky top-0 z-40 px-4 sm:px-6 py-3 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <.link
            navigate={~p"/sse"}
            class="px-3 py-1.5 rounded-lg bg-slate-800/80 hover:bg-slate-700 text-slate-300 hover:text-white text-xs font-semibold flex items-center gap-1.5 transition-all"
          >
            <.icon name="hero-arrow-left" class="size-3.5" />
            <span>Dashboard</span>
          </.link>
          <.link
            navigate={~p"/sse/feed"}
            class="text-slate-400 hover:text-slate-200 text-xs hidden sm:inline transition-colors"
          >
            SoulBook Feed
          </.link>
          <span class="text-slate-600">/</span>
          <span class="text-xs font-bold text-amber-400">{@character.name}</span>
        </div>

        <div class="flex items-center gap-2">
          <.link
            navigate={~p"/sse/chat?character=#{@character.slug}"}
            class="px-4 py-1.5 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold text-xs shadow-md shadow-blue-500/20 flex items-center gap-1.5 transition-all"
          >
            <span>💬 Chat 1-on-1</span>
          </.link>
          <.link
            navigate={~p"/sse/acp"}
            class="px-3 py-1.5 rounded-xl bg-purple-600/20 hover:bg-purple-600/30 text-purple-300 border border-purple-500/30 font-semibold text-xs hidden sm:inline-flex items-center gap-1.5 transition-all"
          >
            <span>⚙️ Studio Tuning</span>
          </.link>
        </div>
      </header>

      <%!-- Main Container --%>
      <main class="max-w-6xl mx-auto px-4 sm:px-6 py-8 space-y-8">
        <%!-- Profile Hero Card --%>
        <section class="p-6 sm:p-8 rounded-3xl bg-slate-900/80 border border-slate-800 shadow-2xl relative overflow-hidden">
          <div class="absolute -right-20 -top-20 size-80 rounded-full bg-amber-500/5 blur-3xl pointer-events-none"></div>
          <div class="absolute -left-20 -bottom-20 size-80 rounded-full bg-purple-500/5 blur-3xl pointer-events-none"></div>

          <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6 relative z-10">
            <div class="flex items-start sm:items-center gap-5">
              <div class="size-20 rounded-2xl bg-gradient-to-tr from-amber-500 via-rose-500 to-purple-600 flex items-center justify-center font-extrabold text-3xl text-slate-950 shadow-xl shadow-amber-500/20 ring-4 ring-slate-800">
                {String.first(@character.name)}
              </div>
              <div class="space-y-1">
                <div class="flex flex-wrap items-center gap-2.5">
                  <h1 class="text-2xl sm:text-3xl font-black text-white tracking-tight">{@character.name}</h1>
                  <span class="px-2.5 py-0.5 rounded-full text-xs font-mono font-bold bg-amber-500/15 text-amber-300 border border-amber-500/30">
                    {@character.kind |> String.upcase()}
                  </span>
                  <span class="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-mono bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                    <span class="size-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                    <span>{@character.status |> String.upcase()}</span>
                  </span>
                </div>
                <p class="text-xs sm:text-sm font-mono text-slate-400">
                  @{String.downcase(@character.slug)} • Feannag's Rest
                </p>
                <p class="text-sm text-slate-300 max-w-2xl pt-1 leading-relaxed">
                  {@character.description || "A living, autonomous soul in the Soul Society world."}
                </p>
              </div>
            </div>

            <div class="flex flex-col items-start sm:items-end gap-2 shrink-0">
              <.link
                navigate={~p"/sse/chat?character=#{@character.slug}"}
                class="w-full sm:w-auto px-5 py-2.5 rounded-2xl bg-gradient-to-r from-amber-500 to-rose-500 hover:from-amber-400 hover:to-rose-400 text-slate-950 font-black text-sm shadow-xl shadow-amber-500/25 flex items-center justify-center gap-2 transition-all"
              >
                <span>💬 Start Companion Chat</span>
              </.link>
              <span class="text-[11px] font-mono text-slate-500">
                Memory Vault: {length(@memories)} Active Records
              </span>
            </div>
          </div>

          <%!-- Sovereign DID Pill --%>
          <%= if @did_record do %>
            <div class="mt-6 pt-6 border-t border-slate-800/80 flex flex-wrap items-center justify-between gap-3 text-xs">
              <div class="flex items-center gap-2 text-slate-400 font-mono">
                <span class="text-purple-400 font-bold">DID:</span>
                <span class="px-2 py-1 rounded-lg bg-slate-950 border border-slate-800 text-slate-300 font-mono text-[11px] select-all">
                  {@did_record.did}
                </span>
              </div>
              <span class="px-2.5 py-0.5 rounded-full text-[10px] font-mono bg-purple-950/60 border border-purple-800/40 text-purple-300">
                RFC-0002 Ed25519 Cryptographically Sealed
              </span>
            </div>
          <% end %>
        </section>

        <%!-- 2-Column Core Architecture Grid --%>
        <div class="grid grid-cols-1 lg:grid-cols-12 gap-8">
          <%!-- LEFT COLUMN: Persona & Psychological Blueprint (7 cols on lg) --%>
          <div class="lg:col-span-7 space-y-8">
            <%!-- Soul Profile Card --%>
            <%= if @soul_profile do %>
              <section class="p-6 rounded-3xl bg-slate-900/70 border border-slate-800 shadow-xl space-y-5">
                <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                  <div class="flex items-center gap-2">
                    <span class="text-base">🧬</span>
                    <h2 class="font-extrabold text-sm text-white">Soul Blueprint & Persona</h2>
                  </div>
                  <span class="text-[10px] font-mono text-amber-400">Enduring Core</span>
                </div>

                <div class="space-y-4 text-xs">
                  <div>
                    <h3 class="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                      Identity & Archetype
                    </h3>
                    <p class="text-slate-200 leading-relaxed bg-slate-950 p-3 rounded-xl border border-slate-800/80">
                      {@soul_profile.identity_summary || @character.description}
                    </p>
                  </div>

                  <div>
                    <h3 class="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                      Speech Style & Tone
                    </h3>
                    <p class="text-slate-200 bg-slate-950 p-3 rounded-xl border border-slate-800/80 font-mono text-[11px]">
                      {@soul_profile.speech_style || "Direct, guarded, authentic"}
                    </p>
                  </div>

                  <%!-- Personality Traits --%>
                  <div>
                    <h3 class="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1.5">
                      Personality Dimensions
                    </h3>
                    <div class="flex flex-wrap gap-2">
                      <%= for {trait, val} <- @soul_profile.personality_traits || %{} do %>
                        <span class="px-2.5 py-1 rounded-xl bg-purple-500/10 border border-purple-500/20 text-purple-300 font-mono text-[11px]">
                          {trait}: <strong class="text-white">{to_string(val)}</strong>
                        </span>
                      <% end %>
                    </div>
                  </div>

                  <%!-- Core Values --%>
                  <div>
                    <h3 class="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1.5">
                      Core Values
                    </h3>
                    <div class="flex flex-wrap gap-2">
                      <%= for val <- @soul_profile.core_values || [] do %>
                        <span class="px-2.5 py-1 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-300 text-[11px] font-semibold">
                          ✦ {val}
                        </span>
                      <% end %>
                    </div>
                  </div>

                  <%!-- Fears & Desires Grid --%>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                    <div class="p-3 rounded-xl bg-slate-950 border border-slate-800/80 space-y-1">
                      <h4 class="text-[10px] font-bold text-rose-400 uppercase">Fears & Wounds</h4>
                      <ul class="space-y-1 text-[11px] text-slate-400">
                        <%= for f <- @soul_profile.fears || [] do %>
                          <li>• {f}</li>
                        <% end %>
                        <%= if (@soul_profile.fears || []) == [] do %>
                          <li class="italic text-slate-600">None declared</li>
                        <% end %>
                      </ul>
                    </div>

                    <div class="p-3 rounded-xl bg-slate-950 border border-slate-800/80 space-y-1">
                      <h4 class="text-[10px] font-bold text-emerald-400 uppercase">Active Motives</h4>
                      <ul class="space-y-1 text-[11px] text-slate-400">
                        <%= for d <- @soul_profile.desires || [] do %>
                          <li>• {d}</li>
                        <% end %>
                        <%= if (@soul_profile.desires || []) == [] do %>
                          <li class="italic text-slate-600">Survive and maintain autonomy</li>
                        <% end %>
                      </ul>
                    </div>
                  </div>
                </div>
              </section>
            <% end %>

            <%!-- Recent SoulBook Posts by this Character --%>
            <section class="p-6 rounded-3xl bg-slate-900/70 border border-slate-800 shadow-xl space-y-4">
              <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                <div class="flex items-center gap-2">
                  <span class="text-base">📰</span>
                  <h2 class="font-extrabold text-sm text-white">SoulBook Wall Activity</h2>
                </div>
                <.link navigate={~p"/sse/feed"} class="text-xs text-amber-400 hover:underline">
                  Main Feed →
                </.link>
              </div>

              <%= if @recent_posts == [] do %>
                <div class="text-center py-6 text-xs text-slate-500 italic">
                  {@character.name} hasn't published to the wall recently.
                </div>
              <% else %>
                <div class="space-y-3">
                  <%= for post <- @recent_posts do %>
                    <div class="p-3.5 rounded-2xl bg-slate-950 border border-slate-800/80 space-y-2">
                      <div class="flex items-center justify-between text-[10px] text-slate-500">
                        <span>📍 {(post.metadata && post.metadata["location"]) || "Feannag's Rest"}</span>
                        <span>{post.inserted_at}</span>
                      </div>
                      <p class="text-xs text-slate-200 leading-relaxed font-sans">
                        "{post.content}"
                      </p>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </section>
          </div>

          <%!-- RIGHT COLUMN: Neurochemistry, Town Ties & Memories (5 cols on lg) --%>
          <div class="lg:col-span-5 space-y-8">
            <%!-- Live Neurochemistry & Somatics --%>
            <%= if @emotional_state do %>
              <section class="p-6 rounded-3xl bg-slate-900/70 border border-slate-800 shadow-xl space-y-4">
                <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                  <div class="flex items-center gap-2">
                    <span class="text-base">🧠</span>
                    <h2 class="font-extrabold text-sm text-white">Emotional State & Neurochemistry</h2>
                  </div>
                  <span class="size-2 rounded-full bg-emerald-400 animate-pulse"></span>
                </div>

                <div class="space-y-3">
                  <%= for {label, key, color} <- emotion_fields() do %>
                    <% val = Map.get(@emotional_state, key) || 0 %>
                    <div class="space-y-1">
                      <div class="flex justify-between text-[11px]">
                        <span class="text-slate-400 font-medium">{label}</span>
                        <span class="font-mono font-bold text-white">{val}%</span>
                      </div>
                      <div class="h-2 w-full rounded-full bg-slate-950 overflow-hidden border border-slate-800">
                        <div
                          class="h-full rounded-full transition-all duration-700"
                          style={"width: #{val}%; background-color: #{color}"}
                        >
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%!-- Somatics Strip --%>
                <%= if @somatic_state do %>
                  <div class="mt-4 pt-4 border-t border-slate-800/80 grid grid-cols-3 gap-2 text-center text-[10px]">
                    <div class="p-2 rounded-xl bg-slate-950 border border-slate-800/80">
                      <span class="text-slate-500 block">Fatigue</span>
                      <strong class="text-amber-400 text-xs font-mono">{@somatic_state.fatigue}%</strong>
                    </div>
                    <div class="p-2 rounded-xl bg-slate-950 border border-slate-800/80">
                      <span class="text-slate-500 block">Stamina</span>
                      <strong class="text-emerald-400 text-xs font-mono">{@soul_profile.social_stamina || 100}%</strong>
                    </div>
                    <div class="p-2 rounded-xl bg-slate-950 border border-slate-800/80">
                      <span class="text-slate-500 block">Hunger</span>
                      <strong class="text-blue-400 text-xs font-mono">{@somatic_state.hunger}%</strong>
                    </div>
                  </div>
                <% end %>
              </section>
            <% end %>

            <%!-- Town Relationships & Affinity Graph --%>
            <section class="p-6 rounded-3xl bg-slate-900/70 border border-slate-800 shadow-xl space-y-4">
              <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                <div class="flex items-center gap-2">
                  <span class="text-base">🤝</span>
                  <h2 class="font-extrabold text-sm text-white">Town Ties & Affinities</h2>
                </div>
                <span class="text-[10px] font-mono text-slate-500">{length(@relationships)} Recorded</span>
              </div>

              <%= if @relationships == [] do %>
                <div class="text-center py-6 text-xs text-slate-500 italic">
                  No relationship vectors recorded yet.
                </div>
              <% else %>
                <div class="space-y-2.5 max-h-80 overflow-y-auto pr-1">
                  <%= for rel <- @relationships do %>
                    <div class="p-3 rounded-2xl bg-slate-950 border border-slate-800/80 flex items-center justify-between gap-3 text-xs">
                      <div class="min-w-0">
                        <div class="font-bold text-white truncate">
                          {if rel.target_character, do: rel.target_character.name, else: "Companion"}
                        </div>
                        <div class="text-[10px] text-slate-500">
                          {rel.relationship_type || "Town Peer"}
                        </div>
                      </div>

                      <div class="flex items-center gap-2 shrink-0">
                        <span class={[
                          "px-2 py-0.5 rounded-lg text-xs font-mono font-bold",
                          rel_val_class(rel.affinity || 0)
                        ]}>
                          {rel.affinity || 0}
                        </span>
                        <%= if rel.target_character do %>
                          <.link
                            navigate={~p"/sse/chat?character=#{rel.target_character.slug}"}
                            class="px-2 py-0.5 rounded-lg bg-blue-600/20 hover:bg-blue-600/40 text-blue-300 font-bold text-[10px] border border-blue-500/30"
                          >
                            Chat
                          </.link>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </section>

            <%!-- Recent Memories Timeline --%>
            <section class="p-6 rounded-3xl bg-slate-900/70 border border-slate-800 shadow-xl space-y-4">
              <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                <div class="flex items-center gap-2">
                  <span class="text-base">📜</span>
                  <h2 class="font-extrabold text-sm text-white">Episodic Memory Vault</h2>
                </div>
                <.link navigate={~p"/sse/memories"} class="text-xs text-primary hover:underline">
                  Full Vault →
                </.link>
              </div>

              <%= if @memories == [] do %>
                <div class="text-center py-6 text-xs text-slate-500 italic">
                  Memory vault is clear.
                </div>
              <% else %>
                <div class="space-y-2 max-h-72 overflow-y-auto pr-1">
                  <%= for mem <- @memories do %>
                    <div class="p-3 rounded-2xl bg-slate-950 border border-slate-800/80 space-y-1 text-xs">
                      <p class="text-slate-300 leading-snug">{mem.summary}</p>
                      <div class="flex items-center justify-between text-[10px] text-slate-500">
                        <span class="px-1.5 py-0.5 rounded bg-slate-900 font-mono">{mem.category}</span>
                        <span>Intensity: {mem.emotional_intensity || 0}%</span>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </section>

            <%!-- Recent Ledger Entries --%>
            <section class="p-6 rounded-3xl bg-slate-900/70 border border-slate-800 shadow-xl space-y-4">
              <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                <div class="flex items-center gap-2">
                  <span class="text-base">⚖️</span>
                  <h2 class="font-extrabold text-sm text-white">Recent Ledger Entries</h2>
                </div>
                <.link navigate={~p"/sse/ledger"} class="text-xs text-primary hover:underline">
                  Full Timeline →
                </.link>
              </div>

              <%= if @ledger_entries == [] do %>
                <div class="text-center py-6 text-xs text-slate-500 italic">
                  No ledger actions recorded yet.
                </div>
              <% else %>
                <div class="space-y-2 max-h-72 overflow-y-auto pr-1">
                  <%= for entry <- @ledger_entries do %>
                    <div class="p-3 rounded-2xl bg-slate-950 border border-slate-800/80 space-y-1 text-xs">
                      <div class="flex items-center justify-between text-[11px] text-white font-bold">
                        <span>{entry.label}</span>
                        <span class="text-slate-500 font-mono text-[10px]">{format_time(entry.inserted_at)}</span>
                      </div>
                      <p class="text-slate-400 text-[11px]">{entry.summary}</p>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </section>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp emotion_fields do
    [
      {"Anger", :anger, "#ef4444"},
      {"Fear", :fear, "#a855f7"},
      {"Confidence", :confidence, "#8b5cf6"},
      {"Trust", :trust, "#10b981"},
      {"Joy", :joy, "#3b82f6"},
      {"Curiosity", :curiosity, "#06b6d4"},
      {"Attachment", :attachment, "#ec4899"},
      {"Stress", :stress, "#f59e0b"}
    ]
  end

  defp rel_val_class(val) when val >= 40, do: "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
  defp rel_val_class(val) when val > 0, do: "bg-blue-500/20 text-blue-400 border border-blue-500/30"
  defp rel_val_class(val) when val < 0, do: "bg-rose-500/20 text-rose-400 border border-rose-500/30"
  defp rel_val_class(_), do: "bg-slate-900 text-slate-400 border border-slate-800"

  defp format_time(nil), do: "--"
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")
end
