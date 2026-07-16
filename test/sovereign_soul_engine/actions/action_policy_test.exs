defmodule SovereignSoulEngine.Actions.ActionPolicyTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Actions.ActionPolicy
  alias SovereignSoulEngine.Actions.ActionResolver

  @scene_ids [Ecto.UUID.generate(), Ecto.UUID.generate()]
  @target_id Enum.at(@scene_ids, 1)
  @outside_id Ecto.UUID.generate()

  describe "ActionPolicy — always permitted actions" do
    test "observe is always approved" do
      assert {:ok, :approved, reason, :observe} =
               ActionPolicy.validate(
                 proposed_action: :observe,
                 character_status: :dead,
                 target_character_id: nil,
                 scene_participant_ids: []
               )

      assert reason =~ "approved"
    end

    test "speak is always approved" do
      assert {:ok, :approved, _reason, :speak} =
               ActionPolicy.validate(proposed_action: :speak)
    end

    test "leave_room is always approved" do
      assert {:ok, :approved, _reason, :leave_room} =
               ActionPolicy.validate(proposed_action: :leave_room)
    end
  end

  describe "ActionPolicy — character status restrictions" do
    test "dead character cannot attack" do
      assert {:ok, :rejected, reason, :attack} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :dead,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids
               )

      assert reason =~ "dead"
    end

    test "dead character cannot heal" do
      assert {:ok, :rejected, reason, :heal} =
               ActionPolicy.validate(
                 proposed_action: :heal,
                 character_status: :dead,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids
               )

      assert reason =~ "dead"
    end

    test "incapacitated character cannot protect" do
      assert {:ok, :rejected, reason, :protect} =
               ActionPolicy.validate(
                 proposed_action: :protect,
                 character_status: :incapacitated,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids
               )

      assert reason =~ "incapacitated"
    end

    test "active character can attack" do
      assert {:ok, :approved, _reason, :attack} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:combat]
               )
    end
  end

  describe "ActionPolicy — target validation" do
    test "attack requires a target" do
      assert {:ok, :rejected, reason, :attack} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :active,
                 target_character_id: nil,
                 scene_participant_ids: @scene_ids
               )

      assert reason =~ "target"
    end

    test "target outside the scene is rejected" do
      assert {:ok, :rejected, reason, :attack} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :active,
                 target_character_id: @outside_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:combat]
               )

      assert reason =~ "not in the current scene"
    end

    test "valid target in scene is accepted" do
      assert {:ok, :approved, _reason, :attack} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:combat]
               )
    end
  end

  describe "ActionPolicy — capability checks" do
    test "heal requires healing capability" do
      assert {:ok, :rejected, reason, :heal} =
               ActionPolicy.validate(
                 proposed_action: :heal,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:combat]
               )

      assert reason =~ "Missing required capabilities"
      assert reason =~ "healing"
    end

    test "heal succeeds with healing capability" do
      assert {:ok, :approved, _reason, :heal} =
               ActionPolicy.validate(
                 proposed_action: :heal,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:healing]
               )
    end

    test "protect requires combat and guard capabilities" do
      assert {:ok, :rejected, reason, :protect} =
               ActionPolicy.validate(
                 proposed_action: :protect,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:healing]
               )

      assert reason =~ "capabilities"
    end

    test "attack requires combat capability" do
      assert {:ok, :rejected, reason, :attack} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:healing]
               )

      assert reason =~ "combat"
    end
  end

  describe "ActionPolicy — fear-driven refusal" do
    test "overwhelming fear transforms attack to observe" do
      assert {:ok, :transformed, reason, :observe} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:combat],
                 emotional_state: %{fear: 85}
               )

      assert reason =~ "Overwhelming fear"
    end

    test "overwhelming fear transforms threaten to observe" do
      assert {:ok, :transformed, reason, :observe} =
               ActionPolicy.validate(
                 proposed_action: :threaten,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 emotional_state: %{fear: 95}
               )

      assert reason =~ "Overwhelming fear"
    end

    test "moderate fear does not refuse attack" do
      assert {:ok, :approved, _reason, :attack} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:combat],
                 emotional_state: %{fear: 60}
               )
    end

    test "fear does not affect non-combat actions" do
      assert {:ok, :approved, _reason, :praise} =
               ActionPolicy.validate(
                 proposed_action: :praise,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 emotional_state: %{fear: 95}
               )
    end
  end

  describe "ActionPolicy — attachment-driven protection override" do
    test "high attachment and gratitude overrides attack to protect" do
      assert {:ok, :transformed, reason, :protect} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:combat],
                 emotional_state: %{fear: 50, attachment: 80},
                 relationship_state: %{gratitude: 60}
               )

      assert reason =~ "attachment"
    end

    test "high attachment but low gratitude does not override" do
      assert {:ok, :approved, _reason, :attack} =
               ActionPolicy.validate(
                 proposed_action: :attack,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:combat],
                 emotional_state: %{fear: 50, attachment: 85},
                 relationship_state: %{gratitude: 30}
               )
    end

    test "attachment override applies to threaten" do
      assert {:ok, :transformed, reason, :protect} =
               ActionPolicy.validate(
                 proposed_action: :threaten,
                 character_status: :active,
                 target_character_id: @target_id,
                 scene_participant_ids: @scene_ids,
                 character_capabilities: [:combat, :guard],
                 emotional_state: %{fear: 50, attachment: 75},
                 relationship_state: %{gratitude: 55}
               )

      assert reason =~ "protect"
    end
  end

  describe "ActionPolicy — invalid actions" do
    test "unknown action returns error" do
      assert {:error, reason} =
               ActionPolicy.validate(proposed_action: :dance_party)

      assert reason =~ "unknown"
    end

    test "nil action returns error" do
      assert {:error, reason} =
               ActionPolicy.validate(proposed_action: nil)

      assert reason =~ "unknown"
    end
  end

  describe "ActionResolver" do
    test "resolves an approved action" do
      {:ok, resolution} =
        ActionResolver.resolve(
          proposed_action: :observe,
          proposed_confidence: 0.9,
          proposed_reason: "Watching carefully"
        )

      assert resolution.proposed_action == :observe
      assert resolution.validation_status == :approved
      assert resolution.resolved_action == :observe
      assert resolution.proposed_confidence == 0.9
      assert resolution.proposed_reason == "Watching carefully"
      assert is_nil(resolution.rejection_reason)
      assert is_nil(resolution.transformation_reason)
    end

    test "resolves a rejected action with reason" do
      {:ok, resolution} =
        ActionResolver.resolve(
          proposed_action: :attack,
          character_status: :dead,
          target_character_id: @target_id,
          scene_participant_ids: @scene_ids
        )

      assert resolution.validation_status == :rejected
      assert resolution.rejection_reason =~ "dead"
    end

    test "resolves a transformed action with reason" do
      {:ok, resolution} =
        ActionResolver.resolve(
          proposed_action: :attack,
          character_status: :active,
          target_character_id: @target_id,
          scene_participant_ids: @scene_ids,
          character_capabilities: [:combat],
          emotional_state: %{fear: 85}
        )

      assert resolution.validation_status == :transformed
      assert resolution.resolved_action == :observe
      assert resolution.transformation_reason =~ "fear"
    end

    test "resolve! raises on error" do
      assert_raise ArgumentError, fn ->
        ActionResolver.resolve!(proposed_action: :invalid_action)
      end
    end

    test "resolve! returns map on success" do
      result =
        ActionResolver.resolve!(
          proposed_action: :observe,
          proposed_confidence: 0.5
        )

      assert result.validation_status == :approved
      assert result.proposed_confidence == 0.5
    end
  end
end
