<#
.SYNOPSIS
    Feature 190 probe: a share-list worker that is still asking the server when the program
    exits (the user gave up waiting) leaves no leaked job - the Debug build showed "Detected
    memory leaks!" at exit.

.DESCRIPTION
    Uses the Debug-only seam of feature 125 (specs/125-unc-server-shares/contracts/probe-seam.md):
    TC_PROBE_UNC_SHARES answers without the network, TC_PROBE_UNC_DELAY holds the worker,
    TC_PROBE_UNC_CANCEL gives the wait up as ESC would (feature 193).
      ABANDON   delay 60 s, given up after 0.8 s, exit 2 s later: the worker is still asleep at
                exit and is ended there. PASS = clean exit, no window at exit.
      DONE      the control: delay 1.5 s, given up after 0.3 s, exit 4 s later: the worker has
                answered and freed the job itself. PASS = clean exit.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot 'dbwin_lib.ps1')
$Root = $TempRoot + '\tc193'
$StartDir = $Root + '\start'
$bs = [string][char]92
$Server = $bs + $bs + 'probesrv193' + $bs

function Run-Case([string]$Case, [string]$Delay, [string]$Cancel, [int]$ExitAfterMs) {
    $id = 0; $before = Reports
    $env:TC_PROBE_UNC_SHARES = 'alpha|beta'; $env:TC_PROBE_UNC_DELAY = $Delay; $env:TC_PROBE_UNC_CANCEL = $Cancel; $env:TC_PROBE_UNC_ERROR = ''
    try {
        $id = Start-Tc $StartDir
        $dlg = Open-ByCmd $id 862 10
        [void][Drv098f]::SetText((Find-Ctl $dlg 210), $Server, 5000)
        Click-Ok $dlg
        # what shows meanwhile (the wait window, a re-opened Change Directory is cancelled by Serve)
        $r = Serve $id ($ExitAfterMs / 1000.0) @(2)
        $m = Msgs $r
        Row $Case 'WAIT' 'INFO' ("delay {0} ms, given up after {1} ms, exit {2} ms after OK; windows: {3}" -f $Delay, $Cancel, $ExitAfterMs, (Tail $m 300))
        $pid0 = $id
        End-Row $Case $id $null $before; $id = 0
        # the Debug heap's dump at exit (OutputDebugString of that process)
        Start-Sleep -Milliseconds 300
        $dump = @([DbWin193]::Take() | Where-Object { $_ -like ('' + $pid0 + ': *') } | ForEach-Object { $_.Substring(('' + $pid0 + ': ').Length) } | Where-Object { $_ -match 'block|bytes long|Data:|leak|Dumping|\.cpp\(|\.h\(' })
        Row $Case 'DUMP' 'INFO' $(if ($dump.Count) { ($dump | Select-Object -First 40) -join ' | ' } else { 'no leak dump in the debug output' })
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { End-Row $Case $id $null $before }
        Remove-Item Env:TC_PROBE_UNC_SHARES, Env:TC_PROBE_UNC_DELAY, Env:TC_PROBE_UNC_CANCEL, Env:TC_PROBE_UNC_ERROR -ErrorAction SilentlyContinue
    }
}

$backup = Join-Path $env:TEMP 'tc193_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("unc_abandon_probe (feature 193), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash)
    Out ''
    Out ("Debug output: {0}" -f [DbWin193]::Start())
    Run-Case 'ABANDON' '60000' '800' 2500
    Run-Case 'DONE' '1500' '300' 4000
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
if ($Expect -eq 'before') { exit 0 }
exit $nf
