defmodule SovereignSoulEngine.ModerationTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.Moderation

  setup do
    unless Process.whereis(Moderation) do
      start_supervised!(Moderation)
    end

    :ok
  end

  test "redact/1 scrubs blocked terms" do
    Application.put_env(:sovereign_soul_engine, :moderation_blocked_terms, ["forbidden"])
    on_exit(fn -> Application.put_env(:sovereign_soul_engine, :moderation_blocked_terms, []) end)

    assert Moderation.redact("this contains a forbidden word") ==
             "this contains a [redacted] word"
  end

  test "mute_did/1 and muted?/1 gate souls" do
    did = "did:soul:zmuted"

    refute Moderation.muted?(did)
    Moderation.mute_did(did)
    assert Moderation.muted?(did)

    Moderation.unmute_did(did)
    refute Moderation.muted?(did)
  end

  test "screen/1 rejects muted DIDs" do
    did = "did:soul:zscreened"
    Moderation.mute_did(did)

    assert {:error, :muted} = Moderation.screen(%{from_did: did, payload: %{}})
  end

  test "screen/1 rejects fully-blocked content" do
    Application.put_env(:sovereign_soul_engine, :moderation_blocked_terms, ["forbidden"])
    on_exit(fn -> Application.put_env(:sovereign_soul_engine, :moderation_blocked_terms, []) end)

    assert {:error, :blocked_content} =
             Moderation.screen(%{from_did: "did:soul:zok", payload: %{"text" => "forbidden"}})

    assert :ok =
             Moderation.screen(%{from_did: "did:soul:zok", payload: %{"text" => "fine content"}})
  end
end
