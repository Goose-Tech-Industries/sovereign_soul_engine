# Environment Audit — Sovereign Soul Engine

**Date**: 2026-07-14
**Conducted by**: Automated build agent

---

## 1. Operating System

| Property       | Value                                                                 |
|----------------|-----------------------------------------------------------------------|
| OS             | Ubuntu 24.04.4 LTS (Noble Numbat)                                     |
| Kernel         | Linux 6.8.0-107-generic (x86_64)                                      |
| CPU Count      | 4 cores                                                               |
| RAM            | 7.8 GiB total, ~4.7 GiB available                                     |
| Disk           | 154 GB total, 129 GB available (17% used)                             |

## 2. Language & Runtime Versions

| Tool              | Version                     |
|-------------------|-----------------------------|
| Erlang/OTP        | 26 (erts-14.2.5)            |
| Elixir            | 1.16.3                      |
| Mix               | 1.16.3                      |
| Hex               | 2.4.1                       |
| Node.js           | v20.20.2                    |
| npm               | 10.8.2                      |
| pnpm              | 10.33.0                     |

## 3. Phoenix & Key Dependencies

_(From `mix.exs` and `mix.lock`)_

| Dependency           | Version / Constraint |
|----------------------|-----------------------|
| phoenix              | 1.8.9 (locked)        |
| phoenix_live_view    | 1.1.32 (locked)        |
| phoenix_ecto         | 4.7.0 (locked)         |
| ecto_sql             | 3.14.0 (locked)        |
| ecto                 | 3.14.1 (locked)        |
| postgrex             | 0.22.3 (locked)        |
| bandit               | 1.12.0 (locked)        |
| phoenix_html         | 4.3.0 (locked)         |
| req                  | 0.6.2 (locked)         |
| swoosh               | 1.26.3 (locked)        |
| jason                | 1.4.5 (locked)         |
| tailwind             | 0.5.1 (locked)         |
| esbuild              | 0.10.0 (locked)         |
| heroicons            | v2.2.0 (git tag)       |
| lazy_html            | >= 0.1.0 (test only)   |

## 4. PostgreSQL

| Property   | Value                                          |
|------------|------------------------------------------------|
| Version    | PostgreSQL 16.14 (Ubuntu 16.14-...)            |
| Status     | Running, accepting connections on localhost     |
| Auth       | User: `postgres`, Password: `postgres`          |
| Dev DB     | `sovereign_soul_engine_dev` (not yet created)   |
| Test DB    | `sovereign_soul_engine_test` (not yet created)  |

## 5. External Services & Tools

### 5.1 n8n
- **Not detected** as a running service or installed binary.
- A `pm2` process named `twisted-player` is running (unrelated; DO NOT touch).
- n8n may be available as a Docker container but none is currently running.

### 5.2 Cinema
- Located at `/root/goose_panel/priv/cinema/`.
- It is a **Playwright-driven demo recorder** for the GOOSE Panel application.
- Package: `goose-panel-cinema` v0.1.0.
- Uses Playwright (^1.60.0) to walk a recipe, capture WebM video, and output to disk.
- **Relevance to Soul Core**: Potentially useful for capturing browser-based demos or E2E test recordings, but not a direct integration requirement for Soul Core Milestone 1. Will document and not integrate yet.

### 5.3 Playwright
| Property   | Value                                          |
|------------|------------------------------------------------|
| Version    | 1.61.1 (npx playwright)                         |
| Browsers   | chromium-1217, chromium-1223, firefox-1511, webkit-2272 (all installed) |
| Status     | Ready for E2E testing                           |

### 5.4 DeepSeek
- No DeepSeek API key or endpoint was detected in environment variables.
- Will be configured later via `DEEPSEEK_API_KEY` or similar env var.

## 6. Git Repository

| Property    | Value                                            |
|-------------|--------------------------------------------------|
| Branch      | `master` (no commits yet)                        |
| Remote      | None configured                                  |
| State       | All files untracked, fresh project               |
| Action      | Feature branch `feature/sovereign-soul-core` recommended |

## 7. Existing Project State

### 7.1 Phoenix Application
- Already initialized as `SovereignSoulEngine` (app: `:sovereign_soul_engine`).
- Compiles cleanly — `mix compile` outputs "Generated sovereign_soul_engine app".
- All deps are fetched and locked.

### 7.2 Migrations (already created)
All 9 required migrations exist under `priv/repo/migrations/`:

| File                                    | Table                |
|-----------------------------------------|----------------------|
| `20260714075208_create_characters`      | `characters`          |
| `20260714075210_create_soul_profiles`   | `soul_profiles`       |
| `20260714075212_create_emotional_states`| `emotional_states`    |
| `20260714075213_create_relationships`   | `relationships`       |
| `20260714075217_create_scenes`          | `scenes` (+ `scene_participants`, `scene_messages`) |
| `20260714075218_create_soul_events`     | `soul_events`         |
| `20260714075219_create_memories`        | `memories`            |
| `20260714075220_create_action_intents`  | `action_intents`      |
| `20260714075221_create_soul_ledger`     | `soul_ledger`         |

All use UUID primary keys with `uuid_generate_v4()` defaults, matching the specification.

### 7.3 Ecto Schemas
- **Not yet created** — need to add schema modules for each migration.

### 7.4 Domain Contexts
- Only the default `SovereignSoulEngine` root module exists.
- Need to establish: `SovereignSoulEngine.Characters`, `SovereignSoulEngine.Souls`, etc.

### 7.5 Test Configuration
- `test/test_helper.exs` — configured with sandbox mode `:manual`.
- `test/support/data_case.ex` — DataCase with sandbox setup.
- `test/support/conn_case.ex` — ConnCase for web tests.
- 3 default controller tests exist (page_controller, error_json, error_html).

### 7.6 Configuration Files
- `config/config.exs` — base config (endpoint, repo, esbuild, tailwind).
- `config/dev.exs` — dev database, watchers, live reload.
- `config/test.exs` — test database, sandbox pool, no server.
- `config/runtime.exs` — runtime/prod config with DATABASE_URL support.
- `config/prod.exs` — (not yet inspected; assumed default).

## 8. Port Availability

| Port | Use                |
|------|--------------------|
| 4000 | Phoenix (default)   |
| 4002 | Phoenix test        |
| 5432 | PostgreSQL          |

No port conflicts detected. `4000` and `4002` are available.

## 9. Environment Variables

No sensitive variables detected for the project. Relevant env vars:
- `ANTIGRAVITY_SOURCE_METADATA` — task runner metadata (not project-specific).

## 10. Decisions & Findings

1. **Project already scaffolded**: The `mix phx.new` step was already completed with the correct name, PostgreSQL adapter, and asset pipeline.
2. **Migrations already exist**: All 9 required tables are defined with proper UUID primary keys and relationships matching the spec.
3. **Ecto schemas need to be created**: The struct/schema modules are missing.
4. **Domain context modules need to be established**: Directory structure and context modules are not yet created.
5. **Cinema is a Playwright recorder**: Not directly needed for Soul Core, but could later record demos.
6. **n8n is not running**: Integration boundary can be added later when needed.
7. **Playwright is ready**: v1.61.1 with all browsers installed.
8. **No destructive risks**: Clean state, no existing data. Safe to proceed.
