defmodule SovereignSoulEngine.Cognition.Checkpoints do
  @moduledoc "Durable, versioned cognition state for pause, restart, and resume."

  import Ecto.Query

  alias SovereignSoulEngine.Cognition.Checkpoint
  alias SovereignSoulEngine.Repo

  def create(attrs) when is_map(attrs) do
    character_id = Map.get(attrs, :character_id) || Map.get(attrs, "character_id")
    thread_id = Map.get(attrs, :thread_id) || Map.get(attrs, "thread_id")

    version =
      case latest(character_id, thread_id) do
        nil -> 1
        checkpoint -> checkpoint.version + 1
      end

    attrs = attrs |> Map.put(:version, version) |> Map.put_new(:status, "paused")
    Repo.insert(Checkpoint.changeset(%Checkpoint{}, attrs))
  end

  def get!(id), do: Repo.get!(Checkpoint, id)

  def latest(character_id, thread_id) do
    Repo.one(
      from c in Checkpoint,
        where: c.character_id == ^character_id and c.thread_id == ^thread_id,
        order_by: [desc: c.version],
        limit: 1
    )
  end

  def list_for_thread(character_id, thread_id) do
    Repo.all(
      from c in Checkpoint,
        where: c.character_id == ^character_id and c.thread_id == ^thread_id,
        order_by: [desc: c.version]
    )
  end

  def recent(limit \\ 50) do
    Repo.all(from c in Checkpoint, order_by: [desc: c.inserted_at], limit: ^limit)
  end

  @doc "Resumes a paused or interrupted checkpoint after an explicit decision."
  def resume(%Checkpoint{status: status} = checkpoint) when status in ["paused", "interrupted"] do
    checkpoint
    |> Checkpoint.changeset(%{status: "running"})
    |> Repo.update()
  end

  def resume(%Checkpoint{}), do: {:error, :not_resumable}

  @doc "Resumes the latest checkpoint for a durable cognition thread."
  def resume_latest(character_id, thread_id) do
    case latest(character_id, thread_id) do
      nil -> {:error, :not_found}
      checkpoint -> resume(checkpoint)
    end
  end

  def interrupt(%Checkpoint{} = checkpoint, interrupt) when is_map(interrupt) do
    checkpoint
    |> Checkpoint.changeset(%{status: "interrupted", interrupt: interrupt})
    |> Repo.update()
  end

  @doc "Cancels a checkpoint and records the cancellation reason for recovery tools."
  def cancel(%Checkpoint{} = checkpoint, reason \\ "cancelled") do
    checkpoint
    |> Checkpoint.changeset(%{
      status: "cancelled",
      interrupt: %{"reason" => to_string(reason)}
    })
    |> Repo.update()
  end

  def finish(%Checkpoint{} = checkpoint, status, attrs \\ %{})
      when status in ~w(completed failed cancelled) and is_map(attrs) do
    checkpoint
    |> Checkpoint.changeset(Map.merge(attrs, %{status: status}))
    |> Repo.update()
  end
end
