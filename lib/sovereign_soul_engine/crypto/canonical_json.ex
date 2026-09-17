defmodule SovereignSoulEngine.Crypto.CanonicalJSON do
  @moduledoc """
  Deterministic JSON serialization for envelope signing (RFC-0002 §4).

  Recursively sorts object keys and encodes via `Jason.OrderedObject`, so the
  byte representation is independent of map insertion order across runtimes.
  Full RFC 8785 (JCS) numeric formatting remains a `SHOULD`; this canonicalizes
  key order (the part that matters for structural determinism) and leaves number
  rendering to the encoder.
  """

  @doc "Canonicalizes a term (sorts object keys recursively) into a JSON-encodable tree."
  @spec canonicalize(term()) :: term()
  def canonicalize(value)

  def canonicalize(value) when is_map(value) do
    value
    |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> {to_string(k), canonicalize(v)} end)
    |> Jason.OrderedObject.new()
  end

  def canonicalize(value) when is_list(value), do: Enum.map(value, &canonicalize/1)
  def canonicalize(value), do: value

  @doc "Returns the canonical JSON string for a term."
  @spec encode(term()) :: String.t()
  def encode(value) do
    value |> canonicalize() |> Jason.encode!()
  end
end
