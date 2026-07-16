defmodule SovereignSoulEngine.Repo.Migrations.CreateSoulLedger do
  use Ecto.Migration

  def change do
    create table(:soul_ledger, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :scene_id, references(:scenes, type: :uuid, on_delete: :nilify_all)
      add :event_id, references(:soul_events, type: :uuid, on_delete: :nilify_all)
      add :relationship_id, references(:relationships, type: :uuid, on_delete: :nilify_all)
      add :memory_id, references(:memories, type: :uuid, on_delete: :nilify_all)
      add :entry_type, :string, null: false
      add :source, :string, null: false
      add :label, :string
      add :summary, :text, null: false
      add :before_state, :map, default: %{}
      add :delta, :map, default: %{}
      add :after_state, :map, default: %{}
      add :reason, :text
      add :tags, {:array, :string}, default: []
      add :correlation_id, :uuid

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:soul_ledger, [:character_id])
    create index(:soul_ledger, [:scene_id])
    create index(:soul_ledger, [:event_id])
    create index(:soul_ledger, [:entry_type])
    create index(:soul_ledger, [:correlation_id])
    create index(:soul_ledger, [:inserted_at])
  end
end
