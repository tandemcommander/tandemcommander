<#
.SYNOPSIS
    ISO 9660 folder length that cannot be a directory of the image: a folder record whose data length is
    2 GiB or more (negative as int), larger than a sane limit or past the end of the image must be a
    folder that cannot be read - one "Error reading directory structure" box per walk, the listing
    incomplete, later folders walked, the image kept - never the core's "Insufficient memory" box.

.DESCRIPTION
    Images by img403.py (plain ISO 9660 written from scratch; no WSL):
      IS-NEG    A (block 21, 0xFFFFF800), TOP.TXT, ZLAST/Z.TXT - PASS = top.txt, zlast/z.txt, exactly one
                window and it is the read-error box, the image kept - before: the memory box
      IS-NEG2   A (21, 2048; A1.TXT), B (21, 0xFFFFF800), TOP.TXT, ZLAST/Z.TXT (401 review's isoneg) -
                PASS = a/a1.txt, top.txt, zlast/z.txt, one read-error box, the image kept
      IS-MIN    A (21, 0x80000000), TOP.TXT, ZLAST/Z.TXT - as IS-NEG
      IS-HUGE   A (21, 0x7FFFF800 - positive, over the limit), TOP.TXT, ZLAST/Z.TXT - as IS-NEG
      IS-PAST   A (the image's last sector, 3 sectors claimed), TOP.TXT, ZLAST/Z.TXT - as IS-NEG (control:
                the read fails as before)
      IS-EDGE   A (3 sectors, the image's last 3), TOP.TXT, ZLAST/Z.TXT - nothing damaged (control): PASS =
                a/a1.txt, a/a3.txt, top.txt, zlast/z.txt, no window, the image deleted
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK. A memory box is
    answered Ignore (5: the allocation returns NULL, never Abort - it ends the program). Names compared
    without case. Every row also fails on a program exit, a bug report, a fatal window, or a main window
    that does not answer within 10 s (End-Row).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\401-uniso-share-length\probe\iso401_probe.ps1.
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
$Root = $TempRoot + '\tc403'
$StartDir = $Root + '\start'
$ReadErr = 'Error reading directory structure'

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

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking". $Damaged = the image
# has a folder that cannot be read: PASS needs exactly one window, the read-error box, and the image kept;
# else a control: no window, the image deleted. (not $Kept / $box: PowerShell names ignore case)
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
        $r = Serve $id 90 @(1, 6, 5)   # 5 = Ignore of the memory box (never Abort)
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $Want
        $kept = [IO.File]::Exists($LP + $img)
        $nWin = $r.Messages.Count
        $nErr = @($r.Messages | Where-Object { "$_" -match $ReadErr }).Count
        $mem = ($msgs -match 'Insufficient memory')
        if ($Damaged) { $winOk = ($nWin -eq 1 -and $nErr -eq 1) } else { $winOk = ($nWin -eq 0) }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and (-not $r.TimedOut)
        if ($Damaged) { $ok = $ok -and $kept } else { $ok = $ok -and (-not $kept) }
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows {4} (read-error {5}, memory box {6}; want {7}); timed out: {8}; fatal: {9}; windows: {10}' -f $c[1], $c[0], $kept, $Damaged.IsPresent, $nWin, $nErr, $mem, $(if ($Damaged) { 'one read-error box' } else { 'none' }), $r.TimedOut, (Tail ([string]$fatal) 200), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc403_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso403_probe {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img403.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $made = @()
    foreach ($k in @('isoneg', 'isoneg2', 'isomin', 'isohuge', 'isopast', 'isoedge')) { $made += & python -I $py $k ("$s\" + $k + '.iso') 2>&1 }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img403: ' + "$m") }
    Out ''

    $tz = [ordered]@{ 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z' }
    Unpack-Row 'IS-NEG' "$s\isoneg.iso" $tz -Damaged
    Unpack-Row 'IS-NEG2' "$s\isoneg2.iso" ([ordered]@{ 'a/a1.txt' = 'A1'; 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z' }) -Damaged
    Unpack-Row 'IS-MIN' "$s\isomin.iso" $tz -Damaged
    Unpack-Row 'IS-HUGE' "$s\isohuge.iso" $tz -Damaged
    Unpack-Row 'IS-PAST' "$s\isopast.iso" $tz -Damaged
    Unpack-Row 'IS-EDGE' "$s\isoedge.iso" ([ordered]@{ 'a/a1.txt' = 'A1'; 'a/a3.txt' = 'A3'; 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z' })
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
