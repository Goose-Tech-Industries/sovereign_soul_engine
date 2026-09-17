defmodule SovereignSoulEngine.Social.SocialDriftEngineTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Social.SocialDriftEngine

  describe "compute_compatibility/2" do
    test "identical core values yield 0.5" do
      a = %{core_values: ["loyalty"], fears: []}
      b = %{core_values: ["loyalty"], fears: []}

      assert SocialDriftEngine.compute_compatibility(a, b) == 0.5
    end

    test "conflicting values yield a negative score" do
      a = %{core_values: ["loyalty"], fears: []}
      b = %{core_values: ["betrayal"], fears: []}

      assert SocialDriftEngine.compute_compatibility(a, b) == -0.667
    end

    test "empty profiles are neutral" do
      assert SocialDriftEngine.compute_compatibility(%{core_values: [], fears: []}, %{
               core_values: [],
               fears: []
             }) == 0.0
    end

    test "shared fears and values boost compatibility above 0.6" do
      a = %{
        core_values: ["loyalty", "honor", "justice"],
        fears: ["abandonment", "betrayal", "darkness"]
      }

      b = %{
        core_values: ["loyalty", "honor", "justice"],
        fears: ["abandonment", "betrayal", "darkness"]
      }

      assert SocialDriftEngine.compute_compatibility(a, b) == 0.667
    end
  end

  describe "compute_drift/3" do
    defp compatible_profiles(style) do
      {
        %{
          core_values: ["loyalty", "honor", "justice"],
          fears: ["abandonment", "betrayal", "darkness"],
          attachment_style: style
        },
        %{
          core_values: ["loyalty", "honor", "justice"],
          fears: ["abandonment", "betrayal", "darkness"]
        }
      }
    end

    test "compatible secure pair drifts closer" do
      {a, b} = compatible_profiles("secure")

      assert SocialDriftEngine.compute_drift(a, b, %{wound: 0, trust: 50, anger: 0}) == %{
               trust: 2,
               affinity: 2,
               anger: 0
             }
    end

    test "a deep wound drags trust and affinity negative" do
      a = %{core_values: ["loyalty"], fears: [], attachment_style: "secure"}
      b = %{core_values: ["loyalty"], fears: []}

      assert SocialDriftEngine.compute_drift(a, b, %{wound: 80, trust: 50, anger: 0}) == %{
               trust: -1,
               affinity: -1,
               anger: 0
             }
    end

    test "high trust anchors trust upward" do
      a = %{core_values: ["loyalty"], fears: [], attachment_style: "secure"}
      b = %{core_values: ["loyalty"], fears: []}

      assert SocialDriftEngine.compute_drift(a, b, %{wound: 0, trust: 90, anger: 0}) == %{
               trust: 2,
               affinity: 1,
               anger: 0
             }
    end

    test "anxious attachment amplifies drift vs avoidant" do
      {anxious_a, b} = compatible_profiles("anxious")
      {avoidant_a, _} = compatible_profiles("avoidant")

      anxious = SocialDriftEngine.compute_drift(anxious_a, b, %{wound: 0, trust: 50, anger: 0})
      avoidant = SocialDriftEngine.compute_drift(avoidant_a, b, %{wound: 0, trust: 50, anger: 0})

      assert anxious.trust > avoidant.trust
      assert anxious.affinity > avoidant.affinity
    end

    test "deltas are small integers within bounds" do
      a = %{
        core_values: ["loyalty", "honor"],
        fears: ["abandonment"],
        attachment_style: "disorganized"
      }

      b = %{core_values: ["betrayal", "deceit"], fears: []}

      drift = SocialDriftEngine.compute_drift(a, b, %{wound: 90, trust: 10, anger: 80})

      assert is_integer(drift.trust)
      assert is_integer(drift.affinity)
      assert is_integer(drift.anger)
      assert drift.trust >= -5 and drift.trust <= 5
      assert drift.affinity >= -5 and drift.affinity <= 5
    end
  end

  describe "describe_compatibility/1" do
    test "maps scores to human labels" do
      assert SocialDriftEngine.describe_compatibility(0.8) == "strongly compatible"
      assert SocialDriftEngine.describe_compatibility(0.5) == "compatible"
      assert SocialDriftEngine.describe_compatibility(0.0) == "neutral"
      assert SocialDriftEngine.describe_compatibility(-0.2) == "friction"
      assert SocialDriftEngine.describe_compatibility(-0.5) == "deeply incompatible"
    end
  end
end
