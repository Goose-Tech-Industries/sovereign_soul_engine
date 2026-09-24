defmodule SovereignSoulEngineWeb.CoverageSweepTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.AccountsFixtures
  alias SovereignSoulEngine.Characters

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    previous = Application.get_env(:sovereign_soul_engine, :admin_user_ids, [])
    Application.put_env(:sovereign_soul_engine, :admin_user_ids, [user.id])

    on_exit(fn -> Application.put_env(:sovereign_soul_engine, :admin_user_ids, previous) end)
    %{conn: log_in_user(conn, user)}
  end

  test "mounts the core authenticated chat and cognition views", %{conn: conn} do
    assert {:ok, _view, html} = live(conn, "/sse/chat/sauce")
    assert html =~ "Chat" or html =~ "Sauce"

    assert {:ok, _view, cognition_html} = live(conn, "/sse/cognition")
    assert cognition_html =~ "Cognition" or cognition_html =~ "cognitive"
  end

  test "mounts soul creator and map-adjacent world views", %{conn: conn} do
    assert {:ok, _view, html} = live(conn, "/sse/souls/new")
    assert html =~ "Create" or html =~ "Soul"

    assert {:ok, _view, world_html} = live(conn, "/sse/world")
    assert byte_size(world_html) > 0
  end

  test "mounts ACP dashboard, creator, and social log", %{conn: conn} do
    assert {:ok, _view, dashboard_html} = live(conn, "/sse/acp")
    assert dashboard_html =~ "Character Registry"

    assert {:ok, creator_view, creator_html} = live(conn, "/sse/acp/npcs/new")
    assert creator_html =~ "NPC" or creator_html =~ "Character"
    render_click(element(creator_view, "button[phx-click='next_step']"))

    assert {:ok, social_view, social_html} = live(conn, "/sse/acp/social")
    assert social_html =~ "Social" or social_html =~ "social"

    if has_element?(social_view, "button[phx-click='trigger_tick']") do
      render_click(element(social_view, "button[phx-click='trigger_tick']"))
    end
  end

  test "mounts ACP character tabs and renders a real character", %{conn: conn} do
    {:ok, character} =
      Characters.create_character(%{
        name: "Coverage NPC",
        slug: "coverage-npc-#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    assert {:ok, _view, html} = live(conn, "/sse/acp/npcs/#{character.id}")
    assert html =~ "Coverage NPC"

    assert {:ok, _view, timeline_html} = live(conn, "/sse/acp/npcs/#{character.id}/timeline")
    assert timeline_html =~ "Timeline" or timeline_html =~ "Coverage NPC"
  end
end
