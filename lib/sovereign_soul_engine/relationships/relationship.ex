defmodule SovereignSoulEngine.Relationships.Relationship do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "relationships" do
    field :affinity, :integer, default: 0
    field :trust, :integer, default: 0
    field :respect, :integer, default: 0
    field :fear, :integer, default: 0
    field :anger, :integer, default: 0
    field :gratitude, :integer, default: 0
    field :debt, :integer, default: 0
    field :softening, :integer, default: 0
    field :hardening, :integer, default: 0
    field :wound, :integer, default: 0
    field :relationship_type, :string, default: "acquaintance"
    field :lock_version, :integer, default: 1
    field :last_interaction_at, :utc_datetime_usec

    belongs_to :source_character, SovereignSoulEngine.Characters.Character
    belongs_to :target_character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @dimensions ~w(affinity trust respect fear anger gratitude debt softening hardening wound)a
  @min -100
  @max 100

  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [
      :source_character_id,
      :target_character_id,
      :relationship_type,
      :lock_version,
      :last_interaction_at | @dimensions
    ])
    |> validate_required([:source_character_id, :target_character_id])
    |> validate_dimension_range()
    |> unique_constraint([:source_character_id, :target_character_id])
    |> optimistic_lock(:lock_version)
  end

  defp validate_dimension_range(changeset) do
    Enum.reduce(@dimensions, changeset, fn dim, cs ->
      validate_number(cs, dim, greater_than_or_equal_to: @min, less_than_or_equal_to: @max)
    end)
  end
end
