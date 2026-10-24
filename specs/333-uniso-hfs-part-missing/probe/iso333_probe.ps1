<#
.SYNOPSIS
    Feature 333: Unpack with "Delete archive after unpacking" keeps an ISO 9660 + HFS+ hybrid whose HFS+
    part does not open - before, the ISO plug-in dropped the HFS+ part without a mark, extracted the ISO
    9660 part, reported success and the image was deleted (files only in the HFS+ part lost).

.DESCRIPTION
    One tree (as 332): a/side.txt (SIDE), top.txt (TOP), zlast/z.txt (Z). Seed hdh.iso by mkimg333.sh in
    WSL Ubuntu (xorriso -hfsplus, no Rock Ridge / Joliet, volume id TC333; side.txt hidden from the ISO
    9660 part - it is only in the HFS+ part, listed under "HFS (TC333)"); damaged copies by img333.py:
      hdh_ver.iso    the HFS+ volume header's version 5 (signature "H+" kept)
      hdh_cat.iso    the catalog's header node kind 0 (feature 322 refuses the catalog)
      hdh_size.iso   the catalog's logical size 0
      hdh_ext.iso    the catalog's first extent far past the end of the image
      hdh_nosig.iso  the volume header's signature zeroed - no HFS+ volume is declared any more
    apm.iso by mkimg333.sh: the layout of Ubuntu's / Debian's install images (xorriso -isohybrid-mbr
    -isohybrid-apm-hfsplus with an EFI boot image): an Apple partition map whose "Apple_HFS" partition
    holds the EFI image, no HFS+ volume - the plug-in takes it as ISO 9660 + HFS+ and its HFS part does
    not open; it must not be marked (every such image's whole unpack would fail).
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      H-VER, H-CAT, H-SIZE, H-EXT  PASS = no window, exactly the ISO 9660 part's files extracted (top.txt,
                 zlast/z.txt), the image KEPT - before 333: the image deleted, side.txt lost
      H-OK       (control) PASS = every file of both parts extracted, no window, the image deleted
      APM-EFI    (control) PASS = no window, top.txt and a/side.txt of the ISO part extracted (the boot
                 files too - not compared), the image deleted - as before 333
      H-APMSIG, H-APMCNT  (review 1) the partition map entry "Gap0" (not the HFS+ one) damaged - its
                 signature "PX", its entry count + 1; the HFS+ volume intact: PASS = as H-VER (kept)
      APM-EFI-CNT (control) the APM install image's map refused (entry count + 1 in "EFI"): PASS = as
                 APM-EFI (deleted) - its intact "Apple_HFS" entry holds no HFS+ volume
      H-NOSIG    (limit, as 330's destroyed UDF anchor) PASS = the ISO 9660 part extracted, no window,
                 the image deleted - nothing shows that an HFS+ part was there
    The HFS+ hybrid opens with the known "Cannot read sector #00000020" box (Inbox item
    iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot), the APM image shows "Cannot read
    sector #00000200" (an Inbox item of 333's measurement) - neither is counted as a window.
    Names are compared without case (the ISO 9660 part is upper case). Every row also fails on a
    program exit, a bug report, a fatal window, or a main window that does not answer within 30 s
    (End-Row). Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\332-uniso-hfs-skipped-records\probe\iso332_probe.ps1.
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
$Root = $TempRoot + '\tc333'
$StartDir = $Root + '\start'
# known boxes of other items, not counted: "#00000020" at the open of every xorriso HFS+ hybrid (Inbox
# iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot), "#00000200" for the APM install image
# (Inbox item of feature 333's measurement)
$KnownBox = 'Cannot read sector #(00000020|00000200)\.'

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

# the files of $Want (relative path -> content, $null = any; compared without case) in tgt - exactly
# these, or with $Contains at least these; @(ok, facts)
function Check-Files([string]$Tgt, $Want, [bool]$Contains) {
    $files = @(Tgt-Files $Tgt)
    $low = @($files | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @($Want.Keys | Where-Object { $low -notcontains $_.ToLowerInvariant() })
    $bad = @($Want.Keys | Where-Object { $low -contains $_.ToLowerInvariant() } | Where-Object {
            $k = $_.ToLowerInvariant(); $real = @($files | Where-Object { $_.ToLowerInvariant() -eq $k })[0]
            $Want[$_] -ne $null -and (Content $Tgt $real) -cne $Want[$_] })
    $ok = (($Contains -or $files.Count -eq $Want.Count) -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Kept = the HFS+
# part did not open (the image kept, no window), else a control (no window, the image deleted)
function Unpack-Row([string]$Case, [string]$Iso, $Want, [switch]$Kept, [switch]$Contains) {
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
        $c = Check-Files $tgt $Want ([bool]$Contains)
        $isKept = [IO.File]::Exists($LP + $img)
        # the HFS+ hybrid's known "Cannot read sector #00000020" box (Inbox item
        # iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot) is not this feature's
        $other = @(($msgs -split ' \|\| ') | Where-Object { $_ -ne 'no window' -and $_ -notmatch $KnownBox })
        $winOk = ($other.Count -eq 0)
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); no window: {4}; fatal: {5}; windows: {6}' -f $c[1], $c[0], $isKept, [bool]$Kept, $winOk, (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc333_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso333_probe (feature 333) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img333.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath (Join-Path $Here 'mkimg333.sh')) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\hdh.iso")) {
        foreach ($h in @('ver', 'cat', 'size', 'ext', 'nosig', 'apmsig', 'apmcnt')) { $made += & python -I $py $h "$s\hdh.iso" "$s\hdh_$h.iso" 2>&1 }
    }
    if ([IO.File]::Exists("$s\apm.iso")) { $made += & python -I $py apmcnt "$s\apm.iso" "$s\apm_apmcnt.iso" 2>&1 }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img333: ' + "$m") }
    if (-not [IO.File]::Exists("$s\hdh.iso") -or -not [IO.File]::Exists("$s\apm.iso")) { Out ('mkimg333.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $iso = [ordered]@{ 'ISO (TC333)/top.txt' = 'TOP'; 'ISO (TC333)/zlast/z.txt' = 'Z' }
    $all = [ordered]@{}; foreach ($k in $iso.Keys) { $all[$k] = $iso[$k] }
    $all['HFS (TC333)/a/side.txt'] = 'SIDE'; $all['HFS (TC333)/top.txt'] = 'TOP'; $all['HFS (TC333)/zlast/z.txt'] = 'Z'
    Unpack-Row 'H-OK' "$s\hdh.iso" $all
    Unpack-Row 'H-VER' "$s\hdh_ver.iso" $iso -Kept
    Unpack-Row 'H-CAT' "$s\hdh_cat.iso" $iso -Kept
    Unpack-Row 'H-SIZE' "$s\hdh_size.iso" $iso -Kept
    Unpack-Row 'H-EXT' "$s\hdh_ext.iso" $iso -Kept
    Unpack-Row 'H-NOSIG' "$s\hdh_nosig.iso" $iso
    $apm = [ordered]@{ 'ISO (TC333APM)/top.txt' = 'TOP'; 'ISO (TC333APM)/a/side.txt' = 'SIDE' }
    Unpack-Row 'APM-EFI' "$s\apm.iso" $apm -Contains
    Unpack-Row 'H-APMSIG' "$s\hdh_apmsig.iso" $iso -Kept
    Unpack-Row 'H-APMCNT' "$s\hdh_apmcnt.iso" $iso -Kept
    Unpack-Row 'APM-EFI-CNT' "$s\apm_apmcnt.iso" $apm -Contains
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
