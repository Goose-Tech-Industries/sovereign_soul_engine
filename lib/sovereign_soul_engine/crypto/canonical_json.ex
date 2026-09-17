defmodule SovereignSoulEngine.Crypto.CanonicalJSON do
  @moduledoc """
  Deterministic JSON serialization for envelope signing (RFC-0002 §4).

  Sorts object keys recursively and normalizes numbers per RFC 8785: integer
  values (including integer-valued floats like `1.0`) serialize as plain
  integers, and non-integer floats use the shortest round-trip form. Produces a
  byte-stable string independent of map insertion order across runtimes.
  """

  @doc "Returns the canonical JSON string for a term."
  @spec encode(term()) :: String.t()
  def encode(value) do
    value |> canonical() |> IO.iodata_to_binary()
  end

  defp canonical(nil), do: "null"
  defp canonical(true), do: "true"
  defp canonical(false), do: "false"
  defp canonical(i) when is_integer(i), do: Integer.to_string(i)
  defp canonical(f) when is_float(f), do: canonical_float(f)
  defp canonical(s) when is_binary(s), do: Jason.encode!(s)

  defp canonical(list) when is_list(list) do
    ["[", Enum.map_intersperse(list, ",", &canonical/1), "]"]
  end

  defp canonical(map) when is_map(map) do
    entries =
      map
      |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
      |> Enum.map(fn {k, v} -> [Jason.encode!(to_string(k)), ":", canonical(v)] end)

    ["{", Enum.intersperse(entries, ","), "}"]
  end

  # RFC 8785: numbers that are integers serialize without a fraction/exponent.
  # Non-integer floats use the shortest round-trip representation, which matches
  # ECMAScript number-to-string for the ordinary magnitude range.
  defp canonical_float(f) do
    if f == trunc(f) and abs(f) < 1.0e21 do
      Integer.to_string(trunc(f))
    else
      :erlang.float_to_binary(f, [:short])
    end
  end
end
