defmodule SovereignSoulEngine.Memories.DreamLoopTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Memories.DreamLoop

  describe "DreamLoop — biological memory consolidation & emotional decay" do
    setup do
      {:ok, char} =
        Characters.create_character(%{
          name: "Dreamer",
          slug: "dreamer-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active"
        })

      {:ok, profile} =
        Souls.create_soul_profile(%{
          character_id: char.id,
          core_values: ["Always protect the weak"],
          baseline_emotions: %{
            anger: 10,
            fear: 10,
            stress: 15,
            rumination_intensity: 0
          }
        })

      {:ok, emotional} =
        Souls.create_emotional_state(%{
          character_id: char.id,
          anger: 60,
          fear: 50,
          stress: 80,
          rumination_intensity: 70
        })

      %{character: char, profile: profile, emotional_state: emotional}
    end

    test "decays emotional residue toward baseline emotions", %{character: char} do
      assert %{anger: new_anger, stress: new_stress} =
               DreamLoop.decay_emotional_residue(char.id, 0.4)

      # Anger: 60 -> (60 - (60-10)*0.4) = 40
      assert new_anger < 60
      assert new_anger >= 10

      # Stress: 80 -> (80 - (80-15)*0.4) = 54
      assert new_stress < 80
      assert new_stress >= 15

      reloaded = Souls.get_emotional_state_by_character(char.id)
      assert reloaded.rumination_intensity < 70
    end

    test "distills low-importance episodic memories into a consolidated core memory", %{
      character: char
    } do
      # Create 3 episodic memories
      for i <- 1..3 do
        {:ok, _} =
          Memories.create_memory(%{
            owner_character_id: char.id,
            category: "episodic",
            summary: "Met a traveler by the road #{i}",
            importance: 25,
            emotional_intensity: 30,
            tags: ["traveler", "road"],
            status: "active",
            occurred_at: DateTime.utc_now()
          })
      end

      # Run consolidation cycle
      {:ok, result} = DreamLoop.run_cycle(char.id, force: true)

      assert result.character_id == char.id
      assert length(result.distilled_memories) >= 1

      distilled = List.first(result.distilled_memories)
      assert distilled.category == "core"
      assert "dream_distilled" in distilled.tags
      assert distilled.importance > 25

      # Verify original memories are marked consolidated
      active = Memories.list_memories_for_character(char.id)
      # The 3 original ones are consolidated, only the distilled core memory is active
      assert Enum.count(active, &(&1.category == "core")) >= 1
      assert Enum.count(active, &(&1.status == "active" and &1.category == "episodic")) == 0
    end
  end
end
