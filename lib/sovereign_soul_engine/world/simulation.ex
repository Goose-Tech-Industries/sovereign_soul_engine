defmodule SovereignSoulEngine.World.Simulation do
  @moduledoc """
  Hermetic (no-LLM) autonomous simulation of the Soul Society world scene.

  A step regenerates social stamina, matches the pilot cohort of souls who are
  "in the square" (their `IntentEngine` disposition is social), and runs
  deterministic encounters: `MeshProtocol` resonance → relationship update →
  memory → signed world event. The LLM is reserved for high-salience moments via
  the `:llm` option, which routes a high-resonance pair through
  `NPCConversation`.

  This is the counterpart to `NPCScheduler`: that drives the general NPC
  population (drift + occasional LLM conversation); this drives the always-on
  world scene with zero inference cost.
  """

  use GenServer

  alias SovereignSoulEngine.{Characters, Identity, Memories, Relationships, Souls, World}
  alias SovereignSoulEngine.Souls.IntentEngine
  alias SovereignSoulEngine.Social.{MeshProtocol, NPCConversation}

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
    regenerate_stamina(souls)

    encounters =
      souls
      |> Enum.filter(&eligible?/1)
      |> pair_up()
      |> Enum.map(fn {a, b} -> encounter(a, b, opts) end)

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

  defp encounter(a, b, opts) do
    cond do
      not can_meet?(a) or not can_meet?(b) ->
        %{a: a.slug, b: b.slug, outcome: :insufficient_stamina}

      true ->
        resonance = MeshProtocol.compute_resonance(a, b)
        delta = relationship_delta(resonance)

        apply_relationship(a, b, delta)
        record_memory(a, b, resonance)
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

  defp clamp_dim(:affinity, v), do: v |> max(-100) |> min(100)
  defp clamp_dim(_dim, v), do: v |> max(0) |> min(100)
end
