defmodule SovereignSoulEngine.WorldTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.World

  test "ensure_world_scene/0 creates the singleton world scene idempotently" do
    scene1 = World.ensure_world_scene()
    scene2 = World.ensure_world_scene()

    assert scene1.id == scene2.id
    assert scene1.is_autonomous == true
    assert scene1.external_source == "world"
    assert scene1.external_id == "sovereign-society"
    assert scene1.status == "active"
  end

  test "append_event/1 and list_recent_events/1 round-trip" do
    {:ok, event} =
      World.append_event(%{
        kind: "encounter",
        from_did: "did:soul:zaaa",
        to_did: "did:soul:zbbb",
        payload: %{},
        signature: "sig"
      })

    assert event.kind == "encounter"
    assert [%{id: id}] = World.list_recent_events()
    assert id == event.id
  end

  test "append_event/1 rejects an invalid kind" do
    assert {:error, _changeset} = World.append_event(%{kind: "banana"})
  end
end
