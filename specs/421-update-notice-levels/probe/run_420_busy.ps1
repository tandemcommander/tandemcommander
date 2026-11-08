<#
.SYNOPSIS
    Feature 421: runs 420's probe (specs/420-auto-update-install/probe/autoupd_probe.ps1) as a
    regression check with the Debug seam TC_UPDATE_PROBE_IDLE_MS set to a huge value - "the user is
    working", so 421's silent automatic install waits and the automatic level behaves as in 420 except
    for its removed notification form. Run through tools\run_on_hidden_desktop.ps1.
#>
param([Parameter(Mandatory = $true)][string]$Exe, [string]$Result = '')
if (-not $Result) { $Result = Join-Path $PSScriptRoot 'result_420_regression_busy.txt' }
$env:TC_UPDATE_PROBE_IDLE_MS = '600000000'
& (Join-Path $PSScriptRoot '..\..\420-auto-update-install\probe\autoupd_probe.ps1') -Exe $Exe -Result $Result
$code = $LASTEXITCODE
Remove-Item Env:\TC_UPDATE_PROBE_IDLE_MS -ErrorAction SilentlyContinue
exit $code
