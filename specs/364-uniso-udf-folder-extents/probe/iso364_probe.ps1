<#
.SYNOPSIS
    Feature 364: a UDF folder stored in more than one extent was read by the ISO plug-in only up to its first
    extent - the rest of its entries were not listed, nothing was marked, and a whole unpack with "Delete archive
    after unpacking" deleted the image. Now every extent of a folder is walked; a folder that is still not read
    whole (an extent that is not recorded, descriptors continued elsewhere, extents shorter than its Information
    Length) marks the listing incomplete (feature 330), so a whole unpack keeps the image.

.DESCRIPTION
    Seeds (WSL Ubuntu): big364.iso by mkimg364.sh (this folder; genisoimage -udf -R, root and sub with 40 files
    a_rather_long_file_name_NN.txt each, content RNN / SNN - each folder 2.9 KB in one extent) and ud.iso by
    specs\330-iso-unreadable-folder\probe\mkimg330.sh (a/side.txt SIDE, top.txt TOP, zlast/z.txt Z). img364.py
    (this folder) changes one folder entry:
      x_rootsplit  the root's extent split into two contiguous ones (2048 + 916 bytes) - valid
      x_rootfrag   as rootsplit, the second extent moved to a free block, the old block zeroed - valid
      x_subsplit   as rootsplit for folder sub (2048 + 872 bytes) - valid
      x_subfrag    as rootfrag for folder sub - valid
      x_rootcont   the root: 2048 bytes + an allocation extent descriptor (type 3) - the rest is not read
      x_rootunrec  as rootsplit, the second extent of type 1 (allocated, not recorded)
      x_alen38/40  ud.iso: folder a's one extent 88 -> 38 / 40 bytes, its Information Length kept 88
    Listing rows: the left panel shows <row>\src, Home, End, Enter (posted) on the image; PASS = no window, the
    program answers, no bug report:
      L-ROOTFRAG, L-SUBFRAG, L-ROOTCONT, L-BIG (control)
    Unpack rows: Alt+F9 (851), the target field (210) <row>\tgt, "Delete archive after unpacking" (6210)
    checked, OK; exactly the listed files with their content, no window (big364 rows compare the UDF part only -
    the ISO 9660 part carries Rock Ridge names):
      R-ROOTSPLIT, R-ROOTFRAG, R-SUBSPLIT, R-SUBFRAG   all 80 UDF files, deleted
      R-ROOTCONT, R-ROOTUNREC   the root's files 00 .. 27 (those whose identifiers start in the first 2048
                  bytes), not sub, KEPT
      R-ALEN38, R-ALEN40   the ISO 9660 part and UDF top.txt, zlast/z.txt (folder a read short: listed empty,
                  the listing incomplete), KEPT
      C-BIG, C-UD (controls) every file, deleted
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not answer
    within 10 s. Without WSL Ubuntu the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\363-uniso-udf-fid-bound\probe\iso363_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$Specs
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Specs) { $Specs = Join-Path $Here '..\..' }
if (-not $Lib) { $Lib = Join-Path $Specs '098-long-path-overruns\probe\fix_probe_lib.ps1' }
$MkUd = Join-Path $Specs '330-iso-unreadable-folder\probe\mkimg330.sh'
$MkBig = Join-Path $Here 'mkimg364.sh'
$Py = Join-Path $Here 'img364.py'
. $Lib
$Root = $TempRoot + '\tc364'
$StartDir = $Root + '\start'

