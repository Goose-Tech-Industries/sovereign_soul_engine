defmodule SovereignSoulEngine.Souls do
  @moduledoc """
  Context for managing Soul Profiles, Emotional States, Beliefs, Triggers,
  Desires, Secrets, and Moral Lines.
  """

  import Ecto.Query

  alias SovereignSoulEngine.Souls.{SoulProfile, EmotionalState, SoulShadow, SoulFear, MoralLine, SomaticState, GriefArc, ForgivenessArc}
  alias SovereignSoulEngine.Goals.CharacterGoal
  alias SovereignSoulEngine.Beliefs.CharacterBelief
  alias SovereignSoulEngine.Triggers.CharacterTrigger
  alias SovereignSoulEngine.Desires.SoulDesire
  alias SovereignSoulEngine.Secrets.CharacterSecret
  alias SovereignSoulEngine.Relationships.Relationship
  alias SovereignSoulEngine.Repo

  # Soul Profiles

  def get_soul_profile!(id), do: Repo.get!(SoulProfile, id)

  def get_soul_profile_by_character(character_id) do
    Repo.get_by(SoulProfile, character_id: character_id)
  end

  def get_soul_profile_by_character!(character_id) do
    Repo.get_by!(SoulProfile, character_id: character_id)
  end

  def create_soul_profile(attrs \\ %{}) do
    %SoulProfile{}
    |> SoulProfile.changeset(attrs)
    |> Repo.insert()
  end

  def update_soul_profile(%SoulProfile{} = profile, attrs) do
    profile
    |> SoulProfile.changeset(attrs)
    |> Repo.update()
  end

  def change_soul_profile(%SoulProfile{} = profile, attrs \\ %{}) do
    SoulProfile.changeset(profile, attrs)
  end

  # Emotional States

  def get_emotional_state!(id), do: Repo.get!(EmotionalState, id)

  def get_emotional_state_by_character(character_id) do
    Repo.get_by(EmotionalState, character_id: character_id)
  end

  def get_emotional_state_by_character!(character_id) do
    Repo.get_by!(EmotionalState, character_id: character_id)
  end

  def create_emotional_state(attrs \\ %{}) do
    %EmotionalState{}
    |> EmotionalState.changeset(attrs)
    |> Repo.insert()
  end

  def update_emotional_state(%EmotionalState{} = state, attrs) do
    state
    |> EmotionalState.changeset(attrs)
    |> Repo.update()
  end

  def change_emotional_state(%EmotionalState{} = state, attrs \\ %{}) do
    EmotionalState.changeset(state, attrs)
  end

  # Soul Shadows

  def create_soul_shadow(attrs \\ %{}) do
    %SoulShadow{}
    |> SoulShadow.changeset(attrs)
    |> Repo.insert()
  end

  def list_soul_shadows_for_character(character_id) do
    Repo.all(
      from s in SoulShadow,
        where: s.character_id == ^character_id,
        order_by: [desc: s.inserted_at]
    )
  end

  # Soul Fears

  def create_soul_fear(attrs \\ %{}) do
    %SoulFear{}
    |> SoulFear.changeset(attrs)
    |> Repo.insert()
  end

  def list_soul_fears_for_character(character_id) do
    Repo.all(
      from f in SoulFear,
        where: f.character_id == ^character_id and f.status == "active",
        order_by: [desc: f.inserted_at]
    )
  end

  def update_soul_fear(%SoulFear{} = soul_fear, attrs) do
    soul_fear
    |> SoulFear.changeset(attrs)
    |> Repo.update()
  end

  # Character Beliefs

  def list_beliefs_for_character(character_id) do
    Repo.all(
      from b in CharacterBelief,
        where: b.character_id == ^character_id,
        order_by: [desc: b.conviction]
    )
  end

  def get_belief!(id), do: Repo.get!(CharacterBelief, id)

  def create_belief(attrs \\ %{}) do
    %CharacterBelief{}
    |> CharacterBelief.changeset(attrs)
    |> Repo.insert()
  end

  def update_belief(%CharacterBelief{} = belief, attrs) do
    belief
    |> CharacterBelief.changeset(attrs)
    |> Repo.update()
  end

  # Character Triggers

  def list_triggers_for_character(character_id) do
    Repo.all(
      from t in CharacterTrigger,
        where: t.character_id == ^character_id,
        order_by: [desc: t.intensity_modifier]
    )
  end

  def get_trigger!(id), do: Repo.get!(CharacterTrigger, id)

  def create_trigger(attrs \\ %{}) do
    %CharacterTrigger{}
    |> CharacterTrigger.changeset(attrs)
    |> Repo.insert()
  end

  def update_trigger(%CharacterTrigger{} = trigger, attrs) do
    trigger
    |> CharacterTrigger.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deterministic relevance gate for ambient/group chat — would this NPC
  even notice a message not addressed to them directly? An NPC is
  "interested" if their name is mentioned, or the message touches one of
  their configured trigger topics. No LLM call, no cost, defaults to
  false: a shop NPC standing nearby shouldn't chime in on every line
  two players exchange, only when something actually concerns them.
  """
  def interested_in_message?(%SovereignSoulEngine.Characters.Character{} = npc, message) do
    lower_message = String.downcase(message)

    name_mentioned? =
      npc.name
      |> String.split(~r/\s+/, trim: true)
      |> Enum.filter(&(String.length(&1) > 2))
      |> Enum.any?(&String.contains?(lower_message, String.downcase(&1)))

    trigger_matched? =
      npc.id
      |> list_triggers_for_character()
      |> Enum.any?(&String.contains?(lower_message, String.downcase(&1.topic)))

    name_mentioned? or trigger_matched?
  end

  # Soul Desires

  def list_desires_for_character(character_id) do
    Repo.all(
      from d in SoulDesire,
        where: d.character_id == ^character_id,
        order_by: [desc: d.urgency]
    )
  end

  def list_active_desires_for_character(character_id) do
    Repo.all(
      from d in SoulDesire,
        where: d.character_id == ^character_id and d.status in ["active", "pursuing"],
        order_by: [desc: d.urgency]
    )
  end

  def get_desire!(id), do: Repo.get!(SoulDesire, id)

  def create_desire(attrs \\ %{}) do
    %SoulDesire{}
    |> SoulDesire.changeset(attrs)
    |> Repo.insert()
  end

  def update_desire(%SoulDesire{} = desire, attrs) do
    desire
    |> SoulDesire.changeset(attrs)
    |> Repo.update()
  end

  # Character Secrets

  def list_secrets_for_character(character_id) do
    Repo.all(
      from s in CharacterSecret,
        where: s.character_id == ^character_id,
        order_by: [asc: s.inserted_at]
    )
  end

  def list_high_risk_secrets_for_character(character_id) do
    Repo.all(
      from s in CharacterSecret,
        where: s.character_id == ^character_id and s.risk_level in ["high", "critical"],
        order_by: [asc: s.inserted_at]
    )
  end

  def get_secret!(id), do: Repo.get!(CharacterSecret, id)

  def create_secret(attrs \\ %{}) do
    %CharacterSecret{}
    |> CharacterSecret.changeset(attrs)
    |> Repo.insert()
  end

  def update_secret(%CharacterSecret{} = secret, attrs) do
    secret
    |> CharacterSecret.changeset(attrs)
    |> Repo.update()
  end

  # Moral Lines

  def list_moral_lines_for_character(character_id) do
    Repo.all(
      from m in MoralLine,
        where: m.character_id == ^character_id,
        order_by: [asc: m.inserted_at]
    )
  end

  def get_moral_line!(id), do: Repo.get!(MoralLine, id)

  def create_moral_line(attrs \\ %{}) do
    %MoralLine{}
    |> MoralLine.changeset(attrs)
    |> Repo.insert()
  end

  def update_moral_line(%MoralLine{} = moral_line, attrs) do
    moral_line
    |> MoralLine.changeset(attrs)
    |> Repo.update()
  end

  # Somatic States

  def get_somatic_state_by_character(character_id) do
    Repo.get_by(SomaticState, character_id: character_id)
  end

  def get_or_create_somatic_state(character_id) do
    case get_somatic_state_by_character(character_id) do
      nil ->
        {:ok, state} = create_somatic_state(%{character_id: character_id})
        state
      state -> state
    end
  end

  def create_somatic_state(attrs \\ %{}) do
    %SomaticState{}
    |> SomaticState.changeset(attrs)
    |> Repo.insert()
  end

  def update_somatic_state(%SomaticState{} = somatic, attrs) do
    somatic
    |> SomaticState.changeset(attrs)
    |> Repo.update()
  end

  # Grief Arcs

  def list_active_grief_arcs_for_character(character_id) do
    Repo.all(
      from g in GriefArc,
        where: g.character_id == ^character_id and g.is_resolved == false,
        order_by: [desc: g.intensity]
    )
  end

  def create_grief_arc(attrs \\ %{}) do
    %GriefArc{}
    |> GriefArc.changeset(attrs)
    |> Repo.insert()
  end

  def update_grief_arc(%GriefArc{} = arc, attrs) do
    arc
    |> GriefArc.changeset(attrs)
    |> Repo.update()
  end

  @grief_stage_order ~w(denial anger bargaining depression integration)

  def progress_grief_arc(%GriefArc{} = arc) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    new_intensity = max(arc.intensity - 3, 0)

    if new_intensity < 30 and arc.stage != "integration" do
      current_index = Enum.find_index(@grief_stage_order, &(&1 == arc.stage)) || 0
      next_stage = Enum.at(@grief_stage_order, current_index + 1, "integration")

      update_grief_arc(arc, %{
        intensity: new_intensity,
        stage: next_stage,
        last_progressed_at: now
      })
    else
      update_grief_arc(arc, %{intensity: new_intensity, last_progressed_at: now})
    end
  end

  # Forgiveness Arcs

  def list_active_forgiveness_arcs_for_character(character_id) do
    Repo.all(
      from f in ForgivenessArc,
        where: f.character_id == ^character_id and f.stage not in ["forgiven", "hardened"],
        order_by: [desc: f.intensity]
    )
  end

  def create_forgiveness_arc(attrs \\ %{}) do
    %ForgivenessArc{}
    |> ForgivenessArc.changeset(attrs)
    |> Repo.insert()
  end

  def update_forgiveness_arc(%ForgivenessArc{} = arc, attrs) do
    arc
    |> ForgivenessArc.changeset(attrs)
    |> Repo.update()
  end

  # Character Goals

  def list_active_goals_for_character(character_id) do
    Repo.all(
      from g in CharacterGoal,
        where: g.character_id == ^character_id and g.status == "active",
        order_by: [desc: g.priority]
    )
  end

  def create_goal(attrs \\ %{}) do
    %CharacterGoal{}
    |> CharacterGoal.changeset(attrs)
    |> Repo.insert()
  end

  def update_goal(%CharacterGoal{} = goal, attrs) do
    goal
    |> CharacterGoal.changeset(attrs)
    |> Repo.update()
  end

  # Death notification

  def notify_character_death(dead_character_id) do
    alias SovereignSoulEngine.{Relationships, Characters}

    relationships = Relationships.list_relationships_for_target(dead_character_id)
    dead_char = Characters.get_character!(dead_character_id)

    Enum.each(relationships, fn rel ->
      griever = Characters.get_character!(rel.source_character_id)

      if griever.kind == "npc" and griever.status == "active" do
        intensity = min(div((rel.trust || 0) + max((rel.affinity || 0), 0), 2), 90)

        if intensity > 20 do
          create_grief_arc(%{
            character_id: griever.id,
            subject: dead_char.name,
            loss_type: "person",
            stage: "denial",
            intensity: intensity,
            triggered_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })
        end
      end
    end)

    Characters.update_character(dead_char, %{status: "dead"})
  end

  # Reputation

  @doc """
  Derives a character's reputation as perceived by others by aggregating all
  relationships where target_character_id = character_id.
  Returns %{avg_trust, avg_respect, avg_fear, avg_affinity, relationship_count}.
  """
  def reputation_for_character(character_id) do
    rels =
      Repo.all(
        from r in Relationship,
          where: r.target_character_id == ^character_id
      )

    count = length(rels)

    if count == 0 do
      %{avg_trust: 0, avg_respect: 0, avg_fear: 0, avg_affinity: 0, relationship_count: 0}
    else
      avg = fn field ->
        total = Enum.reduce(rels, 0, fn r, acc -> acc + Map.get(r, field, 0) end)
        round(total / count)
      end

      %{
        avg_trust: avg.(:trust),
        avg_respect: avg.(:respect),
        avg_fear: avg.(:fear),
        avg_affinity: avg.(:affinity),
        relationship_count: count
      }
    end
  end
end
