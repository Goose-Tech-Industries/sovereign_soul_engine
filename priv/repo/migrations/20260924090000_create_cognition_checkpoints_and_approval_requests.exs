defmodule SovereignSoulEngine.Repo.Migrations.CreateCognitionCheckpointsAndApprovalRequests do
  use Ecto.Migration

  def change do
    create table(:cognition_checkpoints, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false

      add :parent_checkpoint_id,
          references(:cognition_checkpoints, type: :uuid, on_delete: :nilify_all)

      add :thread_id, :string, null: false
      add :version, :integer, null: false, default: 1
      add :status, :string, null: false, default: "paused"
      add :state, :map, null: false, default: %{}
      add :pending_tasks, :map, null: false, default: %{}
      add :interrupt, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:cognition_checkpoints, [:character_id, :thread_id, :version])
    create index(:cognition_checkpoints, [:status])

    create table(:approval_requests, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :checkpoint_id, references(:cognition_checkpoints, type: :uuid, on_delete: :nilify_all)
      add :action_intent_id, references(:action_intents, type: :uuid, on_delete: :nilify_all)
      add :operation, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :policy_context, :map, null: false, default: %{}
      add :status, :string, null: false, default: "pending"
      add :requested_by, :string
      add :decided_by, :string
      add :decision_reason, :text
      add :expires_at, :utc_datetime_usec
      add :decided_at, :utc_datetime_usec
      add :correlation_id, :uuid

      timestamps(type: :utc_datetime_usec)
    end

    create index(:approval_requests, [:character_id, :status])
    create index(:approval_requests, [:checkpoint_id])
    create index(:approval_requests, [:action_intent_id])
    create index(:approval_requests, [:correlation_id])
  end
end
