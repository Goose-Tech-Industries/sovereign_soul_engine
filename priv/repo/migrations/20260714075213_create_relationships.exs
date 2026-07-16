defmodule SovereignSoulEngine.Repo.Migrations.CreateRelationships do
  use Ecto.Migration

  def change do
    create table(:relationships, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")

      add :source_character_id, references(:characters, type: :uuid, on_delete: :delete_all),
        null: false

      add :target_character_id, references(:characters, type: :uuid, on_delete: :delete_all),
        null: false

      add :affinity, :integer, null: false, default: 0
      add :trust, :integer, null: false, default: 0
      add :respect, :integer, null: false, default: 0
      add :fear, :integer, null: false, default: 0
      add :anger, :integer, null: false, default: 0
      add :gratitude, :integer, null: false, default: 0
      add :debt, :integer, null: false, default: 0
      add :softening, :integer, null: false, default: 0
      add :hardening, :integer, null: false, default: 0
      add :wound, :integer, null: false, default: 0
      add :lock_version, :integer, null: false, default: 1
      add :last_interaction_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:relationships, [:source_character_id, :target_character_id])
    create index(:relationships, [:target_character_id])
  end
end
