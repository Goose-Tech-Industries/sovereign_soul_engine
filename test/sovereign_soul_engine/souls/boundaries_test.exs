defmodule SovereignSoulEngine.Souls.BoundariesTest do
  use SovereignSoulEngine.DataCase, async: false
  alias SovereignSoulEngine.{Characters, Souls}

  test "default creation APIs return validation errors without inserting records" do
    for function <- [
          :create_soul_profile,
          :create_emotional_state,
          :create_soul_shadow,
          :create_soul_fear,
          :create_belief,
          :create_trigger,
          :create_desire,
          :create_secret,
          :create_moral_line,
          :create_somatic_state,
          :create_grief_arc,
          :create_forgiveness_arc,
          :create_goal
        ] do
      assert {:error, changeset} = apply(Souls, function, [])
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).character_id
    end
  end

  test "ambient relevance uses names and configured topics, otherwise stays silent" do
    {:ok, npc} =
      Characters.create_character(%{
        name: "Al Nightkeeper",
        slug: Ecto.UUID.generate(),
        kind: "npc",
        status: "active"
      })

    refute Souls.interested_in_message?(npc, "hello all")
    assert Souls.interested_in_message?(npc, "NIGHTKEEPER, are you there?")
    refute Souls.interested_in_message?(npc, "")

    {:ok, trigger} =
      Souls.create_trigger(%{character_id: npc.id, topic: "Storm", reaction_type: "anger_spike"})

    assert Souls.interested_in_message?(npc, "A STORM is coming")
    {:ok, _} = Souls.update_trigger(trigger, %{topic: "Fire"})
    refute Souls.interested_in_message?(npc, "A storm is coming")
    assert Souls.interested_in_message?(npc, "Fire in the square")
  end
end
