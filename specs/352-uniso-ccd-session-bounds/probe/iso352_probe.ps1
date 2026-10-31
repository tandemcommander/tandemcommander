<#
.SYNOPSIS
    Feature 352: a CloneCD (.img + .ccd) image whose .ccd names a session the reader has no arrays for,
    whose [Session n] sections and track splits disagree, or one of whose rows does not parse, no longer
    makes the ISO plug-in write or read outside its arrays - and a whole unpack with "Delete archive
    after unpacking" keeps such an image.

.DESCRIPTION
    Seeds by feature 334's mkimg334.sh in WSL Ubuntu (genisoimage): s1.iso (a.txt "A1") and s2.iso (b.txt
    "B2", addressed from the sector after s1). img352.py writes the images (see its docstring).
    Unpack rows (as feature 351's): the left panel shows <row>\src, Home, End focuses the image, Alt+F9
    (851), the target field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      C-M1, C-M1M1  (controls) PASS = a.txt (and Session 01/a.txt, Session 02/b.txt) extracted, no window,
                    the image deleted
      R-S0, R-S200, R-S257, R-MODEX, R-DUP
                    the .ccd is damaged (an entry names session 0 / 200 / 257 of a one-session .ccd, a
                    MODE that does not parse, an entry without PLBA with Session twice). PASS = the box
                    "Bad format of .CCD file" shown, the image KEPT, no fatal window, no bug report.
                    Before 352: R-S0 heap corruption (Debug CRT), R-S200 silent unpack, the image
                    deleted; R-S257 taken as session 1 (deleted); R-MODEX / R-DUP stack values
      R-ABS         two [Session n] sections, one track split (the second track's INDEX 1 absolute).
                    PASS = no bad-format box, the image KEPT, no fatal window. Before 352: the reader read
                    a session count past its list (Debug: the array's index check). (Review 1: the image
                    is kept by 334's mark of the unlisted first track as well - this row proves the
                    bounds, not the layout mark; R-TWOSEC does)
      R-SPLIT       one [Session n] section, two track splits. PASS as R-ABS (kept also by 338's read
                    error). Before 352: extents[1] read past a one-element array (silent)
      R-TWOSEC      two [Session n] sections, one track (one split) holding s1 whole. PASS = a.txt
                    extracted, no window, the image KEPT - only 352's layout mark (sections != splits)
                    keeps it (review 1's SHOULD)
      C-NOCCD       (control, FR-006) the image without a .ccd: PASS = only boxes "Missing .CCD file",
                    a.txt extracted, the image deleted (not marked, as before)
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\351-uniso-track-defaults\probe\iso351_probe.ps1.
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
if (-not $MkImg) { $MkImg = Join-Path $Specs '334-uniso-session-missing\probe\mkimg334.sh' }
if (-not $Py) { $Py = Join-Path $Here 'img352.py' }
. $Lib
$Root = $TempRoot + '\tc352'
$StartDir = $Root + '\start'
$BadCcd = 'Bad format of .CCD file'
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
#   $Want   files that must be extracted exactly ($null = not checked, only recorded)
#   $Kept   the image must be kept (else deleted)
#   $Msg    'none' = no window may show; 'bad' = the bad-format box must show; 'nobad' = it must not;
#           'missing' = every window is the missing-.ccd box (it shows once per open of the image)
function Unpack-Row([string]$Case, [string]$Img0, $Want, [switch]$Kept, [string]$Msg = 'none') {
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
        $hasBad = ($msgs.Contains($BadCcd))
        switch ($Msg) {
            'none' { $winOk = ($all.Count -eq 0) }
            'bad' { $winOk = $hasBad }
            'missing' { $winOk = ($all.Count -gt 0) -and (@($all | Where-Object { -not $_.Contains($MissingCcd) }).Count -eq 0) }
            'nobad' { $winOk = -not $hasBad }
        }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows ok ({4}): {5}; fatal: {6}; windows: {7}' -f $c[1], $c[0], $isKept, [bool]$Kept, $Msg, $winOk, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc352_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso352_probe (feature 352) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $kinds = @('ccd_m1', 'ccd_m1m1', 'ccd_s0', 'ccd_s200', 'ccd_s257', 'ccd_abs', 'ccd_split', 'ccd_modex', 'ccd_dup', 'ccd_twosec')
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath $MkImg) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\s1.iso") -and [IO.File]::Exists("$s\s2.iso")) {
        foreach ($k in $kinds) { $made += & python -I $Py $k "$s\s1.iso" "$s\s2.iso" "$s\$k.img" 2>&1 }
        $made += & python -I $Py noccd "$s\s1.iso" "$s\s2.iso" "$s\noccd.img" 2>&1
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img352: ' + "$m") }
    if (-not [IO.File]::Exists("$s\s1.iso")) { Out ('mkimg334.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $both = [ordered]@{ 'Session 01/a.txt' = 'A1'; 'Session 02/b.txt' = 'B2' }
    $a = [ordered]@{ 'a.txt' = 'A1' }
    Unpack-Row 'C-M1' "$s\ccd_m1.img" $a
    Unpack-Row 'C-M1M1' "$s\ccd_m1m1.img" $both
    Unpack-Row 'R-S0' "$s\ccd_s0.img" $null -Kept -Msg 'bad'
    Unpack-Row 'R-S200' "$s\ccd_s200.img" $null -Kept -Msg 'bad'
    Unpack-Row 'R-S257' "$s\ccd_s257.img" $null -Kept -Msg 'bad'
    Unpack-Row 'R-ABS' "$s\ccd_abs.img" $null -Kept -Msg 'nobad'
    Unpack-Row 'R-SPLIT' "$s\ccd_split.img" $null -Kept -Msg 'nobad'
    Unpack-Row 'R-MODEX' "$s\ccd_modex.img" $null -Kept -Msg 'bad'
    Unpack-Row 'R-DUP' "$s\ccd_dup.img" $null -Kept -Msg 'bad'
    Unpack-Row 'R-TWOSEC' "$s\ccd_twosec.img" $a -Kept
    Unpack-Row 'C-NOCCD' "$s\noccd.img" $a -Msg 'missing'
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
