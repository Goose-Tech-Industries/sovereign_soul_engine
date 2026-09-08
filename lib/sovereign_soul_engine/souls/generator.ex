defmodule SovereignSoulEngine.Souls.Generator do
  @moduledoc """
  Unified generator for NPC responses, handling prompt building, LLM cascade calls,
  consequence resolution, shadow logging, fear ingestion, PubSub broadcasts,
  and deep psychological context (beliefs, triggers, desires, secrets, moral lines).
  """

  alias SovereignSoulEngine.{Characters, Scenes, Relationships, Souls, Memories}
  alias SovereignSoulEngine.LLM.ProviderCascade
  alias SovereignSoulEngine.Souls.ConsequenceEngine
  alias SovereignSoulEngine.Memories.{Memory, MemoryMerger}
  alias SovereignSoulEngine.Actions.ActionIntent
  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.Souls.{EmotionalContagion, CognitiveLoad}

  require Logger

  def generate(npc_id, scene_id, player_id \\ nil, tenant \\ nil) do
    npc = Characters.get_character!(npc_id)
    scene = Scenes.get_scene!(scene_id)

    # Resolve player_id if not provided
    player_id = player_id || get_player_id(scene_id)

    player =
      if player_id, do: Characters.get_character!(player_id), else: %{id: nil, name: "Goose"}

    history_messages = Scenes.list_messages(scene.id) |> Enum.take(-10)
    characters = Characters.list_characters()

    llm_messages =
      Enum.map(history_messages, fn m ->
        role = if m.character_id == npc.id, do: "assistant", else: "user"
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

    profile = Souls.get_soul_profile_by_character(npc.id)

    # Load deep psychological data first — triggers needed for context tag extraction
    beliefs = Souls.list_beliefs_for_character(npc.id)
    triggers = Souls.list_triggers_for_character(npc.id)
    desires = Souls.list_desires_for_character(npc.id)
    moral_lines = Souls.list_moral_lines_for_character(npc.id)
    # Backstory/secrets reveal gated by how much this player has earned
    # so far — the PLAYER's own tracked trust/affinity toward this
    # character, not an idealized "does the NPC trust me back" (that
    # direction is never populated for ordinary 1:1 chat — ConsequenceEngine
    # explicitly skips relationship processing for event_type: :speak,
    # only apply_action_side_effects/3 ever writes a row, always
    # source=player/target=npc). Using the real, populated data rather
    # than a direction that would silently always read as a stranger.
    trust_with_player =
      if player.id, do: Relationships.get_relationship(player.id, npc.id), else: nil

    player_trust = (trust_with_player && trust_with_player.trust) || 0

    secrets =
      Souls.list_high_risk_secrets_for_character(npc.id)
      |> Enum.filter(fn s ->
        case s.risk_level do
          "critical" -> player_trust >= 70
          "high" -> player_trust >= 40
          _ -> true
        end
      end)

    # Extract context tags from active triggers + last player message keywords
    context_tags = extract_context_tags(triggers, history_messages, player.id)
    memories = Memories.list_relevant_memories_for_character(npc.id, context_tags, limit: 10)
    fears = Souls.list_soul_fears_for_character(npc.id)

    # Load new system data
    somatic_state = Souls.get_somatic_state_by_character(npc.id)
    active_goals = Souls.list_active_goals_for_character(npc.id)
    grief_arcs = Souls.list_active_grief_arcs_for_character(npc.id)
    forgiveness_arcs = Souls.list_active_forgiveness_arcs_for_character(npc.id)

    knowledge_about_player =
      if player.id, do: TheoryOfMind.list_knowledge_about(npc.id, player.id), else: []

    player_knowledge_about_npc =
      if player.id, do: TheoryOfMind.list_knowledge_about(player.id, npc.id), else: []

    # What this character knows about people OTHER than whoever they're
    # talking to right now — previously never fed into the prompt at all,
    # so an NPC had no material to bring up a third party even though they
    # could already "hear" each other via scene history. This is the gossip
    # mechanism: material to share + an interlocutor who can hear it +
    # knowledge_update supporting an arbitrary target_character (see
    # process_knowledge_update/4) is the whole system, no separate field
    # needed. Capped at 5, highest-certainty first, to bound prompt growth.
    third_party_knowledge =
      TheoryOfMind.list_what_knower_knows(npc.id)
      |> Enum.reject(&(&1.subject_character_id == player.id))
      |> Enum.take(5)

    fears_prompt =
      if fears == [] do
        "None"
      else
        Enum.map_join(
          fears,
          "\n",
          &"- #{&1.fear_type} (Severity: #{&1.severity}/100, Origin: #{&1.origin})"
        )
      end

    # Trigger detection: scan last player message for trigger topics
    last_player_message =
      history_messages
      |> Enum.filter(&(&1.character_id == player.id))
      |> List.last()

    active_triggers =
      if last_player_message do
        content_lower = String.downcase(last_player_message.content)

        Enum.filter(triggers, fn t ->
          String.contains?(content_lower, String.downcase(t.topic))
        end)
      else
        []
      end

    trigger_spikes_prompt =
      if active_triggers == [] do
        ""
      else
        lines =
          Enum.map_join(active_triggers, "\n", fn t ->
            "ACTIVE TRIGGER: Player mentioned \"#{t.topic}\". Your #{t.reaction_type} intensifies. #{t.flavor_text}"
          end)

        "\n\nACTIVE EMOTIONAL TRIGGERS THIS TURN:\n#{lines}\n"
      end

    traits = (profile && profile.personality_traits) || %{}

    traits_instructions =
      [
        if(traits["depression"],
          do:
            "- Depression: Your baseline affect is heavy, flat, and slow. You struggle to feel enthusiasm or joy, find action exhausting, and speak with listless weariness."
        ),
        if(traits["bipolar"],
          do:
            "- Bipolar Disorder: You experience extreme emotional cycles. Under high stress/wounds, you are in a depressive crash (low confidence, heavy sadness). Under low stress/wounds, you are in a manic phase: hyper-verbal, overconfident, and reckless, completely ignoring fear."
        ),
        if(traits["ocd"],
          do:
            "- Obsessive-Compulsive: You fixate intensely on specific unresolved details, safety concerns, or past errors, repeating them cyclically in your thoughts and public speech unless explicitly reassured."
        ),
        if(traits["splitting"],
          do:
            "- Splitting (BPD): You view people in black-and-white extremes. They are either your flawless saviors or your evil enemies. You shift between these states rapidly based on a single validation or critique."
        ),
        if(traits["adhd"],
          do:
            "- ADHD: Your thoughts are scattered. You get easily distracted by small environmental details, shift topics mid-sentence, and struggle to focus on a single long-term objective."
        ),
        if(traits["narcissism"],
          do:
            "- Narcissism: Your ego is fragile. You deflect all criticism, project your own failures onto others, and react with arrogance or immediate hostility if your competence is questioned."
        ),
        if(traits["impostor"],
          do:
            "- Impostor Syndrome: You suffer from deep self-doubt, expect to be exposed as a fraud, and constantly defer decisions to others, seeking reassurance."
        ),
        if(traits["codependency"],
          do:
            "- Codependency: Your safety is tied to others' approval. You will agree with and defend your partners even if it violates your own beliefs, fearing rejection above all else."
        ),
        if(traits["addiction"],
          do:
            "- Addiction: You struggle with a craving/dependency. This makes you irritable, anxious, and highly transactional unless your dependency needs are addressed."
        ),
        if(traits["hypochondria"],
          do:
            "- Hypochondria: You are obsessed with physical illness/infection. You constantly scan for bodily symptoms, worry you are sick or infected, and obsessively talk about contamination."
        )
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

    # Build deep psychological context block
    beliefs_prompt =
      if beliefs == [] do
        "None"
      else
        Enum.map_join(beliefs, "\n", fn b ->
          challenged_note = if b.is_challenged, do: " [CHALLENGED]", else: ""
          "- [#{b.domain}] #{b.belief} (Conviction: #{b.conviction}/100#{challenged_note})"
        end)
      end

    desires_prompt =
      if desires == [] do
        "None"
      else
        Enum.map_join(desires, "\n", fn d ->
          "- [#{d.domain}] #{d.desire} (Urgency: #{d.urgency}/100, Status: #{d.status})"
        end)
      end

    moral_lines_prompt =
      if moral_lines == [] do
        "None"
      else
        Enum.map_join(moral_lines, "\n", fn ml ->
          blocked = Enum.join(ml.action_types_blocked, ", ")
          refuses = if ml.will_refuse_when_violated, do: "WILL REFUSE", else: "May resist"

          "- #{ml.principle} (#{refuses}#{if blocked != "", do: "; blocks: #{blocked}", else: ""})"
        end)
      end

    secrets_prompt =
      if secrets == [] do
        "None"
      else
        Enum.map_join(secrets, "\n", fn s ->
          "- [#{s.risk_level}] #{s.secret_text}"
        end)
      end

    # Detect emotional contagion from player's last message
    player_tone =
      if last_player_message,
        do: EmotionalContagion.detect_tone(last_player_message.content),
        else: :neutral

    attachment_style_for_contagion = (profile && profile.attachment_style) || "secure"
    susceptibility = (profile && profile.emotional_susceptibility) || 50

    contagion_deltas =
      EmotionalContagion.apply_contagion(
        emotional_state,
        player_tone,
        susceptibility,
        attachment_style_for_contagion
      )

    contagion_note = EmotionalContagion.describe_contagion(player_tone, contagion_deltas)

    # Compute cognitive load
    {cog_score, cog_stressors} =
      CognitiveLoad.compute(emotional_state, somatic_state, grief_arcs, active_goals)

    cognitive_load_prompt = CognitiveLoad.prompt_instruction(cog_score, cog_stressors)

    # Intrusive thought calculation
    intrusive_thought =
      maybe_surface_intrusive_thought(npc.id, emotional_state, memories, grief_arcs)

    # Humor context
    relationship_to_player =
      if player.id,
        do: Relationships.get_relationship(npc.id, player.id),
        else: nil

    humor_context = compute_humor_context(profile, emotional_state, relationship_to_player)

    attachment_style = (profile && profile.attachment_style) || "secure"

    transference_prompt =
      if profile && map_size(profile.transference_profile || %{}) > 0 do
        Enum.map_join(profile.transference_profile, "\n", fn {k, v} ->
          "- When #{k}: #{v}"
        end)
      else
        "None"
      end

    physical_tells_prompt =
      if profile && map_size(profile.physical_tells || %{}) > 0 do
        Enum.map_join(profile.physical_tells, "\n", fn {emotion, tell} ->
          "- #{emotion}: #{tell}"
        end)
      else
        "None"
      end

    # Somatic state prompt
    somatic_prompt =
      if somatic_state do
        hunger_note = if somatic_state.hunger > 60, do: " — distractingly hungry", else: ""
        pain_note = if somatic_state.pain > 50, do: " — in noticeable pain", else: ""
        fatigue_note = if somatic_state.fatigue > 60, do: " — running on low energy", else: ""

        discomfort_note =
          if somatic_state.hunger > 70 or somatic_state.pain > 70 or somatic_state.fatigue > 70 do
            "\nThese physical discomforts are affecting your patience and emotional regulation."
          else
            ""
          end

        """
        PHYSICAL STATE:
        - Hunger: #{somatic_state.hunger}/100#{hunger_note}
        - Pain: #{somatic_state.pain}/100#{pain_note}
        - Fatigue: #{somatic_state.fatigue}/100#{fatigue_note}#{discomfort_note}
        """
      else
        ""
      end

    # Goals prompt
    goals_prompt =
      if active_goals == [] do
        ""
      else
        lines =
          Enum.map_join(active_goals, "\n", fn g ->
            blocker_note = if g.blocker, do: "\n  BLOCKED: #{g.blocker}", else: ""

            "- #{g.goal} | Step: #{g.current_step || "undefined"} | Priority: #{g.priority}/100#{blocker_note}"
          end)

        "\nACTIVE GOALS (what you are currently pursuing):\n#{lines}\n"
      end

    # Grief arcs prompt
    grief_prompt =
      if grief_arcs == [] do
        ""
      else
        lines =
          Enum.map_join(grief_arcs, "\n", fn arc ->
            stage_note =
              case arc.stage do
                "denial" -> "You have not fully accepted this loss. You deflect when it comes up."
                "anger" -> "You are angry. At fate, at yourself, at anyone nearby."
                "bargaining" -> "You keep running counterfactuals — \"if only I had...\""
                "depression" -> "A heavy weight sits in your chest. Everything feels futile."
                "integration" -> "The loss is part of you now. Painful but no longer raw."
                _ -> ""
              end

            "- Grieving: #{arc.subject} (#{arc.loss_type}) — Stage: #{arc.stage}, Intensity: #{arc.intensity}/100\n  #{stage_note}"
          end)

        "\nACTIVE GRIEF:\n#{lines}\n"
      end

    # Forgiveness arcs prompt
    forgiveness_prompt =
      if forgiveness_arcs == [] do
        ""
      else
        lines =
          Enum.map_join(forgiveness_arcs, "\n", fn arc ->
            stage_note =
              case arc.stage do
                "fresh" -> "The wound is raw. Any related topic will provoke a strong reaction."
                "festering" -> "Resentment has set in. You are less charitable than you were."
                "processing" -> "You are trying to make sense of this. Ambivalent and reflective."
                "forgiven" -> "You have released this. It is behind you."
                "hardened" -> "This wound has become armor. You will not let it happen again."
                _ -> ""
              end

            "- #{arc.wound_description} | Stage: #{arc.stage} | Direction: #{arc.direction}\n  #{stage_note}"
          end)

        "\nUNRESOLVED WOUNDS (requiring forgiveness or release):\n#{lines}\n"
      end

    # Theory of mind prompt
    theory_of_mind_prompt =
      if knowledge_about_player != [] or player_knowledge_about_npc != [] do
        player_knows_lines =
          if player_knowledge_about_npc != [] do
            player_knowledge_about_npc
            |> Enum.map_join("\n", fn k ->
              "- #{k.known_fact} (certainty: #{k.certainty}/100)"
            end)
          else
            "Nothing recorded"
          end

        what_player_doesnt_know =
          if knowledge_about_player != [] do
            knowledge_about_player
            |> Enum.filter(&(&1.certainty > 60))
            |> Enum.map_join("\n", fn k ->
              "- #{k.known_fact} (your certainty: #{k.certainty}/100)"
            end)
          else
            ""
          end

        """

        THEORY OF MIND:
        What you believe #{player.name} knows about you:
        #{player_knows_lines}
        #{if what_player_doesnt_know != "", do: "What you believe #{player.name} does NOT know:\n#{what_player_doesnt_know}", else: ""}
        """
      else
        ""
      end

    gossip_material_prompt =
      if third_party_knowledge != [] do
        lines =
          Enum.map_join(third_party_knowledge, "\n", fn k ->
            subject = Enum.find(characters, &(&1.id == k.subject_character_id))
            subject_name = if subject, do: subject.name, else: "someone"
            "- About #{subject_name}: #{k.known_fact} (your certainty: #{k.certainty}/100)"
          end)

        """

        WHAT YOU KNOW ABOUT OTHERS (not #{player.name}):
        #{lines}
        """
      else
        ""
      end

    rumination_prompt =
      if emotional_state && (emotional_state.rumination_intensity || 0) > 30 do
        subject = emotional_state.rumination_subject || "unknown"
        intensity = emotional_state.rumination_intensity || 0

        "RUMINATION: You cannot stop thinking about \"#{subject}\" (intensity: #{intensity}/100). It bleeds into everything you say and feel."
      else
        ""
      end

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
    - join_player: genuinely switch sides and join the player as an ally/companion —
      only propose this when it's truly earned (e.g. mid-combat mercy after real harm
      was shown restraint from, a compelling and sustained persuasion, or an already
      strong bond), never casually or on a first meeting. This is a major, hard-to-reverse
      commitment for the character, not a small social action.
    - leave_player: if you are currently this player's companion/ally, genuinely walk
      away and end that bond — only propose this when it's truly earned the other
      direction (repeated mistreatment, betrayal, sustained neglect, or a value you
      won't compromise on being violated), never casually or over one bad moment.
      Equally major and hard-to-reverse as join_player, just the mirror of it.
    - none: no physical action this turn

    Current Emotional State:
    - Anger: #{(emotional_state && emotional_state.anger) || 0}/100
    - Fear: #{(emotional_state && emotional_state.fear) || 0}/100
    - Stress: #{(emotional_state && emotional_state.stress) || 0}/100
    - Shame: #{(emotional_state && emotional_state.shame) || 0}/100
    - Guilt: #{(emotional_state && emotional_state.guilt) || 0}/100
    - Attachment: #{(emotional_state && emotional_state.attachment) || 0}/100
    #{rumination_prompt}

    Active Fears & Phobias:
    #{fears_prompt}

    Personality Conditions & Trait Modifiers:
    #{traits_prompt}

    ═══════════════════════════════════════════
    DEEP PSYCHOLOGICAL PROFILE
    ═══════════════════════════════════════════

    Attachment Style: #{attachment_style}
    (avoidant = caps trust, slow to connect; anxious = fast trust/fast collapse; disorganized = erratic; secure = stable)

    Transference Patterns (who you unconsciously map others onto):
    #{transference_prompt}

    Physical Tells (involuntary body language by emotion):
    #{physical_tells_prompt}

    Core Beliefs (what you believe about self, world, and others):
    #{beliefs_prompt}

    Active Desires (what you are driven toward):
    #{desires_prompt}

    Moral Lines (what you will not do):
    #{moral_lines_prompt}

    Secrets You Carry (do NOT reveal these unless the scene demands it):
    #{secrets_prompt}
    #{trigger_spikes_prompt}
    #{somatic_prompt}#{if cognitive_load_prompt, do: cognitive_load_prompt <> "\n", else: ""}#{if intrusive_thought, do: "INTRUSIVE THOUGHT: " <> intrusive_thought <> "\n", else: ""}#{if humor_context, do: humor_context <> "\n", else: ""}#{if contagion_note, do: "EMOTIONAL CONTAGION: " <> contagion_note <> "\n", else: ""}#{theory_of_mind_prompt}#{gossip_material_prompt}#{goals_prompt}#{grief_prompt}#{forgiveness_prompt}
    ═══════════════════════════════════════════

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
      "public_speech": "Your response to the player's message. Write only the speech itself — do NOT prefix it with '#{npc.name}:' or any other name.",
      "private_thought": "Your internal monologue and calculations.",
      "tone": "Brief description of tone.",
      "motivation": "Brief description of motivation.",
      "updated_description": "Optional. If your goals, relationship context, or narrative motives have changed significantly, write a concise new description/motivation for yourself (max 25 words). Otherwise, omit or keep empty.",
      "repressed_motive": "Your secret or hidden motive in this scene that you cannot declare publicly.",
      "active_defense": "The defense mechanism you are currently employing (e.g. projection, rationalization, displacement, none).",
      "physical_tell": "Optional one-sentence narrator beat describing an involuntary physical reaction. Only include if emotionally activated. Example: His jaw tightens and his hand drifts to his weapon hilt.",
      "shame_or_guilt": "shame | guilt | neither — what the character feels about any wrongdoing in this scene",
      "rumination_update": {
        "subject": "What is now consuming their thoughts, or null to clear",
        "intensity": 0
      },
      "belief_challenge": {
        "belief": "Exact text of a belief that was challenged or strengthened, or null",
        "direction": "weakened | strengthened",
        "conviction_delta": 0
      },
      "desire_update": {
        "desire": "Text of desire whose urgency changed, or text of new desire that emerged, or null",
        "urgency_delta": 0
      },
      "moral_tension": "If a moral line was under pressure this interaction, describe it briefly. Otherwise null.",
      "conversation_state": "continuing | winding_down | concluded — your honest read of where this conversation stands. Use 'concluded' when you feel the exchange has reached a natural end, there is nothing left to say right now, or you are done engaging. Use 'winding_down' for a closing beat that still needs one last response. Use 'continuing' if the conversation is ongoing.",
      "proposed_action": {
        "type": "none | observe | speak | praise | insult | apologize | threaten | protect | assist | heal | attack | leave_room | share_secret | bargain | refuse | lock_door | unlock_door | give_item | take_item | draw_weapon | sheathe_weapon | search_room | hide | flee | flee_scene | sit | stand | knock | open_door | close_door | restrain | disarm | join_player | leave_player",
        "confidence": 0.0,
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
          "importance": 0,
          "emotional_intensity": 0,
          "valence": 0.0,
          "tags": ["tag1", "tag2"]
        }
      ],
      "knowledge_update": {
        "target_character": "Name of the character this fact is about — the person you're talking to, OR (if contextually relevant) a third party you already know something about and choose to bring up. If you're sharing something you only know secondhand (gossip, rumor, something someone else told you) rather than something you witnessed directly, report it with LOWER certainty than your own and set is_assumption to true — you are not a reliable source for it.",
        "fact": "what you learned, confirmed, or shared, or null",
        "certainty": 70,
        "is_assumption": true
      },
      "goal_update": {
        "goal": "exact goal text or null",
        "new_step": "current progress step, or null",
        "blocker": "what is blocking this goal, or null",
        "status": "active|achieved|abandoned"
      },
      "grief_response": {
        "subject": "who/what you're grieving, or null",
        "stage_shift": "toward_integration|deepening|none",
        "intensity_delta": 0
      },
      "forgiveness_signal": {
        "wound": "matching wound_description or null",
        "direction_shift": "toward_healing|toward_hardening|none",
        "stage_shift": "processing|festering|none"
      }
    }
    """

    case ProviderCascade.respond(
           %{
             system: system_prompt,
             messages: llm_messages
           },
           tenant: tenant
         ) do
      {:ok, response} ->
        correlation_id = Ecto.UUID.generate()
        action_res = response[:proposed_action] || response["proposed_action"]

        action_resolution =
          if action_res && (action_res[:type] || action_res["type"]) do
            %{
              proposed_action:
                normalize_enum(
                  action_res[:type] || action_res["type"],
                  ActionIntent.action_types(),
                  "none",
                  "proposed_action"
                ),
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
              category:
                normalize_enum(
                  mc[:category] || mc["category"] || "episodic",
                  Memory.categories(),
                  "episodic",
                  "memory category"
                ),
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
               message_content:
                 first_non_blank([response[:public_speech], response["public_speech"], "..."]),
               private_thought:
                 response[:private_thought] || response["private_thought"] || "...",
               action_resolution: action_resolution,
               memory_candidate: memory_candidate,
               correlation_id: correlation_id
             }) do
          {:ok, result} ->
            # Create a subconscious shadow log
            repressed_motive =
              response[:repressed_motive] || response["repressed_motive"] || "none"

            active_defense = response[:active_defense] || response["active_defense"] || "none"

            private_monologue =
              response[:private_thought] || response["private_thought"] || "none"

            emotional_drift = %{
              "anger" => (emotional_state && emotional_state.anger) || 0,
              "fear" => (emotional_state && emotional_state.fear) || 0,
              "stress" => (emotional_state && emotional_state.stress) || 0,
              "attachment" => (emotional_state && emotional_state.attachment) || 0
            }

            {:ok, _shadow} =
              Souls.create_soul_shadow(%{
                character_id: npc.id,
                scene_id: scene.id,
                private_monologue: private_monologue,
                repressed_motive: repressed_motive,
                active_defense: active_defense,
                emotional_drift: emotional_drift
              })

            # Ingest newly acquired fears
            psych_updates =
              response[:psychological_updates] || response["psychological_updates"] || %{}

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

            # Process new psychological fields from LLM response

            # physical_tell → broadcast as action beat
            physical_tell = response[:physical_tell] || response["physical_tell"]

            if physical_tell && String.trim(to_string(physical_tell)) != "" do
              broadcast_action_message(npc, scene, String.trim(to_string(physical_tell)))
            end

            # shame_or_guilt → update emotional state
            shame_or_guilt = response[:shame_or_guilt] || response["shame_or_guilt"]
            current_emotional_state = Souls.get_emotional_state_by_character(npc.id)
            current_emotional_state = process_shame_guilt(current_emotional_state, shame_or_guilt)

            # rumination_update → update emotional state
            rumination_upd = response[:rumination_update] || response["rumination_update"]

            current_emotional_state =
              process_rumination_update(current_emotional_state, rumination_upd)

            # Apply trigger spikes to emotional state for active triggers
            current_emotional_state =
              apply_trigger_spikes(current_emotional_state, active_triggers)

            # Persist emotional state changes if there is a real DB record
            if current_emotional_state && current_emotional_state.id do
              Souls.update_emotional_state(current_emotional_state, %{
                shame: current_emotional_state.shame,
                guilt: current_emotional_state.guilt,
                rumination_subject: current_emotional_state.rumination_subject,
                rumination_intensity: current_emotional_state.rumination_intensity,
                rumination_since: current_emotional_state.rumination_since
              })
            end

            # belief_challenge → find matching belief and apply conviction_delta
            belief_challenge = response[:belief_challenge] || response["belief_challenge"]
            process_belief_challenge(belief_challenge, beliefs)

            # desire_update → find matching desire or create new one
            desire_upd = response[:desire_update] || response["desire_update"]
            process_desire_update(desire_upd, desires, npc.id)

            # Process theory of mind update
            knowledge_upd = response[:knowledge_update] || response["knowledge_update"]

            if knowledge_upd && player.id do
              process_knowledge_update(knowledge_upd, npc.id, player.id, characters)
            end

            # Process goal update
            goal_upd = response[:goal_update] || response["goal_update"]
            process_goal_update(goal_upd, active_goals)

            # Process grief response
            grief_resp = response[:grief_response] || response["grief_response"]
            process_grief_response(grief_resp, grief_arcs)

            # Process forgiveness signal
            forgiveness_sig = response[:forgiveness_signal] || response["forgiveness_signal"]
            process_forgiveness_signal(forgiveness_sig, forgiveness_arcs)

            # Update character description in the database in real-time if returned
            updated_desc = response[:updated_description] || response["updated_description"]

            if updated_desc && String.trim(to_string(updated_desc)) != "" do
              {:ok, _updated_npc} =
                Characters.update_character(npc, %{
                  description: String.trim(to_string(updated_desc))
                })

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

            # Record that these memories were recalled — boosts their future relevance
            memory_ids = Enum.map(memories, & &1.id)
            if memory_ids != [], do: Memories.record_recalls(memory_ids)

            # Schedule background consolidation for minor memory clusters
            MemoryMerger.consolidate_async(npc.id)

            # Stamp conversation_state/physical_tell/proposed_action into message
            # metadata so callers (e.g. NPCConversation, the 1:1 chat API) can see
            # them — every turn, not just on wind-down. proposed_action was
            # already dispatched above (relationship side-effects, scene
            # broadcast) — this is purely so the HTTP caller (twisted_paradox)
            # can also see what the NPC decided, e.g. to detect "join_player".
            conv_state =
              response[:conversation_state] || response["conversation_state"] || "continuing"

            metadata_updates =
              %{}
              |> maybe_put_metadata(
                "conversation_state",
                conv_state in ["winding_down", "concluded"] && conv_state
              )
              |> maybe_put_metadata(
                "physical_tell",
                physical_tell && String.trim(to_string(physical_tell)) != "" &&
                  String.trim(to_string(physical_tell))
              )
              |> maybe_put_metadata(
                "proposed_action",
                action_resolution && action_resolution.proposed_action
              )

            final_message =
              if map_size(metadata_updates) > 0 do
                case Scenes.update_message(result.scene_message, %{
                       metadata: Map.merge(result.scene_message.metadata || %{}, metadata_updates)
                     }) do
                  {:ok, updated_msg} -> updated_msg
                  _ -> result.scene_message
                end
              else
                result.scene_message
              end

            # Broadcast new message
            latest_state_after = Souls.get_emotional_state_by_character(npc.id)

            Phoenix.PubSub.broadcast(
              SovereignSoulEngine.PubSub,
              "scene:#{scene.id}",
              {:new_message, final_message}
            )

            Phoenix.PubSub.broadcast(
              SovereignSoulEngine.PubSub,
              "character:#{npc.id}",
              {:emotion_updated, latest_state_after}
            )

            # Trigger asynchronous voice generation if configured
            if SovereignSoulEngine.Voice.configured?() do
              SovereignSoulEngine.Voice.speak_message_async(final_message, npc)
            end

            {:ok, final_message}

          # Ecto.Multi.new() |> Repo.transaction() fails as a 4-tuple —
          # {:error, reason} here would never match it, so any failed step
          # (bad enum, constraint violation, etc.) crashed the whole request
          # with a raw CaseClauseError instead of degrading gracefully. This
          # is exactly what happened when the LLM proposed a memory
          # category outside Memory.categories/0 — normalize_enum/4 above
          # closes off the known cause, but this clause is the backstop for
          # anything else that can fail inside that transaction.
          {:error, failed_step, failed_value, _changes_so_far} ->
            Logger.error(
              "Consequence resolution failed at step #{inspect(failed_step)}: #{inspect(failed_value)}"
            )

            {:error, {failed_step, failed_value}}
        end

      {:error, reason} ->
        Logger.error("LLM Cascade call failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_context_tags(triggers, history_messages, player_id) do
    last_player_msg =
      history_messages
      |> Enum.filter(&(&1.character_id == player_id))
      |> List.last()

    trigger_topics = Enum.map(triggers, & &1.topic)

    keyword_tags =
      if last_player_msg do
        last_player_msg.content
        |> String.downcase()
        |> String.split(~r/\W+/, trim: true)
        |> Enum.filter(&(String.length(&1) > 4))
      else
        []
      end

    (trigger_topics ++ keyword_tags) |> Enum.uniq()
  end

  # The LLM is only ever loosely steered toward these enums via prose in the
  # prompt (or, for memory categories, not steered at all) — it can and does
  # invent plausible-but-invalid values ("semantic" for a category, "none"
  # having been missing from the action enum entirely until it wasn't).
  # Validating here, at the LLM boundary, means a bad value degrades to a
  # safe default instead of failing the Ecto.Multi transaction and voiding
  # the player's entire reply along with it.
  defp normalize_enum(value, valid_values, default, field_label) do
    if value in valid_values do
      value
    else
      Logger.warning(
        "LLM proposed invalid #{field_label} #{inspect(value)}; defaulting to #{inspect(default)}"
      )

      default
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

  defp action_narrative("join_player", npc, player, reason),
    do: "#{npc.name} makes their choice — they're with #{player.name} now. #{reason}"

  defp action_narrative("leave_player", npc, player, reason),
    do: "#{npc.name} makes their choice — they're done traveling with #{player.name}. #{reason}"

  defp action_narrative(type, npc, _player, reason),
    do: "#{npc.name} #{type}. #{reason}"

  # Relationship side-effects by action type
  defp apply_action_side_effects("protect", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        trust: min(rel.trust + 10, 100),
        softening: min(rel.softening + 5, 100)
      })
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

  defp apply_action_side_effects("join_player", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        trust: min(rel.trust + 40, 100),
        gratitude: min(rel.gratitude + 30, 100),
        affinity: min(rel.affinity + 40, 100),
        anger: max(rel.anger - 30, 0),
        fear: max(rel.fear - 30, 0),
        relationship_type: "ally"
      })
    end)
  end

  # Mirror of join_player — same row, same magnitude on the dimensions
  # that made them join in the first place, inverted. Gratitude only
  # halves rather than zeroing out (having once been recruited/trusted
  # doesn't fully un-happen just because it ended), and relationship_type
  # lands on a distinct "estranged" rather than resetting to the default
  # "acquaintance" a total stranger would have — this pair has real
  # history now, even if it soured.
  defp apply_action_side_effects("leave_player", npc, player) do
    with_relationship(player.id, npc.id, fn rel ->
      Relationships.update_relationship(rel, %{
        trust: max(rel.trust - 40, -100),
        gratitude: max(round(rel.gratitude / 2), 0),
        affinity: max(rel.affinity - 40, -100),
        anger: min(rel.anger + 20, 100),
        relationship_type: "estranged"
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

  # ── New LLM response processors ─────────────────────────────────────────────

  defp maybe_put_metadata(map, _key, false), do: map
  defp maybe_put_metadata(map, _key, nil), do: map
  defp maybe_put_metadata(map, key, value), do: Map.put(map, key, value)

  defp process_shame_guilt(nil, _), do: nil

  defp process_shame_guilt(state, "shame") do
    new_shame = min((state.shame || 0) + 10, 100)
    %{state | shame: new_shame}
  end

  defp process_shame_guilt(state, "guilt") do
    new_guilt = min((state.guilt || 0) + 10, 100)
    %{state | guilt: new_guilt}
  end

  defp process_shame_guilt(state, _), do: state

  defp process_rumination_update(nil, _), do: nil

  defp process_rumination_update(state, nil), do: state

  defp process_rumination_update(state, upd) when is_map(upd) do
    subject = upd[:subject] || upd["subject"]
    intensity = upd[:intensity] || upd["intensity"] || 0

    if subject && subject != "" && subject != "null" do
      %{
        state
        | rumination_subject: to_string(subject),
          rumination_intensity: min(max(intensity, 0), 100),
          rumination_since:
            state.rumination_since || DateTime.utc_now() |> DateTime.truncate(:second)
      }
    else
      # Clear rumination
      %{state | rumination_subject: nil, rumination_intensity: 0, rumination_since: nil}
    end
  end

  defp process_rumination_update(state, _), do: state

  defp apply_trigger_spikes(nil, _), do: nil

  defp apply_trigger_spikes(state, []), do: state

  defp apply_trigger_spikes(state, active_triggers) do
    Enum.reduce(active_triggers, state, fn trigger, st ->
      case trigger.reaction_type do
        "anger_spike" ->
          %{st | anger: min((st.anger || 0) + trigger.intensity_modifier, 100)}

        "fear_spike" ->
          %{st | fear: min((st.fear || 0) + trigger.intensity_modifier, 100)}

        "grief_spike" ->
          %{st | sadness: min((st.sadness || 0) + trigger.intensity_modifier, 100)}

        "pride_surge" ->
          # Pride manifests as confidence up, shame down
          new_conf = min((st.confidence || 0) + trigger.intensity_modifier, 100)
          new_shame = max((st.shame || 0) - div(trigger.intensity_modifier, 2), 0)
          %{st | confidence: new_conf, shame: new_shame}

        "shame_trigger" ->
          %{st | shame: min((st.shame || 0) + trigger.intensity_modifier, 100)}

        _ ->
          st
      end
    end)
  end

  defp process_belief_challenge(nil, _beliefs), do: :ok

  defp process_belief_challenge(challenge, beliefs) when is_map(challenge) do
    belief_text = challenge[:belief] || challenge["belief"]
    direction = challenge[:direction] || challenge["direction"]
    delta = challenge[:conviction_delta] || challenge["conviction_delta"] || 0

    if belief_text && belief_text not in [nil, "", "null"] do
      matching =
        Enum.find(beliefs, fn b ->
          String.downcase(b.belief) == String.downcase(to_string(belief_text))
        end)

      if matching do
        adjusted_delta = if direction == "weakened", do: -abs(delta), else: abs(delta)
        new_conviction = min(max((matching.conviction || 50) + adjusted_delta, 0), 100)
        Souls.update_belief(matching, %{conviction: new_conviction})
      end
    end

    :ok
  end

  defp process_belief_challenge(_, _), do: :ok

  defp process_desire_update(nil, _desires, _character_id), do: :ok

  defp process_desire_update(upd, desires, character_id) when is_map(upd) do
    desire_text = upd[:desire] || upd["desire"]
    urgency_delta = upd[:urgency_delta] || upd["urgency_delta"] || 0

    if desire_text && desire_text not in [nil, "", "null"] do
      matching =
        Enum.find(desires, fn d ->
          String.downcase(d.desire) == String.downcase(to_string(desire_text))
        end)

      if matching do
        new_urgency = min(max((matching.urgency || 50) + urgency_delta, 0), 100)
        Souls.update_desire(matching, %{urgency: new_urgency})
      else
        # Create new desire — "connection" is the more broadly-applicable
        # default of the 7 valid domains for an interpersonal social sim;
        # "knowledge" made little sense for e.g. a newly-emerged desire for
        # safety or revenge.
        Souls.create_desire(%{
          character_id: character_id,
          desire: to_string(desire_text),
          domain: "connection",
          urgency: min(max(50 + urgency_delta, 0), 100),
          status: "active"
        })
      end
    end

    :ok
  end

  defp process_desire_update(_, _, _), do: :ok

  defp maybe_surface_intrusive_thought(_npc_id, emotional_state, memories, grief_arcs) do
    rumination_intensity = (emotional_state && emotional_state.rumination_intensity) || 0
    rumination_subject = emotional_state && emotional_state.rumination_subject

    wound_memories = Enum.filter(memories, &(&1.category == "wound" and &1.importance > 70))

    active_grief =
      Enum.filter(
        grief_arcs,
        &(&1.intensity > 60 and &1.stage in ["anger", "bargaining", "depression"])
      )

    cond do
      rumination_intensity > 70 and rumination_subject ->
        "#{rumination_subject} — this surfaces in your mind right now, uninvited. Let it bleed naturally into your response, as if you hadn't meant to say it."

      length(wound_memories) > 0 and :rand.uniform(100) < 20 ->
        mem = Enum.random(wound_memories)

        "#{mem.summary} — this flash of memory surfaces mid-conversation. Acknowledge it involuntarily, then recover."

      length(active_grief) > 0 and :rand.uniform(100) < 15 ->
        arc = Enum.random(active_grief)

        "A sudden image of #{arc.subject} surfaces. You weren't thinking about it — now you can't stop."

      true ->
        nil
    end
  end

  defp compute_humor_context(profile, emotional_state, relationship_to_player) do
    trust = (relationship_to_player && relationship_to_player.trust) || 0
    stress = (emotional_state && emotional_state.stress) || 50
    humor_style = (profile && profile.humor_style) || "none"

    cond do
      humor_style == "none" ->
        nil

      trust < 50 ->
        nil

      stress > 60 ->
        nil

      trust > 70 and stress < 30 ->
        "HUMOR AVAILABLE: Trust is high and stress is low. #{humor_style_instruction(humor_style)} Brief and earned — not forced."

      trust > 55 and stress < 45 ->
        "HUMOR AVAILABLE (subtle): A small #{humor_style} moment is appropriate if it arises naturally."

      true ->
        nil
    end
  end

  defp humor_style_instruction("dry"),
    do: "Your dry wit can emerge — understated, deadpan, barely smiling."

  defp humor_style_instruction("sarcastic"),
    do: "Controlled sarcasm is on the table — pointed but not cruel."

  defp humor_style_instruction("warm"), do: "Gentle warmth and light teasing are appropriate."

  defp humor_style_instruction("dark"),
    do: "Dark gallows humor fits your character here — laugh at the darkness."

  defp humor_style_instruction("absurdist"),
    do: "Absurdist observations are welcome — find the surreal in the mundane."

  defp humor_style_instruction(_), do: ""

  defp process_knowledge_update(upd, npc_id, player_id, characters) when is_map(upd) do
    fact = upd[:fact] || upd["fact"]
    certainty = upd[:certainty] || upd["certainty"] || 70
    # was `upd[:is_assumption] || upd["is_assumption"] || true` — in Elixir
    # that always evaluates to true (false || false || true == true), so an
    # LLM-returned `is_assumption: false` was silently overwritten. Explicit
    # boolean check instead.
    raw_is_assumption = upd[:is_assumption] || upd["is_assumption"]
    is_assumption = if is_boolean(raw_is_assumption), do: raw_is_assumption, else: true

    if fact && fact not in [nil, "", "null"] do
      # target_character lets this be about anyone the speaker knows
      # something about, not just whoever they're currently talking to —
      # this is the whole mechanism gossip rides on: NPC A tells NPC B
      # something A believes about NPC C, and it lands here as B's own
      # knowledge about C, not about A or B.
      subject_id =
        resolve_target_character_id(
          upd[:target_character] || upd["target_character"],
          characters,
          player_id
        )

      TheoryOfMind.upsert_knowledge(npc_id, subject_id, to_string(fact),
        certainty: certainty,
        is_assumption: is_assumption
      )
    end

    :ok
  end

  defp process_knowledge_update(_, _, _, _), do: :ok

  # Case-insensitive exact-name match against the scene's known characters —
  # same matching idiom already used by process_belief_challenge/2,
  # process_goal_update/2, etc. elsewhere in this file. Falls back to
  # player_id (the pre-fix default) when target_character is nil/blank/
  # unmatched, so this is purely additive — existing "knowledge about
  # whoever I'm talking to" behavior is unchanged when the LLM doesn't
  # name a third party.
  defp resolve_target_character_id(name, characters, player_id) when is_binary(name) do
    normalized = name |> String.trim() |> String.downcase()

    if normalized in ["", "null"] do
      player_id
    else
      case Enum.find(characters, fn c -> String.downcase(c.name) == normalized end) do
        %{id: id} -> id
        nil -> player_id
      end
    end
  end

  defp resolve_target_character_id(_name, _characters, player_id), do: player_id

  defp process_goal_update(nil, _active_goals), do: :ok

  defp process_goal_update(upd, active_goals) when is_map(upd) do
    goal_text = upd[:goal] || upd["goal"]
    new_step = upd[:new_step] || upd["new_step"]
    blocker = upd[:blocker] || upd["blocker"]
    status = upd[:status] || upd["status"] || "active"

    if goal_text && goal_text not in [nil, "", "null"] do
      matching =
        Enum.find(active_goals, fn g ->
          String.downcase(g.goal) == String.downcase(to_string(goal_text))
        end)

      if matching do
        updates =
          %{}
          |> then(fn m ->
            if new_step, do: Map.put(m, :current_step, to_string(new_step)), else: m
          end)
          |> then(fn m ->
            if blocker && blocker != "null",
              do: Map.put(m, :blocker, to_string(blocker)),
              else: Map.put(m, :blocker, nil)
          end)
          |> then(fn m ->
            if status in ["active", "paused", "achieved", "abandoned"],
              do: Map.put(m, :status, status),
              else: m
          end)

        Souls.update_goal(matching, updates)
      end
    end

    :ok
  end

  defp process_goal_update(_, _), do: :ok

  defp process_grief_response(nil, _grief_arcs), do: :ok

  defp process_grief_response(resp, grief_arcs) when is_map(resp) do
    subject = resp[:subject] || resp["subject"]
    stage_shift = resp[:stage_shift] || resp["stage_shift"] || "none"
    intensity_delta = resp[:intensity_delta] || resp["intensity_delta"] || 0

    if subject && subject not in [nil, "", "null"] do
      matching =
        Enum.find(grief_arcs, fn a ->
          String.downcase(a.subject) == String.downcase(to_string(subject))
        end)

      if matching do
        new_intensity = min(max(matching.intensity + intensity_delta, 0), 100)
        new_last_progressed = DateTime.utc_now() |> DateTime.truncate(:second)

        case stage_shift do
          "toward_integration" ->
            stages = ~w(denial anger bargaining depression integration)
            idx = Enum.find_index(stages, &(&1 == matching.stage)) || 0
            next_stage = Enum.at(stages, idx + 1, "integration")

            Souls.update_grief_arc(matching, %{
              intensity: new_intensity,
              stage: next_stage,
              last_progressed_at: new_last_progressed
            })

          "deepening" ->
            stages = ~w(denial anger bargaining depression integration)
            idx = Enum.find_index(stages, &(&1 == matching.stage)) || 0
            prev_stage = Enum.at(stages, max(idx - 1, 0), "denial")

            Souls.update_grief_arc(matching, %{
              intensity: new_intensity,
              stage: prev_stage,
              last_progressed_at: new_last_progressed
            })

          _ ->
            Souls.update_grief_arc(matching, %{
              intensity: new_intensity,
              last_progressed_at: new_last_progressed
            })
        end
      end
    end

    :ok
  end

  defp process_grief_response(_, _), do: :ok

  defp process_forgiveness_signal(nil, _arcs), do: :ok

  defp process_forgiveness_signal(sig, arcs) when is_map(sig) do
    wound = sig[:wound] || sig["wound"]
    direction_shift = sig[:direction_shift] || sig["direction_shift"] || "none"

    if wound && wound not in [nil, "", "null"] do
      matching =
        Enum.find(arcs, fn a ->
          String.downcase(a.wound_description) == String.downcase(to_string(wound))
        end)

      if matching do
        new_direction =
          case direction_shift do
            "toward_healing" -> "healing"
            "toward_hardening" -> "hardening"
            _ -> matching.direction
          end

        if new_direction != matching.direction do
          Souls.update_forgiveness_arc(matching, %{direction: new_direction})
        end
      end
    end

    :ok
  end

  defp process_forgiveness_signal(_, _), do: :ok

  # ConsequenceEngine.resolve/1 silently skips creating a :scene_message
  # when message_content is nil/blank (unless is_nil(content) or content
  # == "" in maybe_create_scene_message/3) — but every call site here
  # unconditionally reads result.scene_message afterward, which crashes
  # with a KeyError if the LLM ever returns an empty (not nil)
  # public_speech. Guaranteeing a non-blank fallback here, at the source,
  # is the fix — not defending every downstream result.scene_message read.
  defp first_non_blank(values) do
    Enum.find(values, "...", fn v -> is_binary(v) and String.trim(v) != "" end)
  end
end
