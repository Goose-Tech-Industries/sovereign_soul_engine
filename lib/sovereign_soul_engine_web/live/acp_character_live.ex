defmodule SovereignSoulEngineWeb.AcpCharacterLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.TraitCatalog
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Relationships

  @tabs ~w(vitals timeline memory beliefs arcs goals social theory_of_mind)
  @default_tab "vitals"

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    tab = Map.get(params, "tab", @default_tab)
    tab = if tab in @tabs, do: tab, else: @default_tab

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "character:#{id}")
    end

    socket =
      socket
      |> assign(:id, id)
      |> assign(:tab, tab)
      # The template's tab nav does `for tab <- @tabs` inside ~H — that's
      # assigns[:tabs], NOT the @tabs module attribute above, which HEEx
      # has no visibility into. Never assigned, so every load of this page
      # crashed with a KeyError.
      |> assign(:tabs, @tabs)
      |> assign(:tom_draft_fact, "")
      |> assign(:tom_draft_certainty, 70)
      |> assign(:tom_draft_assumption, true)
      |> assign(:tom_draft_subject_id, nil)
      |> assign(:tom_save_result, nil)
      |> load_character_data(id)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id, "tab" => tab}, _uri, socket) do
    tab = if tab in @tabs, do: tab, else: @default_tab
    socket = socket |> assign(:tab, tab) |> assign(:id, id) |> load_character_data(id)
    {:noreply, socket}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    socket = socket |> assign(:tab, @default_tab) |> assign(:id, id) |> load_character_data(id)
    {:noreply, socket}
  end

  defp load_character_data(socket, id) do
    character = Characters.get_character!(id)
    emotional = Souls.get_emotional_state_by_character(id)
    soul = Souls.get_soul_profile_by_character(id)
    somatic = Souls.get_somatic_state_by_character(id)
    grief_arcs = Souls.list_active_grief_arcs_for_character(id)
    active_goals = Souls.list_active_goals_for_character(id)

    {cog_score, cog_stressors} =
      SovereignSoulEngine.Souls.CognitiveLoad.compute(emotional, somatic, grief_arcs, active_goals)

    socket
    |> assign(:character, character)
    |> assign(:emotional, emotional)
    |> assign(:soul, soul)
    |> assign(:somatic, somatic)
    |> assign(:grief_arcs, grief_arcs)
    |> assign(:active_goals, active_goals)
    |> assign(:cog_score, cog_score)
    |> assign(:cog_stressors, cog_stressors)
    |> assign(:page_title, "#{character.name} — ACP")
    # Edit drafts for the vitals tab — reset from the freshly-loaded structs
    # every time character data reloads (after a save, or a PubSub
    # emotion_updated push), so the form always reflects real DB state
    # rather than silently going stale.
    |> assign(:emotional_draft, emotional && emotional_draft_from(emotional))
    |> assign(:soul_draft, soul && soul_draft_from(soul))
    |> load_tab_data(socket.assigns[:tab] || @default_tab, id)
  end

  defp emotional_draft_from(emotional) do
    Map.new(emotion_fields(), fn {_label, key, _color} -> {Atom.to_string(key), Map.get(emotional, key) || 0} end)
  end

  defp soul_draft_from(soul) do
    %{
      "attachment_style" => soul.attachment_style,
      "humor_style" => soul.humor_style,
      "emotional_susceptibility" => soul.emotional_susceptibility,
      "speech_style" => soul.speech_style || "",
      "personality_traits" => soul.personality_traits || %{}
    }
  end

  defp load_tab_data(socket, "vitals", _id), do: socket

  defp load_tab_data(socket, "timeline", id) do
    memories = Memories.list_memories_for_character(id)
    fears = Souls.list_soul_fears_for_character(id)
    beliefs = Souls.list_beliefs_for_character(id)

    events =
      (Enum.map(memories, fn m ->
         %{
           type: :memory,
           at: m.inserted_at,
           label: "New memory formed",
           desc: m.summary,
           icon_color: "text-cyan-400",
           bg: "bg-cyan-500/10 border-cyan-500/20"
         }
       end) ++
         Enum.map(fears, fn f ->
           %{
             type: :fear,
             at: f.inserted_at,
             label: "New fear acquired",
             desc: to_string(Map.get(f, :fear_type, "unknown")),
             icon_color: "text-purple-400",
             bg: "bg-purple-500/10 border-purple-500/20"
           }
         end) ++
         Enum.map(socket.assigns.grief_arcs, fn g ->
           %{
             type: :grief,
             at: g.inserted_at,
             label: "Grieving #{g.subject}",
             desc: "Stage: #{g.stage} — intensity #{g.intensity}",
             icon_color: "text-indigo-400",
             bg: "bg-indigo-500/10 border-indigo-500/20"
           }
         end) ++
         Enum.map(Souls.list_active_forgiveness_arcs_for_character(id), fn fa ->
           %{
             type: :forgiveness,
             at: fa.inserted_at,
             label: "Wound: #{fa.wound_description}",
             desc: "#{fa.stage} (#{fa.direction})",
             icon_color: "text-rose-400",
             bg: "bg-rose-500/10 border-rose-500/20"
           }
         end) ++
         Enum.map(socket.assigns.active_goals, fn g ->
           %{
             type: :goal,
             at: g.inserted_at,
             label: g.goal,
             desc: "Status: #{g.status} — priority #{g.priority}",
             icon_color: "text-blue-400",
             bg: "bg-blue-500/10 border-blue-500/20"
           }
         end) ++
         Enum.map(beliefs, fn b ->
           %{
             type: :belief,
             at: b.inserted_at,
             label: b.belief,
             desc: "Conviction #{b.conviction}/100 — #{b.domain}",
             icon_color: "text-purple-400",
             bg: "bg-purple-500/10 border-purple-500/20"
           }
         end))
      |> Enum.sort_by(& &1.at, {:desc, DateTime})

    assign(socket, :timeline_events, events)
  end

  defp load_tab_data(socket, "memory", id) do
    memories = Memories.list_memories_for_character(id)
    consolidated = Enum.filter(memories, &Map.get(&1, :is_consolidated, false))
    assign(socket, :memories, memories) |> assign(:consolidated_memories, consolidated)
  end

  defp load_tab_data(socket, "beliefs", id) do
    socket
    |> assign(:beliefs, Souls.list_beliefs_for_character(id))
    |> assign(:triggers, Souls.list_triggers_for_character(id))
    |> assign(:moral_lines, Souls.list_moral_lines_for_character(id))
    |> assign(:secrets, Souls.list_secrets_for_character(id))
  end

  defp load_tab_data(socket, "arcs", _id) do
    socket
    |> assign(:forgiveness_arcs, Souls.list_active_forgiveness_arcs_for_character(socket.assigns.id))
  end

  defp load_tab_data(socket, "goals", id) do
    desires = Souls.list_desires_for_character(id)
    {_active, completed} = Enum.split_with(socket.assigns.active_goals, &(&1.status == "active"))

    socket
    |> assign(:desires, desires)
    |> assign(:completed_goals, completed)
  end

  defp load_tab_data(socket, "social", id) do
    scenes = Scenes.list_autonomous_scenes(limit: 50)

    char_scenes =
      Enum.filter(scenes, fn scene ->
        Enum.any?(scene.participants, &(&1.character_id == id))
      end)

    relationships =
      id
      |> Relationships.list_relationships_for_source()
      |> Enum.map(fn rel -> {rel, Characters.get_character!(rel.target_character_id)} end)

    existing_target_ids = Enum.map(relationships, fn {rel, _target} -> rel.target_character_id end)

    relationship_candidates =
      Characters.list_characters()
      |> Enum.reject(&(&1.id == id or &1.id in existing_target_ids))

    socket
    |> assign(:char_scenes, char_scenes)
    |> assign(:expanded_scene_ids, MapSet.new())
    |> assign(:relationships, relationships)
    |> assign(:relationship_candidates, relationship_candidates)
  end

  defp load_tab_data(socket, "theory_of_mind", id) do
    knowledge = TheoryOfMind.list_what_knower_knows(id)
    all_chars = Characters.list_characters() |> Enum.reject(&(&1.id == id))

    grouped =
      knowledge
      |> Enum.group_by(& &1.subject_character_id)
      |> Enum.map(fn {subject_id, entries} ->
        subject_char = Enum.find(all_chars, &(&1.id == subject_id))
        {subject_char, entries}
      end)
      |> Enum.reject(fn {char, _} -> is_nil(char) end)

    assign(socket, :tom_grouped, grouped) |> assign(:tom_all_chars, all_chars)
  end

  defp load_tab_data(socket, _tab, _id), do: socket

  # PubSub handlers
  @impl true
  def handle_info({:emotion_updated, _}, socket) do
    {:noreply, load_character_data(socket, socket.assigns.id)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # Events — Theory of Mind form
  @impl true
  def handle_event("update_tom_draft", params, socket) do
    socket =
      socket
      |> assign(:tom_draft_fact, Map.get(params, "known_fact", socket.assigns.tom_draft_fact))
      |> assign(:tom_draft_certainty, parse_int(params["certainty"], socket.assigns.tom_draft_certainty))
      |> assign(:tom_draft_assumption, Map.get(params, "is_assumption", "true") == "true")
      |> assign(:tom_draft_subject_id, Map.get(params, "subject_id", socket.assigns.tom_draft_subject_id))

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_tom_entry", _params, socket) do
    id = socket.assigns.id
    subject_id = socket.assigns.tom_draft_subject_id
    fact = socket.assigns.tom_draft_fact

    if subject_id && String.trim(fact) != "" do
      TheoryOfMind.upsert_knowledge(id, subject_id, fact,
        certainty: socket.assigns.tom_draft_certainty,
        is_assumption: socket.assigns.tom_draft_assumption
      )

      socket =
        socket
        |> assign(:tom_draft_fact, "")
        |> assign(:tom_draft_certainty, 70)
        |> assign(:tom_draft_assumption, true)
        |> assign(:tom_save_result, :ok)
        |> load_tab_data("theory_of_mind", id)

      {:noreply, socket}
    else
      {:noreply, assign(socket, :tom_save_result, :error)}
    end
  end

  # Events — Vitals tab (Emotional State + Soul Profile edit forms)
  @impl true
  def handle_event("update_emotional_draft", params, socket) do
    fields = ~w(anger fear stress gratitude confidence sadness curiosity attachment shame guilt)
    draft = Map.merge(socket.assigns.emotional_draft, Map.take(params, fields))
    {:noreply, assign(socket, :emotional_draft, draft)}
  end

  @impl true
  def handle_event("save_emotional_state", _params, socket) do
    case Souls.update_emotional_state(socket.assigns.emotional, socket.assigns.emotional_draft) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Emotional state saved.") |> load_character_data(socket.assigns.id)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Couldn't save emotional state.")}
    end
  end

  @impl true
  def handle_event("update_soul_draft", params, socket) do
    fields = ~w(attachment_style humor_style emotional_susceptibility speech_style)
    draft = Map.merge(socket.assigns.soul_draft, Map.take(params, fields))
    {:noreply, assign(socket, :soul_draft, draft)}
  end

  @impl true
  def handle_event("toggle_soul_trait", %{"trait" => trait}, socket) do
    traits = socket.assigns.soul_draft["personality_traits"] || %{}
    updated_traits = Map.update(traits, trait, true, &(!&1))
    draft = Map.put(socket.assigns.soul_draft, "personality_traits", updated_traits)
    {:noreply, assign(socket, :soul_draft, draft)}
  end

  @impl true
  def handle_event("save_soul_profile", _params, socket) do
    case Souls.update_soul_profile(socket.assigns.soul, socket.assigns.soul_draft) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Soul profile saved.") |> load_character_data(socket.assigns.id)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Couldn't save soul profile.")}
    end
  end

  # Events — Goals tab (edit existing + add new)
  @impl true
  def handle_event("save_goal", %{"goal_id" => goal_id} = params, socket) do
    goal = Enum.find(socket.assigns.active_goals, &(&1.id == goal_id))
    blocker = params["blocker"] |> to_string() |> String.trim()

    attrs = %{
      "current_step" => params["current_step"],
      "blocker" => if(blocker == "", do: nil, else: blocker),
      "priority" => params["priority"],
      "status" => params["status"]
    }

    case goal && Souls.update_goal(goal, attrs) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Goal updated.") |> load_character_data(socket.assigns.id)}

      _ ->
        {:noreply, put_flash(socket, :error, "Couldn't update goal.")}
    end
  end

  @impl true
  def handle_event("add_goal", %{"goal" => goal_text} = params, socket) do
    if String.trim(goal_text) != "" do
      attrs = %{
        character_id: socket.assigns.id,
        goal: goal_text,
        current_step: params["current_step"],
        priority: params["priority"] || 50
      }

      case Souls.create_goal(attrs) do
        {:ok, _} ->
          {:noreply, socket |> put_flash(:info, "Goal added.") |> load_character_data(socket.assigns.id)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Couldn't add goal.")}
      end
    else
      {:noreply, socket}
    end
  end

  # Events — Arcs tab (grief arcs: edit existing + add new)
  @impl true
  def handle_event("save_grief_arc", %{"arc_id" => arc_id} = params, socket) do
    arc = Enum.find(socket.assigns.grief_arcs, &(&1.id == arc_id))
    attrs = Map.take(params, ["stage", "intensity"])

    case arc && Souls.update_grief_arc(arc, attrs) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Grief arc updated.") |> load_character_data(socket.assigns.id)}

      _ ->
        {:noreply, put_flash(socket, :error, "Couldn't update grief arc.")}
    end
  end

  @impl true
  def handle_event("add_grief_arc", %{"subject" => subject} = params, socket) do
    if String.trim(subject) != "" do
      attrs = %{
        character_id: socket.assigns.id,
        subject: subject,
        loss_type: params["loss_type"],
        stage: params["stage"] || "denial",
        intensity: params["intensity"] || 70,
        triggered_at: DateTime.utc_now()
      }

      case Souls.create_grief_arc(attrs) do
        {:ok, _} ->
          {:noreply, socket |> put_flash(:info, "Grief arc added.") |> load_character_data(socket.assigns.id)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Couldn't add grief arc.")}
      end
    else
      {:noreply, socket}
    end
  end

  # Events — Social tab (relationship authoring: edit existing outbound + add new)
  @impl true
  def handle_event("save_relationship", %{"relationship_id" => rel_id} = params, socket) do
    rel =
      Enum.find_value(socket.assigns.relationships, fn {rel, _target} -> rel.id == rel_id && rel end)

    dimensions = ~w(affinity trust respect fear anger gratitude debt softening hardening wound)

    attrs =
      params
      |> Map.take(["relationship_type", "lock_version" | dimensions])

    try do
      case rel && Relationships.update_relationship(rel, attrs) do
        {:ok, _} ->
          {:noreply, socket |> put_flash(:info, "Relationship updated.") |> load_character_data(socket.assigns.id)}

        _ ->
          {:noreply, put_flash(socket, :error, "Couldn't update relationship.")}
      end
    rescue
      # optimistic_lock on Relationship raises this directly from Repo.update
      # rather than returning {:error, changeset} — it's a runtime row-count
      # check, not a changeset validation, so it can't be caught by a case.
      Ecto.StaleEntryError ->
        {:noreply,
         socket
         |> put_flash(:error, "Someone else changed this relationship first — reloaded with the latest values.")
         |> load_character_data(socket.assigns.id)}
    end
  end

  @impl true
  def handle_event("add_relationship", %{"target_id" => target_id} = params, socket) do
    if target_id not in [nil, ""] do
      attrs = %{
        source_character_id: socket.assigns.id,
        target_character_id: target_id,
        relationship_type: params["relationship_type"] || "acquaintance",
        affinity: params["affinity"] || 0,
        trust: params["trust"] || 0
      }

      case Relationships.create_relationship(attrs) do
        {:ok, _} ->
          {:noreply, socket |> put_flash(:info, "Relationship added.") |> load_character_data(socket.assigns.id)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Couldn't add relationship.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_scene_expand", %{"scene_id" => scene_id}, socket) do
    expanded = socket.assigns.expanded_scene_ids

    new_expanded =
      if MapSet.member?(expanded, scene_id),
        do: MapSet.delete(expanded, scene_id),
        else: MapSet.put(expanded, scene_id)

    {:noreply, assign(socket, :expanded_scene_ids, new_expanded)}
  end

  @impl true
  def handle_event("search_memories", %{"query" => query}, socket) do
    id = socket.assigns.id
    all = Memories.list_memories_for_character(id)

    filtered =
      if String.trim(query) == "" do
        all
      else
        q = String.downcase(query)
        Enum.filter(all, fn m -> String.contains?(String.downcase(m.summary || ""), q) end)
      end

    {:noreply, assign(socket, :memories, filtered)}
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

  # Helpers
  defp emotion_fields do
    [
      {"Anger", :anger, "#ef4444"},
      {"Fear", :fear, "#a855f7"},
      {"Stress", :stress, "#f59e0b"},
      {"Gratitude", :gratitude, "#10b981"},
      {"Confidence", :confidence, "#3b82f6"},
      {"Sadness", :sadness, "#6366f1"},
      {"Curiosity", :curiosity, "#06b6d4"},
      {"Attachment", :attachment, "#ec4899"},
      {"Shame", :shame, "#f43f5e"},
      {"Guilt", :guilt, "#f59e0b"}
    ]
  end

  defp cog_badge(score) when score >= 70, do: {"bg-red-500/20 text-red-400 border-red-500/30", "High"}
  defp cog_badge(score) when score >= 40, do: {"bg-yellow-500/20 text-yellow-400 border-yellow-500/30", "Medium"}
  defp cog_badge(_), do: {"bg-green-500/20 text-green-400 border-green-500/30", "Low"}

  defp grief_stages, do: ~w(denial anger bargaining depression integration)
  defp forgiveness_stages, do: ~w(fresh festering processing forgiven hardened)

  defp stage_index(stages, stage) do
    Enum.find_index(stages, &(&1 == stage)) || 0
  end

  defp status_badge_class("active"), do: "bg-green-500/20 text-green-400 border-green-500/30"
  defp status_badge_class("dead"), do: "bg-red-900/40 text-red-400 border-red-500/30"
  defp status_badge_class("inactive"), do: "bg-gray-500/20 text-gray-400 border-gray-500/30"
  defp status_badge_class(_), do: "bg-gray-500/20 text-gray-400 border-gray-500/30"

  defp risk_badge_class("critical"), do: "bg-red-900/40 text-red-400 border-red-800/50"
  defp risk_badge_class("high"), do: "bg-orange-900/40 text-orange-400 border-orange-800/50"
  defp risk_badge_class("medium"), do: "bg-yellow-900/30 text-yellow-500 border-yellow-800/50"
  defp risk_badge_class(_), do: "bg-gray-800/60 text-gray-500 border-gray-700"

  defp reaction_badge_class("anger_spike"), do: "bg-red-500/20 text-red-400"
  defp reaction_badge_class("fear_spike"), do: "bg-purple-500/20 text-purple-400"
  defp reaction_badge_class("grief_spike"), do: "bg-indigo-500/20 text-indigo-400"
  defp reaction_badge_class("pride_surge"), do: "bg-blue-500/20 text-blue-400"
  defp reaction_badge_class("shame_trigger"), do: "bg-rose-500/20 text-rose-400"
  defp reaction_badge_class(_), do: "bg-gray-700 text-gray-400"

  defp direction_icon("healing"), do: "hero-arrow-trending-up"
  defp direction_icon("hardening"), do: "hero-arrow-trending-down"
  defp direction_icon(_), do: "hero-minus"

  defp direction_color("healing"), do: "text-green-400"
  defp direction_color("hardening"), do: "text-red-400"
  defp direction_color(_), do: "text-gray-500"

  defp format_dt(nil), do: "—"
  defp format_dt(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp valence_class(val) when is_number(val) and val > 0, do: "text-green-400"
  defp valence_class(val) when is_number(val) and val < 0, do: "text-red-400"
  defp valence_class(_), do: "text-gray-500"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100">
      <%!-- Nav --%>
      <nav class="border-b border-gray-800 bg-gray-900 px-6 py-3 flex items-center gap-6">
        <span class="text-amber-400 font-bold text-sm tracking-wide">SOVEREIGN SOUL ENGINE — ACP</span>
        <div class="flex items-center gap-4 ml-4">
          <.link navigate={~p"/sse/acp"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">Dashboard</.link>
          <.link navigate={~p"/sse/acp/npcs/new"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">New NPC</.link>
          <.link navigate={~p"/sse/acp/social"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">Social Log</.link>
        </div>
      </nav>

      <%!-- Character Header --%>
      <div class="px-6 py-4 border-b border-gray-800 bg-gray-900/50 flex items-center gap-4">
        <div class="w-10 h-10 rounded-full bg-amber-500/20 border border-amber-500/30 flex items-center justify-center font-bold text-amber-400 text-sm">
          {String.first(@character.name)}
        </div>
        <div class="flex-1">
          <div class="flex items-center gap-3">
            <h1 class="text-lg font-bold text-gray-100">{@character.name}</h1>
            <span class={"text-[10px] px-2 py-0.5 rounded border font-bold #{status_badge_class(@character.status)}"}>
              {@character.status}
            </span>
            <span class="text-[10px] px-2 py-0.5 rounded border font-bold bg-amber-500/20 text-amber-400 border-amber-500/30">
              {@character.kind}
            </span>
          </div>
          <p class="text-xs text-gray-500 mt-0.5">{@character.description}</p>
        </div>
        <.link navigate={~p"/sse/acp"} class="text-xs text-gray-600 hover:text-gray-400 transition-colors">
          <.icon name="hero-arrow-left" class="size-4 inline" /> Back
        </.link>
      </div>

      <%!-- Tabs --%>
      <div class="border-b border-gray-800 bg-gray-900/30 px-6 flex gap-1">
        <%= for tab <- @tabs do %>
          <.link
            navigate={~p"/sse/acp/npcs/#{@character.id}/#{tab}"}
            class={[
              "px-4 py-3 text-xs font-semibold border-b-2 transition-colors",
              @tab == tab && "border-amber-400 text-amber-300",
              @tab != tab && "border-transparent text-gray-500 hover:text-gray-300"
            ]}
          >
            {tab |> String.replace("_", " ") |> String.capitalize()}
          </.link>
        <% end %>
      </div>

      <div class="px-6 py-6">
        <%!-- TAB: Vitals --%>
        <div :if={@tab == "vitals"}>
          <div class="grid grid-cols-3 gap-4 mb-6">
            <%!-- Emotional State — editable --%>
            <div class="p-4 rounded-xl border border-gray-800 bg-gray-900">
              <h3 class="text-xs font-bold text-gray-400 uppercase tracking-wide mb-3">Emotional State</h3>
              <%= if @emotional do %>
                <form phx-change="update_emotional_draft" phx-submit="save_emotional_state" class="space-y-2.5">
                  <%= for {label, key, color} <- emotion_fields() do %>
                    <% key_str = Atom.to_string(key) %>
                    <div>
                      <div class="flex justify-between text-xs mb-0.5">
                        <span class="text-gray-400">{label}</span>
                        <span class="text-gray-300 font-mono">{Map.get(@emotional_draft, key_str, 0)}</span>
                      </div>
                      <input
                        type="range"
                        min="0"
                        max="100"
                        name={key_str}
                        value={Map.get(@emotional_draft, key_str, 0)}
                        style={"accent-color: #{color}"}
                        class="w-full"
                      />
                    </div>
                  <% end %>
                  <button type="submit" class="mt-1 w-full text-xs px-3 py-1.5 rounded bg-blue-500/20 border border-blue-500/30 text-blue-400 hover:bg-blue-500/30 transition-colors">
                    Save Emotional State
                  </button>
                </form>
              <% else %>
                <p class="text-xs text-gray-600 italic">No emotional state yet</p>
              <% end %>
            </div>

            <%!-- Somatic State --%>
            <div class="p-4 rounded-xl border border-gray-800 bg-gray-900">
              <h3 class="text-xs font-bold text-gray-400 uppercase tracking-wide mb-3">Somatic State</h3>
              <%= if @somatic do %>
                <div class="space-y-2 mb-3">
                  <%= for {label, key, color} <- [{"Hunger", :hunger, "#f59e0b"}, {"Pain", :pain, "#ef4444"}, {"Fatigue", :fatigue, "#a855f7"}, {"Illness", :illness_severity, "#22c55e"}] do %>
                    <div>
                      <div class="flex justify-between text-xs mb-0.5">
                        <span class="text-gray-400">{label}</span>
                        <span class="text-gray-300 font-mono">{Map.get(@somatic, key) || 0}</span>
                      </div>
                      <div class="h-1.5 w-full rounded-full bg-gray-800 overflow-hidden">
                        <div class="h-full rounded-full" style={"width: #{Map.get(@somatic, key) || 0}%; background-color: #{color}"}></div>
                      </div>
                    </div>
                  <% end %>
                </div>
                <div class="text-[10px] text-gray-600 space-y-0.5">
                  <div>Last ate: {format_dt(@somatic.last_ate_at)}</div>
                  <div>Last rested: {format_dt(@somatic.last_rested_at)}</div>
                </div>
              <% else %>
                <p class="text-xs text-gray-600 italic">No somatic data</p>
              <% end %>
            </div>

            <%!-- Cognitive Load --%>
            <div class="p-4 rounded-xl border border-gray-800 bg-gray-900">
              <h3 class="text-xs font-bold text-gray-400 uppercase tracking-wide mb-3">Cognitive Load</h3>
              <% {cog_class, cog_label} = cog_badge(@cog_score) %>
              <div class="flex items-center gap-3 mb-3">
                <div class="text-3xl font-bold text-gray-100">{@cog_score}</div>
                <span class={"text-xs px-2 py-0.5 rounded-full border font-bold #{cog_class}"}>{cog_label}</span>
              </div>
              <div class="h-2 w-full rounded-full bg-gray-800 overflow-hidden mb-3">
                <div
                  class={["h-full rounded-full transition-all", @cog_score >= 70 && "bg-red-500", @cog_score >= 40 && @cog_score < 70 && "bg-yellow-500", @cog_score < 40 && "bg-green-500"]}
                  style={"width: #{@cog_score}%"}
                >
                </div>
              </div>
              <%= if @cog_stressors != [] do %>
                <ul class="space-y-1">
                  <%= for stressor <- @cog_stressors do %>
                    <li class="text-xs text-gray-500 flex items-center gap-1.5">
                      <span class="w-1 h-1 rounded-full bg-yellow-500 shrink-0"></span>
                      {stressor}
                    </li>
                  <% end %>
                </ul>
              <% else %>
                <p class="text-xs text-gray-600 italic">No active stressors</p>
              <% end %>
            </div>
          </div>

          <%!-- Social Stamina — simulation-owned, read-only (NpcScheduler drifts this every tick) --%>
          <%= if @soul do %>
            <div class="p-4 rounded-xl border border-gray-800 bg-gray-900 mb-4">
              <div class="flex items-center justify-between mb-2">
                <h3 class="text-xs font-bold text-gray-400 uppercase tracking-wide">Social Stamina</h3>
                <span class="text-xs text-gray-400 font-mono">{@soul.social_stamina} / {@soul.stamina_max}</span>
              </div>
              <div class="h-3 w-full rounded-full bg-gray-800 overflow-hidden mb-1">
                <div
                  class="h-full rounded-full bg-blue-500 transition-all duration-500"
                  style={"width: #{min(100, Float.round(@soul.social_stamina / max(@soul.stamina_max, 1) * 100, 1))}%"}
                >
                </div>
              </div>
              <div class="text-[10px] text-gray-600">Regen: +{@soul.stamina_regen_rate}/hr</div>
            </div>

            <%!-- Soul Profile identity — editable --%>
            <div class="p-4 rounded-xl border border-gray-800 bg-gray-900">
              <h3 class="text-xs font-bold text-gray-400 uppercase tracking-wide mb-3">Soul Profile</h3>
              <form phx-change="update_soul_draft" phx-submit="save_soul_profile" class="space-y-3">
                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block text-[10px] text-gray-500 mb-1 uppercase tracking-wide">Attachment Style</label>
                    <select name="attachment_style" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500">
                      <%= for style <- ~w(secure anxious avoidant disorganized) do %>
                        <option value={style} selected={@soul_draft["attachment_style"] == style}>{String.capitalize(style)}</option>
                      <% end %>
                    </select>
                  </div>
                  <div>
                    <label class="block text-[10px] text-gray-500 mb-1 uppercase tracking-wide">Humor Style</label>
                    <select name="humor_style" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500">
                      <%= for style <- ~w(none dry sarcastic warm dark absurdist) do %>
                        <option value={style} selected={@soul_draft["humor_style"] == style}>{String.capitalize(style)}</option>
                      <% end %>
                    </select>
                  </div>
                </div>

                <div>
                  <div class="flex justify-between text-[10px] text-gray-500 mb-1 uppercase tracking-wide">
                    <span>Emotional Susceptibility</span>
                    <span class="font-mono normal-case">{@soul_draft["emotional_susceptibility"]}%</span>
                  </div>
                  <input type="range" min="0" max="100" name="emotional_susceptibility" value={@soul_draft["emotional_susceptibility"]} class="w-full accent-blue-500" />
                </div>

                <div>
                  <label class="block text-[10px] text-gray-500 mb-1 uppercase tracking-wide">Speech Style</label>
                  <textarea name="speech_style" rows="2" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500">{@soul_draft["speech_style"]}</textarea>
                </div>

                <div>
                  <label class="block text-[10px] text-gray-500 mb-1.5 uppercase tracking-wide">Behavioral Tendencies</label>
                  <div class="grid grid-cols-3 gap-1.5">
                    <%= for %{key: trait, label: label, blurb: blurb} <- TraitCatalog.all() do %>
                      <% active = Map.get(@soul_draft["personality_traits"] || %{}, trait, false) %>
                      <button
                        type="button"
                        phx-click="toggle_soul_trait"
                        phx-value-trait={trait}
                        title={blurb}
                        class={[
                          "flex items-center gap-1.5 px-2 py-1.5 rounded-lg border text-[11px] text-left transition-all",
                          active && "bg-purple-500/20 border-purple-500/40 text-purple-300",
                          !active && "bg-gray-800/60 border-gray-700/60 text-gray-500 hover:text-gray-300"
                        ]}
                      >
                        <div class={"w-1.5 h-1.5 rounded-full shrink-0 #{if active, do: "bg-purple-400", else: "bg-gray-600"}"}></div>
                        {label}
                      </button>
                    <% end %>
                  </div>
                </div>

                <button type="submit" class="w-full text-xs px-3 py-1.5 rounded bg-blue-500/20 border border-blue-500/30 text-blue-400 hover:bg-blue-500/30 transition-colors">
                  Save Soul Profile
                </button>
              </form>
            </div>
          <% end %>
        </div>

        <%!-- TAB: Timeline --%>
        <div :if={@tab == "timeline"}>
          <h2 class="text-sm font-bold text-gray-300 mb-4">Arc Timeline</h2>
          <div :if={(!is_map_key(assigns, :timeline_events)) or @timeline_events == []} class="text-center py-12 text-gray-600">
            <.icon name="hero-clock" class="size-8 mx-auto mb-2 opacity-40" />
            <p class="text-sm">No events recorded yet</p>
          </div>
          <div class="space-y-3">
            <%= for event <- Map.get(assigns, :timeline_events, []) do %>
              <div class={"flex gap-3 p-3 rounded-lg border #{event.bg}"}>
                <div class={"shrink-0 mt-0.5 #{event.icon_color}"}>
                  <.icon name="hero-bolt" class="size-4" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-xs font-semibold text-gray-200">{event.label}</span>
                    <span class="text-[10px] text-gray-600 shrink-0">{format_dt(event.at)}</span>
                  </div>
                  <p class="text-xs text-gray-400 mt-0.5">{event.desc}</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- TAB: Memory --%>
        <div :if={@tab == "memory"}>
          <div class="flex items-center gap-3 mb-4">
            <h2 class="text-sm font-bold text-gray-300">Memory Vault</h2>
            <form phx-change="search_memories" class="flex-1 max-w-xs">
              <input type="text" name="query" placeholder="Search memories..."
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-1.5 text-sm text-gray-100 focus:outline-none focus:border-amber-500"/>
            </form>
          </div>
          <div :if={!is_map_key(assigns, :memories) or @memories == []} class="text-center py-12 text-gray-600">
            <.icon name="hero-archive-box" class="size-8 mx-auto mb-2 opacity-40" />
            <p class="text-sm">No memories stored</p>
          </div>
          <div class="space-y-2">
            <%= for mem <- Map.get(assigns, :memories, []) do %>
              <div class="p-3 rounded-lg border border-gray-800 bg-gray-900 hover:border-gray-700 transition-colors">
                <div class="flex items-start gap-3">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 flex-wrap mb-1">
                      <span class="text-[10px] px-2 py-0.5 rounded bg-cyan-500/15 text-cyan-400 border border-cyan-500/20 font-semibold">
                        {mem.category}
                      </span>
                      <%= if Map.get(mem, :is_consolidated, false) do %>
                        <span class="text-[10px] px-2 py-0.5 rounded bg-purple-500/15 text-purple-400 border border-purple-500/20">merged</span>
                      <% end %>
                      <span class={"text-[10px] font-semibold #{valence_class(Map.get(mem, :valence, 0))}"}>
                        {if (Map.get(mem, :valence, 0) || 0) > 0, do: "positive", else: if((Map.get(mem, :valence, 0) || 0) < 0, do: "negative", else: "neutral")}
                      </span>
                    </div>
                    <p class="text-sm text-gray-200">{mem.summary}</p>
                  </div>
                  <div class="shrink-0 text-right">
                    <div class="text-xs text-gray-400 font-mono">imp: {mem.importance || 0}</div>
                    <div class="text-[10px] text-gray-600">recalled: {Map.get(mem, :recall_count, 0)}x</div>
                    <div class="text-[10px] text-gray-600">{format_dt(Map.get(mem, :last_recalled_at))}</div>
                  </div>
                </div>
                <div class="mt-2 h-1 w-full rounded-full bg-gray-800 overflow-hidden">
                  <div class="h-full rounded-full bg-cyan-500" style={"width: #{mem.importance || 0}%"}></div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- TAB: Beliefs --%>
        <div :if={@tab == "beliefs"}>
          <%!-- Beliefs grid --%>
          <div class="mb-6">
            <h3 class="text-xs font-bold text-purple-400 uppercase tracking-wide mb-3">Beliefs</h3>
            <div :if={!is_map_key(assigns, :beliefs) or @beliefs == []} class="text-xs text-gray-600 italic">No beliefs recorded</div>
            <div class="grid grid-cols-2 gap-3">
              <%= for belief <- Map.get(assigns, :beliefs, []) do %>
                <div class={["p-3 rounded-lg border bg-gray-900", if(belief.is_challenged, do: "border-orange-500/40", else: "border-gray-800")]}>
                  <div class="flex items-center justify-between gap-2 mb-2">
                    <span class="text-[10px] px-2 py-0.5 rounded bg-purple-500/15 text-purple-400 border border-purple-500/20 font-semibold">{belief.domain}</span>
                    <%= if belief.is_challenged do %>
                      <span class="text-[10px] text-orange-400">challenged</span>
                    <% end %>
                  </div>
                  <p class="text-sm text-gray-200 mb-2">{belief.belief}</p>
                  <div class="h-1 w-full rounded-full bg-gray-800 overflow-hidden">
                    <div class="h-full rounded-full bg-purple-500 transition-all duration-700" style={"width: #{belief.conviction}%"}></div>
                  </div>
                  <div class="text-[10px] text-gray-600 mt-1">conviction: {belief.conviction}/100</div>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Triggers --%>
          <div class="mb-6">
            <h3 class="text-xs font-bold text-orange-400 uppercase tracking-wide mb-3">Triggers</h3>
            <div :if={!is_map_key(assigns, :triggers) or @triggers == []} class="text-xs text-gray-600 italic">No triggers recorded</div>
            <div class="space-y-2">
              <%= for t <- Map.get(assigns, :triggers, []) do %>
                <div class="flex items-center gap-3 p-3 rounded-lg border border-gray-800 bg-gray-900">
                  <span class="text-xs font-semibold text-gray-300 px-2 py-0.5 rounded bg-gray-800">{t.topic}</span>
                  <span class={"text-[10px] px-2 py-0.5 rounded font-semibold #{reaction_badge_class(t.reaction_type)}"}>{String.replace(t.reaction_type, "_", " ")}</span>
                  <span class="text-[10px] text-gray-500">intensity: {t.intensity_modifier}</span>
                  <span :if={t.flavor_text} class="text-[10px] text-gray-500 italic truncate flex-1">"{t.flavor_text}"</span>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Moral Lines --%>
          <div class="mb-6">
            <h3 class="text-xs font-bold text-red-400 uppercase tracking-wide mb-3">Moral Lines</h3>
            <div :if={!is_map_key(assigns, :moral_lines) or @moral_lines == []} class="text-xs text-gray-600 italic">No moral lines recorded</div>
            <div class="space-y-2">
              <%= for ml <- Map.get(assigns, :moral_lines, []) do %>
                <div class="flex items-center gap-3 p-3 rounded-lg border border-gray-800 bg-gray-900">
                  <div class="flex-1">
                    <span class="text-sm text-gray-200">{ml.principle}</span>
                  </div>
                  <%= if ml.will_refuse_when_violated do %>
                    <span class="text-[10px] px-2 py-0.5 rounded bg-red-500/20 text-red-400 border border-red-500/30 font-bold">WILL REFUSE</span>
                  <% end %>
                  <%= if ml.action_types_blocked != [] do %>
                    <div class="flex gap-1 flex-wrap">
                      <%= for a <- ml.action_types_blocked do %>
                        <span class="text-[10px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-500">{a}</span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Secrets --%>
          <div>
            <h3 class="text-xs font-bold text-rose-400 uppercase tracking-wide mb-3">Secrets (Inspector Only)</h3>
            <div :if={!is_map_key(assigns, :secrets) or @secrets == []} class="text-xs text-gray-600 italic">No secrets recorded</div>
            <div class="space-y-2">
              <%= for s <- Map.get(assigns, :secrets, []) do %>
                <div class="flex items-center gap-3 p-3 rounded-lg border border-gray-800 bg-gray-900">
                  <span class={"text-[10px] px-2 py-0.5 rounded border font-bold shrink-0 #{risk_badge_class(s.risk_level)}"}>{s.risk_level}</span>
                  <p class="text-sm text-gray-300 flex-1">{s.secret_text}</p>
                  <span :if={s.domain} class="text-[10px] text-gray-600">{s.domain}</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- TAB: Arcs --%>
        <div :if={@tab == "arcs"}>
          <div class="grid grid-cols-2 gap-6">
            <%!-- Grief Arcs --%>
            <div>
              <h3 class="text-xs font-bold text-indigo-400 uppercase tracking-wide mb-4">Grief Arcs</h3>
              <div :if={@grief_arcs == []} class="text-xs text-gray-600 italic">No active grief arcs</div>
              <div class="space-y-4">
                <%= for arc <- @grief_arcs do %>
                  <div class="p-4 rounded-xl border border-indigo-500/20 bg-gray-900">
                    <div class="text-base font-bold text-gray-100 mb-1">{arc.subject}</div>
                    <div class="flex gap-2 mb-3">
                      <span class="text-[10px] px-2 py-0.5 rounded bg-indigo-500/20 text-indigo-300 border border-indigo-500/30">{arc.loss_type}</span>
                    </div>
                    <%!-- Stage progress dots --%>
                    <div class="flex items-center gap-1 mb-3">
                      <% active_idx = stage_index(grief_stages(), arc.stage) %>
                      <%= for {stage, idx} <- Enum.with_index(grief_stages()) do %>
                        <div class="flex items-center">
                          <div
                            class={"w-2.5 h-2.5 rounded-full border transition-all #{if idx == active_idx, do: "bg-indigo-400 border-indigo-400 scale-125", else: (if idx < active_idx, do: "bg-indigo-700 border-indigo-600", else: "bg-gray-800 border-gray-700")}"}
                            title={stage}
                          ></div>
                          <div :if={idx < length(grief_stages()) - 1} class={"h-0.5 w-4 #{if idx < active_idx, do: "bg-indigo-700", else: "bg-gray-800"}"}></div>
                        </div>
                      <% end %>
                    </div>
                    <div class="text-[10px] text-gray-500 mb-2">Stage: {arc.stage}</div>
                    <div class="h-1.5 w-full rounded-full bg-gray-800 overflow-hidden">
                      <div class="h-full rounded-full bg-indigo-500" style={"width: #{arc.intensity}%"}></div>
                    </div>
                    <div class="text-[10px] text-gray-600 mt-1">intensity: {arc.intensity} | triggered: {format_dt(arc.triggered_at)}</div>

                    <details class="mt-2">
                      <summary class="text-[10px] text-gray-600 uppercase tracking-wide cursor-pointer hover:text-gray-400 transition-colors">Edit</summary>
                      <form phx-submit="save_grief_arc" class="mt-2 grid grid-cols-2 gap-2">
                        <input type="hidden" name="arc_id" value={arc.id} />
                        <select name="stage" class="col-span-2 bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-indigo-500">
                          <%= for s <- grief_stages() do %>
                            <option value={s} selected={arc.stage == s}>{String.capitalize(s)}</option>
                          <% end %>
                        </select>
                        <input type="number" name="intensity" min="0" max="100" value={arc.intensity}
                          class="col-span-2 bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-indigo-500" />
                        <button type="submit" class="col-span-2 text-xs px-3 py-1.5 rounded bg-indigo-500/20 border border-indigo-500/30 text-indigo-400 hover:bg-indigo-500/30 transition-colors">
                          Save
                        </button>
                      </form>
                    </details>
                  </div>
                <% end %>
              </div>

              <form phx-submit="add_grief_arc" class="mt-4 p-3 rounded-lg border border-gray-800 bg-gray-900/50 grid grid-cols-2 gap-2">
                <input type="text" name="subject" placeholder="Subject (who/what was lost)" required
                  class="col-span-2 bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-indigo-500" />
                <select name="loss_type" class="bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-indigo-500">
                  <%= for lt <- ~w(person role belief home ability) do %>
                    <option value={lt}>{String.capitalize(lt)}</option>
                  <% end %>
                </select>
                <input type="number" name="intensity" min="0" max="100" value="70"
                  class="bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-indigo-500" />
                <button type="submit" class="col-span-2 text-xs px-3 py-1.5 rounded bg-indigo-500/20 border border-indigo-500/30 text-indigo-400 hover:bg-indigo-500/30 transition-colors">
                  + Add Grief Arc
                </button>
              </form>
            </div>

            <%!-- Forgiveness Arcs --%>
            <div>
              <h3 class="text-xs font-bold text-rose-400 uppercase tracking-wide mb-4">Forgiveness Arcs</h3>
              <div :if={!is_map_key(assigns, :forgiveness_arcs) or @forgiveness_arcs == []} class="text-xs text-gray-600 italic">No active forgiveness arcs</div>
              <div class="space-y-4">
                <%= for arc <- Map.get(assigns, :forgiveness_arcs, []) do %>
                  <div class="p-4 rounded-xl border border-rose-500/20 bg-gray-900">
                    <p class="text-sm text-gray-100 mb-3">{arc.wound_description}</p>
                    <%!-- Stage progress --%>
                    <div class="flex items-center gap-1 mb-3">
                      <% active_idx = stage_index(forgiveness_stages(), arc.stage) %>
                      <%= for {stage, idx} <- Enum.with_index(forgiveness_stages()) do %>
                        <div class="flex items-center">
                          <div
                            class={"w-2.5 h-2.5 rounded-full border transition-all #{if idx == active_idx, do: "bg-rose-400 border-rose-400 scale-125", else: (if idx < active_idx, do: "bg-rose-700 border-rose-600", else: "bg-gray-800 border-gray-700")}"}
                            title={stage}
                          ></div>
                          <div :if={idx < length(forgiveness_stages()) - 1} class={"h-0.5 w-4 #{if idx < active_idx, do: "bg-rose-700", else: "bg-gray-800"}"}></div>
                        </div>
                      <% end %>
                    </div>
                    <div class="flex items-center gap-3 mb-2">
                      <span class="text-[10px] text-gray-500">Stage: {arc.stage}</span>
                      <span class={"flex items-center gap-1 text-[10px] font-semibold #{direction_color(arc.direction)}"}>
                        <.icon name={direction_icon(arc.direction)} class="size-3" />
                        {arc.direction}
                      </span>
                    </div>
                    <div class="h-1.5 w-full rounded-full bg-gray-800 overflow-hidden">
                      <div class="h-full rounded-full bg-rose-500" style={"width: #{arc.intensity}%"}></div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <%!-- TAB: Goals --%>
        <div :if={@tab == "goals"}>
          <%!-- Active Goals --%>
          <div class="mb-6">
            <h3 class="text-xs font-bold text-blue-400 uppercase tracking-wide mb-3">Active Goals</h3>
            <div :if={@active_goals == []} class="text-xs text-gray-600 italic">No active goals</div>
            <div class="space-y-3">
              <%= for goal <- @active_goals do %>
                <div class="p-4 rounded-xl border border-gray-800 bg-gray-900">
                  <div class="flex items-start justify-between gap-3">
                    <div class="flex-1">
                      <p class="text-base font-semibold text-gray-100">{goal.goal}</p>
                      <p :if={goal.current_step} class="text-xs text-gray-400 mt-1">Next: {goal.current_step}</p>
                    </div>
                    <span class={"text-[10px] px-2 py-0.5 rounded border font-bold shrink-0 #{if goal.priority > 70, do: "bg-red-500/20 text-red-400 border-red-500/30", else: (if goal.priority > 40, do: "bg-yellow-500/20 text-yellow-400 border-yellow-500/30", else: "bg-gray-700 text-gray-400 border-gray-600")}"}>
                      p:{goal.priority}
                    </span>
                  </div>
                  <%= if goal.blocker do %>
                    <div class="mt-2 p-2 rounded bg-red-900/20 border border-red-800/40 text-xs text-red-400">
                      <span class="font-bold">Blocked:</span> {goal.blocker}
                    </div>
                  <% end %>

                  <details class="mt-3">
                    <summary class="text-[10px] text-gray-600 uppercase tracking-wide cursor-pointer hover:text-gray-400 transition-colors">Edit</summary>
                    <form phx-submit="save_goal" class="mt-2 grid grid-cols-2 gap-2">
                      <input type="hidden" name="goal_id" value={goal.id} />
                      <input type="text" name="current_step" value={goal.current_step} placeholder="Current step"
                        class="col-span-2 bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500" />
                      <input type="text" name="blocker" value={goal.blocker} placeholder="Blocker (blank = none)"
                        class="col-span-2 bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500" />
                      <input type="number" name="priority" min="0" max="100" value={goal.priority}
                        class="bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500" />
                      <select name="status" class="bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500">
                        <%= for s <- ~w(active paused achieved abandoned) do %>
                          <option value={s} selected={goal.status == s}>{String.capitalize(s)}</option>
                        <% end %>
                      </select>
                      <button type="submit" class="col-span-2 text-xs px-3 py-1.5 rounded bg-blue-500/20 border border-blue-500/30 text-blue-400 hover:bg-blue-500/30 transition-colors">
                        Save
                      </button>
                    </form>
                  </details>
                </div>
              <% end %>
            </div>

            <form phx-submit="add_goal" class="mt-3 p-3 rounded-lg border border-gray-800 bg-gray-900/50 grid grid-cols-2 gap-2">
              <input type="text" name="goal" placeholder="New goal" required
                class="col-span-2 bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500" />
              <input type="text" name="current_step" placeholder="Current step (optional)"
                class="bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500" />
              <input type="number" name="priority" min="0" max="100" value="50"
                class="bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-blue-500" />
              <button type="submit" class="col-span-2 text-xs px-3 py-1.5 rounded bg-blue-500/20 border border-blue-500/30 text-blue-400 hover:bg-blue-500/30 transition-colors">
                + Add Goal
              </button>
            </form>
          </div>

          <%!-- Desires --%>
          <div class="mb-6">
            <h3 class="text-xs font-bold text-green-400 uppercase tracking-wide mb-3">Desires</h3>
            <div :if={!is_map_key(assigns, :desires) or @desires == []} class="text-xs text-gray-600 italic">No desires recorded</div>
            <div class="space-y-2">
              <%= for d <- Map.get(assigns, :desires, []) do %>
                <div class="flex items-center gap-3 p-3 rounded-lg border border-gray-800 bg-gray-900">
                  <p class="flex-1 text-sm text-gray-200">{d.desire}</p>
                  <span class="text-[10px] px-2 py-0.5 rounded bg-green-500/15 text-green-400 border border-green-500/20 font-semibold">{d.domain}</span>
                  <div class="w-20">
                    <div class="h-1 rounded-full bg-gray-800 overflow-hidden">
                      <div class="h-full rounded-full bg-green-500" style={"width: #{d.urgency}%"}></div>
                    </div>
                    <div class="text-[10px] text-gray-600 text-right">urgency {d.urgency}</div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Completed/Abandoned --%>
          <%= if Map.get(assigns, :completed_goals, []) != [] do %>
            <details class="mt-4">
              <summary class="text-xs text-gray-600 uppercase tracking-wide cursor-pointer hover:text-gray-400 transition-colors">
                Completed / Abandoned ({length(Map.get(assigns, :completed_goals, []))})
              </summary>
              <div class="mt-3 space-y-2">
                <%= for goal <- Map.get(assigns, :completed_goals, []) do %>
                  <div class="flex items-center gap-3 p-3 rounded-lg border border-gray-800 bg-gray-900/50">
                    <span class={"text-[10px] px-2 py-0.5 rounded border #{if goal.status == "achieved", do: "bg-green-500/20 text-green-400 border-green-500/30", else: "bg-gray-700 text-gray-500 border-gray-600"}"}>{goal.status}</span>
                    <p class="text-sm text-gray-400 flex-1 line-through">{goal.goal}</p>
                  </div>
                <% end %>
              </div>
            </details>
          <% end %>
        </div>

        <%!-- TAB: Social --%>
        <div :if={@tab == "social"}>
          <h2 class="text-sm font-bold text-gray-300 mb-4">Relationships</h2>
          <div :if={Map.get(assigns, :relationships, []) == []} class="text-xs text-gray-600 italic mb-4">No outbound relationships recorded</div>
          <div class="space-y-3 mb-4">
            <%= for {rel, target} <- Map.get(assigns, :relationships, []) do %>
              <div class="p-4 rounded-xl border border-gray-800 bg-gray-900">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-sm font-semibold text-gray-100">{target.name}</span>
                  <span class="text-[10px] px-2 py-0.5 rounded bg-gray-800 text-gray-400 border border-gray-700">{rel.relationship_type}</span>
                </div>
                <div class="flex flex-wrap gap-x-3 gap-y-1 text-[10px] text-gray-500 mb-1">
                  <span>Affinity {rel.affinity}</span>
                  <span>Trust {rel.trust}</span>
                  <span>Respect {rel.respect}</span>
                  <span>Fear {rel.fear}</span>
                  <span>Anger {rel.anger}</span>
                </div>

                <details class="mt-2">
                  <summary class="text-[10px] text-gray-600 uppercase tracking-wide cursor-pointer hover:text-gray-400 transition-colors">Edit</summary>
                  <form phx-submit="save_relationship" class="mt-2 space-y-2">
                    <input type="hidden" name="relationship_id" value={rel.id} />
                    <input type="hidden" name="lock_version" value={rel.lock_version} />
                    <select name="relationship_type" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-cyan-500">
                      <%= for t <- ~w(acquaintance friend rival ally enemy family romantic mentor) do %>
                        <option value={t} selected={rel.relationship_type == t}>{String.capitalize(t)}</option>
                      <% end %>
                    </select>
                    <div class="grid grid-cols-5 gap-1.5">
                      <%= for {label, key} <- [{"Affin.", :affinity}, {"Trust", :trust}, {"Resp.", :respect}, {"Fear", :fear}, {"Anger", :anger}, {"Grat.", :gratitude}, {"Debt", :debt}, {"Soft.", :softening}, {"Hard.", :hardening}, {"Wound", :wound}] do %>
                        <div>
                          <label class="block text-[9px] text-gray-500 mb-0.5">{label}</label>
                          <input
                            type="number"
                            min="-100"
                            max="100"
                            name={Atom.to_string(key)}
                            value={Map.get(rel, key)}
                            class="w-full bg-gray-800 border border-gray-700 rounded px-1 py-1 text-[11px] text-gray-100 focus:outline-none focus:border-cyan-500"
                          />
                        </div>
                      <% end %>
                    </div>
                    <button type="submit" class="w-full text-xs px-3 py-1.5 rounded bg-cyan-500/20 border border-cyan-500/30 text-cyan-400 hover:bg-cyan-500/30 transition-colors">
                      Save
                    </button>
                  </form>
                </details>
              </div>
            <% end %>
          </div>

          <%= if Map.get(assigns, :relationship_candidates, []) != [] do %>
            <form phx-submit="add_relationship" class="mb-6 p-3 rounded-lg border border-gray-800 bg-gray-900/50 space-y-2">
              <select name="target_id" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-cyan-500">
                <option value="">Relationship with…</option>
                <%= for c <- @relationship_candidates do %>
                  <option value={c.id}>{c.name}</option>
                <% end %>
              </select>
              <select name="relationship_type" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-cyan-500">
                <%= for t <- ~w(acquaintance friend rival ally enemy family romantic mentor) do %>
                  <option value={t}>{String.capitalize(t)}</option>
                <% end %>
              </select>
              <div class="grid grid-cols-2 gap-2">
                <input type="number" name="affinity" min="-100" max="100" value="0" placeholder="Initial affinity"
                  class="bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-cyan-500" />
                <input type="number" name="trust" min="-100" max="100" value="0" placeholder="Initial trust"
                  class="bg-gray-800 border border-gray-700 rounded-lg px-2 py-1.5 text-xs text-gray-100 focus:outline-none focus:border-cyan-500" />
              </div>
              <button type="submit" class="w-full text-xs px-3 py-1.5 rounded bg-cyan-500/20 border border-cyan-500/30 text-cyan-400 hover:bg-cyan-500/30 transition-colors">
                + Add Relationship
              </button>
            </form>
          <% end %>

          <h2 class="text-sm font-bold text-gray-300 mb-4">Autonomous Conversations</h2>
          <div :if={!is_map_key(assigns, :char_scenes) or @char_scenes == []} class="text-center py-12 text-gray-600">
            <.icon name="hero-chat-bubble-left-right" class="size-8 mx-auto mb-2 opacity-40" />
            <p class="text-sm">No autonomous conversations recorded</p>
          </div>
          <div class="space-y-3">
            <%= for scene <- Map.get(assigns, :char_scenes, []) do %>
              <div class="rounded-xl border border-gray-800 bg-gray-900 overflow-hidden">
                <button
                  phx-click="toggle_scene_expand"
                  phx-value-scene_id={scene.id}
                  class="w-full flex items-center justify-between px-4 py-3 hover:bg-gray-800/50 transition-colors text-left"
                >
                  <div class="flex items-center gap-3">
                    <.icon name="hero-chat-bubble-left-right" class="size-4 text-gray-500" />
                    <div>
                      <div class="text-sm font-semibold text-gray-200">{scene.title}</div>
                      <div class="text-[10px] text-gray-500">
                        {Enum.map(scene.participants, & &1.character.name) |> Enum.join(", ")} · {format_dt(scene.inserted_at)}
                      </div>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="text-[10px] text-gray-600">{length(scene.messages)} msg(s)</span>
                    <.icon name={if MapSet.member?(Map.get(assigns, :expanded_scene_ids, MapSet.new()), scene.id), do: "hero-chevron-up", else: "hero-chevron-down"} class="size-4 text-gray-600" />
                  </div>
                </button>
                <div :if={MapSet.member?(Map.get(assigns, :expanded_scene_ids, MapSet.new()), scene.id)} class="border-t border-gray-800 px-4 py-3 space-y-2 max-h-80 overflow-y-auto">
                  <%= for msg <- scene.messages do %>
                    <div class="text-xs">
                      <span class="font-semibold text-amber-400">
                        {Enum.find_value(scene.participants, "?", fn p -> if p.character_id == msg.character_id, do: p.character.name end)}:
                      </span>
                      <span class="text-gray-300 ml-1">{msg.content}</span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- TAB: Theory of Mind --%>
        <div :if={@tab == "theory_of_mind"}>
          <h2 class="text-sm font-bold text-gray-300 mb-4">Theory of Mind — What {@character.name} Believes About Others</h2>

          <%!-- Grouped knowledge --%>
          <div class="space-y-5 mb-8">
            <div :if={!is_map_key(assigns, :tom_grouped) or @tom_grouped == []} class="text-xs text-gray-600 italic">
              No knowledge entries yet
            </div>
            <%= for {subject_char, entries} <- Map.get(assigns, :tom_grouped, []) do %>
              <div class="p-4 rounded-xl border border-gray-800 bg-gray-900">
                <div class="flex items-center gap-2 mb-3">
                  <div class="w-6 h-6 rounded-full bg-blue-500/20 border border-blue-500/30 flex items-center justify-center text-[10px] font-bold text-blue-400">
                    {String.first(subject_char.name)}
                  </div>
                  <span class="text-sm font-semibold text-gray-200">{subject_char.name}</span>
                  <span class="text-[10px] text-gray-500">{length(entries)} belief(s)</span>
                </div>
                <div class="space-y-2">
                  <%= for entry <- entries do %>
                    <div class="flex items-center gap-3 p-2 rounded-lg bg-gray-800/60">
                      <p class="flex-1 text-xs text-gray-300">{entry.known_fact}</p>
                      <div class="w-20">
                        <div class="h-1 rounded-full bg-gray-700 overflow-hidden">
                          <div class="h-full rounded-full bg-cyan-500" style={"width: #{entry.certainty}%"}></div>
                        </div>
                        <div class="text-[10px] text-gray-600 text-right">{entry.certainty}%</div>
                      </div>
                      <%= if entry.is_assumption do %>
                        <span class="text-[10px] px-1.5 py-0.5 rounded bg-yellow-500/15 text-yellow-500 border border-yellow-500/20">assumption</span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Add Knowledge Form --%>
          <div class="p-4 rounded-xl border border-cyan-500/20 bg-gray-900">
            <h3 class="text-xs font-bold text-cyan-400 uppercase tracking-wide mb-3">Add Knowledge Entry</h3>
            <form phx-change="update_tom_draft" phx-submit="save_tom_entry" class="space-y-3">
              <select name="subject_id" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-cyan-500">
                <option value="">Select subject character...</option>
                <%= for char <- Map.get(assigns, :tom_all_chars, []) do %>
                  <option value={char.id} selected={@tom_draft_subject_id == char.id}>{char.name}</option>
                <% end %>
              </select>
              <input type="text" name="known_fact" value={@tom_draft_fact} placeholder="Known fact or belief about this character"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-cyan-500"/>
              <div class="flex items-center gap-3">
                <input type="range" min="0" max="100" name="certainty" value={@tom_draft_certainty} class="flex-1 accent-cyan-500"/>
                <span class="text-xs text-gray-400 w-20">certainty {@tom_draft_certainty}%</span>
                <label class="flex items-center gap-1.5 text-xs text-gray-400">
                  <input type="checkbox" name="is_assumption" value="true" checked={@tom_draft_assumption} class="accent-cyan-500"/>
                  Assumption
                </label>
              </div>
              <button type="submit" class="px-4 py-2 rounded-lg bg-cyan-500/20 border border-cyan-500/30 text-cyan-300 text-sm font-semibold hover:bg-cyan-500/30 transition-colors">
                Save Entry
              </button>
              <%= if @tom_save_result == :ok do %>
                <span class="text-xs text-green-400 ml-2">Saved!</span>
              <% end %>
              <%= if @tom_save_result == :error do %>
                <span class="text-xs text-red-400 ml-2">Please select a subject and enter a fact.</span>
              <% end %>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
