defmodule SovereignSoulEngineWeb.Api.PrivacyControllerTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Privacy

  setup do
    {:ok, player} =
      Characters.create_character(%{
        name: "Settings Tester",
        slug: "tester-#{Ecto.UUID.generate()}",
        kind: "player",
        status: "active"
      })

    %{player: player}
  end

  describe "GET /api/privacy/settings" do
    test "returns current privacy settings", %{conn: conn, player: player} do
      conn = get(conn, ~p"/api/privacy/settings", %{"character_slug" => player.slug})
      assert json = json_response(conn, 200)

      assert json["status"] == "ok"
      assert json["character_slug"] == player.slug
      assert json["settings"]["proactive_checkins"] == true
      assert json["settings"]["haptic_feedback"] == true
    end
  end

  describe "POST /api/privacy/settings" do
    test "updates settings and takes effect immediately", %{conn: conn, player: player} do
      conn =
        post(conn, ~p"/api/privacy/settings", %{
          "character_slug" => player.slug,
          "settings" => %{
            "proactive_checkins" => false,
            "biometrics_tracking" => false,
            "camera_vision" => false
          }
        })

      assert json = json_response(conn, 200)
      assert json["status"] == "ok"
      assert json["settings"]["proactive_checkins"] == false
      assert json["settings"]["biometrics_tracking"] == false
      assert json["settings"]["camera_vision"] == false

      # Verify backend module sees updated state
      assert Privacy.checkin_allowed?(player.id) == false
      assert Privacy.biometrics_allowed?(player.id) == false
      assert Privacy.vision_allowed?(player.id) == false
    end

    test "returns 404 for unknown character", %{conn: conn} do
      conn =
        post(conn, ~p"/api/privacy/settings", %{
          "character_slug" => "non_existent_ghost",
          "settings" => %{"proactive_checkins" => false}
        })

      assert json_response(conn, 404)["error"] =~ "not found"
    end
  end
end
