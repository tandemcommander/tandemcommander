<#
.SYNOPSIS
    Feature 335: Unpack with "Delete archive after unpacking" keeps an NRG image one of whose data tracks
    shows no file system the ISO plug-in knows, unless the track is a Mode 2 Form 2 stream (a Video CD's
    MPEG track) - before, such a track was taken as raw data that lists nothing, the listing was not
    marked and the image was deleted (the files of that track lost).

.DESCRIPTION
    Seeds by feature 334's mkimg334.sh in WSL Ubuntu (genisoimage): s1.iso (a.txt "A1") and s2.iso (b.txt
    "B2", addressed from the sector after s1). img335.py puts them into NRG images (see its docstring):
      multi_nofs.nrg     two sessions; track 2 Mode 1 with every volume descriptor destroyed
      multi_ok_2336.nrg  two sessions; track 2 Mode 2 / 2336 Form 1, intact
      multi_nofs_f1.nrg  as multi_ok_2336, every volume descriptor destroyed
      multi_form2.nrg    two sessions; track 2 Mode 2 / 2336 Form 2 (an MPEG-like stream)
      single_vcd.nrg     one session: track 1 ISO 9660, track 2 as multi_form2 (a Video CD's layout)
      single_nofs.nrg    one session: track 1 ISO 9660, track 2 as multi_nofs
      single_raw.nrg     one session: track 1 ISO 9660, track 2 Mode 1 zeros (feature 334's S-RAW image)
      (review 1)
      multi_ff_f1.nrg    as multi_nofs_f1, track 2's sector 16 (subheader included) overwritten with 0xFF
      multi_txt_f1.nrg   the same, overwritten with text
    ccd335.py writes CloneCD images (.img of raw 2352-byte sectors + .ccd), one session of two tracks:
      ccd_vcd.img        track 2 Mode 2 Form 2 (a Video CD's MPEG track)
      ccd_nofs_m1.img    track 2 Mode 1, every volume descriptor destroyed
      ccd_nofs_f1.img    track 2 Mode 2 Form 1, every volume descriptor destroyed
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      M-NOFS     PASS = Session 01/a.txt extracted, no window, the image KEPT - before 335: deleted
      M-OK-2336  (control) PASS = Session 01/a.txt and Session 02/b.txt extracted, no window, the image deleted
      M-NOFS-F1  PASS = Session 01/a.txt extracted, no window, the image KEPT - before 335: deleted
      M-FORM2    (limit) PASS = Session 01/a.txt extracted, no window, the image deleted (a Form 2 stream
                 holds no file system; it is not marked)
      S-VCD      (control) PASS = a.txt extracted, no window, the image deleted (a Video CD's MPEG track)
      S-NOFS     PASS = a.txt extracted, no window, the image KEPT - before 335: deleted
      S-RAW      PASS = a.txt extracted, no window, the image KEPT - feature 334's control S-RAW (a Mode 1
                 track of zeros is not a Video CD's stream); before 335: deleted
      M-FF-F1, M-TXT-F1  PASS = Session 01/a.txt extracted, no window, the image KEPT (review 1: an
                 overwritten sector 16 is not a Form 2 stream)
      C-VCD      (control) PASS = a.txt extracted, no window, the image deleted
      C-NOFS-M1, C-NOFS-F1  PASS = a.txt extracted, no window, the image KEPT - before 335: deleted
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\334-uniso-session-missing\probe\iso334_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$MkImg
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
. $Lib
$Root = $TempRoot + '\tc335'
$StartDir = $Root + '\start'
# the plug-in's own box when a session's track does not open (IDS_ERROR_OPENING_MULTISESSION)
$MultiBox = 'Some error\(s\) occured while reading multisession image'

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
    $low = @($files | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @($Want.Keys | Where-Object { $low -notcontains $_.ToLowerInvariant() })
    $bad = @($Want.Keys | Where-Object { $low -contains $_.ToLowerInvariant() } | Where-Object {
            $k = $_.ToLowerInvariant(); $real = @($files | Where-Object { $_.ToLowerInvariant() -eq $k })[0]
            (Content $Tgt $real) -cne $Want[$_] })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Kept = the listing
# is incomplete (the image kept), else the image deleted; $MultiErr = the plug-in's multi-session box must
# show (and is the only window), else no window at all
function Unpack-Row([string]$Case, [string]$Img0, $Want, [switch]$Kept, [switch]$MultiErr) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Img0); [IO.File]::Copy($Img0, $LP + $img)
    # a CloneCD image: its .ccd goes along (the plug-in reads the track table from it)
    $ccd0 = [IO.Path]::ChangeExtension($Img0, '.ccd'); if ($Img0.EndsWith('.img') -and [IO.File]::Exists($ccd0)) { [IO.File]::Copy($ccd0, $LP + [IO.Path]::ChangeExtension($img, '.ccd')) }
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
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $Want
        $isKept = [IO.File]::Exists($LP + $img)
        $all = @(($msgs -split ' \|\| ') | Where-Object { $_ -ne 'no window' })
        $multi = @($all | Where-Object { $_ -match $MultiBox })
        $other = @($all | Where-Object { $_ -notmatch $MultiBox })
        $winOk = ($other.Count -eq 0) -and (($multi.Count -gt 0) -eq [bool]$MultiErr)
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows as expected: {4} (multi-session box {5}, want {6}); fatal: {7}; windows: {8}' -f $c[1], $c[0], $isKept, [bool]$Kept, $winOk, ($multi.Count -gt 0), [bool]$MultiErr, (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc335_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso335_probe (feature 335) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img335.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath $MkImg) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\s1.iso") -and [IO.File]::Exists("$s\s2.iso")) {
        foreach ($k in @('multi_nofs', 'multi_ok_2336', 'multi_nofs_f1', 'multi_form2', 'single_vcd', 'single_nofs', 'single_raw', 'multi_ff_f1', 'multi_txt_f1')) { $made += & python -I $py $k "$s\s1.iso" "$s\s2.iso" "$s\s2.lba" "$s\$k.nrg" 2>&1 }
        $py2 = Join-Path $Here 'ccd335.py'
        foreach ($k in @('ccd_vcd', 'ccd_nofs_m1', 'ccd_nofs_f1')) { $made += & python -I $py2 $k "$s\s1.iso" "$s\s2.iso" "$s\$k.img" 2>&1 }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img335: ' + "$m") }
    if (-not [IO.File]::Exists("$s\s1.iso")) { Out ('mkimg334.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $both = [ordered]@{ 'Session 01/a.txt' = 'A1'; 'Session 02/b.txt' = 'B2' }
    $first = [ordered]@{ 'Session 01/a.txt' = 'A1' }
    $a = [ordered]@{ 'a.txt' = 'A1' }
    Unpack-Row 'M-NOFS' "$s\multi_nofs.nrg" $first -Kept
    Unpack-Row 'M-OK-2336' "$s\multi_ok_2336.nrg" $both
    Unpack-Row 'M-NOFS-F1' "$s\multi_nofs_f1.nrg" $first -Kept
    Unpack-Row 'M-FORM2' "$s\multi_form2.nrg" $first
    Unpack-Row 'S-VCD' "$s\single_vcd.nrg" $a
    Unpack-Row 'S-NOFS' "$s\single_nofs.nrg" $a -Kept
    Unpack-Row 'S-RAW' "$s\single_raw.nrg" $a -Kept
    Unpack-Row 'M-FF-F1' "$s\multi_ff_f1.nrg" $first -Kept
    Unpack-Row 'M-TXT-F1' "$s\multi_txt_f1.nrg" $first -Kept
    Unpack-Row 'C-VCD' "$s\ccd_vcd.img" $a
    Unpack-Row 'C-NOFS-M1' "$s\ccd_nofs_m1.img" $a -Kept
    Unpack-Row 'C-NOFS-F1' "$s\ccd_nofs_f1.img" $a -Kept
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
