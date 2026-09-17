defmodule SovereignSoulEngine.Relay.SeenSetTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.Relay.SeenSet

  setup do
    unless Process.whereis(SeenSet) do
      start_supervised!(SeenSet)
    end

    :ok
  end

  test "accepts a new nonce" do
    assert :ok = SeenSet.check_and_mark("did:soul:ztest1", Ecto.UUID.generate())
  end

  test "rejects a replayed nonce" do
    did = "did:soul:ztest2"
    nonce = Ecto.UUID.generate()

    assert :ok = SeenSet.check_and_mark(did, nonce)
    assert {:error, :replayed} = SeenSet.check_and_mark(did, nonce)
  end

  test "treats DIDs independently" do
    nonce = Ecto.UUID.generate()

    assert :ok = SeenSet.check_and_mark("did:soul:zaaa", nonce)
    assert :ok = SeenSet.check_and_mark("did:soul:zbbb", nonce)
  end
end
