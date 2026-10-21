<#
.SYNOPSIS
    Probe: after a menu-bar popup closes, does a typed character reach the focused field?
    (backlog item menubar-loop-swallows-typed-characters)

.DESCRIPTION
    Written for the measurement of the item at fed08ad1 (result: menubar_probe_result_fed08ad1.txt).
    Main window rows (MAIN*, see Main-Row): Alt+F, the popup closed in the row's way, then a plain
    'e' posted - a running menu bar loop opens the Edit popup on it. MAINESC is the control (Esc
    keeps the loop by design: PASS = a popup); MAINCANCEL / MAINDEACT / MAINOTHER: PASS = nothing.
    Find window rows (command 741, opened per row): Alt+F posted to the Named field's edit; when the
    popup goes away by itself (<case>-SELF, the 093 / 168 timing) or after the row's closer, 'q'
    and 'm' are posted to the field - a running loop drops 'q' and opens a popup on 'm'; an ended
    loop lets "qm" reach the field. F10CTRL / ESC / ACTESC are controls expecting a running loop;
    on the hidden desktop the Find window's loop never stayed (they FAIL), so the Find rows show
    only that characters reach the field after every self-closed popup.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$Lib,
    [int]$Early = 6,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\..\..\specs\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tcmbl'
$StartDir = $Root + '\start'

