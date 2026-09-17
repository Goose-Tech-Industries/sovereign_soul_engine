defmodule SovereignSoulEngine.Crypto.Base58Test do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Crypto.Base58

  describe "encode/1" do
    test "matches Bitcoin reference vectors" do
      assert Base58.encode(hex("")) == ""
      assert Base58.encode(hex("61")) == "2g"
      assert Base58.encode(hex("626262")) == "a3gV"
      assert Base58.encode(hex("636363")) == "aPEr"

      assert Base58.encode(hex("73696d706c792061206c6f6e6720737472696e67")) ==
               "2cFupjhnEsSn59qHXstmK2ffpLv2"

      assert Base58.encode(hex("516b6fcd0f")) == "ABnLTmg"
      assert Base58.encode(hex("10c8511e")) == "Rt5zm"
    end

    test "preserves leading zero bytes as leading ones" do
      assert Base58.encode(hex("00000000000000000000")) == "1111111111"
      assert Base58.encode(<<0, 0, 0, 1>>) == "1112"
    end
  end

  describe "decode/1" do
    test "round-trips Bitcoin reference vectors" do
      assert Base58.decode("2g") == {:ok, hex("61")}
      assert Base58.decode("a3gV") == {:ok, hex("626262")}
      assert Base58.decode("Rt5zm") == {:ok, hex("10c8511e")}
      assert Base58.decode("1111111111") == {:ok, hex("00000000000000000000")}
    end

    test "rejects characters outside the alphabet" do
      assert Base58.decode("0OIl") == {:error, :invalid_character}
    end
  end

  describe "round-trip" do
    test "encodes and decodes random binaries" do
      for _ <- 1..100 do
        bytes = :crypto.strong_rand_bytes(:rand.uniform(32))
        assert {:ok, ^bytes} = bytes |> Base58.encode() |> Base58.decode()
      end
    end
  end

  defp hex(str), do: Base.decode16!(str, case: :mixed)
end
