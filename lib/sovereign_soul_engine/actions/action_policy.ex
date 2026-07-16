defmodule SovereignSoulEngine.Actions.ActionPolicy do
  @moduledoc """
  Deterministic policy engine that decides whether proposed actions are legal.

  Validates proposed actions against rules including:
    - Character status (dead/incapacitated)
    - Required capabilities
    - Scene membership (target must be in scene)
    - Fear-driven refusal
    - Attachment-driven protection
    - Action transformation (unsafe actions to safer alternatives)

  Returns `{:ok, status, reason, resolved_action}` or
          `{:error, reason}` where status is `:approved`, `:rejected`, or `:transformed`.
  """

  @action_types ~w(
    observe speak praise insult apologize threaten
    protect assist heal attack leave_room share_secret bargain refuse
    lock_door unlock_door give_item take_item draw_weapon sheathe_weapon
    search_room hide flee sit stand knock open_door close_door
    restrain disarm flee_scene
  )a

  @actions_requiring_capability %{
    heal: [:healing],
    attack: [:combat],
    protect: [:combat, :guard],
    draw_weapon: [:combat],
    disarm: [:combat],
    restrain: [:combat]
  }

  @actions_requiring_alive ~w(
    attack protect heal assist speak threaten insult praise apologize
    bargain share_secret refuse lock_door unlock_door give_item take_item
    draw_weapon sheathe_weapon search_room hide flee sit stand knock
    open_door close_door restrain disarm flee_scene
  )a

  @actions_requiring_target ~w(
    attack protect heal assist praise insult apologize threaten bargain
    share_secret give_item take_item restrain disarm
  )a

  @doc """
  Validates a proposed action.

  Required inputs (keyword list):
    - `:proposed_action` — atom or string, the action being proposed
    - `:character_status` — atom (:active, :inactive, :archived, :dead, :incapacitated)
    - `:target_character_id` — UUID or nil
    - `:scene_participant_ids` — list of character IDs in the scene
    - `:character_capabilities` — list of atoms
    - `:emotional_state` — map with emotional dimensions
    - `:relationship_state` — map with relationship dimensions toward target
  """
  @spec validate(keyword()) ::
          {:ok, :approved | :rejected | :transformed, String.t(), atom()}
          | {:error, String.t()}
  def validate(opts) do
    proposed = normalize_action(Keyword.get(opts, :proposed_action))
    char_status = Keyword.get(opts, :character_status, :active)
    target_id = Keyword.get(opts, :target_character_id)
    scene_ids = Keyword.get(opts, :scene_participant_ids, [])
    capabilities = Keyword.get(opts, :character_capabilities, [])
    emotional_state = Keyword.get(opts, :emotional_state, %{})
    relationship_state = Keyword.get(opts, :relationship_state, %{})

    cond do
      is_nil(proposed) ->
        {:error, "unknown or missing proposed_action"}

      not action_known?(proposed) ->
        {:error, "unknown action type: #{proposed}"}

      true ->
        run_checks(
          proposed,
          char_status,
          target_id,
          scene_ids,
          capabilities,
          emotional_state,
          relationship_state
        )
    end
  end

  defp run_checks(
         action,
         char_status,
         target_id,
         scene_ids,
         capabilities,
         emotional_state,
         relationship_state
       ) do
    checks = [
      fn -> check_always_permitted(action) end,
      fn -> check_character_alive(action, char_status) end,
      fn -> check_target_required(action, target_id) end,
      fn -> check_target_in_scene(target_id, scene_ids) end,
      fn -> check_capability(action, capabilities) end,
      fn -> check_fear_refusal(action, emotional_state) end,
      fn -> check_protection_override(action, emotional_state, relationship_state) end
    ]

    result =
      Enum.reduce_while(checks, nil, fn check_fn, _acc ->
        case check_fn.() do
          nil -> {:cont, nil}
          reason -> {:halt, reason}
        end
      end)

    case result do
      nil -> {:ok, :approved, "Action #{action} approved", action}
      {:rejected, reason} -> {:ok, :rejected, reason, action}
      {:transformed, new_action, reason} -> {:ok, :transformed, reason, new_action}
    end
  end

  defp check_always_permitted(action) when action in [:observe, :speak, :leave_room], do: nil
  defp check_always_permitted(_), do: nil

  defp check_character_alive(action, char_status) when action in @actions_requiring_alive do
    if char_status in [:dead, :incapacitated] do
      {:rejected, "Character is #{char_status}; cannot perform #{action}"}
    end
  end

  defp check_character_alive(_, _), do: nil

  defp check_target_required(action, target_id) when action in @actions_requiring_target do
    if is_nil(target_id) do
      {:rejected, "Action #{action} requires a target but none provided"}
    end
  end

  defp check_target_required(_, _), do: nil

  defp check_target_in_scene(nil, _scene_ids), do: nil

  defp check_target_in_scene(target_id, scene_ids) do
    if target_id not in scene_ids do
      {:rejected, "Target is not in the current scene"}
    end
  end

  defp check_capability(action, capabilities) do
    required = Map.get(@actions_requiring_capability, action, [])
    missing = required -- capabilities

    if missing != [] do
      {:rejected, "Missing required capabilities: #{Enum.join(missing, ", ")}"}
    end
  end

  defp check_fear_refusal(action, emotions) when action in [:attack, :threaten] do
    fear = Map.get(emotions, :fear, 0)

    if fear >= 80 do
      {:transformed, :observe,
       "Overwhelming fear (#{fear}) prevents #{action}; action transformed to observe"}
    end
  end

  defp check_fear_refusal(_, _), do: nil

  defp check_protection_override(action, emotions, relationship)
       when action in [:attack, :threaten] do
    attachment = Map.get(emotions, :attachment, 0)
    gratitude = Map.get(relationship, :gratitude, 0)

    if attachment >= 70 and gratitude >= 50 do
      {:transformed, :protect,
       "High attachment (#{attachment}) and gratitude (#{gratitude}) override #{action}; transformed to protect"}
    end
  end

  defp check_protection_override(_, _, _), do: nil

  defp normalize_action(action) when is_atom(action), do: action
  defp normalize_action(action) when is_binary(action), do: String.to_existing_atom(action)
  defp normalize_action(_), do: nil

  defp action_known?(action), do: action in @action_types
end
