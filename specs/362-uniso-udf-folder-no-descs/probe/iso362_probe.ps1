<#
.SYNOPSIS
    Feature 362: a UDF folder whose file entry declares no allocation descriptors (L_AD 0) is a damaged entry -
    a folder holds at least its parent's identifier. The ISO plug-in listed such a folder empty without a mark,
    and a whole unpack with "Delete archive after unpacking" deleted the image; now the folder is unreadable
    (feature 330): a sub-folder is listed empty with the listing marked incomplete (the image is kept), the root
    gives "Bad root ICB".

.DESCRIPTION
    Seeds (WSL Ubuntu): ud.iso by specs\330-iso-unreadable-folder\probe\mkimg330.sh (genisoimage -udf: ISO 9660 +
    UDF of a/side.txt SIDE, top.txt TOP, zlast/z.txt Z); mk_cdr.img by specs\356-uniso-udf-rest\probe\mkudf356.sh
    (mkudffs --media-type=cdr, an empty volume whose root entry is embedded); ue.iso by mkimg362.sh (this folder;
    genisoimage -udf of an empty folder e, f.txt F, g/h.txt H). img362.py (this folder) changes one file entry:
      x_alad0     ud.iso, folder a's entry L_AD 0 (short descriptors)
      x_zlad0     ud.iso, folder zlast's entry L_AD 0
      x_aemb0     ud.iso, folder a's entry embedded (type 3) with L_AD 0
      x_rootlad0  ud.iso, the UDF root's entry L_AD 0
      x_rootemb0  mk_cdr.img, the embedded root entry L_AD 0
      x_alen0     ud.iso, folder a's first extent length 0, L_AD kept (review 1)
      x_rootlen0  ud.iso, the UDF root's first extent length 0, L_AD kept (review 1)
      x_alen20, x_rootlen20  as x_alen0 / x_rootlen0 with length 20 - no identifier fits (review 2)
    Listing rows: the left panel shows <row>\src, Home, End, Enter (posted) on the image.
      L-ROOTLAD0, L-ROOTEMB0, L-ROOTLEN0, L-ROOTLEN20  PASS = "Bad root ICB", the program answers (before: no window, an empty UDF part)
      L-UE        (control) ue.iso with a real empty folder: no window
    Unpack rows: Alt+F9 (851), the target field (210) <row>\tgt, "Delete archive after unpacking" (6210)
    checked, OK; exactly the listed files with their content.
      R-ALAD0, R-AEMB0, R-ALEN0, R-ALEN20  no window; every file but UDF a/side.txt (folder a listed empty, the listing incomplete),
                  KEPT (before: deleted)
      R-ZLAD0     no window; every file but UDF zlast/z.txt, KEPT (before: deleted)
      R-ROOTLAD0, R-ROOTLEN0, R-ROOTLEN20  "Bad root ICB"; the ISO 9660 part's files, KEPT (before: deleted)
      R-ROOTEMB0  "Bad root ICB", nothing extracted, KEPT (before: deleted)
      C-UD        (control) ud.iso: every file of both parts, no window, deleted
      C-UE        (control) ue.iso: every file of both parts and both empty folders e, no window, deleted
      C-MKCDR     (control) mk_cdr.img: nothing (empty volume), no window, deleted
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not answer
    within 10 s. Without WSL Ubuntu the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\361-uniso-udf-entry-bound\probe\iso361_probe.ps1.
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
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Specs = Join-Path $Here '..\..'
if (-not $Lib) { $Lib = Join-Path $Specs '098-long-path-overruns\probe\fix_probe_lib.ps1' }
$MkMk = Join-Path $Specs '356-uniso-udf-rest\probe\mkudf356.sh'
$MkUd = Join-Path $Specs '330-iso-unreadable-folder\probe\mkimg330.sh'
$MkUe = Join-Path $Here 'mkimg362.sh'
$Py = Join-Path $Here 'img362.py'
. $Lib
$Root = $TempRoot + '\tc362'
$StartDir = $Root + '\start'
$BadRoot = 'Bad root ICB'

