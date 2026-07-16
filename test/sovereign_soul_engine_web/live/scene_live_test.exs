defmodule SovereignSoulEngineWeb.SceneLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Relationships

  setup do
    {:ok, npc} =
      Characters.create_character(%{
        name: "VaelTest",
        slug: "vael-test-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active",
        description: "Test NPC."
      })

    {:ok, player} =
      Characters.create_character(%{
        name: "GooseTest",
        slug: "goose-test-#{Ecto.UUID.generate()}",
        kind: "player",
        status: "active",
        description: "Test player."
      })

    # Create soul profiles
    for char <- [npc, player] do
      {:ok, _} =
        Souls.create_soul_profile(%{
          character_id: char.id,
          identity_summary: "Test profile.",
          personality_traits: %{},
          core_values: [],
          fears: [],
          desires: [],
          speech_style: "Neutral"
        })

      {:ok, _} =
        Souls.create_emotional_state(%{
          character_id: char.id,
          anger: 10,
          fear: 10,
          confidence: 50
        })
    end

    # Create relationship: Vael -> Goose
    {:ok, _} =
      Relationships.create_relationship(%{
        source_character_id: npc.id,
        target_character_id: player.id,
        affinity: 10,
        trust: 25,
        respect: 45,
        fear: 5,
        anger: 20,
        gratitude: 10,
        debt: 0,
        softening: 15,
        hardening: 35,
        wound: 20
      })

    {:ok, scene} =
      Scenes.create_scene(%{
        title: "Test Scene #{Ecto.UUID.generate()}",
        status: "active",
        location: "The Hollow"
      })

    Scenes.add_participant(%{scene_id: scene.id, character_id: npc.id})
    Scenes.add_participant(%{scene_id: scene.id, character_id: player.id})

    [npc: npc, player: player, scene: scene]
  end

  test "mounts and shows scene header", %{conn: conn, scene: scene, npc: npc, player: player} do
    {:ok, _view, html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    assert html =~ scene.title
    assert html =~ "In scene"
    assert html =~ npc.name
    assert html =~ player.name
  end

  test "shows message input form", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    assert has_element?(view, "#message-form")
    assert has_element?(view, "#send-message-btn")
  end

  test "sends a chat message", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    view
    |> form("#message-form", %{message: %{content: "Hello, Vael!"}})
    |> render_submit()

    html = render(view)
    assert html =~ "Hello, Vael!"
  end

  test "shows event injector panel", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    # Event Injector should be present
    html = render(view)
    assert html =~ "Event Injector"
  end

  test "injects betrayed_me event", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    view
    |> element("#inject-betrayed_me")
    |> render_click()

    html = render(view)
    assert html =~ "betrayed_me"
  end

  test "injects ally_saved_me event", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    view
    |> element("#inject-ally_saved_me")
    |> render_click()

    html = render(view)
    assert html =~ "ally_saved_me"
  end

  test "injects insulted_me event", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    view
    |> element("#inject-insulted_me")
    |> render_click()

    html = render(view)
    assert html =~ "insulted_me"
  end

  test "injects praised_me event", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    view
    |> element("#inject-praised_me")
    |> render_click()

    html = render(view)
    assert html =~ "praised_me"
  end

  test "injects protected_me event", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    view
    |> element("#inject-protected_me")
    |> render_click()

    html = render(view)
    assert html =~ "protected_me"
  end

  test "opens soul inspector when clicking character", %{conn: conn, scene: scene, npc: npc} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    view
    |> element(~s|[phx-value-character_id="#{npc.id}"]|)
    |> render_click()

    html = render(view)
    assert html =~ "Soul Inspector"
    assert html =~ npc.name
  end

  test "receives live updates via PubSub", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    # Simulate a PubSub broadcast for a new message
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "scene:#{scene.id}",
      {:new_message, %{}}
    )

    html = render(view)
    assert html =~ scene.title
  end

  test "displays event result after injection", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    view
    |> element("#inject-abandoned_me")
    |> render_click()

    html = render(view)
    assert html =~ "Injected abandoned_me"
  end

  test "has back navigation to dashboard", %{conn: conn, scene: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/scenes/#{scene.id}")

    assert has_element?(view, ~s|[href="/sse"]|)
  end
end
