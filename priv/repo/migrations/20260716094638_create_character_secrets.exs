defmodule SovereignSoulEngine.Repo.Migrations.CreateCharacterSecrets do
  use Ecto.Migration

  def change do
    create table(:character_secrets, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :secret_text, :text, null: false
      add :risk_level, :string, default: "medium"
      add :domain, :string
      add :revealed_to, {:array, :uuid}, default: []

      timestamps()
    end

    create index(:character_secrets, [:character_id])
  end
end
