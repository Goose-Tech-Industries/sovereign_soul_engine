defmodule SovereignSoulEngine.Souls.DefenseMechanismsTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.DefenseMechanisms

  describe "evaluate/4" do
    test "returns no defense for a calm baseline" do
      d = DefenseMechanisms.evaluate(nil, nil, nil, nil)

      assert d.defense == :none
      assert d.intensity == 0
      assert d.prompt_directive == ""
    end

    test "shame triggers projection" do
      d = DefenseMechanisms.evaluate(%{shame: 60}, nil)

      assert d.defense == :projection
      assert d.intensity == 60
      assert d.prompt_directive =~ "PROJECTION"
    end

    test "guilt triggers projection" do
      d = DefenseMechanisms.evaluate(%{guilt: 70}, nil)

      assert d.defense == :projection
      assert d.intensity == 70
    end

    test "hostility with low trust and fear triggers reaction formation" do
      d = DefenseMechanisms.evaluate(%{anger: 70, fear: 50}, nil, nil, %{trust: 20})

      assert d.defense == :reaction_formation
      assert d.intensity == 60
      assert d.prompt_directive =~ "REACTION FORMATION"
    end

    test "deep sadness triggers intellectualization" do
      d = DefenseMechanisms.evaluate(%{sadness: 75}, nil)

      assert d.defense == :intellectualization
      assert d.intensity == 75
      assert d.prompt_directive =~ "INTELLECTUALIZATION"
    end

    test "extreme fatigue and fear trigger regression" do
      d = DefenseMechanisms.evaluate(%{fear: 70}, %{fatigue: 80})

      assert d.defense == :regression
      assert d.intensity == 75
      assert d.prompt_directive =~ "REGRESSION"
    end

    test "high confidence with anger triggers sublimation" do
      d = DefenseMechanisms.evaluate(%{confidence: 80, anger: 60}, nil)

      assert d.defense == :sublimation
      assert d.intensity == 70
      assert d.prompt_directive =~ "SUBLIMATION"
    end

    test "string-keyed emotional state is honored" do
      d = DefenseMechanisms.evaluate(%{"shame" => 65}, nil)

      assert d.defense == :projection
    end
  end
end
