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

  test "add_blocked_term/1 and remove_blocked_term/1 manage dynamic terms" do
    Moderation.add_blocked_term("curseword")
    assert "curseword" in Moderation.blocked_terms()
    assert Moderation.redact("saying curseword here") == "saying [redacted] here"

    Moderation.remove_blocked_term("curseword")
    refute "curseword" in Moderation.blocked_terms()
    assert Moderation.redact("saying curseword here") == "saying curseword here"
  end

  test "list_muted_dids/0 returns currently muted souls" do
    did = "did:soul:zmute_list_test"
    Moderation.mute_did(did)
    assert did in Moderation.list_muted_dids()

    Moderation.unmute_did(did)
    refute did in Moderation.list_muted_dids()
  end

  test "get_maturity_rating/0 and set_maturity_rating/1 manage content rating" do
    assert Moderation.get_maturity_rating() in ["teen", "mature", "adult"]
    Moderation.set_maturity_rating("adult")
    assert Moderation.get_maturity_rating() == "adult"
    Moderation.set_maturity_rating("mature")
    assert Moderation.get_maturity_rating() == "mature"
  end
end
