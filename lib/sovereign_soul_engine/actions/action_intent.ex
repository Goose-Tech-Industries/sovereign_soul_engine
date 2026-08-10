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
    none observe speak praise insult apologize threaten
    protect assist heal attack leave_room share_secret bargain refuse
    lock_door unlock_door give_item take_item draw_weapon sheathe_weapon
    search_room hide flee flee_scene sit stand knock open_door close_door
    restrain disarm join_player leave_player
  )
  @validation_statuses ~w(pending approved rejected transformed)

  @doc "The exact set of valid action types — the LLM boundary (Generator) validates against this before ever building a changeset."
  def action_types, do: @action_types

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
