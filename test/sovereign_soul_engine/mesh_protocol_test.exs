defmodule SovereignSoulEngine.Social.MeshProtocolTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Social.MeshProtocol
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Privacy
  alias SovereignSoulEngine.TheoryOfMind

  setup do
    {:ok, char_a} =
      Characters.create_character(%{
        name: "Astra",
        slug: "astra_mesh_#{System.unique_integer([:positive])}",
        kind: "npc",
        description: "A philosophical stargazer and cartographer.",
        status: "active",
        metadata: %{
          "archetype" => "scholar",
          "core_values" => ["curiosity", "truth", "harmony"],
          "speech_style" => "poetic"
        }
      })

    {:ok, char_b} =
      Characters.create_character(%{
        name: "Kaelen",
        slug: "kaelen_mesh_#{System.unique_integer([:positive])}",
        kind: "npc",
        description: "A pragmatic guardian of the high pass.",
        status: "active",
        metadata: %{
          "archetype" => "protector",
          "core_values" => ["truth", "loyalty", "vigilance"],
          "speech_style" => "cynical"
        }
      })

    # Enable neighborhood sharing on both characters
    Privacy.update_settings(char_a, %{"neighborhood_share_allowed" => true})
    Privacy.update_settings(char_b, %{"neighborhood_share_allowed" => true})

    %{char_a: char_a, char_b: char_b}
  end

  test "compute_resonance/2 produces bounded, deterministic resonance based on core values", %{
    char_a: a,
    char_b: b
  } do
    score = MeshProtocol.compute_resonance(a, b)
    assert is_integer(score)
    assert score >= 15 and score <= 98

    # Recalculating produces stable deterministic result
    score_again = MeshProtocol.compute_resonance(a, b)
    assert score == score_again
  end

  test "encounter/2 completes successfully with dynamic dialogue and cryptographic signature", %{
    char_a: a,
    char_b: b
  } do
    # Subscribe to PubSub topic to verify event emission
    Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "social:mesh:encounters")

    {:ok, encounter} = MeshProtocol.encounter(a, b, rssi: -45)

    assert is_binary(encounter.id)
    assert encounter.soul_a.slug == a.slug
    assert encounter.soul_b.slug == b.slug
    assert encounter.resonance >= 15 and encounter.resonance <= 98

    # Dialogue is emergent, dynamic, and non-empty
    assert length(encounter.dialogue_exchange) == 2
    [g1, g2] = encounter.dialogue_exchange
    assert String.contains?(g1, a.name)
    assert String.contains?(g2, b.name)
    assert String.contains?(g1, "in close proximity")

    # Cryptographic packet signature is valid 64-char lowercase hex (HMAC-SHA256)
    assert is_binary(encounter.signature)
    assert byte_size(encounter.signature) == 64
    assert encounter.signature =~ ~r/^[0-9a-f]{64}$/

    # PubSub broadcast received
    assert_receive {:mesh_encounter, received_data}
    assert received_data.id == encounter.id
  end

  test "encounter/2 records qualitative Theory of Mind impressions for both souls", %{
    char_a: a,
    char_b: b
  } do
    {:ok, _encounter} = MeshProtocol.encounter(a, b)

    knowledge_a = TheoryOfMind.list_knowledge_about(a.id, b.id)
    assert is_list(knowledge_a)
    assert Enum.any?(knowledge_a, &String.contains?(&1.known_fact, "#{b.name}"))

    knowledge_b = TheoryOfMind.list_knowledge_about(b.id, a.id)
    assert is_list(knowledge_b)
    assert Enum.any?(knowledge_b, &String.contains?(&1.known_fact, "#{a.name}"))
  end

  test "encounter/2 rejects self-encounters", %{char_a: a} do
    assert {:error, :cannot_encounter_self} = MeshProtocol.encounter(a, a)
  end

  test "encounter/2 respects sovereign privacy boundaries when neighborhood share is disabled", %{
    char_a: a,
    char_b: b
  } do
    Privacy.update_settings(a, %{"neighborhood_share_allowed" => false})
    assert {:error, :encounter_prohibited_by_privacy} = MeshProtocol.encounter(a, b)
  end

  test "encounter/2 returns error for non-existent characters" do
    assert {:error, :character_not_found} =
             MeshProtocol.encounter("ghost_slug_xyz", "shadow_slug_abc")
  end

  test "verify_packet?/5 authenticates valid packet signatures and rejects tampered ones", %{
    char_a: a,
    char_b: b
  } do
    {:ok, encounter} = MeshProtocol.encounter(a, b)

    assert MeshProtocol.verify_packet?(
             encounter.id,
             a.id,
             b.id,
             encounter.resonance,
             encounter.signature
           )

    refute MeshProtocol.verify_packet?(
             encounter.id,
             a.id,
             b.id,
             encounter.resonance + 1,
             encounter.signature
           )

    refute MeshProtocol.verify_packet?(
             encounter.id,
             a.id,
             b.id,
             encounter.resonance,
             "forged_signature_hex_0000000000000000000000000000000000000000000000"
           )
  end
end
