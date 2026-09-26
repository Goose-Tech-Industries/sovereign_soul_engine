defmodule SovereignSoulEngine.Social.NPCSchedulerTransitionsTest do
  use SovereignSoulEngine.DataCase, async: false
  alias SovereignSoulEngine.{Characters, Souls}
  alias SovereignSoulEngine.Social.NPCScheduler

  defp npc do
    {:ok, c} =
      Characters.create_character(%{
        name: "Scheduler",
        slug: Ecto.UUID.generate(),
        kind: "npc",
        status: "active"
      })

    c
  end

  defp tick do
    state = %{
      tick_count: 0,
      last_tick_at: nil,
      conversations_run: 0,
      random: fn -> 1.0 end,
      task_runner: fn _ -> {:ok, self()} end
    }

    assert {:noreply, next} = NPCScheduler.handle_cast(:tick, state)
    assert next.tick_count == 1
    assert next.conversations_run == 0
    assert %DateTime{} = next.last_tick_at
  end

  test "tick regenerates stamina, advances bodily needs and decays emotions" do
    c = npc()

    {:ok, _} =
      Souls.create_soul_profile(%{
        character_id: c.id,
        social_stamina: 95,
        stamina_max: 100,
        stamina_regen_rate: 10
      })

    {:ok, _} =
      Souls.create_somatic_state(%{
        character_id: c.id,
        hunger: 99,
        fatigue: 30,
        pain: 5,
        illness_severity: 2
      })

    {:ok, _} =
      Souls.create_emotional_state(%{
        character_id: c.id,
        anger: 50,
        fear: 40,
        stress: 50,
        shame: 30,
        guilt: 20,
        rumination_intensity: 1,
        rumination_subject: "old argument"
      })

    tick()
    assert Souls.get_soul_profile_by_character(c.id).social_stamina == 100
    body = Souls.get_somatic_state_by_character(c.id)
    assert {body.hunger, body.fatigue, body.pain, body.illness_severity} == {100, 32, 3, 1}
    emotion = Souls.get_emotional_state_by_character(c.id)
    assert {emotion.anger, emotion.fear, emotion.stress} == {45, 36, 46}
    assert emotion.rumination_intensity == 0
    assert emotion.rumination_subject == nil
  end

  test "recent rest restores fatigue; inactive NPCs remain unchanged" do
    c = npc()

    {:ok, _} =
      Souls.create_somatic_state(%{
        character_id: c.id,
        fatigue: 20,
        last_rested_at: DateTime.utc_now()
      })

    inactive = npc()
    {:ok, _} = Characters.update_character(inactive, %{status: "dead"})
    {:ok, _} = Souls.create_somatic_state(%{character_id: inactive.id, hunger: 4})
    tick()
    assert Souls.get_somatic_state_by_character(c.id).fatigue == 12
    assert Souls.get_somatic_state_by_character(inactive.id).hunger == 4
  end

  test "old unblocked goals advance but blocked goals remain untouched" do
    c = npc()
    {:ok, goal} = Souls.create_goal(%{character_id: c.id, goal: "Explore", priority: 90})

    {:ok, blocked} =
      Souls.create_goal(%{character_id: c.id, goal: "Wait", blocker: "Locked", priority: 100})

    old = NaiveDateTime.add(NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second), -10800)

    Repo.update_all(
      from(g in SovereignSoulEngine.Goals.CharacterGoal, where: g.character_id == ^c.id),
      set: [updated_at: old]
    )

    tick()
    assert Repo.reload!(goal).progress_notes =~ "Autonomous progress"
    assert Repo.reload!(blocked).progress_notes == blocked.progress_notes
  end

  test "grief resolves integration while recent grief stays unchanged" do
    c = npc()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, arc} =
      Souls.create_grief_arc(%{
        character_id: c.id,
        subject: "Home",
        stage: "integration",
        intensity: 20,
        triggered_at: now
      })

    {:ok, recent} =
      Souls.create_grief_arc(%{
        character_id: c.id,
        subject: "Friend",
        intensity: 70,
        triggered_at: now,
        last_progressed_at: now
      })

    tick()
    assert Repo.reload!(arc).is_resolved
    assert Repo.reload!(arc).intensity == 17
    assert Repo.reload!(recent).intensity == 70
  end

  test "forgiveness moves healing, hardening and neutral arcs independently" do
    c = npc()

    arcs =
      for {direction, intensity} <- [{"healing", 29}, {"hardening", 71}, {"neutral", 50}] do
        {:ok, arc} =
          Souls.create_forgiveness_arc(%{
            character_id: c.id,
            wound_description: direction,
            direction: direction,
            intensity: intensity
          })

        arc
      end

    tick()

    assert Enum.map(arcs, fn arc ->
             a = Repo.reload!(arc)
             {a.intensity, a.stage}
           end) == [{27, "festering"}, {72, "festering"}, {49, "fresh"}]
  end
end
