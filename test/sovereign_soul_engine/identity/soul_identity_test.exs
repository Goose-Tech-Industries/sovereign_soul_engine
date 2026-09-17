defmodule SovereignSoulEngine.Identity.SoulIdentityTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Identity.SoulIdentity

  describe "generate_keypair/0" do
    test "produces 32-byte keys" do
      {pub, priv} = SoulIdentity.generate_keypair()
      assert byte_size(pub) == 32
      assert byte_size(priv) == 32
    end

    test "produces distinct keypairs" do
      {pub1, _} = SoulIdentity.generate_keypair()
      {pub2, _} = SoulIdentity.generate_keypair()
      refute pub1 == pub2
    end
  end

  describe "did/1 and public_key_from_did/1" do
    test "round-trips a public key through the DID string" do
      {pub, _priv} = SoulIdentity.generate_keypair()
      did = SoulIdentity.did(pub)

      assert String.starts_with?(did, "did:soul:z")
      assert {:ok, ^pub} = SoulIdentity.public_key_from_did(did)
    end

    test "rejects a wrong-length public key" do
      assert {:error, :invalid_public_key_length} =
               SoulIdentity.public_key_from_did("did:soul:z11")
    end

    test "rejects a non-DID prefix" do
      assert {:error, :invalid_did} = SoulIdentity.public_key_from_did("not-a-did")
    end
  end

  describe "sign/2 and verify/3" do
    test "verifies a valid signature" do
      {pub, priv} = SoulIdentity.generate_keypair()
      sig = SoulIdentity.sign("hello", priv)
      assert SoulIdentity.verify("hello", sig, pub)
    end

    test "rejects a tampered message" do
      {pub, priv} = SoulIdentity.generate_keypair()
      sig = SoulIdentity.sign("hello", priv)
      refute SoulIdentity.verify("tampered", sig, pub)
    end

    test "rejects a signature from a different key" do
      {pub, _priv} = SoulIdentity.generate_keypair()
      {_other_pub, other_priv} = SoulIdentity.generate_keypair()
      sig = SoulIdentity.sign("hello", other_priv)
      refute SoulIdentity.verify("hello", sig, pub)
    end
  end

  describe "seal_private_key/1 and unseal_private_key/1" do
    test "round-trips a private key" do
      {_pub, priv} = SoulIdentity.generate_keypair()
      sealed = SoulIdentity.seal_private_key(priv)

      assert sealed != priv
      assert {:ok, ^priv} = SoulIdentity.unseal_private_key(sealed)
    end

    test "rejects garbage ciphertext" do
      assert {:error, _} = SoulIdentity.unseal_private_key("not-a-ciphertext")
    end
  end
end
