<#
.SYNOPSIS
    Backlog item iso-plug-in-a-crafted-udf-partition-map-count-reads-past-the: a UDF image whose logical volume
    descriptor declares partition maps that do not fit its sector or its map table (a count too large, a map
    length of 0, a table shorter than its maps) does not open in the ISO plug-in - a whole unpack keeps the
    image; well-formed images unpack as before.

.DESCRIPTION
    Seeds by Windows' IMAPI2FS (specs\356-uniso-udf-rest\probe\imapiudf356.ps1): u201.iso (UDF 2.01 only, one
    type 1 map, a.txt "A1"), u250.iso (UDF 2.50 only, a type 1 and a metadata map), b201.iso (ISO 9660 + UDF
    2.01 bridge); img378.py derives the crafted images:
      count.bin  u201, map count 100000 (bytes after the one map are zero: map length 0)
      len0.bin   u201, the map's length byte 0
      table.bin  u201, map table length 4 (the map is 6 bytes)
      run.bin    u201, count 100000, the rest of the sector 0xFF (maps of length 255 walk off the sector)
      many.bin   u201, table 1608 bytes holding 268 maps, count 300
      bcount.bin b201, map count 100000 (the bridge: the ISO 9660 part still lists)
    Unpack rows (as feature 377's): the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851),
    the target field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      C-U201, C-U250           the seeds: PASS = a.txt "A1", no window, deleted (controls, before and after)
      C-B201                   the bridge seed: PASS = "ISO (UDF356)/A.TXT" and "UDF (UDF356)/a.txt" ("A1"), no
                               window, KEPT - before and after (its ISO 9660 volume, 297 sectors, ends before
                               the file's 576: the rest rule of features 330 / 356 marks the listing)
      R-COUNT, R-LEN0, R-TABLE, R-RUN, R-MANY
                               PASS = nothing extracted, at least one window (none fatal), KEPT.
                               Before (HEAD 514396d3): a.txt extracted, no window, deleted
      R-BCOUNT                 PASS = only "ISO (UDF356)/A.TXT" (the UDF part does not open), at least one
                               window, KEPT. Before: both folders, no window
      C-NB201, R-NBCOUNT       (review 1) b201 / bcount.bin without the UDF anchor at 256 and with the ISO 9660
                               volume as long as the file (img378.py noanchor): C-NB201 PASS = both folders, no
                               window, deleted (before and after); R-NBCOUNT PASS = only "ISO (UDF356)/A.TXT", at
                               least one window, KEPT (the refused UDF part marks the listing). Before: both
                               folders, deleted; review 1's build: ISO folder only, DELETED
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without IMAPI2FS the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\377-uniso-udf-metadata-order\probe\iso377_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$MkU,
    [string]$Py
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Specs = Join-Path $PSScriptRoot '..\..'
if (-not [IO.Directory]::Exists((Join-Path $Specs '098-long-path-overruns'))) { $Specs = 'E:\Projects\tandemcommander\specs' }
if (-not $Lib) { $Lib = Join-Path $Specs '098-long-path-overruns\probe\fix_probe_lib.ps1' }
if (-not $MkU) { $MkU = Join-Path $Specs '356-uniso-udf-rest\probe\imapiudf356.ps1' }
if (-not $Py) { $Py = Join-Path $Here 'img378.py' }
. $Lib
$Root = $TempRoot + '\tc378'
$StartDir = $Root + '\start'

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

# the files of $Want (relative path -> content; compared without case) in tgt - exactly these; @(ok, facts)
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    $low = @($files | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @($Want.Keys | Where-Object { $low -notcontains $_.ToLowerInvariant() })
    $bad = @($Want.Keys | Where-Object { $low -contains $_.ToLowerInvariant() } | Where-Object {
            $k = $_.ToLowerInvariant(); $real = @($files | Where-Object { $_.ToLowerInvariant() -eq $k })[0]
            (Content $Tgt $real) -cne $Want[$_] })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking".
#   $Msg 'none' = no window at all; 'any' = at least one window
#   $Alt = a second accepted file set (optional; no row uses it now)
function Unpack-Row([string]$Case, [string]$Img0, [string]$Name, $Want, [switch]$Kept, [string]$Msg = 'none', $Alt = $null) {
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
        $r = Serve $id 90 @(1, 6)
        $msgs = Msgs $r
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $Want
        if (-not $c[0] -and $Alt -ne $null) { $c2 = Check-Files $tgt $Alt; if ($c2[0]) { $c = $c2 } }
        $isKept = [IO.File]::Exists($LP + $img)
        $all = @(($msgs -split ' \|\| ') | Where-Object { $_ -ne 'no window' })
        switch ($Msg) {
            'none' { $winOk = ($all.Count -eq 0) }
            'any' { $winOk = ($all.Count -gt 0) }
        }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows ok ({4}): {5}; fatal: {6}; windows: {7}' -f $c[1], $c[0], $isKept, [bool]$Kept, $Msg, $winOk, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc378_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso378_probe {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    NewDir "$s\src1"
    [IO.File]::WriteAllText("$s\src1\a.txt", 'A1')
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mu = @(); $made = @()
    try {
        $mu += & $MkU -SrcDir "$s\src1" -Out "$s\u201.iso" -Revision 0x201 2>&1
        $mu += & $MkU -SrcDir "$s\src1" -Out "$s\u250.iso" -Revision 0x250 2>&1
        $mu += & $MkU -SrcDir "$s\src1" -Out "$s\b201.iso" -Revision 0x201 -FileSystems 5 2>&1
    }
    catch { $mu += ('IMAPI2FS: ' + $_.Exception.Message) }
    if ([IO.File]::Exists("$s\u201.iso")) {
        foreach ($m in @('count', 'len0', 'table', 'run', 'many')) { $made += & python -I $Py $m "$s\u201.iso" "$s\$m.bin" 2>&1 }
    }
    if ([IO.File]::Exists("$s\b201.iso")) { $made += & python -I $Py count "$s\b201.iso" "$s\bcount.bin" 2>&1 }
    if ([IO.File]::Exists("$s\b201.iso")) { $made += & python -I $Py noanchor "$s\b201.iso" "$s\nb201.bin" 2>&1 }
    if ([IO.File]::Exists("$s\bcount.bin")) { $made += & python -I $Py noanchor "$s\bcount.bin" "$s\nbcount.bin" 2>&1 }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $mu) { Out ('imapiudf356: ' + "$m") }
    foreach ($m in $made) { Out ('img378: ' + "$m") }
    Out ''

    $a = [ordered]@{ 'a.txt' = 'A1' }
    $none = [ordered]@{}
    Unpack-Row 'C-U201' "$s\u201.iso" 'u201.iso' $a
    Unpack-Row 'C-U250' "$s\u250.iso" 'u250.iso' $a
    $both = [ordered]@{ 'ISO (UDF356)/A.TXT' = 'A1'; 'UDF (UDF356)/a.txt' = 'A1' }
    $isoOnly = [ordered]@{ 'ISO (UDF356)/A.TXT' = 'A1' }
    Unpack-Row 'C-B201' "$s\b201.iso" 'b201.iso' $both -Kept
    Unpack-Row 'R-COUNT' "$s\count.bin" 'count.iso' $none -Kept -Msg 'any'
    Unpack-Row 'R-LEN0' "$s\len0.bin" 'len0.iso' $none -Kept -Msg 'any'
    Unpack-Row 'R-TABLE' "$s\table.bin" 'table.iso' $none -Kept -Msg 'any'
    Unpack-Row 'R-RUN' "$s\run.bin" 'run.iso' $none -Kept -Msg 'any'
    Unpack-Row 'R-MANY' "$s\many.bin" 'many.iso' $none -Kept -Msg 'any'
    Unpack-Row 'R-BCOUNT' "$s\bcount.bin" 'bcount.iso' $isoOnly -Kept -Msg 'any'
    Unpack-Row 'C-NB201' "$s\nb201.bin" 'nb201.iso' $both
    Unpack-Row 'R-NBCOUNT' "$s\nbcount.bin" 'nbcount.iso' $isoOnly -Kept -Msg 'any'
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
