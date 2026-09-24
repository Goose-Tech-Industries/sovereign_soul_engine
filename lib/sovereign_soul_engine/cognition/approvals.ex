defmodule SovereignSoulEngine.Cognition.Approvals do
  @moduledoc "Human approval gates for proposed cognition and external actions."

  import Ecto.Query

  alias SovereignSoulEngine.Cognition.ApprovalRequest
  alias SovereignSoulEngine.Repo

  def create(attrs) when is_map(attrs) do
    %ApprovalRequest{}
    |> ApprovalRequest.changeset(attrs)
    |> Repo.insert()
  end

  def get!(id), do: Repo.get!(ApprovalRequest, id)

  def pending_for_character(character_id) do
    Repo.all(
      from a in ApprovalRequest,
        where: a.character_id == ^character_id and a.status == "pending",
        order_by: [asc: a.inserted_at]
    )
  end

  def recent(limit \\ 50) do
    Repo.all(from a in ApprovalRequest, order_by: [desc: a.inserted_at], limit: ^limit)
  end

  def decide(request, decision, attrs \\ %{})

  def decide(%ApprovalRequest{status: "pending"} = request, decision, attrs)
      when decision in ~w(approved rejected cancelled) and is_map(attrs) do
    now = DateTime.utc_now()

    request
    |> ApprovalRequest.changeset(Map.merge(attrs, %{status: decision, decided_at: now}))
    |> Repo.update()
  end

  def decide(%ApprovalRequest{}, _decision, _attrs),
    do: {:error, :already_decided}
end
