#!/usr/bin/env bash
# Sovereign Soul Engine — PostgreSQL backup.
#
# Dumps the database to a timestamped, compressed archive. Restore with:
#   gunzip -c <file> | psql "$DATABASE_URL"
#
# Usage:
#   DATABASE_URL=postgres://user:pass@host:5432/sovereign_soul_engine \
#   BACKUP_DIR=/var/backups/sse \
#   RETENTION_DAYS=30 \
#   ./tools/backup_db.sh
#
# Run on a cron (e.g. nightly). The .soul capsules, relationships, and memories
# are your users' most valuable asset — back them up.

set -euo pipefail

DATABASE_URL="${DATABASE_URL:?DATABASE_URL is required}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/sse}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

mkdir -p "$BACKUP_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/sovereign_soul_engine-$STAMP.sql.gz"

pg_dump --no-owner --no-privileges "$DATABASE_URL" | gzip > "$OUT"

# Drop backups older than the retention window.
find "$BACKUP_DIR" -name 'sovereign_soul_engine-*.sql.gz' -mtime "+$RETENTION_DAYS" -delete

echo "Backup written to $OUT"
