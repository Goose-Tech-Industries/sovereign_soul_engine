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
