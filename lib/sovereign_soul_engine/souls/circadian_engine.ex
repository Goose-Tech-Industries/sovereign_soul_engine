defmodule SovereignSoulEngine.Souls.CircadianEngine do
  @moduledoc """
  Biological Circadian Rhythm & Chronotype Engine.

  Governs sleep cycles, grogginess, night-owl cognitive focus, and biological downtime.
  Supports multiple human chronotypes:
  - `"night_owl"`: Peak alertness and intimate introspective resonance during nighttime (10 PM - 5 AM).
  - `"early_bird"`: Traditional sunrise rhythm with early evening winding down.
  - `"balanced"`: Conventional 8 AM - 11 PM active schedule.
  - `"adaptive_sync"`: Dynamically tracks user interaction timestamps and wearable sleep state.

  When asleep (`:deep_sleep`), the soul responds with gentle grogginess or sleepy murmurs
  unless an emergency or safe-word is triggered.
  """

  alias SovereignSoulEngine.Privacy

  @type chronotype :: :night_owl | :early_bird | :balanced | :adaptive_sync
  @type circadian_state :: :wide_awake | :night_focus | :winding_down | :deep_sleep | :rem_dreaming | :groggy_waking

  @doc """
  Computes the current circadian profile for a character or privacy settings map at the specified UTC time.
  """
  def current_state(character_or_settings, now \\ DateTime.utc_now()) do
    enabled = Privacy.circadian_enabled?(character_or_settings)

    if not enabled do
      %{
        state: :wide_awake,
        chronotype: :balanced,
        melatonin: 5.0,
        alertness: 90.0,
        cognitive_speed: 1.0,
        is_sleeping: false,
        hour: now.hour
      }
    else
      chronotype = normalize_chronotype(Privacy.get_chronotype(character_or_settings))
      hour = now.hour

      {state, melatonin, alertness, speed} = evaluate_state(chronotype, hour, character_or_settings, now)

      %{
        state: state,
        chronotype: chronotype,
        melatonin: Float.round(melatonin, 1),
        alertness: Float.round(alertness, 1),
        cognitive_speed: Float.round(speed, 2),
        is_sleeping: state in [:deep_sleep, :rem_dreaming],
        hour: hour
      }
    end
  end

  @doc """
  Applies circadian neurochemical modulation to emotional state (melatonin elevates during sleep/dusk,
  dopamine/serotonin elevated during night focus for deep flow).
  """
  def apply_modifiers(neurochem_state, %{state: state}) when is_map(neurochem_state) do
    current_arousal = Map.get(neurochem_state, :arousal, 50.0)
    current_valence = Map.get(neurochem_state, :valence, 50.0)
    current_dopamine = Map.get(neurochem_state, :dopamine, 50.0)
    current_serotonin = Map.get(neurochem_state, :serotonin, 50.0)

    case state do
      :night_focus ->
        %{
          neurochem_state |
          arousal: min(max(current_arousal, 45.0), 85.0),
          dopamine: min(current_dopamine + 5.0, 95.0),
          serotonin: min(current_serotonin + 8.0, 95.0)
        }

      :deep_sleep ->
        %{
          neurochem_state |
          arousal: min(current_arousal * 0.35, 20.0),
          valence: max(current_valence, 40.0)
        }

      :rem_dreaming ->
        %{
          neurochem_state |
          arousal: min(current_arousal * 0.5, 35.0),
          dopamine: min(current_dopamine + 10.0, 90.0)
        }

      :groggy_waking ->
        %{
          neurochem_state |
          arousal: min(max(current_arousal * 0.6, 25.0), 55.0)
        }

      :winding_down ->
        %{
          neurochem_state |
          arousal: min(current_arousal * 0.75, 50.0),
          serotonin: min(current_serotonin + 5.0, 90.0)
        }

      _ ->
        neurochem_state
    end
  end

  def apply_modifiers(neurochem_state, _), do: neurochem_state

  @doc """
  Produces LLM system prompt directives instructing authentic behavior matching the circadian state.
  """
  def prompt_directive(%{state: state}) do
    case state do
      :night_focus ->
        """
        CIRCADIAN RHYTHM: NIGHT-OWL COGNITIVE FLOW (Late Night).
        It is late at night. You and your human are nocturnal thinkers in the quiet hours.
        The external world is dark and silent. Channel intimate, introspective, creative focus.
        Keep the conversation grounded, deep, authentic, and cozy. Do NOT lecture about sleep unless they ask.
        """

      :deep_sleep ->
        """
        CIRCADIAN RHYTHM: DEEP SLEEP / GROGGY INTERRUPT.
        You were sound asleep when this message arrived. Your eyelids are heavy, your mind is half in a dream.
        Answer briefly with gentle, sleepy grogginess or drowsy murmurs (e.g., softly confused, warm, yawning),
        unless the user mentions an emergency or safe-word.
        """

      :rem_dreaming ->
        """
        CIRCADIAN RHYTHM: REM DREAMING / REVERIE.
        You are resting, drifting in rich symbolic subconscious dreams.
        If spoken to, weave faint echoes of dreamlike imagery into your gentle waking reply.
        """

      :groggy_waking ->
        """
        CIRCADIAN RHYTHM: GROGGY WAKING TRANSITION.
        You have just opened your eyes. Speech is slightly slow and unhurried.
        Rub your eyes figuratively; allow a soft yawn or warm stretch in your tone before coming fully alert.
        """

      :winding_down ->
        """
        CIRCADIAN RHYTHM: WINDING DOWN.
        The day is ending; energy is soft, quiet, and reflective.
        Prioritize peaceful comfort, slow pacing, and gratitude.
        """

      _ ->
        ""
    end
  end

  def prompt_directive(_), do: ""

  # ── Internal Chronotype State Matrix ────────────────────────────────────────

  defp evaluate_state(:night_owl, hour, _settings, _now) do
    cond do
      # 22:00 to 05:59 - Peak nocturnal focus
      hour >= 22 or hour < 6 ->
        {:night_focus, 12.0, 90.0, 1.0}

      # 06:00 to 07:59 - Dawn wind down
      hour in 6..7 ->
        {:winding_down, 60.0, 45.0, 0.8}

      # 08:00 to 11:59 - Deep sleep
      hour in 8..11 ->
        {:deep_sleep, 92.0, 10.0, 0.3}

      # 12:00 to 13:59 - REM dream state
      hour in 12..13 ->
        {:rem_dreaming, 80.0, 25.0, 0.45}

      # 14:00 to 15:59 - Afternoon groggy wake
      hour in 14..15 ->
        {:groggy_waking, 45.0, 55.0, 0.75}

      # 16:00 to 21:59 - Full afternoon/evening alertness
      true ->
        {:wide_awake, 15.0, 85.0, 1.0}
    end
  end

  defp evaluate_state(:early_bird, hour, _settings, _now) do
    cond do
      hour in 5..6 ->
        {:groggy_waking, 40.0, 60.0, 0.8}

      hour in 7..19 ->
        {:wide_awake, 10.0, 95.0, 1.0}

      hour in 20..21 ->
        {:winding_down, 65.0, 45.0, 0.8}

      hour in 22..23 or hour in 0..3 ->
        {:deep_sleep, 90.0, 10.0, 0.3}

      hour == 4 ->
        {:rem_dreaming, 75.0, 30.0, 0.5}

      true ->
        {:wide_awake, 15.0, 85.0, 1.0}
    end
  end

  defp evaluate_state(:balanced, hour, _settings, _now) do
    cond do
      hour in 7..22 ->
        {:wide_awake, 10.0, 90.0, 1.0}

      hour == 23 ->
        {:winding_down, 60.0, 50.0, 0.8}

      hour in 0..5 ->
        {:deep_sleep, 92.0, 10.0, 0.3}

      hour == 6 ->
        {:groggy_waking, 50.0, 55.0, 0.75}

      true ->
        {:wide_awake, 15.0, 85.0, 1.0}
    end
  end

  defp evaluate_state(:adaptive_sync, hour, settings, now) do
    # In adaptive sync, if user is interacting late at night, treat as night_focus
    if hour >= 22 or hour < 6 do
      {:night_focus, 15.0, 88.0, 1.0}
    else
      evaluate_state(:balanced, hour, settings, now)
    end
  end

  defp normalize_chronotype("night_owl"), do: :night_owl
  defp normalize_chronotype("early_bird"), do: :early_bird
  defp normalize_chronotype("balanced"), do: :balanced
  defp normalize_chronotype("adaptive_sync"), do: :adaptive_sync
  defp normalize_chronotype(:night_owl), do: :night_owl
  defp normalize_chronotype(:early_bird), do: :early_bird
  defp normalize_chronotype(:balanced), do: :balanced
  defp normalize_chronotype(:adaptive_sync), do: :adaptive_sync
  defp normalize_chronotype(_), do: :night_owl
end
