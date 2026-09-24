defmodule SovereignSoulEngine.Souls.DreamEngineTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Souls.DreamEngine
  alias SovereignSoulEngine.Characters

  setup do
    {:ok, char} =
      Characters.create_character(%{
        name: "Dream Test Companion",
        slug: "dream-test-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active"
      })

    %{character: char}
  end

  test "consolidate_and_dream/2 synthesizes symbolic dream and updates metadata", %{
    character: character
  } do
    {:ok, dream} = DreamEngine.consolidate_and_dream(character.id)

    assert is_binary(dream.id)
    assert is_binary(dream.theme)
    assert is_binary(dream.symbolic_narrative)
    assert is_binary(dream.subconscious_epiphany)
    assert is_binary(dream.wake_dialogue_hook)
    assert is_map(dream.emotional_residual)

    # Check persistence
    {:ok, latest} = DreamEngine.get_latest_dream(character.id)
    assert latest["id"] == dream.id or latest[:id] == dream.id

    {:ok, journal} = DreamEngine.list_dream_journal(character.id)
    assert length(journal) >= 1

    {:ok, hook} = DreamEngine.wake_dialogue_hook(character.id)
    assert is_binary(hook)
    assert hook =~ "dream"
  end
end
