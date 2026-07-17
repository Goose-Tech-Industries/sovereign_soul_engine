defmodule SovereignSoulEngine.Repo.Migrations.AddAutonomousToScenes do
  use Ecto.Migration

  def change do
    alter table(:scenes) do
      add :is_autonomous, :boolean, default: false, null: false
    end

    create index(:scenes, [:is_autonomous])
  end
end
