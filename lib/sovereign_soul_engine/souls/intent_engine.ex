defmodule SovereignSoulEngine.Souls.IntentEngine do
  @moduledoc """
  Deterministic engine deciding an NPC's current *spatial* disposition —
  wander, idle, seek, or flee — from their emotional and somatic state.

  Pure function, never calls an LLM. This engine has no concept of maps,
  tiles, or pathfinding: it decides *why* an NPC would want to move right
  now, not *how*. A spatial system (e.g. carnage_v2's NpcRuntime) owns
  turning this into an actual step, using its own knowledge of terrain and
  nearby actors.

  Intents:
    * "flee"  — get away from whatever's nearby; something threatens them
    * "seek"  — move toward something they need (food, rest, company)
    * "wander" — move around with no fixed goal
    * "idle"  — stay put
  """

  @type intent :: %{intent: String.t(), reason: String.t()}

  @fear_flee_threshold 65
  @pain_idle_threshold 60
  @illness_idle_threshold 50
  @fatigue_idle_threshold 80
  @hunger_seek_threshold 70
  @stress_wander_ceiling 55
  @curiosity_wander_floor 55

  @doc """
  Decide the current intent from an emotional state and a somatic state
  (either may be nil — a soul without a somatic profile yet, for
  instance, just skips the somatic checks).
  """
  @spec decide(struct() | nil, struct() | nil) :: intent()
  def decide(emotional_state, somatic_state) do
    cond do
      threatened?(emotional_state) ->
        %{intent: "flee", reason: "overwhelmed by fear"}

      incapacitated?(somatic_state) ->
        %{intent: "idle", reason: incapacitation_reason(somatic_state)}

      hungry?(somatic_state) ->
        %{intent: "seek", reason: "hungry — looking for food"}

      distressed?(emotional_state) ->
        %{intent: "idle", reason: "too stressed to wander"}

      curious?(emotional_state) ->
        %{intent: "wander", reason: "curious and unbothered"}

      true ->
        %{intent: "wander", reason: "no strong pull either way"}
    end
  end

  defp threatened?(nil), do: false
  defp threatened?(%{fear: fear}), do: fear >= @fear_flee_threshold

  defp incapacitated?(nil), do: false

  defp incapacitated?(%{pain: pain, illness_severity: illness, fatigue: fatigue}) do
    pain >= @pain_idle_threshold or illness >= @illness_idle_threshold or
      fatigue >= @fatigue_idle_threshold
  end

  defp incapacitation_reason(%{pain: pain}) when pain >= @pain_idle_threshold, do: "in too much pain to move"

  defp incapacitation_reason(%{illness_severity: illness}) when illness >= @illness_idle_threshold,
    do: "too ill to move"

  defp incapacitation_reason(_), do: "too exhausted to move"

  defp hungry?(nil), do: false
  defp hungry?(%{hunger: hunger}), do: hunger >= @hunger_seek_threshold

  defp distressed?(nil), do: false
  defp distressed?(%{stress: stress}), do: stress > @stress_wander_ceiling

  defp curious?(nil), do: false

  defp curious?(%{curiosity: curiosity, stress: stress}) do
    curiosity >= @curiosity_wander_floor and stress <= @stress_wander_ceiling
  end
end
