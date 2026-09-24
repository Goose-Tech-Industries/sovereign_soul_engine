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

  test "writes audio metadata after a successful deterministic CLI call" do
    filename = "local-tts-test-#{System.unique_integer([:positive])}"

    runner = fn _cmd, args, _opts ->
      path = Enum.at(args, 5)
      File.write!(path, "fake-mp3")
      {"ok", 0}
    end

    assert {:ok, %{audio_url: "/sse/audio/souls/" <> ^filename <> ".mp3", bytes: 8}} =
             LocalTTS.generate_speech("*smiles* Hello",
               filename: filename,
               command: "fake",
               cmd_fun: runner
             )
  end

  test "returns a structured error when edge-tts fails" do
    runner = fn _cmd, _args, _opts -> {"bad command", 2} end

    assert {:error, {:edge_tts_failed, 2, "bad command"}} =
             LocalTTS.generate_speech("Hello", command: "fake", cmd_fun: runner)
  end
end
