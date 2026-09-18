defmodule SovereignSoulEngine.Relationships do
  @moduledoc """
  Context for managing directional Relationships between characters.
  """

  alias SovereignSoulEngine.Relationships.Relationship
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  def list_relationships do
    Repo.all(Relationship)
  end

  def get_relationship!(id), do: Repo.get!(Relationship, id)

  def get_relationship(source_id, target_id) do
    Repo.get_by(Relationship, source_character_id: source_id, target_character_id: target_id)
  end

  def list_relationships_for_source(source_id) do
    Repo.all(from r in Relationship, where: r.source_character_id == ^source_id)
  end

  def list_relationships_for_target(target_id) do
    Repo.all(from r in Relationship, where: r.target_character_id == ^target_id)
  end

  def create_relationship(attrs \\ %{}) do
    %Relationship{}
    |> Relationship.changeset(attrs)
    |> Repo.insert()
  end

  def update_relationship(%Relationship{} = relationship, attrs) do
    relationship
    |> Relationship.changeset(attrs)
    |> Repo.update()
  end

  def delete_relationship(%Relationship{} = relationship) do
    Repo.delete(relationship)
  end

  @doc """
  Prunes a soul's directional edges down to the most recent `max_edges` (default
  50), deleting the stalest by `last_interaction_at`. Keeps the relationship
  graph sparse — O(edges) with a per-soul cap, rather than O(n²).
  """
  @spec prune_edges(String.t(), non_neg_integer()) :: non_neg_integer()
  def prune_edges(character_id, max_edges \\ 50) do
    excess =
      character_id
      |> list_relationships_for_source()
      |> Enum.sort_by(&sort_key/1, :desc)
      |> Enum.drop(max_edges)

    Enum.each(excess, &delete_relationship/1)
    length(excess)
  end

  # Most-recently-interacted first; never-interacted edges sort last.
  defp sort_key(%{last_interaction_at: %DateTime{} = dt}), do: DateTime.to_unix(dt)
  defp sort_key(_), do: 0

  @doc """
  Returns a character's top friends (highest affinity + trust) for social widgets.
  """
  def get_top_friends(character_id, limit \\ 8) do
    from(r in Relationship,
      where: r.source_character_id == ^character_id,
      order_by: [desc: fragment("? + ?", r.affinity, r.trust)],
      limit: ^limit,
      preload: [:target_character]
    )
    |> Repo.all()
  end

  def change_relationship(%Relationship{} = relationship, attrs \\ %{}) do
    Relationship.changeset(relationship, attrs)
  end
end
