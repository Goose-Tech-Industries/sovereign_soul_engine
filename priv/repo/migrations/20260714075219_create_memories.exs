defmodule SovereignSoulEngine.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def change do
    create table(:memories, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")

      add :owner_character_id, references(:characters, type: :uuid, on_delete: :delete_all),
        null: false

      add :subject_character_id, references(:characters, type: :uuid, on_delete: :nilify_all)
      add :scene_id, references(:scenes, type: :uuid, on_delete: :nilify_all)
      add :event_id, references(:soul_events, type: :uuid, on_delete: :nilify_all)
      add :category, :string, null: false
      add :summary, :text, null: false
      add :details, :map, default: %{}
      add :importance, :integer, null: false, default: 1
      add :emotional_intensity, :integer, null: false, default: 0
      add :confidence, :integer, null: false, default: 100
      add :valence, :float, null: false, default: 0.0
      add :tags, {:array, :string}, default: []
      add :emotional_residue, :map, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false
      add :last_recalled_at, :utc_datetime_usec
      add :recall_count, :integer, null: false, default: 0
      add :decay_rate, :float, null: false, default: 1.0
      add :is_resolved, :boolean, null: false, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:memories, [:owner_character_id])
    create index(:memories, [:subject_character_id])
    create index(:memories, [:scene_id])
    create index(:memories, [:event_id])
    create index(:memories, [:category])
    create index(:memories, [:occurred_at])
    create index(:memories, [:importance])
    create index(:memories, [:emotional_intensity])
    create index(:memories, [:is_resolved])
  end
end
