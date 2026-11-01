<#
.SYNOPSIS
    Backlog item uncab-wtf8-flagged-name-refused: a cabinet entry flagged _A_NAME_IS_UTF whose name is valid
    WTF-8 (an unpaired UTF-16 surrogate as its 3-byte form, as a Windows packer using the vendored 7-Zip
    converter writes it) no longer makes the whole cabinet fail in the UnCAB plug-in - it is listed and
    extracted under that exact name; a flagged name that is not even WTF-8 is still refused.

.DESCRIPTION
    cab381.py writes the cabinets (one folder, stored, two entries: the case's flagged name with content "N1",
    then the plain ASCII "c.txt" with "C1"):
      ok.cab     "a<U+00E9>.txt"   (valid UTF-8, flagged)           - control
      wtf8.cab   "a<ED A0 80>b.txt" (lone high surrogate U+D800)   - the item
      wtf8l.cab  "a<ED B0 80>b.txt" (lone low surrogate U+DC00)    - the item
      bad.cab    "a<FF>b.txt"      (not WTF-8)                      - stays refused
      over.cab   "a<C0 80>b.txt"   (overlong NUL, not WTF-8)        - stays refused
    Unpack rows U-<case> (as feature 378's): the left panel shows <row>\src, Home, End focuses the cabinet,
    Alt+F9 (851), the target field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      U-OK, U-WTF8, U-WTF8L   PASS = both files with their exact names and contents, no window, cabinet deleted.
                              Before (U-WTF8, U-WTF8L): nothing extracted, an error window, cabinet kept
      U-BAD, U-OVER           PASS = nothing extracted (the refused entry aborts the cabinet before c.txt), no
                              window (the refusal is silent - FDIERROR_USER_ABORT, measured at bd7cc15e; a message
                              is a separate backlog item), cabinet kept - before and after
    List rows L-<case>: Home, End, Enter (posted) on the cabinet; the windows are answered; then the panel's
    location is read from Change Directory (862).
      L-OK, L-WTF8, L-WTF8L   PASS = no window, the location is inside the cabinet (ends with "<case>.cab")
      L-BAD                   PASS = no window (silent, as U-BAD), the location stays <row>\src
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\378-uniso-udf-partition-maps\probe\iso378_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
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
if (-not $Py) { $Py = Join-Path $Here 'cab381.py' }
. $Lib
$Root = $TempRoot + '\tc381'
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

# the files of $Want (relative name -> content; compared ordinally, case and code units exact) in tgt -
# exactly these; @(ok, facts)
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    $missing = @($Want.Keys | Where-Object { $files -cnotcontains $_ })
    $bad = @($Want.Keys | Where-Object { $files -ccontains $_ } | Where-Object { (Content $Tgt $_) -cne $Want[$_] })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    if ($missing.Count) { $f += ('; missing: ' + ((@($missing | ForEach-Object { Esc $_ })) -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ((@($bad | ForEach-Object { Esc $_ })) -join ', ')) }
    return @($ok, $f)
}

function New-Row([string]$Case, [string]$Cab0, [string]$Name) {
    $d = $Root + '\' + $Case; NewDir ($d + '\src'); NewDir ($d + '\tgt')
    $cab = $d + '\src\' + $Name; [IO.File]::Copy($Cab0, $LP + $cab)
    if (-not $cab.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $cab) }
    return $d
}

