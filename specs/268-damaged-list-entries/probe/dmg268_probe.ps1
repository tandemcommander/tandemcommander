<#
.SYNOPSIS
    Feature 268 probe: a damaged entry of the viewers, alternative viewers, editors or User Menu list
    must be skipped - the entries after it must survive the start-up and the save on exit.

.DESCRIPTION
    Per row the probe writes its own list (entries with the masks *.tc268a, *.tc268b, *.tc268c, or
    the User Menu item names tc268a / tc268b / tc268c), damages one entry, starts the program, waits
    up to 30 s for the main window (answering and counting message boxes on the way), closes it with
    WM_CLOSE (the configuration is saved on exit) and reads back the list the program saved. Every
    started row also gets a KEYS row: FAIL when the Debug build reports a handle left open at exit.
      V-CONTROL    Viewers a, b, c                          PASS = saved a,b,c, no box
      V-NOTYPE     Viewers a, entry 2 without Type, c       PASS = saved a,c, no box
      V-PIPE       Viewers a, entry 2 masks with '|', c     PASS = saved a,c, no box
      V-NOMASKS    Viewers entry 1 without Masks, b, c      PASS = saved b,c, no box
      AV-NOTYPE    Alternative Viewers a, no Type, c        PASS = saved a,c, no box
      E-CONTROL    Editors a, b, c                          PASS = saved a,b,c, no box
      E-NOMASKS    Editors a, entry 2 without Masks, c      PASS = saved a,c, no box
      E-WRONGTYPE  Editors a, entry 2 Masks as REG_DWORD, c PASS = saved a,c, at most one box
      E-MULTI      Editors two damaged entries, then c      PASS = saved c, no box
      U-CONTROL    User Menu a, b, c                        PASS = saved a,b,c, no box
      U-NONAME     User Menu a, entry 2 without Item Name, c PASS = saved a,c, no box
      U-WRONGTYPE  User Menu a, entry 2 Close Shell Window as REG_SZ, c  PASS = saved a,c, at most one box
    Before the fix every damaged row ends its list at the damaged entry: the save keeps only the
    entries before it, and the damaged entry's key is left open.
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
$Root = $TempRoot + '\tc268'
$StartDir = $Root + '\start'
$Base = 'Software\Tandem Commander\0.1\'
$Str = [Microsoft.Win32.RegistryValueKind]::String
$Dw = [Microsoft.Win32.RegistryValueKind]::DWord
# the lists: registry key under the configuration, and the value that identifies an entry
$Lists = @{
    'V'  = @{ Key = 'Viewers'; Id = 'Masks' }
    'AV' = @{ Key = 'Alternative Viewers'; Id = 'Masks' }
    'E'  = @{ Key = 'Editors'; Id = 'Masks' }
    'U'  = @{ Key = 'User Menu'; Id = 'Item Name' }
}

# one good entry of a list, its identifying value '*.tc268<x>' (masks) or 'tc268<x>' (item name)
function Set-Good($k, [string]$List, [string]$x) {
    switch ($List) {
        'U' {
            $k.SetValue('Item Name', ('tc268' + $x), $Str); $k.SetValue('Command', 'cmd.exe', $Str)
            $k.SetValue('Arguments', '', $Str); $k.SetValue('Initial Directory', '$(Drive)$(Path)', $Str)
            $k.SetValue('Execute Through Shell', 0, $Dw); $k.SetValue('Close Shell Window', 0, $Dw)
            $k.SetValue('Open Shell Window', 1, $Dw); $k.SetValue('Icon', '', $Str)
            $k.SetValue('Type', 0, $Dw); $k.SetValue('Show In Toolbar', 0, $Dw)
        }
        default {
            $k.SetValue('Masks', ('*.tc268' + $x), $Str); $k.SetValue('Command', 'notepad.exe', $Str)
            $k.SetValue('Arguments', '"$(Name)"', $Str); $k.SetValue('Initial Directory', '$(FullPath)', $Str)
            if ($List -ne 'E') { $k.SetValue('Type', 0, $Dw) }
        }
    }
}
# writes the list: each element is 'a' / 'b' / 'c' (a good entry) or a damage kind: 'notype',
# 'pipe', 'nomasks', 'dword' (Masks as REG_DWORD), 'noname', 'closesz' (Close Shell Window as REG_SZ),
# 'empty' (a key without values)
function Write-List([string]$List, [string[]]$Entries) {
    $cu = [Microsoft.Win32.Registry]::CurrentUser
    $sub = $Base + $Lists[$List].Key
    $cu.DeleteSubKeyTree($sub, $false)
    $n = 0
    foreach ($e in $Entries) {
        $n++
        $k = $cu.CreateSubKey($sub + '\' + $n)
        try {
            switch ($e) {
                'notype' { Set-Good $k $List 'x'; $k.DeleteValue('Type') }
                'pipe' { Set-Good $k $List 'x'; $k.SetValue('Masks', '*.tc268x|*.tc268y', $Str) }
                'nomasks' { Set-Good $k $List 'x'; $k.DeleteValue('Masks') }
                'dword' { Set-Good $k $List 'x'; $k.SetValue('Masks', 5, $Dw) }
                'noname' { Set-Good $k $List 'x'; $k.DeleteValue('Item Name') }
                'closesz' { Set-Good $k $List 'x'; $k.SetValue('Close Shell Window', 'yes', $Str) }
                'empty' { }
                default { Set-Good $k $List $e }
            }
        }
        finally { $k.Close() }
    }
}
# the identifying values of the saved list, in order
function Read-List([string]$List) {
    $out = @()
    $h = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Base + $Lists[$List].Key)
    if ($null -eq $h) { return @('<no list>') }
    try {
        for ($i = 1; $i -lt 200; $i++) {
            $k = $h.OpenSubKey([string]$i)
            if ($null -eq $k) { break }
            try { $m = $k.GetValue($Lists[$List].Id); if ($null -eq $m) { $out += '<none>' } else { $out += [string]$m } } finally { $k.Close() }
        }
    }
    finally { $h.Close() }
    return $out
}

