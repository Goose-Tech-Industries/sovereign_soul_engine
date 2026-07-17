defmodule SovereignSoulEngine.Souls.GriefArc do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "grief_arcs" do
    field :subject, :string
    field :loss_type, :string, default: "person"
    field :stage, :string, default: "denial"
    field :intensity, :integer, default: 70
    field :triggered_at, :utc_datetime
    field :last_progressed_at, :utc_datetime
    field :is_resolved, :boolean, default: false

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @valid_stages ~w(denial anger bargaining depression integration)
  @valid_loss_types ~w(person role belief home ability)

  def changeset(arc, attrs) do
    arc
    |> cast(attrs, [:character_id, :subject, :loss_type, :stage, :intensity, :triggered_at, :last_progressed_at, :is_resolved])
    |> validate_required([:character_id, :subject, :triggered_at])
    |> validate_inclusion(:stage, @valid_stages)
    |> validate_inclusion(:loss_type, @valid_loss_types)
    |> validate_number(:intensity, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
