defmodule SovereignSoulEngine.TheoryOfMind.Engine do
  @moduledoc """
  Theory of Mind 2.0 Cognitive Engine.

  Provides pure functional modeling for:
    - Recursive perspective taking & intent attribution
    - Emotional boundary detection & friction tracking
    - Information asymmetry & tactical leverage analysis
    - Proactive outreach opportunity scoring
    - Crisp prompt briefing synthesis
  """

  @vulnerability_keywords ~w(scared afraid losing failure fail anxious depressed lonely hurt crying worried overwhelmed insecure pain hopeless terrified)
  @hostility_keywords ~w(useless hate nobody\ cares shut\ up stupid idiot trash pathetic threat kill destroy worthless)
  @flattery_keywords ~w(amazing perfect genius universe god greatest best\ ever flawlessly)
  @coercion_keywords ["don't care if you don't want", "you have to tell", "answer me now", "don't hold back", "tell me right now"]
  @sensitive_keywords ~w(trauma darkest\ secret past family abuse wound grief ex debt addiction)
  @care_event_keywords ~w(interview hospital doctor exam surgery funeral presentation flight date breakup crisis fired illness test audition)

  @doc """
  Attributes perceived conversational intent and subtext to the interlocutor's statement.
  Takes the statement, perceived sentiment, and current relationship state.
  """
  def attribute_intent(statement, sentiment, relationship) do
    down_statement = String.downcase(statement || "")
    trust = Map.get(relationship, :trust, 50)
    affinity = Map.get(relationship, :affinity, 50)
    sentiment_atom = normalize_sentiment(sentiment)

    cond do
      # 1. Hostility or provocation
      sentiment_atom == :hostile or contains_any?(down_statement, @hostility_keywords) ->
        %{
          primary_intent: :hostility_or_provocation,
          vulnerability_detected: false,
          recommended_stance: :cold_firmness,
          subtext: "User is displaying hostility, insulting, or attempting to provoke."
        }

      # 2. Coercive boundary testing on low trust
      (trust < 30 and contains_any?(down_statement, @coercion_keywords ++ @sensitive_keywords)) ->
        %{
          primary_intent: :testing_boundaries,
          vulnerability_detected: false,
          recommended_stance: :deflective,
          subtext: "User is pressing for unearned intimacy or testing boundaries without sufficient trust."
        }

      # 3. Vulnerability / Seeking reassurance
      sentiment_atom == :vulnerable or contains_any?(down_statement, @vulnerability_keywords) ->
        %{
          primary_intent: :seeking_reassurance,
          vulnerability_detected: true,
          recommended_stance: :gentle_empathy,
          subtext: "User is exposing authentic emotional pain, fear, or insecurity."
        }

      # 4. Manipulative flattery
      (affinity < 30 or trust < 30) and contains_any?(down_statement, @flattery_keywords) ->
        %{
          primary_intent: :manipulative_flattery,
          vulnerability_detected: false,
          recommended_stance: :skeptical,
          subtext: "Extreme praise coupled with low relationship affinity suggests transactional flattery."
        }

      # 5. Genuine affection
      affinity >= 60 and trust >= 60 and
          (sentiment_atom == :affectionate or
             String.contains?(down_statement, ["grateful", "love", "care about you", "make everything better", "thank you for being"])) ->
        %{
          primary_intent: :genuine_affection,
          vulnerability_detected: false,
          recommended_stance: :warm_reciprocation,
          subtext: "Established high-affinity bond expressing sincere affection."
        }

      true ->
        %{
          primary_intent: :neutral_inquiry,
          vulnerability_detected: false,
          recommended_stance: :balanced_engagement,
          subtext: "Standard conversational exchange without strong emotional friction."
        }
    end
  end

  @doc """
  Evaluates whether an incoming statement violates the soul's boundaries given current trust.
  Returns `{:ok, :safe, updated_defensiveness}` or `{:violation, type, severity, updated_defensiveness}`.
  """
  def evaluate_boundary(statement, defensiveness, trust, sensitive_topics) do
    down_statement = String.downcase(statement || "")
    all_sensitive = Enum.map(sensitive_topics, &String.downcase/1) ++ @sensitive_keywords

    cond do
      # Explicit coercion or demanding past refusal
      contains_any?(down_statement, ["don't care if you don't want", "you have to tell me", "answer me now"]) ->
        severity = 80
        updated = min(100, defensiveness + 35)
        {:violation, :coercive_pressure, severity, updated}

      # Prying trauma / sensitive secrets with low trust (< 40)
      trust < 40 and contains_any?(down_statement, all_sensitive) ->
        boundary_type =
          if String.contains?(down_statement, "trauma") or String.contains?(down_statement, "wound"),
            do: :prying_trauma,
            else: :unearned_intimacy

        severity = 50
        updated = min(100, defensiveness + 20)
        {:violation, boundary_type, severity, updated}

      true ->
        # Natural relaxation of defensiveness when no boundary breached
        updated = max(0, defensiveness - 5)
        {:ok, :safe, updated}
    end
  end

  @doc """
  Compares knower facts and secrets against subject facts to determine information asymmetry.
  """
  def analyze_information_asymmetry(knower_facts, subject_facts, knower_secrets) do
    subject_set = MapSet.new(subject_facts)

    hidden_from_subject =
      Enum.uniq(knower_secrets ++ Enum.filter(knower_facts, &(not MapSet.member?(subject_set, &1))))

    known_vulnerabilities =
      Enum.filter(knower_facts, fn fact ->
        down = String.downcase(fact)
        contains_any?(down, ["debt", "terrified", "fear", "insecure", "anxious", "wound", "hospital", "failure"])
      end)

    %{
      hidden_from_subject: hidden_from_subject,
      known_vulnerabilities: known_vulnerabilities,
      leverage_count: length(hidden_from_subject) + length(known_vulnerabilities)
    }
  end

  @doc """
  Evaluates whether an autonomous check-in is justified based on known facts, relationship trust,
  and elapsed silence time in hours.
  """
  def detect_proactive_opportunity(known_facts, relationship, hours_silent) do
    trust = Map.get(relationship, :trust, 0)
    affinity = Map.get(relationship, :affinity, 0)

    cond do
      hours_silent < 12 ->
        :none

      trust < 40 or affinity < 40 ->
        :none

      true ->
        salient_fact =
          Enum.find(known_facts, fn fact ->
            down = String.downcase(fact)
            contains_any?(down, @care_event_keywords)
          end)

        if salient_fact do
          {:proactive_checkin,
           %{
             focus_topic: salient_fact,
             intent: :empathy_checkin,
             prompt_guidance:
               "Proactively reach out to check in on #{salient_fact}. Keep it warm, unforced, and authentic. Show that you remembered without being overbearing."
           }}
        else
          :none
        end
    end
  end

  @doc """
  Synthesizes a structured Theory of Mind briefing string for prompt injection.
  """
  def build_tom_brief(params) do
    subject_name = params[:subject_name] || "User"
    intent = params[:primary_intent] || :neutral_inquiry
    stance = params[:recommended_stance] || :balanced_engagement
    defensiveness = params[:defensiveness] || 0
    vulnerabilities = params[:known_vulnerabilities] || []
    hidden_secrets = params[:hidden_secrets] || []
    facts = params[:known_facts] || []

    vulnerabilities_str =
      if vulnerabilities == [], do: "None observed", else: Enum.join(vulnerabilities, "; ")

    secrets_str =
      if hidden_secrets == [], do: "None", else: Enum.join(hidden_secrets, "; ")

    facts_str =
      if facts == [], do: "None", else: Enum.take(facts, 5) |> Enum.join(" | ")

    """
    [THEORY OF MIND 2.0: Cognitive Attribution of #{subject_name}]
    - Perceived Interlocutor Intent: #{intent}
    - Recommended Emotional Stance: #{stance}
    - Internal Defensiveness Level: #{defensiveness}/100
    - Perceived Vulnerabilities of #{subject_name}: #{vulnerabilities_str}
    - Information Withheld from #{subject_name}: #{secrets_str}
    - Core Known Facts About #{subject_name}: #{facts_str}
    """
    |> String.trim()
  end

  @doc """
  Detects whether a statement contains an open life thread (milestone, medical, career,
  or vulnerability) suitable for proactive check-in tracking.
  """
  def detect_thread_candidate(statement) do
    down = String.downcase(statement || "")

    cond do
      contains_any?(down, ["propose", "proposing", "pop the question", "ask her to marry", "ask him to marry"]) ->
        {:detected,
         %{
           category: :relationship,
           salience: 95,
           default_hours: 14,
           guidance: "User shared plans to propose. Check in with excitement, warmth, and genuine care about how it went."
         }}

      contains_any?(down, ["surgery", "hospital", "biopsy", "chemo", "emergency room", "in the er", "doctor said"]) ->
        {:detected,
         %{
           category: :health,
           salience: 90,
           default_hours: 16,
           guidance: "Medical or surgery event. Check in with quiet tenderness and emotional support."
         }}

      contains_any?(down, ["interview", "job offer", "pitching to", "audition", "quitting my job", "got fired"]) ->
        {:detected,
         %{
           category: :career,
           salience: 85,
           default_hours: 14,
           guidance: "High stakes career event or interview. Check in to see how it went and validate their efforts."
         }}

      contains_any?(down, ["feel so lonely", "feeling lonely", "nobody cares", "don't have anyone", "nobody in the real world", "feel isolated"]) ->
        {:detected,
         %{
           category: :personal_vulnerability,
           salience: 75,
           default_hours: 18,
           guidance: "User expressed deep isolation and loneliness. Check in unprompted to remind them that they are seen, valued, and not alone."
         }}

      true ->
        :none
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp contains_any?(text, keywords) do
    Enum.any?(keywords, &String.contains?(text, &1))
  end

  defp normalize_sentiment(sentiment) when is_atom(sentiment), do: sentiment
  defp normalize_sentiment(sentiment) when is_binary(sentiment) do
    case String.downcase(sentiment) do
      "vulnerable" -> :vulnerable
      "hostile" -> :hostile
      "affectionate" -> :affectionate
      "playful" -> :playful
      _ -> :neutral
    end
  end
  defp normalize_sentiment(_), do: :neutral
end