function Run-Case([string]$Case, [string]$List, [string[]]$Entries, [string[]]$Expect, [int]$MaxBoxes) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        Write-List $List $Entries
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T268', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
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
        if ($main -eq [IntPtr]::Zero) {
            $first = if ($boxes.Count) { $boxes[0] } else { 'none' }
            Row $Case 'START' 'FAIL' ("no main window after {0:N0} s; alive {1}; boxes {2} (first: {3})" -f $sw.Elapsed.TotalSeconds, (Test-Alive $id), $boxes.Count, $first)
            Kill-Mine $id; $id = 0
            return
        }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 1500
        $r = Serve $id 10 @(1, 2)
        foreach ($m in $r.Messages) { [void]$boxes.Add($m) }
        Row $Case 'START' (V ($boxes.Count -le $MaxBoxes)) ("main window after {0:N1} s; boxes {1}{2}" -f $sw.Elapsed.TotalSeconds, $boxes.Count, $(if ($boxes.Count) { ' (' + ($boxes -join ' || ') + ')' } else { '' }))
        End-Row $Case $id $null $before; $id = 0
        # the Debug build reports a registry key left open at exit ("monitored handles remained
        # opened"); End-Row only notes it - here it fails the row
        $endLine = [string]$script:Lines[$script:Lines.Count - 1]
        Row $Case 'KEYS' (V ($endLine -notmatch 'monitored handles')) $(if ($endLine -match 'monitored handles') { 'a handle was left open (Debug handle monitor)' } else { 'no handle left open' })
        $saved = @(Read-List $List)
        $pre = if ($List -eq 'U') { 'tc268' } else { '*.tc268' }
        $want = @($Expect | ForEach-Object { $pre + $_ })
        Row $Case 'SAVED' (V (($saved -join ',') -eq ($want -join ','))) ("saved {0}: {1}; expected: {2}" -f $Lists[$List].Key, (($saved | ForEach-Object { Tail $_ 30 }) -join ', '), ($want -join ', '))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc268_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if (-not $existed) { throw 'needs an existing configuration (HKCU\Software\Tandem Commander) - start the program once first' }
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("dmg268_probe (feature 268) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    Run-Case 'V-CONTROL' 'V' @('a', 'b', 'c') @('a', 'b', 'c') 0
    Run-Case 'V-NOTYPE' 'V' @('a', 'notype', 'c') @('a', 'c') 0
    Run-Case 'V-PIPE' 'V' @('a', 'pipe', 'c') @('a', 'c') 0
    Run-Case 'V-NOMASKS' 'V' @('nomasks', 'b', 'c') @('b', 'c') 0
    Run-Case 'AV-NOTYPE' 'AV' @('a', 'notype', 'c') @('a', 'c') 0
    Run-Case 'E-CONTROL' 'E' @('a', 'b', 'c') @('a', 'b', 'c') 0
    Run-Case 'E-NOMASKS' 'E' @('a', 'nomasks', 'c') @('a', 'c') 0
    Run-Case 'E-WRONGTYPE' 'E' @('a', 'dword', 'c') @('a', 'c') 1
    Run-Case 'E-MULTI' 'E' @('empty', 'nomasks', 'c') @('c') 0
    Run-Case 'U-CONTROL' 'U' @('a', 'b', 'c') @('a', 'b', 'c') 0
    Run-Case 'U-NONAME' 'U' @('a', 'noname', 'c') @('a', 'c') 0
    Run-Case 'U-WRONGTYPE' 'U' @('a', 'closesz', 'c') @('a', 'c') 1
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
