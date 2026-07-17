defmodule SovereignSoulEngine.Souls.CognitiveLoad do
  @moduledoc """
  Computes cognitive load 0-100 from all active stressors.
  """

  @doc """
  Computes cognitive load from emotional state, somatic state, grief arcs, and active goals.
  Returns {score, stressors_list}.
  """
  def compute(emotional_state, somatic_state, grief_arcs, active_goals) do
    {stressors, score} = {[], 0}

    # Rumination
    {stressors, score} =
      if (emotional_state && emotional_state.rumination_intensity || 0) > 50 do
        subject = (emotional_state && emotional_state.rumination_subject) || "something"
        {["ruminating on: #{subject}" | stressors], score + 15}
      else
        {stressors, score}
      end

    # High stress emotion
    {stressors, score} =
      if (emotional_state && emotional_state.stress || 0) > 65 do
        {["high stress" | stressors], score + 10}
      else
        {stressors, score}
      end

    # Grief arcs
    intense_grief = Enum.filter(grief_arcs, &(&1.intensity > 60))

    {stressors, score} =
      if intense_grief != [] do
        {["grieving #{length(intense_grief)} loss(es)" | stressors],
         score + length(intense_grief) * 15}
      else
        {stressors, score}
      end

    # Physical pain/fatigue
    {stressors, score} =
      if somatic_state && (somatic_state.pain > 50 or somatic_state.fatigue > 70) do
        {["physical discomfort" | stressors], score + 10}
      else
        {stressors, score}
      end

    # Blocked goals
    blocked_goals = Enum.filter(active_goals, &(&1.blocker != nil and &1.priority > 60))

    {stressors, score} =
      if blocked_goals != [] do
        {["blocked on important goals" | stressors], score + 10}
      else
        {stressors, score}
      end

    {min(score, 100), stressors}
  end

  @doc "Returns prompt instruction based on cognitive load score."
  def prompt_instruction(score, stressors) when score >= 70 do
    stressor_text = Enum.join(stressors, ", ")

    """
    WARNING COGNITIVE LOAD: HIGH (#{score}/100) — You are mentally overwhelmed right now (#{stressor_text}).
    Your responses may be shorter than usual. You may lose the thread of a conversation.
    You are less patient. Small things irritate you more than they should.
    You might forget what was just said and need to re-ask. This is authentic — lean into it.
    """
  end

  def prompt_instruction(score, stressors) when score >= 45 do
    stressor_text = Enum.join(stressors, ", ")
    "COGNITIVE LOAD: MODERATE (#{score}/100) — You have a lot on your mind (#{stressor_text}). You are present but not fully focused."
  end

  def prompt_instruction(_, _), do: nil
end
