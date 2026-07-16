defmodule SovereignSoulEngineWeb.DashboardLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Scenes

  setup do
    {:ok, npc} =
      Characters.create_character(%{
        name: "Test NPC",
        slug: "test-npc-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active",
        description: "A test NPC character."
      })

    {:ok, _profile} =
      Souls.create_soul_profile(%{
        character_id: npc.id,
        identity_summary: "Test profile.",
        personality_traits: %{pride: 50},
        core_values: ["Test value"],
        fears: ["Test fear"],
        desires: ["Test desire"],
        speech_style: "Neutral"
      })

    {:ok, _emotional} =
      Souls.create_emotional_state(%{
        character_id: npc.id,
        anger: 10,
        fear: 10,
        confidence: 50
      })

    {:ok, scene} =
      Scenes.create_scene(%{
        title: "Test Scene",
        status: "active",
        location: "Test Location"
      })

    [npc: npc, scene: scene]
  end

  test "mounts and shows characters list", %{conn: conn, npc: npc} do
    {:ok, _view, html} = live(conn, ~p"/sse")

    assert html =~ "Sovereign Soul Engine"
    assert html =~ npc.name
    assert html =~ "Characters"
    assert html =~ "Scenes"
  end

  test "shows active scenes", %{conn: conn, scene: scene} do
    {:ok, _view, html} = live(conn, ~p"/sse")

    assert html =~ scene.title
    assert html =~ "Scenes"
  end

  test "navigates to character profile", %{conn: conn, npc: npc} do
    {:ok, view, _html} = live(conn, ~p"/sse")

    assert has_element?(view, ~s|[href="/sse/characters/#{npc.id}"]|)
  end

  test "navigates to scene", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse")

    assert has_element?(view, ~s|[href="/sse/scenes/#{scene.id}"]|)
  end

  test "has links to Soul Ledger and Memory Vault", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse")

    assert has_element?(view, ~s|[href="/sse/ledger"]|)
    assert has_element?(view, ~s|[href="/sse/memories"]|)
  end

  test "receives PubSub updates for ledger", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse")

    # Broadcast a ledger update
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "dashboard",
      {:ledger_updated, %{}}
    )

    html = render(view)

    # Should still render without crash
    assert html =~ "Sovereign Soul Engine"
  end
end
