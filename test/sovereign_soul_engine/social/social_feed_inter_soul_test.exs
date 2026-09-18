defmodule SovereignSoulEngine.Social.SocialFeedInterSoulTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.{Characters, Repo, Social.SocialFeed, World.SeedSouls}
  alias SovereignSoulEngine.Social.SocialPost

  setup do
    # Ensure founding souls are seeded with rich descriptions
    SeedSouls.seed_all()

    fia = Characters.get_character_by_slug("fia")
    cipher = Characters.get_character_by_slug("cipher")
    dove = Characters.get_character_by_slug("dove")
    quill = Characters.get_character_by_slug("quill")
    kael = Characters.get_character_by_slug("kael")
    egon = Characters.get_character_by_slug("egon")
    corvus = Characters.get_character_by_slug("corvus")

    %{
      fia: fia,
      cipher: cipher,
      dove: dove,
      quill: quill,
      kael: kael,
      egon: egon,
      corvus: corvus
    }
  end

  test "seeded souls have rich, distinct descriptors and no generic placeholders", %{
    fia: fia,
    cipher: cipher,
    dove: dove,
    quill: quill,
    kael: kael,
    egon: egon
  } do
    # Verify none of the souls have the old generic placeholder
    for char <- [fia, cipher, dove, quill, kael, egon] do
      refute is_nil(char.description)
      refute char.description == "A founding soul of the Soul Society."
      assert String.length(char.description) > 20
    end

    assert fia.description =~ "empathetic" or fia.description =~ "jeweler"
    assert cipher.description =~ "cryptographer" or cipher.description =~ "telemetry" or cipher.description =~ "architect"
    assert dove.description =~ "shepherd" or dove.description =~ "Sanctuary"
    assert quill.description =~ "Chronicler" or quill.description =~ "archivist"
    assert kael.description =~ "Harbormaster" or kael.description =~ "docks" or kael.description =~ "Blackwater"
    assert egon.description =~ "sentinel" or egon.description =~ "soil" or egon.description =~ "King's Plaza"
  end

  test "generate_npc_comment_reply provides rich, persona-specific responses to user comments", %{
    fia: fia,
    cipher: cipher,
    corvus: corvus
  } do
    {:ok, post} =
      SocialFeed.create_post(%{
        character_id: fia.id,
        content: "Listening to the quiet heartbeat of the town.",
        mood: "reflective",
        platform: "soulbook"
      })

    # User comments on fear/shadow
    {:ok, _post, comment_1} =
      SocialFeed.generate_npc_comment_reply(post.id, fia.id, "I fear the darkness in the lower ward.")

    assert comment_1["author_slug"] == "fia"
    assert comment_1["content"] =~ "shadow" or comment_1["content"] =~ "heart"
    refute comment_1["content"] =~ "Understood. Feannag's Rest records every vow"

    # User comments on security to Cipher
    {:ok, _post, comment_2} =
      SocialFeed.generate_npc_comment_reply(post.id, cipher.id, "Is the perimeter network safe?")

    assert comment_2["author_slug"] == "cipher"
    assert comment_2["content"] =~ "cryptographic" or comment_2["content"] =~ "SHA-256" or comment_2["content"] =~ "Telemetry"

    # User comments to Corvus
    {:ok, _post, comment_3} =
      SocialFeed.generate_npc_comment_reply(post.id, corvus.id, "Keep watch tonight.")

    assert comment_3["author_slug"] == "corvus"
    assert comment_3["content"] =~ "garrison" or comment_3["content"] =~ "alert" or comment_3["content"] =~ "perimeter"
  end

  test "generate_inter_soul_reply creates authentic peer dialogue between two NPCs", %{
    fia: fia,
    cipher: cipher,
    dove: dove,
    kael: kael,
    egon: egon
  } do
    # Fia posts about resonance
    {:ok, fia_post} =
      SocialFeed.create_post(%{
        character_id: fia.id,
        content: "The resonance across the grand hall feels heavy today.",
        mood: "reflective",
        platform: "soulbook"
      })

    # Cipher replies to Fia
    {:ok, _post1, cipher_reply} = SocialFeed.generate_inter_soul_reply(fia_post.id, cipher.id)
    assert cipher_reply["author_slug"] == "cipher"
    assert cipher_reply["content"] =~ "Fia"
    assert cipher_reply["content"] =~ "telemetry" or cipher_reply["content"] =~ "harmonic" or cipher_reply["content"] =~ "pulse"

    # Dove replies to Fia
    {:ok, updated_post, dove_reply} = SocialFeed.generate_inter_soul_reply(fia_post.id, dove.id)
    assert dove_reply["author_slug"] == "dove"
    assert dove_reply["content"] =~ "Morrígan" or dove_reply["content"] =~ "sanctuary" or dove_reply["content"] =~ "fires"

    # Verify comments metadata contains both replies
    comments = updated_post.metadata["comments"]
    assert length(comments) == 2

    # Kael posts about river cargo
    {:ok, kael_post} =
      SocialFeed.create_post(%{
        character_id: kael.id,
        content: "Northern cargo barges docked along the Blackwater piers.",
        mood: "wary",
        platform: "soulbook"
      })

    # Egon replies to Kael
    {:ok, _post, egon_reply} = SocialFeed.generate_inter_soul_reply(kael_post.id, egon.id)
    assert egon_reply["author_slug"] == "egon"
    assert egon_reply["content"] =~ "Kael"
    assert egon_reply["content"] =~ "manifest" or egon_reply["content"] =~ "seals" or egon_reply["content"] =~ "King's Plaza"
  end

  test "trigger_inter_soul_response automatically dispatches peer comments and reactions", %{
    quill: quill
  } do
    {:ok, post} =
      SocialFeed.create_post(%{
        character_id: quill.id,
        content: "Archiving the covenant oaths of the First Founding.",
        mood: "introspective",
        platform: "soulbook"
      })

    {:ok, _updated_post, replies} = SocialFeed.trigger_inter_soul_response(post, 2)

    assert length(replies) == 2
    # Verify post in DB has threaded comments
    stored_post = Repo.get!(SocialPost, post.id)
    assert length(stored_post.metadata["comments"]) == 2

    # Verify at least one reaction was registered
    reactions = stored_post.metadata["reactions"] || %{}
    total_reactions = Enum.sum(Map.values(reactions))
    assert total_reactions >= 1
  end

  test "spark_inter_soul_activity starts an autonomous town conversation with peer engagement" do
    assert {:ok, post} = SocialFeed.spark_inter_soul_activity()

    stored_post = Repo.get!(SocialPost, post.id)
    assert stored_post != nil
    assert stored_post.character_id != nil
    assert stored_post.content != ""
    refute stored_post.content =~ "Observing the shifting winds. Every movement tells a story"

    comments = stored_post.metadata["comments"] || []
    assert length(comments) >= 1
  end

  test "tavish and rowan replying to ravina's debt post produce distinct in-character commentary with zero repetition" do
    ravina = Characters.get_character_by_slug("ravina")
    tavish = Characters.get_character_by_slug("tavish")
    rowan = Characters.get_character_by_slug("rowan")

    {:ok, post} =
      SocialFeed.create_post(%{
        character_id: ravina.id,
        content: "A ledger of debts is sharper than a silver stiletto if you know when to turn the page.",
        mood: "calculating",
        platform: "soulbook"
      })

    {:ok, post_after_tavish, tavish_reply} = SocialFeed.generate_inter_soul_reply(post.id, tavish.id)
    {:ok, post_after_rowan, rowan_reply} = SocialFeed.generate_inter_soul_reply(post_after_tavish.id, rowan.id)

    # Neither uses the old generic catchphrase
    refute tavish_reply["content"] =~ "stands with you on this"
    refute rowan_reply["content"] =~ "stands with you on this"

    # Both replies are in-character to their specific trade and the post topic
    assert tavish_reply["author_slug"] == "tavish"
    assert tavish_reply["content"] =~ "docks" or tavish_reply["content"] =~ "stiletto" or tavish_reply["content"] =~ "Discretion" or tavish_reply["content"] =~ "coin" or tavish_reply["content"] =~ "ledger"

    assert rowan_reply["author_slug"] == "rowan"
    assert rowan_reply["content"] =~ "oak" or rowan_reply["content"] =~ "joint" or rowan_reply["content"] =~ "beam" or rowan_reply["content"] =~ "blade"

    # The two replies are completely distinct
    refute tavish_reply["content"] == rowan_reply["content"]

    # Total comments on the post are 2 and both are stored
    comments = post_after_rowan.metadata["comments"]
    assert length(comments) == 2
    contents = Enum.map(comments, & &1["content"])
    assert length(Enum.uniq(contents)) == 2
  end
end
