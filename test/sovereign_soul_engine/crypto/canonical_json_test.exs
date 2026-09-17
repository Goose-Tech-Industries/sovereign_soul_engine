defmodule SovereignSoulEngine.Crypto.CanonicalJSONTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Crypto.CanonicalJSON

  test "sorts top-level keys deterministically" do
    a = %{"b" => 1, "a" => 2, "c" => 3}
    b = %{"c" => 3, "a" => 2, "b" => 1}

    assert CanonicalJSON.encode(a) == CanonicalJSON.encode(b)
    assert CanonicalJSON.encode(a) == ~s({"a":2,"b":1,"c":3})
  end

  test "sorts nested keys recursively" do
    a = %{"outer" => %{"z" => 1, "a" => 2}}
    b = %{"outer" => %{"a" => 2, "z" => 1}}

    assert CanonicalJSON.encode(a) == CanonicalJSON.encode(b)
    assert CanonicalJSON.encode(a) == ~s({"outer":{"a":2,"z":1}})
  end

  test "preserves list order" do
    assert CanonicalJSON.encode([3, 1, 2]) == "[3,1,2]"
  end

  test "handles scalars" do
    assert CanonicalJSON.encode(nil) == "null"
    assert CanonicalJSON.encode(true) == "true"
    assert CanonicalJSON.encode(42) == "42"
    assert CanonicalJSON.encode("hi") == ~s("hi")
  end

  test "normalizes floats per RFC 8785" do
    # integer-valued floats serialize as plain integers
    assert CanonicalJSON.encode(1.0) == "1"
    assert CanonicalJSON.encode(-2.0) == "-2"

    # non-integer floats use the shortest round-trip form
    assert CanonicalJSON.encode(0.5) == "0.5"
    assert CanonicalJSON.encode(-0.667) == "-0.667"

    # and inside objects
    assert CanonicalJSON.encode(%{"valence" => 0.8}) == ~s({"valence":0.8})
  end
end
