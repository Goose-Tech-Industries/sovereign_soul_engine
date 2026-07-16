defmodule SovereignSoulEngine.Scenes.SoulEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "soul_events" do
    field :event_type, :string
    field :intensity, :integer, default: 50
    field :payload, :map, default: %{}
    field :occurred_at, :utc_datetime_usec
    field :correlation_id, :binary_id

    belongs_to :scene, SovereignSoulEngine.Scenes.Scene
    belongs_to :source_character, SovereignSoulEngine.Characters.Character
    belongs_to :target_character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @event_types ~w(
    ally_saved_me healed_me attacked_me gave_item trained_me
    betrayed_me insulted_me praised_me apologized_to_me threatened_me
    protected_me abandoned_me shared_secret lied_to_me
  )

  def changeset(soul_event, attrs) do
    soul_event
    |> cast(attrs, [
      :scene_id,
      :source_character_id,
      :target_character_id,
      :event_type,
      :intensity,
      :payload,
      :occurred_at,
      :correlation_id
    ])
    |> validate_required([:event_type, :occurred_at])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_number(:intensity, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
