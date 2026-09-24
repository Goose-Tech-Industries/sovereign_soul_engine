defmodule SovereignSoulEngine.Repo.Migrations.CreateCharacterLifeThreads do
  use Ecto.Migration

  def change do
    create table(:character_life_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :topic, :string, null: false
      add :category, :string, default: "milestone"
      add :status, :string, default: "pending"
      add :salience, :integer, default: 70
      add :due_at, :utc_datetime_usec
      add :check_in_sent_at, :utc_datetime_usec
      add :check_in_guidance, :text
      add :resolution_notes, :text

      add :knower_character_id, references(:characters, type: :binary_id, on_delete: :delete_all),
        null: false

      add :subject_character_id,
          references(:characters, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:character_life_threads, [:knower_character_id, :subject_character_id])
    create index(:character_life_threads, [:status, :due_at])
  end
end
