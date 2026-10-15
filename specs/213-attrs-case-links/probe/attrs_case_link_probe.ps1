<#
.SYNOPSIS
    Feature 213 probe: Change Attributes (748), Change Case (747) and Convert (814) with "Include
    subdirectories" never change the files of a junction's TARGET - a junction is not walked.

.DESCRIPTION
    Fixture per row (all under the probe's %TEMP% folder):
      <row>\in\sel\OWN.TXT        a file of the selected folder (the control: it does change)
      <row>\in\sel\j              a junction -> <row>\out\tgt
      <row>\out\tgt\T.TXT         the junction's target file (must not change)
    The panel shows <row>\in; Home, End focus 'sel'; the command's dialog: subdirectories on.
      ATTR  Hidden set: PASS = OWN.TXT hidden, T.TXT and the folder tgt not hidden
      CASE  lower case, whole name: PASS = own.txt, T.TXT keeps its name
      CONV  line ends to LF (CR/LF in both files): PASS = OWN.TXT converted, T.TXT not
      SELJ  the junction itself selected (<row>\in holds only j), Hidden + subdirectories:
            PASS = T.TXT and the folder tgt not hidden (the junction itself may be)
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
if (-not ('Res213' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Res213
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout) { IntPtr r; SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out r); return r.ToInt64(); }
}
'@
}
$Root = $TempRoot + '\tc213'
$StartDir = $Root + '\start'
$script:Links = New-Object System.Collections.ArrayList
function Btn-Of([IntPtr]$Dlg, [int]$CtlId) { $b = @(Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($b.Count) { return $b[0] }; return [IntPtr]::Zero }
function Check-Box([IntPtr]$Dlg, [int]$CtlId) {   # BM_SETCHECK 1; FALSE when the box is not there
    $b = Btn-Of $Dlg $CtlId
    if ($b -eq [IntPtr]::Zero) { return $false }
    [void][Res213]::SendR($b, 0x00F1, 1, 0, 5000)
    return ([Res213]::SendR($b, 0x00F0, 0, 0, 5000) -eq 1)
}
function Names([string]$Dir) { return (@([IO.Directory]::GetFileSystemEntries($LP + $Dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object) -join ',') }
function Hidden([string]$File) { return (([IO.File]::GetAttributes($LP + $File) -band [IO.FileAttributes]::Hidden) -ne 0) }

# $Cmd: 748 / 747 / 814; $Boxes: check boxes set on (IDC_HIDDEN 243, IDC_LOWERCASE 543, IDC_WHOLENAME 401,
# IDC_RECURSESUBDIRS 248); $Clicks: radio buttons clicked (IDC_CHC_EOFLF 2495); $Selected: the
# junction itself is the focused item; $Check: scriptblock -> @(ok, facts)
function Run-Case([string]$Case, [int]$Cmd, [int[]]$Boxes, [scriptblock]$Check, [int[]]$Clicks = @(), [switch]$Selected) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    NewDir $d; NewDir "$d\in"; NewDir "$d\out"; NewDir "$d\out\tgt"
    if (-not $Selected) { NewDir "$d\in\sel"; [IO.File]::WriteAllText($LP + "$d\in\sel\OWN.TXT", "own`r`nline`r`n") }
    [IO.File]::WriteAllText($LP + "$d\out\tgt\T.TXT", "target`r`nline`r`n")
    $j = $(if ($Selected) { "$d\in\j" } else { "$d\in\sel\j" })
    $o = & cmd.exe /c ("mklink /J `"{0}`" `"{1}`"" -f $j, "$d\out\tgt") 2>&1
    if (-not [IO.Directory]::Exists($j)) { Row $Case 'RUN' 'NOT DRIVEN' ('no junction: ' + (($o | ForEach-Object { "$_" }) -join ' ')); return }
    [void]$script:Links.Add($j)
    $id = 0; $before = Reports
    try {
        $id = Start-Tc "$d\in"
        [void](Serve $id 10)
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id $Cmd 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'RUN' 'NOT DRIVEN' "command $Cmd opened no dialog"; return }
        $dlgDesc = WinDesc $dlg
        foreach ($c in $Clicks) { $b = Btn-Of $dlg $c; if ($b -ne [IntPtr]::Zero) { [void][Res213]::SendR($b, 0x00F5, 0, 0, 5000) } }
        $set = @($Boxes | Where-Object { Check-Box $dlg $_ })
        Click-Ok $dlg
        $r = Serve $id 30 @(1, 6)
        End-Row $Case $id $null $before; $id = 0
        $res = & $Check $d
        $setAll = $set.Count -eq $Boxes.Count
        Row $Case 'RUN' (V ($res[0] -and $setAll)) ("{0}; boxes set {1} of {2}; dialog: {3}; windows: {4}" -f $res[1], $set.Count, $Boxes.Count, (Tail $dlgDesc 80), (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc213_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("attrs_case_link_probe (feature 213) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-Case 'ATTR' 748 @(243, 248) {
        param($d)
        $own = Hidden "$d\in\sel\OWN.TXT"; $t = Hidden "$d\out\tgt\T.TXT"; $tf = Hidden "$d\out\tgt"
        @(($own -and -not $t -and -not $tf), ("OWN.TXT hidden {0}; target T.TXT hidden {1}; the folder tgt hidden {2}; target holds {3}" -f $own, $t, $tf, (Names "$d\out\tgt")))
    }
    Run-Case 'CONV' 814 @(248) {
        param($d)
        $own = [IO.File]::ReadAllText($LP + "$d\in\sel\OWN.TXT"); $t = [IO.File]::ReadAllText($LP + "$d\out\tgt\T.TXT")
        @((($own -ceq "own`nline`n") -and ($t -ceq "target`r`nline`r`n")), ("OWN.TXT {0}; target T.TXT {1}" -f (Esc $own), (Esc $t)))
    } @(2495)
    Run-Case 'SELJ' 748 @(243, 248) {
        param($d)
        $t = Hidden "$d\out\tgt\T.TXT"; $tf = Hidden "$d\out\tgt"; $jh = Hidden "$d\in\j"
        @((-not $t -and -not $tf), ("the junction hidden {0}; target T.TXT hidden {1}; the folder tgt hidden {2}" -f $jh, $t, $tf))
    } @() -Selected
    Run-Case 'CASE' 747 @(543, 401, 248) {
        param($d)
        $sel = Names "$d\in\sel"; $tg = Names "$d\out\tgt"
        @((($sel -ceq 'j,own.txt') -and ($tg -ceq 'T.TXT')), ("sel holds {0}; target holds {1}" -f $sel, $tg))
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    # the junctions first (rmdir removes a junction only), then the fixture
    foreach ($l in @($script:Links)) { if ([IO.Directory]::Exists($l)) { [void](& cmd.exe /c ("rmdir `"{0}`"" -f $l) 2>&1) } }
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
