defmodule SovereignSoulEngine.Scenes.SceneParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "scene_participants" do
    field :joined_at, :utc_datetime_usec

    belongs_to :scene, SovereignSoulEngine.Scenes.Scene
    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:scene_id, :character_id, :joined_at])
    |> validate_required([:scene_id, :character_id])
    |> unique_constraint([:scene_id, :character_id])
  end
end
