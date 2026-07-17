defmodule SovereignSoulEngine.Triggers.CharacterTrigger do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "character_triggers" do
    field :topic, :string
    field :reaction_type, :string
    field :intensity_modifier, :integer, default: 0
    field :flavor_text, :string

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @valid_reaction_types ~w(anger_spike fear_spike grief_spike pride_surge shame_trigger)

  def changeset(trigger, attrs) do
    trigger
    |> cast(attrs, [
      :character_id,
      :topic,
      :reaction_type,
      :intensity_modifier,
      :flavor_text
    ])
    |> validate_required([:character_id, :topic, :reaction_type])
    |> validate_inclusion(:reaction_type, @valid_reaction_types)
  end
end
