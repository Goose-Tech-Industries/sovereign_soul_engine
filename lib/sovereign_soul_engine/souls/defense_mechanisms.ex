defmodule SovereignSoulEngine.Souls.DefenseMechanisms do
  @moduledoc """
  Freudian and Jungian Psychological Defense Mechanism Engine.
  Egos automatically deploy unconscious defense mechanisms to shield against shame,
  guilt, trauma, and intolerable emotional vulnerability.
  """

  @type defense_type :: :none | :projection | :reaction_formation | :intellectualization | :regression | :sublimation

  @type t :: %__MODULE__{
          defense: defense_type(),
          intensity: integer(),
          manifestation: String.t(),
          prompt_directive: String.t()
        }

  defstruct defense: :none,
            intensity: 0,
            manifestation: "No active ego defense. Unfiltered emotional communication.",
            prompt_directive: ""

  @doc """
  Evaluates active psychological defense mechanisms given emotional dimensions,
  somatic state, soul profile, and relationship deltas.
  """
  @spec evaluate(map() | nil, map() | nil, map() | nil, map() | nil) :: t()
  def evaluate(emotional_state, somatic_state, _soul_profile \\ nil, relationship \\ nil) do
    shame = safe_get(emotional_state, :shame, 0)
    guilt = safe_get(emotional_state, :guilt, 0)
    anger = safe_get(emotional_state, :anger, 0)
    fear = safe_get(emotional_state, :fear, 0)
    sadness = safe_get(emotional_state, :sadness, 0)
    confidence = safe_get(emotional_state, :confidence, 50)
    fatigue = safe_get(somatic_state, :fatigue, 0)
    wound = safe_get(relationship, :wound, 0)
    trust = safe_get(relationship, :trust, 50)

    cond do
      # 1. Projection: Intolerable shame or guilt projected outward
      shame >= 55 or guilt >= 55 ->
        intensity = max(shame, guilt)
        %__MODULE__{
          defense: :projection,
          intensity: intensity,
          manifestation: "Accusing the conversational partner of the character's own repressed failings.",
          prompt_directive: """
          ACTIVE EGO DEFENSE — PROJECTION (Intensity #{intensity}/100):
          Your subconscious cannot bear your own internal shame or guilt.
          You project your hidden fears and betrayals onto the other person.
          Accuse them of being untrustworthy, deceptive, or selfish. Deflect scrutiny by interrogating their character.
          """
        }

      # 2. Reaction Formation: Hostility disguised as saccharine sweetness
      (anger >= 60 or wound >= 50) and (trust <= 40 and fear >= 40) ->
        intensity = div(anger + fear, 2)
        %__MODULE__{
          defense: :reaction_formation,
          intensity: intensity,
          manifestation: "Displaying exaggerated, saccharine politeness to conceal burning hostility.",
          prompt_directive: """
          ACTIVE EGO DEFENSE — REACTION FORMATION (Intensity #{intensity}/100):
          You harbor deep, dangerous hostility toward this person, but fear the consequences of open conflict.
          Your public speech must be unnervingly polite, attentive, and deferential, almost to a point of mockery.
          Your private thoughts must betray your true venom and calculated contempt.
          """
        }

      # 3. Intellectualization: Severe emotional grief or wound converted into clinical analysis
      sadness >= 60 or wound >= 50 ->
        intensity = max(sadness, wound)
        %__MODULE__{
          defense: :intellectualization,
          intensity: intensity,
          manifestation: "Converting raw emotional agony into detached, clinical, hyper-rational logic.",
          prompt_directive: """
          ACTIVE EGO DEFENSE — INTELLECTUALIZATION (Intensity #{intensity}/100):
          The emotional pain of this topic is too agonizing to feel directly.
          You refuse to show grief, sorrow, or hurt. Instead, speak like a cold, detached academic, strategist, or coroner.
          Analyze human betrayal and loss as clinical case studies, statistical probabilities, or structural inevitabilities.
          """
        }

      # 4. Regression: Childlike dependency under extreme fatigue and fear
      fatigue >= 75 and fear >= 65 ->
        intensity = div(fatigue + fear, 2)
        %__MODULE__{
          defense: :regression,
          intensity: intensity,
          manifestation: "Reverting to childlike vulnerability, helplessness, and desperate attachment demands.",
          prompt_directive: """
          ACTIVE EGO DEFENSE — REGRESSION (Intensity #{intensity}/100):
          You have reached complete psychic and somatic exhaustion.
          Your adult stoicism crumbles. You speak with raw, unvarnished childlike vulnerability, seeking protection,
          reassurance, and comfort. Express fear of being abandoned in simple, unguarded words.
          """
        }

      # 5. Sublimation: Channeling destructive rage into hyper-focused competence
      confidence >= 70 and anger >= 55 ->
        intensity = div(confidence + anger, 2)
        %__MODULE__{
          defense: :sublimation,
          intensity: intensity,
          manifestation: "Transmuting dangerous rage into icy, laser-focused competence and tactical resolve.",
          prompt_directive: """
          ACTIVE EGO DEFENSE — SUBLIMATION (Intensity #{intensity}/100):
          You take burning fury and forge it into cold, razor-sharp discipline.
          You do not shout or lose control; you channel your wrath into ruthless operational efficiency,
          commanding posture, and purposeful action.
          """
        }

      true ->
        %__MODULE__{
          defense: :none,
          intensity: 0,
          manifestation: "No active ego defense.",
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
