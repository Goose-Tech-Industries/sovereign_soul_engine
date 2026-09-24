defmodule SovereignSoulEngine.Edge.SurvivalModeTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Edge.SurvivalMode
  alias SovereignSoulEngine.Characters

  setup do
    {:ok, char} =
      Characters.create_character(%{
        name: "Edge Test Companion",
        slug: "edge-test-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active"
      })

    %{character: char}
  end

  test "current_status/1 reports active mode and local capabilities" do
    status = SurvivalMode.current_status()
    assert is_map(status)
    assert Map.has_key?(status, :mode)
    assert Map.has_key?(status, :air_gapped)
  end

  test "toggle_force_offline/2 enforces offline mode", %{character: char} do
    {:ok, settings} = SurvivalMode.toggle_force_offline(char.id, true)
    assert settings["force_local_offline"] == true

    status = SurvivalMode.current_status(char.id)
    assert status.force_local_offline == true
    assert status.air_gapped == true

    # Toggle back to false
    {:ok, reverted} = SurvivalMode.toggle_force_offline(char.id, false)
    assert reverted["force_local_offline"] == false
  end

  test "generate_offline_fallback/5 generates in-character responses without cloud dependency", %{
    character: char
  } do
    neurochem = %{valence: 70.0, arousal: 45.0, cortisol: 12.0}
    circadian = %{state: :night_focus}

    fallback = SurvivalMode.generate_offline_fallback(char, nil, [], neurochem, circadian)

    assert is_binary(fallback["speech"])
    assert fallback["fallback"] == true
    assert fallback["mode"] == "edge_deterministic_fallback"
  end
end
