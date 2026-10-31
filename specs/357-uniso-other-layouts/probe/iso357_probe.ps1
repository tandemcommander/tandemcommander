<#
.SYNOPSIS
    Feature 357: a disc image the ISO plug-in's plain detection opens through a layout other than "raw with
    the CD sync pattern at sector 0" (355) or "cooked from offset 0" (354) - Easy CD Creator (ECDC), the
    NRG offset, 2336-byte sectors, NCD, PDI, CIF, WinOnCD C2D (cooked and Mode 2), Roxio, CIF 2332 - whose
    file holds more than the volume it lists (a second session past the first) is no longer deleted by a
    whole unpack with "Delete archive after unpacking"; a one-session image of those layouts, and one whose
    rest past the volume holds only zero user data, unpack and are deleted as before.

.DESCRIPTION
    Seeds by feature 334's mkimg334.sh in WSL Ubuntu (genisoimage): s1.iso (a.txt "A1", 176 sectors whose
    primary volume descriptor says 176) and s2.iso (b.txt "B2", addressed from the sector after s1).
    img357.py writes the images per layout (see its docstring; it refuses an image an earlier check of the
    detection would open through another layout). Unpack rows (as features 353 - 355): the left panel shows
    <row>\src, Home, End focuses the image, Alt+F9 (851), the target field (210) set to <row>\tgt, "Delete
    archive after unpacking" (6210) checked, OK. Every row must extract a.txt "A1" exactly and show no
    window at all.
      R-<L>-TWO   layout <L>, s1 + s2 (the defect; the reviewer's X-ECDCTWO of 355 is R-ECDC-TWO): KEPT
      C-<L>-ONE   layout <L>, s1 only: deleted (Roxio: a file this short never opens - C-ROXIO-ZERO150)
      for ECDC (Mode 2 sectors) and NRG (2048-byte sectors past an offset):
      R-<L>-REST17   s1 + 17 sectors of user data 0x5A (a later volume's sector 16 fits): KEPT
      R-<L>-ZERO513  s1 + 513 sectors of zero user data (more than is read): KEPT
      R-<L>-SHORT    s1 without its last 2 sectors (the file ends within the volume): KEPT
      C-<L>-REST16   s1 + 16 sectors of 0x5A (no later volume's sector 16 fits): deleted
      C-<L>-ZERO150  s1 + 150 sectors of zero user data (a post-gap): deleted
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without WSL Ubuntu the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\355-uniso-raw-sessions\probe\iso355_probe.ps1.
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
if (-not $Py) { $Py = Join-Path $Here 'img357.py' }
. $Lib
$Root = $TempRoot + '\tc357'
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
#   $Msg    'none' = no window at all; 'missing' = every window is the missing-.ccd box (once per open)
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
            'missing' { $winOk = ($all.Count -gt 0) -and (@($all | Where-Object { -not $_.Contains($MissingCcd) }).Count -eq 0) }
        }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows ok ({4}): {5}; fatal: {6}; windows: {7}' -f $c[1], $c[0], $isKept, [bool]$Kept, $Msg, $winOk, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc357_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso357_probe (feature 357) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    # layout -> the name the image gets (its usual extension; .iso for the NRG offset - an .nrg name would
    # take the Nero parser first)
    $layouts = [ordered]@{ 'ecdc' = 'bin'; 'nrg' = 'iso'; '2336' = 'bin'; 'ncd' = 'ncd'; 'pdi' = 'pdi'; 'cif' = 'cif'; 'c2d' = 'c2d'; 'c2dm2' = 'c2d'; 'roxio' = 'c2d'; 'cif2332' = 'bin' }
    $kinds = @()
    foreach ($l in $layouts.Keys) { $kinds += @("$l-two", "$l-one") }
    $kinds += @('roxio-zero150', 'ecdc-rest17', 'ecdc-zero513', 'ecdc-short', 'ecdc-rest16', 'ecdc-zero150', 'nrg-rest17', 'nrg-zero513', 'nrg-short', 'nrg-rest16', 'nrg-zero150')
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath $MkImg) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\s1.iso") -and [IO.File]::Exists("$s\s2.iso")) {
        foreach ($k in $kinds) { $made += & python -I $Py $k "$s\s1.iso" "$s\s2.iso" "$s\$k.raw" 2>&1 }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img357: ' + "$m") }
    if (-not [IO.File]::Exists("$s\s1.iso")) { Out ('mkimg334.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $a = [ordered]@{ 'a.txt' = 'A1' }
    foreach ($l in $layouts.Keys) {
        $u = $l.ToUpperInvariant(); $e = $layouts[$l]
        Unpack-Row "R-$u-TWO" "$s\$l-two.raw" "$l-two.$e" $a -Kept
        if ($l -ne 'roxio') { Unpack-Row "C-$u-ONE" "$s\$l-one.raw" "$l-one.$e" $a }
    }
    Unpack-Row 'C-ROXIO-ZERO150' "$s\roxio-zero150.raw" 'roxio-zero150.c2d' $a
    foreach ($l in @('ecdc', 'nrg')) {
        $u = $l.ToUpperInvariant(); $e = $layouts[$l]
        Unpack-Row "R-$u-REST17" "$s\$l-rest17.raw" "$l-rest17.$e" $a -Kept
        Unpack-Row "R-$u-ZERO513" "$s\$l-zero513.raw" "$l-zero513.$e" $a -Kept
        Unpack-Row "R-$u-SHORT" "$s\$l-short.raw" "$l-short.$e" $a -Kept
        Unpack-Row "C-$u-REST16" "$s\$l-rest16.raw" "$l-rest16.$e" $a
        Unpack-Row "C-$u-ZERO150" "$s\$l-zero150.raw" "$l-zero150.$e" $a
    }
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
