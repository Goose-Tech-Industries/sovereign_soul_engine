defmodule SovereignSoulEngine.World.Lorebook do
  @moduledoc """
  Deterministic Dynamic Lorebook & World Info Engine (SillyTavern pattern).

  Selectively scans conversation history, player messages, and scene context
  for trigger keywords, regex patterns, and district locations, injecting only
  relevant world lore into the LLM context.

  Prevents static prompt bloat by keeping context lean (0 tokens overhead by default)
  while ensuring NPCs can speak accurately about regional history, Celtic folklore,
  factions, and city districts whenever mentioned.
  """

  alias SovereignSoulEngine.World.TownMap
  alias SovereignSoulEngine.World.LorebookEntry
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  @table_name :sse_custom_lorebook_entries

  defstruct [
    :slug,
    :title,
    :keys,
    :secondary_keys,
    :category,
    :priority,
    :content,
    :metadata
  ]

  @type t :: %__MODULE__{
          slug: String.t(),
          title: String.t(),
          keys: [String.t()],
          secondary_keys: [String.t()],
          category: atom(),
          priority: integer(),
          content: String.t(),
          metadata: map()
        }

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc """
  Scans conversation messages, recent dialogue, or raw text for lore triggers.
  Returns up to `max_entries` matched and prioritized lore entries.

  Options:
    - `:max_entries` — maximum entries to activate (default: 3)
    - `:scan_depth` — number of recent messages to inspect (default: 6)
    - `:current_district` — slug of the current district (grants high relevance boost)
    - `:extra_text` — additional scene context or environment description to scan
  """
  @spec scan_and_activate(String.t() | [map()], keyword()) :: [t()]
  def scan_and_activate(input, opts \\ []) do
    text = extract_searchable_text(input, opts)
    current_district = Keyword.get(opts, :current_district)
    max_entries = Keyword.get(opts, :max_entries, 3)

    all_entries = list_entries()

    all_entries
    |> Enum.map(fn entry ->
      case match_entry(entry, text, current_district) do
        {:match, score} -> {entry, score}
        :nomatch -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_entry, score} -> score end, :desc)
    |> Enum.take(max_entries)
    |> Enum.map(fn {entry, _score} -> entry end)
  end

  @doc """
  Formats matched lorebook entries into an LLM prompt block.
  Returns an empty string if no entries are active.
  """
  @spec prompt_directive([t()]) :: String.t()
  def prompt_directive([]), do: ""

  def prompt_directive(entries) when is_list(entries) do
    rendered_entries =
      entries
      |> Enum.map(fn entry ->
        "- [#{entry.title}]: #{entry.content}"
      end)
      |> Enum.join("\n")

    """
    LOREBOOK (WORLD CONTEXT):
    The following canonical world knowledge is relevant to the active scene and dialogue. Weave this context naturally into your thoughts and speech:
    #{rendered_entries}
    """
  end

  @doc """
  Lists all available lorebook entries (canonical town lore + registered custom entries).
  """
  @spec list_entries() :: [t()]
  def list_entries do
    canonical = canonical_entries()
    custom = list_custom_entries()

    # Custom entries with identical slugs overwrite canonical defaults
    custom_map = Map.new(custom, &{&1.slug, &1})
    canonical_filtered = Enum.reject(canonical, &Map.has_key?(custom_map, &1.slug))

    canonical_filtered ++ custom
  end

  @doc """
  Retrieves a lorebook entry by its slug.
  """
  @spec get_entry(String.t()) :: t() | nil
  def get_entry(slug) when is_binary(slug) do
    list_entries() |> Enum.find(&(&1.slug == slug))
  end

  @doc """
  Registers a custom lore entry at runtime (persisted in ETS).
  """
  @spec register_entry(map() | t()) :: {:ok, t()}
  def register_entry(attrs) do
    ensure_table_exists()

    entry =
      case attrs do
        %__MODULE__{} = e -> e
        %{} = m -> struct(__MODULE__, normalize_attrs(m))
      end

    scope = Map.get(entry.metadata || %{}, :scope, "global")

    case Repo.get_by(LorebookEntry, scope: scope, slug: entry.slug) do
      nil ->
        with {:ok, _stored} <-
               Repo.insert(LorebookEntry.changeset(%LorebookEntry{}, to_db_attrs(entry, scope))) do
          :ets.insert(@table_name, {entry.slug, entry})
          {:ok, entry}
        end

      existing ->
        with {:ok, _stored} <-
               Repo.update(LorebookEntry.changeset(existing, to_db_attrs(entry, scope))) do
          :ets.insert(@table_name, {entry.slug, entry})
          {:ok, entry}
        end
    end
  end

  @doc """
  Deletes a custom lore entry by slug.
  """
  @spec delete_custom_entry(String.t()) :: :ok
  def delete_custom_entry(slug) when is_binary(slug) do
    ensure_table_exists()
    Repo.delete_all(from e in LorebookEntry, where: e.slug == ^slug)
    :ets.delete(@table_name, slug)
    :ok
  end

  @doc """
  Clears all custom lore entries, resetting to canonical seeds.
  """
  @spec reset_custom_entries() :: :ok
  def reset_custom_entries do
    ensure_table_exists()
    Repo.delete_all(LorebookEntry)
    :ets.delete_all_objects(@table_name)
    :ok
  end

  # ── Canonical Seeds ────────────────────────────────────────────────────────

  @doc """
  Generates the canonical world lore entries derived from TownMap districts,
  Celtic folklore, and Twisted faction lore.
  """
  @spec canonical_entries() :: [t()]
  def canonical_entries do
    district_entries =
      Enum.map(TownMap.districts(), fn d ->
        spaced_slug = String.replace(d.slug, "_", " ")
        name_lower = String.downcase(d.name)
        gaelic_lower = String.downcase(d.gaelic_name)

        without_the = String.replace(name_lower, ~r/^the\s+/, "")
        name_parts = String.split(without_the, ~r/\s*(?:&|,|\band\b)\s*/, trim: true)

        amenities_keys = Enum.map(d.amenities || [], &String.downcase/1)
        amenities_without_the = Enum.map(amenities_keys, &String.replace(&1, ~r/^the\s+/, ""))

        primary_keys =
          [
            d.slug,
            spaced_slug,
            name_lower,
            without_the,
            gaelic_lower
          ] ++ name_parts ++ amenities_keys ++ amenities_without_the

        %__MODULE__{
          slug: d.slug,
          title: "#{d.name} (#{d.gaelic_name})",
          keys: Enum.uniq(primary_keys) |> Enum.reject(&(&1 == "")),
          secondary_keys: [],
          category: :location,
          priority: 60,
          content: "#{d.lore} Atmosphere: #{d.atmosphere}",
          metadata: %{
            district_slug: d.slug,
            danger_level: d.danger_level,
            zone_type: d.zone_type
          }
        }
      end)

    folklore_entries = [
      %__MODULE__{
        slug: "morrigan",
        title: "The Morrígan (Mistress of Fate & Battle)",
        keys: ["morrigan", "morrígan", "goddess of fate", "crow goddess", "cill na feannaige"],
        secondary_keys: [],
        category: :deity,
        priority: 75,
        content:
          "Sovereign mistress of destiny, omen, and crows. Ancient Gaelic goddess worshipped across Gleann Caorach. Her high needle-spire in High Sanctuary resonates whenever death or profound supernatural disturbance touches the valley.",
        metadata: %{pantheon: "celtic_gothic"}
      },
      %__MODULE__{
        slug: "celtic_anam",
        title: "Anam Binding (The Soul-Bond)",
        keys: ["anam", "anam binding", "soul-bond", "soul bond", "companion fusion"],
        secondary_keys: [],
        category: :magic,
        priority: 80,
        content:
          "The ancient Celtic ritual of bonding two sovereign souls together. Formed through hard-earned trust, sacrifice, and resonant emotional baselines, an Anam bond grants shared vitality, telepathic emotional perception, and mutual defense.",
        metadata: %{tradition: "druidic"}
      },
      %__MODULE__{
        slug: "sovereign_guard",
        title: "The Sovereign High Guard",
        keys: ["sovereign guard", "high king's guard", "obsidian sentinel", "palace sentry"],
        secondary_keys: [],
        category: :faction,
        priority: 70,
        content:
          "The heavily armored sentinels sworn to the Obsidian Throne. Wielding twin-handed iron polearms etched with protective Gaelic runes, they patrol the High Palace and Crow's Keep, brooking no insurrection.",
        metadata: %{loyalty: "crown"}
      },
      %__MODULE__{
        slug: "shadowgate_syndicate",
        title: "The Red Hand & Shadowgate Smugglers",
        keys: ["red hand", "shadowgate syndicate", "black docks", "sunken canals", "smugglers"],
        secondary_keys: [],
        category: :faction,
        priority: 70,
        content:
          "The illicit underworld syndicate controlling contraband, black lotus trade, and subterranean passages through the Sunken Undercity. They operate behind the facade of fishmongers and dock hands.",
        metadata: %{loyalty: "outlaw"}
      },
      %__MODULE__{
        slug: "gleann_caorach",
        title: "Gleann Caorach (The Highland Vale)",
        keys: ["gleann caorach", "caorach", "the valley", "highland vale"],
        secondary_keys: [],
        category: :history,
        priority: 50,
        content:
          "The mist-shrouded valley bounded by black crags and seven centuries of bloodfeud. Home to Feannag's Rest, ancient burial cairns, and hidden dwarven iron mines.",
        metadata: %{realm: "highland"}
      }
    ]

    district_entries ++ folklore_entries
  end

  # ── Internal Helpers ───────────────────────────────────────────────────────

  defp match_entry(%__MODULE__{} = entry, text, current_district) do
    # 1. Match primary keys
    matched_primary =
      Enum.filter(entry.keys, fn key ->
        key_clean = String.downcase(key)
        String.contains?(text, key_clean)
      end)

    # 2. Match secondary keys (if entry requires them)
    secondary_ok? =
      case entry.secondary_keys do
        [] -> true
        nil -> true
        secs -> Enum.any?(secs, &String.contains?(text, String.downcase(&1)))
      end

    is_current =
      is_binary(current_district) and
        (current_district == entry.slug or
           current_district == Map.get(entry.metadata || %{}, :district_slug))

    if (matched_primary != [] or is_current) and secondary_ok? do
      base_score = entry.priority || 50
      key_boost = length(matched_primary) * 10
      district_boost = if is_current, do: 50, else: 0
      {:match, base_score + key_boost + district_boost}
    else
      :nomatch
    end
  end

  defp extract_searchable_text(input, opts) do
    depth = Keyword.get(opts, :scan_depth, 6)
    extra = Keyword.get(opts, :extra_text, "")

    dialogue_text =
      case input do
        text when is_binary(text) ->
          text

        messages when is_list(messages) ->
          messages
          |> Enum.take(-depth)
          |> Enum.map_join(" ", fn
            %{content: content} -> to_string(content)
            %{"content" => content} -> to_string(content)
            other -> to_string(other)
          end)

        _ ->
          ""
      end

    String.downcase("#{dialogue_text} #{extra}")
  end

  defp ensure_table_exists do
    case :ets.info(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])

      _ ->
        :ok
    end
  rescue
    _ -> :ok
  end

  defp list_custom_entries do
    ensure_table_exists()

    persisted =
      Repo.all(from e in LorebookEntry, where: e.enabled == true and e.scope == "global")
      |> Enum.map(&from_db_entry/1)

    Enum.uniq_by(
      persisted ++ Enum.map(:ets.tab2list(@table_name), fn {_slug, entry} -> entry end),
      & &1.slug
    )
  rescue
    _ -> []
  end

  defp to_db_attrs(entry, scope) do
    %{
      scope: scope,
      slug: entry.slug,
      title: entry.title,
      keys: entry.keys || [],
      secondary_keys: entry.secondary_keys || [],
      category: to_string(entry.category || :lore),
      priority: entry.priority || 50,
      content: entry.content,
      metadata: entry.metadata || %{},
      enabled: true
    }
  end

  defp from_db_entry(%LorebookEntry{} = entry) do
    %__MODULE__{
      slug: entry.slug,
      title: entry.title,
      keys: entry.keys,
      secondary_keys: entry.secondary_keys,
      category: to_atom(entry.category),
      priority: entry.priority,
      content: entry.content,
      metadata: entry.metadata
    }
  end

  defp normalize_attrs(attrs) do
    %{
      slug: to_string(attrs[:slug] || attrs["slug"]),
      title: to_string(attrs[:title] || attrs["title"]),
      keys: (attrs[:keys] || attrs["keys"] || []) |> Enum.map(&to_string/1),
      secondary_keys:
        (attrs[:secondary_keys] || attrs["secondary_keys"] || []) |> Enum.map(&to_string/1),
      category: (attrs[:category] || attrs["category"] || :lore) |> to_atom(),
      priority: attrs[:priority] || attrs["priority"] || 50,
      content: to_string(attrs[:content] || attrs["content"]),
      metadata: attrs[:metadata] || attrs["metadata"] || %{}
    }
  end

  defp to_atom(a) when is_atom(a), do: a
  defp to_atom(b) when is_binary(b), do: String.to_atom(b)
end
