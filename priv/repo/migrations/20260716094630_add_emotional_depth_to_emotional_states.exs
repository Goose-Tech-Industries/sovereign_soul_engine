defmodule SovereignSoulEngine.Repo.Migrations.AddEmotionalDepthToEmotionalStates do
  use Ecto.Migration

  def change do
    alter table(:emotional_states) do
      add :shame, :integer, default: 0
      add :guilt, :integer, default: 0
      add :mood_baseline, :map, default: %{}
      add :rumination_subject, :string
      add :rumination_intensity, :integer, default: 0
      add :rumination_since, :utc_datetime
    end
  end
end
