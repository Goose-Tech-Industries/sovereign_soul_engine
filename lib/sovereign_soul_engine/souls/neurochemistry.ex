defmodule SovereignSoulEngine.Souls.Neurochemistry do
  @moduledoc """
  Biochemical Neurotransmitter Simulation Layer.
  Models the underlying neurochemistry (Cortisol, Oxytocin, Dopamine, Serotonin)
  that shapes emotional half-lives, cognitive reactivity, and bonding persistence.
  """

  @type t :: %__MODULE__{
          cortisol: integer(),
          oxytocin: integer(),
          dopamine: integer(),
          serotonin: integer(),
          hormonal_tone: String.t()
        }

  defstruct cortisol: 20,
            oxytocin: 40,
            dopamine: 50,
            serotonin: 60,
            hormonal_tone: "Balanced neurochemical baseline."

  @doc """
  Computes live neurochemical levels from current emotional, somatic, and relationship vitals.
  """
  @spec compute(map() | nil, map() | nil, map() | nil) :: t()
  def compute(emotional_state, somatic_state, relationship \\ nil) do
    stress = safe_get(emotional_state, :stress, 20)
    fear = safe_get(emotional_state, :fear, 15)
    anger = safe_get(emotional_state, :anger, 10)
    attachment = safe_get(emotional_state, :attachment, 30)
    curiosity = safe_get(emotional_state, :curiosity, 50)
    confidence = safe_get(emotional_state, :confidence, 50)
    pain = safe_get(somatic_state, :pain, 0)
    fatigue = safe_get(somatic_state, :fatigue, 15)
    wound = safe_get(relationship, :wound, 0)
    trust = safe_get(relationship, :trust, 50)
    gratitude = safe_get(relationship, :gratitude, 10)

    # 1. Cortisol: Stress/Survival Hormone (0-100)
    # Driven by acute stress, physical pain, trauma wounds, anger, and fear
    cortisol =
      (stress * 0.35 + fear * 0.25 + anger * 0.1 + pain * 0.2 + wound * 0.1)
      |> round()
      |> clamp(0, 100)

    # 2. Oxytocin: Social Bonding & Empathy Neuropeptide (0-100)
    # Driven by mutual trust, emotional attachment, gratitude, and low wound
    oxytocin =
      (attachment * 0.4 + trust * 0.35 + gratitude * 0.25 - wound * 0.2)
      |> round()
      |> clamp(0, 100)

    # 3. Dopamine: Reward, Anticipation & Curiosity Neurotransmitter (0-100)
    # Driven by curiosity, confidence, and desire pursuit; suppressed by severe fatigue
    dopamine =
      (curiosity * 0.5 + confidence * 0.4 - fatigue * 0.2)
      |> round()
      |> clamp(0, 100)

    # 4. Serotonin: Mood Stabilization & Impulse Regulation (0-100)
    # Driven by feeling safe, respected, and physically rested; drained by chronic stress/pain
    serotonin =
      (confidence * 0.4 + (100 - fatigue) * 0.3 - (stress + pain) * 0.3)
      |> round()
      |> clamp(0, 100)

    tone = describe_tone(cortisol, oxytocin, dopamine, serotonin)

    %__MODULE__{
      cortisol: cortisol,
      oxytocin: oxytocin,
      dopamine: dopamine,
      serotonin: serotonin,
      hormonal_tone: tone
    }
  end

  @doc """
  Modulates incoming emotional event deltas according to active neurochemistry.
  - High Oxytocin cushions minor slights (reduces anger delta).
  - High Cortisol sensitizes fight-or-flight reactions (magnifies fear & stress deltas).
  - Low Serotonin amplifies emotional volatility.
  """
  @spec modulate_delta(atom(), integer(), t()) :: integer()
  def modulate_delta(:anger, delta, %__MODULE__{oxytocin: oxy, serotonin: ser}) when delta > 0 do
    cushion = div(oxy, 25)
    volatility = if ser < 35, do: 1.3, else: 1.0
    max(1, round((delta - cushion) * volatility))
  end

  def modulate_delta(:fear, delta, %__MODULE__{cortisol: cort}) when delta > 0 do
    sensitizer = if cort > 65, do: 1.35, else: 1.0
    round(delta * sensitizer)
  end

  def modulate_delta(:stress, delta, %__MODULE__{cortisol: cort, oxytocin: oxy}) when delta > 0 do
    multiplier = 1.0 + cort / 200.0 - oxy / 250.0
    max(1, round(delta * multiplier))
  end

  def modulate_delta(_dim, delta, _chemistry), do: delta

  defp describe_tone(cort, oxy, dop, ser) do
    cond do
      cort >= 75 ->
        "Acute hyper-cortisolemia: elevated pulse, vigilance, and survival threat sensitivity."

      oxy >= 70 ->
        "High oxytocinergic bonding: profound empathy, vulnerability, and instinctive devotion."

      dop >= 75 ->
        "Hyper-dopaminergic drive: intense curiosity, excitement, and pursuit of novelty."

      ser <= 30 ->
        "Severe serotonin depletion: volatile emotional regulation, irritability, and depressive vulnerability."

      true ->
        "Neurochemical equilibrium: stable autonomic regulation."
    end
  end

  defp clamp(val, min_v, max_v) do
    val |> max(min_v) |> min(max_v)
  end

  defp safe_get(nil, _key, default), do: default

  defp safe_get(map, key, default) when is_map(map) do
    case Map.get(map, key) do
      nil -> Map.get(map, to_string(key), default) || default
      val -> val
    end
  end
end
