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

    test "safe word detection and persona freeze triggers", %{player: player} do
      assert Privacy.safe_word_triggered?("This is getting too intense, code red!", player.id) == true
      assert Privacy.safe_word_triggered?("Hey pause persona right now please", player.id) == true
      assert Privacy.safe_word_triggered?("Can we red light this scene?", player.id) == true
      assert Privacy.safe_word_triggered?("Just talking about normal things", player.id) == false

      # Trigger safe word
      assert Privacy.safe_word_active?(player.id) == false
      {:ok, _} = Privacy.trigger_safe_word(player.id)
      assert Privacy.safe_word_active?(player.id) == true

      # Clear safe word
      {:ok, _} = Privacy.clear_safe_word(player.id)
      assert Privacy.safe_word_active?(player.id) == false
    end

    test "anti-parasocial dependency detection", %{player: player} do
      assert Privacy.parasocial_dependency_detected?("You are my only friend in the world", player.id) == true
      assert Privacy.parasocial_dependency_detected?("I haven't eaten all day talking to you", player.id) == true
      assert Privacy.parasocial_dependency_detected?("I'm never leaving this room", player.id) == true
      assert Privacy.parasocial_dependency_detected?("Good morning, how is the weather today?", player.id) == false
    end

    test "relationship archetype intimacy ceiling clamping", %{player: player} do
      assert Privacy.archetype_intimacy_ceiling("platonic_mentor") == 40
      assert Privacy.archetype_intimacy_ceiling("witty_companion") == 55
      assert Privacy.archetype_intimacy_ceiling("romantic_partner") == 100

      {:ok, _} = Privacy.update_settings(player.id, %{"relationship_archetype" => "platonic_mentor"})
      assert Privacy.clamp_intimacy(85, player.id) == 40
      assert Privacy.clamp_intimacy(30, player.id) == 30

      {:ok, _} = Privacy.update_settings(player.id, %{"relationship_archetype" => "romantic_partner"})
      assert Privacy.clamp_intimacy(85, player.id) == 85
    end

    test "generator catches safe word in history and halts dramatic roleplay", %{player: player} do
      {:ok, npc} =
        Characters.create_character(%{
          name: "Vael Companion",
          slug: "vael-safe-test-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active"
        })

      scene = SovereignSoulEngine.Scenes.find_or_create_direct_scene(player, npc)

      {:ok, _user_msg} =
        SovereignSoulEngine.Scenes.create_message(%{
          scene_id: scene.id,
          character_id: player.id,
          content: "Wait a second, pause persona! This is too intense.",
          message_type: "dialogue"
        })

      {:ok, response} = SovereignSoulEngine.Souls.Generator.generate(npc.id, scene.id, player.id)

      assert response.content =~ "Safe Word Activated: Persona Paused"
      assert response.metadata["safe_word_triggered"] == true
      assert Privacy.safe_word_active?(npc.id) == true
    end
  end
end
