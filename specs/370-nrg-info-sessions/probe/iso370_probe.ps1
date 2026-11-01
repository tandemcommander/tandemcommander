<#
.SYNOPSIS
    Feature 370: the ISO plug-in's image information (F3 on a disc image: CISOImage::DumpInfo) of an NRG
    image whose SINF session counts do not cover its track table - before, the dump started the next
    session whenever the track index reached the running sum of the counts and read Session[] past its end
    (Debug: the array's range check; Release: an arbitrary count), and a count above 2^31 (an int < 0)
    moved the sum backwards so later sessions were never printed.

.DESCRIPTION
    Seeds by feature 334's mkimg334.sh in WSL Ubuntu (genisoimage): s1.iso (a.txt) and s2.iso (b.txt,
    addressed from the sector after s1). img370.py puts them into NRG images of two Mode 1 tracks with
    these SINF counts; img334.py makes multi_extra (counts 1, 1 and a third, audio track):
      fit 1,1 (control) | zero 0,2 (control) | over 1,2 | short 1 | none (no SINF) | neg 0xFFFFFFFF,2 |
      negend 1,0xFFFFFFFF | extra3 1,1 + three tracks
    Each row: the left panel shows <row>\src, Home, End focuses the image, View (742, F3). The dump the
    viewer shows is read from the disk cache (iso_dump.txt under %TEMP%, written in this row) and reduced
    to a skeleton: N<sessions>, S<session>, n<tracks of the session>, T<track>, U = the line "Tracks not
    in any session". PASS = the skeleton is the expected one, no fatal window, the program ends cleanly.
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer (End-Row). Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\340-nrg-session-count\probe\iso340_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$MkImg,
    [string]$Img334
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Lib) { $Lib = Join-Path $Here '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if (-not $MkImg) { $MkImg = Join-Path $Here '..\..\334-uniso-session-missing\probe\mkimg334.sh' }
if (-not $Img334) { $Img334 = Join-Path $Here '..\..\334-uniso-session-missing\probe\img334.py' }
. $Lib
$Root = $TempRoot + '\tc370'
$StartDir = $Root + '\start'

function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }

# the iso_dump.txt files under the temporary folders written since $Since (the disk cache moves the
# plug-in's dump there under that name while the viewer shows it)
function Find-Dumps([datetime]$Since) {
    $roots = @($TempRoot)
    $u = [Environment]::GetEnvironmentVariable('TEMP', 'User')
    if ($u) { $u = [Environment]::ExpandEnvironmentVariables($u).TrimEnd('\'); if ($roots -notcontains $u) { $roots += $u } }
    $found = @()
    foreach ($r in $roots) {
        if (-not [IO.Directory]::Exists($r)) { continue }
        foreach ($d in @([IO.Directory]::GetDirectories($r))) {
            if ($d.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) { continue }
            $f = Join-Path $d 'iso_dump.txt'
            try { if ([IO.File]::Exists($f) -and [IO.File]::GetLastWriteTime($f) -ge $Since) { $found += $f } } catch { }
        }
    }
    return $found
}

# the dump reduced to its sessions, tracks and the line for tracks no session covers
function Skeleton([string]$Text) {
    $out = @()
    foreach ($l in ($Text -split "`r?`n")) {
        if ($l -match '^Number of sessions: (-?\d+)') { $out += ('N' + $Matches[1]) }
        elseif ($l -match '^Session (-?\d+)\s*$') { $out += ('S' + $Matches[1]) }
        elseif ($l -match '^\s+Number of tracks: (-?\d+)') { $out += ('n' + $Matches[1]) }
        elseif ($l -match '^\s+Track: (-?\d+),') { $out += ('T' + $Matches[1]) }
        elseif ($l -match '^Tracks not in any session\s*$') { $out += 'U' }
    }
    return ($out -join ' ')
}

function View-Row([string]$Case, [string]$Img0, [string]$Want) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; NewDir ($d + '\src')
    $img = $d + '\src\' + [IO.Path]::GetFileName($Img0); [IO.File]::Copy($Img0, $LP + $img)
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $img) }
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $since = (Get-Date).AddSeconds(-2)
        $w = Open-ByCmd $id 742 15
        Start-Sleep -Milliseconds 1500
        $fatal = Fatal-Win $id
        $title = '<no window>'; if ($w -ne [IntPtr]::Zero) { $title = [Drv098f]::Txt($w) }
        $dumps = @(Find-Dumps $since)
        $text = $null
        if ($dumps.Count -ge 1) { try { $text = [IO.File]::ReadAllText($dumps[-1]) } catch { $text = $null } }
        $sk = '<no dump>'; if ($null -ne $text) { $sk = Skeleton $text }
        if ($w -ne [IntPtr]::Zero -and -not $fatal -and [Drv098f]::IsWindow($w)) { Close-Win $w; Start-Sleep -Milliseconds 500 }
        if (-not $fatal) { $fatal = Fatal-Win $id }
        End-Row $Case $id $fatal $before; $id = 0
        $ok = (-not $fatal) -and ($sk -ceq $Want)
        Row $Case 'RUN' (V $ok) ('skeleton [{0}] (want [{1}]); dumps found {2}; viewer: {3}; fatal: {4}' -f $sk, $Want, $dumps.Count, (Tail $title 80), (Tail ([string]$fatal) 300))
        if ($null -ne $text) { foreach ($l in ($text -split "`r?`n" | Select-Object -First 40)) { Out ('    | ' + (Esc $l)) } }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc370_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso370_probe (feature 370) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img370.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath $MkImg) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\s1.iso") -and [IO.File]::Exists("$s\s2.iso")) {
        foreach ($k in @('fit', 'zero', 'over', 'short', 'none', 'neg', 'negend')) { $made += & python -I $py $k "$s\s1.iso" "$s\s2.iso" "$s\s2.lba" "$s\$k.nrg" 2>&1 }
        $made += & python -I $Img334 multi_extra "$s\s1.iso" "$s\s2.iso" "$s\s2.lba" "$s\extra3.nrg" 2>&1
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img: ' + "$m") }
    if (-not [IO.File]::Exists("$s\s1.iso")) { Out ('mkimg334.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    View-Row 'F-FIT' "$s\fit.nrg" 'N2 S1 n1 T1 S2 n1 T2'
    View-Row 'F-ZERO' "$s\zero.nrg" 'N2 S1 n0 S2 n2 T1 T2'
    View-Row 'S-OVER' "$s\over.nrg" 'N2 S1 n1 T1 S2 n1 T2'
    View-Row 'S-SHORT' "$s\short.nrg" 'N1 S1 n1 T1 U T2'
    View-Row 'S-NONE' "$s\none.nrg" 'N0 U T1 T2'
    View-Row 'S-NEG' "$s\neg.nrg" 'N2 S1 n2 T1 T2 S2 n0'
    View-Row 'S-NEGEND' "$s\negend.nrg" 'N2 S1 n1 T1 S2 n1 T2'
    View-Row 'S-EXTRA3' "$s\extra3.nrg" 'N2 S1 n1 T1 S2 n1 T2 U T3'
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
