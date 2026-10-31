<#
.SYNOPSIS
    Feature 358: a UDF image of a sequential medium (a virtual allocation table, VAT - mkudffs
    --media-type=cdr) whose file holds more than the volume no longer crashes Tandem Commander when the ISO
    plug-in lists it - the VAT is not found, the image does not open ("Missing virtual allocation table."),
    nothing is extracted and "Delete archive after unpacking" keeps it; VAT images that end with their VAT
    list (and unpack) as before.

.DESCRIPTION
    Images: mkudffs images by specs\356-uniso-udf-rest\probe\mkudf356.sh in WSL Ubuntu (udftools fetched
    once, as 356 did); vatimg.py (this folder) appends data to mk_cdr.img as review 2 of feature 356 did.
    Unpack rows (as feature 356's): the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851),
    the target field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      R-VCDR100    mk_cdr + 100 sectors of 0x5A: PASS = nothing extracted, KEPT, only "Missing virtual
                   allocation table." boxes. Before: access violation reading address 0 (bug report)
      R-VCLAIM16   mk_cdr + 0x5A up to 4016 sectors (16 past the claimed partition): as R-VCDR100
      R-VCLAIM100Z mk_cdr + 0x5A up to the claimed 4000 sectors + 100 zero sectors: as R-VCDR100
      C-VCLAIM     mk_cdr + 0x5A up to exactly the claimed 4000 sectors: PASS = nothing extracted, KEPT, only
                   "Error reading virtual allocation table" boxes (unchanged - measured before the fix)
      C-MKCDR, C-MKCDRC (closed), C-MKDVDR, C-MKBDR  plain mkudffs VAT images (the file ends with the VAT):
                   PASS = nothing extracted (the volumes are empty), no window, deleted - as 356's rows
      C-MKHD       a plain mkudffs hd image (no VAT): as above
    Review 1 rows (mkvat358.sh, vatimg.py hdlong / hdeq):
      C-MK150, C-MK150C, C-MKNOEFE  plain mkudffs cdr images with a UDF 1.50 VAT (open, closed) and a VAT 2.00
                   in plain file entries: as C-MKCDR
      R-V150D100, R-VNOEFED100  those (open) + 100 sectors of 0x5A: as R-VCDR100 (main: the 1.50 one crashed)
      R-VHDLONG    mk_cdr whose VAT header is 8 bytes longer than the VAT file: as R-VCDR100 (main read a sector
                   through the wrapped count)
      R-VHDEQ      mk_cdr whose VAT header fills the VAT file (0 entries): KEPT, nothing extracted, only boxes
                   naming sector #FF567539 (virtual block 0 not translated - the reader's invalid sector); main
                   read entry 0, one past the table (#FDFDFDFD, the debug heap's guard bytes)
    Listing rows: the left panel shows <row>\src, Home, End, Enter (posted) on the image; the program must
    stay alive with no bug report.
      L-VCDR100    the R-VCDR100 image: PASS = alive, only "Missing virtual allocation table." boxes
      L-MKCDR      mk_cdr.img: PASS = alive, no window (the archive opens)
      L-VHDLONG    the R-VHDLONG image: as L-VCDR100
      L-MK150      mk_cdr150.img: as L-MKCDR
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without WSL Ubuntu the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\356-uniso-udf-rest\probe\iso356_probe.ps1 and review 2's
    rev356b_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$MkMk,
    [string]$MkVat,
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
if (-not $MkVat) { $MkVat = Join-Path $Here 'mkvat358.sh' }
if (-not $Py) { $Py = Join-Path $Here 'vatimg.py' }
. $Lib
$Root = $TempRoot + '\tc358'
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

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; nothing may be extracted
function Unpack-Row([string]$Case, [string]$Img0, [string]$Name, [switch]$Kept, [string]$Msg = 'none') {
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
        $ok = ($files.Count -eq 0) -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
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

$backup = Join-Path $env:TEMP 'tc358_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso358_probe (feature 358) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- bash (WslPath $MkMk) (WslPath $s) 2>&1
    $mk2 = & wsl -d Ubuntu -- bash (WslPath $MkVat) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\mk_cdr.img")) {
        foreach ($k in @('data100', 'toclaim', 'claim16', 'claim100z', 'hdlong', 'hdeq')) { $made += & python -I $Py $k "$s\mk_cdr.img" "$s\v_$k.bin" 2>&1 }
    }
    foreach ($m in @('cdr150', 'cdrnoefe')) {
        if ([IO.File]::Exists("$s\mk_$m.img")) { $made += & python -I $Py data100 "$s\mk_$m.img" "$s\v_${m}data100.bin" 2>&1 }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('vatimg: ' + "$m") }
    if (-not [IO.File]::Exists("$s\mk_cdr.img")) { Out ('mkudf356.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    if (-not [IO.File]::Exists("$s\mk_cdr150.img")) { Out ('mkvat358.sh: ' + (($mk2 | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    Unpack-Row 'R-VCDR100' "$s\v_data100.bin" 'vcdr100.iso' -Kept -Msg $NoVat
    Unpack-Row 'R-VCLAIM16' "$s\v_claim16.bin" 'vclaim16.iso' -Kept -Msg $NoVat
    Unpack-Row 'R-VCLAIM100Z' "$s\v_claim100z.bin" 'vclaim100z.iso' -Kept -Msg $NoVat
    Unpack-Row 'C-VCLAIM' "$s\v_toclaim.bin" 'vclaim.iso' -Kept -Msg $VatRead
    Unpack-Row 'C-MKCDR' "$s\mk_cdr.img" 'mk_cdr.iso'
    Unpack-Row 'C-MKCDRC' "$s\mk_cdrclosed.img" 'mk_cdrc.iso'
    Unpack-Row 'C-MKDVDR' "$s\mk_dvdr.img" 'mk_dvdr.iso'
    Unpack-Row 'C-MKBDR' "$s\mk_bdr.img" 'mk_bdr.iso'
    Unpack-Row 'C-MKHD' "$s\mk_hd.img" 'mk_hd.iso'
    Unpack-Row 'C-MK150' "$s\mk_cdr150.img" 'mk_cdr150.iso'
    Unpack-Row 'C-MK150C' "$s\mk_cdr150c.img" 'mk_cdr150c.iso'
    Unpack-Row 'C-MKNOEFE' "$s\mk_cdrnoefe.img" 'mk_cdrnoefe.iso'
    Unpack-Row 'R-V150D100' "$s\v_cdr150data100.bin" 'v150d100.iso' -Kept -Msg $NoVat
    Unpack-Row 'R-VNOEFED100' "$s\v_cdrnoefedata100.bin" 'vnoefed100.iso' -Kept -Msg $NoVat
    Unpack-Row 'R-VHDLONG' "$s\v_hdlong.bin" 'vhdlong.iso' -Kept -Msg $NoVat
    Unpack-Row 'R-VHDEQ' "$s\v_hdeq.bin" 'vhdeq.iso' -Kept -Msg '#FF567539'
    List-Row 'L-VCDR100' "$s\v_data100.bin" 'lvcdr100.iso' -Msg $NoVat
    List-Row 'L-MKCDR' "$s\mk_cdr.img" 'lmk_cdr.iso'
    List-Row 'L-VHDLONG' "$s\v_hdlong.bin" 'lvhdlong.iso' -Msg $NoVat
    List-Row 'L-MK150' "$s\mk_cdr150.img" 'lmk_cdr150.iso'
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
