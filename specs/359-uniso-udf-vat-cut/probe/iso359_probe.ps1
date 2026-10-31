<#
.SYNOPSIS
    Feature 359: a UDF image of a sequential medium (a virtual allocation table, VAT - mkudffs
    --media-type=cdr) cut short no longer hangs Tandem Commander while the ISO plug-in lists it - the VAT
    search falls back to the file's last sectors at most once and never with a wrapped sector number.

.DESCRIPTION
    Images: mk_cdr.img by specs\356-uniso-udf-rest\probe\mkudf356.sh in WSL Ubuntu (300 sectors, partition
    start 257, the VAT in the last sector); rawimg359.py (this folder) writes it cut short, as 2048-byte
    sectors or as a raw Mode 1 dump (2352-byte sectors - the plug-in counts the file's sectors in 2048 bytes,
    so it sees more sectors than the file holds).
      L-RAWCUT   raw Mode 1, 260 sectors, the partition start set to 288: the fallback window is partition
                 sectors 3-9, past the file - before: the read at sector 3 failed, "3 - 7" wrapped and the
                 search set the same window again for ever (the main window stopped answering). PASS = alive,
                 only "Error reading virtual allocation table" boxes
      R-RAWCUT   the same image, Unpack with "Delete archive after unpacking": PASS = nothing extracted, KEPT,
                 only "Error reading virtual allocation table" boxes
      L-CUT3     the item's row: 2048-byte sectors cut to the partition start + 3 (260 sectors): PASS = alive,
                 only "Missing virtual allocation table." boxes (the three sectors are searched, no VAT)
      R-CUT3     the same, Unpack: PASS = nothing extracted, KEPT, only the missing-VAT boxes
      L-CUT0     2048-byte sectors cut at the partition start (257 sectors - no partition sector in the file):
                 PASS = alive, only "Error reading virtual allocation table" boxes (before: the wrapped
                 window ended the search unread - "Missing virtual allocation table.")
      L-RAWFULL  the whole volume as a raw Mode 1 dump: only "Error reading virtual allocation table" boxes -
                 unchanged (the sector count in 2048 bytes, a separate Inbox item)
      L-MKCDR    mk_cdr.img: PASS = alive, no window (the archive opens)
    Listing rows: the left panel shows <row>\src, Home, End, Enter (posted) on the image. Unpack rows: Alt+F9
    (851), the target field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK. Every
    row also fails on a program exit, a bug report, a fatal window, or a main window that does not answer
    within 30 s (End-Row). Without WSL Ubuntu the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\358-uniso-udf-vat-missing\probe\iso358_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
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
if (-not $MkMk) { $MkMk = Join-Path $Specs '356-uniso-udf-rest\probe\mkudf356.sh' }
if (-not $Py) { $Py = Join-Path $Here 'rawimg359.py' }
. $Lib
$Root = $TempRoot + '\tc359'
$StartDir = $Root + '\start'
$NoVat = 'Missing virtual allocation table.'
$VatRead = 'Error reading virtual allocation table'

function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }
function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}
# $Msg: 'none' = no window at all; otherwise at least one window and each holds the text $Msg
function Windows-Ok($r, [string]$Msg) {
    $all = @(((Msgs $r) -split ' \|\| ') | Where-Object { $_ -ne 'no window' })
    if ($Msg -eq 'none') { return ($all.Count -eq 0) }
    return ($all.Count -gt 0) -and (@($all | Where-Object { -not $_.Contains($Msg) }).Count -eq 0)
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; exactly $NFiles files must be
# extracted (0: nothing - the empty mkudffs volumes, or the volume does not open)
function Unpack-Row([string]$Case, [string]$Img0, [string]$Name, [switch]$Kept, [string]$Msg = 'none', [int]$NFiles = 0) {
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
        $files = @(Tgt-Files $tgt)
        $isKept = [IO.File]::Exists($LP + $img)
        $winOk = Windows-Ok $r $Msg
        $ok = ($files.Count -eq $NFiles) -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('files {0}: {1}; image kept: {2} (want {3}); windows ok ({4}): {5}; fatal: {6}; windows: {7}' -f $files.Count, ($files -join ', '), $isKept, [bool]$Kept, $Msg, $winOk, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# Enter on the image (posted, so a box inside the listing does not block the probe)
function List-Row([string]$Case, [string]$Img0, [string]$Name, [string]$Msg = 'none') {
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
        $winOk = Windows-Ok $r $Msg
        $ok = $alive -and (-not $r.Died) -and (-not $fatal) -and $winOk
        Row $Case 'RUN' (V $ok) ('alive: {0}; windows ok ({1}): {2}; fatal: {3}; windows: {4}' -f $alive, $Msg, $winOk, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc359_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso359_probe (feature 359) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- bash (WslPath $MkMk) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\mk_cdr.img")) {
        $made += & python -I $Py "$s\mk_cdr.img" "$s\rawcut.bin" 260 288 2>&1
        $made += & python -I $Py "$s\mk_cdr.img" "$s\cut3.img" 260 --cooked 2>&1
        $made += & python -I $Py "$s\mk_cdr.img" "$s\cut0.img" 257 --cooked 2>&1
        $made += & python -I $Py "$s\mk_cdr.img" "$s\rawfull.bin" 300 2>&1
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('rawimg359: ' + "$m") }
    if (-not [IO.File]::Exists("$s\mk_cdr.img")) { Out ('mkudf356.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    List-Row 'L-RAWCUT' "$s\rawcut.bin" 'lrawcut.iso' -Msg $VatRead
    Unpack-Row 'R-RAWCUT' "$s\rawcut.bin" 'rrawcut.iso' -Kept -Msg $VatRead
    List-Row 'L-CUT3' "$s\cut3.img" 'lcut3.iso' -Msg $NoVat
    Unpack-Row 'R-CUT3' "$s\cut3.img" 'rcut3.iso' -Kept -Msg $NoVat
    List-Row 'L-CUT0' "$s\cut0.img" 'lcut0.iso' -Msg $VatRead
    List-Row 'L-RAWFULL' "$s\rawfull.bin" 'lrawfull.iso' -Msg $VatRead
    List-Row 'L-MKCDR' "$s\mk_cdr.img" 'lmk_cdr.iso'
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
