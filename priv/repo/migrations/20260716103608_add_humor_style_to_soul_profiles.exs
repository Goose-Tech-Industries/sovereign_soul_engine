defmodule SovereignSoulEngine.Repo.Migrations.AddHumorStyleToSoulProfiles do
  use Ecto.Migration

  def change do
    alter table(:soul_profiles) do
      add :humor_style, :string, default: "none"
    end
  end
end
