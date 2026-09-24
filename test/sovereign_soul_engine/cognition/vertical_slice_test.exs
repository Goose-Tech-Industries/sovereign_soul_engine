defmodule SovereignSoulEngine.Cognition.VerticalSliceTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Actions
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Cognition.VerticalSlice
  alias SovereignSoulEngine.Ledger
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Scenes

  test "connects lore, supersession, checkpointing, approval, and execution" do
    {:ok, character} =
      Characters.create_character(%{name: "Slice NPC", slug: "slice-npc", status: "active"})

    {:ok, scene} = Scenes.create_scene(%{title: "Slice Scene", status: "active"})

    {:ok, old_memory} =
      Memories.create_memory(%{
        owner_character_id: character.id,
        category: "episodic",
        summary: "The Crow's Keep is closed.",
        occurred_at: ~U[2026-09-24 12:00:00Z]
      })

    assert {:ok, result} =
             VerticalSlice.run(character.id, scene.id,
               message: "We should speak with the guards at the Crow's Keep.",
               district: "crows_keep",
               memory: old_memory,
               new_fact: %{summary: "The Crow's Keep reopened at dusk."},
               thread_id: "slice-thread"
             )

    assert Enum.any?(result.lore, &(&1.slug == "crows_keep"))
    assert result.checkpoint.status == "completed"
    assert result.action.intent.validation_status == "pending"
    assert result.action.approval.status == "pending"
    assert result.memory.new_memory.status == "active"

    assert {:ok, %{intent: approved}} =
             Actions.decide_approval(result.action.approval.id, "approved", %{
               decided_by: "tester"
             })

    assert {:ok, executed} =
             Actions.execute_approved(result.action.approval.id, fn _intent ->
               {:ok, %{"delivered" => true}}
             end)

    assert approved.id == executed.id
    assert executed.consequences["execution_status"] == "completed"

    assert Enum.any?(
             Ledger.list_entries_for_character(character.id),
             &(&1.entry_type == "fact_superseded")
           )
  end
end
