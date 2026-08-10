defmodule SovereignSoulEngineWeb.Api.NpcActionsController do
  @moduledoc """
  Lets an external game discover NPC-proposed world actions (e.g.
  lock_door/unlock_door, flee/flee_scene) that have real consequences
  outside SSE, and mark them handled once applied. SSE already writes an
  `action_intents` row for every proposed action as part of the normal
  conversation flow — this just exposes the unconsumed ones (filtered to
  whichever action types the caller cares about) and a way to consume them.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Actions
  alias SovereignSoulEngine.Actions.ActionIntent

  def pending(conn, %{"npc_id" => npc_id, "types" => types_param}) do
    with {:ok, _} <- Ecto.UUID.cast(npc_id),
         {:ok, types} <- parse_action_types(types_param) do
      actions =
        npc_id
        |> Actions.list_pending_action_intents_for_character(types)
        |> Enum.map(fn a ->
          %{id: a.id, proposed_action: a.proposed_action, inserted_at: a.inserted_at}
        end)

      json(conn, %{actions: actions})
    else
      :error -> conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid npc_id"})
      {:error, :invalid_types} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid types"})
    end
  end

  def pending(conn, %{"npc_id" => _npc_id}) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "types is required"})
  end

  defp parse_action_types(types_param) do
    types = types_param |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
    valid = ActionIntent.action_types()

    if types != [] and Enum.all?(types, &(&1 in valid)) do
      {:ok, types}
    else
      {:error, :invalid_types}
    end
  end

  def consume(conn, %{"id" => id}) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         intent <- Actions.get_action_intent!(id),
         {:ok, updated} <- Actions.update_action_intent(intent, %{validation_status: "approved"}) do
      json(conn, %{id: updated.id, validation_status: updated.validation_status})
    else
      :error -> conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid id"})
      _ -> conn |> put_status(:not_found) |> json(%{error: "action not found"})
    end
  rescue
    Ecto.NoResultsError -> conn |> put_status(:not_found) |> json(%{error: "action not found"})
  end
end
