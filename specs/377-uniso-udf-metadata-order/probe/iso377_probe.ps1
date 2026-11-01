<#
.SYNOPSIS
    Feature 377: a UDF 2.50 disc image written by Windows' IMAPI2FS (its logical volume descriptor precedes its
    partition descriptor; a metadata partition) lists and unpacks in the ISO plug-in like the UDF 2.01 image of
    the same files; images whose partition descriptor comes first, and a metadata file that cannot be read,
    behave as before.

.DESCRIPTION
    Seeds by Windows' IMAPI2FS (specs\356-uniso-udf-rest\probe\imapiudf356.ps1, UDF only): u250.iso (UDF 2.50,
    a.txt "A1"), u250sub.iso (UDF 2.50, a.txt "A1", sub\b.txt "B2"), u201sub.iso (UDF 2.01, the same files),
    u102.iso (UDF 1.02, a.txt "A1"); img377.py makes swap.bin (u250sub with the LVD and the PD exchanged - PD
    first) and far.bin (u250 with the metadata file location past the image).
    Unpack rows (as feature 356's): the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851),
    the target field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      C-U250      u250: PASS = a.txt "A1", no window, deleted. Before: nothing, two read-error boxes, kept
      C-U250SUB   u250sub: PASS = a.txt, sub/b.txt, no window, deleted. Before: as C-U250
      C-U250SWAP  swap.bin (PD first): PASS = a.txt, sub/b.txt, no window, deleted - before and after (control:
                  the order of the two descriptors is the cause)
      C-U201SUB   u201sub: PASS = a.txt, sub/b.txt, no window, deleted - before and after
      C-PLAIN     u102: PASS = a.txt, no window, deleted - before and after
      R-U250FAR   far.bin: PASS = nothing extracted, only read-error boxes ("Cannot read sector" /
                  "Error reading directory structure"), KEPT - before and after (FR-004)
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without IMAPI2FS the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\356-uniso-udf-rest\probe\iso356_probe.ps1.
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
if (-not $Py) { $Py = Join-Path $Here 'img377.py' }
. $Lib
$Root = $TempRoot + '\tc377'
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
#   $Msg 'none' = no window at all; 'read' = at least one window, each a sector / directory read error box
function Unpack-Row([string]$Case, [string]$Img0, [string]$Name, $Want, [switch]$Kept, [string]$Msg = 'none') {
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
        $isKept = [IO.File]::Exists($LP + $img)
        $all = @(($msgs -split ' \|\| ') | Where-Object { $_ -ne 'no window' })
        switch ($Msg) {
            'none' { $winOk = ($all.Count -eq 0) }
            'read' { $winOk = ($all.Count -gt 0) -and (@($all | Where-Object { -not $_.Contains('Cannot read sector') -and -not $_.Contains('Error reading directory structure') }).Count -eq 0) }
        }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows ok ({4}): {5}; fatal: {6}; windows: {7}' -f $c[1], $c[0], $isKept, [bool]$Kept, $Msg, $winOk, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc377_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso377_probe (feature 377) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    NewDir "$s\src1"; NewDir "$s\srcs"; NewDir "$s\srcs\sub"
    [IO.File]::WriteAllText("$s\src1\a.txt", 'A1')
    [IO.File]::WriteAllText("$s\srcs\a.txt", 'A1'); [IO.File]::WriteAllText("$s\srcs\sub\b.txt", 'B2')
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mu = @(); $made = @()
    try {
        $mu += & $MkU -SrcDir "$s\src1" -Out "$s\u250.iso" -Revision 0x250 2>&1
        $mu += & $MkU -SrcDir "$s\srcs" -Out "$s\u250sub.iso" -Revision 0x250 2>&1
        $mu += & $MkU -SrcDir "$s\srcs" -Out "$s\u201sub.iso" -Revision 0x201 2>&1
        $mu += & $MkU -SrcDir "$s\src1" -Out "$s\u102.iso" -Revision 0x102 2>&1
    }
    catch { $mu += ('IMAPI2FS: ' + $_.Exception.Message) }
    if ([IO.File]::Exists("$s\u250sub.iso")) { $made += & python -I $Py swap "$s\u250sub.iso" "$s\swap.bin" 2>&1 }
    if ([IO.File]::Exists("$s\u250.iso")) { $made += & python -I $Py metafar "$s\u250.iso" "$s\far.bin" 2>&1 }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $mu) { Out ('imapiudf356: ' + "$m") }
    foreach ($m in $made) { Out ('img377: ' + "$m") }
    Out ''

    $a = [ordered]@{ 'a.txt' = 'A1' }
    $ab = [ordered]@{ 'a.txt' = 'A1'; 'sub/b.txt' = 'B2' }
    $none = [ordered]@{}
    Unpack-Row 'C-U250' "$s\u250.iso" 'u250.iso' $a
    Unpack-Row 'C-U250SUB' "$s\u250sub.iso" 'u250sub.iso' $ab
    Unpack-Row 'C-U250SWAP' "$s\swap.bin" 'swap.iso' $ab
    Unpack-Row 'C-U201SUB' "$s\u201sub.iso" 'u201sub.iso' $ab
    Unpack-Row 'C-PLAIN' "$s\u102.iso" 'u102.iso' $a
    Unpack-Row 'R-U250FAR' "$s\far.bin" 'far.iso' $none -Kept -Msg 'read'
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
