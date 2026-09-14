defmodule SovereignSoulEngineWeb.ChatLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.ConsequenceEngine
  alias SovereignSoulEngine.TheoryOfMind

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    player = Characters.get_character_by_slug!("goose")

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scenes:list_updates")
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "character:#{player.id}:biometrics")
    end

    player_somatic = Souls.get_or_create_somatic_state(player.id)
    player_emotional = Souls.get_emotional_state_by_character(player.id)

    biometrics = %{
      heart_rate: 72,
      stress: (player_emotional && player_emotional.stress) || 20,
      fatigue: (player_somatic && player_somatic.fatigue) || 15,
      motion: "resting"
    }

    npcs =
      Enum.filter(Characters.list_characters(), &(&1.kind == "npc" and &1.status == "active"))

    socket =
      socket
      |> assign(:page_title, "Chat Room — Sovereign Soul Engine")
      |> assign(:player, player)
      |> assign(:player_biometrics, biometrics)
      |> assign(:voice_enabled?, false)
      |> assign(:simulating_somatic?, false)
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
      |> assign(:is_generating?, false)
      |> assign(:typing_npc_name, nil)
      |> load_scenes()
      |> select_first_available_chat()

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_params(%{"character_id" => id}, _uri, socket) do
    case Enum.find(socket.assigns.npcs, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      npc ->
        scene = Scenes.find_or_create_direct_scene(socket.assigns.player, npc)

        socket =
          socket
          |> assign(:creating_group?, false)
          |> load_scenes()
          |> select_scene(scene)

        {:noreply, socket}
    end
  end

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
      directs
      |> Enum.map(fn scene ->
        npc_participant = Enum.find(scene.participants, &(&1.character_id != player.id))
        {scene, npc_participant && npc_participant.character}
      end)
      |> Enum.filter(fn {_scene, char} -> char && char.status == "active" end)

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
          scene = Scenes.find_or_create_direct_scene(socket.assigns.player, vael)

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
          Phoenix.PubSub.unsubscribe(
            SovereignSoulEngine.PubSub,
            "scene:#{socket.assigns.scene.id}"
          )
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

          _ ->
            false
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

  # Refresh scene participants and character details without touching the message stream.
  defp refresh_scene_metadata(socket) do
    player = socket.assigns.player

    scene =
      SovereignSoulEngine.Repo.preload(
        socket.assigns.selected_scene,
        [participants: :character],
        force: true
      )

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
    |> assign(:scene, scene)
    |> assign(:selected_npc, npc)
    |> assign(:invite_candidates, invite_candidates)
    |> assign_character_details()
  end

  @impl true
  def handle_event("select_character", %{"character_id" => id}, socket) do
    npc = Enum.find(socket.assigns.npcs, &(&1.id == id))
    scene = Scenes.find_or_create_direct_scene(socket.assigns.player, npc)

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
  def handle_event(
        "create_group",
        %{
          "group_name" => name,
          "location" => location,
          "scenario_mood" => mood,
          "scenario_weather" => weather
        },
        socket
      ) do
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
      Phoenix.PubSub.broadcast(
        SovereignSoulEngine.PubSub,
        "scenes:list_updates",
        {:scenes_updated, %{}}
      )

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

      # Automatically detect and arm open life threads (proposals, surgeries, interviews, loneliness)
      Enum.each(participant_npcs, fn npc ->
        TheoryOfMind.record_life_thread_if_detected(npc.id, player.id, content)
      end)

      # Determine which NPC(s) should speak:
      responding_npcs =
        cond do
          socket.assigns[:selected_npc] ->
            [socket.assigns.selected_npc]

          true ->
            lower_content = String.downcase(content)

            mentioned =
              Enum.filter(participant_npcs, fn npc ->
                first_name = hd(String.split(npc.name)) |> String.downcase()

                String.contains?(lower_content, String.downcase(npc.slug)) or
                  (String.length(first_name) > 2 and String.contains?(lower_content, first_name))
              end)

            case mentioned do
              [first | _] -> [first]
              [] -> Enum.take(participant_npcs, 1)
            end
        end

      # All NPCs in the scene process the consequence of the player speaking
      Enum.each(participant_npcs, fn npc ->
        ConsequenceEngine.resolve(%{
          character_id: player.id,
          source_character_id: player.id,
          target_character_id: npc.id,
          scene_id: scene.id,
          event_type: :speak,
          event_intensity: 30,
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
      end)

      # Emit immediate visceral action / presence beat beforehand so the player gets instant feedback
      case responding_npcs do
        [first_npc | _] ->
          emit_immediate_reaction(first_npc, scene, player)

        _ ->
          :ok
      end

      # Only responding NPC(s) generate their spoken response
      responding_npcs
      |> Enum.with_index()
      |> Enum.each(fn {npc, index} ->
        delay_ms = index * 2000

        if Mix.env() == :test do
          generate_npc_response(npc, player, scene, content)
        else
          Task.start(fn ->
            :timer.sleep(delay_ms)

            try do
              case generate_npc_response(npc, player, scene, content) do
                {:ok, _} ->
                  :ok

                {:error, reason} ->
                  require Logger

                  Logger.error(
                    "NPC generation failed for #{npc.name} (#{npc.id}): #{inspect(reason)}"
                  )

                  Phoenix.PubSub.broadcast(
                    SovereignSoulEngine.PubSub,
                    "scene:#{scene.id}",
                    {:generation_failed, npc.id}
                  )
              end
            rescue
              e ->
                require Logger

                Logger.error(
                  "NPC Task crash for #{npc.name} (#{npc.id}): #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
                )

                Phoenix.PubSub.broadcast(
                  SovereignSoulEngine.PubSub,
                  "scene:#{scene.id}",
                  {:generation_failed, npc.id}
                )
            end
          end)
        end
      end)

      Phoenix.PubSub.broadcast(
        SovereignSoulEngine.PubSub,
        "dashboard",
        {:ledger_updated, %{}}
      )

      typing_name =
        case responding_npcs do
          [first | _] -> first.name
          _ -> "Companion"
        end

      Process.send_after(self(), :generation_timeout, 60_000)

      socket =
        socket
        |> assign(:is_generating?, true)
        |> assign(:typing_npc_name, typing_name)
        |> push_event("clear-chat-input", %{})
        |> push_event("scroll-chat", %{})
        |> assign(:message_form, to_form(%{"content" => ""}, as: :message))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_edit_scenario", _params, socket) do
    {:noreply, assign(socket, :editing_scenario?, !socket.assigns.editing_scenario?)}
  end

  @impl true
  def handle_event(
        "save_scenario",
        %{"location" => location, "mood" => mood, "weather" => weather, "narrative" => narrative},
        socket
      ) do
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
  def handle_event("toggle_voice", _params, socket) do
    {:noreply, assign(socket, :voice_enabled?, !socket.assigns.voice_enabled?)}
  end

  @impl true
  def handle_event("toggle_somatic_sim", _params, socket) do
    {:noreply, assign(socket, :simulating_somatic?, !socket.assigns.simulating_somatic?)}
  end

  @impl true
  def handle_event("apply_somatic_sim", %{"bpm" => bpm, "stress" => stress, "fatigue" => fatigue, "motion" => motion}, socket) do
    bpm = String.to_integer(bpm)
    stress = String.to_integer(stress)
    fatigue = String.to_integer(fatigue)
    player = socket.assigns.player

    # 1. Update player somatic state
    somatic = Souls.get_or_create_somatic_state(player.id)
    Souls.update_somatic_state(somatic, %{fatigue: fatigue})

    # 2. Update player emotional state
    if emo = Souls.get_emotional_state_by_character(player.id) do
      Souls.update_emotional_state(emo, %{stress: stress})
    end

    # 3. Notify all companions' Theory of Mind
    Enum.each(socket.assigns.npcs, fn npc ->
      TheoryOfMind.upsert_knowledge(
        npc.id,
        player.id,
        "Goose's somatic telemetry indicates heart rate at #{bpm} bpm, stress level #{stress}/100, fatigue #{fatigue}/100, motion state: #{motion}.",
        certainty: 90
      )
    end)

    # 4. Broadcast live telemetry
    payload = %{
      character_id: player.id,
      telemetry: %{heart_rate: bpm, stress_level: stress, fatigue_level: fatigue, motion_state: motion},
      somatic: %{fatigue: fatigue, pain: 0},
      emotional: %{stress: stress}
    }
    Phoenix.PubSub.broadcast(SovereignSoulEngine.PubSub, "character:#{player.id}:biometrics", {:telemetry_received, payload})

    socket =
      socket
      |> assign(:player_biometrics, %{heart_rate: bpm, stress: stress, fatigue: fatigue, motion: motion})
      |> assign(:simulating_somatic?, false)

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
    # Only clear the typing indicator when an NPC dialogue response arrives
    is_companion_dialogue =
      msg.character_id != socket.assigns.player.id and msg.message_type == "dialogue"

    socket =
      if is_companion_dialogue do
        socket
        |> assign(:is_generating?, false)
        |> assign(:typing_npc_name, nil)
      else
        socket
      end

    {:noreply,
     socket
     |> stream_insert(:messages, msg)
     |> assign(:messages_empty?, false)
     |> push_event("scroll-chat", %{})}
  end

  @impl true
  def handle_info({:generation_failed, _character_id}, socket) do
    {:noreply,
     socket
     |> assign(:is_generating?, false)
     |> assign(:typing_npc_name, nil)}
  end

  @impl true
  def handle_info(:generation_timeout, socket) do
    {:noreply,
     socket
     |> assign(:is_generating?, false)
     |> assign(:typing_npc_name, nil)}
  end

  @impl true
  def handle_info({:audio_ready, msg}, socket) do
    socket = stream_insert(socket, :messages, msg)

    audio_url = get_in(msg.metadata || %{}, ["audio_url"])

    socket =
      if audio_url && socket.assigns[:voice_enabled?] do
        push_event(socket, "play_audio", %{url: audio_url})
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:telemetry_received, payload}, socket) do
    tel = payload[:telemetry] || %{}
    som = payload[:somatic] || %{}
    emo = payload[:emotional] || %{}

    updated = %{
      heart_rate: tel[:heart_rate] || socket.assigns.player_biometrics.heart_rate,
      stress: emo[:stress] || tel[:stress_level] || socket.assigns.player_biometrics.stress,
      fatigue: som[:fatigue] || tel[:fatigue_level] || socket.assigns.player_biometrics.fatigue,
      motion: tel[:motion_state] || socket.assigns.player_biometrics.motion
    }

    {:noreply, assign(socket, :player_biometrics, updated)}
  end

  @impl true
  def handle_info({:scenes_updated, _}, socket) do
    {:noreply, load_scenes(socket)}
  end

  @impl true
  def handle_info({:state_updated, _}, socket) do
    # Refresh participants and emotional state without resetting the message stream.
    # select_scene would reset the stream via load_messages_for_selected, causing
    # duplicates when messages are already arriving via {:new_message} broadcasts.
    if socket.assigns.selected_scene do
      {:noreply, refresh_scene_metadata(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

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
              <.link
                navigate={~p"/sse/acp"}
                class="btn btn-ghost btn-xs text-purple-400 font-semibold flex items-center gap-1"
              >
                <.icon name="hero-cpu-chip" class="size-3.5" /> ACP
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
                  <span class="text-xs font-bold text-primary">{String.first(npc.name)}</span>
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
              <span class="text-xs font-bold text-blue-400">{String.first(@player.name)}</span>
            </div>
            
            <div class="text-xs text-base-content/60">
              Logged in as <span class="font-bold text-base-content">{@player.name}</span>
            </div>
          </div>
        </div>
      </aside>
       <%!-- Group Creation Form (Modal state) --%>
      <div
        :if={@creating_group?}
        class="flex-1 flex flex-col bg-base-100 p-8 justify-center items-center"
      >
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
              <label class="text-xs font-bold text-base-content/60 uppercase">
                Location / Scenario backdrop
              </label>
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
              <label class="text-xs font-bold text-base-content/60 uppercase block">
                Select Members
              </label>
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
              </button> <button type="submit" class="btn btn-primary btn-sm px-5">Create</button>
            </div>
          </form>
        </div>
      </div>
       <%!-- Main Chat Area --%>
      <div :if={!@creating_group? && @selected_scene} class="flex-1 flex flex-col min-w-0">
        <%!-- Chat Header --%>
        <header class="shrink-0 flex items-center gap-3 px-6 py-4 border-b border-base-300 bg-base-200/30">
          <div
            :if={@selected_npc}
            class="w-10 h-10 rounded-full bg-primary/20 flex items-center justify-center"
          >
            <span class="text-sm font-bold text-primary">{String.first(@selected_npc.name)}</span>
          </div>
          
          <div
            :if={!@selected_npc}
            class="w-10 h-10 rounded-xl bg-purple-500/15 flex items-center justify-center border border-purple-500/20"
          >
            <.icon name="hero-user-group" class="size-5 text-purple-400" />
          </div>
          
          <div class="min-w-0 flex-1 space-y-1">
            <div class="flex items-center gap-3">
              <h1 class="text-base font-semibold text-base-content">
                {if @selected_npc, do: @selected_npc.name, else: @selected_scene.title}
              </h1>
               <%!-- Scenario Context --%>
              <div class="hidden md:flex items-center gap-2 text-[11px] bg-base-300/40 px-2 py-1 rounded-lg border border-base-300">
                <span class="font-mono text-base-content/40 uppercase text-[9px] tracking-wider">
                  Scenario:
                </span>
                <span class="flex items-center gap-0.5 font-semibold text-base-content/70">
                  <.icon name="hero-map-pin" class="size-3 text-primary/80" /> {@selected_scene.location ||
                    "Unknown"}
                </span> <span class="text-base-content/30">•</span>
                <span class="flex items-center gap-0.5 font-semibold text-base-content/70">
                  <.icon name="hero-face-smile" class="size-3 text-secondary/80" /> {get_in(
                    @selected_scene.context || %{},
                    ["mood"]
                  ) || "calm"}
                </span> <span class="text-base-content/30">•</span>
                <span class="flex items-center gap-0.5 font-semibold text-base-content/70">
                  <.icon name="hero-cloud" class="size-3 text-info/80" /> {get_in(
                    @selected_scene.context || %{},
                    ["weather"]
                  ) || "clear"}
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
            <div :if={@invite_candidates != []} class="relative">
              <button
                phx-click="toggle_invite_menu"
                class="btn btn-outline btn-xs flex items-center gap-1 border-base-300 hover:bg-base-300 text-base-content/80"
              >
                <.icon name="hero-user-plus" class="size-3.5" /> Invite
              </button>
              <div
                :if={@showing_invite_menu?}
                class="absolute right-0 mt-1 w-52 rounded-xl border border-base-300 bg-base-200 shadow-xl z-50 p-1.5 space-y-1"
              >
                <h4 class="px-2 py-1 text-[9px] font-bold text-base-content/40 uppercase tracking-wider font-mono">
                  Invite Character
                </h4>
                
                <%= for candidate <- @invite_candidates do %>
                  <button
                    phx-click="invite_character"
                    phx-value-character_id={candidate.id}
                    class="w-full text-left px-2.5 py-1.5 rounded-lg hover:bg-base-300/80 text-xs font-semibold text-base-content transition-colors flex items-center gap-2"
                  >
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> {candidate.name}
                  </button>
                <% end %>
              </div>
            </div>
            
            <%!-- Galaxy Watch Biometric HUD --%>
            <div class="hidden xl:flex items-center gap-2.5 px-3 py-1.5 rounded-xl bg-base-300/40 border border-base-300 text-xs">
              <span class="flex items-center gap-1 font-mono font-bold text-rose-400">
                <span class="animate-pulse">❤️</span> {@player_biometrics.heart_rate} BPM
              </span>
              <span class="text-base-content/20">•</span>
              <span class="font-mono text-[11px] text-amber-400">
                ⚡ {@player_biometrics.stress}/100
              </span>
              <span class="text-base-content/20">•</span>
              <span class="font-mono text-[11px] text-sky-400">
                💤 {@player_biometrics.fatigue}/100
              </span>
              <button
                phx-click="toggle_somatic_sim"
                class="btn btn-ghost btn-xs text-primary font-bold ml-1 hover:bg-primary/20"
                title="Simulate Galaxy Watch pulse"
              >
                <.icon name="hero-bolt" class="size-3" /> Pulse
              </button>
            </div>

            <%!-- Voice Audio Toggle --%>
            <button
              phx-click="toggle_voice"
              class={[
                "btn btn-xs flex items-center gap-1.5 border transition-all",
                @voice_enabled? && "btn-success text-success-content border-success shadow-sm",
                !@voice_enabled? && "btn-outline border-base-300 text-base-content/60 hover:bg-base-300"
              ]}
              title="Toggle automatic companion voice audio"
            >
              <.icon name={if @voice_enabled?, do: "hero-speaker-wave", else: "hero-speaker-x-mark"} class="size-3.5" />
              {if @voice_enabled?, do: "Voice ON", else: "Voice OFF"}
            </button>

            <%= if @emotional_state do %>
              <div class="hidden sm:flex items-center gap-2 text-xs text-base-content/50">
                <span
                  title="Trust"
                  class="flex items-center gap-1 bg-base-300/30 px-2 py-1 rounded-md"
                >
                  <.icon name="hero-shield-check" class="size-3.5 text-emerald-400" /> {@emotional_state.confidence ||
                    0}
                </span>
                <span
                  title="Curiosity"
                  class="flex items-center gap-1 bg-base-300/30 px-2 py-1 rounded-md"
                >
                  <.icon name="hero-sparkles" class="size-3.5 text-cyan-400" /> {@emotional_state.curiosity ||
                    0}
                </span>
              </div>
            <% end %>
          </div>
        </header>
        
        <div
          id="chat-scroll-container"
          phx-hook=".ChatScroll"
          class={["flex-1 overflow-y-auto px-6 py-4 space-y-4", @messages_empty? && "hidden"]}
        >
          <div
            id="chat-messages"
            phx-update="stream"
            class="space-y-4"
          >
            <%= for {dom_id, msg} <- @streams.messages do %>
              <%= cond do %>
                <% msg.message_type == "action" -> %>
                  <div
                    id={dom_id}
                    class="flex items-start gap-2 px-2 py-0.5 mx-auto max-w-[90%] w-full"
                  >
                    <div class="flex-1 text-center">
                      <p class="text-xs italic text-amber-400/80 leading-relaxed font-medium tracking-wide">
                        <span class="text-amber-500/40 select-none">**</span>{msg.content}<span class="text-amber-500/40 select-none">**</span>
                      </p>
                      
                      <div class="text-[9px] text-base-content/25 mt-0.5">
                        {format_time(msg.inserted_at)}
                      </div>
                    </div>
                  </div>
                <% true -> %>
                  <div
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
                      msg.character_id == @player.id &&
                        "bg-blue-500/20 text-blue-400 border border-blue-500/30",
                      msg.character_id != @player.id && "bg-primary/20 text-primary"
                    ]}>
                      <%= if msg.character_id == @player.id do %>
                        {String.first(@player.name)}
                      <% else %>
                        {character_avatar_letter(@npcs, msg.character_id)}
                      <% end %>
                    </div>
                    
                    <div class="flex-1 min-w-0">
                      <%!-- Speaker name for group chats --%>
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

                        <%= if audio_url = get_in(msg.metadata || %{}, ["audio_url"]) do %>
                          <div class="mt-2 pt-1.5 border-t border-base-content/10 flex items-center gap-2">
                            <audio controls src={audio_url} class="h-7 w-60 max-w-full rounded-lg opacity-90"></audio>
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
              <% end %>
            <% end %>
          </div>

          <div
            :if={@is_generating?}
            id="companion-typing-indicator"
            class="flex items-center gap-2.5 px-4 py-2 my-2 rounded-2xl bg-base-200/60 border border-base-300/40 text-xs text-base-content/60 italic animate-pulse w-fit"
          >
            <span class="loading loading-dots loading-xs text-primary"></span>
            <span>{@typing_npc_name || "Companion"} is formulating a response...</span>
          </div>
        </div>
         <%!-- Empty state --%>
        <div :if={@messages_empty?} class="flex-1 flex items-center justify-center">
          <div class="text-center space-y-3">
            <div class="w-16 h-16 mx-auto rounded-full bg-primary/10 flex items-center justify-center">
              <.icon name="hero-chat-bubble-left-right" class="size-8 text-primary/50" />
            </div>
            
            <p class="text-base-content/60 font-medium">
              Start a conversation in {if @selected_npc,
                do: @selected_npc.name,
                else: @selected_scene.title}
            </p>
            
            <p class="text-sm text-base-content/40">Send a message below to begin.</p>
          </div>
        </div>
         <%!-- Message Input --%>
        <div class="shrink-0 px-6 py-4 border-t border-base-300 bg-base-200/30">
          <.form
            for={@message_form}
            id="chat-form"
            phx-submit="send_message"
            onsubmit="const input = document.getElementById('chat-input'); if(input) { setTimeout(() => { input.value = ''; }, 0); }"
            class="flex items-end gap-3"
          >
            <div class="flex-1 relative">
              <input
                type="text"
                name="message[content]"
                id="chat-input"
                value={Phoenix.HTML.Form.normalize_value("text", @message_form[:content].value)}
                placeholder={[
                  "Message ",
                  if(@selected_npc, do: @selected_npc.name, else: @selected_scene.title),
                  "..."
                ]}
                autocomplete="off"
                class="w-full input input-bordered pr-12 text-sm focus:outline-none focus:border-primary/50"
                phx-hook=".ChatInput"
              />
            </div>
            
            <button
              type="submit"
              id="chat-send-btn"
              class="btn btn-primary btn-square shrink-0"
              disabled={@is_generating?}
            >
              <.icon :if={!@is_generating?} name="hero-paper-airplane" class="size-5 rotate-90" />
              <.icon :if={@is_generating?} name="hero-arrow-path" class="size-5 motion-safe:animate-spin" />
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
         <%!-- Colocated hook: autofocus input and clear on submit --%>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".ChatInput">
          export default {
            mounted() {
              this.el.focus()
              const clearInput = () => {
                this.el.value = ""
                this.el.focus()
              }
              this.el.form?.addEventListener("submit", () => {
                setTimeout(clearInput, 0)
                setTimeout(clearInput, 50)
              })
              this.handleEvent("clear-chat-input", clearInput)
              window.addEventListener("phx:clear-chat-input", clearInput)
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
      <div
        :if={@editing_scenario? && @selected_scene}
        class="fixed inset-0 bg-base-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      >
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
              <label class="text-xs font-bold text-base-content/60 uppercase">
                Scene Narrative / Transition description (DM mode)
              </label> <textarea
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
              </button> <button type="submit" class="btn btn-primary btn-sm px-5">Save</button>
            </div>
          </form>
        </div>
      </div>

      <%!-- Somatic Biometrics Simulator Modal --%>
      <div
        :if={@simulating_somatic?}
        class="fixed inset-0 bg-base-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      >
        <div class="w-full max-w-lg p-6 bg-base-200 rounded-2xl border border-base-300 shadow-2xl space-y-5">
          <div class="text-center">
            <h2 class="text-lg font-bold text-base-content flex items-center justify-center gap-2">
              <span class="text-rose-500 animate-pulse">❤️</span> Wearable Somatic Hub
            </h2>
            <p class="text-xs text-base-content/50 mt-1">
              Pulse biometrics into companions' Theory of Mind
            </p>
          </div>

          <%!-- Quick Presets --%>
          <div class="space-y-1.5">
            <label class="text-[10px] font-bold text-base-content/50 uppercase tracking-wider">Quick Presets</label>
            <div class="grid grid-cols-2 gap-2">
              <button
                type="button"
                phx-click="apply_somatic_sim"
                phx-value-bpm="68"
                phx-value-stress="15"
                phx-value-fatigue="10"
                phx-value-motion="resting"
                class="btn btn-outline btn-xs flex justify-between px-3 border-emerald-500/30 hover:bg-emerald-500/15 text-emerald-400"
              >
                <span>🟢 Calm Baseline</span>
                <span class="font-mono text-[10px]">68 bpm</span>
              </button>

              <button
                type="button"
                phx-click="apply_somatic_sim"
                phx-value-bpm="135"
                phx-value-stress="88"
                phx-value-fatigue="40"
                phx-value-motion="pacing"
                class="btn btn-outline btn-xs flex justify-between px-3 border-rose-500/30 hover:bg-rose-500/15 text-rose-400"
              >
                <span>🔴 Stress Spike</span>
                <span class="font-mono text-[10px]">135 bpm</span>
              </button>

              <button
                type="button"
                phx-click="apply_somatic_sim"
                phx-value-bpm="105"
                phx-value-stress="45"
                phx-value-fatigue="15"
                phx-value-motion="still"
                class="btn btn-outline btn-xs flex justify-between px-3 border-purple-500/30 hover:bg-purple-500/15 text-purple-400"
              >
                <span>💜 Intimate / Aroused</span>
                <span class="font-mono text-[10px]">105 bpm</span>
              </button>

              <button
                type="button"
                phx-click="apply_somatic_sim"
                phx-value-bpm="58"
                phx-value-stress="25"
                phx-value-fatigue="90"
                phx-value-motion="resting"
                class="btn btn-outline btn-xs flex justify-between px-3 border-sky-500/30 hover:bg-sky-500/15 text-sky-400"
              >
                <span>💤 Exhaustion</span>
                <span class="font-mono text-[10px]">58 bpm</span>
              </button>
            </div>
          </div>

          <%!-- Custom Simulation Form --%>
          <form phx-submit="apply_somatic_sim" class="space-y-4 pt-1">
            <div class="grid grid-cols-2 gap-3">
              <div class="space-y-1">
                <label class="text-xs font-semibold text-base-content/70 flex justify-between">
                  <span>Heart Rate (BPM)</span>
                  <span class="font-mono text-rose-400 font-bold" id="bpm-val">{@player_biometrics.heart_rate}</span>
                </label>
                <input
                  type="number"
                  name="bpm"
                  min="40"
                  max="200"
                  value={@player_biometrics.heart_rate}
                  class="w-full input input-bordered input-sm font-mono"
                  required
                />
              </div>

              <div class="space-y-1">
                <label class="text-xs font-semibold text-base-content/70 flex justify-between">
                  <span>Stress (0-100)</span>
                  <span class="font-mono text-amber-400 font-bold">{@player_biometrics.stress}</span>
                </label>
                <input
                  type="number"
                  name="stress"
                  min="0"
                  max="100"
                  value={@player_biometrics.stress}
                  class="w-full input input-bordered input-sm font-mono"
                  required
                />
              </div>

              <div class="space-y-1">
                <label class="text-xs font-semibold text-base-content/70 flex justify-between">
                  <span>Fatigue (0-100)</span>
                  <span class="font-mono text-sky-400 font-bold">{@player_biometrics.fatigue}</span>
                </label>
                <input
                  type="number"
                  name="fatigue"
                  min="0"
                  max="100"
                  value={@player_biometrics.fatigue}
                  class="w-full input input-bordered input-sm font-mono"
                  required
                />
              </div>

              <div class="space-y-1">
                <label class="text-xs font-semibold text-base-content/70">Motion State</label>
                <select name="motion" class="w-full select select-bordered select-sm text-xs">
                  <option value="resting" selected={@player_biometrics.motion == "resting"}>resting</option>
                  <option value="still" selected={@player_biometrics.motion == "still"}>still</option>
                  <option value="walking" selected={@player_biometrics.motion == "walking"}>walking</option>
                  <option value="pacing" selected={@player_biometrics.motion == "pacing"}>pacing</option>
                  <option value="running" selected={@player_biometrics.motion == "running"}>running</option>
                </select>
              </div>
            </div>

            <%!-- Webhook Info --%>
            <div class="p-3 bg-base-300/40 rounded-xl border border-base-300 text-[11px] space-y-1">
              <div class="font-bold text-base-content/80 flex items-center gap-1">
                <.icon name="hero-device-phone-mobile" class="size-3.5 text-primary" /> Galaxy Watch Live Webhook
              </div>
              <div class="font-mono text-[10px] text-primary/80 break-all select-all">
                POST /sse/api/telemetry/somatic
              </div>
              <div class="text-[10px] text-base-content/50">
                JSON: <code>&#123;"heart_rate": 80, "stress_level": 30, "fatigue_level": 20, "motion_state": "resting"&#125;</code>
              </div>
            </div>

            <div class="flex gap-3 justify-end pt-2">
              <button
                type="button"
                phx-click="toggle_somatic_sim"
                class="btn btn-ghost btn-sm"
              >
                Close
              </button>
              <button type="submit" class="btn btn-primary btn-sm px-6 font-semibold">
                Pulse to Soul Engine
              </button>
            </div>
          </form>
        </div>
      </div>

      <script>
        window.addEventListener("phx:play_audio", (e) => {
          if (e.detail && e.detail.url) {
            const audio = new Audio(e.detail.url);
            audio.play().catch(err => console.log("Audio autoplay deferred:", err));
          }
        });
      </script>
    </div>
    """
  end

  defp generate_npc_response(npc, player, scene, _user_message) do
    SovereignSoulEngine.Souls.Generator.generate(npc.id, scene.id, player.id)
  end

  defp emit_immediate_reaction(npc, scene, player) do
    profile = Souls.get_soul_profile_by_character(npc.id)
    emotional_state = Souls.get_emotional_state_by_character(npc.id)
    text = pick_immediate_action_text(npc, profile, emotional_state, player)

    case Scenes.create_message(%{
           scene_id: scene.id,
           character_id: npc.id,
           content: text,
           message_type: "action"
         }) do
      {:ok, msg} ->
        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "scene:#{scene.id}",
          {:new_message, msg}
        )

      _ ->
        :ok
    end
  end

  defp pick_immediate_action_text(npc, profile, emotional_state, player) do
    stress = (emotional_state && emotional_state.stress) || 0
    fear = (emotional_state && emotional_state.fear) || 0
    anger = (emotional_state && emotional_state.anger) || 0
    attachment = (emotional_state && emotional_state.attachment) || 0
    player_name = (player && player.name) || "you"

    tells = (profile && profile.physical_tells) || %{}

    selected_tell =
      cond do
        anger > 50 and Map.has_key?(tells, "irritation") ->
          tells["irritation"]

        fear > 50 and Map.has_key?(tells, "worry") ->
          tells["worry"]

        stress > 50 and Map.has_key?(tells, "guarded") ->
          tells["guarded"]

        attachment > 50 and Map.has_key?(tells, "intimacy") ->
          tells["intimacy"]

        attachment > 40 and Map.has_key?(tells, "comforting") ->
          tells["comforting"]

        attachment > 40 and Map.has_key?(tells, "softening") ->
          tells["softening"]

        Map.has_key?(tells, "commanding") and anger > 30 ->
          tells["commanding"]

        Map.has_key?(tells, "tactical") ->
          tells["tactical"]

        map_size(tells) > 0 ->
          Enum.random(Map.values(tells))

        true ->
          nil
      end

    cond do
      selected_tell ->
        format_tell(npc.name, selected_tell)

      stress > 50 ->
        "#{npc.name}'s eyes narrow slightly, quietly measuring #{player_name}'s demeanor."

      anger > 50 ->
        "#{npc.name}'s jaw sets firmly, holding #{player_name}'s gaze with calculated stillness."

      attachment > 50 ->
        "#{npc.name} pauses, looking directly at #{player_name} with an attentive, lingering quiet."

      true ->
        "#{npc.name} pauses, taking in #{player_name}'s words as she considers a response."
    end
  end

  defp format_tell(name, tell) do
    cond do
      String.contains?(tell, name) ->
        tell

      String.starts_with?(tell, "He ") or String.starts_with?(tell, "She ") ->
        tell

      true ->
        first = String.first(tell) |> String.downcase()
        rest = String.slice(tell, 1..-1//1)
        "#{name} #{first}#{rest}"
    end
  end
end
