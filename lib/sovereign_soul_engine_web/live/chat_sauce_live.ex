defmodule SovereignSoulEngineWeb.ChatSauceLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.AcpManager
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Social.NPCScheduler

  @wizard_steps 7
  @inspector_tabs ~w(vitals beliefs arcs goals memory theory_of_mind)

  @impl true
  def mount(_params, _session, socket) do
    characters = Characters.list_characters()
    running = AcpManager.running?()
    logs = AcpManager.get_logs()
    relationships = Relationships.list_relationships()

    # Form changeset for new character creation
    changeset = Characters.change_character(%Characters.Character{})
    rel_changeset = Relationships.change_relationship(%Relationships.Relationship{})

    socket =
      socket
      |> assign(:page_title, "Chat Sauce — Sovereign Admin")
      |> assign(:characters, characters)
      |> assign(:acp_running?, running)
      |> assign(:acp_logs, logs)
      |> assign(:relationships, relationships)
      |> assign(:new_char_form, to_form(changeset))
      |> assign(:new_rel_form, to_form(rel_changeset))
      |> assign(:editing_character, nil)
      |> assign(:editing_character_profile, nil)
      |> assign(:editing_character_fears, [])
      |> assign(:shadows, load_shadows())
      |> assign(:error_message, nil)
      |> assign(:success_message, nil)
      # ACP tab routing
      |> assign(:sauce_tab, "control")
      # Character inspector
      |> assign(:inspector_char, nil)
      |> assign(:inspector_tab, "vitals")
      |> assign(:inspector_emotional, nil)
      |> assign(:inspector_soul, nil)
      |> assign(:inspector_somatic, nil)
      |> assign(:inspector_grief_arcs, [])
      |> assign(:inspector_active_goals, [])
      |> assign(:inspector_cog_score, 0)
      |> assign(:inspector_beliefs, [])
      |> assign(:inspector_triggers, [])
      |> assign(:inspector_moral_lines, [])
      |> assign(:inspector_secrets, [])
      |> assign(:inspector_desires, [])
      |> assign(:inspector_forgiveness_arcs, [])
      |> assign(:inspector_memories, [])
      |> assign(:inspector_tom_grouped, [])
      |> assign(:inspector_tom_all_chars, [])
      |> assign(:inspector_tom_draft_fact, "")
      |> assign(:inspector_tom_draft_certainty, 70)
      |> assign(:inspector_tom_draft_assumption, true)
      |> assign(:inspector_tom_draft_subject_id, nil)
      |> assign(:inspector_tom_save_result, nil)
      # Social log tab
      |> assign(:social_scenes, [])
      |> assign(:social_selected, nil)
      |> assign(:social_messages, [])
      # NPC Wizard
      |> assign(:w_step, 1)
      |> assign(:w_errors, [])
      |> assign(:w_name, "")
      |> assign(:w_slug, "")
      |> assign(:w_description, "")
      |> assign(:w_kind, "npc")
      |> assign(:w_status, "inactive")
      |> assign(:w_attachment_style, "secure")
      |> assign(:w_humor_style, "none")
      |> assign(:w_emotional_susceptibility, 50)
      |> assign(:w_speech_style, "")
      |> assign(:w_personality_traits, %{
        "depression" => false, "bipolar" => false, "ocd" => false,
        "splitting" => false, "adhd" => false, "narcissism" => false,
        "impostor" => false, "codependency" => false, "addiction" => false,
        "hypochondria" => false
      })
      |> assign(:w_core_values, [])
      |> assign(:w_core_value_input, "")
      |> assign(:w_baseline_emotions, %{
        "anger" => 0, "fear" => 0, "stress" => 20,
        "gratitude" => 30, "confidence" => 50, "sadness" => 0
      })
      |> assign(:w_physical_tells, %{
        "anger" => "", "fear" => "", "sadness" => "", "shame" => "", "stress" => ""
      })
      |> assign(:w_transference_entries, [
        %{"trigger_pattern" => "", "reminds_them_of" => ""},
        %{"trigger_pattern" => "", "reminds_them_of" => ""},
        %{"trigger_pattern" => "", "reminds_them_of" => ""}
      ])
      |> assign(:w_beliefs, [])
      |> assign(:w_belief_draft, %{"belief" => "", "domain" => "social", "conviction" => 50})
      |> assign(:w_triggers, [])
      |> assign(:w_trigger_draft, %{
        "topic" => "", "reaction_type" => "anger_spike",
        "intensity_modifier" => 50, "flavor_text" => ""
      })
      |> assign(:w_moral_lines, [])
      |> assign(:w_moral_line_draft, %{"principle" => "", "will_refuse" => true, "action_types_blocked" => []})
      |> assign(:w_secrets, [])
      |> assign(:w_secret_draft, %{"secret_text" => "", "risk_level" => "medium", "domain" => ""})
      |> assign(:w_desires, [])
      |> assign(:w_desire_draft, %{"desire" => "", "domain" => "connection", "urgency" => 50})
      |> assign(:w_goals, [])
      |> assign(:w_goal_draft, %{"goal" => "", "current_step" => "", "priority" => 50})
      |> assign(:w_grief_arcs, [])
      |> assign(:w_grief_draft, %{"subject" => "", "loss_type" => "person", "stage" => "denial", "intensity" => 70})
      |> assign(:w_forgiveness_arcs, [])
      |> assign(:w_forgiveness_draft, %{
        "wound_description" => "", "stage" => "fresh",
        "direction" => "neutral", "intensity" => 80
      })
      |> assign(:w_tom_entries, [])
      |> assign(:w_tom_draft, %{"known_fact" => "", "certainty" => 70, "is_assumption" => true})
      |> assign(:w_social_stamina, 80)
      |> assign(:w_stamina_regen_rate, 10)
      |> assign(:w_stamina_max, 100)
      |> assign(:w_hunger, 0)
      |> assign(:w_pain, 0)
      |> assign(:w_fatigue, 20)
      |> assign(:w_illness_severity, 0)

    # Automatically refresh status and logs every 5 seconds if connected
    if connected?(socket) do
      :timer.send_interval(5000, self(), :tick)
    end

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply,
     socket
     |> assign(:acp_running?, AcpManager.running?())
     |> assign(:acp_logs, AcpManager.get_logs())
     |> assign(:shadows, load_shadows())}
  end

  @impl true
  def handle_event("start_acp", _params, socket) do
    success = AcpManager.start()
    logs = AcpManager.get_logs()

    socket =
      socket
      |> assign(:acp_running?, success)
      |> assign(:acp_logs, logs)
      |> assign(:success_message, if(success, do: "ACP Server started successfully!", else: nil))
      |> assign(:error_message, if(not success, do: "Failed to start ACP Server.", else: nil))

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_acp", _params, socket) do
    success = AcpManager.stop()
    logs = AcpManager.get_logs()

    socket =
      socket
      |> assign(:acp_running?, not success)
      |> assign(:acp_logs, logs)
      |> assign(:success_message, if(success, do: "ACP Server stopped.", else: nil))
      |> assign(:error_message, if(not success, do: "Failed to stop ACP Server.", else: nil))

    {:noreply, socket}
  end

  @impl true
  def handle_event("restart_acp", _params, socket) do
    success = AcpManager.restart()
    logs = AcpManager.get_logs()

    socket =
      socket
      |> assign(:acp_running?, success)
      |> assign(:acp_logs, logs)
      |> assign(:success_message, if(success, do: "ACP Server restarted.", else: nil))
      |> assign(:error_message, if(not success, do: "Failed to restart ACP Server.", else: nil))

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_logs", _params, socket) do
    {:noreply, assign(socket, :acp_logs, AcpManager.get_logs())}
  end

  @impl true
  def handle_event("create_character", %{"character" => char_params}, socket) do
    # Ensure slug and kind defaults
    char_params =
      char_params
      |> Map.put("kind", "npc")
      |> Map.put("status", "active")
      |> Map.put_new_lazy("slug", fn ->
        char_params["name"]
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]+/, "-")
        |> String.trim("-")
      end)

    case Characters.create_character(char_params) do
      {:ok, _char} ->
        # Successfully created
        # Force start Soul & NPC systems for the new character if needed
        # In SSE, Character insertion triggers necessary emotional profiles via DB triggers or app hooks
        {:noreply,
         socket
         |> assign(:characters, Characters.list_characters())
         |> assign(:success_message, "Character '#{char_params["name"]}' created successfully!")
         |> assign(:error_message, nil)
         |> assign(:new_char_form, to_form(Characters.change_character(%Characters.Character{})))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:new_char_form, to_form(changeset))
         |> assign(:error_message, "Validation failed. Please check inputs.")
         |> assign(:success_message, nil)}
    end
  end

  @impl true
  def handle_event("create_relationship", %{"relationship" => rel_params}, socket) do
    source_id = rel_params["source_character_id"]
    target_id = rel_params["target_character_id"]

    if source_id == target_id do
      {:noreply,
       socket
       |> assign(:error_message, "Source and Target characters must be different.")
       |> assign(:success_message, nil)}
    else
      case Relationships.get_relationship(source_id, target_id) do
        nil ->
          case Relationships.create_relationship(rel_params) do
            {:ok, _rel} ->
              {:noreply,
               socket
               |> assign(:relationships, Relationships.list_relationships())
               |> assign(:success_message, "Relationship created successfully!")
               |> assign(:error_message, nil)
               |> assign(
                 :new_rel_form,
                 to_form(Relationships.change_relationship(%Relationships.Relationship{}))
               )}

            {:error, changeset} ->
              {:noreply,
               socket
               |> assign(:new_rel_form, to_form(changeset))
               |> assign(:error_message, "Failed to create relationship. Please check inputs.")
               |> assign(:success_message, nil)}
          end

        existing_rel ->
          case Relationships.update_relationship(existing_rel, rel_params) do
            {:ok, _rel} ->
              {:noreply,
               socket
               |> assign(:relationships, Relationships.list_relationships())
               |> assign(:success_message, "Relationship updated successfully!")
               |> assign(:error_message, nil)
               |> assign(
                 :new_rel_form,
                 to_form(Relationships.change_relationship(%Relationships.Relationship{}))
               )}

            {:error, changeset} ->
              {:noreply,
               socket
               |> assign(:new_rel_form, to_form(changeset))
               |> assign(:error_message, "Failed to update relationship.")
               |> assign(:success_message, nil)}
          end
      end
    end
  end

  @impl true
  def handle_event("delete_relationship", %{"id" => id}, socket) do
    rel = Relationships.get_relationship!(id)

    case Relationships.delete_relationship(rel) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:relationships, Relationships.list_relationships())
         |> assign(:success_message, "Relationship deleted successfully!")
         |> assign(:error_message, nil)}

      _ ->
        {:noreply,
         socket
         |> assign(:error_message, "Failed to delete relationship.")
         |> assign(:success_message, nil)}
    end
  end

  @impl true
  def handle_event("select_edit_character", %{"id" => id}, socket) do
    import Ecto.Query
    char = Characters.get_character!(id)
    # Fetch or create SoulProfile
    profile =
      SovereignSoulEngine.Souls.get_soul_profile_by_character(char.id) ||
        case SovereignSoulEngine.Souls.create_soul_profile(%{character_id: char.id}) do
          {:ok, p} -> p
        end

    fears =
      SovereignSoulEngine.Repo.all(
        from f in SovereignSoulEngine.Souls.SoulFear,
          where: f.character_id == ^char.id,
          order_by: [desc: f.inserted_at]
      )

    {:noreply,
     socket
     |> assign(:editing_character, char)
     |> assign(:editing_character_profile, profile)
     |> assign(:editing_character_fears, fears)}
  end

  @impl true
  def handle_event("close_edit_character", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_character, nil)
     |> assign(:editing_character_profile, nil)
     |> assign(:editing_character_fears, [])}
  end

  @impl true
  def handle_event("add_fear", %{"fear_type" => fear_type}, socket) do
    import Ecto.Query
    char = socket.assigns.editing_character

    if char && String.trim(fear_type) != "" do
      {:ok, _fear} =
        SovereignSoulEngine.Souls.create_soul_fear(%{
          character_id: char.id,
          fear_type: String.trim(fear_type),
          severity: 70,
          origin: "baked_in",
          status: "active"
        })

      fears =
        SovereignSoulEngine.Repo.all(
          from f in SovereignSoulEngine.Souls.SoulFear,
            where: f.character_id == ^char.id,
            order_by: [desc: f.inserted_at]
        )

      {:noreply, assign(socket, :editing_character_fears, fears)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("resolve_fear", %{"id" => fear_id}, socket) do
    import Ecto.Query
    char = socket.assigns.editing_character
    fear = SovereignSoulEngine.Repo.get!(SovereignSoulEngine.Souls.SoulFear, fear_id)

    {:ok, _} =
      SovereignSoulEngine.Souls.update_soul_fear(fear, %{status: "resolved", severity: 0})

    fears =
      SovereignSoulEngine.Repo.all(
        from f in SovereignSoulEngine.Souls.SoulFear,
          where: f.character_id == ^char.id,
          order_by: [desc: f.inserted_at]
      )

    {:noreply, assign(socket, :editing_character_fears, fears)}
  end

  @impl true
  def handle_event("update_character", %{"character" => char_params}, socket) do
    char = socket.assigns.editing_character
    profile = socket.assigns.editing_character_profile
    description = char_params["description"]

    # Extract boolean checkboxes for the 10 personality traits
    traits = %{
      "depression" => char_params["traits_depression"] == "true",
      "bipolar" => char_params["traits_bipolar"] == "true",
      "ocd" => char_params["traits_ocd"] == "true",
      "splitting" => char_params["traits_splitting"] == "true",
      "adhd" => char_params["traits_adhd"] == "true",
      "narcissism" => char_params["traits_narcissism"] == "true",
      "impostor" => char_params["traits_impostor"] == "true",
      "codependency" => char_params["traits_codependency"] == "true",
      "addiction" => char_params["traits_addiction"] == "true",
      "hypochondria" => char_params["traits_hypochondria"] == "true"
    }

    case Characters.update_character(char, %{description: description}) do
      {:ok, _char} ->
        # Update SoulProfile personality traits
        if profile do
          {:ok, _} =
            SovereignSoulEngine.Souls.update_soul_profile(profile, %{personality_traits: traits})
        end

        # Broadcast that character context was updated
        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "scenes:list_updates",
          {:scenes_updated, %{}}
        )

        {:noreply,
         socket
         |> assign(:editing_character, nil)
         |> assign(:editing_character_profile, nil)
         |> assign(:characters, Characters.list_characters())
         |> assign(
           :success_message,
           "Character '#{char.name}' and personality traits updated successfully!"
         )
         |> assign(:error_message, nil)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:error_message, "Failed to update character description.")
         |> assign(:success_message, nil)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans antialiased">
      <%!-- Top navbar --%>
      <header class="border-b border-slate-800 bg-slate-900/60 backdrop-blur-md sticky top-0 z-50 px-6 py-4 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-xl bg-gradient-to-tr from-amber-500 to-orange-400 flex items-center justify-center shadow-lg shadow-orange-500/20">
            <.icon name="hero-wrench-screwdriver" class="size-5 text-slate-950" />
          </div>
          <div>
            <h1 class="text-base font-bold tracking-tight text-white flex items-center gap-1.5">
              Chat Sauce
              <span class="text-[10px] uppercase font-mono px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-400 border border-amber-500/20">
                Admin
              </span>
            </h1>
            <p class="text-xs text-slate-400">
              Control center for character AI & Agent Client Protocol
            </p>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <.link
            navigate={~p"/sse/chat"}
            class="text-sm font-medium px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 transition-all duration-150 inline-flex items-center gap-1.5 border border-slate-700"
          >
            <.icon name="hero-chat-bubble-left-right" class="size-4" /> Sovereign Chat
          </.link>
          <.link
            navigate={~p"/sse"}
            class="text-sm font-medium px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 transition-all duration-150 inline-flex items-center gap-1.5 border border-slate-700"
          >
            <.icon name="hero-home" class="size-4" /> Dashboard
          </.link>
        </div>
      </header>

      <%!-- ACP Tab Bar --%>
      <div class="sticky top-[65px] z-40 border-b border-slate-800 bg-slate-900/80 backdrop-blur-md px-6 flex gap-0">
        <%= for {label, icon, tab} <- [{"Control", "hero-server", "control"}, {"Characters", "hero-users", "characters"}, {"Create NPC", "hero-user-plus", "create_npc"}, {"Social Log", "hero-chat-bubble-left-right", "social"}] do %>
          <button
            phx-click="switch_sauce_tab"
            phx-value-tab={tab}
            class={[
              "flex items-center gap-1.5 px-4 py-3 text-xs font-semibold border-b-2 transition-colors",
              @sauce_tab == tab && "border-amber-400 text-amber-300",
              @sauce_tab != tab && "border-transparent text-slate-500 hover:text-slate-300"
            ]}
          >
            <.icon name={icon} class="size-3.5" /> {label}
          </button>
        <% end %>
      </div>

      <%!-- Main Body --%>
      <main class="flex-1 max-w-7xl w-full mx-auto p-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Notifications --%>
        <div :if={@success_message || @error_message} class="col-span-1 lg:col-span-3">
          <div
            :if={@success_message}
            class="p-4 rounded-xl border border-emerald-500/30 bg-emerald-500/5 text-emerald-400 text-sm flex items-center gap-2"
          >
            <.icon name="hero-check-circle" class="size-5 text-emerald-400" />
            {@success_message}
          </div>
          <div
            :if={@error_message}
            class="p-4 rounded-xl border border-red-500/30 bg-red-500/5 text-red-400 text-sm flex items-center gap-2"
          >
            <.icon name="hero-exclamation-triangle" class="size-5 text-red-400" />
            {@error_message}
          </div>
        </div>

        <%!-- ── CONTROL TAB ─────────────────────────────────────────── --%>
        <div :if={@sauce_tab == "control"} class="contents">

        <%!-- Column 1 & 2: ACP server control & log --%>
        <div class="lg:col-span-2 space-y-6">
          <%!-- ACP Server Status Card --%>
          <section class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 backdrop-blur-sm space-y-5">
            <div class="flex items-center justify-between">
              <div class="space-y-1">
                <h2 class="text-lg font-bold text-white">Agent Client Protocol (ACP)</h2>
                <p class="text-xs text-slate-400">
                  Allows autonomous coding agents to inspect the soul engines and generate characters.
                </p>
              </div>
              <div class="flex items-center gap-2">
                <span class={[
                  "inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold uppercase tracking-wider border",
                  @acp_running? && "bg-emerald-500/10 text-emerald-400 border-emerald-500/20",
                  !@acp_running? && "bg-rose-500/10 text-rose-400 border-rose-500/20"
                ]}>
                  <span class={[
                    "w-2 h-2 rounded-full",
                    @acp_running? && "bg-emerald-400 animate-pulse",
                    !@acp_running? && "bg-rose-400"
                  ]} />
                  {if @acp_running?, do: "Active", else: "Offline"}
                </span>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 rounded-xl bg-slate-950/60 border border-slate-800 text-sm">
              <div class="flex flex-col gap-1">
                <span class="text-slate-500 text-xs uppercase font-mono">Service Host</span>
                <span class="text-slate-200 font-semibold font-mono">0.0.0.0</span>
              </div>
              <div class="flex flex-col gap-1">
                <span class="text-slate-500 text-xs uppercase font-mono">Listening Port</span>
                <span class="text-slate-200 font-semibold font-mono">4005</span>
              </div>
            </div>

            <div class="flex items-center gap-3">
              <button
                phx-click="start_acp"
                disabled={@acp_running?}
                class="flex-1 py-2.5 px-4 rounded-xl font-semibold text-sm transition-all duration-150 flex items-center justify-center gap-2 bg-gradient-to-tr from-emerald-500 to-teal-400 text-slate-950 hover:shadow-lg hover:shadow-emerald-500/15 disabled:opacity-35 disabled:pointer-events-none"
              >
                <.icon name="hero-play" class="size-4" /> Start Server
              </button>
              <button
                phx-click="stop_acp"
                disabled={!@acp_running?}
                class="flex-1 py-2.5 px-4 rounded-xl font-semibold text-sm transition-all duration-150 flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-700 text-white border border-slate-700 disabled:opacity-35 disabled:pointer-events-none"
              >
                <.icon name="hero-stop" class="size-4" /> Stop Server
              </button>
              <button
                phx-click="restart_acp"
                class="py-2.5 px-4 rounded-xl font-semibold text-sm transition-all duration-150 flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-700 text-white border border-slate-700"
              >
                <.icon name="hero-arrow-path" class="size-4" /> Restart
              </button>
            </div>
          </section>

          <%!-- Logs Viewer --%>
          <section class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 backdrop-blur-sm space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-sm font-bold text-slate-300 uppercase tracking-wider font-mono">
                ACP Server Logs
              </h2>
              <button
                phx-click="refresh_logs"
                class="btn btn-ghost btn-xs text-slate-400 hover:text-white flex items-center gap-1"
              >
                <.icon name="hero-arrow-path" class="size-3" /> Refresh
              </button>
            </div>
            <div class="p-4 rounded-xl bg-slate-950 font-mono text-xs text-slate-300 overflow-x-auto max-h-96 border border-slate-900">
              <pre class="whitespace-pre-wrap">{html_escape(@acp_logs)}</pre>
            </div>
          </section>

          <%!-- Relationships Manager --%>
          <section class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 backdrop-blur-sm space-y-4">
            <h2 class="text-base font-bold text-white flex items-center gap-1.5">
              <.icon name="hero-heart" class="size-5 text-rose-500" /> Relationship Builder
            </h2>

            <.form
              for={@new_rel_form}
              phx-submit="create_relationship"
              class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm bg-slate-950/60 p-4 rounded-xl border border-slate-800"
            >
              <div class="space-y-1">
                <label class="text-xs text-slate-400 font-medium">Source Character</label>
                <select
                  name="relationship[source_character_id]"
                  required
                  class="w-full bg-slate-900 border border-slate-800 text-white rounded-xl p-2.5 focus:border-rose-500/50 outline-none"
                >
                  <option value="">Select source...</option>
                  <%= for char <- @characters do %>
                    <option value={char.id}>{char.name} ({char.kind})</option>
                  <% end %>
                </select>
              </div>

              <div class="space-y-1">
                <label class="text-xs text-slate-400 font-medium">Target Character</label>
                <select
                  name="relationship[target_character_id]"
                  required
                  class="w-full bg-slate-900 border border-slate-800 text-white rounded-xl p-2.5 focus:border-rose-500/50 outline-none"
                >
                  <option value="">Select target...</option>
                  <%= for char <- @characters do %>
                    <option value={char.id}>{char.name} ({char.kind})</option>
                  <% end %>
                </select>
              </div>

              <div class="space-y-1">
                <label class="text-xs text-slate-400 font-medium">Relationship Type</label>
                <select
                  name="relationship[relationship_type]"
                  required
                  class="w-full bg-slate-900 border border-slate-800 text-white rounded-xl p-2.5 focus:border-rose-500/50 outline-none"
                >
                  <option value="acquaintance">Acquaintance</option>
                  <option value="friend">Friend</option>
                  <option value="best_friend">Best Friend</option>
                  <option value="blood_brother">Blood Brother</option>
                  <option value="enemy">Enemy</option>
                  <option value="wife">Wife</option>
                  <option value="husband">Husband</option>
                  <option value="sister">Sister</option>
                  <option value="brother">Brother</option>
                  <option value="savior">Savior</option>
                  <option value="captor">Captor</option>
                  <option value="protege">Protege</option>
                  <option value="master">Master</option>
                  <option value="servant">Servant</option>
                  <option value="ally">Ally</option>
                  <option value="rival">Rival</option>
                  <option value="infiltrator">Infiltrator</option>
                  <option value="duped">Duped</option>
                  <option value="exile">Exile</option>
                  <option value="harborer">Harborer</option>
                  <option value="co_survivor">Co-Survivor</option>
                  <option value="informant">Informant</option>
                  <option value="handler">Handler</option>
                  <option value="predecessor">Predecessor</option>
                  <option value="successor">Successor</option>
                  <option value="vassal">Vassal</option>
                  <option value="overlord">Overlord</option>
                  <option value="escort">Escort</option>
                  <option value="ward">Ward</option>
                  <option value="sympathizer">Sympathizer</option>
                  <option value="childhood_friend">Childhood Friend</option>
                  <option value="frenemy">Frenemy</option>
                  <option value="spiritual_guide">Spiritual Guide</option>
                  <option value="disciple">Disciple</option>
                  <option value="debtor">Debtor</option>
                  <option value="creditor">Creditor</option>
                  <option value="forbidden_lovers">Forbidden Lovers</option>
                  <option value="vampire">Vampire</option>
                  <option value="spawn">Spawn</option>
                </select>
              </div>

              <div class="col-span-1 md:col-span-3 grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
                <div class="space-y-1">
                  <label class="text-xs text-slate-400 font-medium">Trust (-100 to 100)</label>
                  <input
                    type="number"
                    name="relationship[trust]"
                    min="-100"
                    max="100"
                    value={@new_rel_form[:trust].value || 0}
                    class="w-full bg-slate-900 border border-slate-800 text-white rounded-xl p-2 focus:border-rose-500/50 outline-none"
                  />
                </div>
                <div class="space-y-1">
                  <label class="text-xs text-slate-400 font-medium">Respect (-100 to 100)</label>
                  <input
                    type="number"
                    name="relationship[respect]"
                    min="-100"
                    max="100"
                    value={@new_rel_form[:respect].value || 0}
                    class="w-full bg-slate-900 border border-slate-800 text-white rounded-xl p-2 focus:border-rose-500/50 outline-none"
                  />
                </div>
                <div class="space-y-1">
                  <label class="text-xs text-slate-400 font-medium">
                    Affinity / Attachment (-100 to 100)
                  </label>
                  <input
                    type="number"
                    name="relationship[affinity]"
                    min="-100"
                    max="100"
                    value={@new_rel_form[:affinity].value || 0}
                    class="w-full bg-slate-900 border border-slate-800 text-white rounded-xl p-2 focus:border-rose-500/50 outline-none"
                  />
                </div>
              </div>

              <div class="col-span-1 md:col-span-3 pt-2">
                <button
                  type="submit"
                  class="w-full py-2.5 px-4 rounded-xl font-bold bg-rose-500 hover:bg-rose-400 text-slate-950 transition-all duration-150 shadow-lg shadow-rose-500/10"
                >
                  Save / Update Relationship
                </button>
              </div>
            </.form>

            <%!-- Existing Relationships List --%>
            <div class="space-y-2.5">
              <h3 class="text-sm font-bold text-slate-300 uppercase tracking-wider font-mono">
                Current Relationships
              </h3>
              <div class="overflow-x-auto rounded-xl border border-slate-900">
                <table class="w-full text-sm text-left text-slate-300">
                  <thead class="text-xs text-slate-400 uppercase bg-slate-950/80 font-mono">
                    <tr>
                      <th class="px-4 py-2.5">Source</th>
                      <th class="px-4 py-2.5">Target</th>
                      <th class="px-4 py-2.5">Type</th>
                      <th class="px-4 py-2.5 text-center">Trust</th>
                      <th class="px-4 py-2.5 text-center">Respect</th>
                      <th class="px-4 py-2.5 text-center">Affinity</th>
                      <th class="px-4 py-2.5 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-slate-800/60 bg-slate-900/10">
                    <%= for rel <- @relationships do %>
                      <% src = Enum.find(@characters, &(&1.id == rel.source_character_id))
                      tgt = Enum.find(@characters, &(&1.id == rel.target_character_id)) %>
                      <tr :if={src && tgt} class="hover:bg-slate-900/30">
                        <td class="px-4 py-2.5 font-medium text-slate-200">{src.name}</td>
                        <td class="px-4 py-2.5 font-medium text-slate-200">{tgt.name}</td>
                        <td class="px-4 py-2.5 text-slate-400 font-mono uppercase text-xs">
                          {rel.relationship_type || "acquaintance"}
                        </td>
                        <td class="px-4 py-2.5 text-center font-mono">{rel.trust}</td>
                        <td class="px-4 py-2.5 text-center font-mono">{rel.respect}</td>
                        <td class="px-4 py-2.5 text-center font-mono">{rel.affinity}</td>
                        <td class="px-4 py-2.5 text-right">
                          <button
                            phx-click="delete_relationship"
                            phx-value-id={rel.id}
                            class="text-xs font-semibold text-rose-400 hover:text-rose-300 px-2 py-1"
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </section>
        </div>

        <%!-- Column 3: Character creation & listing --%>
        <div class="space-y-6">
          <%!-- Character Creator --%>
          <section class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 backdrop-blur-sm space-y-4">
            <h2 class="text-base font-bold text-white flex items-center gap-1.5">
              <.icon name="hero-user-plus" class="size-5 text-amber-400" /> Create Soul Character
            </h2>

            <.form
              for={@new_char_form}
              phx-submit="create_character"
              class="space-y-3 text-sm"
            >
              <.input
                field={@new_char_form[:name]}
                label="Name"
                placeholder="e.g. Eldon"
                required
                class="w-full input input-bordered bg-slate-950 border-slate-800 text-white rounded-xl focus:border-amber-500/50"
              />

              <.input
                field={@new_char_form[:description]}
                type="textarea"
                rows="3"
                label="Description / Personality"
                placeholder="A mysterious scholar who knows the secret code of the bastion."
                required
                class="w-full textarea textarea-bordered bg-slate-950 border-slate-800 text-white rounded-xl focus:border-amber-500/50"
              />

              <.input
                field={@new_char_form[:slug]}
                label="Slug (optional)"
                placeholder="e.g. eldon (auto-generated if blank)"
                class="w-full input input-bordered bg-slate-950 border-slate-800 text-white rounded-xl focus:border-amber-500/50"
              />

              <button
                type="submit"
                class="w-full py-2 px-4 rounded-xl font-bold bg-amber-500 hover:bg-amber-400 text-slate-950 transition-all duration-150 mt-2 shadow-lg shadow-amber-500/10"
              >
                Create Character
              </button>
            </.form>
          </section>

          <%!-- Characters List --%>
          <section class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 backdrop-blur-sm space-y-4">
            <h2 class="text-base font-bold text-slate-200">Active Characters</h2>
            <div class="divide-y divide-slate-800/60 max-h-80 overflow-y-auto space-y-2.5 pr-2">
              <%= for char <- @characters do %>
                <div class="pt-2.5 flex items-center justify-between gap-3 text-sm">
                  <div class="min-w-0 flex-1">
                    <div class="font-semibold text-slate-200 truncate">{char.name}</div>
                    <div class="text-xs text-slate-500 truncate" title={char.description}>
                      {char.description}
                    </div>
                  </div>
                  <div class="flex items-center gap-2.5 shrink-0">
                    <button
                      phx-click="select_edit_character"
                      phx-value-id={char.id}
                      class="text-xs font-semibold text-slate-400 hover:text-white transition-colors"
                    >
                      Edit
                    </button>
                    <.link
                      navigate={~p"/sse/characters/#{char.id}"}
                      class="text-xs font-semibold text-amber-400 hover:text-amber-300 transition-colors"
                    >
                      View
                    </.link>
                  </div>
                </div>
              <% end %>
            </div>
          </section>
          <%!-- Subconscious Shadow Monitor --%>
          <section class="col-span-1 lg:col-span-3 p-6 rounded-2xl border border-slate-800 bg-slate-900/40 backdrop-blur-sm space-y-4">
            <h2 class="text-base font-bold text-white flex items-center gap-1.5">
              <.icon name="hero-bolt" class="size-5 text-indigo-400" />
              Subconscious Shadow Monitor (Direct Character Minds)
            </h2>
            <p class="text-xs text-slate-400">
              Ledger of recent private monologues, repressed motives, and defense mechanisms captured off-chat from LLM response processes.
            </p>

            <div class="overflow-x-auto rounded-xl border border-slate-900">
              <table class="w-full text-sm text-left text-slate-300">
                <thead class="text-xs text-slate-400 uppercase bg-slate-950/80 font-mono">
                  <tr>
                    <th class="px-4 py-2.5">Time</th>
                    <th class="px-4 py-2.5">Character</th>
                    <th class="px-4 py-2.5">Room</th>
                    <th class="px-4 py-2.5">Defense</th>
                    <th class="px-4 py-2.5">Repressed Motive</th>
                    <th class="px-4 py-2.5">Private Thoughts</th>
                    <th class="px-4 py-2.5">Emotional Snapshot</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-800/60 bg-slate-900/10">
                  <%= for shadow <- @shadows do %>
                    <tr class="hover:bg-slate-900/30 text-xs">
                      <td class="px-4 py-2.5 text-slate-500 whitespace-nowrap font-mono">
                        {Calendar.strftime(shadow.inserted_at, "%H:%M:%S")}
                      </td>
                      <td class="px-4 py-2.5 font-bold text-white whitespace-nowrap">
                        {shadow.character && shadow.character.name}
                      </td>
                      <td class="px-4 py-2.5 text-slate-400 whitespace-nowrap">
                        {shadow.scene && shadow.scene.title}
                      </td>
                      <td class="px-4 py-2.5">
                        <span class={[
                          "px-2 py-0.5 rounded text-[10px] font-mono uppercase font-bold",
                          shadow.active_defense == "none" &&
                            "bg-slate-800 text-slate-400 border border-slate-700",
                          shadow.active_defense != "none" &&
                            "bg-indigo-500/10 text-indigo-400 border border-indigo-500/20"
                        ]}>
                          {shadow.active_defense}
                        </span>
                      </td>
                      <td class="px-4 py-2.5 text-slate-200 leading-normal max-w-xs">
                        {shadow.repressed_motive}
                      </td>
                      <td class="px-4 py-2.5 text-slate-400 italic max-w-sm leading-normal">
                        {shadow.private_monologue}
                      </td>
                      <td class="px-4 py-2.5 font-mono text-[10px] text-slate-400 whitespace-nowrap">
                        ANG: {get_in(shadow.emotional_drift || %{}, ["anger"]) || 0} |
                        FEAR: {get_in(shadow.emotional_drift || %{}, ["fear"]) || 0} |
                        STR: {get_in(shadow.emotional_drift || %{}, ["stress"]) || 0} |
                        ATT: {get_in(shadow.emotional_drift || %{}, ["attachment"]) || 0}
                      </td>
                    </tr>
                  <% end %>
                  <tr :if={@shadows == []}>
                    <td colspan="7" class="px-4 py-8 text-center text-slate-500 italic">
                      No subconscious shadows logged yet. Send messages in Sovereign Chat to start logging.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        </div>
        </div><%!-- /control tab --%>

        <%!-- ── CHARACTERS TAB ─────────────────────────────────────── --%>
        <div :if={@sauce_tab == "characters"} class="col-span-1 lg:col-span-3 flex gap-4 min-h-[70vh]">
          <%!-- Roster --%>
          <aside class="w-56 shrink-0 space-y-1.5 overflow-y-auto">
            <div class="text-[10px] uppercase font-mono text-slate-500 px-2 pb-1 tracking-wider">Characters</div>
            <%= for char <- @characters do %>
              <button
                phx-click="inspector_select_char"
                phx-value-id={char.id}
                class={[
                  "w-full text-left px-3 py-2.5 rounded-xl border text-sm transition-colors",
                  @inspector_char && @inspector_char.id == char.id &&
                    "bg-amber-500/10 border-amber-500/30 text-amber-200",
                  (!@inspector_char || @inspector_char.id != char.id) &&
                    "bg-slate-900/40 border-slate-800 text-slate-300 hover:bg-slate-800/60"
                ]}
              >
                <div class="font-semibold truncate">{char.name}</div>
                <div class="text-[10px] text-slate-500 font-mono">{char.kind} · {char.status}</div>
              </button>
            <% end %>
          </aside>

          <%!-- Inspector Panel --%>
          <div class="flex-1 min-w-0">
            <%= if @inspector_char do %>
              <%!-- Character Header --%>
              <div class="flex items-center gap-3 mb-4">
                <div class="w-9 h-9 rounded-full bg-amber-500/20 border border-amber-500/30 flex items-center justify-center font-bold text-amber-400 text-sm shrink-0">
                  {String.first(@inspector_char.name)}
                </div>
                <div class="flex-1 min-w-0">
                  <div class="font-bold text-white text-sm">{@inspector_char.name}</div>
                  <div class="text-[10px] text-slate-500 truncate">{@inspector_char.description}</div>
                </div>
                <%= if @inspector_cog_score do %>
                  <% {cog_class, cog_label} = cog_badge(@inspector_cog_score) %>
                  <span class={"text-[10px] px-2 py-0.5 rounded border font-bold #{cog_class}"}>
                    COG: {cog_label} ({@inspector_cog_score})
                  </span>
                <% end %>
                <.link
                  navigate={~p"/sse/acp/npcs/#{@inspector_char.id}"}
                  class="text-[10px] text-slate-400 hover:text-amber-400 border border-slate-700 hover:border-amber-500/40 px-2 py-1 rounded-lg transition-colors"
                >
                  Full Inspector →
                </.link>
              </div>

              <%!-- Sub-tabs --%>
              <div class="flex gap-0.5 border-b border-slate-800 mb-4">
                <%= for tab <- @inspector_tabs do %>
                  <button
                    phx-click="inspector_switch_tab"
                    phx-value-tab={tab}
                    class={[
                      "px-3 py-2 text-[11px] font-semibold border-b-2 transition-colors",
                      @inspector_tab == tab && "border-amber-400 text-amber-300",
                      @inspector_tab != tab && "border-transparent text-slate-500 hover:text-slate-300"
                    ]}
                  >
                    {tab |> String.replace("_", " ") |> String.capitalize()}
                  </button>
                <% end %>
              </div>

              <%!-- Vitals sub-tab --%>
              <div :if={@inspector_tab == "vitals"} class="grid grid-cols-2 gap-4">
                <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40 space-y-2">
                  <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide">Emotional State</h3>
                  <%= for {label, key, color} <- emotion_fields() do %>
                    <div>
                      <div class="flex justify-between text-[11px] mb-0.5">
                        <span class="text-slate-400">{label}</span>
                        <span class="text-slate-300 font-mono">{if @inspector_emotional, do: Map.get(@inspector_emotional, key) || 0, else: 0}</span>
                      </div>
                      <div class="h-1.5 w-full rounded-full bg-slate-800 overflow-hidden">
                        <div class="h-full rounded-full transition-all" style={"width: #{if @inspector_emotional, do: Map.get(@inspector_emotional, key) || 0, else: 0}%; background-color: #{color}"}></div>
                      </div>
                    </div>
                  <% end %>
                </div>
                <div class="space-y-4">
                  <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40 space-y-2">
                    <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide">Somatic</h3>
                    <%= if @inspector_somatic do %>
                      <%= for {label, key, color} <- [{"Hunger", :hunger, "#f59e0b"}, {"Pain", :pain, "#ef4444"}, {"Fatigue", :fatigue, "#a855f7"}, {"Illness", :illness_severity, "#22c55e"}] do %>
                        <div>
                          <div class="flex justify-between text-[11px] mb-0.5">
                            <span class="text-slate-400">{label}</span>
                            <span class="text-slate-300 font-mono">{Map.get(@inspector_somatic, key) || 0}</span>
                          </div>
                          <div class="h-1.5 w-full rounded-full bg-slate-800 overflow-hidden">
                            <div class="h-full rounded-full" style={"width: #{Map.get(@inspector_somatic, key) || 0}%; background-color: #{color}"}></div>
                          </div>
                        </div>
                      <% end %>
                    <% else %>
                      <p class="text-xs text-slate-600 italic">No somatic data</p>
                    <% end %>
                  </div>
                  <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40 space-y-2">
                    <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide">Active Loads</h3>
                    <div class="grid grid-cols-2 gap-2 text-xs">
                      <div class="p-2 rounded-lg bg-slate-950/60 text-center">
                        <div class="text-lg font-bold text-white">{length(@inspector_active_goals)}</div>
                        <div class="text-slate-500 text-[10px]">Active Goals</div>
                      </div>
                      <div class="p-2 rounded-lg bg-slate-950/60 text-center">
                        <div class="text-lg font-bold text-indigo-400">{length(@inspector_grief_arcs)}</div>
                        <div class="text-slate-500 text-[10px]">Grief Arcs</div>
                      </div>
                    </div>
                    <%= if @inspector_soul do %>
                      <div class="text-[11px] text-slate-400 space-y-1 pt-1">
                        <div>Attachment: <span class="text-slate-200">{@inspector_soul.attachment_style}</span></div>
                        <div>Humor: <span class="text-slate-200">{@inspector_soul.humor_style}</span></div>
                        <div>Porousness: <span class="text-slate-200">{@inspector_soul.emotional_susceptibility}/100</span></div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

              <%!-- Beliefs sub-tab --%>
              <div :if={@inspector_tab == "beliefs"} class="space-y-4">
                <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40">
                  <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide mb-3">Core Beliefs</h3>
                  <div class="space-y-2">
                    <%= for b <- @inspector_beliefs do %>
                      <div class="flex items-start justify-between gap-3 p-2 rounded-lg bg-slate-950/60 text-xs">
                        <div class="flex-1">
                          <div class="text-slate-200">{b.belief}</div>
                          <div class="text-slate-500 font-mono">{b.domain} · conviction {b.conviction}/100</div>
                        </div>
                      </div>
                    <% end %>
                    <p :if={@inspector_beliefs == []} class="text-xs text-slate-600 italic">No beliefs loaded.</p>
                  </div>
                </div>
                <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40">
                  <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide mb-3">Triggers</h3>
                  <div class="space-y-2">
                    <%= for t <- @inspector_triggers do %>
                      <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs">
                        <span class="font-semibold text-white">{t.topic}</span>
                        <span class="text-slate-400 font-mono">→ {t.reaction_type}</span>
                        <span class="ml-auto text-slate-500">intensity ×{t.intensity_modifier}</span>
                      </div>
                    <% end %>
                    <p :if={@inspector_triggers == []} class="text-xs text-slate-600 italic">No triggers.</p>
                  </div>
                </div>
                <div class="grid grid-cols-2 gap-4">
                  <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40">
                    <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide mb-3">Moral Lines</h3>
                    <%= for ml <- @inspector_moral_lines do %>
                      <div class="p-2 rounded-lg bg-slate-950/60 text-xs text-slate-200 mb-1">{ml.principle}</div>
                    <% end %>
                    <p :if={@inspector_moral_lines == []} class="text-xs text-slate-600 italic">None.</p>
                  </div>
                  <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40">
                    <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide mb-3">Secrets</h3>
                    <%= for s <- @inspector_secrets do %>
                      <div class="p-2 rounded-lg bg-slate-950/60 text-xs mb-1">
                        <span class="text-slate-200">{s.secret_text}</span>
                        <span class="ml-2 text-rose-400 font-mono">{s.risk_level}</span>
                      </div>
                    <% end %>
                    <p :if={@inspector_secrets == []} class="text-xs text-slate-600 italic">None.</p>
                  </div>
                </div>
              </div>

              <%!-- Arcs sub-tab --%>
              <div :if={@inspector_tab == "arcs"} class="space-y-4">
                <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40">
                  <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide mb-3">Grief Arcs</h3>
                  <%= for g <- @inspector_grief_arcs do %>
                    <div class="p-3 rounded-lg bg-slate-950/60 text-xs mb-2">
                      <div class="flex items-center justify-between mb-1">
                        <span class="font-semibold text-white">Grieving: {g.subject}</span>
                        <span class="text-indigo-400 font-mono">{g.stage}</span>
                      </div>
                      <div class="h-1.5 w-full rounded-full bg-slate-800 overflow-hidden">
                        <div class="h-full rounded-full bg-indigo-500" style={"width: #{g.intensity}%"}></div>
                      </div>
                      <div class="text-slate-500 mt-1">intensity {g.intensity} · loss type {g.loss_type}</div>
                    </div>
                  <% end %>
                  <p :if={@inspector_grief_arcs == []} class="text-xs text-slate-600 italic">No active grief arcs.</p>
                </div>
                <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40">
                  <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide mb-3">Forgiveness Arcs</h3>
                  <%= for fa <- @inspector_forgiveness_arcs do %>
                    <div class="p-3 rounded-lg bg-slate-950/60 text-xs mb-2">
                      <div class="flex items-center justify-between mb-1">
                        <span class="text-white">{fa.wound_description}</span>
                        <span class="text-rose-400 font-mono">{fa.stage}</span>
                      </div>
                      <div class="text-slate-500">direction: {fa.direction} · intensity {fa.intensity}</div>
                    </div>
                  <% end %>
                  <p :if={@inspector_forgiveness_arcs == []} class="text-xs text-slate-600 italic">No active forgiveness arcs.</p>
                </div>
              </div>

              <%!-- Goals sub-tab --%>
              <div :if={@inspector_tab == "goals"} class="space-y-4">
                <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40">
                  <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide mb-3">Active Goals</h3>
                  <%= for g <- @inspector_active_goals do %>
                    <div class="p-3 rounded-lg bg-slate-950/60 text-xs mb-2">
                      <div class="flex items-center justify-between">
                        <span class="font-semibold text-white">{g.goal}</span>
                        <span class="text-blue-400 font-mono">priority {g.priority}</span>
                      </div>
                      <div class="text-slate-500 mt-0.5">{g.current_step}</div>
                    </div>
                  <% end %>
                  <p :if={@inspector_active_goals == []} class="text-xs text-slate-600 italic">No active goals.</p>
                </div>
                <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40">
                  <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide mb-3">Desires</h3>
                  <%= for d <- @inspector_desires do %>
                    <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs mb-1">
                      <span class="flex-1 text-slate-200">{d.desire}</span>
                      <span class="text-slate-400 font-mono">{d.domain}</span>
                      <span class="text-cyan-400 font-mono">urgency {d.urgency}</span>
                    </div>
                  <% end %>
                  <p :if={@inspector_desires == []} class="text-xs text-slate-600 italic">No desires.</p>
                </div>
              </div>

              <%!-- Memory sub-tab --%>
              <div :if={@inspector_tab == "memory"} class="space-y-3">
                <div class="flex items-center gap-3">
                  <form phx-change="inspector_search_memories" class="flex-1">
                    <input
                      type="text" name="query" placeholder="Search memories..."
                      class="w-full bg-slate-900 border border-slate-800 text-xs text-white rounded-xl px-3 py-2 focus:border-amber-500/50 outline-none"
                    />
                  </form>
                  <span class="text-xs text-slate-500">{length(@inspector_memories)} memories</span>
                </div>
                <div class="space-y-2 max-h-[55vh] overflow-y-auto">
                  <%= for m <- @inspector_memories do %>
                    <div class="p-3 rounded-xl border border-slate-800 bg-slate-900/40 text-xs">
                      <div class="text-slate-200 leading-normal">{m.summary}</div>
                      <div class="text-slate-600 font-mono mt-1">{format_dt(m.inserted_at)}</div>
                    </div>
                  <% end %>
                  <p :if={@inspector_memories == []} class="text-xs text-slate-600 italic py-4 text-center">No memories recorded.</p>
                </div>
              </div>

              <%!-- Theory of Mind sub-tab --%>
              <div :if={@inspector_tab == "theory_of_mind"} class="space-y-4">
                <div class="space-y-3">
                  <%= for {subject_char, entries} <- @inspector_tom_grouped do %>
                    <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40">
                      <h3 class="text-xs font-bold text-cyan-400 uppercase tracking-wide mb-2">
                        What {@inspector_char.name} knows about {subject_char.name}
                      </h3>
                      <div class="space-y-1.5">
                        <%= for e <- entries do %>
                          <div class="flex items-start gap-2 text-xs">
                            <span class={["text-[10px] px-1.5 rounded border mt-0.5", e.is_assumption && "bg-yellow-500/10 text-yellow-400 border-yellow-500/20", !e.is_assumption && "bg-blue-500/10 text-blue-400 border-blue-500/20"]}>
                              {if e.is_assumption, do: "assume", else: "fact"}
                            </span>
                            <span class="text-slate-200 flex-1">{e.known_fact}</span>
                            <span class="text-slate-600 font-mono shrink-0">{e.certainty}%</span>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                  <p :if={@inspector_tom_grouped == []} class="text-xs text-slate-600 italic py-4 text-center">No theory-of-mind entries.</p>
                </div>
                <%!-- Add ToM entry --%>
                <div class="p-4 rounded-xl border border-slate-800 bg-slate-900/40 space-y-3">
                  <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wide">Add Knowledge Entry</h3>
                  <form phx-change="inspector_update_tom_draft" phx-submit="inspector_save_tom_entry" class="space-y-3">
                    <div>
                      <label class="text-[10px] text-slate-500 uppercase font-mono">About Character</label>
                      <select name="subject_id" class="w-full bg-slate-900 border border-slate-800 text-xs text-white rounded-lg px-2 py-1.5 mt-1">
                        <option value="">Select character...</option>
                        <%= for c <- @inspector_tom_all_chars do %>
                          <option value={c.id} selected={@inspector_tom_draft_subject_id == c.id}>{c.name}</option>
                        <% end %>
                      </select>
                    </div>
                    <div>
                      <label class="text-[10px] text-slate-500 uppercase font-mono">Known Fact / Assumption</label>
                      <input type="text" name="known_fact" value={@inspector_tom_draft_fact}
                        placeholder="e.g. She is hiding something about the Bastion..."
                        class="w-full bg-slate-900 border border-slate-800 text-xs text-white rounded-lg px-2 py-1.5 mt-1 focus:border-amber-500/50 outline-none"/>
                    </div>
                    <div class="flex items-center gap-4">
                      <div class="flex-1">
                        <label class="text-[10px] text-slate-500 uppercase font-mono">Certainty — {@inspector_tom_draft_certainty}%</label>
                        <input type="range" name="certainty" min="0" max="100" value={@inspector_tom_draft_certainty} class="w-full accent-amber-500 mt-1"/>
                      </div>
                      <label class="flex items-center gap-1.5 text-xs text-slate-300 cursor-pointer">
                        <input type="checkbox" name="is_assumption" value="true" checked={@inspector_tom_draft_assumption} class="rounded text-amber-500"/>
                        Assumption
                      </label>
                    </div>
                    <button type="submit" class="w-full py-2 rounded-lg bg-cyan-500/10 border border-cyan-500/30 text-cyan-400 text-xs font-semibold hover:bg-cyan-500/20 transition-colors">
                      Save Knowledge Entry
                    </button>
                  </form>
                  <div :if={@inspector_tom_save_result == :ok} class="text-xs text-emerald-400">Saved.</div>
                  <div :if={@inspector_tom_save_result == :error} class="text-xs text-red-400">Select a character and enter a fact.</div>
                </div>
              </div>

            <% else %>
              <div class="flex flex-col items-center justify-center h-64 text-center">
                <.icon name="hero-users" class="size-10 text-slate-800 mb-3" />
                <p class="text-sm text-slate-500">Select a character from the roster to inspect their soul data.</p>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- ── CREATE NPC TAB ──────────────────────────────────────── --%>
        <div :if={@sauce_tab == "create_npc"} class="col-span-1 lg:col-span-3">
          <div class="max-w-2xl mx-auto">
            <div class="mb-6 flex items-center justify-between">
              <div>
                <h2 class="text-lg font-bold text-white">NPC Creator Wizard</h2>
                <p class="text-xs text-slate-400">Step {@w_step} of 7 — fill out each section, then submit.</p>
              </div>
            </div>
            <%!-- Step progress --%>
            <div class="flex gap-1 mb-6">
              <%= for s <- 1..7 do %>
                <button phx-click="w_goto_step" phx-value-step={s}
                  class={["h-2 flex-1 rounded-full transition-all", s == @w_step && "bg-amber-400", s < @w_step && "bg-amber-700", s > @w_step && "bg-slate-800"]}>
                </button>
              <% end %>
            </div>
            <%!-- Errors --%>
            <div :if={@w_errors != []} class="mb-4 p-3 rounded-xl border border-red-800/50 bg-red-900/20 text-red-400 text-xs space-y-1">
              <%= for err <- @w_errors do %><div>{err}</div><% end %>
            </div>

            <%!-- Step 1: Identity --%>
            <div :if={@w_step == 1} class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-4">
              <h3 class="text-base font-bold text-amber-400">Step 1 — Identity</h3>
              <form phx-change="w_update_identity" class="space-y-4">
                <div>
                  <label class="block text-xs text-slate-400 mb-1 font-semibold uppercase">Name</label>
                  <input type="text" name="name" value={@w_name} phx-blur="w_auto_slug"
                    class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500/50" placeholder="e.g. Morrigan"/>
                </div>
                <div>
                  <label class="block text-xs text-slate-400 mb-1 font-semibold uppercase">Slug</label>
                  <input type="text" name="slug" value={@w_slug}
                    class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-sm text-white font-mono focus:outline-none focus:border-amber-500/50" placeholder="auto-generated"/>
                </div>
                <div>
                  <label class="block text-xs text-slate-400 mb-1 font-semibold uppercase">Description / Personality</label>
                  <textarea name="description" rows="4"
                    class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500/50"
                    placeholder="Who is this character? What drives them?">{@w_description}</textarea>
                </div>
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-xs text-slate-400 mb-1 font-semibold uppercase">Kind</label>
                    <select name="kind" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500/50">
                      <%= for k <- ~w(npc player creature system) do %>
                        <option value={k} selected={@w_kind == k}>{k}</option>
                      <% end %>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs text-slate-400 mb-1 font-semibold uppercase">Status</label>
                    <select name="status" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500/50">
                      <option value="active" selected={@w_status == "active"}>active</option>
                      <option value="inactive" selected={@w_status == "inactive"}>inactive</option>
                    </select>
                  </div>
                </div>
              </form>
            </div>

            <%!-- Step 2: Personality --%>
            <div :if={@w_step == 2} class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-4">
              <h3 class="text-base font-bold text-amber-400">Step 2 — Personality</h3>
              <form phx-change="w_update_personality" class="space-y-4">
                <div>
                  <label class="block text-xs text-slate-400 mb-1 font-semibold uppercase">Attachment Style</label>
                  <select name="attachment_style" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500/50">
                    <option value="secure" selected={@w_attachment_style == "secure"}>Secure</option>
                    <option value="anxious" selected={@w_attachment_style == "anxious"}>Anxious — fears abandonment</option>
                    <option value="avoidant" selected={@w_attachment_style == "avoidant"}>Avoidant — self-reliant</option>
                    <option value="disorganized" selected={@w_attachment_style == "disorganized"}>Disorganized — craves and fears</option>
                  </select>
                </div>
                <div>
                  <label class="block text-xs text-slate-400 mb-1 font-semibold uppercase">Humor Style</label>
                  <select name="humor_style" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500/50">
                    <%= for s <- ~w(none dry sarcastic warm dark absurdist) do %>
                      <option value={s} selected={@w_humor_style == s}>{String.capitalize(s)}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="block text-xs text-slate-400 mb-1 font-semibold uppercase">
                    Emotional Porousness — {@w_emotional_susceptibility}
                  </label>
                  <input type="range" name="emotional_susceptibility" min="0" max="100" value={@w_emotional_susceptibility} class="w-full accent-amber-500"/>
                </div>
                <div>
                  <label class="block text-xs text-slate-400 mb-1 font-semibold uppercase">Speech Style</label>
                  <textarea name="speech_style" rows="2"
                    class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500/50"
                    placeholder="Terse? Verbose? Formal? Folksy?">{@w_speech_style}</textarea>
                </div>
              </form>
              <div>
                <label class="block text-xs text-slate-400 mb-2 font-semibold uppercase">Personality Flags</label>
                <div class="grid grid-cols-2 gap-2">
                  <%= for {trait, active} <- @w_personality_traits do %>
                    <button phx-click="w_toggle_trait" phx-value-trait={trait}
                      class={["flex items-center gap-2 px-3 py-2 rounded-xl border text-sm transition-all",
                        active && "bg-purple-500/20 border-purple-500/40 text-purple-300",
                        !active && "bg-slate-800/60 border-slate-700/60 text-slate-500 hover:text-slate-300"]}>
                      <div class={"w-2 h-2 rounded-full #{if active, do: "bg-purple-400", else: "bg-slate-600"}"}></div>
                      {String.capitalize(trait)}
                    </button>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Step 3: Soul --%>
            <div :if={@w_step == 3} class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-5">
              <h3 class="text-base font-bold text-amber-400">Step 3 — Soul</h3>
              <div>
                <label class="block text-xs text-slate-400 mb-2 font-semibold uppercase">Core Values</label>
                <div class="flex flex-wrap gap-2 mb-2">
                  <%= for v <- @w_core_values do %>
                    <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-300 text-xs">
                      {v}
                      <button phx-click="w_remove_core_value" phx-value-value={v} type="button">
                        <.icon name="hero-x-mark" class="size-3" />
                      </button>
                    </span>
                  <% end %>
                </div>
                <form phx-submit="w_add_core_value" class="flex gap-2">
                  <input type="text" name="value" value={@w_core_value_input} phx-change="w_update_core_value_input"
                    placeholder="e.g. loyalty, justice, survival"
                    class="flex-1 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500/50"/>
                  <button type="submit" class="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs text-white border border-slate-700">Add</button>
                </form>
              </div>
              <div>
                <label class="block text-xs text-slate-400 mb-2 font-semibold uppercase">Baseline Emotions</label>
                <div class="space-y-2">
                  <%= for {label, key} <- [{"Anger", "anger"}, {"Fear", "fear"}, {"Stress", "stress"}, {"Gratitude", "gratitude"}, {"Confidence", "confidence"}, {"Sadness", "sadness"}] do %>
                    <div class="flex items-center gap-3">
                      <label class="w-24 text-xs text-slate-400 shrink-0">{label}</label>
                      <input type="range" min="0" max="100" value={Map.get(@w_baseline_emotions, key, 0)}
                        phx-change="w_update_baseline_emotion" phx-value-emotion={key}
                        class="flex-1 accent-amber-500"/>
                      <span class="text-xs text-slate-300 w-8 font-mono">{Map.get(@w_baseline_emotions, key, 0)}</span>
                    </div>
                  <% end %>
                </div>
              </div>
              <div>
                <label class="block text-xs text-slate-400 mb-2 font-semibold uppercase">Physical Tells</label>
                <div class="space-y-2">
                  <%= for {label, key} <- [{"Anger", "anger"}, {"Fear", "fear"}, {"Sadness", "sadness"}, {"Shame", "shame"}, {"Stress", "stress"}] do %>
                    <div class="flex items-center gap-3">
                      <label class="w-20 text-xs text-slate-400 shrink-0">{label}</label>
                      <input type="text" value={Map.get(@w_physical_tells, key, "")}
                        phx-change="w_update_physical_tell" phx-value-emotion={key}
                        placeholder={"How does #{String.downcase(label)} manifest physically?"}
                        class="flex-1 bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Step 4: Psychology --%>
            <div :if={@w_step == 4} class="space-y-4">
              <div class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-3">
                <h3 class="text-base font-bold text-amber-400">Step 4 — Psychology</h3>
                <h4 class="text-xs font-bold text-slate-400 uppercase">Beliefs</h4>
                <form phx-change="w_update_belief_draft" class="grid grid-cols-3 gap-2">
                  <input type="text" name="belief" value={@w_belief_draft["belief"]} placeholder="A truth they hold..."
                    class="col-span-2 bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <select name="domain" class="bg-slate-950 border border-slate-800 rounded-lg px-2 py-1.5 text-xs text-white focus:outline-none">
                    <%= for d <- ~w(social survival moral love power identity duty) do %>
                      <option value={d} selected={@w_belief_draft["domain"] == d}>{d}</option>
                    <% end %>
                  </select>
                  <div class="col-span-3 flex items-center gap-3">
                    <label class="text-xs text-slate-400">Conviction</label>
                    <input type="range" name="conviction" min="0" max="100" value={@w_belief_draft["conviction"]} class="flex-1 accent-amber-500"/>
                    <span class="text-xs font-mono text-slate-300">{@w_belief_draft["conviction"]}</span>
                    <button type="button" phx-click="w_add_belief" class="px-3 py-1 rounded-lg bg-amber-500/10 border border-amber-500/30 text-amber-400 text-xs hover:bg-amber-500/20">Add</button>
                  </div>
                </form>
                <div class="space-y-1.5">
                  <%= for {b, i} <- Enum.with_index(@w_beliefs) do %>
                    <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs">
                      <span class="flex-1 text-slate-200">{b["belief"]}</span>
                      <span class="text-slate-400 font-mono">{b["domain"]} · {b["conviction"]}</span>
                      <button phx-click="w_remove_belief" phx-value-index={i} class="text-slate-600 hover:text-rose-400">×</button>
                    </div>
                  <% end %>
                </div>
              </div>
              <div class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-3">
                <h4 class="text-xs font-bold text-slate-400 uppercase">Emotional Triggers</h4>
                <form phx-change="w_update_trigger_draft" class="grid grid-cols-2 gap-2">
                  <input type="text" name="topic" value={@w_trigger_draft["topic"]} placeholder="Topic that triggers them..."
                    class="bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <select name="reaction_type" class="bg-slate-950 border border-slate-800 rounded-lg px-2 py-1.5 text-xs text-white">
                    <%= for r <- ~w(anger_spike fear_spike grief_spike pride_surge shame_trigger) do %>
                      <option value={r} selected={@w_trigger_draft["reaction_type"] == r}>{r}</option>
                    <% end %>
                  </select>
                  <input type="text" name="flavor_text" value={@w_trigger_draft["flavor_text"] || ""} placeholder="Flavor text (optional)"
                    class="col-span-2 bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <button type="button" phx-click="w_add_trigger" class="col-span-2 py-1.5 rounded-lg bg-slate-800 border border-slate-700 text-xs text-white hover:bg-slate-700">+ Add Trigger</button>
                </form>
                <div class="space-y-1.5">
                  <%= for {t, i} <- Enum.with_index(@w_triggers) do %>
                    <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs">
                      <span class="font-semibold text-white">{t["topic"]}</span>
                      <span class="text-slate-400">→ {t["reaction_type"]}</span>
                      <button phx-click="w_remove_trigger" phx-value-index={i} class="ml-auto text-slate-600 hover:text-rose-400">×</button>
                    </div>
                  <% end %>
                </div>
              </div>
              <div class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-3">
                <h4 class="text-xs font-bold text-slate-400 uppercase">Moral Lines</h4>
                <form phx-change="w_update_moral_line_draft" class="flex gap-2">
                  <input type="text" name="principle" value={@w_moral_line_draft["principle"]} placeholder="A line they will not cross..."
                    class="flex-1 bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <button type="button" phx-click="w_add_moral_line" class="px-3 py-1.5 rounded-lg bg-slate-800 border border-slate-700 text-xs text-white hover:bg-slate-700">Add</button>
                </form>
                <div class="space-y-1.5">
                  <%= for {ml, i} <- Enum.with_index(@w_moral_lines) do %>
                    <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs">
                      <span class="flex-1 text-slate-200">{ml["principle"]}</span>
                      <button phx-click="w_remove_moral_line" phx-value-index={i} class="text-slate-600 hover:text-rose-400">×</button>
                    </div>
                  <% end %>
                </div>
                <h4 class="text-xs font-bold text-slate-400 uppercase pt-2">Secrets</h4>
                <form phx-change="w_update_secret_draft" class="grid grid-cols-3 gap-2">
                  <input type="text" name="secret_text" value={@w_secret_draft["secret_text"]} placeholder="The secret..."
                    class="col-span-2 bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <select name="risk_level" class="bg-slate-950 border border-slate-800 rounded-lg px-2 py-1.5 text-xs text-white">
                    <%= for r <- ~w(low medium high critical) do %>
                      <option value={r} selected={@w_secret_draft["risk_level"] == r}>{r}</option>
                    <% end %>
                  </select>
                  <button type="button" phx-click="w_add_secret" class="col-span-3 py-1.5 rounded-lg bg-slate-800 border border-slate-700 text-xs text-white hover:bg-slate-700">+ Add Secret</button>
                </form>
                <div class="space-y-1.5">
                  <%= for {s, i} <- Enum.with_index(@w_secrets) do %>
                    <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs">
                      <span class="flex-1 text-slate-200">{s["secret_text"]}</span>
                      <span class="text-rose-400 font-mono">{s["risk_level"]}</span>
                      <button phx-click="w_remove_secret" phx-value-index={i} class="text-slate-600 hover:text-rose-400">×</button>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Step 5: Desires & Goals --%>
            <div :if={@w_step == 5} class="space-y-4">
              <div class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-3">
                <h3 class="text-base font-bold text-amber-400">Step 5 — Desires & Goals</h3>
                <h4 class="text-xs font-bold text-slate-400 uppercase">Desires</h4>
                <form phx-change="w_update_desire_draft" class="grid grid-cols-3 gap-2">
                  <input type="text" name="desire" value={@w_desire_draft["desire"]} placeholder="What do they crave?"
                    class="col-span-2 bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <select name="domain" class="bg-slate-950 border border-slate-800 rounded-lg px-2 py-1.5 text-xs text-white">
                    <%= for d <- ~w(connection power safety knowledge belonging freedom revenge) do %>
                      <option value={d} selected={@w_desire_draft["domain"] == d}>{d}</option>
                    <% end %>
                  </select>
                  <div class="col-span-3 flex items-center gap-3">
                    <label class="text-xs text-slate-400">Urgency</label>
                    <input type="range" name="urgency" min="0" max="100" value={@w_desire_draft["urgency"]} class="flex-1 accent-amber-500"/>
                    <span class="text-xs font-mono text-slate-300 w-8">{@w_desire_draft["urgency"]}</span>
                    <button type="button" phx-click="w_add_desire" class="px-3 py-1 rounded-lg bg-amber-500/10 border border-amber-500/30 text-amber-400 text-xs hover:bg-amber-500/20">Add</button>
                  </div>
                </form>
                <div class="space-y-1.5">
                  <%= for {d, i} <- Enum.with_index(@w_desires) do %>
                    <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs">
                      <span class="flex-1 text-slate-200">{d["desire"]}</span>
                      <span class="text-slate-400 font-mono">{d["domain"]} · urgency {d["urgency"]}</span>
                      <button phx-click="w_remove_desire" phx-value-index={i} class="text-slate-600 hover:text-rose-400">×</button>
                    </div>
                  <% end %>
                </div>
              </div>
              <div class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-3">
                <h4 class="text-xs font-bold text-slate-400 uppercase">Goals</h4>
                <form phx-change="w_update_goal_draft" class="space-y-2">
                  <input type="text" name="goal" value={@w_goal_draft["goal"]} placeholder="What are they working toward?"
                    class="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <input type="text" name="current_step" value={@w_goal_draft["current_step"]} placeholder="Current step toward the goal..."
                    class="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <div class="flex items-center gap-3">
                    <label class="text-xs text-slate-400">Priority</label>
                    <input type="range" name="priority" min="0" max="100" value={@w_goal_draft["priority"]} class="flex-1 accent-amber-500"/>
                    <span class="text-xs font-mono text-slate-300 w-8">{@w_goal_draft["priority"]}</span>
                    <button type="button" phx-click="w_add_goal" class="px-3 py-1 rounded-lg bg-blue-500/10 border border-blue-500/30 text-blue-400 text-xs hover:bg-blue-500/20">Add</button>
                  </div>
                </form>
                <div class="space-y-1.5">
                  <%= for {g, i} <- Enum.with_index(@w_goals) do %>
                    <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs">
                      <span class="flex-1 text-slate-200">{g["goal"]}</span>
                      <span class="text-blue-400 font-mono">priority {g["priority"]}</span>
                      <button phx-click="w_remove_goal" phx-value-index={i} class="text-slate-600 hover:text-rose-400">×</button>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Step 6: Backstory / Arcs --%>
            <div :if={@w_step == 6} class="space-y-4">
              <div class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-3">
                <h3 class="text-base font-bold text-amber-400">Step 6 — Backstory & Arcs</h3>
                <h4 class="text-xs font-bold text-slate-400 uppercase">Grief Arcs</h4>
                <form phx-change="w_update_grief_draft" class="grid grid-cols-2 gap-2">
                  <input type="text" name="subject" value={@w_grief_draft["subject"]} placeholder="Who / what was lost?"
                    class="bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <select name="loss_type" class="bg-slate-950 border border-slate-800 rounded-lg px-2 py-1.5 text-xs text-white">
                    <%= for l <- ~w(person place identity purpose relationship innocence) do %>
                      <option value={l} selected={@w_grief_draft["loss_type"] == l}>{l}</option>
                    <% end %>
                  </select>
                  <select name="stage" class="bg-slate-950 border border-slate-800 rounded-lg px-2 py-1.5 text-xs text-white">
                    <%= for s <- ~w(denial anger bargaining depression integration) do %>
                      <option value={s} selected={@w_grief_draft["stage"] == s}>{s}</option>
                    <% end %>
                  </select>
                  <div class="flex items-center gap-2">
                    <label class="text-xs text-slate-400 shrink-0">Intensity</label>
                    <input type="range" name="intensity" min="0" max="100" value={@w_grief_draft["intensity"]} class="flex-1 accent-indigo-500"/>
                    <span class="text-xs font-mono text-slate-300 w-8">{@w_grief_draft["intensity"]}</span>
                  </div>
                  <button type="button" phx-click="w_add_grief_arc" class="col-span-2 py-1.5 rounded-lg bg-slate-800 border border-slate-700 text-xs text-white hover:bg-slate-700">+ Add Grief Arc</button>
                </form>
                <div class="space-y-1.5">
                  <%= for {g, i} <- Enum.with_index(@w_grief_arcs) do %>
                    <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs">
                      <span class="text-white">Grieving: {g["subject"]}</span>
                      <span class="text-indigo-400 font-mono">{g["stage"]}</span>
                      <button phx-click="w_remove_grief_arc" phx-value-index={i} class="ml-auto text-slate-600 hover:text-rose-400">×</button>
                    </div>
                  <% end %>
                </div>
              </div>
              <div class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-3">
                <h4 class="text-xs font-bold text-slate-400 uppercase">Forgiveness Arcs</h4>
                <form phx-change="w_update_forgiveness_draft" class="grid grid-cols-2 gap-2">
                  <input type="text" name="wound_description" value={@w_forgiveness_draft["wound_description"]} placeholder="The wound / betrayal..."
                    class="col-span-2 bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                  <select name="stage" class="bg-slate-950 border border-slate-800 rounded-lg px-2 py-1.5 text-xs text-white">
                    <%= for s <- ~w(fresh festering processing forgiven hardened) do %>
                      <option value={s} selected={@w_forgiveness_draft["stage"] == s}>{s}</option>
                    <% end %>
                  </select>
                  <select name="direction" class="bg-slate-950 border border-slate-800 rounded-lg px-2 py-1.5 text-xs text-white">
                    <option value="neutral" selected={@w_forgiveness_draft["direction"] == "neutral"}>Neutral</option>
                    <option value="healing" selected={@w_forgiveness_draft["direction"] == "healing"}>Healing</option>
                    <option value="hardening" selected={@w_forgiveness_draft["direction"] == "hardening"}>Hardening</option>
                  </select>
                  <button type="button" phx-click="w_add_forgiveness_arc" class="col-span-2 py-1.5 rounded-lg bg-slate-800 border border-slate-700 text-xs text-white hover:bg-slate-700">+ Add Forgiveness Arc</button>
                </form>
                <div class="space-y-1.5">
                  <%= for {fa, i} <- Enum.with_index(@w_forgiveness_arcs) do %>
                    <div class="flex items-center gap-2 p-2 rounded-lg bg-slate-950/60 text-xs">
                      <span class="flex-1 text-slate-200">{fa["wound_description"]}</span>
                      <span class="text-rose-400 font-mono">{fa["stage"]}</span>
                      <button phx-click="w_remove_forgiveness_arc" phx-value-index={i} class="text-slate-600 hover:text-rose-400">×</button>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Step 7: Physical & Social --%>
            <div :if={@w_step == 7} class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-4">
              <h3 class="text-base font-bold text-amber-400">Step 7 — Physical & Social</h3>
              <form phx-change="w_update_stamina" class="space-y-3">
                <div class="grid grid-cols-3 gap-3">
                  <%= for {label, name, val} <- [{"Social Stamina", "social_stamina", @w_social_stamina}, {"Stamina Max", "stamina_max", @w_stamina_max}, {"Regen/hr", "stamina_regen_rate", @w_stamina_regen_rate}] do %>
                    <div>
                      <label class="block text-[10px] text-slate-400 mb-1 uppercase font-mono">{label}</label>
                      <input type="number" name={name} value={val} min="0" max="100"
                        class="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                    </div>
                  <% end %>
                </div>
                <div class="grid grid-cols-2 gap-3">
                  <%= for {label, name, val} <- [{"Hunger", "hunger", @w_hunger}, {"Pain", "pain", @w_pain}, {"Fatigue", "fatigue", @w_fatigue}, {"Illness Severity", "illness_severity", @w_illness_severity}] do %>
                    <div>
                      <label class="block text-[10px] text-slate-400 mb-1 uppercase font-mono">{label}</label>
                      <input type="number" name={name} value={val} min="0" max="100"
                        class="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none focus:border-amber-500/50"/>
                    </div>
                  <% end %>
                </div>
              </form>
              <div class="pt-2 space-y-2">
                <p class="text-xs text-slate-400">Everything looks good? Click Create to initialize the full soul.</p>
                <button phx-click="w_create_npc" class="w-full py-3 rounded-xl font-bold bg-gradient-to-tr from-amber-500 to-orange-400 text-slate-950 hover:shadow-lg hover:shadow-amber-500/20 transition-all">
                  Create NPC + Initialize Soul
                </button>
              </div>
            </div>

            <%!-- Wizard Nav Buttons --%>
            <div class="flex justify-between mt-4">
              <button :if={@w_step > 1} phx-click="w_prev_step"
                class="px-5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-white text-sm font-semibold border border-slate-700">
                ← Back
              </button>
              <div :if={@w_step == 1}></div>
              <button :if={@w_step < 7} phx-click="w_next_step"
                class="px-5 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 text-sm font-bold">
                Next →
              </button>
            </div>
          </div>
        </div>

        <%!-- ── SOCIAL LOG TAB ──────────────────────────────────────── --%>
        <div :if={@sauce_tab == "social"} class="col-span-1 lg:col-span-3 flex gap-4 min-h-[70vh]">
          <aside class="w-64 shrink-0 overflow-y-auto space-y-0.5">
            <div class="flex items-center justify-between mb-2">
              <span class="text-[10px] uppercase font-mono text-slate-500 px-1">Autonomous Scenes</span>
              <div class="flex gap-1">
                <button phx-click="social_refresh" class="text-[10px] text-slate-500 hover:text-slate-300 px-2 py-1 rounded border border-slate-800 hover:border-slate-600">Refresh</button>
                <button phx-click="social_trigger_tick" class="text-[10px] text-amber-400 hover:text-amber-300 px-2 py-1 rounded border border-amber-500/30 hover:border-amber-500/50">Trigger Tick</button>
              </div>
            </div>
            <%= if @social_scenes == [] do %>
              <div class="text-center p-6 text-xs text-slate-600 italic">No autonomous scenes yet.</div>
            <% else %>
              <%= for scene <- @social_scenes do %>
                <button
                  phx-click="social_select_scene"
                  phx-value-id={scene.id}
                  class={[
                    "w-full text-left p-3 rounded-xl border transition-colors",
                    @social_selected && @social_selected.id == scene.id && "bg-amber-500/10 border-amber-500/30",
                    (!@social_selected || @social_selected.id != scene.id) && "bg-slate-900/40 border-slate-800 hover:bg-slate-800/60"
                  ]}
                >
                  <div class="text-xs font-bold text-slate-200 truncate">{scene.title}</div>
                  <div class="text-[10px] text-slate-500">{scene.status} · {format_time(scene.inserted_at)}</div>
                </button>
              <% end %>
            <% end %>
          </aside>

          <div class="flex-1 min-w-0 flex flex-col">
            <%= if @social_selected do %>
              <div class="flex items-center gap-3 p-4 border-b border-slate-800 bg-slate-900/30 rounded-t-xl">
                <div class="flex-1">
                  <div class="text-sm font-bold text-white">{@social_selected.title}</div>
                  <div class="text-[10px] text-slate-500">{@social_selected.location} · {@social_selected.status}</div>
                </div>
                <div class="flex gap-1.5">
                  <%= for part <- @social_selected.participants do %>
                    <span class="text-[9px] px-2 py-0.5 rounded border bg-amber-500/10 text-amber-400 border-amber-500/20 font-semibold">
                      {part.character.name}
                    </span>
                  <% end %>
                </div>
              </div>
              <div class="flex-1 overflow-y-auto p-4 space-y-3 max-h-[60vh]">
                <%= if @social_messages == [] do %>
                  <div class="text-center text-xs text-slate-600 italic py-8">No messages in this scene.</div>
                <% else %>
                  <%= for msg <- @social_messages do %>
                    <div class="flex gap-3 max-w-[85%]">
                      <div class="shrink-0 w-7 h-7 rounded-full flex items-center justify-center text-[10px] font-bold bg-amber-500/20 text-amber-400 border border-amber-500/30">
                        {String.first(social_char_name(@social_selected.participants, msg.character_id))}
                      </div>
                      <div class="flex-1 min-w-0">
                        <div class="text-[10px] font-semibold text-amber-400/75 mb-0.5">
                          {social_char_name(@social_selected.participants, msg.character_id)}
                          <span class="text-slate-600 font-normal ml-2">{format_time(msg.inserted_at)}</span>
                        </div>
                        <div class="px-3 py-2 rounded-2xl rounded-tl-md bg-slate-900 border border-slate-800 text-xs leading-relaxed text-slate-200">
                          <p class="whitespace-pre-wrap break-words">{msg.content}</p>
                          <div :if={msg.private_thought && msg.private_thought != ""} class="mt-1.5 pt-1 border-t border-purple-500/20 text-[10px] text-purple-400 font-mono">
                            Thought: {msg.private_thought}
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% else %>
              <div class="flex-1 flex flex-col items-center justify-center text-center p-8">
                <.icon name="hero-chat-bubble-left-right" class="size-10 text-slate-800 mb-3" />
                <p class="text-sm text-slate-500">Select a scene to view the conversation.</p>
              </div>
            <% end %>
          </div>
        </div>

      </main>

      <%!-- Edit Character Modal --%>
      <div
        :if={@editing_character}
        class="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      >
        <div class="w-full max-w-lg p-6 bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl space-y-6">
          <div class="text-center">
            <h2 class="text-lg font-bold text-white">Edit Character Details & Motives</h2>
            <p class="text-sm text-slate-400">
              Modify description or current objectives for {@editing_character &&
                @editing_character.name}
            </p>
          </div>

          <.form
            for={Characters.change_character(@editing_character || %Characters.Character{})}
            phx-submit="update_character"
            class="space-y-4"
          >
            <div class="space-y-1.5 text-sm">
              <label class="text-xs font-bold text-slate-400 uppercase">
                Description, Motives, or Context
              </label>
              <textarea
                name="character[description]"
                rows="6"
                required
                class="w-full bg-slate-950 border border-slate-800 text-white rounded-xl p-3 focus:border-amber-500/50 outline-none font-sans leading-relaxed"
                placeholder="Declare their current drives, emotions, or narrative motives..."
              ><%= @editing_character && @editing_character.description %></textarea>
              <p class="text-[10px] text-slate-500 leading-normal">
                This is fed directly into the character's system prompt (e.g. <code>You are Name, Description</code>).
                Update this to alter their active objectives, emotional shifts, or memories of events.
              </p>
            </div>

            <%!-- Psychological Conditions / Traits --%>
            <div class="space-y-2 border-t border-slate-800 pt-4">
              <label class="text-xs font-bold text-slate-400 uppercase flex items-center gap-1.5">
                <.icon name="hero-cpu-chip" class="size-4 text-amber-400" />
                Cognitive Conditions & Traits
              </label>

              <div class="grid grid-cols-2 gap-3 text-xs">
                <%= for {trait_key, label} <- [
                  {"depression", "Depression"},
                  {"bipolar", "Bipolar Disorder"},
                  {"ocd", "Obsessive Compulsive"},
                  {"splitting", "Splitting (BPD)"},
                  {"adhd", "ADHD / Hyperactive"},
                  {"narcissism", "Narcissism / Fragility"},
                  {"impostor", "Impostor Syndrome"},
                  {"codependency", "Codependency"},
                  {"addiction", "Addiction / Craving"},
                  {"hypochondria", "Hypochondria"}
                ] do %>
                  <label class="flex items-center gap-2 text-slate-300 hover:text-white cursor-pointer select-none">
                    <input
                      type="hidden"
                      name={"character[traits_#{trait_key}]"}
                      value="false"
                    />
                    <input
                      type="checkbox"
                      name={"character[traits_#{trait_key}]"}
                      value="true"
                      checked={
                        get_in(
                          (@editing_character_profile && @editing_character_profile.personality_traits) ||
                            %{},
                          [trait_key]
                        ) == true
                      }
                      class="rounded bg-slate-950 border-slate-800 text-amber-500 focus:ring-amber-500/25"
                    />
                    <span>{label}</span>
                  </label>
                <% end %>
              </div>
            </div>

            <div class="flex gap-3 justify-end pt-2 text-sm font-semibold">
              <button
                type="button"
                phx-click="close_edit_character"
                class="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-white transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-5 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 transition-colors"
              >
                Save Changes
              </button>
            </div>
          </.form>

          <%!-- Fears and Phobias Section --%>
          <div class="space-y-3 border-t border-slate-800 pt-4">
            <label class="text-xs font-bold text-slate-400 uppercase flex items-center gap-1.5">
              <.icon name="hero-fire" class="size-4 text-rose-400" /> Active Fears & Phobias
            </label>

            <div class="space-y-2 max-h-40 overflow-y-auto">
              <%= for fear <- @editing_character_fears do %>
                <div class="flex items-center justify-between p-2 rounded bg-slate-950 border border-slate-800/80 text-xs">
                  <div>
                    <span class="font-bold text-white">{fear.fear_type}</span>
                    <span class="text-[10px] text-slate-500 font-mono ml-2">({fear.origin})</span>
                    <span class="text-[10px] ml-2 px-1.5 py-0.5 rounded bg-rose-500/10 text-rose-400 border border-rose-500/20">
                      {fear.severity}/100
                    </span>
                  </div>
                  <div>
                    <button
                      :if={fear.status == "active"}
                      type="button"
                      phx-click="resolve_fear"
                      phx-value-id={fear.id}
                      class="text-[10px] font-semibold text-emerald-400 hover:text-emerald-300 px-2 py-1"
                    >
                      Resolve
                    </button>
                    <span
                      :if={fear.status == "resolved"}
                      class="text-[10px] text-emerald-500 font-semibold px-2 py-1"
                    >
                      Resolved
                    </span>
                  </div>
                </div>
              <% end %>
              <p :if={@editing_character_fears == []} class="text-xs text-slate-500 italic">
                No fears configured for this character.
              </p>
            </div>

            <%!-- Add Fear Form --%>
            <form phx-submit="add_fear" class="flex gap-2">
              <input
                type="text"
                name="fear_type"
                placeholder="Add new fear (e.g. spiders, heights)"
                class="flex-1 bg-slate-950 border border-slate-800 text-xs text-white rounded-xl px-3 py-1.5 focus:border-amber-500/50 outline-none"
                required
              />
              <button
                type="submit"
                class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs text-white transition-colors border border-slate-700"
              >
                Add
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ─── Tab routing ───────────────────────────────────────────────────────────

  @impl true
  def handle_event("switch_sauce_tab", %{"tab" => "social"}, socket) do
    scenes = Scenes.list_autonomous_scenes(limit: 50)
    {socket, messages} =
      case scenes do
        [first | _] ->
          scene = SovereignSoulEngine.Repo.preload(first, [participants: :character], force: true)
          {assign(socket, :social_selected, scene), Scenes.list_messages(scene.id)}
        _ -> {assign(socket, :social_selected, nil), []}
      end
    {:noreply, socket |> assign(:sauce_tab, "social") |> assign(:social_scenes, scenes) |> assign(:social_messages, messages)}
  end

  def handle_event("switch_sauce_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :sauce_tab, tab)}
  end

  # ─── Social Log tab ────────────────────────────────────────────────────────

  @impl true
  def handle_event("social_select_scene", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.social_scenes, &(&1.id == id)) do
      nil ->
        {:noreply, socket}
      scene ->
        scene = SovereignSoulEngine.Repo.preload(scene, [participants: :character], force: true)
        messages = Scenes.list_messages(scene.id)
        {:noreply, socket |> assign(:social_selected, scene) |> assign(:social_messages, messages)}
    end
  end

  @impl true
  def handle_event("social_trigger_tick", _params, socket) do
    NPCScheduler.trigger_tick()
    :timer.sleep(800)
    scenes = Scenes.list_autonomous_scenes(limit: 50)
    {:noreply, assign(socket, :social_scenes, scenes)}
  end

  @impl true
  def handle_event("social_refresh", _params, socket) do
    scenes = Scenes.list_autonomous_scenes(limit: 50)
    messages =
      case socket.assigns.social_selected do
        nil -> []
        s -> Scenes.list_messages(s.id)
      end
    {:noreply, socket |> assign(:social_scenes, scenes) |> assign(:social_messages, messages)}
  end

  # ─── Character Inspector tab ───────────────────────────────────────────────

  @impl true
  def handle_event("inspector_select_char", %{"id" => id}, socket) do
    socket = load_inspector_char(socket, id) |> assign(:inspector_tab, "vitals")
    {:noreply, socket}
  end

  @impl true
  def handle_event("inspector_switch_tab", %{"tab" => tab}, socket) do
    tab = if tab in @inspector_tabs, do: tab, else: "vitals"
    id = socket.assigns.inspector_char && socket.assigns.inspector_char.id
    socket = if id, do: load_inspector_tab(socket, tab, id), else: socket
    {:noreply, assign(socket, :inspector_tab, tab)}
  end

  @impl true
  def handle_event("inspector_update_tom_draft", params, socket) do
    {:noreply,
     socket
     |> assign(:inspector_tom_draft_fact, Map.get(params, "known_fact", socket.assigns.inspector_tom_draft_fact))
     |> assign(:inspector_tom_draft_certainty, parse_int(params["certainty"], socket.assigns.inspector_tom_draft_certainty))
     |> assign(:inspector_tom_draft_assumption, Map.get(params, "is_assumption", "true") == "true")
     |> assign(:inspector_tom_draft_subject_id, Map.get(params, "subject_id", socket.assigns.inspector_tom_draft_subject_id))}
  end

  @impl true
  def handle_event("inspector_save_tom_entry", _params, socket) do
    id = socket.assigns.inspector_char && socket.assigns.inspector_char.id
    subject_id = socket.assigns.inspector_tom_draft_subject_id
    fact = socket.assigns.inspector_tom_draft_fact
    if id && subject_id && String.trim(fact) != "" do
      TheoryOfMind.upsert_knowledge(id, subject_id, fact,
        certainty: socket.assigns.inspector_tom_draft_certainty,
        is_assumption: socket.assigns.inspector_tom_draft_assumption)
      {:noreply,
       socket
       |> assign(:inspector_tom_draft_fact, "")
       |> assign(:inspector_tom_draft_certainty, 70)
       |> assign(:inspector_tom_save_result, :ok)
       |> load_inspector_tab("theory_of_mind", id)}
    else
      {:noreply, assign(socket, :inspector_tom_save_result, :error)}
    end
  end

  @impl true
  def handle_event("inspector_search_memories", %{"query" => q}, socket) do
    id = socket.assigns.inspector_char && socket.assigns.inspector_char.id
    if id do
      all = Memories.list_memories_for_character(id)
      filtered =
        if String.trim(q) == "" do
          all
        else
          qd = String.downcase(q)
          Enum.filter(all, &String.contains?(String.downcase(&1.summary || ""), qd))
        end
      {:noreply, assign(socket, :inspector_memories, filtered)}
    else
      {:noreply, socket}
    end
  end

  defp load_inspector_char(socket, id) do
    char = Characters.get_character!(id)
    emotional = Souls.get_emotional_state_by_character(id)
    soul = Souls.get_soul_profile_by_character(id)
    somatic = Souls.get_somatic_state_by_character(id)
    grief_arcs = Souls.list_active_grief_arcs_for_character(id)
    active_goals = Souls.list_active_goals_for_character(id)
    {cog_score, _stressors} = SovereignSoulEngine.Souls.CognitiveLoad.compute(emotional, somatic, grief_arcs, active_goals)
    socket
    |> assign(:inspector_char, char)
    |> assign(:inspector_emotional, emotional)
    |> assign(:inspector_soul, soul)
    |> assign(:inspector_somatic, somatic)
    |> assign(:inspector_grief_arcs, grief_arcs)
    |> assign(:inspector_active_goals, active_goals)
    |> assign(:inspector_cog_score, cog_score)
  end

  defp load_inspector_tab(socket, "vitals", _id), do: socket

  defp load_inspector_tab(socket, "beliefs", id) do
    socket
    |> assign(:inspector_beliefs, Souls.list_beliefs_for_character(id))
    |> assign(:inspector_triggers, Souls.list_triggers_for_character(id))
    |> assign(:inspector_moral_lines, Souls.list_moral_lines_for_character(id))
    |> assign(:inspector_secrets, Souls.list_secrets_for_character(id))
  end

  defp load_inspector_tab(socket, "arcs", _id) do
    id = socket.assigns.inspector_char.id
    assign(socket, :inspector_forgiveness_arcs, Souls.list_active_forgiveness_arcs_for_character(id))
  end

  defp load_inspector_tab(socket, "goals", id) do
    socket
    |> assign(:inspector_desires, Souls.list_desires_for_character(id))
  end

  defp load_inspector_tab(socket, "memory", id) do
    assign(socket, :inspector_memories, Memories.list_memories_for_character(id))
  end

  defp load_inspector_tab(socket, "theory_of_mind", id) do
    knowledge = TheoryOfMind.list_what_knower_knows(id)
    all_chars = Characters.list_characters() |> Enum.reject(&(&1.id == id))
    grouped =
      knowledge
      |> Enum.group_by(& &1.subject_character_id)
      |> Enum.map(fn {sid, entries} ->
        {Enum.find(all_chars, &(&1.id == sid)), entries}
      end)
      |> Enum.reject(fn {c, _} -> is_nil(c) end)
    socket
    |> assign(:inspector_tom_grouped, grouped)
    |> assign(:inspector_tom_all_chars, all_chars)
  end

  defp load_inspector_tab(socket, _tab, _id), do: socket

  # ─── NPC Wizard ────────────────────────────────────────────────────────────

  @impl true
  def handle_event("w_next_step", _params, %{assigns: %{w_step: s}} = socket) when s < @wizard_steps,
    do: {:noreply, assign(socket, :w_step, s + 1)}
  def handle_event("w_next_step", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("w_prev_step", _params, %{assigns: %{w_step: s}} = socket) when s > 1,
    do: {:noreply, assign(socket, :w_step, s - 1)}
  def handle_event("w_prev_step", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("w_goto_step", %{"step" => s}, socket),
    do: {:noreply, assign(socket, :w_step, String.to_integer(s))}

  @impl true
  def handle_event("w_update_identity", params, socket) do
    name = Map.get(params, "name", socket.assigns.w_name)
    slug_raw = Map.get(params, "slug", "")
    slug = if slug_raw == "", do: slugify(name), else: slug_raw
    {:noreply, socket
     |> assign(:w_name, name)
     |> assign(:w_slug, slug)
     |> assign(:w_description, Map.get(params, "description", socket.assigns.w_description))
     |> assign(:w_kind, Map.get(params, "kind", socket.assigns.w_kind))
     |> assign(:w_status, Map.get(params, "status", socket.assigns.w_status))}
  end

  @impl true
  def handle_event("w_auto_slug", %{"name" => name}, socket),
    do: {:noreply, assign(socket, :w_slug, slugify(name))}

  @impl true
  def handle_event("w_update_personality", params, socket) do
    {:noreply, socket
     |> assign(:w_attachment_style, Map.get(params, "attachment_style", socket.assigns.w_attachment_style))
     |> assign(:w_humor_style, Map.get(params, "humor_style", socket.assigns.w_humor_style))
     |> assign(:w_emotional_susceptibility, parse_int(params["emotional_susceptibility"], socket.assigns.w_emotional_susceptibility))
     |> assign(:w_speech_style, Map.get(params, "speech_style", socket.assigns.w_speech_style))}
  end

  @impl true
  def handle_event("w_toggle_trait", %{"trait" => trait}, socket) do
    traits = Map.put(socket.assigns.w_personality_traits, trait, !Map.get(socket.assigns.w_personality_traits, trait, false))
    {:noreply, assign(socket, :w_personality_traits, traits)}
  end

  @impl true
  def handle_event("w_update_core_value_input", %{"value" => val}, socket),
    do: {:noreply, assign(socket, :w_core_value_input, val)}

  @impl true
  def handle_event("w_add_core_value", _params, socket) do
    val = String.trim(socket.assigns.w_core_value_input)
    if val != "" and val not in socket.assigns.w_core_values do
      {:noreply, socket |> assign(:w_core_values, socket.assigns.w_core_values ++ [val]) |> assign(:w_core_value_input, "")}
    else
      {:noreply, assign(socket, :w_core_value_input, "")}
    end
  end

  @impl true
  def handle_event("w_remove_core_value", %{"value" => val}, socket),
    do: {:noreply, assign(socket, :w_core_values, List.delete(socket.assigns.w_core_values, val))}

  @impl true
  def handle_event("w_update_baseline_emotion", %{"emotion" => e, "value" => v}, socket),
    do: {:noreply, assign(socket, :w_baseline_emotions, Map.put(socket.assigns.w_baseline_emotions, e, parse_int(v, 0)))}

  @impl true
  def handle_event("w_update_physical_tell", %{"emotion" => e, "value" => v}, socket),
    do: {:noreply, assign(socket, :w_physical_tells, Map.put(socket.assigns.w_physical_tells, e, v))}

  @impl true
  def handle_event("w_update_transference", %{"index" => idx, "field" => field, "value" => val}, socket) do
    entries = List.update_at(socket.assigns.w_transference_entries, String.to_integer(idx), &Map.put(&1, field, val))
    {:noreply, assign(socket, :w_transference_entries, entries)}
  end

  @impl true
  def handle_event("w_update_belief_draft", params, socket) do
    draft = socket.assigns.w_belief_draft
      |> Map.merge(Map.take(params, ["belief", "domain"]))
      |> Map.put("conviction", parse_int(params["conviction"], socket.assigns.w_belief_draft["conviction"]))
    {:noreply, assign(socket, :w_belief_draft, draft)}
  end

  @impl true
  def handle_event("w_add_belief", _params, socket) do
    if String.trim(socket.assigns.w_belief_draft["belief"] || "") != "" do
      {:noreply, socket
        |> assign(:w_beliefs, socket.assigns.w_beliefs ++ [socket.assigns.w_belief_draft])
        |> assign(:w_belief_draft, %{"belief" => "", "domain" => "social", "conviction" => 50})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("w_remove_belief", %{"index" => idx}, socket),
    do: {:noreply, assign(socket, :w_beliefs, List.delete_at(socket.assigns.w_beliefs, String.to_integer(idx)))}

  @impl true
  def handle_event("w_update_trigger_draft", params, socket) do
    draft = socket.assigns.w_trigger_draft
      |> Map.merge(Map.take(params, ["topic", "reaction_type", "flavor_text"]))
      |> Map.put("intensity_modifier", parse_int(params["intensity_modifier"], socket.assigns.w_trigger_draft["intensity_modifier"]))
    {:noreply, assign(socket, :w_trigger_draft, draft)}
  end

  @impl true
  def handle_event("w_add_trigger", _params, socket) do
    if String.trim(socket.assigns.w_trigger_draft["topic"] || "") != "" do
      {:noreply, socket
        |> assign(:w_triggers, socket.assigns.w_triggers ++ [socket.assigns.w_trigger_draft])
        |> assign(:w_trigger_draft, %{"topic" => "", "reaction_type" => "anger_spike", "intensity_modifier" => 50, "flavor_text" => ""})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("w_remove_trigger", %{"index" => idx}, socket),
    do: {:noreply, assign(socket, :w_triggers, List.delete_at(socket.assigns.w_triggers, String.to_integer(idx)))}

  @impl true
  def handle_event("w_update_moral_line_draft", params, socket) do
    draft = Map.merge(socket.assigns.w_moral_line_draft, Map.take(params, ["principle"]))
    {:noreply, assign(socket, :w_moral_line_draft, draft)}
  end

  @impl true
  def handle_event("w_add_moral_line", _params, socket) do
    if String.trim(socket.assigns.w_moral_line_draft["principle"] || "") != "" do
      {:noreply, socket
        |> assign(:w_moral_lines, socket.assigns.w_moral_lines ++ [socket.assigns.w_moral_line_draft])
        |> assign(:w_moral_line_draft, %{"principle" => "", "will_refuse" => true, "action_types_blocked" => []})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("w_remove_moral_line", %{"index" => idx}, socket),
    do: {:noreply, assign(socket, :w_moral_lines, List.delete_at(socket.assigns.w_moral_lines, String.to_integer(idx)))}

  @impl true
  def handle_event("w_update_secret_draft", params, socket) do
    draft = Map.merge(socket.assigns.w_secret_draft, Map.take(params, ["secret_text", "risk_level", "domain"]))
    {:noreply, assign(socket, :w_secret_draft, draft)}
  end

  @impl true
  def handle_event("w_add_secret", _params, socket) do
    if String.trim(socket.assigns.w_secret_draft["secret_text"] || "") != "" do
      {:noreply, socket
        |> assign(:w_secrets, socket.assigns.w_secrets ++ [socket.assigns.w_secret_draft])
        |> assign(:w_secret_draft, %{"secret_text" => "", "risk_level" => "medium", "domain" => ""})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("w_remove_secret", %{"index" => idx}, socket),
    do: {:noreply, assign(socket, :w_secrets, List.delete_at(socket.assigns.w_secrets, String.to_integer(idx)))}

  @impl true
  def handle_event("w_update_desire_draft", params, socket) do
    draft = socket.assigns.w_desire_draft
      |> Map.merge(Map.take(params, ["desire", "domain"]))
      |> Map.put("urgency", parse_int(params["urgency"], socket.assigns.w_desire_draft["urgency"]))
    {:noreply, assign(socket, :w_desire_draft, draft)}
  end

  @impl true
  def handle_event("w_add_desire", _params, socket) do
    if String.trim(socket.assigns.w_desire_draft["desire"] || "") != "" do
      {:noreply, socket
        |> assign(:w_desires, socket.assigns.w_desires ++ [socket.assigns.w_desire_draft])
        |> assign(:w_desire_draft, %{"desire" => "", "domain" => "connection", "urgency" => 50})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("w_remove_desire", %{"index" => idx}, socket),
    do: {:noreply, assign(socket, :w_desires, List.delete_at(socket.assigns.w_desires, String.to_integer(idx)))}

  @impl true
  def handle_event("w_update_goal_draft", params, socket) do
    draft = socket.assigns.w_goal_draft
      |> Map.merge(Map.take(params, ["goal", "current_step"]))
      |> Map.put("priority", parse_int(params["priority"], socket.assigns.w_goal_draft["priority"]))
    {:noreply, assign(socket, :w_goal_draft, draft)}
  end

  @impl true
  def handle_event("w_add_goal", _params, socket) do
    if String.trim(socket.assigns.w_goal_draft["goal"] || "") != "" do
      {:noreply, socket
        |> assign(:w_goals, socket.assigns.w_goals ++ [socket.assigns.w_goal_draft])
        |> assign(:w_goal_draft, %{"goal" => "", "current_step" => "", "priority" => 50})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("w_remove_goal", %{"index" => idx}, socket),
    do: {:noreply, assign(socket, :w_goals, List.delete_at(socket.assigns.w_goals, String.to_integer(idx)))}

  @impl true
  def handle_event("w_update_grief_draft", params, socket) do
    draft = socket.assigns.w_grief_draft
      |> Map.merge(Map.take(params, ["subject", "loss_type", "stage"]))
      |> Map.put("intensity", parse_int(params["intensity"], socket.assigns.w_grief_draft["intensity"]))
    {:noreply, assign(socket, :w_grief_draft, draft)}
  end

  @impl true
  def handle_event("w_add_grief_arc", _params, socket) do
    if String.trim(socket.assigns.w_grief_draft["subject"] || "") != "" do
      {:noreply, socket
        |> assign(:w_grief_arcs, socket.assigns.w_grief_arcs ++ [socket.assigns.w_grief_draft])
        |> assign(:w_grief_draft, %{"subject" => "", "loss_type" => "person", "stage" => "denial", "intensity" => 70})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("w_remove_grief_arc", %{"index" => idx}, socket),
    do: {:noreply, assign(socket, :w_grief_arcs, List.delete_at(socket.assigns.w_grief_arcs, String.to_integer(idx)))}

  @impl true
  def handle_event("w_update_forgiveness_draft", params, socket) do
    draft = socket.assigns.w_forgiveness_draft
      |> Map.merge(Map.take(params, ["wound_description", "stage", "direction"]))
      |> Map.put("intensity", parse_int(params["intensity"], socket.assigns.w_forgiveness_draft["intensity"]))
    {:noreply, assign(socket, :w_forgiveness_draft, draft)}
  end

  @impl true
  def handle_event("w_add_forgiveness_arc", _params, socket) do
    if String.trim(socket.assigns.w_forgiveness_draft["wound_description"] || "") != "" do
      {:noreply, socket
        |> assign(:w_forgiveness_arcs, socket.assigns.w_forgiveness_arcs ++ [socket.assigns.w_forgiveness_draft])
        |> assign(:w_forgiveness_draft, %{"wound_description" => "", "stage" => "fresh", "direction" => "neutral", "intensity" => 80})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("w_remove_forgiveness_arc", %{"index" => idx}, socket),
    do: {:noreply, assign(socket, :w_forgiveness_arcs, List.delete_at(socket.assigns.w_forgiveness_arcs, String.to_integer(idx)))}

  @impl true
  def handle_event("w_update_tom_draft", params, socket) do
    draft = socket.assigns.w_tom_draft
      |> Map.merge(Map.take(params, ["known_fact"]))
      |> Map.put("certainty", parse_int(params["certainty"], socket.assigns.w_tom_draft["certainty"]))
      |> Map.put("is_assumption", Map.get(params, "is_assumption", "true") == "true")
    {:noreply, assign(socket, :w_tom_draft, draft)}
  end

  @impl true
  def handle_event("w_add_tom_entry", _params, socket) do
    if String.trim(socket.assigns.w_tom_draft["known_fact"] || "") != "" do
      {:noreply, socket
        |> assign(:w_tom_entries, socket.assigns.w_tom_entries ++ [socket.assigns.w_tom_draft])
        |> assign(:w_tom_draft, %{"known_fact" => "", "certainty" => 70, "is_assumption" => true})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("w_remove_tom_entry", %{"index" => idx}, socket),
    do: {:noreply, assign(socket, :w_tom_entries, List.delete_at(socket.assigns.w_tom_entries, String.to_integer(idx)))}

  @impl true
  def handle_event("w_update_stamina", params, socket) do
    {:noreply, socket
     |> assign(:w_social_stamina, parse_int(params["social_stamina"], socket.assigns.w_social_stamina))
     |> assign(:w_stamina_regen_rate, parse_int(params["stamina_regen_rate"], socket.assigns.w_stamina_regen_rate))
     |> assign(:w_stamina_max, parse_int(params["stamina_max"], socket.assigns.w_stamina_max))
     |> assign(:w_hunger, parse_int(params["hunger"], socket.assigns.w_hunger))
     |> assign(:w_pain, parse_int(params["pain"], socket.assigns.w_pain))
     |> assign(:w_fatigue, parse_int(params["fatigue"], socket.assigns.w_fatigue))
     |> assign(:w_illness_severity, parse_int(params["illness_severity"], socket.assigns.w_illness_severity))}
  end

  @impl true
  def handle_event("w_create_npc", _params, socket) do
    a = socket.assigns
    with {:ok, character} <- Characters.create_character(%{
           name: a.w_name, slug: a.w_slug, kind: a.w_kind,
           description: a.w_description, status: a.w_status}),
         active_traits = a.w_personality_traits |> Enum.filter(fn {_, v} -> v end) |> Enum.map(fn {k, _} -> k end),
         transference = a.w_transference_entries
           |> Enum.reject(&(String.trim(&1["trigger_pattern"] || "") == ""))
           |> Enum.with_index()
           |> Enum.map(fn {e, i} -> {Integer.to_string(i), e} end)
           |> Map.new(),
         {:ok, _soul} <- Souls.create_soul_profile(%{
           character_id: character.id,
           attachment_style: a.w_attachment_style, humor_style: a.w_humor_style,
           emotional_susceptibility: a.w_emotional_susceptibility, speech_style: a.w_speech_style,
           personality_traits: Map.new(active_traits, &{&1, true}), core_values: a.w_core_values,
           baseline_emotions: a.w_baseline_emotions, physical_tells: a.w_physical_tells,
           transference_profile: transference, social_stamina: a.w_social_stamina,
           stamina_regen_rate: a.w_stamina_regen_rate, stamina_max: a.w_stamina_max}),
         {:ok, _emotion} <- Souls.create_emotional_state(%{
           character_id: character.id,
           anger: Map.get(a.w_baseline_emotions, "anger", 0),
           fear: Map.get(a.w_baseline_emotions, "fear", 0),
           stress: Map.get(a.w_baseline_emotions, "stress", 20),
           gratitude: Map.get(a.w_baseline_emotions, "gratitude", 30),
           confidence: Map.get(a.w_baseline_emotions, "confidence", 50),
           sadness: Map.get(a.w_baseline_emotions, "sadness", 0)}),
         {:ok, _somatic} <- Souls.create_somatic_state(%{
           character_id: character.id,
           hunger: a.w_hunger, pain: a.w_pain, fatigue: a.w_fatigue,
           illness_severity: a.w_illness_severity}) do
      for b <- a.w_beliefs, do: Souls.create_belief(%{character_id: character.id, belief: b["belief"], domain: b["domain"], conviction: b["conviction"]})
      for t <- a.w_triggers, do: Souls.create_trigger(%{character_id: character.id, topic: t["topic"], reaction_type: t["reaction_type"], intensity_modifier: t["intensity_modifier"], flavor_text: t["flavor_text"]})
      for ml <- a.w_moral_lines, do: Souls.create_moral_line(%{character_id: character.id, principle: ml["principle"], will_refuse_when_violated: ml["will_refuse"], action_types_blocked: ml["action_types_blocked"] || []})
      for s <- a.w_secrets, do: Souls.create_secret(%{character_id: character.id, secret_text: s["secret_text"], risk_level: s["risk_level"], domain: s["domain"]})
      for d <- a.w_desires, do: Souls.create_desire(%{character_id: character.id, desire: d["desire"], domain: d["domain"], urgency: d["urgency"]})
      for g <- a.w_goals, do: Souls.create_goal(%{character_id: character.id, goal: g["goal"], current_step: g["current_step"], priority: g["priority"]})
      for ga <- a.w_grief_arcs, do: Souls.create_grief_arc(%{character_id: character.id, subject: ga["subject"], loss_type: ga["loss_type"], stage: ga["stage"], intensity: ga["intensity"], triggered_at: DateTime.utc_now()})
      for fa <- a.w_forgiveness_arcs, do: Souls.create_forgiveness_arc(%{character_id: character.id, wound_description: fa["wound_description"], stage: fa["stage"], direction: fa["direction"], intensity: fa["intensity"]})
      socket = socket
        |> assign(:sauce_tab, "characters")
        |> assign(:characters, Characters.list_characters())
        |> assign(:success_message, "#{character.name} created with full soul data!")
        |> assign(:w_step, 1) |> assign(:w_errors, []) |> assign(:w_name, "") |> assign(:w_slug, "")
        |> assign(:w_description, "") |> assign(:w_beliefs, []) |> assign(:w_triggers, [])
        |> assign(:w_moral_lines, []) |> assign(:w_secrets, []) |> assign(:w_desires, [])
        |> assign(:w_goals, []) |> assign(:w_grief_arcs, []) |> assign(:w_forgiveness_arcs, [])
        |> assign(:w_tom_entries, []) |> assign(:w_core_values, [])
        |> load_inspector_char(character.id)
      {:noreply, socket}
    else
      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)
        {:noreply, assign(socket, :w_errors, [inspect(errors)])}
    end
  end

  defp slugify(name) do
    name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end
  defp parse_int(_, default), do: default

  defp format_dt(nil), do: "—"
  defp format_dt(dt), do: Calendar.strftime(dt, "%H:%M %b %d")

  defp cog_badge(score) when score >= 70, do: {"bg-red-500/20 text-red-400 border-red-500/30", "HIGH"}
  defp cog_badge(score) when score >= 40, do: {"bg-yellow-500/20 text-yellow-400 border-yellow-500/30", "MED"}
  defp cog_badge(_), do: {"bg-green-500/20 text-green-400 border-green-500/30", "LOW"}

  defp emotion_fields do
    [
      {"Anger", :anger, "#ef4444"}, {"Fear", :fear, "#a855f7"}, {"Stress", :stress, "#f59e0b"},
      {"Gratitude", :gratitude, "#10b981"}, {"Confidence", :confidence, "#3b82f6"},
      {"Sadness", :sadness, "#6366f1"}, {"Curiosity", :curiosity, "#06b6d4"},
      {"Attachment", :attachment, "#ec4899"}, {"Shame", :shame, "#f43f5e"}, {"Guilt", :guilt, "#f59e0b"}
    ]
  end

  defp social_char_name(participants, character_id) do
    case Enum.find(participants, &(&1.character_id == character_id)) do
      nil -> "Unknown"
      p -> p.character.name
    end
  end

  defp format_time(nil), do: ""
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M")

  defp load_shadows do
    import Ecto.Query

    SovereignSoulEngine.Repo.all(
      from s in SovereignSoulEngine.Souls.SoulShadow,
        order_by: [desc: s.inserted_at],
        limit: 10,
        preload: [:character, :scene]
    )
  end
end
