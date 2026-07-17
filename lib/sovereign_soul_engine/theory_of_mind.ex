defmodule SovereignSoulEngine.TheoryOfMind do
  @moduledoc """
  Context for Theory of Mind: tracking what characters believe other characters know.
  """

  import Ecto.Query
  alias SovereignSoulEngine.TheoryOfMind.CharacterKnowledge
  alias SovereignSoulEngine.Repo

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
end
