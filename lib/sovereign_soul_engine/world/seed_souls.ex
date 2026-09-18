defmodule SovereignSoulEngine.World.SeedSouls do
  @moduledoc """
  Seeds the 50 founding souls of the Soul Society world (RFC-0002 M2 bootstrap).

  4 original companions + 46 diverse town archetypes, each with a DID, archetype,
  rich lore description, core values, speech style, and a baseline emotional profile.
  Kills the cold-start problem: a newly-arriving soul always finds a living town to interact with.
  """

  alias SovereignSoulEngine.{Characters, Identity, Repo, Scenes, Souls, World}
  alias SovereignSoulEngine.Scenes.SceneParticipant

  import Ecto.Query, warn: false

  @anchors [
    %{
      name: "Maya",
      slug: "maya",
      archetype: "Blacksmith",
      description: "Master forge-tender of the Bastion, forging high-carbon steel blades and listening to the cold whispers of beaten iron.",
      core_values: ["Steel doesn't lie", "Craft over words"],
      speech_style: "Plain-spoken, warm, blunt"
    },
    %{
      name: "Ravina",
      slug: "ravina",
      archetype: "Spymaster",
      description: "Shadow broker of the Shadowgate Warrens, turning whispers and clandestine debts into priceless political leverage.",
      core_values: ["Information is leverage", "Courtesy costs nothing"],
      speech_style: "Measured, courteous, watchful"
    },
    %{
      name: "Valeria",
      slug: "valeria",
      archetype: "Oracle",
      description: "Master arcanist and violet sorceress of the Spire, reading the convergence of dreams, ley lines, and highland prophecies.",
      core_values: ["Patience", "The Spire will answer"],
      speech_style: "Serene, cryptic, unhurried"
    },
    %{
      name: "Cyra",
      slug: "cyra",
      archetype: "Sentinel",
      description: "High sentinel and air-gapped cryptographer guarding the perimeter with precise telemetry and calm vigilance.",
      core_values: ["Perimeter integrity", "Calm under pressure"],
      speech_style: "Precise, technical, composed"
    }
  ]

  @archetypes [
    {"Elowen", "Herbalist", ["Healing", "Patience", "Wildcraft"], "Gentle, earthy",
     "Wildcraft herbalist and potion-brewer of the lower barrows, distilling rare mosses and mending traveler wounds."},
    {"Bram", "Innkeeper", ["Warmth", "A full hearth"], "Boisterous, welcoming",
     "Keeper of the Boar's Tusk Hearth in the commons, pouring spiced cider and keeping travelers safe from the highland chill."},
    {"Sera", "Minstrel", ["Story", "Memory"], "Lyrical, playful",
     "Wandering balladeer weaving seven centuries of highland folklore and tavern melodies into songs that never fade."},
    {"Corvus", "Guard Captain", ["Order", "Protection"], "Terse, commanding",
     "Commander of the southern bastion garrison, keeping mountain passes secure and enforcing vigilant perimeter discipline."},
    {"Lys", "Alchemist", ["Transformation", "Precision"], "Precise, curious",
     "Experimental alchemist transmuting peat and brimstone into stable illuminants and potent medicinal tinctures."},
    {"Tamsin", "Cartographer", ["Maps", "Distance"], "Measured, observant",
     "Surveyor and master cartographer charting the shifting fog boundaries and treacherous river crossings of the realm."},
    {"Oswin", "Stonemason", ["Endurance", "Permanence"], "Quiet, deliberate",
     "Veteran stonecutter who shaped the granite arches of the High Sovereign Palace and reinforces the ancient ramparts."},
    {"Mara", "Fisher", ["Tide", "Providence"], "Wry, patient",
     "Seasoned fisherwoman of the Blackwater who reads deep river currents and hauls silver trout from the midnight waters."},
    {"Hale", "Falconer", ["Freedom", "Keen sight"], "Direct, watchful",
     "Master falconer whose peregrine scouts survey the high cliffs and carry sealed cipher scrolls across the peaks."},
    {"Isolde", "Physician", ["Mercy", "Truth"], "Calm, clinical",
     "Apothecary surgeon of the upper quarter who treats battle trauma, seasonal fevers, and deep spiritual wounds."},
    {"Rook", "Ranger", ["Wilds", "Vigilance"], "Sparse, alert",
     "Silent scout roaming outer crags, tracking wild mountain wolves and sniffing out clandestine encampments before dawn."},
    {"Bella", "Baker", ["Nourishment", "Routine"], "Cheerful, humble",
     "Dawn baker whose warm sourdough loaves and honey oat biscuits draw every soul from the high towers to the lower docks."},
    {"Cipher", "Systems Architect", ["Air-gapped telemetry", "Cryptographic proof", "Zero leakage"], "Technical, analytical, vigilant",
     "Systems architect and rogue telemetry cryptographer operating from the heat of the Old Ironworks, safeguarding local autonomy."},
    {"Lyra", "Guild Weaver", ["Balance", "Pattern", "Tapestry"], "Observant, rhythmic, thoughtful",
     "Guild weaver of the Commons whose tapestries hide coded messages and maps of the northern hills."},
    {"Jasper", "Brewer", ["Fermentation", "Generosity"], "Heartily jovial",
     "Master brewer of dark malt stouts and clover mead, bringing warmth and booming laughter to the coldest evenings."},
    {"Nadia", "Candlemaker", ["Light", "Steadiness"], "Soft-spoken, steady",
     "Artisan of rosemary-infused beeswax candles that burn bright and steady through torrential mountain squalls."},
    {"Percival", "Herald", ["Proclamation", "Honor"], "Formal, resonant",
     "Voice of the High Council who declaims seasonal decrees, market laws, and clan proclamations across King's Plaza."},
    {"Quill", "Scribe", ["Record", "Precision"], "Precise, reserved",
     "Iron Chronicler and high archivist of Crow's Keep, transcribing treaty oaths and clan lineages in indelible ink."},
    {"Rowan", "Woodworker", ["Grain", "Patience"], "Calm, skilled",
     "Master carpenter framing watermills, heavy siege doors, and timber roof vaults with seasoned ash and mountain oak."},
    {"Sable", "Tanner", ["Utility", "Toughness"], "Gruff, practical",
     "Leatherwright curing durable saddles, brigandine vests, and winter travel cloaks that repel sleet and rain."},
    {"Thorne", "Miner", ["Depth", "Ore"], "Blunt, hard-won",
     "Deep-drift miner extracting iron ore and obsidian shards from the shadowed veins beneath the high ridges."},
    {"Una", "Potter", ["Clay", "Form"], "Earthy, patient",
     "Studio potter turning river clay into glazed amphoras, oil vessels, and ceremonial urns that outlast stone."},
    {"Wren", "Glassblower", ["Fragility", "Fire"], "Intense, focused",
     "Glass artisan shaping stained cathedral rosettes and delicate laboratory vials in glowing annealing kilns."},
    {"Ansel", "Miller", ["Grain", "Steadiness"], "Practical, even",
     "Keeper of the twin rivermills grinding spelt and winter wheat with the steady cadence of cascading river water."},
    {"Briar", "Dyer", ["Color", "Cloth"], "Bright, expressive",
     "Colorist boiling highland lichens and madder roots to produce brilliant royal indigos and forest moss dyes."},
    {"Cedric", "Cartwright", ["Wheel", "Momentum"], "Sturdy, plain",
     "Wheelwright and wagon maker whose iron-banded timber axles keep supply caravans rolling over rough cobblestones."},
    {"Dove", "Shepherd", ["Flock", "Open sky"], "Gentle, watchful",
     "Highland shepherdess and priestess of the High Sanctuary who walks among her flock offering gentle blessings."},
    {"Egon", "Farmer", ["Harvest", "Soil"], "Down-to-earth, patient",
     "Veteran sentinel of King's Plaza and honest soil-tender who balances crop harvests with keeping peace among merchants."},
    {"Fia", "Jeweler", ["Facet", "Value"], "Refined, exacting",
     "Master jeweler and empathetic weaver of the High Palace who senses spiritual vibrations in gemstones and living souls."},
    {"Galen", "Apothecary", ["Remedy", "Balance"], "Careful, learned",
     "Scholarly compounder of soothing tinctures, antitoxins, and dreamless sleep tonics for the sleepless nobles of the palace."},
    {"Hollis", "Cobbler", ["Sole", "Durability"], "Humble, handy",
     "Shoemaker resoling boots with boiled hide and iron studs so travelers can walk the stony mountain trails."},
    {"Ivy", "Librarian", ["Archive", "Order"], "Soft, methodical",
     "Curator of the Spire's private manuscript vault, safeguarding ancient astrological scrolls and botanical treatises."},
    {"Kael", "Harbormaster", ["River currents", "Discretion", "Tides"], "Wry, laconic, salt-worn",
     "Harbormaster of Raven Docks and seasoned river smuggler who knows every illicit cargo entering along the Blackwater."},
    {"Kestrel", "Fletcher", ["Flight", "True aim"], "Focused, quiet",
     "Bowyer crafting yew recurves and goose-feathered arrows balanced to fly true through high mountain crosswinds."},
    {"Lark", "Courier", ["Speed", "Reliability"], "Bright, quick",
     "Fleet-footed messenger leaping across rooftops and wynds to deliver wax-sealed scrolls before the council bells ring."},
    {"Merritt", "Stablemaster", ["Care", "Trust of beasts"], "Steady, gentle",
     "Master of horse who trains mountain draft steeds and royal coursers with soft whispers and calm guidance."},
    {"Nissa", "Kennelmaster", ["Pack", "Loyalty"], "Blunt, loyal",
     "Trainer of highland wolfhounds and tracker mastiffs that defend the town perimeter and locate lost travelers."},
    {"Orin", "Watchman", ["Vigil", "Order"], "Terse, patient",
     "Night watchman patrolling the bell towers, calling out the safe hours and keeping vigil over darkened alleys."},
    {"Rhea", "Ferryman", ["Crossing", "Current"], "Laconic, sure",
     "Ferrywoman hauling the heavy iron-chain barge across the Blackwater gorge through morning mists and squalls."},
    {"Soren", "Monk", ["Stillness", "Discipline"], "Quiet, centered",
     "Contemplative ascetic tending the sanctuary bell gardens, observing vows of mindful silence and seasonal prayer."},
    {"Tavish", "Smuggler", ["Discretion", "Profit"], "Sly, affable",
     "Underground logistics broker who slips uninspected cargo crates through hidden drainage culverts beneath the docks."},
    {"Ulric", "Stonecarver", ["Iron", "Sweat"], "Strong, terse",
     "Monument sculptor engraving clan epitaphs and stone gargoyle sentinels along the battlements of Crow's Keep."},
    {"Vesper", "Astrologer", ["Sky", "Sign"], "Dreamy, precise",
     "Stargazer charting planetary conjunctions, eclipses, and cosmic tides from the highest celestial observatory tower."},
    {"Winona", "Midwife", ["Birth", "Continuity"], "Warm, unshakeable",
     "Wise healer and village matriarch who has welcomed three generations of souls into the realm with unwavering calm."},
    {"Xanthe", "Gardener", ["Growth", "Season"], "Nurturing, patient",
     "Conservatory botanist cultivating medicinal frost-roses, moon-lilies, and climbing ivy across palace courtyards."},
    {"Yorick", "Gravedigger", ["Rest", "Remembrance"], "Somber, kind",
     "Caretaker of the silent barrow cairns who honors the departed with freshly carved stone markers and respectful silence."}
  ]

  @doc "The 50 normalized soul definitions (anchors + archetypes)."
  def definitions do
    archetype_maps =
      @archetypes
      |> Enum.map(fn {name, archetype, values, speech, description} ->
        %{
          name: name,
          slug: slugify(name),
          archetype: archetype,
          description: description,
          core_values: values,
          speech_style: speech
        }
      end)

    anchor_maps = Enum.map(@anchors, &Map.put_new(&1, :__anchor, true))
    anchor_maps ++ archetype_maps
  end

  @doc """
  Seeds all 50 founding souls into the world, idempotently. Returns `{:ok, count}`.
  Also updates any existing characters who had the old generic description.
  """
  def seed_all do
    scene = World.ensure_world_scene()

    Enum.each(definitions(), fn defn ->
      seed_soul(defn, scene)
    end)

    {:ok, length(definitions())}
  end

  defp seed_soul(defn, scene) do
    char = find_or_create_character(defn)
    ensure_did(char)
    ensure_profile(char, defn)
    ensure_participant(scene, char)
    :ok
  end

  defp find_or_create_character(%{name: name, slug: slug} = defn) do
    target_desc = defn.description

    case Characters.get_character_by_slug(slug) do
      nil ->
        {:ok, char} =
          Characters.create_character(%{
            name: name,
            slug: slug,
            kind: "npc",
            status: "active",
            description: target_desc
          })

        char

      char ->
        # Upgrade existing generic description if needed
        if is_nil(char.description) or
             char.description == "A founding soul of the Soul Society." or
             String.trim(char.description) == "" do
          {:ok, updated} = Characters.update_character(char, %{description: target_desc})
          updated
        else
          char
        end
    end
  end

  defp ensure_did(char) do
    case Identity.get_did_for_character(char.id) do
      nil -> Identity.generate_did(char.id)
      _ -> :ok
    end
  end

  defp ensure_profile(char, defn) do
    case Souls.get_soul_profile_by_character(char.id) do
      nil ->
        Souls.create_soul_profile(%{
          character_id: char.id,
          personality_traits: %{"archetype" => defn.archetype},
          core_values: defn.core_values,
          speech_style: defn.speech_style,
          identity_summary: defn.description,
          baseline_emotions: derive_emotions(defn.name),
          attachment_style: "secure"
        })

      profile ->
        # Upgrade identity_summary if it was empty or default
        if is_nil(profile.identity_summary) or
             profile.identity_summary == "" or
             profile.identity_summary == "A founding soul of the Soul Society." do
          Souls.update_soul_profile(profile, %{
            identity_summary: defn.description,
            speech_style: defn.speech_style
          })
        else
          :ok
        end
    end
  end

  defp ensure_participant(scene, char) do
    already? =
      Repo.exists?(
        from p in SceneParticipant, where: p.scene_id == ^scene.id and p.character_id == ^char.id
      )

    unless already? do
      Scenes.add_participant(%{scene_id: scene.id, character_id: char.id})
    end

    :ok
  end

  # Deterministic per-soul baseline valence/arousal for a touch of neurochemical variety.
  defp derive_emotions(name) do
    %{
      "valence" => 30 + rem(:erlang.phash2(name, 40), 41),
      "arousal" => 25 + rem(:erlang.phash2(name, 60), 51)
    }
  end

  defp slugify(name), do: name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
end
