defmodule SovereignSoulEngine.Actions do
  @moduledoc """
  Context for managing Action Intents — proposed, validated, and resolved actions.
  """

  alias SovereignSoulEngine.Actions.ActionIntent
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  def list_action_intents do
    Repo.all(ActionIntent)
  end

  def get_action_intent!(id), do: Repo.get!(ActionIntent, id)

  def list_action_intents_for_scene(scene_id) do
    Repo.all(
      from a in ActionIntent, where: a.scene_id == ^scene_id, order_by: [desc: :inserted_at]
    )
  end

  def list_action_intents_for_character(character_id) do
    Repo.all(
      from a in ActionIntent,
        where: a.character_id == ^character_id,
        order_by: [desc: :inserted_at]
    )
  end

  def list_pending_action_intents_for_character(character_id, action_types) do
    Repo.all(
      from a in ActionIntent,
        where:
          a.character_id == ^character_id and a.proposed_action in ^action_types and
            a.validation_status == "pending",
        order_by: [asc: :inserted_at]
    )
  end

  def create_action_intent(attrs \\ %{}) do
    %ActionIntent{}
    |> ActionIntent.changeset(attrs)
    |> Repo.insert()
  end

  def update_action_intent(%ActionIntent{} = intent, attrs) do
    intent
    |> ActionIntent.changeset(attrs)
    |> Repo.update()
  end

  def change_action_intent(%ActionIntent{} = intent, attrs \\ %{}) do
    ActionIntent.changeset(intent, attrs)
  end
end
