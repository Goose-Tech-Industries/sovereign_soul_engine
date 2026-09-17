defmodule SovereignSoulEngine.Souls.TraitCatalogTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.TraitCatalog

  describe "all/0" do
    test "returns a stable, non-empty list" do
      traits = TraitCatalog.all()

      assert is_list(traits)
      assert length(traits) == 10
      assert Enum.all?(traits, &Map.has_key?(&1, :key))
      assert Enum.all?(traits, &Map.has_key?(&1, :label))
      assert Enum.all?(traits, &Map.has_key?(&1, :blurb))
    end
  end

  describe "label/1" do
    test "returns the display label for a known key" do
      assert TraitCatalog.label("depression") == "Emotionally Heavy"
      assert TraitCatalog.label("bipolar") == "Mood Swings"
    end

    test "falls back to the key for an unknown key" do
      assert TraitCatalog.label("unknown") == "unknown"
    end
  end

  describe "blurb/1" do
    test "returns a blurb for a known key" do
      assert is_binary(TraitCatalog.blurb("ocd"))
      assert TraitCatalog.blurb("ocd") =~ "distress"
    end

    test "falls back to empty string for an unknown key" do
      assert TraitCatalog.blurb("unknown") == ""
    end
  end

  describe "default_map/0" do
    test "maps every trait key to false" do
      map = TraitCatalog.default_map()

      assert map_size(map) == 10
      assert Map.get(map, "depression") == false
      assert Map.get(map, "narcissism") == false
      assert Enum.all?(map, fn {_k, v} -> v == false end)
    end
  end
end
