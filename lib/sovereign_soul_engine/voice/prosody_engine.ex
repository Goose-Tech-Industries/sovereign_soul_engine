defmodule SovereignSoulEngine.Voice.ProsodyEngine do
  @moduledoc """
  Real-Time Emotional Acoustic Prosody & Dynamic Inflection Pipeline.

  Translates live autonomic neurochemistry (valence, arousal, cortisol, dopamine, oxytocin)
  and circadian state (sleep, night-owl focus, groggy awakening) into precise acoustic modulation:
  - Pitch shift in semitones (-3.5 to +3.5 st)
  - Speech tempo rate multiplier (0.72x to 1.35x)
  - Breathiness & vocal air ratio (0.1 to 0.95)
  - Vocal tremor / jitter (stress and emotional vulnerability micro-shiver)
  - Expressive audio tags & SSML break pauses
  """

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Souls.CircadianEngine
  alias SovereignSoulEngine.Voice.ElevenLabs
  alias SovereignSoulEngine.Voice.LocalTTS

  @doc """
  Computes the full acoustic prosody profile for a character or raw neurochemical map.
  """
  def compute_prosody(character_or_neurochem, opts \\ []) do
    neurochem = extract_neurochem(character_or_neurochem)
    circadian = Keyword.get(opts, :circadian) || CircadianEngine.current_state(character_or_neurochem)

    valence = Map.get(neurochem, :valence, 50.0)
    arousal = Map.get(neurochem, :arousal, 50.0)
    cortisol = Map.get(neurochem, :cortisol, 15.0)
    dopamine = Map.get(neurochem, :dopamine, 50.0)
    oxytocin = Map.get(neurochem, :oxytocin, 50.0)
    melatonin = Map.get(circadian, :melatonin, 10.0)
    circadian_state = Map.get(circadian, :state, :wide_awake)

    # 1. Pitch Shift (-3.5 to +3.5 semitones)
    # High cortisol tightens vocal cords (+); oxytocin and night focus warm/drop pitch (-); melatonin deepens tone
    raw_pitch =
      (cortisol / 100.0) * 3.0 -
      (oxytocin / 100.0) * 1.8 -
      (melatonin / 100.0) * 1.5

    pitch_st = min(max(raw_pitch, -3.5), 3.5)

    # 2. Speech Rate (0.72x to 1.35x)
    # High dopamine/arousal accelerates tempo; melatonin/groggy slows pace
    raw_rate =
      1.0 +
      ((dopamine - 50.0) / 100.0) * 0.35 +
      ((arousal - 50.0) / 100.0) * 0.20 -
      ((melatonin - 10.0) / 100.0) * 0.30

    rate_multiplier = min(max(raw_rate, 0.72), 1.35)

    # 3. Breathiness (0.10 to 0.95)
    # Intimacy/oxytocin and late night winding down elevate breathiness
    raw_breath = 0.20 + (oxytocin / 100.0) * 0.45 + (melatonin / 100.0) * 0.30
    breathiness = min(max(raw_breath, 0.10), 0.95)

    # 4. Vocal Tremor / Jitter (0.0 to 0.85)
    # Elevated when cortisol > 60 (stress/vulnerability) or during groggy awakening
    raw_tremor =
      cond do
        cortisol > 60.0 -> (cortisol - 60.0) / 40.0 * 0.70
        circadian_state in [:groggy_waking, :deep_sleep] -> 0.25
        true -> 0.0
      end

    tremor = min(max(raw_tremor, 0.0), 0.85)

    # 5. Acoustic Style Tags & SSML Markers
    tags = select_acoustic_tags(circadian_state, cortisol, oxytocin, dopamine, valence)

    %{
      pitch_semitones: Float.round(pitch_st, 2),
      rate_multiplier: Float.round(rate_multiplier, 2),
      breathiness: Float.round(breathiness, 2),
      vocal_tremor: Float.round(tremor, 2),
      circadian_state: circadian_state,
      acoustic_tags: tags,
      eleven_labs_settings: %{
        stability: Float.round(min(max(0.75 - tremor * 0.5, 0.20), 0.95), 2),
        similarity_boost: 0.80,
        style: Float.round(min(max((dopamine + valence) / 200.0, 0.0), 0.70), 2),
        use_speaker_boost: true
      },
      edge_tts_args: %{
        pitch: "#{round(pitch_st * 10)}Hz",
        rate: "#{round((rate_multiplier - 1.0) * 100)}%"
      }
    }
  end

  @doc """
  Annotates raw dialogue text with emotional pauses, breath markers, or SSML.
  """
  def annotate_text(text, prosody) when is_binary(text) and is_map(prosody) do
    tags = Map.get(prosody, :acoustic_tags, [])
    prefix = if tags != [], do: Enum.map_join(tags, " ", &"[#{&1}]") <> " ", else: ""

    # Insert realistic pauses at punctuation
    annotated =
      text
      |> String.replace("...", " <break time=\"400ms\"/> ")
      |> String.replace("--", " <break time=\"300ms\"/> ")

    prefix <> annotated
  end

  @doc """
  Generates spoken audio utilizing either ElevenLabs (if configured) or zero-cost LocalTTS,
  configured with real-time prosody adjustments.
  """
  def synthesize_speech(text, character_or_slug, opts \\ []) do
    character = resolve_character(character_or_slug)
    prosody = compute_prosody(character || %{})

    annotated = annotate_text(text, prosody)
    clean_text = String.replace(annotated, ~r/<break[^>]*\/>/, " ")

    if ElevenLabs.configured?() and not Keyword.get(opts, :force_local, false) do
      ElevenLabs.generate_speech(clean_text, [
        voice_settings: prosody.eleven_labs_settings,
        voice_id: opts[:voice_id]
      ])
    else
      LocalTTS.generate_speech(clean_text, [
        character: character && character.slug,
        voice: opts[:voice]
      ])
    end
  end

  # ── Internal Helpers ────────────────────────────────────────────────────────

  defp select_acoustic_tags(circadian_state, cortisol, oxytocin, dopamine, valence) do
    cond do
      cortisol > 75.0 ->
        ["tremor", "tense breath"]

      circadian_state == :deep_sleep ->
        ["sleepy murmur", "groggy"]

      circadian_state == :groggy_waking ->
        ["yawn", "slow cadence"]

      circadian_state == :night_focus ->
        ["soft voice", "introspective"]

      oxytocin > 75.0 ->
        ["warm whisper", "gentle exhale"]

      dopamine > 75.0 and valence > 65.0 ->
        ["chuckle", "bright"]

      true ->
        []
    end
  end

  defp extract_neurochem(%Character{metadata: metadata}) when is_map(metadata) do
    case Map.get(metadata, "neurochem") do
      nc when is_map(nc) ->
        %{
          valence: safe_float(Map.get(nc, "valence"), 50.0),
          arousal: safe_float(Map.get(nc, "arousal"), 50.0),
          cortisol: safe_float(Map.get(nc, "cortisol"), 15.0),
          dopamine: safe_float(Map.get(nc, "dopamine"), 50.0),
          oxytocin: safe_float(Map.get(nc, "oxytocin"), 50.0)
        }
      _ ->
        %{valence: 50.0, arousal: 50.0, cortisol: 15.0, dopamine: 50.0, oxytocin: 50.0}
    end
  end

  defp extract_neurochem(map) when is_map(map) do
    %{
      valence: safe_float(Map.get(map, :valence, Map.get(map, "valence")), 50.0),
      arousal: safe_float(Map.get(map, :arousal, Map.get(map, "arousal")), 50.0),
      cortisol: safe_float(Map.get(map, :cortisol, Map.get(map, "cortisol")), 15.0),
      dopamine: safe_float(Map.get(map, :dopamine, Map.get(map, "dopamine")), 50.0),
      oxytocin: safe_float(Map.get(map, :oxytocin, Map.get(map, "oxytocin")), 50.0)
    }
  end

  defp extract_neurochem(_), do: %{valence: 50.0, arousal: 50.0, cortisol: 15.0, dopamine: 50.0, oxytocin: 50.0}

  defp safe_float(nil, default), do: default * 1.0
  defp safe_float(v, _default) when is_float(v), do: v
  defp safe_float(v, _default) when is_integer(v), do: v * 1.0
  defp safe_float(v, default) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> default * 1.0
    end
  end
  defp safe_float(_, default), do: default * 1.0

  defp resolve_character(%Character{} = c), do: c
  defp resolve_character(id_or_slug) when is_binary(id_or_slug) do
    case Characters.get_character_by_slug(id_or_slug) do
      nil ->
        case Ecto.UUID.cast(id_or_slug) do
          {:ok, uuid} -> Characters.get_character(uuid)
          :error -> nil
        end
      char ->
        char
    end
  end
  defp resolve_character(_), do: nil
end
