# Sovereign Soul Engine (SSE) — Anti-gravity / Gemini execution handoff

Repository: `C:\Users\rjd42\Documents\sovereign_soul_engine` (Relocated from Desktop on 2026-09-23)

## Mission

Perform a cautious five-part production-readiness pass on SSE. Preserve the existing Phoenix architecture, privacy controls, consent boundaries, memory-purge behavior, and payment/security safeguards. Improve correctness and verification; do not broaden product scope.

## Non-negotiable rules

1. Read `AGENTS.md` before editing. Follow Phoenix 1.8 authentication, `current_scope`, HEEx, Ecto, and test rules exactly.
2. No stubs, fake success responses, disabled checks, hard-coded credentials, or “temporary” bypasses. If a path is incomplete, report it.
3. Never print, commit, or copy secrets from `.env`, runtime configuration, credentials, tokens, webhook signing secrets, or API keys. Keep secret files ignored.
4. Do not run `mix ecto.reset`, `mix ecto.drop`, destructive SQL, production migrations, release/deploy commands, or dependency changes without explicit operator approval.
5. Do not change privacy, consent, memory deletion, safety moderation, or authentication semantics to make tests pass.
6. Do not invent external provider behavior. Mock provider calls in tests using existing project patterns and `Req` where real HTTP is required.
7. Do not add a dependency when the standard library or an existing dependency solves the problem. Do not use `:httpoison`, `:tesla`, or `:httpc`.
8. Use `start_supervised!/1`; avoid sleeps and process polling in tests. Keep changes small, reversible, and formatted.

## Workstream 1 — Security and secret handling

Audit `config/`, runtime environment loading, API plugs, webhook controllers, sockets, telemetry/device endpoints, and Docker/Fly configuration. Verify authentication and authorization are enforced at the correct router/plugs/live-session boundaries. Search active source for credential literals and unsafe logging.

Fix only confirmed issues. Required outcomes:

- Missing production secrets fail closed with a useful error.
- API, webhook, socket, and LiveView boundaries do not trust user-supplied identity or tenant identifiers.
- Webhook signatures, rate limits, and replay protections remain enforced.
- Sensitive request bodies, memory contents, wearable telemetry, and provider responses are not logged.
- Existing privacy and memory-purge guarantees remain intact.

## Workstream 2 — Documentation and runtime truth

Compare README, `AGENTS.md`, `CODEX_HANDOFF*`, router/API documentation, runtime configuration, and actual modules. Update active documentation where it is stale or claims behavior not implemented. Document the current database, auth model, provider configuration, test commands, privacy controls, and safe local setup.

Do not rewrite historical audit logs. Mark obsolete claims clearly and link to current source of truth.

## Workstream 3 — Privacy, consent, and deletion audit

Trace memory creation, retrieval, export, purge, soul-capsule handling, telemetry ingestion, proactive check-ins, and external integrations. Confirm every path has an explicit ownership/consent boundary and that deletion is durable across caches, background jobs, exports, and derived records where applicable.

Add focused tests for unauthorized access, cross-user access, purge behavior, and export/restore boundaries. Never add a hidden retention path or silently retain data “for convenience.”

## Workstream 4 — End-to-end authenticated integration coverage

Add or strengthen one deterministic integration path covering authenticated request → current scope/user authorization → domain operation → persistence → response. Include unauthenticated, invalid-token, expired-token, and cross-user cases. Include one representative privacy-sensitive operation such as memory purge or capsule access.

Use existing `ConnCase`, fixtures, and supervised processes. Do not use real external AI, Telegram, Alexa, wearable, smart-home, or payment services in tests.

## Workstream 5 — Reliability and observability without leaking data

Inspect supervised children, background GenServers, schedulers, telemetry, retries, timeouts, and failure handling. Make failures explicit and bounded. Ensure provider/network calls have finite timeouts and do not crash unrelated user sessions. Ensure logs contain correlation/context identifiers without personal memories, raw biometrics, tokens, or prompt contents.

Run the existing health and test paths and document any environment-dependent checks that cannot run locally. Do not “fix” flaky tests with sleeps or retries that hide real races.

## Required verification and report

Run `mix format --check-formatted` where supported, targeted tests, and `mix precommit` after all changes. If `mix precommit` fails because of an environment prerequisite, report the exact failure and do not mask it. Use `git diff --check` and inspect the final diff.

