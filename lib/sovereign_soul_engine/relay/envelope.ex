defmodule SovereignSoulEngine.Relay.Envelope do
  @moduledoc """
  Signed relay message envelope (RFC-0002 §4).

  Wire format is a JSON object:

      {v, type, from, to, id, ts, nonce, prev, sig, payload}

  `sig` is the Ed25519 signature (Base58BTC-encoded) over the canonical JSON of
  the remaining fields. `prev` is the gossip DAG parent: `nil` for a
  genesis/reconnect tip, otherwise the message id it was causally based on.
  """

  alias SovereignSoulEngine.Crypto.{Base58, CanonicalJSON}
  alias SovereignSoulEngine.Identity.SoulIdentity

  @version 1
  @signing_keys ~w(v type from to id ts nonce prev payload)

  @doc """
  Builds an unsigned envelope. `opts` may set `:nonce`, `:prev`, and `:ts` for
  deterministic tests.
  """
  @spec build(String.t(), term(), String.t() | nil, map(), keyword()) :: map()
  def build(from_did, type, to_did \\ nil, payload \\ %{}, opts \\ []) do
    %{
      "v" => @version,
      "type" => to_string(type),
      "from" => from_did,
      "to" => to_did,
      "id" => Ecto.UUID.generate(),
      "ts" => Keyword.get(opts, :ts, DateTime.utc_now() |> DateTime.to_iso8601()),
      "nonce" => Keyword.get(opts, :nonce, Ecto.UUID.generate()),
      "prev" => Keyword.get(opts, :prev),
      "payload" => payload
    }
  end

  @doc "Signs an envelope with the sender's private key, adding the `sig` field."
  @spec sign(map(), binary()) :: map()
  def sign(envelope, private_key) when is_binary(private_key) do
    signature = envelope |> signing_payload() |> SoulIdentity.sign(private_key) |> Base58.encode()
    Map.put(envelope, "sig", signature)
  end

  @doc """
  Verifies an envelope's signature against its `from` DID.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec verify(map()) :: :ok | {:error, term()}
  def verify(%{"sig" => sig_b58, "from" => from_did} = envelope) do
    with {:ok, public_key} <- SoulIdentity.public_key_from_did(from_did),
         {:ok, signature} <- Base58.decode(sig_b58) do
      if SoulIdentity.verify(signing_payload(envelope), signature, public_key) do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      {:error, reason} -> {:error, {:invalid_sender, reason}}
    end
  end

  def verify(_), do: {:error, :missing_signature}

  @doc "Validates the gossip DAG `prev` reference: nil (genesis/reconnect tip) or a UUID."
  @spec validate_prev(String.t() | nil) :: :ok | {:error, :invalid_prev}
  def validate_prev(nil), do: :ok

  def validate_prev(prev) when is_binary(prev) do
    case Ecto.UUID.cast(prev) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_prev}
    end
  end

  def validate_prev(_), do: {:error, :invalid_prev}

  @doc "Validates required structural fields, without checking the signature."
  @spec validate_structure(map()) :: :ok | {:error, term()}
  def validate_structure(envelope) do
    cond do
      not is_map(envelope) ->
        {:error, :not_a_map}

      envelope["v"] != @version ->
        {:error, :unsupported_version}

      not is_binary(envelope["type"]) ->
        {:error, :missing_type}

      not is_binary(envelope["from"]) ->
        {:error, :missing_from}

      not is_binary(envelope["id"]) ->
        {:error, :missing_id}

      not is_binary(envelope["ts"]) ->
        {:error, :missing_ts}

      not is_binary(envelope["nonce"]) ->
        {:error, :missing_nonce}

      true ->
        :ok
    end
  end

  defp signing_payload(envelope) do
    @signing_keys
    |> Enum.reduce(%{}, fn key, acc -> Map.put(acc, key, Map.get(envelope, key)) end)
    |> CanonicalJSON.encode()
  end
end
