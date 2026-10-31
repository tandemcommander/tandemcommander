<#
.SYNOPSIS
    Feature 356: a cooked (2048-byte sector) UDF-only disc image - sector 16 holds the UDF volume recognition
    sequence, no ISO 9660 descriptor - whose file holds more than the UDF volume the ISO plug-in lists (a
    second volume joined past the first) is no longer deleted by a whole unpack with "Delete archive after
    unpacking"; a plain one-volume UDF image, and one whose rest past the volume is only its own anchors and
    zero bytes, unpack and are deleted as before.

.DESCRIPTION
    Seeds by Windows' IMAPI2FS (imapiudf356.ps1, UDF only): u1.iso (UDF 1.02, a.txt "A1"), u2.iso (UDF 1.02,
    b.txt "B2"), u250.iso (UDF 2.50, a.txt "A1"); img356.py composes the rest (see its docstring - "the
    descriptors' end" is the sector after the anchor at 256, both descriptor sequences and the partition);
    mkudf356.sh writes empty mkudffs images in WSL Ubuntu (udftools, as 354 fetched xorriso).
    Unpack rows (as feature 354's): the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851),
    the target field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK. A .iso row
    must show no window at all; an .img row only "Missing .CCD file" boxes (once per open).
      C-PLAIN     u1 (its last sector is its closing anchor): PASS = a.txt, deleted
      N-U250      u250 (UDF 2.50, metadata partition): the plug-in cannot list it (main as well - measured
                  before this feature; Inbox item): PASS = nothing extracted, only the read-error boxes,
                  KEPT - unchanged
      R-TWO       u1 + u2 joined, named .iso: PASS = a.txt, KEPT. Before: deleted, b.txt lost
      R-TWOIMG    the same named .img (no .ccd): PASS = a.txt, KEPT
      R-TWOABS    as R-TWO, u2's last sector an anchor of the later volume addressed as on a disc: PASS =
                  a.txt, KEPT
      C-REST16    u1 cut at the descriptors' end + 16 sectors of 0x5A: PASS = a.txt, deleted
      R-REST17    the same with 17 sectors: PASS = a.txt, KEPT
      C-ZERO100   u1 + 100 zero sectors (its anchor 256 sectors before the end): PASS = a.txt, deleted
      R-ZERO300   u1 + 300 zero sectors (no anchor of u1 at the end or 256 before it; 566 sectors past the
                  descriptors, more than are read): PASS = a.txt, KEPT (a limit: fails closed)
      C-ANCHORREST u1 cut at sector 450 + 1 zero sector (the rest is u1's own anchors and zero bytes): PASS =
                  a.txt, deleted
      C-ZERO512   u1 cut at the descriptors' end + 512 zero sectors: PASS = a.txt, deleted
      R-ZERO513   the same with 513 (more than is read): PASS = a.txt, KEPT
      R-ZEROLATE  u1 cut + 300 zero sectors, the last byte 1: PASS = a.txt, KEPT
      R-SHORT     u1 cut 10 sectors before the descriptors' end (the file ends within the volume): PASS =
                  a.txt, KEPT
      R-NOANCHOR  u1 with its anchor at 256 zeroed (the volume's end cannot be read): PASS = a.txt, KEPT
      C-ANCHOR600 u1 cut + 600 zero sectors + its anchor as the file's last sector: PASS = a.txt, deleted
      C-MKHD, C-MKDVD, C-MKCDRW, C-MKCDR (open, VAT), C-MKCDRC (closed, VAT): empty mkudffs images - PASS =
                  nothing extracted, no window, deleted (the rule leaves plain images as they were)
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without IMAPI2FS (or WSL Ubuntu, for the C-MK rows) the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\354-uniso-cooked-sessions\probe\iso354_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$MkU,
    [string]$MkMk,
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
if (-not $MkU) { $MkU = Join-Path $Here 'imapiudf356.ps1' }
if (-not $MkMk) { $MkMk = Join-Path $Here 'mkudf356.sh' }
if (-not $Py) { $Py = Join-Path $Here 'img356.py' }
. $Lib
$Root = $TempRoot + '\tc356'
$StartDir = $Root + '\start'
$MissingCcd = 'Missing .CCD file'

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

# the files of $Want (relative path -> content; compared without case) in tgt - exactly these; @(ok, facts)
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    if ($null -eq $Want) { return @($true, $f) }
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
#   $Img0   the seed image; $Name the file name it gets in the row's src folder
#   $Want   files that must be extracted exactly
#   $Kept   the image must be kept (else deleted)
#   $Msg    'none' = no window at all; 'missing' = every window is the missing-.ccd box (once per open);
#           'read' = at least one window, each a sector / directory read error box (N-U250)
function Unpack-Row([string]$Case, [string]$Img0, [string]$Name, $Want, [switch]$Kept, [string]$Msg = 'none') {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + $Name; [IO.File]::Copy($Img0, $LP + $img)
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        if ([IO.File]::Exists($LP + [IO.Path]::ChangeExtension($img, '.ccd'))) { throw 'a .ccd lies beside the image' }
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
            'missing' { $winOk = ($all.Count -gt 0) -and (@($all | Where-Object { -not $_.Contains($MissingCcd) }).Count -eq 0) }
        }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows ok ({4}): {5}; fatal: {6}; windows: {7}' -f $c[1], $c[0], $isKept, [bool]$Kept, $Msg, $winOk, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc356_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso356_probe (feature 356) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    NewDir "$s\src1"; NewDir "$s\src2"
    [IO.File]::WriteAllText("$s\src1\a.txt", 'A1'); [IO.File]::WriteAllText("$s\src2\b.txt", 'B2')
    $kinds = @('plain', 'two', 'twoabs', 'rest16', 'rest17', 'zero100', 'zero300', 'anchorrest', 'zero512', 'zero513', 'zerolate', 'short', 'noanchor', 'anchor600')
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mu = @()
    try {
        $mu += & $MkU -SrcDir "$s\src1" -Out "$s\u1.iso" -Revision 0x102 2>&1
        $mu += & $MkU -SrcDir "$s\src2" -Out "$s\u2.iso" -Revision 0x102 2>&1
        $mu += & $MkU -SrcDir "$s\src1" -Out "$s\u250.iso" -Revision 0x250 2>&1
    }
    catch { $mu += ('IMAPI2FS: ' + $_.Exception.Message) }
    $mk = & wsl -d Ubuntu -- bash (WslPath $MkMk) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\u1.iso") -and [IO.File]::Exists("$s\u2.iso")) {
        foreach ($k in $kinds) { $made += & python -I $Py $k "$s\u1.iso" "$s\u2.iso" "$s\$k.bin" 2>&1 }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $mu) { Out ('imapiudf356: ' + "$m") }
    foreach ($m in $made) { Out ('img356: ' + "$m") }
    if (-not [IO.File]::Exists("$s\mk_hd.img")) { Out ('mkudf356.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $a = [ordered]@{ 'a.txt' = 'A1' }
    $none = [ordered]@{}
    Unpack-Row 'C-PLAIN' "$s\plain.bin" 'plain.iso' $a
    Unpack-Row 'N-U250' "$s\u250.iso" 'u250.iso' $none -Kept -Msg 'read'
    Unpack-Row 'R-TWO' "$s\two.bin" 'two.iso' $a -Kept
    Unpack-Row 'R-TWOIMG' "$s\two.bin" 'two.img' $a -Kept -Msg 'missing'
    Unpack-Row 'R-TWOABS' "$s\twoabs.bin" 'twoabs.iso' $a -Kept
    Unpack-Row 'C-REST16' "$s\rest16.bin" 'rest16.iso' $a
    Unpack-Row 'R-REST17' "$s\rest17.bin" 'rest17.iso' $a -Kept
    Unpack-Row 'C-ZERO100' "$s\zero100.bin" 'zero100.iso' $a
    Unpack-Row 'R-ZERO300' "$s\zero300.bin" 'zero300.iso' $a -Kept
    Unpack-Row 'C-ANCHORREST' "$s\anchorrest.bin" 'anchorrest.iso' $a
    Unpack-Row 'C-ZERO512' "$s\zero512.bin" 'zero512.iso' $a
    Unpack-Row 'R-ZERO513' "$s\zero513.bin" 'zero513.iso' $a -Kept
    Unpack-Row 'R-ZEROLATE' "$s\zerolate.bin" 'zerolate.iso' $a -Kept
    Unpack-Row 'R-SHORT' "$s\short.bin" 'short.iso' $a -Kept
    Unpack-Row 'R-NOANCHOR' "$s\noanchor.bin" 'noanchor.iso' $a -Kept
    Unpack-Row 'C-ANCHOR600' "$s\anchor600.bin" 'anchor600.iso' $a
    Unpack-Row 'C-MKHD' "$s\mk_hd.img" 'mk_hd.iso' $none
    Unpack-Row 'C-MKDVD' "$s\mk_dvd.img" 'mk_dvd.iso' $none
    Unpack-Row 'C-MKCDRW' "$s\mk_cdrw.img" 'mk_cdrw.iso' $none
    Unpack-Row 'C-MKCDR' "$s\mk_cdr.img" 'mk_cdr.iso' $none
    Unpack-Row 'C-MKCDRC' "$s\mk_cdrclosed.img" 'mk_cdrc.iso' $none
    Unpack-Row 'C-MKDVDR' "$s\mk_dvdr.img" 'mk_dvdr.iso' $none
    Unpack-Row 'C-MKBDR' "$s\mk_bdr.img" 'mk_bdr.iso' $none
    Unpack-Row 'R-MKHD512' "$s\mk_hd512.img" 'mk_hd512.iso' $none -Kept
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
