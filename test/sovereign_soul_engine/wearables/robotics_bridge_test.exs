defmodule SovereignSoulEngine.Wearables.RoboticsBridgeTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Wearables.RoboticsBridge
  alias SovereignSoulEngine.Characters

  setup do
    {:ok, char} =
      Characters.create_character(%{
        name: "Android Vael",
        slug: "android-vael-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active"
      })

    %{character: char}
  end

  describe "compute_actuation/1" do
    test "returns kinematic goals, posture, breathing and ROS2 packet", %{character: char} do
      packet = RoboticsBridge.compute_actuation(char.slug)

      assert packet.status == "ok"
      assert packet.character_slug == char.slug
      assert is_map(packet.neurochemistry)
      assert is_map(packet.kinematics)

      # Verify head kinematics
      assert is_float(packet.kinematics.head.pitch_deg)
      assert is_float(packet.kinematics.head.yaw_deg)
      assert is_float(packet.kinematics.head.roll_deg)

      # Verify torso kinematics
      assert packet.kinematics.torso.posture in [
               "open_relaxed",
               "tense_guarded",
               "slumped_exhausted",
               "upright_alert"
             ]

      assert packet.kinematics.torso.stiffness_pct >= 20
      assert packet.kinematics.torso.respiration_rate_bpm >= 12
      assert packet.kinematics.torso.chest_expansion_mm > 0.0

      # Verify locomotion & ROS2 packet
      assert packet.kinematics.locomotion.gait_speed_mps >= 0.0
      assert is_map(packet.ros2_packet.cmd_vel)
      assert is_map(packet.ros2_packet.joint_trajectory_targets_rad)
      assert packet.ros2_packet.ros2_topics.velocity == "/cmd_vel"
    end

    test "returns error for non-existent character" do
      packet = RoboticsBridge.compute_actuation("non_existent_robot")
      assert packet.status == "error"
    end
  end

  describe "ingest_telemetry/2" do
    test "low battery increases companion fatigue", %{character: char} do
      {:ok, result} =
        RoboticsBridge.ingest_telemetry(char.slug, %{
          "battery_pct" => 12.5,
          "motor_temp_c" => 40.0
        })

      assert result.status == "ok"
      assert result.fatigue >= 15
    end

    test "high motor temperature increases pain and strain", %{character: char} do
      {:ok, result} =
        RoboticsBridge.ingest_telemetry(char.slug, %{
          "motor_temp_c" => 75.0
        })

      assert result.status == "ok"
      assert result.pain >= 20
    end
  end
end
