defmodule SovereignSoulEngine.Scenes.Scene do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "scenes" do
    field :title, :string
    field :status, :string, default: "pending"
    field :location, :string
    field :context, :map, default: %{}
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :metadata, :map, default: %{}

    has_many :participants, SovereignSoulEngine.Scenes.SceneParticipant
    has_many :messages, SovereignSoulEngine.Scenes.SceneMessage
    has_many :soul_events, SovereignSoulEngine.Scenes.SoulEvent
    has_many :action_intents, SovereignSoulEngine.Actions.ActionIntent

    timestamps()
  end

  @status_values ~w(pending active paused completed cancelled)

  def changeset(scene, attrs) do
    scene
    |> cast(attrs, [:title, :status, :location, :context, :started_at, :ended_at, :metadata])
    |> validate_required([:title, :status])
    |> validate_inclusion(:status, @status_values)
  end
end
