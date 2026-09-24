# Operations Runbook (DRAFT)

What it takes to run Sovereign Soul Engine in production.

## 1. Deploy

- Image: `Dockerfile` (multi-stage Elixir/OTP release). Verify the `ARG
  BUILDER_IMAGE` tag against `elixir --version` before building.
- Host: `fly.toml` is a ready template (Fly.io handles TLS + Postgres). Set the
  secrets it lists before `fly deploy`.

## 2. Required secrets and configuration

| Var | Purpose | Notes |
|---|---|---|
| `SECRET_KEY_BASE` | signs/encrypts cookies and seals soul keys | `mix phx.gen.secret` (minimum 64 bytes enforced at boot) |
| `DATABASE_URL` | Postgres connection | managed DB URL (`ecto://USER:PASS@HOST/DATABASE`) |
| `STRIPE_SECRET_KEY` | Stripe billing integration | optional in dev/prod |
| `STRIPE_WEBHOOK_SECRET` | Stripe signature verification | required in prod if `STRIPE_SECRET_KEY` is set |
| `SSE_ADMIN_USER_IDS` | Allowlist of user UUIDs for ACP access | comma-separated UUIDs |
| `RELAY_SECRET` | authenticates relay peers | required if `RELAY_PEERS` set |
| `RELAY_PEERS` | comma-separated peer base URLs | optional |
| `MODERATION_BLOCKED_TERMS` | comma-separated terms to scrub | optional |
| `SENTRY_DSN` | error tracking | optional (uses `Sentry.ReqClient`) |
| `PORT` | HTTP port | default `8561` |

Prod startup **raises** if:
- `SECRET_KEY_BASE` is missing or shorter than 64 bytes.
- `STRIPE_SECRET_KEY` is set without `STRIPE_WEBHOOK_SECRET`.
- `RELAY_PEERS` is set without `RELAY_SECRET`.

## 3. Bootstrap (first deploy)

```sh
# provision a tenant so clients can connect over WebSocket in prod
mix sse.create_tenant "studio-name" "external-source" 60

# seed the 50 founding souls + the world
mix run priv/repo/seeds/seed_souls.exs
```

## 4. Backups

`tools/backup_db.sh` runs `pg_dump | gzip` with retention. Wire it to a nightly
cron:

```sh
0 2 * * * DATABASE_URL=... BACKUP_DIR=/var/backups/sse RETENTION_DAYS=30 /app/tools/backup_db.sh
```

The `.soul` capsules, relationships, and memories are user data — treat backup
+ restore as a practiced, tested procedure, not a checkbox.

## 5. Monitoring

- **Errors:** wire `SENTRY_DSN` (the `Sentry.PlugCapture` plug is already in the
  endpoint).
- **Metrics:** `Telemetry` is instrumented; export via your APM of choice.
- **Watch these:** WebSocket connect rate (per-IP limit is 30/min), LLM call
  counts per tenant (`Tenants.record_llm_call`), and world-event volume (the
  `WorldCompactor` + `purge_events` bound it).

## 6. Safety & moderation

- `Moderation` scrubs `MODERATION_BLOCKED_TERMS` and can mute DIDs
  (`Moderation.mute_did/1`).
- The consent/anti-parasocial/intimacy-ceiling/safe-word layer is enforced in
  code; ensure it is *documented to users* (see `docs/legal/`) and that you have
  a human moderation loop for edge cases.
