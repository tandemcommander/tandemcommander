<#
.SYNOPSIS
    Feature 368: an ISO 9660 file stored in several extents (multi-extent, ISO 9660 level 3 - every directory
    record of the file but the last has bit 7 of its file flags set; a file of 4 GiB or more is always stored
    so) is listed once with its whole size and extracted whole - before, each record was listed as a file of
    its own and an unpack wrote them one over the other (only the last part was left).

.DESCRIPTION
    Images by img368.py (see its docstring): plain / rr / joliet / rrfirst / dirflag (a multi-extent BIG.BIN of
    three extents out of disc order, SMALL.TXT, SUB\PART.BIN of two extents, ZED.TXT), brkname / brkend (a chain
    without its last record), and big.iso (a real xorrisofs -iso-level 3 image with huge.bin of 4 GiB + 3000
    bytes, mkimg368.sh in WSL Ubuntu; -BigSeed = a folder holding big.iso and big.sha256 - it is hard-linked
    into the fixture, never written).
    Unpack rows (U-*): the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK; boxes answered Yes / OK.
      U-PLAIN, U-RR, U-JOLIET, U-RRFIRST, U-DIRFLAG  every file whole (size and sha256 of expect.json), no box,
                 the image DELETED
      U-BRKNAME, U-BRKEND  the chain without its last record: that file NOT extracted, the others whole, the
                 box "Error reading directory structure", the image KEPT
      G-BIG      big.iso: huge.bin whole (size, sha256), small.txt, no box, the image (a hard link) DELETED
    Copy rows (C-*): the image opened in the left panel, Home, Down, Down focuses the first file (BIG.BIN after
    the folder), F5 (727) to the right panel (<row>\tgt), boxes answered OK / Yes: tgt holds exactly that file,
    whole.
      C-PLAIN, C-JOLIET
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer (End-Row). The "File Overwrite" confirmation is switched on for the run (restored with the
    registry). MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
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
    [string]$BigSeed,
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
$Root = $TempRoot + '\tc368'
$StartDir = $Root + '\start'
$ListErr = 'Error reading directory structure'

