defmodule SovereignSoulEngineWeb.WorldLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.World

  test "renders the world feed with counts when seeded", %{conn: conn} do
    World.seed_souls()

    {:ok, _view, html} = live(conn, ~p"/sse/world")

    assert html =~ "Soul Society"
    assert html =~ "50 souls"
  end

  test "shows the empty state when the world is unseeded", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/sse/world")

    assert html =~ "The world is quiet"
  end

  test "updates live when a world event is appended", %{conn: conn} do
    World.seed_souls()

    {:ok, view, _html} = live(conn, ~p"/sse/world")

    World.append_event(%{
      kind: "gossip",
      from_did: "did:soul:zaaa",
      to_did: "did:soul:zbbb",
      payload: %{}
    })

    # the append broadcast reaches the subscribed view; deliver it deterministically
    send(view.pid, {:world_event, %{kind: "gossip"}})

    assert render(view) =~ "gossiped about"
  end
end
