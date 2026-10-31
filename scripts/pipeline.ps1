<#
 decision-lock pipeline for ONE slice, run inside that slice's own working copy (Windows PowerShell 5+ / PowerShell 7).
   build -> certify (loop to builder on NOT CERTIFIED) -> independent run (loop to builder on NOT REPRODUCED)
 Usage: .\scripts\pipeline.ps1 -Slice D021-D030 -Dir C:\work\slice-copy [-Max 3] [-CertMax n] [-SkipBuild] [-FixFirst file] [-Start 1]
   -Max N          independent fix loops, and certify fix loops unless -CertMax is given (default 3)
   -SkipBuild      do not run the builder first (reports already exist)
   -FixFirst FILE  run this extra builder brief once after the build (for example a general-rules fix)
   -Start N        first certify round number (resume a half-finished run)
   -BuilderCli / $env:DL_BUILDER_CLI          default: claude   (builder, certifier and fix sessions)
   -IndependentCli / $env:DL_INDEPENDENT_CLI  default: grok     (run-only independent agent; use a different vendor)
 The CLI kind (claude, grok or codex) is taken from the file name.
 Exit codes: 0 REPRODUCED | 3 STOPPED (tool error) | 4 still NOT CERTIFIED | 5 still NOT REPRODUCED
 Briefs are passed by file pointer, never inline: PowerShell 5 truncates multi-line arguments at the first double quote (lesson 1).
#>
param(
  [Parameter(Mandatory)][string]$Slice,
  [Parameter(Mandatory)][string]$Dir,
  [int]$Max = 3, [int]$CertMax = -1, [switch]$SkipBuild, [string]$FixFirst = '', [int]$Start = 1,
  [string]$BuilderCli = $(if ($env:DL_BUILDER_CLI) { $env:DL_BUILDER_CLI } else { 'claude' }),
  [string]$IndependentCli = $(if ($env:DL_INDEPENDENT_CLI) { $env:DL_INDEPENDENT_CLI } else { 'grok' })
)
Set-Location $Dir
$j = 'handoff/jobs'; $sl = 'handoff/slices'; $tp = 'handoff/templates'
New-Item -ItemType Directory -Force $j, $sl | Out-Null
function Get-Now { Get-Date -Format HH:mm }
function Stop-Pipeline($m) { "$(Get-Now) STOPPED: $m"; exit 3 }

# Named Invoke-Cli, not after the exe it calls: a function called "claude" that runs "claude" recurses into itself (lesson 7).
function Invoke-Cli($cli, $file, $tag) {
  $kind = [IO.Path]::GetFileNameWithoutExtension($cli)
  $prompt = "Read the file $file in full and do exactly what it says. It is your complete brief."
  $receipt = "$j/SLICE-$Slice-$tag.receipt.txt"
  $here = (Get-Location).Path
  switch ($kind) {
    'claude' { & $cli -p $prompt --permission-mode acceptEdits --allowedTools 'Read,Write,Edit,Glob,Grep,Bash' *> $receipt }
    'grok'   { & $cli -p $prompt --always-approve --disable-web-search --cwd $here *> $receipt }
    'codex'  { & $cli exec --full-auto -C $here $prompt *> $receipt }
    default  { Stop-Pipeline "unknown CLI kind '$kind' (expected claude, grok or codex; edit Invoke-Cli for another agent)" }
  }
  $rc = $LASTEXITCODE
  "$(Get-Now) $tag exit=$rc"
  if ($rc -ne 0) { Stop-Pipeline "$kind exited $rc on $tag (see $receipt)" }
}

