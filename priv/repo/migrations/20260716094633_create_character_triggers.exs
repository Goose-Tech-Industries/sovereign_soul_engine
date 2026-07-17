defmodule SovereignSoulEngine.Repo.Migrations.CreateCharacterTriggers do
  use Ecto.Migration

  def change do
    create table(:character_triggers, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :topic, :string, null: false
      add :reaction_type, :string, null: false
      add :intensity_modifier, :integer, default: 0
      add :flavor_text, :text

      timestamps()
    end

    create index(:character_triggers, [:character_id])
  end
end
