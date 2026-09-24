defmodule SovereignSoulEngine.Cognition.ChatBranches do
  @moduledoc """
  Non-destructive alternate conversation branches.

  A branch shares the canonical scene history through a selected fork message.
  New messages are tagged with the branch id, leaving the canonical timeline
  untouched and making alternate replies safe to discard or compare later.
  """

  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Scenes.SceneMessage
  import Ecto.Query

  @spec fork(binary(), binary(), keyword()) :: {:ok, map()} | {:error, term()}
  def fork(scene_id, message_id, opts \\ []) do
    case Scenes.get_message(message_id) do
      %{scene_id: ^scene_id} = message ->
        {:ok,
         %{
           branch_id: Keyword.get(opts, :branch_id, Ecto.UUID.generate()),
           scene_id: scene_id,
           fork_message_id: message.id,
           forked_at: message.inserted_at,
           metadata: Keyword.get(opts, :metadata, %{})
         }}

      nil ->
        {:error, :message_not_found}

      _ ->
        {:error, :message_not_in_scene}
    end
  end

  @spec append(map(), map()) :: {:ok, map()} | {:error, term()}
  def append(%{branch_id: branch_id, scene_id: scene_id} = branch, attrs)
      when is_map(attrs) do
    metadata =
      attrs
      |> Map.get(:metadata, Map.get(attrs, "metadata", %{}))
      |> Map.merge(%{
        "branch_id" => branch_id,
        "branch_fork_message_id" => branch.fork_message_id
      })

    attrs =
      attrs
      |> Map.put(:scene_id, scene_id)
      |> Map.put(:metadata, metadata)

    Scenes.create_message(attrs)
  end

  @spec list(map()) :: [map()]
  def list(%{branch_id: branch_id, scene_id: scene_id, fork_message_id: fork_message_id}) do
    messages = Scenes.list_messages(scene_id)

    {canonical, branch_messages} =
      Enum.split_with(messages, fn message ->
        Map.get(message.metadata || %{}, "branch_id") in [nil, ""]
      end)

    prefix =
      canonical
      |> Enum.take_while(&(&1.id != fork_message_id))
      |> Kernel.++(Enum.filter(canonical, &(&1.id == fork_message_id)))

    prefix ++ Enum.filter(branch_messages, &(Map.get(&1.metadata, "branch_id") == branch_id))
  end

  @doc "Discards alternate messages while preserving the canonical scene timeline."
  def discard(scene_id, branch_id) when is_binary(scene_id) and is_binary(branch_id) do
    Repo.delete_all(
      from m in SceneMessage,
        where: m.scene_id == ^scene_id,
        where: fragment("?->>'branch_id' = ?", m.metadata, ^branch_id)
    )

    :ok
  end
end
