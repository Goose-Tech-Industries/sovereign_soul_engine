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

  def change_relationship(%Relationship{} = relationship, attrs \\ %{}) do
    Relationship.changeset(relationship, attrs)
  end
end
