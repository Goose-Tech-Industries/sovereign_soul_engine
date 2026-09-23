defmodule SovereignSoulEngine.Characters.LivingWorldPrivacyTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Accounts
  import SovereignSoulEngine.AccountsFixtures

  describe "Living World Privacy & Multi-User Isolation" do
    test "list_living_world_characters/0 excludes companions when in_living_world is false" do
      user = user_fixture()

      {:ok, public_npc} =
        Characters.create_character(%{
          name: "Public Canon Guide",
          slug: "public-guide-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active",
          in_living_world: true
        })

      {:ok, private_npc} =
        Characters.create_character(%{
          name: "Secret Companion",
          slug: "secret-comp-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active",
          user_id: user.id,
          in_living_world: false
        })

      living_chars = Characters.list_living_world_characters()
      living_ids = Enum.map(living_chars, & &1.id)

      assert public_npc.id in living_ids
      refute private_npc.id in living_ids
    end

    test "list_living_world_characters/0 excludes all user companions when user opts out of living world" do
      user = user_fixture()
      {:ok, user} = Accounts.update_user_preferences(user, %{opt_out_living_world: true})
      assert user.opt_out_living_world == true

      {:ok, opt_out_companion} =
        Characters.create_character(%{
          name: "Opted Out Soul",
          slug: "opted-out-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active",
          user_id: user.id,
          in_living_world: true
        })

      living_chars = Characters.list_living_world_characters()
      living_ids = Enum.map(living_chars, & &1.id)

      refute opt_out_companion.id in living_ids
    end

    test "list_companions_for_user/1 isolates companions between users" do
      user_a = user_fixture()
      user_b = user_fixture()

      {:ok, canon_npc} =
        Characters.create_character(%{
          name: "Canon Companion Maya",
          slug: "canon-maya-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active",
          user_id: nil
        })

      {:ok, companion_a} =
        Characters.create_character(%{
          name: "User A Companion",
          slug: "comp-a-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active",
          user_id: user_a.id
        })

      {:ok, companion_b} =
        Characters.create_character(%{
          name: "User B Companion",
          slug: "comp-b-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active",
          user_id: user_b.id
        })

      user_a_comps = Characters.list_companions_for_user(user_a.id)
      user_a_ids = Enum.map(user_a_comps, & &1.id)

      assert canon_npc.id in user_a_ids
      assert companion_a.id in user_a_ids
      refute companion_b.id in user_a_ids

      user_b_comps = Characters.list_companions_for_user(user_b.id)
      user_b_ids = Enum.map(user_b_comps, & &1.id)

      assert canon_npc.id in user_b_ids
      assert companion_b.id in user_b_ids
      refute companion_a.id in user_b_ids
    end

    test "get_or_create_player_for_user/1 provisions and retrieves player persona" do
      user = user_fixture()

      player1 = Characters.get_or_create_player_for_user(user)
      assert player1.user_id == user.id
      assert player1.kind == "player"

      # Idempotent
      player2 = Characters.get_or_create_player_for_user(user)
      assert player1.id == player2.id
    end

    test "set_companion_living_world/2 toggles privacy" do
      user = user_fixture()

      {:ok, companion} =
        Characters.create_character(%{
          name: "Toggleable Companion",
          slug: "toggle-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active",
          user_id: user.id,
          in_living_world: true
        })

      assert companion.in_living_world == true

      {:ok, updated} = Characters.set_companion_living_world(companion, false)
      assert updated.in_living_world == false

      {:ok, restored} = Characters.set_companion_living_world(updated, true)
      assert restored.in_living_world == true
    end
  end
end
