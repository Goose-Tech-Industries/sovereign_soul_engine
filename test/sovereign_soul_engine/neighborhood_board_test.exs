defmodule SovereignSoulEngine.Neighborhood.BoardTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Neighborhood.Board
  alias SovereignSoulEngine.Social.MeshProtocol
  alias SovereignSoulEngine.Characters

  setup do
    {:ok, char_a} =
      Characters.create_character(%{
        name: "Neighborhood Soul Alpha",
        slug: "neigh-alpha-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active"
      })

    {:ok, char_b} =
      Characters.create_character(%{
        name: "Neighborhood Soul Beta",
        slug: "neigh-beta-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active"
      })

    %{char_a: char_a, char_b: char_b}
  end

  test "list_posts/1 returns seeded posts and supports filtering" do
    posts = Board.list_posts()
    assert length(posts) >= 2

    night_owl_posts = Board.list_posts(zone: "Night Owl Commons")
    assert Enum.all?(night_owl_posts, &(&1.zone == "Night Owl Commons"))
  end

  test "create_post/2 sanitizes addresses and privacy sensitive info", %{char_a: char} do
    raw_content =
      "Spotted a stray dog at 742 Evergreen Terrace. Call 555-123-4567 if it belongs to you."

    {:ok, post} =
      Board.create_post(char, %{
        zone: "Cedar Grove",
        category: :community_alert,
        content: raw_content
      })

    assert post.zone == "Cedar Grove"
    refute post.content =~ "742 Evergreen Terrace"
    assert post.content =~ "[neighborhood street]"
    refute post.content =~ "555-123-4567"
    assert post.content =~ "[contact redacted]"
  end

  test "add_comment/3 and react_to_post/2 update post state", %{char_b: char} do
    posts = Board.list_posts()
    target_post = List.first(posts)

    {:ok, updated_post} = Board.add_comment(target_post.id, char, "Agreed completely.")
    assert length(updated_post.comments) > length(target_post.comments)

    {:ok, reacted_post} = Board.react_to_post(target_post.id, :moon)
    assert reacted_post.reactions.moons > target_post.reactions.moons
  end

  test "generate_autonomous_post/1 generates zone observation", %{char_a: char} do
    {:ok, post} = Board.generate_autonomous_post(char)

    assert is_binary(post.id)
    assert is_binary(post.content)
    assert post.author_slug == char.slug
  end

  test "MeshProtocol.encounter/2 computes mutual resonance and records in TheoryOfMind", %{
    char_a: soul_a,
    char_b: soul_b
  } do
    {:ok, encounter} = MeshProtocol.encounter(soul_a, soul_b)

    assert encounter.resonance >= 15 and encounter.resonance <= 98
    assert is_list(encounter.dialogue_exchange)
    assert length(encounter.dialogue_exchange) == 2
  end
end
