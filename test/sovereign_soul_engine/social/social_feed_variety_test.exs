defmodule SovereignSoulEngine.Social.SocialFeedVarietyTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Social.SocialFeed

  describe "candidate_fallback_posts/2 named souls variety" do
    test "returns at least 4 unique thoughts for Fia" do
      char = %Character{slug: "fia", name: "Fia"}
      posts = SocialFeed.candidate_fallback_posts(char, "contemplative")

      assert length(posts) >= 4
      assert length(Enum.uniq(posts)) == length(posts)
      assert Enum.any?(posts, &String.contains?(&1, "Feannag's Rest"))
    end

    test "returns at least 4 unique thoughts for Cipher" do
      char = %Character{slug: "cipher", name: "Cipher"}
      posts = SocialFeed.candidate_fallback_posts(char, "focused")

      assert length(posts) >= 4
      assert length(Enum.uniq(posts)) == length(posts)
      assert Enum.any?(posts, &String.contains?(&1, "CUDA"))
    end

    test "returns at least 4 unique thoughts for Quill" do
      char = %Character{slug: "quill", name: "Quill"}
      posts = SocialFeed.candidate_fallback_posts(char, "scholarly")

      assert length(posts) >= 4
      assert Enum.any?(posts, &String.contains?(&1, "Iron Archives"))
    end

    test "returns at least 4 unique thoughts for Dove" do
      char = %Character{slug: "dove", name: "Dove"}
      posts = SocialFeed.candidate_fallback_posts(char, "serene")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "Morrígan") or String.contains?(&1, "sanctuary"))
             )
    end

    test "returns at least 4 unique thoughts for Kael" do
      char = %Character{slug: "kael", name: "Kael"}
      posts = SocialFeed.candidate_fallback_posts(char, "alert")

      assert length(posts) >= 4
      assert Enum.any?(posts, &String.contains?(&1, "Blackwater"))
    end

    test "returns at least 4 unique thoughts for Egon" do
      char = %Character{slug: "egon", name: "Egon"}
      posts = SocialFeed.candidate_fallback_posts(char, "steady")

      assert length(posts) >= 4
      assert Enum.any?(posts, &String.contains?(&1, "King's Plaza"))
    end

    test "returns at least 4 unique thoughts for Corvus" do
      char = %Character{slug: "corvus", name: "Corvus"}
      posts = SocialFeed.candidate_fallback_posts(char, "vigilant")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "Bastion") or String.contains?(&1, "sentinel"))
             )
    end

    test "returns at least 4 unique thoughts for Ravina" do
      char = %Character{slug: "ravina", name: "Ravina"}
      posts = SocialFeed.candidate_fallback_posts(char, "calculating")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "Mire") or String.contains?(&1, "Leverage")))
    end

    test "returns at least 4 unique thoughts for Maya" do
      char = %Character{slug: "maya", name: "Maya"}
      posts = SocialFeed.candidate_fallback_posts(char, "focused")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "Steel") or String.contains?(&1, "forge")))
    end

    test "returns at least 4 unique thoughts for Valeria" do
      char = %Character{slug: "valeria", name: "Valeria"}
      posts = SocialFeed.candidate_fallback_posts(char, "mystic")

      assert length(posts) >= 4
      assert Enum.any?(posts, &String.contains?(&1, "Spire"))
    end

    test "returns at least 4 unique thoughts for Cyra" do
      char = %Character{slug: "cyra", name: "Cyra"}
      posts = SocialFeed.candidate_fallback_posts(char, "analytical")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "telemetry") or String.contains?(&1, "sensor"))
             )
    end

    test "returns at least 4 unique thoughts for Bram" do
      char = %Character{slug: "bram", name: "Bram"}
      posts = SocialFeed.candidate_fallback_posts(char, "jovial")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "Boar's Tusk") or String.contains?(&1, "mead"))
             )
    end

    test "returns at least 4 unique thoughts for Elowen" do
      char = %Character{slug: "elowen", name: "Elowen"}
      posts = SocialFeed.candidate_fallback_posts(char, "gentle")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "remedy") or String.contains?(&1, "medicine"))
             )
    end

    test "returns at least 4 unique thoughts for Vael" do
      char = %Character{slug: "vael", name: "Vael"}
      posts = SocialFeed.candidate_fallback_posts(char, "grim")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "dead") or String.contains?(&1, "cairns")))
    end

    test "returns at least 4 unique thoughts for Lyra" do
      char = %Character{slug: "lyra", name: "Lyra"}
      posts = SocialFeed.candidate_fallback_posts(char, "creative")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "loom") or String.contains?(&1, "tapestry")))
    end

    test "returns at least 4 unique thoughts for Sera" do
      char = %Character{slug: "sera", name: "Sera"}
      posts = SocialFeed.candidate_fallback_posts(char, "lyrical")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "lute") or String.contains?(&1, "ballad") or
                   String.contains?(&1, "melody"))
             )
    end

    test "returns at least 4 unique thoughts for Lys" do
      char = %Character{slug: "lys", name: "Lys"}
      posts = SocialFeed.candidate_fallback_posts(char, "focused")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "alembic") or String.contains?(&1, "distill") or
                   String.contains?(&1, "precipitate"))
             )
    end

    test "returns at least 4 unique thoughts for Tamsin" do
      char = %Character{slug: "tamsin", name: "Tamsin"}
      posts = SocialFeed.candidate_fallback_posts(char, "measured")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "map") or String.contains?(&1, "sextant") or
                   String.contains?(&1, "parchment"))
             )
    end

    test "returns at least 4 unique thoughts for Oswin" do
      char = %Character{slug: "oswin", name: "Oswin"}
      posts = SocialFeed.candidate_fallback_posts(char, "steady")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "granite") or String.contains?(&1, "chisel") or
                   String.contains?(&1, "stone"))
             )
    end

    test "returns at least 4 unique thoughts for Mara" do
      char = %Character{slug: "mara", name: "Mara"}
      posts = SocialFeed.candidate_fallback_posts(char, "patient")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "drift net") or String.contains?(&1, "Blackwater") or
                   String.contains?(&1, "river"))
             )
    end

    test "returns at least 4 unique thoughts for Hale" do
      char = %Character{slug: "hale", name: "Hale"}
      posts = SocialFeed.candidate_fallback_posts(char, "alert")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "falcon") or String.contains?(&1, "tiercel") or
                   String.contains?(&1, "hawk"))
             )
    end

    test "returns at least 4 unique thoughts for Isolde" do
      char = %Character{slug: "isolde", name: "Isolde"}
      posts = SocialFeed.candidate_fallback_posts(char, "clinical")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "bandage") or String.contains?(&1, "surgical") or
                   String.contains?(&1, "pulse"))
             )
    end

    test "returns at least 4 unique thoughts for Rook" do
      char = %Character{slug: "rook", name: "Rook"}
      posts = SocialFeed.candidate_fallback_posts(char, "silent")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "wolf") or String.contains?(&1, "scout") or
                   String.contains?(&1, "trail"))
             )
    end

    test "returns at least 4 unique thoughts for Bella" do
      char = %Character{slug: "bella", name: "Bella"}
      posts = SocialFeed.candidate_fallback_posts(char, "cheerful")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "sourdough") or String.contains?(&1, "loaves") or
                   String.contains?(&1, "bread"))
             )
    end

    test "returns at least 4 unique thoughts for Jasper" do
      char = %Character{slug: "jasper", name: "Jasper"}
      posts = SocialFeed.candidate_fallback_posts(char, "boisterous")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "stout") or String.contains?(&1, "cask") or
                   String.contains?(&1, "keg"))
             )
    end

    test "returns at least 4 unique thoughts for Nadia" do
      char = %Character{slug: "nadia", name: "Nadia"}
      posts = SocialFeed.candidate_fallback_posts(char, "calm")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "candle") or String.contains?(&1, "tallow") or
                   String.contains?(&1, "beeswax"))
             )
    end

    test "returns at least 4 unique thoughts for Percival" do
      char = %Character{slug: "percival", name: "Percival"}
      posts = SocialFeed.candidate_fallback_posts(char, "resonant")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "herald") or String.contains?(&1, "decree") or
                   String.contains?(&1, "horn"))
             )
    end

    test "returns at least 4 unique thoughts for Rowan" do
      char = %Character{slug: "rowan", name: "Rowan"}
      posts = SocialFeed.candidate_fallback_posts(char, "steady")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "oak") or String.contains?(&1, "joinery") or
                   String.contains?(&1, "wood"))
             )
    end

    test "returns at least 4 unique thoughts for Sable" do
      char = %Character{slug: "sable", name: "Sable"}
      posts = SocialFeed.candidate_fallback_posts(char, "gruff")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "leather") or String.contains?(&1, "hide") or
                   String.contains?(&1, "tallow"))
             )
    end

    test "returns at least 4 unique thoughts for Thorne" do
      char = %Character{slug: "thorne", name: "Thorne"}
      posts = SocialFeed.candidate_fallback_posts(char, "hardened")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "mine") or String.contains?(&1, "ore") or
                   String.contains?(&1, "pick"))
             )
    end

    test "returns at least 4 unique thoughts for Una" do
      char = %Character{slug: "una", name: "Una"}
      posts = SocialFeed.candidate_fallback_posts(char, "earthy")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "clay") or String.contains?(&1, "wheel") or
                   String.contains?(&1, "kiln"))
             )
    end

    test "returns at least 4 unique thoughts for Wren" do
      char = %Character{slug: "wren", name: "Wren"}
      posts = SocialFeed.candidate_fallback_posts(char, "focused")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "glass") or String.contains?(&1, "blowpipe") or
                   String.contains?(&1, "alembic"))
             )
    end

    test "returns at least 4 unique thoughts for Ansel" do
      char = %Character{slug: "ansel", name: "Ansel"}
      posts = SocialFeed.candidate_fallback_posts(char, "even")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "mill") or String.contains?(&1, "spelt") or
                   String.contains?(&1, "flour"))
             )
    end

    test "returns at least 4 unique thoughts for Briar" do
      char = %Character{slug: "briar", name: "Briar"}
      posts = SocialFeed.candidate_fallback_posts(char, "expressive")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "dye") or String.contains?(&1, "indigo") or
                   String.contains?(&1, "madder"))
             )
    end

    test "returns at least 4 unique thoughts for Cedric" do
      char = %Character{slug: "cedric", name: "Cedric"}
      posts = SocialFeed.candidate_fallback_posts(char, "plain")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "wagon") or String.contains?(&1, "wheel") or
                   String.contains?(&1, "axle"))
             )
    end

    test "returns at least 4 unique thoughts for Galen" do
      char = %Character{slug: "galen", name: "Galen"}
      posts = SocialFeed.candidate_fallback_posts(char, "learned")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "remedy") or String.contains?(&1, "tincture") or
                   String.contains?(&1, "botanical"))
             )
    end

    test "returns at least 4 unique thoughts for Hollis" do
      char = %Character{slug: "hollis", name: "Hollis"}
      posts = SocialFeed.candidate_fallback_posts(char, "handy")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "boot") or String.contains?(&1, "sole") or
                   String.contains?(&1, "leather"))
             )
    end

    test "returns at least 4 unique thoughts for Ivy" do
      char = %Character{slug: "ivy", name: "Ivy"}
      posts = SocialFeed.candidate_fallback_posts(char, "methodical")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "archive") or String.contains?(&1, "codices") or
                   String.contains?(&1, "manuscript"))
             )
    end

    test "returns at least 4 unique thoughts for Kestrel" do
      char = %Character{slug: "kestrel", name: "Kestrel"}
      posts = SocialFeed.candidate_fallback_posts(char, "quiet")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "bow") or String.contains?(&1, "yew") or
                   String.contains?(&1, "feather"))
             )
    end

    test "returns at least 4 unique thoughts for Lark" do
      char = %Character{slug: "lark", name: "Lark"}
      posts = SocialFeed.candidate_fallback_posts(char, "quick")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "dispatch") or String.contains?(&1, "messenger") or
                   String.contains?(&1, "scroll"))
             )
    end

    test "returns at least 4 unique thoughts for Merritt" do
      char = %Character{slug: "merritt", name: "Merritt"}
      posts = SocialFeed.candidate_fallback_posts(char, "steady")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "horse") or String.contains?(&1, "stable") or
                   String.contains?(&1, "stallion"))
             )
    end

    test "returns at least 4 unique thoughts for Nissa" do
      char = %Character{slug: "nissa", name: "Nissa"}
      posts = SocialFeed.candidate_fallback_posts(char, "loyal")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "hound") or String.contains?(&1, "mastiff") or
                   String.contains?(&1, "pack"))
             )
    end

    test "returns at least 4 unique thoughts for Orin" do
      char = %Character{slug: "orin", name: "Orin"}
      posts = SocialFeed.candidate_fallback_posts(char, "vigilant")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "watch") or String.contains?(&1, "lantern") or
                   String.contains?(&1, "patrol"))
             )
    end

    test "returns at least 4 unique thoughts for Rhea" do
      char = %Character{slug: "rhea", name: "Rhea"}
      posts = SocialFeed.candidate_fallback_posts(char, "sure")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "ferry") or String.contains?(&1, "river") or
                   String.contains?(&1, "barge"))
             )
    end

    test "returns at least 4 unique thoughts for Soren" do
      char = %Character{slug: "soren", name: "Soren"}
      posts = SocialFeed.candidate_fallback_posts(char, "peaceful")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "garden") or String.contains?(&1, "silence") or
                   String.contains?(&1, "temple"))
             )
    end

    test "returns at least 4 unique thoughts for Tavish" do
      char = %Character{slug: "tavish", name: "Tavish"}
      posts = SocialFeed.candidate_fallback_posts(char, "affable")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "watergate") or String.contains?(&1, "culvert") or
                   String.contains?(&1, "cargo"))
             )
    end

    test "returns at least 4 unique thoughts for Ulric" do
      char = %Character{slug: "ulric", name: "Ulric"}
      posts = SocialFeed.candidate_fallback_posts(char, "strong")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "basalt") or String.contains?(&1, "gargoyle") or
                   String.contains?(&1, "chisel"))
             )
    end

    test "returns at least 4 unique thoughts for Vesper" do
      char = %Character{slug: "vesper", name: "Vesper"}
      posts = SocialFeed.candidate_fallback_posts(char, "stargazing")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "astrolabe") or String.contains?(&1, "planet") or
                   String.contains?(&1, "star"))
             )
    end

    test "returns at least 4 unique thoughts for Winona" do
      char = %Character{slug: "winona", name: "Winona"}
      posts = SocialFeed.candidate_fallback_posts(char, "warm")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "cry") or String.contains?(&1, "generation") or
                   String.contains?(&1, "birth"))
             )
    end

    test "returns at least 4 unique thoughts for Xanthe" do
      char = %Character{slug: "xanthe", name: "Xanthe"}
      posts = SocialFeed.candidate_fallback_posts(char, "patient")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "frost-rose") or String.contains?(&1, "soil") or
                   String.contains?(&1, "garden"))
             )
    end

    test "returns at least 4 unique thoughts for Yorick" do
      char = %Character{slug: "yorick", name: "Yorick"}
      posts = SocialFeed.candidate_fallback_posts(char, "somber")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "cairn") or String.contains?(&1, "barrow") or
                   String.contains?(&1, "slate"))
             )
    end
  end

  describe "candidate_fallback_posts/2 archetype coverage" do
    test "matches blacksmith archetype keywords" do
      char = %Character{slug: "torin", description: "Master blacksmith of the mountain forge"}
      posts = SocialFeed.candidate_fallback_posts(char, "steady")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "anvil") or String.contains?(&1, "forge")))
    end

    test "matches alchemist archetype keywords" do
      char = %Character{slug: "aldous", description: "Distiller of herbal elixirs and tinctures"}
      posts = SocialFeed.candidate_fallback_posts(char, "focused")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "alembic") or String.contains?(&1, "retorts"))
             )
    end

    test "matches herbalist apothecary keywords" do
      char = %Character{slug: "sarah", description: "Forest herbalist and moss gatherer"}
      posts = SocialFeed.candidate_fallback_posts(char, "calm")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "yarrow") or String.contains?(&1, "herbal")))
    end

    test "matches guard / sentry keywords" do
      char = %Character{slug: "garrick", description: "Gate sentry on palisade perimeter watch"}
      posts = SocialFeed.candidate_fallback_posts(char, "alert")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "watch") or String.contains?(&1, "patrol")))
    end

    test "matches tavern innkeeper keywords" do
      char = %Character{slug: "helga", description: "Warm innkeeper of the southside hearth"}
      posts = SocialFeed.candidate_fallback_posts(char, "hospitable")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "hearth") or String.contains?(&1, "loaves")))
    end

    test "matches minstrel / bard keywords" do
      char = %Character{slug: "finn", description: "Wandering minstrel singing highland ballads"}
      posts = SocialFeed.candidate_fallback_posts(char, "lyrical")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "lute") or String.contains?(&1, "verses")))
    end

    test "matches weaver / textile keywords" do
      char = %Character{slug: "maren", description: "Highland weaver working wool and tapestries"}
      posts = SocialFeed.candidate_fallback_posts(char, "patient")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "loom") or String.contains?(&1, "wool")))
    end

    test "matches stone mason keywords" do
      char = %Character{slug: "orson", description: "Master stone mason and foundation builder"}
      posts = SocialFeed.candidate_fallback_posts(char, "sturdy")

      assert length(posts) >= 4

      assert Enum.any?(
               posts,
               &(String.contains?(&1, "granite") or String.contains?(&1, "chisel"))
             )
    end

    test "matches merchant / trader keywords" do
      char = %Character{slug: "nesta", description: "Spices trader running a plaza stall"}
      posts = SocialFeed.candidate_fallback_posts(char, "ambitious")

      assert length(posts) >= 4
      assert Enum.any?(posts, &(String.contains?(&1, "ledger") or String.contains?(&1, "market")))
    end

    test "provides rich general candidate pool for unclassified souls" do
      char = %Character{
        slug: "wanderer",
        description: "A mysterious traveler from the western peaks"
      }

      posts = SocialFeed.candidate_fallback_posts(char, "quiet")

      assert length(posts) >= 5
      assert Enum.any?(posts, &String.contains?(&1, "Feannag's Rest"))
    end
  end

  describe "mood modifiers in candidate pools" do
    test "appends frustrated thoughts when Fia is frustrated" do
      char = %Character{slug: "fia", name: "Fia"}
      frustrated = SocialFeed.candidate_fallback_posts(char, "frustrated")
      neutral = SocialFeed.candidate_fallback_posts(char, "calm")

      assert length(frustrated) > length(neutral)
      assert Enum.any?(frustrated, &String.contains?(&1, "discordant"))
    end

    test "appends tense telemetry thoughts when Cipher is tense" do
      char = %Character{slug: "cipher", name: "Cipher"}
      tense = SocialFeed.candidate_fallback_posts(char, "tense")
      neutral = SocialFeed.candidate_fallback_posts(char, "calm")

      assert length(tense) > length(neutral)

      assert Enum.any?(
               tense,
               &(String.contains?(&1, "jitter") or String.contains?(&1, "Anomaly"))
             )
    end

    test "appends wary thoughts when Quill is wary" do
      char = %Character{slug: "quill", name: "Quill"}
      wary = SocialFeed.candidate_fallback_posts(char, "wary")
      neutral = SocialFeed.candidate_fallback_posts(char, "calm")

      assert length(wary) > length(neutral)

      assert Enum.any?(
               wary,
               &(String.contains?(&1, "treaties") or String.contains?(&1, "register"))
             )
    end
  end

  describe "fallback_post/3 duplicate prevention" do
    test "avoids picking posts already present in recent_contents" do
      char = %Character{slug: "fia", name: "Fia"}
      candidates = SocialFeed.candidate_fallback_posts(char, "reflective")

      # Put all but one in recent_contents
      [unseen | seen] = candidates

      picked = SocialFeed.fallback_post(char, "reflective", seen)
      assert picked == unseen
    end

    test "adds temporal variation when all candidate posts are in recent_contents" do
      char = %Character{slug: "cipher", name: "Cipher"}
      candidates = SocialFeed.candidate_fallback_posts(char, "calm")

      picked = SocialFeed.fallback_post(char, "calm", candidates)

      # It should NOT match any candidate exactly, but be a variation of one
      refute picked in candidates
      assert String.length(picked) > 10

      assert Enum.any?(
               [
                 "As dusk settles",
                 "Under the quiet evening",
                 "With the morning bell",
                 "Watching the valley",
                 "Taking a quiet breath",
                 "The highland wind",
                 "Reflecting as the bells"
               ],
               &String.contains?(picked, &1)
             )
    end
  end

  describe "generate_post/2 non-repetition integration" do
    test "generates sequential posts that are distinct for the same character" do
      {:ok, char} =
        Characters.create_character(%{
          name: "Variety Tester",
          slug: "variety-tester-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active",
          description: "Blacksmith forge master of the high quarter"
        })

      # Generate 3 sequential posts
      {:ok, post1} = SocialFeed.generate_post(char.id)
      {:ok, post2} = SocialFeed.generate_post(char.id)
      {:ok, post3} = SocialFeed.generate_post(char.id)

      # All three must have non-empty content
      assert is_binary(post1.content) and post1.content != ""
      assert is_binary(post2.content) and post2.content != ""
      assert is_binary(post3.content) and post3.content != ""

      # Guarantee that post2 does not duplicate post1
      refute post2.content == post1.content
      # Guarantee that post3 does not duplicate post2 or post1
      refute post3.content == post2.content
      refute post3.content == post1.content
    end

    test "sequential posts from two distinct characters never collide" do
      {:ok, char_a} =
        Characters.create_character(%{
          name: "Smuggler Test",
          slug: "smuggler-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active",
          description: "Underground culvert smuggler"
        })

      {:ok, char_b} =
        Characters.create_character(%{
          name: "Carpenter Test",
          slug: "carpenter-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active",
          description: "Master timber carpenter"
        })

      {:ok, post_a} = SocialFeed.generate_post(char_a.id)
      {:ok, post_b} = SocialFeed.generate_post(char_b.id)

      assert post_a.content != ""
      assert post_b.content != ""
      refute post_a.content == post_b.content
    end

    test "candidate_temporal_variations returns at least 8 unique atmospheric variations" do
      base = "The mountain air is crisp and clear tonight."
      variations = SocialFeed.candidate_temporal_variations(base)

      assert length(variations) >= 8
      assert length(Enum.uniq(variations)) == length(variations)

      for var <- variations do
        assert String.ends_with?(var, base)
      end
    end

    test "all 50 founding souls have pairwise distinct fallback pools" do
      all_slugs = ~w(
        maya ravina valeria cyra elowen bram sera corvus lys tamsin oswin mara
        hale isolde rook bella cipher lyra jasper nadia percival quill rowan sable
        thorne una wren ansel briar cedric dove egon fia galen hollis ivy kael
        kestrel lark merritt nissa orin rhea soren tavish ulric vesper winona xanthe yorick
      )

      pools =
        Enum.map(all_slugs, fn slug ->
          char = %Character{slug: slug, name: String.capitalize(slug)}
          {slug, SocialFeed.candidate_fallback_posts(char, "contemplative")}
        end)

      for {slug_a, pool_a} <- pools, {slug_b, pool_b} <- pools, slug_a < slug_b do
        intersection = MapSet.intersection(MapSet.new(pool_a), MapSet.new(pool_b))

        assert MapSet.size(intersection) == 0,
               "Found overlapping fallback thoughts between #{slug_a} and #{slug_b}: #{inspect(intersection)}"
      end
    end

    test "matches smuggler and woodworker keywords for dynamic characters" do
      smuggler = %Character{slug: "rogue", description: "Clandestine harbor smuggler"}
      posts_s = SocialFeed.candidate_fallback_posts(smuggler, "wary")

      assert Enum.any?(
               posts_s,
               &(String.contains?(&1, "aqueducts") or String.contains?(&1, "cargo"))
             )

      woodworker = %Character{slug: "joiner", description: "Master carpenter of oak rafters"}
      posts_w = SocialFeed.candidate_fallback_posts(woodworker, "steady")
      assert Enum.any?(posts_w, &(String.contains?(&1, "oak") or String.contains?(&1, "rafters")))
    end
  end
end
