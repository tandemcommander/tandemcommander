<#
.SYNOPSIS
    Feature 314 regression: runs feature 081's mdview_probe.ps1 (smoke and hostile scenarios)
    with the product's registry key backed up before and restored + verified after (081's probe
    does not do that itself). Fixtures: specs\081-...\fixtures\security copied to %TEMP%\md081.
    MUST run through tools\run_on_hidden_desktop.ps1.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Exe)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$fixSrc = Join-Path $PSScriptRoot '..\..\081-mdview-shared-webhost\fixtures\security'
$fix = Join-Path $env:TEMP 'md081'
$probe = Join-Path $PSScriptRoot '..\..\081-mdview-shared-webhost\probe\mdview_probe.ps1'
$backup = Join-Path $env:TEMP 'tc314_r081_backup.reg'
$existed = Backup-Reg $backup
$rc = @{}
try {
    if (Test-Path -LiteralPath $fix) { Remove-Item -LiteralPath $fix -Recurse -Force }
    Copy-Item -LiteralPath $fixSrc -Destination $fix -Recurse
    foreach ($s in @('smoke', 'hostile')) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $probe -Exe $Exe -Fixtures $fix -Scenario $s
        $rc[$s] = $LASTEXITCODE
        Out ("scenario {0}: exit {1}" -f $s, $rc[$s])
    }
}
finally {
    foreach ($p in @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $Exe })) { Stop-Process -Id $p.Id -Force }
    Start-Sleep -Milliseconds 600
    $ok = Restore-Reg $backup $existed
    if ($ok -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if (Test-Path -LiteralPath $fix) { Remove-Item -LiteralPath $fix -Recurse -Force }
    Out ("registry restored+identical: {0}" -f $ok)
}
exit ([int]($rc.Values | Measure-Object -Sum).Sum)
