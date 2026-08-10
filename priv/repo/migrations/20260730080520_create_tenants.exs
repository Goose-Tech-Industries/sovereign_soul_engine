defmodule SovereignSoulEngine.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :external_source, :string, null: false
      add :api_key_hash, :string, null: false
      add :api_key_prefix, :string, null: false
      add :rate_limit_per_minute, :integer, null: false, default: 60
      add :llm_call_count, :integer, null: false, default: 0
      add :active, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:tenants, [:external_source])
    create unique_index(:tenants, [:api_key_hash])
  end
end
