defmodule SovereignSoulEngine.Social.NPCSchedulerTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Social.NPCScheduler

  test "reports scheduler state and advances a manual empty-world tick" do
    pid = Process.whereis(NPCScheduler)
    assert is_pid(pid)
    before = NPCScheduler.status()
    assert is_integer(before.tick_count)

    NPCScheduler.trigger_tick()
    _ = :sys.get_state(pid)

    after_tick = NPCScheduler.status()
    assert after_tick.tick_count >= before.tick_count
    assert after_tick.conversations_run >= 0
  end

  test "ignores unexpected messages" do
    pid = Process.whereis(NPCScheduler)
    send(pid, {:unexpected_scheduler_message, self()})
    send(pid, :unexpected_scheduler_atom)
    assert :sys.get_state(pid).tick_count >= 0
  end

  test "processes a direct timer tick and keeps its state contract" do
    pid = Process.whereis(NPCScheduler)
    before = NPCScheduler.status()
    send(pid, :tick)
    after_tick = :sys.get_state(pid)

    assert after_tick.tick_count == before.tick_count + 1
    assert %DateTime{} = after_tick.last_tick_at
    assert is_integer(after_tick.conversations_run)
  end
end
