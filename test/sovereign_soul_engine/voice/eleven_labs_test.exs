defmodule SovereignSoulEngine.Voice.ElevenLabsTest do
  use ExUnit.Case, async: true

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
