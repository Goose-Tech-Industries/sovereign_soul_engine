defmodule SovereignSoulEngine.Identity.SoulDid do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Maps a node-local `character_id` to a soul's global `did:soul:` identity.

  The character is the primary key: a soul has at most one DID per node.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "soul_dids" do
    belongs_to :character, SovereignSoulEngine.Characters.Character

    field :did, :string
    field :public_key, :binary
    field :private_key_sealed, :binary
    field :active, :boolean, default: true

    timestamps()
  end

  @doc false
  def changeset(soul_did, attrs) do
    soul_did
    |> cast(attrs, [:character_id, :did, :public_key, :private_key_sealed, :active])
    |> validate_required([:character_id, :did, :public_key])
    |> unique_constraint(:did)
  end
end
