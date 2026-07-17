defmodule SovereignSoulEngine.Repo.Migrations.CreateSoulDesires do
  use Ecto.Migration

  def change do
    create table(:soul_desires, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :desire, :text, null: false
      add :domain, :string, null: false
      add :urgency, :integer, default: 50
      add :status, :string, default: "active"
      add :blocking_belief, :text

      timestamps()
    end

    create index(:soul_desires, [:character_id])
  end
end
