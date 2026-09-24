defmodule SovereignSoulEngine.Relay.AdaptersTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.Relay.{Discovery, Forwarder}

  setup do
    previous = Application.get_env(:sovereign_soul_engine, :relay_peers, [])
    Application.put_env(:sovereign_soul_engine, :relay_peers, [])

    if :ets.whereis(:sse_discovered_peers) != :undefined,
      do: :ets.delete_all_objects(:sse_discovered_peers)

    on_exit(fn -> Application.put_env(:sovereign_soul_engine, :relay_peers, previous) end)
  end

  test "forward returns empty when no peers or hop budget is exceeded" do
    assert Forwarder.configured_peers() == []
    assert Forwarder.forward(%{"id" => "x"}, 0) == []
    assert Forwarder.forward(%{"id" => "x"}, Forwarder.max_hops() + 1) == []
  end

  test "forwards envelopes and includes discovered peers" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/sse/api/relay/inbound"
      Req.Test.json(conn, %{"accepted" => true})
    end)

    Application.put_env(:sovereign_soul_engine, :relay_peers, ["http://relay.test"])

    assert [:ok] =
             Forwarder.forward(%{"id" => "x"}, 0, req_options: [plug: {Req.Test, __MODULE__}])
  end

  test "discovery records peers returned by a configured relay" do
    discovery_plug = fn conn ->
      assert conn.method == "GET"
      Req.Test.json(conn, %{"peers" => ["http://peer-a", "http://peer-b"]})
    end

    Application.put_env(:sovereign_soul_engine, :relay_peers, ["http://relay.test/"])

    unless Process.whereis(Discovery), do: start_supervised!(Discovery)

    assert Enum.sort(["http://peer-a", "http://peer-b"]) ==
             Enum.sort(Discovery.discover_now(req_options: [plug: discovery_plug]))
  end
end
