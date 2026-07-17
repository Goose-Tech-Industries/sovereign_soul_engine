defmodule SovereignSoulEngine.Repo.Migrations.AddStatusAndConsolidationToMemories do
  use Ecto.Migration

  def change do
    alter table(:memories) do
      add :status, :string, default: "active", null: false
      add :consolidated_into_id, references(:memories, type: :uuid, on_delete: :nilify_all)
    end

    create index(:memories, [:status])
    create index(:memories, [:owner_character_id, :status])
  end
end
