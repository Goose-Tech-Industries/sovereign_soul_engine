defmodule SovereignSoulEngine.Repo.Migrations.AddRelationshipTypeToRelationships do
  use Ecto.Migration

  def change do
    alter table(:relationships) do
      add :relationship_type, :string, default: "acquaintance", null: false
    end
  end
end
