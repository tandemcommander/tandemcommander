<#
.SYNOPSIS
    Feature 428: every GUI probe of the portable edition, one after another, on the hidden desktop.
.DESCRIPTION
    Runs roundtrip_gate, notrace (portable + the normal edition as the negative control), scenarios,
    import, identity, update, pwdnote (Debug trees) and timing (Release trees), each through
    tools\run_on_hidden_desktop.ps1, and prints every PASS / FAIL / RESULT line. Each probe backs up
    and checks the installed edition's registry key itself. Exit code = the number of probes that
    did not end with RESULT: PASS (the notrace negative control must FAIL and counts as passed then).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File specs\428-portable-build\probe\run_all.ps1 -Log out.txt
#>
param([string]$Log = (Join-Path $env:TEMP 'tc428\run_all.txt'), [switch]$NoRelease)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$b = Join-Path $repo 'build\tandemcommander'
$dp = Join-Path $b 'Debug_x64_portable\tandemcommander.exe'
$dn = Join-Path $b 'Debug_x64\tandemcommander.exe'
$rp = Join-Path $b 'Release_x64_portable\tandemcommander.exe'
$rn = Join-Path $b 'Release_x64\tandemcommander.exe'
$probe = $PSScriptRoot
$runs = @(
    @('gate', "python `"$probe\roundtrip_gate.py`" `"$dp`"", 'PASS'),
    @('notrace-portable', "python `"$probe\notrace_probe.py`" --exe `"$dp`"", 'PASS'),
    @('notrace-normal (negative control)', "python `"$probe\notrace_probe.py`" --label normal --exe `"$dn`"", 'FAIL'),
    @('scenarios', "python `"$probe\scenarios_probe.py`" --portable `"$dp`" --normal `"$dn`"", 'PASS'),
    @('import', "python `"$probe\import_probe.py`" --portable `"$dp`"", 'PASS'),
    @('identity', "python `"$probe\identity_probe.py`" --portable `"$dp`" --normal `"$dn`"", 'PASS'),
    @('update', "python `"$probe\update_probe.py`" --portable `"$dp`"", 'PASS'),
    @('pwdnote', "python `"$probe\pwdnote_probe.py`" --portable `"$dp`"", 'PASS')
)
if (-not $NoRelease) { $runs += , @('timing', "python `"$probe\timing_probe.py`" --portable `"$rp`" --normal `"$rn`"", 'PASS') }
New-Item -ItemType Directory -Force (Split-Path $Log) | Out-Null
'' | Set-Content -Encoding UTF8 $Log
$bad = 0
foreach ($r in $runs) {
    $one = Join-Path (Split-Path $Log) ('run_all_' + ($r[0] -replace '[^a-z]', '') + '.txt')
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\run_on_hidden_desktop.ps1') -Log $one -CommandLine $r[1] | Out-Null
    $lines = @(Get-Content -Encoding UTF8 $one | Where-Object { $_ -match '^(PASS|FAIL|RESULT|NOT DRIVEN)' })
    $result = ($lines | Where-Object { $_ -match '^RESULT' } | Select-Object -Last 1)
    $ok = $result -match ('RESULT: ' + $r[2])
    if ($r[2] -eq 'FAIL') {
        # the negative control must fail for the reason it exists - the probe sees the normal edition's
        # writes and its reading of the installed settings - never merely by crashing
        foreach ($must in @('FAIL   no registry key of ours changed', 'FAIL   the installed edition''s settings are not read')) {
            if (-not ($lines | Where-Object { $_.StartsWith($must) })) { $ok = $false; $lines += ('MISSING expected row: ' + $must) }
        }
    }
    if (-not $ok) { $bad++ }
    $head = '== {0}: {1} (expected {2})' -f $r[0], $(if ($result) { $result } else { 'no RESULT line' }), $r[2]
    Add-Content -Encoding UTF8 $Log $head
    Add-Content -Encoding UTF8 $Log $lines
    Write-Output $head
}
Write-Output ('probes not as expected: {0}' -f $bad)
Add-Content -Encoding UTF8 $Log ('probes not as expected: {0}' -f $bad)
$res = Join-Path (Join-Path $probe 'results') ('run_all-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
Copy-Item $Log $res
exit $bad
