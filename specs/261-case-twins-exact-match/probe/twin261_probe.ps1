<#
.SYNOPSIS
    Feature 261 probe: in a case-sensitive folder holding a.txt and A.txt, Compare Directories and
    the viewer's next / previous file address the exact twin, not the first case-insensitive one.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder); "CS" = fsutil setCaseSensitiveInfo enable.
    Compare Directories (737) by size and time, "Include subdirectories" on; then Change Attributes
    (748) Hidden on what the compare selected in the left panel (the focus on ".."):
      CMPTWIN1  L (CS) a.txt "lower!" + A.txt "UP", R A.txt "UP": PASS = a.txt marked, A.txt not
                (before: a.txt was paired with R's A.txt - both marked)
      CMPTWIN2  L (CS) a.txt "lower!" + A.txt "UP", R (CS) a.txt "lower!": PASS = A.txt marked,
                a.txt not (control - the twin that sorts first was paired right also before)
      CMPTWINR  L A.txt "UP12", R (CS) a.txt "x" + A.txt "UP12": PASS = L A.txt not marked
                (before: paired with R's a.txt, sizes differ - marked)
      CMPSUB    L\Sub (CS) aB.txt "1" + Ab.txt "2", R\Sub (CS) ab.txt "1" + AB.txt "2": other
                names, the same sizes by position: PASS = L Sub marked (before: "identical")
      CMPSINGLE L (CS) Readme.txt, R (CS) README.txt, the same: PASS = nothing marked (a case-only
                pair without twins stays one name - feature 232's rule kept)
      CMPSHY    L a<soft hyphen>b.txt "same", R (CS) ab.txt "x1" + AB.txt "x22" + A<soft hyphen>B.txt
                "same": PASS = L not marked (review of 261: the locale key ignores the soft hyphen, so
                all four share one sort run; the case-only pair beside the twins must still pair)
    Viewer (742 = F3) on A.txt of a CS folder a.txt, A.txt, z.txt; then another program creates
    0.txt, Refresh (740) - the viewer's remembered index now holds a.txt; then:
      VIEWNEXT  next file (6086; Code Viewer, the default for .txt: 117): PASS = the viewer shows z.txt (before: A.txt again)
      VIEWPREV  previous file (6085; Code Viewer: 118): PASS = the viewer shows a.txt (before: 0.txt)
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
if (-not ('Res261' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Res261
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout) { IntPtr r; SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out r); return r.ToInt64(); }
}
'@
}
$Root = $TempRoot + '\tc261'
$StartDir = $Root + '\start'
function Btn-Of([IntPtr]$Dlg, [int]$CtlId) { $b = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($b.Count) { return $b[0] }; return [IntPtr]::Zero }
function Set-Box([IntPtr]$Dlg, [int]$CtlId, [int]$State) {   # BM_SETCHECK; TRUE when the box holds the state
    $b = Btn-Of $Dlg $CtlId
    if ($b -eq [IntPtr]::Zero) { return $false }
    [void][Res261]::SendR($b, 0x00F1, $State, 0, 5000)
    return ([Res261]::SendR($b, 0x00F0, 0, 0, 5000) -eq $State)
}
function Hidden([string]$Path) { return (([IO.File]::GetAttributes($LP + $Path) -band [IO.FileAttributes]::Hidden) -ne 0) }
function Make-Cs([string]$Dir) {   # TRUE when the folder is case-sensitive
    NewDir $Dir
    $o = & fsutil.exe file setCaseSensitiveInfo $Dir enable 2>&1
    $script:CsMsg = (($o | ForEach-Object { "$_" }) -join ' ')
    return ($LASTEXITCODE -eq 0)
}
$T0 = Get-Date '2024-01-02 03:04:05'
function Put([string]$Path, [string]$Text) {
    if (-not $Path.StartsWith($Root + '\')) { throw "outside the fixture: $Path" }
    [IO.File]::WriteAllText($LP + $Path, $Text); [IO.File]::SetLastWriteTime($LP + $Path, $T0)
}

# $Files: list of @(side, relative name, text, cs-folder flag for that side's folder of the name)
function Run-Cmp([string]$Case, [bool]$LCs, [bool]$RCs, [string]$Sub, $Files, $Expect) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    NewDir $d
    foreach ($side in @(@('L', $LCs), @('R', $RCs))) {
        $dir = "$d\" + $side[0]
        if ($Sub) { NewDir $dir; $dir = $dir + '\' + $Sub }
        if ($side[1]) { if (-not (Make-Cs $dir)) { Row $Case 'RUN' 'NOT DRIVEN' ('no case-sensitive folder: ' + $script:CsMsg); return } }
        else { NewDir $dir }
    }
    foreach ($f in $Files) {
        $p = "$d\" + $f[0] + '\'; if ($Sub) { $p = $p + $Sub + '\' }
        Put ($p + $f[1]) $f[2]
    }
    if ($Sub) { foreach ($s in @('L', 'R')) { [IO.Directory]::SetLastWriteTime($LP + "$d\$s\$Sub", $T0) } }
    $id = 0; $before = Reports
    try {
        $a = @('-t', 'T261', '-l', ('"{0}"' -f "$d\L"), '-r', ('"{0}"' -f "$d\R"), '-p', '1')
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
        $ok = $true; $facts = @()
        foreach ($e in $Expect) {
            $m = Hidden ("$d\L\" + $e[0])
            if ($m -ne $e[1]) { $ok = $false }
            $facts += ('{0} marked {1} (want {2})' -f $e[0], $m, $e[1])
        }
        Row $Case 'RUN' (V $ok) (("{0}; boxes set {1} of 8; {2}; compare: {3}; attributes: {4}" -f ($facts -join ', '), $set, $hid, (Msgs $r1), (Msgs $r2)))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

function Wait-Title([IntPtr]$W, [string]$Old, [double]$Seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $t = [Drv098f]::Txt($W)
        if ($t -cne $Old) { return $t }
        Start-Sleep -Milliseconds 100
    }
    return [Drv098f]::Txt($W)
}
function Run-View([string]$Case, [bool]$Next, [string]$WantName) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    if (-not (Make-Cs $d)) { Row $Case 'RUN' 'NOT DRIVEN' ('no case-sensitive folder: ' + $script:CsMsg); return }
    Put "$d\a.txt" 'lower'; Put "$d\A.txt" 'UPPER'; Put "$d\z.txt" 'z'
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Serve $id 10)
        Key $id 0x24; Key $id 0x28; Key $id 0x28   # Home (".."), Down (a.txt), Down (A.txt)
        Start-Sleep -Milliseconds 500
        $w = Open-ByCmd $id 742 15
        if ($w -eq [IntPtr]::Zero) { Row $Case 'RUN' 'NOT DRIVEN' 'F3 opened no viewer window'; return }
        Start-Sleep -Milliseconds 1000
        $t1 = [Drv098f]::Txt($w)
        Put "$d\0.txt" '0'
        Start-Sleep -Milliseconds 800
        Post-Cmd (Get-Main $id) 740; Start-Sleep -Milliseconds 1500
        [void](Serve $id 3)
        # the internal viewer: 6086 / 6085; the Code Viewer plug-in (the default for .txt): 117 / 118
        if ($t1 -like '*Code Viewer*') { $Cmd = $(if ($Next) { 117 } else { 118 }) } else { $Cmd = $(if ($Next) { 6086 } else { 6085 }) }
        Post-Cmd $w $Cmd
        $t2 = Wait-Title $w $t1 5
        $ok = ($t1 -cmatch '(^|\\)A\.txt') -and ($t2 -cmatch ('(^|\\)' + [regex]::Escape($WantName)))
        Row $Case 'RUN' (V $ok) ("viewer at first: '{0}'; after command {1}: '{2}' (want {3})" -f (Tail $t1 60), $Cmd, (Tail $t2 60), $WantName)
        [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 700
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc261_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("twin261_probe (feature 261) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-Cmp 'CMPTWIN1' $true $false '' @(@('L', 'a.txt', 'lower!'), @('L', 'A.txt', 'UP'), @('R', 'A.txt', 'UP')) @(@('a.txt', $true), @('A.txt', $false))
    Run-Cmp 'CMPTWIN2' $true $true '' @(@('L', 'a.txt', 'lower!'), @('L', 'A.txt', 'UP'), @('R', 'a.txt', 'lower!')) @(@('a.txt', $false), @('A.txt', $true))
    Run-Cmp 'CMPTWINR' $false $true '' @(@('L', 'A.txt', 'UP12'), @('R', 'a.txt', 'x'), @('R', 'A.txt', 'UP12')) @(, @('A.txt', $false))
    Run-Cmp 'CMPSUB' $true $true 'Sub' @(@('L', 'aB.txt', '1'), @('L', 'Ab.txt', '22'), @('R', 'ab.txt', '1'), @('R', 'AB.txt', '22')) @(, @('Sub', $true))
    Run-Cmp 'CMPSINGLE' $true $true '' @(@('L', 'Readme.txt', 'same'), @('R', 'README.txt', 'same')) @(, @('Readme.txt', $false))
    $shy = [string][char]0x00AD
    Run-Cmp 'CMPSHY' $false $true '' @(@('L', ('a' + $shy + 'b.txt'), 'same'), @('R', 'ab.txt', 'x1'), @('R', 'AB.txt', 'x22'), @('R', ('A' + $shy + 'B.txt'), 'same')) @(, @(('a' + $shy + 'b.txt'), $false))
    Run-View 'VIEWNEXT' $true 'z.txt'
    Run-View 'VIEWPREV' $false 'a.txt'
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
