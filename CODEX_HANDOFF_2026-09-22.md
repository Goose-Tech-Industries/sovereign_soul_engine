# Sovereign Soul Engine inspection handoff

Date: 2026-09-22

## Project
- Folder: C:\Users\rjd42\Desktop\sovereign_soul_engine (Relocated to `C:\Users\rjd42\Documents\sovereign_soul_engine` on 2026-09-23)
- Configured Git origin: https://github.com/Goose-Tech-Industries/sovereign_soul_engine.git
- HEAD branch: feature/sovereign-soul-core
- Stack: Elixir, Phoenix 1.8, LiveView, Ecto/PostgreSQL.
- Repository instructions: AGENTS.md.
- Active Execution Handoff: `ANTIGRAVITY_HANDOFF_2026-09-23.md`.

## Request and completed work
The user requested inspection of their Sovereign Soul Engine code and locating its Git-linked folder. Located the repository and performed an initial static review of startup, routing, API authentication, memory deletion, moderation, and consequence resolution. No application code was changed. This handoff is the only file created for this task.

## Findings to address
1. Sensitive public API routes bypass authentication.
   lib/sovereign_soul_engine_web/router.ex:115 defines the /api scope without the :api pipeline. It exposes memory inspection/deletion and privacy changes, among other actions. Reviewed memory and privacy controllers contain no independent authentication or ownership check. Endpoint has no global authentication plug. Deployment proxy exposure was not checked.
2. Admin moderation is unprotected at the application level.
   lib/sovereign_soul_engine_web/router.ex:219 defines /sse/acp using only :browser, with no authenticated on_mount or role enforcement. AcpModerationLive mount and event handlers lack authorization; handlers delete posts/events and change moderation settings.
3. API authentication accepts a hardcoded development key.
   lib/sovereign_soul_engine_web/plugs/api_auth.ex:15 falls back to a built-in development key when SOVEREIGN_SOUL_API_KEY is unset. This branch has no environment restriction and bypasses tenant authentication and source matching.
4. Missing memory purge filters cause full deletion.
   lib/sovereign_soul_engine/memories.ex:162, purge_memories_for_character/2, falls through to the full character query when no filter is supplied, then calls Repo.delete_all. Thus all memories are deleted without requiring all: true. MemoryPurgeController defaults an omitted character slug to goose and passes empty options when filters are missing.

## Verification limits
- Findings are based on static code inspection, not executed tests.
- Git and Elixir/Mix were not available on the current PowerShell PATH; the usual C:\Program Files\Git\cmd\git.exe location was absent. WSL executable was found, but its distributions/toolchain were not inspected.
- Remote and branch were read from .git/config and .git/HEAD. Working tree cleanliness and remote synchronization are unknown.
- Found 116 *_test.exs files; did not verify README test-pass claims.
- The shell appeared to start in Desktop despite a requested repository workdir; absolute paths were reliable.

## Suggested continuation
Read AGENTS.md and inspect current Git status before editing. Locate the working Git/Elixir toolchain (potentially WSL). The user has authorized inspection only, not yet requested fixes. If fixes are requested, prioritize access controls and explicit purge validation, then add targeted regression tests and run required checks. AGENTS.md asks for mix precommit after changes.

## Authorized follow-up: fixes and local environment repair

The user subsequently authorized fixes and troubleshooting PostgreSQL/WSL.
This section supersedes the earlier inspection-only authorization and toolchain
limitations.

- Both `/api` aliases and `/sse/api` integration routes now authenticate tenant
  keys; the built-in and environment-key bypass was removed.
- ACP requires a confirmed account allowlisted by UUID in `SSE_ADMIN_USER_IDS`,
  enforced for HTTP requests and LiveView mounts.
- Memory purges require an explicit character and deletion intent. Domain memory
  and Theory of Mind purge functions reject missing/invalid filters. Category-only
  purges preserve knowledge; topic searches treat SQL wildcard characters literally.
- Telegram, Alexa, and Stripe routes also require bearer authentication because
  their existing provider verification is missing or permits unsigned requests.
  Direct provider integrations need an authenticated adapter or complete provider
  verification. Per-character tenant ownership remains a separate limitation.
- Added regression tests and updated existing API tests to use real tenant keys.
- Installed PostgreSQL 17.11; its automatic Windows service listens only on
  localhost:5432. Development credentials match config/test.exs.
- Repaired WSL by updating to 2.7.13 and enabling VirtualMachinePlatform. A Windows
  restart is required; no Linux distribution is installed. No automatic reboot
  was performed and no distributions or existing databases were deleted.
- Verification: 22 targeted tests passed; `mix precommit` passed all 1,133 tests.
  Unrelated formatter changes were restored. Existing user changes remain intact.
- Session permissions now allow unrestricted commands without Codex approval
  prompts. Windows UAC was still required for system installation.

See `docs/ACCESS_CONTROL_SETUP.md` for operational setup and remaining boundaries.
Repair log: `C:\Users\rjd42\Desktop\repair_sse_prerequisites.log`.
Full check log: `C:\Users\rjd42\Desktop\sse_precommit_2026-09-22.log`.

## September 23: Git push and PC inventory

- User authorized pushing the project. Published account/chat work and security
  fixes together as commit `546df6f0d12f463ca12b7144595b4232b10a062c` to
  `origin/feature/sovereign-soul-core`; remote SHA verified.
- Removed the hardcoded password from the previously untracked admin provisioning
  script. It now requires `SSE_ADMIN_PASSWORD` and no longer prints the password.
- Ran `mix precommit` again: all 1,133 tests passed.
- Restored GitHub CLI 2.101.0 under the user's LocalAppData Programs directory,
  verified its release checksum, completed browser login, and repaired Git's
  stale credential helper. Added the CLI directory to the user's PATH.
- This handoff remains local and untracked. Personal machine inventory and setup
  recommendations are in `C:\Users\rjd42\Desktop\PC_SETUP_RECOMMENDATIONS_2026-09-23.md`.
- Detected Ryzen 7 5700G, GTX 1660 SUPER 6 GB, 48 GB mixed RAM configured at
  2133 MT/s, one 1 TB NVMe SSD, two 1 TB SATA HDDs, and a 1 TB Samsung T7 USB SSD.
- WSL still reports no installed distributions and a pending virtualization
  activation problem; Windows reports a pending reboot despite firmware
  virtualization being enabled. No automatic reboot was performed.

## September 23: restart checkpoint

Desktop apps and both AI CLIs are installed. The current continuation notes are in
`C:\Users\rjd42\Desktop\RESTART_HANDOFF_2026-09-23.md`.
See `C:\Users\rjd42\Desktop\APP_INSTALLATION_2026-09-23.md` for app versions.
Claude Code 2.1.268 (`claude`) and Antigravity CLI 1.2.8 (`agy`) were verified.
Ubuntu 24.04's Windows app is now installed, superseding earlier no-distro-app notes;
Linux initialization and Docker engine verification still require the pending restart.
Playwright browser launch and interaction checks passed for Chromium, Firefox, WebKit.
The user is restarting manually. No additional project source changes were made.
