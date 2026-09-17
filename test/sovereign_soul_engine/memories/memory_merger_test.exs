defmodule SovereignSoulEngine.Memories.MemoryMergerTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Memories.MemoryMerger
  alias SovereignSoulEngine.Memories.Memory
  alias SovereignSoulEngine.Characters

  setup do
    SovereignSoulEngine.LLM.FakeProvider.reset()

    {:ok, char} =
      Characters.create_character(%{
        name: "MemoryArchivist",
        slug: "archivist_#{System.unique_integer([:positive])}",
        kind: "npc",
        description: "A test NPC for memory consolidation",
        status: "active"
      })

    %{character: char}
  end

  defp insert_minor_memory(char_id, summary, tags, importance) do
    {:ok, mem} =
      Memories.create_memory(%{
        owner_character_id: char_id,
        category: "episodic",
        summary: summary,
        importance: importance,
        emotional_intensity: 30,
        valence: 0.5,
        tags: tags,
        status: "active",
        occurred_at: DateTime.utc_now()
      })

    mem
  end

  describe "consolidate_now/1 synchronous consolidation" do
    test "merges 3+ low-importance memories with shared tags into single consolidated row", %{character: char} do
      # Insert 3 minor memories sharing the "patrol" tag
      m1 = insert_minor_memory(char.id, "Walked the east battlement at dawn.", ["patrol", "dawn"], 20)
      m2 = insert_minor_memory(char.id, "Inspected northern sentry post.", ["patrol", "inspection"], 25)
      m3 = insert_minor_memory(char.id, "Noted shifting wind along the southern wall.", ["patrol", "weather"], 15)

      # Ensure they start active
      assert Repo.get(Memory, m1.id).status == "active"
      assert Repo.get(Memory, m2.id).status == "active"
      assert Repo.get(Memory, m3.id).status == "active"

      # Execute synchronous consolidation
      assert {:ok, 1} = MemoryMerger.consolidate_now(char.id)

      # 1. Source memories must be flipped to status: "consolidated"
      m1_fresh = Repo.get(Memory, m1.id)
      m2_fresh = Repo.get(Memory, m2.id)
      m3_fresh = Repo.get(Memory, m3.id)

      assert m1_fresh.status == "consolidated"
      assert m2_fresh.status == "consolidated"
      assert m3_fresh.status == "consolidated"

      assert is_binary(m1_fresh.consolidated_into_id)
      assert m1_fresh.consolidated_into_id == m2_fresh.consolidated_into_id
      assert m2_fresh.consolidated_into_id == m3_fresh.consolidated_into_id

      # 2. Consolidated row exists and has averaged metrics and union of tags
      consolidated = Repo.get(Memory, m1_fresh.consolidated_into_id)
      assert consolidated != nil
      assert consolidated.owner_character_id == char.id
      assert consolidated.status == "active"
      assert consolidated.category == "episodic"
      assert consolidated.details["merged_from_count"] == 3

      # Importance averaged: (20 + 25 + 15) / 3 = 20
      assert consolidated.importance == 20

      # Union of tags
      assert "patrol" in consolidated.tags
      assert "dawn" in consolidated.tags
      assert "inspection" in consolidated.tags
      assert "weather" in consolidated.tags
    end

    test "ignores memories when cluster count is below 3", %{character: char} do
      # Only 2 memories sharing tags
      m1 = insert_minor_memory(char.id, "Saw a bird on the roof.", ["nature"], 10)
      m2 = insert_minor_memory(char.id, "Saw a fox in the yard.", ["nature"], 12)

      assert {:ok, 0} = MemoryMerger.consolidate_now(char.id)

      # Neither memory is consolidated
      assert Repo.get(Memory, m1.id).status == "active"
      assert Repo.get(Memory, m2.id).status == "active"
    end

    test "ignores memories with high importance (>= 40)", %{character: char} do
      # 3 memories, but importance is high (>= 40)
      m1 = insert_minor_memory(char.id, "Crucial treaty signed.", ["politics"], 85)
      m2 = insert_minor_memory(char.id, "War declared.", ["politics"], 95)
      m3 = insert_minor_memory(char.id, "Castle under siege.", ["politics"], 90)

      assert {:ok, 0} = MemoryMerger.consolidate_now(char.id)

      assert Repo.get(Memory, m1.id).status == "active"
      assert Repo.get(Memory, m2.id).status == "active"
      assert Repo.get(Memory, m3.id).status == "active"
    end

    test "gracefully handles LLM provider failure without corrupting active memories", %{character: char} do
      # Insert 3 candidate memories
      m1 = insert_minor_memory(char.id, "Read ancient scroll page 1.", ["scholarship"], 15)
      m2 = insert_minor_memory(char.id, "Read ancient scroll page 2.", ["scholarship"], 15)
      m3 = insert_minor_memory(char.id, "Read ancient scroll page 3.", ["scholarship"], 15)

      # Configure FakeProvider to simulate an upstream provider error
      SovereignSoulEngine.LLM.FakeProvider.set_fixture(:provider_error)

      try do
        # Merger should gracefully absorb error and merge 0 clusters
        assert {:ok, 0} = MemoryMerger.consolidate_now(char.id)

        # Source memories must remain intact and active
        assert Repo.get(Memory, m1.id).status == "active"
        assert Repo.get(Memory, m2.id).status == "active"
        assert Repo.get(Memory, m3.id).status == "active"
        assert Repo.get(Memory, m1.id).consolidated_into_id == nil
      after
        SovereignSoulEngine.LLM.FakeProvider.reset()
      end
    end
  end
end

