defmodule SovereignSoulEngineWeb.Api.CognitionController do
  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.{Actions, Characters}
  alias SovereignSoulEngine.Cognition.{Approvals, ApprovalRequest}

  def approvals(conn, params) do
    with {:ok, character} <- tenant_character(conn, params["character_id"] || params["npc_id"]),
         approvals <- Approvals.pending_for_character(character.id) do
      json(conn, %{approvals: Enum.map(approvals, &approval_json/1)})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "character not found"})

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "tenant mismatch"})
    end
  end

  def approve(conn, %{"id" => id} = params), do: decide(conn, id, "approved", params)
  def reject(conn, %{"id" => id} = params), do: decide(conn, id, "rejected", params)

  def execute(conn, %{"id" => id, "execution_key" => key, "status" => status} = params) do
    with {:ok, request} <- tenant_request(conn, id),
         {:ok, updated} <-
           Actions.record_external_execution(
             request.id,
             key,
             status,
             params["result"] || %{}
           ) do
      json(conn, %{approval: approval_json(updated)})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "approval not found"})

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "tenant mismatch"})

      {:error, :approval_required} ->
        conn |> put_status(:conflict) |> json(%{error: "approval required"})

      {:error, :already_executed} ->
        conn |> put_status(:conflict) |> json(%{error: "already executed"})
    end
  end

  defp decide(conn, id, decision, params) do
    with {:ok, request} <- tenant_request(conn, id),
         {:ok, %{approval: approval, intent: intent}} <-
           Actions.decide_approval(request.id, decision, %{
             decided_by: params["decided_by"] || "tenant",
             decision_reason: params["reason"]
           }) do
      json(conn, %{approval: approval_json(approval), action_intent_id: intent.id})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "approval not found"})

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "tenant mismatch"})

      {:error, :already_decided} ->
        conn |> put_status(:conflict) |> json(%{error: "already decided"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  defp tenant_request(conn, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        request = Approvals.get!(uuid)

        case tenant_character(conn, request.character_id) do
          {:ok, _character} -> {:ok, request}
          error -> error
        end

      :error ->
        {:error, :not_found}
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp tenant_character(conn, character_id) do
    with {:ok, uuid} <- Ecto.UUID.cast(character_id),
         %{} = character <- Characters.get_character(uuid) do
      if character.external_source == conn.assigns.tenant.external_source do
        {:ok, character}
      else
        {:error, :forbidden}
      end
    else
      _ -> {:error, :not_found}
    end
  end

  defp approval_json(%ApprovalRequest{} = request) do
    %{
      id: request.id,
      character_id: request.character_id,
      action_intent_id: request.action_intent_id,
      operation: request.operation,
      status: request.status,
      payload: request.payload,
      execution_status: request.execution_status,
      execution_key: request.execution_key,
      execution_result: request.execution_result,
      decided_at: request.decided_at,
      executed_at: request.executed_at
    }
  end
end
