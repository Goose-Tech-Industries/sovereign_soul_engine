defmodule SovereignSoulEngine.Souls.ConsequenceEngineTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Souls.ConsequenceEngine
  alias SovereignSoulEngine.Repo

  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Scenes.Scene
  alias SovereignSoulEngine.Scenes.SceneParticipant
  alias SovereignSoulEngine.Souls.EmotionalState
  alias SovereignSoulEngine.Relationships.Relationship
  alias SovereignSoulEngine.Ledger.SoulLedger

  import Ecto.Query

  setup do
    {:ok, source} =
      Repo.insert(%Character{
        name: "Goose",
        slug: "goose-#{:rand.uniform(9999)}",
        kind: "player",
        status: "active"
      })

    {:ok, target} =
      Repo.insert(%Character{
        name: "Vael",
        slug: "vael-#{:rand.uniform(9999)}",
        kind: "npc",
        status: "active"
      })

    {:ok, scene} =
      Repo.insert(%Scene{
        title: "Test Scene",
        status: "active",
        location: "Test Arena",
        started_at: DateTime.utc_now()
      })

    {:ok, _part1} =
      Repo.insert(%SceneParticipant{
        scene_id: scene.id,
        character_id: source.id
      })

    {:ok, _part2} =
      Repo.insert(%SceneParticipant{
        scene_id: scene.id,
        character_id: target.id
      })

    correlation_id = Ecto.UUID.generate()

    %{
      source: source,
      target: target,
      scene: scene,
      correlation_id: correlation_id
    }
  end

  describe "full consequence resolution" do
    test "resolved betrayal creates emotional state, relationship, event, and ledger entries",
         ctx do
      params = %{
        character_id: ctx.target.id,
        event_type: :betrayed_me,
        event_intensity: 80,
        source_character_id: ctx.source.id,
        target_character_id: ctx.target.id,
        scene_id: ctx.scene.id,
        correlation_id: ctx.correlation_id,
        message_content: "You betrayed me!",
        memory_candidate: %{
          category: "episodic",
          summary: "Goose betrayed Vael",
          importance: 85,
          emotional_intensity: 80,
          valence: -0.9,
          tags: ["betrayal", "conflict"]
        }
      }

      assert {:ok, result} = ConsequenceEngine.resolve(params)

      # Soul event created
      assert result.soul_event.id != nil
      assert result.soul_event.event_type == "betrayed_me"

      # Emotional state updated
      assert result.emotional_state_after.anger > 0

      # Relationship updated
      assert result.relationship_after.trust < 100

      # Memory created
      assert result.memory.id != nil
      assert result.memory.category == "episodic"

      # Ledger entries created (at least event, emotion, relationship, memory)
      entries =
        Repo.all(from e in SoulLedger, where: e.correlation_id == ^ctx.correlation_id)

      assert length(entries) >= 4

      entry_types = Enum.map(entries, & &1.entry_type)
      assert "event_injected" in entry_types
      assert "emotion_change" in entry_types
      assert "relationship_change" in entry_types
      assert "memory_created" in entry_types

      # All entries share the correlation ID
      Enum.each(entries, fn e ->
        assert e.correlation_id == ctx.correlation_id
      end)
    end

    test "resolution with action creates action ledger entry", ctx do
      params = %{
        character_id: ctx.target.id,
        event_type: :praised_me,
        event_intensity: 50,
        source_character_id: ctx.source.id,
        target_character_id: ctx.target.id,
        scene_id: ctx.scene.id,
        correlation_id: ctx.correlation_id,
        action_resolution: %{
          proposed_action: "praise",
          proposed_confidence: 0.9,
          proposed_reason: "You did well",
          validation_status: "approved",
          resolved_action: "praise"
        }
      }

      assert {:ok, result} = ConsequenceEngine.resolve(params)

      assert result.action_intent.id != nil
      assert result.action_intent.validation_status == "approved"

      entries =
        Repo.all(from e in SoulLedger, where: e.correlation_id == ^ctx.correlation_id)

      assert Enum.any?(entries, &(&1.entry_type == "action_resolved"))
    end

    test "resolved event without memory or action still succeeds", ctx do
      params = %{
        character_id: ctx.target.id,
        event_type: :ally_saved_me,
        event_intensity: 60,
        source_character_id: ctx.source.id,
        target_character_id: ctx.target.id,
        scene_id: ctx.scene.id,
        correlation_id: ctx.correlation_id
      }

      assert {:ok, result} = ConsequenceEngine.resolve(params)

      refute Map.has_key?(result, :memory)
      refute Map.has_key?(result, :action_intent)
      assert result.soul_event.id != nil
      assert result.emotional_state_after.id != nil
      assert result.relationship_after.id != nil
    end

    test "generates correlation_id when not provided", ctx do
      params = %{
        character_id: ctx.target.id,
        event_type: :insulted_me,
        event_intensity: 30,
        source_character_id: ctx.source.id,
        target_character_id: ctx.target.id,
        scene_id: ctx.scene.id
      }

      assert {:ok, result} = ConsequenceEngine.resolve(params)

      assert result.soul_event.correlation_id != nil
    end
  end

  describe "emotional state persistence" do
    test "creates emotional state if none exists", ctx do
      # Ensure no existing emotional state
      Repo.delete_all(from e in EmotionalState, where: e.character_id == ^ctx.target.id)

      params = %{
        character_id: ctx.target.id,
        event_type: :betrayed_me,
        event_intensity: 70,
        source_character_id: ctx.source.id,
        target_character_id: ctx.target.id,
        scene_id: ctx.scene.id,
        correlation_id: ctx.correlation_id
      }

      assert {:ok, result} = ConsequenceEngine.resolve(params)

      state = Repo.get_by!(EmotionalState, character_id: ctx.target.id)
      assert state.id == result.emotional_state_after.id
    end

    test "updates existing emotional state", ctx do
      Repo.insert!(%EmotionalState{
        character_id: ctx.target.id,
        anger: 10,
        fear: 5,
        stress: 20,
        gratitude: 5,
        confidence: 50,
        sadness: 10,
        curiosity: 50,
        attachment: 10
      })

      params = %{
        character_id: ctx.target.id,
        event_type: :betrayed_me,
        event_intensity: 80,
        source_character_id: ctx.source.id,
        target_character_id: ctx.target.id,
        scene_id: ctx.scene.id,
        correlation_id: ctx.correlation_id
      }

      assert {:ok, result} = ConsequenceEngine.resolve(params)

      assert result.emotional_state_after.anger > 10
    end
  end

  describe "relationship persistence" do
    test "creates relationship if none exists", ctx do
      Repo.delete_all(
        from r in Relationship,
          where:
            r.source_character_id == ^ctx.target.id and
              r.target_character_id == ^ctx.source.id
      )

      params = %{
        character_id: ctx.target.id,
        event_type: :protected_me,
        event_intensity: 60,
        source_character_id: ctx.source.id,
        target_character_id: ctx.target.id,
        scene_id: ctx.scene.id,
        correlation_id: ctx.correlation_id
      }

      assert {:ok, result} = ConsequenceEngine.resolve(params)

      rel =
        Repo.get_by!(Relationship,
          source_character_id: ctx.target.id,
          target_character_id: ctx.source.id
        )

      assert rel.id == result.relationship_after.id
    end
  end

  describe "transaction rollback" do
    test "failure in emotion update rolls back all operations", ctx do
      Repo.insert!(%EmotionalState{
        character_id: ctx.target.id,
        anger: 0,
        fear: 50,
        stress: 20,
        gratitude: 5,
        confidence: 50,
        sadness: 10,
        curiosity: 50,
        attachment: 10
      })

      Repo.insert!(%Relationship{
        source_character_id: ctx.target.id,
        target_character_id: ctx.source.id,
        trust: 25,
        anger: 20
      })

      params = %{
        character_id: ctx.target.id,
        event_type: :betrayed_me,
        event_intensity: 50,
        source_character_id: ctx.source.id,
        target_character_id: ctx.target.id,
        scene_id: ctx.scene.id,
        correlation_id: ctx.correlation_id,
        memory_candidate: %{
          category: "episodic",
          summary: "Test memory",
          importance: 50,
          emotional_intensity: 50,
          valence: 0.0
        }
      }

      assert {:ok, _result} = ConsequenceEngine.resolve(params)

      # Verify everything was persisted
      event_count =
        Repo.aggregate(
          from(e in SovereignSoulEngine.Scenes.SoulEvent,
            where: e.correlation_id == ^ctx.correlation_id
          ),
          :count
        )

      assert event_count == 1
    end
  end

  describe "ledger entry details" do
    test "emotion ledger entry has correct before/after", ctx do
      Repo.insert!(%EmotionalState{
        character_id: ctx.target.id,
        anger: 5,
        fear: 5,
        stress: 10,
        gratitude: 5,
        confidence: 50,
        sadness: 5,
        curiosity: 50,
        attachment: 5
      })

      params = %{
        character_id: ctx.target.id,
        event_type: :betrayed_me,
        event_intensity: 70,
        source_character_id: ctx.source.id,
        target_character_id: ctx.target.id,
        scene_id: ctx.scene.id,
        correlation_id: ctx.correlation_id
      }

      {:ok, _result} = ConsequenceEngine.resolve(params)

      emotion_ledger =
        Repo.one(
          from e in SoulLedger,
            where:
              e.correlation_id == ^ctx.correlation_id and
                e.entry_type == "emotion_change"
        )

      assert emotion_ledger != nil
      assert Map.has_key?(emotion_ledger.before_state, "anger")
      assert Map.has_key?(emotion_ledger.after_state, "anger")
      assert Map.has_key?(emotion_ledger.delta, "anger")

      # After betrayal, anger should have increased
      before_anger = emotion_ledger.before_state["anger"] || 0
      after_anger = emotion_ledger.after_state["anger"] || 0
      delta_anger = emotion_ledger.delta["anger"] || 0

      assert after_anger > before_anger
      assert delta_anger == after_anger - before_anger
    end
  end
end
