defmodule SovereignSoulEngine.Relay.EnvelopeTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Identity.SoulIdentity
  alias SovereignSoulEngine.Relay.Envelope

  setup do
    {public_key, private_key} = SoulIdentity.generate_keypair()
    %{from_did: SoulIdentity.did(public_key), private_key: private_key}
  end

  test "build/5 produces all required fields", %{from_did: from_did} do
    env = Envelope.build(from_did, "world_event", nil, %{"x" => 1})

    assert env["v"] == 1
    assert env["type"] == "world_event"
    assert env["from"] == from_did
    assert env["to"] == nil
    assert is_binary(env["id"])
    assert is_binary(env["ts"])
    assert is_binary(env["nonce"])
    assert env["prev"] == nil
  end

  test "sign/2 adds a signature and verify/1 accepts it", %{
    from_did: from_did,
    private_key: private_key
  } do
    env =
      from_did
      |> Envelope.build("gossip", nil, %{"rumor" => "..."}, prev: Ecto.UUID.generate())
      |> Envelope.sign(private_key)

    assert is_binary(env["sig"])
    assert :ok = Envelope.verify(env)
  end

  test "verify/1 rejects a tampered payload", %{from_did: from_did, private_key: private_key} do
    env = from_did |> Envelope.build("gossip") |> Envelope.sign(private_key)
    tampered = put_in(env, ["payload", "rumor"], "tampered")

    assert {:error, :invalid_signature} = Envelope.verify(tampered)
  end

  test "verify/1 rejects a signature from a different key", %{from_did: from_did} do
    {_other_pub, other_priv} = SoulIdentity.generate_keypair()
    env = from_did |> Envelope.build("gossip") |> Envelope.sign(other_priv)

    assert {:error, :invalid_signature} = Envelope.verify(env)
  end

  test "verify/1 rejects a missing signature", %{from_did: from_did} do
    assert {:error, :missing_signature} = Envelope.verify(Envelope.build(from_did, "gossip"))
  end

  test "validate_prev/1 accepts nil and UUIDs, rejects garbage" do
    assert :ok = Envelope.validate_prev(nil)
    assert :ok = Envelope.validate_prev(Ecto.UUID.generate())
    assert {:error, :invalid_prev} = Envelope.validate_prev("not-a-uuid")
    assert {:error, :invalid_prev} = Envelope.validate_prev(123)
  end

  test "validate_structure/1 catches missing fields", %{from_did: from_did} do
    base = Envelope.build(from_did, "gossip")

    assert :ok = Envelope.validate_structure(base)
    assert {:error, :missing_nonce} = Envelope.validate_structure(%{base | "nonce" => nil})
    assert {:error, :missing_type} = Envelope.validate_structure(%{base | "type" => nil})
    assert {:error, :missing_from} = Envelope.validate_structure(%{base | "from" => nil})
  end
end
