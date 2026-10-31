<#
.SYNOPSIS
    Feature 349: an HFS+ folder whose catalog ID is lower than its parent's (made first, then moved on a
    Mac into a newer folder) - its contents come before its own record in the catalog's order. Before,
    the ISO plug-in listed them at the root of "HFS (...)" and Unpack wrote them there (and deleted the
    image); a left-out folder's contents were listed at the root too.

.DESCRIPTION
    Seed hfs.iso by mkimg349.sh in WSL Ubuntu (xorriso -hfsplus, no Rock Ridge / Joliet, volume id
    TC349; the ISO 9660 part holds only top.txt): a/a.txt (A), a/sub/s.txt (S), b/b.txt (B), c/c.txt (C),
    k/k.txt (K), k/kd/kd.txt (KD), n1<60 x>/n2<60 x>/n3<60 x>/n4<60 x>/ (empty; a folder part of 263 bytes
    - an entry inside is over the listing's 255), top.txt (TOP); catalog IDs rise in name order. Copies by
    img349.py (the HFS+ catalog re-sorted as HFS+ keeps it, by parent ID and name):
      hfs_move.iso   a moved into b, then b into c (a 16 < b 20 < c 22): c/b/a/... - the records of a's
                     and b's contents come before a's and b's own records
      hfs_long.iso   k moved into n4 (k 24 < n4 31): the listing leaves k out (its folder part is over
                     255 bytes) - k.txt, kd and kd.txt come before k's record
      hfs_cycle.iso  a and b each the other's parent (damaged: neither reaches the root)
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK. Boxes answered
    with OK / Yes. The HFS+ hybrid opens with the known "Cannot read sector #00000020." box (Inbox item
    iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot) - not counted.
      H-OK     (control) hfs.iso: every file in its folder, no box, the image DELETED
      H-MOVE   hfs_move.iso: HFS (TC349)/c/b/a/a.txt, c/b/a/sub/s.txt, c/b/b.txt, the rest as H-OK, no
               box, the image DELETED (nothing is missing). Before 349: a.txt, sub/s.txt and b.txt at the
               HFS+ root
      H-LONG   hfs_long.iso: k and its whole subtree left out - k.txt, kd.txt nowhere; one "(206)" box; the
               image KEPT. Before 349: k.txt and kd/kd.txt at the HFS+ root
      H-CYCLE  hfs_cycle.iso: a, b and everything in them left out, the listing incomplete: c, k, top
               extracted, no box, the image KEPT. Before 349: a and b listed (misplaced), the image deleted
    Names are compared without case (the ISO 9660 part is upper case). Every row also fails on a program
    exit, a bug report, a fatal window, or a main window that does not answer within 30 s (End-Row).
    Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\339-uniso-hfs-fork-content\probe\iso339_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Lib) { $Lib = Join-Path $Here '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc349'
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

# exactly the files of $Want (relative path -> content; compared without case) in tgt; @(ok, facts)
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $low = @($files | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @($Want.Keys | Where-Object { $low -notcontains $_.ToLowerInvariant() })
    $bad = @($Want.Keys | Where-Object { $low -contains $_.ToLowerInvariant() } | Where-Object {
            $k = $_.ToLowerInvariant(); $real = @($files | Where-Object { $_.ToLowerInvariant() -eq $k })[0]
            (Content $Tgt $real) -cne $Want[$_] })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { (Short (Esc $_)) + '=' + (Content $Tgt $_) })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ((@($missing | ForEach-Object { Short $_ })) -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}
# the long n<60 x> names shortened for the record
function Short([string]$s) { return ($s -replace 'x{60}', '<60x>') }

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Box = a regex every
# box but the known one must match ('' = no box); $Boxes = how many; $Kept = the image must stay
function Unpack-Row([string]$Case, [string]$Iso, $Want, [string]$Box, [int]$Boxes, [switch]$Kept) {
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
        $r = Serve $id 90 @(1, 6)
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $Want
        $isKept = [IO.File]::Exists($LP + $img)
        $other = @($r.Messages | Where-Object { $_ -notmatch [regex]::Escape($KnownBox) })
        $n = $other.Count
        if ($Box) { $winOk = ($n -eq $Boxes) -and (@($other | Where-Object { $_ -notmatch $Box }).Count -eq 0) }
        else { $winOk = ($n -eq 0) }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); boxes as expected ({4}, {5} box(es)): {6}; fatal: {7}; windows: {8}' -f $c[1], $c[0], $isKept, [bool]$Kept, $(if ($Box) { '"' + $Box + '"' } else { 'none' }), $n, $winOk, (Tail ([string]$fatal) 200), (Short (Tail $msgs 700)))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc349_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso349_probe (feature 349) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img349.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mkOut = & wsl -d Ubuntu -- sh (WslPath (Join-Path $Here 'mkimg349.sh')) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\hfs.iso")) {
        $made += & python -I $py move "$s\hfs.iso" "$s\hfs_move.iso" 'a:b' 'b:c' 2>&1
        $made += & python -I $py move "$s\hfs.iso" "$s\hfs_long.iso" 'k:n1/n2/n3/n4' 2>&1
        $made += & python -I $py cycle "$s\hfs.iso" "$s\hfs_cycle.iso" 'a:b' 2>&1
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img349: ' + "$m") }
    if (-not [IO.File]::Exists("$s\hfs.iso")) { Out ('mkimg349.sh: ' + (($mkOut | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $H = 'HFS (TC349)/'
    function Tree([hashtable]$Parts) {
        $t = [ordered]@{ 'ISO (TC349)/top.txt' = 'TOP'; ($H + 'top.txt') = 'TOP' }
        foreach ($k in ($Parts.Keys | Sort-Object)) { $t[$H + $k] = $Parts[$k] }
        return $t
    }
    $kTree = @{ 'k/k.txt' = 'K'; 'k/kd/kd.txt' = 'KD' }
    $all = Tree (@{ 'a/a.txt' = 'A'; 'a/sub/s.txt' = 'S'; 'b/b.txt' = 'B'; 'c/c.txt' = 'C' } + $kTree)
    $moved = Tree (@{ 'c/b/a/a.txt' = 'A'; 'c/b/a/sub/s.txt' = 'S'; 'c/b/b.txt' = 'B'; 'c/c.txt' = 'C' } + $kTree)
    $long = Tree @{ 'a/a.txt' = 'A'; 'a/sub/s.txt' = 'S'; 'b/b.txt' = 'B'; 'c/c.txt' = 'C' }
    $cycle = Tree (@{ 'c/c.txt' = 'C' } + $kTree)
    Unpack-Row 'H-OK' "$s\hfs.iso" $all '' 0
    Unpack-Row 'H-MOVE' "$s\hfs_move.iso" $moved '' 0
    Unpack-Row 'H-LONG' "$s\hfs_long.iso" $long '\(206\)' 1 -Kept
    Unpack-Row 'H-CYCLE' "$s\hfs_cycle.iso" $cycle '' 0 -Kept
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
