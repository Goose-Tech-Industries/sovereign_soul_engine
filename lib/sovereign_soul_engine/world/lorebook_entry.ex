defmodule SovereignSoulEngine.World.LorebookEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lorebook_entries" do
    field :scope, :string, default: "global"
    field :slug, :string
    field :title, :string
    field :keys, {:array, :string}, default: []
    field :secondary_keys, {:array, :string}, default: []
    field :category, :string, default: "lore"
    field :priority, :integer, default: 50
    field :content, :string
    field :metadata, :map, default: %{}
    field :enabled, :boolean, default: true

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :scope,
      :slug,
      :title,
      :keys,
      :secondary_keys,
      :category,
      :priority,
      :content,
      :metadata,
      :enabled
    ])
    |> validate_required([:scope, :slug, :title, :content])
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> unique_constraint([:scope, :slug])
  end
end