function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }
function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { try { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) } catch { return '<none>' } }
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $low = @($files | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @($Want.Keys | Where-Object { $low -notcontains $_.ToLowerInvariant() })
    $bad = @($Want.Keys | Where-Object { $low -contains $_.ToLowerInvariant() } | Where-Object {
            $k = $_.ToLowerInvariant(); $real = @($files | Where-Object { $_.ToLowerInvariant() -eq $k })[0]
            $Want[$_] -ne $null -and (Content $Tgt $real) -cne $Want[$_] })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}
# $Rx: the windows' text as a regex; '' = no window at all
function Windows-Ok([string]$Msgs, [string]$Rx) {
    if ($Rx) { return ($Msgs -match $Rx) }
    return ($Msgs -eq 'no window')
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Kept = the image must be
# kept (damaged), else deleted (control); $Dirs = folders that must exist in tgt (empty folders of a control)
function Unpack-Row([string]$Case, [string]$Img0, [string]$Name, $WantFiles, [switch]$Kept, [string]$Rx = '', [string[]]$Dirs = @()) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + $Name; [IO.File]::Copy($Img0, $LP + $img)
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 851 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Unpack') { throw ("851 opened '{0}', not the Unpack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        Set-Field $dlg 210 $tgt
        $btn = Find-Btn $dlg 6210
        if (-not $btn -or -not [Drv098f]::IsWindowEnabled($btn)) { throw 'the box "Delete archive after unpacking" (6210) is missing or disabled' }
        [void][Drv098f]::Send($btn, 0x00F1, 1, 0, 5000)   # BM_SETCHECK BST_CHECKED
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 60 @(1, 6)
        $msgs = Msgs $r
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $WantFiles
        $noDirs = @($Dirs | Where-Object { -not [IO.Directory]::Exists($LP + $tgt + '\' + $_.Replace('/', '\')) })
        $isKept = [IO.File]::Exists($LP + $img)
        $winOk = Windows-Ok $msgs $Rx
        $ok = $c[0] -and ($noDirs.Count -eq 0) -and (-not $fatal) -and (-not $r.TimedOut) -and $winOk -and ($isKept -eq [bool]$Kept)
        $dirTxt = ''; if ($Dirs.Count) { $dirTxt = ('; folders missing: {0}' -f $(if ($noDirs.Count) { $noDirs -join ', ' } else { 'none' })) }
        Row $Case 'RUN' (V $ok) ('{0}{1}; files ok: {2}; image kept: {3} (want {4}); windows ok ({5}): {6}; timed out: {7}; fatal: {8}; windows: {9}' -f $c[1], $dirTxt, $c[0], $isKept, [bool]$Kept, $(if ($Rx) { '"' + $Rx + '"' } else { 'none' }), $winOk, $r.TimedOut, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# Enter on the image (posted, so a box inside the listing does not block the probe)
function List-Row([string]$Case, [string]$Img0, [string]$Name, [string]$Rx = '') {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; NewDir ($d + '\src')
    $img = $d + '\src\' + $Name; [IO.File]::Copy($Img0, $LP + $img)
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $img) }
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $l = Get-LeftList $id
        [void][Drv098f]::PostMessageW($l, 0x0100, [IntPtr]0x0D, [IntPtr]1)
        [void][Drv098f]::PostMessageW($l, 0x0101, [IntPtr]0x0D, [IntPtr]0xC0000001L)
        Start-Sleep -Milliseconds 800
        $r = Serve $id 60 @(1, 6)
        $msgs = Msgs $r
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $alive = Test-Alive $id
        End-Row $Case $id $fatal $before; $id = 0
        $winOk = Windows-Ok $msgs $Rx
        $ok = $alive -and (-not $r.Died) -and (-not $fatal) -and (-not $r.TimedOut) -and $winOk
        Row $Case 'RUN' (V $ok) ('alive: {0}; windows ok ({1}): {2}; timed out: {3}; fatal: {4}; windows: {5}' -f $alive, $(if ($Rx) { '"' + $Rx + '"' } else { 'none' }), $winOk, $r.TimedOut, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc362_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso362_probe (feature 362) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- bash (WslPath $MkMk) (WslPath $s) 2>&1
    $mk2 = & wsl -d Ubuntu -- sh (WslPath $MkUd) (WslPath $s) 2>&1
    $mk3 = & wsl -d Ubuntu -- sh (WslPath $MkUe) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\mk_cdr.img")) { $made += & python -I $Py rootemb0 "$s\mk_cdr.img" "$s\x_rootemb0.bin" 2>&1 }
    if ([IO.File]::Exists("$s\ud.iso")) {
        foreach ($k in @('alad0', 'zlad0', 'aemb0', 'rootlad0', 'alen0', 'rootlen0', 'alen20', 'rootlen20')) { $made += & python -I $Py $k "$s\ud.iso" "$s\x_$k.bin" 2>&1 }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img362: ' + "$m") }
    if (-not [IO.File]::Exists("$s\mk_cdr.img")) { Out ('mkudf356.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    if (-not [IO.File]::Exists("$s\ud.iso")) { Out ('mkimg330.sh: ' + (($mk2 | ForEach-Object { "$_" }) -join ' ')) }
    if (-not [IO.File]::Exists("$s\ue.iso")) { Out ('mkimg362.sh: ' + (($mk3 | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $udAll = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/a/side.txt' = 'SIDE'; 'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $udNoA = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $udNoZ = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/a/side.txt' = 'SIDE'; 'UDF (TC330)/top.txt' = 'TOP' }
    $udIso = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z' }
    $ueAll = [ordered]@{ 'ISO (TC362)/f.txt' = 'F'; 'ISO (TC362)/g/h.txt' = 'H'; 'UDF (TC362)/f.txt' = 'F'; 'UDF (TC362)/g/h.txt' = 'H' }

    List-Row 'L-ROOTLAD0' "$s\x_rootlad0.bin" 'rootlad0.iso' $BadRoot
    List-Row 'L-ROOTEMB0' "$s\x_rootemb0.bin" 'rootemb0.iso' $BadRoot
    List-Row 'L-ROOTLEN0' "$s\x_rootlen0.bin" 'rootlen0.iso' $BadRoot
    List-Row 'L-ROOTLEN20' "$s\x_rootlen20.bin" 'rootlen20.iso' $BadRoot
    List-Row 'L-UE' "$s\ue.iso" 'ue.iso'
    Unpack-Row 'R-ALAD0' "$s\x_alad0.bin" 'alad0.iso' $udNoA -Kept
    Unpack-Row 'R-AEMB0' "$s\x_aemb0.bin" 'aemb0.iso' $udNoA -Kept
    Unpack-Row 'R-ZLAD0' "$s\x_zlad0.bin" 'zlad0.iso' $udNoZ -Kept
    Unpack-Row 'R-ROOTLAD0' "$s\x_rootlad0.bin" 'rootlad0.iso' $udIso -Kept -Rx $BadRoot
    Unpack-Row 'R-ALEN0' "$s\x_alen0.bin" 'alen0.iso' $udNoA -Kept
    Unpack-Row 'R-ROOTLEN0' "$s\x_rootlen0.bin" 'rootlen0.iso' $udIso -Kept -Rx $BadRoot
    Unpack-Row 'R-ALEN20' "$s\x_alen20.bin" 'alen20.iso' $udNoA -Kept
    Unpack-Row 'R-ROOTLEN20' "$s\x_rootlen20.bin" 'rootlen20.iso' $udIso -Kept -Rx $BadRoot
    Unpack-Row 'R-ROOTEMB0' "$s\x_rootemb0.bin" 'rootemb0.iso' ([ordered]@{}) -Kept -Rx $BadRoot
    Unpack-Row 'C-UD' "$s\ud.iso" 'ud.iso' $udAll
    Unpack-Row 'C-UE' "$s\ue.iso" 'ue.iso' $ueAll -Dirs @('ISO (TC362)/e', 'UDF (TC362)/e')
    Unpack-Row 'C-MKCDR' "$s\mk_cdr.img" 'mk_cdr.iso' ([ordered]@{})
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
