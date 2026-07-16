defmodule SovereignSoulEngineWeb.ChatLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.ConsequenceEngine

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scenes:list_updates")
    end

    player = Characters.get_character_by_slug!("goose")

    npcs =
      Enum.filter(Characters.list_characters(), &(&1.kind == "npc" and &1.status == "active"))

    socket =
      socket
      |> assign(:page_title, "Chat Room — Sovereign Soul Engine")
      |> assign(:player, player)
      |> assign(:npcs, npcs)
      |> assign(:creating_group?, false)
      |> assign(:group_name, "")
      |> assign(:group_location, "The Hollow Bastion")
      |> assign(:group_mood, "tense")
      |> assign(:group_weather, "overcast")
      |> assign(:selected_npc_ids, %{})
      |> assign(:editing_scenario?, false)
      |> assign(:showing_invite_menu?, false)
      |> assign(:invite_candidates, [])
      |> load_scenes()
      |> select_first_available_chat()

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # Helper to load scenes and split them into direct vs group chats
  defp load_scenes(socket) do
    player = socket.assigns.player

    # Fetch active scenes where the player is a participant
    scenes =
      SovereignSoulEngine.Repo.all(
        from s in SovereignSoulEngine.Scenes.Scene,
          join: p in assoc(s, :participants),
          where: s.status == "active" and p.character_id == ^player.id,
          preload: [participants: :character],
          order_by: [desc: s.inserted_at]
      )

    # Direct chat = exactly 2 participants (player + 1 NPC)
    # Group chat = > 2 participants
    {directs, groups} =
      Enum.split_with(scenes, fn scene ->
        length(scene.participants) == 2
      end)

    direct_npcs =
      Enum.map(directs, fn scene ->
        npc_participant = Enum.find(scene.participants, &(&1.character_id != player.id))
        {scene, npc_participant.character}
      end)

    socket
    |> assign(:direct_chats, direct_npcs)
    |> assign(:group_chats, groups)
  end

  # Select first available chat upon mount
  defp select_first_available_chat(socket) do
    cond do
      Enum.any?(socket.assigns.direct_chats) ->
        {scene, npc} = List.first(socket.assigns.direct_chats)
        socket
        |> assign(:selected_scene, scene)
        |> assign(:selected_npc, npc)
        |> assign_character_details()
        |> load_messages_for_selected()

      Enum.any?(socket.assigns.group_chats) ->
        scene = List.first(socket.assigns.group_chats)
        socket
        |> assign(:selected_scene, scene)
        |> assign(:selected_npc, nil)
        |> assign(:emotional_state, nil)
        |> load_messages_for_selected()

      true ->
        vael = Enum.find(socket.assigns.npcs, &(&1.slug == "vael"))
        if vael do
          scene = find_or_create_scene(socket.assigns.player, vael)
          socket
          |> load_scenes()
          |> select_scene(scene)
        else
          socket
          |> assign(:selected_scene, nil)
          |> assign(:selected_npc, nil)
          |> assign(:emotional_state, nil)
        end
    end
  end

  # Helper to load messages for selected scene and handle PubSub subscriptions
  defp load_messages_for_selected(socket) do
    scene = socket.assigns.selected_scene

    if scene do
      messages = Scenes.list_messages(scene.id)

      if connected?(socket) do
        if socket.assigns[:scene] do
          Phoenix.PubSub.unsubscribe(SovereignSoulEngine.PubSub, "scene:#{socket.assigns.scene.id}")
        end
        Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scene:#{scene.id}")
      end

      auto_play =
        case SovereignSoulEngine.Runtime.NPCRegistry.lookup_scene(scene.id) do
          {:ok, pid} ->
            case GenServer.call(pid, :get_state) do
              {:ok, %{auto_play: ap}} -> ap
              _ -> false
            end
          _ -> false
        end

      socket
      |> assign(:scene, scene)
      |> assign(:auto_play, auto_play)
      |> assign(:messages_empty?, messages == [])
      |> assign(:message_form, to_form(%{"content" => ""}, as: :message))
      |> stream(:messages, messages, reset: true)
      |> push_event("scroll-chat", %{})
    else
      socket
      |> assign(:scene, nil)
      |> assign(:auto_play, false)
      |> assign(:messages_empty?, true)
      |> assign(:message_form, to_form(%{"content" => ""}, as: :message))
      |> stream(:messages, [], reset: true)
    end
  end

  # Helper to select a scene
  defp select_scene(socket, scene) do
    player = socket.assigns.player
    scene = SovereignSoulEngine.Repo.preload(scene, [participants: :character], force: true)

    npc =
      if length(scene.participants) == 2 do
        npc_part = Enum.find(scene.participants, &(&1.character_id != player.id))
        npc_part.character
      else
        nil
      end

    current_participant_ids = Enum.map(scene.participants, & &1.character_id)
    invite_candidates = Enum.filter(socket.assigns.npcs, &(&1.id not in current_participant_ids))

    socket
    |> assign(:selected_scene, scene)
    |> assign(:selected_npc, npc)
    |> assign(:invite_candidates, invite_candidates)
    |> assign_character_details()
    |> load_messages_for_selected()
  end

  @impl true
  def handle_event("select_character", %{"character_id" => id}, socket) do
    npc = Enum.find(socket.assigns.npcs, &(&1.id == id))
    scene = find_or_create_scene(socket.assigns.player, npc)

    socket =
      socket
      |> assign(:creating_group?, false)
      |> load_scenes()
      |> select_scene(scene)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_scene", %{"scene_id" => id}, socket) do
    scene = Scenes.get_scene!(id)

    socket =
      socket
      |> assign(:creating_group?, false)
      |> select_scene(scene)

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_new_group", _params, socket) do
    {:noreply,
     socket
     |> assign(:creating_group?, true)
     |> assign(:selected_npc_ids, %{})
     |> assign(:group_name, "")}
  end

  @impl true
  def handle_event("toggle_npc", %{"npc_id" => id}, socket) do
    selected = socket.assigns.selected_npc_ids
    new_selected = Map.put(selected, id, !Map.get(selected, id, false))
    {:noreply, assign(socket, :selected_npc_ids, new_selected)}
  end

  @impl true
  def handle_event("create_group", %{"group_name" => name, "location" => location, "scenario_mood" => mood, "scenario_weather" => weather}, socket) do
    name = String.trim(name)
    selected_ids =
      socket.assigns.selected_npc_ids
      |> Enum.filter(fn {_id, checked} -> checked end)
      |> Enum.map(fn {id, _} -> id end)

    if name != "" and selected_ids != [] do
      player = socket.assigns.player
      location = if String.trim(location) == "", do: "Group Chat", else: String.trim(location)
      context = %{
        "mood" => if(String.trim(mood) == "", do: "tense", else: String.trim(mood)),
        "weather" => if(String.trim(weather) == "", do: "overcast", else: String.trim(weather))
      }

      # Create new active group scene
      {:ok, scene} =
        Scenes.create_scene(%{
          title: name,
          status: "active",
          location: location,
          context: context,
          started_at: DateTime.utc_now()
        })

      # Add participants
      Scenes.add_participant(%{scene_id: scene.id, character_id: player.id})
      for id <- selected_ids do
        Scenes.add_participant(%{scene_id: scene.id, character_id: id})
      end

      # Broadcast sidebar update
      Phoenix.PubSub.broadcast(SovereignSoulEngine.PubSub, "scenes:list_updates", {:scenes_updated, %{}})

      socket =
        socket
        |> assign(:creating_group?, false)
        |> load_scenes()
        |> select_scene(scene)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    unless String.trim(content) == "" do
      scene = socket.assigns.scene
      player = socket.assigns.player

      {:ok, msg} =
        Scenes.create_message(%{
          scene_id: scene.id,
          character_id: player.id,
          content: content,
          message_type: "dialogue"
        })

      correlation_id = Ecto.UUID.generate()

      # Broadcast user's message
      Phoenix.PubSub.broadcast(
        SovereignSoulEngine.PubSub,
        "scene:#{scene.id}",
        {:new_message, msg}
      )

      # Trigger response generation for each NPC participant in the scene
      participant_npcs =
        scene.participants
        |> Enum.map(& &1.character)
        |> Enum.filter(&(&1.kind == "npc" and &1.status == "active"))

      participant_npcs
      |> Enum.with_index()
      |> Enum.each(fn {npc, index} ->
        delay_ms = index * 4000

        # Player's consequence engine resolve relative to each NPC
        ConsequenceEngine.resolve(%{
          character_id: player.id,
          source_character_id: player.id,
          target_character_id: npc.id,
          scene_id: scene.id,
          event_type: :speak,
          event_intensity: 30,
          message_content: content,
          correlation_id: correlation_id
        })

        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "character:#{npc.id}",
          {:emotion_updated, %{}}
        )

        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "scene:#{scene.id}",
          {:state_updated, %{character_id: npc.id}}
        )

        # NPCs generate their response in the background with a turn delay
        if Mix.env() == :test do
          generate_npc_response(npc, player, scene, content)
        else
          Task.start(fn ->
            :timer.sleep(delay_ms)
            generate_npc_response(npc, player, scene, content)
          end)
        end
      end)

      Phoenix.PubSub.broadcast(
        SovereignSoulEngine.PubSub,
        "dashboard",
        {:ledger_updated, %{}}
      )
    end

    {:noreply,
     socket
     |> assign(:message_form, to_form(%{"content" => ""}, as: :message))}
  end

  @impl true
  def handle_event("toggle_edit_scenario", _params, socket) do
    {:noreply, assign(socket, :editing_scenario?, !socket.assigns.editing_scenario?)}
  end

  @impl true
  def handle_event("save_scenario", %{"location" => location, "mood" => mood, "weather" => weather, "narrative" => narrative}, socket) do
    scene = socket.assigns.selected_scene
    location = String.trim(location)
    context = %{
      "mood" => String.trim(mood),
      "weather" => String.trim(weather),
      "narrative" => String.trim(narrative)
    }

    {:ok, updated_scene} = Scenes.update_scene(scene, %{location: location, context: context})

    # Broadcast updates to scene so any other viewers (or background processors) get it
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "scene:#{scene.id}",
      {:state_updated, %{}}
    )

    socket =
      socket
      |> assign(:editing_scenario?, false)
      |> load_scenes()
      |> select_scene(updated_scene)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_invite_menu", _params, socket) do
    {:noreply, assign(socket, :showing_invite_menu?, !socket.assigns.showing_invite_menu?)}
  end

  @impl true
  def handle_event("invite_character", %{"character_id" => char_id}, socket) do
    scene = socket.assigns.selected_scene

    # 1. Add participant
    {:ok, _part} = Scenes.add_participant(%{scene_id: scene.id, character_id: char_id})

    # 2. If it was a direct chat (i.e. @selected_npc is set), convert it to a group room
    # We can do this by setting @selected_npc to nil, and updating the scene title if needed!
    socket =
      if socket.assigns.selected_npc do
        new_title = "#{socket.assigns.player.name}, #{socket.assigns.selected_npc.name} & others"
        {:ok, updated_scene} = Scenes.update_scene(scene, %{title: new_title})

        socket
        |> assign(:selected_npc, nil)
        |> assign(:selected_scene, updated_scene)
      else
        socket
      end

    # 3. Broadcast updates
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "scene:#{scene.id}",
      {:state_updated, %{}}
    )

    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "scenes:list_updates",
      {:scenes_updated, %{}}
    )

    # 4. Reload scenes and selected scene
    reloaded_scene = Scenes.get_scene!(scene.id)
    socket =
      socket
      |> assign(:showing_invite_menu?, false)
      |> load_scenes()
      |> select_scene(reloaded_scene)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, msg}, socket) do
    {:noreply,
     socket
     |> stream_insert(:messages, msg)
     |> assign(:messages_empty?, false)
     |> push_event("scroll-chat", %{})}
  end

  @impl true
  def handle_info({:scenes_updated, _}, socket) do
    {:noreply, load_scenes(socket)}
  end

  @impl true
  def handle_info({:state_updated, _}, socket) do
    # Reload selected scene to refresh participants and context details
    if scene_id = socket.assigns.selected_scene && socket.assigns.selected_scene.id do
      scene = Scenes.get_scene!(scene_id)
      {:noreply, select_scene(socket, scene)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp find_or_create_scene(player, npc) do
    SovereignSoulEngine.Repo.one(
      from s in SovereignSoulEngine.Scenes.Scene,
        join: p1 in SovereignSoulEngine.Scenes.SceneParticipant,
        on: p1.scene_id == s.id and p1.character_id == ^player.id,
        join: p2 in SovereignSoulEngine.Scenes.SceneParticipant,
        on: p2.scene_id == s.id and p2.character_id == ^npc.id,
        where: s.status == "active",
        order_by: [desc: s.inserted_at],
        limit: 1
    ) || create_direct_scene(player, npc)
  end

  defp create_direct_scene(player, npc) do
    {:ok, scene} =
      Scenes.create_scene(%{
        title: "#{player.name} & #{npc.name}",
        status: "active",
        location: "Direct Chat",
        context: %{},
        started_at: DateTime.utc_now()
      })

    Scenes.add_participant(%{scene_id: scene.id, character_id: player.id})
    Scenes.add_participant(%{scene_id: scene.id, character_id: npc.id})

    scene
  end

  defp assign_character_details(socket) do
    npc = socket.assigns.selected_npc

    if npc do
      soul_profile = Souls.get_soul_profile_by_character(npc.id)
      emotional_state = Souls.get_emotional_state_by_character(npc.id)

      socket
      |> assign(:soul_profile, soul_profile)
      |> assign(:emotional_state, emotional_state)
    else
      socket
      |> assign(:soul_profile, nil)
      |> assign(:emotional_state, nil)
    end
  end

  defp character_avatar_letter(npcs, id) do
    npc = Enum.find(npcs, &(&1.id == id))
    if npc, do: String.first(npc.name), else: "?"
  end

  defp character_name_by_id(npcs, id) do
    npc = Enum.find(npcs, &(&1.id == id))
    if npc, do: npc.name, else: "NPC"
  end

  defp format_time(nil), do: ""
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M")

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-base-100" id="chat-app">
      <%!-- Sidebar --%>
      <aside class="w-80 shrink-0 border-r border-base-300 bg-base-200/50 flex flex-col">
        <div class="p-4 border-b border-base-300 flex flex-col gap-2.5">
          <div class="flex items-center justify-between">
            <.link
              navigate={~p"/sse"}
              class="text-sm text-base-content/50 hover:text-base-content transition-colors inline-flex items-center gap-1"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Dashboard
            </.link>
            <div class="flex items-center gap-1.5">
              <.link
                navigate={~p"/sse/chat/sauce"}
                class="btn btn-ghost btn-xs text-amber-500 font-semibold flex items-center gap-1"
              >
                <.icon name="hero-wrench-screwdriver" class="size-3.5" /> Sauce
              </.link>
              <button
                phx-click="start_new_group"
                class="btn btn-ghost btn-xs text-primary font-semibold flex items-center gap-1"
              >
                <.icon name="hero-plus" class="size-3.5" /> New Group
              </button>
            </div>
          </div>
          <div>
            <h2 class="text-lg font-bold text-base-content">Sovereign Chat</h2>
            <p class="text-xs text-base-content/50">Talk with simulated souls</p>
          </div>
        </div>

        <nav class="flex-1 overflow-y-auto p-3 space-y-4">
          <%!-- Group Chats Section --%>
          <div class="space-y-1">
            <h3 class="px-2 text-[10px] font-bold text-base-content/40 uppercase tracking-wider">
              Group Rooms
            </h3>
            <div :if={@group_chats == []} class="px-2 text-xs text-base-content/30 italic py-1">
              No groups created yet.
            </div>
            <%= for group <- @group_chats do %>
              <button
                phx-click="select_scene"
                phx-value-scene_id={group.id}
                class={[
                  "w-full text-left p-3 rounded-xl transition-all duration-150 flex items-center gap-3",
                  !@creating_group? && @selected_scene && @selected_scene.id == group.id &&
                    "bg-primary/15 border border-primary/25 shadow-sm text-primary font-medium",
                  (@creating_group? || !@selected_scene || @selected_scene.id != group.id) &&
                    "hover:bg-base-300/40 border border-transparent"
                ]}
              >
                <div class="shrink-0 w-9 h-9 rounded-xl bg-purple-500/10 flex items-center justify-center border border-purple-500/20">
                  <.icon name="hero-user-group" class="size-5 text-purple-400" />
                </div>
                <div class="min-w-0 flex-1">
                  <div class="text-sm font-semibold truncate">{group.title}</div>
                  <div class="text-[11px] text-base-content/40 truncate">
                    {Enum.map(group.participants, & &1.character.name) |> Enum.join(", ")}
                  </div>
                </div>
              </button>
            <% end %>
          </div>

          <%!-- Direct Chats Section --%>
          <div class="space-y-1">
            <h3 class="px-2 text-[10px] font-bold text-base-content/40 uppercase tracking-wider">
              Direct Messages
            </h3>
            <%= for {scene, npc} <- @direct_chats do %>
              <button
                phx-click="select_character"
                phx-value-character_id={npc.id}
                class={[
                  "w-full text-left p-3 rounded-xl transition-all duration-150 flex items-center gap-3",
                  !@creating_group? && @selected_npc && @selected_npc.id == npc.id &&
                    "bg-primary/15 border border-primary/25 shadow-sm text-primary font-medium",
                  (@creating_group? || !@selected_npc || @selected_npc.id != npc.id) &&
                    "hover:bg-base-300/40 border border-transparent"
                ]}
              >
                <div class="shrink-0 w-9 h-9 rounded-full bg-primary/20 flex items-center justify-center">
                  <span class="text-xs font-bold text-primary">
                    {String.first(npc.name)}
                  </span>
                </div>
                <div class="min-w-0 flex-1">
                  <div class="text-sm font-semibold truncate">{npc.name}</div>
                  <div class="text-xs text-base-content/50 truncate">{npc.description}</div>
                </div>
                <div class="shrink-0 ml-auto">
                  <span class="inline-block w-2 h-2 rounded-full bg-emerald-500"></span>
                </div>
              </button>
            <% end %>
          </div>
        </nav>

        <%!-- Player identity at bottom --%>
        <div class="p-4 border-t border-base-300 bg-base-200/20">
          <div class="flex items-center gap-2.5">
            <div class="w-8 h-8 rounded-full bg-blue-500/20 flex items-center justify-center border border-blue-500/30">
              <span class="text-xs font-bold text-blue-400">
                {String.first(@player.name)}
              </span>
            </div>
            <div class="text-xs text-base-content/60">
              Logged in as <span class="font-bold text-base-content">{@player.name}</span>
            </div>
          </div>
        </div>
      </aside>

      <%!-- Group Creation Form (Modal state) --%>
      <div :if={@creating_group?} class="flex-1 flex flex-col bg-base-100 p-8 justify-center items-center">
        <div class="w-full max-w-md p-6 bg-base-200 rounded-2xl border border-base-300 shadow-xl space-y-6">
          <div class="text-center">
            <h2 class="text-lg font-bold text-base-content">Create Group Chat</h2>
            <p class="text-sm text-base-content/50">Talk with multiple souls simultaneously</p>
          </div>

          <form phx-submit="create_group" class="space-y-4">
            <div class="space-y-1.5">
              <label class="text-xs font-bold text-base-content/60 uppercase">Group Name</label>
              <input
                type="text"
                name="group_name"
                value={@group_name}
                placeholder="e.g. Bastion Council"
                required
                class="w-full input input-bordered text-sm"
              />
            </div>

            <div class="space-y-1.5">
              <label class="text-xs font-bold text-base-content/60 uppercase">Location / Scenario backdrop</label>
              <input
                type="text"
                name="location"
                value={@group_location}
                placeholder="e.g. Secret Passage"
                required
                class="w-full input input-bordered text-sm"
              />
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div class="space-y-1.5">
                <label class="text-xs font-bold text-base-content/60 uppercase">Mood</label>
                <input
                  type="text"
                  name="scenario_mood"
                  value={@group_mood}
                  placeholder="e.g. tense"
                  required
                  class="w-full input input-bordered text-sm"
                />
              </div>
              <div class="space-y-1.5">
                <label class="text-xs font-bold text-base-content/60 uppercase">Weather / Air</label>
                <input
                  type="text"
                  name="scenario_weather"
                  value={@group_weather}
                  placeholder="e.g. overcast"
                  required
                  class="w-full input input-bordered text-sm"
                />
              </div>
            </div>

            <div class="space-y-2">
              <label class="text-xs font-bold text-base-content/60 uppercase block">Select Members</label>
              <div class="max-h-48 overflow-y-auto space-y-1.5 p-2 bg-base-100 rounded-xl border border-base-300">
                <%= for npc <- @npcs do %>
                  <label class="flex items-center gap-3 p-2 hover:bg-base-200 rounded-lg cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={Map.get(@selected_npc_ids, npc.id, false)}
                      phx-click="toggle_npc"
                      phx-value-npc_id={npc.id}
                      class="checkbox checkbox-primary checkbox-sm"
                    />
                    <div class="text-sm font-medium">{npc.name}</div>
                  </label>
                <% end %>
              </div>
            </div>

            <div class="flex gap-3 justify-end pt-2">
              <button
                type="button"
                phx-click="select_first_available_chat"
                class="btn btn-ghost btn-sm"
              >
                Cancel
              </button>
              <button type="submit" class="btn btn-primary btn-sm px-5">
                Create
              </button>
            </div>
          </form>
        </div>
      </div>

      <%!-- Main Chat Area --%>
      <div :if={!@creating_group? && @selected_scene} class="flex-1 flex flex-col min-w-0">
        <%!-- Chat Header --%>
        <header class="shrink-0 flex items-center gap-3 px-6 py-4 border-b border-base-300 bg-base-200/30">
          <div :if={@selected_npc} class="w-10 h-10 rounded-full bg-primary/20 flex items-center justify-center">
            <span class="text-sm font-bold text-primary">
              {String.first(@selected_npc.name)}
            </span>
          </div>
          <div :if={!@selected_npc} class="w-10 h-10 rounded-xl bg-purple-500/15 flex items-center justify-center border border-purple-500/20">
            <.icon name="hero-user-group" class="size-5 text-purple-400" />
          </div>

          <div class="min-w-0 flex-1 space-y-1">
            <div class="flex items-center gap-3">
              <h1 class="text-base font-semibold text-base-content">
                {if @selected_npc, do: @selected_npc.name, else: @selected_scene.title}
              </h1>
              <%!-- Scenario Context --%>
              <div class="hidden md:flex items-center gap-2 text-[11px] bg-base-300/40 px-2 py-1 rounded-lg border border-base-300">
                <span class="font-mono text-base-content/40 uppercase text-[9px] tracking-wider">Scenario:</span>
                <span class="flex items-center gap-0.5 font-semibold text-base-content/70">
                  <.icon name="hero-map-pin" class="size-3 text-primary/80" />
                  {@selected_scene.location || "Unknown"}
                </span>
                <span class="text-base-content/30">•</span>
                <span class="flex items-center gap-0.5 font-semibold text-base-content/70">
                  <.icon name="hero-face-smile" class="size-3 text-secondary/80" />
                  {get_in(@selected_scene.context || %{}, ["mood"]) || "calm"}
                </span>
                <span class="text-base-content/30">•</span>
                <span class="flex items-center gap-0.5 font-semibold text-base-content/70">
                  <.icon name="hero-cloud" class="size-3 text-info/80" />
                  {get_in(@selected_scene.context || %{}, ["weather"]) || "clear"}
                </span>
                <button
                  phx-click="toggle_edit_scenario"
                  class="text-primary hover:text-primary-focus font-bold ml-1.5 hover:underline"
                >
                  Edit
                </button>
              </div>
            </div>
            <p class="text-xs text-base-content/50 truncate">
              {if @selected_npc,
                do: @selected_npc.description,
                else: Enum.map(@selected_scene.participants, & &1.character.name) |> Enum.join(", ")}
            </p>
          </div>

          <div class="flex items-center gap-3 shrink-0">
            <%!-- Invite Button & Dropdown --%>
            <div :if={@selected_scene && @invite_candidates != []} class="relative">
              <button
                phx-click="toggle_invite_menu"
                class="btn btn-outline btn-xs flex items-center gap-1 border-base-300 hover:bg-base-300 text-base-content/80"
              >
                <.icon name="hero-user-plus" class="size-3.5" /> Invite
              </button>
              <div :if={@showing_invite_menu?} class="absolute right-0 mt-1 w-52 rounded-xl border border-base-300 bg-base-200 shadow-xl z-50 p-1.5 space-y-1">
                <h4 class="px-2 py-1 text-[9px] font-bold text-base-content/40 uppercase tracking-wider font-mono">Invite Character</h4>
                <%= for candidate <- @invite_candidates do %>
                  <button
                    phx-click="invite_character"
                    phx-value-character_id={candidate.id}
                    class="w-full text-left px-2.5 py-1.5 rounded-lg hover:bg-base-300/80 text-xs font-semibold text-base-content transition-colors flex items-center gap-2"
                  >
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                    {candidate.name}
                  </button>
                <% end %>
              </div>
            </div>

            <%= if @emotional_state do %>
              <div class="hidden sm:flex items-center gap-2 text-xs text-base-content/50">
                <span title="Trust" class="flex items-center gap-1 bg-base-300/30 px-2 py-1 rounded-md">
                  <.icon name="hero-shield-check" class="size-3.5 text-emerald-400" />
                  {@emotional_state.confidence || 0}
                </span>
                <span title="Curiosity" class="flex items-center gap-1 bg-base-300/30 px-2 py-1 rounded-md">
                  <.icon name="hero-sparkles" class="size-3.5 text-cyan-400" />
                  {@emotional_state.curiosity || 0}
                </span>
              </div>
            <% end %>
          </div>
        </header>

        <%!-- Messages --%>
        <div
          id="chat-messages"
          phx-hook=".ChatScroll"
          phx-update="stream"
          class="flex-1 overflow-y-auto px-6 py-4 space-y-4"
        >
          <div
            :for={{dom_id, msg} <- @streams.messages}
            id={dom_id}
            class={[
              "flex gap-3 max-w-[80%]",
              msg.character_id == @player.id && "ml-auto flex-row-reverse",
              msg.character_id != @player.id && "mr-auto"
            ]}
          >
            <%!-- Avatar --%>
            <div class={[
              "shrink-0 w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold",
              msg.character_id == @player.id && "bg-blue-500/20 text-blue-400 border border-blue-500/30",
              msg.character_id != @player.id && "bg-primary/20 text-primary"
            ]}>
              <%= if msg.character_id == @player.id do %>
                {String.first(@player.name)}
              <% else %>
                {character_avatar_letter(@npcs, msg.character_id)}
              <% end %>
            </div>

            <div class="flex-1 min-w-0">
              <%!-- Speaker Name for group chats --%>
              <%= if !@selected_npc and msg.character_id != @player.id do %>
                <div class="text-[10px] font-semibold text-primary/75 mb-0.5 ml-1">
                  {character_name_by_id(@npcs, msg.character_id)}
                </div>
              <% end %>

              <div class={[
                "px-4 py-2.5 rounded-2xl text-sm leading-relaxed",
                msg.character_id == @player.id &&
                  "bg-primary text-primary-content rounded-tr-md",
                msg.character_id != @player.id &&
                  "bg-base-300 text-base-content rounded-tl-md"
              ]}>
                <p class="whitespace-pre-wrap break-words">{msg.content}</p>
                <%= if Map.get(msg, :private_thought) && Map.get(msg, :private_thought) != "" do %>
                  <div class="mt-2 pt-1.5 border-t border-purple-500/20 text-[10px] text-purple-400 font-mono">
                    <span class="font-bold">🧠 Thought:</span> {msg.private_thought}
                  </div>
                <% end %>
              </div>
              <div class={[
                "text-[9px] text-base-content/30 mt-1 ml-1",
                msg.character_id == @player.id && "text-right mr-1"
              ]}>
                {format_time(msg.inserted_at)}
              </div>
            </div>
          </div>

          <%!-- Empty state --%>
          <div :if={@messages_empty?} class="h-full flex items-center justify-center">
            <div class="text-center space-y-3">
              <div class="w-16 h-16 mx-auto rounded-full bg-primary/10 flex items-center justify-center">
                <.icon name="hero-chat-bubble-left-right" class="size-8 text-primary/50" />
              </div>
              <p class="text-base-content/60 font-medium">
                Start a conversation in {if @selected_npc, do: @selected_npc.name, else: @selected_scene.title}
              </p>
              <p class="text-sm text-base-content/40">Send a message below to begin.</p>
            </div>
          </div>
        </div>

        <%!-- Message Input --%>
        <div class="shrink-0 px-6 py-4 border-t border-base-300 bg-base-200/30">
          <.form
            for={@message_form}
            id="chat-form"
            phx-submit="send_message"
            class="flex items-end gap-3"
          >
            <div class="flex-1 relative">
              <input
                type="text"
                name="message[content]"
                id="chat-input"
                value={Phoenix.HTML.Form.normalize_value("text", @message_form[:content].value)}
                placeholder={["Message ", if(@selected_npc, do: @selected_npc.name, else: @selected_scene.title), "..."]}
                autocomplete="off"
                class="w-full input input-bordered pr-12 text-sm focus:outline-none focus:border-primary/50"
                phx-hook=".ChatInput"
              />
            </div>
            <button
              type="submit"
              id="chat-send-btn"
              class="btn btn-primary btn-square shrink-0"
              phx-disable-with={".icon name=\"hero-arrow-path\" class=\"size-5 motion-safe:animate-spin\""}
            >
              <.icon name="hero-paper-airplane" class="size-5 rotate-90" />
            </button>
          </.form>
        </div>

        <%!-- Colocated hook: auto-scroll to bottom --%>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".ChatScroll">
          export default {
            mounted() {
              this.scrollToBottom()
              this.handleEvent("scroll-chat", () => this.scrollToBottom())
            },
            updated() {
              this.scrollToBottom()
            },
            scrollToBottom() {
              requestAnimationFrame(() => {
                this.el.scrollTop = this.el.scrollHeight
              })
            }
          }
        </script>

        <%!-- Colocated hook: autofocus input --%>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".ChatInput">
          export default {
            mounted() {
              this.el.focus()
            }
          }
        </script>
      </div>

      <%!-- No active chat at allFallback --%>
      <div :if={!@creating_group? && !@selected_scene} class="flex-1 flex items-center justify-center">
        <div class="text-center space-y-3">
          <div class="w-20 h-20 mx-auto rounded-full bg-base-200 flex items-center justify-center">
            <.icon name="hero-user-group" class="size-10 text-base-content/30" />
          </div>
          <p class="text-lg font-medium text-base-content/60">No Active Chats</p>
          <p class="text-sm text-base-content/40">
            Select a character or create a group chat from the sidebar to begin.
          </p>
        </div>
      </div>

      <%!-- Edit Scenario Modal --%>
      <div :if={@editing_scenario? && @selected_scene} class="fixed inset-0 bg-base-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
        <div class="w-full max-w-md p-6 bg-base-200 rounded-2xl border border-base-300 shadow-xl space-y-6">
          <div class="text-center">
            <h2 class="text-lg font-bold text-base-content">Edit Room Scenario</h2>
            <p class="text-sm text-base-content/50">Change the narrative backdrop for this room</p>
          </div>

          <form phx-submit="save_scenario" class="space-y-4">
            <div class="space-y-1.5">
              <label class="text-xs font-bold text-base-content/60 uppercase">Location</label>
              <input
                type="text"
                name="location"
                value={@selected_scene.location}
                placeholder="e.g. Secret Passage"
                required
                class="w-full input input-bordered text-sm"
              />
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div class="space-y-1.5">
                <label class="text-xs font-bold text-base-content/60 uppercase">Mood</label>
                <input
                  type="text"
                  name="mood"
                  value={get_in(@selected_scene.context || %{}, ["mood"]) || "calm"}
                  placeholder="e.g. tense"
                  required
                  class="w-full input input-bordered text-sm"
                />
              </div>
              <div class="space-y-1.5">
                <label class="text-xs font-bold text-base-content/60 uppercase">Weather / Air</label>
                <input
                  type="text"
                  name="weather"
                  value={get_in(@selected_scene.context || %{}, ["weather"]) || "clear"}
                  placeholder="e.g. overcast"
                  required
                  class="w-full input input-bordered text-sm"
                />
              </div>
            </div>

            <div class="space-y-1.5">
              <label class="text-xs font-bold text-base-content/60 uppercase">Scene Narrative / Transition description (DM mode)</label>
              <textarea
                name="narrative"
                rows="3"
                placeholder="Describe what is happening as the room transitions (e.g. who meets whom, what they see)..."
                class="w-full textarea textarea-bordered text-sm leading-relaxed"
              >{get_in(@selected_scene.context || %{}, ["narrative"]) || ""}</textarea>
            </div>

            <div class="flex gap-3 justify-end pt-2">
              <button
                type="button"
                phx-click="toggle_edit_scenario"
                class="btn btn-ghost btn-sm"
              >
                Cancel
              </button>
              <button type="submit" class="btn btn-primary btn-sm px-5">
                Save
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp generate_npc_response(npc, player, scene, _user_message) do
    SovereignSoulEngine.Souls.Generator.generate(npc.id, scene.id, player.id)
  end
end
