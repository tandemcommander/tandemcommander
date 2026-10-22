<#
.SYNOPSIS
    Feature 309 probe (backlog item tar-unpack-drops-hard-links-and-deletes-archive): a hard-link member of a
    tar is extracted as a copy of the file it names; a link member that cannot be reproduced (a
    symbolic link, a hard link to a file not extracted) is reported and fails the unpack, so
    "Delete archive after unpacking" keeps the archive.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\src\t.tar made by Python's tarfile
    through mklink309.py (next to this script) and an empty <row>\tgt.
    Unpack rows: the left panel shows <row>\src, Home, End focuses the archive, Alt+F9 (851) opens the
    Unpack dialog, the path field (210) is set to <row>\tgt by WM_SETTEXT, the mask stays "*.*",
    "Delete archive after unpacking" (6210) is checked, OK, every box answered OK / Yes.
      UNP-HARD-DEL          a.txt, sub/c.txt, hard links sub/b.txt -> a.txt and ./sub/d.txt -> ./a.txt
                            -> 4 files (b.txt, d.txt = a.txt's content), nothing asked, t.tar deleted
      UNP-HARD-PAX-DEL      CJK(40).txt (PAX path), hard link sub/CJK'(40).txt to it (PAX linkpath; the
                            ustar link name is a '?' fallback) -> both files, nothing asked, t.tar deleted
      UNP-HARD-GNU-DEL      GNU format: g*120.txt (GNU long name), hard link sub/h.txt to it (GNU long
                            link name) -> both files, nothing asked, t.tar deleted
      UNP-HARD-MISSING-DEL  hard link b.txt -> missing.txt (no such member), ok.txt
                            -> ok.txt, a box naming b.txt, t.tar KEPT
      UNP-SYM-DEL           a.txt, symbolic links s.txt and t.txt -> a.txt
                            -> a.txt, exactly one box (naming s.txt), t.tar KEPT
      UNP-HARD-TWIN-DEL     a.txt, hard link A.TXT -> a.txt (the same file on Windows)
                            -> a.txt with its content (never truncated), nothing asked, t.tar deleted
      UNP-HARD-DOTDOT-DEL   a.txt, s/a.txt, hard link b.txt -> sub/../a.txt (review 1: the legacy ".." rule
                            would make it s\a.txt) -> a.txt, s/a.txt, a box naming b.txt, t.tar KEPT
    Copy row: the left panel opens t.tar, the right shows tgt; Select All (842), Copy (727), boxes OK.
      COPY-HARD             the UNP-HARD tar: the listing shows a.txt and sub; copying both
                            -> the 4 files, b.txt and d.txt with a.txt's content, nothing asked
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\308-pax-deep-unpack\probe\unp308_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$Python = 'python'
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
$Root = $TempRoot + '\tc309'
$StartDir = $Root + '\start'
$MkLink309 = Join-Path $Here 'mklink309.py'

