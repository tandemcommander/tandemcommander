<#
.SYNOPSIS
    Feature 232 probe: Compare Directories pairs names that differ only in case (an ordinary,
    case-insensitive folder: "Readme.txt" on the left is "README.txt" on the right).

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\L and <row>\R (the panels).
      FILE     L\Readme.txt and R\README.txt, the same content and time: PASS = nothing marked
      DIR      L\Sub\f.txt and R\SUB\f.txt, the same: PASS = nothing marked
      CONTROL  L\Readme.txt "22" and R\README.txt "1" (sizes differ; by size the larger is
               marked - and before the fix every unpaired name): PASS = Readme.txt marked
      FILECS   as FILE, the same case on both sides: PASS = nothing marked
      NFD      L\<e-acute>.txt (NFC) and R\<e + combining acute>.txt (NFD): two names (FR-009 of
               feature 004) - PASS = the left one marked (it has no pair)
      RENSEL   one panel: Readme.txt selected (Insert), renamed to README.txt by another program,
               Refresh (740); Change Attributes Hidden on the selection: PASS = README.txt hidden
               (the selection follows a case-only rename, as before feature 004)
      CSKEEP1  a case-sensitive folder holding a.txt, A.txt, z.txt: the first file selected, Refresh,
      CSKEEP2  (2: the second file) Change Attributes Hidden: PASS = exactly the selected twin hidden
               (feature 231 made the folder case-sensitive for the panel; the refresh merge lost a
               selected twin that sorted after the other one)
    Compare Directories (737) by size and time, "Include subdirectories" on; then Change
    Attributes (748) Hidden on what the compare selected in the left panel (the focus on "..").
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
if (-not ('Res232' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Res232
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout) { IntPtr r; SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out r); return r.ToInt64(); }
}
'@
}
$Root = $TempRoot + '\tc232'
$StartDir = $Root + '\start'
function Btn-Of([IntPtr]$Dlg, [int]$CtlId) { $b = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($b.Count) { return $b[0] }; return [IntPtr]::Zero }
function Set-Box([IntPtr]$Dlg, [int]$CtlId, [int]$State) {   # BM_SETCHECK; TRUE when the box holds the state
    $b = Btn-Of $Dlg $CtlId
    if ($b -eq [IntPtr]::Zero) { return $false }
    [void][Res232]::SendR($b, 0x00F1, $State, 0, 5000)
    return ([Res232]::SendR($b, 0x00F0, 0, 0, 5000) -eq $State)
}
function Hidden([string]$Path) { return (([IO.File]::GetAttributes($LP + $Path) -band [IO.FileAttributes]::Hidden) -ne 0) }
function Run-Case([string]$Case, [string]$LName, [string]$RName, [string]$LText, [string]$RText, [bool]$Dir, [bool]$WantMarked) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $t = Get-Date '2024-01-02 03:04:05'
    NewDir "$d\L"; NewDir "$d\R"
    foreach ($side in @(@('L', $LName, $LText), @('R', $RName, $RText))) {
        if ($Dir) { NewDir ("$d\" + $side[0] + '\' + $side[1]); $f = "$d\" + $side[0] + '\' + $side[1] + '\f.txt' }
        else { $f = "$d\" + $side[0] + '\' + $side[1] }
        [IO.File]::WriteAllText($LP + $f, $side[2]); [IO.File]::SetLastWriteTime($LP + $f, $t)
    }
    $id = 0; $before = Reports
    try {
        $a = @('-t', 'T232', '-l', ('"{0}"' -f "$d\L"), '-r', ('"{0}"' -f "$d\R"), '-p', '1')
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
        $marked = Hidden ("$d\L\" + $LName)
        $ok = ($marked -eq $WantMarked)
        Row $Case 'RUN' (V $ok) ("left {0} marked {1} (want {2}); boxes set {3} of 8; {4}; compare: {5}; attributes: {6}" -f $LName, $marked, $WantMarked, $set, $hid, (Msgs $r1), (Msgs $r2))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

function Run-RenSel([string]$Case) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    NewDir $d
    [IO.File]::WriteAllText($LP + "$d\Readme.txt", 'r'); [IO.File]::WriteAllText($LP + "$d\z.txt", 'z')
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Serve $id 10)
        Key $id 0x24; Key $id 0x28; Key $id 0x2D   # Home, Down, Insert: Readme.txt selected
        Start-Sleep -Milliseconds 500
        [IO.File]::Move($LP + "$d\Readme.txt", $LP + "$d\tmp232.txt"); [IO.File]::Move($LP + "$d\tmp232.txt", $LP + "$d\README.txt")
        Start-Sleep -Milliseconds 1500
        Post-Cmd (Get-Main $id) 740; Start-Sleep -Milliseconds 1500
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 748
        $dlg2 = Wait-NewWin $id $known 5
        $hid = 'no dialog'
        if ($dlg2 -ne [IntPtr]::Zero) { $hb = Set-Box $dlg2 243 1; Click-Ok $dlg2; $hid = "Hidden set $hb" }
        $r2 = Serve $id 20 @(1, 6)
        $names = @([IO.Directory]::GetFiles($LP + $d) | ForEach-Object { [IO.Path]::GetFileName($_) })
        $h = @($names | Where-Object { Hidden ("$d\" + $_) })
        $ok = ($h.Count -eq 1) -and ($h[0] -ceq 'README.txt')
        Row $Case 'RUN' (V $ok) ("files {0}; hidden: {1}; {2}; windows: {3}" -f ($names -join ','), $(if ($h.Count) { $h -join ',' } else { 'none' }), $hid, (Msgs $r2))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

function Run-CsKeep([string]$Case, [int]$Downs) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    NewDir $d
    $o = & fsutil.exe file setCaseSensitiveInfo $d enable 2>&1
    if ($LASTEXITCODE -ne 0) { Row $Case 'RUN' 'NOT DRIVEN' ('no case-sensitive folder: ' + (($o | ForEach-Object { "$_" }) -join ' ')); return }
    [IO.File]::WriteAllText($LP + "$d\a.txt", 'lower'); [IO.File]::WriteAllText($LP + "$d\A.txt", 'UPPER'); [IO.File]::WriteAllText($LP + "$d\z.txt", 'z')
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Serve $id 10)
        Key $id 0x24
        for ($k = 0; $k -lt $Downs; $k++) { Key $id 0x28 }
        Key $id 0x2D   # Insert: the twin selected
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) 740; Start-Sleep -Milliseconds 1500
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 748
        $dlg2 = Wait-NewWin $id $known 5
        $hid = 'no dialog'
        if ($dlg2 -ne [IntPtr]::Zero) { $hb = Set-Box $dlg2 243 1; Click-Ok $dlg2; $hid = "Hidden set $hb" }
        $r2 = Serve $id 20 @(1, 6)
        $names = @([IO.Directory]::GetFiles($LP + $d) | ForEach-Object { [IO.Path]::GetFileName($_) })
        $h = @($names | Where-Object { Hidden ("$d\" + $_) })
        $ok = ($h.Count -eq 1) -and ($h[0] -cne 'z.txt')
        Row $Case 'RUN' (V $ok) ("files {0}; hidden: {1}; {2}; windows: {3}" -f ($names -join ','), $(if ($h.Count) { $h -join ',' } else { 'none' }), $hid, (Msgs $r2))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc232_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cmp232_probe (feature 232) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-Case 'CONTROL' 'Readme.txt' 'README.txt' '22' '1' $false $true
    Run-Case 'FILECS' 'Readme.txt' 'Readme.txt' 'same' 'same' $false $false
    Run-Case 'FILE' 'Readme.txt' 'README.txt' 'same' 'same' $false $false
    Run-Case 'DIR' 'Sub' 'SUB' 'same' 'same' $true $false
    Run-Case 'NFD' ([string][char]0x00E9 + '.txt') ('e' + [char]0x0301 + '.txt') 'same' 'same' $false $true
    Run-RenSel 'RENSEL'
    Run-CsKeep 'CSKEEP1' 1
    Run-CsKeep 'CSKEEP2' 2
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
