# Windows entry point for the lock CLI. It hands every argument to lock.sh (bash: Git Bash or WSL) so there is one implementation.
# Usage: lock.ps1 launch | doctor | run [D001-D010] | evidence | cleanup | selftest [D003]
# Prints the same single JSON object as lock.sh and exits with its exit code.
$ErrorActionPreference = 'Stop'
$sh = Join-Path $PSScriptRoot 'lock.sh'
$bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
if (-not $bash) { Write-Output '{"ok":false,"error":"bash not found: install Git for Windows or WSL"}'; exit 1 }
& $bash $sh @args
exit $LASTEXITCODE
