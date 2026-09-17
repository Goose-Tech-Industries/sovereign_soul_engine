defmodule SovereignSoulEngine.World.SimulationTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.{Characters, Relationships, Souls, World}
  alias SovereignSoulEngine.World.Simulation

  setup do
    World.seed_souls()
    :ok
  end

  test "pilot_slugs/0 returns six souls" do
    assert length(Simulation.pilot_slugs()) == 6
  end

  test "step/1 runs hermetic encounters across the pilot cohort" do
    assert {:ok, summary} = Simulation.step()

    assert summary.souls == 6
    assert length(summary.encounters) == 3

    for encounter <- summary.encounters do
      assert encounter.outcome == :encountered
      assert encounter.resonance >= 15 and encounter.resonance <= 98
      assert is_map(encounter.delta)
    end

    # relationships were formed for each pair
    assert length(Relationships.list_relationships()) == 3

    # a signed world event was recorded for each encounter
    events = World.list_recent_events(limit: 10) |> Enum.filter(&(&1.kind == "encounter"))
    assert length(events) == 3
  end

  test "step/1 throttles low-stamina souls out of the square" do
    # tank one soul's stamina below the threshold
    char = Characters.get_character_by_slug!("maya")
    profile = Souls.get_soul_profile_by_character(char.id)
    Souls.update_soul_profile(profile, %{social_stamina: 5})

    assert {:ok, summary} = Simulation.step()

    # maya is excluded, leaving 5 eligible souls -> 2 pairs
    assert length(summary.encounters) == 2
    assert Enum.all?(summary.encounters, fn e -> e.a != "maya" and e.b != "maya" end)
  end

  test "step/1 with llm: true does not raise (high-salience path is fire-and-forget)" do
    assert {:ok, _summary} = Simulation.step(llm: true)
  end
end
