defmodule SovereignSoulEngine.Social.SocialDriftEngine do
  @moduledoc """
  Pure deterministic engine for passive NPC-to-NPC relationship drift.

  Drift happens without any conversation — just the slow pull of shared values,
  compatible personalities, and existing relationship history. Called by NPCScheduler
  on every tick for every NPC pair that has an existing relationship.

  Returns a map of dimension deltas that the caller applies to the relationship.
  """

  @value_compatibility_bonus 3
  @value_conflict_penalty -2
  @high_trust_anchor_bonus 1
  @wound_drag_penalty -2
  @max_passive_delta 5

  @doc """
  Computes passive drift deltas between two NPCs for one scheduler tick.

  Returns a map of `%{trust: delta, affinity: delta, anger: delta, ...}`.
  All deltas are small (±1-5). Caller is responsible for clamping and persisting.

  Inputs:
    - `profile_a` — SoulProfile for the initiating NPC
    - `profile_b` — SoulProfile for the target NPC
    - `relationship` — the existing Relationship struct (source=a, target=b)
  """
  @spec compute_drift(map(), map(), map()) :: map()
  def compute_drift(profile_a, profile_b, relationship) do
    compatibility = compute_compatibility(profile_a, profile_b)
    attachment_modifier = attachment_drift_modifier(profile_a.attachment_style)

    base_trust_delta =
      cond do
        compatibility > 0.5 -> 2
        compatibility > 0.2 -> 1
        compatibility < -0.3 -> -1
        compatibility < -0.6 -> -2
        true -> 0
      end

    base_affinity_delta =
      cond do
        compatibility > 0.6 -> 2
        compatibility > 0.3 -> 1
        compatibility < -0.4 -> -1
        true -> 0
      end

    wound_drag = if (relationship.wound || 0) > 50, do: @wound_drag_penalty, else: 0

    high_trust_anchor =
      if (relationship.trust || 0) > 70, do: @high_trust_anchor_bonus, else: 0

    trust_delta =
      clamp((base_trust_delta + wound_drag + high_trust_anchor) * attachment_modifier)

    affinity_delta = clamp((base_affinity_delta + wound_drag) * attachment_modifier)

    anger_delta =
      cond do
        (relationship.wound || 0) > 60 and compatibility < 0 -> 1
        (relationship.anger || 0) > 50 and compatibility > 0.4 -> -1
        true -> 0
      end

    %{
      trust: trust_delta,
      affinity: affinity_delta,
      anger: anger_delta
    }
  end

  @doc """
  Computes a compatibility score between two soul profiles.
  Range: -1.0 (deeply incompatible) to 1.0 (highly compatible).

  Based on: shared core values, shared fears (solidarity), belief domain overlap.
  """
  @spec compute_compatibility(map(), map()) :: float()
  def compute_compatibility(profile_a, profile_b) do
    values_a = MapSet.new(profile_a.core_values || [])
    values_b = MapSet.new(profile_b.core_values || [])
    fears_a = MapSet.new(profile_a.fears || [])
    fears_b = MapSet.new(profile_b.fears || [])

    shared_values = MapSet.intersection(values_a, values_b) |> MapSet.size()
    conflicting_values =
      (MapSet.difference(values_a, values_b) |> MapSet.size()) +
        (MapSet.difference(values_b, values_a) |> MapSet.size())

    shared_fears = MapSet.intersection(fears_a, fears_b) |> MapSet.size()

    raw_score =
      shared_values * @value_compatibility_bonus +
        conflicting_values * @value_conflict_penalty +
        shared_fears * 1

    max_possible = max(MapSet.size(values_a) + MapSet.size(values_b), 1) * @value_compatibility_bonus

    Float.round(raw_score / max_possible, 3)
  end

  @doc """
  Returns a compatibility description for logging and inspector display.
  """
  @spec describe_compatibility(float()) :: String.t()
  def describe_compatibility(score) when score > 0.6, do: "strongly compatible"
  def describe_compatibility(score) when score > 0.3, do: "compatible"
  def describe_compatibility(score) when score > -0.1, do: "neutral"
  def describe_compatibility(score) when score > -0.4, do: "friction"
  def describe_compatibility(_), do: "deeply incompatible"

  # Avoidant characters drift slower (harder to get close, harder to drift apart)
  # Anxious characters drift faster in both directions
  # Disorganized characters have erratic drift
  defp attachment_drift_modifier("anxious"), do: 1.4
  defp attachment_drift_modifier("avoidant"), do: 0.5
  defp attachment_drift_modifier("disorganized"), do: 1.2
  defp attachment_drift_modifier(_), do: 1.0

  defp clamp(val) when val > @max_passive_delta, do: @max_passive_delta
  defp clamp(val) when val < -@max_passive_delta, do: -@max_passive_delta
  defp clamp(val), do: round(val)
end
