defmodule SovereignSoulEngine.Secrets.CharacterSecret do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "character_secrets" do
    field :secret_text, :string
    field :risk_level, :string, default: "medium"
    field :domain, :string
    field :revealed_to, {:array, :binary_id}, default: []

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @valid_risk_levels ~w(low medium high critical)

  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [
      :character_id,
      :secret_text,
      :risk_level,
      :domain,
      :revealed_to
    ])
    |> validate_required([:character_id, :secret_text])
    |> validate_inclusion(:risk_level, @valid_risk_levels)
  end
end
