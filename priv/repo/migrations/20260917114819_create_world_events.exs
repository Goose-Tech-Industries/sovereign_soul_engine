defmodule SovereignSoulEngine.Repo.Migrations.CreateWorldEvents do
  use Ecto.Migration

  def change do
    create table(:world_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :from_did, :string
      add :to_did, :string
      add :payload, :map, default: %{}
      add :signature, :string
      add :retained_until, :utc_datetime
      add :compacted, :boolean, default: false, null: false

      timestamps()
    end

    create index(:world_events, [:kind])
    create index(:world_events, [:inserted_at])
  end
end
