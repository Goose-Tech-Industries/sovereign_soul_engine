defmodule SovereignSoulEngineWeb.Api.BranchController do
  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.{Characters, Cognition.ChatBranches, Scenes}

  def create(conn, %{"scene_id" => scene_id, "message_id" => message_id} = params) do
    with {:ok, _character} <- tenant_character(conn, params["character_id"]),
         {:ok, branch} <- ChatBranches.fork(scene_id, message_id, branch_id: params["branch_id"]) do
      json(conn, branch_json(branch, []))
    else
      {:error, :message_not_found} ->
        error(conn, :not_found, "message not found")

      {:error, :message_not_in_scene} ->
        error(conn, :unprocessable_entity, "message is not in scene")

      {:error, :forbidden} ->
        error(conn, :forbidden, "tenant mismatch")

      {:error, :not_found} ->
        error(conn, :not_found, "character not found")
    end
  end

  def show(conn, %{"scene_id" => scene_id, "branch_id" => branch_id} = params) do
    with {:ok, _character} <- tenant_character(conn, params["character_id"]),
         {:ok, fork_message_id} <- fork_message_id(scene_id, branch_id) do
      branch = %{branch_id: branch_id, scene_id: scene_id, fork_message_id: fork_message_id}
      json(conn, branch_json(branch, ChatBranches.list(branch)))
    else
      {:error, :not_found} -> error(conn, :not_found, "branch not found")
      {:error, :forbidden} -> error(conn, :forbidden, "tenant mismatch")
    end
  end

  def append(conn, %{"scene_id" => scene_id, "branch_id" => branch_id} = params) do
    with {:ok, _character} <- tenant_character(conn, params["character_id"]),
         {:ok, fork_message_id} <- resolve_fork_message_id(scene_id, branch_id, params),
         {:ok, message} <-
           ChatBranches.append(
             %{branch_id: branch_id, scene_id: scene_id, fork_message_id: fork_message_id},
             %{
               character_id: params["character_id"],
               content: params["content"],
               message_type: params["message_type"] || "dialogue"
             }
           ) do
      json(conn, %{message: message_json(message)})
    else
      {:error, :not_found} -> error(conn, :not_found, "branch not found")
      {:error, :forbidden} -> error(conn, :forbidden, "tenant mismatch")
      {:error, changeset} -> error(conn, :unprocessable_entity, inspect(changeset.errors))
    end
  end

  defp resolve_fork_message_id(_scene_id, _branch_id, %{"fork_message_id" => id})
       when is_binary(id) and id != "",
       do: {:ok, id}

  defp resolve_fork_message_id(scene_id, branch_id, _params),
    do: fork_message_id(scene_id, branch_id)

  def discard(conn, %{"scene_id" => scene_id, "branch_id" => branch_id} = params) do
    with {:ok, _character} <- tenant_character(conn, params["character_id"]),
         {:ok, _fork_message_id} <- fork_message_id(scene_id, branch_id) do
      :ok = ChatBranches.discard(scene_id, branch_id)
      json(conn, %{status: "discarded", branch_id: branch_id})
    else
      {:error, :not_found} -> error(conn, :not_found, "branch not found")
      {:error, :forbidden} -> error(conn, :forbidden, "tenant mismatch")
    end
  end

  defp fork_message_id(scene_id, branch_id) do
    case Scenes.list_messages(scene_id)
         |> Enum.find(&(get_in(&1.metadata, ["branch_id"]) == branch_id)) do
      %{metadata: %{"branch_fork_message_id" => id}} -> {:ok, id}
      _ -> {:error, :not_found}
    end
  end

  defp tenant_character(conn, id) do
    case Characters.get_character(id) do
      %{external_source: source} when source == conn.assigns.tenant.external_source -> {:ok, id}
      nil -> {:error, :not_found}
      _ -> {:error, :forbidden}
    end
  end

  defp branch_json(branch, messages) do
    %{
      branch_id: branch.branch_id,
      scene_id: branch.scene_id,
      fork_message_id: branch.fork_message_id,
      messages: Enum.map(messages, &message_json/1)
    }
  end

  defp message_json(message),
    do: %{
      id: message.id,
      character_id: message.character_id,
      content: message.content,
      message_type: message.message_type,
      metadata: message.metadata
    }

  defp error(conn, status, message), do: conn |> put_status(status) |> json(%{error: message})
end
