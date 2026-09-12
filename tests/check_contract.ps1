# Stable convenience entry; run.py and suites.json own test execution.
$ErrorActionPreference = 'Stop'
& python (Join-Path $PSScriptRoot 'run.py') @args
exit $LASTEXITCODE