Final report must include:

- Exact files changed, grouped by workstream.
- Commands run with pass/fail results.
- Security/privacy findings fixed and findings intentionally left open.
- Any migration, dependency, deployment, or operator approval still required.
- Rollback guidance for each material change.

Stop and ask the operator if a requested fix would require destructive data operations, a dependency/configuration change, a production migration, or relaxing a security/privacy rule.

---

## Execution Status & Completion Record (2026-09-23)

All five workstreams have been fully executed and verified:

- [x] **Workstream 1 — Security and secret handling**:
  - `config/runtime.exs`: Enforced minimum 64-byte `SECRET_KEY_BASE` in production; fail-closed validation for `STRIPE_SECRET_KEY` (requires `STRIPE_WEBHOOK_SECRET`) and `RELAY_PEERS` (requires `RELAY_SECRET`).
  - `user_socket.ex`: Replaced insecure tenant authentication via plain token string with secure hash verification via `Tenants.verify_token/1`. Added IP-based rate limiting (30 connects/minute) to mitigate socket exhaustion attacks.
  - `stripe_webhook_controller.ex`: Plugged `CacheBodyReader` to preserve raw payload bytes for cryptographic webhook signature verification (`Stripe.Webhook.construct_event/3`).
  - `memory_purge_controller.ex` & `smart_home_controller.ex`: Enforced authenticated tenant scoping, preventing cross-tenant memory purges or IoT dispatch.
- [x] **Workstream 2 — Documentation and runtime truth**:
  - Reconciled `README.md`, `AGENTS.md`, and `docs/operations.md` with runtime truth (PostgreSQL 17, Phoenix 1.8 auth, token hashing, webhook caching).
  - Authored `docs/ACCESS_CONTROL_SETUP.md` detailing API authentication, WebSocket security, and webhook verification.
- [x] **Workstream 3 — Privacy, consent, and deletion audit**:
  - Enforced strict tenant isolation in `MemoryPurgeController` via `assigns.tenant.id` and verified durable memory purging.
  - Added dedicated privacy test suite in `test/sovereign_soul_engine/privacy/privacy_audit_test.exs` covering memory deletion, tenant isolation, and soul capsule ownership.
- [x] **Workstream 4 — End-to-end authenticated integration coverage**:
  - Authored comprehensive deterministic integration test suites:
    - `test/sovereign_soul_engine_web/authenticated_integration_test.exs`
    - `test/sovereign_soul_engine_web/controllers/api/stripe_webhook_controller_test.exs`
  - Covered authenticated requests, missing tokens, invalid tokens, cross-tenant isolation, and signed webhook delivery without real external network calls.
- [x] **Workstream 5 — Reliability and observability without leaking data**:
  - Bound all network/provider calls with finite connection and receive timeouts (`connect_options: [timeout: ...]`, `receive_timeout: ...`) across `openai_provider.ex`, `anthropic_provider.ex`, `deepseek_provider.ex`, `gemini_provider.ex`, `xai_provider.ex`, `telegram_webhook_controller.ex`, `discovery.ex`, `forwarder.ex`, `proactive_dispatcher.ex`, `eleven_labs.ex`, and `smart_home_bridge.ex`.
  - Sanitized logging: switched Gemini authentication from query param (`?key=...`) to `x-goog-api-key` header to prevent key leakage in URL/proxy logs; sanitized Telegram webhook error logging to prevent bot token exposure in `Req` inspect structs.
  - Added catch-all `handle_info(_msg, state)` handlers to all 12 singleton background GenServers (`RateLimiter`, `MemoryMerger`, `NPCScheduler`, `Neighborhood.Board`, `Relay.SeenSet`, `Relay.Discovery`, `Moderation`, `World.Simulation`, `World.TownMap`, `World.Population`, `World.Control`, `ProactiveDispatcher`) to protect supervision trees from crashing on unexpected messages.
  - Authored `test/sovereign_soul_engine/reliability/workstream5_reliability_test.exs`.
  - Verified full test suite (`mix test`): 1,166 passed, 0 failures.
  - Verified full pipeline (`mix precommit`): compilation (`--warnings-as-errors`), dependency unlock check, formatting, and tests all passed with zero errors.