function Get-Popups([int]$Id) { return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq 'PopupMenuClass' }) }
function Wait-Popup([int]$Id, [double]$Seconds = 2.0) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { $m = Get-Popups $Id; if ($m.Count) { return $m[0] }; Start-Sleep -Milliseconds 30 }
    return $null
}
function Wait-NoPopup([int]$Id, [double]$Seconds = 2.0) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if (-not (Get-Popups $Id).Count) { return $true }; Start-Sleep -Milliseconds 30 }
    return $false
}
function Post-Esc([IntPtr]$H) { [void][Drv098f]::PostMessageW($H, 0x0100, [IntPtr]0x1B, [IntPtr]1); [void][Drv098f]::PostMessageW($H, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001) }
function Inner-Edit([IntPtr]$Ctl) {
    if ([Drv098f]::Cls($Ctl) -eq 'Edit') { return $Ctl }
    $e = @([Drv098f]::Kids($Ctl) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' })
    if ($e.Count) { return $e[0] }
    return [IntPtr]::Zero
}
# the Find window, its Named field's edit (cleared)
function Open-Find([int]$Id, [bool]$Settle) {
    $dlg = Open-ByCmd $Id 741
    if ($dlg -eq [IntPtr]::Zero) { throw 'command 741 opened no window' }
    $named = Find-Ctl $dlg 2505; $in = Inner-Edit $named
    if ($in -eq [IntPtr]::Zero) { throw 'no edit in the Named field (2505)' }
    if ($Settle) { [void][Drv098f]::Send($dlg, 0, 0, 0, 5000); Start-Sleep -Milliseconds 1500; [void][Drv098f]::Send($dlg, 0, 0, 0, 5000) }
    [void][Drv098f]::SetText($in, '', 5000)
    return @($dlg, $in)
}
# posts 'q' to the edit, lets the window serve its queue, returns the field's text
function Type-Q([IntPtr]$Dlg, [IntPtr]$In) {
    [void][Drv098f]::PostMessageW($In, 0x0102, [IntPtr]0x71, [IntPtr]1)
    for ($i = 0; $i -lt 4; $i++) { [void][Drv098f]::Send($Dlg, 0, 0, 0, 5000); Start-Sleep -Milliseconds 150 }
    return [Drv098f]::GetText($In, 5000)
}
# other windows of the pid: not the main window, not the Find window, not a popup
function Strays([int]$Id, [IntPtr]$Dlg) { return @(Get-Tops $Id | Where-Object { $_ -ne $Dlg -and [Drv098f]::Cls($_) -ne $MainClass -and [Drv098f]::Cls($_) -ne 'PopupMenuClass' }) }
# ends a menu bar loop that may still run without touching anything else: a click posted to the
# Named label ends the loop (it is re-posted to the label, which ignores it) and is harmless outside it
function End-Loop([IntPtr]$Dlg) {
    $lbl = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1150 }) | Select-Object -First 1
    if ($lbl) { Post-Click $lbl 2 2 }
    [void][Drv098f]::Send($Dlg, 0, 0, 0, 5000); Start-Sleep -Milliseconds 200
}
# closes the Find window: IDCANCEL, the "Do you want to close Find?" question answered Yes
function Close-Find([int]$Id, [IntPtr]$Dlg) {
    foreach ($p in (Get-Popups $Id)) { Post-Esc $p; [void](Wait-NoPopup $Id 1) }
    if (-not [Drv098f]::IsWindow($Dlg)) { return }
    End-Loop $Dlg
    Post-Cmd $Dlg 2
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 5 -and [Drv098f]::IsWindow($Dlg)) {
        foreach ($h in (Strays $Id $Dlg)) { $y = Buttons $h | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1; if ($y) { Click $y } }
        Start-Sleep -Milliseconds 200
    }
    if ([Drv098f]::IsWindow($Dlg)) { Out '           the Find window did not close' }
}
function Alt-F([IntPtr]$In) { [void][Drv098f]::PostMessageW($In, 0x0106, [IntPtr]0x66, [IntPtr]0x20000001) }
# Alt+F; returns the popup when it is still there 300 ms later, 'self' when it showed and went away by itself, $null when none showed
function Open-Popup([int]$Id, [IntPtr]$In) {
    Alt-F $In
    $p = Wait-Popup $Id
    if (-not $p) { return $null }
    Start-Sleep -Milliseconds 300
    if ((Get-Popups $Id) -contains $p) { return $p }
    return 'self'
}
# posts 'q' (no mnemonic) and then 'm' (the Find menu's mnemonic of the second item) to the field.
# A running menu bar loop drops 'q' and opens a popup on 'm'; an ended loop lets both reach the field.
function Check-Q([string]$Case, [IntPtr]$Dlg, [IntPtr]$In, [string]$How, [bool]$Swallow) {
    Start-Sleep -Milliseconds 300
    [void][Drv098f]::SetText($In, '', 5000)
    $t = Type-Q $Dlg $In
    [void][Drv098f]::PostMessageW($In, 0x0102, [IntPtr]0x6D, [IntPtr]1)
    $pm = $null; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 1.0 -and -not $pm) { $m = Get-Popups $script:Pid0; if ($m.Count) { $pm = $m[0] }; Start-Sleep -Milliseconds 30 }
    for ($i = 0; $i -lt 3; $i++) { [void][Drv098f]::Send($Dlg, 0, 0, 0, 5000); Start-Sleep -Milliseconds 100 }
    $t2 = [Drv098f]::GetText($In, 5000)
    if ($pm) { foreach ($p in (Get-Popups $script:Pid0)) { Post-Esc $p }; [void](Wait-NoPopup $script:Pid0 1) }
    if ($Swallow) { $ok = ($t -ceq '') -and [bool]$pm; $exp = "'q' dropped and a popup on 'm' - the menu bar stays active by design" }
    else { $ok = ($t2 -ceq 'qm') -and -not $pm; $exp = "'qm' in the field, no popup" }
    Row $Case 'RUN' (V $ok) ("{0}; field after 'q': '{1}', after 'm': '{2}'; popup on 'm': {3} (expected {4})" -f $How, (Esc $t), (Esc $t2), [bool]$pm, $exp)
}
# the main window (the pattern of 093's passing main-menu rows): its caption made active by a sent
# WM_NCACTIVATE, Alt+F posted, the popup closed in the row's way; then a plain 'e' is posted. A
# running menu bar loop opens the Edit popup on it; an ended loop does not.
#   MAINESC     control: Esc to the popup - the loop stays by design: PASS = a popup on 'e'
#   MAINCANCEL  WM_CANCELMODE sent to the main window            PASS = no popup on 'e'
#   MAINDEACT   WM_ACTIVATE(WA_INACTIVE) sent to the main window PASS = no popup on 'e'
#   MAINOTHER   Change Directory (862) opens over the menu, is closed  PASS = no popup on 'e'
function Main-Row([int]$Id, [string]$Case) {
    if (-not (Want $Case)) { return }
    $mw = Get-Main $Id
    try {
        [void][Drv098f]::Send($mw, 0x0086, 1, 0, 5000)
        [void][Drv098f]::PostMessageW($mw, 0x0106, [IntPtr]0x66, [IntPtr]0x20000001)
        $p = Wait-Popup $Id
        if (-not $p) { Row $Case 'OPEN' 'NOT DRIVEN' 'Alt+F opened no popup'; return }
        Start-Sleep -Milliseconds 300
        if (-not ((Get-Popups $Id) -contains $p)) { Row $Case 'OPEN' 'NOT DRIVEN' 'the popup went away by itself'; return }
        $how = ''
        switch ($Case) {
            'MAINESC' { Post-Esc $p; $how = 'control: Esc posted to the popup' }
            'MAINCANCEL' { [void][Drv098f]::Send($mw, 0x001F, 0, 0, 5000); $how = 'WM_CANCELMODE sent to the main window' }
            'MAINDEACT' { [void][Drv098f]::Send($mw, 0x0006, 0, 0, 5000); $how = 'WM_ACTIVATE(WA_INACTIVE) sent to the main window' }
            'MAINOTHER' {
                $cd = Open-ByCmd $Id 862
                if ($cd -eq [IntPtr]::Zero) { $how = 'Change Directory did not open' }
                else { Start-Sleep -Milliseconds 500; Close-Win $cd; Start-Sleep -Milliseconds 300; $how = 'Change Directory opened over the menu and closed' }
                [void][Drv098f]::Send($mw, 0x0086, 1, 0, 5000)
            }
        }
        if (-not (Wait-NoPopup $Id 2.0)) { Row $Case 'RUN' 'FAIL' ($how + '; the popup did not close'); return }
        Start-Sleep -Milliseconds 200
        [void][Drv098f]::PostMessageW($mw, 0x0102, [IntPtr]0x65, [IntPtr]1)
        $p2 = Wait-Popup $Id 1.5
        $want = ($Case -eq 'MAINESC')
        Row $Case 'RUN' (V ([bool]$p2 -eq $want)) ("{0}; popup gone; a posted plain 'e' then {1} (expected {2})" -f $how, $(if ($p2) { 'opened a popup - the menu bar loop was still running' } else { 'opened nothing - the loop had ended' }), $(if ($want) { 'a popup' } else { 'nothing' }))
        if ($p2) { Post-Esc $p2; [void](Wait-NoPopup $Id 1.5) }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message) }
    finally {
        foreach ($q in (Get-Popups $Id)) { Post-Esc $q; [void](Wait-NoPopup $Id 1) }
        Post-Esc $mw; Start-Sleep -Milliseconds 300
        [void][Drv098f]::Send($mw, 0x0086, 0, 0, 5000)
        [void][Drv098f]::Send($mw, 0, 0, 0, 5000); Start-Sleep -Milliseconds 300
    }
}

