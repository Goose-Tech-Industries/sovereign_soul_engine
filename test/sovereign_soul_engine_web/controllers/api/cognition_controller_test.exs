defmodule SovereignSoulEngineWeb.Api.CognitionControllerTest do
  use SovereignSoulEngineWeb.ConnCase, async: false

  alias SovereignSoulEngine.Actions
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Scenes

  setup %{conn: conn} do
    {:ok, character} =
      Characters.create_character(%{
        name: "Cognition API NPC",
        slug: "cognition-api-#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active",
        external_source: "twisted"
      })

    {:ok, scene} = Scenes.create_scene(%{title: "Cognition API Scene", status: "active"})

    %{conn: authenticate_api(conn), character: character, scene: scene}
  end

  defp approval_fixture(character, scene) do
    {:ok, %{approval: approval}} =
      Actions.propose_action(
        %{character_id: character.id, scene_id: scene.id, proposed_action: "speak"},
        [proposed_action: :speak, character_status: :active],
        requires_approval: true,
        requested_by: "api-test"
      )

    approval
  end

  test "lists, approves, and rejects tenant-scoped approvals", %{
    conn: conn,
    character: character,
    scene: scene
  } do
    approval = approval_fixture(character, scene)

    listed = get(conn, ~p"/sse/api/cognition/approvals?character_id=#{character.id}")
    assert Enum.any?(json_response(listed, 200)["approvals"], &(&1["id"] == approval.id))

    approved =
      post(conn, ~p"/sse/api/cognition/approvals/#{approval.id}/approve", %{
        "decided_by" => "api-reviewer"
      })

    assert json_response(approved, 200)["approval"]["status"] == "approved"

    rejected_approval = approval_fixture(character, scene)

    rejected =
      post(conn, ~p"/sse/api/cognition/approvals/#{rejected_approval.id}/reject", %{
        "reason" => "policy test"
      })

    assert json_response(rejected, 200)["approval"]["status"] == "rejected"
  end

  test "records an external execution once and rejects duplicate keys", %{
    conn: conn,
    character: character,
    scene: scene
  } do
    approval = approval_fixture(character, scene)
    post(conn, ~p"/sse/api/cognition/approvals/#{approval.id}/approve", %{})

    first =
      post(conn, ~p"/sse/api/cognition/approvals/#{approval.id}/execute", %{
        "execution_key" => "twisted-event-1",
        "status" => "completed",
        "result" => %{"delivered" => true}
      })

    assert json_response(first, 200)["approval"]["execution_status"] == "completed"

    duplicate =
      post(conn, ~p"/sse/api/cognition/approvals/#{approval.id}/execute", %{
        "execution_key" => "twisted-event-2",
        "status" => "completed"
      })

    assert json_response(duplicate, 409)["error"] == "already executed"
  end

  test "branches expose alternate messages without changing canonical history", %{
    conn: conn,
    character: character,
    scene: scene
  } do
    {:ok, fork_message} =
      Scenes.create_message(%{
        scene_id: scene.id,
        character_id: character.id,
        content: "The gate opens.",
        message_type: "dialogue"
      })

    created =
      post(conn, ~p"/sse/api/cognition/branches", %{
        "character_id" => character.id,
        "scene_id" => scene.id,
        "message_id" => fork_message.id,
        "branch_id" => "api-branch"
      })

    assert json_response(created, 200)["branch_id"] == "api-branch"

    appended =
      post(conn, ~p"/sse/api/cognition/branches/#{scene.id}/api-branch/messages", %{
        "character_id" => character.id,
        "fork_message_id" => fork_message.id,
        "content" => "The guard lowers the drawbridge."
      })

    assert json_response(appended, 200)["message"]["metadata"]["branch_id"] == "api-branch"

    shown =
      get(
        conn,
        ~p"/sse/api/cognition/branches/#{scene.id}/api-branch?character_id=#{character.id}"
      )

    assert Enum.map(json_response(shown, 200)["messages"], & &1["content"]) == [
             "The gate opens.",
             "The guard lowers the drawbridge."
           ]

    discarded =
      delete(
        conn,
        ~p"/sse/api/cognition/branches/#{scene.id}/api-branch?character_id=#{character.id}"
      )

    assert json_response(discarded, 200)["status"] == "discarded"
    assert length(Scenes.list_messages(scene.id)) == 1
  end
end
