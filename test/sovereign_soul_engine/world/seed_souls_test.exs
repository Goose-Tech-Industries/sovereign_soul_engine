defmodule SovereignSoulEngine.World.SeedSoulsTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.{Characters, Identity, World}
  alias SovereignSoulEngine.World.SeedSouls

  test "definitions/0 yields exactly 50 souls" do
    assert length(SeedSouls.definitions()) == 50
  end

  test "seed_all/0 creates 50 distinct souls with DIDs, idempotently" do
    assert {:ok, 50} = World.seed_souls()
    assert {:ok, 50} = World.seed_souls()

    assert length(Characters.list_characters()) == 50
    assert World.world_scene() != nil

    for %{slug: slug} <- SeedSouls.definitions() do
      char = Characters.get_character_by_slug(slug)
      assert char != nil
      assert Identity.get_did_for_character(char.id) != nil
    end

    for slug <- ~w(maya ravina valeria cyra) do
      assert Characters.get_character_by_slug(slug) != nil
    end
  end
end