function Run-Row([int]$Id, [string]$Case) {
    if (-not (Want $Case)) { return }
    $dlg = [IntPtr]::Zero
    try {
        $early = $Case -like 'EARLY*'
        $f = Open-Find $Id (-not $early); $dlg = $f[0]; $in = $f[1]
        if ($Case -eq 'F10CTRL') {
            # control in the Find window: F10 enters its menu bar's loop without a popup; the loop must drop 'q' and open a popup on 'm'
            [void][Drv098f]::PostMessageW($in, 0x0100, [IntPtr]0x79, [IntPtr]1); [void][Drv098f]::PostMessageW($in, 0x0101, [IntPtr]0x79, [IntPtr]0xC0000001)
            Check-Q $Case $dlg $in 'control: F10 posted to the Named field (the menu bar loop without a popup)' $true
            return
        }
        if ($Case -eq 'ACTESC') { [void][Drv098f]::Send($dlg, 0x0086, 1, 0, 5000) }   # caption active, as 093 does for the main window
        $p = Open-Popup $Id $in
        if ($p -eq 'self') {
            # the popup went away by itself (the 093 timing): is the menu bar's loop left running?
            Check-Q ($Case + '-SELF') $dlg $in 'the first popup went away by itself' $false
            End-Loop $dlg
            if ($early) { return }
            $p = Open-Popup $Id $in
        }
        if ($null -eq $p) { Row $Case 'OPEN' 'NOT DRIVEN' 'Alt+F opened no popup'; return }
        if ($p -eq 'self') { Row $Case 'OPEN' 'NOT DRIVEN' 'the second popup went away by itself too'; return }
        if ($early) { Row $Case 'RUN' 'NOT DRIVEN' 'the popup stayed - not the 093 timing in this run'; return }
        $how = ''
        switch ($Case) {
            'ESC' { Post-Esc $p; $how = 'Esc posted to the popup' }
            'ACTESC' { Post-Esc $p; $how = 'caption made active; Esc posted to the popup' }
            'CANCELMODE' { [void][Drv098f]::Send($dlg, 0x001F, 0, 0, 5000); $how = 'WM_CANCELMODE sent to the Find window' }
            'DEACTIVATE' { [void][Drv098f]::Send($dlg, 0x0006, 0, 0, 5000); $how = 'WM_ACTIVATE(WA_INACTIVE) sent to the Find window' }
            'OTHERWIN' {
                $cd = Open-ByCmd $Id 862
                if ($cd -eq [IntPtr]::Zero) { $how = 'Change Directory did not open' }
                else { Start-Sleep -Milliseconds 500; Close-Win $cd; Start-Sleep -Milliseconds 300; $how = 'Change Directory opened and closed' }
            }
        }
        if (-not (Wait-NoPopup $Id 2.0)) { Row $Case 'RUN' 'FAIL' ($how + '; the popup did not close'); return }
        Check-Q $Case $dlg $in ($how + '; popup gone') ($Case -like '*ESC' -or $Case -eq 'F10CTRL')
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($dlg -ne [IntPtr]::Zero) {
            $s = @(Strays $Id $dlg)
            if ($s.Count) { Out ('           other windows before closing: ' + (($s | ForEach-Object { WinDesc $_ }) -join ' || ')) }
            Close-Find $Id $dlg
        }
        [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 5000); Start-Sleep -Milliseconds 300
    }
}

$backup = Join-Path $env:TEMP 'tcmbl_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0; $id = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("menubar_probe (backlog item menubar-loop-swallows-typed-characters) {0}" -f $Label)
    Out ("Program : {0}  (built {1:yyyy-MM-dd HH:mm:ss})" -f $Exe, (Get-Item -LiteralPath $Exe).LastWriteTime)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    $before = Reports
    $id = Start-Tc $StartDir; $script:Pid0 = $id
    foreach ($c in @('MAINESC', 'MAINCANCEL', 'MAINDEACT', 'MAINOTHER')) { Main-Row $id $c }
    foreach ($c in @('F10CTRL', 'ESC', 'ACTESC', 'CANCELMODE', 'DEACTIVATE', 'OTHERWIN')) { Run-Row $id $c }
    for ($i = 1; $i -le $Early; $i++) { Run-Row $id ("EARLY{0}" -f $i) }
    End-Row 'END' $id $null $before; $id = 0
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
