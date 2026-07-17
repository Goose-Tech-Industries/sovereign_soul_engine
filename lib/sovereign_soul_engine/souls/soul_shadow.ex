defmodule SovereignSoulEngine.Souls.SoulShadow do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "soul_shadows" do
    field :private_monologue, :string
    field :repressed_motive, :string
    field :active_defense, :string, default: "none"
    field :emotional_drift, :map

    belongs_to :character, SovereignSoulEngine.Characters.Character
    belongs_to :scene, SovereignSoulEngine.Scenes.Scene

    timestamps()
  end

  def changeset(soul_shadow, attrs) do
    soul_shadow
    |> cast(attrs, [
      :character_id,
      :scene_id,
      :private_monologue,
      :repressed_motive,
      :active_defense,
      :emotional_drift
    ])
    |> validate_required([:character_id, :scene_id])
  end
end
