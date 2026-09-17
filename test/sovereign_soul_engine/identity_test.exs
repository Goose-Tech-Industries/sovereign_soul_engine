defmodule SovereignSoulEngine.IdentityTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Identity
  alias SovereignSoulEngine.Characters

  setup do
    {:ok, character} =
      Characters.create_character(%{
        name: "DID Tester",
        slug: "did_tester_#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    %{character: character}
  end

  test "generates a DID for a character", %{character: character} do
    assert {:ok, soul_did, private_key} = Identity.generate_did(character.id)

    assert String.starts_with?(soul_did.did, "did:soul:z")
    assert byte_size(soul_did.public_key) == 32
    assert byte_size(private_key) == 32
    assert soul_did.private_key_sealed != private_key
  end

  test "looks up a DID by character and by did string", %{character: character} do
    {:ok, soul_did, _} = Identity.generate_did(character.id)

    assert %{did: did} = Identity.get_did_for_character(character.id)
    assert did == soul_did.did
    assert Identity.get_did(did).did == soul_did.did
  end

  test "returns already_exists on a second generation", %{character: character} do
    {:ok, soul_did, _} = Identity.generate_did(character.id)

    assert {:error, {:already_exists, existing}} = Identity.generate_did(character.id)
    assert existing.did == soul_did.did
  end

  test "unseals the stored private key", %{character: character} do
    {:ok, soul_did, private_key} = Identity.generate_did(character.id)

    assert {:ok, ^private_key} = Identity.unseal_private_key(soul_did)
  end

  test "ensure_local_character/1 stubs an unknown remote DID" do
    {public_key, _private_key} = SovereignSoulEngine.Identity.SoulIdentity.generate_keypair()
    did = SovereignSoulEngine.Identity.SoulIdentity.did(public_key)

    char = Identity.ensure_local_character(did)
    assert char != nil
    assert String.starts_with?(char.slug, "remote_")

    soul_did = Identity.get_did_for_character(char.id)
    assert soul_did.did == did
    assert soul_did.public_key == public_key
    assert soul_did.private_key_sealed == nil

    # idempotent: a second call returns the same stub
    assert Identity.ensure_local_character(did).id == char.id
  end

  test "ensure_local_character/1 returns nil for an invalid DID" do
    assert Identity.ensure_local_character("not-a-did") == nil
  end

  test "rotate_key/1 deactivates the old DID and issues a new one", %{character: character} do
    {:ok, old_did, _} = Identity.generate_did(character.id)

    assert {:ok, new_did, new_private_key} = Identity.rotate_key(character.id)

    assert new_did.did != old_did.did
    assert new_did.active == true
    assert byte_size(new_private_key) == 32

    # the active DID is now the new one; the old one is historical
    assert Identity.get_did_for_character(character.id).did == new_did.did
    assert Identity.get_did(old_did.did).active == false
  end

  test "rotate_key/1 returns :no_did when the character has no DID", %{character: character} do
    assert {:error, :no_did} = Identity.rotate_key(character.id)
  end
end
