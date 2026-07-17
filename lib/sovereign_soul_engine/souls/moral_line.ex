defmodule SovereignSoulEngine.Souls.MoralLine do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "moral_lines" do
    field :principle, :string
    field :will_refuse_when_violated, :boolean, default: true
    field :action_types_blocked, {:array, :string}, default: []

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  def changeset(moral_line, attrs) do
    moral_line
    |> cast(attrs, [
      :character_id,
      :principle,
      :will_refuse_when_violated,
      :action_types_blocked
    ])
    |> validate_required([:character_id, :principle])
  end
end
