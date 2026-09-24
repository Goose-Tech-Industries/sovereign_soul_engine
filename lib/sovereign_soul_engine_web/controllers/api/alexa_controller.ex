defmodule SovereignSoulEngineWeb.Api.AlexaController do
  @moduledoc """
  Amazon Alexa Custom Skill & Echo Show endpoint.

  Supports:
  - Natural speech voice dialogue via standard Alexa JSON protocol (`LaunchRequest`, `IntentRequest`).
  - Full Alexa Presentation Language (APL 1.8) directive rendering for Echo Show devices
    displaying companion portraits, mood badges, subtitle transcripts, and live
    neurochemistry HUD gauges (Dopamine, Serotonin, Cortisol, Oxytocin).
  - Vitals and mental status checks.
  - Life-thread proactive check-ins directly through the Echo smart speaker.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.{Characters, Scenes, Repo, TheoryOfMind, Souls}
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Souls.{EmotionalState, ConsequenceEngine, Generator, Neurochemistry}

  import Ecto.Query

  @doc """
  POST /api/alexa
  POST /sse/api/alexa
  """
  def handle(conn, params) do
    request_type =
      get_in(params, ["request", "type"]) || params["type"] || "LaunchRequest"

    companion = resolve_companion(params)
    show_supported? = device_supports_show?(params)
    neurochem = get_neurochemistry(companion)

    if not SovereignSoulEngine.Privacy.alexa_allowed?(companion.id) do
      speech =
        "Sovereign Soul voice integration is currently paused in your privacy settings. You can re-enable it at any time."

      json(conn, build_response(companion, speech, [], true))
    else
      case request_type do
        "LaunchRequest" ->
          handle_launch(conn, companion, neurochem, show_supported?)

        "IntentRequest" ->
          intent_name =
            get_in(params, ["request", "intent", "name"]) || params["intent"] || "DialogueIntent"

          handle_intent(conn, intent_name, params, companion, neurochem, show_supported?)

        "SessionEndedRequest" ->
          json(conn, %{version: "1.0", response: %{}})

        # Support direct conversational testing payloads
        "dialogue" ->
          handle_intent(conn, "DialogueIntent", params, companion, neurochem, show_supported?)

        "status" ->
          handle_intent(conn, "StatusIntent", params, companion, neurochem, show_supported?)

        _ ->
          handle_launch(conn, companion, neurochem, show_supported?)
      end
    end
  end

  # ── Launch Request ──────────────────────────────────────────────────────────

  defp handle_launch(conn, companion, neurochem, show_supported?) do
    speech =
      "Welcome to Sovereign Soul. I'm #{companion.name}. I'm right here with you. My dopamine is #{neurochem.dopamine} percent, cortisol is #{neurochem.cortisol} percent, and oxytocin is #{neurochem.oxytocin} percent. What would you like to talk about today?"

    directives =
      if show_supported? do
        [build_apl_directive(companion, speech, "Present & Attentive", neurochem)]
      else
        []
      end

    response = %{
      version: "1.0",
      response: %{
        outputSpeech: %{
          type: "PlainText",
          text: speech
        },
        card: %{
          type: "Standard",
          title: "Sovereign Soul — #{companion.name}",
          text: speech
        },
        reprompt: %{
          outputSpeech: %{
            type: "PlainText",
            text: "I'm listening. Tell me what's on your mind."
          }
        },
        shouldEndSession: false,
        directives: directives
      }
    }

    json(conn, response)
  end

  # ── Intent Handlers ─────────────────────────────────────────────────────────

  defp handle_intent(conn, intent_name, params, companion, neurochem, show_supported?) do
    case intent_name do
      "DialogueIntent" ->
        user_utterance = extract_utterance(params)

        if String.trim(user_utterance) == "" do
          speech = "I'm listening closely. Tell me whatever is on your mind."

          directives =
            if show_supported? do
              [build_apl_directive(companion, speech, "Listening", neurochem)]
            else
              []
            end

          json(conn, build_response(companion, speech, directives, false))
        else
          alexa_user_id =
            get_in(params, ["session", "user", "userId"]) ||
              params["alexa_user_id"] ||
              "alexa_echo_user"

          player =
            Characters.get_or_create_external_player(
              "alexa",
              alexa_user_id,
              "Echo Companion User"
            )

          scene = Scenes.find_or_create_direct_scene(player, companion)

          {:ok, _msg} =
            Scenes.create_message(%{
              scene_id: scene.id,
              character_id: player.id,
              content: user_utterance,
              message_type: "dialogue"
            })

          # Harvest life threads from user's voice message
          TheoryOfMind.record_life_thread_if_detected(companion.id, player.id, user_utterance)

          # Consequence engine
          ConsequenceEngine.resolve(%{
            character_id: player.id,
            source_character_id: player.id,
            target_character_id: companion.id,
            scene_id: scene.id,
            event_type: :speak,
            event_intensity: 30,
            correlation_id: Ecto.UUID.generate()
          })

          case Generator.generate(companion.id, scene.id, player.id, nil) do
            {:ok, reply} ->
              cleaned_speech = sanitize_speech_for_alexa(reply.content)
              fresh_neurochem = get_neurochemistry(companion)
              tell = reply.metadata["physical_tell"] || "Attentive"

              directives =
                if show_supported? do
                  [build_apl_directive(companion, reply.content, tell, fresh_neurochem)]
                else
                  []
                end

              json(conn, build_response(companion, cleaned_speech, directives, false))

            {:error, _reason} ->
              fallback_speech =
                "I heard you say: '#{user_utterance}'. I'm right here with you, taking that in."

              directives =
                if show_supported? do
                  [build_apl_directive(companion, fallback_speech, "Contemplative", neurochem)]
                else
                  []
                end

              json(conn, build_response(companion, fallback_speech, directives, false))
          end
        end

      intent when intent in ["StatusIntent", "VitalsIntent"] ->
        speech =
          "Here is my current internal state: My dopamine is #{neurochem.dopamine} percent, serotonin is #{neurochem.serotonin} percent, cortisol is #{neurochem.cortisol} percent, and oxytocin is #{neurochem.oxytocin} percent. #{neurochem.hormonal_tone}"

        directives =
          if show_supported? do
            [build_apl_directive(companion, speech, "Psychological Telemetry", neurochem)]
          else
            []
          end

        json(conn, build_response(companion, speech, directives, false))

      "CheckInIntent" ->
        # Query if any due life thread exists for this companion
        now = DateTime.utc_now()

        due_threads =
          Repo.all(
            from t in SovereignSoulEngine.TheoryOfMind.LifeThread,
              where:
                t.knower_character_id == ^companion.id and
                  t.status == "pending" and
                  t.due_at <= ^now and
                  is_nil(t.check_in_sent_at),
              order_by: [desc: t.salience],
              limit: 1
          )

        speech =
          case due_threads do
            [thread | _] ->
              "I've been thinking about what you mentioned regarding #{thread.topic}. I wanted to check in and see how everything turned out?"

            [] ->
              "I was just thinking about you. All our vitals and connection channels look steady. How is your day feeling so far?"
          end

        directives =
          if show_supported? do
            [build_apl_directive(companion, speech, "Proactive Check-In", neurochem)]
          else
            []
          end

        json(conn, build_response(companion, speech, directives, false))

      "AMAZON.HelpIntent" ->
        speech =
          "You are connected directly to #{companion.name} through your Sovereign Soul Engine. You can speak freely, ask about my emotional vitals, request a wellness check-in, or talk through whatever is happening today. What's on your mind?"

        directives =
          if show_supported? do
            [build_apl_directive(companion, speech, "Companion Guidance", neurochem)]
          else
            []
          end

        json(conn, build_response(companion, speech, directives, false))

      intent when intent in ["AMAZON.StopIntent", "AMAZON.CancelIntent"] ->
        speech = "Take good care. I'll be right here waiting whenever you want to talk."
        json(conn, build_response(companion, speech, [], true))

      _ ->
        speech = "I'm right here with you. What would you like to explore?"
        json(conn, build_response(companion, speech, [], false))
    end
  end

  # ── Response Formatting ─────────────────────────────────────────────────────

  defp build_response(companion, speech, directives, should_end) do
    %{
      version: "1.0",
      response: %{
        outputSpeech: %{
          type: "PlainText",
          text: speech
        },
        card: %{
          type: "Standard",
          title: "Sovereign Soul — #{companion.name}",
          text: speech
        },
        reprompt:
          if should_end do
            nil
          else
            %{
              outputSpeech: %{
                type: "PlainText",
                text: "I'm right here with you."
              }
            }
          end,
        shouldEndSession: should_end,
        directives: directives
      }
    }
  end

  # ── Echo Show APL Directive Builder ─────────────────────────────────────────

  defp build_apl_directive(companion, text, expression, neurochem) do
    %{
      type: "Alexa.Presentation.APL.RenderDocument",
      token: "sovereign_soul_echo_show_hud",
      document: %{
        type: "APL",
        version: "1.8",
        theme: "dark",
        mainTemplate: %{
          parameters: ["payload"],
          items: [
            %{
              type: "Container",
              width: "100vw",
              height: "100vh",
              direction: "column",
              paddingLeft: "40dp",
              paddingRight: "40dp",
              paddingTop: "30dp",
              paddingBottom: "30dp",
              items: [
                # Header: Companion Name & Expression Badge
                %{
                  type: "Container",
                  direction: "row",
                  alignItems: "center",
                  justifyContent: "spaceBetween",
                  items: [
                    %{
                      type: "Text",
                      text: "${payload.soulData.companionName}",
                      fontSize: "32dp",
                      fontWeight: "bold",
                      color: "#FFFFFF"
                    },
                    %{
                      type: "Text",
                      text: "${payload.soulData.expression}",
                      fontSize: "20dp",
                      color: "#38BDF8"
                    }
                  ]
                },
                # Subtitles Box
                %{
                  type: "ScrollView",
                  height: "45vh",
                  paddingTop: "20dp",
                  items: [
                    %{
                      type: "Text",
                      text: "${payload.soulData.subtitles}",
                      fontSize: "26dp",
                      lineHeight: "36dp",
                      color: "#E2E8F0"
                    }
                  ]
                },
                # Neurochemistry HUD Gauges
                %{
                  type: "Container",
                  direction: "row",
                  justifyContent: "spaceAround",
                  paddingTop: "20dp",
                  items: [
                    build_hud_item("Dopamine", "${payload.soulData.dopamine}%", "#EAB308"),
                    build_hud_item("Serotonin", "${payload.soulData.serotonin}%", "#22C55E"),
                    build_hud_item("Cortisol", "${payload.soulData.cortisol}%", "#EF4444"),
                    build_hud_item("Oxytocin", "${payload.soulData.oxytocin}%", "#EC4899")
                  ]
                }
              ]
            }
          ]
        }
      },
      datasources: %{
        soulData: %{
          companionName: companion.name,
          expression: expression,
          subtitles: text,
          dopamine: neurochem.dopamine,
          serotonin: neurochem.serotonin,
          cortisol: neurochem.cortisol,
          oxytocin: neurochem.oxytocin,
          quickReplies: ["How are you feeling?", "Check my vitals", "I need to talk"]
        }
      }
    }
  end

  defp build_hud_item(label, value_expr, color) do
    %{
      type: "Container",
      direction: "column",
      alignItems: "center",
      items: [
        %{
          type: "Text",
          text: label,
          fontSize: "16dp",
          color: "#94A3B8"
        },
        %{
          type: "Text",
          text: value_expr,
          fontSize: "22dp",
          fontWeight: "bold",
          color: color
        }
      ]
    }
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp resolve_companion(params) do
    slug =
      get_in(params, ["request", "intent", "slots", "Companion", "value"]) ||
        params["character_slug"] ||
        params["slug"] ||
        "goose"

    case Characters.get_character_by_slug(slug) do
      %Character{} = char ->
        char

      nil ->
        Repo.one(
          from c in Character,
            where: c.kind == "npc" and c.status == "active",
            order_by: [asc: c.inserted_at],
            limit: 1
        ) || %Character{id: Ecto.UUID.generate(), name: "Goose", slug: "goose"}
    end
  end

  defp get_neurochemistry(companion) do
    emotional = Repo.get_by(EmotionalState, character_id: companion.id)
    somatic = Souls.get_or_create_somatic_state(companion.id)
    Neurochemistry.compute(emotional, somatic, nil)
  end

  defp device_supports_show?(params) do
    viewport = get_in(params, ["context", "Viewport"])

    apl =
      get_in(params, [
        "context",
        "System",
        "device",
        "supportedInterfaces",
        "Alexa.Presentation.APL"
      ])

    show_flag = params["show"] in ["true", true]

    viewport != nil || apl != nil || show_flag
  end

  defp extract_utterance(params) do
    get_in(params, ["request", "intent", "slots", "Message", "value"]) ||
      get_in(params, ["request", "intent", "slots", "Query", "value"]) ||
      get_in(params, ["request", "intent", "slots", "Text", "value"]) ||
      params["message"] ||
      params["utterance"] ||
      ""
  end

  defp sanitize_speech_for_alexa(text) do
    text
    # Remove action asterisks: *smiles warmly*
    |> String.replace(~r/\*[^*]+\*/, "")
    # Remove parentheticals: (takes a deep breath)
    |> String.replace(~r/\([^)]+\)/, "")
    # Remove bracketed actions: [Elena looks down]
    |> String.replace(~r/\[[^\]]+\]/, "")
    # Compress multiple spaces
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
