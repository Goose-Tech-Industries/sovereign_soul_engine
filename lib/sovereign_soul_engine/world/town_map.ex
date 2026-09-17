defmodule SovereignSoulEngine.World.TownMap do
  @moduledoc """
  Spatial World Architecture & Map Simulation for Feannag's Rest (Gleann Caorach).

  A dark fantasy walled city meeting the architectural grandeur of Elder Scrolls
  Imperial City, the verticality and intrigue of Baldur's Gate, and deep Celtic/Gothic lore.

  Provides:
  - 12 canonical districts with Gaelic titles, atmospheric lore, danger levels, and connections.
  - 1:1 Twisted Paradox tile compatibility (e.g. `region:1:tile:12:15`).
  - Spatial soul distribution & roaming for the 50 living souls.
  - AI District Expansion via `ProviderCascade`.
  """

  use GenServer

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.LLM.ProviderCascade

  import Ecto.Query, warn: false

  @pubsub_topic "town:map"

  # Canonical 12 Districts of Feannag's Rest (Gleann Caorach)
  @districts [
    %{
      slug: "crows_keep",
      name: "The Crow's Keep",
      gaelic_name: "Caisteal Feannag",
      coordinates: %{x: 0, y: 3},
      tile_id: "region:1:tile:12:15",
      zone_type: :citadel,
      danger_level: 3,
      icon: "hero-building-office-2",
      lore:
        "Perched atop the jagged crags of Craig Mor, the Crow's Keep has stood for seven centuries. Built upon the bones of an ancient Gaelic hillfort, it houses the High Council and the Iron Archives. Flocks of ravens roost in its gargoyled eaves, said to carry whispers of the dead across Gleann Caorach.",
      atmosphere:
        "Heavy highland gale howling against black obsidian battlements; banners of the iron raven snapping in the mist; ancient torches burning blue against cold granite.",
      connections: ["north_outpost", "high_sanctuary", "kings_plaza"],
      amenities: [
        "High Council Chamber",
        "Raven Aviary",
        "The Obsidian Throne",
        "Iron Sentry Walk"
      ],
      secrets: [
        "A hidden spiral staircase behind the council tapestry leads straight to the Sunken Undercity."
      ]
    },
    %{
      slug: "high_sanctuary",
      name: "High Sanctuary & Morrígan Spire",
      gaelic_name: "Cill na Feannaige",
      coordinates: %{x: 2, y: 2},
      tile_id: "region:1:tile:14:14",
      zone_type: :sacred,
      danger_level: 2,
      icon: "hero-sparkles",
      lore:
        "A monumental gothic cathedral dedicated to the Morrígan—sovereign mistress of fate, battle, and crows. Above the nave rises a colossal needle-spire of star-metal, vibrating whenever supernatural resonance or death disturbs the valley. Druids and cloistered scholars transcribe prophetic omens here.",
      atmosphere:
        "Cold blue incense swirling around rib-vaulted gothic arches; chimes echoing in rhythm with celestial ley-lines; stained glass casting amethyst shadows on damp flagstones.",
      connections: ["crows_keep", "raven_docks", "kings_plaza"],
      amenities: [
        "Star-Metal Astrolabe",
        "Crypt of the First Druid",
        "Scriptorium of Omens",
        "Altar of the Morrígan"
      ],
      secrets: [
        "The Spire chimes one extra toll whenever a soul crosses the boundary from another realm."
      ]
    },
    %{
      slug: "kings_plaza",
      name: "King's Road Plaza & Great Market",
      gaelic_name: "Margadh Mòr",
      coordinates: %{x: 0, y: 0},
      tile_id: "region:1:tile:12:12",
      zone_type: :market,
      danger_level: 3,
      icon: "hero-building-storefront",
      lore:
        "The pulsating heart of Feannag's Rest where the four ancient royal avenues converge. Built around a weathered fountain depicting the Three Sisters of Fate, the market swells with travelers, highland traders, mercenaries seeking contracts, and town criers.",
      atmosphere:
        "Clattering wagons on worn basalt pavers; shouting merchants in sheepskin cloaks; the aroma of roasted venison, dried herbs, and bitter peat ale.",
      connections: [
        "crows_keep",
        "high_sanctuary",
        "old_ironworks",
        "sunken_undercity",
        "shadowgate_warrens",
        "night_owl_quarter",
        "raven_docks"
      ],
      amenities: [
        "Fountain of the Three Sisters",
        "The Mercenary Bounties Board",
        "Grand Trade Stalls",
        "Town Crier's Rostrum"
      ],
      secrets: [
        "The third stone lion of the central fountain conceals an iron lever that opens the sluice tunnels."
      ]
    },
    %{
      slug: "old_ironworks",
      name: "The Old Ironworks & Foundry",
      gaelic_name: "A' Cheàrdach Dhubh",
      coordinates: %{x: 2, y: -1},
      tile_id: "region:1:tile:14:11",
      zone_type: :forge,
      danger_level: 4,
      icon: "hero-wrench-screwdriver",
      lore:
        "Where cold highland iron is melted down and hammered into weapons of war. Maya's forge burns day and night at the core of the district, producing steel that can withstand the unnatural cold of the outer crags. Dwarven sluice technology blends with Celtic bog-iron techniques.",
      atmosphere:
        "Roar of blast furnaces; shower of red-orange sparks bouncing off soot-stained anvils; heavy ring of sledges beating bog-iron into armor.",
      connections: ["kings_plaza", "south_bastion", "raven_docks"],
      amenities: [
        "The Master Smelter",
        "Weaponsmiths' Guildhall",
        "Bog-Iron Depository",
        "Cooling Canal"
      ],
      secrets: [
        "A hidden quenching trough is cooled by mountain runoff channeled through ancient runes."
      ]
    },
    %{
      slug: "raven_docks",
      name: "Raven Docks & Mist Pier",
      gaelic_name: "Cidhe a' Cheò",
      coordinates: %{x: 3, y: 0},
      tile_id: "region:1:tile:15:12",
      zone_type: :harbor,
      danger_level: 5,
      icon: "hero-arrows-pointing-out",
      lore:
        "The water gate where the Blackwater River cuts through the city wall into Gleann Caorach. Flat-bottomed barges deliver peat, timber, and salted cod from the outer lochs. By night, when the watch lantern burns green, unregistered cargo slips silently ashore.",
      atmosphere:
        "Brackish black water slapping rotten pilings; fog rolling in thick off the river like woolen fleece; oil lanterns swaying from timber cranes.",
      connections: ["kings_plaza", "old_ironworks", "high_sanctuary"],
      amenities: [
        "The Blackwater Crane",
        "Salt-House Warehouses",
        "The Driftwood Tavern",
        "Customs Sentry House"
      ],
      secrets: [
        "Submerged chains beneath Pier 4 can be pulled to capsize unflagged smuggler skiffs."
      ]
    },
    %{
      slug: "shadowgate_warrens",
      name: "Shadowgate Warrens & Thieves' Wynd",
      gaelic_name: "Sràid nan Dubh-sgàil",
      coordinates: %{x: -2, y: -1},
      tile_id: "region:1:tile:10:11",
      zone_type: :underworld,
      danger_level: 7,
      icon: "hero-eye-slash",
      lore:
        "A labyrinth of teetering five-story gothic tenements built into the hollow of the western curtain wall. Here the Syndicate rules through silence, stolen goods, and black-market whispers. Ravina's informants use the interconnected rooftops to traverse the city unseen.",
      atmosphere:
        "Overhanging timber roofs blocking the sky; dripping tallow lamps in claustrophobic alleys; eyes watching from darkened cellar gratings.",
      connections: ["kings_plaza", "south_bastion", "sunken_undercity", "barrowgrounds"],
      amenities: [
        "The Blind Beggar's Den",
        "Rooftop Smugglers' Runs",
        "Fence's Pawnshop",
        "The Whispering Drainpipe"
      ],
      secrets: [
        "Tapping three times on the blue iron lantern at the crossroads summons a Syndicate courier."
      ]
    },
    %{
      slug: "south_bastion",
      name: "The South Bastion & Iron Gate",
      gaelic_name: "Gàrradh a' Chinn a Deas",
      coordinates: %{x: 0, y: -3},
      tile_id: "region:1:tile:12:9",
      zone_type: :bastion,
      danger_level: 6,
      icon: "hero-shield-check",
      lore:
        "The primary defensive fortress standing against the untamed wilderness of southern Gleann Caorach. Corvus commands the ramparts, running drills against barbarian raids and unnatural creatures that creep out of the southern pines. The stones here bear claw marks from sieges long past.",
      atmosphere:
        "Marching sentries in iron plate; brass horns echoing across the barbican; cauldrons of boiling pitch set above the double iron portcullis.",
      connections: ["kings_plaza", "old_ironworks", "shadowgate_warrens"],
      amenities: [
        "The Great Barbican",
        "Garrison Barracks",
        "Ballista Platforms",
        "Prisoners' Bastille"
      ],
      secrets: [
        "A sealed iron sally port in the moat allows six cavalry riders to flank besiegers unseen."
      ]
    },
    %{
      slug: "barrowgrounds",
      name: "Whispering Barrowgrounds & Crypts",
      gaelic_name: "Cladh nan Sinnsear",
      coordinates: %{x: -3, y: 1},
      tile_id: "region:1:tile:9:13",
      zone_type: :barrow,
      danger_level: 6,
      icon: "hero-moon",
      lore:
        "Pre-dating Feannag's Rest by a millennium, these earthen burial mounds hold the clan chiefs of ancient Alba. Valeria studies the ley-lines that intersect among the cairns. Locals leave oatcakes and honey at threshold stones to placate the restless dead.",
      atmosphere:
        "Ancient dolmens and standing stones wrapped in pale mist; crying ravens perched on mossy Celtic crosses; weeping willows and the scent of wild thyme and damp soil.",
      connections: ["shadowgate_warrens", "weavers_commons", "night_owl_quarter"],
      amenities: [
        "The Tomb of the Horned King",
        "The Weeping Dolmen",
        "Charnel House of Skulls",
        "Standing Stone Ring"
      ],
      secrets: [
        "At the stroke of midnight during a waxing moon, the stones whisper true names of those who will die that month."
      ]
    },
    %{
      slug: "night_owl_quarter",
      name: "Night-Owl Taphouse Quarter",
      gaelic_name: "Taigh-òsda na h-Oidhche",
      coordinates: %{x: -1, y: 1},
      tile_id: "region:1:tile:11:13",
      zone_type: :tavern,
      danger_level: 3,
      icon: "hero-fire",
      lore:
        "The bohemian, sleepless district of the city. While the rest of the town sleeps, the taverns here roar until dawn. Philosophers, night-shift guards, poets, bards, and conspirators drink heather ale by the hearth fires, debating politics and trading scandalous town gossip.",
      atmosphere:
        "Fiddles and bagpipes spilling through leaded glass windows; yellow candlelight reflecting on wet cobbles; warm hearth-smoke and the clink of pewter tankards.",
      connections: ["kings_plaza", "barrowgrounds", "weavers_commons"],
      amenities: [
        "The Black Cockade Inn",
        "The Fiddler's Hearth",
        "Bards' Open Rostrum",
        "Distillery of Heather Mead"
      ],
      secrets: [
        "The hearth in the cellar of the Black Cockade is hollowed out to hide up to ten fugitives."
      ]
    },
    %{
      slug: "weavers_commons",
      name: "Weaver's Commons & Apothecary Row",
      gaelic_name: "Sràid an Luchd-fighe",
      coordinates: %{x: -2, y: 2},
      tile_id: "region:1:tile:10:14",
      zone_type: :artisan,
      danger_level: 2,
      icon: "hero-scissors",
      lore:
        "Home to weavers who card and spin the famous heavy tartan of Gleann Caorach. Beside the looms sit herbalists and alchemists, who brew poultices for the garrison and subtle sleep-tonics for the noble houses.",
      atmosphere:
        "Rhythmic thrum of wooden looms; scent of drying belladonna, elderflower, and sheep's wool; rows of slate cottages with herbal window boxes.",
      connections: ["north_outpost", "crows_keep", "night_owl_quarter", "barrowgrounds"],
      amenities: [
        "The Great Loom Hall",
        "Master Apothecary Laboratory",
        "Drying Racks of Wolfsbane",
        "Herbalist Greenhouse"
      ],
      secrets: [
        "The master weaver weaves coded protective runes directly into the lining of all garrison cloaks."
      ]
    },
    %{
      slug: "sunken_undercity",
      name: "The Sunken Undercity & Aqueducts",
      gaelic_name: "An Seann Baile Iosal",
      coordinates: %{x: 0, y: -1},
      tile_id: "region:1:tile:12:11",
      zone_type: :undercity,
      danger_level: 8,
      icon: "hero-cube-transparent",
      lore:
        "Subterranean ruins of an ancient drowned city upon which Feannag's Rest was founded. Below the paved streets lie forgotten vaults, sunken stone bridges, and smuggler waterways. Outcasts, rogue sorcerers, and those wishing to vanish from the surface make their home here.",
      atmosphere:
        "Rushing echoes of water through vaulted stone aqueducts; bioluminescent cave moss casting pale emerald light across flooded flagstones; dripping stalactites.",
      connections: ["kings_plaza", "shadowgate_warrens", "south_bastion"],
      amenities: [
        "The Vault of Sluices",
        "The Sunken Basilica",
        "Clandestine Smugglers' Landing",
        "The Moss Grotto"
      ],
      secrets: [
        "Ancient bronze floodgates can be turned to flood the entire lower catacombs if invaded."
      ]
    },
    %{
      slug: "north_outpost",
      name: "North Watchtower & Moorland Pass",
      gaelic_name: "Tùr a' Chinn a Tuath",
      coordinates: %{x: -1, y: 3},
      tile_id: "region:1:tile:11:15",
      zone_type: :outpost,
      danger_level: 5,
      icon: "hero-flag",
      lore:
        "Built on the highest northern promontory, this watchtower looks out over the treacherous pass connecting Feannag's Rest to the jagged peaks of the Grampian spine. Scouts stationed here use mirrors by day and beacon fires by night to warn of approaching highland clans or blizzard fronts.",
      atmosphere:
        "Freezing mountain winds carrying the scent of pine and crushed heather; sweeping panoramic view of the desolate glen; signal beacon stacked high with dry spruce logs.",
      connections: ["crows_keep", "weavers_commons"],
      amenities: [
        "The Beacon of the North",
        "Eagle's Eyrie Lookout",
        "Rangers' Outpost",
        "Mountain Pass Gate"
      ],
      secrets: [
        "A hidden goat track down the eastern precipice bypasses the main toll gate entirely."
      ]
    }
  ]

  # --- Public API -------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Returns the full town map including all 12 districts with live souls and drama."
  @spec get_map() :: map()
  def get_map do
    GenServer.call(__MODULE__, :get_map)
  end

  @doc "Returns detailed data for a specific district slug."
  @spec get_district(String.t()) :: map() | nil
  def get_district(slug) when is_binary(slug) do
    GenServer.call(__MODULE__, {:get_district, slug})
  end

  @doc "Returns the current district for a given character id or slug."
  @spec get_soul_location(String.t()) :: String.t()
  def get_soul_location(character_id_or_slug) do
    GenServer.call(__MODULE__, {:get_soul_location, character_id_or_slug})
  end

  @doc "Moves a soul to a target district."
  @spec move_soul(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def move_soul(character_id_or_slug, target_slug) do
    GenServer.call(__MODULE__, {:move_soul, character_id_or_slug, target_slug})
  end

  @doc "Simulates roaming: moves an eligible cohort of souls to adjacent districts."
  @spec simulate_roaming() :: {:ok, non_neg_integer()}
  def simulate_roaming do
    GenServer.call(__MODULE__, :simulate_roaming)
  end

  @doc """
  Expands a district using the AI System (ProviderCascade).
  Generates a new point of interest, discovered secret, or atmospheric event.
  """
  @spec expand_district_with_ai(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def expand_district_with_ai(district_slug, prompt \\ "", opts \\ []) do
    GenServer.call(__MODULE__, {:expand_district_with_ai, district_slug, prompt, opts}, 30_000)
  end

  # --- GenServer Callbacks ----------------------------------------------------

  @impl true
  def init(:ok) do
    districts_map =
      @districts
      |> Enum.map(&{&1.slug, &1})
      |> Map.new()

    soul_locations = seed_soul_locations()

    state = %{
      districts: districts_map,
      soul_locations: soul_locations,
      expansions: %{},
      recent_events: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_map, _from, state) do
    enriched_districts =
      @districts
      |> Enum.map(fn base ->
        slug = base.slug
        current = Map.get(state.districts, slug, base)
        present_souls = get_souls_in_district(slug, state.soul_locations)
        expansions = Map.get(state.expansions, slug, [])
        events = Map.get(state.recent_events, slug, [])

        current
        |> Map.put(:present_souls, present_souls)
        |> Map.put(:soul_count, length(present_souls))
        |> Map.put(:expansions, expansions)
        |> Map.put(:recent_events, events)
      end)

    map_overview = %{
      town_name: "Feannag's Rest",
      region_name: "Gleann Caorach",
      district_count: length(@districts),
      total_souls: map_size(state.soul_locations),
      districts: enriched_districts
    }

    {:reply, map_overview, state}
  end

  @impl true
  def handle_call({:get_district, slug}, _from, state) do
    case Map.get(state.districts, slug) do
      nil ->
        {:reply, nil, state}

      base ->
        present_souls = get_souls_in_district(slug, state.soul_locations)
        expansions = Map.get(state.expansions, slug, [])
        events = Map.get(state.recent_events, slug, [])

        result =
          base
          |> Map.put(:present_souls, present_souls)
          |> Map.put(:soul_count, length(present_souls))
          |> Map.put(:expansions, expansions)
          |> Map.put(:recent_events, events)

        {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:get_soul_location, char_key}, _from, state) do
    location = Map.get(state.soul_locations, char_key, "kings_plaza")
    {:reply, location, state}
  end

  @impl true
  def handle_call({:move_soul, char_key, target_slug}, _from, state) do
    if Map.has_key?(state.districts, target_slug) do
      old_location = Map.get(state.soul_locations, char_key, "kings_plaza")
      new_locations = Map.put(state.soul_locations, char_key, target_slug)
      new_state = %{state | soul_locations: new_locations}

      broadcast_update({:soul_moved, char_key, old_location, target_slug})

      {:reply, {:ok, %{character: char_key, from: old_location, to: target_slug}}, new_state}
    else
      {:reply, {:error, :unknown_district}, state}
    end
  end

  @impl true
  def handle_call(:simulate_roaming, _from, state) do
    # Pick 8 souls and move them to random connected neighbor districts
    moved_count =
      state.soul_locations
      |> Enum.take_random(8)
      |> Enum.reduce(0, fn {char_id, current_slug}, acc ->
        district = Map.get(state.districts, current_slug)

        if district && district.connections != [] do
          next_slug = Enum.random(district.connections)
          send(self(), {:deferred_move, char_id, next_slug})
          acc + 1
        else
          acc
        end
      end)

    {:reply, {:ok, moved_count}, state}
  end

  @impl true
  def handle_call({:expand_district_with_ai, slug, prompt, opts}, _from, state) do
    case Map.get(state.districts, slug) do
      nil ->
        {:reply, {:error, :district_not_found}, state}

      district ->
        expansion = call_ai_expansion(district, prompt, opts)

        existing_expansions = Map.get(state.expansions, slug, [])
        new_expansions = [expansion | existing_expansions]
        new_state = put_in(state.expansions[slug], new_expansions)

        broadcast_update({:district_expanded, slug, expansion})

        {:reply, {:ok, expansion}, new_state}
    end
  end

  @impl true
  def handle_info({:deferred_move, char_id, target_slug}, state) do
    new_locations = Map.put(state.soul_locations, char_id, target_slug)
    {:noreply, %{state | soul_locations: new_locations}}
  end

  # --- Helpers & AI Generation ------------------------------------------------

  defp get_souls_in_district(district_slug, soul_locations) do
    character_ids =
      soul_locations
      |> Enum.filter(fn {_id, loc} -> loc == district_slug end)
      |> Enum.map(fn {id, _loc} -> id end)

    if Enum.empty?(character_ids) do
      []
    else
      from(c in Character,
        where: c.id in ^character_ids or c.slug in ^character_ids,
        select: %{
          id: c.id,
          name: c.name,
          slug: c.slug,
          description: c.description,
          status: c.status
        }
      )
      |> Repo.all()
    end
  rescue
    _ -> []
  end

  # Seeds the 50 souls across the 12 districts based on lore affinity
  defp seed_soul_locations do
    souls = load_all_npcs()

    # Pre-defined home anchors for key characters
    named_anchors = %{
      "maya" => "old_ironworks",
      "corvus" => "south_bastion",
      "ravina" => "shadowgate_warrens",
      "valeria" => "high_sanctuary",
      "goose" => "kings_plaza",
      "quill" => "night_owl_quarter",
      "soren" => "crows_keep",
      "vael" => "barrowgrounds",
      "cyra" => "raven_docks"
    }

    all_slugs = Enum.map(@districts, & &1.slug)

    Enum.reduce(souls, %{}, fn soul, acc ->
      slug = soul.slug || ""

      assigned_district =
        Map.get(named_anchors, slug) ||
          assign_by_archetype(soul, all_slugs)

      Map.put(acc, soul.id, assigned_district)
    end)
  end

  defp assign_by_archetype(soul, all_slugs) do
    desc = String.downcase(soul.description || "")

    cond do
      String.contains?(desc, ["guard", "blade", "soldier", "warrior", "sentry"]) ->
        Enum.random(["south_bastion", "north_outpost", "crows_keep"])

      String.contains?(desc, ["magic", "spell", "arcane", "seer", "prophet", "priest"]) ->
        Enum.random(["high_sanctuary", "barrowgrounds"])

      String.contains?(desc, ["smith", "forge", "craft", "hammer", "builder", "miner"]) ->
        Enum.random(["old_ironworks", "weavers_commons"])

      String.contains?(desc, ["thief", "shadow", "rogue", "assassin", "smuggler", "spy"]) ->
        Enum.random(["shadowgate_warrens", "sunken_undercity", "raven_docks"])

      String.contains?(desc, ["bard", "drink", "music", "ale", "poet", "scholar"]) ->
        Enum.random(["night_owl_quarter", "kings_plaza"])

      true ->
        Enum.random(all_slugs)
    end
  end

  defp load_all_npcs do
    from(c in Character, where: c.kind == "npc" and c.status == "active")
    |> Repo.all()
  rescue
    _ -> []
  end

  defp call_ai_expansion(district, prompt, opts) do
    system_prompt = """
    You are the Master World Architect of Feannag's Rest in Gleann Caorach.
    The setting is dark fantasy meets Elder Scrolls Imperial City, Baldur's Gate, and Scottish Celtic/Gothic folklore.
    District: #{district.name} (#{district.gaelic_name})
    Current Lore: #{district.lore}
    Atmosphere: #{district.atmosphere}

    Create an atmospheric new feature or secret for this district based on the prompt.
    Respond with JSON containing:
    {
      "title": "Short gothic title",
      "type": "sub_location" | "secret_vault" | "omen_encounter" | "ancient_relic",
      "description": "2-3 sentences of evocative dark-fantasy lore and sensory detail",
      "danger_shift": integer between -2 and +2,
      "uncovered_by": "A mysterious rumor or clan whisper"
    }
    """

    user_message =
      if prompt != "",
        do: "Expand this district with the following theme: #{prompt}",
        else: "Generate a captivating hidden feature or historical secret for this district."

    case ProviderCascade.respond(
           %{
             system: system_prompt,
             messages: [%{role: "user", content: user_message}]
           },
           opts
         ) do
      {:ok, %{"title" => title, "description" => desc} = map} ->
        %{
          id: Ecto.UUID.generate(),
          title: title,
          type: map["type"] || "sub_location",
          description: desc,
          danger_shift: map["danger_shift"] || 0,
          uncovered_by: map["uncovered_by"] || "Local rumor",
          created_at: DateTime.utc_now()
        }

      _ ->
        fallback_expansion(district, prompt)
    end
  end

  defp fallback_expansion(district, prompt) do
    %{
      id: Ecto.UUID.generate(),
      title: "The Weeping Alcove of #{district.name}",
      type: "secret_vault",
      description:
        if(prompt != "",
          do: "Influenced by '#{prompt}', a moss-covered iron grille reveals an ancient clan reliquary echoing with low chants.",
          else: "Behind an age-worn Celtic crest, a narrow passage descends into cool darkness scented with dried pine and old iron."
        ),
      danger_shift: 1,
      uncovered_by: "Whispers overheard between night sentries",
      created_at: DateTime.utc_now()
    }
  end

  defp broadcast_update(payload) do
    Phoenix.PubSub.broadcast(SovereignSoulEngine.PubSub, @pubsub_topic, payload)
  rescue
    _ -> :ok
  end
end
