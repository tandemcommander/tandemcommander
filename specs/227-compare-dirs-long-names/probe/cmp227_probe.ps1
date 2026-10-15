<#
.SYNOPSIS
    Feature 227 probe: Compare Directories with "Include subdirectories" compares a subfolder
    whose name is 260+ bytes in UTF-8 - never another folder whose name is its cut form.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\L and <row>\R (the left and the right
    panel), each holding the folders
      N   the long name (LONG: 86 CJK letters + "ab" = 260 bytes; SHORT: "nn") - its f.txt differs
          between L and R ("1" / "22")
      S   N cut to 259 bytes (LONG: 86 CJK letters + "a"; SHORT: "ss") - its f.txt the same on both
          sides (same content and time)
    Compare Directories (737) by size and time, "Include subdirectories" on; then Change
    Attributes (748) Hidden on what the compare selected in the left panel (the focus on "..").
      SHORT  the control: PASS = L\N hidden, L\S not
      LONG   PASS = L\N hidden (its content differs), L\S not; or a refusal ("too long") with
             nothing hidden - never S compared in N's place (N then left unmarked)
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
if (-not ('Res227' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Res227
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout) { IntPtr r; SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out r); return r.ToInt64(); }
}
'@
}
$Root = $TempRoot + '\tc227'
$StartDir = $Root + '\start'
function Btn-Of([IntPtr]$Dlg, [int]$CtlId) { $b = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($b.Count) { return $b[0] }; return [IntPtr]::Zero }
function Set-Box([IntPtr]$Dlg, [int]$CtlId, [int]$State) {   # BM_SETCHECK; TRUE when the box holds the state
    $b = Btn-Of $Dlg $CtlId
    if ($b -eq [IntPtr]::Zero) { return $false }
    [void][Res227]::SendR($b, 0x00F1, $State, 0, 5000)
    return ([Res227]::SendR($b, 0x00F0, 0, 0, 5000) -eq $State)
}
function Hidden([string]$Path) { return (([IO.File]::GetAttributes($LP + $Path) -band [IO.FileAttributes]::Hidden) -ne 0) }
$Cjk = [string][char]0x4E2D
$LongS = ($Cjk * 86) + 'a'
$LongN = $LongS + 'b'

function Run-Case([string]$Case, [string]$NName, [string]$SName) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $t = Get-Date '2024-01-02 03:04:05'
    foreach ($side in @('L', 'R')) {
        foreach ($f in @($NName, $SName)) { NewDir "$d\$side\$f" }
        [IO.File]::WriteAllText($LP + "$d\$side\$NName\f.txt", $(if ($side -eq 'L') { '1' } else { '22' }))
        [IO.File]::WriteAllText($LP + "$d\$side\$SName\f.txt", 'same')
        foreach ($f in @($NName, $SName)) { [IO.File]::SetLastWriteTime($LP + "$d\$side\$f\f.txt", $t) }
    }
    $id = 0; $before = Reports
    try {
        $a = @('-t', 'T227', '-l', ('"{0}"' -f "$d\L"), '-r', ('"{0}"' -f "$d\R"), '-p', '1')
        $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        [void](Serve $id 10)
        Key $id 0x24
        $dlg = Open-ByCmd $id 737 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'RUN' 'NOT DRIVEN' 'Compare Directories opened no dialog'; return }
        # by size and time, subdirectories; not by content / attributes, not "one panel dirs", no ignore masks
        $set = @(@(@(197, 1), @(192, 1), @(193, 0), @(194, 0), @(231, 0), @(234, 0), @(195, 1), @(196, 0)) | Where-Object { Set-Box $dlg $_[0] $_[1] }).Count
        Click-Ok $dlg
        $r1 = Serve $id 30 @(1, 6)
        Key $id 0x24
        Start-Sleep -Milliseconds 500
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 748
        $dlg2 = Wait-NewWin $id $known 5
        $hid = 'no dialog (nothing selected)'
        if ($dlg2 -ne [IntPtr]::Zero) {
            if ([Drv098f]::Cls($dlg2) -eq '#32770' -and (Btn-Of $dlg2 243) -ne [IntPtr]::Zero) { $hb = Set-Box $dlg2 243 1; Click-Ok $dlg2; $hid = "Hidden set $hb" }
            else { $hid = 'another window: ' + (WinDesc $dlg2); Close-Win $dlg2 }
        }
        $r2 = Serve $id 20 @(1, 6)
        $nH = Hidden "$d\L\$NName"; $sH = Hidden "$d\L\$SName"
        $refused = (@($r1.Messages) -join ' ') -match 'too long'
        $ok = ($nH -and -not $sH) -or ($refused -and -not $nH -and -not $sH)
        Row $Case 'RUN' (V $ok) ("N hidden {0}, S hidden {1} (N {2} bytes); boxes set {3} of 8; {4}; compare: {5}; attributes: {6}" -f $nH, $sH, (U8Len $NName), $set, $hid, (Msgs $r1), (Msgs $r2))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc227_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cmp227_probe (feature 227) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-Case 'SHORT' 'nn' 'ss'
    Run-Case 'LONG' $LongN $LongS
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
