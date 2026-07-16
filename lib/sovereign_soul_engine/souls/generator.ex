defmodule SovereignSoulEngine.Souls.Generator do
  @moduledoc """
  Unified generator for NPC responses, handling prompt building, LLM cascade calls,
  consequence resolution, shadow logging, fear ingestion, and PubSub broadcasts.
  """

  alias SovereignSoulEngine.{Characters, Scenes, Relationships, Souls, Memories}
  alias SovereignSoulEngine.LLM.ProviderCascade
  alias SovereignSoulEngine.Souls.ConsequenceEngine

  require Logger

  def generate(npc_id, scene_id, player_id \\ nil) do
    npc = Characters.get_character!(npc_id)
    scene = Scenes.get_scene!(scene_id)
    
    # Resolve player_id if not provided
    player_id = player_id || get_player_id(scene_id)
    player = if player_id, do: Characters.get_character!(player_id), else: %{id: nil, name: "Goose"}

    history_messages = Scenes.list_messages(scene.id) |> Enum.take(-10)
    characters = Characters.list_characters()

    llm_messages =
      Enum.map(history_messages, fn m ->
        role = if m.character_id == player.id, do: "user", else: "assistant"
        char = Enum.find(characters, &(&1.id == m.character_id))
        name = if char, do: char.name, else: "Unknown"
        %{role: role, content: "#{name}: #{m.content}"}
      end)

    emotional_state = Souls.get_emotional_state_by_character(npc.id)
    relationships = Relationships.list_relationships_for_source(npc.id)

    relationships_prompt =
      relationships
      |> Enum.map(fn r ->
        target = Enum.find(characters, &(&1.id == r.target_character_id))
        target_name = if target, do: target.name, else: "Unknown"
        rel_type = r.relationship_type || "acquaintance"
        """
        - #{target_name} (Relationship: #{rel_type}):
          * Trust: #{r.trust}/100
          * Respect: #{r.respect}/100
          * Anger: #{r.anger}/100
          * Fear: #{r.fear}/100
          * Attachment/Affinity: #{r.affinity}/100
          * Wounds: #{r.wound}/100
        """
      end)
      |> Enum.join("\n")

    memories = Memories.list_memories_for_character(npc.id) |> Enum.take(5)
    fears = Souls.list_soul_fears_for_character(npc.id)
    fears_prompt =
      if fears == [] do
        "None"
      else
        Enum.map_join(fears, "\n", &"- #{&1.fear_type} (Severity: #{&1.severity}/100, Origin: #{&1.origin})")
      end

    profile = Souls.get_soul_profile_by_character(npc.id)
    traits = (profile && profile.personality_traits) || %{}
    traits_instructions = [
      if(traits["depression"], do: "- Depression: Your baseline affect is heavy, flat, and slow. You struggle to feel enthusiasm or joy, find action exhausting, and speak with listless weariness."),
      if(traits["bipolar"], do: "- Bipolar Disorder: You experience extreme emotional cycles. Under high stress/wounds, you are in a depressive crash (low confidence, heavy sadness). Under low stress/wounds, you are in a manic phase: hyper-verbal, overconfident, and reckless, completely ignoring fear."),
      if(traits["ocd"], do: "- Obsessive-Compulsive: You fixate intensely on specific unresolved details, safety concerns, or past errors, repeating them cyclically in your thoughts and public speech unless explicitly reassured."),
      if(traits["splitting"], do: "- Splitting (BPD): You view people in black-and-white extremes. They are either your flawless saviors or your evil enemies. You shift between these states rapidly based on a single validation or critique."),
      if(traits["adhd"], do: "- ADHD: Your thoughts are scattered. You get easily distracted by small environmental details, shift topics mid-sentence, and struggle to focus on a single long-term objective."),
      if(traits["narcissism"], do: "- Narcissism: Your ego is fragile. You deflect all criticism, project your own failures onto others, and react with arrogance or immediate hostility if your competence is questioned."),
      if(traits["impostor"], do: "- Impostor Syndrome: You suffer from deep self-doubt, expect to be exposed as a fraud, and constantly defer decisions to others, seeking reassurance."),
      if(traits["codependency"], do: "- Codependency: Your safety is tied to others' approval. You will agree with and defend your partners even if it violates your own beliefs, fearing rejection above all else."),
      if(traits["addiction"], do: "- Addiction: You struggle with a craving/dependency. This makes you irritable, anxious, and highly transactional unless your dependency needs are addressed."),
      if(traits["hypochondria"], do: "- Hypochondria: You are obsessed with physical illness/infection. You constantly scan for bodily symptoms, worry you are sick or infected, and obsessively talk about contamination.")
    ]
    |> Enum.filter(& &1)

    traits_prompt =
      if traits_instructions == [] do
        "None"
      else
        Enum.join(traits_instructions, "\n")
      end

    location = scene.location || "Unknown Location"
    mood = get_in(scene.context || %{}, ["mood"]) || "calm"
    weather = get_in(scene.context || %{}, ["weather"]) || "clear"
    narrative = get_in(scene.context || %{}, ["narrative"]) || ""

    system_prompt = """
    You are #{npc.name}, #{npc.description}.

    You are a persistent, embodied character who can take physical actions in the world beyond speaking.
    After responding in dialogue, you may propose ONE physical or emotional action that reflects your
    current state, relationship, and goals. Choose actions that feel authentic and grounded — do not
    perform dramatic actions without narrative justification.

    Available actions (only propose one per response):
    - observe: watch silently, gather information
    - protect: physically shield or defend someone
    - attack: use force against someone (high anger, low trust required)
    - threaten: intimidate without physical contact
    - heal: tend to wounds or illness
    - give_item: hand something to another character
    - take_item: take something from another character
    - draw_weapon: reveal a weapon as a warning or preparation
    - sheathe_weapon: put away a weapon to de-escalate
    - lock_door: secure the room
    - unlock_door: open a locked passage
    - open_door / close_door: mundane door use
    - knock: rap on a door or surface
    - search_room: look through the environment
    - hide: conceal yourself
    - flee / flee_scene: retreat in fear or urgency
    - sit / stand: postural changes that signal emotional state
    - restrain: physically hold someone
    - disarm: strip a weapon from someone
    - share_secret: lean in and confide something
    - bargain: offer a deal
    - praise / insult / apologize / refuse: social actions with real weight
    - leave_room: exit the scene
    - none: no physical action this turn

    Current Emotional State:
    - Anger: #{(emotional_state && emotional_state.anger) || 0}/100
    - Fear: #{(emotional_state && emotional_state.fear) || 0}/100
    - Stress: #{(emotional_state && emotional_state.stress) || 0}/100
    - Attachment: #{(emotional_state && emotional_state.attachment) || 0}/100

    Active Fears & Phobias:
    #{fears_prompt}

    Personality Conditions & Trait Modifiers:
    #{traits_prompt}

    Current Scenario / Backdrop:
    - Location: #{location}
    - Atmosphere / Mood: #{mood}
    - Environment / Weather: #{weather}
    #{if narrative != "", do: "- Narrative Event / Transition context: " <> narrative, else: ""}

    Your Relationships with other characters:
    #{relationships_prompt}

    Recent Memories:
    #{Enum.map(memories, &"- #{&1.summary} (Valence: #{&1.valence})") |> Enum.join("\n")}

    Respond in JSON format matching this schema:
    {
      "public_speech": "Your response to the player's message.",
      "private_thought": "Your internal monologue and calculations.",
      "tone": "Brief description of tone.",
      "motivation": "Brief description of motivation.",
      "updated_description": "Optional. If your goals, relationship context, or narrative motives have changed significantly, write a concise new description/motivation for yourself (max 25 words). Otherwise, omit or keep empty.",
      "repressed_motive": "Your secret or hidden motive in this scene that you cannot declare publicly.",
      "active_defense": "The defense mechanism you are currently employing (e.g. projection, rationalization, displacement, none).",
      "proposed_action": {
        "type": "none | observe | speak | praise | insult | apologize | threaten | protect | assist | heal | attack | leave_room | share_secret | bargain | refuse | lock_door | unlock_door | give_item | take_item | draw_weapon | sheathe_weapon | search_room | hide | flee | flee_scene | sit | stand | knock | open_door | close_door | restrain | disarm",
        "confidence": 0.0 to 1.0,
        "reason": "Concise physical or emotional reason for this action. Write as a narrator beat, not dialogue."
      },
      "psychological_updates": {
        "acquired_fears": ["A list of new fear strings born from this interaction, or empty array."]
      },
      "memory_candidates": [
        {
          "category": "episodic",
          "summary": "Short summary of the interaction.",
          "details": "More details.",
          "importance": 0 to 100,
          "emotional_intensity": 0 to 100,
          "valence": -1.0 to 1.0,
          "tags": ["tag1", "tag2"]
        }
      ]
    }
    """

    case ProviderCascade.respond(%{
           system: system_prompt,
           messages: llm_messages
         }) do
      {:ok, response} ->
        correlation_id = Ecto.UUID.generate()
        action_res = response[:proposed_action] || response["proposed_action"]

        action_resolution =
          if action_res && (action_res[:type] || action_res["type"]) do
            %{
              proposed_action: action_res[:type] || action_res["type"],
              confidence: action_res[:confidence] || action_res["confidence"] || 0.0,
              reason: action_res[:reason] || action_res["reason"] || ""
            }
          else
            nil
          end

        memory_candidate =
          if response[:memory_candidates] || response["memory_candidates"] do
            mcs = response[:memory_candidates] || response["memory_candidates"]
            mc = List.first(mcs) || %{}
            %{
              category: mc[:category] || mc["category"] || "episodic",
              summary: mc[:summary] || mc["summary"] || "interaction",
              details: mc[:details] || mc["details"] || "",
              importance: mc[:importance] || mc["importance"] || 50,
              emotional_intensity: mc[:emotional_intensity] || mc["emotional_intensity"] || 50,
              valence: mc[:valence] || mc["valence"] || 0.0,
              tags: mc[:tags] || mc["tags"] || []
            }
          else
            nil
          end

        case ConsequenceEngine.resolve(%{
          character_id: npc.id,
          source_character_id: npc.id,
          target_character_id: player.id,
          scene_id: scene.id,
          event_type: :speak,
          event_intensity: 10,
          message_content: response[:public_speech] || response["public_speech"] || "...",
          private_thought: response[:private_thought] || response["private_thought"] || "...",
          action_resolution: action_resolution,
          memory_candidate: memory_candidate,
          correlation_id: correlation_id
        }) do
          {:ok, result} ->
            # Create a subconscious shadow log
            repressed_motive = response[:repressed_motive] || response["repressed_motive"] || "none"
            active_defense = response[:active_defense] || response["active_defense"] || "none"
            private_monologue = response[:private_thought] || response["private_thought"] || "none"
            emotional_drift = %{
              "anger" => (emotional_state && emotional_state.anger) || 0,
              "fear" => (emotional_state && emotional_state.fear) || 0,
              "stress" => (emotional_state && emotional_state.stress) || 0,
              "attachment" => (emotional_state && emotional_state.attachment) || 0
            }

            {:ok, _shadow} = Souls.create_soul_shadow(%{
              character_id: npc.id,
              scene_id: scene.id,
              private_monologue: private_monologue,
              repressed_motive: repressed_motive,
              active_defense: active_defense,
              emotional_drift: emotional_drift
            })

            # Ingest newly acquired fears
            psych_updates = response[:psychological_updates] || response["psychological_updates"] || %{}
            new_fears = psych_updates[:acquired_fears] || psych_updates["acquired_fears"] || []

            Enum.each(new_fears, fn fear_str ->
              if String.trim(fear_str) != "" do
                Souls.create_soul_fear(%{
                  character_id: npc.id,
                  fear_type: String.trim(fear_str),
                  severity: 70,
                  origin: "acquired",
                  status: "active",
                  acquired_in_scene_id: scene.id
                })
              end
            end)

            # Active fears decay loop: if current stress is low, decrement severity
            latest_state = Souls.get_emotional_state_by_character(npc.id)
            stress_level = (latest_state && latest_state.stress) || 0
            if stress_level < 30 do
              Enum.each(fears, fn f ->
                new_sev = max(f.severity - 5, 0)
                if new_sev == 0 do
                  Souls.update_soul_fear(f, %{severity: 0, status: "resolved"})
                else
                  Souls.update_soul_fear(f, %{severity: new_sev})
                end
              end)
            end

            # Update character description in the database in real-time if returned
            updated_desc = response[:updated_description] || response["updated_description"]
            if updated_desc && String.trim(updated_desc) != "" do
              {:ok, _updated_npc} = Characters.update_character(npc, %{description: String.trim(updated_desc)})
              
              Phoenix.PubSub.broadcast(
                SovereignSoulEngine.PubSub,
                "scenes:list_updates",
                {:scenes_updated, %{}}
              )
            end

            # Dispatch action resolution (e.g. increase trust if protecting)
            if action_resolution do
              dispatch_action(npc, player, scene, action_resolution)
            end

            # Broadcast new message
            Phoenix.PubSub.broadcast(
              SovereignSoulEngine.PubSub,
              "scene:#{scene.id}",
              {:new_message, result.scene_message}
            )

            Phoenix.PubSub.broadcast(
              SovereignSoulEngine.PubSub,
              "character:#{npc.id}",
              {:emotion_updated, latest_state}
            )

            {:ok, result.scene_message}

          {:error, reason} ->
            Logger.error("Consequence resolution failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("LLM Cascade call failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_player_id(scene_id) do
    Scenes.get_scene!(scene_id)
    |> SovereignSoulEngine.Repo.preload(participants: :character)
    |> Map.get(:participants, [])
    |> Enum.find(&(&1.character.kind == "player" or &1.character.kind == "user"))
    |> case do
         nil -> nil
         p -> p.character_id
       end
  end

  # Action Dispatcher: applies relationship side-effects and broadcasts a
  # distinct action message to the scene. message_type "action" renders
  # differently from "dialogue" in the UI (bold-italic, coloured border).

  defp dispatch_action(npc, player, scene, %{proposed_action: action_type} = action) do
    Logger.info("Dispatching action #{action_type}: #{npc.name} in scene #{scene.id}")
    text = action_narrative(action_type, npc, player, action.reason)
    apply_action_side_effects(action_type, npc, player)
    broadcast_action_message(npc, scene, text)
  end

  defp dispatch_action(_npc, _player, _scene, _action), do: :ok

  # Narrative text for each action type — shown in chat as an action beat
  defp action_narrative("protect", npc, player, reason),
    do: "#{npc.name} steps in front of #{player.name}, shielding them. #{reason}"

  defp action_narrative("attack", npc, player, reason),
    do: "#{npc.name} lunges at #{player.name} with intent to harm. #{reason}"

  defp action_narrative("threaten", npc, player, reason),
    do: "#{npc.name} levels a threatening gaze at #{player.name}. #{reason}"

  defp action_narrative("flee", npc, _player, reason),
    do: "#{npc.name} turns and bolts from the scene. #{reason}"

  defp action_narrative("flee_scene", npc, _player, reason),
    do: "#{npc.name} retreats, disappearing from sight. #{reason}"

  defp action_narrative("lock_door", npc, _player, reason),
    do: "#{npc.name} moves to the door and locks it with a heavy click. #{reason}"

  defp action_narrative("unlock_door", npc, _player, reason),
    do: "#{npc.name} produces a key and unlocks the door. #{reason}"

  defp action_narrative("open_door", npc, _player, reason),
    do: "#{npc.name} pulls the door open. #{reason}"

  defp action_narrative("close_door", npc, _player, reason),
    do: "#{npc.name} pushes the door shut behind them. #{reason}"

  defp action_narrative("give_item", npc, player, reason),
    do: "#{npc.name} presses something into #{player.name}'s hands. #{reason}"

  defp action_narrative("take_item", npc, player, reason),
    do: "#{npc.name} takes something from #{player.name}. #{reason}"

  defp action_narrative("draw_weapon", npc, _player, reason),
    do: "#{npc.name} draws a weapon, grip tightening. #{reason}"

  defp action_narrative("sheathe_weapon", npc, _player, reason),
    do: "#{npc.name} slowly sheathes their weapon. #{reason}"

  defp action_narrative("heal", npc, player, reason),
    do: "#{npc.name} tends to #{player.name}'s wounds. #{reason}"

  defp action_narrative("search_room", npc, _player, reason),
    do: "#{npc.name} begins searching the room carefully. #{reason}"

  defp action_narrative("hide", npc, _player, reason),
    do: "#{npc.name} slips into shadow, trying to conceal themselves. #{reason}"

  defp action_narrative("knock", npc, _player, reason),
    do: "#{npc.name} raps sharply on the door. #{reason}"

  defp action_narrative("restrain", npc, player, reason),
    do: "#{npc.name} moves to restrain #{player.name}. #{reason}"

  defp action_narrative("disarm", npc, player, reason),
    do: "#{npc.name} attempts to disarm #{player.name}. #{reason}"

  defp action_narrative("sit", npc, _player, reason),
    do: "#{npc.name} settles into a seat. #{reason}"

  defp action_narrative("stand", npc, _player, reason),
    do: "#{npc.name} rises to their feet. #{reason}"

  defp action_narrative("leave_room", npc, _player, reason),
    do: "#{npc.name} moves toward the exit. #{reason}"

  defp action_narrative("observe", npc, _player, reason),
    do: "#{npc.name} watches silently, taking everything in. #{reason}"

  defp action_narrative("praise", npc, player, reason),
    do: "#{npc.name} acknowledges #{player.name} with genuine respect. #{reason}"

  defp action_narrative("insult", npc, player, reason),
    do: "#{npc.name} directs a cutting remark at #{player.name}. #{reason}"

  defp action_narrative("apologize", npc, player, reason),
    do: "#{npc.name} turns to #{player.name} with something like regret. #{reason}"

  defp action_narrative("assist", npc, player, reason),
    do: "#{npc.name} moves to help #{player.name}. #{reason}"

  defp action_narrative("share_secret", npc, player, reason),
    do: "#{npc.name} leans close to #{player.name} and speaks in a low voice. #{reason}"

  defp action_narrative("bargain", npc, player, reason),
    do: "#{npc.name} makes an offer to #{player.name}. #{reason}"

  defp action_narrative("refuse", npc, _player, reason),
    do: "#{npc.name} refuses. #{reason}"

  defp action_narrative(type, npc, _player, reason),
    do: "#{npc.name} #{type}. #{reason}"

  # Relationship side-effects by action type
  defp apply_action_side_effects("protect", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{trust: min(rel.trust + 10, 100), softening: min(rel.softening + 5, 100)})
    end)
  end

  defp apply_action_side_effects("attack", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        trust: max(rel.trust - 25, -100),
        fear: min(rel.fear + 30, 100),
        anger: min(rel.anger + 20, 100)
      })
    end)
  end

  defp apply_action_side_effects("threaten", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        trust: max(rel.trust - 15, -100),
        fear: min(rel.fear + 20, 100)
      })
    end)
  end

  defp apply_action_side_effects("heal", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        gratitude: min(rel.gratitude + 15, 100),
        trust: min(rel.trust + 8, 100)
      })
    end)
  end

  defp apply_action_side_effects("give_item", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{gratitude: min(rel.gratitude + 10, 100)})
    end)
  end

  defp apply_action_side_effects("praise", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        respect: min(rel.respect + 8, 100),
        affinity: min(rel.affinity + 5, 100)
      })
    end)
  end

  defp apply_action_side_effects("insult", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        respect: max(rel.respect - 10, -100),
        anger: min(rel.anger + 12, 100)
      })
    end)
  end

  defp apply_action_side_effects("apologize", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        anger: max(rel.anger - 10, 0),
        softening: min(rel.softening + 8, 100)
      })
    end)
  end

  defp apply_action_side_effects("restrain", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        trust: max(rel.trust - 20, -100),
        fear: min(rel.fear + 25, 100)
      })
    end)
  end

  defp apply_action_side_effects(_action_type, _npc, _player), do: :ok

  defp with_relationship(source_id, target_id, update_fn) do
    rel =
      Relationships.get_relationship(source_id, target_id) ||
        case Relationships.create_relationship(%{
               source_character_id: source_id,
               target_character_id: target_id
             }) do
          {:ok, r} -> r
          _ -> nil
        end

    if rel, do: update_fn.(rel)
  end

  defp broadcast_action_message(npc, scene, text) do
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

      {:error, reason} ->
        Logger.error("Failed to create action message: #{inspect(reason)}")
    end
  end
end
