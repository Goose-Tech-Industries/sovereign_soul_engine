defmodule SovereignSoulEngineWeb.AcpModerationLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.{Moderation, Social.SocialFeed, World, Characters}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, SocialFeed.pubsub_topic())
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "world:events")
    end

    socket =
      socket
      |> assign(:page_title, "Content Moderation & Oversight — ACP")
      |> assign(:maturity_rating, Moderation.get_maturity_rating())
      |> assign(:blocked_terms, Moderation.blocked_terms())
      |> assign(:muted_dids, Moderation.list_muted_dids())
      |> assign(:recent_posts, SocialFeed.list_recent_posts(limit: 30))
      |> assign(:recent_events, World.list_recent_events(limit: 30))
      |> assign(:active_tab, "posts")
      |> assign(:term_input, "")
      |> assign(:did_input, "")
      |> assign(:action_feedback, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("set_maturity_rating", %{"rating" => rating}, socket) do
    Moderation.set_maturity_rating(rating)

    {:noreply,
     socket
     |> assign(:maturity_rating, rating)
     |> assign(:action_feedback, "Maturity rating updated to #{String.upcase(rating)}")}
  end

  @impl true
  def handle_event("add_term", %{"term" => term}, socket) do
    clean_term = String.trim(term)

    if clean_term != "" do
      Moderation.add_blocked_term(clean_term)

      {:noreply,
       socket
       |> assign(:blocked_terms, Moderation.blocked_terms())
       |> assign(:term_input, "")
       |> assign(:action_feedback, "Blocked term added: \"#{clean_term}\"")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_term", %{"term" => term}, socket) do
    Moderation.remove_blocked_term(term)

    {:noreply,
     socket
     |> assign(:blocked_terms, Moderation.blocked_terms())
     |> assign(:action_feedback, "Removed blocked term: \"#{term}\"")}
  end

  @impl true
  def handle_event("mute_did", %{"did" => did}, socket) do
    clean_did = String.trim(did)

    if clean_did != "" do
      Moderation.mute_did(clean_did)

      {:noreply,
       socket
       |> assign(:muted_dids, Moderation.list_muted_dids())
       |> assign(:did_input, "")
       |> assign(:action_feedback, "Soul silenced: #{clean_did}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unmute_did", %{"did" => did}, socket) do
    Moderation.unmute_did(did)

    {:noreply,
     socket
     |> assign(:muted_dids, Moderation.list_muted_dids())
     |> assign(:action_feedback, "Soul unsilenced: #{did}")}
  end

  @impl true
  def handle_event("mute_character", %{"character_id" => char_id}, socket) do
    character = Characters.get_character(char_id)

    did =
      (character && character.metadata && character.metadata["did"]) ||
        "did:soul:#{char_id}"

    Moderation.mute_did(did)

    {:noreply,
     socket
     |> assign(:muted_dids, Moderation.list_muted_dids())
     |> assign(:action_feedback, "Muted #{character && character.name || char_id} (#{did})")}
  end

  @impl true
  def handle_event("delete_post", %{"id" => id}, socket) do
    SocialFeed.delete_post(id)

    {:noreply,
     socket
     |> assign(:recent_posts, Enum.reject(socket.assigns.recent_posts, &(&1.id == id)))
     |> assign(:action_feedback, "Social post deleted.")}
  end

  @impl true
  def handle_event("delete_event", %{"id" => id}, socket) do
    World.delete_event(id)

    {:noreply,
     socket
     |> assign(:recent_events, Enum.reject(socket.assigns.recent_events, &(&1.id == id)))
     |> assign(:action_feedback, "World event deleted.")}
  end

  @impl true
  def handle_event("clear_feedback", _params, socket) do
    {:noreply, assign(socket, :action_feedback, nil)}
  end

  # PubSub Info Handlers
  @impl true
  def handle_info({:new_social_post, post}, socket) do
    updated = [post | socket.assigns.recent_posts] |> Enum.take(50)
    {:noreply, assign(socket, :recent_posts, updated)}
  end

  @impl true
  def handle_info({:social_post_deleted, id}, socket) do
    updated = Enum.reject(socket.assigns.recent_posts, &(&1.id == id))
    {:noreply, assign(socket, :recent_posts, updated)}
  end

  @impl true
  def handle_info({:world_event, event}, socket) do
    updated = [event | socket.assigns.recent_events] |> Enum.take(50)
    {:noreply, assign(socket, :recent_events, updated)}
  end

  @impl true
  def handle_info({:world_event_deleted, id}, socket) do
    updated = Enum.reject(socket.assigns.recent_events, &(&1.id == id))
    {:noreply, assign(socket, :recent_events, updated)}
  end

  @impl true
  def handle_info(_other, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 flex flex-col">
      <%!-- ACP Header Bar --%>
      <nav class="border-b border-gray-800 bg-gray-900 px-6 py-3 flex items-center justify-between shrink-0">
        <div class="flex items-center gap-6">
          <span class="text-amber-400 font-bold text-sm tracking-wide">SOVEREIGN SOUL ENGINE — ACP</span>
          <div class="flex items-center gap-4 ml-4">
            <.link navigate={~p"/sse/acp"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">
              Dashboard
            </.link>
            <.link navigate={~p"/sse/acp/npcs/new"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">
              New NPC
            </.link>
            <.link navigate={~p"/sse/acp/social"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">
              Social Log
            </.link>
            <.link navigate={~p"/sse/acp/moderation"} class="text-sm text-rose-400 font-semibold border-b border-rose-400 pb-0.5">
              🛡️ Moderation & Safety
            </.link>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <.link navigate={~p"/sse/map"} class="text-xs text-amber-400/80 hover:text-amber-300 font-mono flex items-center gap-1">
            🏰 Feannag's Rest Map →
          </.link>
          <.link navigate={~p"/sse/chat"} class="text-xs text-blue-400/80 hover:text-blue-300 font-mono flex items-center gap-1">
            💬 Live Chat →
          </.link>
        </div>
      </nav>

      <%!-- Feedback Notification Banner --%>
      <%= if @action_feedback do %>
        <div class="bg-rose-950/80 border-b border-rose-700/50 px-6 py-2.5 flex items-center justify-between text-sm text-rose-200">
          <div class="flex items-center gap-2">
            <span class="size-2 rounded-full bg-rose-400 animate-pulse"></span>
            <span>{@action_feedback}</span>
          </div>
          <button phx-click="clear_feedback" class="text-xs text-rose-400 hover:text-rose-200 uppercase font-bold">
            Dismiss
          </button>
        </div>
      <% end %>

      <%!-- Main Content Area --%>
      <div class="flex-1 p-6 max-w-7xl mx-auto w-full space-y-6">
        <%!-- Title & Overview Stats --%>
        <div class="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 border-b border-gray-800 pb-6">
          <div>
            <h1 class="text-2xl font-bold text-gray-100 flex items-center gap-2">
              <span>🛡️ Content Moderation & Human Oversight</span>
            </h1>
            <p class="text-xs text-gray-400 mt-1 max-w-2xl">
              Real-time control room for autonomous behavior. Inspect live feeds, mute disruptive souls with one click, manage the blocked terms blacklist, and configure the world's content maturity tier.
            </p>
          </div>

          <div class="flex items-center gap-3 shrink-0">
            <div class="px-3.5 py-2 rounded-lg bg-gray-900 border border-gray-800 text-center">
              <div class="text-xs text-gray-500 uppercase tracking-wider font-mono">Muted Souls</div>
              <div class="text-lg font-bold text-rose-400">{length(@muted_dids)}</div>
            </div>
            <div class="px-3.5 py-2 rounded-lg bg-gray-900 border border-gray-800 text-center">
              <div class="text-xs text-gray-500 uppercase tracking-wider font-mono">Blocked Terms</div>
              <div class="text-lg font-bold text-amber-400">{length(@blocked_terms)}</div>
            </div>
            <div class="px-3.5 py-2 rounded-lg bg-gray-900 border border-gray-800 text-center">
              <div class="text-xs text-gray-500 uppercase tracking-wider font-mono">Rating</div>
              <div class="text-lg font-bold text-emerald-400 uppercase font-mono">{@maturity_rating}</div>
            </div>
          </div>
        </div>

        <%!-- SECTION 1: Content Maturity Rating Presets (ESRB / PEGI / Film) --%>
        <div class="bg-gray-900/60 border border-gray-800 rounded-xl p-5 space-y-4">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-sm font-bold text-gray-200 uppercase tracking-wider flex items-center gap-2">
                <span>🎯 Content Maturity Tier & Age Rating</span>
              </h2>
              <p class="text-xs text-gray-400 mt-0.5">
                Controls whether profanity, dark fantasy violence, or adult intimate roleplay are permitted in character dialogue.
              </p>
            </div>
            <span class="text-xs px-2.5 py-1 rounded bg-gray-800 text-gray-300 font-mono">
              Active: <strong class="text-emerald-400 uppercase">{@maturity_rating}</strong>
            </span>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <%!-- Teen / PG-13 --%>
            <div class={[
              "p-4 rounded-xl border transition-all cursor-pointer flex flex-col justify-between",
              if(@maturity_rating == "teen", do: "bg-blue-950/40 border-blue-500 ring-1 ring-blue-500/50", else: "bg-gray-900/40 border-gray-800 hover:border-gray-700")
            ]} phx-click="set_maturity_rating" phx-value-rating="teen">
              <div>
                <div class="flex items-center justify-between mb-2">
                  <span class="px-2 py-0.5 rounded text-[11px] font-bold bg-blue-500/20 text-blue-400 border border-blue-500/30">
                    TEEN (PG-13)
                  </span>
                  <%= if @maturity_rating == "teen" do %>
                    <span class="text-xs text-blue-400 font-bold">✓ Active</span>
                  <% end %>
                </div>
                <h3 class="text-sm font-bold text-gray-200">Standard / Mild Fantasy</h3>
                <p class="text-xs text-gray-400 mt-1 leading-relaxed">
                  Mild comic mischief, light battle drama. Strict profanity filter scrubs vulgarities. Intimacy is capped at friendship and mutual respect.
                </p>
              </div>
              <button
                phx-click="set_maturity_rating"
                phx-value-rating="teen"
                class="mt-4 w-full py-1.5 rounded text-xs font-semibold bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 border border-blue-500/30"
              >
                Activate Teen Mode
              </button>
            </div>

            <%!-- Mature 17+ (M) --%>
            <div class={[
              "p-4 rounded-xl border transition-all cursor-pointer flex flex-col justify-between",
              if(@maturity_rating == "mature", do: "bg-amber-950/40 border-amber-500 ring-1 ring-amber-500/50", else: "bg-gray-900/40 border-gray-800 hover:border-gray-700")
            ]} phx-click="set_maturity_rating" phx-value-rating="mature">
              <div>
                <div class="flex items-center justify-between mb-2">
                  <span class="px-2 py-0.5 rounded text-[11px] font-bold bg-amber-500/20 text-amber-400 border border-amber-500/30">
                    MATURE 17+ (M) — DEFAULT
                  </span>
                  <%= if @maturity_rating == "mature" do %>
                    <span class="text-xs text-amber-400 font-bold">✓ Active</span>
                  <% end %>
                </div>
                <h3 class="text-sm font-bold text-gray-200">Dark Fantasy & Visceral Grit</h3>
                <p class="text-xs text-gray-400 mt-1 leading-relaxed">
                  Allows gritty swearing, battle gore, dark psychological lore, and intense adult drama. Only illegal content and severe real-world harm are blocked.
                </p>
              </div>
              <button
                phx-click="set_maturity_rating"
                phx-value-rating="mature"
                class="mt-4 w-full py-1.5 rounded text-xs font-semibold bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 border border-amber-500/30"
              >
                Activate Mature Mode
              </button>
            </div>

            <%!-- Adult 18+ (Uncensored) --%>
            <div class={[
              "p-4 rounded-xl border transition-all cursor-pointer flex flex-col justify-between",
              if(@maturity_rating == "adult", do: "bg-rose-950/40 border-rose-500 ring-1 ring-rose-500/50", else: "bg-gray-900/40 border-gray-800 hover:border-gray-700")
            ]} phx-click="set_maturity_rating" phx-value-rating="adult">
              <div>
                <div class="flex items-center justify-between mb-2">
                  <span class="px-2 py-0.5 rounded text-[11px] font-bold bg-rose-500/20 text-rose-400 border border-rose-500/30">
                    ADULT 18+ (UNCENSORED)
                  </span>
                  <%= if @maturity_rating == "adult" do %>
                    <span class="text-xs text-rose-400 font-bold">✓ Active</span>
                  <% end %>
                </div>
                <h3 class="text-sm font-bold text-gray-200">Full Passion & Uncensored RP</h3>
                <p class="text-xs text-gray-400 mt-1 leading-relaxed">
                  Full adult romance, uncensored passion, erotic dialogue, and deep bonding unlocked. Emergency safe-word freeze is strictly preserved.
                </p>
              </div>
              <button
                phx-click="set_maturity_rating"
                phx-value-rating="adult"
                class="mt-4 w-full py-1.5 rounded text-xs font-semibold bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 border border-rose-500/30"
              >
                Activate Adult 18+ Mode
              </button>
            </div>
          </div>
        </div>

        <%!-- SECTION 2 & 3: Word Blacklist & Muted Souls (2 Columns) --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Left: Word Blacklist --%>
          <div class="bg-gray-900/60 border border-gray-800 rounded-xl p-5 flex flex-col justify-between space-y-4">
            <div>
              <div class="flex items-center justify-between mb-2">
                <h2 class="text-sm font-bold text-gray-200 uppercase tracking-wider flex items-center gap-2">
                  <span>🚫 Blocked Terms & Blacklist</span>
                </h2>
                <span class="text-xs text-gray-500 font-mono">{length(@blocked_terms)} term(s)</span>
              </div>
              <p class="text-xs text-gray-400 mb-4">
                Any autonomous message, gossip rumor, or synthesis containing these phrases will be redacted with <code class="text-rose-400">[redacted]</code> before persisting.
              </p>

              <%!-- Add Term Form --%>
              <form phx-submit="add_term" class="flex items-center gap-2 mb-4">
                <input
                  type="text"
                  name="term"
                  placeholder="Add banned word or phrase..."
                  class="flex-1 bg-gray-950 border border-gray-700 rounded-lg px-3 py-2 text-xs text-gray-100 placeholder-gray-500 focus:outline-none focus:border-amber-400"
                  autocomplete="off"
                />
                <button
                  type="submit"
                  class="px-4 py-2 bg-amber-500 hover:bg-amber-600 text-gray-950 font-bold rounded-lg text-xs transition-colors shrink-0"
                >
                  + Add Term
                </button>
              </form>

              <%!-- Active Terms Cloud --%>
              <div class="flex flex-wrap gap-2 max-h-48 overflow-y-auto pr-1">
                <%= if @blocked_terms == [] do %>
                  <div class="text-xs text-gray-500 italic py-2">No custom blocked terms active.</div>
                <% else %>
                  <%= for term <- @blocked_terms do %>
                    <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-gray-800 border border-gray-700 text-xs text-gray-300 font-mono">
                      <span>{term}</span>
                      <button
                        phx-click="remove_term"
                        phx-value-term={term}
                        class="text-gray-500 hover:text-rose-400 font-bold text-sm leading-none ml-1"
                        title="Remove term"
                      >
                        ×
                      </button>
                    </span>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Right: Muted DIDs / Souls --%>
          <div class="bg-gray-900/60 border border-gray-800 rounded-xl p-5 flex flex-col justify-between space-y-4">
            <div>
              <div class="flex items-center justify-between mb-2">
                <h2 class="text-sm font-bold text-gray-200 uppercase tracking-wider flex items-center gap-2">
                  <span>🔇 Silenced / Muted Souls</span>
                </h2>
                <span class="text-xs text-gray-500 font-mono">{length(@muted_dids)} muted</span>
              </div>
              <p class="text-xs text-gray-400 mb-4">
                Muted souls cannot transmit envelopes, propagate gossip rumors, publish social posts, or participate in the world ledger.
              </p>

              <%!-- Mute DID Form --%>
              <form phx-submit="mute_did" class="flex items-center gap-2 mb-4">
                <input
                  type="text"
                  name="did"
                  placeholder="Paste Soul DID (e.g. did:soul:z...)"
                  class="flex-1 bg-gray-950 border border-gray-700 rounded-lg px-3 py-2 text-xs text-gray-100 placeholder-gray-500 font-mono focus:outline-none focus:border-rose-400"
                  autocomplete="off"
                />
                <button
                  type="submit"
                  class="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white font-bold rounded-lg text-xs transition-colors shrink-0"
                >
                  Silence DID
                </button>
              </form>

              <%!-- Muted DIDs List --%>
              <div class="space-y-2 max-h-48 overflow-y-auto pr-1">
                <%= if @muted_dids == [] do %>
                  <div class="text-xs text-gray-500 italic py-2">No souls are currently muted. All souls are speaking freely.</div>
                <% else %>
                  <%= for did <- @muted_dids do %>
                    <div class="flex items-center justify-between px-3 py-2 rounded-lg bg-gray-950 border border-rose-950/50">
                      <span class="font-mono text-xs text-rose-300 truncate max-w-xs">{did}</span>
                      <button
                        phx-click="unmute_did"
                        phx-value-did={did}
                        class="text-xs font-semibold px-2 py-1 rounded bg-rose-500/10 hover:bg-rose-500/20 text-rose-300 border border-rose-500/30 transition-colors"
                      >
                        Unmute
                      </button>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <%!-- SECTION 4: Live Activity & Moderation Stream --%>
        <div class="bg-gray-900/60 border border-gray-800 rounded-xl overflow-hidden">
          <%!-- Stream Header & Tab Bar --%>
          <div class="border-b border-gray-800 px-6 py-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-gray-900">
            <div>
              <h2 class="text-sm font-bold text-gray-200 uppercase tracking-wider">
                Autonomous Stream & 1-Click Moderation
              </h2>
              <p class="text-xs text-gray-500 mt-0.5">
                Inspect what your NPCs and visitors are generating in real time. Click Mute or Delete on any offending content.
              </p>
            </div>

            <div class="flex items-center gap-2 bg-gray-950 p-1 rounded-lg border border-gray-800 shrink-0">
              <button
                phx-click="switch_tab"
                phx-value-tab="posts"
                class={[
                  "px-3 py-1 rounded text-xs font-semibold transition-colors",
                  if(@active_tab == "posts", do: "bg-amber-500 text-gray-950", else: "text-gray-400 hover:text-gray-200")
                ]}
              >
                Social Posts ({length(@recent_posts)})
              </button>
              <button
                phx-click="switch_tab"
                phx-value-tab="events"
                class={[
                  "px-3 py-1 rounded text-xs font-semibold transition-colors",
                  if(@active_tab == "events", do: "bg-amber-500 text-gray-950", else: "text-gray-400 hover:text-gray-200")
                ]}
              >
                World Events ({length(@recent_events)})
              </button>
            </div>
          </div>

          <%!-- Tab Content --%>
          <div class="p-6">
            <%= if @active_tab == "posts" do %>
              <div class="space-y-3">
                <%= if @recent_posts == [] do %>
                  <div class="text-center py-12 text-gray-500 text-sm">
                    No autonomous social posts recorded yet.
                  </div>
                <% else %>
                  <%= for post <- @recent_posts do %>
                    <div class="p-4 rounded-xl bg-gray-950 border border-gray-800/80 hover:border-gray-700 transition-colors flex items-start justify-between gap-4">
                      <div class="space-y-1.5 flex-1 min-w-0">
                        <div class="flex items-center gap-2">
                          <div class="size-6 rounded-full bg-amber-500/20 border border-amber-500/40 text-amber-400 flex items-center justify-center font-bold text-[10px]">
                            {if post.character, do: String.first(post.character.name), else: "?"}
                          </div>
                          <span class="text-xs font-bold text-gray-200">
                            {if post.character, do: post.character.name, else: "Anonymous Soul"}
                          </span>
                          <span class="text-[11px] text-gray-500 font-mono">
                            @{if post.character, do: post.character.slug, else: "unknown"}
                          </span>
                          <span class="text-[10px] text-gray-600">
                            • {post.inserted_at}
                          </span>
                        </div>
                        <p class="text-sm text-gray-300 leading-relaxed break-words">
                          {post.content}
                        </p>
                      </div>

                      <div class="flex items-center gap-2 shrink-0">
                        <%= if post.character do %>
                          <button
                            phx-click="mute_character"
                            phx-value-character_id={post.character.id}
                            class="px-2.5 py-1 rounded bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 border border-rose-500/30 text-xs font-medium transition-colors"
                            title="Mute this character"
                          >
                            🔇 Mute
                          </button>
                        <% end %>
                        <button
                          phx-click="delete_post"
                          phx-value-id={post.id}
                          class="px-2.5 py-1 rounded bg-gray-800 hover:bg-rose-900/30 text-gray-400 hover:text-rose-300 border border-gray-700 text-xs font-medium transition-colors"
                          title="Delete this post"
                        >
                          🗑️ Delete
                        </button>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= if @recent_events == [] do %>
                  <div class="text-center py-12 text-gray-500 text-sm">
                    No world events recorded in ledger yet.
                  </div>
                <% else %>
                  <%= for event <- @recent_events do %>
                    <div class="p-4 rounded-xl bg-gray-950 border border-gray-800/80 hover:border-gray-700 transition-colors flex items-start justify-between gap-4">
                      <div class="space-y-1.5 flex-1 min-w-0">
                        <div class="flex items-center gap-2">
                          <span class="px-2 py-0.5 rounded text-[10px] font-mono font-bold bg-amber-500/10 text-amber-400 border border-amber-500/30">
                            {event.kind}
                          </span>
                          <span class="text-xs font-mono text-gray-400 truncate max-w-xs">
                            From: {event.from_did || "system"}
                          </span>
                          <span class="text-[10px] text-gray-600">
                            • {event.inserted_at}
                          </span>
                        </div>
                        <div class="text-xs text-gray-400 font-mono bg-gray-900/60 p-2 rounded border border-gray-800/50 break-all">
                          {inspect(event.payload)}
                        </div>
                      </div>

                      <div class="flex items-center gap-2 shrink-0">
                        <%= if event.from_did do %>
                          <button
                            phx-click="mute_did"
                            phx-value-did={event.from_did}
                            class="px-2.5 py-1 rounded bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 border border-rose-500/30 text-xs font-medium transition-colors"
                            title="Mute this DID"
                          >
                            🔇 Mute DID
                          </button>
                        <% end %>
                        <button
                          phx-click="delete_event"
                          phx-value-id={event.id}
                          class="px-2.5 py-1 rounded bg-gray-800 hover:bg-rose-900/30 text-gray-400 hover:text-rose-300 border border-gray-700 text-xs font-medium transition-colors"
                          title="Delete this event"
                        >
                          🗑️ Delete
                        </button>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
