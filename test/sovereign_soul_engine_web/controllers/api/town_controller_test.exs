defmodule SovereignSoulEngineWeb.Api.TownControllerTest do
  use SovereignSoulEngineWeb.ConnCase

  test "GET /sse/api/town/map returns 13 regions with Twisted metadata", %{conn: conn} do
    conn = get(conn, "/sse/api/town/map")
    assert json = json_response(conn, 200)

    assert json["town_name"] == "Feannag's Rest"
    assert json["region_name"] == "Gleann Caorach"
    assert json["district_count"] == 13
    assert length(json["districts"]) == 13

    palace = Enum.find(json["districts"], &(&1["slug"] == "high_palace"))
    assert palace["tile_id"] == "region:1:tile:12:12"
    assert palace["zone_type"] == "palace"

    crows = Enum.find(json["districts"], &(&1["slug"] == "crows_keep"))
    assert crows["tile_id"] == "region:1:tile:12:15"
  end

  test "GET /sse/api/town/districts/:slug returns district details", %{conn: conn} do
    conn = get(conn, "/sse/api/town/districts/crows_keep")
    assert json = json_response(conn, 200)

    assert json["slug"] == "crows_keep"
    assert json["name"] =~ "Crow's Keep"
    assert json["tile_id"] == "region:1:tile:12:15"
    assert is_list(json["connections"])
  end

  test "GET /sse/api/town/districts/unknown returns 404", %{conn: conn} do
    conn = get(conn, "/sse/api/town/districts/nonexistent_place")
    assert json_response(conn, 404)["error"] == "district_not_found"
  end

  test "POST /sse/api/town/districts/:slug/expand expands district with AI", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/sse/api/town/districts/old_ironworks/expand", Jason.encode!(%{"prompt" => "ancient anvil"}))

    assert json = json_response(conn, 200)
    assert json["status"] == "ok"
    assert json["district"] == "old_ironworks"
    assert is_binary(json["expansion"]["title"])
  end

  test "POST /sse/api/town/simulate_movements triggers roaming", %{conn: conn} do
    conn = post(conn, "/sse/api/town/simulate_movements")
    assert json = json_response(conn, 200)
    assert json["status"] == "ok"
    assert is_integer(json["moved_souls"])
  end
end
