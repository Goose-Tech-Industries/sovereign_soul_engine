defmodule SovereignSoulEngine.Souls.SomaticState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "somatic_states" do
    field :hunger, :integer, default: 0
    field :pain, :integer, default: 0
    field :fatigue, :integer, default: 20
    field :illness_severity, :integer, default: 0
    field :last_ate_at, :utc_datetime
    field :last_rested_at, :utc_datetime

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @fields ~w(character_id hunger pain fatigue illness_severity last_ate_at last_rested_at)a

  def changeset(somatic, attrs) do
    somatic
    |> cast(attrs, @fields)
    |> validate_required([:character_id])
    |> validate_number(:hunger, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:pain, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:fatigue, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:illness_severity, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint(:character_id)
  end
end
