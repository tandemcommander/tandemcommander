<#
.SYNOPSIS
    Feature 339: Unpack with "Delete archive after unpacking" keeps an ISO 9660 + HFS+ hybrid one of
    whose HFS+ files keeps its content outside the data fork (HFS+ compressed, or only in the resource
    fork) - before, the ISO plug-in wrote the empty data fork as the file, counted it as extracted and
    the image was deleted with the file's only content.

.DESCRIPTION
    One tree (feature 332's): a/side.txt (SIDE), top.txt (TOP), zlast/z.txt (Z). Seed hdh.iso by
    specs\332-uniso-hfs-skipped-records\probe\mkimg332.sh in WSL Ubuntu (xorriso -hfsplus, no Rock Ridge
    / Joliet, volume id TC332; side.txt hidden from the ISO 9660 part - only in the HFS+ part, listed
    under "HFS (TC332)"); copies by img339.py, each of side.txt's HFS+ file record (top.txt's too where
    named):
      hdh_rsrc.iso     the content only in the resource fork, the data fork empty
      hdh_comp.iso     UF_COMPRESSED, the data in the resource fork (decmpfs type 4)
      hdh_compin.iso   UF_COMPRESSED, both forks empty (decmpfs type 3: inline in an attribute)
      hdh_flag.iso     UF_COMPRESSED with the data fork kept (macOS reads a compressed file's content
                       through decmpfs, never from the data fork)
      hdh_comp2.iso    side.txt and the HFS+ top.txt compressed (as hdh_comp.iso)
      hdh_nomode.iso   UF_COMPRESSED but the file mode 0 (TN1150: the BSD permissions are not
                       initialised - the flags are not read), the data fork kept: an ordinary file
      hdh_both.iso     a resource fork as well as the data fork: the data fork is extracted (scope:
                       the resource fork of a file that has data is not this feature's)
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK. Boxes answered
    with the row's buttons (1 OK, 173 Skip, 174 Skip all, 2 Cancel). The HFS+ hybrid opens with the
    known "Cannot read sector #00000020." box (Inbox item
    iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot) - not counted.
      H-OK       (control) hdh.iso: every file, no box, the image DELETED
      H-RSRC     hdh_rsrc.iso: one box naming side.txt and the resource fork, Skip: side.txt NOT
                 written, the rest extracted, the image KEPT
      H-COMP     hdh_comp.iso: one box naming side.txt as compressed, Skip: as H-RSRC
      H-COMPIN   hdh_compin.iso: as H-COMP
      H-FLAG     hdh_flag.iso: as H-COMP (the data fork is not the content)
      H-SKIPALL  hdh_comp2.iso, the first box answered Skip all, the second file silent: side.txt and the
                 HFS+ top.txt not written, ONE box, the image KEPT
      H-CANCEL   hdh_comp.iso, the box answered Cancel: side.txt not written, the image KEPT
      H-NOMODE   (control) hdh_nomode.iso: every file (side.txt = SIDE), no box, the image DELETED
      H-BOTH     (control) hdh_both.iso: every file (side.txt = SIDE), no box, the image DELETED (as before)
    Before 339 H-RSRC, H-COMP, H-COMPIN extract side.txt empty and delete the image; H-FLAG extracts SIDE
    and deletes it. Names are compared without case (the ISO 9660 part is upper case). Every row also
    fails on a program exit, a bug report, a fatal window, or a main window that does not answer within
    30 s (End-Row). Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\338-uniso-skip-fails-unpack\probe\iso338_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$Mk
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Lib) { $Lib = Join-Path $Here '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if (-not $Mk) { $Mk = Join-Path $Here '..\..\332-uniso-hfs-skipped-records\probe\mkimg332.sh' }
. $Lib
$Root = $TempRoot + '\tc339'
$StartDir = $Root + '\start'
$KnownBox = 'Cannot read sector #00000020.'

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

# exactly the files of $Want (relative path -> content, $null = any; compared without case) in tgt;
# @(ok, facts)
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $low = @($files | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @($Want.Keys | Where-Object { $low -notcontains $_.ToLowerInvariant() })
    $bad = @($Want.Keys | Where-Object { $low -contains $_.ToLowerInvariant() } | Where-Object {
            $k = $_.ToLowerInvariant(); $real = @($files | Where-Object { $_.ToLowerInvariant() -eq $k })[0]
            $Want[$_] -ne $null -and (Content $Tgt $real) -cne $Want[$_] })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { (Esc $_) + '=' + (Content $Tgt $_) })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Buttons answer the
# boxes; $Box = a regex every box text but the known one must match ('' = no box); $Boxes = how many;
# $Kept = the image must stay
function Unpack-Row([string]$Case, [string]$Iso, $Want, [int[]]$Buttons, [string]$Box, [int]$Boxes, [switch]$Kept) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Iso)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Iso); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Iso); [IO.File]::Copy($Iso, $LP + $img)
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
        $r = Serve $id 90 $Buttons
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        if ($null -eq $Want) {
            # Cancel: what was written before it depends on the order - only side.txt must be missing
            $files = @(Tgt-Files $tgt)
            $c = @((@($files | Where-Object { $_ -match 'side\.txt$' }).Count -eq 0), ('files {0}: {1}' -f $files.Count, ($files -join ', ')))
        }
        else { $c = Check-Files $tgt $Want }
        $isKept = [IO.File]::Exists($LP + $img)
        $other = @($r.Messages | Where-Object { $_ -notmatch [regex]::Escape($KnownBox) })
        $n = $other.Count
        if ($Box) { $winOk = ($n -eq $Boxes) -and (@($other | Where-Object { $_ -notmatch $Box }).Count -eq 0) }
        else { $winOk = ($n -eq 0) }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); boxes as expected ({4}, {5} box(es)): {6}; fatal: {7}; windows: {8}' -f $c[1], $c[0], $isKept, [bool]$Kept, $(if ($Box) { '"' + $Box + '"' } else { 'none' }), $n, $winOk, (Tail ([string]$fatal) 200), (Tail $msgs 700))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc339_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso339_probe (feature 339) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img339.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mkOut = & wsl -d Ubuntu -- sh (WslPath $Mk) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\hdh.iso")) {
        foreach ($h in @('rsrc', 'comp', 'compin', 'flag', 'nomode', 'both')) { $made += & python -I $py $h "$s\hdh.iso" "$s\hdh_$h.iso" 2>&1 }
        $made += & python -I $py comp "$s\hdh.iso" "$s\hdh_comp2.iso" 'side,top' 2>&1
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img339: ' + "$m") }
    if (-not [IO.File]::Exists("$s\hdh.iso")) { Out ('mkimg332.sh: ' + (($mkOut | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $all = [ordered]@{ 'ISO (TC332)/top.txt' = 'TOP'; 'ISO (TC332)/zlast/z.txt' = 'Z'
        'HFS (TC332)/a/side.txt' = 'SIDE'; 'HFS (TC332)/top.txt' = 'TOP'; 'HFS (TC332)/zlast/z.txt' = 'Z' }
    $noSide = [ordered]@{ 'ISO (TC332)/top.txt' = 'TOP'; 'ISO (TC332)/zlast/z.txt' = 'Z'
        'HFS (TC332)/top.txt' = 'TOP'; 'HFS (TC332)/zlast/z.txt' = 'Z' }
    $noSideTop = [ordered]@{ 'ISO (TC332)/top.txt' = 'TOP'; 'ISO (TC332)/zlast/z.txt' = 'Z'; 'HFS (TC332)/zlast/z.txt' = 'Z' }
    $rsrcBox = 'side\.txt.*resource fork'
    $compBox = 'side\.txt.*compressed'
    Unpack-Row 'H-OK' "$s\hdh.iso" $all @(1) '' 0
    Unpack-Row 'H-RSRC' "$s\hdh_rsrc.iso" $noSide @(1, 173) $rsrcBox 1 -Kept
    Unpack-Row 'H-COMP' "$s\hdh_comp.iso" $noSide @(1, 173) $compBox 1 -Kept
    Unpack-Row 'H-COMPIN' "$s\hdh_compin.iso" $noSide @(1, 173) $compBox 1 -Kept
    Unpack-Row 'H-FLAG' "$s\hdh_flag.iso" $noSide @(1, 173) $compBox 1 -Kept
    Unpack-Row 'H-SKIPALL' "$s\hdh_comp2.iso" $noSideTop @(1, 174) $compBox 1 -Kept
    Unpack-Row 'H-CANCEL' "$s\hdh_comp.iso" $null @(1, 2) $compBox 1 -Kept
    Unpack-Row 'H-NOMODE' "$s\hdh_nomode.iso" $all @(1) '' 0
    Unpack-Row 'H-BOTH' "$s\hdh_both.iso" $all @(1) '' 0
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
