defmodule SovereignSoulEngine.Souls.ForgivenessArc do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "forgiveness_arcs" do
    field :wound_description, :string
    field :stage, :string, default: "fresh"
    field :intensity, :integer, default: 80
    field :direction, :string, default: "neutral"

    belongs_to :character, SovereignSoulEngine.Characters.Character
    belongs_to :offender_character, SovereignSoulEngine.Characters.Character,
      foreign_key: :offender_character_id

    timestamps()
  end

  @valid_stages ~w(fresh festering processing forgiven hardened)
  @valid_directions ~w(healing hardening neutral)

  def changeset(arc, attrs) do
    arc
    |> cast(attrs, [:character_id, :offender_character_id, :wound_description, :stage, :intensity, :direction])
    |> validate_required([:character_id, :wound_description])
    |> validate_inclusion(:stage, @valid_stages)
    |> validate_inclusion(:direction, @valid_directions)
    |> validate_number(:intensity, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
