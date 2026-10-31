<#
.SYNOPSIS
    Feature 354: a cooked (2048-byte sector) disc image whose file holds more than the volume the ISO
    plug-in lists (a second session past the first volume) is no longer deleted by a whole unpack with
    "Delete archive after unpacking"; a plain one-volume image, and one whose rest past the volume is
    only zero padding, unpack and are deleted as before.

.DESCRIPTION
    Seeds by feature 334's mkimg334.sh in WSL Ubuntu (genisoimage): s1.iso (a.txt "A1", 176 sectors whose
    primary volume descriptor says 176) and s2.iso (b.txt "B2", addressed from the sector after s1).
    img354.py writes the cooked images (see its docstring); mkxorriso354.sh the xorriso images.
    Unpack rows (as feature 353's): the left panel shows <row>\src, Home, End focuses the image, Alt+F9
    (851), the target field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
    A .iso row must show no window at all; an .img row only "Missing .CCD file" boxes (once per open).
      C-PLAIN     s1.iso (the file equals the volume): PASS = a.txt extracted, the image deleted
      R-TWOISO    s1 + s2 joined, named .iso: PASS = a.txt extracted, the image KEPT. Before: deleted,
                  b.txt lost (review 1 of 353, X-COOKED2ISO)
      R-TWOIMG    the same named .img (no .ccd): PASS = a.txt, KEPT (353's X-COOKED2IMG)
      C-REST16    s1 + 16 sectors of 0x5A (no later volume's sector 16 fits): PASS = a.txt, deleted
      R-REST17    s1 + 17 sectors of 0x5A (a later volume's sector 16 fits): PASS = a.txt, KEPT
      C-ZERO168   s1 + 168 zero sectors (xorriso's native padding): PASS = a.txt, deleted
      C-ZERO512   s1 + 512 zero sectors (the most that is read): PASS = a.txt, deleted
      R-ZERO513   s1 + 513 zero sectors (more than is read - not all checked): PASS = a.txt, KEPT
      R-ZEROLATE  s1 + 300 zero sectors, the last byte 1 (the whole rest is read): PASS = a.txt, KEPT
      R-SHORT     s1 without its last 2 sectors (the file ends within the volume): PASS = a.txt, KEPT
      R-BIGPVD    as R-TWOISO, s1's volume size patched to 400 (more than the file): PASS = a.txt, KEPT
      C-XDEV1     xorriso native, one session (zero padding outside the volume): PASS = a.txt, deleted
      C-XMS       xorriso native, two sessions in one file (sector 16 describes the newest): PASS = a.txt
                  and b.txt extracted, deleted
      R-XESP      xorriso with an appended partition past the volume (not listed): PASS = a.txt, KEPT
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without WSL Ubuntu (or xorriso, for the X rows) the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\353-uniso-noccd-sessions\probe\iso353_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$MkImg,
    [string]$MkX,
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
if (-not $MkX) { $MkX = Join-Path $Here 'mkxorriso354.sh' }
if (-not $Py) { $Py = Join-Path $Here 'img354.py' }
. $Lib
$Root = $TempRoot + '\tc354'
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

$backup = Join-Path $env:TEMP 'tc354_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso354_probe (feature 354) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $kinds = @('plain', 'two', 'rest16', 'rest17', 'zero168', 'zero512', 'zero513', 'zerolate', 'short', 'bigpvd')
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath $MkImg) (WslPath $s) 2>&1
    $mx = & wsl -d Ubuntu -- sh (WslPath $MkX) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\s1.iso") -and [IO.File]::Exists("$s\s2.iso")) {
        foreach ($k in $kinds) { $made += & python -I $Py $k "$s\s1.iso" "$s\s2.iso" "$s\$k.bin" 2>&1 }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img354: ' + "$m") }
    if (-not [IO.File]::Exists("$s\s1.iso")) { Out ('mkimg334.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    if (-not [IO.File]::Exists("$s\xesp.iso")) { Out ('mkxorriso354.sh: ' + (($mx | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $a = [ordered]@{ 'a.txt' = 'A1' }
    $ab = [ordered]@{ 'a.txt' = 'A1'; 'b.txt' = 'B2' }
    Unpack-Row 'C-PLAIN' "$s\plain.bin" 'plain.iso' $a
    Unpack-Row 'R-TWOISO' "$s\two.bin" 'two.iso' $a -Kept
    Unpack-Row 'R-TWOIMG' "$s\two.bin" 'two.img' $a -Kept -Msg 'missing'
    Unpack-Row 'C-REST16' "$s\rest16.bin" 'rest16.iso' $a
    Unpack-Row 'R-REST17' "$s\rest17.bin" 'rest17.iso' $a -Kept
    Unpack-Row 'C-ZERO168' "$s\zero168.bin" 'zero168.iso' $a
    Unpack-Row 'C-ZERO512' "$s\zero512.bin" 'zero512.iso' $a
    Unpack-Row 'R-ZERO513' "$s\zero513.bin" 'zero513.iso' $a -Kept
    Unpack-Row 'R-ZEROLATE' "$s\zerolate.bin" 'zerolate.iso' $a -Kept
    Unpack-Row 'R-SHORT' "$s\short.bin" 'short.iso' $a -Kept
    Unpack-Row 'R-BIGPVD' "$s\bigpvd.bin" 'bigpvd.iso' $a -Kept
    Unpack-Row 'C-XDEV1' "$s\xdev1.iso" 'xdev1.iso' $a
    Unpack-Row 'C-XMS' "$s\xms.iso" 'xms.iso' $ab
    Unpack-Row 'R-XESP' "$s\xesp.iso" 'xesp.iso' $a -Kept
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
