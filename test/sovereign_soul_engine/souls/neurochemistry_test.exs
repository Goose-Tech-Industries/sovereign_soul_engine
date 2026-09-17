defmodule SovereignSoulEngine.Souls.NeurochemistryTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.Neurochemistry

  describe "compute/3" do
    test "computes a balanced baseline from defaults" do
      chem = Neurochemistry.compute(nil, nil, nil)

      assert %Neurochemistry{} = chem
      assert chem.cortisol == 12
      assert chem.oxytocin == 32
      assert chem.dopamine == 42
      assert chem.serotonin == 40
      assert chem.hormonal_tone =~ "equilibrium"
    end

    test "accepts string-keyed maps" do
      chem = Neurochemistry.compute(%{"stress" => 100, "fear" => 100}, %{"pain" => 100}, nil)
      atom_chem = Neurochemistry.compute(%{stress: 100, fear: 100}, %{pain: 100}, nil)

      assert chem == atom_chem
      assert chem.cortisol == 81
    end

    test "caps cortisol at 100 under extreme inputs" do
      chem = Neurochemistry.compute(%{stress: 100, fear: 100, anger: 100}, %{pain: 100}, %{wound: 100})
      assert chem.cortisol == 100
    end

    test "clamps oxytocin at 0 for a deep betrayal" do
      chem = Neurochemistry.compute(%{attachment: 0}, nil, %{trust: 0, gratitude: 0, wound: 100})

      assert chem.oxytocin == 0
    end

    test "high stress and pain drives down serotonin" do
      calm = Neurochemistry.compute(%{stress: 0}, %{pain: 0}, nil)
      stressed = Neurochemistry.compute(%{stress: 100}, %{pain: 100}, nil)

      assert stressed.serotonin < calm.serotonin
    end

    test "trust and attachment raise oxytocin" do
      cold = Neurochemistry.compute(nil, nil, %{trust: 0, attachment: 0})
      bonded = Neurochemistry.compute(%{attachment: 100}, nil, %{trust: 100})

      assert bonded.oxytocin > cold.oxytocin
    end
  end

  describe "modulate_delta/3" do
    test "high oxytocin cushions anger deltas" do
      chem = %Neurochemistry{oxytocin: 100, serotonin: 60}
      assert Neurochemistry.modulate_delta(:anger, 10, chem) < 10
    end

    test "low serotonin amplifies anger volatility" do
      calm = %Neurochemistry{oxytocin: 100, serotonin: 60}
      volatile = %Neurochemistry{oxytocin: 100, serotonin: 20}

      assert Neurochemistry.modulate_delta(:anger, 10, volatile) > Neurochemistry.modulate_delta(:anger, 10, calm)
    end

    test "high cortisol sensitizes fear deltas" do
      stressed = %Neurochemistry{cortisol: 80}
      calm = %Neurochemistry{cortisol: 30}

      assert Neurochemistry.modulate_delta(:fear, 10, stressed) > Neurochemistry.modulate_delta(:fear, 10, calm)
    end

    test "unknown dimensions pass through unchanged" do
      chem = %Neurochemistry{}
      assert Neurochemistry.modulate_delta(:curiosity, 7, chem) == 7
    end
  end
end
