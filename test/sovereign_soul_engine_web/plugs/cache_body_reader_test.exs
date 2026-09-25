defmodule SovereignSoulEngineWeb.Plugs.CacheBodyReaderTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngineWeb.Plugs.CacheBodyReader

  test "caches a complete request body" do
    conn = Plug.Test.conn(:post, "/", "hello")
    assert {:ok, "hello", conn} = CacheBodyReader.read_body(conn, [])
    assert conn.assigns.raw_body == "hello"
  end

  test "returns the plug parser result for an empty body" do
    conn = Plug.Test.conn(:post, "/", "")
    assert {:ok, "", conn} = CacheBodyReader.read_body(conn, [])
    assert conn.assigns.raw_body == ""
  end
end
