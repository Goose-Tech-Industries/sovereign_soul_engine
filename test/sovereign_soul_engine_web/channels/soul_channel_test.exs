defmodule SovereignSoulEngineWeb.SoulChannelTest do
  use SovereignSoulEngineWeb.ChannelCase

  alias SovereignSoulEngine.Identity.SoulIdentity
  alias SovereignSoulEngine.Relay.Envelope
  alias SovereignSoulEngineWeb.Presence
  alias SovereignSoulEngineWeb.UserSocket

  setup do
    {public_key, private_key} = SoulIdentity.generate_keypair()
    from_did = SoulIdentity.did(public_key)

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
      socket(UserSocket, "soul:#{from_did}", %{})
      |> subscribe_and_join("world:sovereign-society", %{})

    ref = push(socket, "envelope", envelope)
    assert_reply ref, :ok
    assert_receive {:envelope, ^envelope}, 1_000
  end

  test "rejects a replayed envelope", %{from_did: from_did, private_key: private_key} do
    envelope =
      from_did
      |> Envelope.build("world_event")
      |> Envelope.sign(private_key)

    {:ok, _reply, socket} =
      socket(UserSocket, "soul:#{from_did}", %{})
      |> subscribe_and_join("world:sovereign-society", %{})

    assert_reply push(socket, "envelope", envelope), :ok
    assert_reply push(socket, "envelope", envelope), :error, %{reason: "replayed"}
  end

  test "rejects an unsigned envelope", %{from_did: from_did} do
    envelope = Envelope.build(from_did, "world_event")

    {:ok, _reply, socket} =
      socket(UserSocket, "soul:#{from_did}", %{})
      |> subscribe_and_join("world:sovereign-society", %{})

    assert_reply push(socket, "envelope", envelope), :error, %{reason: "missing_signature"}
  end

  test "tracks presence by DID on join", %{from_did: did} do
    {:ok, _reply, _socket} =
      socket(UserSocket, "soul:#{did}", %{})
      |> subscribe_and_join("world:sovereign-society", %{"did" => did})

    assert_push "presence_state", _state, 1_000
    assert Map.has_key?(Presence.list("world:sovereign-society"), did)
  end

  test "routes a direct message to the recipient's soul topic", %{
    from_did: did_a,
    private_key: priv_a
  } do
    {pub_b, _priv_b} = SoulIdentity.generate_keypair()
    did_b = SoulIdentity.did(pub_b)

    {:ok, _reply, socket_a} =
      socket(UserSocket, "a", %{})
      |> subscribe_and_join("soul:#{did_a}", %{"did" => did_a})

    {:ok, _reply, _socket_b} =
      socket(UserSocket, "b", %{})
      |> subscribe_and_join("soul:#{did_b}", %{"did" => did_b})

    envelope =
      did_a
      |> Envelope.build("gossip", did_b, %{"secret" => "hello"})
      |> Envelope.sign(priv_a)

    assert_reply push(socket_a, "envelope", envelope), :ok
    assert_push "envelope", ^envelope, 1_000
  end

  test "rejects an envelope from a muted DID", %{from_did: from_did, private_key: private_key} do
    SovereignSoulEngine.Moderation.mute_did(from_did)

    envelope =
      from_did
      |> Envelope.build("world_event", nil, %{"hello" => "world"})
      |> Envelope.sign(private_key)

    {:ok, _reply, socket} =
      socket(UserSocket, "soul:#{from_did}", %{})
      |> subscribe_and_join("world:sovereign-society", %{})

    assert_reply push(socket, "envelope", envelope), :error, %{reason: "muted"}

    SovereignSoulEngine.Moderation.unmute_did(from_did)
  end

  test "UserSocket.connect/3 assigns authenticated tenant" do
    {:ok, tenant, key} = SovereignSoulEngine.Tenants.create_tenant("Socket Test", "socket", 100)
    assert {:ok, socket} = UserSocket.connect(%{"api_key" => key}, %Phoenix.Socket{}, %{})
    assert socket.assigns.tenant.id == tenant.id
  end

  test "UserSocket.connect/3 rejects unauthenticated connections when require_connect_auth is true" do
    Application.put_env(:sovereign_soul_engine, :require_connect_auth, true)

    on_exit(fn ->
      Application.put_env(:sovereign_soul_engine, :require_connect_auth, false)
    end)

    assert :error = UserSocket.connect(%{}, %Phoenix.Socket{}, %{})
    assert :error = UserSocket.connect(%{"api_key" => "invalid"}, %Phoenix.Socket{}, %{})
  end
end
