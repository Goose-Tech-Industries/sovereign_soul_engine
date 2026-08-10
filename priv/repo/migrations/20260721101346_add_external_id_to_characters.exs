defmodule SovereignSoulEngine.Repo.Migrations.AddExternalIdToCharacters do
  use Ecto.Migration

  def change do
    # Maps a character to an identity owned by an external game (e.g. a
    # Twisted Paradox player_id) — SSE is meant to be a soul engine any
    # game can plug into, not just this one's own dev-harness "Goose".
    # Nullable: NPCs and the existing dev-harness player never set these.
    alter table(:characters) do
      add :external_source, :string
      add :external_id, :string
    end

    create unique_index(:characters, [:external_source, :external_id])
  end
end
