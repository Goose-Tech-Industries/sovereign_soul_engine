defmodule SovereignSoulEngine.TheoryOfMind.CharacterKnowledge do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "character_knowledge" do
    field :known_fact, :string
    field :certainty, :integer, default: 70
    field :is_assumption, :boolean, default: true
    field :last_updated_at, :utc_datetime

    belongs_to :knower_character, SovereignSoulEngine.Characters.Character,
      foreign_key: :knower_character_id

    belongs_to :subject_character, SovereignSoulEngine.Characters.Character,
      foreign_key: :subject_character_id

    timestamps()
  end

  def changeset(knowledge, attrs) do
    knowledge
    |> cast(attrs, [:knower_character_id, :subject_character_id, :known_fact, :certainty, :is_assumption, :last_updated_at])
    |> validate_required([:knower_character_id, :subject_character_id, :known_fact])
    |> validate_number(:certainty, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
