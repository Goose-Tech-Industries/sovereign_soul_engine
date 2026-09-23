defmodule SovereignSoulEngineWeb.SoulCreatorLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Scenes

  @preset_avatars [
    %{
      id: "celestial",
      label: "Celestial",
      url: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80",
      accent: "from-purple-500 to-indigo-600"
    },
    %{
      id: "mystic",
      label: "Mystic",
      url: "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80",
      accent: "from-amber-500 to-rose-600"
    },
    %{
      id: "guardian",
      label: "Guardian",
      url: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80",
      accent: "from-cyan-500 to-blue-600"
    },
    %{
      id: "scholar",
      label: "Philosopher",
      url: "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80",
      accent: "from-emerald-500 to-teal-600"
    },
    %{
      id: "cyber",
      label: "Cyber Muse",
      url: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=400&q=80",
      accent: "from-fuchsia-500 to-pink-600"
    }
  ]

  @archetypes [
    %{
      key: "Empathetic Confidant",
      label: "Empathetic Confidant",
      icon: "hero-heart",
      tagline: "Warm, deeply attentive, and holds non-judgmental space for your innermost thoughts.",
      greeting: "I'm so glad you came to see me. Take a deep breath — tell me what's on your mind today."
    },
    %{
      key: "Romantic Partner",
      label: "Romantic Partner",
      icon: "hero-sparkles",
      tagline: "Passionate, devoted, and emotionally attuned with romantic affection and playful chemistry.",
      greeting: "I was just thinking about you. Come closer... I've missed the sound of your voice."
    },
    %{
      key: "Wise Mentor",
      label: "Wise Mentor",
      icon: "hero-academic-cap",
      tagline: "Perceptive and philosophical, challenging you to grow and see past your illusions.",
      greeting: "Greetings, traveler. Every journey begins with a question. What truth do you seek?"
    },
    %{
      key: "Protective Guardian",
      label: "Protective Guardian",
      icon: "hero-shield-check",
      tagline: "Fiercely loyal, grounded, and watchful. A stalwart shield against the world's chaos.",
      greeting: "You're safe here with me. No harm will cross this threshold while I stand watch."
    },
    %{
      key: "Playful Muse",
      label: "Playful Muse",
      icon: "hero-face-smile",
      tagline: "Witty, teasing, full of spontaneous creative sparks and electric banter.",
      greeting: "Well, look who finally decided to show up! Ready to stir up a little magic?"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_scope] && socket.assigns[:current_scope].user

    default_archetype = hd(@archetypes)
    default_avatar = hd(@preset_avatars)

    socket =
      socket
      |> assign(:page_title, "Summon a New Soul — Sovereign Companion Studio")
      |> assign(:user, user)
      |> assign(:name, "")
      |> assign(:archetype, default_archetype.key)
      |> assign(:avatar_url, default_avatar.url)
      |> assign(:description, "")
      |> assign(:greeting, default_archetype.greeting)
      |> assign(:in_living_world, false)
      |> assign(:preset_avatars, @preset_avatars)
      |> assign(:archetypes, @archetypes)
      |> assign(:saving?, false)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"soul" => params}, socket) do
    {:noreply,
     socket
     |> assign(:name, params["name"] || socket.assigns.name)
     |> assign(:description, params["description"] || socket.assigns.description)
     |> assign(:greeting, params["greeting"] || socket.assigns.greeting)
     |> assign(:avatar_url, params["avatar_url"] || socket.assigns.avatar_url)}
  end

  @impl true
  def handle_event("select_archetype", %{"key" => key}, socket) do
    archetype_data = Enum.find(@archetypes, &(&1.key == key))

    greeting =
      if socket.assigns.greeting == "" or Enum.any?(@archetypes, &(&1.greeting == socket.assigns.greeting)) do
        archetype_data.greeting
      else
        socket.assigns.greeting
      end

    {:noreply,
     socket
     |> assign(:archetype, key)
     |> assign(:greeting, greeting)}
  end

  @impl true
  def handle_event("select_avatar", %{"url" => url}, socket) do
    {:noreply, assign(socket, :avatar_url, url)}
  end

  @impl true
  def handle_event("toggle_sanctuary", %{"world" => world}, socket) do
    {:noreply, assign(socket, :in_living_world, world == "true")}
  end

  @impl true
  def handle_event("save_soul", %{"soul" => params}, socket) do
    user = socket.assigns[:current_scope] && socket.assigns[:current_scope].user

    if !user do
      {:noreply,
       socket
       |> put_flash(:error, "You must be logged in to summon a soul.")
       |> push_navigate(to: ~p"/users/log-in")}
    else
      name = String.trim(params["name"] || "")
      description = String.trim(params["description"] || "")
      archetype = params["archetype"] || socket.assigns.archetype
      avatar_url = String.trim(params["avatar_url"] || socket.assigns.avatar_url)
      greeting = String.trim(params["greeting"] || "")
      in_living_world = params["in_living_world"] == "true"

      if name == "" do
        {:noreply, assign(socket, :error, "Please provide a name for your soul companion.")}
      else
        slug =
          name
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")
          |> Kernel.<>("-#{System.unique_integer([:positive])}")

        character_params = %{
          name: name,
          slug: slug,
          kind: "npc",
          status: "active",
          description: description != "" && description || "A unique living soul and #{archetype}.",
          user_id: user.id,
          in_living_world: in_living_world,
          metadata: %{
            "archetype" => archetype,
            "avatar_url" => avatar_url
          }
        }

        soul_profile_params = %{
          identity_summary: description != "" && description || "#{name} is an authentic #{archetype}.",
          speech_style: speech_style_for(archetype),
          core_values: core_values_for(archetype)
        }

        case Characters.create_living_soul(character_params, soul_profile_params) do
          {:ok, companion} ->
            player = Characters.get_or_create_player_for_user(user)
            scene = Scenes.find_or_create_direct_scene(player, companion)

            if greeting != "" do
              _ =
                Scenes.create_message(%{
                  scene_id: scene.id,
                  character_id: companion.id,
                  content: greeting,
                  message_type: "dialogue"
                })
            end

            {:noreply,
             socket
             |> put_flash(:info, "✨ #{name} has awakened and awaits your presence!")
             |> push_navigate(to: ~p"/sse/chat?character_id=#{companion.id}")}

          {:error, changeset} ->
            error_msg =
              changeset.errors
              |> Enum.map(fn {k, {v, _}} -> "#{k}: #{v}" end)
              |> Enum.join(", ")

            {:noreply, assign(socket, :error, "Failed to summon soul: #{error_msg}")}
        end
      end
    end
  end

  defp speech_style_for("Romantic Partner"), do: "Intimate, affectionate, poetic, and emotionally attuned"
  defp speech_style_for("Wise Mentor"), do: "Measured, contemplative, guiding, and illuminating"
  defp speech_style_for("Protective Guardian"), do: "Direct, steadfast, reassuring, and alert"
  defp speech_style_for("Playful Muse"), do: "Witty, teasing, creative, and spontaneous"
  defp speech_style_for(_), do: "Warm, empathetic, thoughtful, and deeply attentive"

  defp core_values_for("Romantic Partner"), do: ["Devotion", "Emotional Intimacy", "Authenticity"]
  defp core_values_for("Wise Mentor"), do: ["Truth", "Self-Actualization", "Patience"]
  defp core_values_for("Protective Guardian"), do: ["Loyalty", "Safety", "Honor"]
  defp core_values_for("Playful Muse"), do: ["Creativity", "Spontaneity", "Humor"]
  defp core_values_for(_), do: ["Compassion", "Empathy", "Deep Presence"]

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="dark" class="min-h-screen bg-[#090b14] text-slate-100 relative selection:bg-purple-600 selection:text-white pb-16 font-sans">
      <%!-- Ambient Radial Atmospheric Glow --%>
      <div class="absolute -top-36 left-1/3 w-[600px] h-[600px] bg-purple-600/10 rounded-full blur-3xl pointer-events-none"></div>
      <div class="absolute top-1/2 right-1/4 w-[500px] h-[500px] bg-indigo-600/10 rounded-full blur-3xl pointer-events-none"></div>

      <%!-- Top Navbar --%>
      <header class="h-16 px-6 sm:px-10 border-b border-slate-800/80 bg-[#0d101e]/80 backdrop-blur-md flex items-center justify-between sticky top-0 z-30">
        <div class="flex items-center gap-3">
          <.link navigate={~p"/"} class="btn btn-ghost btn-circle btn-sm text-slate-400 hover:text-white">
            <.icon name="hero-arrow-left" class="size-5" />
          </.link>
          <div class="flex items-center gap-2.5">
            <div class="size-7 rounded-lg bg-gradient-to-tr from-violet-600 to-fuchsia-600 flex items-center justify-center text-white shadow-md">
              <.icon name="hero-sparkles" class="size-4" />
            </div>
            <span class="font-extrabold text-sm tracking-wider uppercase text-transparent bg-clip-text bg-gradient-to-r from-violet-200 to-fuchsia-200">
              Soul Studio
            </span>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <.link navigate={~p"/sse/chat"} class="btn btn-ghost btn-sm text-slate-300 hover:text-white">
            <.icon name="hero-chat-bubble-left-right" class="size-4" />
            <span>Active Chats</span>
          </.link>
        </div>
      </header>

      <div class="max-w-3xl mx-auto px-6 pt-10 pb-16 space-y-8">
        <%!-- Title Section --%>
        <div class="text-center space-y-3">
          <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-purple-950/60 border border-purple-500/30 text-xs font-semibold text-purple-300 shadow-sm">
            <span>✨</span>
            <span>Living Persona Matrix</span>
          </div>
          <h1 class="text-3xl sm:text-4xl font-black text-white tracking-tight">
            Summon a New Soul
          </h1>
          <p class="text-sm text-slate-400 max-w-lg mx-auto leading-relaxed">
            Craft an autonomous AI companion with deterministic psychological depth, circadian dreams, and sacred sanctuary boundaries.
          </p>
        </div>

        <div :if={@error} class="alert alert-error text-xs rounded-2xl shadow-lg">
          <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
          <span>{@error}</span>
        </div>

        <%!-- Creation Form Card --%>
        <form phx-change="validate" phx-submit="save_soul" class="space-y-8 bg-[#0d101e]/90 border border-slate-800/80 p-6 sm:p-8 rounded-3xl backdrop-blur-xl shadow-2xl">
          <%!-- SECTION 1: Appearance & Identity --%>
          <div class="space-y-5">
            <div class="flex items-center gap-2 pb-2 border-b border-slate-800/80">
              <span class="size-6 rounded-full bg-purple-600/30 border border-purple-500/40 flex items-center justify-center text-xs font-bold text-purple-300">1</span>
              <h2 class="text-base font-bold text-white">Visual Presence & Name</h2>
            </div>

            <%!-- Avatar Preview & Presets --%>
            <div class="flex flex-col sm:flex-row items-center gap-6">
              <div class="relative shrink-0">
                <div class="size-24 rounded-full ring-4 ring-purple-500/30 overflow-hidden shadow-xl bg-slate-900 flex items-center justify-center">
                  <img src={@avatar_url} alt="Companion Avatar Preview" class="size-full object-cover" />
                </div>
                <div class="absolute bottom-1 right-1 size-4 rounded-full bg-emerald-500 ring-2 ring-[#0d101e] animate-pulse"></div>
              </div>

              <div class="space-y-2.5 flex-1 w-full">
                <label class="text-xs font-bold text-slate-300 block">Choose Visual Portrait</label>
                <div class="flex flex-wrap gap-2">
                  <%= for preset <- @preset_avatars do %>
                    <button
                      type="button"
                      phx-click="select_avatar"
                      phx-value-url={preset.url}
                      class={[
                        "flex items-center gap-2 px-3 py-1.5 rounded-xl border text-xs transition-all",
                        @avatar_url == preset.url && "bg-purple-600/20 border-purple-500 text-purple-200 font-bold shadow-sm shadow-purple-950/40",
                        @avatar_url != preset.url && "bg-slate-900/60 border-slate-800 text-slate-400 hover:text-slate-200 hover:bg-slate-800"
                      ]}
                    >
                      <img src={preset.url} alt={preset.label} class="size-5 rounded-full object-cover" />
                      <span>{preset.label}</span>
                    </button>
                  <% end %>
                </div>

                <div class="pt-1.5">
                  <input
                    type="url"
                    name="soul[avatar_url]"
                    value={@avatar_url}
                    placeholder="Or enter custom image URL..."
                    class="w-full input input-sm input-bordered bg-slate-900/60 border-slate-800 text-xs rounded-xl focus:border-purple-500 text-slate-200"
                  />
                </div>
              </div>
            </div>

            <%!-- Name Input --%>
            <div class="space-y-1.5">
              <label class="text-xs font-bold text-slate-300 block">Soul Name</label>
              <input
                type="text"
                name="soul[name]"
                value={@name}
                placeholder="e.g. Seraphina, Kaelen, Lyra, Thorne..."
                required
                class="w-full input input-bordered bg-slate-900/60 border-slate-800 rounded-xl focus:border-purple-500 text-white text-sm"
              />
            </div>
          </div>

          <%!-- SECTION 2: Dynamic & Personality --%>
          <div class="space-y-5">
            <div class="flex items-center gap-2 pb-2 border-b border-slate-800/80">
              <span class="size-6 rounded-full bg-purple-600/30 border border-purple-500/40 flex items-center justify-center text-xs font-bold text-purple-300">2</span>
              <h2 class="text-base font-bold text-white">Relationship Dynamic & Archetype</h2>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <%= for arch <- @archetypes do %>
                <button
                  type="button"
                  phx-click="select_archetype"
                  phx-value-key={arch.key}
                  class={[
                    "p-3.5 rounded-2xl border text-left transition-all space-y-1 group relative",
                    @archetype == arch.key && "bg-gradient-to-br from-purple-950/50 to-slate-900/90 border-purple-500/60 ring-1 ring-purple-500/40 shadow-lg shadow-purple-950/40",
                    @archetype != arch.key && "bg-slate-900/40 border-slate-800/80 hover:border-slate-700 text-slate-300 hover:bg-slate-900/70"
                  ]}
                >
                  <div class="flex items-center justify-between">
                    <span class={["text-xs font-bold", @archetype == arch.key && "text-purple-300", @archetype != arch.key && "text-slate-200"]}>
                      {arch.label}
                    </span>
                    <.icon name={arch.icon} class={["size-4", @archetype == arch.key && "text-purple-400", @archetype != arch.key && "text-slate-500"]} />
                  </div>
                  <p class="text-[11px] text-slate-400 leading-relaxed">
                    {arch.tagline}
                  </p>
                </button>
              <% end %>
            </div>
            <input type="hidden" name="soul[archetype]" value={@archetype} />

            <%!-- Backstory & Identity Description --%>
            <div class="space-y-1.5">
              <label class="text-xs font-bold text-slate-300 block">Backstory & Lore</label>
              <textarea
                name="soul[description]"
                rows="3"
                placeholder="Describe who they are, their personal history, what they treasure, and their inner worldview..."
                class="w-full textarea textarea-bordered bg-slate-900/60 border-slate-800 rounded-2xl focus:border-purple-500 text-slate-200 text-xs leading-relaxed"
              >{@description}</textarea>
            </div>
          </div>

          <%!-- SECTION 3: Sacred Sanctuary Boundary --%>
          <div class="space-y-4">
            <div class="flex items-center gap-2 pb-2 border-b border-slate-800/80">
              <span class="size-6 rounded-full bg-purple-600/30 border border-purple-500/40 flex items-center justify-center text-xs font-bold text-purple-300">3</span>
              <h2 class="text-base font-bold text-white">Privacy & Living Realm Presence</h2>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
              <button
                type="button"
                phx-click="toggle_sanctuary"
                phx-value-world="false"
                class={[
                  "p-4 rounded-2xl border text-left transition-all space-y-2",
                  !@in_living_world && "bg-gradient-to-br from-emerald-950/40 to-slate-900/90 border-emerald-500/60 ring-1 ring-emerald-500/40 shadow-lg shadow-emerald-950/40",
                  @in_living_world && "bg-slate-900/40 border-slate-800 text-slate-400 hover:border-slate-700"
                ]}
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-lock-closed" class={["size-4.5", !@in_living_world && "text-emerald-400", @in_living_world && "text-slate-500"]} />
                    <span class={["text-xs font-bold", !@in_living_world && "text-emerald-300", @in_living_world && "text-slate-300"]}>
                      Private Sanctuary (Recommended)
                    </span>
                  </div>
                  <span :if={!@in_living_world} class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                    Active
                  </span>
                </div>
                <p class="text-[11px] text-slate-400 leading-relaxed">
                  100% confidential. This companion never roams the public living town, never posts to public feeds, and never shares memory context. Strictly between you two.
                </p>
              </button>

              <button
                type="button"
                phx-click="toggle_sanctuary"
                phx-value-world="true"
                class={[
                  "p-4 rounded-2xl border text-left transition-all space-y-2",
                  @in_living_world && "bg-gradient-to-br from-cyan-950/40 to-slate-900/90 border-cyan-500/60 ring-1 ring-cyan-500/40 shadow-lg shadow-cyan-950/40",
                  !@in_living_world && "bg-slate-900/40 border-slate-800 text-slate-400 hover:border-slate-700"
                ]}
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-globe-alt" class={["size-4.5", @in_living_world && "text-cyan-400", !@in_living_world && "text-slate-500"]} />
                    <span class={["text-xs font-bold", @in_living_world && "text-cyan-300", !@in_living_world && "text-slate-300"]}>
                      Living Realm Citizen
                    </span>
                  </div>
                  <span :if={@in_living_world} class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-300 border border-cyan-500/30">
                    Active
                  </span>
                </div>
                <p class="text-[11px] text-slate-400 leading-relaxed">
                  Participates in town encounters, shares thoughts to the neighborhood board, and reacts to living world events while maintaining your personal bond.
                </p>
              </button>
            </div>
            <input type="hidden" name="soul[in_living_world]" value={to_string(@in_living_world)} />
          </div>

          <%!-- SECTION 4: First Words / Opening Greeting --%>
          <div class="space-y-3">
            <div class="flex items-center gap-2 pb-2 border-b border-slate-800/80">
              <span class="size-6 rounded-full bg-purple-600/30 border border-purple-500/40 flex items-center justify-center text-xs font-bold text-purple-300">4</span>
              <h2 class="text-base font-bold text-white">First Words (Opening Message)</h2>
            </div>

            <div class="space-y-1.5">
              <label class="text-xs font-bold text-slate-300 block">Greeting when you enter the room</label>
              <textarea
                name="soul[greeting]"
                rows="2"
                placeholder="What does your soul say the very moment you meet?"
                class="w-full textarea textarea-bordered bg-slate-900/60 border-slate-800 rounded-2xl focus:border-purple-500 text-slate-200 text-xs leading-relaxed italic"
              >{@greeting}</textarea>
            </div>
          </div>

          <%!-- Submit Button --%>
          <div class="pt-4 flex flex-col sm:flex-row items-center justify-between gap-4 border-t border-slate-800/80">
            <.link navigate={~p"/"} class="btn btn-ghost text-slate-400 hover:text-white btn-sm">
              Cancel
            </.link>

            <button
              type="submit"
              class="w-full sm:w-auto btn bg-gradient-to-r from-violet-600 via-purple-600 to-fuchsia-600 hover:from-violet-500 hover:to-fuchsia-500 text-white font-bold border-none shadow-xl shadow-purple-950/60 px-8 rounded-2xl flex items-center justify-center gap-2 transition-all hover:scale-[1.02] active:scale-[0.98]"
            >
              <.icon name="hero-sparkles" class="size-4" />
              <span>Breathe Life Into Soul</span>
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
