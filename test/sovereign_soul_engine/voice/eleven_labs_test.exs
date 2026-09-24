defmodule SovereignSoulEngine.Voice.ElevenLabsTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.Voice
  alias SovereignSoulEngine.Voice.ElevenLabs

  describe "configuration" do
    test "configured?/1 returns false when no key is provided" do
      refute ElevenLabs.configured?(api_key: nil)
      refute ElevenLabs.configured?(api_key: "")
    end

    test "configured?/1 returns true when key is present" do
      assert ElevenLabs.configured?(api_key: "test_key_123")
    end
  end

  describe "validation" do
    test "generate_speech/2 returns error when key is missing" do
      assert {:error, "ELEVENLABS_API_KEY not configured"} =
               ElevenLabs.generate_speech("Hello", api_key: nil)
    end

    test "list_voices parses the account voice payload" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "voices" => [
            %{
              "voice_id" => "v1",
              "name" => "Rook",
              "category" => "cloned",
              "description" => "clear",
              "preview_url" => nil,
              "labels" => %{"accent" => "irish"}
            }
          ]
        })
      end)

      assert {:ok, [%{voice_id: "v1", name: "Rook", labels: %{"accent" => "irish"}}]} =
               ElevenLabs.list_voices(
                 api_key: "test_key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end

    test "get_subscription maps subscription fields" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "tier" => "creator",
          "character_count" => 10,
          "character_limit" => 100,
          "status" => "active",
          "next_character_count_reset_unix" => 42
        })
      end)

      assert {:ok, %{tier: "creator", character_count: 10, status: "active"}} =
               ElevenLabs.get_subscription(
                 api_key: "test_key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end

    test "maps provider HTTP failures for voices and subscription" do
      Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 429, "rate limited") end)

      assert {:error, "elevenlabs_http_429: \"rate limited\""} =
               ElevenLabs.list_voices(
                 api_key: "test_key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )

      assert {:error, "elevenlabs_http_429: \"rate limited\""} =
               ElevenLabs.get_subscription(
                 api_key: "test_key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end

    test "maps a TTS provider HTTP failure" do
      Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 500, "offline") end)

      assert {:error, "elevenlabs_http_500: \"offline\""} =
               ElevenLabs.generate_speech(
                 "Hello",
                 api_key: "test_key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end

    test "generate_speech/2 returns error on empty text" do
      assert {:error, :empty_text} =
               ElevenLabs.generate_speech("", api_key: "test_key_123")
    end

    test "Voice.speak_message/2 returns error when not configured" do
      message = %SovereignSoulEngine.Scenes.SceneMessage{
        content: "I am speaking."
      }

      # Without global ELEVENLABS_API_KEY set
      if not Voice.configured?() do
        assert {:error, :not_configured_or_empty} = Voice.speak_message(message, nil)
      end
    end
  end
end
