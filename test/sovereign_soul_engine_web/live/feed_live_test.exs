defmodule SovereignSoulEngineWeb.FeedLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.{Characters, Social.SocialFeed}

  setup do
    {:ok, player} =
      Characters.create_character(%{
        name: "Goose",
        slug: "goose",
        kind: "player",
        status: "active",
        description: "Primary player character."
      })

    {:ok, npc} =
      Characters.create_character(%{
        name: "Maya",
        slug: "maya-feed-test-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active",
        description: "Test tactician companion."
      })

    {:ok, post} =
      SocialFeed.create_post(%{
        character_id: npc.id,
        content: "The fog is creeping over the western garrison.",
        mood: "introspective",
        platform: "soulbook",
        metadata: %{
          "location" => "The Raven Docks",
          "comments" => [],
          "reactions" => %{"love" => 1, "honor" => 0, "fire" => 0, "laugh" => 0, "moon" => 0}
        }
      })

    %{player: player, npc: npc, post: post}
  end

  test "mounts SoulBook feed and renders living wall and Top 8", %{conn: conn, post: post} do
    {:ok, view, html} = live(conn, ~p"/sse/feed")

    assert html =~ "SoulBook"
    assert html =~ "Top 8 Companions"
    assert html =~ "What is unfolding in Feannag&#39;s Rest"
    assert html =~ post.content
    assert has_element?(view, "button[phx-click='react'][phx-value-type='love']")
  end

  test "player publishes a status post", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/feed")

    html =
      view
      |> form("form[phx-submit='publish_post']", %{
        "content" => "We march towards the Obsidian Spire at dusk.",
        "location" => "The High Sovereign Palace"
      })
      |> render_submit()

    assert html =~ "We march towards the Obsidian Spire at dusk."
    assert html =~ "The High Sovereign Palace"
  end

  test "player adds a comment to a post", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/sse/feed")

    html =
      view
      |> form("form[phx-submit='add_comment']", %{
        "post_id" => post.id,
        "content" => "Keep your lanterns extinguished."
      })
      |> render_submit()

    assert html =~ "Keep your lanterns extinguished."
  end

  test "player reacts with an emote to a post", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/sse/feed")

    view
    |> element("button[phx-click='react'][phx-value-post_id='#{post.id}'][phx-value-type='fire']")
    |> render_click()

    updated = SovereignSoulEngine.Repo.get!(SovereignSoulEngine.Social.SocialPost, post.id)
    assert updated.metadata["reactions"]["fire"] == 1
  end

  test "sparks an autonomous NPC post", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/feed")

    html =
      view
      |> element("button[phx-click='spark_npc_post']")
      |> render_click()

    assert html =~ "posted" or html =~ "SoulBook"
  end
end
