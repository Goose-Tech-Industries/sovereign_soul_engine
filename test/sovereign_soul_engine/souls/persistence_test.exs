defmodule SovereignSoulEngine.Souls.PersistenceTest do
  use SovereignSoulEngine.DataCase, async: false
  alias SovereignSoulEngine.{Characters, Souls, Relationships}

  defp character(name \\ "Keeper") do
    {:ok, c} =
      Characters.create_character(%{
        name: name,
        slug: Ecto.UUID.generate(),
        kind: "npc",
        status: "active"
      })

    c
  end

  for {kind, attrs, field, value} <- [
        {:belief, %{belief: "Keep promises", domain: "social"}, :conviction, 82},
        {:trigger, %{topic: "thunder", reaction_type: "anger_spike"}, :intensity_modifier, 72},
        {:desire, %{desire: "Learn", domain: "knowledge"}, :urgency, 91},
        {:secret, %{secret_text: "Hidden oath"}, :risk_level, "critical"},
        {:moral_line, %{principle: "Do no harm"}, :principle, "Protect guests"}
      ] do
    test "#{kind} persists updates, rejects invalid data, and isolates characters" do
      c = character()
      other = character("Other")
      kind = unquote(kind)
      attrs = unquote(Macro.escape(attrs))
      create = String.to_atom("create_#{kind}")
      update = String.to_atom("update_#{kind}")
      get = String.to_atom("get_#{kind}!")
      list = String.to_atom("list_#{kind}s_for_character")
      assert {:error, invalid} = apply(Souls, create, [%{}])
      refute invalid.valid?
      assert {:ok, item} = apply(Souls, create, [Map.put(attrs, :character_id, c.id)])
      assert {:ok, changed} = apply(Souls, update, [item, %{unquote(field) => unquote(value)}])
      assert Map.fetch!(apply(Souls, get, [item.id]), unquote(field)) == unquote(value)
      assert [^changed] = apply(Souls, list, [c.id])
      assert [] = apply(Souls, list, [other.id])
      assert_raise Ecto.NoResultsError, fn -> apply(Souls, get, [Ecto.UUID.generate()]) end
    end
  end

  test "profile and emotional state accessors preserve persisted values after invalid updates" do
    c = character()
    assert {:ok, profile} = Souls.create_soul_profile(%{character_id: c.id})
    assert Souls.get_soul_profile!(profile.id) == profile
    assert Souls.get_soul_profile_by_character!(c.id) == profile
    assert Souls.change_soul_profile(profile).valid?
    assert {:ok, state} = Souls.create_emotional_state(%{character_id: c.id, anger: 25})
    assert Souls.get_emotional_state!(state.id) == state
    assert Souls.get_emotional_state_by_character!(c.id) == state
    assert Souls.change_emotional_state(state).valid?
    assert {:error, _} = Souls.update_emotional_state(state, %{anger: 101})
    assert Souls.get_emotional_state!(state.id).anger == 25
    assert Souls.get_emotional_state_by_character(Ecto.UUID.generate()) == nil
    assert Souls.ensure_soul_vitality(Ecto.UUID.generate()) == nil
  end

  test "active desires and high-risk secrets filter by status and owner" do
    c = character()

    for {status, urgency} <- [
          {"active", 10},
          {"pursuing", 90},
          {"resolved", 100},
          {"blocked", 99}
        ] do
      {:ok, _} =
        Souls.create_desire(%{
          character_id: c.id,
          desire: status,
          domain: "safety",
          status: status,
          urgency: urgency
        })
    end

    assert Enum.map(Souls.list_active_desires_for_character(c.id), & &1.status) == [
             "pursuing",
             "active"
           ]

    for risk <- ~w(low medium high critical) do
      {:ok, _} = Souls.create_secret(%{character_id: c.id, secret_text: risk, risk_level: risk})
    end

    assert Enum.sort(Enum.map(Souls.list_high_risk_secrets_for_character(c.id), & &1.risk_level)) ==
             ["critical", "high"]
  end

  test "fear resolution removes only the resolved fear from active queries" do
    c = character()
    {:ok, fear} = Souls.create_soul_fear(%{character_id: c.id, fear_type: "abandonment"})
    assert [^fear] = Souls.list_soul_fears_for_character(c.id)
    assert {:ok, _} = Souls.update_soul_fear(fear, %{status: "resolved"})
    assert Souls.list_soul_fears_for_character(c.id) == []
  end

  test "grief progresses through stages, floors intensity, and excludes resolved arcs" do
    c = character()

    {:ok, arc} =
      Souls.create_grief_arc(%{
        character_id: c.id,
        subject: "Home",
        intensity: 29,
        triggered_at: DateTime.utc_now()
      })

    arc =
      Enum.reduce(~w(anger bargaining depression integration), arc, fn stage, arc ->
        {:ok, next} = Souls.progress_grief_arc(arc)
        assert next.stage == stage
        assert next.intensity == arc.intensity - 3
        assert %DateTime{} = next.last_progressed_at
        next
      end)

    {:ok, arc} = Souls.update_grief_arc(arc, %{intensity: 1})
    {:ok, arc} = Souls.progress_grief_arc(arc)
    assert arc.intensity == 0
    assert arc.stage == "integration"
    {:ok, _} = Souls.update_grief_arc(arc, %{is_resolved: true})
    assert Souls.list_active_grief_arcs_for_character(c.id) == []
  end

  test "transaction rollback removes soul writes" do
    c = character()

    assert {:error, :cancelled} =
             Repo.transaction(fn ->
               {:ok, _} = Souls.create_goal(%{character_id: c.id, goal: "Cancelled"})
               {:ok, _} = Souls.create_somatic_state(%{character_id: c.id})
               Repo.rollback(:cancelled)
             end)

    assert Souls.list_active_goals_for_character(c.id) == []
    assert Souls.get_somatic_state_by_character(c.id) == nil
    somatic = Souls.get_or_create_somatic_state(c.id)
    assert Souls.get_or_create_somatic_state(c.id).id == somatic.id
  end

  test "death creates grief for close active NPCs and reputation averages inbound relationships" do
    dead = character("Departed")
    friend = character("Friend")
    distant = character("Distant")

    for {c, trust, affinity} <- [{friend, 90, 90}, {distant, 10, -20}] do
      {:ok, _} =
        Relationships.create_relationship(%{
          source_character_id: c.id,
          target_character_id: dead.id,
          relationship_type: "friend",
          trust: trust,
          affinity: affinity
        })
    end

    reputation = Souls.reputation_for_character(dead.id)
    assert reputation.relationship_count == 2
    assert reputation.avg_trust == 50
    assert reputation.avg_affinity == 35
    assert Souls.reputation_for_character(friend.id).relationship_count == 0
    assert {:ok, %{status: "dead"}} = Souls.notify_character_death(dead.id)

    assert [%{subject: "Departed", intensity: 90}] =
             Souls.list_active_grief_arcs_for_character(friend.id)

    assert [] = Souls.list_active_grief_arcs_for_character(distant.id)
  end
end
