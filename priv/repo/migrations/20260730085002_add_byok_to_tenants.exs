defmodule SovereignSoulEngine.Repo.Migrations.AddByokToTenants do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :byok_provider, :string
      add :byok_api_key_encrypted, :binary
    end
  end
end
