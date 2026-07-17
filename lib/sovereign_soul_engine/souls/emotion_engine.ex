defmodule SovereignSoulEngine.Souls.EmotionEngine do
  @moduledoc """
  Deterministic engine for resolving emotional state changes from soul events.

  Pure functions — never calls an LLM. All deltas are clamped, modified by
  personality traits, event intensity, repetition, and existing wounds.
  """

  @dimensions ~w(anger fear stress gratitude confidence sadness curiosity attachment shame guilt)a

  @event_types ~w(
    ally_saved_me healed_me attacked_me gave_item trained_me
    betrayed_me insulted_me praised_me apologized_to_me threatened_me
    protected_me abandoned_me shared_secret lied_to_me
  )a

  @min_val 0
  @max_val 100

  @default_intensity 50

  @harmful_events ~w(betrayed_me attacked_me insulted_me threatened_me abandoned_me lied_to_me)a

  # Events that trigger shame (I am bad) or guilt (I did bad)
  @shame_events ~w(betrayed_me abandoned_me)a
  @guilt_events ~w(insulted_me attacked_me lied_to_me threatened_me)a

  @delta_rules %{
    ally_saved_me: %{
      fear: -5,
      stress: -8,
      gratitude: 12,
      confidence: 8,
      sadness: -5,
      attachment: 10,
      guilt: -3,
      shame: -2
    },
    healed_me: %{fear: -3, stress: -5, gratitude: 10, sadness: -5, attachment: 8, confidence: 3},
    attacked_me: %{
      anger: 20,
      fear: 15,
      stress: 20,
      gratitude: -5,
      confidence: -10,
      sadness: 5,
      attachment: -5,
      shame: 8
    },
    gave_item: %{gratitude: 8, curiosity: 5, stress: -3},
    trained_me: %{confidence: 10, gratitude: 8, curiosity: 5, stress: -3, shame: -5},
    betrayed_me: %{
      anger: 25,
      fear: 10,
      stress: 15,
      sadness: 20,
      gratitude: -10,
      confidence: -15,
      attachment: -10,
      shame: 15
    },
    insulted_me: %{anger: 15, sadness: 10, stress: 10, confidence: -5, shame: 10},
    praised_me: %{
      confidence: 10,
      gratitude: 5,
      sadness: -5,
      stress: -3,
      anger: -3,
      shame: -8,
      guilt: -5
    },
    apologized_to_me: %{anger: -10, sadness: -5, gratitude: 5, stress: -5, guilt: 8},
    threatened_me: %{fear: 20, anger: 10, stress: 15, confidence: -10, shame: 5},
    protected_me: %{
      fear: -10,
      gratitude: 15,
      attachment: 10,
      confidence: 5,
      stress: -5,
      shame: -5
    },
    abandoned_me: %{
      sadness: 20,
      anger: 15,
      fear: 10,
      confidence: -10,
      attachment: -10,
      shame: 20
    },
    shared_secret: %{gratitude: 5, attachment: 10, curiosity: 5, guilt: 3},
    lied_to_me: %{anger: 10, sadness: 5, confidence: -5, gratitude: -5, guilt: 15}
  }

  @doc """
  Processes a soul event and returns updated emotional state.

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
          clamped = min(max(new_val |> round(), @min_val), @max_val)
          {dim, clamped}
        end)
        |> Map.new()

      clamped_deltas =
        dims
        |> Enum.map(fn {dim, val} ->
          {dim, Map.get(updated, dim) - val}
        end)
        |> Map.new()

      {:ok, updated, clamped_deltas}
    end
  end

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

  @doc """
  Moves each dimension in current_state 1-3 points toward the corresponding
  value in mood_baseline. Simulates mood settling over time.

  mood_baseline is a map of dimension => integer target value.
  Dimensions not in mood_baseline are left unchanged.

  Returns updated state map.
  """
  @spec drift_toward_baseline(current_state :: map(), mood_baseline :: map()) :: map()
  def drift_toward_baseline(current_state, mood_baseline) when is_map(mood_baseline) do
    dims = ensure_dimensions(current_state)

    Enum.reduce(dims, dims, fn {dim, current_val}, acc ->
      case Map.fetch(mood_baseline, dim) do
        {:ok, target} when is_integer(target) ->
          diff = target - current_val

          drift =
            cond do
              diff == 0 -> 0
              abs(diff) <= 1 -> diff
              abs(diff) <= 5 -> if diff > 0, do: 1, else: -1
              abs(diff) <= 20 -> if diff > 0, do: 2, else: -2
              true -> if diff > 0, do: 3, else: -3
            end

          Map.put(acc, dim, clamp(current_val + drift))

        _ ->
          acc
      end
    end)
  end

  @doc """
  If rumination_intensity > 50, adds a stress spike and returns a context hint.
  Takes the current state map and the rumination_intensity integer.

  Returns `{updated_state, rumination_context_string | nil}`.
  """
  @spec apply_rumination(current_state :: map(), rumination_intensity :: integer()) ::
          {map(), String.t() | nil}
  def apply_rumination(current_state, rumination_intensity)
      when is_integer(rumination_intensity) do
    if rumination_intensity > 50 do
      stress_spike = div(rumination_intensity, 10)
      dims = ensure_dimensions(current_state)
      current_stress = Map.get(dims, :stress, 0)
      updated = Map.put(dims, :stress, clamp(current_stress + stress_spike))

      context =
        "RUMINATION ACTIVE (intensity #{rumination_intensity}): Background stress elevated."

      {updated, context}
    else
      {ensure_dimensions(current_state), nil}
    end
  end

  defp clamp(val), do: min(max(val, @min_val), @max_val)

  # Expose dimension list for tests / external callers
  def dimensions, do: @dimensions
  def shame_events, do: @shame_events
  def guilt_events, do: @guilt_events

  @doc """
  Applies somatic (physical state) modifiers to an emotion delta map.
  Takes current emotional state map and somatic_state struct.
  Returns a delta map to be merged with other deltas.
  """
  def apply_somatic_modifiers(_emotional_state, nil), do: %{}

  def apply_somatic_modifiers(_emotional_state, somatic) do
    deltas = %{}

    deltas =
      cond do
        somatic.hunger > 80 ->
          Map.merge(deltas, %{anger: 10, stress: 8, confidence: -5})
        somatic.hunger > 60 ->
          Map.merge(deltas, %{anger: 5, stress: 3})
        true -> deltas
      end

    deltas =
      cond do
        somatic.pain > 80 ->
          Map.merge(deltas, %{stress: 15, confidence: -10})
        somatic.pain > 50 ->
          Map.merge(deltas, %{stress: 8, anger: 5, sadness: 3})
        true -> deltas
      end

    deltas =
      cond do
        somatic.fatigue > 80 ->
          current_negatives = %{anger: 5, fear: 5, stress: 5, sadness: 5, shame: 5, guilt: 5}
          Map.merge(deltas, Map.merge(current_negatives, %{confidence: -15}))
        somatic.fatigue > 60 ->
          Map.merge(deltas, %{confidence: -5, sadness: 3, stress: 5})
        true -> deltas
      end

    deltas =
      if somatic.illness_severity > 50 do
        Map.merge(deltas, %{fear: 5, stress: 8, sadness: 5})
      else
        deltas
      end

    deltas
  end
end
