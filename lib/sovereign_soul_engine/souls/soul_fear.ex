defmodule SovereignSoulEngine.Souls.SoulFear do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "soul_fears" do
    field :fear_type, :string
    field :severity, :integer, default: 50
    field :origin, :string, default: "baked_in"
    field :status, :string, default: "active"

    belongs_to :character, SovereignSoulEngine.Characters.Character

    belongs_to :acquired_in_scene, SovereignSoulEngine.Scenes.Scene,
      foreign_key: :acquired_in_scene_id

    timestamps()
  end

  def changeset(soul_fear, attrs) do
    soul_fear
    |> cast(attrs, [:character_id, :fear_type, :severity, :origin, :status, :acquired_in_scene_id])
    |> validate_required([:character_id, :fear_type])
    |> validate_number(:severity, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:status, ["active", "suppressed", "resolved"])
    |> validate_inclusion(:origin, ["baked_in", "acquired"])
  end
end
