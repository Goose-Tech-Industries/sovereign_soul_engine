defmodule SovereignSoulEngine.Identity.SoulIdentity do
  @moduledoc """
  Pure Ed25519 identity primitives for the Soul Society relay (RFC-0002).

  - Keypair generation via Erlang's native `:crypto` Ed25519
  - `did:soul:` DID formatting (multibase `z` + Base58BTC public key)
  - Message signing and verification
  - Private-key sealing at rest (AES-256-GCM via `Plug.Crypto`, same primitive
    as the tenant BYOK layer)
  """

  alias SovereignSoulEngine.Crypto.Base58

  @did_prefix "did:soul:z"
  @public_key_bytes 32
  @key_seal_context "sse.soul_identity_key"

  @type public_key :: <<_::256>>
  @type private_key :: <<_::256>>

  @doc "Generates a fresh Ed25519 keypair. Returns `{public_key, private_key}` (32 bytes each)."
  @spec generate_keypair() :: {public_key(), private_key()}
  def generate_keypair do
    :crypto.generate_key(:eddsa, :ed25519)
  end

  @doc "Formats an Ed25519 public key as a `did:soul:` DID string."
  @spec did(public_key()) :: String.t()
  def did(public_key) when is_binary(public_key) do
    @did_prefix <> Base58.encode(public_key)
  end

  @doc """
  Parses a `did:soul:` DID string back into its 32-byte public key.

  Returns `{:ok, public_key}` or `{:error, reason}`.
  """
  @spec public_key_from_did(String.t()) :: {:ok, public_key()} | {:error, term()}
  def public_key_from_did(@did_prefix <> encoded) do
    case Base58.decode(encoded) do
      {:ok, pub} when byte_size(pub) == @public_key_bytes -> {:ok, pub}
      {:ok, _} -> {:error, :invalid_public_key_length}
      {:error, reason} -> {:error, reason}
    end
  end

  def public_key_from_did(_), do: {:error, :invalid_did}

  @doc "Signs a message with an Ed25519 private key. Returns a 64-byte signature."
  @spec sign(binary(), private_key()) :: binary()
  def sign(message, private_key) when is_binary(message) and is_binary(private_key) do
    :crypto.sign(:eddsa, :sha512, message, [private_key, :ed25519])
  end

  @doc "Verifies a signature against a public key."
  @spec verify(binary(), binary(), public_key()) :: boolean()
  def verify(message, signature, public_key)
      when is_binary(signature) and is_binary(public_key) do
    :crypto.verify(:eddsa, :sha512, message, signature, [public_key, :ed25519])
  rescue
    _ -> false
  end

  @doc "Seals a private key at rest using the app's secret_key_base (AES-256-GCM)."
  @spec seal_private_key(private_key()) :: binary()
  def seal_private_key(private_key) when is_binary(private_key) do
    Plug.Crypto.encrypt(secret_key_base(), @key_seal_context, private_key)
  end

  @doc "Unseals a private key. Returns `{:ok, private_key}` or `{:error, reason}`."
  @spec unseal_private_key(binary()) :: {:ok, private_key()} | {:error, term()}
  def unseal_private_key(ciphertext) when is_binary(ciphertext) do
    case Plug.Crypto.decrypt(secret_key_base(), @key_seal_context, ciphertext) do
      {:ok, plaintext} -> {:ok, plaintext}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :invalid_ciphertext}
  end

  defp secret_key_base do
    Application.fetch_env!(:sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
