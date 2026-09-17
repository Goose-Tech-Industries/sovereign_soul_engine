defmodule SovereignSoulEngine.Identity do
  @moduledoc """
  Context for managing a soul's global DID identity (RFC-0002 M0).

  A soul's DID is its portable, verifiable identity on the Soul Society relay.
  The private key is sealed at rest and the plaintext is returned exactly once,
  at generation time — mirroring `Tenants.create_tenant/3`.
  """

  import Ecto.Query, warn: false

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
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

  @doc """
  Resolves a DID to a local character. When the DID is not yet known locally,
  materializes a complete remote-soul record (a real `Character` registered under
  the DID, with its public key extracted from the DID and no private key — a node
  cannot hold another soul's private key). This is how a relay node forms
  relationships with souls living on other nodes.

  Remote-soul materialization is capped by `:max_remote_souls` to bound growth
  from arbitrary DIDs. Returns a `Character` or nil if the DID is invalid or the
  cap is reached.
  """
  @spec ensure_local_character(String.t()) :: Character.t() | nil
  def ensure_local_character(did) when is_binary(did) do
    case get_did(did) do
      nil ->
        with {:ok, public_key} <- SoulIdentity.public_key_from_did(did),
             {:ok, character} <- create_remote_soul(did) do
          case get_did_for_character(character.id) do
            nil ->
              register_did(%{
                character_id: character.id,
                did: did,
                public_key: public_key,
                private_key_sealed: nil,
                active: true
              })

            _existing ->
              :ok
          end

          character
        else
          _ -> nil
        end

      soul_did ->
        Characters.get_character(soul_did.character_id)
    end
  end

  @doc """
  Rotates a soul's DID: deactivates the current key, generates a fresh keypair,
  and registers the new DID. Returns `{:ok, new_soul_did, private_key}` (the
  plaintext is returned once), `{:error, :no_did}`, or `{:error, changeset}`.
  """
  @spec rotate_key(String.t()) :: {:ok, SoulDid.t(), binary()} | {:error, term()}
  def rotate_key(character_id) when is_binary(character_id) do
    case get_did_for_character(character_id) do
      nil ->
        {:error, :no_did}

      current ->
        {public_key, private_key} = SoulIdentity.generate_keypair()
        did = SoulIdentity.did(public_key)

        with {:ok, _} <- deactivate_did(current),
             {:ok, new_did} <-
               register_did(%{
                 character_id: character_id,
                 did: did,
                 public_key: public_key,
                 private_key_sealed: SoulIdentity.seal_private_key(private_key),
                 active: true
               }) do
          {:ok, new_did, private_key}
        end
    end
  end

  defp deactivate_did(%SoulDid{} = soul_did) do
    soul_did
    |> SoulDid.changeset(%{active: false})
    |> Repo.update()
  end

  defp create_remote_soul(did) do
    if remote_soul_count() >= max_remote_souls() do
      {:error, :cap_reached}
    else
      do_create_remote_soul(did)
    end
  end

  defp do_create_remote_soul(did) do
    hash = :crypto.hash(:sha256, did) |> Base.encode16(case: :lower)
    slug = "remote_" <> String.slice(hash, 0, 16)

    case Characters.get_character_by_slug(slug) do
      nil ->
        case Characters.create_character(%{
               name: "Soul " <> String.slice(did, -8..-1//1),
               slug: slug,
               kind: "npc",
               status: "active",
               description: "A sovereign soul encountered over the relay (remote).",
               metadata: %{"remote_did" => did}
             }) do
          {:ok, character} -> {:ok, character}
          # lost a race — re-fetch the winner
          {:error, _} -> {:ok, Characters.get_character_by_slug!(slug)}
        end

      character ->
        {:ok, character}
    end
  end

  defp remote_soul_count do
    from(c in Character, where: like(c.slug, "remote_%"))
    |> Repo.aggregate(:count)
  end

  defp max_remote_souls do
    Application.get_env(:sovereign_soul_engine, :max_remote_souls, 1000)
  end

  @doc "Unseals a soul's private key. Returns `{:ok, private_key}` or `{:error, reason}`."
  @spec unseal_private_key(SoulDid.t() | nil) :: {:ok, binary()} | {:error, term()}
  def unseal_private_key(%SoulDid{private_key_sealed: sealed}),
    do: SoulIdentity.unseal_private_key(sealed)

  def unseal_private_key(_), do: {:error, :not_found}
end
