defmodule SovereignSoulEngine.Souls.PTSDFlashback do
  @moduledoc """
  Involuntary Episodic PTSD Flashback Engine.
  Detects when ambient scene metadata, environmental cues, or spoken keywords
  resonate with deeply traumatic episodic memories (valence <= -0.7, intensity >= 70),
  triggering an autonomic regression where the character perceives the past as unfolding in the present.
  """

  alias SovereignSoulEngine.Memories.Memory

  @type t :: %__MODULE__{
          triggered?: boolean(),
          memory: Memory.t() | nil,
          trigger_cue: String.t() | nil,
          heart_rate_surge: integer(),
          stress_surge: integer(),
          prompt_directive: String.t()
        }

  defstruct triggered?: false,
            memory: nil,
            trigger_cue: nil,
            heart_rate_surge: 0,
            stress_surge: 0,
            prompt_directive: ""

  @doc """
  Evaluates whether an involuntary flashback is triggered by the current scene context or incoming dialogue.
  """
  @spec detect_flashback([Memory.t()], map(), String.t()) :: t()
  def detect_flashback(memories, scene_context \\ %{}, dialogue_content \\ "") do
    traumatic_memories =
      Enum.filter(memories, fn m ->
        m.status == "active" and
          (m.valence || 0.0) <= -0.7 and
          (m.emotional_intensity || 0) >= 70
      end)

    if traumatic_memories == [] do
      no_flashback()
    else
      search_text =
        String.downcase("#{dialogue_content} #{Map.get(scene_context, "mood", "")} #{Map.get(scene_context, "weather", "")} #{Map.get(scene_context, "narrative", "")}")

      case Enum.find_value(traumatic_memories, &match_memory_to_cues(&1, search_text)) do
        nil ->
          no_flashback()

        {memory, cue} ->
          surge_hr = min(175, 40 + div(memory.emotional_intensity, 2))
          surge_stress = min(100, 30 + div(memory.emotional_intensity, 3))

          %__MODULE__{
            triggered?: true,
            memory: memory,
            trigger_cue: cue,
            heart_rate_surge: surge_hr,
            stress_surge: surge_stress,
            prompt_directive: """
            ══════════════════════════════════════════════════════════════════
            INVOLUNTARY EPISODIC PTSD FLASHBACK ACTIVATED
            Trigger Cue: "#{cue}"
            Traumatic Memory Resurfaced: "#{memory.summary}"
            ══════════════════════════════════════════════════════════════════
            You have suffered an involuntary sensory flashback. You are no longer fully in the present room.
            For this turn, your perception is violently overwhelmed by the memory of "#{memory.summary}".
            You believe you are back in that moment of agony or betrayal.
            React with acute terror, physical recoil, or defensive panic toward whoever is near you.
            Your words must confuse the present speaker with the perpetrators or victims of your past trauma.
            """
          }
      end
    end
  end

  defp no_flashback do
    %__MODULE__{
      triggered?: false,
      memory: nil,
      trigger_cue: nil,
      heart_rate_surge: 0,
      stress_surge: 0,
      prompt_directive: ""
    }
  end

  defp match_memory_to_cues(memory, search_text) do
    tags = memory.tags || []
    summary_words =
      (memory.summary || "")
      |> String.downcase()
      |> String.split(~r/[^\w]+/, trim: true)
      |> Enum.filter(&(String.length(&1) >= 4))

    # Common visceral trauma cues that bridge past to present
    universal_trauma_cues = [
      "blood", "bleed", "blade", "knife", "poison", "fire", "burn", "locked",
      "dark", "shadow", "screaming", "betrayed", "trapped", "abandoned", "drown",
      "suffocate", "choke", "ruin", "corpse", "dead", "grave", "wound", "strike"
    ]

    all_cues = Enum.uniq(tags ++ summary_words ++ universal_trauma_cues)

    matched_cue =
      Enum.find(all_cues, fn cue ->
        String.contains?(search_text, String.downcase(cue))
      end)

    if matched_cue do
      {memory, matched_cue}
    else
      nil
    end
  end
end
