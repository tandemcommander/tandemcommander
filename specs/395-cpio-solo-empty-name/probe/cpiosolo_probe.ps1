<#
.SYNOPSIS
    Probe for backlog item unpack-silently-drops-a-cpio-file-whose-only-name-normalizes: a regular
    file whose data is stored under a name that normalizes to nothing ("", ".", "./") and reaches no
    other name (a single name, or a hard-link group whose other names are absent) must be reported by
    a whole Unpack, with the operation failing (archive kept) - never success while the data stayed
    in the archive.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder) made by mkcpiosolo.py (next to this script):
    newc cpio unless the row says CRC (crc "070702"), ODC (odc "070707"), RPM (a minimal rpm whose
    payload is a newc cpio) or TAR (ustar). <E> = the empty name: DOT ".", DOTSLASH "./", NUL "".
      SOLO layout:   <E> regular, nlink 1, 'AAA' (ZERO: size 0), then ok.txt 'K'
      ORPHAN layout: <E> regular, nlink 2 (inode 5, the other name absent), 'AAA' (ZERO: size 0), ok.txt
      WAIT control:  a.txt (size 0) and <E> ('AAA') one file (feature 394), ok.txt
      DOTDIR control: the folder "." (cpio) / "./" (tar), ok.txt
    Unpack rows: the left panel shows <row>\src, Home, End focuses the archive, Alt+F9 (851), the path
    field (210) set to <row>\tgt, the mask (521) "*.*" unless the row gives one, "Delete archive after
    unpacking" (6210) checked, OK, every box answered OK / Yes.
      UNP-SOLO-DOT-DEL, -DOTSLASH-, -NUL-, UNP-CRC-SOLO-DOT-DEL, UNP-ODC-SOLO-DOT-DEL,
      UNP-RPM-SOLO-DOT-DEL, UNP-ORPHAN-DOT-DEL, UNP-CRC-ORPHAN-DOT-DEL, UNP-TAR-SOLO-DOT-DEL
                                   -> ok.txt, a "(123)" box naming the member, archive KEPT
      UNP-SOLO-DOT-ZERO-DEL, UNP-ORPHAN-DOT-ZERO-DEL, UNP-DOTDIR-DEL, UNP-TAR-DOTDIR-DEL
                                   -> ok.txt, nothing asked, archive deleted (controls)
      UNP-WAIT-DOT-DEL             -> a.txt = AAA, ok.txt, nothing asked, archive deleted (394)
      UNP-SOLO-DOT-MASK            mask "*.txt" -> ok.txt, nothing asked, archive deleted (not asked)
    Rows added after review 1 (odc / binary repeat a hard-linked file's data with every name; BIN = the
    binary cpio; LINK: a.txt and <E> one file, both 'AAA', a.txt first; LINKFIRST: <E> first; DFIRST:
    newc, <E> 'AAA' then a.txt size 0):
      UNP-ODC-LINK-DOT-DEL, UNP-ODC-LINKFIRST-DOT-DEL, UNP-BIN-LINK-DOT-DEL
                                   -> a.txt = AAA, ok.txt, nothing asked, archive deleted
      UNP-ODC-ORPHAN-DOT-DEL, UNP-BIN-ORPHAN-DOT-DEL, UNP-BIN-SOLO-DOT-DEL
                                   -> ok.txt, a "(123)" box, archive KEPT
      UNP-DFIRST-DOT-MASKQ         mask "?" (matches "." only) -> nothing extracted, "(123)", archive KEPT
    Copy row: the left panel opens <row>\t.cpio, the right shows <row>\tgt; Select All (842), Copy
    (727), boxes OK.
      COPY-SOLO-DOT                -> only the Copy dialog, tgt ok.txt (the member is not listed - not asked)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Copied from specs\394-cpio-empty-name-link\probe\cpioempty_probe.ps1.
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
$Root = $TempRoot + '\tc395'
$StartDir = $Root + '\start'
$MkCpio = Join-Path $Here 'mkcpiosolo.py'

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
    # every member of the fixtures has mtime 1000000000 (2001-09-09 01:46:40 UTC)
    $wantTime = [DateTime]::new(2001, 9, 9, 1, 46, 40, [DateTimeKind]::Utc)
    $badTime = @($files | Where-Object { [IO.File]::GetLastWriteTimeUtc($LP + $Tgt + '\' + $_.Replace('/', '\')) -ne $wantTime })
    if ($badTime.Count) { $ok = $false; $f += ('; wrong time: ' + ((@($badTime | ForEach-Object { '{0}={1:u}' -f (Esc $_), [IO.File]::GetLastWriteTimeUtc($LP + $Tgt + '\' + $_.Replace('/', '\')) })) -join ', ')) }
    elseif ($files.Count) { $f += '; times 2001-09-09 01:46:40Z' }
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
function Arc-Ext([string]$Row) { if ($Row -like '*-RPM-*') { return 'rpm' }; if ($Row -like '*-TAR-*') { return 'tar' }; return 'cpio' }
function Make-Fixture([string]$Row, [string]$Arc) {
    $o = & $Python -I $MkCpio $Row $Arc 2>&1
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($Arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}

# Unpack (Alt+F9) of the whole archive into tgt; $Want = expected files; $NeedMsg = a regular expression
# the windows must match (else nothing may be asked); $ArcGone = the archive must be deleted afterwards;
# $Mask = the mask typed into the dialog (else its default "*.*")
function Unpack-Row([string]$Case, $Want, [switch]$ArcGone, [string]$NeedMsg, [string]$Mask) {
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
        if ($Mask) { Set-Field $dlg 521 $Mask }
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
# windows during the copy must match (else nothing may be asked)
function Copy-Row([string]$Case, $Want, [string]$NeedCopyMsg) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\t.' + (Arc-Ext $Case); $tgt = $d + '\tgt'
    try { NewDir $d; NewDir $tgt; Make-Fixture $Case $arc }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T395', '-l', ('"{0}"' -f $arc), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
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
        else {
            # the core's own Copy dialog is answered OK; no other box (an error names its code "(n)")
            $mOk = ($msgs -notmatch '\(\d+\)') -and (@($msgs -split '\[#32770 ' | Where-Object { $_ -and $_ -notlike "'Copy'*" }).Count -eq 0)
            if (-not $mOk) { $ok = $false }
            $facts += ('; only the Copy dialog: ' + $mOk)
        }
        Row $Case 'RUN' (V $ok) ('{0}; at open: {1}; windows: {2}' -f $facts, (Tail $openMsgs 160), (Tail $msgs 200))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc395_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cpiosolo_probe (backlog item unpack-silently-drops-a-cpio-file-whose-only-name-normalizes) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; python {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), ((& $Python --version 2>&1) -join ' '))
    Out ''
    $ok1 = [ordered]@{ 'ok.txt' = 'K' }
    $both = [ordered]@{ 'a.txt' = 'AAA'; 'ok.txt' = 'K' }
    $rep = '\(123\)'
    Unpack-Row 'UNP-SOLO-DOT-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-SOLO-DOTSLASH-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-SOLO-NUL-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-CRC-SOLO-DOT-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-ODC-SOLO-DOT-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-RPM-SOLO-DOT-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-ORPHAN-DOT-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-CRC-ORPHAN-DOT-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-TAR-SOLO-DOT-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-SOLO-DOT-ZERO-DEL' $ok1 -ArcGone
    Unpack-Row 'UNP-ORPHAN-DOT-ZERO-DEL' $ok1 -ArcGone
    Unpack-Row 'UNP-DOTDIR-DEL' $ok1 -ArcGone
    Unpack-Row 'UNP-TAR-DOTDIR-DEL' $ok1 -ArcGone
    Unpack-Row 'UNP-WAIT-DOT-DEL' $both -ArcGone
    Unpack-Row 'UNP-SOLO-DOT-MASK' $ok1 -ArcGone -Mask '*.txt'
    # review 1: odc / binary repeat a hard-linked file's data with every name
    Unpack-Row 'UNP-ODC-LINK-DOT-DEL' $both -ArcGone
    Unpack-Row 'UNP-ODC-LINKFIRST-DOT-DEL' $both -ArcGone
    Unpack-Row 'UNP-ODC-ORPHAN-DOT-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-BIN-SOLO-DOT-DEL' $ok1 -NeedMsg $rep
    Unpack-Row 'UNP-BIN-LINK-DOT-DEL' $both -ArcGone
    Unpack-Row 'UNP-BIN-ORPHAN-DOT-DEL' $ok1 -NeedMsg $rep
    # review 1: newc data-first, the mask "?" matches "." but not a.txt - reported at the end of the archive
    Unpack-Row 'UNP-DFIRST-DOT-MASKQ' ([ordered]@{}) -NeedMsg $rep -Mask '?'
    Copy-Row 'COPY-SOLO-DOT' $ok1
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
