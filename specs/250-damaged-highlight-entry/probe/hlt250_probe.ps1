<#
.SYNOPSIS
    Feature 250 probe: a damaged entry of the panel item highlighting list (Colors\Panel Items
    Hilighting\<n> without a readable Masks value) must not hang the start-up.

.DESCRIPTION
    Per row the probe writes its own highlighting list (entries with the masks *.tc250a, *.tc250b,
    *.tc250c), damages one entry, starts the program, waits up to 30 s for the main window (answering
    and counting message boxes on the way), closes it with WM_CLOSE (the configuration is saved on
    exit) and reads back the list the program saved.
      CONTROL    a, b, c intact                         PASS = starts, no box, saved a,b,c
      NOMASKS    entry 1 without Masks, then b, c       PASS = starts, no box, saved b,c
      MIDDLE     a, entry 2 without Masks, c            PASS = starts, no box, saved a,c (skipped, not the end)
      EMPTYKEY   entry 1 a key without values, then b   PASS = starts, no box, saved b
      MULTI      two damaged entries in a row, then b   PASS = starts, no box, saved b
      WRONGTYPE  entry 1 Masks as REG_DWORD, then b     PASS = starts, at most one box, saved b
      LONG       entry 1 Masks of 400 letters, then b   PASS = starts, at most one box, saved b
    Before the fix every damaged row hangs: no main window (NOMASKS / MIDDLE / EMPTYKEY spin silently,
    WRONGTYPE / LONG show the same message box again and again).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$Lib,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. $Lib
$Root = $TempRoot + '\tc250'
$StartDir = $Root + '\start'
$HltSub = 'Software\Tandem Commander\0.1\Colors\Panel Items Hilighting'
$Str = [Microsoft.Win32.RegistryValueKind]::String
$Dw = [Microsoft.Win32.RegistryValueKind]::DWord

# writes the list: each element is 'a' / 'b' / 'c' (a good entry *.tc250<x>), 'nomasks', 'empty',
# 'dword' or 'long'
function Write-List([string[]]$Entries) {
    $cu = [Microsoft.Win32.Registry]::CurrentUser
    $cu.DeleteSubKeyTree($HltSub, $false)
    $n = 0
    foreach ($e in $Entries) {
        $n++
        $k = $cu.CreateSubKey($HltSub + '\' + $n)
        try {
            switch ($e) {
                'nomasks' { $k.SetValue('Attributes', 0, $Dw); $k.SetValue('Valid Attributes', 0, $Dw) }
                'empty' { }
                'dword' { $k.SetValue('Masks', 5, $Dw); $k.SetValue('Attributes', 0, $Dw) }
                'long' { $k.SetValue('Masks', ('*.' + ('x' * 398)), $Str); $k.SetValue('Attributes', 0, $Dw) }
                default { $k.SetValue('Masks', ('*.tc250' + $e), $Str); $k.SetValue('Attributes', 0, $Dw); $k.SetValue('Valid Attributes', 0, $Dw) }
            }
        }
        finally { $k.Close() }
    }
}
# the masks of the saved list, in order ('<no Masks>' for an entry without one)
function Read-List {
    $out = @()
    $h = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($HltSub)
    if ($null -eq $h) { return @('<no list>') }
    try {
        for ($i = 1; $i -lt 100; $i++) {
            $k = $h.OpenSubKey([string]$i)
            if ($null -eq $k) { break }
            try { $m = $k.GetValue('Masks'); if ($null -eq $m) { $out += '<no Masks>' } else { $out += [string]$m } } finally { $k.Close() }
        }
    }
    finally { $h.Close() }
    return $out
}

function Run-Case([string]$Case, [string[]]$Entries, [string[]]$Expect, [int]$MaxBoxes) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        Write-List $Entries
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T250', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $boxes = New-Object System.Collections.ArrayList
        $answered = @{}
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero -and $boxes.Count -lt 10) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) {
                $key = $h.ToInt64()
                if ($answered.ContainsKey($key) -or -not [Drv098f]::IsWindowEnabled($h)) { continue }
                $b = Buttons $h | Where-Object { @(1, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
                if (-not $b) { continue }   # the splash window (no buttons) is not a message box
                $answered[$key] = $true
                [void]$boxes.Add((WinDesc $h))
                Click $b
            }
            Start-Sleep -Milliseconds 150
        }
        $main = Get-Main $id
        $cpu = '?'; try { $cpu = '{0:N1}' -f (Get-Process -Id $id).TotalProcessorTime.TotalSeconds } catch { }
        if ($main -eq [IntPtr]::Zero) {
            $first = if ($boxes.Count) { $boxes[0] } else { 'none' }
            Row $Case 'START' 'FAIL' ("no main window after {0:N0} s; alive {1}; CPU {2} s; boxes {3} (first: {4})" -f $sw.Elapsed.TotalSeconds, (Test-Alive $id), $cpu, $boxes.Count, $first)
            Kill-Mine $id; $id = 0
            return
        }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 1500
        $r = Serve $id 10 @(1, 2)
        foreach ($m in $r.Messages) { [void]$boxes.Add($m) }
        Row $Case 'START' (V ($boxes.Count -le $MaxBoxes)) ("main window after {0:N1} s; CPU {1} s; boxes {2}{3}" -f $sw.Elapsed.TotalSeconds, $cpu, $boxes.Count, $(if ($boxes.Count) { ' (' + ($boxes -join ' || ') + ')' } else { '' }))
        End-Row $Case $id $null $before; $id = 0
        $saved = @(Read-List)
        $want = @($Expect | ForEach-Object { '*.tc250' + $_ })
        Row $Case 'SAVED' (V (($saved -join ',') -eq ($want -join ','))) ("saved list: {0}; expected: {1}" -f (($saved | ForEach-Object { Tail $_ 20 }) -join ', '), ($want -join ', '))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc250_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if (-not $existed) { throw 'needs an existing configuration (HKCU\Software\Tandem Commander) - start the program once first' }
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("hlt250_probe (feature 250) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    Run-Case 'CONTROL' @('a', 'b', 'c') @('a', 'b', 'c') 0
    Run-Case 'NOMASKS' @('nomasks', 'b', 'c') @('b', 'c') 0
    Run-Case 'MIDDLE' @('a', 'nomasks', 'c') @('a', 'c') 0
    Run-Case 'EMPTYKEY' @('empty', 'b') @('b') 0
    Run-Case 'MULTI' @('nomasks', 'empty', 'b') @('b') 0
    Run-Case 'WRONGTYPE' @('dword', 'b') @('b') 1
    Run-Case 'LONG' @('long', 'b') @('b') 1
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
