defmodule SovereignSoulEngine.Repo.Migrations.CreateSoulShadows do
  use Ecto.Migration

  def change do
    create table(:soul_shadows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :character_id, references(:characters, type: :binary_id, on_delete: :delete_all), null: false
      add :scene_id, references(:scenes, type: :binary_id, on_delete: :delete_all), null: false
      add :private_monologue, :text
      add :repressed_motive, :text
      add :active_defense, :string, default: "none"
      add :emotional_drift, :map

      timestamps()
    end

    create index(:soul_shadows, [:character_id])
    create index(:soul_shadows, [:scene_id])
  end
end
