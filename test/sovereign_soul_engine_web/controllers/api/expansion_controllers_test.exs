defmodule SovereignSoulEngineWeb.Api.ExpansionControllersTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.Characters

  setup %{conn: conn} do
    {:ok, char} =
      Characters.create_character(%{
        name: "Test Companion #{System.unique_integer([:positive])}",
        slug: "test-soul-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active"
      })

    conn = authenticate_api(conn)
    %{conn: conn, character: char}
  end

  describe "CircadianController" do
    test "GET /sse/api/circadian/status", %{conn: conn, character: char} do
      conn = get(conn, ~p"/sse/api/circadian/status?character_slug=#{char.slug}")
      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)
      assert is_map(body["circadian"])
      assert Map.has_key?(body["circadian"], "state")
    end

    test "POST /sse/api/circadian/chronotype sets night_owl", %{conn: conn, character: char} do
      conn =
        post(conn, ~p"/sse/api/circadian/chronotype", %{
          "character_slug" => char.slug,
          "chronotype" => "night_owl"
        })

      assert json_response(conn, 200)["status"] == "ok"
      assert json_response(conn, 200)["chronotype"] == "night_owl"
    end
  end

  describe "DreamController" do
    test "POST /sse/api/souls/dream triggers REM consolidation", %{conn: conn, character: char} do
      conn = post(conn, ~p"/sse/api/souls/dream", %{"character_slug" => char.slug})
      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)
      assert is_map(body["dream"])
      assert is_binary(body["dream"]["theme"])
    end

    test "GET /sse/api/souls/dream fetches dream history", %{conn: conn, character: char} do
      # Trigger once first
      _ = post(conn, ~p"/sse/api/souls/dream", %{"character_slug" => char.slug})

      conn = get(conn, ~p"/sse/api/souls/dream?character_slug=#{char.slug}")
      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)
      assert is_map(body["latest_dream"])
    end
  end

  describe "VoiceProsodyController" do
    test "GET /sse/api/voice/prosody returns acoustic modulation", %{conn: conn, character: char} do
      conn = get(conn, ~p"/sse/api/voice/prosody?character_slug=#{char.slug}")
      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)
      assert is_map(body["prosody"])
      assert Map.has_key?(body["prosody"], "pitch_semitones")
      assert Map.has_key?(body["prosody"], "rate_multiplier")
    end

    test "GET prosody falls back to goose for an unknown character", %{conn: conn} do
      conn = get(conn, ~p"/sse/api/voice/prosody?character_slug=missing-voice-character")
      body = json_response(conn, 200)
      assert body["status"] == "ok"
      assert body["character_slug"] == "missing-voice-character"
      assert is_map(body["prosody"])
    end

    test "POST synthesize returns a controlled error when local speech is unavailable", %{conn: conn} do
      conn =
        post(conn, ~p"/sse/api/voice/synthesize", %{
          "character_slug" => "missing-voice-character",
          "text" => "hello [REDACTED]"
        })

      assert json_response(conn, 400)["status"] == "error"
    end
  end

  describe "EdgeController" do
    test "GET /sse/api/edge/status reports connectivity", %{conn: conn, character: char} do
      conn = get(conn, ~p"/sse/api/edge/status?character_slug=#{char.slug}")
      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)
      assert is_map(body["edge"])
    end

    test "POST /sse/api/edge/toggle toggles force_local_offline", %{conn: conn, character: char} do
      conn =
        post(conn, ~p"/sse/api/edge/toggle", %{
          "character_slug" => char.slug,
          "enabled" => true
        })

      assert json_response(conn, 200)["status"] == "ok"
      assert json_response(conn, 200)["force_local_offline"] == true
    end
  end

  describe "NeighborhoodController" do
    test "GET /sse/api/neighborhood/posts lists local posts", %{conn: conn} do
      conn = get(conn, ~p"/sse/api/neighborhood/posts")
      assert json_response(conn, 200)["status"] == "ok"
      assert is_list(json_response(conn, 200)["posts"])
    end

    test "POST /sse/api/neighborhood/posts creates sanitized post", %{conn: conn, character: char} do
      conn =
        post(conn, ~p"/sse/api/neighborhood/posts", %{
          "character_slug" => char.slug,
          "zone" => "Night Owl Commons",
          "category" => "night_owl_musings",
          "content" => "Enjoying the calm darkness at 3 AM."
        })

      assert json_response(conn, 200)["status"] == "ok"
      assert json_response(conn, 200)["post"]["zone"] == "Night Owl Commons"
    end

    test "POST /sse/api/neighborhood/encounter processes P2P mesh greeting", %{
      conn: conn,
      character: char
    } do
      {:ok, peer} =
        Characters.create_character(%{
          name: "Peer Companion",
          slug: "peer-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active"
        })

      conn =
        post(conn, ~p"/sse/api/neighborhood/encounter", %{
          "soul_a" => char.slug,
          "soul_b" => peer.slug
        })

      assert json_response(conn, 200)["status"] == "ok"
      assert json_response(conn, 200)["encounter"]["resonance"] >= 50
    end
  end
end
