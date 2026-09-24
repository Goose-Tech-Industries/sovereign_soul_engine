defmodule SovereignSoulEngine.Cognition.CheckpointsAndApprovalsTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Cognition.{Approvals, Checkpoints}

  setup do
    {:ok, character} =
      Characters.create_character(%{
        name: "Checkpoint Test",
        slug: "checkpoint-test",
        status: "active"
      })

    %{character: character}
  end

  test "checkpoints version and resume by thread", %{character: character} do
    assert {:ok, first} =
             Checkpoints.create(%{
               character_id: character.id,
               thread_id: "thread-1",
               state: %{step: 1}
             })

    assert first.version == 1
    assert {:ok, resumed} = Checkpoints.resume(first)
    assert resumed.status == "running"

    assert {:error, :not_resumable} = Checkpoints.resume(resumed)

    assert {:ok, second} =
             Checkpoints.create(%{
               character_id: character.id,
               thread_id: "thread-1",
               state: %{step: 2}
             })

    assert second.version == 2
    assert Checkpoints.latest(character.id, "thread-1").id == second.id
  end

  test "resume_latest and cancel preserve durable thread control", %{character: character} do
    assert {:ok, checkpoint} =
             Checkpoints.create(%{
               character_id: character.id,
               thread_id: "control-thread",
               state: %{step: 4},
               status: "interrupted"
             })

    assert {:ok, resumed} = Checkpoints.resume_latest(character.id, "control-thread")
    assert resumed.id == checkpoint.id
    assert resumed.status == "running"

    assert {:ok, cancelled} = Checkpoints.cancel(resumed, "operator stopped the run")
    assert cancelled.status == "cancelled"
    assert cancelled.interrupt["reason"] == "operator stopped the run"
    assert {:error, :not_resumable} = Checkpoints.resume_latest(character.id, "control-thread")
  end

  test "approval decisions are terminal", %{character: character} do
    assert {:ok, request} =
             Approvals.create(%{
               character_id: character.id,
               operation: "send_message",
               payload: %{recipient: "user"}
             })

    assert {:ok, approved} = Approvals.decide(request, "approved", %{decided_by: "rob"})
    assert approved.status == "approved"
    assert {:error, :already_decided} = Approvals.decide(approved, "rejected")
  end
end
