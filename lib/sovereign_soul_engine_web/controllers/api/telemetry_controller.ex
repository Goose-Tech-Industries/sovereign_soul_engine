defmodule SovereignSoulEngineWeb.Api.TelemetryController do
  @moduledoc """
  Ingests real-time somatic telemetry from wearables (Samsung Galaxy Watch,
  Apple Watch, Garmin) and smart glasses (Ray-Ban Meta, Solos).

  Translates raw biological sensors (heart rate, stress, sleep, ambient noise)
  into the character's somatic/emotional states and broadcasts high-order
  perceptions into companion Theory of Mind.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.EmotionalState
  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.Repo
  import Ecto.Query

  @doc """
  POST /sse/api/telemetry/somatic
  POST /sse/api/telemetry/wearable
  """
  def create(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"

    case Characters.get_character_by_slug(character_slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Character '#{character_slug}' not found."})

      %Character{} = character ->
        telemetry = extract_telemetry(params)
        {:ok, somatic} = sync_somatic_state(character, telemetry)
        {:ok, emotional} = sync_emotional_state(character, telemetry)
        notified_count = sync_companion_theory_of_mind(character, telemetry)
        broadcast_telemetry(character, telemetry, somatic, emotional)

        # Trigger biofeedback calming haptic cadence on acute stress
        if (telemetry.stress_level && telemetry.stress_level >= 75) ||
             (telemetry.heart_rate && telemetry.heart_rate >= 105 && telemetry.motion_state != "running") do
          calming_signal = SovereignSoulEngine.Wearables.HapticEngine.signal_for_event(:calming_guidance)
          SovereignSoulEngine.Wearables.HapticEngine.dispatch(character.id, calming_signal)
        end

        conn
        |> put_status(:ok)
        |> json(%{
          status: "ok",
          character_slug: character.slug,
          device: telemetry.device_type,
          biometrics: %{
            heart_rate: telemetry.heart_rate,
            hrv: telemetry.hrv,
            stress_level: telemetry.stress_level,
            motion_state: telemetry.motion_state,
            sleep_hours: telemetry.sleep_hours,
            steps: telemetry.steps,
            ambient_noise_db: telemetry.ambient_noise_db
          },
          somatic_state: %{
            fatigue: somatic.fatigue,
            pain: somatic.pain,
            hunger: somatic.hunger,
            last_rested_at: somatic.last_rested_at
          },
          emotional_state: %{
            stress: emotional.stress,
            confidence: emotional.confidence,
            attachment: emotional.attachment
          },
          companions_notified: notified_count,
          timestamp: DateTime.utc_now()
        })
    end
  end

  @doc """
  GET /sse/api/telemetry/:slug
  Returns latest somatic & emotional biometric profile for character.
  """
  def show(conn, %{"slug" => slug}) do
    case Characters.get_character_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Character '#{slug}' not found."})

      %Character{} = character ->
        somatic = Souls.get_or_create_somatic_state(character.id)
        emotional = Repo.get_by(EmotionalState, character_id: character.id)

        json(conn, %{
          character_slug: character.slug,
          character_name: character.name,
          somatic: %{
            fatigue: somatic.fatigue,
            pain: somatic.pain,
            hunger: somatic.hunger,
            illness_severity: somatic.illness_severity,
            last_rested_at: somatic.last_rested_at
          },
          emotional:
            if emotional do
              %{
                stress: emotional.stress,
                anger: emotional.anger,
                fear: emotional.fear,
                gratitude: emotional.gratitude,
                confidence: emotional.confidence,
                sadness: emotional.sadness,
                curiosity: emotional.curiosity,
                attachment: emotional.attachment
              }
            else
              nil
            end
        })
    end
  end

  # ── Private Helpers ──────────────────────────────────────────────────────────

  defp extract_telemetry(params) do
    %{
      device_type: params["device"] || params["device_type"] || "galaxy_watch",
      heart_rate: parse_int(params["heart_rate"]),
      hrv: parse_int(params["hrv"]),
      stress_level: parse_int(params["stress_level"]),
      fatigue: parse_int(params["fatigue"]),
      pain: parse_int(params["pain"]),
      steps: parse_int(params["steps"]),
      sleep_hours: parse_float(params["sleep_hours"]),
      skin_temp: parse_float(params["skin_temp"]),
      ambient_noise_db: parse_float(params["ambient_noise_db"]),
      motion_state: params["motion_state"] || "stationary"
    }
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_float(nil), do: nil
  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {fl, _} -> fl
      :error -> nil
    end
  end

  defp sync_somatic_state(character, telemetry) do
    somatic = Souls.get_or_create_somatic_state(character.id)
    attrs = %{}

    attrs =
      if telemetry.fatigue do
        Map.put(attrs, :fatigue, clamp(telemetry.fatigue, 0, 100))
      else
        cond do
          telemetry.sleep_hours && telemetry.sleep_hours >= 7.5 ->
            Map.put(attrs, :fatigue, max(0, somatic.fatigue - 25))

          telemetry.sleep_hours && telemetry.sleep_hours <= 4.5 ->
            Map.put(attrs, :fatigue, min(100, somatic.fatigue + 35))

          true ->
            attrs
        end
      end

    attrs =
      if telemetry.sleep_hours do
        Map.put(attrs, :last_rested_at, DateTime.utc_now())
      else
        attrs
      end

    attrs =
      if telemetry.pain do
        Map.put(attrs, :pain, clamp(telemetry.pain, 0, 100))
      else
        attrs
      end

    if map_size(attrs) > 0 do
      Souls.update_somatic_state(somatic, attrs)
    else
      {:ok, somatic}
    end
  end

  defp sync_emotional_state(character, telemetry) do
    case Repo.get_by(EmotionalState, character_id: character.id) do
      nil ->
        {:ok, %EmotionalState{stress: 20, confidence: 60, attachment: 50}}

      %EmotionalState{} = emotional ->
        attrs = %{}

        attrs =
          cond do
            telemetry.stress_level != nil ->
              target = clamp(telemetry.stress_level, 0, 100)
              smoothed = round(0.4 * emotional.stress + 0.6 * target)
              Map.put(attrs, :stress, clamp(smoothed, 0, 100))

            telemetry.heart_rate != nil && telemetry.heart_rate > 105 && telemetry.motion_state != "running" ->
              Map.put(attrs, :stress, min(100, emotional.stress + 15))

            telemetry.heart_rate != nil && telemetry.heart_rate < 70 ->
              Map.put(attrs, :stress, max(0, emotional.stress - 10))

            true ->
              attrs
          end

        if map_size(attrs) > 0 do
          Souls.update_emotional_state(emotional, attrs)
        else
          {:ok, emotional}
        end
    end
  end

  defp sync_companion_theory_of_mind(character, telemetry) do
    companions =
      Repo.all(
        from c in Character,
          where: c.kind == "npc" and c.status == "active"
      )

    facts = build_biometric_facts(character.name, telemetry)

    Enum.reduce(companions, 0, fn npc, acc ->
      Enum.each(facts, fn fact ->
        TheoryOfMind.upsert_knowledge(npc.id, character.id, fact,
          certainty: 95,
          is_assumption: false
        )
      end)

      acc + 1
    end)
  end

  defp build_biometric_facts(name, telemetry) do
    facts = []

    facts =
      cond do
        telemetry.stress_level != nil && telemetry.stress_level >= 75 ->
          [
            "#{name}'s wearable biometrics show high physiological stress (#{telemetry.stress_level}%, HR: #{telemetry.heart_rate || "elevated"} bpm)."
            | facts
          ]

        telemetry.stress_level != nil && telemetry.stress_level <= 25 ->
          [
            "#{name}'s biometrics show they are physically calm and relaxed right now (Stress: #{telemetry.stress_level}%)."
            | facts
          ]

        true ->
          facts
      end

    facts =
      cond do
        telemetry.sleep_hours != nil && telemetry.sleep_hours <= 5.0 ->
          [
            "#{name} is operating on only #{telemetry.sleep_hours} hours of sleep and is physically exhausted."
            | facts
          ]

        telemetry.sleep_hours != nil && telemetry.sleep_hours >= 8.0 ->
          [
            "#{name} got a full #{telemetry.sleep_hours} hours of deep restorative rest."
            | facts
          ]

        true ->
          facts
      end

    facts =
      if telemetry.ambient_noise_db != nil && telemetry.ambient_noise_db >= 80.0 do
        [
          "#{name}'s smart glasses sensors detect a loud, overstimulating environment (#{round(telemetry.ambient_noise_db)} dB)."
          | facts
        ]
      else
        facts
      end

    facts
  end

  defp broadcast_telemetry(character, telemetry, somatic, emotional) do
    payload = %{
      character_id: character.id,
      character_slug: character.slug,
      telemetry: telemetry,
      somatic: %{
        fatigue: somatic.fatigue,
        pain: somatic.pain
      },
      emotional: %{
        stress: emotional.stress
      }
    }

    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "telemetry:wearables",
      {:telemetry_received, payload}
    )

    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "character:#{character.id}:biometrics",
      {:telemetry_received, payload}
    )
  end

  defp clamp(val, min_v, max_v) do
    val
    |> max(min_v)
    |> min(max_v)
  end
end
