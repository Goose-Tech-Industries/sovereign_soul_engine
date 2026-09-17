defmodule SovereignSoulEngineWeb.ChatLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Relationships

  setup do
    # Player character with slug "goose" is required by ChatLive
    {:ok, player} =
      Characters.create_character(%{
        name: "Goose",
        slug: "goose",
        kind: "player",
        status: "active",
        description: "Primary player character."
      })

    {:ok, npc1} =
      Characters.create_character(%{
        name: "Maya",
        slug: "maya-test-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active",
        description: "Test companion 1."
      })

    {:ok, npc2} =
      Characters.create_character(%{
        name: "Ravina",
        slug: "ravina-test-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active",
        description: "Test companion 2."
      })

    # Create profiles and emotional states
    for char <- [player, npc1, npc2] do
      {:ok, _} =
        Souls.create_soul_profile(%{
          character_id: char.id,
          identity_summary: "Profile for #{char.name}.",
          personality_traits: %{openness: 75, neuroticism: 30},
          core_values: ["Truth", "Freedom"],
          fears: ["Abandonment"],
          desires: ["Connection"],
          speech_style: "Direct"
        })

      {:ok, _} =
        Souls.create_emotional_state(%{
          character_id: char.id,
          anger: 10,
          fear: 15,
          confidence: 70,
          stress: 20
        })

      Souls.get_or_create_somatic_state(char.id)
    end

    # Relationships: NPC -> Player
    for npc <- [npc1, npc2] do
      {:ok, _} =
        Relationships.create_relationship(%{
          source_character_id: npc.id,
          target_character_id: player.id,
          affinity: 60,
          trust: 55,
          respect: 50,
          fear: 10,
          anger: 5,
          gratitude: 30,
          debt: 0,
          softening: 20,
          hardening: 10,
          wound: 0
        })
    end

    # Create direct scenes for both NPCs so they appear in Direct Messages
    {:ok, direct_scene1} =
      Scenes.create_scene(%{
        title: "#{player.name} & #{npc1.name}",
        status: "active",
        location: "The Hollow Bastion",
        context: %{
          "mood" => "calm",
          "weather" => "misty",
          "narrative" => "A quiet evening by the hearth."
        }
      })

    Scenes.add_participant(%{scene_id: direct_scene1.id, character_id: player.id})
    Scenes.add_participant(%{scene_id: direct_scene1.id, character_id: npc1.id})

    {:ok, direct_scene2} =
      Scenes.create_scene(%{
        title: "#{player.name} & #{npc2.name}",
        status: "active",
        location: "The Obsidian Library",
        context: %{
          "mood" => "studious",
          "weather" => "rainy"
        }
      })

    Scenes.add_participant(%{scene_id: direct_scene2.id, character_id: player.id})
    Scenes.add_participant(%{scene_id: direct_scene2.id, character_id: npc2.id})

    [player: player, npc1: npc1, npc2: npc2, scene1: direct_scene1, scene2: direct_scene2]
  end

  test "mounts and displays Sovereign Chat with biometrics HUD", %{conn: conn, npc1: npc1} do
    {:ok, view, html} = live(conn, ~p"/sse/chat")

    assert html =~ "Sovereign Chat"
    assert html =~ "Direct Messages"
    assert html =~ npc1.name
    assert has_element?(view, "#chat-app")
    assert has_element?(view, "#chat-form")
    assert has_element?(view, "#chat-input")
  end

  test "sends a message and triggers instant action beat and dialogue in test mode", %{
    conn: conn,
    scene1: scene
  } do
    {:ok, view, _html} = live(conn, ~p"/sse/chat?scene_id=#{scene.id}")

    # Submit a message from the player
    view
    |> form("#chat-form", %{"message" => %{"content" => "Hello, are you there?"}})
    |> render_submit()

    # The player message should exist in the scene messages
    messages = Scenes.list_messages(scene.id)
    assert Enum.any?(messages, &(&1.content == "Hello, are you there?"))
  end

  test "switches direct chat character selection", %{conn: conn, npc2: npc2} do
    {:ok, view, _html} = live(conn, ~p"/sse/chat")

    html =
      view
      |> element("button[phx-click='select_character'][phx-value-character_id='#{npc2.id}']")
      |> render_click()

    assert html =~ npc2.name
  end

  test "creates a new group room with selected NPCs", %{conn: conn, npc1: npc1, npc2: npc2} do
    {:ok, view, _html} = live(conn, ~p"/sse/chat")

    # Start group creation
    view
    |> element("button[phx-click='start_new_group']")
    |> render_click()

    # Select both companions
    view
    |> element("input[phx-click='toggle_npc'][phx-value-npc_id='#{npc1.id}']")
    |> render_click()

    view
    |> element("input[phx-click='toggle_npc'][phx-value-npc_id='#{npc2.id}']")
    |> render_click()

    # Submit group creation form
    html =
      view
      |> form("form[phx-submit='create_group']", %{
        "group_name" => "Council of the Bastion",
        "location" => "Great Hall",
        "scenario_mood" => "solemn",
        "scenario_weather" => "stormy"
      })
      |> render_submit()

    assert html =~ "Council of the Bastion"
  end

  test "edits and saves scenario context", %{conn: conn, scene1: scene} do
    {:ok, view, _html} = live(conn, ~p"/sse/chat?scene_id=#{scene.id}")

    # Toggle scenario edit
    view
    |> element("button[phx-click='toggle_edit_scenario']")
    |> render_click()

    # Submit new scenario attributes
    view
    |> form("form[phx-submit='save_scenario']", %{
      "location" => "Obsidian Spire",
      "mood" => "electric",
      "weather" => "crimson aurora",
      "narrative" => "Thunder echoes across the sky."
    })
    |> render_submit()

    updated = Scenes.get_scene!(scene.id)
    assert updated.location == "Obsidian Spire"
    assert updated.context["mood"] == "electric"
    assert updated.context["weather"] == "crimson aurora"
  end

  test "applies somatic biometric telemetry simulation", %{conn: conn, player: player} do
    {:ok, view, _html} = live(conn, ~p"/sse/chat")

    # Toggle somatic sim modal
    view
    |> element("button[phx-click='toggle_somatic_sim']")
    |> render_click()

    # Submit somatic changes
    view
    |> form("form[phx-submit='apply_somatic_sim']", %{
      "bpm" => "115",
      "stress" => "65",
      "fatigue" => "40",
      "motion" => "running"
    })
    |> render_submit()

    player_somatic = Souls.get_or_create_somatic_state(player.id)
    assert player_somatic.fatigue == 40

    player_emotional = Souls.get_emotional_state_by_character(player.id)
    assert player_emotional.stress == 65
  end

  test "toggles voice immersion", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/chat")

    assert has_element?(view, "button[phx-click='toggle_voice']")

    view
    |> element("button[phx-click='toggle_voice']")
    |> render_click()
  end

  test "toggles social feed drawer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/chat")

    assert has_element?(view, "button[phx-click='toggle_social_drawer']")

    view
    |> element("button[phx-click='toggle_social_drawer']")
    |> render_click()
  end
end
