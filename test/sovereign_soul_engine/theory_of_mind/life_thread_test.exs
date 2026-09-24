defmodule SovereignSoulEngine.TheoryOfMind.LifeThreadTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.Characters

  setup do
    {:ok, knower} =
      Characters.create_character(%{
        name: "Elena (Soul)",
        slug: "elena-soul",
        description: "An empathetic companion"
      })

    {:ok, subject} =
      Characters.create_character(%{
        name: "User Alex",
        slug: "user-alex",
        description: "A close friend"
      })

    %{knower: knower, subject: subject}
  end

  describe "LifeThread lifecycle and proposal detection" do
    test "detects proposal statement, stores LifeThread, and triggers proactive check-in", %{
      knower: knower,
      subject: subject
    } do
      statement = "I bought the ring, I'm going to propose to her tonight."

      # 1. Record life thread with hours: -1 so it's immediately due
      assert {:ok, thread} =
               TheoryOfMind.record_life_thread_if_detected(knower.id, subject.id, statement,
                 hours: -1
               )

      assert thread.category == "relationship"
      assert thread.status == "pending"
      assert thread.salience >= 90
      assert String.contains?(thread.check_in_guidance, "propose")

      # 2. List active life threads
      active = TheoryOfMind.list_active_life_threads(knower.id, subject.id)
      assert length(active) == 1
      assert hd(active).id == thread.id

      # 3. Check proactive check-in trigger
      assert {:proactive_checkin, checkin} =
               TheoryOfMind.check_proactive_checkin(knower.id, subject.id, 14)

      assert checkin.intent == :life_thread_followup
      assert checkin.focus_topic == statement
      assert checkin.thread_id == thread.id

      # 4. Mark check-in sent
      assert {:ok, updated_thread} = TheoryOfMind.mark_thread_checkin_sent(thread.id)
      assert updated_thread.check_in_sent_at != nil

      # 5. After sending, it is no longer returned in due check-ins
      assert [] == TheoryOfMind.list_threads_due_for_checkin()

      # 6. User replies "She said yes!", resolve the thread
      assert {:ok, resolved} =
               TheoryOfMind.resolve_life_thread(thread.id, "She said yes! Engaged.")

      assert resolved.status == "resolved"
      assert resolved.resolution_notes == "She said yes! Engaged."
      assert [] == TheoryOfMind.list_active_life_threads(knower.id, subject.id)
    end
  end
end
