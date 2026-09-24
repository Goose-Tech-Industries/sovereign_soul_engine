defmodule SovereignSoulEngine.Safety.Grounding do
  @moduledoc """
  Opt-in, non-diagnostic grounding support for companion conversations.

  This module provides short present-moment prompts. It does not infer a
  diagnosis, evaluate clinical severity, confirm unusual beliefs, or replace a
  qualified human professional. Safety signals must be explicitly supplied by
  the user, a trusted adult, or an approved integration.
  """

  @danger_signals ~w(immediate_danger self_harm harm_to_others)
  @styles ~w(gentle direct sensory breathing)

  @type plan :: %{
          mode: :grounding,
          style: String.t(),
          steps: [String.t()],
          reality_anchor: String.t(),
          trusted_adult_required: boolean(),
          escalate: boolean(),
          escalation_message: String.t() | nil
        }

  @doc "Builds an opt-in grounding plan from explicit, non-diagnostic context."
  @spec plan(map()) :: {:ok, plan()} | {:error, :not_enabled}
  def plan(context) when is_map(context) do
    if enabled?(context) do
      style = normalize_style(Map.get(context, "style") || Map.get(context, :style))

      minor? =
        Map.get(context, "age_group") in ["child", "minor"] or
          Map.get(context, :age_group) in [:child, :minor, "child", "minor"]

      signal = Map.get(context, "safety_signal") || Map.get(context, :safety_signal)

      escalate? =
        signal in @danger_signals or
          signal in [:immediate_danger, :self_harm, :harm_to_others] or
          Map.get(context, "immediate_danger") == true or
          Map.get(context, :immediate_danger) == true

      {:ok,
       %{
         mode: :grounding,
         style: style,
         steps: steps(style),
         reality_anchor:
           reality_anchor(Map.get(context, "statement") || Map.get(context, :statement)),
         trusted_adult_required: minor?,
         escalate: escalate?,
         escalation_message: escalation_message(escalate?, minor?)
       }}
    else
      {:error, :not_enabled}
    end
  end

  def plan(_), do: {:error, :not_enabled}

  def enabled?(context),
    do:
      Map.get(context, "grounding_enabled") == true or
        Map.get(context, :grounding_enabled) == true

  def steps("sensory"),
    do: [
      "Name five things you can see.",
      "Name four things you can feel.",
      "Name three things you can hear.",
      "Name two things you can smell.",
      "Name one thing you can taste."
    ]

  def steps("breathing"),
    do: [
      "Put both feet on the floor.",
      "Breathe in gently.",
      "Breathe out slowly and let your shoulders drop.",
      "Repeat at your own pace."
    ]

  def steps("direct"),
    do: [
      "Pause.",
      "Look around and name where you are.",
      "Check the date and time.",
      "Choose one safe next step."
    ]

  def steps(_),
    do: [
      "Pause with me.",
      "Look around and name three things you can see.",
      "Feel your feet on the floor.",
      "Breathe out slowly.",
      "Tell me where you are and what safe next step you want."
    ]

  def reality_anchor(nil),
    do:
      "I am here with you. I cannot verify unusual perceptions from here, so let us check what is observable and present together."

  def reality_anchor(statement) when is_binary(statement) and byte_size(statement) > 0 do
    "I hear that this feels real and frightening. I cannot verify it from here. Let us check what is observable, where you are, and who you can contact for support."
  end

  def reality_anchor(_), do: reality_anchor(nil)

  defp normalize_style(style) when style in @styles, do: style
  defp normalize_style(style) when is_atom(style), do: normalize_style(Atom.to_string(style))
  defp normalize_style(_), do: "gentle"

  defp escalation_message(false, _), do: nil

  defp escalation_message(true, true),
    do:
      "Please involve a trusted adult now. If anyone may be in immediate danger, contact local emergency services."

  defp escalation_message(true, false),
    do:
      "Please contact a trusted person or qualified professional now. If anyone may be in immediate danger, contact local emergency services."
end
