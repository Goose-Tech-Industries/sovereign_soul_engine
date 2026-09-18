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

  test "walks using keyboard WASD and updates player position", %{conn: conn} do
    {:ok, view, html} = live(conn, "/sse/map")

    # Initial position at High Sovereign Palace
    assert html =~ "YOU (Traveler)"
    assert html =~ "1/13"

    # Press 'W' to walk North to Crow's Keep
    html = render_keydown(view, "handle_keydown", %{"key" => "w"})
    assert html =~ "The Crow&#39;s Keep" or html =~ "The Crow's Keep"
    assert html =~ "2/13"
    assert html =~ "Step 1"

    # Press 'D' to walk East to High Sanctuary
    html = render_keydown(view, "handle_keydown", %{"key" => "d"})
    assert html =~ "High Sanctuary" or html =~ "Cill na Feannaige"
    assert html =~ "3/13"

    # Press 'C' to fast-return to High Sovereign Palace
    html = render_keydown(view, "handle_keydown", %{"key" => "c"})
    assert html =~ "The High Sovereign Palace" or html =~ "Lùchairt an Àrd-Rìgh"
  end

  test "walks using on-screen virtual D-Pad buttons", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sse/map")

    # Click Walk South button
    html =
      view
      |> element("button[phx-value-direction='south']", "S")
      |> render_click()

    assert html =~ "The South Bastion" or html =~ "Gàrradh a&#39; Chinn a Deas"

    # Click Walk West button
    html =
      view
      |> element("button[phx-value-direction='west']", "A")
      |> render_click()

    assert html =~ "Shadowgate" or html =~ "Sràid nan Dubh-sgàil"
  end

  test "hails NPC in district for instant ambient dialogue without compute overhead", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sse/map")

    # Move to South Bastion where Corvus anchors
    _html =
      view
      |> element("button[phx-value-direction='south']", "S")
      |> render_click()

    # Hail Corvus
    html =
      view
      |> render_hook("hail_soul", %{"name" => "Corvus", "slug" => "corvus"})

    assert html =~ "Corvus"
    assert html =~ "Ramparts are secure" or html =~ "Keep your"
    assert html =~ "Ambient Local Voice"
  end

  test "renders 28x24 2D RPG matrix with inline grid columns preventing 1-column collapse", %{conn: conn} do
    {:ok, view, html} = live(conn, "/sse/map")

    # Verify grid board has inline style repeat(28, ...)
    assert html =~ "grid-template-columns: repeat(28,"
    assert html =~ "grid-template-rows: repeat(24,"
    assert html =~ "rpg-grid-board"

    # Verify initial tile coordinates and player start
    assert html =~ "tile-14-8"
    assert html =~ "tile-14-9"
    assert html =~ "YOU (Traveler)"

    # Click a walkable tile
    html =
      view
      |> element("#tile-14-9")
      |> render_click()

    # Player stepped onto tile (14, 9) right next to Fia
    assert html =~ "Tile: region:1:tile:14:9"
    assert html =~ "Fia"
    assert html =~ "Empathetic Weaver"

    # Toggle zoom level / tile size
    html =
      view
      |> element("button[phx-value-size='36']", "36px")
      |> render_click()

    assert html =~ "grid-template-columns: repeat(28, 36px)"
  end
end
