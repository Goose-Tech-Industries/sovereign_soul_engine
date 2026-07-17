defmodule SovereignSoulEngine.Repo.Migrations.CreateGriefArcs do
  use Ecto.Migration

  def change do
    create table(:grief_arcs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :subject, :text, null: false
      add :loss_type, :string, default: "person"
      add :stage, :string, default: "denial"
      add :intensity, :integer, default: 70
      add :triggered_at, :utc_datetime, null: false
      add :last_progressed_at, :utc_datetime
      add :is_resolved, :boolean, default: false

      timestamps()
    end

    create index(:grief_arcs, [:character_id])
  end
end
