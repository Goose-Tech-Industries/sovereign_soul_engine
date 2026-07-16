defmodule SovereignSoulEngineWeb.CharacterLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls

  setup do
    {:ok, npc} =
      Characters.create_character(%{
        name: "ProfileTest NPC",
        slug: "profile-test-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active",
        description: "A test character for profile page."
      })

    {:ok, _profile} =
      Souls.create_soul_profile(%{
        character_id: npc.id,
        identity_summary: "A proud guardian.",
        personality_traits: %{pride: 75, courage: 70},
        core_values: ["Loyalty must be earned"],
        fears: ["Betrayal"],
        desires: ["To protect"],
        speech_style: "Blunt"
      })

    {:ok, _emotional} =
      Souls.create_emotional_state(%{
        character_id: npc.id,
        anger: 20,
        fear: 15,
        confidence: 60
      })

    [npc: npc]
  end

  test "mounts and shows character name", %{conn: conn, npc: npc} do
    {:ok, _view, html} = live(conn, ~p"/sse/characters/#{npc.id}")

    assert html =~ npc.name
    assert html =~ "Soul Profile"
  end

  test "shows soul profile data", %{conn: conn, npc: npc} do
    {:ok, _view, html} = live(conn, ~p"/sse/characters/#{npc.id}")

    assert html =~ "A proud guardian"
    assert html =~ "Loyalty must be earned"
    assert html =~ "Betrayal"
    assert html =~ "Blunt"
  end

  test "shows emotional state bars", %{conn: conn, npc: npc} do
    {:ok, _view, html} = live(conn, ~p"/sse/characters/#{npc.id}")

    assert html =~ "Emotional State"
    assert html =~ "Anger"
    assert html =~ "Fear"
    assert html =~ "Confidence"
  end

  test "has links to ledger and memories", %{conn: conn, npc: npc} do
    {:ok, view, _html} = live(conn, ~p"/sse/characters/#{npc.id}")

    assert has_element?(view, ~s|[href="/sse/ledger"]|)
    assert has_element?(view, ~s|[href="/sse/memories"]|)
  end

  test "has back navigation to dashboard", %{conn: conn, npc: npc} do
    {:ok, view, _html} = live(conn, ~p"/sse/characters/#{npc.id}")

    assert has_element?(view, ~s|[href="/sse"]|)
  end

  test "receives emotion updates via PubSub", %{conn: conn, npc: npc} do
    {:ok, view, _html} = live(conn, ~p"/sse/characters/#{npc.id}")

    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "character:#{npc.id}",
      {:emotion_updated, %{}}
    )

    html = render(view)
    assert html =~ npc.name
  end

  test "receives relationship updates via PubSub", %{conn: conn, npc: npc} do
    {:ok, view, _html} = live(conn, ~p"/sse/characters/#{npc.id}")

    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "character:#{npc.id}",
      {:relationship_updated, %{}}
    )

    html = render(view)
    assert html =~ npc.name
  end
end
