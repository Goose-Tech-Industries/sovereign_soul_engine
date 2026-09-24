defmodule SovereignSoulEngine.Social.AutonomousSocialLoopTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Social.{NPCConversation, SocialFeed}

  setup do
    {:ok, npc_a} =
      Characters.create_character(%{
        name: "Corvus Raven",
        slug: "corvus_#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    {:ok, _soul_a} =
      Souls.create_soul_profile(%{
        character_id: npc_a.id,
        personality_traits: %{"stoicism" => 80},
        social_stamina: 80,
        stamina_max: 100,
        stamina_regen_rate: 10
      })

    {:ok, _emo_a} =
      Souls.create_emotional_state(%{
        character_id: npc_a.id,
        confidence: 70,
        stress: 15
      })

    {:ok, _som_a} =
      Souls.create_somatic_state(%{character_id: npc_a.id, energy: 90})

    {:ok, npc_b} =
      Characters.create_character(%{
        name: "Lyra Whisper",
        slug: "lyra_#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    {:ok, _soul_b} =
      Souls.create_soul_profile(%{
        character_id: npc_b.id,
        personality_traits: %{"curiosity" => 90},
        social_stamina: 60,
        stamina_max: 100,
        stamina_regen_rate: 10
      })

    {:ok, _emo_b} =
      Souls.create_emotional_state(%{
        character_id: npc_b.id,
        confidence: 60,
        stress: 20
      })

    {:ok, _som_b} =
      Souls.create_somatic_state(%{character_id: npc_b.id, energy: 80})

    %{npc_a: npc_a, npc_b: npc_b}
  end

  describe "NPCConversation stamina gating and turn loop" do
    test "can_converse?/2 gates initiation on both NPCs having >= 30 stamina", %{
      npc_a: a,
      npc_b: b
    } do
      # Both start with high stamina (80 and 60)
      assert NPCConversation.can_converse?(a.id, b.id) == true

      # Drain NPC B below threshold (e.g. 15)
      profile_b = Souls.get_soul_profile_by_character(b.id)
      Souls.update_soul_profile(profile_b, %{social_stamina: 15})

      assert NPCConversation.can_converse?(a.id, b.id) == false
      assert NPCConversation.can_converse?(b.id, a.id) == false
    end

    test "run/3 drains stamina, generates dialogue turns in autonomous scene, and broadcasts", %{
      npc_a: a,
      npc_b: b
    } do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "social:conversations")

      profile_a = Souls.get_soul_profile_by_character(a.id)
      profile_b = Souls.get_soul_profile_by_character(b.id)
      initial_stamina_a = profile_a.social_stamina
      initial_stamina_b = profile_b.social_stamina

      # Execute 2-turn autonomous conversation
      assert {:ok, scene_id} = NPCConversation.run(a.id, b.id, 2)

      # 1. Stamina drained by 20 on both participants
      fresh_a = Souls.get_soul_profile_by_character(a.id)
      fresh_b = Souls.get_soul_profile_by_character(b.id)
      assert fresh_a.social_stamina == initial_stamina_a - 20
      assert fresh_b.social_stamina == initial_stamina_b - 20

      # 2. Scene is flagged as autonomous
      scene = Scenes.get_scene!(scene_id)
      assert scene.is_autonomous == true

      # 3. Scene contains generated messages
      messages = Scenes.list_messages(scene_id)
      assert length(messages) >= 2

      # 4. Both NPCs have last_social_action_at set
      assert fresh_a.last_social_action_at != nil
      assert fresh_b.last_social_action_at != nil

      # 5. Scene participants linked
      scene_fresh = SovereignSoulEngine.Repo.preload(scene, :participants)
      p_ids = Enum.map(scene_fresh.participants, & &1.character_id)
      assert a.id in p_ids
      assert b.id in p_ids
    end

    test "run/3 returns {:error, :insufficient_stamina} when stamina is too low", %{
      npc_a: a,
      npc_b: b
    } do
      profile_a = Souls.get_soul_profile_by_character(a.id)
      Souls.update_soul_profile(profile_a, %{social_stamina: 10})

      assert {:error, :insufficient_stamina} = NPCConversation.run(a.id, b.id, 2)
    end
  end

  describe "SocialFeed autonomous post generation and persistence" do
    test "generate_post/2 creates, persists, and broadcasts in-character social post", %{npc_a: a} do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "social:feed")

      # Generate post for character
      assert {:ok, post} = SocialFeed.generate_post(a.id)

      assert post.character_id == a.id
      assert is_binary(post.content)
      assert String.length(post.content) > 0
      assert String.length(post.content) <= 280

      # Verify persistence and query APIs
      recent = SocialFeed.list_recent_posts(limit: 10)
      assert Enum.any?(recent, &(&1.id == post.id))

      latest = SocialFeed.get_latest_post_for_slug(a.slug)
      assert latest != nil
      assert latest.id == post.id

      # Verify PubSub emission
      assert_receive {:new_social_post, received_post}
      assert received_post.id == post.id
    end
  end
end
