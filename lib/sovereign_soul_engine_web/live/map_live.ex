defmodule SovereignSoulEngineWeb.MapLive do
  @moduledoc """
  Interactive Living Town Map of Feannag's Rest (Gleann Caorach).

  Combines:
  - 12 Celtic/Gothic dark-fantasy districts meeting Elder Scrolls Imperial City & Baldur's Gate lore.
  - Live spatial distribution & roaming for the 50 souls.
  - 1:1 Twisted Paradox tile compatibility (`region:1:tile:X:Y`).
  - Interactive District Inspector with lore, present souls, secrets, and AI District Expansion.
  """

  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.World.TownMap

  @road_connections [
    {"crows_keep", "north_outpost"},
    {"crows_keep", "high_sanctuary"},
    {"crows_keep", "kings_plaza"},
    {"north_outpost", "weavers_commons"},
    {"high_sanctuary", "kings_plaza"},
    {"high_sanctuary", "raven_docks"},
    {"weavers_commons", "night_owl_quarter"},
    {"weavers_commons", "barrowgrounds"},
    {"night_owl_quarter", "kings_plaza"},
    {"night_owl_quarter", "barrowgrounds"},
    {"barrowgrounds", "shadowgate_warrens"},
    {"kings_plaza", "raven_docks"},
    {"kings_plaza", "old_ironworks"},
    {"kings_plaza", "sunken_undercity"},
    {"kings_plaza", "shadowgate_warrens"},
    {"raven_docks", "old_ironworks"},
    {"old_ironworks", "south_bastion"},
    {"shadowgate_warrens", "south_bastion"},
    {"shadowgate_warrens", "sunken_undercity"},
    {"sunken_undercity", "south_bastion"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "town:map")
    end

    map_data = TownMap.get_map()
    selected_district = TownMap.get_district("kings_plaza")

    socket =
      socket
      |> assign(:page_title, "Feannag's Rest — Living Map")
      |> assign(:town_name, map_data.town_name)
      |> assign(:region_name, map_data.region_name)
      |> assign(:districts, map_data.districts)
      |> assign(:total_souls, map_data.total_souls)
      |> assign(:selected_slug, "kings_plaza")
      |> assign(:selected_district, selected_district)
      |> assign(:ai_prompt, "")
      |> assign(:is_generating_ai?, false)
      |> assign(:road_connections, @road_connections)

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

  # --- User Events ------------------------------------------------------------

  @impl true
  def handle_event("select_district", %{"slug" => slug}, socket) do
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

  @impl true
  def handle_event("simulate_roam", _params, socket) do
    {:ok, count} = TownMap.simulate_roaming()
    # Refresh map state
    map_data = TownMap.get_map()
    selected = TownMap.get_district(socket.assigns.selected_slug)

    socket =
      socket
      |> assign(:districts, map_data.districts)
      |> assign(:selected_district, selected)
      |> put_flash(:info, "Highland gale blew through Feannag's Rest: #{count} souls roamed to new districts!")

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

  # --- SVG Coordinates & Helpers ----------------------------------------------

  defp node_coords("kings_plaza"), do: {500, 400}
  defp node_coords("crows_keep"), do: {500, 110}
  defp node_coords("north_outpost"), do: {330, 110}
  defp node_coords("high_sanctuary"), do: {730, 220}
  defp node_coords("weavers_commons"), do: {260, 240}
  defp node_coords("night_owl_quarter"), do: {370, 310}
  defp node_coords("barrowgrounds"), do: {140, 320}
  defp node_coords("raven_docks"), do: {850, 400}
  defp node_coords("sunken_undercity"), do: {500, 490}
  defp node_coords("old_ironworks"), do: {730, 500}
  defp node_coords("shadowgate_warrens"), do: {270, 500}
  defp node_coords("south_bastion"), do: {500, 680}
  defp node_coords(_), do: {500, 400}

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

  defp danger_badge_class(danger) when danger >= 7, do: "badge-error"
  defp danger_badge_class(danger) when danger >= 4, do: "badge-warning"
  defp danger_badge_class(_), do: "badge-success"

  # --- Template ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-950 text-base-content flex flex-col font-sans">
      <%!-- Navigation Header --%>
      <header class="h-16 border-b border-base-800 bg-base-900/90 backdrop-blur-md px-6 flex items-center justify-between sticky top-0 z-30">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/sse/chat"} class="btn btn-ghost btn-xs text-base-content/60 hover:text-base-content flex items-center gap-1.5">
            <.icon name="hero-arrow-left" class="size-4" />
            <span>Chat</span>
          </.link>
          
          <div class="h-5 w-px bg-base-700" />
          
          <div>
            <h1 class="text-base font-extrabold tracking-tight text-white flex items-center gap-2">
              <span class="text-amber-500">🏰</span>
              <span>{@town_name}</span>
              <span class="text-xs font-normal text-base-content/50 font-serif italic">({@region_name})</span>
            </h1>
            <p class="text-[11px] text-base-content/50 font-medium tracking-wide">
              The Dark Walled City of the Crows • 12 Living Districts • Celtic Gothic Lore
            </p>
          </div>
        </div>

        <%!-- Status Badges & Quick Actions --%>
        <div class="flex items-center gap-3">
          <div class="hidden sm:flex items-center gap-2 px-3 py-1 rounded-lg bg-base-800/80 border border-base-700/60 text-xs">
            <span class="size-2 rounded-full bg-emerald-400 animate-pulse"></span>
            <span class="font-bold text-white">{@total_souls}</span>
            <span class="text-base-content/60">Living Souls</span>
          </div>

          <div class="hidden md:flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-indigo-950/80 border border-indigo-700/50 text-indigo-300 text-xs font-mono">
            <span>Twisted Matrix 12x12</span>
          </div>

          <button
            phx-click="simulate_roam"
            class="btn btn-xs btn-outline border-amber-500/50 text-amber-400 hover:bg-amber-500/15 font-semibold flex items-center gap-1"
            title="Randomly roam souls along connected roads"
          >
            <.icon name="hero-arrows-right-left" class="size-3.5" />
            <span>Roam Souls</span>
          </button>
        </div>
      </header>

      <%!-- Flash Banners --%>
      <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
        <div id="flash-info" class="bg-amber-500/20 border-b border-amber-500/30 text-amber-300 text-xs py-2 px-6 font-medium flex items-center gap-2">
          <.icon name="hero-sparkles" class="size-4 text-amber-400" />
          <span>{flash}</span>
        </div>
      <% end %>
      <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
        <div id="flash-error" class="bg-rose-500/20 border-b border-rose-500/30 text-rose-300 text-xs py-2 px-6 font-medium flex items-center gap-2">
          <.icon name="hero-exclamation-triangle" class="size-4 text-rose-400" />
          <span>{flash}</span>
        </div>
      <% end %>

      <%!-- Main Layout: Map Canvas (Left 70%) + District Inspector (Right 30%) --%>
      <div class="flex-1 flex flex-col lg:flex-row overflow-hidden">
        <%!-- SVG Interactive Map Canvas --%>
        <div class="flex-1 relative bg-gradient-to-b from-[#070a12] via-[#090d18] to-[#0a0f1d] overflow-hidden flex items-center justify-center p-4">
          <%!-- Subtle background ambient watermarks --%>
          <div class="absolute inset-0 opacity-5 pointer-events-none bg-[radial-gradient(#38bdf8_1px,transparent_1px)] [background-size:24px_24px]"></div>
          
          <svg viewBox="0 0 1000 780" class="w-full h-full max-h-[85vh] select-none filter drop-shadow-2xl">
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
                <circle cx="0" cy="0" r="28" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="1.5" stroke-dasharray="4,4" />
                <path d="M 0 -35 L 5 -5 L 35 0 L 5 5 L 0 35 L -5 5 L -35 0 L -5 -5 Z" fill="rgba(245,158,11,0.2)" stroke="rgba(245,158,11,0.5)" stroke-width="1" />
                <text x="0" y="-40" fill="rgba(245,158,11,0.8)" font-size="11" font-weight="bold" text-anchor="middle" font-family="serif">N</text>
              </g>
            </defs>

            <%!-- Compass Rose in upper left --%>
            <use href="#compass-rose" x="80" y="80" />

            <%!-- Outer Wall & River Decorators --%>
            <path
              d="M 120 700 C 350 780, 650 780, 880 700 C 950 500, 950 250, 880 120 C 650 40, 350 40, 120 120 C 50 250, 50 500, 120 700 Z"
              fill="none"
              stroke="rgba(148, 163, 184, 0.12)"
              stroke-width="3"
              stroke-dasharray="8,6"
            />
            
            <%!-- Blackwater River winding from top-right to docks --%>
            <path
              d="M 980 200 Q 860 300, 850 400 T 980 600"
              fill="none"
              stroke="rgba(56, 189, 248, 0.25)"
              stroke-width="18"
              stroke-linecap="round"
            />
            <path
              d="M 980 200 Q 860 300, 850 400 T 980 600"
              fill="none"
              stroke="rgba(14, 165, 233, 0.4)"
              stroke-width="6"
              stroke-dasharray="12,8"
            />

            <%!-- Road Connections between Districts --%>
            <g class="roads">
              <%= for {from_slug, to_slug} <- @road_connections do %>
                <% {x1, y1} = node_coords(from_slug) %>
                <% {x2, y2} = node_coords(to_slug) %>
                <line
                  x1={x1}
                  y1={y1}
                  x2={x2}
                  y2={y2}
                  stroke="rgba(100, 116, 139, 0.35)"
                  stroke-width="4"
                  stroke-dasharray="6,4"
                  class="transition-all duration-300"
                />
              <% end %>
            </g>

            <%!-- District Nodes --%>
            <%= for district <- @districts do %>
              <% {cx, cy} = node_coords(district.slug) %>
              <% is_selected = district.slug == @selected_slug %>
              <% color = zone_color(district.zone_type) %>
              <% soul_count = Map.get(district, :soul_count, 0) %>

              <g
                phx-click="select_district"
                phx-value-slug={district.slug}
                class="cursor-pointer group transition-transform duration-200"
                transform={"translate(#{cx}, #{cy})"}
              >
                <%!-- Highlight halo if selected --%>
                <%= if is_selected do %>
                  <circle
                    cx="0"
                    cy="0"
                    r="46"
                    fill="none"
                    stroke={color}
                    stroke-width="2.5"
                    stroke-dasharray="4,4"
                    class="animate-spin"
                    style="animation-duration: 12s;"
                  />
                  <circle
                    cx="0"
                    cy="0"
                    r="40"
                    fill={color}
                    fill-opacity="0.25"
                    filter="url(#glow)"
                  />
                <% end %>

                <%!-- Base District Circle --%>
                <circle
                  cx="0"
                  cy="0"
                  r={if is_selected, do: 34, else: 30}
                  fill="#0f172a"
                  stroke={if is_selected, do: color, else: "rgba(148, 163, 184, 0.4)"}
                  stroke-width={if is_selected, do: 3, else: 1.5}
                  class="group-hover:stroke-amber-400 transition-all shadow-xl"
                />

                <%!-- Inner Ring with Zone Color Accent --%>
                <circle
                  cx="0"
                  cy="0"
                  r={if is_selected, do: 28, else: 24}
                  fill={color}
                  fill-opacity="0.18"
                />

                <%!-- District Short Title / Monogram --%>
                <text
                  x="0"
                  y="-4"
                  fill="#ffffff"
                  font-size="12"
                  font-weight="bold"
                  text-anchor="middle"
                  class="pointer-events-none"
                >
                  {String.slice(district.name, 0, 3)}
                </text>

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
                  fill={if is_selected, do: "#f8fafc", else: "#cbd5e1"}
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
          </svg>

          <%!-- Legend Footer --%>
          <div class="absolute bottom-4 left-6 hidden sm:flex items-center gap-3 px-3 py-1.5 rounded-xl bg-base-900/80 backdrop-blur-md border border-base-800 text-[11px] text-base-content/60 shadow-lg">
            <span class="font-bold text-white uppercase text-[9px] tracking-wider">Districts:</span>
            <span class="flex items-center gap-1"><span class="size-2 rounded-full bg-amber-500"></span> Citadel</span>
            <span class="flex items-center gap-1"><span class="size-2 rounded-full bg-cyan-500"></span> Sacred</span>
            <span class="flex items-center gap-1"><span class="size-2 rounded-full bg-emerald-500"></span> Market</span>
            <span class="flex items-center gap-1"><span class="size-2 rounded-full bg-orange-500"></span> Forge</span>
            <span class="flex items-center gap-1"><span class="size-2 rounded-full bg-purple-500"></span> Underworld</span>
            <span class="flex items-center gap-1"><span class="size-2 rounded-full bg-rose-500"></span> Bastion</span>
          </div>
        </div>

        <%!-- District Inspector Side Drawer (Right 30%) --%>
        <%= if @selected_district do %>
          <div class="w-full lg:w-[420px] bg-base-900 border-l border-base-800 flex flex-col h-auto lg:h-[calc(100vh-4rem)] overflow-y-auto shadow-2xl">
            <%!-- Header Banner --%>
            <div class="p-6 border-b border-base-800 bg-gradient-to-b from-base-800/40 to-transparent space-y-3">
              <div class="flex items-center justify-between">
                <span class={[
                  "badge badge-sm font-mono text-[10px] uppercase font-bold tracking-wider",
                  danger_badge_class(@selected_district.danger_level)
                ]}>
                  Danger Lvl {@selected_district.danger_level}/10
                </span>

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

              <%!-- Atmosphere sensory prose --%>
              <div class="p-3 rounded-xl bg-base-950/70 border border-base-800 text-xs text-base-content/80 leading-relaxed italic">
                "{@selected_district.atmosphere}"
              </div>
            </div>

            <%!-- District Body Info --%>
            <div class="p-6 space-y-6 flex-1">
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

              <%!-- Present Souls Roster --%>
              <div class="space-y-2">
                <div class="flex items-center justify-between">
                  <h3 class="text-xs font-bold text-base-content/50 uppercase tracking-wider flex items-center gap-1.5">
                    <.icon name="hero-users" class="size-3.5 text-sky-400" />
                    Present Souls ({length(@selected_district.present_souls)})
                  </h3>
                  <.link
                    navigate={~p"/sse/chat?location=#{@selected_district.name}"}
                    class="btn btn-ghost btn-xs text-teal-400 hover:text-teal-300 font-semibold"
                  >
                    Chat Here →
                  </.link>
                </div>

                <%= if Enum.empty?(@selected_district.present_souls) do %>
                  <div class="p-3 rounded-xl bg-base-950/40 border border-base-800 text-center text-xs text-base-content/40">
                    No souls currently linger in this district. Click "Roam Souls" to watch them migrate.
                  </div>
                <% else %>
                  <div class="grid grid-cols-1 gap-2 max-h-48 overflow-y-auto pr-1">
                    <%= for soul <- @selected_district.present_souls do %>
                      <div class="p-2.5 rounded-xl bg-base-800/60 border border-base-700/50 flex items-center justify-between">
                        <div class="flex items-center gap-2.5">
                          <div class="w-8 h-8 rounded-full bg-amber-500/20 text-amber-400 border border-amber-500/40 flex items-center justify-center font-bold text-xs">
                            {String.slice(soul.name, 0, 1)}
                          </div>
                          <div>
                            <div class="text-xs font-bold text-white">{soul.name}</div>
                            <div class="text-[10px] text-base-content/50 font-mono">@{soul.slug}</div>
                          </div>
                        </div>

                        <.link
                          navigate={~p"/sse/chat?npc_id=#{soul.id}"}
                          class="btn btn-xs btn-outline border-base-600 text-base-content/80 hover:bg-base-700"
                        >
                          Talk
                        </.link>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <%!-- Amenities & Discovered Secrets --%>
              <div class="space-y-2">
                <h3 class="text-xs font-bold text-base-content/50 uppercase tracking-wider flex items-center gap-1.5">
                  <.icon name="hero-key" class="size-3.5 text-purple-400" />
                  District Amenities & Secrets
                </h3>

                <div class="flex flex-wrap gap-1.5">
                  <%= for amenity <- @selected_district.amenities do %>
                    <span class="badge badge-sm bg-base-800 border-base-700 text-base-content/80 text-[11px]">
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
                      <span class="badge badge-xs badge-warning uppercase text-[9px]">{exp.type}</span>
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
              <div class="p-4 rounded-2xl bg-base-950 border border-amber-500/30 space-y-3 shadow-lg">
                <div class="flex items-center gap-2">
                  <div class="w-6 h-6 rounded-full bg-amber-500/20 text-amber-400 flex items-center justify-center">
                    <.icon name="hero-sparkles" class="size-3.5" />
                  </div>
                  <div>
                    <h4 class="text-xs font-bold text-white">AI World Architect</h4>
                    <p class="text-[10px] text-base-content/50">Expand this district with procedural lore</p>
                  </div>
                </div>

                <form phx-submit="expand_with_ai" class="space-y-2">
                  <input
                    type="text"
                    name="prompt"
                    value={@ai_prompt}
                    phx-change="update_ai_prompt"
                    placeholder="e.g. Hidden alchemist cellar, omen from the moors..."
                    class="input input-sm input-bordered w-full text-xs bg-base-900 border-base-700"
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
    </div>
    """
  end
end
