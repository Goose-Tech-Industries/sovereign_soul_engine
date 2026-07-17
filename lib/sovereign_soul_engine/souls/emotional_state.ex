defmodule SovereignSoulEngine.Souls.EmotionalState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "emotional_states" do
    field :anger, :integer, default: 0
    field :fear, :integer, default: 0
    field :stress, :integer, default: 0
    field :gratitude, :integer, default: 0
    field :confidence, :integer, default: 50
    field :sadness, :integer, default: 0
    field :curiosity, :integer, default: 50
    field :attachment, :integer, default: 0
    field :shame, :integer, default: 0
    field :guilt, :integer, default: 0
    field :mood_baseline, :map, default: %{}
    field :rumination_subject, :string
    field :rumination_intensity, :integer, default: 0
    field :rumination_since, :utc_datetime

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @dimensions ~w(anger fear stress gratitude confidence sadness curiosity attachment shame guilt)a
  @min 0
  @max 100

  def changeset(state, attrs) do
    state
    |> cast(attrs, [
      :character_id,
      :mood_baseline,
      :rumination_subject,
      :rumination_intensity,
      :rumination_since | @dimensions
    ])
    |> validate_required([:character_id])
    |> validate_dimension_range()
    |> unique_constraint(:character_id)
  end

  defp validate_dimension_range(changeset) do
    Enum.reduce(@dimensions, changeset, fn dim, cs ->
      validate_number(cs, dim, greater_than_or_equal_to: @min, less_than_or_equal_to: @max)
    end)
  end
end