# The verdict comes ONLY from the first "**Verdict:" line, never from a search of the whole file (lesson 4).
function Get-Verdict($f) {
  $m = Select-String -Path $f -Pattern '^\s*\*\*Verdict:' | Select-Object -First 1
  if (-not $m) { Stop-Pipeline "no **Verdict: line in $f" }
  ($m.Line -replace '^\s*\*\*Verdict:(\*\*)?\s*', '')
}
# $true = pass, $false = fail; STOPPED when the verdict starts with neither word.
function Test-Verdict($f, $bad, $good) {
  $v = Get-Verdict $f
  if ($v -match "^$bad") { return $false }
  if ($v -match "^$good") { return $true }
  Stop-Pipeline "unreadable verdict in ${f}: $v"
}
function Write-Brief($template, $out, $round, $inputFile) {
  $t = [IO.File]::ReadAllText((Join-Path (Get-Location).Path $template))
  $t = $t.Replace('{{SLICE}}', $Slice).Replace('{{ROUND}}', "$round").Replace('{{INPUT}}', $inputFile)
  [IO.File]::WriteAllText((Join-Path (Get-Location).Path $out), $t, (New-Object Text.UTF8Encoding($false)))
}

if (-not $SkipBuild) {
  Invoke-Cli $BuilderCli "$j/SLICE-$Slice.md" 'BUILD'
  if (-not (Test-Path "$sl/$Slice.md")) { Stop-Pipeline 'builder wrote no slice report' }
}
if ($FixFirst) { Invoke-Cli $BuilderCli $FixFirst 'GAPFIX' }

# certify loop
if ($CertMax -lt 0) { $CertMax = $Max }
$last = $Start + $CertMax
for ($i = $Start; $i -le $last; $i++) {
  if (Test-Path "$sl/$Slice-cert.md") { Move-Item "$sl/$Slice-cert.md" "$sl/$Slice-cert-$($i-1).md" -Force }
  Invoke-Cli $BuilderCli "$j/SLICE-$Slice-CERT.md" "CERT$i"
  if (-not (Test-Path "$sl/$Slice-cert.md")) { Stop-Pipeline 'certifier wrote no report' }
  if (Test-Verdict "$sl/$Slice-cert.md" 'NOT CERTIFIED' 'CERTIFIED') { "$(Get-Now) CERTIFIED on round $i"; break }
  if ($i -ge $last) { "$(Get-Now) RESULT: STILL NOT CERTIFIED after $CertMax fix loops"; exit 4 }
  Copy-Item "$sl/$Slice-cert.md" "$sl/$Slice-cert-fixinput-$i.md"
  Write-Brief "$tp/cert-fix-brief.md" "$j/SLICE-$Slice-CFIX$i.md" $i "$sl/$Slice-cert-fixinput-$i.md"
  Invoke-Cli $BuilderCli "$j/SLICE-$Slice-CFIX$i.md" "CFIX$i"
}

# independent loop
function Invoke-Independent($tag) {
  Remove-Item "$sl/$Slice-independent-run.md" -ErrorAction SilentlyContinue
  Invoke-Cli $IndependentCli "$j/SLICE-$Slice-INDEPENDENT.md" $tag
  if (-not (Test-Path "$sl/$Slice-independent-run.md")) { Stop-Pipeline "independent agent wrote no report ($tag)" }
}
function Test-Reproduced { Test-Verdict "$sl/$Slice-independent-run.md" 'NOT REPRODUCED' 'REPRODUCED' }
Invoke-Independent 'IND0'
for ($i = 1; $i -le $Max; $i++) {
  if (Test-Reproduced) { "$(Get-Now) RESULT: REPRODUCED after $($i-1) fix loops"; Get-Content "$sl/$Slice-independent-run.md" -Tail 25; exit 0 }
  Copy-Item "$sl/$Slice-independent-run.md" "$sl/$Slice-independent-run-$i.md"
  Write-Brief "$tp/independent-fix-brief.md" "$j/SLICE-$Slice-IFIX$i.md" $i "$sl/$Slice-independent-run-$i.md"
  Invoke-Cli $BuilderCli "$j/SLICE-$Slice-IFIX$i.md" "IFIX$i"
  Invoke-Independent "IND$i"
}
if (Test-Reproduced) { "$(Get-Now) RESULT: REPRODUCED after $Max fix loops"; exit 0 }
else { "$(Get-Now) RESULT: STILL NOT REPRODUCED after $Max loops"; exit 5 }
