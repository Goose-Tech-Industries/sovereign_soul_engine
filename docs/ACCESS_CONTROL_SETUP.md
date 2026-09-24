# API and administrator access

The `/api` aliases now use the same bearer-key authentication and rate limiting as
`/sse/api`. The hardcoded development key and `SOVEREIGN_SOUL_API_KEY` bypass have
been removed. Provision keys with `SovereignSoulEngine.Tenants.create_tenant/3`
and send the returned key as `Authorization: Bearer <key>`. Store the key securely:
the database stores only its hash. Inactive tenant keys are rejected, and an
`external_source` supplied in a request must match the tenant.

Telegram and Alexa routes under both prefixes require tenant bearer authentication.
Stripe webhook ingress (`POST /sse/api/webhooks/stripe` and `POST /api/webhooks/stripe`)
has been moved to a dedicated `:stripe_webhook` pipeline that verifies cryptographic
Stripe signatures (`Stripe-Signature`) using `CacheBodyReader` to preserve the raw
request body, enforced with a 300-second replay tolerance window and fail-closed
`STRIPE_WEBHOOK_SECRET` validation. This supersedes the previous temporary bearer
auth requirement for Stripe webhooks.

ACP routes stay in the `/sse/acp` scope and `:acp` LiveView session. The scope uses
`:browser`, `:require_authenticated_user`, and `:require_admin_user`; the session
uses `UserAuth`'s `:require_admin` mount hook to enforce authorization again for
LiveView connections. Only confirmed accounts with an ID in `SSE_ADMIN_USER_IDS`
can access ACP. Set that environment variable to a comma-separated list of
existing user UUIDs and restart the application. An empty list denies all ACP
access. Subscription tiers and email addresses do not grant administrator access.

The optional `priv/repo/create_admin.exs` provisioning script requires
`SSE_ADMIN_PASSWORD` and accepts `SSE_ADMIN_EMAIL`. It does not print the password.
Add the resulting user UUID to `SSE_ADMIN_USER_IDS` to grant ACP access.

Memory purge requests must explicitly supply `character_slug` (or `slug`) and a
nonblank `topic`/`query`, a nonblank `category`, or `all: true`. Missing or malformed
intent returns HTTP 400 without deletion. Domain purge functions also reject
unfiltered deletion. Topic matching is a literal case-insensitive substring;
SQL wildcard characters have no special meaning. Category-only purges leave
Theory of Mind knowledge intact.

These changes enforce authentication at the reviewed route boundaries. They do
not introduce character ownership checks for every tenant API operation; the
existing API still gives authenticated tenants access to some shared character
data. Treat tenant keys as trusted integration credentials until that separate
authorization model is implemented.

## Verification on 2026-09-22

After installing PostgreSQL 17.11, all 22 targeted security regression tests
passed. The full `mix precommit` run passed all 1,133 tests. Existing API tests
were updated to authenticate using database-backed tenant keys. Unrelated
repository formatting changes were restored to preserve the existing work.
Windows emitted a nonblocking LiveView node_modules symlink permission warning.

To repeat verification, run:

```powershell
mix test test/sovereign_soul_engine/memories/purge_filters_test.exs test/sovereign_soul_engine_web/controllers/api/access_control_test.exs test/sovereign_soul_engine_web/controllers/api/memory_purge_controller_test.exs test/sovereign_soul_engine_web/live/acp_access_test.exs test/sovereign_soul_engine_web/live/acp_moderation_live_test.exs
mix precommit
```

## Local prerequisites

PostgreSQL 17.11 is installed at `C:\Program Files\PostgreSQL\17`. The
`postgresql-x64-17` Windows service starts automatically and listens only on
localhost, port 5432. The local development account is `postgres`, with password
`postgres`, matching the repository's test configuration.

WSL was updated to 2.7.13 and its version command now works. The Windows Virtual
Machine Platform feature was enabled without an automatic restart. Restart
Windows to finish enabling that feature. No Linux distribution is registered
yet. Native Elixir and PostgreSQL already support this project's test suite.
