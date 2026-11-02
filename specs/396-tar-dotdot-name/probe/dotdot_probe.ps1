<#
.SYNOPSIS
    Probe of the backlog item tar-member-name-with-dotdot-extracted-into-wrong-folder: a tar member whose
    name has a ".." component is listed and extracted where the name points - ".." removes the whole
    previous component and never climbs above the archive root.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\src\t.tar made by Python's tarfile
    through mkdotdot.py (next to this script) and an empty <row>\tgt.
    Unpack rows: the left panel shows <row>\src, Home, End focuses the archive, Alt+F9 (851) opens the
    Unpack dialog, the path field (210) is set to <row>\tgt by WM_SETTEXT, the mask stays "*.*",
    "Delete archive after unpacking" (6210) is checked, OK, every box answered OK / Yes.
      UNP-ROOT-DEL   sub/c.txt, sub/../a.txt, x/y/../b.txt, ../../e.txt, q/../../f.txt (ustar)
                     -> a.txt, sub/c.txt, x/b.txt, e.txt, f.txt; nothing asked; t.tar deleted
                     (the legacy rule: s/a.txt and q/f.txt)
      UNP-OVER-DEL   s/a.txt (S), sub/../a.txt (A)
                     -> a.txt = A, s/a.txt = S; nothing asked; t.tar deleted
                     (the legacy rule: an overwrite question, s/a.txt overwritten by A)
      UNP-GNU-DEL    GNU long name sub/../g*120.txt -> g*120.txt; t.tar deleted
      UNP-PAX-DEL    PAX path sub/../g*120.txt -> g*120.txt; t.tar deleted
      UNP-LINK-DEL   a.txt, s/a.txt, hard link b.txt -> sub/../a.txt (feature 309's rule stays: a link
                     name with ".." is reported) -> a.txt, s/a.txt, a box naming b.txt, t.tar KEPT
    Copy row: the left panel opens t.tar, the right shows tgt; Select All (842), Copy (727), boxes OK.
      COPY-ROOT      the UNP-ROOT tar: the listing's root -> the same 5 files, nothing asked
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\309-tar-link-members\probe\link309_probe.ps1.
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
$Root = $TempRoot + '\tcdotdot'
$StartDir = $Root + '\start'
$MkFix = Join-Path $Here 'mkdotdot.py'

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
    $extra = @($files | Where-Object { -not $Want.Contains($_) })
    $bad = @($Want.Keys | Where-Object { $files -contains $_ -and (Content $Tgt $_) -cne $Want[$_] })
    if ($missing.Count -or $bad.Count -or $extra.Count) { $ok = $false }
    $f = ('tgt: {0} of {1} files' -f $files.Count, $Want.Count)
    if ($missing.Count) { $f += ('; missing {0}: {1}' -f $missing.Count, ((@($missing | Select-Object -First 4 | ForEach-Object { Esc (Short $_) })) -join ', ')) }
    if ($extra.Count) { $f += ('; extra {0}: {1}' -f $extra.Count, ((@($extra | Select-Object -First 4 | ForEach-Object { Esc (Short $_) })) -join ', ')) }
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
    $o = & $Python -I $MkFix $Row $Arc 2>&1
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
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'TDOTDOT', '-l', ('"{0}"' -f $arc), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
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
        $ok = $c[0] -and ($openMsgs -eq 'no window') -and (-not $msgs.Contains('Overwrite'))
        Row $Case 'RUN' (V $ok) ('{0}; at open: {1}; during the copy: {2}' -f $c[1], (Tail $openMsgs 120), (Tail $msgs 200))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tcdotdot_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("dotdot_probe (tar member names with '..') {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; python {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), ((& $Python --version 2>&1) -join ' '))
    Out ''
    $rootWant = [ordered]@{ 'a.txt' = 'A'; 'sub/c.txt' = 'C'; 'x/b.txt' = 'B'; 'e.txt' = 'E'; 'f.txt' = 'F' }
    Unpack-Row 'UNP-ROOT-DEL' $rootWant -ArcGone
    Unpack-Row 'UNP-OVER-DEL' ([ordered]@{ 'a.txt' = 'A'; 's/a.txt' = 'S' }) -ArcGone
    $g = ('g' * 120) + '.txt'
    Unpack-Row 'UNP-GNU-DEL' ([ordered]@{ $g = 'G' }) -ArcGone
    Unpack-Row 'UNP-PAX-DEL' ([ordered]@{ $g = 'G' }) -ArcGone
    Unpack-Row 'UNP-LINK-DEL' ([ordered]@{ 'a.txt' = 'A'; 's/a.txt' = 'S' }) -BoxName 'b.txt'
    Copy-Row 'COPY-ROOT' $rootWant
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
