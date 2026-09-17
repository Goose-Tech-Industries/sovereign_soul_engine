defmodule SovereignSoulEngine.Relay.EncounterBridgeTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Identity
  alias SovereignSoulEngine.Relay.EncounterBridge
  alias SovereignSoulEngine.World

  setup do
    {:ok, a} =
      Characters.create_character(%{
        name: "Bridge A",
        slug: "bridge_a_#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    {:ok, b} =
      Characters.create_character(%{
        name: "Bridge B",
        slug: "bridge_b_#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    {:ok, did_a, _} = Identity.generate_did(a.id)
    {:ok, did_b, _} = Identity.generate_did(b.id)

    %{did_a: did_a.did, did_b: did_b.did, a: a, b: b}
  end

  test "encounter?/1 identifies encounter lifecycle envelopes" do
    assert EncounterBridge.encounter?(%{"type" => "encounter_offer"})
    assert EncounterBridge.encounter?(%{"type" => "encounter_accept"})
    assert EncounterBridge.encounter?(%{"type" => "encounter_decline"})
    refute EncounterBridge.encounter?(%{"type" => "gossip"})
    refute EncounterBridge.encounter?(%{})
  end

  test "runs MeshProtocol.encounter for two local souls, records event and establishes relationship", %{
    did_a: did_a,
    did_b: did_b,
    a: a,
    b: b
  } do
    envelope = %{"from" => did_a, "to" => did_b, "payload" => %{}, "sig" => "signed"}

    assert {:ok, _encounter} = EncounterBridge.process_envelope(envelope)

    assert [%{kind: "encounter", from_did: ^did_a, to_did: ^did_b}] = World.list_recent_events()
    assert SovereignSoulEngine.Relationships.get_relationship(a.id, b.id) != nil
    assert SovereignSoulEngine.Relationships.get_relationship(b.id, a.id) != nil
  end

  test "records a remote encounter without a local target", %{did_a: did_a} do
    envelope = %{"from" => did_a, "to" => "did:soul:zremote", "payload" => %{}, "sig" => "signed"}

    assert {:ok, :recorded_remote} = EncounterBridge.process_envelope(envelope)

    assert [%{kind: "encounter", to_did: "did:soul:zremote"}] = World.list_recent_events()
  end
end
