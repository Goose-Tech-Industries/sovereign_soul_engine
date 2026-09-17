defmodule SovereignSoulEngineWeb.Api.CoreApiControllersTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Privacy

  setup %{conn: conn} do
    {:ok, char} =
      Characters.create_character(%{
        name: "Aria Shadowsong",
        slug: "aria-#{System.unique_integer([:positive])}",
        kind: "npc",
        description: "A mysterious scholar and companion.",
        status: "active"
      })

    {:ok, _soul} =
      Souls.create_soul_profile(%{
        character_id: char.id,
        personality_traits: %{"curiosity" => 80, "loyalty" => 70},
        baseline_emotions: %{"confidence" => 65, "stress" => 10},
        attachment_style: "secure"
      })

    {:ok, _emotional} =
      Souls.create_emotional_state(%{
        character_id: char.id,
        confidence: 65,
        stress: 10,
        gratitude: 20
      })

    {:ok, _somatic} =
      Souls.create_somatic_state(%{
        character_id: char.id,
        energy: 85,
        fatigue: 15
      })

    {:ok, player} =
      Characters.create_character(%{
        name: "Goose Player",
        slug: "goose-player-#{System.unique_integer([:positive])}",
        kind: "player",
        status: "active"
      })

    conn = put_req_header(conn, "authorization", "Bearer twisted_dev_key")
    %{conn: conn, npc: char, player: player}
  end

  describe "ApiAuth plug protection" do
    test "rejects requests without authorization header with 401", %{npc: char} do
      unauth_conn = build_conn() |> get(~p"/sse/api/characters/#{char.id}")
      assert json_response(unauth_conn, 401)["error"] == "missing api key"
    end

    test "rejects requests with invalid api key with 401", %{npc: char} do
      bad_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer completely_fake_and_invalid_key")
        |> get(~p"/sse/api/characters/#{char.id}")

      assert json_response(bad_conn, 401)["error"] == "invalid or inactive api key"
    end
  end

  describe "CharacterController" do
    test "GET /sse/api/characters lists active NPCs", %{conn: conn, npc: npc} do
      conn = get(conn, ~p"/sse/api/characters")
      assert json_response(conn, 200)["characters"] != nil
      chars = json_response(conn, 200)["characters"]
      assert Enum.any?(chars, &(&1["slug"] == npc.slug))
    end

    test "POST /sse/api/characters provisions a new character with soul state", %{conn: conn} do
      unique_slug = "sylvan-#{System.unique_integer([:positive])}"

      conn =
        post(conn, ~p"/sse/api/characters", %{
          "name" => "Sylvan Scout",
          "slug" => unique_slug,
          "description" => "A ranger from the outer rim.",
          "traits" => %{"vigilance" => 90},
          "baseline_emotions" => %{"confidence" => 70, "fear" => 5}
        })

      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)
      assert body["slug"] == unique_slug
      assert is_binary(body["character_id"])
      assert is_binary(body["soul_profile_id"])
    end

    test "GET /sse/api/characters/:id returns full soul profile or 404", %{conn: conn, npc: npc} do
      conn_show = get(conn, ~p"/sse/api/characters/#{npc.id}")
      assert json_response(conn_show, 200)["id"] == npc.id
      assert json_response(conn_show, 200)["soul_profile"] != nil

      missing_conn = get(conn, ~p"/sse/api/characters/non_existent_slug_xyz")
      assert json_response(missing_conn, 404)["error"] == "character not found"
    end

    test "GET /sse/api/characters/:id/intent returns deterministic spatial intent", %{conn: conn, npc: npc} do
      conn_intent = get(conn, ~p"/sse/api/characters/#{npc.id}/intent")
      body = json_response(conn_intent, 200)
      assert body["character_id"] == npc.id
      assert is_binary(body["intent"])
      assert is_binary(body["reason"])

      missing_conn = get(conn, ~p"/sse/api/characters/#{Ecto.UUID.generate()}/intent")
      assert json_response(missing_conn, 404)["error"] == "character not found"
    end
  end

  describe "NpcChatController" do
    test "POST /sse/api/npc_chat handles player dialogue and returns NPC reply", %{conn: conn, npc: npc} do
      conn =
        post(conn, ~p"/sse/api/npc_chat", %{
          "external_source" => "twisted",
          "external_player_id" => "ext_p_100",
          "external_player_name" => "Commander Shepard",
          "npc_id" => npc.id,
          "message" => "What do you see in the stars tonight?"
        })

      assert json_response(conn, 200)["reply"] != nil
      body = json_response(conn, 200)
      assert body["npc_name"] == npc.name
      assert is_binary(body["reply"])
    end

    test "GET /sse/api/npc_chat/relationship returns known: false for new encounters", %{conn: conn, npc: npc} do
      conn =
        get(
          conn,
          ~p"/sse/api/npc_chat/relationship?external_source=twisted&external_player_id=ext_p_new&npc_id=#{npc.id}"
        )

      assert json_response(conn, 200)["known"] == false
    end
  end

  describe "AmbientChatController" do
    test "POST /sse/api/ambient_chat/message stores shared scene message", %{conn: conn} do
      conn =
        post(conn, ~p"/sse/api/ambient_chat/message", %{
          "external_source" => "twisted",
          "external_player_id" => "ext_p_200",
          "external_player_name" => "Scout",
          "group_key" => "town_square_alpha",
          "message" => "The bells are tolling in the tower."
        })

      assert json_response(conn, 200)["scene_id"] != nil
      assert json_response(conn, 200)["player_id"] != nil
    end

    test "POST /sse/api/ambient_chat/message rejects empty message with 422", %{conn: conn} do
      conn =
        post(conn, ~p"/sse/api/ambient_chat/message", %{
          "external_source" => "twisted",
          "external_player_id" => "ext_p_200",
          "external_player_name" => "Scout",
          "group_key" => "town_square_alpha",
          "message" => "   "
        })

      assert json_response(conn, 422)["error"] == "message is empty"
    end
  end

  describe "NpcActionsController" do
    test "GET /sse/api/npc_actions/pending requires types and returns pending actions", %{conn: conn, npc: npc} do
      conn = get(conn, ~p"/sse/api/npc_actions/pending?npc_id=#{npc.id}&types=join_player,lock_door")
      assert json_response(conn, 200)["actions"] != nil

      missing_types = get(conn, ~p"/sse/api/npc_actions/pending?npc_id=#{npc.id}")
      assert json_response(missing_types, 422)["error"] == "types is required"
    end

    test "POST /sse/api/npc_actions/:id/consume returns 404 for non-existent action", %{conn: conn} do
      random_uuid = Ecto.UUID.generate()
      conn = post(conn, ~p"/sse/api/npc_actions/#{random_uuid}/consume")
      assert json_response(conn, 404)["error"] == "action not found"
    end
  end

  describe "SoulCapsuleController" do
    test "GET /sse/api/souls/:slug/export produces downloadable .soul capsule", %{conn: conn, npc: npc} do
      conn = get(conn, ~p"/sse/api/souls/#{npc.slug}/export")
      assert response(conn, 200) =~ "\"format\""
      assert get_resp_header(conn, "content-disposition") == ["attachment; filename=\"#{npc.slug}.soul\""]
    end

    test "GET /sse/api/souls/:slug/export returns 404 for unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/sse/api/souls/missing_slug_capsule_test/export")
      assert json_response(conn, 404)["error"] =~ "not found"
    end

    test "POST /sse/api/souls/import reconstitutes soul capsule and rejects tampered ones", %{conn: conn, npc: npc} do
      # 1. Export capsule
      export_conn = get(conn, ~p"/sse/api/souls/#{npc.slug}/export")
      capsule_json = response(export_conn, 200)
      parsed = Jason.decode!(capsule_json)

      # 2. Reconstitute authentic capsule with overwrite: true
      import_conn = post(conn, ~p"/sse/api/souls/import", %{"capsule" => parsed, "overwrite" => true})
      assert json_response(import_conn, 201)["status"] == "ok"
      assert json_response(import_conn, 201)["character_slug"] == npc.slug

      # 3. Tampered capsule is rejected with 422 checksum mismatch
      tampered = put_in(parsed, ["soul", "character", "name"], "Forged Name")
      tamper_conn = post(conn, ~p"/sse/api/souls/import", %{"capsule" => tampered})
      assert json_response(tamper_conn, 422)["error"] =~ "checksum_mismatch"
    end
  end

  describe "SmartHomeController" do
    test "GET /sse/api/smart_home/ambient returns lighting profile and neurochemistry", %{conn: conn, npc: npc} do
      conn = get(conn, ~p"/sse/api/smart_home/ambient?character_slug=#{npc.slug}")
      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)
      assert is_map(body["lighting"])
      assert is_map(body["neurochemistry"])
      assert is_binary(body["lighting"]["hex"])
    end

    test "POST /sse/api/smart_home/sync synchronizes environmental lighting", %{conn: conn, npc: npc} do
      conn = post(conn, ~p"/sse/api/smart_home/sync", %{"character_slug" => npc.slug})
      assert json_response(conn, 200)["status"] == "ok"
      assert json_response(conn, 200)["synced"] == true
    end
  end

  describe "VisionController" do
    test "POST /sse/api/vision/perceive executes multimodal perception", %{conn: conn, npc: npc, player: player} do
      # Enable camera vision in privacy settings for player
      Privacy.update_settings(player, %{"camera_vision" => true})

      conn =
        post(conn, ~p"/sse/api/vision/perceive", %{
          "character_slug" => npc.slug,
          "player_slug" => player.slug,
          "image_base64" => "data:image/jpeg;base64,dGVzdF9pbWFnZV9ieXRlcw=="
        })

      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)
      assert body["companion_slug"] == npc.slug
      assert body["perception"]["scene_description"] != nil
    end

    test "POST /sse/api/vision/perceive blocks when privacy setting disables vision with 403", %{
      conn: conn,
      npc: npc,
      player: player
    } do
      Privacy.update_settings(player, %{"camera_vision" => false})

      conn =
        post(conn, ~p"/sse/api/vision/perceive", %{
          "character_slug" => npc.slug,
          "player_slug" => player.slug,
          "image_base64" => "dGVzdF9pbWFnZV9ieXRlcw=="
        })

      assert json_response(conn, 403)["error"] =~ "disabled in user privacy settings"
    end
  end

  describe "SocialPostController" do
    test "GET /sse/api/social/feed returns companion social posts", %{conn: conn} do
      conn = get(conn, ~p"/sse/api/social/feed")
      assert json_response(conn, 200)["status"] == "ok"
      assert is_list(json_response(conn, 200)["posts"])
    end

    test "POST /sse/api/social/generate creates autonomous post for character", %{conn: conn, npc: npc} do
      conn = post(conn, ~p"/sse/api/social/generate", %{"slug" => npc.slug})
      assert json_response(conn, 201)["status"] == "ok"
      body = json_response(conn, 201)
      assert body["post"]["slug"] == npc.slug
      assert is_binary(body["post"]["content"])

      # Verify GET /sse/api/social/latest/:slug finds it
      latest_conn = get(conn, ~p"/sse/api/social/latest/#{npc.slug}")
      assert json_response(latest_conn, 200)["status"] == "ok"
      assert json_response(latest_conn, 200)["post"]["id"] == body["post"]["id"]
    end
  end
end
