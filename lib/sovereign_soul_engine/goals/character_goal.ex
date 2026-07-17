defmodule SovereignSoulEngine.Goals.CharacterGoal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "character_goals" do
    field :goal, :string
    field :current_step, :string
    field :blocker, :string
    field :priority, :integer, default: 50
    field :status, :string, default: "active"
    field :progress_notes, :string

    belongs_to :character, SovereignSoulEngine.Characters.Character
    belongs_to :target_character, SovereignSoulEngine.Characters.Character,
      foreign_key: :target_character_id

    timestamps()
  end

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:character_id, :goal, :current_step, :blocker, :priority, :status, :target_character_id, :progress_notes])
    |> validate_required([:character_id, :goal])
    |> validate_number(:priority, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:status, ["active", "paused", "achieved", "abandoned"])
  end
end
