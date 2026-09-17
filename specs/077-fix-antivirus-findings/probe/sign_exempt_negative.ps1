# 077 probe: a runtime file without a valid Microsoft signature must make the
# signing sweep fail before it touches anything (contract signing-exemption.md,
# rule 1), and -VerifyOnly must report it.
#
# Copies the release tree to the scratchpad, tampers one runtime DLL (appends a
# byte -> Authenticode hash mismatch), records every PE file's timestamp and
# size, runs sign_release.ps1 -Root <copy> and -VerifyOnly through Windows
# PowerShell 5.1 with the default module path (the sweep is a 5.1 script), then
# asserts: exit 1, the ERROR line names the tampered file, no file changed.
# Prints RESULT: OK / FAIL (exit 0 / 1). ASCII only.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Tree,
    [string]$Tamper = 'concrt140.dll',
    [string]$Scratch = $env:TEMP
)

$ErrorActionPreference = 'Stop'
function Fail([string]$m) { Write-Host "RESULT: FAIL - $m"; exit 1 }

$Tree = (Resolve-Path -LiteralPath $Tree).Path
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$sweep = Join-Path $repo 'tools\codesign\sign_release.ps1'
if (-not (Test-Path -LiteralPath $sweep)) { Fail "sweep not found: $sweep" }
$copy = Join-Path $Scratch ('tc-signneg-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $copy | Out-Null
$rc = & robocopy $Tree $copy /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Fail "robocopy failed ($LASTEXITCODE)" }

$victim = Join-Path $copy $Tamper
if (-not (Test-Path -LiteralPath $victim)) { Fail "runtime file not in tree root: $victim" }
$sigBefore = (Get-AuthenticodeSignature -LiteralPath $victim).Status
$fs = [System.IO.File]::Open($victim, 'Append'); $fs.WriteByte(0); $fs.Close()
$sigAfter = (Get-AuthenticodeSignature -LiteralPath $victim).Status
Write-Host ("probe: {0} signature {1} -> {2} after tampering" -f $Tamper, $sigBefore, $sigAfter)
if ($sigAfter -eq 'Valid') { Fail 'tampering did not invalidate the signature' }

$snap = @{}
Get-ChildItem -LiteralPath $copy -Recurse -File | Where-Object { $_.Extension -in '.exe', '.dll', '.spl', '.slg' } |
    ForEach-Object { $snap[$_.FullName] = '{0}|{1}' -f $_.Length, $_.LastWriteTimeUtc.Ticks }

$ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$oldPath = $env:PSModulePath
$env:PSModulePath = ('{0}\Documents\WindowsPowerShell\Modules;{1}\WindowsPowerShell\Modules;{2}\System32\WindowsPowerShell\v1.0\Modules' -f $env:USERPROFILE, $env:ProgramFiles, $env:SystemRoot)
try {
    $out1 = & $ps51 -NoProfile -ExecutionPolicy Bypass -File $sweep -Root $copy 2>&1 | ForEach-Object { $_.ToString() }
    $exit1 = $LASTEXITCODE
    $out2 = & $ps51 -NoProfile -ExecutionPolicy Bypass -File $sweep -Root $copy -VerifyOnly 2>&1 | ForEach-Object { $_.ToString() }
    $exit2 = $LASTEXITCODE
} finally { $env:PSModulePath = $oldPath }

Write-Host '--- sweep output ---'; $out1 | ForEach-Object { Write-Host "  $_" }
Write-Host '--- verifyonly output ---'; $out2 | ForEach-Object { Write-Host "  $_" }

$changed = @()
Get-ChildItem -LiteralPath $copy -Recurse -File | Where-Object { $_.Extension -in '.exe', '.dll', '.spl', '.slg' } |
    ForEach-Object { $v = '{0}|{1}' -f $_.Length, $_.LastWriteTimeUtc.Ticks; if ($snap[$_.FullName] -ne $v) { $changed += $_.FullName } }

$ok = $true
if ($exit1 -ne 1) { Write-Host "probe: sweep exit code $exit1 (expected 1)"; $ok = $false }
if (-not ($out1 | Where-Object { $_ -match 'ERROR: runtime file is not validly signed by Microsoft' -and $_ -match [regex]::Escape($Tamper) })) { Write-Host 'probe: sweep did not name the tampered runtime file'; $ok = $false }
if ($exit2 -ne 1) { Write-Host "probe: verifyonly exit code $exit2 (expected 1)"; $ok = $false }
if (-not ($out2 | Where-Object { $_ -match 'RUNTIME FILE NOT MICROSOFT-SIGNED' -and $_ -match [regex]::Escape($Tamper) })) { Write-Host 'probe: verifyonly did not name the tampered runtime file'; $ok = $false }
if ($changed.Count -gt 0) { Write-Host ("probe: {0} file(s) were modified by the failed sweep:" -f $changed.Count); $changed | ForEach-Object { Write-Host "  $_" }; $ok = $false }
Write-Host ("probe: copy at {0} (kept for inspection)" -f $copy)
if ($ok) { Write-Host 'RESULT: OK'; exit 0 } else { Write-Host 'RESULT: FAIL'; exit 1 }
