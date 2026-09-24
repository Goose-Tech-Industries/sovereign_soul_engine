defmodule SovereignSoulEngine.World.LorebookTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.World.Lorebook

  setup do
    Lorebook.reset_custom_entries()
    :ok
  end

  describe "canonical entries" do
    test "loads the 13 canonical districts and folklore seeds" do
      entries = Lorebook.list_entries()

      # 13 districts + 5 folklore entries
      assert length(entries) >= 18

      slugs = Enum.map(entries, & &1.slug)
      assert "high_palace" in slugs
      assert "crows_keep" in slugs
      assert "high_sanctuary" in slugs
      assert "morrigan" in slugs
      assert "celtic_anam" in slugs
      assert "sovereign_guard" in slugs
    end

    test "get_entry/1 returns entry by slug" do
      entry = Lorebook.get_entry("crows_keep")
      assert entry != nil
      assert entry.title =~ "The Crow's Keep"
      assert "crows_keep" in entry.keys
      assert entry.content =~ "Seven centuries" or entry.content =~ "Craig Mor"
    end
  end

  describe "scan_and_activate/2" do
    test "returns empty list when dialogue contains no lore triggers (0 token overhead)" do
      text = "Good morning Goose. Have you eaten anything today?"
      assert Lorebook.scan_and_activate(text) == []
    end

    test "activates district lore when triggered in dialogue text" do
      text = "I heard strange rumors coming from the Crow's Keep last midnight."
      matches = Lorebook.scan_and_activate(text)

      assert length(matches) >= 1
      first = hd(matches)
      assert first.slug == "crows_keep"
      assert first.title =~ "Crow's Keep"
    end

    test "activates Celtic folklore lore when deity is mentioned" do
      text = "The omens are dark. We must make an offering to the Morrígan before marching."
      matches = Lorebook.scan_and_activate(text)

      assert Enum.any?(matches, &(&1.slug == "morrigan"))
    end

    test "supports dialogue message lists as input" do
      messages = [
        %{role: "user", content: "Where are we heading next?"},
        %{role: "assistant", content: "Through the shadowgate warrens into the black docks."}
      ]

      matches = Lorebook.scan_and_activate(messages)

      assert Enum.any?(
               matches,
               &(&1.slug == "shadowgate_warrens" or &1.slug == "shadowgate_syndicate")
             )
    end

    test "enforces secondary keys requirement" do
      {:ok, _entry} =
        Lorebook.register_entry(%{
          slug: "royal_vault_secrets",
          title: "The Royal Vaults",
          keys: ["palace", "throne"],
          secondary_keys: ["vault", "gold"],
          category: :location,
          priority: 85,
          content: "Enchanted subterranean iron vaults beneath the Obsidian Throne."
        })

      # Matches primary "palace" but lacks secondary key "vault" or "gold"
      text_no_secondary = "I walked through the palace courtyard."
      matches1 = Lorebook.scan_and_activate(text_no_secondary)
      refute Enum.any?(matches1, &(&1.slug == "royal_vault_secrets"))

      # Matches primary "palace" AND secondary "vault"
      text_with_secondary = "The thieves plan to infiltrate the palace vault."
      matches2 = Lorebook.scan_and_activate(text_with_secondary)
      assert Enum.any?(matches2, &(&1.slug == "royal_vault_secrets"))
    end

    test "boosts current_district relevance" do
      # Both "crows keep" and "high sanctuary" mentioned, but current district is high_sanctuary
      text = "We walked from the crows keep all the way to the cathedral."
      matches = Lorebook.scan_and_activate(text, current_district: "high_sanctuary")

      assert length(matches) >= 2
      assert hd(matches).slug == "high_sanctuary"
    end

    test "respects max_entries cap" do
      # Mentions multiple districts and factions
      text =
        "From High Palace to Crow's Keep, past High Sanctuary, Shadowgate Warrens, and the Morrígan Spire."

      matches = Lorebook.scan_and_activate(text, max_entries: 2)

      assert length(matches) == 2
    end
  end

  describe "prompt_directive/1" do
    test "returns empty string for empty list" do
      assert Lorebook.prompt_directive([]) == ""
    end

    test "formats matched entries into clean prompt block" do
      entry = %Lorebook{
        slug: "test_relic",
        title: "The Obsidian Glaive",
        content: "An ancient weapon forged from volcanic glass."
      }

      directive = Lorebook.prompt_directive([entry])
      assert directive =~ "LOREBOOK (WORLD CONTEXT):"
      assert directive =~ "- [The Obsidian Glaive]: An ancient weapon forged from volcanic glass."
    end
  end

  describe "custom entry registration & reset" do
    test "registers custom campaign entry and resets cleanly" do
      custom_entry = %{
        slug: "iron_claws_guild",
        title: "The Iron Claws Mercenaries",
        keys: ["iron claws", "mercenaries"],
        content: "A veteran company hired by the Merchant League.",
        priority: 70
      }

      {:ok, registered} = Lorebook.register_entry(custom_entry)
      assert registered.slug == "iron_claws_guild"

      found = Lorebook.get_entry("iron_claws_guild")
      assert found != nil
      assert found.title == "The Iron Claws Mercenaries"

      Lorebook.delete_custom_entry("iron_claws_guild")
      assert Lorebook.get_entry("iron_claws_guild") == nil
    end
  end
end
