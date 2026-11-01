<#
.SYNOPSIS
    Feature 375 probe: how long the main window stops answering after the program is activated again
    (WM_ACTIVATEAPP), with the clipboard free and with the clipboard held open by another program.

.DESCRIPTION
    Per row the program starts with both panels on local fixture folders (the left one with 800
    files, as row LOCAL of feature 372's probe). After 3 s of rest it is deactivated and activated
    again the way Windows tells it (WM_ACTIVATEAPP FALSE, 400 ms, WM_ACTIVATEAPP TRUE, posted to the
    main window). From the activation on, for 1500 ms, the probe sends WM_NULL to the main window
    every 2 ms (SendMessageTimeout) and records every wait > 16 ms with its start offset = the times
    the UI thread did not run its message loop. The activation requests the idle clipboard check
    (IdleCheckClipboard), so the first idle after it runs the check.
      FREE  the clipboard is free (its content is the user's; read only).
            PASS = the longest wait of every activation is below -LimitMs (30 ms, the item's example).
      HELD  a helper process (clip_hold.ps1) holds the clipboard open for the whole row, as an
            application that keeps it open does; the content is not changed.
            PASS = the longest wait of every activation is below -LimitMs.
    While HELD runs (~15 s) no program on the machine can open the clipboard (copy / paste of the
    user fails for that time). Nothing is written to the clipboard.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$Lib,
    [string]$HoldScript,
    [int]$Cycles = 5,
    [int]$LimitMs = 30,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if (-not $HoldScript) { $HoldScript = Join-Path $PSScriptRoot 'clip_hold.ps1' }
. $Lib
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Clip375p
{
    [DllImport("user32.dll")] public static extern IntPtr GetOpenClipboardWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
'@
$Root = $TempRoot + '\tc375act'
$StartDir = $Root + '\start'
$LocalDir = $Root + '\local'
$Ready = $Root + '\hold.ready'
$Stop = $Root + '\hold.stop'

function Clip-State {
    $w = [Clip375p]::GetOpenClipboardWindow(); $p = [uint32]0
    if ($w -eq [IntPtr]::Zero) { return 'clipboard not open' }
    [void][Clip375p]::GetWindowThreadProcessId($w, [ref]$p)
    return ('clipboard open by window {0} of pid {1}' -f $w, $p)
}

# every wait for an answer of the main window within $Ms milliseconds
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

function Start-Row([string]$Left) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T375', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 3000
    [void](Serve $p.Id 5)
    return $p.Id
}

function Deactivate([IntPtr]$Main) { [void][Drv098f]::PostMessageW($Main, 0x001C, [IntPtr]0, [IntPtr]::Zero) }  # WM_ACTIVATEAPP FALSE
function Activate([IntPtr]$Main) { [void][Drv098f]::PostMessageW($Main, 0x001C, [IntPtr]1, [IntPtr]::Zero) }    # WM_ACTIVATEAPP TRUE

function Start-Holder {
    foreach ($f in @($Ready, $Stop)) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } }
    $h = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $HoldScript), '-Ready', ('"{0}"' -f $Ready), '-StopFile', ('"{0}"' -f $Stop), '-MaxSeconds', '60') -PassThru -WindowStyle Hidden -RedirectStandardOutput ($Root + '\hold.out') -RedirectStandardError ($Root + '\hold.err')
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $said = $null
    while ($sw.Elapsed.TotalSeconds -lt 30) {
        # the file can exist before its text is written: wait for the text
        if (Test-Path -LiteralPath $Ready) { $said = (Get-Content -LiteralPath $Ready -ErrorAction SilentlyContinue) -join '' }
        if ($said) { break }
        Start-Sleep -Milliseconds 50
    }
    $ok = ($said -eq 'True')
    return [pscustomobject]@{ Proc = $h; Holds = $ok }
}
function Stop-Holder($H) {
    if ($null -eq $H) { return }
    [IO.File]::WriteAllText($Stop, 'stop')
    if (-not $H.Proc.WaitForExit(10000)) { Stop-Process -Id $H.Proc.Id -Force }
}

function Run-Timing([string]$Case, [bool]$Hold) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports; $holder = $null
    try {
        $id = Start-Row $LocalDir
        $main = Get-Main $id
        $title = [Drv098f]::Txt($main)
        $rest = Measure-Answers $main 1000
        if ($Hold) {
            $holder = Start-Holder
            if (-not $holder.Holds) { throw ('the helper could not open the clipboard (' + (Clip-State) + '); helper output: ' + ((Get-Content -LiteralPath ($Root + '\hold.out'), ($Root + '\hold.err') -ErrorAction SilentlyContinue) -join ' / ')) }
        }
        $state = Clip-State
        $maxes = @(); $log = @()
        for ($c = 0; $c -lt $Cycles; $c++) {
            Deactivate $main
            Start-Sleep -Milliseconds 400
            Activate $main
            $m = Measure-Answers $main 1500
            $maxes += [math]::Round($m.Max, 1)
            $log += ('{0} #{1}: {2}' -f $Case, $c, $m.Waits)
            Start-Sleep -Milliseconds 600
        }
        if ($Hold) { Stop-Holder $holder; $holder = $null }
        foreach ($w in $log) { Out ('  waits (start ms after activation + length ms): ' + $w) }
        # after the clipboard is free again the program still answers
        $after = Measure-Answers $main 1000
        $r = Serve $id 3
        $worst = ($maxes | Measure-Object -Maximum).Maximum
        $ok = ($worst -lt $LimitMs)
        Row $Case 'ACTIVATE' (V $ok) ("longest {0:N1} ms < {1}; {2}; at rest max {3:N1} ms; per activation max [ms]: {4}; after the row max {5:N1} ms; title '{6}'; windows: {7}" -f $worst, $LimitMs, $state, $rest.Max, ($maxes -join ', '), $after.Max, (Tail $title 60), (Msgs $r))
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($holder) { Stop-Holder $holder }
        if ($id) { End-Row $Case $id $null $before }
    }
}

$backup = Join-Path $env:TEMP 'tc375_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $LocalDir
    for ($i = 0; $i -lt 800; $i++) { WriteFile ('{0}\f{1:D4}.txt' -f $LocalDir, $i) 'x' }
    Set-Config
    Out ("act375_probe (feature 375) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; limit {2} ms; {3} activations a row; at start: {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $LimitMs, $Cycles, (Clip-State))
    Out ''
    Run-Timing 'FREE' $false
    Run-Timing 'HELD' $true
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
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; {5}; registry restored+identical: {6}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), (Clip-State), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
