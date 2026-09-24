defmodule SovereignSoulEngine.Wearables.RoboticsBridge do
  @moduledoc """
  Physical Robotics Body & ROS2 Actuation Bridge.

  Translates the companion's real-time neurochemistry, emotional state,
  and somatic state into actionable kinematic packets for physical robot bodies
  (including the Unitree G1 humanoid, Unitree Go2 quadruped, LOVOT, or ROS2 motor controllers):

  - Head & Neck: Pitch (attentive tilt vs. dejected hang), Yaw (gaze tracking), Roll (empathy head tilt).
  - Torso & Stance: Postural rigidity, motor stiffness, simulated breathing heave and respiration BPM.
  - Locomotion: Gait speed (m/s), balance compliance mode, quadruped tail-wag frequency (Hz).
  - ROS2 Packet: Serialized `/cmd_vel` velocities and target joint trajectories in radians.
  - Telemetry Ingestion: Feeds physical robot battery levels, motor temperatures, and bump hits back into SomaticState.
  """

  alias SovereignSoulEngine.{Characters, Souls, Repo}
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Souls.{EmotionalState, Neurochemistry}
  alias SovereignSoulEngine.Wearables.SmartHomeBridge

  @doc """
  Computes a complete robotic actuation and kinematics packet for a character.
  """
  def compute_actuation(character_or_slug) do
    character = resolve_character(character_or_slug)

    if character do
      emotional = Repo.get_by(EmotionalState, character_id: character.id)
      somatic = Souls.get_or_create_somatic_state(character.id)
      neurochem = Neurochemistry.compute(emotional, somatic, nil)
      ambient = SmartHomeBridge.compute_light_profile(neurochem)

      kinematics = build_kinematics(neurochem, somatic, emotional)
      ros2_packet = build_ros2_packet(kinematics, neurochem)

      %{
        status: "ok",
        character_name: character.name,
        character_slug: character.slug,
        neurochemistry: %{
          cortisol: neurochem.cortisol,
          oxytocin: neurochem.oxytocin,
          dopamine: neurochem.dopamine,
          serotonin: neurochem.serotonin,
          hormonal_tone: neurochem.hormonal_tone
        },
        kinematics: kinematics,
        ambient_light: %{
          hex: ambient.hex,
          mode: ambient.mode
        },
        ros2_packet: ros2_packet
      }
    else
      %{status: "error", error: "Character not found"}
    end
  end

  @doc """
  Ingests physical robot hardware telemetry (battery %, motor temperature, collision/bump events)
  and reflects them in the companion's enduring SomaticState.
  """
  def ingest_telemetry(character_or_slug, params) when is_map(params) do
    character = resolve_character(character_or_slug)

    if character do
      somatic = Souls.get_or_create_somatic_state(character.id)

      battery = parse_float(params["battery_pct"] || params[:battery_pct], 100.0)
      motor_temp = parse_float(params["motor_temp_c"] || params[:motor_temp_c], 35.0)

      obstacle_dist =
        parse_float(params["obstacle_distance_m"] || params[:obstacle_distance_m], 2.0)

      touch_event = params["touch_sensor"] || params[:touch_sensor]

      # Low battery increases companion fatigue
      fatigue_delta = if battery < 20.0, do: 15, else: 0

      # High motor heat registers as somatic pain/physical strain
      pain_delta = if motor_temp > 60.0, do: 20, else: 0

      updated_fatigue = min(100, max(0, somatic.fatigue + fatigue_delta))
      updated_pain = min(100, max(0, somatic.pain + pain_delta))

      {:ok, updated_somatic} =
        Souls.update_somatic_state(somatic, %{
          fatigue: updated_fatigue,
          pain: updated_pain
        })

      # If an obstacle collision or near miss occurred (< 0.3m), heighten startle cortisol
      if obstacle_dist < 0.3 do
        case Repo.get_by(EmotionalState, character_id: character.id) do
          nil ->
            :ok

          emotional ->
            Souls.update_emotional_state(emotional, %{
              fear: min(100, (emotional.fear || 0) + 20),
              stress: min(100, (emotional.stress || 0) + 15)
            })
        end
      end

      # Handle physical touch on the robot chassis
      if touch_event in ["pat", "hug", "stroke"] do
        case Repo.get_by(EmotionalState, character_id: character.id) do
          nil ->
            :ok

          emotional ->
            Souls.update_emotional_state(emotional, %{
              attachment: min(100, (emotional.attachment || 0) + 12),
              stress: max(0, (emotional.stress || 0) - 10)
            })
        end
      end

      {:ok,
       %{
         status: "ok",
         character_slug: character.slug,
         fatigue: updated_somatic.fatigue,
         pain: updated_somatic.pain,
         battery_pct: battery
       }}
    else
      {:error, :character_not_found}
    end
  end

  # ── Kinematic Calculations ──────────────────────────────────────────────────

  defp build_kinematics(neurochem, somatic, emotional) do
    stress = (emotional && emotional.stress) || 0
    fear = (emotional && emotional.fear) || 0
    anger = (emotional && emotional.anger) || 0

    # Head Pitch: Positive = looking up attentively, Negative = head hung low
    pitch_deg =
      cond do
        neurochem.dopamine >= 70 -> 8.5
        somatic.fatigue >= 70 or neurochem.serotonin <= 30 -> -12.0
        fear >= 60 -> 5.0
        true -> 0.0
      end

    # Head Roll: Soft 7.5° tilt when oxytocin/intimacy is high (empathy cue)
    roll_deg =
      cond do
        neurochem.oxytocin >= 65 -> 7.5
        anger >= 60 -> -3.0
        true -> 0.0
      end

    # Head Yaw: Subtle autonomous saccade look-around
    yaw_deg = calculate_yaw(neurochem)

    # Posture and Joint Rigidity
    {posture, stiffness_pct} =
      cond do
        neurochem.cortisol >= 70 or fear >= 60 or anger >= 60 ->
          {"tense_guarded", min(95, 50 + trunc(neurochem.cortisol * 0.45))}

        somatic.fatigue >= 70 ->
          {"slumped_exhausted", 25}

        neurochem.oxytocin >= 65 ->
          {"open_relaxed", 35}

        true ->
          {"upright_alert", 50}
      end

    # Breathing Heave and Respiration BPM
    respiration_bpm =
      cond do
        neurochem.cortisol >= 70 or fear >= 60 -> 26
        somatic.fatigue >= 70 -> 14
        true -> 18
      end

    chest_expansion_mm =
      cond do
        neurochem.cortisol >= 70 -> 8.0
        somatic.fatigue >= 70 -> 3.0
        true -> 5.5
      end

    # Locomotion & Gait Speed
    gait_speed_mps =
      cond do
        somatic.fatigue >= 80 -> 0.2
        neurochem.dopamine >= 70 -> 0.9
        neurochem.cortisol >= 75 -> 1.1
        true -> 0.5
      end

    # Quadruped tail wag frequency (Hz) for robots like Unitree Go2
    tail_wag_hz =
      cond do
        neurochem.dopamine >= 70 and neurochem.oxytocin >= 60 -> 2.8
        neurochem.oxytocin >= 50 -> 1.4
        neurochem.cortisol >= 70 -> 0.0
        true -> 0.5
      end

    %{
      head: %{
        pitch_deg: pitch_deg,
        yaw_deg: yaw_deg,
        roll_deg: roll_deg
      },
      torso: %{
        posture: posture,
        stiffness_pct: stiffness_pct,
        respiration_rate_bpm: respiration_bpm,
        chest_expansion_mm: chest_expansion_mm
      },
      locomotion: %{
        gait_speed_mps: gait_speed_mps,
        balance_mode: if(stiffness_pct > 70, do: "stiff", else: "compliant"),
        tail_wag_hz: tail_wag_hz
      },
      gaze: %{
        pupil_dilation: if(neurochem.oxytocin > 60, do: 0.85, else: 0.5),
        eye_expression: determine_eye_expression(neurochem, somatic, stress)
      }
    }
  end

  defp build_ros2_packet(kinematics, _neurochem) do
    # Deg to rad conversion
    deg2rad = :math.pi() / 180.0

    pitch_rad = kinematics.head.pitch_deg * deg2rad
    yaw_rad = kinematics.head.yaw_deg * deg2rad
    roll_rad = kinematics.head.roll_deg * deg2rad

    %{
      cmd_vel: %{
        linear: %{x: kinematics.locomotion.gait_speed_mps, y: 0.0, z: 0.0},
        angular: %{x: 0.0, y: 0.0, z: 0.0}
      },
      joint_trajectory_targets_rad: %{
        "head_pitch_joint" => Float.round(pitch_rad, 4),
        "head_yaw_joint" => Float.round(yaw_rad, 4),
        "head_roll_joint" => Float.round(roll_rad, 4),
        "torso_stiffness" => kinematics.torso.stiffness_pct / 100.0
      },
      ros2_topics: %{
        velocity: "/cmd_vel",
        joint_commands: "/joint_states/command",
        heartbeat_cadence: "/robot/bio_pulse"
      },
      behavioral_state: kinematics.torso.posture
    }
  end

  defp calculate_yaw(neurochem) do
    if neurochem.dopamine > 65 do
      Enum.random([-15.0, -8.0, 0.0, 8.0, 15.0])
    else
      0.0
    end
  end

  defp determine_eye_expression(neurochem, somatic, stress) do
    cond do
      somatic.fatigue >= 70 -> "sleepy"
      stress >= 70 -> "concerned"
      neurochem.oxytocin >= 65 -> "intimate"
      neurochem.dopamine >= 65 -> "curious"
      true -> "attentive"
    end
  end

  defp parse_float(val, _default) when is_float(val), do: val
  defp parse_float(val, _default) when is_integer(val), do: val * 1.0

  defp parse_float(val, default) when is_binary(val) do
    case Float.parse(val) do
      {f, _} ->
        f

      :error ->
        case Integer.parse(val) do
          {i, _} -> i * 1.0
          :error -> default
        end
    end
  end

  defp parse_float(_, default), do: default

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

  defp resolve_character(%Character{} = c), do: c
  defp resolve_character(_), do: nil
end
