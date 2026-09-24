defmodule SovereignSoulEngine.Repo.Migrations.CreateLorebookEntries do
  use Ecto.Migration

  def change do
    create table(:lorebook_entries, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :scope, :string, null: false, default: "global"
      add :slug, :string, null: false
      add :title, :string, null: false
      add :keys, {:array, :string}, null: false, default: []
      add :secondary_keys, {:array, :string}, null: false, default: []
      add :category, :string, null: false, default: "lore"
      add :priority, :integer, null: false, default: 50
      add :content, :text, null: false
      add :metadata, :map, null: false, default: %{}
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:lorebook_entries, [:scope, :slug])
    create index(:lorebook_entries, [:scope, :enabled])
  end
end
