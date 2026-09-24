defmodule SovereignSoulEngineWeb.PageControllerTest do
  use SovereignSoulEngineWeb.ConnCase

  test "GET /sse renders dashboard", %{conn: conn} do
    conn = get(conn, ~p"/sse")
    assert html_response(conn, 200) =~ "Sovereign Soul Engine"
    assert html_response(conn, 200) =~ "Characters"
    assert html_response(conn, 200) =~ "Scenes"
  end

  test "GET /chat redirects to the SSE chat surface", %{conn: conn} do
    conn = get(conn, "/chat")
    assert redirected_to(conn) == "/sse/chat"
  end

  test "GET /sse/map redirects to the SSE chat surface", %{conn: conn} do
    conn = get(conn, "/sse/map")
    assert redirected_to(conn) == "/sse/chat"
  end
end
