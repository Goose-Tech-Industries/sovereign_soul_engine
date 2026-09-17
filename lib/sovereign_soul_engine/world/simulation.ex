defmodule SovereignSoulEngine.World.Simulation do
  @moduledoc """
  Hermetic (no-LLM) autonomous simulation of the Soul Society world scene.

  A step regenerates social stamina, matches the pilot cohort of souls who are
  "in the square" (their `IntentEngine` disposition is social), and runs
  deterministic encounters: `MeshProtocol` resonance → relationship update →
  memory → three-party gossip → signed world event. A passive drift pass then
  adjusts every cohort relationship by value/wound compatibility.

  The LLM is reserved for high-salience moments via the `:llm` option, which
  routes a high-resonance pair through `NPCConversation`.
  """

  use GenServer

  alias SovereignSoulEngine.{Characters, Identity, Memories, Relationships, Repo, Souls, World}
  alias SovereignSoulEngine.Relationships.Relationship
  alias SovereignSoulEngine.Souls.IntentEngine

  alias SovereignSoulEngine.Social.{
    GossipNetwork,
    MeshProtocol,
    NPCConversation,
    SocialDriftEngine
  }

  import Ecto.Query, warn: false

  @pilot_slugs ~w(maya ravina valeria corvus quill soren)
  @stamina_threshold 30
  @stamina_cost 20
  @stamina_regen 10
  @social_intents ~w(wander seek)
  @default_tick_ms :timer.minutes(10)

  # --- Public API -------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "The pilot cohort's slugs (the first souls to live in the world)."
  def pilot_slugs, do: @pilot_slugs

  @doc "Manually trigger a simulation step (test/admin)."
  def trigger_step, do: GenServer.cast(__MODULE__, :step)

  @doc "Runs one simulation step synchronously. Returns `{:ok, summary}`."
  def step(opts \\ []) do
    {:ok, do_step(opts)}
  end

  # --- GenServer callbacks ----------------------------------------------------

  @impl true
  def init(:ok) do
    if Mix.env() != :test do
      tick_ms = Application.get_env(:sovereign_soul_engine, :world_sim_tick_ms, @default_tick_ms)
      Process.send_after(self(), :step, tick_ms)
    end

    {:ok, %{steps: 0}}
  end

  @impl true
  def handle_cast(:step, state) do
    _ = do_step([])
    {:noreply, %{state | steps: state.steps + 1}}
  end

  @impl true
  def handle_info(:step, state) do
    _ = do_step([])
    tick_ms = Application.get_env(:sovereign_soul_engine, :world_sim_tick_ms, @default_tick_ms)
    Process.send_after(self(), :step, tick_ms)
    {:noreply, %{state | steps: state.steps + 1}}
  end

  # --- Step logic -------------------------------------------------------------

  defp do_step(opts) do
    souls = load_pilot()
    cohort_ids = Enum.map(souls, & &1.id)
    regenerate_stamina(souls)

    encounters =
      souls
      |> Enum.filter(&eligible?/1)
      |> pair_up()
      |> Enum.map(fn {a, b} -> encounter(a, b, cohort_ids, opts) end)

    run_drift(souls)

    %{souls: length(souls), encounters: encounters}
  end

  # A soul is eligible to meet when it is "in the square" (social intent) and has
  # enough social stamina.
  defp eligible?(char) do
    in_the_square?(char) and can_meet?(char)
  end

  defp in_the_square?(char) do
    emotional = Souls.get_emotional_state_by_character(char.id)
    somatic = Souls.get_somatic_state_by_character(char.id)
    IntentEngine.decide(emotional, somatic).intent in @social_intents
  end

  defp can_meet?(char) do
    case Souls.get_soul_profile_by_character(char.id) do
      nil -> false
      profile -> (profile.social_stamina || 80) >= @stamina_threshold
    end
  end

  defp load_pilot do
    Enum.flat_map(@pilot_slugs, fn slug ->
      case Characters.get_character_by_slug(slug) do
        nil -> []
        char -> [char]
      end
    end)
  end

  defp pair_up(souls) when length(souls) < 2, do: []

  defp pair_up(souls) do
    souls
    |> Enum.sort_by(& &1.slug)
    |> Enum.chunk_every(2, 2, :discard)
    |> Enum.map(fn [a, b] -> {a, b} end)
  end

  defp regenerate_stamina(souls) do
    Enum.each(souls, fn soul ->
      profile = Souls.get_soul_profile_by_character(soul.id)

      if profile do
        new_stamina =
          min((profile.social_stamina || 80) + @stamina_regen, profile.stamina_max || 100)

        if new_stamina != profile.social_stamina do
          Souls.update_soul_profile(profile, %{social_stamina: new_stamina})
        end
      end
    end)
  end

  # --- Hermetic encounter -----------------------------------------------------

  defp encounter(a, b, cohort_ids, opts) do
    cond do
      not can_meet?(a) or not can_meet?(b) ->
        %{a: a.slug, b: b.slug, outcome: :insufficient_stamina}

      true ->
        resonance = MeshProtocol.compute_resonance(a, b)
        delta = relationship_delta(resonance)

        apply_relationship(a, b, delta)
        record_memory(a, b, resonance)
        gossip_between(a, b, cohort_ids)
        drain_stamina(a)
        drain_stamina(b)
        record_world_event(a, b, resonance)
        maybe_llm_conversation(a, b, resonance, opts)

        %{a: a.slug, b: b.slug, outcome: :encountered, resonance: resonance, delta: delta}
    end
  end

  defp relationship_delta(resonance) do
    cond do
      resonance >= 80 -> %{affinity: 5, trust: 4, respect: 3}
      resonance >= 55 -> %{affinity: 2, trust: 1, respect: 1}
      resonance >= 30 -> %{affinity: 1}
      true -> %{affinity: -2, fear: 2, anger: 1}
    end
  end

  defp apply_relationship(a, b, delta) do
    case Relationships.get_relationship(a.id, b.id) do
      nil ->
        base = %{
          source_character_id: a.id,
          target_character_id: b.id,
          relationship_type: "acquaintance",
          last_interaction_at: DateTime.utc_now()
        }

        attrs = Enum.reduce(delta, base, fn {k, v}, acc -> Map.put(acc, k, clamp_dim(k, v)) end)
        Relationships.create_relationship(attrs)

      rel ->
        attrs =
          Enum.reduce(delta, %{}, fn {k, v}, acc ->
            Map.put(acc, k, clamp_dim(k, (Map.get(rel, k) || 0) + v))
          end)
          |> Map.put(:last_interaction_at, DateTime.utc_now())

        Relationships.update_relationship(rel, attrs)
    end
  end

  defp record_memory(a, b, resonance) do
    Memories.create_memory(%{
      owner_character_id: a.id,
      subject_character_id: b.id,
      category: "relationship",
      summary: "Encountered #{b.name} in the Soul Society.",
      emotional_intensity: resonance,
      valence: if(resonance >= 55, do: 0.4, else: -0.2),
      importance: 30,
      tags: ["world", "encounter", b.slug],
      occurred_at: DateTime.utc_now()
    })
  end

  defp drain_stamina(char) do
    profile = Souls.get_soul_profile_by_character(char.id)

    if profile do
      Souls.update_soul_profile(profile, %{
        social_stamina: max((profile.social_stamina || 80) - @stamina_cost, 0)
      })
    end
  end

  defp record_world_event(a, b, resonance) do
    World.append_event(%{
      kind: "encounter",
      from_did: did_of(a),
      to_did: did_of(b),
      payload: %{"resonance" => resonance},
      signature: nil
    })
  end

  defp did_of(char) do
    case Identity.get_did_for_character(char.id) do
      nil -> char.slug
      soul_did -> soul_did.did
    end
  end

  defp maybe_llm_conversation(a, b, resonance, opts) do
    if Keyword.get(opts, :llm, false) and resonance >= 70 do
      Task.start(fn -> NPCConversation.run(a.id, b.id) end)
    end

    :ok
  end

  # --- Three-party gossip -----------------------------------------------------

  # When A meets B, A shares their most salient opinion about a third party C.
  defp gossip_between(a, b, cohort_ids) do
    gossip_one(a, b, cohort_ids)
    gossip_one(b, a, cohort_ids)
    :ok
  end

  defp gossip_one(speaker, listener, cohort_ids) do
    case most_salient_third_party(speaker, listener, cohort_ids) do
      nil ->
        :ok

      {subject, event_type, intensity} ->
        GossipNetwork.propagate(speaker.id, listener.id, subject.id, %{
          event_type: event_type,
          summary: gossip_summary(event_type, subject),
          intensity: intensity
        })
    end
  end

  defp most_salient_third_party(speaker, listener, cohort_ids) do
    speaker.id
    |> Relationships.list_relationships_for_source()
    |> Enum.filter(fn rel ->
      rel.target_character_id in cohort_ids and rel.target_character_id != listener.id
    end)
    |> Enum.map(fn rel -> {rel, salience_and_type(rel)} end)
    |> Enum.reject(fn {_rel, {salience, _type}} -> is_nil(salience) end)
    |> Enum.max_by(fn {_rel, {salience, _type}} -> salience end, fn -> nil end)
    |> case do
      nil ->
        nil

      {rel, {_salience, event_type}} ->
        subject = Characters.get_character(rel.target_character_id)
        {subject, event_type, gossip_intensity(rel)}
    end
  end

  defp salience_and_type(rel) do
    anger = rel.anger || 0
    fear = rel.fear || 0
    affinity = rel.affinity || 0
    wound = rel.wound || 0

    cond do
      wound >= 60 -> {wound + anger, :betrayed_me}
      anger >= 60 -> {anger, :insulted_me}
      fear >= 60 -> {fear, :threatened_me}
      affinity <= -40 -> {abs(affinity), :betrayed_me}
      affinity >= 60 -> {affinity, :praised_me}
      true -> {nil, nil}
    end
  end

  defp gossip_intensity(rel) do
    max(max(rel.anger || 0, rel.fear || 0), abs(rel.affinity || 0))
  end

  defp gossip_summary(:insulted_me, subject), do: "#{subject.name} has been difficult lately"
  defp gossip_summary(:betrayed_me, subject), do: "#{subject.name} cannot be trusted"
  defp gossip_summary(:threatened_me, subject), do: "#{subject.name} is dangerous"
  defp gossip_summary(:praised_me, subject), do: "#{subject.name} has earned great respect"

  # --- Passive drift ----------------------------------------------------------

  defp run_drift(souls) do
    ids = Enum.map(souls, & &1.id)

    rels =
      Repo.all(
        from r in Relationship,
          where: r.source_character_id in ^ids and r.target_character_id in ^ids
      )

    profiles =
      ids
      |> Enum.map(fn id -> {id, Souls.get_soul_profile_by_character(id)} end)
      |> Enum.reject(fn {_id, p} -> is_nil(p) end)
      |> Map.new()

    Enum.each(rels, fn rel ->
      profile_a = Map.get(profiles, rel.source_character_id)
      profile_b = Map.get(profiles, rel.target_character_id)

      if profile_a && profile_b do
        deltas = SocialDriftEngine.compute_drift(profile_a, profile_b, rel)
        apply_drift(rel, deltas)
      end
    end)
  end

  defp apply_drift(rel, deltas) do
    new_trust = clamp(rel.trust + Map.get(deltas, :trust, 0), 0, 100)
    new_affinity = clamp(rel.affinity + Map.get(deltas, :affinity, 0), -100, 100)
    new_anger = clamp(rel.anger + Map.get(deltas, :anger, 0), 0, 100)

    if new_trust != rel.trust or new_affinity != rel.affinity or new_anger != rel.anger do
      Relationships.update_relationship(rel, %{
        trust: new_trust,
        affinity: new_affinity,
        anger: new_anger
      })
    end
  end

  defp clamp_dim(:affinity, v), do: v |> max(-100) |> min(100)
  defp clamp_dim(_dim, v), do: v |> max(0) |> min(100)
  defp clamp(v, min, max), do: v |> max(min) |> min(max)
end
