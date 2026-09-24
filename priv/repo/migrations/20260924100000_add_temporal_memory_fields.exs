defmodule SovereignSoulEngine.Repo.Migrations.AddTemporalMemoryFields do
  use Ecto.Migration

  def change do
    alter table(:memories) do
      add :valid_from, :utc_datetime_usec
      add :valid_until, :utc_datetime_usec
      add :supersedes_id, references(:memories, type: :uuid, on_delete: :nilify_all)
      add :superseded_by_id, references(:memories, type: :uuid, on_delete: :nilify_all)
      add :supersession_reason, :text
      add :provenance, :map, default: %{}
    end

    create index(:memories, [:valid_from])
    create index(:memories, [:valid_until])
    create index(:memories, [:supersedes_id])
    create index(:memories, [:superseded_by_id])

    execute(
      """
      UPDATE memories
      SET valid_from = NULLIF(metadata->>'valid_from', '')::timestamptz,
          valid_until = NULLIF(metadata->>'valid_until', '')::timestamptz,
          supersedes_id = NULLIF(metadata->>'supersedes_id', '')::uuid,
          superseded_by_id = NULLIF(metadata->>'superseded_by_id', '')::uuid,
          supersession_reason = metadata->>'supersession_reason',
          provenance = COALESCE(metadata->'provenance', '{}'::jsonb)
      WHERE metadata IS NOT NULL
        AND (metadata ? 'valid_from'
          OR metadata ? 'valid_until'
          OR metadata ? 'supersedes_id'
          OR metadata ? 'superseded_by_id'
          OR metadata ? 'provenance')
      """,
      ""
    )
  end
end
