defmodule SovereignSoulEngine.Cognition.RunnerTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Cognition.{Checkpoints, Runner}

  setup do
    {:ok, character} =
      Characters.create_character(%{name: "Runner Test", slug: "runner-test", status: "active"})

    %{character: character}
  end

  test "checkpoints each step and resumes after an interruption", %{character: character} do
    steps = [
      fn state -> {:ok, Map.update(state, "count", 1, &(&1 + 1))} end,
      fn state -> {:pause, Map.put(state, "paused", true), %{reason: "awaiting approval"}} end,
      fn state -> {:ok, Map.put(state, "finished", true)} end
    ]

    assert {:paused, %{"count" => 1, "paused" => true}} =
             Runner.run(character.id, "runner-thread", steps, state: %{"count" => 0})

    assert {:ok, %{"count" => 1, "paused" => true, "finished" => true}} =
             Runner.run(character.id, "runner-thread", steps)

    assert Checkpoints.latest(character.id, "runner-thread").status == "completed"
  end

  test "cancellation leaves a durable cancelled checkpoint", %{character: character} do
    assert {:error, :cancelled} =
             Runner.run(character.id, "cancel-thread", [fn state -> {:ok, state} end],
               cancelled?: fn -> true end
             )

    assert Checkpoints.latest(character.id, "cancel-thread").status == "cancelled"
  end
end
