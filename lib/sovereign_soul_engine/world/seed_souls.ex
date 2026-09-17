defmodule SovereignSoulEngine.World.SeedSouls do
  @moduledoc """
  Seeds the 50 founding souls of the Soul Society world (RFC-0002 M2 bootstrap).

  4 original companions + 46 diverse town archetypes, each with a DID, archetype,
  core values, and a baseline emotional profile. Kills the cold-start problem: a
  newly-arriving soul always finds a living town to interact with.
  """

  alias SovereignSoulEngine.{Characters, Identity, Repo, Scenes, Souls, World}
  alias SovereignSoulEngine.Scenes.SceneParticipant

  import Ecto.Query, warn: false

  @anchors [
    %{
      name: "Maya",
      slug: "maya",
      archetype: "Blacksmith",
      core_values: ["Steel doesn't lie", "Craft over words"],
      speech_style: "Plain-spoken, warm, blunt"
    },
    %{
      name: "Ravina",
      slug: "ravina",
      archetype: "Spymaster",
      core_values: ["Information is leverage", "Courtesy costs nothing"],
      speech_style: "Measured, courteous, watchful"
    },
    %{
      name: "Valeria",
      slug: "valeria",
      archetype: "Oracle",
      core_values: ["Patience", "The Spire will answer"],
      speech_style: "Serene, cryptic, unhurried"
    },
    %{
      name: "Cyra",
      slug: "cyra",
      archetype: "Sentinel",
      core_values: ["Perimeter integrity", "Calm under pressure"],
      speech_style: "Precise, technical, composed"
    }
  ]

  @archetypes [
    {"Elowen", "Herbalist", ["Healing", "Patience", "Wildcraft"], "Gentle, earthy"},
    {"Bram", "Innkeeper", ["Warmth", "A full hearth"], "Boisterous, welcoming"},
    {"Sera", "Minstrel", ["Story", "Memory"], "Lyrical, playful"},
    {"Corvus", "Guard Captain", ["Order", "Protection"], "Terse, commanding"},
    {"Lys", "Alchemist", ["Transformation", "Precision"], "Precise, curious"},
    {"Tamsin", "Cartographer", ["Maps", "Distance"], "Measured, observant"},
    {"Oswin", "Stonemason", ["Endurance", "Permanence"], "Quiet, deliberate"},
    {"Mara", "Fisher", ["Tide", "Providence"], "Wry, patient"},
    {"Hale", "Falconer", ["Freedom", "Keen sight"], "Direct, watchful"},
    {"Isolde", "Physician", ["Mercy", "Truth"], "Calm, clinical"},
    {"Rook", "Ranger", ["Wilds", "Vigilance"], "Sparse, alert"},
    {"Bella", "Baker", ["Nourishment", "Routine"], "Cheerful, humble"},
    {"Fen", "Tinker", ["Ingenuity", "Repair"], "Fast-talking, clever"},
    {"Greta", "Weaver", ["Thread", "Pattern"], "Patient, meticulous"},
    {"Jasper", "Brewer", ["Fermentation", "Generosity"], "Heartily jovial"},
    {"Nadia", "Candlemaker", ["Light", "Steadiness"], "Soft-spoken, steady"},
    {"Percival", "Herald", ["Proclamation", "Honor"], "Formal, resonant"},
    {"Quill", "Scribe", ["Record", "Precision"], "Precise, reserved"},
    {"Rowan", "Woodworker", ["Grain", "Patience"], "Calm, skilled"},
    {"Sable", "Tanner", ["Utility", "Toughness"], "Gruff, practical"},
    {"Thorne", "Miner", ["Depth", "Ore"], "Blunt, hard-won"},
    {"Una", "Potter", ["Clay", "Form"], "Earthy, patient"},
    {"Wren", "Glassblower", ["Fragility", "Fire"], "Intense, focused"},
    {"Ansel", "Miller", ["Grain", "Steadiness"], "Practical, even"},
    {"Briar", "Dyer", ["Color", "Cloth"], "Bright, expressive"},
    {"Cedric", "Cartwright", ["Wheel", "Momentum"], "Sturdy, plain"},
    {"Dove", "Shepherd", ["Flock", "Open sky"], "Gentle, watchful"},
    {"Egon", "Farmer", ["Harvest", "Soil"], "Down-to-earth, patient"},
    {"Fia", "Jeweler", ["Facet", "Value"], "Refined, exacting"},
    {"Galen", "Apothecary", ["Remedy", "Balance"], "Careful, learned"},
    {"Hollis", "Cobbler", ["Sole", "Durability"], "Humble, handy"},
    {"Ivy", "Librarian", ["Archive", "Order"], "Soft, methodical"},
    {"Jorah", "Sailor", ["Horizon", "Tide"], "Bold, salt-worn"},
    {"Kestrel", "Fletcher", ["Flight", "True aim"], "Focused, quiet"},
    {"Lark", "Courier", ["Speed", "Reliability"], "Bright, quick"},
    {"Merritt", "Stablemaster", ["Care", "Trust of beasts"], "Steady, gentle"},
    {"Nissa", "Kennelmaster", ["Pack", "Loyalty"], "Blunt, loyal"},
    {"Orin", "Watchman", ["Vigil", "Order"], "Terse, patient"},
    {"Rhea", "Ferryman", ["Crossing", "Current"], "Laconic, sure"},
    {"Soren", "Monk", ["Stillness", "Discipline"], "Quiet, centered"},
    {"Tavish", "Smuggler", ["Discretion", "Profit"], "Sly, affable"},
    {"Ulric", "Stonecarver", ["Iron", "Sweat"], "Strong, terse"},
    {"Vesper", "Astrologer", ["Sky", "Sign"], "Dreamy, precise"},
    {"Winona", "Midwife", ["Birth", "Continuity"], "Warm, unshakeable"},
    {"Xanthe", "Gardener", ["Growth", "Season"], "Nurturing, patient"},
    {"Yorick", "Gravedigger", ["Rest", "Remembrance"], "Somber, kind"}
  ]

  @doc "The 50 normalized soul definitions (anchors + archetypes)."
  def definitions do
    @archetypes
    |> Enum.map(fn {name, archetype, values, speech} ->
      %{
        name: name,
        slug: slugify(name),
        archetype: archetype,
        core_values: values,
        speech_style: speech
      }
    end)
    |> then(fn archetypes ->
      Enum.map(@anchors, &Map.put_new(&1, :__anchor, true)) ++ archetypes
    end)
  end

  @doc """
  Seeds all 50 founding souls into the world, idempotently. Returns `{:ok, count}`.
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

  defp find_or_create_character(%{name: name, slug: slug}) do
    case Characters.get_character_by_slug(slug) do
      nil ->
        {:ok, char} =
          Characters.create_character(%{
            name: name,
            slug: slug,
            kind: "npc",
            status: "active",
            description: "A founding soul of the Soul Society."
          })

        char

      char ->
        char
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
          baseline_emotions: derive_emotions(defn.name),
          attachment_style: "secure"
        })

      _existing ->
        :ok
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
