defmodule SovereignSoulEngineWeb.MapLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  test "redirects /sse/map to companion chat /sse/chat", %{conn: conn} do
    conn = get(conn, "/sse/map")
    assert redirected_to(conn) == "/sse/chat"
  end
end
