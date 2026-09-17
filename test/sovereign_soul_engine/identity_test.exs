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
end
