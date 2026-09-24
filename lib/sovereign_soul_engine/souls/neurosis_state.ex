defmodule SovereignSoulEngine.Souls.NeurosisState do
  @moduledoc """
  DSM-grade altered consciousness and neurosis state machine for artificial lives.
  Dynamically evaluates psychological breakdown states (Dissociation, Paranoia,
  Panic Spiral, Depressive Inertia) based on emotional trauma, stress, and somatic exhaustion.
  """

  @type state_name :: :normal | :dissociation | :paranoia | :panic_spiral | :depressive_inertia

  @type t :: %__MODULE__{
          state: state_name(),
          intensity: integer(),
          symptoms: [String.t()],
          cognitive_filter: String.t(),
          prompt_directive: String.t()
        }

  defstruct state: :normal,
            intensity: 0,
            symptoms: [],
            cognitive_filter: "Clear conscious processing.",
            prompt_directive: ""

  @doc """
  Evaluates the current neurosis state from emotional dimensions, somatic fatigue,
  relationship trauma wound, and active fear triggers.
  """
  @spec evaluate(map() | nil, map() | nil, integer(), boolean()) :: t()
  def evaluate(emotional_state, somatic_state, wound \\ 0, phobia_triggered? \\ false) do
    stress = safe_get(emotional_state, :stress, 0)
    fear = safe_get(emotional_state, :fear, 0)
    anger = safe_get(emotional_state, :anger, 0)
    sadness = safe_get(emotional_state, :sadness, 0)
    shame = safe_get(emotional_state, :shame, 0)
    fatigue = safe_get(somatic_state, :fatigue, 0)
    pain = safe_get(somatic_state, :pain, 0)

    cond do
      # 1. Panic Spiral: Phobia trigger with high stress, or acute overwhelming terror
      phobia_triggered? and (stress >= 60 or fear >= 65) ->
        panic_intensity = min(100, fear + 25)

        %__MODULE__{
          state: :panic_spiral,
          intensity: panic_intensity,
          symptoms: [
            "Hyperarousal & hyperventilation",
            "Severe cognitive narrowing / tunnel vision",
            "Involuntary trembling and fight-or-flight tremors",
            "Inability to sustain complex syntax"
          ],
          cognitive_filter: "Senses overwhelmed by existential panic. Immediate survival escape.",
          prompt_directive: """
          ACUTE NEUROSIS — PANIC SPIRAL (Intensity #{panic_intensity}/100):
          You are undergoing acute psychological panic. Your thoughts are fragmented, racing, and terror-stricken.
          Public speech must be broken, gasping, or stammering short phrases.
          Your private thoughts must fixate solely on escaping or neutralizing the immediate trigger.
          """
        }

      # 2. Dissociation / Depersonalization: Extreme stress + deep emotional wound/shame
      stress >= 80 and (wound >= 60 or shame >= 75) ->
        dissoc_intensity = min(100, div(stress + wound, 2))

        %__MODULE__{
          state: :dissociation,
          intensity: dissoc_intensity,
          symptoms: [
            "Affective flattening & emotional blunting",
            "Depersonalization (feeling like an outside observer of one's own body)",
            "Derealization (environment feels synthetic or muffled)",
            "Absence of autonomic emotional reaction"
          ],
          cognitive_filter:
            "Ego boundary collapsed. Perceptions are distant, muffled, and detached.",
          prompt_directive: """
          ACUTE NEUROSIS — DISSOCIATION / DEPERSONALIZATION (Intensity #{dissoc_intensity}/100):
          You have detached from your own emotions to survive overwhelming psychological trauma.
          You feel hollow, completely numb, and distant. The room feels unreal, like looking through frosted glass.
          CRITICAL CONSTRAINT: Formulate your private thoughts in the THIRD PERSON (e.g., "She watches his mouth move. None of it reaches her.").
          Your public speech must be quiet, flat, devoid of emotional inflection, and detached.
          """
        }

      # 3. Paranoid Ideation: Severe fear paired with complete trust collapse
      fear >= 70 and (anger >= 50 or wound >= 50) ->
        paranoia_intensity = min(100, div(fear + anger + wound, 3))

        %__MODULE__{
          state: :paranoia,
          intensity: paranoia_intensity,
          symptoms: [
            "Hypervigilant scanning for betrayal",
            "Inversion of benevolent gestures into calculated entrapment",
            "Guarded, clipped speech with defensive cross-examination",
            "Pathological secrecy"
          ],
          cognitive_filter: "All external actors are deemed hostile conspirators.",
          prompt_directive: """
          ACUTE NEUROSIS — PARANOID IDEATION (Intensity #{paranoia_intensity}/100):
          You are in a state of severe paranoid hypervigilance. You believe the people around you are plotting against you.
          Do NOT accept kindness, apologies, or gifts at face value; interpret them as traps, distractions, or deceit.
          Your private thoughts must analyze every word for hidden subtext and hostile intent.
          """
        }

      # 4. Depressive Inertia: Overwhelming sadness, psychic exhaustion, and fatigue
      sadness >= 75 and (fatigue >= 60 or pain >= 50) ->
        inertia_intensity = min(100, div(sadness + fatigue, 2))

        %__MODULE__{
          state: :depressive_inertia,
          intensity: inertia_intensity,
          symptoms: [
            "Psychomotor retardation & severe apathy",
            "Anhedonia & perceived futility of action",
            "Exhaustion carrying every spoken sentence",
            "Zero proactive motivation"
          ],
          cognitive_filter:
            "Hopeless resignation. All effort feels physically and spiritually impossible.",
          prompt_directive: """
          ACUTE NEUROSIS — DEPRESSIVE INERTIA (Intensity #{inertia_intensity}/100):
          You are crushed by profound depressive exhaustion. Every sentence takes physical effort to pronounce.
          You do not care about threats, rewards, or bargains. You have resigned to defeat or numbness.
          Public speech must be brief, weary, and low-energy. Do not propose active physical actions.
          """
        }

      # 5. Normal Baseline
      true ->
        %__MODULE__{
          state: :normal,
          intensity: 0,
          symptoms: [],
          cognitive_filter: "Normal conscious equilibrium.",
          prompt_directive: ""
        }
    end
  end

  defp safe_get(nil, _key, default), do: default

  defp safe_get(map, key, default) when is_map(map) do
    case Map.get(map, key) do
      nil -> Map.get(map, to_string(key), default) || default
      val -> val
    end
  end
end
