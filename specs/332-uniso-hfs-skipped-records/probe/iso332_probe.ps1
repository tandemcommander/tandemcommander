<#
.SYNOPSIS
    Feature 332: Unpack with "Delete archive after unpacking" keeps an ISO 9660 + HFS+ hybrid one of
    whose HFS+ catalog records the ISO plug-in skipped as damaged - before, it extracted what was
    listed, reported success and the image was deleted (the skipped file lost).

.DESCRIPTION
    One tree (review 4 of feature 328): a/side.txt (SIDE), top.txt (TOP), zlast/z.txt (Z). Seed hdh.iso
    by mkimg332.sh in WSL Ubuntu (xorriso -hfsplus, no Rock Ridge / Joliet, volume id TC332; side.txt
    hidden from the ISO 9660 part - it is only in the HFS+ part, listed under "HFS (TC332)"); damaged
    copies by img332.py, each of side.txt's catalog record:
      hdh_type.iso   the record type 5 (neither folder nor file) - the HFS+ listing ends there
                     (z.txt, after it in the catalog, is not listed either)
      hdh_key.iso    the key length 0xFFFF (the record does not fit its node) - skipped
      hdh_long.iso   a name of 256 units in a key that fits - skipped
      hdh_short.iso  a file record shorter than its structure - skipped
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      H-TYPE, H-KEY, H-LONG, H-SHORT  PASS = no window, exactly the listed files extracted with their
                 content (side.txt missing), the image KEPT - before 332: the image deleted
      H-OK       (control) PASS = every file extracted, no window, the image deleted - as before 332
    The HFS+ hybrid opens with the known "Cannot read sector #00000020" box (Inbox item
    iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot) - it is not counted as a window.
    The UDF part of the item (feature 330 marks it): ud.iso by mkimg332.sh (genisoimage -udf, ISO 9660 +
    UDF), ud_file.iso by img332.py - a/side.txt's identifier points its file entry past the end:
      U-FILE     PASS = no window, the ISO 9660 part's three files and UDF top.txt extracted (the UDF
                 walk of folder a ends at side.txt and no later folder is descended), the image KEPT
      U-OK       (control) PASS = all six files, no window, the image deleted
    Names are compared without case (the ISO 9660 part is upper case). Every row also fails on a
    program exit, a bug report, a fatal window, or a main window that does not answer within 30 s
    (End-Row). Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\330-iso-unreadable-folder\probe\iso330_probe.ps1.
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
$Root = $TempRoot + '\tc332'
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
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Damaged = a
# catalog record of the image was skipped (the image kept, no window), else a control (no window, the
# image deleted)
function Unpack-Row([string]$Case, [string]$Iso, $Want, [switch]$Damaged) {
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
        $kept = [IO.File]::Exists($LP + $img)
        # the HFS+ hybrid's known "Cannot read sector #00000020" box (Inbox item
        # iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot) is not this feature's
        $other = @(($msgs -split ' \|\| ') | Where-Object { $_ -ne 'no window' -and $_ -notmatch [regex]::Escape($KnownBox) })
        $winOk = ($other.Count -eq 0)
        $ok = $c[0] -and (-not $fatal) -and $winOk
        if ($Damaged) { $ok = $ok -and $kept } else { $ok = $ok -and (-not $kept) }
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); no window: {4}; fatal: {5}; windows: {6}' -f $c[1], $c[0], $kept, [bool]$Damaged, $winOk, (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc332_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso332_probe (feature 332) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img332.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath (Join-Path $Here 'mkimg332.sh')) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\hdh.iso")) {
        foreach ($h in @('type', 'key', 'long', 'short')) { $made += & python -I $py $h "$s\hdh.iso" "$s\hdh_$h.iso" 2>&1 }
    }
    if ([IO.File]::Exists("$s\ud.iso")) { $made += & python -I $py udffile "$s\ud.iso" "$s\ud_file.iso" 2>&1 }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img332: ' + "$m") }
    if (-not [IO.File]::Exists("$s\hdh.iso")) { Out ('mkimg332.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $iso = [ordered]@{ 'ISO (TC332)/top.txt' = 'TOP'; 'ISO (TC332)/zlast/z.txt' = 'Z' }
    $all = [ordered]@{}; foreach ($k in $iso.Keys) { $all[$k] = $iso[$k] }
    $all['HFS (TC332)/a/side.txt'] = 'SIDE'; $all['HFS (TC332)/top.txt'] = 'TOP'; $all['HFS (TC332)/zlast/z.txt'] = 'Z'
    $skip = [ordered]@{}; foreach ($k in $iso.Keys) { $skip[$k] = $iso[$k] }
    $skip['HFS (TC332)/top.txt'] = 'TOP'; $skip['HFS (TC332)/zlast/z.txt'] = 'Z'
    $ends = [ordered]@{}; foreach ($k in $iso.Keys) { $ends[$k] = $iso[$k] }
    $ends['HFS (TC332)/top.txt'] = 'TOP'
    Unpack-Row 'H-OK' "$s\hdh.iso" $all
    Unpack-Row 'H-TYPE' "$s\hdh_type.iso" $ends -Damaged
    Unpack-Row 'H-KEY' "$s\hdh_key.iso" $skip -Damaged
    Unpack-Row 'H-LONG' "$s\hdh_long.iso" $skip -Damaged
    Unpack-Row 'H-SHORT' "$s\hdh_short.iso" $skip -Damaged
    $udAll = [ordered]@{ 'ISO (TC332)/a/side.txt' = 'SIDE'; 'ISO (TC332)/top.txt' = 'TOP'; 'ISO (TC332)/zlast/z.txt' = 'Z'
        'UDF (TC332)/a/side.txt' = 'SIDE'; 'UDF (TC332)/top.txt' = 'TOP'; 'UDF (TC332)/zlast/z.txt' = 'Z' }
    $udFile = [ordered]@{ 'ISO (TC332)/a/side.txt' = 'SIDE'; 'ISO (TC332)/top.txt' = 'TOP'; 'ISO (TC332)/zlast/z.txt' = 'Z'
        'UDF (TC332)/top.txt' = 'TOP' }
    Unpack-Row 'U-OK' "$s\ud.iso" $udAll
    Unpack-Row 'U-FILE' "$s\ud_file.iso" $udFile -Damaged
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
