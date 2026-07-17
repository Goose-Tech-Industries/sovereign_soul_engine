defmodule SovereignSoulEngine.Repo.Migrations.CreateCharacterKnowledge do
  use Ecto.Migration

  def change do
    create table(:character_knowledge, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :knower_character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :subject_character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :known_fact, :text, null: false
      add :certainty, :integer, default: 70
      add :is_assumption, :boolean, default: true
      add :last_updated_at, :utc_datetime

      timestamps()
    end

    create index(:character_knowledge, [:knower_character_id, :subject_character_id])
  end
end
