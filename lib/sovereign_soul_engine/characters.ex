defmodule SovereignSoulEngine.Characters do
  @moduledoc """
  Context for managing Characters (NPCs, players, system actors, creatures).
  """

  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Accounts.User
  alias SovereignSoulEngine.Repo
  import Ecto.Query

  def list_characters do
    Repo.all(Character)
  end

  @doc """
  Returns characters that participate in the public living world.
  Excludes characters whose owner has opted out of the living world,
  or characters explicitly set to in_living_world: false.
  """
  def list_living_world_characters do
    from(c in Character,
      left_join: u in User,
      on: c.user_id == u.id,
      where:
        c.in_living_world == true and
          (is_nil(c.user_id) or u.opt_out_living_world == false) and
          c.status == "active"
    )
    |> Repo.all()
  end

  @doc """
  Lists companions visible to a given user.
  Includes canon/platform companions (user_id is nil) plus the user's custom companions.
  """
  def list_companions_for_user(user_id) do
    from(c in Character,
      where:
        (is_nil(c.user_id) or c.user_id == ^user_id) and c.kind == "npc" and c.status == "active",
      order_by: [asc: c.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets or provisions the personal player profile for an authenticated user.
  """
  def get_or_create_player_for_user(%User{} = user) do
    slug = "user-" <> (user.id |> String.replace("-", "") |> String.slice(0, 12))
    name = user.email |> String.split("@") |> List.first() |> String.capitalize()

    case Repo.get_by(Character, user_id: user.id, kind: "player") do
      nil ->
        case create_character(%{
               name: name,
               slug: slug,
               kind: "player",
               status: "active",
               description: "Personal companion chat persona for #{user.email}",
               user_id: user.id
             }) do
          {:ok, player} -> player
          {:error, _} -> Repo.get_by!(Character, slug: slug)
        end

      player ->
        player
    end
  end

  @doc """
  Toggles whether a companion participates in the living world.
  """
  def set_companion_living_world(%Character{} = character, in_living_world)
      when is_boolean(in_living_world) do
    update_character(character, %{in_living_world: in_living_world})
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

  @doc """
  Creates a character and immediately provisions their complete Soul Profile,
  baseline emotions, somatics, and cryptographic DID identity.
  """
  def create_living_soul(attrs \\ %{}, profile_attrs \\ %{}) do
    case create_character(attrs) do
      {:ok, character} ->
        SovereignSoulEngine.Souls.ensure_soul_vitality(character, profile_attrs)
        {:ok, character}

      error ->
        error
    end
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
        slug =
          "#{external_source}-#{external_id}"
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9-]/, "-")

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
