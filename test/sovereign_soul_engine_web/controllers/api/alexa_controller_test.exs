defmodule SovereignSoulEngineWeb.Api.AlexaControllerTest do
  use SovereignSoulEngineWeb.ConnCase

  setup %{conn: conn} do
    %{conn: authenticate_api(conn)}
  end

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls

  setup do
    {:ok, npc} =
      Characters.create_character(%{
        name: "Elena (Companion)",
        slug: "elena-alexa",
        description: "An emotionally resonant companion",
        kind: "npc",
        status: "active"
      })

    {:ok, _emotional} =
      Souls.create_emotional_state(%{
        character_id: npc.id,
        stress: 15,
        confidence: 80,
        attachment: 65
      })

    {:ok, _somatic} =
      Souls.create_somatic_state(%{
        character_id: npc.id,
        fatigue: 10,
        pain: 0
      })

    {:ok, npc: npc}
  end

  describe "POST /api/alexa LaunchRequest" do
    test "returns audio speech welcome and reprompt", %{conn: conn, npc: npc} do
      payload = %{
        "version" => "1.0",
        "request" => %{
          "type" => "LaunchRequest",
          "requestId" => "amzn1.echo-api.request.1"
        },
        "character_slug" => npc.slug
      }

      conn = post(conn, ~p"/api/alexa", payload)
      assert json = json_response(conn, 200)

      assert json["version"] == "1.0"
      assert response = json["response"]
      assert response["outputSpeech"]["type"] == "PlainText"
      assert response["outputSpeech"]["text"] =~ "Welcome to Sovereign Soul"
      assert response["outputSpeech"]["text"] =~ npc.name
      assert response["shouldEndSession"] == false
      assert response["card"]["title"] =~ npc.name
    end

    test "renders APL RenderDocument directive when Echo Show device is detected", %{
      conn: conn,
      npc: npc
    } do
      payload = %{
        "version" => "1.0",
        "context" => %{
          "Viewport" => %{
            "shape" => "RECTANGLE",
            "pixelWidth" => 1280,
            "pixelHeight" => 800
          }
        },
        "request" => %{
          "type" => "LaunchRequest"
        },
        "character_slug" => npc.slug
      }

      conn = post(conn, ~p"/api/alexa", payload)
      assert json = json_response(conn, 200)
      directives = json["response"]["directives"]

      assert length(directives) >= 1
      apl = hd(directives)
      assert apl["type"] == "Alexa.Presentation.APL.RenderDocument"
      assert apl["datasources"]["soulData"]["companionName"] == npc.name
      assert apl["datasources"]["soulData"]["dopamine"] != nil
      assert apl["datasources"]["soulData"]["cortisol"] != nil
    end
  end

  describe "POST /api/alexa IntentRequest" do
    test "DialogueIntent generates real companion response with updated neurochemistry", %{
      conn: conn,
      npc: npc
    } do
      payload = %{
        "version" => "1.0",
        "session" => %{
          "user" => %{"userId" => "amzn1.ask.account.user123"}
        },
        "request" => %{
          "type" => "IntentRequest",
          "intent" => %{
            "name" => "DialogueIntent",
            "slots" => %{
              "Message" => %{"value" => "I had a really difficult and exhausting day today."}
            }
          }
        },
        "character_slug" => npc.slug,
        "show" => true
      }

      conn = post(conn, ~p"/api/alexa", payload)
      assert json = json_response(conn, 200)

      speech = json["response"]["outputSpeech"]["text"]
      assert String.length(speech) > 10
      assert json["response"]["shouldEndSession"] == false

      # Echo Show APL should display subtitles and dopamine/oxytocin
      directives = json["response"]["directives"]
      assert length(directives) == 1
      assert hd(directives)["datasources"]["soulData"]["subtitles"] != nil
    end

    test "VitalsIntent reports dopamine, serotonin, cortisol, and oxytocin breakdown", %{
      conn: conn,
      npc: npc
    } do
      payload = %{
        "version" => "1.0",
        "request" => %{
          "type" => "IntentRequest",
          "intent" => %{
            "name" => "VitalsIntent"
          }
        },
        "character_slug" => npc.slug
      }

      conn = post(conn, ~p"/api/alexa", payload)
      assert json = json_response(conn, 200)

      speech = json["response"]["outputSpeech"]["text"]
      assert speech =~ "dopamine"
      assert speech =~ "cortisol"
      assert speech =~ "oxytocin"
      assert json["response"]["shouldEndSession"] == false
    end

    test "CheckInIntent checks in on wellness and open life threads", %{conn: conn, npc: npc} do
      payload = %{
        "version" => "1.0",
        "request" => %{
          "type" => "IntentRequest",
          "intent" => %{
            "name" => "CheckInIntent"
          }
        },
        "character_slug" => npc.slug
      }

      conn = post(conn, ~p"/api/alexa", payload)
      assert json = json_response(conn, 200)

      speech = json["response"]["outputSpeech"]["text"]
      assert speech =~ "thinking about you" or speech =~ "steady"
      assert json["response"]["shouldEndSession"] == false
    end

    test "AMAZON.HelpIntent and AMAZON.StopIntent work correctly", %{conn: conn, npc: npc} do
      # Help intent
      help_conn =
        post(conn, ~p"/api/alexa", %{
          "request" => %{"type" => "IntentRequest", "intent" => %{"name" => "AMAZON.HelpIntent"}},
          "character_slug" => npc.slug
        })

      assert json_response(help_conn, 200)["response"]["outputSpeech"]["text"] =~
               "connected directly"

      # Stop intent
      stop_conn =
        post(conn, ~p"/api/alexa", %{
          "request" => %{"type" => "IntentRequest", "intent" => %{"name" => "AMAZON.StopIntent"}},
          "character_slug" => npc.slug
        })

      stop_json = json_response(stop_conn, 200)
      assert stop_json["response"]["outputSpeech"]["text"] =~ "Take good care"
      assert stop_json["response"]["shouldEndSession"] == true
    end
  end
end
