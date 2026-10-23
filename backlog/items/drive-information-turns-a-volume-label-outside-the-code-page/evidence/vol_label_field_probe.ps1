<#
.SYNOPSIS
    Measurement probe of this backlog item (autonomous run of 2026-10-23, at ae49a67d): does the
    label field of Drive Information (752) hold every Unicode letter - a label outside the code page
    neither turned into '?' when set nor when typed; the error path, the "unchanged" rule (069) and
    the too-long refusal (270) of feature 300 still hold. Measured: every row PASS at ae49a67d - the
    field is a comctl32 6 Unicode edit inside the code-page dialog, the dialog's modal loop is wide;
    vol-negctl shows the read-back detects a code-page window (loop_negctl.ps1 the code-page loop).

.DESCRIPTION
    The real write cannot be driven unelevated on a fixed drive (the call fails with access denied);
    a label outside the code page cannot be put on the drive either - the person step of the item.
    The drive is the fixture's (the drive of %TEMP%). Rows:
      vol-kind     the label field after the dialog opened: PASS = a Unicode window
                   (IsWindowUnicode), Cancel
      vol-cyr-set  'Disk1' in Cyrillic (U+0414 U+0438 U+0441 U+043A '1') set into the field by a
                   wide WM_SETTEXT: PASS = the field reads back the same five letters (a code-page
                   field would read '????1'), Cancel, the drive's label unchanged
      vol-cjk-type the field cleared, then the CJK letters U+4E2D U+6587 and '2' posted as wide WM_CHAR
                   (as TranslateMessage delivers typed letters): PASS = the field reads back the three
                   letters as typed (a code-page field or loop: '??2'), Cancel, the label unchanged
      vol-negctl   negative control: the same wide WM_SETTEXT into IDB_FREESPACE (565) of the same
                   dialog, which WinLib subclasses with the code-page SetWindowLongPtr: PASS = an ANSI
                   window and the read-back '????1' (the method sees the loss where it exists)
      vol-cyr-ok   the Cyrillic label 'Disk2', OK: the write fails (not elevated). PASS = the dialog
                   stays, "Unable to change drive label." shown, the field still holds the Cyrillic
                   letters, the drive's label unchanged
      vol-fail     300's row: 'Zalohy' with a-acute, OK: the write fails; PASS = as vol-cyr-ok
      vol-same     300's row: the label left as the drive has it, OK: PASS = the dialog closes,
                   nothing asked, the label unchanged, the next Drive Information shows the same
      vol-long     270's row: 140 r-caron (280 bytes), OK: PASS = refused as too long, the field
                   whole, the label unchanged
    The rows that press OK are NOT DRIVEN when the probe runs elevated or the drive is not fixed
    (the label could then really be written); the rows that end with Cancel run always. Driver of
    300's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1. Registry
    exported, restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\..\..\specs\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. $Lib
if (-not ('Drv324k' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Drv324k
{
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
}
'@
}
$Root = $TempRoot + '\tc324_vol'
$StartDir = $Root + '\start'
$CmdDriveInfo = 752
$FieldLabel = 552
$TooLong = 'too long'
$Unable = 'Unable to change drive label'
$Cyr1 = [string]([char]0x0414) + [char]0x0438 + [char]0x0441 + [char]0x043A + '1'
$Cyr2 = [string]([char]0x0414) + [char]0x0438 + [char]0x0441 + [char]0x043A + '2'
$CjkTyped = [string]([char]0x4E2D) + [char]0x6587 + '2'

function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    $held = [Drv098f]::GetText($f, 5000)
    if ($held -cne $Text) { throw ("field $CtlId did not take the text ({0} of {1} units, reads '{2}')" -f $held.Length, $Text.Length, (Esc $held)) }
}
function Get-Field([IntPtr]$Dlg, [int]$CtlId) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { return '<no field>' }
    return [Drv098f]::GetText($f, 5000)
}
# answers every window except $Keep with OK / Yes; until idle
function Serve324([int]$Id, $Keep = @(), [double]$Seconds = 40) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and $Keep -notcontains $_ })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            [void]$r.Messages.Add($d)
            $btn = Buttons $h; $pick = $null
            foreach ($want in @(6, 1)) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } }
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function Short([string]$s) {
    $s = $s -replace '\[Button id=\d+\] [^|]*(\||$)', ''
    $s = $s -replace '\[Static id=-?\d+\] ', ''
    if ($s.Length -gt 200) { $s = $s.Substring(0, 200) + '...' }
    return $s.Trim()
}
function DriveLabel { return (New-Object IO.DriveInfo ($TempRoot.Substring(0, 1))).VolumeLabel }

