defmodule SovereignSoulEngine.Repo.Migrations.CreateSomaticStates do
  use Ecto.Migration

  def change do
    create table(:somatic_states, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :hunger, :integer, default: 0
      add :pain, :integer, default: 0
      add :fatigue, :integer, default: 20
      add :illness_severity, :integer, default: 0
      add :last_ate_at, :utc_datetime
      add :last_rested_at, :utc_datetime

      timestamps()
    end

    create unique_index(:somatic_states, [:character_id])
  end
end
