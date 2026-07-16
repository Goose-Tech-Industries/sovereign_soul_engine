defmodule SovereignSoulEngine.Characters do
  @moduledoc """
  Context for managing Characters (NPCs, players, system actors, creatures).
  """

  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Repo

  def list_characters do
    Repo.all(Character)
  end

  def get_character!(id), do: Repo.get!(Character, id)
  def get_character(id), do: Repo.get(Character, id)

  def get_character_by_slug!(slug), do: Repo.get_by!(Character, slug: slug)
  def get_character_by_slug(slug), do: Repo.get_by(Character, slug: slug)

  def create_character(attrs \\ %{}) do
    %Character{}
    |> Character.changeset(attrs)
    |> Repo.insert()
  end

  def update_character(%Character{} = character, attrs) do
    character
    |> Character.changeset(attrs)
    |> Repo.update()
  end

  def delete_character(%Character{} = character) do
    Repo.delete(character)
  end

  def change_character(%Character{} = character, attrs \\ %{}) do
    Character.changeset(character, attrs)
  end
end
