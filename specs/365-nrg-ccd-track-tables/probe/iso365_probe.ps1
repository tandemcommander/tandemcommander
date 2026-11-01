<#
.SYNOPSIS
    Feature 365: the ISO plug-in reads the track tables of NRG (Nero) images - ETNF entries of modes 0x05 /
    0x06 (raw sectors of 2352 bytes) and ETN2 entries (every entry, its mode, its first sector, its end =
    start + length) - and of CloneCD images whose [TRACK n] INDEX 1 is counted from the start of the disc,
    so a whole unpack extracts both sessions and "Delete archive after unpacking" deletes such an image
    only once both were extracted.

.DESCRIPTION
    Seeds by mkimg365.sh in WSL Ubuntu (genisoimage): s1.iso (a.txt "A1") and s2.iso (b.txt "B2",
    addressed from session 1's sectors + 11400 - the lead-out / lead-in / pregap no image file holds).
    img365.py writes the images (see its docstring).
    Unpack rows (as feature 352's): the left panel shows <row>\src, Home, End focuses the image, Alt+F9
    (851), the target field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      C-ETNF00, C-ETN2ONE, C-CCDREL
                    (controls) PASS = Session 01/a.txt and Session 02/b.txt (C-ETN2ONE: a.txt) extracted,
                    no window, the image deleted
      R-ETNF05, R-ETNF06
                    ETNF, track 2 raw Mode 1 (0x05) / raw Mode 2 Form 1 (0x06). PASS = both sessions
                    extracted, no window, the image deleted. Before 365: read with 2336 / 2048-byte
                    sectors, no file system found, session 2 lost (the image kept by 335's mark)
      R-ETN200, R-ETN203, R-ETN206
                    ETN2, a chunk a session, track 2 Mode 1 / 2048 (0x00), Mode 2 / 2336 (0x03), raw
                    Mode 2 (0x06). PASS as R-ETNF05. Before 365: track 2's end was its length, its mode
                    Mode 1 / 2048 and its first sector 0 whatever the entry said
      R-ETN2ONE150, R-ETN2150
                    (review 1) as C-ETN2ONE / R-ETN200 with first-sector fields 150 higher. PASS as
                    C-ETN2ONE / R-ETN200. Before review 1's fix R-ETN2ONE150 opened nothing (main: passed)
      R-CCDABS      CloneCD, track 2's INDEX 1 = its PLBA (from the start of the disc). PASS as R-ETNF05.
                    Before 365: one INDEX-1 split for two [Session n] sections - the listing marked
                    (352), the last track's sector count underflowed
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\352-uniso-ccd-session-bounds\probe\iso352_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$MkImg,
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
if (-not $MkImg) { $MkImg = Join-Path $Here 'mkimg365.sh' }
if (-not $Py) { $Py = Join-Path $Here 'img365.py' }
. $Lib
$Root = $TempRoot + '\tc365'
$StartDir = $Root + '\start'

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
#   $Want   files that must be extracted exactly ($null = not checked, only recorded)
#   $Kept   the image must be kept (else deleted)
#   no window may show
function Unpack-Row([string]$Case, [string]$Img0, $Want, [switch]$Kept) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Img0); [IO.File]::Copy($Img0, $LP + $img)
    $ccd0 = [IO.Path]::ChangeExtension($Img0, '.ccd'); if ([IO.File]::Exists($ccd0)) { [IO.File]::Copy($ccd0, $LP + [IO.Path]::ChangeExtension($img, '.ccd')) }
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
        $winOk = ($all.Count -eq 0)
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); no window: {4}; fatal: {5}; windows: {6}' -f $c[1], $c[0], $isKept, [bool]$Kept, $winOk, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc365_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso365_probe (feature 365) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $kinds = @('etnf_00', 'etnf_05', 'etnf_06', 'etn2_one', 'etn2_00', 'etn2_03', 'etn2_06', 'etn2_one150', 'etn2_150', 'ccd_rel', 'ccd_abs')
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath $MkImg) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\s1.iso") -and [IO.File]::Exists("$s\s2.iso")) {
        foreach ($k in $kinds) {
            $ext = if ($k.StartsWith('ccd')) { 'img' } else { 'nrg' }
            $made += & python -I $Py $k "$s\s1.iso" "$s\s2.iso" "$s\s2.lba" "$s\$k.$ext" 2>&1
        }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img365: ' + "$m") }
    if (-not [IO.File]::Exists("$s\s1.iso")) { Out ('mkimg365.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $both = [ordered]@{ 'Session 01/a.txt' = 'A1'; 'Session 02/b.txt' = 'B2' }
    $a = [ordered]@{ 'a.txt' = 'A1' }
    Unpack-Row 'C-ETNF00' "$s\etnf_00.nrg" $both
    Unpack-Row 'R-ETNF05' "$s\etnf_05.nrg" $both
    Unpack-Row 'R-ETNF06' "$s\etnf_06.nrg" $both
    Unpack-Row 'C-ETN2ONE' "$s\etn2_one.nrg" $a
    Unpack-Row 'R-ETN200' "$s\etn2_00.nrg" $both
    Unpack-Row 'R-ETN203' "$s\etn2_03.nrg" $both
    Unpack-Row 'R-ETN206' "$s\etn2_06.nrg" $both
    Unpack-Row 'R-ETN2ONE150' "$s\etn2_one150.nrg" $a
    Unpack-Row 'R-ETN2150' "$s\etn2_150.nrg" $both
    Unpack-Row 'C-CCDREL' "$s\ccd_rel.img" $both
    Unpack-Row 'R-CCDABS' "$s\ccd_abs.img" $both
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
