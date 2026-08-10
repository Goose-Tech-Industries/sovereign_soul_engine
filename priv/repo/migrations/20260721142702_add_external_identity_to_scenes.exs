defmodule SovereignSoulEngine.Repo.Migrations.AddExternalIdentityToScenes do
  use Ecto.Migration

  def change do
    alter table(:scenes) do
      add :external_source, :string
      add :external_id, :string
    end

    create unique_index(:scenes, [:external_source, :external_id])
  end
end
