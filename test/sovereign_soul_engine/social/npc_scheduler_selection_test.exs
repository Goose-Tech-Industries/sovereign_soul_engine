defmodule SovereignSoulEngine.Social.NPCSchedulerSelectionTest do
  use SovereignSoulEngine.DataCase, async: false
  alias SovereignSoulEngine.{Characters, Souls, Scenes, Relationships}
  alias SovereignSoulEngine.Social.NPCScheduler

  defp npc(stamina \\ 80) do
    {:ok, c} =
      Characters.create_character(%{
        name: "Resident",
        slug: Ecto.UUID.generate(),
        kind: "npc",
        status: "active"
      })

    {:ok, _} =
      Souls.create_soul_profile(%{
        character_id: c.id,
        social_stamina: stamina,
        stamina_regen_rate: 0,
        core_values: ["honesty"],
        fears: ["loss"]
      })

    c
  end

  defp tick do
    state = %{
      tick_count: 0,
      last_tick_at: nil,
      conversations_run: 0,
      random: fn -> 0.0 end,
      task_runner: fn fun ->
        send(self(), {:scheduled, fun})
        {:ok, self()}
      end
    }

    {:noreply, next} = NPCScheduler.handle_cast(:tick, state)
    next
  end

  test "pair selection dispatches a conversation and social activity" do
    a = npc()
    b = npc()

    {:ok, rel} =
      Relationships.create_relationship(%{
        source_character_id: a.id,
        target_character_id: b.id,
        relationship_type: "friend",
        affinity: 99,
        trust: 99,
        anger: 60
      })

    assert tick().conversations_run == 1
    assert_receive {:scheduled, conversation}
    assert is_function(conversation, 0)
    assert_receive {:scheduled, social}
    assert is_function(social, 0)
    refute_received {:scheduled, _}
    updated = Repo.reload!(rel)
    assert updated.trust == 100
    assert updated.affinity == 100
    assert updated.anger == 59
  end

  test "insufficient stamina prevents conversation dispatch" do
    npc(0)
    npc(10)
    assert tick().conversations_run == 0
    assert_receive {:scheduled, _social}
    refute_received {:scheduled, _conversation}
  end

  test "a single NPC cannot start a conversation" do
    npc()
    assert tick().conversations_run == 0
    assert_receive {:scheduled, _social}
    refute_received {:scheduled, _}
  end

  test "recent player activity excludes the NPC from passive ticks and conversations" do
    busy = npc(20)
    npc()

    {:ok, player} =
      Characters.create_character(%{
        name: "Player",
        slug: Ecto.UUID.generate(),
        kind: "player",
        status: "active"
      })

    {:ok, scene} = Scenes.create_scene(%{title: "In conversation", status: "active"})

    for c <- [busy, player] do
      {:ok, _} = Scenes.add_participant(%{scene_id: scene.id, character_id: c.id})
    end

    {:ok, _} =
      Scenes.create_message(%{
        scene_id: scene.id,
        character_id: player.id,
        message_type: "dialogue",
        content: "Hello"
      })

    {:ok, _} = Souls.create_somatic_state(%{character_id: busy.id, hunger: 12})
    assert tick().conversations_run == 0
    assert Souls.get_somatic_state_by_character(busy.id).hunger == 12
  end
end
