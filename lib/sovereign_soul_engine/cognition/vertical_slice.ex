defmodule SovereignSoulEngine.Cognition.VerticalSlice do
  @moduledoc "Reference end-to-end path connecting lore, memory, checkpoints, policy, and approval."

  alias SovereignSoulEngine.Actions
  alias SovereignSoulEngine.Cognition.Runner
  alias SovereignSoulEngine.Cognition.Checkpoints
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.World.Lorebook

  @doc """
  Runs the canonical SSE NPC turn without executing an external side effect.

  The return value contains the activated lore, checkpoint, optional superseded
  fact lineage, and a pending approval request. The caller must explicitly
  decide and execute the action through `Actions.decide_approval/3` and
  `Actions.execute_approved/2`.
  """
  def run(character_id, scene_id, opts \\ [])
      when is_binary(character_id) and is_binary(scene_id) do
    message = Keyword.fetch!(opts, :message)
    district = Keyword.get(opts, :district)
    thread_id = Keyword.get(opts, :thread_id, "vertical-slice:" <> Ecto.UUID.generate())
    lore = Lorebook.scan_and_activate(message, current_district: district)

    with {:ok, memory_result} <- maybe_supersede_memory(Keyword.get(opts, :memory), opts),
         {:ok, checkpoint_state} <-
           checkpoint_context(character_id, thread_id, message, district, lore),
         {:ok, action} <- propose_action(character_id, scene_id, message, opts) do
      {:ok,
       %{
         thread_id: thread_id,
         lore: lore,
         memory: memory_result,
         checkpoint: Checkpoints.latest(character_id, thread_id),
         checkpoint_state: checkpoint_state,
         action: action
       }}
    end
  end

  defp maybe_supersede_memory(nil, _opts), do: {:ok, nil}

  defp maybe_supersede_memory(memory, opts) do
    new_fact = Keyword.fetch!(opts, :new_fact)

    case Memories.supersede_memory(memory, new_fact,
           reason: Keyword.get(opts, :supersession_reason, "new scene evidence"),
           source: "vertical_slice",
           source_type: Keyword.get(opts, :source_type, :witnessed)
         ) do
      {:ok, result} -> {:ok, result}
      error -> error
    end
  end

  defp checkpoint_context(character_id, thread_id, message, district, lore) do
    steps = [
      fn _state ->
        {:ok,
         %{
           "message" => message,
           "district" => district,
           "lore_slugs" => Enum.map(lore, & &1.slug),
           "phase" => "context_collected"
         }}
      end
    ]

    Runner.run(character_id, thread_id, steps, state: %{})
  end

  defp propose_action(character_id, scene_id, message, opts) do
    action = Keyword.get(opts, :action, "speak")
    action_atom = if is_atom(action), do: action, else: String.to_existing_atom(action)

    Actions.propose_action(
      %{character_id: character_id, scene_id: scene_id, proposed_action: action},
      [
        proposed_action: action_atom,
        character_status: :active,
        proposed_reason: message,
        proposed_confidence: Keyword.get(opts, :confidence, 1.0)
      ],
      requires_approval: true,
      requested_by: "vertical_slice"
    )
  end
end
