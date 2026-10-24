<#
.SYNOPSIS
    Feature 338: Unpack with "Delete archive after unpacking" keeps a disc image one of whose files
    the unpack skipped or did not extract whole - before, any end but Cancel counted as success and
    the image was deleted with the skipped file's only copy.

.DESCRIPTION
    One tree: a/side.txt (SIDE), top.txt (TOP), tou.txt (TOU), zlast/z.txt (Z). Seed plain.iso (plain
    ISO 9660, genisoimage) by mkimg338.sh in WSL Ubuntu; damaged copies by img338.py:
      readerr.iso   TOP.TXT's data past the end of the image (read error at unpack)
      readerr2.iso  TOP.TXT's and ZLAST\Z.TXT's data past the end (two read errors)
      twins.iso     TOU.TXT;1 renamed TOP.TXT;1 - two listed files named top.txt (TOP, then TOU)
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK. Boxes are
    answered with the row's buttons (173 Skip, 174 Skip all, 6 Yes, 1 OK).
      OK         (control) plain.iso: every file, no window, the image DELETED
      R-SKIP     readerr.iso, "Cannot read sector" answered Skip: side, tou, z extracted, the image KEPT
      R-SKIPALL  readerr2.iso, the first "Cannot read sector" answered Skip all, the second error is
                 silent: side, tou extracted, the image KEPT (one box)
      C-SKIP     plain.iso into a target holding a FOLDER top.txt: "This name has already been used
                 for a directory" answered Skip: side, tou, z extracted, the image KEPT
      O-SKIP     plain.iso into a target holding the user's top.txt (OLD): the overwrite question
                 answered Skip: top.txt stays OLD, the image KEPT
      O-YES      (control) the same answered Yes: top.txt = TOP, the image DELETED (the user's own file
                 replaced on purpose - no file of the image lost)
      TWINS      twins.iso, the overwrite question for the second top.txt answered Yes: top.txt = TOU
                 (the first record's TOP is gone), the image KEPT
      R-SILENT   readerrz.iso (only z.txt unreadable) into a target holding the user's top.txt: the overwrite
                 question answered All - the read error of z.txt then shows NO box (the readers' silent
                 path returned success); side, top (TOP), tou extracted, the image KEPT - the only row
                 whose sole loss is a silent read error (the readers' rule alone)
      D-SKIP     plain.iso into a target holding a FILE zlast: the folder cannot be created, the boxes
                 answered Skip / OK: side, top, tou extracted (zlast stays the user's file), the image KEPT
    Before 338 every row but OK / O-YES deleted the image. Every row also fails on a program exit, a
    bug report, a fatal window, or a main window that does not answer within 30 s (End-Row). The
    "File Overwrite" confirmation is switched on for the run (restored with the registry).
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
$Root = $TempRoot + '\tc338'
$StartDir = $Root + '\start'
$ReadErr = 'Cannot read sector'

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

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Prep runs on the
# empty tgt first; $Buttons answer the boxes; $Box = a regex every box text must match ('' = no window);
# $Boxes = how many boxes ( -1 = any number > 0); $Kept = the image must stay
function Unpack-Row([string]$Case, [string]$Iso, $Want, [int[]]$Buttons, [string]$Box, [int]$Boxes, [switch]$Kept, [scriptblock]$Prep) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Iso)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Iso); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Iso); [IO.File]::Copy($Iso, $LP + $img)
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        if ($Prep) { & $Prep $tgt }
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
        $c = Check-Files $tgt $Want
        $isKept = [IO.File]::Exists($LP + $img)
        $n = $r.Messages.Count
        if ($Box) {
            $winOk = ($n -gt 0) -and (@($r.Messages | Where-Object { $_ -notmatch $Box }).Count -eq 0)
            if ($Boxes -ge 0) { $winOk = $winOk -and ($n -eq $Boxes) }
        }
        else { $winOk = ($n -eq 0) }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows as expected ({4}, {5} box(es)): {6}; fatal: {7}; windows: {8}' -f $c[1], $c[0], $isKept, [bool]$Kept, $(if ($Box) { '"' + $Box + '"' } else { 'none' }), $n, $winOk, (Tail ([string]$fatal) 200), (Tail $msgs 600))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc338_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) { & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'File Overwrite' /t REG_DWORD /d 1 /f | Out-Null }
    Out ("iso338_probe (feature 338) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img338.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath (Join-Path $Here 'mkimg338.sh')) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\plain.iso")) {
        $made += & python -I $py readerr "$s\plain.iso" "$s\readerr.iso" 2>&1
        $made += & python -I $py readerr2 "$s\plain.iso" "$s\readerr2.iso" 2>&1
        $made += & python -I $py readerrz "$s\plain.iso" "$s\readerrz.iso" 2>&1
        $made += & python -I $py twins "$s\plain.iso" "$s\twins.iso" 2>&1
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img338: ' + "$m") }
    if (-not [IO.File]::Exists("$s\plain.iso")) { Out ('mkimg338.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $all = [ordered]@{ 'a/side.txt' = 'SIDE'; 'top.txt' = 'TOP'; 'tou.txt' = 'TOU'; 'zlast/z.txt' = 'Z' }
    $noTop = [ordered]@{ 'a/side.txt' = 'SIDE'; 'tou.txt' = 'TOU'; 'zlast/z.txt' = 'Z' }
    $noTopZ = [ordered]@{ 'a/side.txt' = 'SIDE'; 'tou.txt' = 'TOU' }
    $oldTop = [ordered]@{ 'a/side.txt' = 'SIDE'; 'top.txt' = 'OLD'; 'tou.txt' = 'TOU'; 'zlast/z.txt' = 'Z' }
    $twins = [ordered]@{ 'a/side.txt' = 'SIDE'; 'top.txt' = 'TOU'; 'zlast/z.txt' = 'Z' }
    $noZ = [ordered]@{ 'a/side.txt' = 'SIDE'; 'top.txt' = 'TOP'; 'tou.txt' = 'TOU'; 'zlast' = 'F' }
    $noZ2 = [ordered]@{ 'a/side.txt' = 'SIDE'; 'top.txt' = 'TOP'; 'tou.txt' = 'TOU' }
    $userTop = { param($t) WriteFile ($t + '\top.txt') 'OLD' }
    Unpack-Row 'OK' "$s\plain.iso" $all @(1, 6) '' 0
    Unpack-Row 'R-SKIP' "$s\readerr.iso" $noTop @(173) $ReadErr 1 -Kept
    Unpack-Row 'R-SKIPALL' "$s\readerr2.iso" $noTopZ @(174) $ReadErr 1 -Kept
    Unpack-Row 'C-SKIP' "$s\plain.iso" $noTop @(173) 'already been used for a directory' 1 -Kept -Prep { param($t) NewDir ($t + '\top.txt') }
    Unpack-Row 'O-SKIP' "$s\plain.iso" $oldTop @(173) 'Confirm File Overwrite|top\.txt' 1 -Kept -Prep $userTop
    Unpack-Row 'O-YES' "$s\plain.iso" $all @(6) 'Confirm File Overwrite|top\.txt' 1 -Prep $userTop
    Unpack-Row 'TWINS' "$s\twins.iso" $twins @(6) 'Confirm File Overwrite|top\.txt' 1 -Kept
    Unpack-Row 'R-SILENT' "$s\readerrz.iso" $noZ2 @(185) 'Confirm File Overwrite|top\.txt' 1 -Kept -Prep $userTop
    Unpack-Row 'D-SKIP' "$s\plain.iso" $noZ @(173, 1) '.' -1 -Kept -Prep { param($t) WriteFile ($t + '\zlast') 'F' }
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
