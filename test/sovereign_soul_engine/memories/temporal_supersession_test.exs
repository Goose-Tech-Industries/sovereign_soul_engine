defmodule SovereignSoulEngine.Memories.TemporalSupersessionTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Memories.{Memory, MemoryRetrieval}
  alias SovereignSoulEngine.Characters

  setup do
    {:ok, char} =
      Characters.create_character(%{
        name: "Lachlan the Chronicler",
        slug: "lachlan_#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active",
        description:
          "An ancient highland archivist recording the shifting truths of Gleann Caorach."
      })

    %{character: char}
  end

  describe "Memory temporal schema accessors" do
    test "accessors read from metadata correctly" do
      t_from = ~U[2026-01-01 00:00:00Z]
      t_until = ~U[2026-06-01 00:00:00Z]
      parent_id = Ecto.UUID.generate()
      child_id = Ecto.UUID.generate()

      mem = %Memory{
        status: "superseded",
        occurred_at: t_from,
        metadata: %{
          "valid_from" => DateTime.to_iso8601(t_from),
          "valid_until" => DateTime.to_iso8601(t_until),
          "supersedes_id" => parent_id,
          "superseded_by_id" => child_id,
          "provenance" => %{"source_type" => "witnessed", "confidence" => 95}
        }
      }

      assert Memory.superseded?(mem) == true
      assert Memory.valid_until(mem) == DateTime.to_iso8601(t_until)
      assert Memory.supersedes_id(mem) == parent_id
      assert Memory.superseded_by_id(mem) == child_id
      assert Memory.provenance(mem)["source_type"] == "witnessed"
    end
  end

  describe "Memories.supersede_memory/3" do
    test "atomically supersedes an old memory and establishes lineage", %{character: char} do
      t0 = ~U[2026-05-01 10:00:00Z]

      {:ok, original} =
        Memories.create_memory(%{
          owner_character_id: char.id,
          category: "belief",
          summary: "The Crow's Keep is impregnable and guarded by the Royal Raven Garrison.",
          importance: 80,
          occurred_at: t0,
          status: "active"
        })

      t1 = ~U[2026-07-15 14:30:00Z]

      {:ok, %{old_memory: updated_old, new_memory: new_mem}} =
        Memories.supersede_memory(
          original,
          %{
            summary:
              "The Crow's Keep was breached through the forgotten catacombs during the solstice raid.",
            importance: 90
          },
          reason: "Catacomb breach witnessed during raid",
          source_type: :witnessed,
          timestamp: t1
        )

      # Old memory is superseded with validity window closed
      assert updated_old.status == "superseded"
      assert Memory.superseded?(updated_old)
      assert updated_old.metadata["superseded_by_id"] == new_mem.id
      assert updated_old.metadata["valid_until"] == DateTime.to_iso8601(t1)
      assert updated_old.metadata["supersession_reason"] =~ "breach witnessed"

      # New memory is active with provenance and backward link
      assert new_mem.status == "active"
      assert new_mem.metadata["supersedes_id"] == original.id
      assert new_mem.metadata["valid_from"] == DateTime.to_iso8601(t1)
      assert new_mem.metadata["provenance"]["source_type"] == "witnessed"
      assert new_mem.summary =~ "breached through the forgotten catacombs"

      # Verify active character memory list excludes superseded
      active_mems = Memories.list_memories_for_character(char.id)
      assert length(active_mems) == 1
      assert hd(active_mems).id == new_mem.id

      # Verify superseded memory list returns it
      superseded_list = Memories.list_superseded_memories(char.id)
      assert length(superseded_list) == 1
      assert hd(superseded_list).id == original.id
    end
  end

  describe "Memories.get_fact_history/1" do
    test "walks the entire lineage chain across multiple supersessions", %{character: char} do
      t0 = ~U[2026-01-01 00:00:00Z]
      t1 = ~U[2026-03-01 00:00:00Z]
      t2 = ~U[2026-06-01 00:00:00Z]

      {:ok, v1} =
        Memories.create_memory(%{
          owner_character_id: char.id,
          category: "episodic",
          summary: "Eldred is the beloved Mayor of Feannag's Rest.",
          importance: 70,
          occurred_at: t0,
          status: "active"
        })

      {:ok, %{new_memory: v2}} =
        Memories.supersede_memory(
          v1,
          %{summary: "Eldred was arrested on charges of treason and smuggling."},
          reason: "Guard raid uncovered contraband",
          timestamp: t1
        )

      {:ok, %{new_memory: v3}} =
        Memories.supersede_memory(
          v2,
          %{summary: "Eldred escaped the dungeons and now leads the Shadowgate insurgents."},
          reason: "Prison break reported by sentries",
          timestamp: t2
        )

      # Walk history from the middle version (v2)
      history_from_v2 = Memories.get_fact_history(v2)
      assert length(history_from_v2) == 3
      assert Enum.map(history_from_v2, & &1.id) == [v1.id, v2.id, v3.id]

      # Walk history from the latest active version (v3)
      history_from_v3 = Memories.get_fact_history(v3.id)
      assert length(history_from_v3) == 3
      assert Enum.map(history_from_v3, & &1.id) == [v1.id, v2.id, v3.id]
    end
  end

  describe "Memories.list_memories_as_of/3 (Graphiti Temporal Query)" do
    test "correctly queries what was believed at past points in time", %{character: char} do
      t0 = ~U[2026-02-01 00:00:00Z]
      t_superseded = ~U[2026-05-01 00:00:00Z]

      {:ok, original} =
        Memories.create_memory(%{
          owner_character_id: char.id,
          category: "belief",
          summary: "The Old Bridge across the gorge is sturdy and well-guarded.",
          importance: 75,
          occurred_at: t0,
          status: "active"
        })

      {:ok, %{new_memory: replacement}} =
        Memories.supersede_memory(
          original,
          %{summary: "The Old Bridge collapsed in the spring flood and is impassable."},
          reason: "Flood destruction",
          timestamp: t_superseded
        )

      # Query at T = April 2026 (Before the flood): The old bridge belief is returned!
      t_before = ~U[2026-04-01 00:00:00Z]
      memories_in_april = Memories.list_memories_as_of(char.id, t_before)
      assert length(memories_in_april) == 1
      assert hd(memories_in_april).id == original.id
      assert hd(memories_in_april).summary =~ "sturdy and well-guarded"

      # Query at T = June 2026 (After the flood): The new bridge belief is returned!
      t_after = ~U[2026-06-01 00:00:00Z]
      memories_in_june = Memories.list_memories_as_of(char.id, t_after)
      assert length(memories_in_june) == 1
      assert hd(memories_in_june).id == replacement.id
      assert hd(memories_in_june).summary =~ "collapsed in the spring flood"
    end
  end

  describe "MemoryRetrieval.format_memory_line/1 formatting" do
    test "formats active, updated, and superseded memories with distinct contrast tags" do
      active_regular = %Memory{
        summary: "I enjoy foraging heather in the high barrows.",
        valence: 0.4,
        status: "active",
        metadata: %{}
      }

      assert MemoryRetrieval.format_memory_line(active_regular) ==
               "- I enjoy foraging heather in the high barrows. (Valence: 0.4)"

      active_updated = %Memory{
        summary: "The high barrows are now stalked by shadow wolves.",
        valence: -0.8,
        status: "active",
        metadata: %{"supersedes_id" => Ecto.UUID.generate()}
      }

      assert MemoryRetrieval.format_memory_line(active_updated) =~ "(Valence: -0.8, updated fact)"

      superseded = %Memory{
        summary: "I enjoy foraging heather in the high barrows.",
        valence: 0.4,
        status: "superseded",
        metadata: %{"valid_until" => "2026-08-12T00:00:00Z"}
      }

      line = MemoryRetrieval.format_memory_line(superseded)
      assert line =~ "[HISTORICAL CONTEXT - formerly believed until 2026-08-12T00:00:00Z]"
      assert line =~ "I enjoy foraging heather"
    end
  end
end
