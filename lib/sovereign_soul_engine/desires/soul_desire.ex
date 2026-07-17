defmodule SovereignSoulEngine.Desires.SoulDesire do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "soul_desires" do
    field :desire, :string
    field :domain, :string
    field :urgency, :integer, default: 50
    field :status, :string, default: "active"
    field :blocking_belief, :string

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @valid_domains ~w(revenge connection safety power redemption knowledge belonging)
  @valid_statuses ~w(active pursuing blocked resolved)

  def changeset(desire, attrs) do
    desire
    |> cast(attrs, [
      :character_id,
      :desire,
      :domain,
      :urgency,
      :status,
      :blocking_belief
    ])
    |> validate_required([:character_id, :desire, :domain])
    |> validate_inclusion(:domain, @valid_domains)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:urgency, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
