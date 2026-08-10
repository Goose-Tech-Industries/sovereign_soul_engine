defmodule SovereignSoulEngine.Social.NPCScheduler do
  @moduledoc """
  GenServer that drives autonomous NPC social life.

  Every tick it:
    1. Regenerates social stamina for all active NPCs (capped at stamina_max)
    2. Runs passive relationship drift for all NPC-NPC pairs
    3. Selects one NPC pair for a full autonomous conversation (stamina permitting)
       — weighted toward pairs with high existing relationship scores and
         who haven't spoken recently

  Tick interval is configurable via `:sovereign_soul_engine, :social_tick_ms`.
  Default: 10 minutes. In test env it's not scheduled (call trigger_tick/0 directly).

  Token cost control:
    - Each conversation costs @stamina_cost from both NPCs' pools
    - Only one full conversation fires per tick (not all pairs at once)
    - NPCs below @stamina_threshold are skipped
    - Players currently active in a scene block their scene-mates from autonomous chat
  """

  use GenServer
  require Logger

  alias SovereignSoulEngine.{Relationships, Souls, Repo}
  alias SovereignSoulEngine.Social.{SocialDriftEngine, NPCConversation}
  alias SovereignSoulEngine.Relationships.Relationship

  import Ecto.Query

  @default_tick_ms :timer.minutes(10)
  @stamina_regen_per_tick 10
  @conversation_probability 0.4
  @player_active_window_minutes 30

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Manually trigger a tick (useful for testing and admin scripts)."
  def trigger_tick do
    GenServer.cast(__MODULE__, :tick)
  end

  @doc "Returns the scheduler's current state summary."
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(:ok) do
    if Mix.env() != :test do
      tick_ms = Application.get_env(:sovereign_soul_engine, :social_tick_ms, @default_tick_ms)
      Process.send_after(self(), :tick, tick_ms)
    end

    {:ok, %{tick_count: 0, last_tick_at: nil, conversations_run: 0}}
  end

  @impl true
  def handle_cast(:tick, state) do
    new_state = do_tick(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:tick, state) do
    new_state = do_tick(state)

    tick_ms = Application.get_env(:sovereign_soul_engine, :social_tick_ms, @default_tick_ms)
    Process.send_after(self(), :tick, tick_ms)

    {:noreply, new_state}
  end

  # --- Tick logic ---

  defp do_tick(state) do
    Logger.debug("NPCScheduler: tick #{state.tick_count + 1}")

    active_npcs = load_active_npcs()
    busy_npc_ids = load_busy_npc_ids()

    available_npcs = Enum.reject(active_npcs, &(&1.id in busy_npc_ids))

    regenerate_stamina(available_npcs)
    run_passive_drift(available_npcs)
    tick_somatic_states(available_npcs)
    advance_goals(available_npcs)
    tick_grief_arcs(available_npcs)
    tick_forgiveness_arcs(available_npcs)

    conversations_run =
      if :rand.uniform() < @conversation_probability do
        case pick_conversation_pair(available_npcs) do
          {npc_a, npc_b} ->
            Task.start(fn ->
              NPCConversation.run(npc_a.id, npc_b.id)
            end)
            Logger.info("NPCScheduler: triggered conversation #{npc_a.name} ↔ #{npc_b.name}")
            state.conversations_run + 1

          nil ->
            state.conversations_run
        end
      else
        state.conversations_run
      end

    %{state | tick_count: state.tick_count + 1, last_tick_at: DateTime.utc_now(), conversations_run: conversations_run}
  end

  # --- Stamina regeneration ---

  defp regenerate_stamina(npcs) do
    Enum.each(npcs, fn npc ->
      profile = Souls.get_soul_profile_by_character(npc.id)

      if profile do
        regen = profile.stamina_regen_rate || @stamina_regen_per_tick
        max_stamina = profile.stamina_max || 100
        current = profile.social_stamina || 80
        new_stamina = min(current + regen, max_stamina)

        if new_stamina != current do
          Souls.update_soul_profile(profile, %{social_stamina: new_stamina})
        end
      end
    end)
  end

  # --- Passive drift ---

  defp run_passive_drift(npcs) do
    npc_ids = Enum.map(npcs, & &1.id)

    npc_relationships =
      Repo.all(
        from r in Relationship,
          where: r.source_character_id in ^npc_ids and r.target_character_id in ^npc_ids
      )

    profiles =
      npc_ids
      |> Enum.map(fn id -> {id, Souls.get_soul_profile_by_character(id)} end)
      |> Enum.reject(fn {_id, p} -> is_nil(p) end)
      |> Map.new()

    Enum.each(npc_relationships, fn rel ->
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

  # --- Conversation pair selection ---

  defp pick_conversation_pair(npcs) when length(npcs) < 2, do: nil

  defp pick_conversation_pair(npcs) do
    scored_pairs =
      for npc_a <- npcs,
          npc_b <- npcs,
          npc_a.id < npc_b.id,
          NPCConversation.can_converse?(npc_a.id, npc_b.id) do
        rel_ab = Relationships.get_relationship(npc_a.id, npc_b.id)

        relationship_weight =
          cond do
            rel_ab && rel_ab.affinity > 50 -> 3
            rel_ab && rel_ab.anger > 60 -> 2
            not is_nil(rel_ab) -> 1
            true -> 0
          end

        recency_weight =
          case get_last_social_action(npc_a.id) do
            nil -> 3
            ts ->
              hours_ago = DateTime.diff(DateTime.utc_now(), ts, :second) / 3600
              cond do
                hours_ago > 2 -> 2
                hours_ago > 0.5 -> 1
                true -> 0
              end
          end

        {npc_a, npc_b, relationship_weight + recency_weight}
      end

    if scored_pairs == [] do
      nil
    else
      {npc_a, npc_b, _score} = Enum.max_by(scored_pairs, fn {_, _, s} -> s end)
      {npc_a, npc_b}
    end
  end

  # --- Player activity check ---

  defp load_busy_npc_ids do
    cutoff = DateTime.add(DateTime.utc_now(), -@player_active_window_minutes * 60, :second)

    Repo.all(
      from sp in SovereignSoulEngine.Scenes.SceneParticipant,
        join: s in assoc(sp, :scene),
        join: msg in assoc(s, :messages),
        join: player_part in assoc(s, :participants),
        join: player_char in assoc(player_part, :character),
        where:
          s.status == "active" and
            s.is_autonomous == false and
            player_char.kind == "player" and
            msg.inserted_at >= ^cutoff,
        select: sp.character_id,
        distinct: true
    )
  end

  # --- Helpers ---

  defp load_active_npcs do
    Repo.all(
      from c in SovereignSoulEngine.Characters.Character,
        where: c.kind == "npc" and c.status == "active"
    )
  end

  defp get_last_social_action(character_id) do
    profile = Souls.get_soul_profile_by_character(character_id)
    profile && profile.last_social_action_at
  end

  defp clamp(val, min, max) do
    val |> max(min) |> min(max)
  end

  defp tick_somatic_states(npcs) do
    Enum.each(npcs, fn npc ->
      somatic = Souls.get_somatic_state_by_character(npc.id)

      if somatic do
        now = DateTime.utc_now()
        tick_ms = Application.get_env(:sovereign_soul_engine, :social_tick_ms, @default_tick_ms)
        tick_window_seconds = div(tick_ms, 1000)

        was_rested_recently =
          somatic.last_rested_at &&
            DateTime.diff(now, somatic.last_rested_at, :second) < tick_window_seconds

        new_hunger = min((somatic.hunger || 0) + 3, 100)
        new_fatigue_raw = (somatic.fatigue || 20) + 2
        new_fatigue =
          if was_rested_recently,
            do: max(new_fatigue_raw - 10, 0),
            else: min(new_fatigue_raw, 100)
        new_pain = max((somatic.pain || 0) - 2, 0)
        new_illness = max((somatic.illness_severity || 0) - 1, 0)

        Souls.update_somatic_state(somatic, %{
          hunger: new_hunger,
          fatigue: new_fatigue,
          pain: new_pain,
          illness_severity: new_illness
        })
      end
    end)
  end

  defp advance_goals(npcs) do
    # CharacterGoal uses timestamps() with no :type option, so updated_at
    # is a NaiveDateTime — comparing it with DateTime.compare/2 (which
    # requires both args to be actual DateTimes) crashed this every tick
    # with a FunctionClauseError, before the scheduler ever reached the
    # actual conversation-selection step below. NaiveDateTime.compare/2
    # matches the field's real type.
    two_hours_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -2 * 3600, :second)

    Enum.each(npcs, fn npc ->
      active_goals = Souls.list_active_goals_for_character(npc.id)

      # Only advance 1 goal per NPC per tick
      goal_to_advance =
        Enum.find(active_goals, fn g ->
          g.blocker == nil and
            NaiveDateTime.compare(g.updated_at, two_hours_ago) == :lt
        end)

      if goal_to_advance do
        Souls.update_goal(goal_to_advance, %{
          progress_notes: "Autonomous progress: step underway as of #{DateTime.utc_now() |> DateTime.to_iso8601()}"
        })
      end
    end)
  end

  defp tick_grief_arcs(npcs) do
    four_hours_ago = DateTime.add(DateTime.utc_now(), -4 * 3600, :second)

    Enum.each(npcs, fn npc ->
      active_arcs = Souls.list_active_grief_arcs_for_character(npc.id)

      Enum.each(active_arcs, fn arc ->
        should_progress =
          (arc.last_progressed_at == nil or
             DateTime.compare(arc.last_progressed_at, four_hours_ago) == :lt) and
            arc.intensity > 0

        if should_progress do
          case Souls.progress_grief_arc(arc) do
            {:ok, updated} ->
              if updated.stage == "integration" and updated.intensity < 20 do
                Souls.update_grief_arc(updated, %{is_resolved: true})
              end
            _ -> :ok
          end
        end
      end)
    end)
  end

  defp tick_forgiveness_arcs(npcs) do
    Enum.each(npcs, fn npc ->
      active_arcs = Souls.list_active_forgiveness_arcs_for_character(npc.id)

      Enum.each(active_arcs, fn arc ->
        {new_intensity, new_stage} =
          case arc.direction do
            "healing" ->
              ni = max(arc.intensity - 2, 0)
              ns = if ni < 30 and arc.stage not in ["forgiven"] do
                advance_forgiveness_stage(arc.stage, :healing)
              else
                arc.stage
              end
              {ni, ns}

            "hardening" ->
              ni = min(arc.intensity + 1, 95)
              ns = if ni > 70 and arc.stage not in ["hardened"] do
                advance_forgiveness_stage(arc.stage, :hardening)
              else
                arc.stage
              end
              {ni, ns}

            _ ->
              # neutral: slow fade
              {max(arc.intensity - 1, 0), arc.stage}
          end

        if new_intensity != arc.intensity or new_stage != arc.stage do
          Souls.update_forgiveness_arc(arc, %{intensity: new_intensity, stage: new_stage})
        end
      end)
    end)
  end

  defp advance_forgiveness_stage(current_stage, :healing) do
    stages = ~w(fresh festering processing forgiven)
    idx = Enum.find_index(stages, &(&1 == current_stage)) || 0
    Enum.at(stages, idx + 1, "forgiven")
  end

  defp advance_forgiveness_stage(current_stage, :hardening) do
    stages = ~w(fresh festering hardened)
    idx = Enum.find_index(stages, &(&1 == current_stage)) || 0
    Enum.at(stages, idx + 1, "hardened")
  end
end
