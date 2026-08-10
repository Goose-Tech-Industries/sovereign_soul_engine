defmodule SovereignSoulEngine.LLM.ProviderCascade do
  @moduledoc """
  Multi-provider cascade with automatic fallback.

  Attempts providers in the configured priority order:
    1. Anthropic (Claude)
    2. OpenAI (GPT)
    3. DeepSeek
    4. xAI (Grok)
    5. Google (Gemini)

  Each provider is tried in sequence. If one returns an error, times out,
  or produces unparseable output, the cascade moves to the next provider.

  All LLM output is validated against a strict JSON schema before being
  returned. Missing or invalid fields are replaced with safe defaults.
  """

  alias SovereignSoulEngine.LLM.Provider

  require Logger

  @default_providers [
    SovereignSoulEngine.LLM.AnthropicProvider,
    SovereignSoulEngine.LLM.OpenAIProvider,
    SovereignSoulEngine.LLM.DeepSeekProvider,
    SovereignSoulEngine.LLM.XAIProvider,
    SovereignSoulEngine.LLM.GeminiProvider
  ]

  @default_timeout_ms 30_000

  @provider_by_name Map.new(@default_providers, &{&1.provider_name(), &1})

  # ── Public API ───────────────────────────────────────────────

  @doc "Looks up a provider module by its `provider_name/0` (e.g. \"anthropic\") — used to resolve a tenant's BYOK choice."
  @spec provider_by_name(String.t()) :: module() | nil
  def provider_by_name(name), do: Map.get(@provider_by_name, name)

  @doc """
  Sends an LLM request through the cascade of providers.

  Falls back through providers on failure. Validates and sanitizes the
  response before returning.

  Options:
    - `:providers` — list of provider modules (defaults to the full cascade)
    - `:timeout_ms` — per-provider timeout in ms (default: 30_000)
    - `:tenant` — a `Tenants.Tenant` struct. If it has BYOK configured, the
      request goes ONLY to that tenant's own provider/key — never the
      operator's cascade, and never falls back to it on failure. A tenant's
      broken BYOK key should fail loudly for them to fix, not silently
      spend the operator's money on the fallback.
  """
  @spec respond(map(), keyword()) :: {:ok, Provider.provider_response()} | {:error, String.t()}
  def respond(input, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)

    case byok_provider(opts[:tenant]) do
      {:ok, provider_module, api_key} ->
        respond_via_provider(provider_module, input, timeout_ms, api_key: api_key)

      :not_configured ->
        providers = Keyword.get(opts, :providers, configured_providers())
        try_providers(providers, input, timeout_ms)
    end
  end

  defp byok_provider(nil), do: :not_configured
  defp byok_provider(tenant), do: SovereignSoulEngine.Tenants.resolve_byok(tenant)

  # Single-provider path for BYOK — deliberately not `try_providers/3`,
  # which cascades to other providers on failure. A tenant's BYOK failure
  # must surface to them, not silently spend the operator's own key.
  defp respond_via_provider(provider_module, input, timeout_ms, provider_opts) do
    case call_provider(provider_module, input, timeout_ms, provider_opts) do
      {:ok, raw} -> validate_and_sanitize(raw)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the configured list of provider modules.
  """
  @spec configured_providers() :: [module()]
  def configured_providers do
    Application.get_env(:sovereign_soul_engine, :llm_providers, @default_providers)
  end

  @doc """
  Checks health across all configured providers.
  """
  @spec health_all() :: %{String.t() => {:ok, map()} | {:error, String.t()}}
  def health_all do
    providers = configured_providers()

    Map.new(providers, fn provider ->
      name = provider.provider_name()
      {name, provider.health()}
    end)
  end

  # ── Cascade Logic ────────────────────────────────────────────

  defp try_providers([], _input, _timeout_ms) do
    Logger.error("LLM cascade exhausted: all providers failed")
    {:error, "cascade_exhausted: all providers failed"}
  end

  defp try_providers([provider | rest], input, timeout_ms) do
    provider_name = provider.provider_name()
    Logger.debug("LLM cascade: trying #{provider_name}")

    case call_provider(provider, input, timeout_ms, []) do
      {:ok, raw} ->
        case validate_and_sanitize(raw) do
          {:ok, sanitized} ->
            Logger.info("LLM cascade: #{provider_name} succeeded")
            {:ok, sanitized}

          {:error, reason} ->
            Logger.warning(
              "LLM cascade: #{provider_name} returned unvalidatable response: #{reason}"
            )

            try_providers(rest, input, timeout_ms)
        end

      {:error, reason} ->
        Logger.warning("LLM cascade: #{provider_name} failed: #{reason}")
        try_providers(rest, input, timeout_ms)
    end
  end

  defp call_provider(provider, input, timeout_ms, provider_opts) do
    task = Task.async(fn -> provider.respond(input, provider_opts) end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task) do
      {:ok, result} ->
        result

      nil ->
        Logger.warning("LLM cascade: #{provider.provider_name()} timed out after #{timeout_ms}ms")
        {:error, "timeout: provider did not respond within #{timeout_ms}ms"}
    end
  end

  # ── Validation & Sanitization ────────────────────────────────

  @required_string_fields [:public_speech, :private_thought, :tone, :motivation]
  @max_string_length 20_000

  @doc false
  @spec validate_and_sanitize(map()) :: {:ok, Provider.provider_response()} | {:error, String.t()}
  def validate_and_sanitize(raw) when is_map(raw) do
    result = %{
      public_speech: sanitize_string(raw[:public_speech] || raw["public_speech"]),
      private_thought: sanitize_string(raw[:private_thought] || raw["private_thought"]),
      tone: sanitize_string(raw[:tone] || raw["tone"]),
      motivation: sanitize_string(raw[:motivation] || raw["motivation"]),
      target_character_id:
        sanitize_target(raw[:target_character_id] || raw["target_character_id"]),
      proposed_action: sanitize_proposed_action(raw[:proposed_action] || raw["proposed_action"]),
      memory_candidates:
        sanitize_memory_candidates(raw[:memory_candidates] || raw["memory_candidates"]),
      relationship_signals:
        sanitize_relationship_signals(raw[:relationship_signals] || raw["relationship_signals"]),
      # Everything below here was previously discarded entirely — Generator's
      # prompt asks the LLM for all of it, but this function only ever
      # returned the 8 keys above, so every consumer of these fields in
      # Generator always saw nil. They have real, correct consumer logic
      # already; the bug was purely here.
      updated_description:
        sanitize_nullable_string(raw[:updated_description] || raw["updated_description"]),
      repressed_motive: sanitize_nullable_string(raw[:repressed_motive] || raw["repressed_motive"]),
      active_defense: sanitize_nullable_string(raw[:active_defense] || raw["active_defense"]),
      physical_tell: sanitize_nullable_string(raw[:physical_tell] || raw["physical_tell"]),
      shame_or_guilt: sanitize_nullable_string(raw[:shame_or_guilt] || raw["shame_or_guilt"]),
      # No consumer logic exists for this one yet (unlike everything else
      # here) — whitelisted so it round-trips instead of being silently
      # dropped, ready for whenever that gets built.
      moral_tension: sanitize_nullable_string(raw[:moral_tension] || raw["moral_tension"]),
      conversation_state: sanitize_nullable_string(raw[:conversation_state] || raw["conversation_state"]),
      rumination_update:
        sanitize_rumination_update(raw[:rumination_update] || raw["rumination_update"]),
      belief_challenge: sanitize_belief_challenge(raw[:belief_challenge] || raw["belief_challenge"]),
      desire_update: sanitize_desire_update(raw[:desire_update] || raw["desire_update"]),
      psychological_updates:
        sanitize_psychological_updates(raw[:psychological_updates] || raw["psychological_updates"]),
      knowledge_update: sanitize_knowledge_update(raw[:knowledge_update] || raw["knowledge_update"]),
      goal_update: sanitize_goal_update(raw[:goal_update] || raw["goal_update"]),
      grief_response: sanitize_grief_response(raw[:grief_response] || raw["grief_response"]),
      forgiveness_signal:
        sanitize_forgiveness_signal(raw[:forgiveness_signal] || raw["forgiveness_signal"])
    }

    missing =
      @required_string_fields
      |> Enum.filter(fn field ->
        is_nil(Map.get(result, field)) || Map.get(result, field) == ""
      end)

    if missing != [] do
      Logger.warning(
        "LLM response missing required fields: #{Enum.join(missing, ", ")}. Filling with defaults."
      )

      filled =
        Enum.reduce(missing, result, fn field, acc ->
          Map.put(acc, field, default_for_field(field))
        end)

      {:ok, filled}
    else
      {:ok, result}
    end
  end

  def validate_and_sanitize(_raw) do
    {:error, "validate_error: response is not a map"}
  end

  defp sanitize_string(nil), do: ""
  defp sanitize_string(str) when is_binary(str), do: String.slice(str, 0, @max_string_length)
  defp sanitize_string(_), do: ""

  # Unlike sanitize_string/1, preserves nil rather than collapsing it to "" —
  # every one of Generator's consumers for the fields below distinguishes
  # "no update" (nil) from "explicit empty" via `||` chains and `if x, do:`
  # guards. Collapsing nil to "" here would silently break that distinction
  # for currently-correct code, not just leave it dead.
  defp sanitize_nullable_string(nil), do: nil
  defp sanitize_nullable_string(str) when is_binary(str), do: String.slice(str, 0, @max_string_length)
  defp sanitize_nullable_string(_), do: nil

  defp sanitize_boolean(val) when is_boolean(val), do: val
  defp sanitize_boolean(_), do: true

  defp sanitize_target(nil), do: nil

  defp sanitize_target(str) when is_binary(str) do
    uuid_pattern = ~r/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i

    if String.match?(str, uuid_pattern) do
      String.downcase(str)
    end
  end

  defp sanitize_target(_), do: nil

  defp sanitize_proposed_action(nil), do: nil

  defp sanitize_proposed_action(action) when is_binary(action) do
    type = String.trim(action)
    if type == "" || type == "none" do
      nil
    else
      %{type: type, confidence: 1.0, reason: "Inferred from string response"}
    end
  end

  defp sanitize_proposed_action(%{} = action) when is_map(action) do
    type = sanitize_string(action[:type] || action["type"])
    reason = sanitize_string(action[:reason] || action["reason"])
    confidence = sanitize_confidence(action[:confidence] || action["confidence"])

    if type == "" do
      nil
    else
      %{type: type, confidence: confidence, reason: reason}
    end
  end

  defp sanitize_proposed_action(_), do: nil

  defp sanitize_confidence(nil), do: 0.0

  defp sanitize_confidence(val) when is_number(val) do
    val |> max(0.0) |> min(1.0) |> Float.round(4)
  end

  defp sanitize_confidence(_), do: 0.0

  defp sanitize_memory_candidates(nil), do: []
  defp sanitize_memory_candidates(list) when is_list(list), do: Enum.map(list, &sanitize_memory/1)
  defp sanitize_memory_candidates(_), do: []

  defp sanitize_memory(%{} = mem) when is_map(mem) do
    %{
      category: sanitize_string(mem[:category] || mem["category"]),
      summary: sanitize_string(mem[:summary] || mem["summary"]),
      importance:
        (mem[:importance] || mem["importance"] || 0)
        |> sanitize_integer()
        |> clamp(0, 100),
      emotional_intensity:
        (mem[:emotional_intensity] || mem["emotional_intensity"] || 0)
        |> sanitize_integer()
        |> clamp(0, 100),
      valence:
        (mem[:valence] || mem["valence"] || 0.0)
        |> sanitize_float()
        |> clamp_float(-1.0, 1.0),
      tags: sanitize_tags(mem[:tags] || mem["tags"])
    }
  end

  defp sanitize_memory(_), do: nil

  defp sanitize_tags(nil), do: []
  defp sanitize_tags(tags) when is_list(tags), do: Enum.map(tags, &sanitize_string/1)
  defp sanitize_tags(_), do: []

  defp sanitize_relationship_signals(nil), do: nil

  defp sanitize_relationship_signals(%{} = signals) when is_map(signals) do
    signals
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      key = if is_atom(k), do: Atom.to_string(k), else: to_string(k)
      Map.put(acc, key, sanitize_integer(v))
    end)
    |> case do
      empty when empty == %{} -> nil
      cleaned -> cleaned
    end
  end

  defp sanitize_relationship_signals(_), do: nil

  defp sanitize_rumination_update(nil), do: nil

  defp sanitize_rumination_update(%{} = m) do
    %{
      subject: sanitize_nullable_string(m[:subject] || m["subject"]),
      intensity:
        (m[:intensity] || m["intensity"] || 0)
        |> sanitize_integer()
        |> clamp(0, 100)
    }
  end

  defp sanitize_rumination_update(_), do: nil

  defp sanitize_belief_challenge(nil), do: nil

  defp sanitize_belief_challenge(%{} = m) do
    %{
      belief: sanitize_nullable_string(m[:belief] || m["belief"]),
      direction: sanitize_nullable_string(m[:direction] || m["direction"]),
      conviction_delta: sanitize_integer(m[:conviction_delta] || m["conviction_delta"] || 0)
    }
  end

  defp sanitize_belief_challenge(_), do: nil

  defp sanitize_desire_update(nil), do: nil

  defp sanitize_desire_update(%{} = m) do
    %{
      desire: sanitize_nullable_string(m[:desire] || m["desire"]),
      urgency_delta: sanitize_integer(m[:urgency_delta] || m["urgency_delta"] || 0)
    }
  end

  defp sanitize_desire_update(_), do: nil

  # acquired_fears always comes back as a real list (never nil) — Generator
  # reads `psych_updates[:acquired_fears] || ... || []` directly off this
  # value with no nil-guard on the outer map, matching that expectation.
  defp sanitize_psychological_updates(nil), do: %{acquired_fears: []}

  defp sanitize_psychological_updates(%{} = m) do
    %{acquired_fears: sanitize_tags(m[:acquired_fears] || m["acquired_fears"])}
  end

  defp sanitize_psychological_updates(_), do: %{acquired_fears: []}

  defp sanitize_knowledge_update(nil), do: nil

  defp sanitize_knowledge_update(%{} = m) do
    %{
      target_character: sanitize_nullable_string(m[:target_character] || m["target_character"]),
      fact: sanitize_nullable_string(m[:fact] || m["fact"]),
      certainty:
        (m[:certainty] || m["certainty"] || 70)
        |> sanitize_integer()
        |> clamp(0, 100),
      is_assumption: sanitize_boolean(m[:is_assumption] || m["is_assumption"])
    }
  end

  defp sanitize_knowledge_update(_), do: nil

  defp sanitize_goal_update(nil), do: nil

  defp sanitize_goal_update(%{} = m) do
    %{
      goal: sanitize_nullable_string(m[:goal] || m["goal"]),
      new_step: sanitize_nullable_string(m[:new_step] || m["new_step"]),
      blocker: sanitize_nullable_string(m[:blocker] || m["blocker"]),
      status: sanitize_nullable_string(m[:status] || m["status"])
    }
  end

  defp sanitize_goal_update(_), do: nil

  defp sanitize_grief_response(nil), do: nil

  defp sanitize_grief_response(%{} = m) do
    %{
      subject: sanitize_nullable_string(m[:subject] || m["subject"]),
      stage_shift: sanitize_nullable_string(m[:stage_shift] || m["stage_shift"]),
      intensity_delta: sanitize_integer(m[:intensity_delta] || m["intensity_delta"] || 0)
    }
  end

  defp sanitize_grief_response(_), do: nil

  defp sanitize_forgiveness_signal(nil), do: nil

  defp sanitize_forgiveness_signal(%{} = m) do
    %{
      wound: sanitize_nullable_string(m[:wound] || m["wound"]),
      direction_shift: sanitize_nullable_string(m[:direction_shift] || m["direction_shift"]),
      stage_shift: sanitize_nullable_string(m[:stage_shift] || m["stage_shift"])
    }
  end

  defp sanitize_forgiveness_signal(_), do: nil

  defp sanitize_integer(nil), do: 0
  defp sanitize_integer(val) when is_integer(val), do: val

  defp sanitize_integer(val) when is_float(val) do
    val |> Float.round() |> trunc()
  end

  defp sanitize_integer(_), do: 0

  defp sanitize_float(nil), do: 0.0
  defp sanitize_float(val) when is_float(val), do: Float.round(val, 4)
  defp sanitize_float(val) when is_integer(val), do: val / 1.0
  defp sanitize_float(_), do: 0.0

  defp clamp(val, min, _max) when val < min, do: min
  defp clamp(val, _min, max) when val > max, do: max
  defp clamp(val, _min, _max), do: val

  defp clamp_float(val, min, _max) when val < min, do: min
  defp clamp_float(val, _min, max) when val > max, do: max
  defp clamp_float(val, _min, _max), do: val

  defp default_for_field(:public_speech), do: "..."
  defp default_for_field(:private_thought), do: ""
  defp default_for_field(:tone), do: "neutral"
  defp default_for_field(:motivation), do: "unknown"
end
