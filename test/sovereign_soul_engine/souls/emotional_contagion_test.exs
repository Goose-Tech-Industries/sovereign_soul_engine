defmodule SovereignSoulEngine.Souls.EmotionalContagionTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.EmotionalContagion

  describe "detect_tone/1" do
    test "nil and empty are neutral" do
      assert EmotionalContagion.detect_tone(nil) == :neutral
      assert EmotionalContagion.detect_tone("") == :neutral
    end

    test "positive words yield positive" do
      assert EmotionalContagion.detect_tone("thank you, I love this") == :positive
    end

    test "negative words yield negative" do
      assert EmotionalContagion.detect_tone("I hate you, you are terrible") == :negative
    end

    test "multiple distressed words yield distressed" do
      assert EmotionalContagion.detect_tone("please help me, I'm scared and hurt") == :distressed
    end

    test "distress plus negativity yields distressed" do
      assert EmotionalContagion.detect_tone("please help, I hate this") == :distressed
    end

    test "neutral content yields neutral" do
      assert EmotionalContagion.detect_tone("the cat sat on the mat") == :neutral
    end
  end

  describe "apply_contagion/4" do
    test "positive tone with sufficient susceptibility" do
      assert EmotionalContagion.apply_contagion(nil, :positive, 60) == %{
               stress: -2,
               anger: -1,
               gratitude: 2
             }
    end

    test "negative tone" do
      assert EmotionalContagion.apply_contagion(nil, :negative, 60) == %{stress: 3, anger: 2}
    end

    test "distressed tone" do
      assert EmotionalContagion.apply_contagion(nil, :distressed, 60) == %{
               fear: 3,
               stress: 4,
               sadness: 2
             }
    end

    test "low susceptibility produces no contagion" do
      assert EmotionalContagion.apply_contagion(nil, :positive, 10) == %{}
    end

    test "avoidant attachment halves the deltas" do
      assert EmotionalContagion.apply_contagion(nil, :negative, 60, "avoidant") == %{
               stress: 1,
               anger: 1
             }
    end

    test "anxious attachment doubles the deltas" do
      assert EmotionalContagion.apply_contagion(nil, :negative, 60, "anxious") == %{
               stress: 6,
               anger: 4
             }
    end

    test "secure attachment leaves deltas unchanged" do
      assert EmotionalContagion.apply_contagion(nil, :negative, 60, "secure") == %{
               stress: 3,
               anger: 2
             }
    end
  end

  describe "describe_contagion/2" do
    test "neutral tone has no description" do
      assert EmotionalContagion.describe_contagion(:neutral, %{stress: 3}) == nil
    end

    test "empty deltas have no description" do
      assert EmotionalContagion.describe_contagion(:negative, %{}) == nil
    end

    test "returns a description for an active tone" do
      assert EmotionalContagion.describe_contagion(:negative, %{stress: 3}) =~ "hostile"
    end
  end
end
