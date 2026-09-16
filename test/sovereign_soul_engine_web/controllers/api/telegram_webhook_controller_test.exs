defmodule SovereignSoulEngineWeb.Api.TelegramWebhookControllerTest do
  use SovereignSoulEngineWeb.ConnCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls

  setup do
    {:ok, npc} =
      Characters.create_character(%{
        name: "Vael",
        slug: "vael",
        kind: "npc",
        status: "active",
        description: "Tactical strategist"
      })

    {:ok, _profile} =
      Souls.create_soul_profile(%{
        character_id: npc.id,
        archetype: "Tactician",
        core_wound: "Betrayal",
        moral_alignment: "Lawful Neutral"
      })

    {:ok, _emotional} =
      Souls.create_emotional_state(%{
        character_id: npc.id,
        stress: 25,
        confidence: 70,
        attachment: 40
      })

    %{npc: npc}
  end

  describe "POST /sse/api/webhooks/telegram" do
    test "handles /start command cleanly", %{conn: conn} do
      payload = %{
        "message" => %{
          "chat" => %{"id" => 12_345_678},
          "from" => %{"id" => 12_345_678, "first_name" => "GooseUser"},
          "text" => "/start"
        }
      }

      conn = post(conn, "/sse/api/webhooks/telegram", payload)
      assert json_response(conn, 200)["status"] == "ok"
      assert json_response(conn, 200)["command"] == "start"
    end

    test "handles /status command returning companion neurochemistry", %{conn: conn, npc: npc} do
      payload = %{
        "message" => %{
          "chat" => %{"id" => 12_345_678},
          "text" => "/status"
        }
      }

      conn = post(conn, "/sse/api/webhooks/telegram", payload)
      res = json_response(conn, 200)
      assert res["status"] == "ok"
      assert res["command"] == "status"
      assert res["companion"] == npc.name
    end

    test "handles dialogue text and returns companion reply", %{conn: conn, npc: npc} do
      payload = %{
        "message" => %{
          "chat" => %{"id" => 98_765_432},
          "from" => %{"id" => 98_765_432, "first_name" => "AgentAlex"},
          "text" => "Vael, what is the situation?"
        }
      }

      conn = post(conn, "/sse/api/webhooks/telegram", payload)
      res = json_response(conn, 200)
      assert res["status"] == "ok"
      assert res["companion"] == npc.name
      assert is_binary(res["reply"])
      assert String.length(res["reply"]) > 0
    end
  end
end
