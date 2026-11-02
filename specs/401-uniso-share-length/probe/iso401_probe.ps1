<#
.SYNOPSIS
    ISO 9660 folder met again with another data length: two folder records of a disc image point to
    one directory block with different lengths - the second folder must be walked for its own length
    (before: listed empty, the listing not marked, a whole Unpack with "Delete archive after
    unpacking" deleted the image without its longer part).

.DESCRIPTION
    Images by img401.py (plain ISO 9660 written from scratch; no WSL):
      IS-SHARE   root: A (block S, 2048 bytes), B (S, 4096 bytes), TOP.TXT; S holds A1.TXT, S + 1 A2.TXT
                 PASS = a/a1.txt, b/a1.txt, b/a2.txt, top.txt, no window, the image deleted (nothing
                 damaged) - before: b/a2.txt missing, no window, the image deleted
      IS-SHARE2  the same with the longer record first (A 4096, B 2048) - PASS = a/a1.txt, a/a2.txt,
                 b/a1.txt, top.txt, no window, the image deleted - before: b/a1.txt missing
      IS-LOOP    A (S, 2048) holds A1.TXT and L (a folder at S itself, 4096 bytes); S + 1 holds A2.TXT;
                 TOP.TXT, ZLAST/Z.TXT - PASS = the program answers, a/a1.txt, a/l/a1.txt, a/l/a2.txt,
                 top.txt, zlast/z.txt, no window, the image deleted (a/l/l is met again with its own
                 length: listed empty, 328's rule) - before: a/l/a2.txt missing
      IS-HLINK   A and B at one block with one length (control of 328's rule, unchanged): PASS =
                 a/x.txt, top.txt, no window, the image deleted
      IS-MANY    A (S, 2048) and 40 folders F00..F39 at S with lengths 4096..83968 - PASS = the program
                 answers, a/a1.txt, f00/a1.txt .. f39/a1.txt, top.txt, no window, the image deleted -
                 before: only a/a1.txt and top.txt
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK. Names compared
    without case. Every row also fails on a program exit, a bug report, a fatal window, or a main window
    that does not answer within 10 s (End-Row).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\400-uniso-walk-after-unreadable\probe\iso400_probe.ps1.
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
$Root = $TempRoot + '\tc401'
$StartDir = $Root + '\start'

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

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; nothing in these
# images is damaged: PASS needs no window and the image deleted, unless $KeepImage (the image kept)
# (not $Kept: PowerShell names ignore case - $kept is taken)
function Unpack-Row([string]$Case, [string]$Iso, $Want, [switch]$KeepImage) {
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
        $winOk = ($msgs -eq 'no window')
        $ok = $c[0] -and (-not $fatal) -and $winOk
        $wantKept = $KeepImage.IsPresent
        if ($wantKept) { $ok = $ok -and $kept } else { $ok = $ok -and (-not $kept) }
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); no window: {4}; fatal: {5}; windows: {6}' -f $c[1], $c[0], $kept, $wantKept, $winOk, (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc401_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso401_probe {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $Here 'img401.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $made = @()
    foreach ($k in @('isoshare', 'isoshare2', 'isoloop', 'isohlink', 'isomany')) { $made += & python -I $py $k ("$s\" + $k + '.iso') 2>&1 }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img401: ' + "$m") }
    Out ''

    Unpack-Row 'IS-SHARE' "$s\isoshare.iso" ([ordered]@{ 'a/a1.txt' = 'A1'; 'b/a1.txt' = 'A1'; 'b/a2.txt' = 'A2'; 'top.txt' = 'TOP' })
    Unpack-Row 'IS-SHARE2' "$s\isoshare2.iso" ([ordered]@{ 'a/a1.txt' = 'A1'; 'a/a2.txt' = 'A2'; 'b/a1.txt' = 'A1'; 'top.txt' = 'TOP' })
    Unpack-Row 'IS-LOOP' "$s\isoloop.iso" ([ordered]@{ 'a/a1.txt' = 'A1'; 'a/l/a1.txt' = 'A1'; 'a/l/a2.txt' = 'A2'; 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z' })
    Unpack-Row 'IS-HLINK' "$s\isohlink.iso" ([ordered]@{ 'a/x.txt' = 'X'; 'top.txt' = 'TOP' })
    $many = [ordered]@{ 'a/a1.txt' = 'A1' }
    for ($k = 0; $k -lt 40; $k++) { $many[('f{0:D2}/a1.txt' -f $k)] = 'A1' }
    $many['top.txt'] = 'TOP'
    Unpack-Row 'IS-MANY' "$s\isomany.iso" $many
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
