defmodule SovereignSoulEngine.Identity do
  @moduledoc """
  Context for managing a soul's global DID identity (RFC-0002 M0).

  A soul's DID is its portable, verifiable identity on the Soul Society relay.
  The private key is sealed at rest and the plaintext is returned exactly once,
  at generation time — mirroring `Tenants.create_tenant/3`.
  """

  import Ecto.Query, warn: false

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Identity.{SoulDid, SoulIdentity}

  @doc """
  Generates an Ed25519 keypair, seals the private key, and records the DID for a
  character. Returns `{:ok, soul_did, private_key}` (plaintext returned once) or
  `{:error, {:already_exists, existing}}`.
  """
  @spec generate_did(String.t()) :: {:ok, SoulDid.t(), binary()} | {:error, term()}
  def generate_did(character_id) when is_binary(character_id) do
    case get_did_for_character(character_id) do
      nil ->
        {public_key, private_key} = SoulIdentity.generate_keypair()
        did = SoulIdentity.did(public_key)

        %SoulDid{}
        |> SoulDid.changeset(%{
          character_id: character_id,
          did: did,
          public_key: public_key,
          private_key_sealed: SoulIdentity.seal_private_key(private_key),
          active: true
        })
        |> Repo.insert()
        |> case do
          {:ok, soul_did} -> {:ok, soul_did, private_key}
          {:error, changeset} -> {:error, changeset}
        end

      existing ->
        {:error, {:already_exists, existing}}
    end
  end

  @doc "Returns the active DID record for a character, or nil."
  @spec get_did_for_character(String.t()) :: SoulDid.t() | nil
  def get_did_for_character(character_id) do
    Repo.get_by(SoulDid, character_id: character_id, active: true)
  end

  @doc "Returns the DID record for a `did:soul:` string, or nil."
  @spec get_did(String.t()) :: SoulDid.t() | nil
  def get_did(did_string) when is_binary(did_string) do
    Repo.get_by(SoulDid, did: did_string)
  end

  @doc """
  Registers a pre-existing DID identity (e.g. one restored from a `.soul`
  capsule) without generating a fresh keypair.
  """
  @spec register_did(map()) :: {:ok, SoulDid.t()} | {:error, Ecto.Changeset.t()}
  def register_did(attrs) do
    %SoulDid{}
    |> SoulDid.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Unseals a soul's private key. Returns `{:ok, private_key}` or `{:error, reason}`."
  @spec unseal_private_key(SoulDid.t() | nil) :: {:ok, binary()} | {:error, term()}
  def unseal_private_key(%SoulDid{private_key_sealed: sealed}),
    do: SoulIdentity.unseal_private_key(sealed)

  def unseal_private_key(_), do: {:error, :not_found}
end
