defmodule SovereignSoulEngine.Scenes.SceneMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "scene_messages" do
    field :message_type, :string, default: "dialogue"
    field :content, :string
    field :private_thought, :string
    field :metadata, :map, default: %{}

    belongs_to :scene, SovereignSoulEngine.Scenes.Scene
    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @message_types ~w(dialogue narrative system_event action)

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :scene_id,
      :character_id,
      :message_type,
      :content,
      :private_thought,
      :metadata
    ])
    |> validate_required([:scene_id, :character_id, :message_type, :content])
    |> validate_inclusion(:message_type, @message_types)
  end
end