# one Drive Information row that never presses OK: $Action gets the dialog and returns a fact
# text and a verdict; then Cancel
function Field-Row([string]$Case, [scriptblock]$Action) {
    $before = Reports; $id = 0; $fatal = $null
    try {
        $labelBefore = DriveLabel
        $id = Start-Tc $StartDir
        $dlg = Open-ByCmd $id $CmdDriveInfo 15
        if ($dlg -eq [IntPtr]::Zero) { throw "command $CmdDriveInfo opened no window" }
        $res = & $Action $dlg
        Close-Win $dlg; Start-Sleep -Milliseconds 500
        $r = Serve324 $id @() 15
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $labelAfter = DriveLabel
        $shown = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || '); if (-not $shown) { $shown = 'nothing' }
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and $res.Ok -and ($r.Messages.Count -eq 0) -and ($labelAfter -ceq $labelBefore)
        Row $Case 'RUN' (V $ok) ("{0}; after Cancel asked: {1}; label of the drive before '{2}', after '{3}'" -f $res.Facts, $shown, (Esc $labelBefore), (Esc $labelAfter))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# one Drive Information row: $Text into the label field (or the field left as shown when $Text is
# $null), OK, everything answered; returns the facts
function Vol-Row([string]$Case, $Text, [scriptblock]$Verdict) {
    $before = Reports; $id = 0; $fatal = $null
    try {
        $labelBefore = DriveLabel
        $id = Start-Tc $StartDir
        $dlg = Open-ByCmd $id $CmdDriveInfo 15
        if ($dlg -eq [IntPtr]::Zero) { throw "command $CmdDriveInfo opened no window" }
        $shownAtOpen = Get-Field $dlg $FieldLabel
        if ($null -ne $Text) { Set-Field $dlg $FieldLabel $Text } else { $Text = $shownAtOpen }
        Click-Ok $dlg
        Start-Sleep -Milliseconds 700
        $r = Serve324 $id @($dlg)
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        $atRefusal = $null
        if ($stayed -and -not $fatal) {
            $atRefusal = Get-Field $dlg $FieldLabel
            Close-Win $dlg; Start-Sleep -Milliseconds 500
            $r2 = Serve324 $id @() 15
            foreach ($m in $r2.Messages) { [void]$r.Messages.Add('after cancel: ' + $m) }
            if ($r2.Fatal) { $fatal = $r2.Fatal }
        }
        $reopened = $null
        if (-not $stayed -and -not $fatal) {
            $dlg2 = Open-ByCmd $id $CmdDriveInfo 15
            if ($dlg2 -eq [IntPtr]::Zero) { throw 'Drive Information did not open again' }
            $reopened = Get-Field $dlg2 $FieldLabel
            Close-Win $dlg2; Start-Sleep -Milliseconds 400
            [void](Serve324 $id @() 10)
        }
        $labelAfter = DriveLabel
        $shown = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || '); if (-not $shown) { $shown = 'nothing' }
        $facts = [pscustomobject]@{ Stayed = $stayed; Shown = $shown; AtRefusal = $atRefusal; Reopened = $reopened; LabelBefore = $labelBefore; LabelAfter = $labelAfter; Text = $Text; ShownAtOpen = $shownAtOpen }
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and (& $Verdict $facts)
        Row $Case 'RUN' (V $ok) ("typed {0} units / {1} bytes '{2}'; field at opening '{3}'; dialog stayed: {4}; asked: {5}; field at the refusal: {6}; next dialog's field: {7}; label of the drive before '{8}', after '{9}'{10}" -f $Text.Length, (U8Len $Text), (Tail $Text 12), (Esc $shownAtOpen), $stayed, $shown, $(if ($null -ne $atRefusal) { "{0} units, same as typed: {1}" -f $atRefusal.Length, ($atRefusal -ceq $Text) } else { '-' }), $(if ($null -ne $reopened) { "'" + (Esc $reopened) + "'" } else { '-' }), (Esc $labelBefore), (Esc $labelAfter), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$CancelRows = @('vol-kind', 'vol-cyr-set', 'vol-cjk-type', 'vol-negctl')
$Cases = [ordered]@{}
$Cases['vol-kind'] = {
    Field-Row 'vol-kind' {
        param($dlg)
        $f = Find-Ctl $dlg $FieldLabel
        if ($f -eq [IntPtr]::Zero) { throw "field $FieldLabel not found" }
        $fu = [Drv324k]::IsWindowUnicode($f); $du = [Drv324k]::IsWindowUnicode($dlg)
        [pscustomobject]@{ Ok = $fu; Facts = ("label field a Unicode window: {0}; dialog a Unicode window: {1}" -f $fu, $du) }
    }
}
$Cases['vol-cyr-set'] = {
    Field-Row 'vol-cyr-set' {
        param($dlg)
        $f = Find-Ctl $dlg $FieldLabel
        if ($f -eq [IntPtr]::Zero) { throw "field $FieldLabel not found" }
        [void][Drv098f]::SetText($f, $Cyr1, 5000)
        $held = [Drv098f]::GetText($f, 5000)
        [pscustomobject]@{ Ok = ($held -ceq $Cyr1); Facts = ("set '{0}', field reads '{1}'" -f (Esc $Cyr1), (Esc $held)) }
    }
}
$Cases['vol-cjk-type'] = {
    Field-Row 'vol-cjk-type' {
        param($dlg)
        $f = Find-Ctl $dlg $FieldLabel
        if ($f -eq [IntPtr]::Zero) { throw "field $FieldLabel not found" }
        [void][Drv098f]::SetText($f, '', 5000)
        foreach ($c in $CjkTyped.ToCharArray()) { [void][Drv098f]::PostMessageW($f, 0x0102, [IntPtr][int]$c, [IntPtr]1); Start-Sleep -Milliseconds 100 }
        Start-Sleep -Milliseconds 400
        $held = [Drv098f]::GetText($f, 5000)
        [pscustomobject]@{ Ok = ($held -ceq $CjkTyped); Facts = ("typed (WM_CHAR) '{0}', field reads '{1}'" -f (Esc $CjkTyped), (Esc $held)) }
    }
}
$Cases['vol-negctl'] = {
    # negative control: IDB_FREESPACE (565, a button) of the same dialog is attached by WinLib with the
    # code-page SetWindowLongPtr (CColorRectangle) - an ANSI window; the same wide WM_SETTEXT must read
    # back '?'
    Field-Row 'vol-negctl' {
        param($dlg)
        $f = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 565 }) | Select-Object -First 1
        if (-not $f) { Close-Win $dlg; throw 'control 565 not found' }
        $fu = [Drv324k]::IsWindowUnicode($f)
        [void][Drv098f]::SetText($f, $Cyr1, 5000)
        $held = [Drv098f]::GetText($f, 5000)
        [pscustomobject]@{ Ok = ((-not $fu) -and ($held -ceq '????1')); Facts = ("control 565 a Unicode window: {0}; set '{1}', reads '{2}' (expected the loss '????1')" -f $fu, (Esc $Cyr1), (Esc $held)) }
    }
}
$Cases['vol-cyr-ok'] = {
    $t = $Cyr2
    if ((DriveLabel) -ceq $t) { $t = $Cyr1 }
    Vol-Row 'vol-cyr-ok' $t { param($f) $f.Stayed -and ($f.Shown -match $Unable) -and ($f.AtRefusal -ceq $f.Text) -and ($f.LabelAfter -ceq $f.LabelBefore) }
}
$Cases['vol-fail'] = {
    $t = 'Z' + [char]0x00E1 + 'lohy'
    if ((DriveLabel) -ceq $t) { $t = $t + '2' }
    Vol-Row 'vol-fail' $t { param($f) $f.Stayed -and ($f.Shown -match $Unable) -and ($f.AtRefusal -ceq $f.Text) -and ($f.LabelAfter -ceq $f.LabelBefore) }
}
$Cases['vol-same'] = {
    Vol-Row 'vol-same' $null { param($f) (-not $f.Stayed) -and ($f.Shown -eq 'nothing') -and ($f.Reopened -ceq $f.ShownAtOpen) -and ($f.LabelAfter -ceq $f.LabelBefore) }
}
$Cases['vol-long'] = {
    $t = [string]([char]0x0159) * 140
    Vol-Row 'vol-long' $t { param($f) $f.Stayed -and ($f.Shown -match $TooLong) -and ($f.AtRefusal -ceq $f.Text) -and ($f.LabelAfter -ceq $f.LabelBefore) }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc324_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    WriteFile "$StartDir\a.txt" 'A'
    Set-Config
    $elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $drive = New-Object IO.DriveInfo ($TempRoot.Substring(0, 1))
    Out ("vol324_probe (item measurement) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; elevated {3}; drive {4} {5}, label '{6}'" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, $elevated, $drive.Name, $drive.DriveType, (Esc $drive.VolumeLabel))
    Out ''
    foreach ($k in @($Cases.Keys)) {
        if (Want $k) {
            if (($CancelRows -notcontains $k) -and ($elevated -or $drive.DriveType -ne 'Fixed')) { Row $k 'RUN' 'NOT DRIVEN' ("elevated: {0}, drive type {1} - the label could really be written" -f $elevated, $drive.DriveType); continue }
            & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
            if ($existed) { & cmd.exe /c "reg import `"$backup`" >nul 2>&1" }
            Set-Config
            & $Cases[$k]
        }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
