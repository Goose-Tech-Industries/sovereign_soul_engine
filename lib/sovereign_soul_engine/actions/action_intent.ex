defmodule SovereignSoulEngine.Actions.ActionIntent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "action_intents" do
    field :proposed_action, :string
    field :proposed_confidence, :float
    field :proposed_reason, :string
    field :validation_status, :string, default: "pending"
    field :resolved_action, :string
    field :rejection_reason, :string
    field :transformation_reason, :string
    field :consequences, :map, default: %{}
    field :correlation_id, :binary_id

    belongs_to :scene, SovereignSoulEngine.Scenes.Scene
    belongs_to :character, SovereignSoulEngine.Characters.Character
    belongs_to :target_character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @action_types ~w(
    observe speak praise insult apologize threaten
    protect assist heal attack leave_room share_secret bargain refuse
  )
  @validation_statuses ~w(pending approved rejected transformed)

  def changeset(intent, attrs) do
    intent
    |> cast(attrs, [
      :scene_id,
      :character_id,
      :target_character_id,
      :proposed_action,
      :proposed_confidence,
      :proposed_reason,
      :validation_status,
      :resolved_action,
      :rejection_reason,
      :transformation_reason,
      :consequences,
      :correlation_id
    ])
    |> validate_required([:scene_id, :character_id, :proposed_action])
    |> validate_inclusion(:proposed_action, @action_types)
    |> validate_inclusion(:validation_status, @validation_statuses)
  end
end
