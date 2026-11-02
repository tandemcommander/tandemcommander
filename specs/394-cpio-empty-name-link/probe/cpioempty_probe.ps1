<#
.SYNOPSIS
    Probe for backlog item a-cpio-hard-link-whose-data-name-normalizes-to-empty-is: in a newc / crc cpio
    (or an rpm) the member carrying the data of a hard-linked file has a name that normalizes to
    nothing ("", ".", "./"); the file's other names must get the data, or be reported with the
    operation failing (archive kept) - never an empty file with success.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder) made by mkcpioempty.py (next to this script):
    newc cpio unless the row says CRC (crc "070702" with the data checksum; BADSUM = the carrier's
    checksum off by one) or RPM (a minimal rpm whose payload is a newc cpio). <E> = the carrier's name:
    DOT ".", DOTSLASH "./", NUL "" (name size 1).
      default layout: a.txt (size 0) and <E> ('AAA') are one file (inode 5, nlink 2; GNU cpio order -
                      the data with the last name), then ok.txt 'K'
      FIRST layout:   <E> ('AAA') first, then a.txt (size 0), ok.txt
      DOTDIR control: the folder member "." (GNU cpio's find . | cpio -o), ok.txt
    Unpack rows: the left panel shows <row>\src, Home, End focuses the archive, Alt+F9 (851), the path
    field (210) set to <row>\tgt, mask "*.*", "Delete archive after unpacking" (6210) checked, OK, every
    box answered OK / Yes.
      UNP-EMPTY-DOT-DEL            -> a.txt = AAA, ok.txt, nothing asked, archive deleted
      UNP-EMPTY-DOTSLASH-DEL       -> the same
      UNP-EMPTY-NUL-DEL            -> the same
      UNP-CRC-EMPTY-DOT-DEL        -> the same (crc, the checksum right)
      UNP-CRC-EMPTY-DOT-BADSUM-DEL -> a checksum box, a.txt not written, archive KEPT
      UNP-RPM-EMPTY-DOT-DEL        -> a.txt = AAA, ok.txt, nothing asked, the rpm deleted
      UNP-EMPTY-DOT-FIRST-DEL      -> ok.txt, a "(2)" box naming a.txt, archive KEPT
      UNP-DOTDIR-DEL               -> ok.txt, nothing asked, archive deleted (control)
    Copy rows: the left panel opens <row>\t.<ext>, the right shows <row>\tgt; Select All (842), Copy
    (727), boxes OK.
      COPY-EMPTY-DOT               -> no window at open, tgt a.txt = AAA, ok.txt
      COPY-EMPTY-DOT-FIRST         -> no window at open, a "(2)" box naming a.txt, tgt ok.txt
    View row: the left panel opens t.cpio; Home, End, F3 (742); the copy the disk cache made is read.
      VIEW-EMPTY-DOT               a.txt (size 0) and "." ('AAA'), nothing else -> the viewer, cached a.txt = AAA
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Copied from specs\393-cpio-long-name\probe\cpio393_probe.ps1.
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
$Root = $TempRoot + '\tc394'
$StartDir = $Root + '\start'
$MkCpio = Join-Path $Here 'mkcpioempty.py'

function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) }
# compares tgt with $Want: returns @(ok, facts)
function Check-Tgt([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $ok = ($files.Count -eq $Want.Count)
    $missing = @($Want.Keys | Where-Object { $files -notcontains $_ })
    $bad = @($Want.Keys | Where-Object { $files -contains $_ -and (Content $Tgt $_) -cne $Want[$_] })
    if ($missing.Count -or $bad.Count) { $ok = $false }
    $f = ('tgt: {0} of {1} files' -f $files.Count, $Want.Count)
    if ($missing.Count) { $f += ('; missing: ' + ((@($missing | ForEach-Object { Esc $_ })) -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ((@($bad | ForEach-Object { '{0}="{1}"' -f (Esc $_), (Esc (Content $Tgt $_)) })) -join ', ')) }
    $f += ('; files: ' + ((@($files | ForEach-Object { '{0}({1})' -f (Esc $_), (Content $Tgt $_).Length })) -join ', '))
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
function Arc-Ext([string]$Row) { if ($Row -like '*-RPM-*') { return 'rpm' }; return 'cpio' }
function Make-Fixture([string]$Row, [string]$Arc) {
    $o = & $Python -I $MkCpio $Row $Arc 2>&1
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($Arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}

# Unpack (Alt+F9) of the whole archive into tgt; $Want = expected files; $NeedMsg = a regular expression
# the windows must match (else nothing may be asked); $ArcGone = the archive must be deleted afterwards
function Unpack-Row([string]$Case, $Want, [switch]$ArcGone, [string]$NeedMsg) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\src\t.' + (Arc-Ext $Case); $tgt = $d + '\tgt'
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
        $ok = $c[0] -and (-not $fatal) -and ($kept -ne [bool]$ArcGone)
        if ($NeedMsg) { $ok = $ok -and ($msgs -match $NeedMsg) } else { $ok = $ok -and (-not $asked) }
        Row $Case 'RUN' (V $ok) ('{0}; archive kept: {1} (want {2}); windows: {3}' -f $c[1], $kept, (-not $ArcGone), (Tail $msgs 260))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# Copy of everything listed; no window may show at opening; $NeedCopyMsg = a regular expression the
# windows during the copy must match
function Copy-Row([string]$Case, $Want, [string]$NeedCopyMsg) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\t.' + (Arc-Ext $Case); $tgt = $d + '\tgt'
    try { NewDir $d; NewDir $tgt; Make-Fixture $Case $arc }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T394', '-l', ('"{0}"' -f $arc), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        $openMsgs = Msgs (Serve $id 10)
        $loc = Get-Loc $id
        if (-not $loc.StartsWith($arc, [StringComparison]::OrdinalIgnoreCase)) {
            End-Row $Case $id $null $before; $id = 0
            Row $Case 'RUN' 'FAIL' ('the archive did not open; panel at: ' + (Tail $loc 80) + '; at open: ' + (Tail $openMsgs 200))
            return
        }
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        Post-Cmd (Get-Main $id) 727
        $msgs = Msgs (Serve $id 60 @(1, 6))
        End-Row $Case $id $null $before; $id = 0
        $c = Check-Tgt $tgt $Want
        $ok = $c[0] -and ($openMsgs -eq 'no window')
        $facts = $c[1]
        if ($NeedCopyMsg) {
            $mOk = $msgs -match $NeedCopyMsg
            if (-not $mOk) { $ok = $false }
            $facts += ('; message during the copy matches ' + $NeedCopyMsg + ': ' + $mOk)
        }
        Row $Case 'RUN' (V $ok) ('{0}; at open: {1}; windows: {2}' -f $facts, (Tail $openMsgs 160), (Tail $msgs 200))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

# F3 on the focused last item of the opened archive (feature 310's View-Row); the copy the disk cache made
# (SAL*.tmp folders created during the row) must hold $Want
function View-Row([string]$Case, [string]$Member, [string]$Want) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\t.cpio'
    try { NewDir $d; Make-Fixture $Case $arc }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports; $t0 = (Get-Date).AddSeconds(-2)
    try {
        $id = Start-Tc $arc
        Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500
        $t = Which-Viewer $id
        $r = Serve $id 8 @(1)
        $copies = @([IO.Directory]::GetDirectories($LP + $TempRoot, 'SAL*.tmp') | Where-Object { [IO.Directory]::GetCreationTime($_) -ge $t0 } | ForEach-Object { $_ + '\' + $Member } | Where-Object { [IO.File]::Exists($_) })
        $content = $(if ($copies.Count) { [IO.File]::ReadAllText($copies[0]) } else { '<no cached copy>' })
        $ok = ($t -notlike '<*') -and ($copies.Count -eq 1) -and ($content -ceq $Want)
        Row $Case 'RUN' (V $ok) ('F3: {0}; cached copies: {1}; content: "{2}" (want {3}){4}' -f (Tail $t 200), $copies.Count, (Esc $content), $Want, $(if ((Msgs $r) -ne 'no window') { '; after: ' + (Tail (Msgs $r) 200) } else { '' }))
        [void](Do-ChangeDir $id $StartDir); [void](Serve $id 8 @(1, 7, 2))
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc394_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cpioempty_probe (backlog item a-cpio-hard-link-whose-data-name-normalizes-to-empty-is) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; python {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), ((& $Python --version 2>&1) -join ' '))
    Out ''
    $ok1 = [ordered]@{ 'ok.txt' = 'K' }
    $both = [ordered]@{ 'a.txt' = 'AAA'; 'ok.txt' = 'K' }
    Unpack-Row 'UNP-EMPTY-DOT-DEL' $both -ArcGone
    Unpack-Row 'UNP-EMPTY-DOTSLASH-DEL' $both -ArcGone
    Unpack-Row 'UNP-EMPTY-NUL-DEL' $both -ArcGone
    Unpack-Row 'UNP-CRC-EMPTY-DOT-DEL' $both -ArcGone
    Unpack-Row 'UNP-CRC-EMPTY-DOT-BADSUM-DEL' ([ordered]@{}) -NeedMsg 'checksum'
    Unpack-Row 'UNP-RPM-EMPTY-DOT-DEL' $both -ArcGone
    Unpack-Row 'UNP-EMPTY-DOT-FIRST-DEL' $ok1 -NeedMsg '\(2\)[^|]*a\.txt'
    Unpack-Row 'UNP-DOTDIR-DEL' $ok1 -ArcGone
    Copy-Row 'COPY-EMPTY-DOT' $both
    Copy-Row 'COPY-EMPTY-DOT-FIRST' $ok1 -NeedCopyMsg '\(2\)[^|]*a\.txt'
    View-Row 'VIEW-EMPTY-DOT' 'a.txt' 'AAA'
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
