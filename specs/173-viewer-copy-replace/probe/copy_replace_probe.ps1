<#
.SYNOPSIS
    Feature 173 probe: the viewer's Copy to File (6067) onto an existing file never loses that
    file - the new content takes its place in one step, or the old file stays.

.DESCRIPTION
    Each row: a source a.dat ("the new content"), a target folder with an existing file; the
    viewer opens a.dat (End, F3), Copy to File, the target typed, Save, "already exists" Yes.
    PASS = afterwards the target holds the new content, or - where the replace cannot happen - its
    old content (never missing), and no temporary sal*.tmp is left without a word.
      PLAIN   a plain target (created 2001, hidden): replaced; KEPT - it keeps its creation time
              and attributes (a delete and a move made a new file)
      HELD    the target held open by another program that allows deleting it (FILE_SHARE_DELETE):
              a delete "succeeds" (pending) and the move onto the name fails - the probe closes its
              handle after the viewer is done
      LOCKED  the target held open without FILE_SHARE_DELETE: the replace fails - the old file
              stays, the temporary file is removed, the error is shown
      RO      a read-only target
      SELF    the viewed file onto itself
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc173'
$StartDir = $Root + '\start'
$NewBody = 'the new content from the viewer'
$OldBody = 'the old content of the target'

function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function NameBox([IntPtr]$Dlg) {
    if (-not (Kid $Dlg 1121 $null)) { return $null }
    return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::Cls([Drv098f]::GetParent($_)) -match 'ComboBox' -and ([Drv098f]::GetDlgCtrlID($_) -eq 1001 -or [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148) }) | Select-Object -First 1
}
# Copy to File in the viewer window: the save dialog, the name typed, Save
function Drive-Copy([int]$Id, [IntPtr]$Vw, [string]$Full) {
    $known = Get-Tops $Id
    Post-Cmd $Vw 6067
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 20 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($c) {
            $sw2 = [Diagnostics.Stopwatch]::StartNew()
            while ($sw2.Elapsed.TotalSeconds -lt 5 -and -not (NameBox $c)) { Start-Sleep -Milliseconds 200 }
            if ((NameBox $c)) { Start-Sleep -Milliseconds 600; $od = $c; break }
            return ('not a save dialog: ' + (WinDesc $c))
        }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) { return 'no save dialog' }
    [void][Drv098f]::SetText((NameBox $od), $Full, 5000)
    $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
    if ($ok) { Click $ok } else { Post-Cmd $od 1 }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
    if ([Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Post-Cmd $od 2; Start-Sleep -Milliseconds 800; return 'the save dialog stayed open' }
    return ''
}
function Body([string]$p) { if (-not [IO.File]::Exists($LP + $p)) { return $null }; return [IO.File]::ReadAllText($LP + $p) }
function Temps([string]$d) { return @([IO.Directory]::GetFiles($LP + $d, 'sal*.tmp') | ForEach-Object { [IO.Path]::GetFileName($_) }) }

function Run-Case([string]$Case) {
    if (-not (Want $Case)) { return }
    $sd = $Root + '\src-' + $Case; NewDir $sd
    $src = $sd + '\a.dat'
    [IO.File]::WriteAllText($LP + $src, $NewBody, (New-Object Text.ASCIIEncoding))
    $td = $Root + '\dst-' + $Case; NewDir $td
    $target = $td + '\t.txt'
    if ($Case -eq 'SELF') { $td = $sd; $target = $src; $want = $NewBody }
    else { [IO.File]::WriteAllText($LP + $target, $OldBody, (New-Object Text.ASCIIEncoding)); $want = $NewBody }
    if ($Case -eq 'RO') { [IO.File]::SetAttributes($LP + $target, [IO.FileAttributes]::ReadOnly) }
    $born = [DateTime]::new(2001, 2, 3, 4, 5, 6, [DateTimeKind]::Utc)
    if ($Case -eq 'PLAIN') { [IO.File]::SetCreationTimeUtc($LP + $target, $born); [IO.File]::SetAttributes($LP + $target, [IO.FileAttributes]::Hidden) }
    $held = $null
    if ($Case -eq 'HELD') { $held = [IO.File]::Open($LP + $target, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)) }
    if ($Case -eq 'LOCKED') { $held = [IO.File]::Open($LP + $target, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $sd
        Key $id 0x23
        $vw = Open-ByCmd $id 742 15
        if ($vw -eq [IntPtr]::Zero) { Row $Case 'VIEW' 'NOT DRIVEN' 'no viewer window'; return }
        Start-Sleep -Milliseconds 1000
        $note = Drive-Copy $id $vw $target
        $after = Serve $id 20 @(6, 1)
        if ($held) { $held.Close(); $held = $null; Start-Sleep -Milliseconds 300 }
        [void][Drv098f]::PostMessageW($vw, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 800
        End-Row $Case $id $null $before; $id = 0
        $b = Body $target
        $tmps = Temps $td
        $msgs = Msgs $after
        $tmpNamed = @($tmps | Where-Object { $msgs -like ('*' + $_ + '*') })
        $ok = ($b -ceq $want -or ($Case -ne 'SELF' -and $b -ceq $OldBody)) -and ($tmps.Count -eq $tmpNamed.Count)
        if ($Case -eq 'PLAIN' -and $null -ne $b) {
            # the replaced file keeps what the user's file had (creation time, attributes) - a
            # delete and a move made a new file instead
            $ct = [IO.File]::GetCreationTimeUtc($LP + $target); $at = [IO.File]::GetAttributes($LP + $target)
            Row $Case 'KEPT' (V ($ct -eq $born -and ($at -band [IO.FileAttributes]::Hidden))) ("creation time {0:yyyy-MM-dd HH:mm:ss} (was {1:yyyy-MM-dd HH:mm:ss}); attributes {2}" -f $ct, $born, $at)
        }
        Row $Case 'TARGET' (V $ok) ("target now: {0}; temporary files: {1} (named in a message: {2}); {3}windows: {4}" -f $(if ($null -eq $b) { 'MISSING' } elseif ($b -ceq $NewBody) { 'the new content' } elseif ($b -ceq $OldBody) { 'the old content' } else { "'" + (Esc $b) + "'" }), ($tmps -join ', '), $tmpNamed.Count, $(if ($note) { $note + '; ' } else { '' }), $msgs)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($held) { $held.Close() }
        if ($id) { End-Row $Case $id $null $before }
        if ([IO.File]::Exists($LP + $target)) { [IO.File]::SetAttributes($LP + $target, [IO.FileAttributes]::Normal) }
    }
}

$backup = Join-Path $env:TEMP 'tc173_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("copy_replace_probe (feature 173), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    foreach ($c in @('PLAIN', 'HELD', 'LOCKED', 'RO', 'SELF')) { Run-Case $c }
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
if ($Expect -eq 'before') { exit 0 }
exit $nf
