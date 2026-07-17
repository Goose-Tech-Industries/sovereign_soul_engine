defmodule SovereignSoulEngine.Souls.EmotionalContagion do
  @moduledoc """
  Detects tone from player messages and applies emotional contagion to NPC emotional states.
  """

  @positive_words ~w(thank love help glad safe good kind wonderful appreciate grateful happy)
  @negative_words ~w(angry hate kill betray leave wrong terrible awful bad stupid worthless)
  @distressed_words ~w(please help scared afraid dying hurt pain desperate crying scared)

  @doc """
  Detects the emotional tone of a message string.
  Returns :positive | :negative | :neutral | :distressed
  """
  def detect_tone(nil), do: :neutral
  def detect_tone(""), do: :neutral

  def detect_tone(content) when is_binary(content) do
    lower = String.downcase(content)
    words = String.split(lower, ~r/\W+/, trim: true)

    positive_count = Enum.count(words, &(&1 in @positive_words))
    negative_count = Enum.count(words, &(&1 in @negative_words))
    distressed_count = Enum.count(words, &(&1 in @distressed_words))

    cond do
      distressed_count >= 2 -> :distressed
      distressed_count > 0 and negative_count > 0 -> :distressed
      positive_count > negative_count -> :positive
      negative_count > positive_count -> :negative
      true -> :neutral
    end
  end

  @doc """
  Applies emotional contagion deltas based on tone and susceptibility (0-100).
  Returns a delta map for emotion fields.
  Avoidant attachment style halves contagion. Anxious doubles it.
  """
  def apply_contagion(_emotional_state, tone, susceptibility, attachment_style \\ "secure") do
    base_deltas = base_deltas_for_tone(tone, susceptibility)
    apply_attachment_modifier(base_deltas, attachment_style)
  end

  defp base_deltas_for_tone(:positive, susceptibility) when susceptibility > 40 do
    %{stress: -2, anger: -1, gratitude: 2}
  end

  defp base_deltas_for_tone(:negative, susceptibility) when susceptibility > 40 do
    %{stress: 3, anger: 2}
  end

  defp base_deltas_for_tone(:distressed, susceptibility) when susceptibility > 50 do
    %{fear: 3, stress: 4, sadness: 2}
  end

  defp base_deltas_for_tone(_, _), do: %{}

  defp apply_attachment_modifier(deltas, "avoidant") when map_size(deltas) > 0 do
    Map.new(deltas, fn {k, v} -> {k, div(v, 2)} end)
  end

  defp apply_attachment_modifier(deltas, "anxious") when map_size(deltas) > 0 do
    Map.new(deltas, fn {k, v} -> {k, v * 2} end)
  end

  defp apply_attachment_modifier(deltas, _), do: deltas

  @doc """
  Returns a human-readable description of the contagion effect for prompt injection.
  """
  def describe_contagion(:neutral, _), do: nil
  def describe_contagion(_, deltas) when map_size(deltas) == 0, do: nil

  def describe_contagion(tone, _deltas) do
    tone_word = case tone do
      :positive -> "warm"
      :negative -> "hostile"
      :distressed -> "distressed"
      _ -> "neutral"
    end
    "The player's #{tone_word} tone has subtly affected your emotional state."
  end
end
