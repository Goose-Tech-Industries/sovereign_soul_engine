defmodule SovereignSoulEngine.Scenes do
  @moduledoc """
  Context for managing Scenes, Scene Participants, and Scene Messages.
  """

  alias SovereignSoulEngine.Scenes.{Scene, SceneParticipant, SceneMessage}
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  # Scenes

  def list_scenes do
    Repo.all(Scene)
  end

  def list_active_scenes do
    Repo.all(from s in Scene, where: s.status == "active")
  end

  def list_autonomous_scenes(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    Repo.all(
      from s in Scene,
        where: s.is_autonomous == true,
        order_by: [desc: s.inserted_at],
        limit: ^limit,
        preload: [participants: :character, messages: []]
    )
  end

  def get_scene!(id), do: Repo.get!(Scene, id)
  def get_scene(id), do: Repo.get(Scene, id)

  def create_scene(attrs \\ %{}) do
    %Scene{}
    |> Scene.changeset(attrs)
    |> Repo.insert()
  end

  def update_scene(%Scene{} = scene, attrs) do
    scene
    |> Scene.changeset(attrs)
    |> Repo.update()
  end

  def delete_scene(%Scene{} = scene) do
    Repo.delete(scene)
  end

  def change_scene(%Scene{} = scene, attrs \\ %{}) do
    Scene.changeset(scene, attrs)
  end

  @doc "Read-only — the active 1:1 scene between two characters, or nil. Never creates (a GET shouldn't have side effects)."
  def find_direct_scene(character_a, character_b) do
    Repo.one(
      from s in Scene,
        join: p1 in SceneParticipant,
        on: p1.scene_id == s.id and p1.character_id == ^character_a.id,
        join: p2 in SceneParticipant,
        on: p2.scene_id == s.id and p2.character_id == ^character_b.id,
        where: s.status == "active",
        order_by: [desc: s.inserted_at],
        limit: 1
    )
  end

  @doc """
  The active 1:1 scene between two characters, creating one on first
  contact. Extracted from ChatLive (was private there) so any caller —
  the dev chat UI or an external API like npc_chat — shares one
  find-or-create path instead of two copies drifting apart.
  """
  def find_or_create_direct_scene(character_a, character_b) do
    find_direct_scene(character_a, character_b) || create_direct_scene(character_a, character_b)
  end

  defp create_direct_scene(character_a, character_b) do
    {:ok, scene} =
      create_scene(%{
        title: "#{character_a.name} & #{character_b.name}",
        status: "active",
        location: "Direct Chat",
        context: %{},
        started_at: DateTime.utc_now()
      })

    add_participant(%{scene_id: scene.id, character_id: character_a.id})
    add_participant(%{scene_id: scene.id, character_id: character_b.id})

    scene
  end

  @doc "Read-only lookup for a shared/group scene by its external identity, or nil."
  def find_group_scene(external_source, group_key) do
    Repo.get_by(Scene, external_source: external_source, external_id: group_key)
  end

  @doc """
  The shared scene for an external group identity (e.g. a physical tile),
  creating one on first contact. Unlike a direct scene, this has no fixed
  participant list — any number of external players and NPCs can post
  into it (participants aren't required for Generator.generate/3 since the
  caller always passes an explicit player_id).
  """
  def find_or_create_group_scene(external_source, group_key) do
    find_group_scene(external_source, group_key) || insert_group_scene(external_source, group_key)
  end

  defp insert_group_scene(external_source, group_key) do
    %Scene{}
    |> Scene.changeset(%{
      title: "Ambient: #{group_key}",
      status: "active",
      location: "Ambient",
      context: %{},
      started_at: DateTime.utc_now(),
      external_source: external_source,
      external_id: group_key
    })
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:external_source, :external_id])

    find_group_scene(external_source, group_key)
  end

  # Scene Participants

  def list_participants(scene_id) do
    Repo.all(from p in SceneParticipant, where: p.scene_id == ^scene_id)
  end

  def add_participant(attrs \\ %{}) do
    %SceneParticipant{}
    |> SceneParticipant.changeset(attrs)
    |> Repo.insert()
  end

  def remove_participant(%SceneParticipant{} = participant) do
    Repo.delete(participant)
  end

  # Scene Messages

  def list_messages(scene_id) do
    Repo.all(
      from m in SceneMessage, where: m.scene_id == ^scene_id, order_by: [asc: :inserted_at]
    )
  end

  def create_message(attrs \\ %{}) do
    %SceneMessage{}
    |> SceneMessage.changeset(attrs)
    |> Repo.insert()
  end

  def update_message(%SceneMessage{} = message, attrs) do
    message
    |> SceneMessage.changeset(attrs)
    |> Repo.update()
  end

  def change_message(%SceneMessage{} = message, attrs \\ %{}) do
    SceneMessage.changeset(message, attrs)
  end
end
