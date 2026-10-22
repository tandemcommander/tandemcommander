<#
.SYNOPSIS
    Feature 310 probe (backlog item cpio-unpack-drops-links-and-may-delete-archive): a cpio symbolic link
    is reported and fails the unpack, so "Delete archive after unpacking" keeps the archive; the names
    of a hard-linked file in a newc / crc cpio (data only with one of the names) all arrive with the
    file's content.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\src\t.cpio made by mkcpio310.py (next to
    this script) and an empty <row>\tgt.
    Unpack rows: the left panel shows <row>\src, Home, End focuses the archive, Alt+F9 (851) opens the
    Unpack dialog, the path field (210) is set to <row>\tgt by WM_SETTEXT, the mask stays "*.*",
    "Delete archive after unpacking" (6210) is checked, OK, every box answered OK / Yes.
      CPIO-HARD-DEL        newc, GNU cpio / rpm order: c.txt, sub, a.txt + sub/b.txt (size 0) + sub/d.txt
                           (data) one inode -> a.txt, sub/b.txt, sub/d.txt = AAA, nothing asked, deleted
      CPIO-CRC-HARD-DEL    the same in the crc format (070702, checksum)
      CPIO-HARD-FIRST-DEL  newc, the data with the first name: a.txt (F), b.txt (size 0) -> both F
      CPIO-HARD-EMPTY-DEL  newc, an empty file with two names + ok.txt -> e1, e2 empty, ok.txt, deleted
      CPIO-HARD-DEV-DEL    newc, one inode number on two devices: a.txt (8,1 size 0), b.txt (8,2 'B'),
                           c.txt (8,1 'C') -> a.txt = C, b.txt = B, c.txt = C
      CPIO-ODC-HARD-DEL    odc (070707) repeats the data per name -> a.txt, b.txt = O (unchanged)
      CPIO-SYM-DEL         newc, a.txt, symbolic links s.txt and t.txt -> a.txt
                           -> a.txt, exactly one box (naming s.txt), t.cpio KEPT
      CPIO-FIFO-DEL        newc, a named pipe p + ok.txt -> ok.txt, nothing asked, deleted (as tar)
    Copy rows: the left panel opens t.cpio, the right shows tgt; boxes OK.
      COPY-CPIO-ALL        the CPIO-HARD-DEL archive, Select All (842), Copy (727) -> the 4 files, AAA
      COPY-CPIO-ONE        a.txt (size 0), sub, sub/b.txt (the data) one inode; End focuses a.txt,
                           Copy (727) -> tgt holds a.txt = AAA only
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
$Root = $TempRoot + '\tc310'
$StartDir = $Root + '\start'
$MkCpio = Join-Path $Here 'mkcpio310.py'

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
    $f = ('tgt: {0} of {1} files' -f $files.Count, $Want.Count)
    if ($missing.Count) { $f += ('; missing {0}: {1}' -f $missing.Count, ((@($missing | Select-Object -First 4 | ForEach-Object { Esc $_ })) -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ((@($bad | ForEach-Object { '{0}={1}' -f (Esc $_), (Esc (Content $Tgt $_)) })) -join ', ')) }
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
    $o = & $Python -I $MkCpio $Row $Arc 2>&1
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($Arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}

# Unpack (Alt+F9) of the whole archive into tgt with "Delete archive after unpacking"; $Want = expected
# files; $BoxName = a box naming this member is required (else nothing may be asked); $ArcGone = the
# archive must be deleted afterwards (else kept)
function Unpack-Row([string]$Case, $Want, [string]$BoxName, [switch]$ArcGone) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\src\t.cpio'; $tgt = $d + '\tgt'
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

# Copy (F5) from the opened archive into tgt: everything (Select All) or the focused last item (-FocusLast)
function Copy-Row([string]$Case, $Want, [switch]$FocusLast) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\t.cpio'; $tgt = $d + '\tgt'
    try { NewDir $d; NewDir $tgt; Make-Fixture $Case $arc }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T310', '-l', ('"{0}"' -f $arc), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        $openMsgs = Msgs (Serve $id 10)
        $loc = Get-Loc $id
        if (-not $loc.StartsWith($arc, [StringComparison]::OrdinalIgnoreCase)) { throw ('the archive did not open; panel at: ' + (Tail $loc 80)) }
        if ($FocusLast) { Key $id 0x23; Start-Sleep -Milliseconds 500 }
        else { Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800 }
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

$backup = Join-Path $env:TEMP 'tc310_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cpio310_probe (feature 310) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; python {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), ((& $Python --version 2>&1) -join ' '))
    Out ''
    $hard = [ordered]@{ 'c.txt' = 'C'; 'a.txt' = 'AAA'; 'sub/b.txt' = 'AAA'; 'sub/d.txt' = 'AAA' }
    Unpack-Row 'CPIO-HARD-DEL' $hard -ArcGone
    Unpack-Row 'CPIO-CRC-HARD-DEL' $hard -ArcGone
    Unpack-Row 'CPIO-HARD-FIRST-DEL' ([ordered]@{ 'a.txt' = 'F'; 'b.txt' = 'F' }) -ArcGone
    Unpack-Row 'CPIO-HARD-EMPTY-DEL' ([ordered]@{ 'e1.txt' = ''; 'e2.txt' = ''; 'ok.txt' = 'K' }) -ArcGone
    Unpack-Row 'CPIO-HARD-DEV-DEL' ([ordered]@{ 'a.txt' = 'C'; 'b.txt' = 'B'; 'c.txt' = 'C' }) -ArcGone
    Unpack-Row 'CPIO-ODC-HARD-DEL' ([ordered]@{ 'a.txt' = 'O'; 'b.txt' = 'O' }) -ArcGone
    Unpack-Row 'CPIO-SYM-DEL' ([ordered]@{ 'a.txt' = 'A' }) -BoxName 's.txt'
    Unpack-Row 'CPIO-FIFO-DEL' ([ordered]@{ 'ok.txt' = 'K' }) -ArcGone
    Copy-Row 'COPY-CPIO-ALL' $hard
    Copy-Row 'COPY-CPIO-ONE' ([ordered]@{ 'a.txt' = 'AAA' }) -FocusLast
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
