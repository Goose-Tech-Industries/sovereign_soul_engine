defmodule SovereignSoulEngine.Repo.Migrations.CreateSoulEvents do
  use Ecto.Migration

  def change do
    create table(:soul_events, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :scene_id, references(:scenes, type: :uuid, on_delete: :nilify_all)
      add :source_character_id, references(:characters, type: :uuid, on_delete: :nilify_all)
      add :target_character_id, references(:characters, type: :uuid, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :intensity, :integer, null: false, default: 50
      add :payload, :map, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false
      add :correlation_id, :uuid

      timestamps()
    end

    create index(:soul_events, [:scene_id])
    create index(:soul_events, [:source_character_id])
    create index(:soul_events, [:target_character_id])
    create index(:soul_events, [:event_type])
    create index(:soul_events, [:occurred_at])
    create index(:soul_events, [:correlation_id])
  end
end
