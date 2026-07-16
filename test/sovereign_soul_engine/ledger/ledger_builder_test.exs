defmodule SovereignSoulEngine.Ledger.LedgerBuilderTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Ledger.LedgerBuilder

  @character_id Ecto.UUID.generate()
  @scene_id Ecto.UUID.generate()
  @event_id Ecto.UUID.generate()
  @relationship_id Ecto.UUID.generate()
  @memory_id Ecto.UUID.generate()
  @correlation_id Ecto.UUID.generate()

  describe "build_emotion_change_entry" do
    test "builds a valid changeset with before/after/delta" do
      before = %{anger: 10, fear: 5, stress: 20}
      emo_after = %{anger: 35, fear: 15, stress: 35}

      cs =
        LedgerBuilder.build_emotion_change_entry(
          character_id: @character_id,
          scene_id: @scene_id,
          before_state: before,
          after_state: emo_after,
          reason: "Event: betrayed_me",
          correlation_id: @correlation_id
        )

      assert cs.valid?
      assert Ecto.Changeset.get_field(cs, :entry_type) == "emotion_change"
      assert Ecto.Changeset.get_field(cs, :source) == "EmotionEngine"
      assert Ecto.Changeset.get_field(cs, :reason) == "Event: betrayed_me"
      assert Ecto.Changeset.get_field(cs, :correlation_id) == @correlation_id

      delta = Ecto.Changeset.get_field(cs, :delta)
      assert delta.anger == 25
      assert delta.fear == 10
      assert delta.stress == 15
    end

    test "computes correct delta from before/after" do
      cs =
        LedgerBuilder.build_emotion_change_entry(
          character_id: @character_id,
          before_state: %{anger: 0, trust: 0},
          after_state: %{anger: 30, trust: -15},
          reason: "test"
        )

      delta = Ecto.Changeset.get_field(cs, :delta)
      assert delta.anger == 30
      assert delta.trust == -15
    end
  end

  describe "build_relationship_change_entry" do
    test "builds a valid changeset with relationship id" do
      rel_before = %{trust: 25, anger: 20}
      rel_after = %{trust: 10, anger: 50}

      cs =
        LedgerBuilder.build_relationship_change_entry(
          character_id: @character_id,
          scene_id: @scene_id,
          relationship_id: @relationship_id,
          before_state: rel_before,
          after_state: rel_after,
          reason: "Event: betrayed_me",
          correlation_id: @correlation_id
        )

      assert cs.valid?
      assert Ecto.Changeset.get_field(cs, :entry_type) == "relationship_change"
      assert Ecto.Changeset.get_field(cs, :source) == "RelationshipEngine"
      assert Ecto.Changeset.get_field(cs, :relationship_id) == @relationship_id
    end
  end

  describe "build_memory_entry" do
    test "builds a valid changeset for memory creation" do
      cs =
        LedgerBuilder.build_memory_entry(
          character_id: @character_id,
          scene_id: @scene_id,
          memory_id: @memory_id,
          entry_type: :memory_created,
          summary: "Memory: ally saved me",
          delta: %{category: "episodic", importance: 75},
          correlation_id: @correlation_id,
          reason: "Scene interaction"
        )

      assert cs.valid?
      assert Ecto.Changeset.get_field(cs, :entry_type) == "memory_created"
      assert Ecto.Changeset.get_field(cs, :source) == "MemorySystem"
      assert Ecto.Changeset.get_field(cs, :memory_id) == @memory_id
    end
  end

  describe "build_action_entry" do
    test "builds a valid changeset for proposed action" do
      cs =
        LedgerBuilder.build_action_entry(
          character_id: @character_id,
          scene_id: @scene_id,
          entry_type: :action_resolved,
          summary: "Action approved: protect",
          before_state: %{proposed: :attack},
          after_state: %{resolved: :protect, status: "transformed"},
          delta: %{status: "transformed", reason: "attachment override"},
          reason: "attachment override",
          correlation_id: @correlation_id
        )

      assert cs.valid?
      assert Ecto.Changeset.get_field(cs, :entry_type) == "action_resolved"
      assert Ecto.Changeset.get_field(cs, :source) == "ActionPolicy"
    end
  end

  describe "build_event_entry" do
    test "builds a valid changeset for event injection" do
      cs =
        LedgerBuilder.build_event_entry(
          character_id: @character_id,
          scene_id: @scene_id,
          event_id: @event_id,
          entry_type: :event_injected,
          source: "event",
          label: "Soul Event",
          summary: "Event: betrayed_me injected",
          delta: %{event_type: "betrayed_me", intensity: 75},
          correlation_id: @correlation_id
        )

      assert cs.valid?
      assert Ecto.Changeset.get_field(cs, :event_id) == @event_id
      assert Ecto.Changeset.get_field(cs, :entry_type) == "event_injected"
    end
  end

  describe "build_custom_entry" do
    test "builds a valid custom entry changeset" do
      cs =
        LedgerBuilder.build_custom_entry(
          character_id: @character_id,
          scene_id: @scene_id,
          entry_type: :scene_message_created,
          source: "scene",
          label: "Scene Message",
          summary: "Message created",
          before_state: %{},
          delta: %{content: "Hello"},
          after_state: %{content: "Hello"},
          reason: "player message",
          tags: ["scene", "message"],
          correlation_id: @correlation_id
        )

      assert cs.valid?
      assert Ecto.Changeset.get_field(cs, :entry_type) == "scene_message_created"
      assert Ecto.Changeset.get_field(cs, :tags) == ["scene", "message"]
    end
  end

  describe "immutability" do
    test "entry changeset does not include an updated_at field" do
      cs =
        LedgerBuilder.build_event_entry(
          character_id: @character_id,
          entry_type: :event_injected,
          source: "test",
          label: "Test",
          summary: "test",
          delta: %{},
          correlation_id: @correlation_id
        )

      assert cs.valid?

      # Should be insert-only; no updated_at changeset key
      changes = cs.changes
      refute Map.has_key?(changes, :updated_at)
    end
  end

  describe "correlation IDs" do
    test "all entries share the same correlation ID when provided" do
      corr_id = @correlation_id

      emo =
        LedgerBuilder.build_emotion_change_entry(
          character_id: @character_id,
          before_state: %{},
          after_state: %{},
          correlation_id: corr_id,
          reason: "test"
        )

      rel =
        LedgerBuilder.build_relationship_change_entry(
          character_id: @character_id,
          before_state: %{},
          after_state: %{},
          correlation_id: corr_id,
          reason: "test"
        )

      mem =
        LedgerBuilder.build_memory_entry(
          character_id: @character_id,
          correlation_id: corr_id,
          reason: "test"
        )

      act =
        LedgerBuilder.build_action_entry(
          character_id: @character_id,
          correlation_id: corr_id,
          reason: "test"
        )

      evt =
        LedgerBuilder.build_event_entry(
          character_id: @character_id,
          entry_type: :event_injected,
          source: "test",
          label: "Test",
          summary: "test",
          delta: %{},
          correlation_id: corr_id
        )

      for cs <- [emo, rel, mem, act, evt] do
        assert cs.valid?
        assert Ecto.Changeset.get_field(cs, :correlation_id) == corr_id
      end
    end
  end
end
