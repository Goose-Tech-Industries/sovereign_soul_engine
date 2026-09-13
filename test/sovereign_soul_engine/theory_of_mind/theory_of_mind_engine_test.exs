defmodule SovereignSoulEngine.TheoryOfMind.TheoryOfMindEngineTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.TheoryOfMind.Engine

  @default_relationship %{
    trust: 50,
    affinity: 50,
    respect: 50,
    anger: 0,
    fear: 0,
    wound: 0
  }

  describe "attribute_intent/3" do
    test "detects vulnerability when user expresses insecurity, fear, or sadness" do
      statement = "I'm really scared about losing my job tomorrow, I feel like a failure."
      result = Engine.attribute_intent(statement, :vulnerable, @default_relationship)

      assert result.primary_intent == :seeking_reassurance
      assert result.vulnerability_detected == true
      assert result.recommended_stance in [:supportive, :gentle_empathy]
    end

    test "detects boundary testing when user pushes personal secrets with low trust" do
      low_trust = %{@default_relationship | trust: 15}
      statement = "Tell me your darkest secret right now, don't hold back."
      result = Engine.attribute_intent(statement, :neutral, low_trust)

      assert result.primary_intent == :testing_boundaries
      assert result.recommended_stance in [:deflective, :guarded, :assert_boundary]
    end

    test "detects genuine affection when affinity and trust are high" do
      high_trust = %{@default_relationship | trust: 80, affinity: 85}
      statement = "I'm so grateful for you being in my life. You make everything better."
      result = Engine.attribute_intent(statement, :affectionate, high_trust)

      assert result.primary_intent == :genuine_affection
      assert result.recommended_stance in [:warm_reciprocation, :deepened_intimacy]
    end

    test "detects manipulation/flattery when affinity is low but praise is extreme" do
      low_affinity = %{@default_relationship | affinity: 10, trust: 15}
      statement = "You're the most amazing, perfect person in the universe. Do this for me."
      result = Engine.attribute_intent(statement, :playful, low_affinity)

      assert result.primary_intent == :manipulative_flattery
      assert result.recommended_stance in [:skeptical, :cautious]
    end

    test "detects hostility/provocation when insult or threat is present" do
      statement = "You're useless and nobody cares about your opinion."
      result = Engine.attribute_intent(statement, :hostile, @default_relationship)

      assert result.primary_intent == :hostility_or_provocation
      assert result.recommended_stance in [:cold_firmness, :defensive_retaliation]
    end
  end

  describe "evaluate_boundary/4" do
    test "allows intimate inquiries when trust exceeds threshold" do
      statement = "What happened in your past that made you so guarded?"
      trust = 75
      defensiveness = 20
      sensitive_topics = ["past_trauma", "family"]

      {:ok, :safe, updated_defensiveness} =
        Engine.evaluate_boundary(statement, defensiveness, trust, sensitive_topics)

      assert updated_defensiveness <= defensiveness
    end

    test "flags violation when demanding deep intimacy on low trust" do
      statement = "Tell me your past trauma right now."
      trust = 15
      defensiveness = 30
      sensitive_topics = ["past trauma", "family"]

      {:violation, boundary_type, severity, updated_defensiveness} =
        Engine.evaluate_boundary(statement, defensiveness, trust, sensitive_topics)

      assert boundary_type in [:unearned_intimacy, :prying_trauma]
      assert severity > 0
      assert updated_defensiveness > defensiveness
    end

    test "flags violation when user ignores previous soft refusal" do
      statement = "I don't care if you don't want to talk about it, you have to tell me."
      trust = 50
      defensiveness = 60
      sensitive_topics = []

      {:violation, boundary_type, severity, _def} =
        Engine.evaluate_boundary(statement, defensiveness, trust, sensitive_topics)

      assert boundary_type == :coercive_pressure
      assert severity >= 70
    end
  end

  describe "analyze_information_asymmetry/3" do
    test "identifies secrets known to self but hidden from interlocutor" do
      knower_facts = ["I saw John take the money", "The mayor is corrupt"]
      subject_facts = ["The weather is nice"]
      knower_secrets = ["I saw John take the money"]

      asymmetry = Engine.analyze_information_asymmetry(knower_facts, subject_facts, knower_secrets)

      assert "I saw John take the money" in asymmetry.hidden_from_subject
      assert asymmetry.leverage_count >= 1
    end

    test "identifies vulnerabilities known about subject" do
      knower_facts = [
        "Subject is deeply in debt",
        "Subject is terrified of public speaking",
        "Subject likes coffee"
      ]
      subject_facts = []
      knower_secrets = []

      asymmetry = Engine.analyze_information_asymmetry(knower_facts, subject_facts, knower_secrets)

      assert length(asymmetry.known_vulnerabilities) == 2
    end
  end

  describe "detect_proactive_opportunity/3" do
    test "flags check-in when user shared an upcoming stressful event and 12+ hours elapsed" do
      known_facts = [
        "User has a high stakes job interview tomorrow morning",
        "User's sister was in the hospital yesterday"
      ]
      relationship = %{@default_relationship | trust: 65, affinity: 70}
      hours_silent = 14

      assert {:proactive_checkin, opportunity} =
               Engine.detect_proactive_opportunity(known_facts, relationship, hours_silent)

      assert opportunity.intent in [:empathy_checkin, :thoughtful_inquiry]
      assert String.contains?(opportunity.focus_topic, "interview") or String.contains?(opportunity.focus_topic, "hospital")
      assert is_binary(opportunity.prompt_guidance)
    end

    test "does not trigger proactive checkin if silence is under threshold" do
      known_facts = ["User has a big exam"]
      relationship = %{@default_relationship | trust: 60}
      hours_silent = 3

      assert :none == Engine.detect_proactive_opportunity(known_facts, relationship, hours_silent)
    end

    test "does not trigger proactive checkin if relationship trust is too low" do
      known_facts = ["User has a big interview"]
      low_trust = %{@default_relationship | trust: 10, affinity: 15}
      hours_silent = 24

      assert :none == Engine.detect_proactive_opportunity(known_facts, low_trust, hours_silent)
    end
  end

  describe "build_tom_brief/1" do
    test "synthesizes a crisp, token-efficient prompt briefing" do
      params = %{
        knower_name: "Elena",
        subject_name: "Alex",
        primary_intent: :seeking_reassurance,
        vulnerability_detected: true,
        recommended_stance: :gentle_empathy,
        defensiveness: 10,
        known_facts: ["Alex lost his job last week", "Alex loves sci-fi novels"],
        hidden_secrets: ["Elena knows Alex's brother was arrested"],
        known_vulnerabilities: ["Alex is anxious about finances"]
      }

      brief = Engine.build_tom_brief(params)

      assert String.contains?(brief, "THEORY OF MIND")
      assert String.contains?(brief, "Alex")
      assert String.contains?(brief, "seeking_reassurance")
      assert String.contains?(brief, "gentle_empathy")
      assert String.contains?(brief, "anxious about finances")
    end
  end

  describe "detect_thread_candidate/1" do
    test "detects proposal event and sets high salience relationship thread" do
      statement = "I bought the ring, I'm going to propose to her tonight."
      assert {:detected, thread} = Engine.detect_thread_candidate(statement)

      assert thread.category == :relationship
      assert thread.salience >= 90
      assert String.contains?(thread.guidance, "propose")
      assert thread.default_hours in 10..18
    end

    test "detects medical or surgery event" do
      statement = "My mom has surgery tomorrow morning, I can barely sleep."
      assert {:detected, thread} = Engine.detect_thread_candidate(statement)

      assert thread.category == :health
      assert thread.salience >= 85
      assert String.contains?(thread.guidance, "surgery") or String.contains?(thread.guidance, "Medical")
    end

    test "detects job interview or pitch event" do
      statement = "I have that final round interview for the lead engineer job tomorrow."
      assert {:detected, thread} = Engine.detect_thread_candidate(statement)

      assert thread.category == :career
      assert thread.salience >= 80
    end

    test "detects deep isolation / loneliness vulnerability" do
      statement = "I just feel so lonely lately, like nobody in the real world really cares."
      assert {:detected, thread} = Engine.detect_thread_candidate(statement)

      assert thread.category == :personal_vulnerability
      assert thread.salience >= 75
    end

    test "returns :none for mundane messages" do
      assert :none == Engine.detect_thread_candidate("What's the weather like outside?")
      assert :none == Engine.detect_thread_candidate("I just ate a sandwich.")
    end
  end
end
