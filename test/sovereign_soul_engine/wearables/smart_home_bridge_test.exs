defmodule SovereignSoulEngine.Wearables.SmartHomeBridgeTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Wearables.SmartHomeBridge

  setup do
    {:ok, npc} =
      Characters.create_character(%{
        name: "Lumina",
        slug: "lumina-smarthome",
        kind: "npc",
        status: "active"
      })

    {:ok, emotional} =
      Souls.create_emotional_state(%{
        character_id: npc.id,
        stress: 20,
        confidence: 70,
        attachment: 80
      })

    {:ok, somatic} =
      Souls.create_somatic_state(%{
        character_id: npc.id,
        fatigue: 15,
        pain: 0
      })

    {:ok, npc: npc, emotional: emotional, somatic: somatic}
  end

  describe "compute_light_profile/1" do
    test "returns calming lavender on high cortisol or acute stress" do
      state = %{cortisol: 85, oxytocin: 30, dopamine: 40, serotonin: 50}
      profile = SmartHomeBridge.compute_light_profile(state)

      assert profile.mode == :calming_lavender
      assert profile.color_temp_kelvin == 2700
      assert profile.rgb == [179, 157, 219]
      assert profile.rationale =~ "Cortisol spike"
    end

    test "returns candlelight amber on high oxytocin and intimacy" do
      state = %{cortisol: 20, oxytocin: 85, dopamine: 50, serotonin: 65}
      profile = SmartHomeBridge.compute_light_profile(state)

      assert profile.mode == :candlelight_amber
      assert profile.color_temp_kelvin == 2200
      assert profile.hex == "#FF8A3D"
      assert profile.rationale =~ "oxytocinergic bonding"
    end

    test "returns radiant dawn gold on high dopamine and curiosity" do
      state = %{cortisol: 25, oxytocin: 45, dopamine: 85, serotonin: 60}
      profile = SmartHomeBridge.compute_light_profile(state)

      assert profile.mode == :radiant_dawn
      assert profile.brightness_pct == 85
      assert profile.color_temp_kelvin == 3500
    end

    test "returns fireside comfort on serotonin depletion" do
      state = %{cortisol: 30, oxytocin: 40, dopamine: 35, serotonin: 25}
      profile = SmartHomeBridge.compute_light_profile(state)

      assert profile.mode == :fireside_comfort
      assert profile.color_temp_kelvin == 2000
    end
  end

  describe "SmartHome API endpoints" do
    test "GET /api/smart_home/ambient returns active lighting payload", %{conn: conn, npc: npc} do
      conn = get(conn, ~p"/api/smart_home/ambient", %{"character_slug" => npc.slug})
      assert json = json_response(conn, 200)

      assert json["status"] == "ok"
      assert json["lighting"]["mode"] in ["candlelight_amber", "balanced_daylight"]
      assert json["lighting"]["hex"] != nil
      assert json["lighting"]["rgb"] != nil
      assert json["neurochemistry"]["oxytocin"] != nil
    end

    test "POST /api/smart_home/sync broadcasts to PubSub and returns profile", %{
      conn: conn,
      npc: npc
    } do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "smart_home:lighting")

      conn = post(conn, ~p"/api/smart_home/sync", %{"character_slug" => npc.slug})
      assert json = json_response(conn, 200)

      assert json["status"] == "ok"
      assert json["synced"] == true

      assert_receive {:ambient_light_sync, profile}, 1000
      assert profile.name != nil
    end
  end
end
