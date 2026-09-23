defmodule SovereignSoulEngine.Repo.Migrations.AddCompanionPrivacyAndUserTiers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :subscription_tier, :string, default: "free", null: false
      add :stripe_customer_id, :string
      add :opt_out_living_world, :boolean, default: false, null: false
    end

    alter table(:characters) do
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :in_living_world, :boolean, default: true, null: false
    end

    create index(:characters, [:user_id])
    create index(:characters, [:in_living_world])
  end
end
