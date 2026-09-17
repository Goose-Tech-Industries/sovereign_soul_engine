defmodule SovereignSoulEngine.RelationshipsTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Relationships

  setup do
    {:ok, source} =
      Characters.create_character(%{
        name: "Source",
        slug: "rsrc_#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    %{source: source}
  end

  defp create_target(i) do
    {:ok, target} =
      Characters.create_character(%{
        name: "Target #{i}",
        slug: "rtgt_#{i}_#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    target
  end

  test "prune_edges/2 removes the stalest edges beyond the cap", %{source: source} do
    t1 = create_target(1)
    t2 = create_target(2)
    t3 = create_target(3)

    {:ok, r1} =
      Relationships.create_relationship(%{
        source_character_id: source.id,
        target_character_id: t1.id,
        last_interaction_at: ~U[2026-01-01 00:00:00Z]
      })

    {:ok, _r2} =
      Relationships.create_relationship(%{
        source_character_id: source.id,
        target_character_id: t2.id,
        last_interaction_at: ~U[2026-06-01 00:00:00Z]
      })

    {:ok, _r3} =
      Relationships.create_relationship(%{
        source_character_id: source.id,
        target_character_id: t3.id,
        last_interaction_at: ~U[2026-09-01 00:00:00Z]
      })

    assert Relationships.prune_edges(source.id, 2) == 1

    remaining = Relationships.list_relationships_for_source(source.id)
    assert length(remaining) == 2
    refute Enum.any?(remaining, &(&1.id == r1.id))
  end

  test "prune_edges/2 is a no-op when under the cap", %{source: source} do
    t1 = create_target(1)

    {:ok, _} =
      Relationships.create_relationship(%{
        source_character_id: source.id,
        target_character_id: t1.id
      })

    assert Relationships.prune_edges(source.id, 50) == 0
    assert length(Relationships.list_relationships_for_source(source.id)) == 1
  end
end
