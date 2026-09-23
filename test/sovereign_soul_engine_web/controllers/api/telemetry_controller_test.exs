defmodule SovereignSoulEngineWeb.Api.TelemetryControllerTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.TheoryOfMind

  setup do
    {:ok, player} =
      Characters.create_character(%{
        name: "Test Runner",
        slug: "runner-#{Ecto.UUID.generate()}",
        kind: "player",
        status: "active"
      })

    {:ok, npc} =
      Characters.create_character(%{
        name: "Test Observer",
        slug: "observer-#{Ecto.UUID.generate()}",
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
        stress: 15,
        confidence: 70
      })

    {:ok, player: player, npc: npc}
  end

  describe "POST /sse/api/telemetry/somatic" do
    test "ingests galaxy watch heart rate and stress metrics", %{
      conn: conn,
      player: player,
      npc: npc
    } do
      conn =
        conn
        |> authenticate_api()
        |> post(~p"/sse/api/telemetry/somatic", %{
          "character_slug" => player.slug,
          "device" => "galaxy_watch_10",
          "heart_rate" => 125,
          "stress_level" => 85,
          "fatigue" => 40
        })

      assert json = json_response(conn, 200)
      assert json["status"] == "ok"
      assert json["character_slug"] == player.slug
      assert json["device"] == "galaxy_watch_10"
      assert json["biometrics"]["heart_rate"] == 125
      assert json["biometrics"]["stress_level"] == 85
      assert json["somatic_state"]["fatigue"] == 40
      assert json["emotional_state"]["stress"] > 20
      assert json["companions_notified"] >= 1

      # Verify Theory of Mind fact was created for companion
      knowledge = TheoryOfMind.list_knowledge_about(npc.id, player.id)
      assert Enum.any?(knowledge, &String.contains?(&1.known_fact, "high physiological stress"))
    end

    test "handles sleep data and smart glasses ambient noise", %{conn: conn, player: player} do
      conn =
        conn
        |> authenticate_api()
        |> post(~p"/sse/api/telemetry/wearable", %{
          "character_slug" => player.slug,
          "device" => "smart_glasses",
          "sleep_hours" => 8.5,
          "ambient_noise_db" => 85.5
        })

      assert json = json_response(conn, 200)
      assert json["status"] == "ok"
      assert json["somatic_state"]["last_rested_at"] != nil
    end

    test "ingests smart ring recovery score and creates Theory of Mind awareness", %{
      conn: conn,
      player: player,
      npc: npc
    } do
      conn =
        conn
        |> authenticate_api()
        |> post(~p"/sse/api/telemetry/wearable", %{
          "character_slug" => player.slug,
          "device" => "oura_ring_gen4",
          "recovery_score" => 48,
          "readiness_score" => 52,
          "sleep_score" => 61
        })

      assert json = json_response(conn, 200)
      assert json["status"] == "ok"
      assert json["biometrics"]["recovery_score"] == 48
      assert json["biometrics"]["readiness_score"] == 52

      # Theory of Mind should capture recovery fact
      knowledge = TheoryOfMind.list_knowledge_about(npc.id, player.id)
      assert Enum.any?(knowledge, &String.contains?(&1.known_fact, "recovery score (48%)"))
    end

    test "ignores telemetry when user has opted out in privacy settings", %{
      conn: conn,
      player: player
    } do
      {:ok, _} =
        SovereignSoulEngine.Privacy.update_settings(player.id, %{
          "biometrics_tracking" => false
        })

      conn =
        conn
        |> authenticate_api()
        |> post(~p"/sse/api/telemetry/somatic", %{
          "character_slug" => player.slug,
          "device" => "galaxy_watch_10",
          "heart_rate" => 150,
          "stress_level" => 95
        })

      assert json = json_response(conn, 200)
      assert json["status"] == "ignored_by_privacy_settings"
    end

    test "returns 404 for unknown character", %{conn: conn} do
      conn =
        conn
        |> authenticate_api()
        |> post(~p"/sse/api/telemetry/somatic", %{
          "character_slug" => "non_existent_ghost"
        })

      assert json_response(conn, 404)["error"] =~ "not found"
    end
  end

  describe "GET /sse/api/telemetry/:slug" do
    test "returns somatic and emotional profile", %{conn: conn, player: player} do
      conn =
        conn
        |> authenticate_api()
        |> get(~p"/sse/api/telemetry/#{player.slug}")

      assert json = json_response(conn, 200)
      assert json["character_slug"] == player.slug
      assert json["somatic"]["fatigue"] == 20
      assert json["emotional"]["confidence"] == 70
    end
  end
end
