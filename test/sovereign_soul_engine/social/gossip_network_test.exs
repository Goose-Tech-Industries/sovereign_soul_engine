defmodule SovereignSoulEngine.Social.GossipNetworkTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Social.GossipNetwork

  describe "GossipNetwork — Inter-NPC reputation and memory propagation" do
    setup do
      {:ok, speaker} =
        Characters.create_character(%{
          name: "Speaker NPC",
          slug: "speaker-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active"
        })

      {:ok, listener} =
        Characters.create_character(%{
          name: "Listener NPC",
          slug: "listener-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active"
        })

      {:ok, subject} =
        Characters.create_character(%{
          name: "Subject Rogue",
          slug: "subject-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active"
        })

      %{speaker: speaker, listener: listener, subject: subject}
    end

    test "propagates negative gossip with high credibility when listener trusts speaker", %{
      speaker: speaker,
      listener: listener,
      subject: subject
    } do
      # Listener has high trust & affinity toward Speaker
      {:ok, _} =
        Relationships.create_relationship(%{
          source_character_id: listener.id,
          target_character_id: speaker.id,
          trust: 80,
          affinity: 70,
          respect: 75
        })

      gossip = %{
        event_type: :betrayed_me,
        summary: "#{subject.name} stole the guild treasury and deserted.",
        intensity: 80
      }

      assert {:ok, result} =
               GossipNetwork.propagate(speaker.id, listener.id, subject.id, gossip)

      assert result.credibility > 0.6
      assert result.deltas.trust < 0
      assert result.deltas.affinity < 0

      # Check listener's updated relationship toward subject
      rel = Relationships.get_relationship(listener.id, subject.id)
      assert rel != nil
      assert rel.affinity <= result.deltas.affinity
      assert rel.fear > 0
      assert rel.relationship_type == "reputation"

      # Check second-hand memory created in listener's vault
      memory = result.memory
      assert memory.owner_character_id == listener.id
      assert memory.subject_character_id == subject.id
      assert "gossip" in memory.tags
      assert "second_hand" in memory.tags
      assert memory.summary =~ "Word from #{speaker.name}"
    end

    test "low credibility discounts gossip impact when listener distrusts speaker", %{
      speaker: speaker,
      listener: listener,
      subject: subject
    } do
      # Listener strongly distrusts Speaker
      {:ok, _} =
        Relationships.create_relationship(%{
          source_character_id: listener.id,
          target_character_id: speaker.id,
          trust: 0,
          affinity: -50,
          respect: 0
        })

      gossip = %{
        event_type: :betrayed_me,
        summary: "Suspicious rumor",
        intensity: 50
      }

      assert {:ok, result} =
               GossipNetwork.propagate(speaker.id, listener.id, subject.id, gossip)

      assert result.credibility <= 0.2
      # Trust delta should be minimal due to negligible credibility
      assert abs(result.deltas.trust) <= 5
    end
  end
end
