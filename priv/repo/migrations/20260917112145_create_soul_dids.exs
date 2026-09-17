defmodule SovereignSoulEngine.Repo.Migrations.CreateSoulDids do
  use Ecto.Migration

  def up do
    drop_if_exists table(:soul_dids)

    create table(:soul_dids, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :character_id,
          references(:characters, type: :uuid, on_delete: :delete_all),
          null: false

      add :did, :string, null: false
      add :public_key, :binary, null: false
      add :private_key_sealed, :binary
      add :active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:soul_dids, [:did])
    create unique_index(:soul_dids, [:character_id], where: "active = true", name: :soul_dids_active_character_unique)
  end

  def down do
    drop_if_exists table(:soul_dids)
  end
end
