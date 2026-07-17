defmodule SovereignSoulEngine.Repo.Migrations.CreateForgivenessArcs do
  use Ecto.Migration

  def change do
    create table(:forgiveness_arcs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :offender_character_id, references(:characters, type: :uuid, on_delete: :nilify_all)
      add :wound_description, :text, null: false
      add :stage, :string, default: "fresh"
      add :intensity, :integer, default: 80
      add :direction, :string, default: "neutral"

      timestamps()
    end

    create index(:forgiveness_arcs, [:character_id])
  end
end
