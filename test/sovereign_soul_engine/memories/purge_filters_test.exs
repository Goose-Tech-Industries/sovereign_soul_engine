defmodule SovereignSoulEngine.Memories.PurgeFiltersTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Memories.PurgeFilters

  test "empty or malformed intent never authorizes deletion" do
    for opts <- [
          [],
          [all: false],
          [all: "true"],
          [topic: "  "],
          [category: ""],
          [topic: 1],
          [category: %{}],
          [topic: []]
        ] do
      assert {:error, :invalid_purge_filters} = PurgeFilters.validate(opts)
    end
  end

  test "full deletion requires the boolean true" do
    assert {:ok, [all: true]} = PurgeFilters.validate(all: true)
  end

  test "normalizes a selective topic without losing literal characters" do
    assert {:ok, filters} = PurgeFilters.validate(query: "  100%_certain  ")
    assert filters[:topic] == "100%_certain"
    assert filters[:all] == false
  end

  test "a memory category does not authorize a knowledge purge" do
    assert {:ok, filters} = PurgeFilters.validate(category: " core ")
    assert filters[:category] == "core"
    assert {:error, :invalid_purge_filters} = PurgeFilters.validate(filters, [:topic])
  end
end
