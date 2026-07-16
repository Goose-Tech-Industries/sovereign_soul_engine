defmodule SovereignSoulEngine.Repo.Migrations.CreateEmotionalStates do
  use Ecto.Migration

  def change do
    create table(:emotional_states, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :anger, :integer, null: false, default: 0
      add :fear, :integer, null: false, default: 0
      add :stress, :integer, null: false, default: 0
      add :gratitude, :integer, null: false, default: 0
      add :confidence, :integer, null: false, default: 50
      add :sadness, :integer, null: false, default: 0
      add :curiosity, :integer, null: false, default: 50
      add :attachment, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:emotional_states, [:character_id])
  end
end
