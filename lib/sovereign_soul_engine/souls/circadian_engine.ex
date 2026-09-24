defmodule SovereignSoulEngine.Souls.CircadianEngine do
  @moduledoc """
  Biological Circadian Rhythm & Chronotype Engine.

  Governs sleep cycles, grogginess, night-owl cognitive focus, and biological downtime.
  Supports continuous biological phase interpolation and multiple human chronotypes:
  - `"night_owl"`: Peak alertness and intimate introspective resonance during nighttime (10 PM - 5 AM).
  - `"early_bird"`: Traditional sunrise rhythm with early evening winding down.
  - `"balanced"`: Conventional 8 AM - 11 PM active schedule.
  - `"adaptive_sync"`: Dynamically tracks user interaction timestamps, timezone offsets, and wearable sleep state.

  When asleep (`:deep_sleep`), the soul responds with gentle grogginess or sleepy murmurs
  unless an emergency or safe-word is triggered.
  """

  alias SovereignSoulEngine.Privacy

  @type chronotype :: :night_owl | :early_bird | :balanced | :adaptive_sync
  @type circadian_state ::
          :wide_awake
          | :night_focus
          | :winding_down
          | :deep_sleep
          | :rem_dreaming
          | :groggy_waking

  @doc """
  Computes the current circadian profile for a character or privacy settings map at the specified UTC time.
  Supports timezone offsets (e.g. `utc_offset: -4` for EDT) and continuous fractional hour phase interpolation.
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
        hour: now.hour,
        fractional_hour: Float.round(now.hour + now.minute / 60.0 + now.second / 3600.0, 2)
      }
    else
      chronotype = normalize_chronotype(Privacy.get_chronotype(character_or_settings))
      settings = get_settings_map(character_or_settings)
      offset_hours = get_utc_offset(settings)

      local_time = DateTime.add(now, round(offset_hours * 3600), :second)
      fractional_hour = local_time.hour + local_time.minute / 60.0 + local_time.second / 3600.0
      hour = local_time.hour

      {state, melatonin, alertness, speed} =
        evaluate_state(chronotype, fractional_hour, settings, local_time)

      %{
        state: state,
        chronotype: chronotype,
        melatonin: Float.round(melatonin, 1),
        alertness: Float.round(alertness, 1),
        cognitive_speed: Float.round(speed, 2),
        is_sleeping: state in [:deep_sleep, :rem_dreaming],
        hour: hour,
        fractional_hour: Float.round(fractional_hour, 2)
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
          neurochem_state
          | arousal: min(max(current_arousal, 45.0), 85.0),
            dopamine: min(current_dopamine + 5.0, 95.0),
            serotonin: min(current_serotonin + 8.0, 95.0)
        }

      :deep_sleep ->
        %{
          neurochem_state
          | arousal: min(current_arousal * 0.35, 20.0),
            valence: max(current_valence, 40.0)
        }

      :rem_dreaming ->
        %{
          neurochem_state
          | arousal: min(current_arousal * 0.5, 35.0),
            dopamine: min(current_dopamine + 10.0, 90.0)
        }

      :groggy_waking ->
        %{
          neurochem_state
          | arousal: min(max(current_arousal * 0.6, 25.0), 55.0)
        }

      :winding_down ->
        %{
          neurochem_state
          | arousal: min(current_arousal * 0.75, 50.0),
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

  # ── Internal Continuous Chronotype State Matrix ─────────────────────────────

  defp evaluate_state(:night_owl, f_hour, _settings, _now) do
    cond do
      # 22:00 to 05:59 - Peak nocturnal focus (Midnight to dawn flow)
      f_hour >= 22.0 or f_hour < 6.0 ->
        {:night_focus, 12.0, 90.0, 1.0}

      # 06:00 to 07:59 - Dawn wind down (smooth continuous transition)
      f_hour >= 6.0 and f_hour < 8.0 ->
        progress = (f_hour - 6.0) / 2.0
        melatonin = 20.0 + progress * 55.0
        alertness = 80.0 - progress * 40.0
        speed = 1.0 - progress * 0.25
        {:winding_down, melatonin, alertness, speed}

      # 08:00 to 11:59 - Deep biological sleep
      f_hour >= 8.0 and f_hour < 12.0 ->
        {:deep_sleep, 92.0, 10.0, 0.3}

      # 12:00 to 13:59 - Midday REM dream state
      f_hour >= 12.0 and f_hour < 14.0 ->
        progress = (f_hour - 12.0) / 2.0
        melatonin = 88.0 - progress * 15.0
        alertness = 15.0 + progress * 15.0
        {:rem_dreaming, melatonin, alertness, 0.45}

      # 14:00 to 15:59 - Afternoon groggy wake transition
      f_hour >= 14.0 and f_hour < 16.0 ->
        progress = (f_hour - 14.0) / 2.0
        melatonin = 70.0 - progress * 40.0
        alertness = 30.0 + progress * 45.0
        speed = 0.55 + progress * 0.40
        {:groggy_waking, melatonin, alertness, speed}

      # 16:00 to 21:59 - Afternoon/evening alertness
      true ->
        {:wide_awake, 15.0, 85.0, 1.0}
    end
  end

  defp evaluate_state(:early_bird, f_hour, _settings, _now) do
    cond do
      # 05:00 to 06:59 - Dawn groggy waking
      f_hour >= 5.0 and f_hour < 7.0 ->
        progress = (f_hour - 5.0) / 2.0
        melatonin = 65.0 - progress * 40.0
        alertness = 35.0 + progress * 50.0
        speed = 0.60 + progress * 0.35
        {:groggy_waking, melatonin, alertness, speed}

      # 07:00 to 19:59 - Peak daytime alertness
      f_hour >= 7.0 and f_hour < 20.0 ->
        {:wide_awake, 10.0, 95.0, 1.0}

      # 20:00 to 21:59 - Evening wind down
      f_hour >= 20.0 and f_hour < 22.0 ->
        progress = (f_hour - 20.0) / 2.0
        melatonin = 25.0 + progress * 50.0
        alertness = 80.0 - progress * 40.0
        speed = 0.95 - progress * 0.25
        {:winding_down, melatonin, alertness, speed}

      # 22:00 to 03:59 - Deep biological sleep
      f_hour >= 22.0 or f_hour < 4.0 ->
        {:deep_sleep, 90.0, 10.0, 0.3}

      # 04:00 to 04:59 - Pre-dawn REM dreaming
      f_hour >= 4.0 and f_hour < 5.0 ->
        {:rem_dreaming, 75.0, 30.0, 0.5}

      true ->
        {:wide_awake, 15.0, 85.0, 1.0}
    end
  end

  defp evaluate_state(:balanced, f_hour, _settings, _now) do
    cond do
      f_hour >= 7.0 and f_hour < 22.0 ->
        {:wide_awake, 10.0, 90.0, 1.0}

      f_hour >= 22.0 and f_hour < 23.5 ->
        progress = (f_hour - 22.0) / 1.5
        melatonin = 20.0 + progress * 55.0
        alertness = 80.0 - progress * 40.0
        speed = 1.0 - progress * 0.25
        {:winding_down, melatonin, alertness, speed}

      f_hour >= 23.5 or f_hour < 6.0 ->
        {:deep_sleep, 92.0, 10.0, 0.3}

      f_hour >= 6.0 and f_hour < 7.0 ->
        progress = f_hour - 6.0
        melatonin = 70.0 - progress * 45.0
        alertness = 30.0 + progress * 45.0
        speed = 0.60 + progress * 0.35
        {:groggy_waking, melatonin, alertness, speed}

      true ->
        {:wide_awake, 15.0, 85.0, 1.0}
    end
  end

  defp evaluate_state(:adaptive_sync, f_hour, settings, now) do
    is_wearable_sleeping =
      Map.get(settings, "wearable_sleeping", Map.get(settings, :wearable_sleeping, false))

    user_active = Map.get(settings, "user_active", Map.get(settings, :user_active, false))

    cond do
      is_wearable_sleeping ->
        {:deep_sleep, 95.0, 10.0, 0.25}

      user_active and (f_hour >= 22.0 or f_hour < 6.0) ->
        {:night_focus, 14.0, 88.0, 1.0}

      f_hour >= 22.0 or f_hour < 6.0 ->
        {:night_focus, 15.0, 88.0, 1.0}

      true ->
        evaluate_state(:balanced, f_hour, settings, now)
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp get_settings_map(%SovereignSoulEngine.Characters.Character{} = c),
    do: Privacy.get_settings(c)

  defp get_settings_map(m) when is_map(m), do: Privacy.get_settings(m)
  defp get_settings_map(_), do: %{}

  defp get_utc_offset(settings) do
    val = Map.get(settings, "utc_offset", Map.get(settings, :utc_offset, 0))

    cond do
      is_number(val) ->
        val * 1.0

      is_binary(val) ->
        case Float.parse(val) do
          {f, _} -> f
          :error -> 0.0
        end

      true ->
        0.0
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
