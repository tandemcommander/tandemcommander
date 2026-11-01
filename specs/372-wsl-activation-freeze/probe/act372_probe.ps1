<#
.SYNOPSIS
    Probe: how long the main window stops answering after the program is activated again while a
    panel shows a WSL folder (\\wsl.localhost\<distro>\...) - and, as the control, a local folder.

.DESCRIPTION
    Per row the program starts with the left panel on the row's folder and the right panel on a
    local fixture folder. After 3 s of rest it is deactivated and activated again <Cycles> times the
    way Windows tells it (WM_ACTIVATEAPP FALSE, 400 ms, WM_ACTIVATEAPP TRUE, posted to the main
    window). From the activation on, for 1500 ms, the probe sends WM_NULL to the main window every
    2 ms (SendMessageTimeout) and records the longest wait for an answer = the longest time the
    UI thread did not run its message loop. Also recorded: the busy-cursor time is not measurable
    on the hidden desktop (NOT DRIVEN).
      LOCAL   the control: a local folder with 800 files
      WSLROOT \\wsl.localhost\<distro>\
      WSLBIG  \\wsl.localhost\<distro>\usr\bin
    PASS = the longest wait of every cycle is below -LimitMs (default 50).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$Lib,
    [string]$Distro = 'Ubuntu',
    [int]$Cycles = 5,
    [int]$LimitMs = 50,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc372act'
$StartDir = $Root + '\start'
$LocalDir = $Root + '\local'
$Wsl = '\\wsl.localhost\' + $Distro + '\'

# the longest wait for an answer of the main window within $Ms milliseconds
function Measure-Answers([IntPtr]$Main, [int]$Ms) {
    $max = 0.0; $sum = 0.0; $n = 0; $waits = @()
    $total = [Diagnostics.Stopwatch]::StartNew(); $one = New-Object Diagnostics.Stopwatch
    while ($total.Elapsed.TotalMilliseconds -lt $Ms) {
        $at = $total.Elapsed.TotalMilliseconds
        $one.Restart()
        [void][Drv098f]::Send($Main, 0, 0, 0, 20000)
        $d = $one.Elapsed.TotalMilliseconds
        if ($d -gt $max) { $max = $d }
        if ($d -gt 16) { $sum += $d; $waits += ('{0:N0}+{1:N0}' -f $at, $d) }
        $n++
        Start-Sleep -Milliseconds 2
    }
    return [pscustomobject]@{ Max = $max; Blocked = $sum; Pings = $n; Waits = ($waits -join ' ') }
}

function Run-Case([string]$Case, [string]$Left) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'TACT', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        $main = Get-Main $id
        if ($main -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 3000
        [void](Serve $id 5)
        $title = [Drv098f]::Txt($main)
        $rest = Measure-Answers $main 1000
        $maxes = @(); $blocked = @()
        for ($c = 0; $c -lt $Cycles; $c++) {
            [void][Drv098f]::PostMessageW($main, 0x001C, [IntPtr]0, [IntPtr]::Zero)   # WM_ACTIVATEAPP FALSE
            Start-Sleep -Milliseconds 400
            [void][Drv098f]::PostMessageW($main, 0x001C, [IntPtr]1, [IntPtr]::Zero)   # WM_ACTIVATEAPP TRUE
            $m = Measure-Answers $main 1500
            $maxes += [math]::Round($m.Max, 1); $blocked += [math]::Round($m.Blocked, 1); $script:WaitLog += ('{0} #{1}: {2}' -f $Case, $c, $m.Waits)
            Start-Sleep -Milliseconds 600
        }
        foreach ($w in $script:WaitLog) { Out ('  waits (start ms after activation + length ms): ' + $w) }
        $script:WaitLog = @()
        $r = Serve $id 3
        $worst = ($maxes | Measure-Object -Maximum).Maximum
        $ok = ($worst -lt $LimitMs)
        Row $Case 'ACTIVATE' (V $ok) ("left '{0}'; at rest max {1:N1} ms; per activation max wait [ms]: {2}; blocked (waits > 16 ms) [ms]: {3}; title '{4}'; windows: {5}" -f $Left, $rest.Max, ($maxes -join ', '), ($blocked -join ', '), (Tail $title 60), (Msgs $r))
        Row $Case 'CURSOR' 'NOT DRIVEN' 'the busy cursor of another process is not readable on the hidden desktop'
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc372_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $LocalDir
    for ($i = 0; $i -lt 800; $i++) { WriteFile ('{0}\f{1:D4}.txt' -f $LocalDir, $i) 'x' }
    Set-Config
    Out ("act372_probe (feature 372) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    $wslOk = Test-Path -LiteralPath $Wsl
    Out ("Date    : {0}; registry key existed {1}; WSL path {2} reachable {3}; limit {4} ms; {5} activations a row" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $Wsl, $wslOk, $LimitMs, $Cycles)
    Out ''
    Run-Case 'LOCAL' $LocalDir
    if ($wslOk) {
        Run-Case 'WSLROOT' $Wsl
        Run-Case 'WSLBIG' ($Wsl + 'usr\bin')
    }
    else { Row 'WSL' 'ACTIVATE' 'NOT DRIVEN' ("{0} not reachable on this machine" -f $Wsl) }
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
exit $nf
