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

  test "step/1 runs hermetic encounters across the full world population" do
    assert {:ok, summary} = Simulation.step()

    assert summary.souls == 50
    assert length(summary.encounters) == 25

    for encounter <- summary.encounters do
      assert encounter.outcome == :encountered
      assert encounter.resonance >= 15 and encounter.resonance <= 98
      assert is_map(encounter.delta)
    end

    # relationships were formed for each pair
    assert length(Relationships.list_relationships()) == 25

    # a signed world event was recorded for each encounter
    events = World.list_recent_events(limit: 100) |> Enum.filter(&(&1.kind == "encounter"))
    assert length(events) == 25
  end

  test "step/1 throttles low-stamina souls out of the square" do
    # tank one soul's stamina below the threshold
    char = Characters.get_character_by_slug!("maya")
    profile = Souls.get_soul_profile_by_character(char.id)
    Souls.update_soul_profile(profile, %{social_stamina: 5})

    assert {:ok, summary} = Simulation.step()

    # maya is excluded, leaving 49 eligible souls -> 24 pairs
    assert length(summary.encounters) == 24
    assert Enum.all?(summary.encounters, fn e -> e.a != "maya" and e.b != "maya" end)
  end

  test "step/1 with llm: true does not raise (high-salience path is fire-and-forget)" do
    assert {:ok, _summary} = Simulation.step(llm: true)
  end

  test "three-party gossip ripples a grudge to a soul who has never met the subject" do
    maya = Characters.get_character_by_slug!("maya")
    soren = Characters.get_character_by_slug!("soren")

    # Maya nurses a grudge against Soren.
    Relationships.create_relationship(%{
      source_character_id: maya.id,
      target_character_id: soren.id,
      anger: 70,
      affinity: -50
    })

    {:ok, summary} = Simulation.step()

    # Maya gossips about Soren to whoever she meets this tick.
    partner_slug =
      Enum.find_value(summary.encounters, fn e ->
        cond do
          e.a == "maya" -> e.b
          e.b == "maya" -> e.a
          true -> nil
        end
      end)

    assert partner_slug != nil
    partner = Characters.get_character_by_slug(partner_slug)

    rel = Relationships.get_relationship(partner.id, soren.id)
    assert rel != nil
    assert rel.affinity < 0
  end

  test "passive drift adjusts a wounded relationship" do
    maya = Characters.get_character_by_slug!("maya")
    ravina = Characters.get_character_by_slug!("ravina")

    {:ok, rel} =
      Relationships.create_relationship(%{
        source_character_id: maya.id,
        target_character_id: ravina.id,
        wound: 80,
        trust: 50,
        affinity: 0
      })

    assert {:ok, _summary} = Simulation.step()

    drifted = Relationships.get_relationship!(rel.id)
    assert drifted.trust < 50
    assert drifted.affinity < 0
  end
end
