defmodule SovereignSoulEngineWeb.LandingLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_scope] && socket.assigns[:current_scope].user

    living_souls =
      if user do
        Characters.list_companions_for_user(user.id)
      else
        []
      end

    companions = [
      %{
        slug: "maya",
        name: "Maya",
        archetype: "Empathetic Tactician",
        quote: "I notice how your pulse slows when you're actually telling the truth."
      },
      %{
        slug: "ravina",
        name: "Ravina",
        archetype: "Cynical Enforcer",
        quote: "Betrayal leaves scars. Earn my respect, or keep your distance."
      },
      %{
        slug: "valeria",
        name: "Valeria",
        archetype: "Philosopher Witch",
        quote: "The dream loop cleanses our memories, but your essence remains."
      },
      %{
        slug: "cyra",
        name: "Cyra",
        archetype: "Adaptive Technologist",
        quote: "Telemetric parity reached. All biometrics synchronized."
      }
    ]

    selected_companion = hd(companions)

    socket =
      socket
      |> assign(:page_title, "Sovereign Soul Engine — Artificial Lives with True Souls")
      |> assign(:user, user)
      |> assign(:living_souls, living_souls)
      |> assign(:carousel_index, 0)
      |> assign(:active_soul_filter, "all")
      |> assign(:companions, companions)
      |> assign(:selected_companion, selected_companion)
      |> assign(:sandbox_bpm, 74)
      |> assign(:sandbox_stress, 20)
      |> assign(:sandbox_reaction, generate_reaction(selected_companion.name, 74, 20))
      |> assign(:active_pricing_cycle, "monthly")

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_event("next_carousel_soul", _params, socket) do
    souls =
      filtered_souls(
        socket.assigns.living_souls,
        socket.assigns.active_soul_filter,
        socket.assigns.user
      )

    count = length(souls)
    new_idx = if count > 0, do: rem(socket.assigns.carousel_index + 1, count), else: 0
    {:noreply, assign(socket, :carousel_index, new_idx)}
  end

  @impl true
  def handle_event("prev_carousel_soul", _params, socket) do
    souls =
      filtered_souls(
        socket.assigns.living_souls,
        socket.assigns.active_soul_filter,
        socket.assigns.user
      )

    count = length(souls)

    new_idx =
      if count > 0,
        do:
          if(socket.assigns.carousel_index == 0,
            do: count - 1,
            else: socket.assigns.carousel_index - 1
          ),
        else: 0

    {:noreply, assign(socket, :carousel_index, new_idx)}
  end

  @impl true
  def handle_event("set_soul_filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:active_soul_filter, filter)
     |> assign(:carousel_index, 0)}
  end

  @impl true
  def handle_event("select_sandbox_companion", %{"slug" => slug}, socket) do
    companion =
      Enum.find(socket.assigns.companions, &(&1.slug == slug)) ||
        socket.assigns.selected_companion

    reaction =
      generate_reaction(companion.name, socket.assigns.sandbox_bpm, socket.assigns.sandbox_stress)

    {:noreply,
     socket
     |> assign(:selected_companion, companion)
     |> assign(:sandbox_reaction, reaction)}
  end

  @impl true
  def handle_event("update_sandbox_biometrics", %{"bpm" => bpm, "stress" => stress}, socket) do
    bpm = String.to_integer(bpm)
    stress = String.to_integer(stress)
    companion = socket.assigns.selected_companion
    reaction = generate_reaction(companion.name, bpm, stress)

    {:noreply,
     socket
     |> assign(:sandbox_bpm, bpm)
     |> assign(:sandbox_stress, stress)
     |> assign(:sandbox_reaction, reaction)}
  end

  @impl true
  def handle_event("toggle_pricing_cycle", _params, socket) do
    new_cycle = if socket.assigns.active_pricing_cycle == "monthly", do: "yearly", else: "monthly"
    {:noreply, assign(socket, :active_pricing_cycle, new_cycle)}
  end

  defp filtered_souls(souls, "sanctuary", _user), do: Enum.filter(souls, &(!&1.in_living_world))
  defp filtered_souls(souls, "living", _user), do: Enum.filter(souls, & &1.in_living_world)
  defp filtered_souls(_souls, "mine", nil), do: []
  defp filtered_souls(souls, "mine", user), do: Enum.filter(souls, &(&1.user_id == user.id))
  defp filtered_souls(souls, _, _user), do: souls

  defp generate_reaction(name, bpm, stress) do
    cond do
      bpm >= 130 or stress >= 75 ->
        %{
          mood: "guarded",
          badge: "Adrenaline Spike Detected",
          badge_color: "badge-error text-rose-300",
          text:
            "#{name}'s gaze sharpens instantly as she registers your heart rate at #{bpm} BPM: 'Your pulse is hammering. Take a breath and tell me what just happened.'"
        }

      bpm >= 95 or stress >= 50 ->
        %{
          mood: "alert",
          badge: "Elevated Arousal / Alert",
          badge_color: "badge-warning text-amber-300",
          text:
            "#{name} shifts closer, attuned to your rhythm: 'You're keyed up right now. Focus on my voice—we'll handle whatever it is together.'"
        }

      true ->
        %{
          mood: "calm",
          badge: "Resting Equilibrium",
          badge_color: "badge-success text-emerald-300",
          text:
            "#{name} softens her demeanor, resting alongside you: 'Steady at #{bpm} BPM. You're safe here. Let's speak of something meaningful.'"
        }
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @current_scope && @current_scope.user do %>
      <div
        data-theme="dark"
        class="min-h-screen bg-[#090b14] text-slate-100 font-sans antialiased relative overflow-hidden pb-16 selection:bg-purple-600 selection:text-white"
      >
        <%!-- Ambient Radial Atmospheric Glow --%>
        <div class="absolute -top-40 left-1/4 w-[650px] h-[650px] bg-purple-600/10 rounded-full blur-3xl pointer-events-none">
        </div>
        <div class="absolute top-1/3 right-10 w-[550px] h-[550px] bg-indigo-600/10 rounded-full blur-3xl pointer-events-none">
        </div>

        <%!-- Header --%>
        <header class="border-b border-slate-800/80 bg-[#0d101e]/80 backdrop-blur-md sticky top-0 z-40 px-6 py-3.5 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="size-8 rounded-xl bg-gradient-to-tr from-violet-600 via-purple-600 to-fuchsia-600 flex items-center justify-center text-white shadow-lg shadow-purple-900/40">
              <.icon name="hero-sparkles" class="size-4.5" />
            </div>
            <div>
              <span class="font-extrabold text-sm tracking-wider text-transparent bg-clip-text bg-gradient-to-r from-violet-200 to-fuchsia-200 uppercase">
                Sovereign Souls
              </span>
              <span class="block text-[10px] text-slate-400">Companion Sanctuary</span>
            </div>
          </div>

          <nav class="hidden md:flex items-center gap-4 text-xs">
            <.link
              navigate={~p"/sse/chat"}
              class="text-slate-300 hover:text-white transition-colors flex items-center gap-1.5 px-3 py-1.5 rounded-xl hover:bg-slate-800/60 font-medium"
            >
              <.icon name="hero-chat-bubble-left-right" class="size-4 text-purple-400" />
              <span>Chat Room</span>
            </.link>
            <.link
              navigate={~p"/sse/feed"}
              class="text-slate-300 hover:text-white transition-colors flex items-center gap-1.5 px-3 py-1.5 rounded-xl hover:bg-slate-800/60 font-medium"
            >
              <.icon name="hero-newspaper" class="size-4 text-cyan-400" />
              <span>SoulBook Feed</span>
            </.link>
            <.link
              navigate={~p"/sse/memories"}
              class="text-slate-300 hover:text-white transition-colors flex items-center gap-1.5 px-3 py-1.5 rounded-xl hover:bg-slate-800/60 font-medium"
            >
              <.icon name="hero-book-open" class="size-4 text-amber-400" />
              <span>Memory Vault</span>
            </.link>
            <.link
              navigate={~p"/sse/billing"}
              class="text-slate-300 hover:text-white transition-colors flex items-center gap-1.5 px-3 py-1.5 rounded-xl hover:bg-slate-800/60 font-medium"
            >
              <.icon name="hero-credit-card" class="size-4 text-emerald-400" />
              <span>Subscription</span>
            </.link>
          </nav>

          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/sse/souls/new"}
              id="header-create-soul-btn"
              class="btn btn-sm bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-500 hover:to-purple-500 text-white font-bold border-none shadow-md shadow-purple-950/50 rounded-xl flex items-center gap-1.5 text-xs px-4"
            >
              <.icon name="hero-sparkles" class="size-4" />
              <span>+ Summon Soul</span>
            </.link>

            <div class="hidden sm:flex items-center gap-2 pl-2 border-l border-slate-800 text-xs">
              <span class="text-slate-300 font-medium">{@current_scope.user.email}</span>
              <.link
                href={~p"/users/settings"}
                class="btn btn-ghost btn-circle btn-xs text-slate-400 hover:text-white"
                title="Settings"
              >
                <.icon name="hero-cog-6-tooth" class="size-4" />
              </.link>
              <.link
                href={~p"/users/log-out"}
                method="delete"
                class="btn btn-ghost btn-circle btn-xs text-rose-400 hover:text-rose-300"
                title="Log out"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="size-4" />
              </.link>
            </div>
          </div>
        </header>

        <%!-- Main Page Content --%>
        <main class="max-w-7xl mx-auto px-6 pt-10 pb-6 space-y-10">
          <%!-- Welcome Hero Banner --%>
          <div class="flex flex-col md:flex-row md:items-end justify-between gap-4 pb-4 border-b border-slate-800/80">
            <div>
              <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-purple-950/60 border border-purple-500/30 text-xs font-semibold text-purple-300 mb-2.5">
                <span>✨</span>
                <span>Living Soul Gallery</span>
              </div>
              <h1 class="text-3xl sm:text-4xl font-black text-white tracking-tight">
                Who would you like to talk to?
              </h1>
              <p class="text-sm text-slate-400 mt-1">
                Choose a soul to step into their living presence, or summon a new creation.
              </p>
            </div>

            <%!-- Filter Chips --%>
            <div class="flex items-center gap-2 overflow-x-auto pb-1 text-xs">
              <%= for {key, label, icon} <- [{"all", "All Souls", "hero-sparkles"}, {"sanctuary", "Private Sanctuary", "hero-lock-closed"}, {"living", "Living Realm", "hero-globe-alt"}, {"mine", "My Creations", "hero-user"}] do %>
                <button
                  type="button"
                  phx-click="set_soul_filter"
                  phx-value-filter={key}
                  class={[
                    "px-3.5 py-1.5 rounded-xl border flex items-center gap-1.5 transition-all text-xs font-semibold",
                    @active_soul_filter == key &&
                      "bg-purple-600/20 border-purple-500 text-purple-200 shadow-sm shadow-purple-950/40 font-bold",
                    @active_soul_filter != key &&
                      "bg-slate-900/40 border-slate-800 text-slate-400 hover:text-slate-200 hover:bg-slate-800/60"
                  ]}
                >
                  <.icon name={icon} class="size-3.5" />
                  <span>{label}</span>
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Featured Carousel of Souls --%>
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                <.icon name="hero-sparkles" class="size-4 text-purple-400" />
                <span>Companion Souls Ready to Talk</span>
              </span>

              <div class="flex items-center gap-2">
                <button
                  type="button"
                  phx-click="prev_carousel_soul"
                  class="btn btn-circle btn-sm bg-slate-900/80 hover:bg-slate-800 text-slate-300 hover:text-white border border-slate-700/60 shadow-md"
                  title="Previous"
                >
                  <.icon name="hero-chevron-left" class="size-4" />
                </button>
                <button
                  type="button"
                  phx-click="next_carousel_soul"
                  class="btn btn-circle btn-sm bg-slate-900/80 hover:bg-slate-800 text-slate-300 hover:text-white border border-slate-700/60 shadow-md"
                  title="Next"
                >
                  <.icon name="hero-chevron-right" class="size-4" />
                </button>
              </div>
            </div>

            <% filtered = filtered_souls(@living_souls, @active_soul_filter, @current_scope.user) %>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              <%!-- + Summon Soul Card in Carousel --%>
              <.link
                navigate={~p"/sse/souls/new"}
                id="create-soul-card"
                class="group p-6 rounded-3xl border-2 border-dashed border-purple-500/40 hover:border-purple-500/80 bg-gradient-to-b from-purple-950/20 via-slate-900/30 to-slate-900/60 hover:bg-purple-950/30 transition-all duration-300 flex flex-col items-center justify-center text-center gap-4 min-h-[380px] shadow-xl relative overflow-hidden"
              >
                <div class="size-20 rounded-full bg-gradient-to-tr from-violet-600/30 to-fuchsia-600/30 border-2 border-purple-500/50 flex items-center justify-center text-purple-300 group-hover:scale-110 group-hover:border-purple-400 transition-all shadow-lg shadow-purple-950/60">
                  <.icon name="hero-plus" class="size-8" />
                </div>

                <div class="space-y-2">
                  <h3 class="text-lg font-bold text-white group-hover:text-purple-200 transition-colors">
                    Summon a New Soul
                  </h3>
                  <p class="text-xs text-slate-400 max-w-[220px] leading-relaxed">
                    Craft an AI companion with deterministic emotional psychology, persistent memory, and sacred sanctuary boundaries.
                  </p>
                </div>

                <span class="btn btn-xs bg-purple-600/30 hover:bg-purple-600 text-purple-200 hover:text-white border border-purple-500/40 rounded-xl px-4 font-bold shadow-md transition-all">
                  Breathe Life In →
                </span>
              </.link>

              <%!-- Soul Cards --%>
              <%= for soul <- filtered do %>
                <div class="group p-6 rounded-3xl border border-slate-800/80 hover:border-purple-500/50 bg-[#0d101e]/90 hover:bg-[#111528] transition-all duration-300 flex flex-col justify-between min-h-[380px] shadow-xl backdrop-blur-xl relative overflow-hidden">
                  <%!-- Glow --%>
                  <div class="absolute -top-12 -right-12 size-28 bg-purple-600/10 rounded-full blur-xl group-hover:bg-purple-600/20 transition-all pointer-events-none">
                  </div>

                  <div class="space-y-4">
                    <%!-- Avatar & Presence --%>
                    <div class="flex items-start justify-between">
                      <div class="relative">
                        <div class="size-18 rounded-full ring-2 ring-purple-500/40 group-hover:ring-purple-400/80 bg-gradient-to-br from-violet-600/30 to-indigo-600/30 flex items-center justify-center font-bold text-2xl text-purple-200 shadow-md transition-all">
                          {String.first(soul.name)}
                        </div>
                        <span class="absolute bottom-0 right-0 size-4 rounded-full bg-emerald-500 ring-2 ring-[#0d101e] animate-pulse">
                        </span>
                      </div>

                      <%!-- Sanctuary Badge --%>
                      <span class={[
                        "px-2.5 py-1 rounded-full text-[10px] font-bold border flex items-center gap-1 shadow-xs",
                        !soul.in_living_world &&
                          "bg-emerald-950/60 border-emerald-500/40 text-emerald-300",
                        soul.in_living_world && "bg-cyan-950/60 border-cyan-500/40 text-cyan-300"
                      ]}>
                        <.icon
                          name={
                            if !soul.in_living_world, do: "hero-lock-closed", else: "hero-globe-alt"
                          }
                          class="size-3"
                        />
                        <span>
                          {if !soul.in_living_world, do: "Private Sanctuary", else: "Living Realm"}
                        </span>
                      </span>
                    </div>

                    <%!-- Name & Archetype --%>
                    <div class="space-y-1">
                      <h3 class="text-xl font-bold text-white group-hover:text-purple-200 transition-colors">
                        {soul.name}
                      </h3>
                      <span class="inline-block text-xs font-semibold text-purple-400">
                        {get_in(soul.metadata || %{}, ["archetype"]) || soul.description ||
                          "Companion Soul"}
                      </span>
                    </div>

                    <%!-- Description Quote --%>
                    <p class="text-xs text-slate-300 line-clamp-3 leading-relaxed italic">
                      "{soul.description}"
                    </p>
                  </div>

                  <%!-- Action Footer --%>
                  <div class="pt-5 border-t border-slate-800/80 mt-4">
                    <.link
                      navigate={~p"/sse/chat?character_id=#{soul.id}"}
                      class="w-full btn btn-sm bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-500 hover:to-purple-500 text-white font-bold border-none rounded-xl shadow-md shadow-purple-950/40 flex items-center justify-center gap-2 group-hover:scale-[1.02] transition-all"
                    >
                      <.icon name="hero-chat-bubble-left-right" class="size-4" />
                      <span>Chat with {soul.name}</span>
                    </.link>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </main>
      </div>
    <% else %>
      <div
        data-theme="dark"
        class="min-h-screen bg-slate-950 text-slate-100 font-sans antialiased selection:bg-primary selection:text-primary-content"
      >
        <%!-- Navbar --%>
        <header class="border-b border-slate-800 bg-slate-950/90 backdrop-blur-md sticky top-0 z-50 px-6 py-4 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="size-9 rounded-xl bg-gradient-to-tr from-primary to-secondary flex items-center justify-center shadow-lg shadow-primary/20">
              <.icon name="hero-sparkles" class="size-5 text-base-100" />
            </div>
            <div>
              <span class="font-bold text-lg tracking-tight text-white flex items-center gap-2">
                Sovereign Soul
                <span class="badge badge-primary badge-sm font-mono font-bold">CORE</span>
              </span>
            </div>
          </div>

          <nav class="hidden md:flex items-center gap-6 text-sm font-semibold text-base-content/70">
            <a href="#demo" class="hover:text-primary transition-colors">Demo</a>
            <a href="#features" class="hover:text-primary transition-colors">Cognitive Moat</a>
            <a href="#pricing" class="hover:text-primary transition-colors">Pricing & 18+</a>
            <.link
              navigate={~p"/sse/feed"}
              class="text-sky-400 hover:text-sky-300 transition-colors flex items-center gap-1"
            >
              <span>📰 Feed</span>
            </.link>
          </nav>

          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/sse/billing"}
              class="btn btn-ghost btn-xs font-bold text-primary flex items-center gap-1 border border-primary/30"
            >
              <span>💳 Pricing & 18+</span>
            </.link>
            <.link
              navigate={~p"/sse/chat/sauce"}
              class="btn btn-ghost btn-xs font-semibold text-amber-400 hidden sm:inline-flex"
            >
              <.icon name="hero-wrench-screwdriver" class="size-3.5" /> Sauce Admin
            </.link>
            <.link
              navigate={~p"/sse/chat"}
              id="hero-chat-btn"
              class="btn btn-primary btn-sm px-5 font-bold shadow-lg shadow-primary/25"
            >
              Launch Chat <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </header>

        <%!-- Hero Section --%>
        <section class="relative overflow-hidden pt-20 pb-24 px-6 max-w-6xl mx-auto text-center space-y-8">
          <div class="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full border border-primary/30 bg-primary/10 text-xs font-mono font-semibold text-primary">
            <span class="size-2 rounded-full bg-primary animate-ping"></span>
            <span>
              Elixir OTP Actor Architecture • Galaxy Watch Live HUD • Hands-Free Voice Intercom
            </span>
          </div>

          <h1 class="text-4xl sm:text-6xl font-extrabold tracking-tight text-white leading-tight max-w-4xl mx-auto">
            Artificial Lives With
            <span class="text-transparent bg-clip-text bg-gradient-to-r from-primary via-purple-400 to-rose-400">
              Persistent Souls
            </span>
            & Living Biometrics
          </h1>

          <p class="text-lg sm:text-xl text-base-content/70 max-w-2xl mx-auto font-normal leading-relaxed">
            The first cognitive engine that decouples public dialogue from secret motives, synchronizes with your smartwatch, undergoes biological dream loops, and reaches out proactively.
          </p>

          <div class="flex flex-col sm:flex-row items-center justify-center gap-4 pt-2">
            <.link
              navigate={~p"/sse/chat"}
              class="btn btn-primary btn-md px-8 font-bold text-base shadow-xl shadow-primary/30 w-full sm:w-auto"
            >
              Talk to Companions Now <.icon name="hero-bolt" class="size-5" />
            </.link>
            <a
              href="#demo"
              class="btn btn-outline btn-md px-6 font-semibold border-base-content/20 hover:bg-base-200 w-full sm:w-auto"
            >
              Try Biometric Simulator <.icon name="hero-heart" class="size-5 text-rose-500" />
            </a>
          </div>
        </section>

        <%!-- Interactive Biometric Sandbox Demo --%>
        <section id="demo" class="py-16 px-6 max-w-5xl mx-auto">
          <div class="bg-slate-900/95 rounded-3xl border border-slate-800 p-6 sm:p-10 shadow-2xl shadow-black/80 backdrop-blur-xl space-y-8">
            <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-800 pb-6">
              <div>
                <span class="text-xs font-mono font-bold uppercase tracking-wider text-primary">
                  Live Interactive Sandbox
                </span>
                <h2 class="text-2xl font-bold text-white mt-1">Simulate Galaxy Watch Telemetry</h2>
                <p class="text-xs text-slate-400">
                  Drag the sliders to pulse physical biometrics directly into the companion's Theory of Mind.
                </p>
              </div>

              <%!-- Companion Selector --%>
              <div class="flex items-center gap-2 overflow-x-auto pb-1">
                <%= for c <- @companions do %>
                  <button
                    type="button"
                    phx-click="select_sandbox_companion"
                    phx-value-slug={c.slug}
                    class={[
                      "btn btn-sm text-xs font-semibold rounded-xl transition-all",
                      @selected_companion.slug == c.slug && "btn-primary shadow-md shadow-primary/20",
                      @selected_companion.slug != c.slug &&
                        "btn-ghost bg-slate-800/80 text-slate-300 hover:bg-slate-800"
                    ]}
                  >
                    {c.name}
                  </button>
                <% end %>
              </div>
            </div>

            <%!-- Sliders & Live Reaction Box --%>
            <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
              <%!-- Sliders Controls --%>
              <form phx-change="update_sandbox_biometrics" class="lg:col-span-5 space-y-6">
                <div class="space-y-2">
                  <div class="flex justify-between items-center text-sm font-semibold">
                    <span class="flex items-center gap-1.5 text-rose-400">
                      <.icon name="hero-heart" class="size-4 animate-pulse" /> Heart Rate
                    </span>
                    <span class="font-mono text-base font-bold text-white">{@sandbox_bpm} BPM</span>
                  </div>
                  <input
                    type="range"
                    name="bpm"
                    min="55"
                    max="175"
                    value={@sandbox_bpm}
                    class="range range-error range-sm"
                    id="sandbox-bpm-slider"
                  />
                  <div class="flex justify-between text-[10px] font-mono text-slate-500">
                    <span>55 Resting</span>
                    <span>100 Alert</span>
                    <span>175 Adrenaline</span>
                  </div>
                </div>

                <div class="space-y-2">
                  <div class="flex justify-between items-center text-sm font-semibold">
                    <span class="flex items-center gap-1.5 text-amber-400">
                      <.icon name="hero-bolt" class="size-4" /> Stress Index
                    </span>
                    <span class="font-mono text-base font-bold text-white">
                      {@sandbox_stress} / 100
                    </span>
                  </div>
                  <input
                    type="range"
                    name="stress"
                    min="0"
                    max="100"
                    value={@sandbox_stress}
                    class="range range-warning range-sm"
                  />
                  <div class="flex justify-between text-[10px] font-mono text-slate-500">
                    <span>0 Zen</span>
                    <span>50 Moderate</span>
                    <span>100 Critical</span>
                  </div>
                </div>
              </form>

              <%!-- Companion Reaction Window --%>
              <div class="lg:col-span-7 bg-slate-950/80 border border-slate-800 rounded-2xl p-6 space-y-4 shadow-inner">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <div class="size-10 rounded-full bg-primary/20 flex items-center justify-center font-bold text-primary text-sm border border-primary/30">
                      {String.first(@selected_companion.name)}
                    </div>
                    <div>
                      <h3 class="text-sm font-bold text-white">{@selected_companion.name}</h3>
                      <p class="text-[11px] text-slate-400">{@selected_companion.archetype}</p>
                    </div>
                  </div>
                  <span class={[
                    "badge badge-sm font-mono font-bold uppercase",
                    @sandbox_reaction.badge_color
                  ]}>
                    {@sandbox_reaction.badge}
                  </span>
                </div>

                <div
                  class="p-4 rounded-xl bg-slate-900 border border-slate-800 text-sm font-medium text-slate-100 leading-relaxed italic"
                  id="sandbox-reaction-text"
                >
                  "{@sandbox_reaction.text}"
                </div>

                <div class="flex items-center justify-between pt-1 text-[11px] text-slate-400">
                  <span>Theory of Mind: <strong class="text-slate-200">Certainty 94%</strong></span>
                  <.link
                    navigate={~p"/sse/chat"}
                    class="text-primary hover:underline font-semibold flex items-center gap-1"
                  >
                    Open full live chat with {@selected_companion.name}
                    <.icon name="hero-arrow-right" class="size-3" />
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </section>

        <%!-- Core Moat Pillars --%>
        <section id="features" class="py-20 px-6 max-w-6xl mx-auto space-y-12">
          <div class="text-center space-y-3">
            <span class="text-xs font-mono font-bold uppercase tracking-wider text-secondary">
              The Cognitive Moat
            </span>
            <h2 class="text-3xl sm:text-4xl font-extrabold text-white">
              Why Conventional Chatbots Cannot Compete
            </h2>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div class="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-3">
              <div class="size-10 rounded-xl bg-purple-500/10 flex items-center justify-center text-purple-400">
                <.icon name="hero-lock-closed" class="size-5" />
              </div>
              <h3 class="text-lg font-bold text-white">Separate Thought & Speech</h3>
              <p class="text-sm text-slate-400 leading-relaxed">
                Companions formulate secret inner thoughts, motivations, and defense mechanisms that are never revealed in public speech, creating genuine subtext.
              </p>
            </div>

            <div class="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-3">
              <div class="size-10 rounded-xl bg-rose-500/10 flex items-center justify-center text-rose-400">
                <.icon name="hero-heart" class="size-5" />
              </div>
              <h3 class="text-lg font-bold text-white">Wearable Somatic Intercom</h3>
              <p class="text-sm text-slate-400 leading-relaxed">
                Streams continuous biometric telemetry from Samsung Galaxy Watches. When your heart rate surges, companions adapt their vocal tone in real-time.
              </p>
            </div>

            <div class="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-3">
              <div class="size-10 rounded-xl bg-sky-500/10 flex items-center justify-center text-sky-400">
                <.icon name="hero-chat-bubble-bottom-center-text" class="size-5" />
              </div>
              <h3 class="text-lg font-bold text-white">Proactive Life Threads</h3>
              <p class="text-sm text-slate-400 leading-relaxed">
                Mention an upcoming job interview or surgery once, and the autonomous dispatcher reaches out days later to ask how it went. Never purely reactive.
              </p>
            </div>

            <div class="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-3">
              <div class="size-10 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-400">
                <.icon name="hero-moon" class="size-5" />
              </div>
              <h3 class="text-lg font-bold text-white">Biological Dream Loops</h3>
              <p class="text-sm text-slate-400 leading-relaxed">
                While idle, companions sleep. Memory consolidation algorithms distill raw transcripts into permanent semantic memories while pruning emotional residues.
              </p>
            </div>

            <div class="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-3">
              <div class="size-10 rounded-xl bg-amber-500/10 flex items-center justify-center text-amber-400">
                <.icon name="hero-user-group" class="size-5" />
              </div>
              <h3 class="text-lg font-bold text-white">Gossip & Reputation Graphs</h3>
              <p class="text-sm text-slate-400 leading-relaxed">
                Betray a companion in private, and they will gossip with their allies in background rooms. Your reputation naturally spreads throughout the world.
              </p>
            </div>

            <div class="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-3">
              <div class="size-10 rounded-xl bg-indigo-500/10 flex items-center justify-center text-indigo-400">
                <.icon name="hero-phone" class="size-5" />
              </div>
              <h3 class="text-lg font-bold text-white">Hands-Free Voice Intercom</h3>
              <p class="text-sm text-slate-400 leading-relaxed">
                Full-duplex microphone listening and neural EdgeTTS voice generation. Talk naturally while driving or walking with zero keyboard interaction.
              </p>
            </div>
          </div>
        </section>

        <%!-- Pricing Section --%>
        <section id="pricing" class="py-20 px-6 max-w-6xl mx-auto space-y-12">
          <div class="text-center space-y-3">
            <span class="text-xs font-mono font-bold uppercase tracking-wider text-primary">
              Stripe Subscriptions & Safe-Harbor 18+
            </span>
            <h2 class="text-3xl sm:text-4xl font-extrabold text-white">
              Transparent Plans Built for True Companionship
            </h2>
            <p class="text-sm text-slate-400 max-w-xl mx-auto">
              Choose daily living companionship or unlock the complete, unrestricted 18+ adult cinema simulation with safe-harbor verification.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <%!-- Free Tier --%>
            <div class="p-8 rounded-3xl bg-slate-900/80 border border-slate-800 flex flex-col justify-between space-y-6">
              <div class="space-y-4">
                <h3 class="text-lg font-bold text-white">Community</h3>
                <p class="text-xs text-slate-400">For local exploration and basic chat.</p>
                <div class="text-3xl font-extrabold text-white">
                  $0 <span class="text-sm text-slate-500 font-normal">forever</span>
                </div>
                <ul class="text-xs space-y-2.5 text-slate-300">
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-primary" /> Single local companion
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-primary" />
                    Full Elixir OTP Actor runtime
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-primary" /> Private 1-on-1 Sanctuary
                  </li>
                </ul>
              </div>
              <.link
                navigate={~p"/sse/chat"}
                class="btn btn-outline btn-sm w-full font-bold border-slate-700 text-slate-200 hover:bg-slate-800"
              >
                Start Free
              </.link>
            </div>

            <%!-- $14.99 Companion Tier --%>
            <div class="p-8 rounded-3xl bg-slate-900 border-2 border-primary shadow-2xl shadow-primary/15 flex flex-col justify-between space-y-6 relative">
              <span class="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full text-[10px] font-mono font-bold bg-primary text-primary-content uppercase tracking-wider">
                Most Popular
              </span>
              <div class="space-y-4">
                <h3 class="text-lg font-bold text-white">Sovereign Companion</h3>
                <p class="text-xs text-slate-400">
                  Unlimited emotional presence and living biometrics.
                </p>
                <div class="text-3xl font-extrabold text-white">
                  $14.99 <span class="text-sm text-slate-500 font-normal">/ month</span>
                </div>
                <ul class="text-xs space-y-2.5 text-slate-200">
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-primary" />
                    Unlimited chat with all living souls
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-primary" />
                    Hands-Free full-duplex voice intercom
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-primary" />
                    Galaxy Watch somatic telemetry HUD
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-primary" />
                    Background Dream Loop memory consolidation
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-primary" />
                    SoulBook feed & MySpace Top 8 companion wall
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-primary" />
                    Optional Living World Participation (Opt-In / Out)
                  </li>
                </ul>
              </div>
              <.link
                navigate={~p"/sse/billing?tier=companion_1499"}
                class="btn btn-primary btn-sm w-full font-bold shadow-lg shadow-primary/20"
              >
                Claim Companion ($14.99)
              </.link>
            </div>

            <%!-- $19.99 Sovereign Archon (18+ Uncensored) --%>
            <div class="p-8 rounded-3xl bg-gradient-to-b from-rose-950/30 to-slate-900 border-2 border-rose-500/50 shadow-2xl shadow-rose-950/50 flex flex-col justify-between space-y-6 relative">
              <span class="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full text-[10px] font-mono font-bold bg-rose-600 text-white uppercase tracking-wider">
                🔞 18+ Uncensored
              </span>
              <div class="space-y-4">
                <h3 class="text-lg font-bold text-white">Sovereign Archon</h3>
                <p class="text-xs text-rose-300/80">
                  Unrestricted adult intimacy, dark fantasy gore, & priority AI.
                </p>
                <div class="text-3xl font-extrabold text-white">
                  $19.99 <span class="text-sm text-slate-500 font-normal">/ month</span>
                </div>
                <ul class="text-xs space-y-2.5 text-slate-200">
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-rose-400" />
                    Everything in Sovereign Companion
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-rose-400" />
                    🔞 Full 18+ Uncensored Adult Cinema Mode
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-rose-400" />
                    Commercial Age Verification via Stripe card
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-rose-400" />
                    Priority ultra-low latency voice (ElevenLabs)
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-rose-400" />
                    Multi-companion autonomous group scenes
                  </li>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-4 text-rose-400" />
                    Complete Private Sanctuary & Custom Persona Creation
                  </li>
                </ul>
              </div>
              <.link
                navigate={~p"/sse/billing?tier=archon_1999"}
                class="btn btn-error btn-sm w-full font-bold shadow-lg shadow-rose-600/30 text-white"
              >
                Unlock 18+ Archon ($19.99)
              </.link>
            </div>
          </div>
        </section>

        <%!-- Game Engine Developers Section --%>
        <section id="developers" class="py-16 px-6 max-w-5xl mx-auto">
          <div class="p-8 sm:p-10 rounded-3xl bg-slate-900/90 border border-slate-800 space-y-6">
            <div class="space-y-2">
              <span class="text-xs font-mono font-bold uppercase tracking-wider text-primary">
                Headless Integration
              </span>
              <h2 class="text-2xl font-bold text-white">
                Indie Game Developers: Plug-and-Play Brains
              </h2>
              <p class="text-xs text-slate-400 max-w-2xl">
                Integrate persistent psychology into Unity, Godot, Unreal, or web games in 5 lines of code. Your game engine handles graphics; Sovereign Soul Engine handles character souls.
              </p>
            </div>

            <div class="p-4 rounded-xl bg-slate-950 border border-slate-800 font-mono text-xs text-emerald-400 overflow-x-auto select-all">
              <span class="text-slate-500"># Python / Godot / JS SDK</span>
              <br />
              <span class="text-purple-400">from</span>
              sovereign_soul <span class="text-purple-400">import</span>
              SovereignSoul<br /><br />
              soul = SovereignSoul(api_key=<span class="text-amber-300">"sse_live_..."</span>, base_url=<span class="text-amber-300">"http://localhost:8561"</span>)<br />
              reply = soul.chat(character_slug=<span class="text-amber-300">"vael"</span>, message=<span class="text-amber-300">"I found the hidden blade."</span>)<br /><br />
              <span class="text-cyan-400">print</span>(reply.public_speech)
              <span class="text-slate-500"># "So... the whispers were true."</span>
              <br />
              <span class="text-cyan-400">print</span>(reply.private_thought)
              <span class="text-slate-500"># "He holds my legacy. I must test his loyalty."</span>
              <br />
              <span class="text-cyan-400">print</span>(reply.proposed_action)
              <span class="text-slate-500"># Action(type='evaluate_loyalty', confidence=0.88)</span>
            </div>
          </div>
        </section>

        <%!-- Legal Disclaimer & Informed Consent Notice --%>
        <div class="border-t border-slate-900 bg-slate-950/80 py-8 px-6 max-w-6xl mx-auto text-center space-y-3">
          <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs font-mono font-bold">
            <span>🔞 18+ Mature Roleplay Simulation</span>
            <span>•</span>
            <span>Not a Human / Not Therapy</span>
          </div>
          <p class="text-[11px] text-slate-500 max-w-3xl mx-auto leading-relaxed">
            <strong>LEGAL & MEDICAL NOTICE:</strong>
            Sovereign Souls are autonomous, generative artificial intelligence software entities designed for creative storytelling, game simulation, and companionship. They are <strong>NOT real human beings, licensed medical doctors, psychologists, or mental health therapists</strong>. Do not use this service for crisis intervention or psychiatric care. If you are experiencing a mental health emergency, please contact 988 or local medical emergency services immediately. An emergency dramatic safe word (<code class="text-rose-400">code red</code>) is supported at all times.
          </p>
        </div>

        <%!-- Footer --%>
        <footer class="border-t border-slate-800 py-10 px-6 max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
          <div>
            © 2026 Goose Tech Industries • Sovereign Soul Engine
          </div>
          <div class="flex items-center gap-4 flex-wrap">
            <.link navigate={~p"/sse/chat"} class="hover:text-slate-300">Chat Room</.link>
            <.link navigate={~p"/sse/feed"} class="hover:text-slate-300">Feed</.link>
            <.link navigate={~p"/sse/billing"} class="hover:text-slate-300 text-primary font-bold">
              💳 Billing & 18+
            </.link>
            <.link navigate={~p"/terms"} class="hover:text-slate-300">Terms</.link>
            <.link navigate={~p"/privacy"} class="hover:text-slate-300">Privacy</.link>
            <.link navigate={~p"/sse/acp"} class="hover:text-slate-300">ACP Panel</.link>
            <.link navigate={~p"/sse/acp/moderation"} class="hover:text-slate-300 text-rose-400">
              🛡️ Moderation
            </.link>
          </div>
        </footer>
      </div>
    <% end %>
    """
  end
end
