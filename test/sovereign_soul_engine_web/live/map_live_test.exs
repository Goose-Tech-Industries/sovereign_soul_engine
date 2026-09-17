defmodule SovereignSoulEngineWeb.MapLiveTest do
  use SovereignSoulEngineWeb.ConnCase
  import Phoenix.LiveViewTest

  test "mounts /sse/map and displays 12 districts", %{conn: conn} do
    {:ok, view, html} = live(conn, "/sse/map")

    assert html =~ "Feannag&#39;s Rest" or html =~ "Feannag's Rest"
    assert html =~ "Gleann Caorach"
    assert html =~ "The Crow&#39;s Keep" or html =~ "The Crow's Keep"
    assert html =~ "High Sanctuary"
    assert html =~ "King&#39;s Road Plaza" or html =~ "King's Road Plaza"

    # Select a district
    html =
      view
      |> element("g[phx-value-slug='old_ironworks']")
      |> render_click()

    assert html =~ "The Old Ironworks"
    assert html =~ "A&#39; Cheàrdach Dhubh" or html =~ "Cheàrdach"
    assert html =~ "region:1:tile:14:11"
  end

  test "simulates soul roaming on button click", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sse/map")

    html =
      view
      |> element("button", "Roam Souls")
      |> render_click()

    assert html =~ "roamed to new districts"
  end

  test "expands district with AI architect", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sse/map")

    html =
      view
      |> form("form[phx-submit='expand_with_ai']", %{"prompt" => "secret crypt"})
      |> render_submit()

    assert html =~ "AI Architect discovered"
  end
end