function Cjk([int]$n, [int]$start = 0x4E00) { $sb = New-Object Text.StringBuilder; for ($i = 0; $i -lt $n; $i++) { [void]$sb.Append([char]($start + $i)) }; return $sb.ToString() }
function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) }
function Short([string]$s) { if ($s.Length -le 24) { return $s }; return ('{0}..[{1} chars]..{2}' -f $s.Substring(0, 8), $s.Length, $s.Substring($s.Length - 8)) }
# compares tgt with $Want (names compared as the file system does - case-insensitively): @(ok, facts)
function Check-Tgt([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $ok = ($files.Count -eq $Want.Count)
    $missing = @($Want.Keys | Where-Object { $files -notcontains $_ })
    $bad = @($Want.Keys | Where-Object { $files -contains $_ -and (Content $Tgt $_) -cne $Want[$_] })
    if ($missing.Count -or $bad.Count) { $ok = $false }
    $f = ('tgt: {0} of {1} files' -f $files.Count, $Want.Count)
    if ($missing.Count) { $f += ('; missing {0}: {1}' -f $missing.Count, ((@($missing | Select-Object -First 4 | ForEach-Object { Esc (Short $_) })) -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ((@($bad | ForEach-Object { Esc (Short $_) })) -join ', ')) }
    return @($ok, $f)
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
function Make-Fixture([string]$Row, [string]$Arc) {
    $o = & $Python -I $MkLink309 $Row $Arc 2>&1
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($Arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}

# Unpack (Alt+F9) of the whole archive into tgt with "Delete archive after unpacking"; $Want = expected
# files; $BoxName = a box naming this member is required (else nothing may be asked); $ArcGone = the
# archive must be deleted afterwards (else kept)
function Unpack-Row([string]$Case, $Want, [string]$BoxName, [switch]$ArcGone) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\src\t.tar'; $tgt = $d + '\tgt'
    try { NewDir ($d + '\src'); NewDir $tgt; Make-Fixture $Case $arc }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 851 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Unpack') { throw ("851 opened '{0}', not the Unpack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        Set-Field $dlg 210 $tgt
        $b = Find-Btn $dlg 6210
        if (-not $b -or -not [Drv098f]::IsWindowEnabled($b)) { throw 'the box "Delete archive after unpacking" (6210) is missing or disabled' }
        [void][Drv098f]::Send($b, 0x00F1, 1, 0, 5000)   # BM_SETCHECK BST_CHECKED
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 90 @(1, 6)
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Tgt $tgt $Want
        $kept = [IO.File]::Exists($LP + $arc)
        $asked = ($msgs -ne 'no window')
        $named = $BoxName -and $msgs.Contains($BoxName)
        $ok = $c[0] -and (-not $fatal) -and ($kept -ne [bool]$ArcGone)
        if ($BoxName) { $ok = $ok -and $named -and ($r.Messages.Count -eq 1) } else { $ok = $ok -and (-not $asked) }
        Row $Case 'RUN' (V $ok) ('{0}; archive kept: {1} (want {2}); box naming the member: {3} (boxes: {5}); windows: {4}' -f $c[1], $kept, (-not $ArcGone), $named, (Tail $msgs 260), $r.Messages.Count)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

function Copy-Row([string]$Case, $Want) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\t.tar'; $tgt = $d + '\tgt'
    try { NewDir $d; NewDir $tgt; Make-Fixture $Case $arc }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T309', '-l', ('"{0}"' -f $arc), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        $openMsgs = Msgs (Serve $id 10)
        $loc = Get-Loc $id
        if (-not $loc.StartsWith($arc, [StringComparison]::OrdinalIgnoreCase)) { throw ('the archive did not open; panel at: ' + (Tail $loc 80)) }
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        Post-Cmd (Get-Main $id) 727
        $msgs = Msgs (Serve $id 60 @(1, 6))
        End-Row $Case $id $null $before; $id = 0
        $c = Check-Tgt $tgt $Want
        $ok = $c[0] -and ($openMsgs -eq 'no window')
        Row $Case 'RUN' (V $ok) ('{0}; at open: {1}; during the copy: {2}' -f $c[1], (Tail $openMsgs 120), (Tail $msgs 200))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc309_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("link309_probe (feature 309) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; python {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), ((& $Python --version 2>&1) -join ' '))
    Out ''
    $hard = [ordered]@{ 'a.txt' = 'A'; 'sub/c.txt' = 'C'; 'sub/b.txt' = 'A'; 'sub/d.txt' = 'A' }
    Unpack-Row 'UNP-HARD-DEL' $hard -ArcGone
    $t = (Cjk 40) + '.txt'
    Unpack-Row 'UNP-HARD-PAX-DEL' ([ordered]@{ $t = 'L'; ('sub/' + (Cjk 40 0x4F00) + '.txt') = 'L' }) -ArcGone
    Unpack-Row 'UNP-HARD-GNU-DEL' ([ordered]@{ (('g' * 120) + '.txt') = 'G'; 'sub/h.txt' = 'G' }) -ArcGone
    Unpack-Row 'UNP-HARD-MISSING-DEL' ([ordered]@{ 'ok.txt' = 'K' }) -BoxName 'b.txt'
    Unpack-Row 'UNP-SYM-DEL' ([ordered]@{ 'a.txt' = 'A' }) -BoxName 's.txt'
    Unpack-Row 'UNP-HARD-TWIN-DEL' ([ordered]@{ 'a.txt' = 'A' }) -ArcGone
    Unpack-Row 'UNP-HARD-DOTDOT-DEL' ([ordered]@{ 'a.txt' = 'A'; 's/a.txt' = 'S' }) -BoxName 'b.txt'
    Copy-Row 'COPY-HARD' $hard
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
