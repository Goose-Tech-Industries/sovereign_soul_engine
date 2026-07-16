defmodule SovereignSoulEngine.Repo.Migrations.CreateCharacters do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", ""

    create table(:characters, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name, :string, null: false
      add :slug, :string, null: false
      add :kind, :string, null: false, default: "npc"
      add :description, :text
      add :status, :string, null: false, default: "inactive"
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:characters, [:slug])
    create index(:characters, [:kind])
    create index(:characters, [:status])
  end
end
