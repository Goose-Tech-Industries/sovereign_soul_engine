defmodule SovereignSoulEngine.Actions.ActionApprovalTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Actions
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Scenes

  setup do
    {:ok, character} =
      Characters.create_character(%{
        name: "Action Test",
        slug: "action-approval-test",
        status: "active"
      })

    {:ok, scene} = Scenes.create_scene(%{title: "Approval Scene", status: "active"})
    %{character: character, scene: scene}
  end

  test "policy-approved external actions wait for explicit approval", %{
    character: character,
    scene: scene
  } do
    assert {:ok, %{intent: intent, approval: approval}} =
             Actions.propose_action(
               %{character_id: character.id, scene_id: scene.id, proposed_action: "speak"},
               [proposed_action: :speak, character_status: :active],
               requires_approval: true,
               requested_by: "test"
             )

    assert intent.validation_status == "pending"
    assert approval.status == "pending"

    assert {:ok, %{intent: approved}} =
             Actions.decide_approval(approval.id, "approved", %{decided_by: "rob"})

    assert approved.validation_status == "approved"

    assert {:ok, executed} =
             Actions.execute_approved(approval.id, fn _intent -> {:ok, %{sent: true}} end)

    assert executed.consequences["execution_status"] == "completed"
  end

  test "external execution reports are idempotent", %{character: character, scene: scene} do
    {:ok, %{approval: approval}} =
      Actions.propose_action(
        %{character_id: character.id, scene_id: scene.id, proposed_action: "speak"},
        [proposed_action: :speak, character_status: :active],
        requires_approval: true
      )

    {:ok, _} = Actions.decide_approval(approval.id, "approved")

    assert {:ok, first} =
             Actions.record_external_execution(approval.id, "event-123", "completed", %{
               "ok" => true
             })

    assert {:ok, second} =
             Actions.record_external_execution(approval.id, "event-123", "completed", %{
               "ok" => true
             })

    assert first.id == second.id

    assert {:error, :already_executed} =
             Actions.record_external_execution(approval.id, "event-456", "completed", %{})
  end
end
