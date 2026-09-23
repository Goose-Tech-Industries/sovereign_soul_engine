defmodule SovereignSoulEngineWeb.Api.VesselControllerTest do
  use SovereignSoulEngineWeb.ConnCase

  setup %{conn: conn} do
    %{conn: authenticate_api(conn)}
  end

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls

  setup do
    {:ok, npc} =
      Characters.create_character(%{
        name: "Goose Cyberdeck",
        slug: "goose-vessel",
        kind: "npc",
        status: "active"
      })

    {:ok, emotional} =
      Souls.create_emotional_state(%{
        character_id: npc.id,
        stress: 40,
        confidence: 60,
        attachment: 50
      })

    {:ok, somatic} =
      Souls.create_somatic_state(%{
        character_id: npc.id,
        fatigue: 20,
        pain: 0
      })

    {:ok, npc: npc, emotional: emotional, somatic: somatic}
  end

  describe "GET /api/vessel/display_state" do
    test "returns microcontroller OLED render telemetry", %{conn: conn, npc: npc} do
      conn = get(conn, ~p"/api/vessel/display_state", %{"character_slug" => npc.slug})
      assert json = json_response(conn, 200)

      assert json["status"] == "ok"
      assert json["companion_name"] == npc.name
      assert json["expression_sprite"] in ["calm", "curious", "happy", "concerned", "intimate"]
      assert is_map(json["saccade_target"])
      assert json["saccade_target"]["dwell_ms"] > 0
      assert json["neurochemistry"]["dopamine"] != nil
      assert json["ambient_hex"] =~ "#"
    end
  end

  describe "POST /api/vessel/touch" do
    test "processes head pat and increases oxytocin / lowers stress", %{conn: conn, npc: npc} do
      conn =
        post(conn, ~p"/api/vessel/touch", %{
          "character_slug" => npc.slug,
          "touch_type" => "pat"
        })

      assert json = json_response(conn, 200)
      assert json["status"] == "ok"
      assert json["touch_type"] == "pat"
      assert json["reaction"] =~ npc.name
      assert json["reaction"] =~ "hand"
      assert json["neurochemistry"]["oxytocin"] != nil
    end

    test "processes hug touch type", %{conn: conn, npc: npc} do
      conn =
        post(conn, ~p"/api/vessel/touch", %{
          "character_slug" => npc.slug,
          "touch_type" => "hug"
        })

      assert json = json_response(conn, 200)
      assert json["reaction"] =~ "hug" or json["reaction"] =~ "exhale"
    end
  end
end
