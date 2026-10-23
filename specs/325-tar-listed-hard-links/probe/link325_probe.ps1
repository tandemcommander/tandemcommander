<#
.SYNOPSIS
    Feature 325 probe (backlog item tar-copy-of-listed-files-leaves-hard-links-out): the hard-link
    members of a tar are listed in the panel as files and a Copy of them - also without the file they
    name - extracts the content of that file; a link that cannot be reproduced is reported.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\t.tar (or t.tar.gz) made by Python's
    tarfile through mklink325.py (next to this script) and an empty <row>\tgt. The left panel opens
    the archive folder <arc>\sub (or the archive root), the right panel shows tgt.
      COPY-INSIDE      a.txt, sub/c.txt, hard links sub/b.txt -> a.txt and ./sub/d.txt -> ./a.txt; inside
                       sub: Select All (842), Copy (727) -> b.txt = d.txt = 'A', c.txt, nothing asked
      COPY-INSIDE-GZ   the same tar gzip-compressed (the stream is read again from its start)
      COPY-CHAIN       a.txt (128 KiB), sub/c.txt, sub/b.txt -> a.txt, sub/e.txt -> sub/b.txt; inside sub:
                       Select All, Copy -> b.txt = e.txt = a.txt's content, c.txt, nothing asked
      COPY-MISSING     sub/c.txt, sub/b.txt -> missing.txt; inside sub: Select All, Copy -> c.txt and one
                       box naming b.txt (it was left out without a word)
      COPY-SYM         a.txt, sub/c.txt, symbolic link sub/s.txt; inside sub: Select All, Copy -> c.txt,
                       nothing asked (symbolic links stay unlisted)
      COPY-FOCUSED     the COPY-INSIDE tar; inside sub: End focuses d.txt, Copy -> only d.txt = 'A'
      COPY-EXIST       the COPY-CHAIN tar, tgt\e.txt exists ('old'); inside sub: End focuses e.txt, Copy,
                       exactly one box: the overwrite question showing the new size 131 072 (a.txt's;
                       its name fields are not readable by the driver), Yes -> e.txt = a.txt's content
      COPY-ROOT        the COPY-INSIDE tar at the archive root: Select All, Copy -> a.txt, sub/b.txt,
                       sub/c.txt, sub/d.txt (feature 309's COPY-HARD)
      VIEW-LINK        the COPY-INSIDE tar; inside sub: End focuses d.txt, F3 (742) -> a viewer of d.txt,
                       no message box, the disk-cache copy it shows holds a.txt's content
    Rows of review 1 (a "tar -u" archive: a.dat 'OLD', sub/c.txt, sub/b.txt -> a.dat, a.dat 'NEWER',
    sub/b.txt -> a.dat - tar extracts b.txt as NEWER):
      UNP-UPD-DEL      Unpack (Alt+F9) of <row>\src\t.tar, mask *.txt (521), "Delete archive after
                       unpacking" -> sub/b.txt = 'NEWER', sub/c.txt, nothing asked, archive deleted
      COPY-UPD         inside sub: Select All, Copy -> b.txt = 'NEWER', c.txt, nothing asked
      COPY-SKIP        the COPY-INSIDE tar, tgt\b.txt exists ('old'); inside sub: Select All, Copy, Skip at
                       the overwrite question -> b.txt 'old', c.txt, d.txt = 'A' (the data is written
                       under the next link of the group), exactly one box (the question)
    Rows of review 2 (Unpack with a mask + "Delete archive after unpacking"):
      UNP-RELINK-DEL   a.txt 'A', z.txt 'Z', sub/c.txt, a.txt -> z.txt (a.txt redefined), sub/b.txt ->
                       a.txt; mask "a.txt;*b.txt" -> a.txt = sub/b.txt = 'Z' (tar's result), archive
                       deleted; one question: a.txt is written twice by the operation (as on main)
      UNP-CASE-DEL     a.txt, sub/c.txt, sub/b.txt -> a.txt, then SUB/B.TXT 'NEW' (the same file on
                       Windows); mask "*b.txt" -> sub/b.txt = 'NEW', nothing asked, archive deleted
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
$Root = $TempRoot + '\tc325'
$StartDir = $Root + '\start'
$MkLink325 = Join-Path $Here 'mklink325.py'
$Big = '0123456789abcdef' * 8192

function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) }
# compares tgt with $Want (names compared as the file system does - case-insensitively): @(ok, facts)
function Check-Tgt([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $ok = ($files.Count -eq $Want.Count)
    $missing = @($Want.Keys | Where-Object { $files -notcontains $_ })
    $bad = @($Want.Keys | Where-Object { $files -contains $_ -and (Content $Tgt $_) -cne $Want[$_] })
    if ($missing.Count -or $bad.Count) { $ok = $false }
    $f = ('tgt: {0} of {1} files ({2})' -f $files.Count, $Want.Count, ($files -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}
function Make-Fixture([string]$Row, [string]$Arc) {
    $o = & $Python -I $MkLink325 $Row $Arc 2>&1
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($Arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}
# starts the program with the left panel in $Left (an archive path) and the right one in $Tgt
function Start-Arc([string]$Left, [string]$Tgt, [string]$Arc) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T325', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Tgt), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 2000
    $openMsgs = Msgs (Serve $id 10)
    $loc = Get-Loc $id
    if (-not $loc.StartsWith($Left, [StringComparison]::OrdinalIgnoreCase)) { throw ('the archive folder did not open; panel at: ' + (Tail $loc 80) + '; at open: ' + (Tail $openMsgs 160)) }
    return @($id, $openMsgs)
}

# $How: 'all' = Select All + Copy; 'end' = End (focus the last item) + Copy; $Sub = open <arc>\sub;
# $BoxName = exactly one box naming this member is required (else no box but the overwrite question
# when $Exist); $Exist = file created in tgt before (name, content); $ExistSize = the size the overwrite
# question must show (regex); $Answer = the button ids answered (OK / Yes, or Skip 173)
function Copy-Row([string]$Case, [string]$How, [switch]$Sub, $Want, [string]$BoxName, $Exist, [string]$ExistSize = '131\D?072', [int[]]$Answer = @(1, 6)) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\t.tar'; if ($Case.EndsWith('-GZ')) { $arc += '.gz' }
    $tgt = $d + '\tgt'
    try { NewDir $d; NewDir $tgt; Make-Fixture $Case $arc; if ($Exist) { WriteFile ($tgt + '\' + $Exist[0]) $Exist[1] } }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $left = $arc; if ($Sub) { $left = $arc + '\sub' }
        $s = Start-Arc $left $tgt $arc; $id = $s[0]; $openMsgs = $s[1]
        if ($How -eq 'all') { Post-Cmd (Get-Main $id) 842 } else { Key $id 0x23 }
        Start-Sleep -Milliseconds 800
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 60 $Answer
        $msgs = Msgs $r
        End-Row $Case $id $null $before; $id = 0
        $c = Check-Tgt $tgt $Want
        $boxes = @($r.Messages | Where-Object { $_ -notmatch "^\[#32770 'Copy'\]" })
        $ok = $c[0] -and ($openMsgs -eq 'no window')
        if ($BoxName) { $ok = $ok -and ($boxes.Count -eq 1) -and $boxes[0].Contains($BoxName) }
        elseif ($Exist) { $ok = $ok -and ($boxes.Count -eq 1) -and $boxes[0].Contains("'Confirm File Overwrite'") -and ($boxes[0] -match $ExistSize) }
        else { $ok = $ok -and ($boxes.Count -eq 0) }
        Row $Case 'RUN' (V $ok) ('{0}; boxes besides the Copy dialog: {1}; windows: {2}' -f $c[1], $boxes.Count, (Tail $msgs 300))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

# Unpack (Alt+F9) of the whole archive with mask $Mask into tgt, "Delete archive after unpacking"
# checked; $Want = expected files (paths below tgt); nothing may be asked but $Questions overwrite
# questions (answered Yes); $ArcGone = deleted afterwards
function Unpack-Row([string]$Case, [string]$Mask, $Want, [switch]$ArcGone, [int]$Questions = 0) {
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
        foreach ($f in @(@(210, $tgt), @(521, $Mask))) {
            $ctl = Find-Ctl $dlg $f[0]
            if ($ctl -eq [IntPtr]::Zero) { throw ('field {0} not found' -f $f[0]) }
            [void][Drv098f]::SetText($ctl, $f[1], 5000)
            if ([Drv098f]::GetText($ctl, 5000) -cne $f[1]) { throw ('field {0} did not take the text' -f $f[0]) }
        }
        $b = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq 6210 }) | Select-Object -First 1
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
        $asked = @($r.Messages | Where-Object { $_ -match "^\[#32770 'Confirm File Overwrite'\]" })
        $ok = $c[0] -and (-not $fatal) -and ($kept -ne [bool]$ArcGone) -and ($r.Messages.Count -eq $Questions) -and ($asked.Count -eq $Questions)
        Row $Case 'RUN' (V $ok) ('{0}; archive kept: {1} (want {2}); windows: {3}' -f $c[1], $kept, (-not $ArcGone), (Tail $msgs 260))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

function View-Row([string]$Case, [string]$Name, [string]$Content) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\t.tar'; $tgt = $d + '\tgt'
    try { NewDir $d; NewDir $tgt; Make-Fixture $Case $arc }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        $s = Start-Arc ($arc + '\sub') $tgt $arc; $id = $s[0]; $openMsgs = $s[1]
        Key $id 0x23
        Start-Sleep -Milliseconds 800
        $title = Which-Viewer $id
        $msgs = Msgs (Serve $id 10)
        # the viewer's title starts with the disk-cache copy it shows: read it while the program runs
        $shown = '<not read>'
        $vp = ($title -split ' \[')[0]
        if ($vp.EndsWith('\' + $Name) -and [IO.File]::Exists($vp)) { $shown = [IO.File]::ReadAllText($vp) }
        End-Row $Case $id $null $before; $id = 0
        $ok = ($openMsgs -eq 'no window') -and ($msgs -eq 'no window') -and (-not $title.StartsWith('<')) -and $title.Contains($Name) -and ($shown -ceq $Content)
        Row $Case 'RUN' (V $ok) ('viewer: {0}; content shown: {1} (want {2}); after: {3}' -f (Tail $title 200), (Tail $shown 40), $Content, (Tail $msgs 200))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc325_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("link325_probe (feature 325) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; python {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), ((& $Python --version 2>&1) -join ' '))
    Out ''
    $inside = [ordered]@{ 'b.txt' = 'A'; 'c.txt' = 'C'; 'd.txt' = 'A' }
    Copy-Row 'COPY-INSIDE' 'all' -Sub $inside
    Copy-Row 'COPY-INSIDE-GZ' 'all' -Sub $inside
    Copy-Row 'COPY-CHAIN' 'all' -Sub ([ordered]@{ 'b.txt' = $Big; 'c.txt' = 'C'; 'e.txt' = $Big })
    Copy-Row 'COPY-MISSING' 'all' -Sub ([ordered]@{ 'c.txt' = 'C' }) -BoxName 'b.txt'
    Copy-Row 'COPY-SYM' 'all' -Sub ([ordered]@{ 'c.txt' = 'C' })
    Copy-Row 'COPY-FOCUSED' 'end' -Sub ([ordered]@{ 'd.txt' = 'A' })
    Copy-Row 'COPY-EXIST' 'end' -Sub ([ordered]@{ 'e.txt' = $Big }) -Exist @('e.txt', 'old')
    Copy-Row 'COPY-ROOT' 'all' ([ordered]@{ 'a.txt' = 'A'; 'sub/b.txt' = 'A'; 'sub/c.txt' = 'C'; 'sub/d.txt' = 'A' })
    View-Row 'VIEW-LINK' 'd.txt' 'A'
    Unpack-Row 'UNP-UPD-DEL' '*.txt' ([ordered]@{ 'sub/b.txt' = 'NEWER'; 'sub/c.txt' = 'C' }) -ArcGone
    Copy-Row 'COPY-UPD' 'all' -Sub ([ordered]@{ 'b.txt' = 'NEWER'; 'c.txt' = 'C' })
    Unpack-Row 'UNP-RELINK-DEL' 'a.txt;*b.txt' ([ordered]@{ 'a.txt' = 'Z'; 'sub/b.txt' = 'Z' }) -ArcGone -Questions 1
    Unpack-Row 'UNP-CASE-DEL' '*b.txt' ([ordered]@{ 'sub/b.txt' = 'NEW' }) -ArcGone
    Copy-Row 'COPY-SKIP' 'all' -Sub ([ordered]@{ 'b.txt' = 'old'; 'c.txt' = 'C'; 'd.txt' = 'A' }) -Exist @('b.txt', 'old') -ExistSize ', \d' -Answer @(1, 173)
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
