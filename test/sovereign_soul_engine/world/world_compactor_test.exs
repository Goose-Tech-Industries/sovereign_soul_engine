defmodule SovereignSoulEngine.World.WorldCompactorTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.World
  alias SovereignSoulEngine.World.WorldCompactor

  test "compacts old events into a summary and marks them compacted" do
    {:ok, _} = World.append_event(%{kind: "gossip", from_did: "did:soul:zaaa", payload: %{}})
    {:ok, _} = World.append_event(%{kind: "gossip", from_did: "did:soul:zbbb", payload: %{}})

    # "before" in the future so everything inserted now counts as old.
    future = DateTime.add(DateTime.utc_now(), 24 * 3600, :second)
    assert WorldCompactor.compact(before: future) == 2

    events = World.list_recent_events(limit: 10)

    assert Enum.any?(events, &(&1.kind == "world_summary"))

    gossips = Enum.filter(events, &(&1.kind == "gossip"))
    assert length(gossips) == 2
    assert Enum.all?(gossips, & &1.compacted)
  end

  test "compacts nothing when there are no old events" do
    {:ok, _} = World.append_event(%{kind: "gossip", from_did: "did:soul:zaaa", payload: %{}})

    past = DateTime.add(DateTime.utc_now(), -60 * 24 * 3600, :second)
    assert WorldCompactor.compact(before: past) == 0
  end
end
