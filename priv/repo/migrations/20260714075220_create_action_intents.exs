defmodule SovereignSoulEngine.Repo.Migrations.CreateActionIntents do
  use Ecto.Migration

  def change do
    create table(:action_intents, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :scene_id, references(:scenes, type: :uuid, on_delete: :nilify_all), null: false
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :target_character_id, references(:characters, type: :uuid, on_delete: :nilify_all)
      add :proposed_action, :string, null: false
      add :proposed_confidence, :float
      add :proposed_reason, :text
      add :validation_status, :string, null: false, default: "pending"
      add :resolved_action, :string
      add :rejection_reason, :text
      add :transformation_reason, :text
      add :consequences, :map, default: %{}
      add :correlation_id, :uuid

      timestamps()
    end

    create index(:action_intents, [:scene_id])
    create index(:action_intents, [:character_id])
    create index(:action_intents, [:target_character_id])
    create index(:action_intents, [:validation_status])
    create index(:action_intents, [:correlation_id])
  end
end
