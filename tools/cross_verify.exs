pub = Base.decode16!("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a", case: :lower)
sig = Base.decode16!("204708d889f7951514fdacae813d50c1c2af8dcdc3ab0b870f2e2eb804bcdb703e786fe3182e9679c0896d36a81804d053df1d22520a51d538a1bcb6e0a1db08", case: :lower)
msg = "hello-cross-check"

verified = :crypto.verify(:eddsa, :none, msg, sig, [pub, :ed25519])
IO.puts("=== CROSS-LANGUAGE VERIFICATION RESULT ===")
IO.puts("C# -> Elixir Ed25519 signature valid: #{verified}")

if verified do
  IO.puts("SUCCESS: C# pure BigInteger Ed25519 byte-matches Elixir OTP Erlang :crypto exactly!")
else
  IO.puts("FAILURE: Signature verification failed.")
  System.halt(1)
end
