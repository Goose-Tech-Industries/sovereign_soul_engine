defmodule SovereignSoulEngine.Characters.Character do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "characters" do
    field :name, :string
    field :slug, :string
    field :kind, :string, default: "npc"
    field :description, :string
    field :status, :string, default: "inactive"
    field :metadata, :map, default: %{}

    # Which external game owns this identity (e.g. "twisted_paradox") and
    # that game's own id for it. Nil for NPCs and the dev-harness player.
    field :external_source, :string
    field :external_id, :string

    timestamps()
  end

  @kind_values ~w(npc player system creature)

  def changeset(character, attrs) do
    character
    |> cast(attrs, [:name, :slug, :kind, :description, :status, :metadata, :external_source, :external_id])
    |> validate_required([:name, :slug, :kind])
    |> validate_inclusion(:kind, @kind_values)
    |> validate_inclusion(:status, ~w(active inactive archived dead))
    |> unique_constraint(:slug)
    |> unique_constraint([:external_source, :external_id])
  end
end
