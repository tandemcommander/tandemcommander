<#
.SYNOPSIS
    Feature 231 probe: in a case-sensitive folder (fsutil file setCaseSensitiveInfo) holding a.txt and
    A.txt, a selection restored by name selects only the item that was selected - never its other-case
    twin.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\cs - a case-sensitive folder holding
    A.txt, a.txt and z.txt. The panel shows it; Home, Down focuses the first file (A.txt or a.txt -
    whichever sorts first), Insert selects it.
      RESEL   Change Attributes (748) with no change (OK) - the selection is stored and cleared;
              Reselect (865); Change Attributes Hidden on the selection: PASS = exactly the selected
              one hidden (its twin and z.txt not)
      GLOBAL  Store Selection (866, its dialog: OK), Unselect All (844), Restore Selection (867, its
              dialog: OK);
              Change Attributes Hidden: PASS as above
      HIDE    Hide Selected Names (2945) - the selected one leaves the panel; Select All (842), Change
              Attributes Hidden: PASS = the twin and z.txt hidden (still in the panel), the selected
              one not
      CONTROL a case-insensitive folder holding a.txt and z.txt, RESEL's steps: PASS = a.txt hidden
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Res231' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Res231
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout) { IntPtr r; SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out r); return r.ToInt64(); }
}
'@
}
$Root = $TempRoot + '\tc231'
$StartDir = $Root + '\start'
function Btn-Of([IntPtr]$Dlg, [int]$CtlId) { $b = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($b.Count) { return $b[0] }; return [IntPtr]::Zero }
function Set-Box([IntPtr]$Dlg, [int]$CtlId, [int]$State) {
    $b = Btn-Of $Dlg $CtlId
    if ($b -eq [IntPtr]::Zero) { return $false }
    [void][Res231]::SendR($b, 0x00F1, $State, 0, 5000)
    return ([Res231]::SendR($b, 0x00F0, 0, 0, 5000) -eq $State)
}
function Hidden([string]$Path) { return (([IO.File]::GetAttributes($LP + $Path) -band [IO.FileAttributes]::Hidden) -ne 0) }
# runs a command that opens a dialog and answers it with OK (setting the Hidden box when asked)
function Dialog-Ok([int]$Id, [int]$Cmd, [bool]$SetHidden) {
    $dlg = Open-ByCmd $Id $Cmd 10
    if ($dlg -eq [IntPtr]::Zero) { return 'no dialog' }
    $d = WinDesc $dlg
    if ($SetHidden) { [void](Set-Box $dlg 243 1) }
    Click-Ok $dlg
    [void](Serve $Id 20 @(1, 6))
    return (Tail $d 60)
}

function Run-Case([string]$Case, [bool]$CaseSensitive, [string]$Kind) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case + '\cs'
    NewDir $d
    if ($CaseSensitive) {
        $o = & fsutil.exe file setCaseSensitiveInfo $d enable 2>&1
        if ($LASTEXITCODE -ne 0) { Row $Case 'RUN' 'NOT DRIVEN' ('no case-sensitive folder: ' + (($o | ForEach-Object { "$_" }) -join ' ')); return }
        [IO.File]::WriteAllText($LP + "$d\A.txt", 'UPPER'); [IO.File]::WriteAllText($LP + "$d\a.txt", 'lower')
    }
    else { [IO.File]::WriteAllText($LP + "$d\a.txt", 'lower') }
    [IO.File]::WriteAllText($LP + "$d\z.txt", 'z')
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Serve $id 10)
        Key $id 0x24; Key $id 0x28; Key $id 0x2D   # Home, Down, Insert: the first file selected
        Start-Sleep -Milliseconds 500
        $steps = New-Object System.Collections.ArrayList
        if ($Kind -eq 'resel') {
            [void]$steps.Add('attr: ' + (Dialog-Ok $id 748 $false))
            Post-Cmd (Get-Main $id) 865; Start-Sleep -Milliseconds 800
        }
        elseif ($Kind -eq 'hide') {
            Post-Cmd (Get-Main $id) 2945; Start-Sleep -Milliseconds 1500
            Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        }
        else {
            [void]$steps.Add('store: ' + (Dialog-Ok $id 866 $false))
            Post-Cmd (Get-Main $id) 844; Start-Sleep -Milliseconds 500
            [void]$steps.Add('restore: ' + (Dialog-Ok $id 867 $false))
        }
        [void]$steps.Add('hidden: ' + (Dialog-Ok $id 748 $true))
        End-Row $Case $id $null $before; $id = 0
        $names = @([IO.Directory]::GetFiles($LP + $d) | ForEach-Object { [IO.Path]::GetFileName($_) })
        $hid = @($names | Where-Object { Hidden ("$d\" + $_) })
        $ok = ($hid.Count -eq 1) -and ($hid[0] -cne 'z.txt')
        if ($Kind -eq 'hide') { $ok = ($hid.Count -eq 2) -and ($hid -ccontains 'z.txt') }
        Row $Case 'RUN' (V $ok) ("files {0}; hidden: {1}; steps: {2}" -f ($names -join ','), $(if ($hid.Count) { $hid -join ',' } else { 'none' }), ($steps -join ' / '))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc231_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("resel231_probe (feature 231) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-Case 'CONTROL' $false 'resel'
    Run-Case 'RESEL' $true 'resel'
    Run-Case 'GLOBAL' $true 'global'
    Run-Case 'HIDE' $true 'hide'
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
