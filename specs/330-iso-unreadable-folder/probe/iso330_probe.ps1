<#
.SYNOPSIS
    Feature 330: Unpack with "Delete archive after unpacking" keeps an ISO / UDF / Xbox image one of
    whose folders could not be read ("Error reading directory structure ... Incomplete content of ISO
    image") - before, it extracted what was listed, reported success and the image was deleted.

.DESCRIPTION
    One tree (review 4 of feature 328): a/side.txt (SIDE), top.txt (TOP), zlast/z.txt (Z); folder a
    comes before zlast in every directory, so after a read error in a no later folder is descended
    (unchanged by 330) and only top.txt is listed by that file system.
    Seeds: rd.iso (genisoimage -R) and ud.iso (genisoimage -udf: ISO 9660 + UDF, the listing shows
    "ISO (TC330)" and "UDF (TC330)") by mkimg330.sh in WSL Ubuntu; damaged copies by img330.py:
      rd_ext.iso  ISO 9660: folder A's directory record points past the end of the image
      rd_rec.iso  ISO 9660: SIDE.TXT's record in folder A has differing LE / BE extents (safety check)
      ud_ext.iso  UDF: folder a's file entry points its directory data past the end (the ISO 9660 part
                  is intact)
      xd.iso / xd_ext.iso  Xbox (XDVDFS) images of the tree written by img330.py; xd_ext's folder a
                  starts past the end
      (review 1) rd_zero.iso  ISO 9660: folder A's record has data length 0 (no box)
      ud_icb.iso  UDF: folder a's identifier points its file entry past the end (listed empty, no box)
      ud_tag.iso  UDF: folder a's directory starts with an invalid tag ("Invalid UDF Tag ID.")
      udh.iso / udh_root.iso  ISO 9660 + UDF with side.txt hidden from the ISO 9660 part (it is only in
                  the UDF part); udh_root's file set descriptor points the root past the end ("Bad
                  root ICB") - nothing of the UDF part is listed
      (review 2) udh_avdp.iso  udh.iso whose UDF anchor points the volume descriptors past the end -
                  the UDF part does not open ("Cannot read sector"); rd_root.iso  ISO 9660: the root
                  directory past the end (the box, nothing listed)
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      RD-EXT, RD-REC, UD-EXT, XD-EXT  PASS = the "Error reading directory structure" box, exactly the
                 listed files extracted with their content (top.txt; UD-EXT also the three files of
                 "ISO (TC330)"), the image KEPT - before 330: the image deleted
      RD-ZERO, UD-ICB (no window), UD-TAG ("Invalid UDF Tag ID"), UDH-ROOT ("Bad root ICB")  PASS =
                 that box (or none), exactly the listed files, the image KEPT - before review 1 of 330
                 (RD-ZERO: before 330): the image deleted
      RD-ROOT (the "Error reading directory structure" box, no file), UDH-AVDP ("Cannot read sector")
                 PASS = the image KEPT - before 330 (UDH-AVDP: before review 2): the image deleted
      RD-OK, UD-OK, UDH-OK, XD-OK  (controls) PASS = every file extracted, no window, the image
                 deleted - as before 330
    Names are compared without case (genisoimage's ISO 9660 part is upper case). Every row also fails
    on a program exit, a bug report, a fatal window, or a main window that does not answer within 30 s
    (End-Row). Without WSL Ubuntu the RD / UD rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\329-uniso-other-readers-refused\probe\iso329_probe.ps1.
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
$Root = $TempRoot + '\tc330'
$StartDir = $Root + '\start'
$ReadErr = 'Error reading directory structure'

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
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Damaged = the
# image has an unreadable folder (the image kept; $Box = the box's text, a regex, '' = no window), else
# a control (no window, the image deleted)
function Unpack-Row([string]$Case, [string]$Iso, $Want, [switch]$Damaged, [string]$Box = $ReadErr) {
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
        if (-not $Damaged) { $Box = '' }
        # (not $box: PowerShell names ignore case - it would overwrite $Box)
        if ($Box) { $winOk = ($msgs -match $Box) } else { $winOk = ($msgs -eq 'no window') }
        $ok = $c[0] -and (-not $fatal) -and $winOk
        if ($Damaged) { $ok = $ok -and $kept } else { $ok = $ok -and (-not $kept) }
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows as expected ({4}): {5}; fatal: {6}; windows: {7}' -f $c[1], $c[0], $kept, [bool]$Damaged, $(if ($Box) { '"' + $Box + '"' } else { 'none' }), $winOk, (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc330_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso330_probe (feature 330) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img330.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath (Join-Path $Here 'mkimg330.sh')) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\rd.iso")) {
        $made += & python -I $py isoext "$s\rd.iso" "$s\rd_ext.iso" 2>&1
        $made += & python -I $py isorec "$s\rd.iso" "$s\rd_rec.iso" 2>&1
        $made += & python -I $py isozero "$s\rd.iso" "$s\rd_zero.iso" 2>&1
        $made += & python -I $py isoroot "$s\rd.iso" "$s\rd_root.iso" 2>&1
    }
    if ([IO.File]::Exists("$s\ud.iso")) {
        $made += & python -I $py udfext "$s\ud.iso" "$s\ud_ext.iso" 2>&1
        $made += & python -I $py udficb "$s\ud.iso" "$s\ud_icb.iso" 2>&1
        $made += & python -I $py udftag "$s\ud.iso" "$s\ud_tag.iso" 2>&1
    }
    if ([IO.File]::Exists("$s\udh.iso")) {
        $made += & python -I $py udfroot "$s\udh.iso" "$s\udh_root.iso" 2>&1
        $made += & python -I $py udfavdp "$s\udh.iso" "$s\udh_avdp.iso" 2>&1
    }
    $made += & python -I $py xbox "$s\xd.iso" 2>&1
    $made += & python -I $py xboxext "$s\xd_ext.iso" 2>&1
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img330: ' + "$m") }
    if (-not [IO.File]::Exists("$s\rd.iso")) { Out ('mkimg330.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $all = [ordered]@{ 'a/side.txt' = 'SIDE'; 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z' }
    $top = [ordered]@{ 'top.txt' = 'TOP' }
    $udAll = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/a/side.txt' = 'SIDE'; 'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $udTop = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/top.txt' = 'TOP' }
    $udIcb = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $udhAll = [ordered]@{ 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/a/side.txt' = 'SIDE'; 'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $udhIso = [ordered]@{ 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z' }
    Unpack-Row 'RD-OK' "$s\rd.iso" $all
    Unpack-Row 'RD-EXT' "$s\rd_ext.iso" $top -Damaged
    Unpack-Row 'RD-REC' "$s\rd_rec.iso" $top -Damaged
    Unpack-Row 'RD-ZERO' "$s\rd_zero.iso" $top -Damaged -Box ''
    Unpack-Row 'RD-ROOT' "$s\rd_root.iso" ([ordered]@{}) -Damaged
    Unpack-Row 'UD-OK' "$s\ud.iso" $udAll
    Unpack-Row 'UD-EXT' "$s\ud_ext.iso" $udTop -Damaged
    Unpack-Row 'UD-ICB' "$s\ud_icb.iso" $udIcb -Damaged -Box ''
    Unpack-Row 'UD-TAG' "$s\ud_tag.iso" $udTop -Damaged -Box 'Invalid UDF Tag ID'
    Unpack-Row 'UDH-OK' "$s\udh.iso" $udhAll
    Unpack-Row 'UDH-ROOT' "$s\udh_root.iso" $udhIso -Damaged -Box 'Bad root ICB'
    Unpack-Row 'UDH-AVDP' "$s\udh_avdp.iso" $udhIso -Damaged -Box 'Cannot read sector'
    Unpack-Row 'XD-OK' "$s\xd.iso" $all
    Unpack-Row 'XD-EXT' "$s\xd_ext.iso" $top -Damaged
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
