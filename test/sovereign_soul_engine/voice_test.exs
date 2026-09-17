defmodule SovereignSoulEngine.VoiceTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Voice
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Scenes

  setup do
    {:ok, char} =
      Characters.create_character(%{
        name: "VoiceTester",
        slug: "voice_tester_#{System.unique_integer([:positive])}",
        kind: "npc",
        description: "A test character for voice synthesis",
        status: "active",
        metadata: %{"voice_id" => "custom_test_voice_123"}
      })

    {:ok, scene} =
      Scenes.create_scene(%{
        title: "Voice Lab",
        slug: "voice_lab_#{System.unique_integer([:positive])}",
        location: "Soundstage"
      })

    {:ok, msg} =
      Scenes.create_message(%{
        scene_id: scene.id,
        character_id: char.id,
        content: "Hello, this is a test of the speech pipeline.",
        message_type: "dialogue",
        metadata: %{}
      })

    %{character: char, scene: scene, message: msg}
  end

  test "configured?/0 returns boolean state" do
    assert is_boolean(Voice.configured?())
  end

  test "speak_message/2 handles empty content gracefully", %{character: char, message: msg} do
    empty_msg = %{msg | content: ""}
    assert {:error, :not_configured_or_empty} = Voice.speak_message(empty_msg, char)
  end

  test "speak_message_async/2 spawns supervised unlinked task without crashing caller", %{character: char, message: msg} do
    assert {:ok, _pid} = Voice.speak_message_async(msg, char)
  end
end
