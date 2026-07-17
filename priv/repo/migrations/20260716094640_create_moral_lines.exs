defmodule SovereignSoulEngine.Repo.Migrations.CreateMoralLines do
  use Ecto.Migration

  def change do
    create table(:moral_lines, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :character_id, references(:characters, type: :uuid, on_delete: :delete_all), null: false
      add :principle, :text, null: false
      add :will_refuse_when_violated, :boolean, default: true
      add :action_types_blocked, {:array, :string}, default: []

      timestamps()
    end

    create index(:moral_lines, [:character_id])
  end
end
