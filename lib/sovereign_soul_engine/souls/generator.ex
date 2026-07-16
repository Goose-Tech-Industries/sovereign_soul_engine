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
        "type": "none | observe | protect | threaten | flee",
        "confidence": 0.0 to 1.0,
        "reason": "Reason for action."
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

  # Action Dispatcher: Triggers direct relationship changes in the database
  defp dispatch_action(npc, player, scene, %{proposed_action: "protect"} = action) do
    # Protect increases target trust towards the protector
    Logger.info("Dispatching action: #{npc.name} protects #{player.name}. Shifting relationship trust.")
    rel = Relationships.get_relationship(player.id, npc.id) ||
      (case Relationships.create_relationship(%{source_character_id: player.id, target_character_id: npc.id}) do
         {:ok, r} -> r
       end)
    Relationships.update_relationship(rel, %{trust: min(rel.trust + 10, 100)})

    # Log system notice message
    Scenes.create_message(%{
      scene_id: scene.id,
      character_id: npc.id,
      content: "*[Action: Protect] #{npc.name} moves to protect and shield #{player.name} (Reason: #{action.reason})*",
      kind: "system"
    })
  end

  defp dispatch_action(npc, player, scene, %{proposed_action: "threaten"} = action) do
    # Threaten decreases target trust and increases fear
    Logger.info("Dispatching action: #{npc.name} threatens #{player.name}.")
    rel = Relationships.get_relationship(player.id, npc.id) ||
      (case Relationships.create_relationship(%{source_character_id: player.id, target_character_id: npc.id}) do
         {:ok, r} -> r
       end)
    Relationships.update_relationship(rel, %{trust: max(rel.trust - 15, -100), fear: min(rel.fear + 20, 100)})

    # Log system notice message
    Scenes.create_message(%{
      scene_id: scene.id,
      character_id: npc.id,
      content: "*[Action: Threaten] #{npc.name} aggressively threatens #{player.name} (Reason: #{action.reason})*",
      kind: "system"
    })
  end

  defp dispatch_action(npc, player, scene, %{proposed_action: "flee"} = action) do
    # Flee logs system action
    Logger.info("Dispatching action: #{npc.name} flees.")
    Scenes.create_message(%{
      scene_id: scene.id,
      character_id: npc.id,
      content: "*[Action: Flee] #{npc.name} retreats in panic (Reason: #{action.reason})*",
      kind: "system"
    })
  end

  defp dispatch_action(_npc, _player, _scene, _action), do: :ok
end
