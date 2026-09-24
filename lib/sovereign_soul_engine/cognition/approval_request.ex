defmodule SovereignSoulEngine.Cognition.ApprovalRequest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "approval_requests" do
    field :operation, :string
    field :payload, :map, default: %{}
    field :policy_context, :map, default: %{}
    field :status, :string, default: "pending"
    field :requested_by, :string
    field :decided_by, :string
    field :decision_reason, :string
    field :expires_at, :utc_datetime_usec
    field :decided_at, :utc_datetime_usec
    field :correlation_id, :binary_id
    field :execution_key, :string
    field :execution_status, :string
    field :execution_result, :map, default: %{}
    field :executed_at, :utc_datetime_usec

    belongs_to :character, SovereignSoulEngine.Characters.Character
    belongs_to :checkpoint, SovereignSoulEngine.Cognition.Checkpoint
    belongs_to :action_intent, SovereignSoulEngine.Actions.ActionIntent

    timestamps(type: :utc_datetime_usec)
  end

  @statuses ~w(pending approved rejected cancelled expired)

  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :character_id,
      :checkpoint_id,
      :action_intent_id,
      :operation,
      :payload,
      :policy_context,
      :status,
      :requested_by,
      :decided_by,
      :decision_reason,
      :expires_at,
      :decided_at,
      :correlation_id,
      :execution_key,
      :execution_status,
      :execution_result,
      :executed_at
    ])
    |> validate_required([:character_id, :operation])
    |> validate_inclusion(:status, @statuses)
  end
end
