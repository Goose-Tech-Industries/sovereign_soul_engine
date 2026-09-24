defmodule SovereignSoulEngine.Souls.SoulVitalityTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.{Characters, Souls, Identity, Repo}
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Souls.{SoulProfile, EmotionalState, SomaticState}

  setup do
    {:ok, char} =
      Characters.create_character(%{
        name: "Aurelia Dawn",
        slug: "aurelia-dawn-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active",
        description: "An arcanist studying the high mountain constellations."
      })

    [character: char]
  end

  describe "ensure_soul_vitality/2 lazy provisioning" do
    test "provisions a complete SoulProfile if absent", %{character: char} do
      assert Souls.get_soul_profile_by_character(char.id) == nil

      profile = Souls.ensure_soul_vitality(char)

      assert %SoulProfile{} = profile
      assert profile.character_id == char.id
      assert profile.identity_summary == char.description
      assert profile.speech_style == "Direct, expressive"
      assert profile.social_stamina == 100
      assert profile.stamina_max == 100
      assert profile.stamina_regen_rate == 10
    end

    test "provisions baseline emotional state with valid emotional spectrum", %{character: char} do
      assert Souls.get_emotional_state_by_character(char.id) == nil

      Souls.ensure_soul_vitality(char)

      emotional = Souls.get_emotional_state_by_character(char.id)
      assert %EmotionalState{} = emotional
      assert emotional.anger == 0
      assert emotional.fear == 0
      assert emotional.stress == 15
      assert emotional.gratitude == 40
      assert emotional.confidence == 60
      assert emotional.sadness == 0
      assert emotional.curiosity == 70
      assert emotional.attachment == 50
    end

    test "provisions somatic state with baseline biological metrics", %{character: char} do
      assert Souls.get_somatic_state_by_character(char.id) == nil

      Souls.ensure_soul_vitality(char)

      somatic = Souls.get_somatic_state_by_character(char.id)
      assert %SomaticState{} = somatic
      assert somatic.fatigue >= 0
      assert somatic.hunger >= 0
      assert somatic.pain >= 0
    end

    test "provisions cryptographic DID with did:soul prefix and public key", %{character: char} do
      assert Identity.get_did_for_character(char.id) == nil

      Souls.ensure_soul_vitality(char)

      did_record = Identity.get_did_for_character(char.id)
      refute is_nil(did_record)
      assert String.starts_with?(did_record.did, "did:soul:")
      assert is_binary(did_record.public_key)
    end

    test "idempotent: calling ensure_soul_vitality repeatedly does not duplicate profile", %{
      character: char
    } do
      p1 = Souls.ensure_soul_vitality(char)
      p2 = Souls.ensure_soul_vitality(char)

      assert p1.id == p2.id
      # Exactly 1 profile in the database
      profiles = Repo.all(from p in SoulProfile, where: p.character_id == ^char.id)
      assert length(profiles) == 1
    end

    test "idempotent: does not overwrite customized emotional state", %{character: char} do
      Souls.ensure_soul_vitality(char)

      emotional = Souls.get_emotional_state_by_character(char.id)

      {:ok, updated_emotional} =
        Souls.update_emotional_state(emotional, %{anger: 85, sadness: 20})

      assert updated_emotional.anger == 85

      # Re-run ensure_soul_vitality
      Souls.ensure_soul_vitality(char)

      refetched = Souls.get_emotional_state_by_character(char.id)
      assert refetched.anger == 85
      assert refetched.sadness == 20
    end

    test "idempotent: does not overwrite existing DID record", %{character: char} do
      Souls.ensure_soul_vitality(char)
      did_1 = Identity.get_did_for_character(char.id)

      Souls.ensure_soul_vitality(char)
      did_2 = Identity.get_did_for_character(char.id)

      assert did_1.id == did_2.id
      assert did_1.did == did_2.did
    end

    test "accepts custom attributes to merge into SoulProfile", %{character: char} do
      custom_attrs = %{
        speech_style: "Lyrical, mystical",
        core_values: ["Celestial Truth", "Highland Silence"],
        fears: ["Sudden eclipses"]
      }

      profile = Souls.ensure_soul_vitality(char, custom_attrs)

      assert profile.speech_style == "Lyrical, mystical"
      assert profile.core_values == ["Celestial Truth", "Highland Silence"]
      assert profile.fears == ["Sudden eclipses"]
    end

    test "works when passed character_id as binary string", %{character: char} do
      profile = Souls.ensure_soul_vitality(char.id)

      assert %SoulProfile{} = profile
      assert profile.character_id == char.id
    end

    test "returns nil when passed non-existent character_id" do
      fake_id = Ecto.UUID.generate()
      assert Souls.ensure_soul_vitality(fake_id) == nil
    end

    test "sets default Big 5 personality traits within normalized 0.0..1.0 range", %{
      character: char
    } do
      profile = Souls.ensure_soul_vitality(char)
      traits = profile.personality_traits

      assert is_map(traits)
      assert traits["openness"] >= 0.0 and traits["openness"] <= 1.0
      assert traits["conscientiousness"] >= 0.0 and traits["conscientiousness"] <= 1.0
      assert traits["extraversion"] >= 0.0 and traits["extraversion"] <= 1.0
      assert traits["agreeableness"] >= 0.0 and traits["agreeableness"] <= 1.0
      assert traits["neuroticism"] >= 0.0 and traits["neuroticism"] <= 1.0
    end

    test "sets fallback identity summary when character description is empty or nil" do
      {:ok, no_desc_char} =
        Characters.create_character(%{
          name: "Silent Wanderer",
          slug: "silent-wanderer-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active"
        })

      profile = Souls.ensure_soul_vitality(no_desc_char)
      assert profile.identity_summary =~ "living sovereign soul"
    end

    test "sets default core values protecting autonomy and sovereign craft", %{character: char} do
      profile = Souls.ensure_soul_vitality(char)
      assert is_list(profile.core_values)
      assert "Autonomy" in profile.core_values
      assert "Honor the craft" in profile.core_values
    end

    test "sets default fears protecting against loss of autonomy", %{character: char} do
      profile = Souls.ensure_soul_vitality(char)
      assert is_list(profile.fears)
      assert "Loss of autonomy" in profile.fears
    end

    test "sets default desires for community purpose", %{character: char} do
      profile = Souls.ensure_soul_vitality(char)
      assert is_list(profile.desires)
      assert Enum.any?(profile.desires, &String.contains?(&1, "Feannag's Rest"))
    end

    test "preserves profile updates across future ensure_soul_vitality calls", %{character: char} do
      profile = Souls.ensure_soul_vitality(char)

      {:ok, updated} =
        Souls.update_soul_profile(profile, %{speech_style: "Gruff northern dialect"})

      assert updated.speech_style == "Gruff northern dialect"

      refetched = Souls.ensure_soul_vitality(char)
      assert refetched.speech_style == "Gruff northern dialect"
    end

    test "initializes somatic state fatigue at baseline 20", %{character: char} do
      Souls.ensure_soul_vitality(char)
      somatic = Souls.get_somatic_state_by_character(char.id)
      assert somatic.fatigue == 20
    end

    test "initializes baseline attachment and trust at warm levels", %{character: char} do
      Souls.ensure_soul_vitality(char)
      emotional = Souls.get_emotional_state_by_character(char.id)
      assert emotional.attachment == 50
      assert emotional.gratitude == 40
      assert emotional.sadness == 0
    end
  end

  describe "Characters.create_living_soul/2 atomic vitality creation" do
    test "creates character and provisions all vitality subsystems in one call" do
      {:ok, char} =
        Characters.create_living_soul(%{
          name: "Bram Stoneheart",
          slug: "bram-stoneheart-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active",
          description: "Stalwart guardian of the iron forge."
        })

      assert %Character{} = char
      assert char.name == "Bram Stoneheart"

      # Verify all 4 subsystems are provisioned
      profile = Souls.get_soul_profile_by_character(char.id)
      assert %SoulProfile{} = profile
      assert profile.identity_summary == "Stalwart guardian of the iron forge."

      emotional = Souls.get_emotional_state_by_character(char.id)
      assert %EmotionalState{} = emotional
      assert emotional.confidence == 60

      somatic = Souls.get_somatic_state_by_character(char.id)
      assert %SomaticState{} = somatic

      did = Identity.get_did_for_character(char.id)
      assert did != nil
      assert String.starts_with?(did.did, "did:soul:")
    end

    test "accepts custom profile attributes during create_living_soul" do
      {:ok, char} =
        Characters.create_living_soul(
          %{
            name: "Lyra Moonweaver",
            slug: "lyra-moonweaver-#{Ecto.UUID.generate()}",
            kind: "npc",
            status: "active",
            description: "Weaver of highland silk and secrets."
          },
          %{
            speech_style: "Hushed, melodic whisper",
            core_values: ["Thread of Fate", "Sanctuary"],
            social_stamina: 80
          }
        )

      profile = Souls.get_soul_profile_by_character(char.id)
      assert profile.speech_style == "Hushed, melodic whisper"
      assert profile.core_values == ["Thread of Fate", "Sanctuary"]
      assert profile.social_stamina == 80
    end

    test "returns {:error, changeset} when character attributes fail validation" do
      result = Characters.create_living_soul(%{name: ""})
      assert {:error, %Ecto.Changeset{}} = result
    end

    test "supports creating player-kind living souls" do
      {:ok, player} =
        Characters.create_living_soul(%{
          name: "Adventurer Zero",
          slug: "player-zero-#{Ecto.UUID.generate()}",
          kind: "player",
          status: "active"
        })

      assert player.kind == "player"
      profile = Souls.get_soul_profile_by_character(player.id)
      assert profile != nil
      did = Identity.get_did_for_character(player.id)
      assert did != nil
    end

    test "creates unique DIDs for different characters" do
      {:ok, char1} =
        Characters.create_living_soul(%{
          name: "Soul One",
          slug: "soul-one-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active"
        })

      {:ok, char2} =
        Characters.create_living_soul(%{
          name: "Soul Two",
          slug: "soul-two-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active"
        })

      did1 = Identity.get_did_for_character(char1.id)
      did2 = Identity.get_did_for_character(char2.id)

      refute did1.did == did2.did
      refute did1.public_key == did2.public_key
    end

    test "created soul can immediately participate in social feeds without error" do
      {:ok, char} =
        Characters.create_living_soul(%{
          name: "Socialite Soul",
          slug: "socialite-soul-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active",
          description: "Highland bard with a story for every traveler."
        })

      assert {:ok, post} = SovereignSoulEngine.Social.SocialFeed.generate_post(char.id)
      assert post.character_id == char.id
      assert is_binary(post.content) and post.content != ""
    end

    test "created soul has valid cryptographic DID that resolves to local character" do
      {:ok, char} =
        Characters.create_living_soul(%{
          name: "Document Soul",
          slug: "doc-soul-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active"
        })

      did = Identity.get_did_for_character(char.id)
      assert did != nil
      assert String.starts_with?(did.did, "did:soul:z")

      assert {:ok, pubkey} =
               SovereignSoulEngine.Identity.SoulIdentity.public_key_from_did(did.did)

      assert byte_size(pubkey) == 32
      assert resolved_char = Identity.ensure_local_character(did.did)
      assert resolved_char.id == char.id
    end
  end
end
