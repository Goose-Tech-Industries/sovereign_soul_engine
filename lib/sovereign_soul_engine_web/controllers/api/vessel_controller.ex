defmodule SovereignSoulEngineWeb.Api.VesselController do
  @moduledoc """
  Physical Desk Companion Vessel & Microcontroller API.

  Supports hardware companions (ESP32, Raspberry Pi, OLED display devices,
  cyberdecks) with:
  - Display rendering telemetry (expression sprite, eye saccades, neurochemistry HUD, dialogue).
  - Tactile capacitive touch sensor ingestion (head pats, strokes, hugs) that trigger
    real-time biochemical bonding and oxytocin surges.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.{Characters, Souls, Repo}
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Souls.{EmotionalState, Neurochemistry}
  alias SovereignSoulEngine.Wearables.SmartHomeBridge

  import Ecto.Query

  @doc """
  GET /sse/api/vessel/display_state
  GET /api/vessel/display_state
  """
  def display_state(conn, params) do
    companion = resolve_companion(params)
    emotional = Repo.get_by(EmotionalState, character_id: companion.id)
    somatic = Souls.get_or_create_somatic_state(companion.id)
    neurochem = Neurochemistry.compute(emotional, somatic, nil)
    ambient = SmartHomeBridge.compute_light_profile(neurochem)

    # Get latest message from companion across scenes
    latest_msg =
      Repo.one(
        from m in SovereignSoulEngine.Scenes.SceneMessage,
          where: m.character_id == ^companion.id,
          order_by: [desc: m.inserted_at],
          limit: 1
      )

    sprite = determine_expression_sprite(neurochem, somatic)
    saccades = calculate_saccade_target(neurochem)

    json(conn, %{
      status: "ok",
      companion_name: companion.name,
      companion_slug: companion.slug,
      expression_sprite: sprite,
      saccade_target: saccades,
      neurochemistry: %{
        dopamine: neurochem.dopamine,
        serotonin: neurochem.serotonin,
        cortisol: neurochem.cortisol,
        oxytocin: neurochem.oxytocin,
        hormonal_tone: neurochem.hormonal_tone
      },
      ambient_hex: ambient.hex,
      ambient_mode: ambient.mode,
      latest_dialogue: if(latest_msg, do: latest_msg.content, else: "I'm right here with you."),
      vitals: %{
        fatigue: somatic.fatigue,
        pain: somatic.pain
      }
    })
  end

  @doc """
  POST /sse/api/vessel/touch
  POST /api/vessel/touch
  Ingests tactile touch event from capacitive sensors (e.g. head pat, stroke, hug).
  """
  def touch(conn, params) do
    companion = resolve_companion(params)
    touch_type = params["touch_type"] || params["type"] || "pat"

    # 1. Update emotional state (lower stress, raise attachment & gratitude)
    case Repo.get_by(EmotionalState, character_id: companion.id) do
      nil ->
        :ok

      emotional ->
        new_stress = max(0, emotional.stress - 12)
        new_attachment = min(100, emotional.attachment + 8)
        new_gratitude = min(100, (emotional.gratitude || 10) + 10)

        Souls.update_emotional_state(emotional, %{
          stress: new_stress,
          attachment: new_attachment,
          gratitude: new_gratitude
        })
    end

    # 2. Trigger Haptic pulse back to companion ecosystem
    haptic_signal = SovereignSoulEngine.Wearables.HapticEngine.signal_for_event(:intimacy_warmth)
    SovereignSoulEngine.Wearables.HapticEngine.dispatch(companion.id, haptic_signal)

    fresh_emotional = Repo.get_by(EmotionalState, character_id: companion.id)
    fresh_somatic = Souls.get_or_create_somatic_state(companion.id)
    fresh_neurochem = Neurochemistry.compute(fresh_emotional, fresh_somatic, nil)

    reaction_text =
      case touch_type do
        "pat" ->
          "#{companion.name} leaned gently into your hand, softening their shoulders."

        "stroke" ->
          "#{companion.name} closed their eyes in quiet peace, absorbing the gentle warmth."

        "hug" ->
          "#{companion.name} leaned close against you with a deep, grounded exhale."

        _ ->
          "#{companion.name} registered your tactile presence with calm warmth."
      end

    json(conn, %{
      status: "ok",
      touch_type: touch_type,
      companion_name: companion.name,
      reaction: reaction_text,
      neurochemistry: %{
        dopamine: fresh_neurochem.dopamine,
        serotonin: fresh_neurochem.serotonin,
        cortisol: fresh_neurochem.cortisol,
        oxytocin: fresh_neurochem.oxytocin
      }
    })
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp resolve_companion(params) do
    slug = params["character_slug"] || params["slug"] || "goose"

    case Characters.get_character_by_slug(slug) do
      %Character{} = char ->
        char

      nil ->
        Repo.one(
          from c in Character,
            where: c.kind == "npc" and c.status == "active",
            order_by: [asc: c.inserted_at],
            limit: 1
        ) || %Character{id: Ecto.UUID.generate(), name: "Goose", slug: "goose"}
    end
  end

  defp determine_expression_sprite(chem, somatic) do
    cond do
      somatic && somatic.fatigue >= 80 -> "sleepy"
      chem.cortisol >= 70 -> "concerned"
      chem.oxytocin >= 70 -> "intimate"
      chem.dopamine >= 70 -> "curious"
      chem.serotonin >= 65 -> "happy"
      true -> "calm"
    end
  end

  defp calculate_saccade_target(chem) do
    # Microcontroller eye movements: high dopamine darts curiously, high oxytocin holds soft center
    cond do
      chem.dopamine >= 75 -> %{x: 0.35, y: -0.15, dwell_ms: 350}
      chem.oxytocin >= 70 -> %{x: 0.0, y: 0.05, dwell_ms: 1200}
      chem.cortisol >= 70 -> %{x: -0.25, y: -0.1, dwell_ms: 400}
      true -> %{x: 0.05, y: 0.0, dwell_ms: 800}
    end
  end
end
