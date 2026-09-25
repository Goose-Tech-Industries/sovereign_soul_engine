defmodule SovereignSoulEngine.Voice.ProsodyEngineBoundaryTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Voice.ProsodyEngine

  @awake %{state: :wide_awake, melatonin: 10.0}

  test "computes bounded neutral prosody from a raw neurochemical map" do
    result = ProsodyEngine.compute_prosody(%{}, circadian: @awake)

    assert result.pitch_semitones >= -3.5 and result.pitch_semitones <= 3.5
    assert result.rate_multiplier >= 0.72 and result.rate_multiplier <= 1.35
    assert result.breathiness >= 0.10 and result.breathiness <= 0.95
    assert result.vocal_tremor == 0.0
    assert result.acoustic_tags == []
  end

  test "stress and night states produce distinct acoustic tags" do
    stressed = ProsodyEngine.compute_prosody(%{cortisol: 90}, circadian: @awake)
    sleepy = ProsodyEngine.compute_prosody(%{}, circadian: %{state: :deep_sleep, melatonin: 90})
    intimate = ProsodyEngine.compute_prosody(%{oxytocin: 90}, circadian: @awake)

    assert stressed.acoustic_tags == ["tremor", "tense breath"]
    assert stressed.vocal_tremor > 0
    assert sleepy.acoustic_tags == ["sleepy murmur", "groggy"]
    assert intimate.acoustic_tags == ["warm whisper", "gentle exhale"]
  end

  test "annotates pauses and acoustic tags" do
    prosody = %{acoustic_tags: ["soft voice"]}

    assert ProsodyEngine.annotate_text("Wait... no--really", prosody) ==
             "[soft voice] Wait <break time=\"400ms\"/>  no <break time=\"300ms\"/> really"

    assert ProsodyEngine.annotate_text("plain", %{acoustic_tags: []}) == "plain"
  end

  test "accepts string neurochemical values and clamps ranges" do
    result =
      ProsodyEngine.compute_prosody(
        %{"valence" => "100", "arousal" => "100", "cortisol" => "100", "dopamine" => "100"},
        circadian: %{state: :night_focus, melatonin: 0}
      )

    assert result.rate_multiplier == 1.31
    assert result.vocal_tremor == 0.7
    assert result.acoustic_tags == ["tremor", "tense breath"]
  end

  test "falls back to defaults for malformed neurochemical input" do
    result = ProsodyEngine.compute_prosody(:unknown, circadian: @awake)
    assert result.circadian_state == :wide_awake
    assert result.eleven_labs_settings.use_speaker_boost
    assert result.edge_tts_args.pitch =~ "Hz"
  end
end
