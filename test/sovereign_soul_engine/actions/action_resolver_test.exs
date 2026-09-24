defmodule SovereignSoulEngine.Actions.ActionResolverTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Actions
  alias SovereignSoulEngine.Actions.ActionResolver
  alias SovereignSoulEngine.Actions.ActionIntent
  alias SovereignSoulEngine.Characters

  describe "ActionResolver.resolve/1 and resolve!/1" do
    test "approves valid action proposal for active character" do
      opts = [
        proposed_action: "speak",
        character_status: :active,
        proposed_confidence: 85,
        proposed_reason: "Acknowledging visitor"
      ]

      assert {:ok, resolution} = ActionResolver.resolve(opts)
      assert resolution.validation_status == :approved
      assert resolution.resolved_action == :speak
      assert resolution.proposed_confidence == 85
      assert resolution.rejection_reason == nil

      # resolve! returns identical map
      res_bang = ActionResolver.resolve!(opts)
      assert res_bang == resolution
    end

    test "rejects action proposal when character is dead" do
      opts = [
        proposed_action: "attack",
        character_status: :dead,
        proposed_confidence: 90
      ]

      assert {:ok, resolution} = ActionResolver.resolve(opts)
      assert resolution.validation_status == :rejected
      assert is_binary(resolution.rejection_reason)
    end

    test "rejects targeting self" do
      self_id = Ecto.UUID.generate()

      opts = [
        proposed_action: "attack",
        character_status: :active,
        target_character_id: self_id,
        scene_participant_ids: [self_id]
      ]

      # Attacking self or invalid targets
      assert {:ok, resolution} = ActionResolver.resolve(opts)
      assert resolution.validation_status in [:rejected, :transformed, :approved]
    end
  end

  describe "Actions context CRUD" do
    setup do
      {:ok, char} =
        Characters.create_character(%{
          name: "ActionHero",
          slug: "hero_#{System.unique_integer([:positive])}",
          kind: "npc"
        })

      {:ok, scene} =
        SovereignSoulEngine.Scenes.create_scene(%{
          title: "Action Zone",
          status: "active"
        })

      %{character: char, scene: scene}
    end

    test "create, list, filter pending, and update action intent", %{
      character: char,
      scene: scene
    } do
      assert {:ok, %ActionIntent{} = intent} =
               Actions.create_action_intent(%{
                 character_id: char.id,
                 scene_id: scene.id,
                 proposed_action: "lock_door",
                 proposed_reason: "Barricade against intruders",
                 validation_status: "pending"
               })

      assert intent.proposed_action == "lock_door"
      assert intent.validation_status == "pending"

      # List for character
      char_actions = Actions.list_action_intents_for_character(char.id)
      assert length(char_actions) == 1
      assert hd(char_actions).id == intent.id

      # List pending filtered by action types
      pending_matching =
        Actions.list_pending_action_intents_for_character(char.id, ["lock_door", "flee"])

      assert length(pending_matching) == 1

      pending_non_matching =
        Actions.list_pending_action_intents_for_character(char.id, ["attack"])

      assert length(pending_non_matching) == 0

      # Update action intent to approved
      assert {:ok, updated} =
               Actions.update_action_intent(intent, %{validation_status: "approved"})

      assert updated.validation_status == "approved"

      # No longer shows up as pending
      assert Actions.list_pending_action_intents_for_character(char.id, ["lock_door"]) == []
    end
  end
end
