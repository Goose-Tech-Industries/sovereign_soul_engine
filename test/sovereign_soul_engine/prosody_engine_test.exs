defmodule SovereignSoulEngine.Voice.ProsodyEngineTest do
  use SovereignSoulEngine.DataCase, async: true

  alias SovereignSoulEngine.Voice.ProsodyEngine

  describe "compute_prosody/2" do
    test "high cortisol tightens pitch and elevates vocal tremor" do
      high_stress_neurochem = %{
        valence: 30.0,
        arousal: 80.0,
        cortisol: 85.0,
        dopamine: 40.0,
        oxytocin: 15.0
      }

      prosody = ProsodyEngine.compute_prosody(high_stress_neurochem)

      assert prosody.pitch_semitones > 0.0
      assert prosody.vocal_tremor > 0.3
      assert "tremor" in prosody.acoustic_tags or "tense breath" in prosody.acoustic_tags
    end

    test "high oxytocin and late night winding down drops pitch and increases breathiness" do
      warm_calm_neurochem = %{
        valence: 75.0,
        arousal: 35.0,
        cortisol: 10.0,
        dopamine: 55.0,
        oxytocin: 85.0
      }

      prosody = ProsodyEngine.compute_prosody(warm_calm_neurochem, circadian: %{melatonin: 40.0, state: :winding_down})

      assert prosody.pitch_semitones < 0.0
      assert prosody.breathiness > 0.6
      assert prosody.vocal_tremor == 0.0
    end
  end

  describe "annotate_text/2" do
    test "injects break tags at pauses and prepends acoustic tags" do
      prosody = %{
        acoustic_tags: ["warm whisper"],
        pitch_semitones: -1.2,
        rate_multiplier: 0.95
      }

      raw_text = "I am right here... take your time."
      annotated = ProsodyEngine.annotate_text(raw_text, prosody)

      assert annotated =~ "[warm whisper]"
      assert annotated =~ "<break time=\"400ms\"/>"
    end
  end
end
