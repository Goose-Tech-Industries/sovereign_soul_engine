defmodule SovereignSoulEngine.Repo.Migrations.AddPsychologicalDepthToSoulProfiles do
  use Ecto.Migration

  def change do
    alter table(:soul_profiles) do
      add :attachment_style, :string, default: "secure"
      add :transference_profile, :map, default: %{}
      add :physical_tells, :map, default: %{}
    end
  end
end
