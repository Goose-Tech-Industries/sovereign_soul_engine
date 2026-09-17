defmodule SovereignSoulEngine.Crypto.Base58 do
  @moduledoc """
  Dependency-free Bitcoin Base58 (Base58BTC) encoder/decoder.

  Used to render 32-byte Ed25519 public keys as compact DID suffixes.
  The alphabet deliberately omits `0`, `O`, `I`, and `l` to stay URL- and
  human-copy-safe.
  """

  @alphabet ~c"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  @alphabet_values @alphabet |> Enum.with_index() |> Map.new()
  @valid_chars @alphabet |> MapSet.new() |> MapSet.put(?1)

  @doc """
  Encodes a binary as a Base58BTC string (no multibase prefix).

  Leading zero bytes are preserved as leading `1` characters, matching the
  Bitcoin Base58 convention.
  """
  @spec encode(binary()) :: String.t()
  def encode(data) when is_binary(data) do
    leading_zeros = data |> :binary.bin_to_list() |> Enum.take_while(&(&1 == 0)) |> length()

    body =
      data
      |> :binary.decode_unsigned()
      |> do_encode([])
      |> Enum.map(&Enum.at(@alphabet, &1))
      |> List.to_string()

    String.duplicate("1", leading_zeros) <> body
  end

  @doc """
  Decodes a Base58BTC string into a binary.

  Returns `{:ok, binary}` or `{:error, :invalid_character}`.
  """
  @spec decode(String.t()) :: {:ok, binary()} | {:error, :invalid_character}
  def decode(string) when is_binary(string) do
    chars = String.to_charlist(string)
    {leading_ones, rest} = Enum.split_while(chars, &(&1 == ?1))

    if Enum.all?(rest, &MapSet.member?(@valid_chars, &1)) do
      integer = Enum.reduce(rest, 0, fn c, acc -> acc * 58 + Map.fetch!(@alphabet_values, c) end)
      padding = :binary.copy(<<0>>, length(leading_ones))
      body = if rest == [], do: <<>>, else: :binary.encode_unsigned(integer)

      {:ok, padding <> body}
    else
      {:error, :invalid_character}
    end
  end

  defp do_encode(0, acc), do: acc
  defp do_encode(n, acc), do: do_encode(div(n, 58), [rem(n, 58) | acc])
end
