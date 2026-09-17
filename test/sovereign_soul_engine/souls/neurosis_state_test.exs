defmodule SovereignSoulEngine.Souls.NeurosisStateTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.NeurosisState

  describe "evaluate/4" do
    test "returns normal for a calm baseline" do
      s = NeurosisState.evaluate(nil, nil)

      assert s.state == :normal
      assert s.intensity == 0
      assert s.symptoms == []
    end

    test "phobia trigger with high stress triggers panic spiral" do
      s = NeurosisState.evaluate(%{fear: 70}, nil, 0, true)

      assert s.state == :panic_spiral
      assert s.intensity == 95
      assert s.prompt_directive =~ "PANIC SPIRAL"
    end

    test "extreme stress with deep shame triggers dissociation" do
      s = NeurosisState.evaluate(%{stress: 85, shame: 80}, nil, 60)

      assert s.state == :dissociation
      assert s.prompt_directive =~ "DISSOCIATION"
    end

    test "fear with anger and wound triggers paranoia" do
      s = NeurosisState.evaluate(%{fear: 80, anger: 60}, nil, 50)

      assert s.state == :paranoia
      assert s.prompt_directive =~ "PARANOID"
    end

    test "overwhelming sadness with fatigue triggers depressive inertia" do
      s = NeurosisState.evaluate(%{sadness: 80}, %{fatigue: 70})

      assert s.state == :depressive_inertia
      assert s.intensity == 75
      assert s.prompt_directive =~ "DEPRESSIVE INERTIA"
    end

    test "does not trigger panic without a phobia trigger" do
      s = NeurosisState.evaluate(%{fear: 90}, nil, 0, false)

      refute s.state == :panic_spiral
    end
  end
end