function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Sha([string]$p) {
    $s = [IO.File]::OpenRead($LP + $p)
    try { $h = [Security.Cryptography.SHA256]::Create(); return (($h.ComputeHash($s) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $s.Dispose() }
}
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}
# exactly the files of $Want (relative path -> @(size, sha256); case-sensitive names) in tgt; @(ok, facts)
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $facts = @()
    $ok = ($files.Count -eq $Want.Count)
    foreach ($f in $files) {
        $len = (New-Object IO.FileInfo ($LP + $Tgt + '\' + $f.Replace('/', '\'))).Length
        $fact = ('{0}={1}' -f (Esc $f), $len)
        if ($Want.Contains($f)) {
            $w = $Want[$f]
            if ($len -ne [long]$w[0]) { $ok = $false; $fact += (' (want ' + $w[0] + ')') }
            elseif ((Sha ($Tgt + '\' + $f.Replace('/', '\'))) -ne $w[1]) { $ok = $false; $fact += ' (wrong content)' }
        }
        else { $ok = $false; $fact += ' (not expected)' }
        $facts += $fact
    }
    $missing = @($Want.Keys | Where-Object { $files -cnotcontains $_ })
    if ($missing.Count) { $ok = $false }
    $t = ('files {0}: {1}' -f $files.Count, ($facts -join ', '))
    if ($missing.Count) { $t += ('; missing: ' + ($missing -join ', ')) }
    return @($ok, $t)
}
function Expect-Of($e) {
    $w = [ordered]@{}
    foreach ($p in ($e.files.PSObject.Properties | Sort-Object Name)) { $w[$p.Name] = @($p.Value[0], $p.Value[1]) }
    return $w
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Box = a regex every box
# must match ('' = no window); $Kept = the image must stay; $Link = hard-link the image instead of copying it
function Unpack-Row([string]$Case, [string]$Iso, $Want, [string]$Box, [switch]$Kept, [switch]$Link, [double]$Secs = 90) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Iso)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Iso); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Iso)
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        if ($Link) {
            & cmd.exe /c "mklink /H `"$img`" `"$Iso`" >nul"
            if (-not [IO.File]::Exists($img)) { throw 'the hard link of the image was not made' }
        }
        else { [IO.File]::Copy($Iso, $LP + $img) }
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
        $r = Serve $id $Secs @(1, 6)
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $Want
        $isKept = [IO.File]::Exists($LP + $img)
        $n = $r.Messages.Count
        if ($Box) { $winOk = ($n -gt 0) -and (@($r.Messages | Where-Object { $_ -notmatch $Box }).Count -eq 0) }
        else { $winOk = ($n -eq 0) }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept) -and (-not $r.TimedOut)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows as expected ({4}, {5} box(es)): {6}; timed out: {7}; fatal: {8}; windows: {9}' -f $c[1], $c[0], $isKept, [bool]$Kept, $(if ($Box) { '"' + $Box + '"' } else { 'none' }), $n, $winOk, $r.TimedOut, (Tail ([string]$fatal) 200), (Tail $msgs 600))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# F5 of the first file (Home, Down, Down) of the image opened in the left panel into tgt (the right panel)
function Copy-Row([string]$Case, [string]$Iso, $Want) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Iso)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Iso); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Iso); [IO.File]::Copy($Iso, $LP + $img)
    $id = 0; $fatal = $null; $before = Reports; $save = $script:StartDir
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $script:StartDir = $tgt
        $id = Start-Tc $img; $script:StartDir = $save
        $r0 = Serve $id 6 @(1)
        foreach ($k in @(0x24, 0x28, 0x28)) { Key $id $k; Start-Sleep -Milliseconds 400 }
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 40 @(1, 6)
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $Want
        $ok = $c[0] -and (-not $fatal) -and ($r0.Messages.Count -eq 0)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; at the open: {2}; F5: {3}' -f $c[1], $c[0], (Tail (Msgs $r0) 300), (Tail (Msgs $r) 300))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { $script:StartDir = $save; if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc368_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    & cmd.exe /c "reg query `"$RegKey\Settings\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) { & reg.exe add "$RegKey\Settings\Configuration\Confirmation" /v 'File Overwrite' /t REG_DWORD /d 1 /f | Out-Null }
    Out ("iso368_probe (feature 368) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $made = & python -I (Join-Path $Here 'img368.py') $s 2>&1
    $ErrorActionPreference = $old
    Out ("img368: {0}" -f (($made | ForEach-Object { "$_" }) -join ' '))
    $exp = Get-Content -Raw -LiteralPath "$s\expect.json" | ConvertFrom-Json
    Out ''

    foreach ($k in @('plain', 'rr', 'joliet', 'rrfirst', 'dirflag')) {
        Unpack-Row ('U-' + $k.ToUpperInvariant()) "$s\$k.iso" (Expect-Of $exp."$k.iso") ''
    }
    Unpack-Row 'U-BRKNAME' "$s\brkname.iso" (Expect-Of $exp.'brkname.iso') $ListErr -Kept
    Unpack-Row 'U-BRKEND' "$s\brkend.iso" (Expect-Of $exp.'brkend.iso') $ListErr -Kept
    $wp = [ordered]@{ 'BIG.BIN' = @($exp.'plain.iso'.files.'BIG.BIN') }
    Copy-Row 'C-PLAIN' "$s\plain.iso" $wp
    $wj = [ordered]@{ 'Big File.bin' = @($exp.'joliet.iso'.files.'Big File.bin') }
    Copy-Row 'C-JOLIET' "$s\joliet.iso" $wj
    if (Want 'G-BIG') {
        if ($BigSeed -and [IO.File]::Exists("$BigSeed\big.iso") -and [IO.File]::Exists("$BigSeed\big.sha256")) {
            $sha = (Get-Content -Raw -LiteralPath "$BigSeed\big.sha256").Trim()
            $wb = [ordered]@{ 'huge.bin' = @(4294970296, $sha); 'small.txt' = @(5, '74dc4b485158ef973dd72fdcf7a8650182b34f84bc2e5e0c8f450b9a42f91adc') }
            Unpack-Row 'G-BIG' "$BigSeed\big.iso" $wb '' -Link -Secs 900
        }
        else { Row 'G-BIG' 'RUN' 'NOT DRIVEN' 'no -BigSeed with big.iso and big.sha256 (mkimg368.sh in WSL Ubuntu)' }
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
