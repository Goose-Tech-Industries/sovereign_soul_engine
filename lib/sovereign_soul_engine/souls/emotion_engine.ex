defmodule SovereignSoulEngine.Souls.EmotionEngine do
  @moduledoc """
  Deterministic engine for resolving emotional state changes from soul events.

  Pure functions — never calls an LLM. All deltas are clamped, modified by
  personality traits, event intensity, repetition, and existing wounds.
  """

  @dimensions ~w(anger fear stress gratitude confidence sadness curiosity attachment)a

  @event_types ~w(
    ally_saved_me healed_me attacked_me gave_item trained_me
    betrayed_me insulted_me praised_me apologized_to_me threatened_me
    protected_me abandoned_me shared_secret lied_to_me
  )a

  @min_val 0
  @max_val 100

  @default_intensity 50

  @harmful_events ~w(betrayed_me attacked_me insulted_me threatened_me abandoned_me lied_to_me)a

  @delta_rules %{
    ally_saved_me: %{
      fear: -5,
      stress: -8,
      gratitude: 12,
      confidence: 8,
      sadness: -5,
      attachment: 10
    },
    healed_me: %{fear: -3, stress: -5, gratitude: 10, sadness: -5, attachment: 8, confidence: 3},
    attacked_me: %{
      anger: 20,
      fear: 15,
      stress: 20,
      gratitude: -5,
      confidence: -10,
      sadness: 5,
      attachment: -5
    },
    gave_item: %{gratitude: 8, curiosity: 5, stress: -3},
    trained_me: %{confidence: 10, gratitude: 8, curiosity: 5, stress: -3},
    betrayed_me: %{
      anger: 25,
      fear: 10,
      stress: 15,
      sadness: 20,
      gratitude: -10,
      confidence: -15,
      attachment: -10
    },
    insulted_me: %{anger: 15, sadness: 10, stress: 10, confidence: -5},
    praised_me: %{confidence: 10, gratitude: 5, sadness: -5, stress: -3, anger: -3},
    apologized_to_me: %{anger: -10, sadness: -5, gratitude: 5, stress: -5},
    threatened_me: %{fear: 20, anger: 10, stress: 15, confidence: -10},
    protected_me: %{fear: -10, gratitude: 15, attachment: 10, confidence: 5, stress: -5},
    abandoned_me: %{
      sadness: 20,
      anger: 15,
      fear: 10,
      confidence: -10,
      attachment: -10
    },
    shared_secret: %{gratitude: 5, attachment: 10, curiosity: 5},
    lied_to_me: %{anger: 10, sadness: 5, confidence: -5, gratitude: -5}
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
end
