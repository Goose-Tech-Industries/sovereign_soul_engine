defmodule SovereignSoulEngine.Memories.MemoryOperationTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.Memories.MemoryOperation

  test "serializes operations for the same owner" do
    parent = self()

    first =
      Task.async(fn ->
        MemoryOperation.with_owner("character-1", fn ->
          send(parent, :first_entered)

          receive do
            :release -> :released
          end
        end)
      end)

    assert_receive :first_entered

    second =
      Task.async(fn ->
        MemoryOperation.with_owner("character-1", fn ->
          send(parent, :second_entered)
          :second_done
        end)
      end)

    refute_receive :second_entered, 50

    send(first.pid, :release)
    assert :released = Task.await(first)
    assert_receive :second_entered, 1_000
    assert :second_done = Task.await(second)
  end

  test "different owners do not share a lock" do
    parent = self()

    first =
      Task.async(fn ->
        MemoryOperation.with_owner("character-2", fn ->
          send(parent, :owner_two_entered)

          receive do
            :release -> :released
          end
        end)
      end)

    assert_receive :owner_two_entered

    second =
      Task.async(fn ->
        MemoryOperation.with_owner("character-3", fn ->
          send(parent, :owner_three_entered)
          :owner_three_done
        end)
      end)

    assert_receive :owner_three_entered
    send(first.pid, :release)
    assert :released = Task.await(first)
    assert :owner_three_done = Task.await(second)
  end
end
