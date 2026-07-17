defmodule SovereignSoulEngine.Relationships.RelationshipEngine do
  @moduledoc """
  Deterministic engine for resolving directional relationship changes from soul events.

  Pure functions — never calls an LLM. All deltas are clamped, modified by
  personality traits, event intensity, repetition, and existing wounds.

  Relationship dimensions have varying ranges:
    - affinity: -100..100
    - trust, respect, fear, anger, gratitude, debt, softening, hardening, wound: 0..100
  """

  @dimensions ~w(affinity trust respect fear anger gratitude debt softening hardening wound)a

  @dimension_ranges %{
    affinity: {-100, 100},
    trust: {0, 100},
    respect: {0, 100},
    fear: {0, 100},
    anger: {0, 100},
    gratitude: {0, 100},
    debt: {0, 100},
    softening: {0, 100},
    hardening: {0, 100},
    wound: {0, 100}
  }

  @event_types ~w(
    ally_saved_me healed_me attacked_me gave_item trained_me
    betrayed_me insulted_me praised_me apologized_to_me threatened_me
    protected_me abandoned_me shared_secret lied_to_me
  )a

  @default_intensity 50

  @harmful_events ~w(betrayed_me attacked_me insulted_me threatened_me abandoned_me lied_to_me)a

  @delta_rules %{
    ally_saved_me: %{
      trust: 8,
      respect: 10,
      gratitude: 14,
      softening: 5,
      affinity: 8,
      anger: -4,
      hardening: -3
    },
    healed_me: %{
      trust: 5,
      respect: 3,
      gratitude: 12,
      softening: 3,
      affinity: 5,
      anger: -2
    },
    attacked_me: %{
      anger: 20,
      fear: 10,
      trust: -20,
      respect: -15,
      affinity: -20,
      hardening: 15,
      softening: -5
    },
    gave_item: %{
      gratitude: 8,
      affinity: 5,
      debt: 5
    },
    trained_me: %{
      respect: 10,
      trust: 5,
      gratitude: 8,
      affinity: 8,
      debt: 5
    },
    betrayed_me: %{
      trust: -35,
      respect: -20,
      anger: 30,
      hardening: 20,
      wound: 25,
      affinity: -30,
      fear: 10,
      gratitude: -10,
      softening: -15
    },
    insulted_me: %{
      anger: 15,
      affinity: -10,
      respect: -10,
      hardening: 10,
      trust: -5,
      softening: -5
    },
    praised_me: %{
      affinity: 10,
      respect: 5,
      trust: 5,
      gratitude: 5,
      softening: 3,
      anger: -3
    },
    apologized_to_me: %{
      anger: -12,
      trust: 8,
      respect: 5,
      affinity: 8,
      gratitude: 5,
      hardening: -5,
      wound: -5
    },
    threatened_me: %{
      fear: 20,
      anger: 10,
      trust: -15,
      affinity: -15,
      hardening: 10,
      softening: -5
    },
    protected_me: %{
      trust: 10,
      respect: 8,
      gratitude: 15,
      softening: 5,
      affinity: 10,
      fear: -5
    },
    abandoned_me: %{
      anger: 20,
      trust: -25,
      respect: -15,
      affinity: -25,
      hardening: 15,
      wound: 20,
      gratitude: -10,
      softening: -10
    },
    shared_secret: %{
      trust: 15,
      affinity: 10,
      gratitude: 5,
      softening: 5
    },
    lied_to_me: %{
      trust: -20,
      anger: 15,
      respect: -10,
      affinity: -15,
      hardening: 10,
      wound: 10
    }
  }

  @doc """
  Processes a soul event and returns updated relationship state.

  Accepts a keyword list of options:
    - `:intensity` — event intensity 0..100 (default: 50)
    - `:personality_modifiers` — map of dimension => float multiplier (default: 1.0 each)
    - `:existing_wounds` — wound level 0..100 that amplifies negative changes (default: 0)
    - `:repetition_count` — how many times this event type has occurred before (default: 0)

  Returns `{:ok, updated_state, deltas}` or `{:error, reason}`.
  """
  @spec process_event(
          current_state :: map(),
          event_type :: atom(),
          opts :: keyword()
        ) :: {:ok, map(), map()} | {:error, String.t()}
  def process_event(current_state, event_type, opts \\ []) when is_atom(event_type) do
    with {:ok, intensity} <- validate_intensity(opts),
         {:ok, rules} <- validate_event_type(event_type) do
      personality = Keyword.get(opts, :personality_modifiers, %{})
      existing_wounds = Keyword.get(opts, :existing_wounds, 0)
      repetition_count = Keyword.get(opts, :repetition_count, 0)
      attachment_style = Keyword.get(opts, :attachment_style, "secure")

      intensity_factor = intensity / @default_intensity
      repetition_factor = 1.0 / (1.0 + 0.2 * repetition_count)
      wound_factor = 1.0 + existing_wounds / 200.0

      dims = ensure_dimensions(current_state)

      harmful? = event_type in @harmful_events

      deltas =
        rules
        |> Enum.map(fn {dim, base_delta} ->
          mod = Map.get(personality, dim, 1.0)
          effective = base_delta * intensity_factor * mod * repetition_factor

          effective =
            if harmful? do
              effective * wound_factor
            else
              effective
            end

          {dim, effective}
        end)
        |> Map.new()

      updated =
        dims
        |> Enum.map(fn {dim, val} ->
          delta = Map.get(deltas, dim, 0.0)
          new_val = val + delta
          {min_r, max_r} = Map.get(@dimension_ranges, dim)
          clamped = clamp_value(round(new_val), min_r, max_r)
          {dim, clamped}
        end)
        |> Map.new()

      # Apply attachment style modifier to trust changes
      updated = apply_attachment_modifier(updated, dims, attachment_style)

      clamped_deltas =
        dims
        |> Enum.map(fn {dim, val} ->
          {dim, Map.get(updated, dim) - val}
        end)
        |> Map.new()

      {:ok, updated, clamped_deltas}
    end
  end

  @doc """
  Adjusts relationship trust changes based on the NPC's attachment style.

  - avoidant: cap trust at 65, slow trust growth (×0.6), slight hardening when trust > 55
  - anxious: trust builds 1.4× faster and collapses 1.4× faster
  - disorganized: trust and fear can both be high; adds ±10 random variance
  - secure: no modification

  Takes the proposed updated state, original dims (for delta calculation), and
  attachment_style string. Returns the adjusted updated state.
  """
  @spec attachment_modifier(map(), map(), String.t()) :: map()
  def attachment_modifier(updated, original_dims, attachment_style) do
    apply_attachment_modifier(updated, original_dims, attachment_style)
  end

  defp apply_attachment_modifier(updated, original_dims, "avoidant") do
    orig_trust = Map.get(original_dims, :trust, 0)
    new_trust = Map.get(updated, :trust, 0)
    trust_delta = new_trust - orig_trust

    # Cap trust at 65 max
    capped_trust = min(new_trust, 65)

    # Slow trust growth by ×0.6 for positive deltas
    adjusted_trust =
      if trust_delta > 0 do
        adjusted = round(orig_trust + trust_delta * 0.6)
        min(adjusted, 65)
      else
        capped_trust
      end

    # When trust is above 55, add slight hardening
    updated = Map.put(updated, :trust, adjusted_trust)

    if adjusted_trust > 55 do
      current_hardening = Map.get(updated, :hardening, 0)
      {_min_r, max_r} = Map.get(@dimension_ranges, :hardening)
      Map.put(updated, :hardening, min(current_hardening + 2, max_r))
    else
      updated
    end
  end

  defp apply_attachment_modifier(updated, original_dims, "anxious") do
    orig_trust = Map.get(original_dims, :trust, 0)
    new_trust = Map.get(updated, :trust, 0)
    trust_delta = new_trust - orig_trust

    adjusted_trust =
      if trust_delta != 0 do
        adjusted = round(orig_trust + trust_delta * 1.4)
        {min_r, max_r} = Map.get(@dimension_ranges, :trust)
        clamp_value(adjusted, min_r, max_r)
      else
        new_trust
      end

    Map.put(updated, :trust, adjusted_trust)
  end

  defp apply_attachment_modifier(updated, _original_dims, "disorganized") do
    variance = :rand.uniform(21) - 11
    current_trust = Map.get(updated, :trust, 0)
    {min_r, max_r} = Map.get(@dimension_ranges, :trust)
    Map.put(updated, :trust, clamp_value(current_trust + variance, min_r, max_r))
  end

  defp apply_attachment_modifier(updated, _original_dims, _secure), do: updated

  defp validate_intensity(opts) do
    intensity = Keyword.get(opts, :intensity, @default_intensity)

    if is_number(intensity) and intensity >= 0 and intensity <= 100 do
      {:ok, intensity + 0.0}
    else
      {:error, "intensity must be a number between 0 and 100, got: #{inspect(intensity)}"}
    end
  end

  defp validate_event_type(event_type) do
    if event_type in @event_types do
      {:ok, Map.get(@delta_rules, event_type)}
    else
      {:error, "unknown event_type: #{inspect(event_type)}"}
    end
  end

  defp ensure_dimensions(current_state) do
    Map.take(current_state, @dimensions)
    |> then(fn taken ->
      Enum.reduce(@dimensions, taken, fn dim, acc ->
        Map.put_new(acc, dim, 0)
      end)
    end)
  end

  defp clamp_value(val, min_r, max_r) do
    val |> max(min_r) |> min(max_r)
  end
end
