defmodule SovereignSoulEngineWeb.SoulLedgerLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.Characters

  setup do
    {:ok, char} =
      Characters.create_character(%{
        name: "LedgerTest NPC",
        slug: "ledger-test-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active",
        description: "Test character for ledger."
      })

    [char: char]
  end

  test "mounts and shows ledger heading", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/sse/ledger")

    assert html =~ "Soul Ledger"
    assert html =~ "timeline"
  end

  test "shows character filter", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/ledger")

    assert has_element?(view, "#ledger-filter-form")
    assert has_element?(view, "#ledger-filter")
  end

  test "shows empty state when no entries", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/sse/ledger")

    assert html =~ "No ledger entries yet"
  end

  test "receives live updates via PubSub", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/ledger")

    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "ledger",
      {:ledger_updated, %{}}
    )

    html = render(view)
    assert html =~ "Soul Ledger"
  end

  test "has back navigation to dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/ledger")

    assert has_element?(view, ~s|[href="/sse"]|)
  end
end
