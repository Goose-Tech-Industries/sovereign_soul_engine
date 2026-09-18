defmodule SovereignSoulEngineWeb.LandingLive do
  use SovereignSoulEngineWeb, :live_view



  @impl true
  def mount(_params, _session, socket) do
    companions = [
      %{slug: "maya", name: "Maya", archetype: "Empathetic Tactician", quote: "I notice how your pulse slows when you're actually telling the truth."},
      %{slug: "ravina", name: "Ravina", archetype: "Cynical Enforcer", quote: "Betrayal leaves scars. Earn my respect, or keep your distance."},
      %{slug: "valeria", name: "Valeria", archetype: "Philosopher Witch", quote: "The dream loop cleanses our memories, but your essence remains."},
      %{slug: "cyra", name: "Cyra", archetype: "Adaptive Technologist", quote: "Telemetric parity reached. All biometrics synchronized."}
    ]

    selected_companion = hd(companions)

    socket =
      socket
      |> assign(:page_title, "Sovereign Soul Engine — Artificial Lives with True Souls")
      |> assign(:companions, companions)
      |> assign(:selected_companion, selected_companion)
      |> assign(:sandbox_bpm, 74)
      |> assign(:sandbox_stress, 20)
      |> assign(:sandbox_reaction, generate_reaction(selected_companion.name, 74, 20))
      |> assign(:active_pricing_cycle, "monthly")

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_event("select_sandbox_companion", %{"slug" => slug}, socket) do
    companion = Enum.find(socket.assigns.companions, &(&1.slug == slug)) || socket.assigns.selected_companion
    reaction = generate_reaction(companion.name, socket.assigns.sandbox_bpm, socket.assigns.sandbox_stress)

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

  defp generate_reaction(name, bpm, stress) do
    cond do
      bpm >= 130 or stress >= 75 ->
        %{
          mood: "guarded",
          badge: "Adrenaline Spike Detected",
          badge_color: "badge-error text-rose-300",
          text: "#{name}'s gaze sharpens instantly as she registers your heart rate at #{bpm} BPM: 'Your pulse is hammering. Take a breath and tell me what just happened.'"
        }

      bpm >= 95 or stress >= 50 ->
        %{
          mood: "alert",
          badge: "Elevated Arousal / Alert",
          badge_color: "badge-warning text-amber-300",
          text: "#{name} shifts closer, attuned to your rhythm: 'You're keyed up right now. Focus on my voice—we'll handle whatever it is together.'"
        }

      true ->
        %{
          mood: "calm",
          badge: "Resting Equilibrium",
          badge_color: "badge-success text-emerald-300",
          text: "#{name} softens her demeanor, resting alongside you: 'Steady at #{bpm} BPM. You're safe here. Let's speak of something meaningful.'"
        }
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="dark" class="min-h-screen bg-slate-950 text-slate-100 font-sans antialiased selection:bg-primary selection:text-primary-content">
      <%!-- Navbar --%>
      <header class="border-b border-slate-800 bg-slate-950/90 backdrop-blur-md sticky top-0 z-50 px-6 py-4 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="size-9 rounded-xl bg-gradient-to-tr from-primary to-secondary flex items-center justify-center shadow-lg shadow-primary/20">
            <.icon name="hero-sparkles" class="size-5 text-base-100" />
          </div>
          <div>
            <span class="font-bold text-lg tracking-tight text-white flex items-center gap-2">
              Sovereign Soul <span class="badge badge-primary badge-sm font-mono font-bold">CORE</span>
            </span>
          </div>
        </div>

        <nav class="hidden md:flex items-center gap-6 text-sm font-semibold text-base-content/70">
          <a href="#demo" class="hover:text-primary transition-colors">Demo</a>
          <a href="#features" class="hover:text-primary transition-colors">Cognitive Moat</a>
          <a href="#pricing" class="hover:text-primary transition-colors">Pricing & 18+</a>
          <.link navigate={~p"/sse/map"} class="text-amber-400 hover:text-amber-300 transition-colors flex items-center gap-1">
            <span>🏰 Town Map</span>
          </.link>
          <.link navigate={~p"/sse/feed"} class="text-sky-400 hover:text-sky-300 transition-colors flex items-center gap-1">
            <span>📰 Feed</span>
          </.link>
        </nav>

        <div class="flex items-center gap-3">
          <.link navigate={~p"/sse/billing"} class="btn btn-ghost btn-xs font-bold text-primary flex items-center gap-1 border border-primary/30">
            <span>💳 Pricing & 18+</span>
          </.link>
          <.link navigate={~p"/sse/chat/sauce"} class="btn btn-ghost btn-xs font-semibold text-amber-400 hidden sm:inline-flex">
            <.icon name="hero-wrench-screwdriver" class="size-3.5" /> Sauce Admin
          </.link>
          <.link navigate={~p"/sse/chat"} id="hero-chat-btn" class="btn btn-primary btn-sm px-5 font-bold shadow-lg shadow-primary/25">
            Launch Chat <.icon name="hero-arrow-right" class="size-4" />
          </.link>
        </div>
      </header>

      <%!-- Hero Section --%>
      <section class="relative overflow-hidden pt-20 pb-24 px-6 max-w-6xl mx-auto text-center space-y-8">
        <div class="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full border border-primary/30 bg-primary/10 text-xs font-mono font-semibold text-primary">
          <span class="size-2 rounded-full bg-primary animate-ping"></span>
          <span>Elixir OTP Actor Architecture • Galaxy Watch Live HUD • Hands-Free Voice Intercom</span>
        </div>

        <h1 class="text-4xl sm:text-6xl font-extrabold tracking-tight text-white leading-tight max-w-4xl mx-auto">
          Artificial Lives With <span class="text-transparent bg-clip-text bg-gradient-to-r from-primary via-purple-400 to-rose-400">Persistent Souls</span> & Living Biometrics
        </h1>

        <p class="text-lg sm:text-xl text-base-content/70 max-w-2xl mx-auto font-normal leading-relaxed">
          The first cognitive engine that decouples public dialogue from secret motives, synchronizes with your smartwatch, undergoes biological dream loops, and reaches out proactively.
        </p>

        <div class="flex flex-col sm:flex-row items-center justify-center gap-4 pt-2">
          <.link navigate={~p"/sse/chat"} class="btn btn-primary btn-md px-8 font-bold text-base shadow-xl shadow-primary/30 w-full sm:w-auto">
            Talk to Companions Now <.icon name="hero-bolt" class="size-5" />
          </.link>
          <a href="#demo" class="btn btn-outline btn-md px-6 font-semibold border-base-content/20 hover:bg-base-200 w-full sm:w-auto">
            Try Biometric Simulator <.icon name="hero-heart" class="size-5 text-rose-500" />
          </a>
        </div>
      </section>

      <%!-- Interactive Biometric Sandbox Demo --%>
      <section id="demo" class="py-16 px-6 max-w-5xl mx-auto">
        <div class="bg-slate-900/95 rounded-3xl border border-slate-800 p-6 sm:p-10 shadow-2xl shadow-black/80 backdrop-blur-xl space-y-8">
          <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-800 pb-6">
            <div>
              <span class="text-xs font-mono font-bold uppercase tracking-wider text-primary">Live Interactive Sandbox</span>
              <h2 class="text-2xl font-bold text-white mt-1">Simulate Galaxy Watch Telemetry</h2>
              <p class="text-xs text-slate-400">Drag the sliders to pulse physical biometrics directly into the companion's Theory of Mind.</p>
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
                    @selected_companion.slug != c.slug && "btn-ghost bg-slate-800/80 text-slate-300 hover:bg-slate-800"
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
                  <span class="font-mono text-base font-bold text-white">{@sandbox_stress} / 100</span>
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
                <span class={["badge badge-sm font-mono font-bold uppercase", @sandbox_reaction.badge_color]}>
                  {@sandbox_reaction.badge}
                </span>
              </div>

              <div class="p-4 rounded-xl bg-slate-900 border border-slate-800 text-sm font-medium text-slate-100 leading-relaxed italic" id="sandbox-reaction-text">
                "{@sandbox_reaction.text}"
              </div>

              <div class="flex items-center justify-between pt-1 text-[11px] text-slate-400">
                <span>Theory of Mind: <strong class="text-slate-200">Certainty 94%</strong></span>
                <.link navigate={~p"/sse/chat"} class="text-primary hover:underline font-semibold flex items-center gap-1">
                  Open full live chat with {@selected_companion.name} <.icon name="hero-arrow-right" class="size-3" />
                </.link>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Core Moat Pillars --%>
      <section id="features" class="py-20 px-6 max-w-6xl mx-auto space-y-12">
        <div class="text-center space-y-3">
          <span class="text-xs font-mono font-bold uppercase tracking-wider text-secondary">The Cognitive Moat</span>
          <h2 class="text-3xl sm:text-4xl font-extrabold text-white">Why Conventional Chatbots Cannot Compete</h2>
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
          <span class="text-xs font-mono font-bold uppercase tracking-wider text-primary">Stripe Subscriptions & Safe-Harbor 18+</span>
          <h2 class="text-3xl sm:text-4xl font-extrabold text-white">Transparent Plans Built for True Companionship</h2>
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
              <div class="text-3xl font-extrabold text-white">$0 <span class="text-sm text-slate-500 font-normal">forever</span></div>
              <ul class="text-xs space-y-2.5 text-slate-300">
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-primary" /> Single local companion</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-primary" /> Full Elixir OTP Actor runtime</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-primary" /> Feannag's Rest Town Map (preview)</li>
              </ul>
            </div>
            <.link navigate={~p"/sse/chat"} class="btn btn-outline btn-sm w-full font-bold border-slate-700 text-slate-200 hover:bg-slate-800">Start Free</.link>
          </div>

          <%!-- $14.99 Companion Tier --%>
          <div class="p-8 rounded-3xl bg-slate-900 border-2 border-primary shadow-2xl shadow-primary/15 flex flex-col justify-between space-y-6 relative">
            <span class="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full text-[10px] font-mono font-bold bg-primary text-primary-content uppercase tracking-wider">
              Most Popular
            </span>
            <div class="space-y-4">
              <h3 class="text-lg font-bold text-white">Sovereign Companion</h3>
              <p class="text-xs text-slate-400">Unlimited emotional presence and living biometrics.</p>
              <div class="text-3xl font-extrabold text-white">$14.99 <span class="text-sm text-slate-500 font-normal">/ month</span></div>
              <ul class="text-xs space-y-2.5 text-slate-200">
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-primary" /> Unlimited chat with all 50 living souls</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-primary" /> Hands-Free full-duplex voice intercom</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-primary" /> Galaxy Watch somatic telemetry HUD</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-primary" /> Background Dream Loop memory consolidation</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-primary" /> SoulBook feed & MySpace Top 8 companion wall</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-primary" /> Walkable Town Map & proximity encounters</li>
              </ul>
            </div>
            <.link navigate={~p"/sse/billing?tier=companion_1499"} class="btn btn-primary btn-sm w-full font-bold shadow-lg shadow-primary/20">
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
              <p class="text-xs text-rose-300/80">Unrestricted adult intimacy, dark fantasy gore, & priority AI.</p>
              <div class="text-3xl font-extrabold text-white">$19.99 <span class="text-sm text-slate-500 font-normal">/ month</span></div>
              <ul class="text-xs space-y-2.5 text-slate-200">
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-rose-400" /> Everything in Sovereign Companion</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-rose-400" /> 🔞 Full 18+ Uncensored Adult Cinema Mode</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-rose-400" /> Commercial Age Verification via Stripe card</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-rose-400" /> Priority ultra-low latency voice (ElevenLabs)</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-rose-400" /> Multi-companion autonomous group scenes</li>
                <li class="flex items-center gap-2"><.icon name="hero-check" class="size-4 text-rose-400" /> AI World Architect procedural district expansion</li>
              </ul>
            </div>
            <.link navigate={~p"/sse/billing?tier=archon_1999"} class="btn btn-error btn-sm w-full font-bold shadow-lg shadow-rose-600/30 text-white">
              Unlock 18+ Archon ($19.99)
            </.link>
          </div>
        </div>
      </section>

      <%!-- Game Engine Developers Section --%>
      <section id="developers" class="py-16 px-6 max-w-5xl mx-auto">
        <div class="p-8 sm:p-10 rounded-3xl bg-slate-900/90 border border-slate-800 space-y-6">
          <div class="space-y-2">
            <span class="text-xs font-mono font-bold uppercase tracking-wider text-primary">Headless Integration</span>
            <h2 class="text-2xl font-bold text-white">Indie Game Developers: Plug-and-Play Brains</h2>
            <p class="text-xs text-slate-400 max-w-2xl">
              Integrate persistent psychology into Unity, Godot, Unreal, or web games in 5 lines of code. Your game engine handles graphics; Sovereign Soul Engine handles character souls.
            </p>
          </div>

          <div class="p-4 rounded-xl bg-slate-950 border border-slate-800 font-mono text-xs text-emerald-400 overflow-x-auto select-all">
            <span class="text-slate-500"># Python / Godot / JS SDK</span><br/>
            <span class="text-purple-400">from</span> sovereign_soul <span class="text-purple-400">import</span> SovereignSoul<br/><br/>
            soul = SovereignSoul(api_key=<span class="text-amber-300">"sse_live_..."</span>, base_url=<span class="text-amber-300">"http://localhost:8561"</span>)<br/>
            reply = soul.chat(character_slug=<span class="text-amber-300">"vael"</span>, message=<span class="text-amber-300">"I found the hidden blade."</span>)<br/><br/>
            <span class="text-cyan-400">print</span>(reply.public_speech)   <span class="text-slate-500"># "So... the whispers were true."</span><br/>
            <span class="text-cyan-400">print</span>(reply.private_thought) <span class="text-slate-500"># "He holds my legacy. I must test his loyalty."</span><br/>
            <span class="text-cyan-400">print</span>(reply.proposed_action) <span class="text-slate-500"># Action(type='evaluate_loyalty', confidence=0.88)</span>
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
          <strong>LEGAL & MEDICAL NOTICE:</strong> Sovereign Souls are autonomous, generative artificial intelligence software entities designed for creative storytelling, game simulation, and companionship. They are <strong>NOT real human beings, licensed medical doctors, psychologists, or mental health therapists</strong>. Do not use this service for crisis intervention or psychiatric care. If you are experiencing a mental health emergency, please contact 988 or local medical emergency services immediately. An emergency dramatic safe word (<code class="text-rose-400">code red</code>) is supported at all times.
        </p>
      </div>

      <%!-- Footer --%>
      <footer class="border-t border-slate-800 py-10 px-6 max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
        <div>
          © 2026 Goose Tech Industries • Sovereign Soul Engine
        </div>
        <div class="flex items-center gap-4">
          <.link navigate={~p"/sse/chat"} class="hover:text-slate-300">Chat Room</.link>
          <.link navigate={~p"/sse/feed"} class="hover:text-slate-300">Feed</.link>
          <.link navigate={~p"/sse/map"} class="hover:text-slate-300">Town Map</.link>
          <.link navigate={~p"/sse/billing"} class="hover:text-slate-300 text-primary font-bold">💳 Billing & 18+</.link>
          <.link navigate={~p"/sse/acp"} class="hover:text-slate-300">ACP Panel</.link>
          <.link navigate={~p"/sse/acp/moderation"} class="hover:text-slate-300 text-rose-400">🛡️ Moderation</.link>
        </div>
      </footer>
    </div>
    """
  end
end
