defmodule SovereignSoulEngine.TheoryOfMind.ProactiveDispatcherTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.TheoryOfMind.ProactiveDispatcher
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Scenes

  setup do
    {:ok, knower} =
      Characters.create_character(%{
        name: "Elena (Soul)",
        slug: "elena-proactive",
        description: "An empathetic companion",
        kind: "npc",
        status: "active"
      })

    {:ok, subject} =
      Characters.create_character(%{
        name: "Alex",
        slug: "alex-user",
        description: "A close friend",
        kind: "player",
        status: "active"
      })

    %{knower: knower, subject: subject}
  end

  describe "dispatch_due_threads/0" do
    test "dispatches follow-up message to direct scene when thread is due", %{
      knower: knower,
      subject: subject
    } do
      # 1. Arm a thread that is already due (hours: -1)
      statement = "I'm going to propose to her tonight."
      {:ok, thread} =
        TheoryOfMind.record_life_thread_if_detected(knower.id, subject.id, statement, hours: -1)

      assert thread.status == "pending"

      # 2. Run dispatch
      {:ok, dispatched_count} = ProactiveDispatcher.dispatch_due_threads()
      assert dispatched_count == 1

      # 3. Verify message was created in the direct scene
      scene = Scenes.find_or_create_direct_scene(subject, knower)
      messages = Scenes.list_messages(scene.id)

      assert length(messages) >= 1
      last_msg = List.last(messages)
      assert last_msg.character_id == knower.id
      assert String.contains?(last_msg.content, "propose") or String.contains?(last_msg.content, "hear how it went")

      # 4. Verify thread check_in_sent_at was marked
      active_due = TheoryOfMind.list_threads_due_for_checkin()
      assert active_due == []

      # 5. Running dispatch again results in 0
      {:ok, second_count} = ProactiveDispatcher.dispatch_due_threads()
      assert second_count == 0
    end
  end

  describe "checkin_for_somatic_event/3" do
    test "dispatches acute stress somatic check-in message", %{knower: knower, subject: subject} do
      {:ok, msg} =
        ProactiveDispatcher.checkin_for_somatic_event(subject.id, :acute_stress, %{
          stress: 88,
          hr: 118
        })

      assert msg.character_id == knower.id
      assert msg.content =~ "stress spike" or msg.content =~ "grounding breath"

      scene = Scenes.find_or_create_direct_scene(subject, knower)
      scene_messages = Scenes.list_messages(scene.id)
      assert Enum.any?(scene_messages, &(&1.id == msg.id))
    end

    test "dispatches morning waking check-in message", %{subject: subject} do
      {:ok, msg} =
        ProactiveDispatcher.checkin_for_somatic_event(subject.id, :morning_waking, %{
          sleep_hours: 8.0
        })

      assert msg.content =~ "Good morning"
      assert msg.content =~ "8"
    end

    test "dispatches late night insomnia check-in message", %{subject: subject} do
      {:ok, msg} =
        ProactiveDispatcher.checkin_for_somatic_event(subject.id, :late_night_insomnia, %{
          hour: 3
        })

      assert msg.content =~ "middle of the night" or msg.content =~ "awake"
    end

    test "dispatches recovery dip check-in message", %{subject: subject} do
      {:ok, msg} =
        ProactiveDispatcher.checkin_for_somatic_event(subject.id, :recovery_dip, %{
          recovery_score: 42
        })

      assert msg.content =~ "smart ring"
      assert msg.content =~ "42"
    end
  end

  describe "harvest_life_threads/4 and Engine.detect_thread_candidate/1" do
    test "detects temporal commitments and dynamic hours", %{knower: knower, subject: subject} do
      {:ok, thread} =
        TheoryOfMind.harvest_life_threads(
          knower.id,
          subject.id,
          "My interview is tomorrow morning."
        )

      assert thread.category == "career"
      assert thread.due_at != nil
    end

    test "detects grief and loss events", %{knower: knower, subject: subject} do
      {:ok, thread} =
        TheoryOfMind.harvest_life_threads(
          knower.id,
          subject.id,
          "My grandmother passed away today."
        )

      assert thread.category == "personal_vulnerability"
      assert thread.salience >= 90
    end

    test "detects medical surgery events", %{knower: knower, subject: subject} do
      {:ok, thread} =
        TheoryOfMind.harvest_life_threads(
          knower.id,
          subject.id,
          "I have knee surgery scheduled for tomorrow."
        )

      assert thread.category == "health"
    end
  end
end
