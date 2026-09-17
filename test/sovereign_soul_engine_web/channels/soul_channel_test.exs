defmodule SovereignSoulEngineWeb.SoulChannelTest do
  use SovereignSoulEngineWeb.ChannelCase

  alias SovereignSoulEngine.Identity.SoulIdentity
  alias SovereignSoulEngine.Relay.Envelope

  setup do
    {public_key, private_key} = SoulIdentity.generate_keypair()
    from_did = SoulIdentity.did(public_key)

    Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "world:sovereign-society")

    %{from_did: from_did, private_key: private_key}
  end

  test "accepts a valid signed envelope and broadcasts it to the world", %{
    from_did: from_did,
    private_key: private_key
  } do
    envelope =
      from_did
      |> Envelope.build("world_event", nil, %{"hello" => "world"})
      |> Envelope.sign(private_key)

    {:ok, _reply, socket} =
      socket(SovereignSoulEngineWeb.UserSocket, "soul:#{from_did}", %{})
      |> subscribe_and_join("world:sovereign-society", %{})

    ref = push(socket, "envelope", envelope)
    assert_reply ref, :ok
    assert_receive {:envelope, ^envelope}
  end

  test "rejects a replayed envelope", %{from_did: from_did, private_key: private_key} do
    envelope =
      from_did
      |> Envelope.build("world_event")
      |> Envelope.sign(private_key)

    {:ok, _reply, socket} =
      socket(SovereignSoulEngineWeb.UserSocket, "soul:#{from_did}", %{})
      |> subscribe_and_join("world:sovereign-society", %{})

    assert_reply push(socket, "envelope", envelope), :ok
    assert_reply push(socket, "envelope", envelope), :error, %{reason: "replayed"}
  end

  test "rejects an unsigned envelope", %{from_did: from_did} do
    envelope = Envelope.build(from_did, "world_event")

    {:ok, _reply, socket} =
      socket(SovereignSoulEngineWeb.UserSocket, "soul:#{from_did}", %{})
      |> subscribe_and_join("world:sovereign-society", %{})

    assert_reply push(socket, "envelope", envelope), :error, %{reason: "missing_signature"}
  end
end
