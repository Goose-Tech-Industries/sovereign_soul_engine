defmodule SovereignSoulEngine.Repo.Migrations.CreateCharacterGoals do
  use Ecto.Migration

  def change do
    create table(:character_goals, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :goal, :text, null: false
      add :current_step, :text
      add :blocker, :text
      add :priority, :integer, default: 50
      add :status, :string, default: "active"
      add :target_character_id, references(:characters, type: :uuid, on_delete: :nilify_all)
      add :progress_notes, :text

      timestamps()
    end

    create index(:character_goals, [:character_id])
    create index(:character_goals, [:character_id, :status])
  end
end
