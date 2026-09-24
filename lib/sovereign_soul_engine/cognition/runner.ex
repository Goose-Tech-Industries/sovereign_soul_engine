defmodule SovereignSoulEngine.Cognition.Runner do
  @moduledoc "Runs a small, durable cognition workflow with checkpointed steps."

  alias SovereignSoulEngine.Cognition.Checkpoints

  @type step :: (map() -> {:ok, map()} | {:pause, map(), map()} | {:error, term()})

  @doc "Runs steps from the latest checkpoint, persisting state before and after every step."
  def run(character_id, thread_id, steps, opts \\ [])
      when is_binary(character_id) and is_binary(thread_id) and is_list(steps) do
    checkpoint = Checkpoints.latest(character_id, thread_id)
    state = if checkpoint, do: checkpoint.state, else: Keyword.get(opts, :state, %{})
    start_index = if checkpoint, do: Map.get(checkpoint.metadata, "next_step", 0), else: 0

    run_steps(character_id, thread_id, steps, start_index, state, opts)
  end

  defp run_steps(character_id, thread_id, steps, index, state, _opts)
       when index >= length(steps) do
    {:ok, _checkpoint} = persist(character_id, thread_id, state, index, "completed", %{})
    {:ok, state}
  end

  defp run_steps(character_id, thread_id, steps, index, state, opts) do
    if Keyword.get(opts, :cancelled?, fn -> false end).() do
      persist(character_id, thread_id, state, index, "cancelled", %{})
      {:error, :cancelled}
    else
      step = Enum.at(steps, index)

      case step.(state) do
        {:ok, next_state} when is_map(next_state) ->
          persist(character_id, thread_id, next_state, index + 1, "running", %{})
          run_steps(character_id, thread_id, steps, index + 1, next_state, opts)

        {:pause, next_state, interrupt} when is_map(next_state) and is_map(interrupt) ->
          persist(character_id, thread_id, next_state, index + 1, "interrupted", interrupt)
          {:paused, next_state}

        {:error, reason} ->
          persist(character_id, thread_id, state, index, "failed", %{reason: inspect(reason)})
          {:error, reason}

        other ->
          persist(character_id, thread_id, state, index, "failed", %{reason: inspect(other)})
          {:error, {:invalid_step_result, other}}
      end
    end
  end

  defp persist(character_id, thread_id, state, next_step, status, interrupt) do
    Checkpoints.create(%{
      character_id: character_id,
      thread_id: thread_id,
      state: state,
      interrupt: interrupt,
      metadata: %{"next_step" => next_step},
      status: status
    })
  end
end
