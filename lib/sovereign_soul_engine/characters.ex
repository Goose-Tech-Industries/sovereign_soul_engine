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

  @doc "Read-only lookup — nil if this external player has never been seen before (no create side effect, safe for a GET)."
  def get_external_player(external_source, external_id) do
    Repo.get_by(Character, external_source: external_source, external_id: external_id)
  end

  @doc """
  Finds (or creates on first contact) the player-kind Character for an
  external game's own player id — e.g. a Twisted Paradox player talking to
  an NPC for the first time. Idempotent on (external_source, external_id).
  """
  def get_or_create_external_player(external_source, external_id, name) do
    case Repo.get_by(Character, external_source: external_source, external_id: external_id) do
      nil ->
        slug = "#{external_source}-#{external_id}" |> String.downcase() |> String.replace(~r/[^a-z0-9-]/, "-")

        %Character{}
        |> Character.changeset(%{
          name: name,
          slug: slug,
          kind: "player",
          status: "active",
          external_source: external_source,
          external_id: external_id
        })
        |> Repo.insert(on_conflict: :nothing, conflict_target: [:external_source, :external_id])

        Repo.get_by!(Character, external_source: external_source, external_id: external_id)

      character ->
        character
    end
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
