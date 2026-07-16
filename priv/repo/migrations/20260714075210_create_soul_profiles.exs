defmodule SovereignSoulEngine.Repo.Migrations.CreateSoulProfiles do
  use Ecto.Migration

  def change do
    create table(:soul_profiles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :personality_traits, :map, default: %{}
      add :core_values, {:array, :string}, default: []
      add :fears, {:array, :string}, default: []
      add :desires, {:array, :string}, default: []
      add :speech_style, :text
      add :behavioral_constraints, :map, default: %{}
      add :baseline_emotions, :map, default: %{}
      add :identity_summary, :text
      add :version, :integer, null: false, default: 1

      timestamps()
    end

    create unique_index(:soul_profiles, [:character_id])
  end
end
