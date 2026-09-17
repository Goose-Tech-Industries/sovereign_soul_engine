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
end
