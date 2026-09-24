defmodule SovereignSoulEngine.Repo.Migrations.AddExternalExecutionTracking do
  use Ecto.Migration

  def change do
    alter table(:approval_requests) do
      add :execution_key, :string
      add :execution_status, :string
      add :execution_result, :map, default: %{}
      add :executed_at, :utc_datetime_usec
    end

    create unique_index(:approval_requests, [:execution_key], where: "execution_key IS NOT NULL")
  end
end
