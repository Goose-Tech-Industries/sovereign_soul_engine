defmodule SovereignSoulEngine.Repo.Migrations.CreateSocialPosts do
  use Ecto.Migration

  def change do
    create table(:social_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :character_id, references(:characters, type: :binary_id, on_delete: :delete_all), null: false
      add :content, :string, size: 280, null: false
      add :mood, :string
      add :platform, :string, default: "twitter"
      add :status, :string, default: "published"
      add :metadata, :map, default: %{}
      add :posted_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:social_posts, [:character_id])
    create index(:social_posts, [:posted_at])
  end
end