function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }
$script:Part = ''   # when set, only the extracted files under this folder are compared
function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Where-Object { -not $script:Part -or $_.StartsWith($script:Part + '/') } | Sort-Object)
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
    $extra = @($files | Where-Object { $k = $_.ToLowerInvariant(); @($Want.Keys | Where-Object { $_.ToLowerInvariant() -eq $k }).Count -eq 0 })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    $f = ('files {0} (want {1})' -f $files.Count, $Want.Count)
    if ($missing.Count) { $m = @($missing | Select-Object -First 6); if ($missing.Count -gt 6) { $m += '...' }; $f += ('; missing {0}: {1}' -f $missing.Count, ($m -join ', ')) }
    if ($extra.Count) { $x = @($extra | Select-Object -First 6 | ForEach-Object { Esc $_ }); if ($extra.Count -gt 6) { $x += '...' }; $f += ('; extra {0}: {1}' -f $extra.Count, ($x -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}
# $Rx: the windows' text as a regex; '' = no window at all
function Windows-Ok([string]$Msgs, [string]$Rx) {
    if ($Rx) { return ($Msgs -match $Rx) }
    return ($Msgs -eq 'no window')
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Kept = the image must be
# kept (read short), else deleted (read whole)
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

$backup = Join-Path $env:TEMP 'tc364_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso364_probe (feature 364) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath $MkUd) (WslPath $s) 2>&1
    $mkb = & wsl -d Ubuntu -- sh (WslPath $MkBig) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\big364.iso")) {
        foreach ($k in @('rootsplit', 'rootfrag', 'subsplit', 'subfrag', 'rootcont', 'rootunrec')) { $made += & python -I $Py $k "$s\big364.iso" "$s\x_$k.bin" 2>&1 }
    }
    if ([IO.File]::Exists("$s\ud.iso")) {
        foreach ($k in @('alen38', 'alen40')) { $made += & python -I $Py $k "$s\ud.iso" "$s\x_$k.bin" 2>&1 }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img364: ' + "$m") }
    if (-not [IO.File]::Exists("$s\ud.iso")) { Out ('mkimg330.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    if (-not [IO.File]::Exists("$s\big364.iso")) { Out ('mkimg364.sh: ' + (($mkb | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $udAll = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/a/side.txt' = 'SIDE'; 'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $udNoA = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $bigAll = [ordered]@{}
    $bigHead = [ordered]@{}
    for ($i = 0; $i -lt 40; $i++) {
        $n = '{0:D2}' -f $i
        $bigAll["UDF (TC364)/a_rather_long_file_name_$n.txt"] = "R$n"
        $bigAll["UDF (TC364)/sub/a_rather_long_file_name_$n.txt"] = "S$n"
        # the root's identifiers: the parent's 40 bytes, then 72 bytes each - those starting before 2048
        if (40 + 72 * $i -lt 2048) { $bigHead["UDF (TC364)/a_rather_long_file_name_$n.txt"] = "R$n" }
    }

    List-Row 'L-ROOTFRAG' "$s\x_rootfrag.bin" 'rootfrag.iso'
    List-Row 'L-SUBFRAG' "$s\x_subfrag.bin" 'subfrag.iso'
    List-Row 'L-ROOTCONT' "$s\x_rootcont.bin" 'rootcont.iso'
    List-Row 'L-BIG' "$s\big364.iso" 'big364.iso'
    $script:Part = 'UDF (TC364)'
    Unpack-Row 'R-ROOTSPLIT' "$s\x_rootsplit.bin" 'rootsplit.iso' $bigAll
    Unpack-Row 'R-ROOTFRAG' "$s\x_rootfrag.bin" 'rootfrag.iso' $bigAll
    Unpack-Row 'R-SUBSPLIT' "$s\x_subsplit.bin" 'subsplit.iso' $bigAll
    Unpack-Row 'R-SUBFRAG' "$s\x_subfrag.bin" 'subfrag.iso' $bigAll
    Unpack-Row 'R-ROOTCONT' "$s\x_rootcont.bin" 'rootcont.iso' $bigHead -Kept
    Unpack-Row 'R-ROOTUNREC' "$s\x_rootunrec.bin" 'rootunrec.iso' $bigHead -Kept
    Unpack-Row 'C-BIG' "$s\big364.iso" 'big364.iso' $bigAll
    $script:Part = ''
    Unpack-Row 'R-ALEN38' "$s\x_alen38.bin" 'alen38.iso' $udNoA -Kept
    Unpack-Row 'R-ALEN40' "$s\x_alen40.bin" 'alen40.iso' $udNoA -Kept
    Unpack-Row 'C-UD' "$s\ud.iso" 'ud.iso' $udAll
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
