defmodule SovereignSoulEngine.PrivacyTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Privacy
  alias SovereignSoulEngine.Characters

  setup do
    {:ok, player} =
      Characters.create_character(%{
        name: "Privacy Conscious User",
        slug: "privacy-user-#{Ecto.UUID.generate()}",
        kind: "player",
        status: "active"
      })

    %{player: player}
  end

  describe "default_settings/0 and get_settings/1" do
    test "returns default settings for new character", %{player: player} do
      settings = Privacy.get_settings(player.id)

      assert settings["proactive_checkins"] == true
      assert settings["somatic_stress_checkins"] == true
      assert settings["biometrics_tracking"] == true
      assert settings["haptic_feedback"] == true
      assert settings["camera_vision"] == true
      assert settings["ambient_lighting"] == true
      assert settings["alexa_voice"] == true
    end
  end

  describe "update_settings/2" do
    test "updates selective privacy toggles and persists them", %{player: player} do
      {:ok, updated} =
        Privacy.update_settings(player.id, %{
          "proactive_checkins" => false,
          "haptic_feedback" => false,
          "camera_vision" => false
        })

      assert updated["proactive_checkins"] == false
      assert updated["haptic_feedback"] == false
      assert updated["camera_vision"] == false
      # Other settings remain default
      assert updated["biometrics_tracking"] == true

      # Reloading verifies persistence
      reloaded = Privacy.get_settings(player.id)
      assert reloaded["proactive_checkins"] == false
      assert reloaded["haptic_feedback"] == false
    end
  end

  describe "boundary checks" do
    test "checkin_allowed? respects master kill switch", %{player: player} do
      assert Privacy.checkin_allowed?(player.id, :acute_stress) == true

      {:ok, _} = Privacy.update_settings(player.id, %{"proactive_checkins" => false})
      assert Privacy.checkin_allowed?(player.id, :acute_stress) == false
      assert Privacy.checkin_allowed?(player.id, :morning_waking) == false
    end

    test "checkin_allowed? respects specific somatic toggles", %{player: player} do
      {:ok, _} = Privacy.update_settings(player.id, %{"somatic_stress_checkins" => false})

      assert Privacy.checkin_allowed?(player.id, :acute_stress) == false
      assert Privacy.checkin_allowed?(player.id, :morning_waking) == true
    end

    test "hardware permission checkers respect toggles", %{player: player} do
      assert Privacy.biometrics_allowed?(player.id) == true
      assert Privacy.haptics_allowed?(player.id) == true
      assert Privacy.vision_allowed?(player.id) == true
      assert Privacy.ambient_lighting_allowed?(player.id) == true
      assert Privacy.alexa_allowed?(player.id) == true

      {:ok, _} =
        Privacy.update_settings(player.id, %{
          "biometrics_tracking" => false,
          "haptic_feedback" => false,
          "camera_vision" => false,
          "ambient_lighting" => false,
          "alexa_voice" => false
        })

      assert Privacy.biometrics_allowed?(player.id) == false
      assert Privacy.haptics_allowed?(player.id) == false
      assert Privacy.vision_allowed?(player.id) == false
      assert Privacy.ambient_lighting_allowed?(player.id) == false
      assert Privacy.alexa_allowed?(player.id) == false
    end
  end
end
