# SSE coverage slices 1–3 — 2026-09-26

Verified full coverage run: **3,106 passed, zero test failures**.
Measured line coverage: **66.42% (9,187 / 13,831)**, up from the previous reported 64.99%.

| Target | Coverage |
| --- | ---: |
| Souls | 98.43% |
| NPCScheduler | 87.11% |
| AcpManager | 79.07% |

Added persistence, validation, isolation, rollback, grief, reputation/death notification, and ambient relevance tests. Scheduler tests cover stamina, somatic state, rest, emotional recovery, goals, grief, forgiveness, relationship drift, conversation eligibility, exhausted NPCs, and player activity exclusion. External task dispatch and ACP process operations have deterministic test seams.

Fixed ACP log-tail counting for newline-terminated files and prevented restart after failed shutdown. Missing command errors now return false instead of escaping lifecycle calls. Native Linux opencode/pkill integration is still not exercised on this Windows workstation.

Coverage tooling: scripts/coverage.ps1 exports raw data and scripts/coverage_report.exs saves module coverage and uncovered lines, matching Mix's generated-line and duplicate-line rules. It avoids the HTML stylesheet path failure without excluding application code or reducing the existing Mix coverage threshold. Mix task tests no longer clear global task state or execute asynchronously.

Validation: mix precommit passed with 3,104 tests before the final two boundary tests; the final full coverage run passed with 3,106. Final formatting and diff checks passed. Precommit also formatted four previously unformatted test files; those edits only affect formatting.

Reports are retained locally in cover/test-results.log, cover/current.coverdata, cover/summary.json, and cover/summary.txt. Uncovered module lines remain; this is not a claim of 100% coverage or exhaustive behavior validation.
