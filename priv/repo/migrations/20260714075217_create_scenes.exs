defmodule SovereignSoulEngine.Repo.Migrations.CreateScenes do
  use Ecto.Migration

  def change do
    create table(:scenes, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :title, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :location, :string
      add :context, :map, default: %{}
      add :started_at, :utc_datetime_usec
      add :ended_at, :utc_datetime_usec
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:scenes, [:status])

    create table(:scene_participants, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :scene_id, references(:scenes, type: :uuid, on_delete: :delete_all), null: false
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :joined_at, :utc_datetime_usec, null: false, default: fragment("NOW()")

      timestamps()
    end

    create unique_index(:scene_participants, [:scene_id, :character_id])
    create index(:scene_participants, [:character_id])

    create table(:scene_messages, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :scene_id, references(:scenes, type: :uuid, on_delete: :delete_all), null: false
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :message_type, :string, null: false, default: "dialogue"
      add :content, :text, null: false
      add :private_thought, :text
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:scene_messages, [:scene_id])
    create index(:scene_messages, [:character_id])
  end
end
