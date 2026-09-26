$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:MIX_ENV = 'test'
New-Item -ItemType Directory -Force cover | Out-Null
Remove-Item -LiteralPath cover/current.coverdata -ErrorAction SilentlyContinue
mix test --cover --export-coverage current --max-requires 1 2>&1 | Tee-Object -FilePath cover/test-results.log
$testExit = $LASTEXITCODE
$testLog = Get-Content cover/test-results.log -Raw
if ($testLog -match '(?m)^Failed:|^== Compilation error' -or $testLog -notmatch '(?m)^Result: \d+ passed') {
  $testExit = 1
}
if (Test-Path cover/current.coverdata) {
  mix run --no-start --no-compile scripts/coverage_report.exs 2>&1 | Tee-Object -FilePath cover/summary.txt
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
exit $testExit

