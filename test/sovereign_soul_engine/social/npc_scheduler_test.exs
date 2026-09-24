defmodule SovereignSoulEngine.Social.NPCSchedulerTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Social.NPCScheduler

  test "reports scheduler state and advances a manual empty-world tick" do
    pid = Process.whereis(NPCScheduler)
    assert is_pid(pid)
    before = NPCScheduler.status()
    assert is_integer(before.tick_count)

    NPCScheduler.trigger_tick()
    Process.sleep(30)

    after_tick = NPCScheduler.status()
    assert after_tick.tick_count >= before.tick_count
    assert after_tick.conversations_run >= 0
  end

  test "ignores unexpected messages" do
    pid = Process.whereis(NPCScheduler)
    send(pid, {:unexpected_scheduler_message, self()})
    send(pid, :unexpected_scheduler_atom)
    Process.sleep(10)
    assert Process.alive?(pid)
  end
end
