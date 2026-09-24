defmodule SovereignSoulEngine.Memories.MemoryAuditTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Ledger
  alias SovereignSoulEngine.Memories

  setup do
    {:ok, character} =
      Characters.create_character(%{
        name: "Memory Test",
        slug: "memory-audit-test",
        status: "active"
      })

    {:ok, memory} =
      Memories.create_memory(%{
        owner_character_id: character.id,
        category: "episodic",
        summary: "Original event",
        occurred_at: DateTime.utc_now()
      })

    %{character: character, memory: memory}
  end

  test "correction and export leave a ledger trail", %{character: character, memory: memory} do
    assert {:ok, corrected} = Memories.correct_memory(memory, %{summary: "Corrected event"})
    assert corrected.summary == "Corrected event"
    assert {:ok, [exported]} = Memories.export_memories_for_character(character.id)
    assert exported.id == corrected.id

    entries = Ledger.list_entries_for_character(character.id)
    assert Enum.any?(entries, &(&1.entry_type == "memory_corrected"))
    assert Enum.any?(entries, &(&1.entry_type == "memory_exported"))
  end

  test "deletion is audited before the row is removed", %{character: character, memory: memory} do
    assert {:ok, deleted} = Memories.delete_memory(memory, reason: "user requested deletion")
    assert deleted.id == memory.id
    assert Memories.list_memories_for_character(character.id) == []

    assert [%{entry_type: "memory_deleted", reason: "user requested deletion"}] =
             Ledger.list_entries_for_character(character.id)
  end
end
