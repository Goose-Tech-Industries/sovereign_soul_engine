defmodule SovereignSoulEngine.Vision.PerceptionEngineTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.Vision.PerceptionEngine

  setup do
    {:ok, npc} =
      Characters.create_character(%{
        name: "Vael",
        slug: "vael",
        kind: "npc",
        status: "active",
        description: "Observant tactician"
      })

    {:ok, player} =
      Characters.create_character(%{
        name: "Goose",
        slug: "goose",
        kind: "player",
        status: "active",
        description: "Primary user"
      })

    {:ok, _profile} =
      Souls.create_soul_profile(%{
        character_id: npc.id,
        archetype: "Tactician",
        core_wound: "Isolation",
        moral_alignment: "Lawful Neutral"
      })

    {:ok, _emotional} =
      Souls.create_emotional_state(%{
        character_id: npc.id,
        stress: 20,
        confidence: 80,
        attachment: 50
      })

    %{npc: npc, player: player}
  end

  describe "perceive/4" do
    test "processes visual frame, stores episodic memory, updates Theory of Mind, and generates reaction",
         %{
           npc: npc,
           player: player
         } do
      image_b64 = Base.encode64("sample_smart_glasses_visual_frame_binary")

      assert {:ok, result} =
               PerceptionEngine.perceive(npc, player, image_b64,
                 source: "smart_glasses",
                 generate_reaction: true
               )

      perception = result.perception
      assert is_binary(perception.scene_description)
      assert is_binary(perception.user_affect)
      assert is_list(perception.salient_objects)
      assert perception.source == "smart_glasses"
      assert is_binary(perception.analysis_mode)
      assert is_boolean(perception.synthetic)

      # Verify episodic memory was created
      memories = Memories.list_memories_for_character(npc.id)
      assert Enum.any?(memories, &("vision" in (&1.tags || [])))

      # Verify Theory of Mind knowledge was registered
      knowledge = TheoryOfMind.list_knowledge_about(npc.id, player.id)
      assert Enum.any?(knowledge, &String.contains?(&1.known_fact, "smart_glasses"))

      # Verify reaction dialogue was generated
      assert result.reaction != nil
      assert is_binary(result.reaction.content)
    end
  end
end
