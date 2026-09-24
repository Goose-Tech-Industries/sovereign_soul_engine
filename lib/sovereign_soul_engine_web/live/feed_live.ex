defmodule SovereignSoulEngineWeb.FeedLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.{
    Characters,
    Relationships,
    Social.SocialFeed,
    World
  }

  import Ecto.Query, warn: false

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, SocialFeed.pubsub_topic())
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "world:events")
      # Start live autonomous pulse so the feed dynamically updates
      Process.send_after(self(), :live_feed_pulse, 3_000)
    end

    # Ensure player character exists
    player =
      cond do
        user = socket.assigns[:current_scope] && socket.assigns.current_scope.user ->
          Characters.get_or_create_player_for_user(user)

        goose = Characters.get_character_by_slug("goose") ->
          goose

        true ->
          case Characters.create_character(%{
                 name: "Goose",
                 slug: "goose",
                 kind: "player",
                 status: "active",
                 description: "The primary traveler and sovereign commander."
               }) do
            {:ok, char} -> char
            _ -> hd(Characters.list_characters())
          end
      end

    top_friends = Relationships.get_top_friends(player.id, 8)

    npcs =
      Enum.filter(
        Characters.list_living_world_characters(),
        &(&1.kind == "npc" and &1.status == "active")
      )

    recent_events = World.list_recent_events(limit: 10)

    # Load initial posts
    posts = SocialFeed.list_recent_posts(limit: 30)

    socket =
      socket
      |> assign(:page_title, "SoulBook — Living Society Feed of Feannag's Rest")
      |> assign(:player, player)
      |> assign(:posts, posts)
      |> assign(:top_friends, top_friends)
      |> assign(:npcs, npcs)
      |> assign(:recent_events, recent_events)
      |> assign(:composer_content, "")
      |> assign(:composer_location, "High Sovereign Palace")
      |> assign(:comment_inputs, %{})
      |> assign(:toast, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("publish_post", %{"content" => content, "location" => location}, socket) do
    clean_content = String.trim(content)
    player = socket.assigns.player

    if clean_content != "" do
      attrs = %{
        character_id: player.id,
        content: clean_content,
        mood: "expressive",
        platform: "soulbook",
        metadata: %{
          "location" => location,
          "comments" => [],
          "reactions" => %{"love" => 1, "fire" => 0, "honor" => 0, "laugh" => 0, "moon" => 0}
        }
      }

      case SocialFeed.create_post(attrs) do
        {:ok, post} ->
          # Trigger peer companions to react and reply after a brief natural pause
          Process.send_after(self(), {:trigger_inter_soul_chain, post.id}, 500)

          {:noreply,
           socket
           |> assign(:composer_content, "")
           |> assign(:posts, [post | socket.assigns.posts])
           |> assign(:toast, "Your post is echoing across Feannag's Rest.")}

        _error ->
          {:noreply, assign(socket, :toast, "Could not publish post.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_comment", %{"post_id" => post_id, "content" => text}, socket) do
    clean_text = String.trim(text)
    player = socket.assigns.player

    if clean_text != "" do
      case SocialFeed.add_comment(post_id, player, clean_text) do
        {:ok, updated_post, _comment} ->
          # Find post author to see if it's an NPC who should reply
          if updated_post.character && updated_post.character.kind == "npc" do
            Process.send_after(
              self(),
              {:npc_reply_to_comment, post_id, updated_post.character.id, clean_text},
              500
            )
          end

          # Also trigger a second peer NPC to chime in on the conversation
          Process.send_after(self(), {:trigger_peer_comment, post_id}, 1200)

          comment_inputs = Map.put(socket.assigns.comment_inputs, post_id, "")

          {:noreply,
           socket
           |> assign(:comment_inputs, comment_inputs)
           |> update_post_in_list(updated_post)}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("react", %{"post_id" => post_id, "type" => type}, socket) do
    case SocialFeed.react_to_post(post_id, type) do
      {:ok, updated_post} ->
        {:noreply, update_post_in_list(socket, updated_post)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("spark_npc_post", _params, socket) do
    case SocialFeed.spark_inter_soul_activity() do
      {:ok, post} ->
        post = SovereignSoulEngine.Repo.preload(post, :character)
        {:noreply, assign(socket, :toast, "#{post.character.name} sparked a town conversation.")}

      _ ->
        if socket.assigns.npcs != [] do
          npc = Enum.random(socket.assigns.npcs)
          fallback_text = pick_fallback_quote(npc)

          case SocialFeed.create_post(%{
                 character_id: npc.id,
                 content: fallback_text,
                 mood: "introspective",
                 platform: "soulbook",
                 metadata: %{
                   "location" => "Feannag's Rest",
                   "comments" => [],
                   "reactions" => %{
                     "love" => 1,
                     "honor" => 1,
                     "fire" => 0,
                     "laugh" => 0,
                     "moon" => 1
                   }
                 }
               }) do
            {:ok, post} ->
              Process.send_after(self(), {:trigger_inter_soul_chain, post.id}, 400)
              {:noreply, assign(socket, :toast, "#{npc.name} posted to the town square.")}

            _ ->
              {:noreply, assign(socket, :toast, "All souls are currently at rest.")}
          end
        else
          {:noreply, assign(socket, :toast, "All souls are currently at rest.")}
        end
    end
  end

  @impl true
  def handle_event("dismiss_toast", _params, socket) do
    {:noreply, assign(socket, :toast, nil)}
  end

  # PubSub and Async Handlers
  @impl true
  def handle_info({:new_social_post, post}, socket) do
    updated = [post | Enum.reject(socket.assigns.posts, &(&1.id == post.id))] |> Enum.take(40)
    {:noreply, assign(socket, :posts, updated)}
  end

  @impl true
  def handle_info({:post_updated, updated_post}, socket) do
    {:noreply, update_post_in_list(socket, updated_post)}
  end

  @impl true
  def handle_info({:social_post_deleted, id}, socket) do
    updated = Enum.reject(socket.assigns.posts, &(&1.id == id))
    {:noreply, assign(socket, :posts, updated)}
  end

  @impl true
  def handle_info({:autonomous_comment_reaction, post_id, npc_id, comment_text}, socket) do
    SocialFeed.generate_npc_comment_reply(post_id, npc_id, comment_text)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:npc_reply_to_comment, post_id, npc_id, comment_text}, socket) do
    SocialFeed.generate_npc_comment_reply(post_id, npc_id, comment_text)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:trigger_inter_soul_chain, post_id}, socket) do
    post = SovereignSoulEngine.Repo.get(SovereignSoulEngine.Social.SocialPost, post_id)

    if post do
      SocialFeed.trigger_inter_soul_response(post, 2)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:trigger_peer_comment, post_id}, socket) do
    post = SovereignSoulEngine.Repo.get(SovereignSoulEngine.Social.SocialPost, post_id)

    if post do
      SocialFeed.trigger_inter_soul_response(post, 1)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:world_event, event}, socket) do
    updated = [event | socket.assigns.recent_events] |> Enum.take(10)
    {:noreply, assign(socket, :recent_events, updated)}
  end

  @impl true
  def handle_info(:live_feed_pulse, socket) do
    unless SovereignSoulEngine.World.Control.paused?() do
      SocialFeed.spark_inter_soul_activity()
    end

    # Pulse every 12 to 22 seconds for an organic living town feeling
    next_delay = Enum.random(12_000..22_000)
    Process.send_after(self(), :live_feed_pulse, next_delay)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_other, socket), do: {:noreply, socket}

  defp update_post_in_list(socket, updated_post) do
    updated =
      Enum.map(socket.assigns.posts, fn p ->
        if p.id == updated_post.id, do: updated_post, else: p
      end)

    assign(socket, :posts, updated)
  end

  defp pick_fallback_quote(npc) do
    recent_contents =
      from(p in SovereignSoulEngine.Social.SocialPost,
        order_by: [desc: p.posted_at, desc: p.inserted_at],
        limit: 50,
        select: p.content
      )
      |> SovereignSoulEngine.Repo.all()

    SocialFeed.fallback_post(npc, "contemplative", recent_contents)
  end

  defp reaction_count(post, key) do
    (post.metadata && post.metadata["reactions"] && post.metadata["reactions"][key]) || 0
  end

  defp post_comments(post) do
    comments = (post.metadata && post.metadata["comments"]) || []

    Enum.filter(comments, fn c ->
      content = Map.get(c, "content", "") |> String.trim()

      content != "" and content != "..." and
        not String.starts_with?(content, "...") and
        not String.contains?(content, "<|reserved") and
        String.length(content) >= 4
    end)
    |> Enum.map(fn c ->
      content = Map.get(c, "content", "") |> String.trim()

      cleaned_content =
        content
        |> String.replace(~r/^{\s*"([^"]+)"/, "\\1")
        |> String.replace(~r/<\|[^|]+\|>/, "")
        |> String.replace(~r/\s*-\s*(edited to fit|no, I'll keep it simple).*$/i, "")
        |> String.trim()

      Map.put(c, "content", cleaned_content)
    end)
  end

  defp post_location(post) do
    (post.metadata && post.metadata["location"]) || "Feannag's Rest"
  end

  defp format_event_narrative(event) do
    from_name = format_participant(event.from_did)
    to_name = format_participant(event.to_did)
    res = get_in(event.payload || %{}, ["resonance"])

    case event.kind do
      "encounter" when is_integer(res) and res >= 80 ->
        {"✨", "#{from_name} and #{to_name} shared an extraordinary kindred resonance (#{res}%)."}

      "encounter" when is_integer(res) and res >= 60 ->
        {"🤝", "#{from_name} and #{to_name} bonded warmly in the square (#{res}% resonance)."}

      "encounter" when is_integer(res) and res >= 45 ->
        {"💬", "#{from_name} and #{to_name} crossed paths in the commons (#{res}% resonance)."}

      "encounter" when is_integer(res) ->
        {"⚡", "#{from_name} and #{to_name} had a guarded, tense exchange (#{res}% resonance)."}

      "gossip" ->
        summary =
          get_in(event.payload || %{}, ["summary"]) ||
            "Whispers spread between #{from_name} and #{to_name}."

        {"🗣️", summary}

      "world_post" ->
        {"📜", "#{from_name} posted a decree to the district."}

      _ ->
        {"✨", "#{from_name} was active in Feannag's Rest."}
    end
  end

  defp format_participant(did_or_slug) do
    cond do
      is_nil(did_or_slug) ->
        "A Soul"

      String.starts_with?(did_or_slug, "did:soul:") ->
        case SovereignSoulEngine.Identity.get_did(did_or_slug) do
          %SovereignSoulEngine.Identity.SoulDid{character_id: char_id} when is_binary(char_id) ->
            case SovereignSoulEngine.Characters.get_character(char_id) do
              nil -> "A Sovereign Soul"
              char -> char.name
            end

          _ ->
            "A Sovereign Soul"
        end

      true ->
        String.capitalize(did_or_slug)
    end
  end

  defp format_event_time(nil), do: "just now"
  defp format_event_time(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%H:%M:%S")
  defp format_event_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M:%S")
  defp format_event_time(other), do: to_string(other)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans pb-20 md:pb-6">
      <%!-- Top Desktop & Mobile Header Bar --%>
      <header class="border-b border-slate-800 bg-slate-900/90 backdrop-blur-md sticky top-0 z-40 px-4 sm:px-6 py-3 flex items-center justify-between">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/sse/feed"} class="flex items-center gap-2.5">
            <div class="size-8 rounded-xl bg-gradient-to-tr from-amber-500 to-rose-500 flex items-center justify-center font-black text-sm text-slate-950 shadow-md shadow-amber-500/20">
              SB
            </div>
            <div>
              <span class="font-extrabold text-base tracking-tight text-white flex items-center gap-1.5">
                SoulBook
                <span class="badge badge-warning badge-xs font-mono font-bold">FEANNAG'S REST</span>
              </span>
            </div>
          </.link>

          <nav class="hidden md:flex items-center gap-4 ml-6 text-xs font-semibold text-slate-400">
            <.link
              navigate={~p"/sse/feed"}
              class="text-amber-400 font-bold border-b-2 border-amber-400 pb-1"
            >
              📰 Living Feed
            </.link>
            <.link navigate={~p"/sse/chat"} class="hover:text-slate-200 transition-colors">
              💬 Companion Chat
            </.link>
            <.link navigate={~p"/sse/acp"} class="hover:text-purple-300 transition-colors">
              ⚙️ Studio
            </.link>
            <.link navigate={~p"/sse/memories"} class="hover:text-slate-200 transition-colors">
              🧠 Memory Vault
            </.link>
            <.link navigate={~p"/sse/acp/moderation"} class="hover:text-rose-400 transition-colors">
              🛡️ Moderation
            </.link>
          </nav>
        </div>

        <div class="flex items-center gap-2.5">
          <div class="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/25 text-emerald-400 text-[11px] font-mono shadow-xs">
            <span class="size-2 rounded-full bg-emerald-400 animate-pulse"></span>
            <span>Live Pulse: {length(@npcs)} Souls</span>
          </div>
          <button
            phx-click="spark_npc_post"
            class="px-3 py-1.5 rounded-lg bg-amber-500/10 hover:bg-amber-500/20 border border-amber-500/30 text-amber-400 text-xs font-semibold flex items-center gap-1.5 transition-colors"
            title="Prompt an NPC to publish a thought right now"
          >
            <span>✨ Spark Post</span>
          </button>
          <.link
            navigate={~p"/sse/chat"}
            class="px-3 py-1.5 rounded-lg bg-primary hover:bg-primary-focus text-primary-content text-xs font-bold shadow-md shadow-primary/25 hidden sm:inline-flex items-center gap-1"
          >
            Direct Chat →
          </.link>
        </div>
      </header>

      <%!-- Notification Toast --%>
      <%= if @toast do %>
        <div class="bg-amber-950/80 border-b border-amber-500/40 px-6 py-2 flex items-center justify-between text-xs text-amber-200">
          <div class="flex items-center gap-2">
            <span class="size-1.5 rounded-full bg-amber-400 animate-ping"></span>
            <span>{@toast}</span>
          </div>
          <button
            phx-click="dismiss_toast"
            class="text-amber-400 hover:text-white uppercase font-bold text-[10px]"
          >
            Dismiss
          </button>
        </div>
      <% end %>

      <%!-- Main 3-Column Social Container --%>
      <div class="flex-1 max-w-7xl mx-auto w-full px-4 sm:px-6 py-6 grid grid-cols-1 lg:grid-cols-12 gap-6">
        <%!-- LEFT COLUMN: Player Profile & MySpace "Top 8" (4 cols on lg) --%>
        <aside class="lg:col-span-4 space-y-6 order-2 lg:order-1">
          <%!-- Player Identity Card --%>
          <div class="p-5 rounded-2xl bg-slate-900/70 border border-slate-800 shadow-xl space-y-4">
            <div class="flex items-center gap-3.5">
              <div class="size-12 rounded-2xl bg-gradient-to-tr from-amber-500 to-purple-600 flex items-center justify-center font-bold text-lg text-white shadow-lg shadow-amber-500/20">
                {String.first(@player.name)}
              </div>
              <div>
                <h2 class="font-extrabold text-white text-base leading-tight">{@player.name}</h2>
                <span class="text-xs font-mono text-amber-400">
                  @{String.downcase(@player.slug)} • Sovereign Traveler
                </span>
              </div>
            </div>

            <p class="text-xs text-slate-400 leading-relaxed">
              {@player.description ||
                "Commander walking through the 13 concentric districts of Feannag's Rest."}
            </p>

            <div class="pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
              <span>Status: <strong class="text-emerald-400">Active in Feannag's Rest</strong></span>
              <.link
                navigate={~p"/sse/chat"}
                class="text-amber-400 hover:text-amber-300 font-semibold text-[11px]"
              >
                Open Chat →
              </.link>
            </div>
          </div>

          <%!-- MySpace Top 8 Friends Widget --%>
          <div class="p-5 rounded-2xl bg-slate-900/70 border border-slate-800 shadow-xl space-y-4">
            <div class="flex items-center justify-between border-b border-slate-800 pb-3">
              <div class="flex items-center gap-2">
                <span class="text-base">⭐</span>
                <div>
                  <h3 class="font-extrabold text-sm text-white">Top 8 Companions</h3>
                  <p class="text-[10px] text-slate-500">Live dynamic affinity & trust</p>
                </div>
              </div>
              <span class="text-[10px] font-mono px-2 py-0.5 rounded bg-slate-800 text-amber-400">
                MySpace Grid
              </span>
            </div>

            <%= if @top_friends == [] do %>
              <div class="text-center py-6 text-xs text-slate-500 italic">
                No companions in your Top 8 yet. Start chatting or exploring to forge bonds!
              </div>
            <% else %>
              <div class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-2 gap-3">
                <%= for rel <- @top_friends do %>
                  <div class="p-2.5 rounded-xl bg-slate-950 border border-slate-800/80 hover:border-amber-500/40 transition-all flex flex-col justify-between group">
                    <div class="flex items-center gap-2">
                      <.link
                        navigate={~p"/sse/characters/#{rel.target_character.id}"}
                        class="size-8 rounded-lg bg-amber-500/20 border border-amber-500/40 text-amber-400 hover:border-amber-300 flex items-center justify-center font-bold text-xs shrink-0 transition-colors"
                        title="View Soul Profile"
                      >
                        {String.first(rel.target_character.name)}
                      </.link>
                      <div class="min-w-0">
                        <.link
                          navigate={~p"/sse/characters/#{rel.target_character.id}"}
                          class="text-xs font-bold text-white truncate block group-hover:text-amber-400 transition-colors"
                          title="View Soul Profile"
                        >
                          {rel.target_character.name}
                        </.link>
                        <div class="text-[10px] text-slate-500 truncate">
                          {rel.relationship_type || "Companion"}
                        </div>
                      </div>
                    </div>

                    <div class="mt-2 pt-2 border-t border-slate-900 flex items-center justify-between text-[10px]">
                      <span class="text-slate-400 font-mono">
                        Affinity: <strong class="text-amber-400">{rel.affinity}</strong>
                      </span>
                      <.link
                        navigate={~p"/sse/chat?character=#{rel.target_character.slug}"}
                        class="text-blue-400 hover:text-blue-300 font-semibold"
                      >
                        Chat →
                      </.link>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </aside>

        <%!-- CENTER COLUMN: "What's On Your Mind" Composer & Feed Stream (5 cols on lg) --%>
        <main class="lg:col-span-5 space-y-6 order-1 lg:order-2">
          <%!-- "What's on your mind?" Composer Card --%>
          <div class="p-5 rounded-2xl bg-slate-900/90 border border-slate-800 shadow-xl space-y-3">
            <div class="flex items-center gap-3">
              <div class="size-9 rounded-xl bg-amber-500/20 text-amber-400 flex items-center justify-center font-bold text-sm border border-amber-500/30">
                {String.first(@player.name)}
              </div>
              <div class="text-xs font-semibold text-slate-300">
                What is unfolding in Feannag's Rest, {@player.name}?
              </div>
            </div>

            <form phx-submit="publish_post" class="space-y-3">
              <textarea
                name="content"
                rows="2"
                placeholder="Share a thought, announce a decree, or address the town..."
                class="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-400 resize-none"
                required
              ></textarea>

              <div class="flex items-center justify-between gap-3 pt-1">
                <div class="flex items-center gap-1.5 text-xs text-slate-400">
                  <span>📍</span>
                  <select
                    name="location"
                    class="bg-slate-950 border border-slate-800 rounded-lg px-2.5 py-1 text-[11px] text-slate-300 focus:outline-none focus:border-amber-400"
                  >
                    <option value="The High Sovereign Palace">The High Sovereign Palace</option>
                    <option value="The Raven Docks">The Raven Docks</option>
                    <option value="The Obsidian Spire">The Obsidian Spire</option>
                    <option value="The Old Ironworks">The Old Ironworks</option>
                    <option value="Whispering Shrines">Whispering Shrines</option>
                    <option value="Grand Market Square">Grand Market Square</option>
                  </select>
                </div>

                <button
                  type="submit"
                  class="px-4 py-1.5 rounded-lg bg-amber-500 hover:bg-amber-600 text-slate-950 font-bold text-xs shadow-md shadow-amber-500/20 transition-all shrink-0"
                >
                  Post to Wall
                </button>
              </div>
            </form>
          </div>

          <%!-- Living Feed Posts --%>
          <div class="space-y-5">
            <%= if @posts == [] do %>
              <div class="p-8 rounded-2xl bg-slate-900/40 border border-slate-800 text-center text-xs text-slate-500">
                The town square is quiet right now. Click "Spark Post" above or write the first thought!
              </div>
            <% else %>
              <%= for post <- @posts do %>
                <article class="p-5 rounded-2xl bg-slate-900/80 border border-slate-800 shadow-xl space-y-4 hover:border-slate-700/80 transition-all">
                  <%!-- Post Header --%>
                  <div class="flex items-start justify-between gap-3">
                    <div class="flex items-center gap-3">
                      <.link
                        navigate={
                          if post.character, do: ~p"/sse/characters/#{post.character.id}", else: "#"
                        }
                        class="size-10 rounded-xl bg-gradient-to-tr from-amber-500/20 to-purple-500/20 border border-amber-500/30 text-amber-400 hover:border-amber-400 flex items-center justify-center font-bold text-sm transition-all shadow-xs"
                        title="View Soul Profile"
                      >
                        {if post.character, do: String.first(post.character.name), else: "S"}
                      </.link>
                      <div>
                        <div class="flex items-center gap-1.5">
                          <.link
                            navigate={
                              if post.character,
                                do: ~p"/sse/characters/#{post.character.id}",
                                else: "#"
                            }
                            class="font-extrabold text-sm text-white hover:text-amber-400 transition-colors"
                            title="View Soul Profile"
                          >
                            {if post.character, do: post.character.name, else: "Resident"}
                          </.link>
                          <span class="text-[11px] text-slate-500 font-mono">
                            @{if post.character, do: post.character.slug, else: "unknown"}
                          </span>
                        </div>
                        <div class="text-[10px] text-slate-500 flex items-center gap-1.5">
                          <span>📍 {post_location(post)}</span>
                          <span>•</span>
                          <span>{post.inserted_at}</span>
                        </div>
                      </div>
                    </div>

                    <div class="flex items-center gap-2">
                      <%= if post.character && post.character.kind == "npc" do %>
                        <.link
                          navigate={~p"/sse/chat?character=#{post.character.slug}"}
                          class="px-2.5 py-1 rounded-lg text-xs font-bold bg-blue-600/20 hover:bg-blue-600/40 text-blue-300 border border-blue-500/30 transition-all flex items-center gap-1"
                          title={"Chat 1-on-1 with #{post.character.name}"}
                        >
                          <span>💬 Chat</span>
                        </.link>
                        <span class="hidden sm:inline-block px-2 py-0.5 rounded-full text-[10px] font-mono bg-purple-950/60 border border-purple-800/40 text-purple-300">
                          Autonomous Soul
                        </span>
                      <% end %>
                    </div>
                  </div>

                  <%!-- Post Content Body --%>
                  <p class="text-sm text-slate-200 leading-relaxed whitespace-pre-line">
                    {post.content}
                  </p>

                  <%!-- Emote Reactions Bar --%>
                  <div class="pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
                    <div class="flex items-center gap-1.5 flex-wrap">
                      <button
                        phx-click="react"
                        phx-value-post_id={post.id}
                        phx-value-type="love"
                        class="px-2 py-1 rounded-lg bg-slate-950 hover:bg-rose-950/40 border border-slate-800 hover:border-rose-500/40 text-[11px] text-slate-300 hover:text-rose-400 transition-colors flex items-center gap-1"
                      >
                        <span>❤️</span> <span>{reaction_count(post, "love")}</span>
                      </button>
                      <button
                        phx-click="react"
                        phx-value-post_id={post.id}
                        phx-value-type="honor"
                        class="px-2 py-1 rounded-lg bg-slate-950 hover:bg-amber-950/40 border border-slate-800 hover:border-amber-500/40 text-[11px] text-slate-300 hover:text-amber-400 transition-colors flex items-center gap-1"
                      >
                        <span>⚔️</span> <span>{reaction_count(post, "honor")}</span>
                      </button>
                      <button
                        phx-click="react"
                        phx-value-post_id={post.id}
                        phx-value-type="fire"
                        class="px-2 py-1 rounded-lg bg-slate-950 hover:bg-orange-950/40 border border-slate-800 hover:border-orange-500/40 text-[11px] text-slate-300 hover:text-orange-400 transition-colors flex items-center gap-1"
                      >
                        <span>🔥</span> <span>{reaction_count(post, "fire")}</span>
                      </button>
                      <button
                        phx-click="react"
                        phx-value-post_id={post.id}
                        phx-value-type="laugh"
                        class="px-2 py-1 rounded-lg bg-slate-950 hover:bg-blue-950/40 border border-slate-800 hover:border-blue-500/40 text-[11px] text-slate-300 hover:text-blue-400 transition-colors flex items-center gap-1"
                      >
                        <span>😂</span> <span>{reaction_count(post, "laugh")}</span>
                      </button>
                      <button
                        phx-click="react"
                        phx-value-post_id={post.id}
                        phx-value-type="moon"
                        class="px-2 py-1 rounded-lg bg-slate-950 hover:bg-indigo-950/40 border border-slate-800 hover:border-indigo-500/40 text-[11px] text-slate-300 hover:text-indigo-400 transition-colors flex items-center gap-1"
                      >
                        <span>🌙</span> <span>{reaction_count(post, "moon")}</span>
                      </button>
                    </div>

                    <span class="text-[10px] text-slate-500 font-mono">
                      {length(post_comments(post))} comment(s)
                    </span>
                  </div>

                  <%!-- Threaded Comments Section --%>
                  <div class="pt-3 border-t border-slate-800/50 space-y-3">
                    <%!-- Existing Comments List --%>
                    <%= for comment <- post_comments(post) do %>
                      <div class="flex items-start gap-2.5 p-2.5 rounded-xl bg-slate-950/60 border border-slate-800/40 text-xs">
                        <div class="size-6 rounded-md bg-amber-500/10 text-amber-400 font-bold flex items-center justify-center text-[10px] shrink-0">
                          {String.first(comment["author_name"] || "?")}
                        </div>
                        <div class="space-y-0.5 flex-1 min-w-0">
                          <div class="flex items-center gap-1.5">
                            <span class="font-bold text-white text-[11px]">
                              {comment["author_name"]}
                            </span>
                            <span class="text-[9px] text-slate-500 font-mono">
                              {comment["inserted_at"]}
                            </span>
                          </div>
                          <p class="text-slate-300 leading-relaxed break-words">
                            {comment["content"]}
                          </p>
                        </div>
                      </div>
                    <% end %>

                    <%!-- Write Comment Form --%>
                    <form phx-submit="add_comment" class="flex items-center gap-2">
                      <input type="hidden" name="post_id" value={post.id} />
                      <input
                        type="text"
                        name="content"
                        placeholder={"Reply as #{@player.name}..."}
                        class="flex-1 bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-400"
                        autocomplete="off"
                        required
                      />
                      <button
                        type="submit"
                        class="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold shrink-0 transition-colors"
                      >
                        Reply
                      </button>
                    </form>
                  </div>
                </article>
              <% end %>
            <% end %>
          </div>
        </main>

        <%!-- RIGHT COLUMN: Live Gossip & Town Rumors Ticker (3 cols on lg) --%>
        <aside class="lg:col-span-3 space-y-6 order-3">
          <%!-- Town Commons / Rumor Ticker --%>
          <div class="p-5 rounded-2xl bg-slate-900/70 border border-slate-800 shadow-xl space-y-4">
            <div class="flex items-center justify-between border-b border-slate-800 pb-3">
              <div class="flex items-center gap-2">
                <span class="text-base">📜</span>
                <div>
                  <h3 class="font-extrabold text-sm text-white">Gossip & Rumors</h3>
                  <p class="text-[10px] text-slate-500">Autonomous ledger murmurs</p>
                </div>
              </div>
              <span class="size-2 rounded-full bg-emerald-400 animate-pulse" title="Live updates">
              </span>
            </div>

            <%= if @recent_events == [] do %>
              <div class="text-xs text-slate-500 italic py-4 text-center">
                Quiet in the alleys. No active rumors spreading.
              </div>
            <% else %>
              <div class="space-y-2.5 max-h-96 overflow-y-auto pr-1">
                <%= for event <- @recent_events do %>
                  <% {icon, narrative} = format_event_narrative(event) %>
                  <div class="p-2.5 rounded-xl bg-slate-950/80 border border-slate-800/80 text-xs space-y-1.5 hover:border-slate-700 transition-colors">
                    <div class="flex items-center justify-between text-[10px]">
                      <span class="font-mono text-amber-400 font-bold flex items-center gap-1">
                        <span>{icon}</span>
                        <span>{String.upcase(event.kind)}</span>
                      </span>
                      <span class="text-slate-500 font-mono">
                        {format_event_time(event.inserted_at)}
                      </span>
                    </div>
                    <p class="text-[11px] text-slate-300 leading-snug">
                      {narrative}
                    </p>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="pt-3 border-t border-slate-800/80">
              <.link
                navigate={~p"/sse/acp"}
                class="w-full py-2 rounded-xl bg-purple-500/10 hover:bg-purple-500/20 text-purple-400 border border-purple-500/30 text-xs font-bold flex items-center justify-center gap-1.5 transition-colors"
              >
                <span>⚙️ Studio & Creator Panel →</span>
              </.link>
            </div>
          </div>
        </aside>
      </div>

      <%!-- Universal PWA Mobile Bottom Navigation Dock (visible on mobile screens) --%>
      <nav class="md:hidden fixed bottom-0 left-0 right-0 z-50 bg-slate-950/95 backdrop-blur-lg border-t border-slate-800 px-4 py-2 flex items-center justify-around">
        <.link
          navigate={~p"/sse/chat"}
          class="flex flex-col items-center gap-1 text-slate-400 hover:text-white"
        >
          <span class="text-lg leading-none">💬</span>
          <span class="text-[10px] font-semibold">Chat</span>
        </.link>

        <.link
          navigate={~p"/sse/feed"}
          class="flex flex-col items-center gap-1 text-amber-400 font-bold"
        >
          <span class="text-lg leading-none">📰</span>
          <span class="text-[10px]">Feed</span>
        </.link>

        <.link
          navigate={~p"/sse/acp"}
          class="flex flex-col items-center gap-1 text-slate-400 hover:text-white"
        >
          <span class="text-lg leading-none">⚙️</span>
          <span class="text-[10px] font-semibold">Studio</span>
        </.link>

        <.link
          navigate={~p"/sse/memories"}
          class="flex flex-col items-center gap-1 text-slate-400 hover:text-white"
        >
          <span class="text-lg leading-none">🧠</span>
          <span class="text-[10px] font-semibold">Vault</span>
        </.link>

        <.link
          navigate={~p"/sse/acp/moderation"}
          class="flex flex-col items-center gap-1 text-slate-400 hover:text-rose-400"
        >
          <span class="text-lg leading-none">🛡️</span>
          <span class="text-[10px] font-semibold">Shield</span>
        </.link>
      </nav>
    </div>
    """
  end
end
