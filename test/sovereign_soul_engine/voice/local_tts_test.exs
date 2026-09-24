defmodule SovereignSoulEngine.Voice.LocalTTSTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Voice.LocalTTS

  test "reports whether edge-tts is installed without raising" do
    assert is_boolean(LocalTTS.available?())
  end

  test "rejects blank speech before invoking the CLI" do
    assert {:error, :empty_text} = LocalTTS.generate_speech("  \n  ")
  end

  test "resolves known character voices case-insensitively" do
    assert LocalTTS.resolve_voice("MAYA") == "en-US-JennyNeural"
    assert LocalTTS.resolve_voice(%{slug: "RAVINA"}) == "en-GB-LibbyNeural"
  end

  test "uses the default voice for unknown or invalid characters" do
    assert LocalTTS.resolve_voice("unknown") == "en-US-AriaNeural"
    assert LocalTTS.resolve_voice(nil) == "en-US-AriaNeural"
    assert LocalTTS.resolve_voice(:invalid) == "en-US-AriaNeural"
  end
end
