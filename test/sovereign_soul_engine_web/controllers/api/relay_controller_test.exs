defmodule SovereignSoulEngineWeb.Api.RelayControllerTest do
  use SovereignSoulEngineWeb.ConnCase, async: false

  alias SovereignSoulEngine.Identity.SoulIdentity
  alias SovereignSoulEngine.Relay.Envelope

  setup do
    {public_key, private_key} = SoulIdentity.generate_keypair()
    %{from_did: SoulIdentity.did(public_key), private_key: private_key}
  end

  defp relay_post(conn, envelope, hops) do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> post("/sse/api/relay/inbound", Jason.encode!(%{"envelope" => envelope, "hops" => hops}))
  end

  test "verifies and re-broadcasts a valid forwarded envelope", %{
    from_did: from_did,
    private_key: private_key
  } do
    envelope =
      from_did
      |> Envelope.build("gossip", nil, %{"rumor" => "x"})
      |> Envelope.sign(private_key)

    Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "world:sovereign-society")

    conn = relay_post(build_conn(), envelope, 1)

    assert json_response(conn, 200)["status"] == "ok"
    assert_receive {:envelope, ^envelope}, 1_000
  end

  test "dedupes a replayed envelope via the SeenSet", %{
    from_did: from_did,
    private_key: private_key
  } do
    envelope = from_did |> Envelope.build("gossip") |> Envelope.sign(private_key)

    relay_post(build_conn(), envelope, 1)
    conn = relay_post(build_conn(), envelope, 1)

    assert json_response(conn, 200)["deduped"] == true
  end

  test "rejects a tampered envelope", %{from_did: from_did, private_key: private_key} do
    envelope = from_did |> Envelope.build("gossip") |> Envelope.sign(private_key)
    tampered = put_in(envelope, ["payload", "rumor"], "tampered")

    conn = relay_post(build_conn(), tampered, 1)

    assert conn.status == 422
    assert json_response(conn, 422)["error"] == "invalid_signature"
  end

  test "rejects malformed input" do
    conn =
      build_conn()
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> post("/sse/api/relay/inbound", Jason.encode!(%{}))

    assert conn.status == 400
  end

  test "advertises peers for transitive discovery" do
    conn = get(build_conn(), "/sse/api/relay/peers")

    assert %{"peers" => peers} = json_response(conn, 200)
    assert is_list(peers)
  end

  test "enforces the relay secret when one is configured", %{
    from_did: from_did,
    private_key: private_key
  } do
    Application.put_env(:sovereign_soul_engine, :relay_secret, "s3cret")
    on_exit(fn -> Application.delete_env(:sovereign_soul_engine, :relay_secret) end)

    envelope = from_did |> Envelope.build("gossip") |> Envelope.sign(private_key)

    # without the secret header -> 401
    assert relay_post(build_conn(), envelope, 1).status == 401

    # with the correct secret header -> 200
    conn =
      build_conn()
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> Plug.Conn.put_req_header("x-relay-secret", "s3cret")
      |> post("/sse/api/relay/inbound", Jason.encode!(%{"envelope" => envelope, "hops" => 1}))

    assert json_response(conn, 200)["status"] == "ok"
  end
end
