<#
.SYNOPSIS
    Feature 361: a UDF image whose folder or file entry declares a reserved allocation-descriptor type (4 - 7) or
    a descriptor area past its 2048-byte sector no longer makes the ISO plug-in's general file-entry reader
    (CUDF::ReadFileEntry(data, bEFE, part, icbTag, ad, maxAds)) loop for ever or read past its sector: the entry
    is refused the way an unreadable entry is refused today, the program answers and a whole unpack with
    "Delete archive after unpacking" keeps the image.

.DESCRIPTION
    Seeds (WSL Ubuntu): mk_cdr.img by specs\356-uniso-udf-rest\probe\mkudf356.sh (mkudffs --media-type=cdr, an
    empty VAT volume); ud.iso by specs\330-iso-unreadable-folder\probe\mkimg330.sh (genisoimage -udf: ISO 9660 +
    UDF of a/side.txt SIDE, top.txt TOP, zlast/z.txt Z); imapi250.iso by
    specs\356-uniso-udf-rest\probe\imapiudf356.ps1 -Revision 0x250 (Windows IMAPI2FS, UDF 2.50 with a metadata
    partition; d/f.txt). img361.py (this folder) changes one file entry:
      x_root5    mk_cdr, the root folder's entry descriptor type 5 (review 1 of 360's rootadt5)
      x_fold5    ud.iso, folder a's entry descriptor type 5
      x_foldlea  ud.iso, folder a's entry L_EA 0x10000000 (the area 256 MB past the sector)
      x_file5    ud.iso, file top.txt's entry descriptor type 5 (the listing reads only its size)
      x_meta5    imapi250.iso, the metadata file's entry (file type 250) descriptor type 5
    Listing rows: the left panel shows <row>\src, Home, End, Enter (posted) on the image.
      L-ROOT5    PASS = "Bad root ICB", program answers (before: it stopped answering)
      L-FOLD5, L-FOLDLEA  PASS = no window, program answers (before: a hang / an access violation)
      L-META5    PASS = the program answers (any box: IMAPI2FS 2.50 images do not list - older, 356)
      L-IMAPI250 (control) the unchanged image: the program answers (any box)
      L-UD       (control) ud.iso: no window
    Unpack rows: Alt+F9 (851), the target field (210) <row>\tgt, "Delete archive after unpacking" (6210)
    checked, OK; exactly the listed files with their content.
      R-ROOT5    "Bad root ICB", nothing extracted, KEPT
      R-FOLD5, R-FOLDLEA  no window; the ISO 9660 part whole and the UDF part's top.txt and zlast/z.txt (folder a
                 listed empty, the listing incomplete - feature 330), KEPT
      R-FILE5    the box "cannot be extracted" naming top.txt; every file but UDF top.txt, KEPT
      C-UD       (control) every file of both parts, no window, deleted
      C-MKCDR    (control) mk_cdr.img: nothing (empty volume), no window, deleted
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not answer
    within 10 s (END row: a hang shows as WM_NULL False). Without WSL Ubuntu the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\360-uniso-udf-vat-bound\probe\iso360_probe.ps1 and
    specs\330-iso-unreadable-folder\probe\iso330_probe.ps1.
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
$MkImapi = Join-Path $Specs '356-uniso-udf-rest\probe\imapiudf356.ps1'
$Py = Join-Path $Here 'img361.py'
. $Lib
$Root = $TempRoot + '\tc361'
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
# kept (damaged), else deleted (control)
function Unpack-Row([string]$Case, [string]$Img0, [string]$Name, $WantFiles, [switch]$Kept, [string]$Rx = '') {
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
        $isKept = [IO.File]::Exists($LP + $img)
        $winOk = Windows-Ok $msgs $Rx
        $ok = $c[0] -and (-not $fatal) -and (-not $r.TimedOut) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows ok ({4}): {5}; timed out: {6}; fatal: {7}; windows: {8}' -f $c[1], $c[0], $isKept, [bool]$Kept, $(if ($Rx) { '"' + $Rx + '"' } else { 'none' }), $winOk, $r.TimedOut, (Tail ([string]$fatal) 300), (Tail $msgs 500))
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

$backup = Join-Path $env:TEMP 'tc361_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso361_probe (feature 361) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- bash (WslPath $MkMk) (WslPath $s) 2>&1
    $mk2 = & wsl -d Ubuntu -- sh (WslPath $MkUd) (WslPath $s) 2>&1
    NewDir ($s + '\src250\d'); WriteFile ($s + '\src250\d\f.txt') 'F250'
    $mk3 = & powershell -NoProfile -ExecutionPolicy Bypass -File $MkImapi -SrcDir ($s + '\src250') -Out ($s + '\imapi250.iso') -Revision 0x250 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\mk_cdr.img")) { $made += & python -I $Py rootadt5 "$s\mk_cdr.img" "$s\x_root5.bin" 2>&1 }
    if ([IO.File]::Exists("$s\ud.iso")) {
        $made += & python -I $Py foldadt5 "$s\ud.iso" "$s\x_fold5.bin" 2>&1
        $made += & python -I $Py foldleabig "$s\ud.iso" "$s\x_foldlea.bin" 2>&1
        $made += & python -I $Py fileadt5 "$s\ud.iso" "$s\x_file5.bin" 2>&1
    }
    if ([IO.File]::Exists("$s\imapi250.iso")) { $made += & python -I $Py metaadt5 "$s\imapi250.iso" "$s\x_meta5.bin" 2>&1 }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img361: ' + "$m") }
    if (-not [IO.File]::Exists("$s\mk_cdr.img")) { Out ('mkudf356.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    if (-not [IO.File]::Exists("$s\ud.iso")) { Out ('mkimg330.sh: ' + (($mk2 | ForEach-Object { "$_" }) -join ' ')) }
    if (-not [IO.File]::Exists("$s\imapi250.iso")) { Out ('imapiudf356.ps1: ' + (($mk3 | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $udAll = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/a/side.txt' = 'SIDE'; 'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $udNoA = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $udNoTop = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/a/side.txt' = 'SIDE'; 'UDF (TC330)/zlast/z.txt' = 'Z' }

    List-Row 'L-ROOT5' "$s\x_root5.bin" 'root5.iso' $BadRoot
    List-Row 'L-FOLD5' "$s\x_fold5.bin" 'fold5.iso'
    List-Row 'L-FOLDLEA' "$s\x_foldlea.bin" 'foldlea.iso'
    List-Row 'L-META5' "$s\x_meta5.bin" 'meta5.iso' '.*'
    List-Row 'L-IMAPI250' "$s\imapi250.iso" 'imapi250.iso' '.*'
    List-Row 'L-UD' "$s\ud.iso" 'ud.iso'
    Unpack-Row 'R-ROOT5' "$s\x_root5.bin" 'root5.iso' ([ordered]@{}) -Kept -Rx $BadRoot
    Unpack-Row 'R-FOLD5' "$s\x_fold5.bin" 'fold5.iso' $udNoA -Kept
    Unpack-Row 'R-FOLDLEA' "$s\x_foldlea.bin" 'foldlea.iso' $udNoA -Kept
    Unpack-Row 'R-FILE5' "$s\x_file5.bin" 'file5.iso' $udNoTop -Kept -Rx 'cannot be extracted'
    Unpack-Row 'C-UD' "$s\ud.iso" 'ud.iso' $udAll
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
