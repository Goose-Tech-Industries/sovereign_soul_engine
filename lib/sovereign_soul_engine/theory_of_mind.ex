defmodule SovereignSoulEngine.TheoryOfMind do
  @moduledoc """
  Context for Theory of Mind 2.0:
    - Tracking what characters believe other characters know (first and second-order).
    - Attribute perceived conversational intent and subtext.
    - Emotional boundary and friction evaluation.
    - Information asymmetry and tactical leverage.
    - Autonomous check-in opportunity detection for companion retention.
  """

  import Ecto.Query
  alias SovereignSoulEngine.TheoryOfMind.CharacterKnowledge
  alias SovereignSoulEngine.TheoryOfMind.Engine
  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.TheoryOfMind.LifeThread

  # Delegations to the pure cognitive Engine
  defdelegate attribute_intent(statement, sentiment, relationship), to: Engine
  defdelegate evaluate_boundary(statement, defensiveness, trust, sensitive_topics), to: Engine

  defdelegate analyze_information_asymmetry(knower_facts, subject_facts, knower_secrets),
    to: Engine

  defdelegate detect_proactive_opportunity(known_facts, relationship, hours_silent), to: Engine
  defdelegate build_tom_brief(params), to: Engine

  # ── Knowledge Persistence ──────────────────────────────────────────

  def list_knowledge_about(knower_id, subject_id) do
    Repo.all(
      from k in CharacterKnowledge,
        where: k.knower_character_id == ^knower_id and k.subject_character_id == ^subject_id,
        order_by: [desc: k.certainty]
    )
  end

  def list_what_knower_knows(knower_id) do
    Repo.all(
      from k in CharacterKnowledge,
        where: k.knower_character_id == ^knower_id,
        order_by: [desc: k.certainty]
    )
  end

  def create_knowledge(attrs \\ %{}) do
    %CharacterKnowledge{}
    |> CharacterKnowledge.changeset(attrs)
    |> Repo.insert()
  end

  def update_knowledge(%CharacterKnowledge{} = knowledge, attrs) do
    knowledge
    |> CharacterKnowledge.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Upsert: if a knowledge entry matching knower_id + subject_id + fact exists, update it.
  Otherwise create a new entry. Opts: certainty, is_assumption, last_updated_at.
  """
  def upsert_knowledge(knower_id, subject_id, fact, opts \\ []) do
    certainty = Keyword.get(opts, :certainty, 70)
    is_assumption = Keyword.get(opts, :is_assumption, true)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    existing =
      Repo.one(
        from k in CharacterKnowledge,
          where:
            k.knower_character_id == ^knower_id and
              k.subject_character_id == ^subject_id and
              k.known_fact == ^fact,
          limit: 1
      )

    attrs = %{
      knower_character_id: knower_id,
      subject_character_id: subject_id,
      known_fact: fact,
      certainty: certainty,
      is_assumption: is_assumption,
      last_updated_at: now
    }

    if existing do
      existing
      |> CharacterKnowledge.changeset(attrs)
      |> Repo.update()
    else
      %CharacterKnowledge{}
      |> CharacterKnowledge.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Purges knowledge entries held by a character about a subject based on optional topic query or all.
  """
  def purge_knowledge_about(knower_id, subject_id, opts \\ []) do
    with {:ok, opts} <- SovereignSoulEngine.Memories.PurgeFilters.validate(opts, [:topic]) do
      query =
        from(k in CharacterKnowledge,
          where: k.knower_character_id == ^knower_id and k.subject_character_id == ^subject_id
        )

      query =
        cond do
          Keyword.get(opts, :all) == true ->
            query

          topic = Keyword.get(opts, :topic) || Keyword.get(opts, :query) ->
            from(k in query,
              where: fragment("strpos(lower(?), lower(?)) > 0", k.known_fact, ^topic)
            )

          true ->
            query
        end

      {count, _} = Repo.delete_all(query)
      {:ok, count}
    end
  end

  @doc """
  Purges all knowledge entries where character is knower or subject, based on optional topic query or all.
  """
  def purge_knowledge_for_character(character_id, opts \\ []) do
    with {:ok, opts} <- SovereignSoulEngine.Memories.PurgeFilters.validate(opts, [:topic]) do
      query =
        from(k in CharacterKnowledge,
          where: k.knower_character_id == ^character_id or k.subject_character_id == ^character_id
        )

      query =
        cond do
          Keyword.get(opts, :all) == true ->
            query

          topic = Keyword.get(opts, :topic) || Keyword.get(opts, :query) ->
            from(k in query,
              where: fragment("strpos(lower(?), lower(?)) > 0", k.known_fact, ^topic)
            )

          true ->
            query
        end

      {count, _} = Repo.delete_all(query)
      {:ok, count}
    end
  end

  @doc """
  Purges pending life threads where character is knower or subject, based on optional topic query or all.
  """
  def purge_life_threads_for_character(character_id, opts \\ []) do
    with {:ok, opts} <- SovereignSoulEngine.Memories.PurgeFilters.validate(opts, [:topic]) do
      query =
        from(t in LifeThread,
          where: t.knower_character_id == ^character_id or t.subject_character_id == ^character_id
        )

      query =
        cond do
          Keyword.get(opts, :all) == true ->
            query

          topic = Keyword.get(opts, :topic) || Keyword.get(opts, :query) ->
            from(t in query,
              where: fragment("strpos(lower(?), lower(?)) > 0", t.topic, ^topic)
            )

          true ->
            query
        end

      {count, _} = Repo.delete_all(query)
      {:ok, count}
    end
  end

  # ── Theory of Mind 2.0 High-Level Briefing ─────────────────────────

  @doc """
  Builds a complete, token-efficient Theory of Mind 2.0 briefing for LLM prompt generation.
  Fetches knowledge, secrets, and relationship data between knower and subject.
  """
  def build_character_tom_brief(knower_id, subject_id, opts \\ []) do
    knower = Characters.get_character(knower_id)
    subject = Characters.get_character(subject_id)
    subject_name = (subject && subject.name) || "User"
    knower_name = (knower && knower.name) || "Soul"

    knower_facts =
      list_knowledge_about(knower_id, subject_id)
      |> Enum.map(& &1.known_fact)

    subject_facts =
      list_knowledge_about(subject_id, knower_id)
      |> Enum.map(& &1.known_fact)

    knower_secrets =
      try do
        Souls.list_secrets_for_character(knower_id)
        |> Enum.map(& &1.content)
      rescue
        _ -> []
      end

    relationship =
      case Relationships.get_relationship(knower_id, subject_id) do
        nil -> %{trust: 50, affinity: 50, respect: 50, anger: 0, fear: 0, wound: 0}
        rel -> rel
      end

    last_statement = Keyword.get(opts, :last_statement, "")
    sentiment = Keyword.get(opts, :sentiment, :neutral)
    defensiveness = Keyword.get(opts, :defensiveness, 0)

    intent_analysis = Engine.attribute_intent(last_statement, sentiment, relationship)
    asymmetry = Engine.analyze_information_asymmetry(knower_facts, subject_facts, knower_secrets)

    Engine.build_tom_brief(%{
      knower_name: knower_name,
      subject_name: subject_name,
      primary_intent: intent_analysis.primary_intent,
      recommended_stance: intent_analysis.recommended_stance,
      defensiveness: defensiveness,
      known_vulnerabilities: asymmetry.known_vulnerabilities,
      hidden_secrets: asymmetry.hidden_from_subject,
      known_facts: knower_facts
    })
  end

  # ── Life Threads Persistence & Proactive Check-In ──────────────────

  alias SovereignSoulEngine.TheoryOfMind.LifeThread

  defdelegate detect_thread_candidate(statement), to: Engine

  def list_active_life_threads(knower_id, subject_id) do
    Repo.all(
      from t in LifeThread,
        where:
          t.knower_character_id == ^knower_id and
            t.subject_character_id == ^subject_id and
            t.status == "pending",
        order_by: [desc: t.salience, asc: t.due_at]
    )
  end

  def create_life_thread(attrs \\ %{}) do
    %LifeThread{}
    |> LifeThread.changeset(attrs)
    |> Repo.insert()
  end

  def resolve_life_thread(thread_id, notes \\ nil) do
    case Repo.get(LifeThread, thread_id) do
      nil ->
        {:error, :not_found}

      thread ->
        attrs = %{status: "resolved", resolution_notes: notes}

        thread
        |> LifeThread.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Inspects a statement for open life threads (proposals, surgeries, interviews, loneliness).
  If detected, creates a pending LifeThread record with an armed due_at time.
  """
  def record_life_thread_if_detected(knower_id, subject_id, statement, opts \\ []) do
    case Engine.detect_thread_candidate(statement) do
      {:detected, candidate} ->
        hours = Keyword.get(opts, :hours, candidate.default_hours)
        now = DateTime.utc_now()
        due_at = DateTime.add(now, hours * 3600, :second)

        attrs = %{
          knower_character_id: knower_id,
          subject_character_id: subject_id,
          topic: statement,
          category: to_string(candidate.category),
          salience: candidate.salience,
          due_at: due_at,
          check_in_guidance: candidate.guidance,
          status: "pending"
        }

        create_life_thread(attrs)

      :none ->
        :none
    end
  end

  @doc """
  Harvests open life threads from natural dialogue statements and records them.
  Returns `{:ok, thread}` when a thread was detected and created, or `:none`.
  """
  def harvest_life_threads(knower_id, subject_id, statement, opts \\ []) do
    record_life_thread_if_detected(knower_id, subject_id, statement, opts)
  end

  @doc """
  Lists all pending threads where the due_at time has passed and no check-in has been sent.
  """
  def list_threads_due_for_checkin(now \\ DateTime.utc_now()) do
    Repo.all(
      from t in LifeThread,
        where: t.status == "pending" and t.due_at <= ^now and is_nil(t.check_in_sent_at),
        order_by: [desc: t.salience]
    )
  end

  @doc """
  Marks a check-in as sent so it won't be triggered repeatedly.
  """
  def mark_thread_checkin_sent(thread_id) do
    case Repo.get(LifeThread, thread_id) do
      nil ->
        {:error, :not_found}

      thread ->
        thread
        |> LifeThread.changeset(%{check_in_sent_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  @doc """
  Checks if an autonomous check-in opportunity exists for a given subject.
  """
  def check_proactive_checkin(knower_id, subject_id, hours_silent) do
    # First priority: check if any explicit pending LifeThread has come due
    now = DateTime.utc_now()

    due_threads =
      Repo.all(
        from t in LifeThread,
          where:
            t.knower_character_id == ^knower_id and
              t.subject_character_id == ^subject_id and
              t.status == "pending" and
              t.due_at <= ^now and
              is_nil(t.check_in_sent_at),
          order_by: [desc: t.salience],
          limit: 1
      )

    case due_threads do
      [thread | _] ->
        {:proactive_checkin,
         %{
           focus_topic: thread.topic,
           category: thread.category,
           intent: :life_thread_followup,
           prompt_guidance: thread.check_in_guidance || "Check in with warmth on how this went.",
           thread_id: thread.id
         }}

      [] ->
        # Fallback to general care event scan
        known_facts =
          list_knowledge_about(knower_id, subject_id)
          |> Enum.map(& &1.known_fact)

        relationship =
          case Relationships.get_relationship(knower_id, subject_id) do
            nil -> %{trust: 0, affinity: 0}
            rel -> rel
          end

        Engine.detect_proactive_opportunity(known_facts, relationship, hours_silent)
    end
  end
end
