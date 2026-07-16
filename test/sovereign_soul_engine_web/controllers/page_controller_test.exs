defmodule SovereignSoulEngineWeb.PageControllerTest do
  use SovereignSoulEngineWeb.ConnCase

  test "GET /sse renders dashboard", %{conn: conn} do
    conn = get(conn, ~p"/sse")
    assert html_response(conn, 200) =~ "Sovereign Soul Engine"
    assert html_response(conn, 200) =~ "Characters"
    assert html_response(conn, 200) =~ "Scenes"
  end
end
