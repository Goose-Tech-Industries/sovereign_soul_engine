defmodule SovereignSoulEngine.World.TownMapTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.World.TownMap

  describe "Feannag's Rest TownMap context" do
    test "get_map/0 returns the 12 canonical districts and metadata" do
      map = TownMap.get_map()

      assert map.town_name == "Feannag's Rest"
      assert map.region_name == "Gleann Caorach"
      assert map.district_count == 12
      assert length(map.districts) == 12

      crows_keep = Enum.find(map.districts, &(&1.slug == "crows_keep"))
      assert crows_keep != nil
      assert crows_keep.gaelic_name == "Caisteal Feannag"
      assert crows_keep.tile_id == "region:1:tile:12:15"
      assert crows_keep.zone_type == :citadel
      assert crows_keep.danger_level == 3
      assert is_list(crows_keep.connections)
    end

    test "get_district/1 returns detailed district with Twisted coordinates" do
      district = TownMap.get_district("high_sanctuary")

      assert district != nil
      assert district.slug == "high_sanctuary"
      assert district.name =~ "High Sanctuary"
      assert district.gaelic_name == "Cill na Feannaige"
      assert district.tile_id == "region:1:tile:14:14"
      assert is_list(district.present_souls)
      assert is_list(district.amenities)
      assert is_list(district.secrets)
    end

    test "get_district/1 returns nil for unknown slug" do
      assert TownMap.get_district("unknown_district") == nil
    end

    test "move_soul/2 moves a soul and updates locations" do
      {:ok, character} =
        SovereignSoulEngine.Characters.create_character(%{
          name: "Highland Scout",
          slug: "highland_scout_#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active",
          description: "A highland sentry watching the passes"
        })

      assert {:ok, res} = TownMap.move_soul(character.id, "north_outpost")
      assert res.to == "north_outpost"

      assert TownMap.get_soul_location(character.id) == "north_outpost"
    end

    test "simulate_roaming/0 moves souls across connected roads" do
      assert {:ok, count} = TownMap.simulate_roaming()
      assert is_integer(count)
    end

    test "expand_district_with_ai/3 generates a new secret/POI" do
      assert {:ok, expansion} =
               TownMap.expand_district_with_ai("shadowgate_warrens", "smugglers cache")

      assert is_binary(expansion.title)
      assert is_binary(expansion.description)
      assert is_integer(expansion.danger_shift)

      # Verify expansion is stored on the district
      district = TownMap.get_district("shadowgate_warrens")
      assert Enum.any?(district.expansions, &(&1.title == expansion.title))
    end
  end
end
