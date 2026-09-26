# Coverage workflow

Run `pwsh -File scripts/coverage.ps1` from this repository. It runs the full test suite in MIX_ENV=test, exports Erlang coverage, and writes:

- cover/test-results.log: full test output
- cover/current.coverdata: raw executable-line counts
- cover/summary.json: per-module totals and uncovered line numbers
- cover/summary.txt: readable module ranking

This diagnostic command preserves the test exit status. It reports coverage without lowering or replacing the existing 90% Mix coverage gate. It uses raw export to avoid OTP's failing HTML stylesheet lookup on this installation. No application modules are excluded. The total includes test-support modules compiled into the application, consistent with the previous Mix reports; it is line coverage, not proof of branch or behavioral completeness.

Test files load sequentially with --max-requires 1. Mix task tests no longer clear global task state or run asynchronously. Clearing that state allowed app.start to rerun compilation during test loading; the earlier attribution to a Windows compiler bug was not established.

Keep raw reports local (cover/ is ignored). Record the verified percentage and test count in the committed work report. Do not interpret an old export as a current result.
