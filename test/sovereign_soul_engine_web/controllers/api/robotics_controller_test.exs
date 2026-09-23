defmodule SovereignSoulEngineWeb.Api.RoboticsControllerTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.Characters

  setup %{conn: conn} do
    {:ok, char} =
      Characters.create_character(%{
        name: "G1 Unitree Companion",
        slug: "unitree-g1-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active"
      })

    conn = authenticate_api(conn)
    %{conn: conn, character: char}
  end

  describe "GET /sse/api/robotics/actuation" do
    test "returns 200 with kinematics and ros2 goals", %{conn: conn, character: char} do
      conn = get(conn, ~p"/sse/api/robotics/actuation?character_slug=#{char.slug}")

      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)

      assert body["character_slug"] == char.slug
      assert is_map(body["kinematics"]["head"])
      assert is_map(body["kinematics"]["torso"])
      assert is_map(body["ros2_packet"])
    end

    test "returns 404 for non-existent robot slug", %{conn: conn} do
      conn = get(conn, ~p"/sse/api/robotics/actuation?character_slug=ghost_robot")
      assert json_response(conn, 404)["error"] =~ "not found"
    end
  end

  describe "POST /sse/api/robotics/telemetry" do
    test "ingests battery and motor temperature telemetry", %{conn: conn, character: char} do
      payload = %{
        "character_slug" => char.slug,
        "battery_pct" => 15.0,
        "motor_temp_c" => 68.0,
        "touch_sensor" => "pat"
      }

      conn = post(conn, ~p"/sse/api/robotics/telemetry", payload)
      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)
      assert body["fatigue"] >= 15
      assert body["pain"] >= 20
    end
  end
end
