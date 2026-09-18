defmodule SovereignSoulEngine.Social.GlobalFeedDeduplicationTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.{Characters, Social.SocialFeed, World.SeedSouls}
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Social.SocialPost

  setup do
    SeedSouls.seed_all()
    :ok
  end

  describe "global town-wide post deduplication" do
    test "ten consecutive posts across ten different characters are 100% unique" do
      sample_slugs = ~w(tavish rowan ulric vesper winona xanthe yorick thorne una wren)

      posts =
        Enum.map(sample_slugs, fn slug ->
          char = Characters.get_character_by_slug(slug)
          assert char != nil, "Expected character #{slug} to exist"
          {:ok, post} = SocialFeed.generate_post(char.id)
          post
        end)

      contents = Enum.map(posts, & &1.content)

      # All 10 contents must be non-empty
      for content <- contents do
        assert is_binary(content)
        assert String.length(content) > 10
      end

      # 10 completely unique posts
      assert length(Enum.uniq(contents)) == 10
    end

    test "cross-character anti-collision: character B never re-uses character A's thought" do
      tavish = Characters.get_character_by_slug("tavish")
      rowan = Characters.get_character_by_slug("rowan")

      {:ok, post_a} = SocialFeed.generate_post(tavish.id)
      {:ok, post_b} = SocialFeed.generate_post(rowan.id)

      refute post_a.content == post_b.content
    end

    test "saturated feed: character generates unique thought even when all primary candidates are in town history" do
      char = Characters.get_character_by_slug("vesper")
      candidates = SocialFeed.candidate_fallback_posts(char, "contemplative")

      # Seed DB with all candidate thoughts
      for c <- candidates do
        {:ok, _} =
          SocialFeed.create_post(%{
            character_id: char.id,
            content: c,
            mood: "contemplative",
            platform: "soulbook"
          })
      end

      # Next generated post must NOT be any of the raw candidates
      {:ok, new_post} = SocialFeed.generate_post(char.id)

      refute new_post.content in candidates
      assert is_binary(new_post.content) and String.length(new_post.content) > 15
    end

    test "fallback_post returns a variation when all base candidates are in recent_contents" do
      char = %Character{slug: "tavish", name: "Tavish"}
      base_candidates = SocialFeed.candidate_fallback_posts(char, "affable")

      picked = SocialFeed.fallback_post(char, "affable", base_candidates)

      refute picked in base_candidates
      assert is_binary(picked)
      assert String.length(picked) > 20
    end

    test "fallback_post appends time marker when both base and standard variations are exhausted" do
      char = %Character{slug: "una", name: "Una"}
      base_candidates = SocialFeed.candidate_fallback_posts(char, "earthy")
      all_variations = Enum.flat_map(base_candidates, &SocialFeed.candidate_temporal_variations/1)
      exhausted = base_candidates ++ all_variations

      picked = SocialFeed.fallback_post(char, "earthy", exhausted)

      # Must not match any in the exhausted list
      refute picked in exhausted
      assert is_binary(picked)
      assert String.length(picked) > 10
    end

    test "generate_all_posts creates posts for all active founding companions without errors" do
      results = SocialFeed.generate_all_posts()

      assert length(results) >= 40
      for res <- results do
        assert {:ok, %SocialPost{}} = res
      end
    end
  end

  describe "individual soul candidate generation and non-repetition" do
    @souls_to_test ~w(
      sera lys tamsin oswin mara hale isolde rook bella jasper
      nadia percival rowan sable thorne una wren ansel briar cedric
      galen hollis ivy kestrel lark merritt nissa orin rhea soren
      tavish ulric vesper winona xanthe yorick
    )

    for slug <- @souls_to_test do
      @slug slug
      test "soul #{slug} generates valid distinct fallback posts and avoids repetition" do
        slug = @slug
        char = %Character{slug: slug, name: String.capitalize(slug)}
        candidates = SocialFeed.candidate_fallback_posts(char, "contemplative")

        assert length(candidates) >= 4
        assert length(Enum.uniq(candidates)) == length(candidates)

        for c <- candidates do
          assert is_binary(c)
          assert String.length(c) >= 15
        end

        # Verify fallback_post with the first candidate in recent_contents never picks the first
        first = hd(candidates)
        picked = SocialFeed.fallback_post(char, "contemplative", [first])
        refute picked == first
      end
    end
  end
end
