defmodule SovereignSoulEngineWeb.MapLive do
  @moduledoc """
  Interactive Living Town Map of Feannag's Rest (Gleann Caorach).

  Combines:
  - 13 Celtic/Gothic dark-fantasy districts meeting Elder Scrolls Imperial City & Baldur's Gate lore.
  - Full player walkability: Keyboard (WASD / Arrows), touch virtual D-Pad, and click-to-walk.
  - Dynamic visual player token with pulsating radar beacon.
  - Active walkable road radiance highlighting paths from current position.
  - Proximity encounters with ambient greeting dialogue (zero compute / $0 cost) and direct chat.
  - Live spatial distribution & roaming for the 50 souls.
  - 1:1 Twisted Paradox tile compatibility (`region:1:tile:X:Y`).
  - Interactive District Inspector with lore, present souls, secrets, and AI District Expansion.
  """

  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.World.TownMap

  @road_connections [
    # Royal Radial Boulevards (High Sovereign Palace spokes)
    {"high_palace", "crows_keep"},
    {"high_palace", "high_sanctuary"},
    {"high_palace", "raven_docks"},
    {"high_palace", "old_ironworks"},
    {"high_palace", "kings_plaza"},
    {"high_palace", "sunken_undercity"},
    {"high_palace", "south_bastion"},
    {"high_palace", "shadowgate_warrens"},
    {"high_palace", "night_owl_quarter"},
    {"high_palace", "barrowgrounds"},
    {"high_palace", "weavers_commons"},
    {"high_palace", "north_outpost"},
    # Outer Ring Road (encircling the 12 districts)
    {"north_outpost", "crows_keep"},
    {"crows_keep", "high_sanctuary"},
    {"high_sanctuary", "raven_docks"},
    {"raven_docks", "old_ironworks"},
    {"old_ironworks", "kings_plaza"},
    {"kings_plaza", "sunken_undercity"},
    {"sunken_undercity", "south_bastion"},
    {"south_bastion", "shadowgate_warrens"},
    {"shadowgate_warrens", "night_owl_quarter"},
    {"night_owl_quarter", "barrowgrounds"},
    {"barrowgrounds", "weavers_commons"},
    {"weavers_commons", "north_outpost"}
  ]

  # Directional transitions graph for Euclidean step walking
  @movement_graph %{
    "high_palace" => %{
      north: "crows_keep",
      south: "south_bastion",
      east: "old_ironworks",
      west: "barrowgrounds"
    },
    "crows_keep" => %{
      north: "north_outpost",
      south: "high_palace",
      east: "high_sanctuary",
      west: "north_outpost"
    },
    "high_sanctuary" => %{
      north: "crows_keep",
      south: "high_palace",
      east: "raven_docks",
      west: "crows_keep"
    },
    "raven_docks" => %{
      north: "high_sanctuary",
      south: "old_ironworks",
      east: "old_ironworks",
      west: "high_palace"
    },
    "old_ironworks" => %{
      north: "raven_docks",
      south: "kings_plaza",
      east: "kings_plaza",
      west: "high_palace"
    },
    "kings_plaza" => %{
      north: "old_ironworks",
      south: "sunken_undercity",
      east: "old_ironworks",
      west: "high_palace"
    },
    "sunken_undercity" => %{
      north: "high_palace",
      south: "south_bastion",
      east: "kings_plaza",
      west: "south_bastion"
    },
    "south_bastion" => %{
      north: "high_palace",
      south: "high_palace",
      east: "sunken_undercity",
      west: "shadowgate_warrens"
    },
    "shadowgate_warrens" => %{
      north: "high_palace",
      south: "south_bastion",
      east: "south_bastion",
      west: "night_owl_quarter"
    },
    "night_owl_quarter" => %{
      north: "barrowgrounds",
      south: "shadowgate_warrens",
      east: "high_palace",
      west: "barrowgrounds"
    },
    "barrowgrounds" => %{
      north: "weavers_commons",
      south: "night_owl_quarter",
      east: "high_palace",
      west: "night_owl_quarter"
    },
    "weavers_commons" => %{
      north: "north_outpost",
      south: "barrowgrounds",
      east: "high_palace",
      west: "barrowgrounds"
    },
    "north_outpost" => %{
      north: "crows_keep",
      south: "high_palace",
      east: "crows_keep",
      west: "weavers_commons"
    }
  }

  @grid_cols 28
  @grid_rows 24

  @npc_locations [
    %{
      slug: "fia",
      name: "Fia",
      icon: "🪶",
      title: "Empathetic Weaver",
      x: 14,
      y: 9,
      district: "high_palace",
      quote: "I feel the living pulse of every soul in Gleann Caorach."
    },
    %{
      slug: "cipher",
      name: "Cipher",
      icon: "⚡",
      title: "Systems Architect",
      x: 23,
      y: 19,
      district: "old_ironworks",
      quote: "Air-gapped telemetry, local CUDA inference, zero data leakage."
    },
    %{
      slug: "quill",
      name: "Quill",
      icon: "📜",
      title: "Iron Chronicler",
      x: 13,
      y: 4,
      district: "crows_keep",
      quote: "Seven centuries of clan treaties are inked in these archives."
    },
    %{
      slug: "dove",
      name: "Dove",
      icon: "🕊️",
      title: "Sanctuary Priestess",
      x: 22,
      y: 4,
      district: "high_sanctuary",
      quote: "The Morrígan watches over those who walk with purpose."
    },
    %{
      slug: "kael",
      name: "Kael",
      icon: "⚓",
      title: "Docks Harbormaster",
      x: 24,
      y: 12,
      district: "raven_docks",
      quote: "The Blackwater river remembers what the high lords try to forget."
    },
    %{
      slug: "egon",
      name: "Egon",
      icon: "🛡️",
      title: "Market Sentinel",
      x: 14,
      y: 18,
      district: "kings_plaza",
      quote: "Keep your blades sheathed in the market square, traveler."
    },
    %{
      slug: "ravina",
      name: "Ravina",
      icon: "🗝️",
      title: "Shadow Broker",
      x: 5,
      y: 18,
      district: "shadowgate_warrens",
      quote: "Keep your voice low. Everything in these wynds belongs to someone else."
    },
    %{
      slug: "vael",
      name: "Vael",
      icon: "🕯️",
      title: "Barrow Watcher",
      x: 4,
      y: 13,
      district: "barrowgrounds",
      quote: "Walk lightly upon the cairns, traveler."
    },
    %{
      slug: "lyra",
      name: "Lyra",
      icon: "🧶",
      title: "Guild Weaver",
      x: 5,
      y: 4,
      district: "weavers_commons",
      quote: "Every thread tells a story if you know how to read the weave."
    },
    %{
      slug: "corvus",
      name: "Corvus",
      icon: "🦅",
      title: "Bastion Commander",
      x: 14,
      y: 22,
      district: "south_bastion",
      quote: "The south wall holds against all wild highland incursions."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "town:map")
    end

    map_data = TownMap.get_map()
    initial_district_slug = "high_palace"

    selected_district =
      TownMap.get_district(initial_district_slug) || TownMap.get_district("kings_plaza")

    initial_x = 14
    initial_y = 8
    nearby = find_nearby_npc(initial_x, initial_y)

    socket =
      socket
      |> assign(:page_title, "Feannag's Rest — Walkable Living Map")
      |> assign(:town_name, map_data.town_name)
      |> assign(:region_name, map_data.region_name)
      |> assign(:districts, map_data.districts)
      |> assign(:total_souls, map_data.total_souls)
      |> assign(:player_district, initial_district_slug)
      |> assign(:visited_districts, MapSet.new([initial_district_slug]))
      |> assign(:travel_step_count, 0)
      |> assign(:last_direction, nil)
      |> assign(:show_arrival_banner, true)
      |> assign(:ambient_dialogue, nil)
      |> assign(:ai_input_focused?, false)
      |> assign(
        :selected_slug,
        if(selected_district, do: selected_district.slug, else: initial_district_slug)
      )
      |> assign(:selected_district, selected_district)
      |> assign(:ai_prompt, "")
      |> assign(:is_generating_ai?, false)
      |> assign(:road_connections, @road_connections)
      |> assign(:view_mode, "rpg")
      |> assign(:player_x, initial_x)
      |> assign(:player_y, initial_y)
      |> assign(:player_facing, :south)
      |> assign(:npc_locations, @npc_locations)
      |> assign(:nearby_npc, nearby)
      |> assign(:grid_cols, @grid_cols)
      |> assign(:grid_rows, @grid_rows)
      |> assign(:tile_size, 30)
      |> assign(:grid_tiles, generate_world_grid())

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"district" => slug}, _uri, socket) do
    case TownMap.get_district(slug) do
      nil ->
        {:noreply, socket}

      district ->
        {:noreply,
         socket
         |> assign(:selected_slug, slug)
         |> assign(:selected_district, district)}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # --- Movement & Walking Events ----------------------------------------------

  @impl true
  def handle_event("walk_to_district", %{"slug" => slug}, socket) do
    {:noreply, do_walk_to_district(socket, slug)}
  end

  @impl true
  def handle_event("select_district", %{"slug" => slug}, socket) do
    # In the walkable map, selecting a district on the canvas walks the player there
    # while also selecting it in the inspector
    {:noreply, do_walk_to_district(socket, slug)}
  end

  @impl true
  def handle_event("toggle_view_mode", _params, socket) do
    new_mode = if socket.assigns.view_mode == "rpg", do: "radar", else: "rpg"
    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  @impl true
  def handle_event("set_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  @impl true
  def handle_event("set_tile_size", %{"size" => size_str}, socket) do
    size =
      case Integer.parse(to_string(size_str)) do
        {val, _} when val in 18..54 -> val
        _ -> 30
      end

    {:noreply, assign(socket, :tile_size, size)}
  end

  @impl true
  def handle_event("walk_tile", %{"x" => x_val, "y" => y_val}, socket) do
    x = if is_binary(x_val), do: String.to_integer(x_val), else: x_val
    y = if is_binary(y_val), do: String.to_integer(y_val), else: y_val

    if is_walkable_tile?(x, y) do
      target_district = district_for_tile(x, y)
      new_visited = MapSet.put(socket.assigns.visited_districts, target_district)
      new_step_count = socket.assigns.travel_step_count + 1
      district_changed? = target_district != socket.assigns.player_district

      selected =
        if district_changed?,
          do: TownMap.get_district(target_district),
          else: socket.assigns.selected_district

      socket =
        socket
        |> assign(:player_x, x)
        |> assign(:player_y, y)
        |> assign(:travel_step_count, new_step_count)
        |> assign(:visited_districts, new_visited)
        |> assign(:nearby_npc, find_nearby_npc(x, y))
        |> assign(:player_district, target_district)
        |> assign(:selected_slug, target_district)
        |> assign(:selected_district, selected)
        |> assign(:show_arrival_banner, district_changed?)

      {:noreply, socket}
    else
      {:noreply,
       put_flash(socket, :error, "That path is blocked by city battlements or deep waters.")}
    end
  end

  @impl true
  def handle_event("step_direction", %{"direction" => dir}, socket) do
    {dx, dy, facing} =
      case dir do
        "north" -> {0, -1, :north}
        "south" -> {0, 1, :south}
        "east" -> {1, 0, :east}
        "west" -> {-1, 0, :west}
        "up_left" -> {-1, -1, :north}
        "up_right" -> {1, -1, :north}
        "down_left" -> {-1, 1, :south}
        "down_right" -> {1, 1, :south}
        _ -> {0, 0, :south}
      end

    new_x = max(0, min(@grid_cols - 1, socket.assigns.player_x + dx))
    new_y = max(0, min(@grid_rows - 1, socket.assigns.player_y + dy))

    socket = assign(socket, :player_facing, facing)
    handle_event("walk_tile", %{"x" => new_x, "y" => new_y}, socket)
  end

  @impl true
  def handle_event("interact_nearby", _params, socket) do
    case socket.assigns.nearby_npc do
      nil ->
        {:noreply, socket}

      npc ->
        handle_event("hail_soul", %{"name" => npc.name, "slug" => npc.slug}, socket)
    end
  end

  @impl true
  def handle_event("walk_direction", %{"direction" => direction_str}, socket) do
    current = socket.assigns.player_district

    dir_atom =
      case direction_str do
        "north" -> :north
        "south" -> :south
        "east" -> :east
        "west" -> :west
        _ -> :north
      end

    target_slug =
      if direction_str == "palace" do
        "high_palace"
      else
        get_in(@movement_graph, [current, dir_atom]) || "high_palace"
      end

    socket =
      socket
      |> assign(:last_direction, dir_atom)
      |> do_walk_to_district(target_slug)

    {:noreply, socket}
  end

  @impl true
  def handle_event("handle_keydown", %{"key" => key}, socket) do
    # Skip if user is typing in the AI prompt input box
    if socket.assigns.ai_input_focused? do
      {:noreply, socket}
    else
      normalized_key = String.downcase(key)

      cond do
        normalized_key in ["w", "arrowup"] ->
          handle_event("walk_direction", %{"direction" => "north"}, socket)

        normalized_key in ["s", "arrowdown"] ->
          handle_event("walk_direction", %{"direction" => "south"}, socket)

        normalized_key in ["a", "arrowleft"] ->
          handle_event("walk_direction", %{"direction" => "west"}, socket)

        normalized_key in ["d", "arrowright"] ->
          handle_event("walk_direction", %{"direction" => "east"}, socket)

        normalized_key in ["c", "home"] ->
          handle_event("walk_direction", %{"direction" => "palace"}, socket)

        normalized_key in ["e", "enter"] ->
          handle_event("interact_nearby", %{}, socket)

        normalized_key in ["m"] ->
          handle_event("toggle_view_mode", %{}, socket)

        true ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("focus_ai_input", _params, socket) do
    {:noreply, assign(socket, :ai_input_focused?, true)}
  end

  @impl true
  def handle_event("blur_ai_input", _params, socket) do
    {:noreply, assign(socket, :ai_input_focused?, false)}
  end

  @impl true
  def handle_event("dismiss_arrival_banner", _params, socket) do
    {:noreply, assign(socket, :show_arrival_banner, false)}
  end

  @impl true
  def handle_event("dismiss_ambient_dialogue", _params, socket) do
    {:noreply, assign(socket, :ambient_dialogue, nil)}
  end

  @impl true
  def handle_event("hail_soul", %{"name" => name, "slug" => slug}, socket) do
    cur_district = socket.assigns.player_district
    district_data = TownMap.get_district(cur_district)
    district_name = if district_data, do: district_data.name, else: "the district"

    quote_text = generate_ambient_greeting(slug, name, cur_district, district_name)

    dialogue = %{
      name: name,
      slug: slug,
      district: district_name,
      quote: quote_text,
      timestamp: "Just now"
    }

    {:noreply, assign(socket, :ambient_dialogue, dialogue)}
  end

  # --- Simulation & AI Events -------------------------------------------------

  @impl true
  def handle_event("simulate_roam", _params, socket) do
    {:ok, count} = TownMap.simulate_roaming()
    map_data = TownMap.get_map()
    selected = TownMap.get_district(socket.assigns.selected_slug)

    socket =
      socket
      |> assign(:districts, map_data.districts)
      |> assign(:selected_district, selected)
      |> put_flash(
        :info,
        "Highland gale blew through Feannag's Rest: #{count} souls roamed to new districts!"
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_ai_prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, :ai_prompt, prompt)}
  end

  @impl true
  def handle_event("expand_with_ai", %{"prompt" => prompt}, socket) do
    slug = socket.assigns.selected_slug
    socket = assign(socket, :is_generating_ai?, true)

    case TownMap.expand_district_with_ai(slug, prompt) do
      {:ok, expansion} ->
        map_data = TownMap.get_map()
        selected = TownMap.get_district(slug)

        socket =
          socket
          |> assign(:is_generating_ai?, false)
          |> assign(:ai_prompt, "")
          |> assign(:districts, map_data.districts)
          |> assign(:selected_district, selected)
          |> put_flash(:info, "AI Architect discovered: #{expansion.title} in #{selected.name}!")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:is_generating_ai?, false)
          |> put_flash(:error, "Failed to expand district: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # --- PubSub Broadcasts ------------------------------------------------------

  @impl true
  def handle_info({:soul_moved, _char_id, _from, _to}, socket) do
    map_data = TownMap.get_map()
    selected = TownMap.get_district(socket.assigns.selected_slug)

    {:noreply,
     socket
     |> assign(:districts, map_data.districts)
     |> assign(:selected_district, selected)}
  end

  @impl true
  def handle_info({:district_expanded, _slug, _expansion}, socket) do
    map_data = TownMap.get_map()
    selected = TownMap.get_district(socket.assigns.selected_slug)

    {:noreply,
     socket
     |> assign(:districts, map_data.districts)
     |> assign(:selected_district, selected)}
  end

  # --- Internal Helpers -------------------------------------------------------

  defp do_walk_to_district(socket, target_slug) do
    case TownMap.get_district(target_slug) do
      nil ->
        socket

      district ->
        new_visited = MapSet.put(socket.assigns.visited_districts, target_slug)
        new_step_count = socket.assigns.travel_step_count + 1
        {new_x, new_y} = district_center_coords(target_slug)

        socket
        |> assign(:player_district, target_slug)
        |> assign(:selected_slug, target_slug)
        |> assign(:selected_district, district)
        |> assign(:visited_districts, new_visited)
        |> assign(:travel_step_count, new_step_count)
        |> assign(:player_x, new_x)
        |> assign(:player_y, new_y)
        |> assign(:nearby_npc, find_nearby_npc(new_x, new_y))
        |> assign(:show_arrival_banner, true)
        |> assign(:ambient_dialogue, nil)
    end
  end

  defp district_for_tile(x, y) do
    cond do
      x in 10..17 and y in 8..15 -> "high_palace"
      x in 10..17 and y in 0..7 -> "crows_keep"
      x in 18..27 and y in 0..7 -> "high_sanctuary"
      x in 0..9 and y in 0..7 -> "weavers_commons"
      x in 20..27 and y in 8..15 -> "raven_docks"
      x in 18..27 and y in 16..23 -> "old_ironworks"
      x in 10..17 and y in 16..19 -> "kings_plaza"
      x in 10..17 and y in 20..23 -> "south_bastion"
      x in 0..9 and y in 16..19 -> "shadowgate_warrens"
      x in 0..9 and y in 20..23 -> "sunken_undercity"
      x in 0..9 and y in 8..11 -> "night_owl_quarter"
      x in 0..9 and y in 12..15 -> "barrowgrounds"
      true -> "high_palace"
    end
  end

  defp terrain_for_tile(x, y) do
    cond do
      (x == 0 or x == 27 or y == 0 or y == 23) and
          not ((x == 14 and y in [0, 23]) or (y in [11, 12] and x in [0, 27])) ->
        :wall

      x in 25..27 and y in 9..17 and not (y in [11, 12] and x in 25..26) ->
        :water

      y in [11, 12] and x in 25..27 ->
        :wood_dock

      x in 10..17 and y in 8..15 ->
        :palace_floor

      x in [13, 14] or y in [11, 12] ->
        :cobblestone

      x in 10..17 and y in 0..7 ->
        :obsidian

      x in 18..27 and y in 0..7 ->
        :sanctuary_stone

      x in 18..27 and y in 16..23 ->
        :forge_iron

      x in 10..17 and y in 16..19 ->
        :market_cobble

      x in 0..9 and y in 16..19 ->
        :shadow_wynd

      x in 0..9 and y in 0..7 ->
        :green_commons

      true ->
        :stone_brick
    end
  end

  defp is_walkable_tile?(x, y) do
    terrain = terrain_for_tile(x, y)
    terrain not in [:wall, :water]
  end

  defp find_nearby_npc(px, py) do
    Enum.find(@npc_locations, fn npc ->
      abs(npc.x - px) <= 2 and abs(npc.y - py) <= 2
    end)
  end

  defp find_npc_at_tile(npcs, x, y) do
    Enum.find(npcs, fn npc -> npc.x == x and npc.y == y end)
  end

  defp is_nearby?(npc, px, py) do
    abs(npc.x - px) <= 2 and abs(npc.y - py) <= 2
  end

  defp district_center_coords("high_palace"), do: {14, 8}
  defp district_center_coords("crows_keep"), do: {14, 5}
  defp district_center_coords("high_sanctuary"), do: {22, 5}
  defp district_center_coords("raven_docks"), do: {24, 11}
  defp district_center_coords("old_ironworks"), do: {23, 19}
  defp district_center_coords("kings_plaza"), do: {14, 18}
  defp district_center_coords("south_bastion"), do: {14, 22}
  defp district_center_coords("shadowgate_warrens"), do: {5, 18}
  defp district_center_coords("sunken_undercity"), do: {5, 21}
  defp district_center_coords("night_owl_quarter"), do: {5, 10}
  defp district_center_coords("barrowgrounds"), do: {4, 13}
  defp district_center_coords("weavers_commons"), do: {5, 5}
  defp district_center_coords("north_outpost"), do: {11, 2}
  defp district_center_coords(_), do: {14, 8}

  defp generate_world_grid do
    for y <- 0..23, x <- 0..27 do
      %{
        x: x,
        y: y,
        district: district_for_tile(x, y),
        terrain: terrain_for_tile(x, y),
        walkable: is_walkable_tile?(x, y),
        tile_id: "region:1:tile:#{x}:#{y}"
      }
    end
  end

  defp terrain_class(:palace_floor),
    do:
      "bg-gradient-to-br from-amber-950/80 to-yellow-950/60 border border-amber-600/40 hover:border-amber-400 shadow-inner"

  defp terrain_class(:cobblestone),
    do: "bg-stone-800/90 border border-stone-700/50 hover:border-amber-400/80"

  defp terrain_class(:stone_brick),
    do: "bg-stone-900/90 border border-stone-800/60 hover:border-amber-400/60"

  defp terrain_class(:obsidian),
    do: "bg-zinc-950 border border-red-900/50 hover:border-red-400/60"

  defp terrain_class(:sanctuary_stone),
    do: "bg-indigo-950/80 border border-indigo-700/50 hover:border-cyan-400/60"

  defp terrain_class(:forge_iron),
    do: "bg-stone-950 border border-amber-800/50 hover:border-orange-500/60"

  defp terrain_class(:market_cobble),
    do: "bg-stone-900 border border-emerald-800/50 hover:border-emerald-400/60"

  defp terrain_class(:shadow_wynd),
    do: "bg-purple-950/70 border border-purple-900/50 hover:border-purple-400/60"

  defp terrain_class(:green_commons),
    do: "bg-emerald-950/70 border border-emerald-800/50 hover:border-emerald-400/60"

  defp terrain_class(:wood_dock),
    do: "bg-amber-950/90 border border-amber-800/50 hover:border-yellow-500/60"

  defp terrain_class(:water),
    do: "bg-cyan-950/90 border border-cyan-800/50 opacity-60 cursor-not-allowed"

  defp terrain_class(:wall),
    do: "bg-zinc-900 border border-zinc-700/80 opacity-75 cursor-not-allowed"

  defp terrain_class(_), do: "bg-stone-900/80 border border-stone-800/40"

  # Zero-compute ambient in-character greeting generator (< 1ms, $0 cost)
  defp generate_ambient_greeting(slug, name, district_slug, district_name) do
    clean_slug = String.downcase(to_string(slug || ""))
    clean_name = String.downcase(to_string(name || ""))

    cond do
      String.contains?(clean_slug, "corvus") or String.contains?(clean_name, "corvus") ->
        if district_slug == "south_bastion" do
          "\"Ramparts are secure. Keep your broadsword sharp, traveler; the wild clans test our perimeter after dusk.\""
        else
          "\"Eyes open, traveler. In Feannag's Rest, a sheath is only as good as the steel inside it.\""
        end

      String.contains?(clean_slug, "maya") or String.contains?(clean_name, "maya") ->
        if district_slug == "old_ironworks" do
          "\"Step back from the blast furnace! That star-steel quench took three days to balance, don't kick slag into it.\""
        else
          "\"The smell of forge sulfur clings to me, but cold iron never lies. Need an edge honed?\""
        end

      String.contains?(clean_slug, "valeria") or String.contains?(clean_name, "valeria") ->
        if district_slug == "high_sanctuary" do
          "\"The star-metal needle hums above the cathedral. The Morrígan senses a stranger's footsteps.\""
        else
          "\"The ley-lines beneath our boots run deep. Do not mistake the city's quiet for peace.\""
        end

      String.contains?(clean_slug, "ravina") or String.contains?(clean_name, "ravina") ->
        if district_slug == "shadowgate_warrens" do
          "\"Keep your voice low and your hands inside your cloak. Everything in these wynds belongs to someone else.\""
        else
          "\"Looking for something that fell off the city manifests? Meet me when the lanterns turn green.\""
        end

      String.contains?(clean_slug, "soren") or String.contains?(clean_name, "soren") ->
        if district_slug == "crows_keep" do
          "\"Seven centuries of clan treaties are inked in these archives. Half of them sealed in blood.\""
        else
          "\"History repeats itself in Gleann Caorach. Usually the chapters involving siege and betrayal.\""
        end

      String.contains?(clean_slug, "quill") or String.contains?(clean_name, "quill") ->
        if district_slug == "night_owl_quarter" do
          "\"Pull up a bench! A flagon of heather mead and three good verses—that's all you need to defy the dark.\""
        else
          "\"Did you hear the criers? The High Council sealed the palace gates at dawn. Something stirred in the hills.\""
        end

      String.contains?(clean_slug, "cyra") or String.contains?(clean_name, "cyra") ->
        if district_slug == "raven_docks" do
          "\"River fog is thick enough to choke on. Unregistered cargo slips into port every time the beacon flickers.\""
        else
          "\"The Blackwater river remembers what the high lords try to forget.\""
        end

      String.contains?(clean_slug, "vael") or String.contains?(clean_name, "vael") ->
        if district_slug == "barrowgrounds" do
          "\"Walk lightly upon the cairns, traveler. The ancient highland kings do not appreciate hurried footsteps.\""
        else
          "\"Even in daylight, the veil between worlds is paper-thin here.\""
        end

      true ->
        "\"Safe travels through #{district_name}, wanderer. May the ravens guard your back.\""
    end
  end

  # --- SVG Coordinates & Helpers ----------------------------------------------

  # Center Sovereign Citadel
  defp node_coords("high_palace"), do: {500, 390}

  # Concentric Circle of 12 Surrounding Districts (Clockwise from 12 o'clock)
  defp node_coords("crows_keep"), do: {500, 110}
  defp node_coords("high_sanctuary"), do: {640, 150}
  defp node_coords("raven_docks"), do: {750, 250}
  defp node_coords("old_ironworks"), do: {780, 390}
  defp node_coords("kings_plaza"), do: {750, 530}
  defp node_coords("sunken_undercity"), do: {640, 630}
  defp node_coords("south_bastion"), do: {500, 670}
  defp node_coords("shadowgate_warrens"), do: {360, 630}
  defp node_coords("night_owl_quarter"), do: {250, 530}
  defp node_coords("barrowgrounds"), do: {220, 390}
  defp node_coords("weavers_commons"), do: {250, 250}
  defp node_coords("north_outpost"), do: {360, 150}
  defp node_coords(_), do: {500, 390}

  defp is_connected_to_player?(slug1, slug2, player_slug) do
    slug1 == player_slug or slug2 == player_slug
  end

  defp zone_color(:palace), do: "#fbbf24"
  defp zone_color(:citadel), do: "#f59e0b"
  defp zone_color(:sacred), do: "#06b6d4"
  defp zone_color(:market), do: "#10b981"
  defp zone_color(:forge), do: "#f97316"
  defp zone_color(:harbor), do: "#38bdf8"
  defp zone_color(:underworld), do: "#8b5cf6"
  defp zone_color(:bastion), do: "#ef4444"
  defp zone_color(:barrow), do: "#a855f7"
  defp zone_color(:tavern), do: "#eab308"
  defp zone_color(:artisan), do: "#84cc16"
  defp zone_color(:undercity), do: "#14b8a6"
  defp zone_color(:outpost), do: "#64748b"
  defp zone_color(_), do: "#94a3b8"

  defp district_monogram("high_palace"), do: "👑"
  defp district_monogram("crows_keep"), do: "CRW"
  defp district_monogram("high_sanctuary"), do: "SAN"
  defp district_monogram("kings_plaza"), do: "MRK"
  defp district_monogram("old_ironworks"), do: "IRN"
  defp district_monogram("raven_docks"), do: "DCK"
  defp district_monogram("shadowgate_warrens"), do: "SHD"
  defp district_monogram("south_bastion"), do: "BST"
  defp district_monogram("barrowgrounds"), do: "BRW"
  defp district_monogram("night_owl_quarter"), do: "OWL"
  defp district_monogram("weavers_commons"), do: "WVR"
  defp district_monogram("sunken_undercity"), do: "SNK"
  defp district_monogram("north_outpost"), do: "NTH"
  defp district_monogram(slug), do: String.slice(slug, 0, 3) |> String.upcase()

  defp danger_badge_class(danger) when danger >= 7, do: "badge-error"
  defp danger_badge_class(danger) when danger >= 4, do: "badge-warning"
  defp danger_badge_class(_), do: "badge-success"

  # --- Template ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="map-viewport-container"
      phx-hook="MapControls"
      phx-window-keydown="handle_keydown"
      class="min-h-screen bg-[#030712] text-base-content flex flex-col font-sans select-none pb-20 lg:pb-0"
    >
      <%!-- Navigation Header --%>
      <header class="h-16 border-b border-base-800/80 bg-base-950/90 backdrop-blur-md px-4 sm:px-6 flex items-center justify-between sticky top-0 z-30">
        <div class="flex items-center gap-3 sm:gap-4">
          <.link
            navigate={~p"/sse/chat"}
            class="btn btn-ghost btn-xs text-base-content/60 hover:text-base-content flex items-center gap-1.5"
          >
            <.icon name="hero-arrow-left" class="size-4" />
            <span class="hidden sm:inline">Chat</span>
          </.link>

          <.link
            navigate={~p"/sse/feed"}
            class="btn btn-ghost btn-xs text-base-content/60 hover:text-base-content flex items-center gap-1.5"
          >
            <span>📰</span>
            <span class="hidden sm:inline">Feed</span>
          </.link>

          <div class="h-5 w-px bg-base-800" />

          <div>
            <h1 class="text-base font-extrabold tracking-tight text-white flex items-center gap-2">
              <span class="text-amber-500">🏰</span>
              <span>{@town_name}</span>
              <span class="text-xs font-normal text-base-content/50 font-serif italic">
                ({@region_name})
              </span>
            </h1>
            <p class="text-[11px] text-base-content/50 font-medium tracking-wide hidden sm:block">
              Walkable Dark Walled City • 13 Regions • WASD / Arrow Keys or Click-to-Travel
            </p>
          </div>
        </div>

        <%!-- Stats & Controls --%>
        <div class="flex items-center gap-2 sm:gap-3">
          <%!-- Exploration Gauge --%>
          <div class="flex items-center gap-2 px-2.5 py-1 rounded-lg bg-base-900/90 border border-base-800 text-xs">
            <span class="text-amber-400 font-bold">🧭</span>
            <span class="text-white font-mono font-bold">{MapSet.size(@visited_districts)}/13</span>
            <span class="text-base-content/50 hidden md:inline">Explored</span>
          </div>

          <div class="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-base-900/90 border border-base-800 text-xs">
            <span class="size-2 rounded-full bg-emerald-400 animate-pulse"></span>
            <span class="font-bold text-white">{@total_souls}</span>
            <span class="text-base-content/50">Souls</span>
          </div>

          <div class="hidden lg:flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-indigo-950/70 border border-indigo-700/50 text-indigo-300 text-xs font-mono">
            <span>Twisted Paradox 12x12</span>
          </div>

          <%!-- Mode Switcher: 2D Walkable RPG Grid vs Strategic Radar --%>
          <div class="join border border-base-700 bg-base-900/90 rounded-lg p-0.5 shadow-sm">
            <button
              phx-click="set_view_mode"
              phx-value-mode="rpg"
              class={[
                "btn btn-xs join-item font-semibold gap-1 transition-all",
                if(@view_mode == "rpg",
                  do: "btn-primary text-white shadow-sm",
                  else: "btn-ghost text-base-content/60 hover:text-white"
                )
              ]}
              title="2D Walkable RPG Map (Twisted Grid)"
            >
              <span>🎮</span>
              <span class="hidden sm:inline">2D RPG Map</span>
            </button>
            <button
              phx-click="set_view_mode"
              phx-value-mode="radar"
              class={[
                "btn btn-xs join-item font-semibold gap-1 transition-all",
                if(@view_mode == "radar",
                  do: "btn-primary text-white shadow-sm",
                  else: "btn-ghost text-base-content/60 hover:text-white"
                )
              ]}
              title="Strategic District Radar"
            >
              <span>🗺️</span>
              <span class="hidden sm:inline">Radar</span>
            </button>
          </div>

          <button
            phx-click="simulate_roam"
            class="btn btn-xs btn-outline border-amber-500/50 text-amber-400 hover:bg-amber-500/15 font-semibold flex items-center gap-1"
            title="Randomly roam souls along connected roads"
          >
            <.icon name="hero-arrows-right-left" class="size-3.5" />
            <span class="hidden sm:inline">Roam Souls</span>
          </button>
        </div>
      </header>

      <%!-- Flash Banners --%>
      <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
        <div
          id="flash-info"
          class="bg-amber-500/20 border-b border-amber-500/30 text-amber-300 text-xs py-2 px-6 font-medium flex items-center gap-2"
        >
          <.icon name="hero-sparkles" class="size-4 text-amber-400" />
          <span>{flash}</span>
        </div>
      <% end %>
      <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
        <div
          id="flash-error"
          class="bg-rose-500/20 border-b border-rose-500/30 text-rose-300 text-xs py-2 px-6 font-medium flex items-center gap-2"
        >
          <.icon name="hero-exclamation-triangle" class="size-4 text-rose-400" />
          <span>{flash}</span>
        </div>
      <% end %>

      <%!-- Main Layout: Map Canvas (Left 70%) + District Inspector (Right 30%) --%>
      <div class="flex-1 flex flex-col lg:flex-row overflow-hidden relative">
        <%!-- SVG Interactive Walkable Map Canvas --%>
        <div class="flex-1 relative bg-gradient-to-b from-[#050811] via-[#070b16] to-[#090e1d] overflow-hidden flex items-center justify-center p-2 sm:p-4">
          <%!-- Background Ambient Grid Pattern --%>
          <div class="absolute inset-0 opacity-5 pointer-events-none bg-[radial-gradient(#38bdf8_1px,transparent_1px)] [background-size:24px_24px]">
          </div>

          <%!-- Cinematic Arrival Banner (HUD Overlay Top) --%>
          <%= if @show_arrival_banner && @selected_district do %>
            <div
              id="arrival-banner"
              class="absolute top-4 left-4 right-4 sm:left-6 sm:right-auto sm:max-w-md z-20 bg-base-950/90 backdrop-blur-md border border-amber-500/40 rounded-2xl p-3.5 shadow-2xl animate-in fade-in slide-in-from-top-4 duration-300 flex items-start justify-between gap-3"
            >
              <div class="flex items-start gap-3">
                <div class="w-10 h-10 rounded-xl bg-amber-500/20 text-amber-400 border border-amber-500/40 flex items-center justify-center font-bold text-lg shrink-0">
                  {district_monogram(@player_district)}
                </div>
                <div>
                  <div class="flex items-center gap-2 flex-wrap">
                    <span class="text-xs font-bold text-white tracking-wide">
                      {@selected_district.name}
                    </span>
                    <span class="badge badge-xs badge-outline text-amber-400/80 font-serif italic text-[10px]">
                      {@selected_district.gaelic_name}
                    </span>
                    <span class={[
                      "badge badge-xs font-mono text-[9px] uppercase font-bold",
                      danger_badge_class(@selected_district.danger_level)
                    ]}>
                      Lvl {@selected_district.danger_level}
                    </span>
                  </div>
                  <p class="text-[11px] text-base-content/70 italic mt-0.5 line-clamp-1">
                    {@selected_district.atmosphere}
                  </p>
                  <div class="flex items-center gap-2 mt-1.5 text-[10px] text-cyan-400 font-mono">
                    <span>📍 Tile: {@selected_district.tile_id}</span>
                    <span>•</span>
                    <span>
                      👥 {@selected_district.soul_count || length(@selected_district.present_souls)} souls present
                    </span>
                  </div>
                </div>
              </div>

              <button
                phx-click="dismiss_arrival_banner"
                class="btn btn-ghost btn-circle btn-xs text-base-content/40 hover:text-white"
                title="Dismiss banner"
              >
                <.icon name="hero-x-mark" class="size-3.5" />
              </button>
            </div>
          <% end %>

          <%!-- Ambient Dialogue Speech Bubble (HUD Overlay) --%>
          <%= if @ambient_dialogue do %>
            <div
              id="ambient-speech-bubble"
              class="absolute top-24 left-4 right-4 sm:left-6 sm:max-w-md z-20 bg-indigo-950/95 backdrop-blur-md border border-indigo-500/50 rounded-2xl p-4 shadow-2xl animate-in zoom-in-95 duration-200"
            >
              <div class="flex items-start justify-between gap-2">
                <div class="flex items-center gap-2">
                  <div class="w-6 h-6 rounded-full bg-cyan-500/20 text-cyan-400 flex items-center justify-center font-bold text-xs border border-cyan-500/40">
                    💬
                  </div>
                  <span class="text-xs font-bold text-white">{@ambient_dialogue.name}</span>
                  <span class="text-[10px] text-indigo-300/60 font-mono">
                    ({@ambient_dialogue.district})
                  </span>
                </div>
                <button
                  phx-click="dismiss_ambient_dialogue"
                  class="text-base-content/40 hover:text-white text-xs"
                >
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
              <p class="text-xs text-indigo-100 italic mt-2 leading-relaxed bg-indigo-900/40 p-2.5 rounded-xl border border-indigo-800/40">
                {@ambient_dialogue.quote}
              </p>
              <div class="flex items-center justify-between mt-2 pt-2 border-t border-indigo-800/40 text-[10px]">
                <span class="text-indigo-300/50 font-mono">Ambient Local Voice</span>
                <.link
                  navigate={~p"/sse/chat?location=#{@ambient_dialogue.district}"}
                  class="text-teal-300 hover:text-teal-200 font-semibold flex items-center gap-1"
                >
                  <span>Continue in Private Chat</span>
                  <.icon name="hero-arrow-right" class="size-3" />
                </.link>
              </div>
            </div>
          <% end %>

          <%!-- Floating Virtual Compass D-Pad (Bottom Left) --%>
          <div class="absolute bottom-6 left-6 z-20 hidden sm:flex flex-col items-center bg-base-950/90 backdrop-blur-md border border-base-800/90 p-3 rounded-2xl shadow-2xl">
            <div class="text-[10px] font-mono text-base-content/40 uppercase tracking-wider mb-2 flex items-center gap-1">
              <span>🧭 Move (WASD)</span>
            </div>

            <div class="grid grid-cols-3 gap-1 w-28 h-28">
              <div></div>
              <button
                phx-click="walk_direction"
                phx-value-direction="north"
                class="btn btn-xs btn-outline border-base-700 hover:border-amber-400 hover:bg-amber-500/20 text-white font-mono flex flex-col items-center justify-center p-0 h-full"
                title="Walk North [W]"
              >
                <span class="text-amber-400 text-xs">▲</span>
                <span class="text-[9px] text-base-content/60">W</span>
              </button>
              <div></div>

              <button
                phx-click="walk_direction"
                phx-value-direction="west"
                class="btn btn-xs btn-outline border-base-700 hover:border-amber-400 hover:bg-amber-500/20 text-white font-mono flex flex-col items-center justify-center p-0 h-full"
                title="Walk West [A]"
              >
                <span class="text-amber-400 text-xs">◀</span>
                <span class="text-[9px] text-base-content/60">A</span>
              </button>

              <button
                phx-click="walk_direction"
                phx-value-direction="palace"
                class="btn btn-xs btn-accent font-bold text-xs flex flex-col items-center justify-center p-0 h-full shadow-lg"
                title="Return to High Sovereign Palace [C]"
              >
                <span class="text-xs">👑</span>
                <span class="text-[8px] tracking-tighter">Palace</span>
              </button>

              <button
                phx-click="walk_direction"
                phx-value-direction="east"
                class="btn btn-xs btn-outline border-base-700 hover:border-amber-400 hover:bg-amber-500/20 text-white font-mono flex flex-col items-center justify-center p-0 h-full"
                title="Walk East [D]"
              >
                <span class="text-amber-400 text-xs">▶</span>
                <span class="text-[9px] text-base-content/60">D</span>
              </button>

              <div></div>
              <button
                phx-click="walk_direction"
                phx-value-direction="south"
                class="btn btn-xs btn-outline border-base-700 hover:border-amber-400 hover:bg-amber-500/20 text-white font-mono flex flex-col items-center justify-center p-0 h-full"
                title="Walk South [S]"
              >
                <span class="text-amber-400 text-xs">▼</span>
                <span class="text-[9px] text-base-content/60">S</span>
              </button>
              <div></div>
            </div>

            <div class="mt-2 text-[9px] text-cyan-400 font-mono">
              Step {@travel_step_count}
            </div>
          </div>

          <%!-- Mobile On-Screen Travel Bar (for small screens) --%>
          <div class="absolute bottom-2 left-2 right-2 sm:hidden z-20 flex items-center justify-between bg-base-950/95 border border-base-800 rounded-xl p-2 shadow-2xl">
            <div class="flex items-center gap-1.5 text-xs text-white font-bold">
              <span>🧭</span>
              <span class="truncate max-w-[140px]">{@player_district}</span>
            </div>
            <div class="flex items-center gap-1">
              <button
                phx-click="walk_direction"
                phx-value-direction="north"
                class="btn btn-xs btn-square btn-outline border-base-700 text-amber-400"
              >
                ▲
              </button>
              <button
                phx-click="walk_direction"
                phx-value-direction="south"
                class="btn btn-xs btn-square btn-outline border-base-700 text-amber-400"
              >
                ▼
              </button>
              <button
                phx-click="walk_direction"
                phx-value-direction="west"
                class="btn btn-xs btn-square btn-outline border-base-700 text-amber-400"
              >
                ◀
              </button>
              <button
                phx-click="walk_direction"
                phx-value-direction="east"
                class="btn btn-xs btn-square btn-outline border-base-700 text-amber-400"
              >
                ▶
              </button>
              <button
                phx-click="walk_direction"
                phx-value-direction="palace"
                class="btn btn-xs btn-accent px-2"
              >
                👑
              </button>
            </div>
          </div>

          <%!-- 2D Walkable RPG Tile Grid Canvas (Twisted Style) --%>
          <%= if @view_mode == "rpg" do %>
            <div class="w-full h-full flex flex-col items-center justify-between relative overflow-hidden select-none">
              <%!-- Top Info Bar --%>
              <div class="w-full z-20 flex items-center justify-between px-4 py-2 bg-base-950/80 backdrop-blur-md border-b border-base-800/80 text-xs">
                <div class="flex items-center gap-2.5">
                  <span class="badge badge-warning badge-sm font-mono font-bold shadow-sm">
                    📍 [X: {@player_x}, Y: {@player_y}]
                  </span>
                  <span class="text-white font-bold tracking-wide">{@selected_district.name}</span>
                  <span class="badge badge-xs badge-outline text-amber-400 font-serif italic hidden md:inline">
                    {@selected_district.gaelic_name}
                  </span>
                  <span class="text-cyan-400/80 font-mono text-[11px] hidden lg:inline">
                    Tile: region:1:tile:{@player_x}:{@player_y}
                  </span>
                </div>
                <div class="flex items-center gap-3">
                  <div class="flex items-center gap-1 border border-base-700/60 rounded-lg p-0.5 bg-base-900/80">
                    <button
                      phx-click="set_tile_size"
                      phx-value-size="24"
                      class={[
                        "btn btn-xs px-2 h-6 min-h-0 text-[10px]",
                        if(@tile_size == 24,
                          do: "btn-primary",
                          else: "btn-ghost text-base-content/60"
                        )
                      ]}
                      title="Compact View"
                    >
                      24px
                    </button>
                    <button
                      phx-click="set_tile_size"
                      phx-value-size="30"
                      class={[
                        "btn btn-xs px-2 h-6 min-h-0 text-[10px]",
                        if(@tile_size == 30,
                          do: "btn-primary",
                          else: "btn-ghost text-base-content/60"
                        )
                      ]}
                      title="Normal View"
                    >
                      30px
                    </button>
                    <button
                      phx-click="set_tile_size"
                      phx-value-size="36"
                      class={[
                        "btn btn-xs px-2 h-6 min-h-0 text-[10px]",
                        if(@tile_size == 36,
                          do: "btn-primary",
                          else: "btn-ghost text-base-content/60"
                        )
                      ]}
                      title="Large View"
                    >
                      36px
                    </button>
                  </div>
                  <span class="text-amber-400 font-mono text-xs font-semibold">
                    👣 Step {@travel_step_count}
                  </span>
                  <span class="text-base-content/50 text-[11px] hidden sm:inline">
                    WASD / Click to Walk
                  </span>
                </div>
              </div>

              <%!-- 2D Scrollable Tile Grid Container --%>
              <div
                class="flex-1 w-full overflow-auto flex items-start justify-center p-4 relative"
                id="rpg-grid-container"
                style="min-height: 480px;"
              >
                <div
                  id="rpg-grid-board"
                  class="bg-base-950/95 p-3 sm:p-4 rounded-2xl border-2 border-amber-900/40 shadow-2xl relative select-none"
                  style={"display: grid; grid-template-columns: repeat(#{@grid_cols}, #{@tile_size}px); grid-template-rows: repeat(#{@grid_rows}, #{@tile_size}px); gap: 2px; width: max-content; margin: 0 auto;"}
                >
                  <%= for tile <- @grid_tiles do %>
                    <div
                      id={"tile-#{tile.x}-#{tile.y}"}
                      phx-click="walk_tile"
                      phx-value-x={tile.x}
                      phx-value-y={tile.y}
                      title={"#{tile.district} [X: #{tile.x}, Y: #{tile.y}]"}
                      style={"width: #{@tile_size}px; height: #{@tile_size}px; min-width: #{@tile_size}px; min-height: #{@tile_size}px;"}
                      class={[
                        "rounded transition-all duration-75 flex items-center justify-center relative cursor-pointer group",
                        terrain_class(tile.terrain),
                        if(tile.x == @player_x and tile.y == @player_y,
                          do: "ring-2 ring-amber-400 z-20 shadow-lg shadow-amber-500/30",
                          else: ""
                        )
                      ]}
                    >
                      <%!-- Player Token (YOU) --%>
                      <%= if tile.x == @player_x and tile.y == @player_y do %>
                        <div class="relative flex items-center justify-center w-full h-full">
                          <span class="absolute -inset-1 rounded-full bg-amber-400/40 animate-ping">
                          </span>
                          <div class="size-5 sm:size-6 rounded-full bg-gradient-to-tr from-amber-400 to-yellow-200 text-black font-black text-xs flex items-center justify-center shadow-lg border-2 border-white z-10">
                            👑
                          </div>
                          <div class="absolute -bottom-5 whitespace-nowrap px-1.5 py-0.5 rounded bg-amber-500 text-black text-[9px] font-black uppercase tracking-wider shadow-lg z-30 pointer-events-none">
                            YOU (Traveler)
                          </div>
                        </div>
                      <% else %>
                        <%!-- Resident Soul (NPC) on Tile --%>
                        <% npc = find_npc_at_tile(@npc_locations, tile.x, tile.y) %>
                        <%= if npc do %>
                          <div
                            phx-click="hail_soul"
                            phx-value-name={npc.name}
                            phx-value-slug={npc.slug}
                            class="relative flex items-center justify-center w-full h-full group"
                            title={"#{npc.name} (#{npc.title})"}
                          >
                            <%= if is_nearby?(npc, @player_x, @player_y) do %>
                              <span class="absolute -inset-1.5 rounded-full bg-cyan-400/60 animate-pulse">
                              </span>
                            <% end %>
                            <div class={[
                              "size-5 sm:size-6 rounded-full flex items-center justify-center text-xs shadow-md border z-10 transition-transform group-hover:scale-125",
                              if(is_nearby?(npc, @player_x, @player_y),
                                do:
                                  "bg-cyan-500 text-black border-white ring-2 ring-cyan-300 animate-bounce",
                                else: "bg-base-900 text-white border-base-700"
                              )
                            ]}>
                              {npc.icon}
                            </div>
                            <span class="absolute -bottom-3 text-[8px] font-bold text-white bg-base-950/90 px-1 rounded z-20 pointer-events-none truncate max-w-[36px]">
                              {npc.name}
                            </span>
                          </div>
                        <% else %>
                          <%!-- Coordinate text on hover --%>
                          <span class="opacity-0 group-hover:opacity-40 text-[7px] font-mono text-white pointer-events-none">
                            {tile.x},{tile.y}
                          </span>
                        <% end %>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>

              <%!-- Proximity Encounter Card (Twisted Style) --%>
              <%= if @nearby_npc do %>
                <div class="absolute bottom-6 left-6 z-30 max-w-sm bg-base-950/95 backdrop-blur-md border border-cyan-500/60 rounded-2xl p-3.5 shadow-2xl animate-in slide-in-from-bottom-3 duration-200">
                  <div class="flex items-start gap-3">
                    <div class="size-10 rounded-xl bg-cyan-500/20 text-cyan-300 border border-cyan-500/40 flex items-center justify-center font-bold text-xl shrink-0">
                      {@nearby_npc.icon}
                    </div>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2">
                        <span class="text-xs font-bold text-white tracking-wide">
                          {@nearby_npc.name}
                        </span>
                        <span class="badge badge-xs badge-info font-mono text-[9px]">
                          {@nearby_npc.title}
                        </span>
                        <span class="text-[10px] text-emerald-400 font-mono">Nearby</span>
                      </div>
                      <p class="text-[11px] text-cyan-100/90 italic mt-1 leading-snug line-clamp-2">
                        "{@nearby_npc.quote}"
                      </p>
                      <div class="flex items-center gap-2 mt-2">
                        <button
                          phx-click="hail_soul"
                          phx-value-name={@nearby_npc.name}
                          phx-value-slug={@nearby_npc.slug}
                          class="btn btn-xs btn-primary gap-1 font-semibold"
                        >
                          <span>💬</span>
                          <span>Talk [E]</span>
                        </button>
                        <.link
                          navigate={~p"/sse/chat?character=#{@nearby_npc.slug}"}
                          class="btn btn-xs btn-outline border-cyan-500/50 text-cyan-300 hover:bg-cyan-500/20 gap-1 font-semibold"
                        >
                          <span>✉️</span>
                          <span>Direct Chat</span>
                        </.link>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <%!-- Minimap Radar (Top Right) --%>
              <div class="absolute top-12 right-6 z-20 hidden md:block bg-base-950/90 backdrop-blur-md border border-base-800 rounded-xl p-2 shadow-xl">
                <div class="text-[9px] font-mono text-base-content/50 uppercase tracking-wider mb-1 flex items-center justify-between">
                  <span>Mini Radar</span>
                  <span class="text-amber-400">{@player_x},{@player_y}</span>
                </div>
                <div class="w-36 h-28 bg-stone-950 rounded border border-stone-800 relative overflow-hidden">
                  <div class="absolute inset-1 grid grid-cols-3 grid-rows-3 gap-0.5 opacity-30">
                    <div class="bg-indigo-700/50 rounded-xs"></div>
                    <div class="bg-red-700/50 rounded-xs"></div>
                    <div class="bg-cyan-700/50 rounded-xs"></div>
                    <div class="bg-yellow-700/50 rounded-xs"></div>
                    <div class="bg-amber-500/70 rounded-xs border border-amber-400"></div>
                    <div class="bg-blue-700/50 rounded-xs"></div>
                    <div class="bg-purple-700/50 rounded-xs"></div>
                    <div class="bg-emerald-700/50 rounded-xs"></div>
                    <div class="bg-orange-700/50 rounded-xs"></div>
                  </div>
                  <div
                    class="size-2 rounded-full bg-amber-400 border border-white absolute shadow-lg animate-pulse"
                    style={"left: #{(@player_x / 28.0) * 100}%; top: #{(@player_y / 24.0) * 100}%; transform: translate(-50%, -50%);"}
                  >
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Strategic District Radar SVG Canvas (Shown in Radar mode or queried by tests) --%>
          <div class={
            if(@view_mode == "radar",
              do: "w-full h-full flex items-center justify-center",
              else: "hidden"
            )
          }>
            <svg
              viewBox="0 0 1000 780"
              class="w-full h-full max-h-[85vh] select-none filter drop-shadow-2xl"
            >
              <defs>
                <%!-- Radial glow filter for district nodes --%>
                <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
                  <feGaussianBlur in="SourceGraphic" stdDeviation="6" result="blur" />
                  <feMerge>
                    <feMergeNode in="blur" />
                    <feMergeNode in="SourceGraphic" />
                  </feMerge>
                </filter>

                <%!-- Compass Rose Marker --%>
                <g id="compass-rose">
                  <circle
                    cx="0"
                    cy="0"
                    r="28"
                    fill="none"
                    stroke="rgba(255,255,255,0.08)"
                    stroke-width="1.5"
                    stroke-dasharray="4,4"
                  />
                  <path
                    d="M 0 -35 L 5 -5 L 35 0 L 5 5 L 0 35 L -5 5 L -35 0 L -5 -5 Z"
                    fill="rgba(245,158,11,0.2)"
                    stroke="rgba(245,158,11,0.5)"
                    stroke-width="1"
                  />
                  <text
                    x="0"
                    y="-40"
                    fill="rgba(245,158,11,0.8)"
                    font-size="11"
                    font-weight="bold"
                    text-anchor="middle"
                    font-family="serif"
                  >
                    N
                  </text>
                </g>
              </defs>

              <%!-- Compass Rose in upper left --%>
              <use href="#compass-rose" x="80" y="80" />

              <%!-- Concentric City Walls (Elder Scrolls Imperial City Architecture) --%>
              <%!-- Inner Sovereign Citadel Moat & Wall around High Palace --%>
              <circle
                cx="500"
                cy="390"
                r="115"
                fill="rgba(251, 191, 36, 0.03)"
                stroke="rgba(251, 191, 36, 0.25)"
                stroke-width="2.5"
                stroke-dasharray="6,6"
              />
              <%!-- Outer Ring Avenue Guideline --%>
              <circle
                cx="500"
                cy="390"
                r="280"
                fill="none"
                stroke="rgba(148, 163, 184, 0.12)"
                stroke-width="2"
                stroke-dasharray="8,6"
              />
              <%!-- Great Mountain Curtain Wall --%>
              <path
                d="M 120 700 C 350 780, 650 780, 880 700 C 950 500, 950 250, 880 120 C 650 40, 350 40, 120 120 C 50 250, 50 500, 120 700 Z"
                fill="none"
                stroke="rgba(148, 163, 184, 0.15)"
                stroke-width="3.5"
                stroke-dasharray="10,6"
              />

              <%!-- Blackwater River winding through Raven Docks & Foundry --%>
              <path
                d="M 960 110 Q 760 170, 750 250 T 780 390 T 890 620 T 960 720"
                fill="none"
                stroke="rgba(56, 189, 248, 0.22)"
                stroke-width="20"
                stroke-linecap="round"
              />
              <path
                d="M 960 110 Q 760 170, 750 250 T 780 390 T 890 620 T 960 720"
                fill="none"
                stroke="rgba(14, 165, 233, 0.35)"
                stroke-width="7"
                stroke-dasharray="14,8"
              />

              <%!-- Road Connections between Districts --%>
              <g class="roads">
                <%= for {from_slug, to_slug} <- @road_connections do %>
                  <% {x1, y1} = node_coords(from_slug) %>
                  <% {x2, y2} = node_coords(to_slug) %>
                  <% is_player_road = is_connected_to_player?(from_slug, to_slug, @player_district) %>
                  <line
                    x1={x1}
                    y1={y1}
                    x2={x2}
                    y2={y2}
                    stroke={if is_player_road, do: "#fbbf24", else: "rgba(255,255,255,0.12)"}
                    stroke-width={if is_player_road, do: "4.5", else: "2"}
                    stroke-dasharray={if is_player_road, do: "none", else: "6,6"}
                    class={
                      if is_player_road,
                        do: "filter drop-shadow-[0_0_8px_rgba(251,191,36,0.6)] animate-pulse",
                        else: ""
                    }
                  />
                <% end %>
              </g>

              <%!-- 13 District Interactive Nodes --%>
              <%= for district <- @districts do %>
                <% {nx, ny} = node_coords(district.slug) %>
                <% is_player_here = district.slug == @player_district %>
                <% is_selected = district.slug == @selected_slug %>
                <% is_visited = MapSet.member?(@visited_districts, district.slug) %>
                <% color = zone_color(district.zone_type) %>
                <% soul_count = district.soul_count || length(district.present_souls || []) %>

                <g
                  id={"node-#{district.slug}"}
                  transform={"translate(#{nx}, #{ny})"}
                  phx-click="select_district"
                  phx-value-slug={district.slug}
                  class="cursor-pointer group"
                >
                  <%!-- Active Radiance Aura when Player or Selected --%>
                  <%= if is_player_here do %>
                    <circle cx="0" cy="0" r="42" fill="rgba(251, 191, 36, 0.15)" class="animate-ping" />
                    <circle
                      cx="0"
                      cy="0"
                      r="34"
                      fill="none"
                      stroke="#fbbf24"
                      stroke-width="2"
                      class="animate-pulse"
                    />
                  <% end %>

                  <%= if is_selected and not is_player_here do %>
                    <circle
                      cx="0"
                      cy="0"
                      r="32"
                      fill="none"
                      stroke="#38bdf8"
                      stroke-width="2"
                      stroke-dasharray="4,4"
                    />
                  <% end %>

                  <%!-- Main District Node Circle --%>
                  <circle
                    cx="0"
                    cy="0"
                    r={if district.slug == "high_palace", do: "32", else: "26"}
                    fill={if is_player_here, do: "#090d16", else: "#0f172a"}
                    stroke={if is_player_here, do: "#fbbf24", else: color}
                    stroke-width={if is_player_here or is_selected, do: "3.5", else: "2"}
                    filter={if is_player_here, do: "url(#glow)", else: "none"}
                    class="transition-all duration-300 group-hover:stroke-white group-hover:scale-110"
                  />

                  <%!-- District Monogram inside Node --%>
                  <text
                    x="0"
                    y="-4"
                    fill={if is_player_here, do: "#fbbf24", else: "#ffffff"}
                    font-size={if district.slug == "high_palace", do: "16", else: "11"}
                    font-weight="900"
                    text-anchor="middle"
                    font-family="monospace"
                    class="pointer-events-none"
                  >
                    {district_monogram(district.slug)}
                  </text>

                  <%!-- Explored / Visited Indicator --%>
                  <%= if is_visited and not is_player_here do %>
                    <circle cx="18" cy="-18" r="4" fill="#10b981" />
                  <% end %>

                  <%!-- Soul Count Badge inside Node --%>
                  <g transform="translate(0, 12)">
                    <rect
                      x="-18"
                      y="-8"
                      width="36"
                      height="14"
                      rx="7"
                      fill="#1e293b"
                      stroke={color}
                      stroke-width="1"
                    />
                    <text
                      x="0"
                      y="3"
                      fill="#38bdf8"
                      font-size="9"
                      font-weight="bold"
                      text-anchor="middle"
                      font-family="monospace"
                    >
                      {soul_count} souls
                    </text>
                  </g>

                  <%!-- Gaelic Name Label Below Node --%>
                  <text
                    x="0"
                    y="48"
                    fill={if is_selected or is_player_here, do: "#f8fafc", else: "#cbd5e1"}
                    font-size="11"
                    font-weight="bold"
                    text-anchor="middle"
                    font-family="system-ui, sans-serif"
                    class="pointer-events-none drop-shadow-md"
                  >
                    {district.name}
                  </text>
                  <text
                    x="0"
                    y="62"
                    fill="rgba(148, 163, 184, 0.7)"
                    font-size="9"
                    font-style="italic"
                    text-anchor="middle"
                    font-family="serif"
                    class="pointer-events-none"
                  >
                    {district.gaelic_name}
                  </text>
                </g>
              <% end %>

              <%!-- Visual Player Token (Rendered on top of active district) --%>
              <% {px, py} = node_coords(@player_district) %>
              <g
                id="player-avatar-token"
                transform={"translate(#{px}, #{py})"}
                class="pointer-events-none transition-all duration-500"
              >
                <%!-- Animated Radar Pulse --%>
                <circle
                  cx="0"
                  cy="0"
                  r="40"
                  fill="none"
                  stroke="#38bdf8"
                  stroke-width="2.5"
                  class="animate-ping opacity-60"
                />
                <circle cx="0" cy="0" r="28" fill="rgba(56, 189, 248, 0.3)" filter="url(#glow)" />

                <%!-- Player Emblem --%>
                <circle cx="0" cy="0" r="18" fill="#020617" stroke="#fbbf24" stroke-width="3" />
                <text x="0" y="5" font-size="13" text-anchor="middle">🧭</text>

                <%!-- Overhead Badge --%>
                <g transform="translate(0, -32)">
                  <rect
                    x="-44"
                    y="-10"
                    width="88"
                    height="20"
                    rx="10"
                    fill="#020617"
                    stroke="#38bdf8"
                    stroke-width="1.5"
                  />
                  <text
                    x="0"
                    y="3"
                    fill="#38bdf8"
                    font-size="9"
                    font-weight="extrabold"
                    text-anchor="middle"
                    font-family="monospace"
                  >
                    YOU (Traveler)
                  </text>
                </g>
              </g>
            </svg>
          </div>

          <%!-- Legend Footer --%>
          <div class="absolute bottom-4 right-6 hidden md:flex items-center gap-3 px-3 py-1.5 rounded-xl bg-base-950/80 backdrop-blur-md border border-base-800 text-[11px] text-base-content/60 shadow-lg">
            <span class="font-bold text-white uppercase text-[9px] tracking-wider">Regions:</span>
            <span class="flex items-center gap-1">
              <span class="size-2 rounded-full bg-amber-400"></span> Palace
            </span>
            <span class="flex items-center gap-1">
              <span class="size-2 rounded-full bg-amber-500"></span> Citadel
            </span>
            <span class="flex items-center gap-1">
              <span class="size-2 rounded-full bg-cyan-500"></span> Sacred
            </span>
            <span class="flex items-center gap-1">
              <span class="size-2 rounded-full bg-emerald-500"></span> Market
            </span>
            <span class="flex items-center gap-1">
              <span class="size-2 rounded-full bg-orange-500"></span> Forge
            </span>
            <span class="flex items-center gap-1">
              <span class="size-2 rounded-full bg-purple-500"></span> Underworld
            </span>
            <span class="flex items-center gap-1">
              <span class="size-2 rounded-full bg-rose-500"></span> Bastion
            </span>
          </div>
        </div>

        <%!-- District Inspector Side Drawer (Right 30%) --%>
        <%= if @selected_district do %>
          <% is_player_in_selected = @selected_district.slug == @player_district %>
          <div class="w-full lg:w-[420px] bg-base-950 border-l border-base-800 flex flex-col h-auto lg:h-[calc(100vh-4rem)] overflow-y-auto shadow-2xl">
            <%!-- Header Banner --%>
            <div class="p-6 border-b border-base-800/80 bg-gradient-to-b from-base-900/60 to-transparent space-y-3">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <span class={[
                    "badge badge-sm font-mono text-[10px] uppercase font-bold tracking-wider",
                    danger_badge_class(@selected_district.danger_level)
                  ]}>
                    Danger Lvl {@selected_district.danger_level}/10
                  </span>

                  <%= if is_player_in_selected do %>
                    <span class="badge badge-sm bg-cyan-950 text-cyan-300 border-cyan-500/40 text-[10px] font-bold">
                      📍 You Are Here
                    </span>
                  <% end %>
                </div>

                <span class="badge badge-sm badge-outline font-mono text-[10px] text-teal-400 border-teal-500/40">
                  {@selected_district.tile_id}
                </span>
              </div>

              <div>
                <h2 class="text-xl font-black text-white tracking-tight">
                  {@selected_district.name}
                </h2>
                <p class="text-xs font-serif italic text-amber-400/90 mt-0.5">
                  {@selected_district.gaelic_name}
                </p>
              </div>

              <%!-- Fast Walk button if viewing a district from afar --%>
              <%= if not is_player_in_selected do %>
                <button
                  phx-click="walk_to_district"
                  phx-value-slug={@selected_district.slug}
                  class="btn btn-sm btn-outline border-cyan-500/60 text-cyan-300 hover:bg-cyan-500/20 w-full font-bold flex items-center justify-center gap-2"
                >
                  <span>🚶 Walk to {@selected_district.name}</span>
                </button>
              <% end %>

              <%!-- Atmosphere sensory prose --%>
              <div class="p-3 rounded-xl bg-base-900/80 border border-base-800 text-xs text-base-content/80 leading-relaxed italic">
                "{@selected_district.atmosphere}"
              </div>
            </div>

            <%!-- District Body Info --%>
            <div class="p-6 space-y-6 flex-1">
              <%!-- Proximity Souls Roster --%>
              <div class="space-y-2.5">
                <div class="flex items-center justify-between">
                  <h3 class="text-xs font-bold text-base-content/50 uppercase tracking-wider flex items-center gap-1.5">
                    <.icon name="hero-users" class="size-3.5 text-sky-400" />
                    <%= if is_player_in_selected do %>
                      <span>Local Proximity Souls ({length(@selected_district.present_souls)})</span>
                    <% else %>
                      <span>Souls in District ({length(@selected_district.present_souls)})</span>
                    <% end %>
                  </h3>
                  <.link
                    navigate={~p"/sse/chat?location=#{@selected_district.name}"}
                    class="btn btn-ghost btn-xs text-teal-400 hover:text-teal-300 font-semibold"
                  >
                    Group Chat →
                  </.link>
                </div>

                <%= if Enum.empty?(@selected_district.present_souls) do %>
                  <div class="p-4 rounded-xl bg-base-900/40 border border-base-800 text-center text-xs text-base-content/40">
                    No souls currently linger in this district. Click "Roam Souls" or wait for a patrol.
                  </div>
                <% else %>
                  <div class="grid grid-cols-1 gap-2.5 max-h-56 overflow-y-auto pr-1">
                    <%= for soul <- @selected_district.present_souls do %>
                      <div class="p-3 rounded-xl bg-base-900/70 border border-base-800 flex items-center justify-between gap-2">
                        <div class="flex items-center gap-2.5 min-w-0">
                          <div class="w-8 h-8 rounded-full bg-amber-500/20 text-amber-400 border border-amber-500/40 flex items-center justify-center font-bold text-xs shrink-0">
                            {String.slice(soul.name, 0, 1)}
                          </div>
                          <div class="min-w-0">
                            <div class="text-xs font-bold text-white truncate">{soul.name}</div>
                            <div class="text-[10px] text-base-content/50 font-mono truncate">
                              @{soul.slug}
                            </div>
                          </div>
                        </div>

                        <div class="flex items-center gap-1.5 shrink-0">
                          <%!-- Instant Ambient Hail Button (Zero Compute / Instant Local Voice) --%>
                          <button
                            phx-click="hail_soul"
                            phx-value-name={soul.name}
                            phx-value-slug={soul.slug}
                            class="btn btn-xs btn-ghost text-amber-400 hover:bg-amber-500/20 font-semibold"
                            title={"Hail #{soul.name} for an ambient local greeting"}
                          >
                            👋 Hail
                          </button>

                          <%!-- Direct Chat Navigation Link with Location Context --%>
                          <.link
                            navigate={
                              ~p"/sse/chat?character_id=#{soul.id}&location=#{@selected_district.name}"
                            }
                            class="btn btn-xs btn-outline border-base-700 text-teal-300 hover:bg-teal-500/20"
                            title={"Talk with #{soul.name} in private chat"}
                          >
                            💬 Talk
                          </.link>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <%!-- Lore & History --%>
              <div class="space-y-1.5">
                <h3 class="text-xs font-bold text-base-content/50 uppercase tracking-wider flex items-center gap-1.5">
                  <.icon name="hero-book-open" class="size-3.5 text-amber-500" />
                  Historical Lore & Heritage
                </h3>
                <p class="text-xs text-base-content/85 leading-relaxed">
                  {@selected_district.lore}
                </p>
              </div>

              <%!-- Amenities & Discovered Secrets --%>
              <div class="space-y-2">
                <h3 class="text-xs font-bold text-base-content/50 uppercase tracking-wider flex items-center gap-1.5">
                  <.icon name="hero-key" class="size-3.5 text-purple-400" />
                  District Landmarks & Secrets
                </h3>

                <div class="flex flex-wrap gap-1.5">
                  <%= for amenity <- @selected_district.amenities do %>
                    <span class="badge badge-sm bg-base-900 border-base-800 text-base-content/80 text-[11px]">
                      {amenity}
                    </span>
                  <% end %>
                </div>

                <%= for secret <- (@selected_district.secrets || []) do %>
                  <div class="p-2.5 rounded-xl bg-purple-950/40 border border-purple-800/40 text-[11px] text-purple-200 flex items-start gap-2">
                    <.icon name="hero-sparkles" class="size-4 text-purple-400 shrink-0 mt-0.5" />
                    <span>{secret}</span>
                  </div>
                <% end %>

                <%!-- AI Expansions list --%>
                <%= for exp <- (@selected_district.expansions || []) do %>
                  <div class="p-3 rounded-xl bg-amber-950/40 border border-amber-800/50 space-y-1">
                    <div class="flex items-center justify-between text-xs font-bold text-amber-300">
                      <span>✨ {exp.title}</span>
                      <span class="badge badge-xs badge-warning uppercase text-[9px]">
                        {exp.type}
                      </span>
                    </div>
                    <p class="text-[11px] text-base-content/80 leading-relaxed">
                      {exp.description}
                    </p>
                    <div class="text-[10px] text-amber-400/60 font-mono italic">
                      Discovered via: {exp.uncovered_by}
                    </div>
                  </div>
                <% end %>
              </div>

              <%!-- AI District Expansion Prompt Box --%>
              <div class="p-4 rounded-2xl bg-base-900 border border-amber-500/30 space-y-3 shadow-lg">
                <div class="flex items-center gap-2">
                  <div class="w-6 h-6 rounded-full bg-amber-500/20 text-amber-400 flex items-center justify-center">
                    <.icon name="hero-sparkles" class="size-3.5" />
                  </div>
                  <div>
                    <h4 class="text-xs font-bold text-white">AI World Architect</h4>
                    <p class="text-[10px] text-base-content/50">
                      Expand this district with procedural lore
                    </p>
                  </div>
                </div>

                <form phx-submit="expand_with_ai" class="space-y-2">
                  <input
                    type="text"
                    name="prompt"
                    value={@ai_prompt}
                    phx-change="update_ai_prompt"
                    phx-focus="focus_ai_input"
                    phx-blur="blur_ai_input"
                    placeholder="e.g. Hidden alchemist cellar, omen from the moors..."
                    class="input input-sm input-bordered w-full text-xs bg-base-950 border-base-700"
                    disabled={@is_generating_ai?}
                  />
                  <button
                    type="submit"
                    class="btn btn-sm btn-accent w-full font-bold text-xs flex items-center justify-center gap-1.5"
                    disabled={@is_generating_ai?}
                  >
                    <%= if @is_generating_ai? do %>
                      <span class="loading loading-spinner loading-xs"></span>
                      <span>Architecting with AI...</span>
                    <% else %>
                      <.icon name="hero-bolt" class="size-3.5" />
                      <span>Expand District with AI</span>
                    <% end %>
                  </button>
                </form>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Mobile Bottom Navigation Dock (Matching Feed & Chat PWA feel) --%>
      <nav class="lg:hidden fixed bottom-0 left-0 right-0 z-40 bg-base-950/95 backdrop-blur-lg border-t border-base-800/80 px-4 py-2 flex items-center justify-around">
        <.link
          navigate={~p"/sse/chat"}
          class="flex flex-col items-center gap-0.5 text-base-content/60 hover:text-white"
        >
          <span class="text-lg">💬</span>
          <span class="text-[10px] font-medium">Chat</span>
        </.link>

        <.link
          navigate={~p"/sse/feed"}
          class="flex flex-col items-center gap-0.5 text-base-content/60 hover:text-white"
        >
          <span class="text-lg">📰</span>
          <span class="text-[10px] font-medium">Feed</span>
        </.link>

        <.link
          navigate={~p"/sse/map"}
          class="flex flex-col items-center gap-0.5 text-amber-400 font-bold"
        >
          <span class="text-lg">🏰</span>
          <span class="text-[10px]">Map</span>
        </.link>

        <.link
          navigate={~p"/sse/acp/moderation"}
          class="flex flex-col items-center gap-0.5 text-base-content/60 hover:text-white"
        >
          <span class="text-lg">🛡️</span>
          <span class="text-[10px] font-medium">Shield</span>
        </.link>
      </nav>
    </div>
    """
  end
end
