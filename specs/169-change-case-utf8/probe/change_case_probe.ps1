<#
.SYNOPSIS
    Feature 169 probe: Change Case (command 747) renames a file whose name has letters outside
    ASCII to the right name - not to bytes the code page's case table made of its UTF-8.

.DESCRIPTION
    A row: a folder with one file; all selected (Select, 841, '*'); Change Case with the given
    radio button and "Whole filename"; OK; the folder's content read afterwards (the probe reads
    the names wide). PASS = exactly the expected name, nothing else in the folder.
      CTRL-LOWER  ASCII.TXT -> ascii.txt                              (control: passes on any build)
      CZ-LOWER    SARKA with S-caron, A-acute -> sarka (s-caron, a-acute)
      CZ-UPPER    zlutoucky kun (z-caron, t-caron, ...) -> upper case
      GR-UPPER    elliniko (Greek small) -> Greek capital
      RU-MIXED    privet mir (Cyrillic small) -> mixed case: each word capitalised
      CZ-PARTMIX  NAME.TXT form with c-caron: name mixed, extension lower
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
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
if (-not ('Res169' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Res169
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout) { IntPtr r; SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out r); return r.ToInt64(); }
}
'@
}
$Root = $TempRoot + '\tc169'
$StartDir = $Root + '\start'
function U([string]$s) { return [regex]::Unescape($s) }
function Btn-Of([IntPtr]$Dlg, [int]$CtlId) { $b = @(Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($b.Count) { return $b[0] }; return [IntPtr]::Zero }

function Run-Case([string]$Case, [string]$Name, [int]$Radio, [string]$Expected) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case; NewDir $d
    [IO.File]::WriteAllText($LP + $d + '\' + $Name, 'x')
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Serve $id 10)
        $sel = Open-ByCmd $id 841 10
        if ($sel -eq [IntPtr]::Zero) { Row $Case 'NAME' 'NOT DRIVEN' 'no Select dialog'; return }
        [void][Drv098f]::SetText((Find-Ctl $sel 101), '*', 5000); Click-Ok $sel
        Start-Sleep -Milliseconds 600
        $dlg = Open-ByCmd $id 747 10
        $dlgDesc = WinDesc $dlg
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'NAME' 'NOT DRIVEN' 'no Change Case dialog'; return }
        # the case and "Whole filename": a click on each radio button (BM_CLICK - the group is
        # unchecked by the button itself; fix_probe_lib's Find-Ctl finds only edits and combo boxes)
        foreach ($c in @($Radio, 401)) {
            $b = Btn-Of $dlg $c
            if ($b -ne [IntPtr]::Zero) { [void][Res169]::SendR($b, 0x00F5, 0, 0, 5000) }
        }
        $checked = @(@(542, 543, 544, 548, 401, 402, 403) | Where-Object { [Res169]::SendR((Btn-Of $dlg $_), 0x00F0, 0, 0, 5000) -eq 1 })
        Click-Ok $dlg
        $r = Serve $id 30 @(1, 6)
        [void]$r.Messages.Insert(0, '[dialog ' + $dlgDesc + '; checked before OK: ' + ($checked -join ',') + ']')
        End-Row $Case $id $null $before; $id = 0
        $names = @([IO.Directory]::GetFileSystemEntries($LP + $d) | ForEach-Object { [IO.Path]::GetFileName($_) })
        $ok = $names.Count -eq 1 -and $names[0] -ceq $Expected
        Row $Case 'NAME' (V $ok) ("'{0}' -> folder holds {1}; expected '{2}'; windows: {3}" -f (Esc $Name), (($names | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', '), (Esc $Expected), (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc169_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("change_case_probe (feature 169), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    # IDC_LOWERCASE 543, IDC_UPPERCASE 544, IDC_CAPITALIZE 542, IDC_PARTMIXEDCASE 548
    Run-Case 'CTRL-LOWER' 'ASCII.TXT' 543 'ascii.txt'
    Run-Case 'CZ-LOWER' (U 'ŠÁRKA.TXT') 543 (U 'šárka.txt')
    Run-Case 'CZ-UPPER' (U 'žluťoučký kůň.txt') 544 (U 'ŽLUŤOUČKÝ KŮŇ.TXT')
    Run-Case 'GR-UPPER' (U 'ελληνικα.txt') 544 (U 'ΕΛΛΗΝΙΚΑ.TXT')
    Run-Case 'RU-MIXED' (U 'привет мир.txt') 542 (U 'Привет Мир.Txt')
    Run-Case 'CZ-PARTMIX' (U 'ČERNÁ KOČKA.TXT') 548 (U 'Černá Kočka.txt')
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
