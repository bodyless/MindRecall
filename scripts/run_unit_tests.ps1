# Run all unit tests under test/ (not packaged into the app).
# After any feature/fix, run this script; non-zero exit means keep iterating.
#
# Usage: .\scripts\run_unit_tests.ps1

$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $RepoRoot

$TestDir = Join-Path $RepoRoot 'test'
if (-not (Test-Path -LiteralPath $TestDir -PathType Container)) {
  Write-Error "Missing test directory: $TestDir"
  exit 1
}

Write-Host ''
Write-Host '========================================'
Write-Host ' Mind Recall - unit tests (test/)'
Write-Host " Root: $RepoRoot"
Write-Host '========================================'
Write-Host ''

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
  Write-Error 'flutter not found in PATH'
  exit 1
}

# flutter.bat must be invoked via cmd so PowerShell waits and gets exit code
cmd /c "flutter test test/"
$exitCode = $LASTEXITCODE

Write-Host ''
if ($exitCode -eq 0) {
  Write-Host '========================================'
  Write-Host ' PASSED - all unit tests green'
  Write-Host '========================================'
} else {
  Write-Host '========================================'
  Write-Host ' FAILED - fix then re-run:'
  Write-Host '   .\scripts\run_unit_tests.ps1'
  Write-Host '========================================'
}

exit $exitCode
