defmodule SovereignSoulEngine.Beliefs.CharacterBelief do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "character_beliefs" do
    field :belief, :string
    field :domain, :string
    field :conviction, :integer, default: 50
    field :is_challenged, :boolean, default: false
    field :challenged_evidence, :string

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @valid_domains ~w(social self world spiritual)

  def changeset(belief, attrs) do
    belief
    |> cast(attrs, [
      :character_id,
      :belief,
      :domain,
      :conviction,
      :is_challenged,
      :challenged_evidence
    ])
    |> validate_required([:character_id, :belief, :domain])
    |> validate_inclusion(:domain, @valid_domains)
    |> validate_number(:conviction, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
