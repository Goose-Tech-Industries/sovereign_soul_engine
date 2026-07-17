defmodule SovereignSoulEngine.Repo.Migrations.CreateSoulFears do
  use Ecto.Migration

  def change do
    create table(:soul_fears, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :character_id, references(:characters, type: :binary_id, on_delete: :delete_all),
        null: false

      add :fear_type, :string, null: false
      add :severity, :integer, default: 50, null: false
      add :origin, :string, default: "baked_in", null: false
      add :status, :string, default: "active", null: false

      add :acquired_in_scene_id, references(:scenes, type: :binary_id, on_delete: :nilify_all),
        null: true

      timestamps()
    end

    create index(:soul_fears, [:character_id])
    create index(:soul_fears, [:character_id, :status])
  end
end
