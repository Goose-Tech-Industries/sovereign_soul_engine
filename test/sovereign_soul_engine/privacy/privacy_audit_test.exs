defmodule SovereignSoulEngine.Privacy.PrivacyAuditTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.{Characters, Memories, Privacy, Scenes, Souls, TheoryOfMind}
  alias SovereignSoulEngine.Souls.SoulCapsule
  alias SovereignSoulEngine.TheoryOfMind.ProactiveDispatcher
  alias SovereignSoulEngine.Wearables.HapticEngine

  setup %{conn: conn} do
    {:ok, player} =
      Characters.create_character(%{
        name: "Test User",
        slug: "privacy-audit-player-#{Ecto.UUID.generate()}",
        kind: "player",
        status: "active"
      })

    {:ok, companion} =
      Characters.create_character(%{
        name: "Vael Auditor",
        slug: "privacy-audit-companion-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active"
      })

    {:ok, _somatic} =
      Souls.create_somatic_state(%{
        character_id: player.id,
        fatigue: 20,
        pain: 0
      })

    {:ok, _emotional} =
      Souls.create_emotional_state(%{
        character_id: player.id,
        stress: 20,
        confidence: 70
      })

    {:ok, _companion_somatic} =
      Souls.create_somatic_state(%{
        character_id: companion.id,
        fatigue: 10,
        pain: 0
      })

    {:ok, _companion_emotional} =
      Souls.create_emotional_state(%{
        character_id: companion.id,
        stress: 15,
        confidence: 80,
        attachment: 65
      })

    conn = authenticate_api(conn)
    %{conn: conn, player: player, companion: companion}
  end

  describe "1. Biometrics Ingest Opt-out" do
    test "ignores somatic telemetry when biometrics_tracking is disabled", %{
      conn: conn,
      player: player
    } do
      {:ok, _} = Privacy.update_settings(player.id, %{"biometrics_tracking" => false})

      conn =
        post(conn, ~p"/sse/api/telemetry/somatic", %{
          "character_slug" => player.slug,
          "device" => "galaxy_watch_10",
          "heart_rate" => 140,
          "stress_level" => 90
        })

      assert json = json_response(conn, 200)
      assert json["status"] == "ignored_by_privacy_settings"

      # Ensure no emotional state mutation or companion knowledge was created
      emotional = Souls.get_emotional_state_by_character(player.id)
      assert emotional.stress == 20
    end
  end

  describe "2. Vision Perception Opt-out" do
    test "returns 403 Forbidden when camera_vision is disabled", %{
      conn: conn,
      player: player,
      companion: companion
    } do
      {:ok, _} = Privacy.update_settings(player.id, %{"camera_vision" => false})

      conn =
        post(conn, ~p"/sse/api/vision/perceive", %{
          "player_slug" => player.slug,
          "character_slug" => companion.slug,
          "image_data" => "base64encodeddummydata"
        })

      assert json = json_response(conn, 403)
      assert json["error"] =~ "disabled in user privacy settings"
    end
  end

  describe "3. Haptic Tactile Engine Opt-out" do
    test "rejects dispatch and drops pubsub when haptic_feedback is disabled", %{
      player: player
    } do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "character:#{player.id}:haptics")

      signal = HapticEngine.signal_for_event(:proactive_ping)

      # Allowed initially
      assert {:ok, _} = HapticEngine.dispatch(player.id, signal)
      assert_receive {:haptic_pulse, _}, 500

      # Disable haptics
      {:ok, _} = Privacy.update_settings(player.id, %{"haptic_feedback" => false})

      assert {:ignored, :disabled_by_privacy_settings} =
               HapticEngine.dispatch(player.id, signal)

      refute_receive {:haptic_pulse, _}, 200
    end
  end

  describe "4. Smart Home Sync Graceful Fallback" do
    test "sync endpoint returns 200 with graceful disabled status instead of crashing", %{
      conn: conn,
      companion: companion
    } do
      {:ok, _} = Privacy.update_settings(companion.id, %{"ambient_lighting" => false})

      conn = post(conn, ~p"/api/smart_home/sync", %{"character_slug" => companion.slug})

      assert json = json_response(conn, 200)
      assert json["status"] == "ignored_by_privacy_settings"
      assert json["synced"] == false
      assert json["message"] =~ "ambient lighting is disabled in user privacy settings"
    end
  end

  describe "5. Amazon Alexa Voice Opt-out" do
    test "returns paused voice response when alexa_voice is disabled", %{
      conn: conn,
      companion: companion
    } do
      {:ok, _} = Privacy.update_settings(companion.id, %{"alexa_voice" => false})

      payload = %{
        "version" => "1.0",
        "request" => %{
          "type" => "LaunchRequest",
          "requestId" => "amzn1.echo-api.request.test"
        },
        "character_slug" => companion.slug
      }

      conn = post(conn, ~p"/api/alexa", payload)
      assert json = json_response(conn, 200)

      assert json["response"]["outputSpeech"]["text"] =~
               "voice integration is currently paused in your privacy settings"

      assert json["response"]["shouldEndSession"] == true
    end
  end

  describe "6. Proactive Dispatcher Privacy Controls" do
    test "suppresses check-ins when proactive_checkins is disabled", %{
      player: player,
      companion: companion
    } do
      # Create an overdue life thread
      {:ok, thread} =
        TheoryOfMind.record_life_thread_if_detected(
          companion.id,
          player.id,
          "I have a big presentation in 2 hours",
          hours: -1
        )

      assert thread.status == "pending"

      # Disable proactive check-ins on subject
      {:ok, _} = Privacy.update_settings(player.id, %{"proactive_checkins" => false})

      # Run dispatcher
      {:ok, count} = ProactiveDispatcher.dispatch_due_threads()
      assert count == 0

      # Scene should have 0 messages from companion
      scene = Scenes.find_or_create_direct_scene(player, companion)
      messages = Scenes.list_messages(scene.id)
      assert messages == []
    end

    test "suppresses somatic stress check-in when somatic_stress_checkins is disabled", %{
      player: player,
      companion: _companion
    } do
      {:ok, _} = Privacy.update_settings(player.id, %{"somatic_stress_checkins" => false})

      assert {:ignored, :disabled_by_privacy_settings} =
               ProactiveDispatcher.checkin_for_somatic_event(player.id, :acute_stress, %{
                 stress: 95,
                 hr: 130
               })
    end
  end

  describe "7. Durable Deletion & Purge Across Derived Records" do
    test "completely purges memories, knowledge facts, and life threads across all characters", %{
      conn: conn,
      player: player,
      companion: companion
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # 1. Seed memory about knee surgery
      {:ok, _mem} =
        Memories.create_memory(%{
          owner_character_id: player.id,
          summary: "Scheduled for urgent knee surgery tomorrow",
          category: "episodic",
          importance: 90,
          emotional_intensity: 80,
          occurred_at: now,
          status: "active",
          tags: ["knee", "surgery", "hospital"]
        })

      # 2. Seed memory on another unrelated topic
      {:ok, _unrelated_mem} =
        Memories.create_memory(%{
          owner_character_id: player.id,
          summary: "Bought groceries at the organic market",
          category: "episodic",
          importance: 30,
          emotional_intensity: 10,
          occurred_at: now,
          status: "active",
          tags: ["groceries", "market"]
        })

      # 3. Seed companion Theory of Mind knowledge about the player's surgery
      {:ok, _fact} =
        TheoryOfMind.create_knowledge(%{
          knower_character_id: companion.id,
          subject_character_id: player.id,
          known_fact: "Patient is anxious about upcoming knee surgery",
          certainty: 90
        })

      # 4. Seed overdue Life Thread about the surgery
      {:ok, thread} =
        TheoryOfMind.record_life_thread_if_detected(
          companion.id,
          player.id,
          "I have knee surgery scheduled for tomorrow",
          hours: -1
        )

      assert thread.status == "pending"

      # Pre-condition: check that 2 memories, 1 knowledge, 1 thread exist
      assert length(Memories.list_memories_for_character(player.id)) == 2
      assert length(TheoryOfMind.list_knowledge_about(companion.id, player.id)) == 1
      assert length(TheoryOfMind.list_threads_due_for_checkin()) == 1

      # 5. Purge by topic "surgery" via API
      conn =
        post(conn, ~p"/sse/api/memories/purge", %{
          "character_slug" => player.slug,
          "topic" => "surgery"
        })

      assert json = json_response(conn, 200)
      assert json["status"] == "ok"
      assert json["memories_deleted"] == 1
      assert json["knowledge_facts_deleted"] == 1
      assert json["life_threads_deleted"] == 1

      # 6. Verify database records:
      # Memory about surgery is permanently deleted
      remaining_memories = Memories.list_memories_for_character(player.id)
      assert length(remaining_memories) == 1
      assert hd(remaining_memories).summary =~ "groceries"

      # Knowledge facts about surgery are eradicated
      remaining_knowledge = TheoryOfMind.list_knowledge_about(companion.id, player.id)
      assert remaining_knowledge == []

      # Life threads about surgery are removed, preventing ghost check-ins
      assert TheoryOfMind.list_threads_due_for_checkin() == []
      {:ok, dispatched} = ProactiveDispatcher.dispatch_due_threads()
      assert dispatched == 0
    end
  end

  describe "8. Soul Capsule HMAC Integrity & Anti-Tampering" do
    test "tampered capsule payload fails HMAC validation on import", %{player: player} do
      {:ok, capsule} = SoulCapsule.export_capsule(player)
      assert is_binary(capsule["checksum"])

      # Tamper with the capsule payload (inject unauthorized prompt or attribute)
      tampered = put_in(capsule, ["soul", "character", "name"], "Hacked Persona Name")

      assert {:error, :checksum_mismatch_corrupted_capsule} =
               SoulCapsule.import_capsule(tampered)
    end

    test "capsule imported with mismatched secret key fails verification", %{player: player} do
      {:ok, capsule} = SoulCapsule.export_capsule(player, secret_key: "audit-secret-key-alpha")

      assert {:error, :checksum_mismatch_corrupted_capsule} =
               SoulCapsule.import_capsule(capsule, secret_key: "audit-secret-key-beta")

      # Untampered with matching key succeeds
      assert {:ok, _} =
               SoulCapsule.import_capsule(capsule,
                 secret_key: "audit-secret-key-alpha",
                 overwrite: false
               )
    end
  end
end
