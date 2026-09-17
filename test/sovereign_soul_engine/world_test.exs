defmodule SovereignSoulEngine.WorldTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.World
  alias SovereignSoulEngine.World.WorldCompactor

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

  test "feed/0 summarizes the world" do
    World.seed_souls()

    {:ok, _} =
      World.append_event(%{
        kind: "encounter",
        from_did: "did:soul:zaaa",
        to_did: "did:soul:zbbb",
        payload: %{},
        signature: "sig"
      })

    feed = World.feed()

    assert feed.scene_id == World.world_scene().id
    assert feed.souls == 50
    assert is_integer(feed.relationships)
    assert [%{kind: "encounter", from: "did:soul:zaaa"} | _] = feed.recent_events
  end

  test "world_souls/0 returns the seeded population" do
    World.seed_souls()
    assert length(World.world_souls()) == 50
  end

  test "compaction then purge leaves only the summary" do
    World.append_event(%{kind: "gossip", from_did: "did:soul:zaaa", payload: %{}})
    World.append_event(%{kind: "gossip", from_did: "did:soul:zbbb", payload: %{}})

    future = DateTime.add(DateTime.utc_now(), 3600, :second)

    assert WorldCompactor.compact(before: future) == 2
    assert World.purge_events(future) == 2

    assert [%{kind: "world_summary"}] = World.list_recent_events()
  end
end
