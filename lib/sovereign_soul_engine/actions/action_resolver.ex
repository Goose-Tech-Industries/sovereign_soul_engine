defmodule SovereignSoulEngine.Actions.ActionResolver do
  @moduledoc """
  Resolves proposed actions through the policy engine and produces
  an updated ActionIntent with validation results.

  This module combines ActionPolicy validation with state construction
  for the ActionIntent schema.
  """

  alias SovereignSoulEngine.Actions.ActionPolicy

  @doc """
  Resolves a proposed action through the policy engine.

  Takes the action intent context and produces a resolution map.

  Returns `{:ok, resolution_map}` where the map contains:
    - `:validation_status` — "approved", "rejected", or "transformed"
    - `:resolved_action` — the final action
    - `:rejection_reason` — set if rejected
    - `:transformation_reason` — set if transformed
    - `:proposed_confidence` — passed through
    - `:proposed_reason` — passed through
    - `:proposed_action` — the original proposal
  """
  @spec resolve(keyword()) :: {:ok, map()} | {:error, String.t()}
  def resolve(opts) do
    proposed_action = Keyword.get(opts, :proposed_action)
    character_status = Keyword.get(opts, :character_status, :active)
    target_id = Keyword.get(opts, :target_character_id)
    scene_ids = Keyword.get(opts, :scene_participant_ids, [])
    capabilities = Keyword.get(opts, :character_capabilities, [])
    emotional_state = Keyword.get(opts, :emotional_state, %{})
    relationship_state = Keyword.get(opts, :relationship_state, %{})
    proposed_confidence = Keyword.get(opts, :proposed_confidence)
    proposed_reason = Keyword.get(opts, :proposed_reason)

    case ActionPolicy.validate(
           proposed_action: proposed_action,
           character_status: character_status,
           target_character_id: target_id,
           scene_participant_ids: scene_ids,
           character_capabilities: capabilities,
           emotional_state: emotional_state,
           relationship_state: relationship_state
         ) do
      {:ok, status, reason, resolved_action} ->
        resolution =
          %{
            proposed_action: proposed_action,
            validation_status: status,
            resolved_action: resolved_action,
            rejection_reason: nil,
            transformation_reason: nil,
            proposed_confidence: proposed_confidence,
            proposed_reason: proposed_reason
          }
          |> set_reason(status, reason)

        {:ok, resolution}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Same as resolve/1 but returns the map directly or raises on error.
  """
  @spec resolve!(keyword()) :: map()
  def resolve!(opts) do
    case resolve(opts) do
      {:ok, resolution} -> resolution
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp set_reason(map, :rejected, reason), do: %{map | rejection_reason: reason}
  defp set_reason(map, :transformed, reason), do: %{map | transformation_reason: reason}
  defp set_reason(map, :approved, _reason), do: map
end
