defmodule SovereignSoulEngineWeb.ChatSauceLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.AcpManager
  alias SovereignSoulEngine.Relationships

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
               |> assign(:new_rel_form, to_form(Relationships.change_relationship(%Relationships.Relationship{})))}

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
               |> assign(:new_rel_form, to_form(Relationships.change_relationship(%Relationships.Relationship{})))}

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
    profile = SovereignSoulEngine.Souls.get_soul_profile_by_character(char.id) || 
      (case SovereignSoulEngine.Souls.create_soul_profile(%{character_id: char.id}) do
         {:ok, p} -> p
       end)

    fears = SovereignSoulEngine.Repo.all(
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
      {:ok, _fear} = SovereignSoulEngine.Souls.create_soul_fear(%{
        character_id: char.id,
        fear_type: String.trim(fear_type),
        severity: 70,
        origin: "baked_in",
        status: "active"
      })
      fears = SovereignSoulEngine.Repo.all(
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
    {:ok, _} = SovereignSoulEngine.Souls.update_soul_fear(fear, %{status: "resolved", severity: 0})
    fears = SovereignSoulEngine.Repo.all(
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
          {:ok, _} = SovereignSoulEngine.Souls.update_soul_profile(profile, %{personality_traits: traits})
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
         |> assign(:success_message, "Character '#{char.name}' and personality traits updated successfully!")
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
              Chat Sauce <span class="text-[10px] uppercase font-mono px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-400 border border-amber-500/20">Admin</span>
            </h1>
            <p class="text-xs text-slate-400">Control center for character AI & Agent Client Protocol</p>
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

      <%!-- Main Body --%>
      <main class="flex-1 max-w-7xl w-full mx-auto p-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Notifications --%>
        <div :if={@success_message || @error_message} class="col-span-1 lg:col-span-3">
          <div :if={@success_message} class="p-4 rounded-xl border border-emerald-500/30 bg-emerald-500/5 text-emerald-400 text-sm flex items-center gap-2">
            <.icon name="hero-check-circle" class="size-5 text-emerald-400" />
            {@success_message}
          </div>
          <div :if={@error_message} class="p-4 rounded-xl border border-red-500/30 bg-red-500/5 text-red-400 text-sm flex items-center gap-2">
            <.icon name="hero-exclamation-triangle" class="size-5 text-red-400" />
            {@error_message}
          </div>
        </div>

        <%!-- Column 1 & 2: ACP server control & log --%>
        <div class="lg:col-span-2 space-y-6">
          <%!-- ACP Server Status Card --%>
          <section class="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 backdrop-blur-sm space-y-5">
            <div class="flex items-center justify-between">
              <div class="space-y-1">
                <h2 class="text-lg font-bold text-white">Agent Client Protocol (ACP)</h2>
                <p class="text-xs text-slate-400">Allows autonomous coding agents to inspect the soul engines and generate characters.</p>
              </div>
              <div class="flex items-center gap-2">
                <span class={[
                  "inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold uppercase tracking-wider border",
                  @acp_running? && "bg-emerald-500/10 text-emerald-400 border-emerald-500/20",
                  !@acp_running? && "bg-rose-500/10 text-rose-400 border-rose-500/20"
                ]}>
                  <span class={["w-2 h-2 rounded-full", @acp_running? && "bg-emerald-400 animate-pulse", !@acp_running? && "bg-rose-400"]} />
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
              <h2 class="text-sm font-bold text-slate-300 uppercase tracking-wider font-mono">ACP Server Logs</h2>
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
                  <label class="text-xs text-slate-400 font-medium">Affinity / Attachment (-100 to 100)</label>
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
              <h3 class="text-sm font-bold text-slate-300 uppercase tracking-wider font-mono">Current Relationships</h3>
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
                      <%
                        src = Enum.find(@characters, &(&1.id == rel.source_character_id))
                        tgt = Enum.find(@characters, &(&1.id == rel.target_character_id))
                      %>
                      <tr :if={src && tgt} class="hover:bg-slate-900/30">
                        <td class="px-4 py-2.5 font-medium text-slate-200">{src.name}</td>
                        <td class="px-4 py-2.5 font-medium text-slate-200">{tgt.name}</td>
                        <td class="px-4 py-2.5 text-slate-400 font-mono uppercase text-xs">{rel.relationship_type || "acquaintance"}</td>
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
                    <div class="text-xs text-slate-500 truncate" title={char.description}>{char.description}</div>
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
              <.icon name="hero-bolt" class="size-5 text-indigo-400" /> Subconscious Shadow Monitor (Direct Character Minds)
            </h2>
            <p class="text-xs text-slate-400">Ledger of recent private monologues, repressed motives, and defense mechanisms captured off-chat from LLM response processes.</p>

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
                      <td class="px-4 py-2.5 text-slate-500 whitespace-nowrap font-mono">{Calendar.strftime(shadow.inserted_at, "%H:%M:%S")}</td>
                      <td class="px-4 py-2.5 font-bold text-white whitespace-nowrap">{shadow.character && shadow.character.name}</td>
                      <td class="px-4 py-2.5 text-slate-400 whitespace-nowrap">{shadow.scene && shadow.scene.title}</td>
                      <td class="px-4 py-2.5">
                        <span class={[
                          "px-2 py-0.5 rounded text-[10px] font-mono uppercase font-bold",
                          shadow.active_defense == "none" && "bg-slate-800 text-slate-400 border border-slate-700",
                          shadow.active_defense != "none" && "bg-indigo-500/10 text-indigo-400 border border-indigo-500/20"
                        ]}>
                          {shadow.active_defense}
                        </span>
                      </td>
                      <td class="px-4 py-2.5 text-slate-200 leading-normal max-w-xs">{shadow.repressed_motive}</td>
                      <td class="px-4 py-2.5 text-slate-400 italic max-w-sm leading-normal">{shadow.private_monologue}</td>
                      <td class="px-4 py-2.5 font-mono text-[10px] text-slate-400 whitespace-nowrap">
                        ANG: {get_in(shadow.emotional_drift || %{}, ["anger"]) || 0} | 
                        FEAR: {get_in(shadow.emotional_drift || %{}, ["fear"]) || 0} | 
                        STR: {get_in(shadow.emotional_drift || %{}, ["stress"]) || 0} | 
                        ATT: {get_in(shadow.emotional_drift || %{}, ["attachment"]) || 0}
                      </td>
                    </tr>
                  <% end %>
                  <tr :if={@shadows == []}>
                    <td colspan="7" class="px-4 py-8 text-center text-slate-500 italic">No subconscious shadows logged yet. Send messages in Sovereign Chat to start logging.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        </div>
      </main>

      <%!-- Edit Character Modal --%>
      <div :if={@editing_character} class="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
        <div class="w-full max-w-lg p-6 bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl space-y-6">
          <div class="text-center">
            <h2 class="text-lg font-bold text-white">Edit Character Details & Motives</h2>
            <p class="text-sm text-slate-400">Modify description or current objectives for {@editing_character && @editing_character.name}</p>
          </div>

          <.form
            for={Characters.change_character(@editing_character || %Characters.Character{})}
            phx-submit="update_character"
            class="space-y-4"
          >
            <div class="space-y-1.5 text-sm">
              <label class="text-xs font-bold text-slate-400 uppercase">Description, Motives, or Context</label>
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
                <.icon name="hero-cpu-chip" class="size-4 text-amber-400" /> Cognitive Conditions & Traits
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
                      checked={get_in((@editing_character_profile && @editing_character_profile.personality_traits) || %{}, [trait_key]) == true}
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
                    <span :if={fear.status == "resolved"} class="text-[10px] text-emerald-500 font-semibold px-2 py-1">
                      Resolved
                    </span>
                  </div>
                </div>
              <% end %>
              <p :if={@editing_character_fears == []} class="text-xs text-slate-500 italic">No fears configured for this character.</p>
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
