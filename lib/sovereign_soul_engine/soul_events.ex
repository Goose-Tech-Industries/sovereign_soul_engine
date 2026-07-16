defmodule SovereignSoulEngine.SoulEvents do
  @moduledoc """
  Context for managing canonical Soul Events.
  """

  alias SovereignSoulEngine.Scenes.SoulEvent
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  def list_events do
    Repo.all(SoulEvent)
  end

  def get_event!(id), do: Repo.get!(SoulEvent, id)

  def list_events_for_scene(scene_id) do
    Repo.all(from e in SoulEvent, where: e.scene_id == ^scene_id, order_by: [asc: :occurred_at])
  end

  def list_events_for_character(character_id) do
    Repo.all(
      from e in SoulEvent,
        where: e.target_character_id == ^character_id,
        order_by: [desc: :occurred_at]
    )
  end

  def create_event(attrs \\ %{}) do
    %SoulEvent{}
    |> SoulEvent.changeset(attrs)
    |> Repo.insert()
  end

  def change_event(%SoulEvent{} = event, attrs \\ %{}) do
    SoulEvent.changeset(event, attrs)
  end
end
