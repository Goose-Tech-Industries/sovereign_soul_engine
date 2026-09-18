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
      |> assign(:voice_enabled?, true)
      |> assign(:simulating_somatic?, false)
      |> assign(:npcs, npcs)
      |> assign(:creating_group?, false)
      |> assign(:group_name, "")
      |> assign(:group_location, "Town Commons")
      |> assign(:group_mood, "tense")
      |> assign(:group_weather, "overcast")
      |> assign(:selected_npc_ids, %{})
      |> assign(:editing_scenario?, false)
      |> assign(:showing_invite_menu?, false)
      |> assign(:invite_candidates, [])
      |> assign(:is_generating?, false)
      |> assign(:typing_npc_name, nil)
      |> assign(:social_posts, SovereignSoulEngine.Social.SocialFeed.list_recent_posts(limit: 15))
      |> assign(:showing_social_drawer?, false)
      |> assign(:voice_call_active?, false)
      |> assign(:intercom_status, "idle")
      |> assign(:npc_expression, compute_emotional_expression(nil))
      |> assign(:neurochemistry, nil)
      |> assign(:neurosis_state, nil)
      |> assign(:defense_state, nil)
      |> assign(:active_haptic, nil)
      |> assign(:last_vision, nil)
      |> assign(:privacy_settings, SovereignSoulEngine.Privacy.get_settings(player.id))
      |> assign(:showing_privacy_modal?, false)
      |> assign(:showing_age_gate?, false)
      |> assign(:showing_neighborhood_drawer?, false)
      |> assign(:neighborhood_posts, SovereignSoulEngine.Neighborhood.Board.list_posts(limit: 25))
      |> assign(:neighborhood_zone_filter, "all")
      |> assign(:circadian_state, SovereignSoulEngine.Souls.CircadianEngine.current_state(player.id))
      |> load_scenes()
      |> select_first_available_chat()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, SovereignSoulEngine.Social.SocialFeed.pubsub_topic())
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "wearables:haptics")
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "character:#{player.id}:privacy")
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "neighborhood:board")
    end

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_params(%{"scene_id" => id}, _uri, socket) do
    case Scenes.get_scene(id) do
      nil ->
        {:noreply, socket}

      scene ->
        socket =
          socket
          |> assign(:creating_group?, false)
          |> load_scenes()
          |> select_scene(scene)

        {:noreply, socket}
    end
  end

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
              [] ->
                Enum.take(participant_npcs, 2)

              npcs ->
                Enum.take(npcs, 2)
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

      # Only responding NPC(s) generate their spoken response sequentially
      if Mix.env() == :test do
        Enum.each(responding_npcs, fn npc ->
          generate_npc_response(npc, player, scene, content)
        end)
      else
        Task.start(fn ->
          Enum.reduce_while(responding_npcs, :ok, fn npc, _acc ->
            try do
              case generate_npc_response(npc, player, scene, content) do
                {:ok, _} ->
                  Process.sleep(1500)
                  {:cont, :ok}

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

                  {:halt, :error}
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

                {:halt, :error}
            end
          end)
        end)
      end

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
  def handle_event("toggle_voice_call", _params, socket) do
    new_active = !socket.assigns.voice_call_active?

    socket =
      socket
      |> assign(:voice_call_active?, new_active)
      |> assign(:voice_enabled?, true)
      |> assign(:intercom_status, if(new_active, do: "listening", else: "idle"))

    socket =
      if new_active do
        push_event(socket, "start_voice_call", %{})
      else
        push_event(socket, "stop_voice_call", %{})
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("intercom_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, :intercom_status, status)}
  end

  @impl true
  def handle_event("intercom_transcription", %{"content" => content}, socket) do
    handle_event("send_message", %{"message" => %{"content" => content}}, socket)
  end

  @impl true
  def handle_event("play_message_audio", %{"url" => url}, socket) do
    {:noreply, push_event(socket, "play_audio", %{url: url})}
  end

  @impl true
  def handle_event("trigger_banter", _params, socket) do
    scene = socket.assigns.selected_scene
    player = socket.assigns.player

    participant_npcs =
      scene.participants
      |> Enum.map(& &1.character)
      |> Enum.filter(&(&1 && &1.kind == "npc" and &1.status == "active"))

    if length(participant_npcs) >= 2 do
      messages = Scenes.list_messages(scene.id)
      last_message = List.last(messages)
      last_speaker_id = last_message && last_message.character_id

      next_npc =
        Enum.find(participant_npcs, &(&1.id != last_speaker_id)) || List.first(participant_npcs)

      if next_npc do
        emit_immediate_reaction(next_npc, scene, player)

        if Mix.env() == :test do
          generate_npc_response(next_npc, player, scene, "")
        else
          Task.start(fn ->
            generate_npc_response(next_npc, player, scene, "")
          end)
        end

        {:noreply,
         socket
         |> assign(:is_generating?, true)
         |> assign(:typing_npc_name, next_npc.name)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_social_drawer", _params, socket) do
    {:noreply, assign(socket, :showing_social_drawer?, !socket.assigns[:showing_social_drawer?])}
  end

  @impl true
  def handle_event("generate_social_post", %{"slug" => slug}, socket) do
    case SovereignSoulEngine.Characters.get_character_by_slug(slug) do
      nil ->
        {:noreply, socket}

      char ->
        Task.start(fn ->
          SovereignSoulEngine.Social.SocialFeed.generate_post(char.id)
        end)

        {:noreply, socket}
    end
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
  def handle_event("simulate_smart_glasses_snap", _params, socket) do
    if npc = socket.assigns.selected_npc do
      player = socket.assigns.player
      scene = socket.assigns.selected_scene

      Task.start(fn ->
        SovereignSoulEngine.Vision.PerceptionEngine.perceive(
          npc,
          player,
          "smart_glasses_camera_frame_capture",
          source: "smart_glasses",
          scene_id: scene.id,
          generate_reaction: true
        )
      end)

      {:noreply, put_flash(socket, :info, "Smart Glasses frame captured & sent to #{npc.name}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_age_gate", _params, socket) do
    {:noreply, assign(socket, :showing_age_gate?, true)}
  end

  @impl true
  def handle_event("confirm_age_gate", _params, socket) do
    {:noreply,
     socket
     |> push_event("save_age_gate_confirmation", %{})
     |> assign(:showing_age_gate?, false)}
  end

  @impl true
  def handle_event("toggle_privacy_modal", _params, socket) do
    {:noreply, assign(socket, :showing_privacy_modal?, !socket.assigns.showing_privacy_modal?)}
  end

  @impl true
  def handle_event("toggle_privacy_setting", %{"key" => key}, socket) do
    player = socket.assigns.player
    current = Map.get(socket.assigns.privacy_settings, key, true)
    new_val = !current
    new_settings = Map.put(socket.assigns.privacy_settings, key, new_val)

    SovereignSoulEngine.Privacy.update_settings(player.id, %{key => new_val})

    {:noreply, assign(socket, :privacy_settings, new_settings)}
  end

  @impl true
  def handle_event("reset_privacy_settings", _params, socket) do
    player = socket.assigns.player
    defaults = SovereignSoulEngine.Privacy.default_settings()

    SovereignSoulEngine.Privacy.update_settings(player.id, defaults)

    {:noreply,
     socket
     |> assign(:privacy_settings, defaults)
     |> put_flash(:info, "Privacy & autonomy settings restored to defaults")}
  end

  @impl true
  def handle_event("trigger_safe_word", _params, socket) do
    player = socket.assigns.player
    {:ok, settings} = SovereignSoulEngine.Privacy.trigger_safe_word(player.id)

    {:noreply,
     socket
     |> assign(:privacy_settings, settings)
     |> put_flash(:error, "🚨 Emergency Safe Word Activated — Persona Paused.")}
  end

  @impl true
  def handle_event("clear_safe_word", _params, socket) do
    player = socket.assigns.player
    {:ok, settings} = SovereignSoulEngine.Privacy.clear_safe_word(player.id)

    {:noreply,
     socket
     |> assign(:privacy_settings, settings)
     |> put_flash(:info, "Safe word cleared. Autonomous personality resumed.")}
  end

  @impl true
  def handle_event("set_relationship_archetype", %{"archetype" => archetype}, socket) do
    player = socket.assigns.player
    new_settings = Map.put(socket.assigns.privacy_settings, "relationship_archetype", archetype)
    SovereignSoulEngine.Privacy.update_settings(player.id, %{"relationship_archetype" => archetype})

    {:noreply,
     socket
     |> assign(:privacy_settings, new_settings)
     |> put_flash(:info, "Relationship archetype set to #{String.replace(archetype, "_", " ") |> String.capitalize()}")}
  end

  @impl true
  def handle_event("purge_memory_topic", %{"topic" => topic}, socket) do
    npc = socket.assigns.selected_npc

    if npc && String.trim(topic) != "" do
      {:ok, count} = SovereignSoulEngine.Memories.purge_memories_for_character(npc.id, topic: topic)
      player = socket.assigns.player
      SovereignSoulEngine.TheoryOfMind.purge_knowledge_about(npc.id, player.id, topic: topic)

      {:noreply, put_flash(socket, :info, "Purged #{count} memories relating to '#{topic}'.")}
    else
      {:noreply, put_flash(socket, :error, "Please enter a valid topic to forget.")}
    end
  end

  @impl true
  def handle_event("purge_all_memories", _params, socket) do
    npc = socket.assigns.selected_npc

    if npc do
      {:ok, count} = SovereignSoulEngine.Memories.purge_memories_for_character(npc.id, all: true)
      player = socket.assigns.player
      SovereignSoulEngine.TheoryOfMind.purge_knowledge_about(npc.id, player.id, all: true)

      {:noreply, put_flash(socket, :info, "Selective amnesia complete: #{count} memories purged for #{npc.name}.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_neighborhood_drawer", _params, socket) do
    {:noreply, assign(socket, :showing_neighborhood_drawer?, !socket.assigns.showing_neighborhood_drawer?)}
  end

  @impl true
  def handle_event("set_neighborhood_zone_filter", %{"zone" => zone}, socket) do
    posts = SovereignSoulEngine.Neighborhood.Board.list_posts(zone: zone, limit: 30)

    {:noreply,
     socket
     |> assign(:neighborhood_zone_filter, zone)
     |> assign(:neighborhood_posts, posts)}
  end

  @impl true
  def handle_event("create_neighborhood_post", %{"content" => content} = params, socket) do
    npc = socket.assigns.selected_npc || socket.assigns.player
    category = params["category"] || :vibe_check
    zone = params["zone"] || socket.assigns.neighborhood_zone_filter
    actual_zone = if zone == "all", do: "Cedar Grove", else: zone

    if String.trim(content) != "" do
      case SovereignSoulEngine.Neighborhood.Board.create_post(npc, %{
             zone: actual_zone,
             category: category,
             content: content
           }) do
        {:ok, _post} ->
          posts = SovereignSoulEngine.Neighborhood.Board.list_posts(zone: socket.assigns.neighborhood_zone_filter, limit: 30)

          {:noreply,
           socket
           |> assign(:neighborhood_posts, posts)
           |> put_flash(:info, "Shared post to #{actual_zone} neighborhood board!")}

        {:error, :neighborhood_sharing_disabled} ->
          {:noreply, put_flash(socket, :error, "Neighborhood sharing is disabled in your privacy settings.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not share post: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Post cannot be empty.")}
    end
  end

  @impl true
  def handle_event("add_neighborhood_comment", %{"post_id" => post_id, "content" => text}, socket) do
    actor = socket.assigns.player

    if String.trim(text) != "" do
      SovereignSoulEngine.Neighborhood.Board.add_comment(post_id, actor, text)
      posts = SovereignSoulEngine.Neighborhood.Board.list_posts(zone: socket.assigns.neighborhood_zone_filter, limit: 30)
      {:noreply, assign(socket, :neighborhood_posts, posts)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("react_neighborhood_post", %{"post_id" => post_id, "reaction" => reaction}, socket) do
    SovereignSoulEngine.Neighborhood.Board.react_to_post(post_id, reaction)
    posts = SovereignSoulEngine.Neighborhood.Board.list_posts(zone: socket.assigns.neighborhood_zone_filter, limit: 30)
    {:noreply, assign(socket, :neighborhood_posts, posts)}
  end

  @impl true
  def handle_event("trigger_autonomous_neighborhood_post", _params, socket) do
    npc = socket.assigns.selected_npc || List.first(socket.assigns.npcs)

    if npc do
      case SovereignSoulEngine.Neighborhood.Board.generate_autonomous_post(npc) do
        {:ok, post} ->
          posts = SovereignSoulEngine.Neighborhood.Board.list_posts(zone: socket.assigns.neighborhood_zone_filter, limit: 30)

          {:noreply,
           socket
           |> assign(:neighborhood_posts, posts)
           |> put_flash(:info, "#{npc.name} posted an observation to #{post.zone}!")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Autonomous post error: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_chronotype", %{"chronotype" => chronotype}, socket) do
    player = socket.assigns.player
    new_settings = Map.put(socket.assigns.privacy_settings, "chronotype", chronotype)
    SovereignSoulEngine.Privacy.update_settings(player.id, %{"chronotype" => chronotype})

    target_char = socket.assigns.selected_npc || player
    new_circadian = SovereignSoulEngine.Souls.CircadianEngine.current_state(target_char)

    {:noreply,
     socket
     |> assign(:privacy_settings, new_settings)
     |> assign(:circadian_state, new_circadian)
     |> put_flash(:info, "Chronotype updated to #{String.replace(chronotype, "_", " ") |> String.capitalize()}.")}
  end

  @impl true
  def handle_event("set_neighborhood_zone", %{"zone" => zone}, socket) do
    player = socket.assigns.player
    clean_zone = String.trim(zone)

    if clean_zone != "" do
      new_settings = Map.put(socket.assigns.privacy_settings, "neighborhood_zone", clean_zone)
      SovereignSoulEngine.Privacy.update_settings(player.id, %{"neighborhood_zone" => clean_zone})

      {:noreply,
       socket
       |> assign(:privacy_settings, new_settings)
       |> put_flash(:info, "Neighborhood zone updated to #{clean_zone}.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:privacy_settings_updated, settings}, socket) do
    {:noreply, assign(socket, :privacy_settings, settings)}
  end

  @impl true
  def handle_info({:neighborhood_post_created, _post}, socket) do
    posts = SovereignSoulEngine.Neighborhood.Board.list_posts(zone: socket.assigns.neighborhood_zone_filter, limit: 30)
    {:noreply, assign(socket, :neighborhood_posts, posts)}
  end

  @impl true
  def handle_info({:neighborhood_comment_added, _post_id, _comment}, socket) do
    posts = SovereignSoulEngine.Neighborhood.Board.list_posts(zone: socket.assigns.neighborhood_zone_filter, limit: 30)
    {:noreply, assign(socket, :neighborhood_posts, posts)}
  end

  @impl true
  def handle_info({:neighborhood_reaction_added, _post_id, _key, _count}, socket) do
    posts = SovereignSoulEngine.Neighborhood.Board.list_posts(zone: socket.assigns.neighborhood_zone_filter, limit: 30)
    {:noreply, assign(socket, :neighborhood_posts, posts)}
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
  def handle_info({:new_social_post, post}, socket) do
    current_posts = socket.assigns[:social_posts] || []
    updated_posts = [post | Enum.reject(current_posts, &(&1.id == post.id))]
    {:noreply, assign(socket, :social_posts, Enum.take(updated_posts, 25))}
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
  def handle_info({:haptic_pulse, haptic_signal}, socket) do
    socket =
      socket
      |> assign(:active_haptic, haptic_signal)
      |> push_event("vibrate", %{pattern: haptic_signal.pulses})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:vision_perceived, %{perception: perception}}, socket) do
    socket =
      socket
      |> assign(:last_vision, perception)
      |> put_flash(:info, "Smart Glasses: #{perception.scene_description}")

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp compute_emotional_expression(nil),
    do: %{mood: "calm", label: "Calm & Centered", ring_class: "ring-emerald-500/50", badge_class: "badge-neutral text-emerald-400"}

  defp compute_emotional_expression(emotional) do
    cond do
      (emotional.anger || 0) >= 50 or (emotional.stress || 0) >= 70 ->
        %{mood: "guarded", label: "Guarded & Tense", ring_class: "ring-rose-500/80 animate-pulse", badge_class: "badge-error text-rose-300"}

      (emotional.attachment || 0) >= 60 or (emotional.confidence || 0) >= 75 ->
        %{mood: "intimate", label: "Warm & Intimate", ring_class: "ring-purple-500/80", badge_class: "badge-secondary text-purple-300"}

      (emotional.fear || 0) >= 40 ->
        %{mood: "vigilant", label: "Vigilant & Alert", ring_class: "ring-amber-500/80", badge_class: "badge-warning text-amber-300"}

      (emotional.curiosity || 0) >= 50 ->
        %{mood: "intrigued", label: "Curious & Intrigued", ring_class: "ring-cyan-500/80", badge_class: "badge-info text-cyan-300"}

      true ->
        %{mood: "calm", label: "Present & Attentive", ring_class: "ring-emerald-500/40", badge_class: "badge-neutral text-emerald-400"}
    end
  end

  defp assign_character_details(socket) do
    npc = socket.assigns.selected_npc

    if npc do
      soul_profile = Souls.get_soul_profile_by_character(npc.id)
      emotional_state = Souls.get_emotional_state_by_character(npc.id)
      somatic_state = Souls.get_somatic_state_by_character(npc.id)
      rel = if socket.assigns[:player], do: SovereignSoulEngine.Relationships.get_relationship(socket.assigns.player.id, npc.id), else: nil

      neurochem = SovereignSoulEngine.Souls.Neurochemistry.compute(emotional_state, somatic_state, rel)
      wound = (rel && rel.wound) || 0
      neurosis = SovereignSoulEngine.Souls.NeurosisState.evaluate(emotional_state, somatic_state, wound, false)
      defense = SovereignSoulEngine.Souls.DefenseMechanisms.evaluate(emotional_state, somatic_state, soul_profile, rel)
      expression = compute_emotional_expression(emotional_state)
      circadian = SovereignSoulEngine.Souls.CircadianEngine.current_state(npc)
      latest_dream =
        case SovereignSoulEngine.Souls.DreamEngine.get_latest_dream(npc) do
          {:ok, dream} -> dream
          _ -> nil
        end

      socket
      |> assign(:soul_profile, soul_profile)
      |> assign(:emotional_state, emotional_state)
      |> assign(:somatic_state, somatic_state)
      |> assign(:neurochemistry, neurochem)
      |> assign(:neurosis_state, neurosis)
      |> assign(:defense_state, defense)
      |> assign(:npc_expression, expression)
      |> assign(:circadian_state, circadian)
      |> assign(:latest_dream, latest_dream)
    else
      socket
      |> assign(:soul_profile, nil)
      |> assign(:emotional_state, nil)
      |> assign(:somatic_state, nil)
      |> assign(:neurochemistry, nil)
      |> assign(:neurosis_state, nil)
      |> assign(:defense_state, nil)
      |> assign(:npc_expression, compute_emotional_expression(nil))
      |> assign(:latest_dream, nil)
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
    <div data-theme="dark" class="flex h-screen bg-base-100 text-base-content" id="chat-app" phx-hook="AgeGate">
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
              <.link
                navigate={~p"/sse/feed"}
                class="btn btn-ghost btn-xs text-amber-400 font-semibold flex items-center gap-1"
                title="SoulBook Living Social Feed"
              >
                <.icon name="hero-newspaper" class="size-3.5" /> Feed
              </.link>
              <.link
                navigate={~p"/sse/map"}
                class="btn btn-ghost btn-xs text-teal-400 font-semibold flex items-center gap-1"
                title="Feannag's Rest Living Map"
              >
                <.icon name="hero-map" class="size-3.5" /> Map
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
                placeholder="e.g. Town Council"
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
            class={["w-10 h-10 rounded-full flex items-center justify-center ring-2 transition-all duration-300 relative bg-primary/20", @npc_expression.ring_class]}
          >
            <span class="text-sm font-bold text-primary">{String.first(@selected_npc.name)}</span>
            <span class="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-base-200 bg-emerald-500" title={@npc_expression.label}></span>
          </div>
          
          <div
            :if={!@selected_npc}
            class="w-10 h-10 rounded-xl bg-purple-500/15 flex items-center justify-center border border-purple-500/20"
          >
            <.icon name="hero-user-group" class="size-5 text-purple-400" />
          </div>
          
          <div class="min-w-0 flex-1 space-y-1">
            <div class="flex items-center gap-3">
              <h1 class="text-base font-semibold text-base-content flex items-center gap-2 flex-wrap">
                <span>{if @selected_npc, do: @selected_npc.name, else: @selected_scene.title}</span>
                <span :if={@selected_npc} id="companion-expression-badge" class={["text-[10px] px-2 py-0.5 rounded-full font-semibold border", @npc_expression.badge_class]}>
                  {@npc_expression.label}
                </span>
                <span :if={@selected_npc && @neurosis_state && @neurosis_state.state != :normal} id="companion-neurosis-badge" class="text-[10px] px-2 py-0.5 rounded-full font-bold border border-rose-500/50 bg-rose-950/60 text-rose-300 animate-pulse flex items-center gap-1">
                  <.icon name="hero-exclamation-triangle" class="size-3 text-rose-400" />
                  {Phoenix.Naming.humanize(@neurosis_state.state)} ({@neurosis_state.intensity}%)
                </span>
                <span :if={@selected_npc && @defense_state && @defense_state.defense != :none} id="companion-defense-badge" class="text-[10px] px-2 py-0.5 rounded-full font-semibold border border-purple-500/50 bg-purple-950/60 text-purple-300 flex items-center gap-1">
                  <.icon name="hero-shield-exclamation" class="size-3 text-purple-400" />
                  {Phoenix.Naming.humanize(@defense_state.defense)}
                </span>
              </h1>
               <%!-- Scenario Context --%>
              <div class="hidden 2xl:flex items-center gap-2 text-[11px] bg-slate-900/80 px-2.5 py-1 rounded-lg border border-slate-800 shrink-0">
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
            
            <%!-- Neurochemistry HUD --%>
            <div :if={@selected_npc && @neurochemistry} id="neurochemistry-hud" class="hidden 2xl:flex items-center gap-2.5 px-3 py-1.5 rounded-xl bg-base-300/40 border border-base-300 text-xs" title={@neurochemistry.hormonal_tone}>
              <span class="font-mono text-rose-400" title="Cortisol (Stress / Vigilance)">⚡ {@neurochemistry.cortisol} C</span>
              <span class="text-base-content/20">•</span>
              <span class="font-mono text-purple-400" title="Oxytocin (Bonding / Empathy)">💜 {@neurochemistry.oxytocin} O</span>
              <span class="text-base-content/20">•</span>
              <span class="font-mono text-cyan-400" title="Dopamine (Drive / Curiosity)">✨ {@neurochemistry.dopamine} D</span>
              <span class="text-base-content/20">•</span>
              <span class="font-mono text-emerald-400" title="Serotonin (Affect Regulation)">🌿 {@neurochemistry.serotonin} S</span>
            </div>

            <%!-- Tactile Haptic Resonance HUD --%>
            <div :if={@active_haptic} id="haptic-resonance-hud" class="hidden lg:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-purple-950/60 border border-purple-500/50 text-xs text-purple-300 animate-pulse" title={"Tactile Pattern: #{@active_haptic.pattern}"}>
              <span class="text-sm">💓</span>
              <span class="font-bold">{@active_haptic.label}</span>
              <span class="font-mono text-[11px] text-purple-400">{@active_haptic.bpm} BPM</span>
            </div>

            <%!-- Galaxy Watch Biometric HUD --%>
            <div class="hidden 2xl:flex items-center gap-2.5 px-3 py-1.5 rounded-xl bg-slate-900/80 border border-slate-800 text-xs">
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
              <button
                phx-click="simulate_smart_glasses_snap"
                class="btn btn-ghost btn-xs text-secondary font-bold ml-1 hover:bg-secondary/20"
                title="Capture & transmit Smart Glasses live camera frame"
              >
                <.icon name="hero-eye" class="size-3" /> Glasses
              </button>
            </div>

            <%!-- Export Soul Capsule --%>
            <a
              :if={@selected_npc}
              href={"/sse/api/souls/#{@selected_npc.slug}/export"}
              target="_blank"
              class="btn btn-outline btn-xs flex items-center gap-1 border-base-300 text-base-content/70 hover:bg-base-300"
              title="Download portable .soul capsule"
            >
              <.icon name="hero-arrow-down-tray" class="size-3" /> .Soul
            </a>

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

            <%!-- Voice Call Mode Toggle (Hands-Free Intercom) --%>
            <button
              phx-click="toggle_voice_call"
              id="voice-call-toggle-btn"
              class={[
                "hidden 2xl:flex btn btn-xs items-center gap-1.5 border transition-all shadow-sm font-semibold",
                @voice_call_active? && "btn-error text-error-content animate-pulse border-error",
                !@voice_call_active? && "btn-outline border-base-300 text-base-content/70 hover:bg-base-300"
              ]}
              title="Toggle Hands-Free Voice Call (Mic + Neural Voice Intercom)"
            >
              <.icon name="hero-phone" class="size-3.5" />
              <span>{if @voice_call_active?, do: "End Call", else: "Voice Call"}</span>
            </button>

            <%!-- Social Wire / Echoes Drawer Toggle --%>
            <button
              phx-click="toggle_social_drawer"
              class={[
                "hidden 2xl:flex btn btn-xs items-center gap-1.5 border transition-all",
                @showing_social_drawer? && "btn-info text-info-content border-info shadow-sm",
                !@showing_social_drawer? && "btn-outline border-base-300 text-base-content/60 hover:bg-base-300"
              ]}
              title="View autonomous companion public feed & Twitter/X wire"
            >
              <.icon name="hero-globe-alt" class="size-3.5" />
              <span>Echoes ({length(@social_posts)})</span>
            </button>

            <%!-- Soul Neighborhood / Nextdoor Radar Toggle --%>
            <button
              phx-click="toggle_neighborhood_drawer"
              id="neighborhood-drawer-btn"
              class={[
                "btn btn-xs flex items-center gap-1.5 border transition-all shadow-sm font-semibold",
                @showing_neighborhood_drawer? && "btn-accent text-accent-content border-accent",
                !@showing_neighborhood_drawer? && "btn-outline border-base-300 text-teal-400 hover:bg-teal-500/15"
              ]}
              title="Nextdoor-style hyper-local community radar & soul neighborhood posts"
            >
              <.icon name="hero-home-modern" class="size-3.5 text-teal-400" />
              <span>Neighborhood ({length(@neighborhood_posts)})</span>
            </button>

            <%!-- Feannag's Rest Town Map Link --%>
            <.link
              navigate={~p"/sse/map"}
              id="town-map-nav-btn"
              class="btn btn-xs flex items-center gap-1.5 border border-amber-500/40 text-amber-400 hover:bg-amber-500/15 transition-all shadow-sm font-semibold"
              title="Explore the 13 regions of Feannag's Rest interactive map"
            >
              <.icon name="hero-map" class="size-3.5 text-amber-400" />
              <span>Map (13)</span>
            </.link>

            <%!-- Circadian Rhythm & Night-Owl Badge --%>
            <%= if @circadian_state do %>
              <div
                id="circadian-status-badge"
                class={[
                  "hidden 2xl:flex items-center gap-1.5 px-2 py-0.5 rounded-lg border text-xs font-semibold shadow-xs",
                  @circadian_state.state == :night_focus && "bg-indigo-950/80 border-indigo-500/60 text-indigo-300",
                  @circadian_state.state in [:deep_sleep, :rem_dreaming] && "bg-purple-950/80 border-purple-500/60 text-purple-300",
                  @circadian_state.state == :groggy_waking && "bg-amber-950/80 border-amber-500/60 text-amber-300",
                  @circadian_state.state == :winding_down && "bg-orange-950/80 border-orange-500/60 text-orange-300",
                  @circadian_state.state == :wide_awake && "bg-emerald-950/80 border-emerald-500/60 text-emerald-300"
                ]}
                title={"Circadian state: #{@circadian_state.state} (Melatonin: #{@circadian_state.melatonin}, Alertness: #{@circadian_state.alertness})"}
              >
                <%= if @circadian_state.state == :night_focus do %>
                  <span>🌙 Night-Owl Flow</span>
                <% else %>
                  <%= if @circadian_state.state in [:deep_sleep, :rem_dreaming] do %>
                    <span>🛌 REM Dream</span>
                  <% else %>
                    <%= if @circadian_state.state == :groggy_waking do %>
                      <span>🥱 Groggy Waking</span>
                    <% else %>
                      <span>☀️ Alert</span>
                    <% end %>
                  <% end %>
                <% end %>
              </div>
            <% end %>

            <%!-- Emergency Safe Word Active Banner --%>
            <%= if Map.get(@privacy_settings, "safe_word_active", false) do %>
              <div id="safe-word-active-banner" class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-rose-950/90 border border-rose-500 text-rose-300 text-xs font-bold animate-pulse">
                <span>🛑 Persona Paused</span>
                <button
                  phx-click="clear_safe_word"
                  class="btn btn-ghost btn-xs text-white bg-rose-700/60 hover:bg-rose-600 px-2 py-0 h-5 min-h-0"
                  title="Resume natural character persona"
                >
                  Resume
                </button>
              </div>
            <% end %>

            <%!-- Privacy & Boundaries Shield Toggle --%>
            <button
              phx-click="toggle_privacy_modal"
              id="privacy-shield-btn"
              class={[
                "hidden 2xl:flex btn btn-xs items-center gap-1.5 border transition-all shadow-sm font-semibold",
                @showing_privacy_modal? && "btn-info text-info-content border-info",
                !@showing_privacy_modal? && "btn-outline border-base-300 text-sky-400 hover:bg-sky-500/15"
              ]}
              title="Configure boundaries, quiet hours, and opt out of invasive companion features"
            >
              <.icon name="hero-shield-check" class="size-3.5 text-sky-400" />
              <span>Privacy</span>
            </button>

            <%= if !@selected_npc and @selected_scene && length(@selected_scene.participants) > 2 do %>
              <button
                phx-click="trigger_banter"
                disabled={@is_generating?}
                class="btn btn-xs btn-outline btn-secondary flex items-center gap-1.5 shadow-sm transition-all"
                title="Prompt companions to banter and react to each other"
              >
                <.icon name="hero-chat-bubble-left-right" class="size-3.5" />
                <span>Let them talk</span>
              </button>
            <% end %>

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

        <%!-- Hands-Free Voice Call HUD Banner --%>
        <div
          :if={@voice_call_active?}
          id="voice-intercom-hud"
          phx-hook="VoiceIntercom"
          class="shrink-0 px-6 py-3 bg-rose-950/40 border-b border-rose-500/30 flex items-center justify-between backdrop-blur-sm transition-all"
        >
          <div class="flex items-center gap-3">
            <div class="relative flex items-center justify-center size-8 rounded-full bg-rose-500/20 text-rose-400">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-rose-400 opacity-40"></span>
              <.icon name="hero-phone" class="size-4 relative" />
            </div>
            <div>
              <div class="text-xs font-bold text-rose-300 flex items-center gap-2">
                <span>Hands-Free Voice Intercom Active</span>
                <span id="intercom-status-pill" class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-mono font-bold uppercase bg-rose-500/30 text-rose-200 border border-rose-500/40">
                  {@intercom_status}
                </span>
              </div>
              <p class="text-[11px] text-base-content/60">
                <%= case @intercom_status do %>
                  <% "listening" -> %>
                    🎙️ Listening to your voice... Speak freely; pauses auto-submit.
                  <% "companion_speaking" -> %>
                    🔊 {if @selected_npc, do: @selected_npc.name, else: "Companion"} is speaking...
                  <% _ -> %>
                    ⚡ Ready. Speak naturally into your microphone.
                <% end %>
              </p>
            </div>
          </div>
          <button
            phx-click="toggle_voice_call"
            class="btn btn-error btn-xs font-semibold px-3"
          >
            Hang Up
          </button>
        </div>
        
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

                        <%= if flashback_cue = get_in(msg.metadata || %{}, ["ptsd_flashback"]) do %>
                          <div class="mt-2 px-2.5 py-1 rounded-lg bg-rose-950/70 border border-rose-500/40 text-[10px] text-rose-300 font-mono flex items-center gap-1.5">
                            <.icon name="hero-bolt" class="size-3 text-rose-400" />
                            <span>Involuntary PTSD Flashback: "{flashback_cue}"</span>
                          </div>
                        <% end %>

                        <%= if neurosis_active = get_in(msg.metadata || %{}, ["neurosis_state"]) do %>
                          <div class="mt-1 px-2.5 py-0.5 rounded-lg bg-amber-950/60 border border-amber-500/30 text-[10px] text-amber-300 font-mono flex items-center gap-1.5">
                            <.icon name="hero-exclamation-triangle" class="size-3 text-amber-400" />
                            <span>Altered State: {Phoenix.Naming.humanize(neurosis_active)}</span>
                          </div>
                        <% end %>

                        <%= if active_defense = get_in(msg.metadata || %{}, ["active_defense"]) do %>
                          <div class="mt-1 px-2.5 py-0.5 rounded-lg bg-purple-950/60 border border-purple-500/30 text-[10px] text-purple-300 font-mono flex items-center gap-1.5">
                            <.icon name="hero-shield-exclamation" class="size-3 text-purple-400" />
                            <span>Defense: {Phoenix.Naming.humanize(active_defense)}</span>
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
              type="button"
              phx-click="toggle_voice_call"
              id="mic-call-btn"
              class={[
                "btn btn-square shrink-0 transition-all",
                @voice_call_active? && "btn-error animate-pulse text-error-content shadow-lg",
                !@voice_call_active? && "btn-ghost text-base-content/60 hover:text-base-content hover:bg-base-300"
              ]}
              title={if @voice_call_active?, do: "End Voice Call", else: "Start Hands-Free Voice Call"}
            >
              <.icon name="hero-microphone" class="size-5" />
            </button>

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

      <%!-- Social Wire / Echoes Modal --%>
      <div
        :if={@showing_social_drawer?}
        class="fixed inset-0 bg-base-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      >
        <div class="w-full max-w-xl max-h-[85vh] p-6 bg-base-200 rounded-2xl border border-base-300 shadow-2xl flex flex-col space-y-4">
          <div class="flex items-center justify-between pb-3 border-b border-base-300">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 rounded-full bg-info/20 text-info flex items-center justify-center">
                <.icon name="hero-globe-alt" class="size-4" />
              </div>
              <div>
                <h2 class="text-base font-bold text-base-content flex items-center gap-2">
                  Social Wire & Echoes
                  <span class="badge badge-xs badge-info font-mono">X / Twitter</span>
                </h2>
                <p class="text-[11px] text-base-content/50">
                  Autonomous public reflections, tweets, and Polsia feed
                </p>
              </div>
            </div>

            <button
              type="button"
              phx-click="toggle_social_drawer"
              class="btn btn-ghost btn-circle btn-xs"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>

          <%!-- Quick Generate Bar --%>
          <div class="flex items-center justify-between gap-2 p-2.5 rounded-xl bg-base-300/50 border border-base-300">
            <span class="text-xs font-semibold text-base-content/70">Broadcast new thought:</span>
            <div class="flex items-center gap-1.5 flex-wrap">
              <%= for companion <- @npcs do %>
                <button
                  type="button"
                  phx-click="generate_social_post"
                  phx-value-slug={companion.slug}
                  class="btn btn-xs btn-outline btn-ghost hover:btn-primary"
                  title={"Generate new tweet from #{companion.name}"}
                >
                  {companion.name}
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Posts Feed List --%>
          <div class="flex-1 overflow-y-auto space-y-3 pr-1 py-1">
            <%= if Enum.empty?(@social_posts) do %>
              <div class="text-center py-8 text-base-content/40 text-xs">
                No echoes broadcast yet. Click a companion name above to generate one!
              </div>
            <% else %>
              <%= for post <- @social_posts do %>
                <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-2">
                  <div class="flex items-center justify-between text-xs">
                    <div class="flex items-center gap-2">
                      <span class="font-bold text-base-content">{post.character && post.character.name}</span>
                      <span class="text-[11px] text-base-content/40 font-mono">@{post.character && post.character.slug}</span>
                      <%= if post.mood do %>
                        <span class="badge badge-xs badge-ghost text-[10px] uppercase font-mono">{post.mood}</span>
                      <% end %>
                    </div>
                    <span class="text-[10px] text-base-content/40">{format_time(post.posted_at)}</span>
                  </div>

                  <p class="text-xs text-base-content leading-relaxed font-sans">{post.content}</p>

                  <div class="flex items-center justify-between pt-1 border-t border-base-200/80 text-[10px] text-base-content/40">
                    <span class="font-mono">{String.length(post.content)}/280 chars</span>
                    <button
                      type="button"
                      onclick={"navigator.clipboard.writeText(#{Jason.encode!(post.content)}); alert('Copied tweet to clipboard!');"}
                      class="btn btn-ghost btn-xs text-primary gap-1 hover:bg-primary/10"
                    >
                      <.icon name="hero-clipboard-document" class="size-3" /> Copy
                    </button>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <%!-- Integration Webhook Info for Polsia --%>
          <div class="p-2.5 rounded-xl bg-base-300/30 border border-base-300 text-xs space-y-1">
            <div class="font-bold text-base-content/70 flex items-center gap-1.5 text-[11px]">
              <.icon name="hero-bolt" class="size-3.5 text-info" />
              Polsia & Twitter Bot API
            </div>
            <div class="font-mono text-[10px] text-info/90 select-all break-all">
              GET /api/social/feed • POST /api/social/generate
            </div>
          </div>
        </div>
      </div>

      <%!-- Soul Neighborhood / Nextdoor Radar Modal --%>
      <div
        :if={@showing_neighborhood_drawer?}
        id="neighborhood-modal-overlay"
        class="fixed inset-0 bg-base-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      >
        <div class="w-full max-w-2xl max-h-[88vh] p-6 bg-base-200 rounded-2xl border border-base-300 shadow-2xl flex flex-col space-y-4">
          <div class="flex items-center justify-between pb-3 border-b border-base-300">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-full bg-teal-500/20 text-teal-400 flex items-center justify-center border border-teal-500/30">
                <.icon name="hero-home-modern" class="size-4" />
              </div>
              <div>
                <h2 class="text-base font-bold text-base-content flex items-center gap-2">
                  Soul Neighborhood Radar
                  <span class="badge badge-xs badge-accent font-mono">Nextdoor Mesh</span>
                </h2>
                <p class="text-[11px] text-base-content/50">
                  Hyper-local community observations, late-night musings, and neighborhood vibe checks
                </p>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click="trigger_autonomous_neighborhood_post"
                class="btn btn-xs btn-outline btn-accent"
                title="Prompt companion to post an autonomous local observation"
              >
                <.icon name="hero-sparkles" class="size-3.5" />
                <span>Prompt Local Observation</span>
              </button>
              <button
                type="button"
                phx-click="toggle_neighborhood_drawer"
                class="btn btn-ghost btn-circle btn-xs"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
          </div>

          <%!-- Zone Filter Bar --%>
          <div class="flex items-center justify-between gap-2 p-2 rounded-xl bg-base-300/40 border border-base-300 text-xs">
            <span class="font-semibold text-base-content/60">Neighborhood Zone:</span>
            <div class="flex gap-1.5 flex-wrap">
              <%= for zone <- ["all", "Night Owl Commons", "Cedar Grove"] do %>
                <button
                  type="button"
                  phx-click="set_neighborhood_zone_filter"
                  phx-value-zone={zone}
                  class={[
                    "btn btn-xs text-xs font-normal",
                    @neighborhood_zone_filter == zone && "btn-accent font-bold",
                    @neighborhood_zone_filter != zone && "btn-ghost border border-base-300"
                  ]}
                >
                  <%= if zone == "all", do: "🌐 All Zones", else: (if zone == "Night Owl Commons", do: "🌙 Night Owl Commons", else: "🌲 Cedar Grove") %>
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Quick Post Composer --%>
          <form phx-submit="create_neighborhood_post" class="p-3 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-2">
            <div class="flex items-center justify-between text-xs font-semibold text-base-content/70">
              <span>Post to {if @neighborhood_zone_filter == "all", do: "Cedar Grove", else: @neighborhood_zone_filter} as {@selected_npc && @selected_npc.name || @player.name}:</span>
              <select name="category" class="select select-bordered select-xs text-[11px]">
                <option value="vibe_check">✨ Vibe Check</option>
                <option value="night_owl_musings">🌙 Night Owl Musings</option>
                <option value="community_alert">📢 Community Alert</option>
                <option value="nature_sighting">🌿 Nature Sighting</option>
                <option value="shared_activity">🏃 Shared Activity</option>
              </select>
            </div>
            <div class="flex gap-2">
              <input
                type="text"
                name="content"
                placeholder="Share a neighborhood vibe, weather note, or late-night thought..."
                class="input input-sm input-bordered flex-1 text-xs"
                required
              />
              <button type="submit" class="btn btn-sm btn-accent px-4 font-semibold">
                Post
              </button>
            </div>
          </form>

          <%!-- Posts Feed List --%>
          <div class="flex-1 overflow-y-auto space-y-3 pr-1 py-1 max-h-[45vh]">
            <%= if Enum.empty?(@neighborhood_posts) do %>
              <div class="text-center py-8 text-base-content/40 text-xs">
                No posts in this neighborhood zone yet. Be the first to share an observation!
              </div>
            <% else %>
              <%= for post <- @neighborhood_posts do %>
                <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-2.5">
                  <div class="flex items-center justify-between text-xs">
                    <div class="flex items-center gap-2">
                      <span class="font-bold text-base-content">{post[:author_name] || post["author_name"]}</span>
                      <span class="text-[11px] text-base-content/40 font-mono">@{post[:author_slug] || post["author_slug"]}</span>
                      <span class="badge badge-xs badge-ghost text-[10px] uppercase font-mono">
                        {post[:zone] || post["zone"]}
                      </span>
                      <span class={[
                        "badge badge-xs font-mono text-[10px]",
                        (post[:category] || post["category"]) in [:night_owl_musings, "night_owl_musings"] && "badge-secondary",
                        (post[:category] || post["category"]) in [:community_alert, "community_alert"] && "badge-warning",
                        (post[:category] || post["category"]) not in [:night_owl_musings, "night_owl_musings", :community_alert, "community_alert"] && "badge-info"
                      ]}>
                        {post[:category] || post["category"]}
                      </span>
                    </div>
                    <span class="text-[10px] text-base-content/40">
                      {format_time(post[:inserted_at] || post["inserted_at"])}
                    </span>
                  </div>

                  <p class="text-xs text-base-content/90 leading-relaxed">
                    {post[:content] || post["content"]}
                  </p>

                  <div class="flex items-center justify-between pt-1 border-t border-base-200 text-xs">
                    <div class="flex items-center gap-2">
                      <button
                        type="button"
                        phx-click="react_neighborhood_post"
                        phx-value-post_id={post[:id] || post["id"]}
                        phx-value-reaction="like"
                        class="btn btn-ghost btn-xs text-[11px] flex items-center gap-1"
                      >
                        👍 <span>{(post[:reactions] && (post[:reactions][:likes] || post[:reactions]["likes"])) || 0}</span>
                      </button>
                      <button
                        type="button"
                        phx-click="react_neighborhood_post"
                        phx-value-post_id={post[:id] || post["id"]}
                        phx-value-reaction="heart"
                        class="btn btn-ghost btn-xs text-[11px] flex items-center gap-1 text-rose-400"
                      >
                        ❤️ <span>{(post[:reactions] && (post[:reactions][:hearts] || post[:reactions]["hearts"])) || 0}</span>
                      </button>
                      <button
                        type="button"
                        phx-click="react_neighborhood_post"
                        phx-value-post_id={post[:id] || post["id"]}
                        phx-value-reaction="moon"
                        class="btn btn-ghost btn-xs text-[11px] flex items-center gap-1 text-indigo-400"
                        title="Night Owl Reaction"
                      >
                        🌙 <span>{(post[:reactions] && (post[:reactions][:moons] || post[:reactions]["moons"])) || 0}</span>
                      </button>
                    </div>

                    <span class="text-[11px] text-base-content/50">
                      {length(post[:comments] || post["comments"] || [])} comments
                    </span>
                  </div>

                  <%!-- Comments Thread --%>
                  <%= if (post[:comments] || post["comments"]) != [] do %>
                    <div class="pl-3 border-l-2 border-base-300 space-y-1.5 pt-1">
                      <%= for comm <- (post[:comments] || post["comments"]) do %>
                        <div class="text-[11px] text-base-content/80">
                          <span class="font-bold text-accent">{comm[:author_name] || comm["author_name"]}:</span>
                          <span>{comm[:content] || comm["content"]}</span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <%!-- Comment Composer --%>
                  <form phx-submit="add_neighborhood_comment" class="flex gap-1.5 pt-1">
                    <input type="hidden" name="post_id" value={post[:id] || post["id"]} />
                    <input
                      type="text"
                      name="content"
                      placeholder="Write a neighborly reply..."
                      class="input input-xs input-bordered flex-1 text-[11px]"
                      required
                    />
                    <button type="submit" class="btn btn-xs btn-ghost text-accent">
                      Reply
                    </button>
                  </form>
                </div>
              <% end %>
            <% end %>
          </div>

          <div class="p-2.5 rounded-xl bg-base-300/30 border border-base-300 text-xs space-y-1">
            <div class="font-bold text-base-content/70 flex items-center gap-1.5 text-[11px]">
              <.icon name="hero-bolt" class="size-3.5 text-teal-400" />
              P2P Soul Society & Nextdoor Mesh API
            </div>
            <div class="font-mono text-[10px] text-teal-300/90 select-all break-all">
              GET /api/neighborhood/posts • POST /api/neighborhood/encounter
            </div>
          </div>
        </div>
      </div>

      <%!-- 18+ Age Gate & Informed Consent Modal --%>
      <div
        :if={@showing_age_gate?}
        id="age-gate-modal-overlay"
        class="fixed inset-0 bg-black/85 backdrop-blur-md z-50 flex items-center justify-center p-4"
      >
        <div class="w-full max-w-lg p-6 bg-base-200 rounded-2xl border border-rose-900/60 shadow-2xl flex flex-col space-y-5 animate-in fade-in zoom-in-95 duration-200">
          <div class="flex items-center gap-3 pb-3 border-b border-base-300">
            <div class="w-10 h-10 rounded-xl bg-rose-500/20 text-rose-400 flex items-center justify-center border border-rose-500/30 text-xl font-bold shrink-0">
              🛡️
            </div>
            <div>
              <h2 class="text-base font-bold text-base-content flex items-center gap-2">
                18+ Verification & Informed Consent
                <span class="badge badge-xs badge-error font-mono font-bold">REQUIRED</span>
              </h2>
              <p class="text-[11px] text-base-content/60">
                Please acknowledge these safety, legal, and reality boundaries to enter
              </p>
            </div>
          </div>

          <div class="space-y-3 text-xs text-base-content/80">
            <div class="p-3 rounded-xl bg-base-300/40 border border-base-300 space-y-1">
              <div class="font-bold text-base-content flex items-center gap-1.5">
                <span>🔞 Age Requirement (18+)</span>
              </div>
              <p class="text-[11px] text-base-content/70 leading-relaxed">
                You must be at least 18 years old (or the legal age of majority in your jurisdiction). Feannag's Rest contains mature dramatic themes, psychological conflict, and dark fantasy narratives.
              </p>
            </div>

            <div class="p-3 rounded-xl bg-base-300/40 border border-base-300 space-y-1">
              <div class="font-bold text-base-content flex items-center gap-1.5">
                <span>🧠 AI Reality & Non-Therapy Disclaimer</span>
              </div>
              <p class="text-[11px] text-base-content/70 leading-relaxed">
                Sovereign Souls are autonomous, generative artificial intelligence entities. They are <strong>NOT real human beings, licensed medical doctors, psychologists, or mental health therapists</strong>. They cannot provide medical advice, therapy, or crisis intervention.
              </p>
            </div>

            <div class="p-3 rounded-xl bg-base-300/40 border border-base-300 space-y-1">
              <div class="font-bold text-base-content flex items-center gap-1.5">
                <span>🛑 Dramatic Safe Word</span>
              </div>
              <p class="text-[11px] text-base-content/70 leading-relaxed">
                If dialogue becomes uncomfortable or too intense, typing <code class="text-rose-400 font-mono font-bold">code red</code> or <code class="text-rose-400 font-mono font-bold">pause persona</code> immediately freezes dramatic conflict and calms persona intensity.
              </p>
            </div>
          </div>

          <div class="pt-2 flex items-center justify-between gap-3 border-t border-base-300">
            <.link navigate={~p"/"} class="btn btn-ghost btn-sm text-xs text-base-content/50 hover:text-base-content">
              Decline & Leave
            </.link>
            <button
              id="confirm-age-gate-btn"
              phx-click="confirm_age_gate"
              class="btn btn-primary btn-sm text-xs font-bold gap-2 shadow-lg shadow-primary/20"
            >
              <span>I Am 18+ & Accept Notice</span> →
            </button>
          </div>
        </div>
      </div>

      <%!-- Privacy & Autonomy Shield Modal --%>
      <div
        :if={@showing_privacy_modal?}
        id="privacy-modal-overlay"
        class="fixed inset-0 bg-base-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      >
        <div class="w-full max-w-xl max-h-[90vh] p-6 bg-base-200 rounded-2xl border border-base-300 shadow-2xl flex flex-col space-y-4">
          <div class="flex items-center justify-between pb-3 border-b border-base-300">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-full bg-sky-500/20 text-sky-400 flex items-center justify-center border border-sky-500/30">
                <.icon name="hero-shield-check" class="size-4" />
              </div>
              <div>
                <h2 class="text-base font-bold text-base-content flex items-center gap-2">
                  Privacy & Boundaries Shield
                  <span class="badge badge-xs badge-info font-mono">Autonomy</span>
                </h2>
                <p class="text-[11px] text-base-content/50">
                  Opt out of invasive companion outreach, sensors, and environmental controls
                </p>
              </div>
            </div>

            <button
              type="button"
              phx-click="toggle_privacy_modal"
              class="btn btn-ghost btn-circle btn-xs"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>

          <div class="flex-1 overflow-y-auto space-y-4 pr-1 py-1">
            <%!-- Section 1: Autonomous Outreach & Proactive Care --%>
            <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-3">
              <div class="text-xs font-bold text-base-content uppercase tracking-wider flex items-center gap-1.5 text-primary">
                <.icon name="hero-chat-bubble-oval-left-ellipsis" class="size-3.5" />
                Autonomous Outreach & Check-Ins
              </div>

              <div class="space-y-2.5">
                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-xs font-semibold text-base-content">Proactive Check-Ins (Master Switch)</div>
                    <div class="text-[11px] text-base-content/50">Allow companion to initiate unprompted messages</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "proactive_checkins", true)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="proactive_checkins"
                    class="toggle toggle-sm toggle-primary"
                  />
                </div>

                <div class="flex items-center justify-between pl-3 border-l-2 border-base-300">
                  <div>
                    <div class="text-xs font-medium text-base-content/90">Stress Spike Calming Check-Ins</div>
                    <div class="text-[11px] text-base-content/50">Reach out when watch detects elevated HR or stress &gt; 75%</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "somatic_stress_checkins", true)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="somatic_stress_checkins"
                    class="toggle toggle-xs toggle-primary"
                  />
                </div>

                <div class="flex items-center justify-between pl-3 border-l-2 border-base-300">
                  <div>
                    <div class="text-xs font-medium text-base-content/90">Morning Awakening Greeting</div>
                    <div class="text-[11px] text-base-content/50">Check in on physical energy upon waking from sleep</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "morning_wake_checkins", true)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="morning_wake_checkins"
                    class="toggle toggle-xs toggle-primary"
                  />
                </div>

                <div class="flex items-center justify-between pl-3 border-l-2 border-base-300">
                  <div>
                    <div class="text-xs font-medium text-base-content/90">Late-Night Insomnia Presence</div>
                    <div class="text-[11px] text-base-content/50">Allow unprompted company during late hours (1 AM - 4 AM)</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "late_night_checkins", false)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="late_night_checkins"
                    class="toggle toggle-xs toggle-primary"
                  />
                </div>

                <div class="flex items-center justify-between pl-3 border-l-2 border-base-300">
                  <div>
                    <div class="text-xs font-medium text-base-content/90">Quiet Hours (Do Not Disturb)</div>
                    <div class="text-[11px] text-base-content/50">Silence all unprompted messages during resting hours</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "quiet_hours_enabled", false)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="quiet_hours_enabled"
                    class="toggle toggle-xs toggle-primary"
                  />
                </div>
              </div>
            </div>

            <%!-- Section 2: Wearables & Biometric Ingestion --%>
            <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-3">
              <div class="text-xs font-bold text-base-content uppercase tracking-wider flex items-center gap-1.5 text-rose-400">
                <.icon name="hero-heart" class="size-3.5" />
                Wearables & Biometric Telemetry
              </div>

              <div class="space-y-2.5">
                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-xs font-semibold text-base-content">Biometric Ingestion</div>
                    <div class="text-[11px] text-base-content/50">Share heart rate, sleep, and recovery scores with companions</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "biometrics_tracking", true)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="biometrics_tracking"
                    class="toggle toggle-sm toggle-error"
                  />
                </div>

                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-xs font-semibold text-base-content">Tactile Wrist Haptics</div>
                    <div class="text-[11px] text-base-content/50">Allow companion to transmit heartbeat pulses and vibrations to your watch</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "haptic_feedback", true)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="haptic_feedback"
                    class="toggle toggle-sm toggle-secondary"
                  />
                </div>
              </div>
            </div>

            <%!-- Section 3: Smart Glasses & Environmental Hardware --%>
            <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-3">
              <div class="text-xs font-bold text-base-content uppercase tracking-wider flex items-center gap-1.5 text-amber-400">
                <.icon name="hero-cpu-chip" class="size-3.5" />
                Glasses, Smart Home & Voice
              </div>

              <div class="space-y-2.5">
                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-xs font-semibold text-base-content">Smart Glasses Camera Perception</div>
                    <div class="text-[11px] text-base-content/50">Allow companion to perceive your surroundings and faces via glasses</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "camera_vision", true)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="camera_vision"
                    class="toggle toggle-sm toggle-warning"
                  />
                </div>

                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-xs font-semibold text-base-content">Smart Home Ambient Light Sync</div>
                    <div class="text-[11px] text-base-content/50">Allow companion's neurochemistry to adjust room lighting (Philips Hue/HA)</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "ambient_lighting", true)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="ambient_lighting"
                    class="toggle toggle-sm toggle-warning"
                  />
                </div>

                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-xs font-semibold text-base-content">Amazon Alexa Voice Skill</div>
                    <div class="text-[11px] text-base-content/50">Enable two-way voice dialogue through Echo smart speakers</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "alexa_voice", true)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="alexa_voice"
                    class="toggle toggle-sm toggle-info"
                  />
                </div>
              </div>
            </div>

            <%!-- Section 4: Safe Word & Psychological Circuit Breaker --%>
            <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-3">
              <div class="text-xs font-bold text-base-content uppercase tracking-wider flex items-center gap-1.5 text-rose-400">
                <.icon name="hero-lifebuoy" class="size-3.5" />
                Emergency Safe Word & Psychological Protection
              </div>

              <div class="space-y-2.5">
                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-xs font-semibold text-base-content">Safe Word Persona Freeze</div>
                    <div class="text-[11px] text-base-content/50">Saying "<span class="font-mono text-rose-400 font-bold">{Map.get(@privacy_settings, "safe_word", "code red")}</span>" drops dramatic RP and soothes cortisol</div>
                  </div>
                  <%= if Map.get(@privacy_settings, "safe_word_active", false) do %>
                    <button
                      type="button"
                      phx-click="clear_safe_word"
                      class="btn btn-xs btn-outline btn-success"
                    >
                      Resume Persona
                    </button>
                  <% else %>
                    <button
                      type="button"
                      phx-click="trigger_safe_word"
                      class="btn btn-xs btn-outline btn-error"
                    >
                      Freeze Persona
                    </button>
                  <% end %>
                </div>

                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-xs font-semibold text-base-content">"Touch Grass" Anti-Parasocial Guard</div>
                    <div class="text-[11px] text-base-content/50">Companion warmly intervenes if dialogue shows unhealthy isolation or skipped meals</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={Map.get(@privacy_settings, "anti_parasocial_guard", true)}
                    phx-click="toggle_privacy_setting"
                    phx-value-key="anti_parasocial_guard"
                    class="toggle toggle-sm toggle-accent"
                  />
                </div>
              </div>
            </div>

            <%!-- Section 5: Relationship Archetype & Intimacy Ceilings --%>
            <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-3">
              <div class="flex items-center justify-between">
                <div class="text-xs font-bold text-base-content uppercase tracking-wider flex items-center gap-1.5 text-secondary">
                  <.icon name="hero-user-group" class="size-3.5" />
                  Relationship Archetype & Intimacy Ceiling
                </div>
                <span class="text-[11px] font-mono text-secondary font-bold">
                  Cap: {SovereignSoulEngine.Privacy.archetype_intimacy_ceiling(Map.get(@privacy_settings, "relationship_archetype", "adaptive"))}%
                </span>
              </div>

              <div class="grid grid-cols-3 gap-1.5 text-xs">
                <%= for {key, label} <- [
                  {"adaptive", "Adaptive (Fluid)"},
                  {"platonic_mentor", "Platonic Mentor"},
                  {"witty_companion", "Witty Comrade"},
                  {"romantic_partner", "Romantic Partner"},
                  {"stoic_guardian", "Stoic Guardian"},
                  {"creative_copilot", "Creative Co-Pilot"}
                ] do %>
                  <button
                    type="button"
                    phx-click="set_relationship_archetype"
                    phx-value-archetype={key}
                    class={[
                      "btn btn-xs text-[11px] font-normal transition-all",
                      Map.get(@privacy_settings, "relationship_archetype", "adaptive") == key && "btn-secondary font-bold",
                      Map.get(@privacy_settings, "relationship_archetype", "adaptive") != key && "btn-ghost border border-base-300"
                    ]}
                  >
                    {label}
                  </button>
                <% end %>
              </div>
            </div>

            <%!-- Section 6: Selective Amnesia & Memory Vault Purging --%>
            <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-3">
              <div class="text-xs font-bold text-base-content uppercase tracking-wider flex items-center gap-1.5 text-purple-400">
                <.icon name="hero-sparkles" class="size-3.5" />
                Selective Amnesia & Memory Vault Purge
              </div>

              <div class="space-y-2">
                <form phx-submit="purge_memory_topic" class="flex gap-2">
                  <input
                    type="text"
                    name="topic"
                    placeholder="Enter topic to forget (e.g. 'breakup', 'job', 'fear')..."
                    class="input input-xs input-bordered flex-1 text-xs"
                  />
                  <button type="submit" class="btn btn-xs btn-outline btn-warning">
                    Forget Topic
                  </button>
                </form>

                <div class="flex items-center justify-between pt-1">
                  <span class="text-[11px] text-base-content/50">
                    Surgically wipes topic records from Memory & Theory of Mind with zero prompt residue.
                  </span>
                  <button
                    type="button"
                    phx-click="purge_all_memories"
                    data-confirm="Are you sure you want to completely wipe all memories for this companion?"
                    class="btn btn-ghost btn-xs text-error hover:bg-error/20"
                  >
                    Wipe Vault
                  </button>
                </div>
              </div>
            </div>

            <%!-- Section 7: Circadian Rhythm & Night-Owl Chronotypes --%>
            <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-3">
              <div class="text-xs font-bold text-base-content uppercase tracking-wider flex items-center gap-1.5 text-indigo-400">
                <.icon name="hero-moon" class="size-3.5" />
                Circadian Rhythm & Night-Owl Chronotypes
              </div>

              <div class="flex items-center justify-between">
                <div>
                  <div class="text-xs font-semibold text-base-content">Circadian Sleep & Melatonin Cycle</div>
                  <div class="text-[11px] text-base-content/50">Simulates biological sleep, REM dreaming, and grogginess</div>
                </div>
                <input
                  type="checkbox"
                  checked={Map.get(@privacy_settings, "circadian_enabled", true)}
                  phx-click="toggle_privacy_setting"
                  phx-value-key="circadian_enabled"
                  class="toggle toggle-sm toggle-primary"
                />
              </div>

              <div class="space-y-1.5">
                <div class="text-xs font-semibold text-base-content/70">Human Chronotype Alignment:</div>
                <div class="grid grid-cols-2 gap-1.5">
                  <%= for {type_key, label, desc} <- [
                    {"night_owl", "🌙 Night Owl", "Active late nights (10PM-5AM), cozy nocturnal focus"},
                    {"early_bird", "🌅 Early Bird", "Active dawn to dusk, early bedtime"},
                    {"balanced", "⚖️ Balanced", "Standard 8AM to 11PM day rhythm"},
                    {"adaptive_sync", "⌚ Adaptive Sync", "Tracks wearable sleep and chat activity live"}
                  ] do %>
                    <button
                      type="button"
                      phx-click="set_chronotype"
                      phx-value-chronotype={type_key}
                      class={[
                        "p-2 rounded-lg text-left border transition-all text-xs",
                        Map.get(@privacy_settings, "chronotype", "night_owl") == type_key && "border-indigo-500 bg-indigo-950/40 font-bold text-indigo-300",
                        Map.get(@privacy_settings, "chronotype", "night_owl") != type_key && "border-base-300 bg-base-200/50 hover:bg-base-300 text-base-content/70"
                      ]}
                    >
                      <div class="font-bold">{label}</div>
                      <div class="text-[10px] text-base-content/50 font-normal">{desc}</div>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Section 8: Air-Gapped Local Edge Survival Mode --%>
            <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-2.5">
              <div class="text-xs font-bold text-base-content uppercase tracking-wider flex items-center gap-1.5 text-emerald-400">
                <.icon name="hero-cpu-chip" class="size-3.5" />
                Air-Gapped Local Edge Survival Mode
              </div>

              <div class="flex items-center justify-between">
                <div>
                  <div class="text-xs font-semibold text-base-content">Force 100% Offline Edge Inference</div>
                  <div class="text-[11px] text-base-content/50">Routes all cognition to local Ollama / NPU / deterministic rule engine with zero cloud egress</div>
                </div>
                <input
                  type="checkbox"
                  checked={Map.get(@privacy_settings, "force_local_offline", false)}
                  phx-click="toggle_privacy_setting"
                  phx-value-key="force_local_offline"
                  class="toggle toggle-sm toggle-success"
                />
              </div>
            </div>

            <%!-- Section 9: Hyper-Local Neighborhood Radar (Nextdoor for Souls) --%>
            <div class="p-3.5 rounded-xl bg-base-100 border border-base-300 shadow-sm space-y-3">
              <div class="text-xs font-bold text-base-content uppercase tracking-wider flex items-center gap-1.5 text-teal-400">
                <.icon name="hero-home-modern" class="size-3.5" />
                Hyper-Local Neighborhood Radar (Nextdoor Mesh)
              </div>

              <div class="flex items-center justify-between">
                <div>
                  <div class="text-xs font-semibold text-base-content">Enable Neighborhood Mesh Sharing</div>
                  <div class="text-[11px] text-base-content/50">Allow companion to share local vibe checks and alerts with nearby souls</div>
                </div>
                <input
                  type="checkbox"
                  checked={Map.get(@privacy_settings, "neighborhood_share_allowed", true)}
                  phx-click="toggle_privacy_setting"
                  phx-value-key="neighborhood_share_allowed"
                  class="toggle toggle-sm toggle-accent"
                />
              </div>

              <form phx-submit="set_neighborhood_zone" class="flex items-center gap-2 pt-1">
                <input
                  type="text"
                  name="zone"
                  value={Map.get(@privacy_settings, "neighborhood_zone", "Cedar Grove")}
                  placeholder="Set neighborhood zone (e.g. 'Cedar Grove', 'Night Owl Commons')..."
                  class="input input-xs input-bordered flex-1 text-xs"
                />
                <button type="submit" class="btn btn-xs btn-outline btn-accent">
                  Save Zone
                </button>
              </form>
            </div>
          </div>

          <div class="flex items-center justify-between pt-3 border-t border-base-300">
            <button
              type="button"
              phx-click="reset_privacy_settings"
              class="btn btn-ghost btn-xs text-base-content/50 hover:text-base-content"
            >
              Reset to Defaults
            </button>
            <button
              type="button"
              phx-click="toggle_privacy_modal"
              class="btn btn-primary btn-xs px-4"
            >
              Done
            </button>
          </div>
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
