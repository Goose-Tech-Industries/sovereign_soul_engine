defmodule SovereignSoulEngine.Repo.Migrations.CreateCharacterBeliefs do
  use Ecto.Migration

  def change do
    create table(:character_beliefs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :belief, :text, null: false
      add :domain, :string, null: false
      add :conviction, :integer, default: 50
      add :is_challenged, :boolean, default: false
      add :challenged_evidence, :text

      timestamps()
    end

    create index(:character_beliefs, [:character_id])
  end
end
