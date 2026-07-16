defmodule SovereignSoulEngineWeb.MemoryVaultLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.Characters

  setup do
    {:ok, char} =
      Characters.create_character(%{
        name: "MemoryTest NPC",
        slug: "memory-test-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active",
        description: "Test character for memory vault."
      })

    [char: char]
  end

  test "mounts and shows memory vault heading", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/sse/memories")

    assert html =~ "Memory Vault"
    assert html =~ "Browse and filter"
  end

  test "shows filter form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/memories")

    assert has_element?(view, "#memory-filter-form")
    assert has_element?(view, "#memory-char-filter")
    assert has_element?(view, "#memory-cat-filter")
  end

  test "shows empty state when no memories", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/sse/memories")

    assert html =~ "No memories found"
  end

  test "has back navigation to dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/memories")

    assert has_element?(view, ~s|[href="/sse"]|)
  end

  test "receives live updates via PubSub", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/memories")

    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "ledger",
      {:ledger_updated, %{}}
    )

    html = render(view)
    assert html =~ "Memory Vault"
  end
end
