defmodule SovereignSoulEngine.Cognition.Checkpoint do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "cognition_checkpoints" do
    field :thread_id, :string
    field :version, :integer, default: 1
    field :status, :string, default: "paused"
    field :state, :map, default: %{}
    field :pending_tasks, :map, default: %{}
    field :interrupt, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :character, SovereignSoulEngine.Characters.Character
    belongs_to :parent_checkpoint, __MODULE__

    timestamps(type: :utc_datetime_usec)
  end

  @statuses ~w(paused running interrupted completed failed cancelled)

  def changeset(checkpoint, attrs) do
    checkpoint
    |> cast(attrs, [
      :character_id,
      :parent_checkpoint_id,
      :thread_id,
      :version,
      :status,
      :state,
      :pending_tasks,
      :interrupt,
      :metadata
    ])
    |> validate_required([:character_id, :thread_id, :state])
    |> validate_number(:version, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
  end
end
