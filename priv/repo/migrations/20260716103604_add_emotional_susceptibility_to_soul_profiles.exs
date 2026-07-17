defmodule SovereignSoulEngine.Repo.Migrations.AddEmotionalSusceptibilityToSoulProfiles do
  use Ecto.Migration

  def change do
    alter table(:soul_profiles) do
      add :emotional_susceptibility, :integer, default: 50
    end
  end
end
