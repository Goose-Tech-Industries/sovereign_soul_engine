defmodule SovereignSoulEngineWeb.AcpNpcCreatorLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls

  @total_steps 7

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "New NPC — ACP")
      |> assign(:step, 1)
      |> assign(:errors, [])
      # Step 1 — Identity
      |> assign(:name, "")
      |> assign(:slug, "")
      |> assign(:description, "")
      |> assign(:kind, "npc")
      |> assign(:status, "inactive")
      # Step 2 — Personality
      |> assign(:attachment_style, "secure")
      |> assign(:humor_style, "none")
      |> assign(:emotional_susceptibility, 50)
      |> assign(:speech_style, "")
      |> assign(:personality_traits, %{
        "depression" => false,
        "bipolar" => false,
        "ocd" => false,
        "splitting" => false,
        "adhd" => false,
        "narcissism" => false,
        "impostor" => false,
        "codependency" => false,
        "addiction" => false,
        "hypochondria" => false
      })
      # Step 3 — Soul
      |> assign(:core_values, [])
      |> assign(:core_value_input, "")
      |> assign(:baseline_emotions, %{
        "anger" => 0, "fear" => 0, "stress" => 20, "gratitude" => 30,
        "confidence" => 50, "sadness" => 0
      })
      |> assign(:physical_tells, %{
        "anger" => "", "fear" => "", "sadness" => "", "shame" => "", "stress" => ""
      })
      |> assign(:transference_entries, [%{"trigger_pattern" => "", "reminds_them_of" => ""},
                                        %{"trigger_pattern" => "", "reminds_them_of" => ""},
                                        %{"trigger_pattern" => "", "reminds_them_of" => ""}])
      # Step 4 — Psychology
      |> assign(:beliefs, [])
      |> assign(:belief_draft, %{"belief" => "", "domain" => "social", "conviction" => 50})
      |> assign(:triggers, [])
      |> assign(:trigger_draft, %{"topic" => "", "reaction_type" => "anger_spike", "intensity_modifier" => 50, "flavor_text" => ""})
      |> assign(:moral_lines, [])
      |> assign(:moral_line_draft, %{"principle" => "", "will_refuse" => true, "action_types_blocked" => []})
      |> assign(:secrets, [])
      |> assign(:secret_draft, %{"secret_text" => "", "risk_level" => "medium", "domain" => ""})
      # Step 5 — Desires & Goals
      |> assign(:desires, [])
      |> assign(:desire_draft, %{"desire" => "", "domain" => "connection", "urgency" => 50})
      |> assign(:goals, [])
      |> assign(:goal_draft, %{"goal" => "", "current_step" => "", "priority" => 50})
      # Step 6 — Backstory State
      |> assign(:grief_arcs, [])
      |> assign(:grief_draft, %{"subject" => "", "loss_type" => "person", "stage" => "denial", "intensity" => 70})
      |> assign(:forgiveness_arcs, [])
      |> assign(:forgiveness_draft, %{"wound_description" => "", "stage" => "fresh", "direction" => "neutral", "intensity" => 80})
      |> assign(:tom_entries, [])
      |> assign(:tom_draft, %{"known_fact" => "", "certainty" => 70, "is_assumption" => true})
      # Step 7 — Physical & Social
      |> assign(:social_stamina, 80)
      |> assign(:stamina_regen_rate, 10)
      |> assign(:stamina_max, 100)
      |> assign(:hunger, 0)
      |> assign(:pain, 0)
      |> assign(:fatigue, 20)
      |> assign(:illness_severity, 0)
      |> assign(:submitting, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # Navigation
  @impl true
  def handle_event("next_step", _params, %{assigns: %{step: step}} = socket)
      when step < @total_steps do
    {:noreply, assign(socket, step: step + 1)}
  end

  def handle_event("next_step", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("prev_step", _params, %{assigns: %{step: step}} = socket) when step > 1 do
    {:noreply, assign(socket, step: step - 1)}
  end

  def handle_event("prev_step", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("goto_step", %{"step" => step_str}, socket) do
    step = String.to_integer(step_str)
    {:noreply, assign(socket, step: step)}
  end

  # Step 1 — Identity
  @impl true
  def handle_event("update_identity", params, socket) do
    name = Map.get(params, "name", socket.assigns.name)
    slug_raw = Map.get(params, "slug", "")
    slug = if slug_raw == "", do: slugify(name), else: slug_raw

    socket =
      socket
      |> assign(:name, name)
      |> assign(:slug, slug)
      |> assign(:description, Map.get(params, "description", socket.assigns.description))
      |> assign(:kind, Map.get(params, "kind", socket.assigns.kind))
      |> assign(:status, Map.get(params, "status", socket.assigns.status))

    {:noreply, socket}
  end

  @impl true
  def handle_event("auto_slug", %{"name" => name}, socket) do
    {:noreply, assign(socket, :slug, slugify(name))}
  end

  # Step 2 — Personality
  @impl true
  def handle_event("update_personality", params, socket) do
    socket =
      socket
      |> assign(:attachment_style, Map.get(params, "attachment_style", socket.assigns.attachment_style))
      |> assign(:humor_style, Map.get(params, "humor_style", socket.assigns.humor_style))
      |> assign(:emotional_susceptibility, parse_int(params["emotional_susceptibility"], socket.assigns.emotional_susceptibility))
      |> assign(:speech_style, Map.get(params, "speech_style", socket.assigns.speech_style))

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_trait", %{"trait" => trait}, socket) do
    traits = socket.assigns.personality_traits
    updated = Map.put(traits, trait, !Map.get(traits, trait, false))
    {:noreply, assign(socket, :personality_traits, updated)}
  end

  # Step 3 — Soul: core values
  @impl true
  def handle_event("update_core_value_input", %{"value" => val}, socket) do
    {:noreply, assign(socket, :core_value_input, val)}
  end

  @impl true
  def handle_event("add_core_value", _params, socket) do
    val = String.trim(socket.assigns.core_value_input)
    if val != "" and val not in socket.assigns.core_values do
      socket =
        socket
        |> assign(:core_values, socket.assigns.core_values ++ [val])
        |> assign(:core_value_input, "")
      {:noreply, socket}
    else
      {:noreply, assign(socket, :core_value_input, "")}
    end
  end

  @impl true
  def handle_event("remove_core_value", %{"value" => val}, socket) do
    {:noreply, assign(socket, :core_values, List.delete(socket.assigns.core_values, val))}
  end

  @impl true
  def handle_event("update_baseline_emotion", %{"emotion" => emotion, "value" => val}, socket) do
    emotions = Map.put(socket.assigns.baseline_emotions, emotion, parse_int(val, 0))
    {:noreply, assign(socket, :baseline_emotions, emotions)}
  end

  @impl true
  def handle_event("update_physical_tell", %{"emotion" => emotion, "value" => val}, socket) do
    tells = Map.put(socket.assigns.physical_tells, emotion, val)
    {:noreply, assign(socket, :physical_tells, tells)}
  end

  @impl true
  def handle_event("update_transference", %{"index" => idx_str, "field" => field, "value" => val}, socket) do
    idx = String.to_integer(idx_str)
    entries = List.update_at(socket.assigns.transference_entries, idx, &Map.put(&1, field, val))
    {:noreply, assign(socket, :transference_entries, entries)}
  end

  # Step 4 — Beliefs
  @impl true
  def handle_event("update_belief_draft", params, socket) do
    draft =
      socket.assigns.belief_draft
      |> Map.merge(Map.take(params, ["belief", "domain"]))
      |> Map.put("conviction", parse_int(params["conviction"], socket.assigns.belief_draft["conviction"]))
    {:noreply, assign(socket, :belief_draft, draft)}
  end

  @impl true
  def handle_event("add_belief", _params, socket) do
    if String.trim(socket.assigns.belief_draft["belief"] || "") != "" do
      beliefs = socket.assigns.beliefs ++ [socket.assigns.belief_draft]
      socket = socket |> assign(:beliefs, beliefs) |> assign(:belief_draft, %{"belief" => "", "domain" => "social", "conviction" => 50})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_belief", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {:noreply, assign(socket, :beliefs, List.delete_at(socket.assigns.beliefs, idx))}
  end

  # Step 4 — Triggers
  @impl true
  def handle_event("update_trigger_draft", params, socket) do
    draft =
      socket.assigns.trigger_draft
      |> Map.merge(Map.take(params, ["topic", "reaction_type", "flavor_text"]))
      |> Map.put("intensity_modifier", parse_int(params["intensity_modifier"], socket.assigns.trigger_draft["intensity_modifier"]))
    {:noreply, assign(socket, :trigger_draft, draft)}
  end

  @impl true
  def handle_event("add_trigger", _params, socket) do
    if String.trim(socket.assigns.trigger_draft["topic"] || "") != "" do
      triggers = socket.assigns.triggers ++ [socket.assigns.trigger_draft]
      socket = socket |> assign(:triggers, triggers) |> assign(:trigger_draft, %{"topic" => "", "reaction_type" => "anger_spike", "intensity_modifier" => 50, "flavor_text" => ""})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_trigger", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {:noreply, assign(socket, :triggers, List.delete_at(socket.assigns.triggers, idx))}
  end

  # Step 4 — Moral Lines
  @impl true
  def handle_event("update_moral_line_draft", params, socket) do
    draft =
      socket.assigns.moral_line_draft
      |> Map.merge(Map.take(params, ["principle"]))

    {:noreply, assign(socket, :moral_line_draft, draft)}
  end

  @impl true
  def handle_event("add_moral_line", _params, socket) do
    if String.trim(socket.assigns.moral_line_draft["principle"] || "") != "" do
      moral_lines = socket.assigns.moral_lines ++ [socket.assigns.moral_line_draft]
      socket = socket |> assign(:moral_lines, moral_lines) |> assign(:moral_line_draft, %{"principle" => "", "will_refuse" => true, "action_types_blocked" => []})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_moral_line", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {:noreply, assign(socket, :moral_lines, List.delete_at(socket.assigns.moral_lines, idx))}
  end

  # Step 4 — Secrets
  @impl true
  def handle_event("update_secret_draft", params, socket) do
    draft = socket.assigns.secret_draft |> Map.merge(Map.take(params, ["secret_text", "risk_level", "domain"]))
    {:noreply, assign(socket, :secret_draft, draft)}
  end

  @impl true
  def handle_event("add_secret", _params, socket) do
    if String.trim(socket.assigns.secret_draft["secret_text"] || "") != "" do
      secrets = socket.assigns.secrets ++ [socket.assigns.secret_draft]
      socket = socket |> assign(:secrets, secrets) |> assign(:secret_draft, %{"secret_text" => "", "risk_level" => "medium", "domain" => ""})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_secret", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {:noreply, assign(socket, :secrets, List.delete_at(socket.assigns.secrets, idx))}
  end

  # Step 5 — Desires
  @impl true
  def handle_event("update_desire_draft", params, socket) do
    draft =
      socket.assigns.desire_draft
      |> Map.merge(Map.take(params, ["desire", "domain"]))
      |> Map.put("urgency", parse_int(params["urgency"], socket.assigns.desire_draft["urgency"]))
    {:noreply, assign(socket, :desire_draft, draft)}
  end

  @impl true
  def handle_event("add_desire", _params, socket) do
    if String.trim(socket.assigns.desire_draft["desire"] || "") != "" do
      desires = socket.assigns.desires ++ [socket.assigns.desire_draft]
      socket = socket |> assign(:desires, desires) |> assign(:desire_draft, %{"desire" => "", "domain" => "connection", "urgency" => 50})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_desire", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {:noreply, assign(socket, :desires, List.delete_at(socket.assigns.desires, idx))}
  end

  # Step 5 — Goals
  @impl true
  def handle_event("update_goal_draft", params, socket) do
    draft =
      socket.assigns.goal_draft
      |> Map.merge(Map.take(params, ["goal", "current_step"]))
      |> Map.put("priority", parse_int(params["priority"], socket.assigns.goal_draft["priority"]))
    {:noreply, assign(socket, :goal_draft, draft)}
  end

  @impl true
  def handle_event("add_goal", _params, socket) do
    if String.trim(socket.assigns.goal_draft["goal"] || "") != "" do
      goals = socket.assigns.goals ++ [socket.assigns.goal_draft]
      socket = socket |> assign(:goals, goals) |> assign(:goal_draft, %{"goal" => "", "current_step" => "", "priority" => 50})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_goal", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {:noreply, assign(socket, :goals, List.delete_at(socket.assigns.goals, idx))}
  end

  # Step 6 — Grief Arcs
  @impl true
  def handle_event("update_grief_draft", params, socket) do
    draft =
      socket.assigns.grief_draft
      |> Map.merge(Map.take(params, ["subject", "loss_type", "stage"]))
      |> Map.put("intensity", parse_int(params["intensity"], socket.assigns.grief_draft["intensity"]))
    {:noreply, assign(socket, :grief_draft, draft)}
  end

  @impl true
  def handle_event("add_grief_arc", _params, socket) do
    if String.trim(socket.assigns.grief_draft["subject"] || "") != "" do
      grief_arcs = socket.assigns.grief_arcs ++ [socket.assigns.grief_draft]
      socket = socket |> assign(:grief_arcs, grief_arcs) |> assign(:grief_draft, %{"subject" => "", "loss_type" => "person", "stage" => "denial", "intensity" => 70})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_grief_arc", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {:noreply, assign(socket, :grief_arcs, List.delete_at(socket.assigns.grief_arcs, idx))}
  end

  # Step 6 — Forgiveness Arcs
  @impl true
  def handle_event("update_forgiveness_draft", params, socket) do
    draft =
      socket.assigns.forgiveness_draft
      |> Map.merge(Map.take(params, ["wound_description", "stage", "direction"]))
      |> Map.put("intensity", parse_int(params["intensity"], socket.assigns.forgiveness_draft["intensity"]))
    {:noreply, assign(socket, :forgiveness_draft, draft)}
  end

  @impl true
  def handle_event("add_forgiveness_arc", _params, socket) do
    if String.trim(socket.assigns.forgiveness_draft["wound_description"] || "") != "" do
      arcs = socket.assigns.forgiveness_arcs ++ [socket.assigns.forgiveness_draft]
      socket = socket |> assign(:forgiveness_arcs, arcs) |> assign(:forgiveness_draft, %{"wound_description" => "", "stage" => "fresh", "direction" => "neutral", "intensity" => 80})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_forgiveness_arc", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {:noreply, assign(socket, :forgiveness_arcs, List.delete_at(socket.assigns.forgiveness_arcs, idx))}
  end

  # Step 6 — Theory of Mind
  @impl true
  def handle_event("update_tom_draft", params, socket) do
    draft =
      socket.assigns.tom_draft
      |> Map.merge(Map.take(params, ["known_fact"]))
      |> Map.put("certainty", parse_int(params["certainty"], socket.assigns.tom_draft["certainty"]))
      |> Map.put("is_assumption", Map.get(params, "is_assumption", "true") == "true")
    {:noreply, assign(socket, :tom_draft, draft)}
  end

  @impl true
  def handle_event("add_tom_entry", _params, socket) do
    if String.trim(socket.assigns.tom_draft["known_fact"] || "") != "" do
      entries = socket.assigns.tom_entries ++ [socket.assigns.tom_draft]
      socket = socket |> assign(:tom_entries, entries) |> assign(:tom_draft, %{"known_fact" => "", "certainty" => 70, "is_assumption" => true})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_tom_entry", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {:noreply, assign(socket, :tom_entries, List.delete_at(socket.assigns.tom_entries, idx))}
  end

  # Step 7 — Physical & Social
  @impl true
  def handle_event("update_stamina", params, socket) do
    socket =
      socket
      |> assign(:social_stamina, parse_int(params["social_stamina"], socket.assigns.social_stamina))
      |> assign(:stamina_regen_rate, parse_int(params["stamina_regen_rate"], socket.assigns.stamina_regen_rate))
      |> assign(:stamina_max, parse_int(params["stamina_max"], socket.assigns.stamina_max))
      |> assign(:hunger, parse_int(params["hunger"], socket.assigns.hunger))
      |> assign(:pain, parse_int(params["pain"], socket.assigns.pain))
      |> assign(:fatigue, parse_int(params["fatigue"], socket.assigns.fatigue))
      |> assign(:illness_severity, parse_int(params["illness_severity"], socket.assigns.illness_severity))

    {:noreply, socket}
  end

  # Final submit
  @impl true
  def handle_event("create_npc", _params, socket) do
    a = socket.assigns

    with {:ok, character} <- Characters.create_character(%{
           name: a.name,
           slug: a.slug,
           kind: a.kind,
           description: a.description,
           status: a.status
         }),
         active_traits =
           a.personality_traits
           |> Enum.filter(fn {_k, v} -> v end)
           |> Enum.map(fn {k, _} -> k end),
         transference =
           a.transference_entries
           |> Enum.reject(&(String.trim(&1["trigger_pattern"] || "") == ""))
           |> Enum.with_index()
           |> Enum.map(fn {e, i} -> {Integer.to_string(i), e} end)
           |> Map.new(),
         {:ok, _soul} <- Souls.create_soul_profile(%{
           character_id: character.id,
           attachment_style: a.attachment_style,
           humor_style: a.humor_style,
           emotional_susceptibility: a.emotional_susceptibility,
           speech_style: a.speech_style,
           personality_traits: Map.new(active_traits, &{&1, true}),
           core_values: a.core_values,
           baseline_emotions: a.baseline_emotions,
           physical_tells: a.physical_tells,
           transference_profile: transference,
           social_stamina: a.social_stamina,
           stamina_regen_rate: a.stamina_regen_rate,
           stamina_max: a.stamina_max
         }),
         baseline = a.baseline_emotions,
         {:ok, _emotion} <- Souls.create_emotional_state(%{
           character_id: character.id,
           anger: Map.get(baseline, "anger", 0),
           fear: Map.get(baseline, "fear", 0),
           stress: Map.get(baseline, "stress", 20),
           gratitude: Map.get(baseline, "gratitude", 30),
           confidence: Map.get(baseline, "confidence", 50),
           sadness: Map.get(baseline, "sadness", 0)
         }),
         {:ok, _somatic} <- Souls.create_somatic_state(%{
           character_id: character.id,
           hunger: a.hunger,
           pain: a.pain,
           fatigue: a.fatigue,
           illness_severity: a.illness_severity
         }) do
      # Create beliefs
      for b <- a.beliefs do
        Souls.create_belief(%{
          character_id: character.id,
          belief: b["belief"],
          domain: b["domain"],
          conviction: b["conviction"]
        })
      end

      # Create triggers
      for t <- a.triggers do
        Souls.create_trigger(%{
          character_id: character.id,
          topic: t["topic"],
          reaction_type: t["reaction_type"],
          intensity_modifier: t["intensity_modifier"],
          flavor_text: t["flavor_text"]
        })
      end

      # Create moral lines
      for ml <- a.moral_lines do
        Souls.create_moral_line(%{
          character_id: character.id,
          principle: ml["principle"],
          will_refuse_when_violated: ml["will_refuse"],
          action_types_blocked: ml["action_types_blocked"] || []
        })
      end

      # Create secrets
      for s <- a.secrets do
        Souls.create_secret(%{
          character_id: character.id,
          secret_text: s["secret_text"],
          risk_level: s["risk_level"],
          domain: s["domain"]
        })
      end

      # Create desires
      for d <- a.desires do
        Souls.create_desire(%{
          character_id: character.id,
          desire: d["desire"],
          domain: d["domain"],
          urgency: d["urgency"]
        })
      end

      # Create goals
      for g <- a.goals do
        Souls.create_goal(%{
          character_id: character.id,
          goal: g["goal"],
          current_step: g["current_step"],
          priority: g["priority"]
        })
      end

      # Create grief arcs
      for ga <- a.grief_arcs do
        Souls.create_grief_arc(%{
          character_id: character.id,
          subject: ga["subject"],
          loss_type: ga["loss_type"],
          stage: ga["stage"],
          intensity: ga["intensity"],
          triggered_at: DateTime.utc_now()
        })
      end

      # Create forgiveness arcs
      for fa <- a.forgiveness_arcs do
        Souls.create_forgiveness_arc(%{
          character_id: character.id,
          wound_description: fa["wound_description"],
          stage: fa["stage"],
          direction: fa["direction"],
          intensity: fa["intensity"]
        })
      end

      {:noreply, push_navigate(socket, to: ~p"/acp/npcs/#{character.id}")}
    else
      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)

        {:noreply, assign(socket, :errors, [inspect(errors)])}
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100">
      <%!-- Nav --%>
      <nav class="border-b border-gray-800 bg-gray-900 px-6 py-3 flex items-center gap-6">
        <span class="text-amber-400 font-bold text-sm tracking-wide">SOVEREIGN SOUL ENGINE — ACP</span>
        <div class="flex items-center gap-4 ml-4">
          <.link navigate={~p"/acp"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">Dashboard</.link>
          <.link navigate={~p"/acp/npcs/new"} class="text-sm text-amber-400 font-semibold border-b border-amber-400 pb-0.5">New NPC</.link>
          <.link navigate={~p"/acp/social"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">Social Log</.link>
        </div>
      </nav>

      <div class="max-w-3xl mx-auto px-6 py-8">
        <div class="mb-8">
          <h1 class="text-xl font-bold text-gray-100">New NPC Wizard</h1>
          <p class="text-xs text-gray-500 mt-1">Step {@step} of {@total_steps}</p>
        </div>

        <%!-- Step progress bar --%>
        <div class="flex items-center gap-1 mb-8">
          <%= for s <- 1..@total_steps do %>
            <button
              phx-click="goto_step"
              phx-value-step={s}
              class={[
                "h-1.5 flex-1 rounded-full transition-all",
                s == @step && "bg-amber-400",
                s < @step && "bg-amber-700",
                s > @step && "bg-gray-800"
              ]}
            >
            </button>
          <% end %>
        </div>

        <%!-- Errors --%>
        <div :if={@errors != []} class="mb-4 p-3 rounded-lg bg-red-900/30 border border-red-800/50 text-red-400 text-sm">
          <%= for err <- @errors do %>
            <div>{err}</div>
          <% end %>
        </div>

        <%!-- STEP 1: Identity --%>
        <div :if={@step == 1} class="space-y-6">
          <div class="p-6 rounded-xl border border-gray-800 bg-gray-900">
            <h2 class="text-base font-bold text-amber-400 mb-4">Step 1 — Identity</h2>
            <form phx-change="update_identity" class="space-y-4">
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Name</label>
                <input type="text" name="name" value={@name} phx-blur="auto_slug"
                  class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500"
                  placeholder="e.g. Morrigan"/>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Slug</label>
                <input type="text" name="slug" value={@slug}
                  class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 font-mono focus:outline-none focus:border-amber-500"
                  placeholder="auto-derived"/>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Description</label>
                <textarea name="description" rows="3"
                  class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500"
                  placeholder="Who is this character?">{@description}</textarea>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Kind</label>
                  <select name="kind" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500">
                    <option value="npc" selected={@kind == "npc"}>npc</option>
                    <option value="player" selected={@kind == "player"}>player</option>
                    <option value="creature" selected={@kind == "creature"}>creature</option>
                    <option value="system" selected={@kind == "system"}>system</option>
                  </select>
                </div>
                <div>
                  <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Status</label>
                  <select name="status" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500">
                    <option value="active" selected={@status == "active"}>active</option>
                    <option value="inactive" selected={@status == "inactive"}>inactive</option>
                  </select>
                </div>
              </div>
            </form>
          </div>
        </div>

        <%!-- STEP 2: Personality --%>
        <div :if={@step == 2} class="space-y-6">
          <div class="p-6 rounded-xl border border-gray-800 bg-gray-900">
            <h2 class="text-base font-bold text-amber-400 mb-4">Step 2 — Personality</h2>
            <form phx-change="update_personality" class="space-y-5">
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Attachment Style</label>
                <select name="attachment_style" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500">
                  <option value="secure" selected={@attachment_style == "secure"}>Secure — trusts bonds, comfortable with closeness</option>
                  <option value="anxious" selected={@attachment_style == "anxious"}>Anxious — fears abandonment, seeks constant reassurance</option>
                  <option value="avoidant" selected={@attachment_style == "avoidant"}>Avoidant — suppresses need for closeness, self-reliant</option>
                  <option value="disorganized" selected={@attachment_style == "disorganized"}>Disorganized — craves and fears intimacy simultaneously</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Humor Style</label>
                <select name="humor_style" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500">
                  <%= for style <- ~w(none dry sarcastic warm dark absurdist) do %>
                    <option value={style} selected={@humor_style == style}>{String.capitalize(style)}</option>
                  <% end %>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">
                  Emotional Porousness — {@emotional_susceptibility}
                </label>
                <input type="range" name="emotional_susceptibility" min="0" max="100"
                  value={@emotional_susceptibility}
                  class="w-full accent-amber-500"/>
                <div class="flex justify-between text-[10px] text-gray-600 mt-1">
                  <span>Unaffected</span><span>Highly porous</span>
                </div>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Speech Style</label>
                <textarea name="speech_style" rows="2"
                  class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500"
                  placeholder="How do they talk? Terse? Verbose? Formal? Folksy?">{@speech_style}</textarea>
              </div>
            </form>

            <div class="mt-5">
              <label class="block text-xs text-gray-400 mb-2 font-semibold uppercase tracking-wide">Personality Flags</label>
              <div class="grid grid-cols-2 gap-2">
                <%= for {trait, active} <- @personality_traits do %>
                  <button
                    phx-click="toggle_trait"
                    phx-value-trait={trait}
                    class={[
                      "flex items-center gap-2 px-3 py-2 rounded-lg border text-sm transition-all",
                      active && "bg-purple-500/20 border-purple-500/40 text-purple-300",
                      !active && "bg-gray-800/60 border-gray-700/60 text-gray-500 hover:text-gray-300"
                    ]}
                  >
                    <div class={"w-2 h-2 rounded-full #{if active, do: "bg-purple-400", else: "bg-gray-600"}"}></div>
                    {String.capitalize(trait)}
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <%!-- STEP 3: Soul --%>
        <div :if={@step == 3} class="space-y-5">
          <div class="p-6 rounded-xl border border-gray-800 bg-gray-900">
            <h2 class="text-base font-bold text-amber-400 mb-4">Step 3 — Soul</h2>

            <%!-- Core Values --%>
            <div class="mb-5">
              <label class="block text-xs text-gray-400 mb-2 font-semibold uppercase tracking-wide">Core Values</label>
              <div class="flex flex-wrap gap-2 mb-2">
                <%= for v <- @core_values do %>
                  <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-300 text-xs">
                    {v}
                    <button phx-click="remove_core_value" phx-value-value={v} type="button" class="text-amber-500 hover:text-amber-200 ml-0.5">
                      <.icon name="hero-x-mark" class="size-3" />
                    </button>
                  </span>
                <% end %>
              </div>
              <form phx-submit="add_core_value" class="flex gap-2">
                <input type="text" value={@core_value_input} phx-change="update_core_value_input" phx-value-value={@core_value_input} name="value"
                  placeholder="e.g. loyalty — press Enter to add"
                  class="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500"/>
                <button type="submit" class="px-3 py-2 rounded-lg bg-amber-500/20 border border-amber-500/30 text-amber-400 text-sm hover:bg-amber-500/30 transition-colors">Add</button>
              </form>
            </div>

            <%!-- Baseline Emotions --%>
            <div class="mb-5">
              <label class="block text-xs text-gray-400 mb-3 font-semibold uppercase tracking-wide">Baseline Emotions</label>
              <div class="space-y-2">
                <%= for {emotion, color} <- [{"anger", "red"}, {"fear", "purple"}, {"stress", "orange"}, {"gratitude", "green"}, {"confidence", "blue"}, {"sadness", "indigo"}] do %>
                  <div class="flex items-center gap-3">
                    <span class="w-20 text-xs text-gray-400 capitalize">{emotion}</span>
                    <input type="range" min="0" max="100"
                      value={Map.get(@baseline_emotions, emotion, 0)}
                      phx-change="update_baseline_emotion"
                      phx-value-emotion={emotion}
                      name="value"
                      class={"flex-1 accent-#{color}-500"}/>
                    <span class="w-8 text-xs text-gray-400 text-right">{Map.get(@baseline_emotions, emotion, 0)}</span>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Physical Tells --%>
            <div class="mb-5">
              <label class="block text-xs text-gray-400 mb-3 font-semibold uppercase tracking-wide">Physical Tells</label>
              <div class="space-y-2">
                <%= for emotion <- ~w(anger fear sadness shame stress) do %>
                  <div>
                    <label class="block text-[10px] text-gray-500 mb-1 capitalize">{emotion} tell</label>
                    <input type="text"
                      value={Map.get(@physical_tells, emotion, "")}
                      phx-change="update_physical_tell"
                      phx-value-emotion={emotion}
                      name="value"
                      placeholder={"How does this NPC show #{emotion}? (e.g. jaw tightens)"}
                      class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500"/>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Transference --%>
            <div>
              <label class="block text-xs text-gray-400 mb-3 font-semibold uppercase tracking-wide">Transference Profile</label>
              <%= for {entry, idx} <- Enum.with_index(@transference_entries) do %>
                <div class="grid grid-cols-2 gap-2 mb-2">
                  <input type="text" value={entry["trigger_pattern"]}
                    phx-change="update_transference"
                    phx-value-index={idx}
                    phx-value-field="trigger_pattern"
                    name="value"
                    placeholder="Trigger pattern (e.g. authority figures)"
                    class="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500"/>
                  <input type="text" value={entry["reminds_them_of"]}
                    phx-change="update_transference"
                    phx-value-index={idx}
                    phx-value-field="reminds_them_of"
                    name="value"
                    placeholder="Reminds them of (e.g. their father)"
                    class="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-amber-500"/>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- STEP 4: Psychology --%>
        <div :if={@step == 4} class="space-y-5">
          <%!-- Beliefs --%>
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h3 class="text-sm font-bold text-purple-400 mb-3">Beliefs</h3>
            <%= for {b, idx} <- Enum.with_index(@beliefs) do %>
              <div class="flex items-center gap-2 mb-2 p-2 bg-gray-800/60 rounded-lg">
                <div class="flex-1 text-xs text-gray-300 truncate">{b["belief"]}</div>
                <span class="text-[10px] text-gray-500 px-2 py-0.5 rounded bg-gray-700">{b["domain"]}</span>
                <span class="text-[10px] text-gray-500">{b["conviction"]}</span>
                <button phx-click="remove_belief" phx-value-index={idx} class="text-gray-600 hover:text-red-400">
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            <% end %>
            <form phx-change="update_belief_draft" class="space-y-2">
              <input type="text" name="belief" value={@belief_draft["belief"]} placeholder="Belief statement"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-purple-500"/>
              <div class="flex gap-2">
                <select name="domain" class="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-purple-500">
                  <%= for d <- ~w(social self world spiritual) do %>
                    <option value={d} selected={@belief_draft["domain"] == d}>{String.capitalize(d)}</option>
                  <% end %>
                </select>
                <input type="range" min="0" max="100" name="conviction" value={@belief_draft["conviction"]} class="flex-1 accent-purple-500"/>
                <span class="text-xs text-gray-400 w-6">{@belief_draft["conviction"]}</span>
              </div>
            </form>
            <button phx-click="add_belief" class="mt-2 text-xs px-3 py-1.5 rounded bg-purple-500/20 border border-purple-500/30 text-purple-400 hover:bg-purple-500/30 transition-colors">+ Add Belief</button>
          </div>

          <%!-- Triggers --%>
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h3 class="text-sm font-bold text-orange-400 mb-3">Triggers</h3>
            <%= for {t, idx} <- Enum.with_index(@triggers) do %>
              <div class="flex items-center gap-2 mb-2 p-2 bg-gray-800/60 rounded-lg">
                <div class="flex-1 text-xs text-gray-300 truncate">{t["topic"]}</div>
                <span class="text-[10px] text-gray-500 px-2 py-0.5 rounded bg-gray-700">{t["reaction_type"]}</span>
                <button phx-click="remove_trigger" phx-value-index={idx} class="text-gray-600 hover:text-red-400">
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            <% end %>
            <form phx-change="update_trigger_draft" class="space-y-2">
              <input type="text" name="topic" value={@trigger_draft["topic"]} placeholder="Topic / keyword that triggers"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-orange-500"/>
              <select name="reaction_type" class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-orange-500">
                <%= for r <- ~w(anger_spike fear_spike grief_spike pride_surge shame_trigger) do %>
                  <option value={r} selected={@trigger_draft["reaction_type"] == r}>{String.replace(r, "_", " ") |> String.capitalize()}</option>
                <% end %>
              </select>
              <input type="text" name="flavor_text" value={@trigger_draft["flavor_text"]} placeholder="Flavor text (how it manifests)"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-orange-500"/>
            </form>
            <button phx-click="add_trigger" class="mt-2 text-xs px-3 py-1.5 rounded bg-orange-500/20 border border-orange-500/30 text-orange-400 hover:bg-orange-500/30 transition-colors">+ Add Trigger</button>
          </div>

          <%!-- Moral Lines --%>
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h3 class="text-sm font-bold text-red-400 mb-3">Moral Lines</h3>
            <%= for {ml, idx} <- Enum.with_index(@moral_lines) do %>
              <div class="flex items-center gap-2 mb-2 p-2 bg-gray-800/60 rounded-lg">
                <div class="flex-1 text-xs text-gray-300 truncate">{ml["principle"]}</div>
                <button phx-click="remove_moral_line" phx-value-index={idx} class="text-gray-600 hover:text-red-400">
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            <% end %>
            <form phx-change="update_moral_line_draft" class="space-y-2">
              <input type="text" name="principle" value={@moral_line_draft["principle"]} placeholder="Moral principle (e.g. Never harm a child)"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-red-500"/>
            </form>
            <button phx-click="add_moral_line" class="mt-2 text-xs px-3 py-1.5 rounded bg-red-500/20 border border-red-500/30 text-red-400 hover:bg-red-500/30 transition-colors">+ Add Moral Line</button>
          </div>

          <%!-- Secrets --%>
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h3 class="text-sm font-bold text-rose-400 mb-3">Secrets</h3>
            <%= for {s, idx} <- Enum.with_index(@secrets) do %>
              <div class="flex items-center gap-2 mb-2 p-2 bg-gray-800/60 rounded-lg">
                <div class="flex-1 text-xs text-gray-300 truncate">{s["secret_text"]}</div>
                <span class={"text-[10px] px-2 py-0.5 rounded border #{secret_risk_class(s["risk_level"])}"}>{s["risk_level"]}</span>
                <button phx-click="remove_secret" phx-value-index={idx} class="text-gray-600 hover:text-red-400">
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            <% end %>
            <form phx-change="update_secret_draft" class="space-y-2">
              <textarea name="secret_text" rows="2" placeholder="The secret..."
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-rose-500">{@secret_draft["secret_text"]}</textarea>
              <div class="flex gap-2">
                <select name="risk_level" class="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-rose-500">
                  <%= for r <- ~w(low medium high critical) do %>
                    <option value={r} selected={@secret_draft["risk_level"] == r}>{String.capitalize(r)}</option>
                  <% end %>
                </select>
                <input type="text" name="domain" value={@secret_draft["domain"]} placeholder="Domain"
                  class="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-rose-500"/>
              </div>
            </form>
            <button phx-click="add_secret" class="mt-2 text-xs px-3 py-1.5 rounded bg-rose-500/20 border border-rose-500/30 text-rose-400 hover:bg-rose-500/30 transition-colors">+ Add Secret</button>
          </div>
        </div>

        <%!-- STEP 5: Desires & Goals --%>
        <div :if={@step == 5} class="space-y-5">
          <%!-- Desires --%>
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h3 class="text-sm font-bold text-green-400 mb-3">Desires</h3>
            <%= for {d, idx} <- Enum.with_index(@desires) do %>
              <div class="flex items-center gap-2 mb-2 p-2 bg-gray-800/60 rounded-lg">
                <div class="flex-1 text-xs text-gray-300 truncate">{d["desire"]}</div>
                <span class="text-[10px] text-gray-500 px-2 py-0.5 rounded bg-gray-700">{d["domain"]}</span>
                <span class="text-[10px] text-gray-500">u:{d["urgency"]}</span>
                <button phx-click="remove_desire" phx-value-index={idx} class="text-gray-600 hover:text-red-400">
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            <% end %>
            <form phx-change="update_desire_draft" class="space-y-2">
              <input type="text" name="desire" value={@desire_draft["desire"]} placeholder="Desire statement"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-green-500"/>
              <div class="flex gap-2 items-center">
                <select name="domain" class="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-green-500">
                  <%= for d <- ~w(revenge connection safety power redemption knowledge belonging) do %>
                    <option value={d} selected={@desire_draft["domain"] == d}>{String.capitalize(d)}</option>
                  <% end %>
                </select>
                <input type="range" min="0" max="100" name="urgency" value={@desire_draft["urgency"]} class="flex-1 accent-green-500"/>
                <span class="text-xs text-gray-400 w-6">{@desire_draft["urgency"]}</span>
              </div>
            </form>
            <button phx-click="add_desire" class="mt-2 text-xs px-3 py-1.5 rounded bg-green-500/20 border border-green-500/30 text-green-400 hover:bg-green-500/30 transition-colors">+ Add Desire</button>
          </div>

          <%!-- Goals --%>
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h3 class="text-sm font-bold text-blue-400 mb-3">Goals</h3>
            <%= for {g, idx} <- Enum.with_index(@goals) do %>
              <div class="flex items-center gap-2 mb-2 p-2 bg-gray-800/60 rounded-lg">
                <div class="flex-1 text-xs text-gray-300 truncate">{g["goal"]}</div>
                <span class="text-[10px] text-gray-500">p:{g["priority"]}</span>
                <button phx-click="remove_goal" phx-value-index={idx} class="text-gray-600 hover:text-red-400">
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            <% end %>
            <form phx-change="update_goal_draft" class="space-y-2">
              <input type="text" name="goal" value={@goal_draft["goal"]} placeholder="Goal description"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-blue-500"/>
              <input type="text" name="current_step" value={@goal_draft["current_step"]} placeholder="Current step / next action"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-blue-500"/>
              <div class="flex items-center gap-2">
                <input type="range" min="0" max="100" name="priority" value={@goal_draft["priority"]} class="flex-1 accent-blue-500"/>
                <span class="text-xs text-gray-400 w-14">priority {@goal_draft["priority"]}</span>
              </div>
            </form>
            <button phx-click="add_goal" class="mt-2 text-xs px-3 py-1.5 rounded bg-blue-500/20 border border-blue-500/30 text-blue-400 hover:bg-blue-500/30 transition-colors">+ Add Goal</button>
          </div>
        </div>

        <%!-- STEP 6: Backstory State --%>
        <div :if={@step == 6} class="space-y-5">
          <%!-- Grief Arcs --%>
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h3 class="text-sm font-bold text-indigo-400 mb-3">Grief Arcs</h3>
            <%= for {ga, idx} <- Enum.with_index(@grief_arcs) do %>
              <div class="flex items-center gap-2 mb-2 p-2 bg-gray-800/60 rounded-lg">
                <div class="flex-1 text-xs text-gray-300 truncate">Grieving: {ga["subject"]}</div>
                <span class="text-[10px] text-gray-500">{ga["stage"]}</span>
                <button phx-click="remove_grief_arc" phx-value-index={idx} class="text-gray-600 hover:text-red-400">
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            <% end %>
            <form phx-change="update_grief_draft" class="space-y-2">
              <input type="text" name="subject" value={@grief_draft["subject"]} placeholder="Subject of grief (e.g. their sister)"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-indigo-500"/>
              <div class="grid grid-cols-2 gap-2">
                <select name="loss_type" class="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-indigo-500">
                  <%= for lt <- ~w(person role belief home ability) do %>
                    <option value={lt} selected={@grief_draft["loss_type"] == lt}>{String.capitalize(lt)}</option>
                  <% end %>
                </select>
                <select name="stage" class="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-indigo-500">
                  <%= for s <- ~w(denial anger bargaining depression integration) do %>
                    <option value={s} selected={@grief_draft["stage"] == s}>{String.capitalize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="flex items-center gap-2">
                <input type="range" min="0" max="100" name="intensity" value={@grief_draft["intensity"]} class="flex-1 accent-indigo-500"/>
                <span class="text-xs text-gray-400 w-14">intensity {@grief_draft["intensity"]}</span>
              </div>
            </form>
            <button phx-click="add_grief_arc" class="mt-2 text-xs px-3 py-1.5 rounded bg-indigo-500/20 border border-indigo-500/30 text-indigo-400 hover:bg-indigo-500/30 transition-colors">+ Add Grief Arc</button>
          </div>

          <%!-- Forgiveness Arcs --%>
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h3 class="text-sm font-bold text-rose-400 mb-3">Forgiveness Arcs</h3>
            <%= for {fa, idx} <- Enum.with_index(@forgiveness_arcs) do %>
              <div class="flex items-center gap-2 mb-2 p-2 bg-gray-800/60 rounded-lg">
                <div class="flex-1 text-xs text-gray-300 truncate">{fa["wound_description"]}</div>
                <span class="text-[10px] text-gray-500">{fa["stage"]}</span>
                <button phx-click="remove_forgiveness_arc" phx-value-index={idx} class="text-gray-600 hover:text-red-400">
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            <% end %>
            <form phx-change="update_forgiveness_draft" class="space-y-2">
              <textarea name="wound_description" rows="2" placeholder="Wound description"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-rose-500">{@forgiveness_draft["wound_description"]}</textarea>
              <div class="grid grid-cols-2 gap-2">
                <select name="stage" class="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-rose-500">
                  <%= for s <- ~w(fresh festering processing forgiven hardened) do %>
                    <option value={s} selected={@forgiveness_draft["stage"] == s}>{String.capitalize(s)}</option>
                  <% end %>
                </select>
                <select name="direction" class="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-rose-500">
                  <option value="healing" selected={@forgiveness_draft["direction"] == "healing"}>Healing</option>
                  <option value="hardening" selected={@forgiveness_draft["direction"] == "hardening"}>Hardening</option>
                  <option value="neutral" selected={@forgiveness_draft["direction"] == "neutral"}>Neutral</option>
                </select>
              </div>
            </form>
            <button phx-click="add_forgiveness_arc" class="mt-2 text-xs px-3 py-1.5 rounded bg-rose-500/20 border border-rose-500/30 text-rose-400 hover:bg-rose-500/30 transition-colors">+ Add Forgiveness Arc</button>
          </div>

          <%!-- Theory of Mind --%>
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h3 class="text-sm font-bold text-cyan-400 mb-3">Theory of Mind Seed Entries</h3>
            <p class="text-[10px] text-gray-500 mb-3">What does this NPC already believe about the player character?</p>
            <%= for {entry, idx} <- Enum.with_index(@tom_entries) do %>
              <div class="flex items-center gap-2 mb-2 p-2 bg-gray-800/60 rounded-lg">
                <div class="flex-1 text-xs text-gray-300 truncate">{entry["known_fact"]}</div>
                <span class="text-[10px] text-gray-500">{entry["certainty"]}%</span>
                <button phx-click="remove_tom_entry" phx-value-index={idx} class="text-gray-600 hover:text-red-400">
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            <% end %>
            <form phx-change="update_tom_draft" class="space-y-2">
              <input type="text" name="known_fact" value={@tom_draft["known_fact"]} placeholder="Known fact about the player"
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-100 focus:outline-none focus:border-cyan-500"/>
              <div class="flex items-center gap-3">
                <input type="range" min="0" max="100" name="certainty" value={@tom_draft["certainty"]} class="flex-1 accent-cyan-500"/>
                <span class="text-xs text-gray-400 w-20">certainty {Map.get(@tom_draft, "certainty", 70)}%</span>
                <label class="flex items-center gap-1.5 text-xs text-gray-400">
                  <input type="checkbox" name="is_assumption" value="true"
                    checked={Map.get(@tom_draft, "is_assumption", true)}
                    class="accent-cyan-500"/>
                  Assumption
                </label>
              </div>
            </form>
            <button phx-click="add_tom_entry" class="mt-2 text-xs px-3 py-1.5 rounded bg-cyan-500/20 border border-cyan-500/30 text-cyan-400 hover:bg-cyan-500/30 transition-colors">+ Add Entry</button>
          </div>
        </div>

        <%!-- STEP 7: Physical & Social --%>
        <div :if={@step == 7} class="space-y-5">
          <div class="p-5 rounded-xl border border-gray-800 bg-gray-900">
            <h2 class="text-base font-bold text-amber-400 mb-4">Step 7 — Physical & Social</h2>
            <form phx-change="update_stamina" class="space-y-4">
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Social Stamina — {@social_stamina}</label>
                <input type="range" name="social_stamina" min="0" max="100" value={@social_stamina} class="w-full accent-blue-500"/>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Max Stamina — {@stamina_max}</label>
                <input type="range" name="stamina_max" min="10" max="200" value={@stamina_max} class="w-full accent-blue-500"/>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Stamina Regen Rate — {@stamina_regen_rate}/hr</label>
                <input type="range" name="stamina_regen_rate" min="0" max="50" value={@stamina_regen_rate} class="w-full accent-green-500"/>
              </div>
              <div class="pt-4 border-t border-gray-800">
                <h3 class="text-xs font-bold text-gray-400 mb-3 uppercase tracking-wide">Somatic State</h3>
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-[10px] text-gray-500 mb-1">Hunger — {@hunger}</label>
                    <input type="range" name="hunger" min="0" max="100" value={@hunger} class="w-full accent-orange-500"/>
                  </div>
                  <div>
                    <label class="block text-[10px] text-gray-500 mb-1">Pain — {@pain}</label>
                    <input type="range" name="pain" min="0" max="100" value={@pain} class="w-full accent-red-500"/>
                  </div>
                  <div>
                    <label class="block text-[10px] text-gray-500 mb-1">Fatigue — {@fatigue}</label>
                    <input type="range" name="fatigue" min="0" max="100" value={@fatigue} class="w-full accent-purple-500"/>
                  </div>
                  <div>
                    <label class="block text-[10px] text-gray-500 mb-1">Illness — {@illness_severity}</label>
                    <input type="range" name="illness_severity" min="0" max="100" value={@illness_severity} class="w-full accent-yellow-500"/>
                  </div>
                </div>
              </div>
            </form>

            <div class="mt-5 p-4 rounded-lg bg-gray-800/60 border border-gray-700">
              <div class="text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wide">Summary</div>
              <div class="text-sm text-gray-100 font-bold">{@name}</div>
              <div class="text-xs text-gray-500 font-mono">{@slug}</div>
              <div class="flex gap-2 mt-2 flex-wrap">
                <span class="text-[10px] px-2 py-0.5 rounded bg-amber-500/20 text-amber-300">{@kind}</span>
                <span class="text-[10px] px-2 py-0.5 rounded bg-gray-700 text-gray-400">{@attachment_style}</span>
                <span class="text-[10px] px-2 py-0.5 rounded bg-gray-700 text-gray-400">humor: {@humor_style}</span>
                <span class="text-[10px] px-2 py-0.5 rounded bg-gray-700 text-gray-400">{length(@beliefs)} belief(s)</span>
                <span class="text-[10px] px-2 py-0.5 rounded bg-gray-700 text-gray-400">{length(@goals)} goal(s)</span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Navigation footer --%>
        <div class="flex items-center justify-between mt-6 pt-4 border-t border-gray-800">
          <button
            :if={@step > 1}
            phx-click="prev_step"
            class="px-4 py-2 rounded-lg bg-gray-800 border border-gray-700 text-gray-300 text-sm hover:bg-gray-700 transition-colors"
          >
            Back
          </button>
          <div :if={@step == 1}></div>

          <%= if @step < @total_steps do %>
            <button
              phx-click="next_step"
              class="px-5 py-2 rounded-lg bg-amber-500/20 border border-amber-500/40 text-amber-300 text-sm font-semibold hover:bg-amber-500/30 transition-colors"
            >
              Next
            </button>
          <% else %>
            <button
              phx-click="create_npc"
              class="px-6 py-2 rounded-lg bg-amber-500 text-gray-950 text-sm font-bold hover:bg-amber-400 transition-colors"
            >
              Create NPC
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp secret_risk_class("critical"), do: "bg-red-900/40 text-red-400 border-red-800/50"
  defp secret_risk_class("high"), do: "bg-orange-900/40 text-orange-400 border-orange-800/50"
  defp secret_risk_class("medium"), do: "bg-yellow-900/30 text-yellow-500 border-yellow-800/50"
  defp secret_risk_class(_), do: "bg-gray-800/60 text-gray-500 border-gray-700"
end
