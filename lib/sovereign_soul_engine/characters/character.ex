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

    timestamps()
  end

  @kind_values ~w(npc player system creature)

  def changeset(character, attrs) do
    character
    |> cast(attrs, [:name, :slug, :kind, :description, :status, :metadata])
    |> validate_required([:name, :slug, :kind])
    |> validate_inclusion(:kind, @kind_values)
    |> validate_inclusion(:status, ~w(active inactive archived))
    |> unique_constraint(:slug)
  end
end