# Unpack (Alt+F9) of the whole cabinet into tgt with "Delete archive after unpacking".
#   $Msg 'none' = no window at all; 'any' = at least one window
function Unpack-Row([string]$Case, [string]$Cab0, [string]$Name, $Want, [switch]$Kept, [string]$Msg = 'none') {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Cab0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no cabinet ' + $Cab0); return }
    $id = 0; $fatal = $null; $before = Reports
    try {
        $d = New-Row $Case $Cab0 $Name; $tgt = $d + '\tgt'; $cab = $d + '\src\' + $Name
        if (-not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
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
        $r = Serve $id 60 @(1, 6)
        $msgs = Msgs $r
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $Want
        $isKept = [IO.File]::Exists($LP + $cab)
        $all = @(($msgs -split ' \|\| ') | Where-Object { $_ -ne 'no window' })
        switch ($Msg) {
            'none' { $winOk = ($all.Count -eq 0) }
            'any' { $winOk = ($all.Count -gt 0) }
        }
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; cabinet kept: {2} (want {3}); windows ok ({4}): {5}; fatal: {6}; windows: {7}' -f $c[1], $c[0], $isKept, [bool]$Kept, $Msg, $winOk, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# Enter on the cabinet (posted, so a message box does not block the probe); $Inside = the listing must open
function List-Row([string]$Case, [string]$Cab0, [string]$Name, [switch]$Inside) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Cab0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no cabinet ' + $Cab0); return }
    $id = 0; $fatal = $null; $before = Reports
    try {
        $d = New-Row $Case $Cab0 $Name; $src = $d + '\src'
        $id = Start-Tc $src
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $l = Get-LeftList $id
        [void][Drv098f]::PostMessageW($l, 0x0100, [IntPtr]0x0D, [IntPtr]1)
        [void][Drv098f]::PostMessageW($l, 0x0101, [IntPtr]0x0D, [IntPtr]0xC0000001L)
        Start-Sleep -Milliseconds 1500
        $r = Serve $id 30 @(1, 6)
        $msgs = Msgs $r
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $loc = '<not read>'; if (-not $fatal) { $loc = Get-Loc $id }
        End-Row $Case $id $fatal $before; $id = 0
        $all = @(($msgs -split ' \|\| ') | Where-Object { $_ -ne 'no window' })
        $trim = $loc.TrimEnd('\')
        if ($Inside) { $ok = ($all.Count -eq 0) -and $trim.EndsWith('\' + $Name, [StringComparison]::OrdinalIgnoreCase) }
        else { $ok = ($all.Count -eq 0) -and ($trim -ieq $src) }
        $ok = $ok -and (-not $fatal)
        Row $Case 'RUN' (V $ok) ('location: {0} (want {1}); fatal: {2}; windows: {3}' -f (Esc $loc), $(if ($Inside) { 'inside ' + $Name } else { 'the src folder' }), (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc381_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cab381_probe {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $made = @()
    foreach ($m in @('ok', 'wtf8', 'wtf8l', 'bad', 'over')) { $made += & python -I $Py $m "$s\$m.cab" 2>&1 }
    $ErrorActionPreference = $old
    foreach ($m in $made) { Out ('cab381: ' + "$m") }
    Out ''

    $hi = [string][char]0xD800; $lo = [string][char]0xDC00; $e = [string][char]0x00E9
    $c = [ordered]@{ 'c.txt' = 'C1' }
    Unpack-Row 'U-OK' "$s\ok.cab" 'ok.cab' ([ordered]@{ ('a' + $e + '.txt') = 'N1'; 'c.txt' = 'C1' })
    Unpack-Row 'U-WTF8' "$s\wtf8.cab" 'wtf8.cab' ([ordered]@{ ('a' + $hi + 'b.txt') = 'N1'; 'c.txt' = 'C1' })
    Unpack-Row 'U-WTF8L' "$s\wtf8l.cab" 'wtf8l.cab' ([ordered]@{ ('a' + $lo + 'b.txt') = 'N1'; 'c.txt' = 'C1' })
    # a refused entry aborts FDICopy: c.txt after it is not reached either -> nothing extracted
    Unpack-Row 'U-BAD' "$s\bad.cab" 'bad.cab' ([ordered]@{}) -Kept
    Unpack-Row 'U-OVER' "$s\over.cab" 'over.cab' ([ordered]@{}) -Kept
    List-Row 'L-OK' "$s\ok.cab" 'ok.cab' -Inside
    List-Row 'L-WTF8' "$s\wtf8.cab" 'wtf8.cab' -Inside
    List-Row 'L-WTF8L' "$s\wtf8l.cab" 'wtf8l.cab' -Inside
    List-Row 'L-BAD' "$s\bad.cab" 'bad.cab'
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
