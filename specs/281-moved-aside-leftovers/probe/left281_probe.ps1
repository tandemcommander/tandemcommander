<#
.SYNOPSIS
    Feature 281 probe: a create whose name is only another entry's short (8.3) name moves that
    entry aside to "salNNN" and back; when the move back keeps failing (another program holds the
    entry), the user is told where it stayed - it was only a trace (the item
    moved-aside-restore-leftovers).

.DESCRIPTION
    The failure is a race; it is driven by the Debug-only seam TC_PROBE_MOVE_BACK_FAIL=<n> (the
    first n move-back attempts of the program fail with a sharing violation, contracts/probe-seam.md).
    Rows (boxes answered Yes / OK / Skip; dialogs that come back after an error are cancelled):
      cp-left     F5 of a file "LONGFI~1.TXT" into a folder holding "longfilename.txt", seam 1000:
                  PASS = exactly one "Error Renaming File" box whose text holds the whole path of
                  the salNNN entry that holds longfilename.txt's content
      cp-long     cp-left in a deep target folder: the box holds the whole salNNN path (review)
      cp-brief    the same with seam 3 (a hold shorter than the retry): the copy lands,
                  longfilename.txt keeps its name and content, no such box
      dir-left    F5 of a folder "LONGDI~1" next to a folder "longdirname" (keep.txt), seam 1000
      zip-left    F5 out of a ZIP (SafeFileCreate) of a member "LONGFI~1.TXT", seam 1000
      zipdir-left F5 out of a ZIP of a member "LONGDI~1/a.txt" next to "longdirname" (the unpack's
                  folder made its own, feature 204), seam 1000
      f7-left     F7 Create Directory "LONGDI~1" next to "longdirname", seam 1000
      new-left    Edit New File "LONGFI~1.TXT" next to "longfilename.txt", seam 1000
      mv-left     F6 of "x.txt" to "LONGFI~1.TXT" in its folder (221's worker move), seam 1000:
                  the box with the whole path; x.txt's content kept (the worker retries the
                  undone move - it lands as LONGFI~1.TXT)
      qr-left     the same by Quick Rename (221's own report), seam 1000: x.txt kept, the box with
                  the whole path and then Quick Rename's error box
    Short names must be made on the volume (dir /x; NOT DRIVEN otherwise). Driver of 203's probe.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc281_left'
$StartDir = $Root + '\start'
$ConfKey = 'HKCU:\Software\Tandem Commander\0.1\Configuration\Confirmation'
$SeamVar = 'TC_PROBE_MOVE_BACK_FAIL'
$ReopenRx = '^(Create Directory|Edit New File|Quick Rename|Rename File)$'

# the path in the error dialog is painted by CStaticText (no window text): the box is captured
# (PrintWindow) into probe\shot_<case>.png and read by a person / the run's reviewer
Add-Type -AssemblyName System.Drawing
if (-not ('Shot281' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class Shot281
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    public static bool Save(IntPtr h, string file)
    {
        RECT r; if (!GetWindowRect(h, out r)) return false;
        int w = r.R - r.L, ht = r.B - r.T; if (w <= 0 || ht <= 0) return false;
        using (var bmp = new Bitmap(w, ht))
        {
            using (var g = Graphics.FromImage(bmp))
            {
                IntPtr dc = g.GetHdc();
                bool ok = PrintWindow(h, dc, 2 /*PW_RENDERFULLCONTENT*/);
                g.ReleaseHdc(dc);
                if (!ok) return false;
            }
            bmp.Save(file, System.Drawing.Imaging.ImageFormat.Png);
        }
        return true;
    }
}
'@
}
$script:ShotCase = ''

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
function Put([string]$p, [string]$text) { [IO.File]::WriteAllText($LP + $p, $text, (New-Object Text.ASCIIEncoding)) }
function ReadOr([string]$p) { if ([IO.File]::Exists($LP + $p)) { return [IO.File]::ReadAllText($LP + $p) } else { return $null } }
# "name=content; ..." of a folder (names escaped)
function Snap([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return '(gone)' }
    $n = @()
    foreach ($e in [IO.Directory]::GetFileSystemEntries($LP + $Dir)) {
        $name = [IO.Path]::GetFileName($e)
        if ([IO.File]::Exists($e)) { $n += ((Esc $name) + '=' + [IO.File]::ReadAllText($e)) }
        else { $n += ((Esc $name) + '/{' + ((@([IO.Directory]::GetFileSystemEntries($e) | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ',') + '}') }
    }
    return (($n | Sort-Object) -join '; ')
}
function Set-Overwrite([int]$v) {
    if (-not (Test-Path $ConfKey)) { [void](New-Item -Path $ConfKey -Force) }
    Set-ItemProperty -Path $ConfKey -Name 'File Overwrite' -Value $v -Type DWord
}

# serves the instance until idle: records every window; the ids in $script:Answers in order, else
# close; a dialog that comes back after an error (F7, Edit New File) is cancelled
function Serve281([int]$Id, [double]$Seconds = 60) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 3.0) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) { continue }   # progress
            if ([Drv098f]::Txt($h) -match '^\(\d+ %\)') { continue }                         # the worker's progress (Pause, Cancel...)
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            if ([Drv098f]::Txt($h) -match $ReopenRx) { [void]$r.Messages.Add([Drv098f]::Txt($h) + ' dialog re-opened (cancelled)'); Close-Win $h; Start-Sleep -Milliseconds 400; continue }
            [void]$r.Messages.Add($d)
            if ([Drv098f]::Txt($h) -ceq 'Error Renaming File' -and $script:ShotCase) {
                $shot = Join-Path $PSScriptRoot ('shot_' + $script:ShotCase + '.png')
                [void]$r.Messages.Add('(captured ' + (Split-Path -Leaf $shot) + ': ' + [Shot281]::Save($h, $shot) + ')')
            }
            $pick = $null
            foreach ($want in $script:Answers) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } }
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function Short([string]$s) {
    $s = $s -replace '\[Button id=\d+\] [^|]*(\||$)', ''
    $s = $s -replace '\[Static id=-?\d+\] ', ''
    if ($s.Length -gt 260) { $s = $s.Substring(0, 260) + '...' }
    return $s.Trim()
}

# one case: $Setup returns @{ Seam; Left; Right; Focus | FocusLast; Cmd; Text; Check } (Check -> @{ Ok; Lost; Facts })
function Run-Case([string]$Case, [scriptblock]$Setup) {
    $script:Answers = @(6, 1, 173)
    $script:ShotCase = $(if ($Label) { $Case + '_' + $Label } else { $Case })
    $before = Reports; $id = 0; $fatal = $null
    try {
        $c = & $Setup
        if ($c.Skip) { Row $Case 'RUN' 'NOT DRIVEN' $c.Skip; return }
        Set-Overwrite 1
        $script:StartDirSave = $StartDir
        $StartDir = $c.Right
        [Environment]::SetEnvironmentVariable($SeamVar, [string]$c.Seam, 'Process')
        try { $id = Start-Tc $c.Left }
        finally { [Environment]::SetEnvironmentVariable($SeamVar, $null, 'Process'); $StartDir = $script:StartDirSave }
        if ($c.FocusLast) { [void](Do-ChangeDir $id $c.Left); Key $id 0x24; Key $id 0x23 }
        else { [void](Do-ChangeDir $id $c.Focus) }
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id $c.Cmd 15
        if ($dlg -eq [IntPtr]::Zero) { throw ('command ' + $c.Cmd + ' opened no window') }
        $fld = Find-Ctl $dlg 210
        if ($fld -eq [IntPtr]::Zero) { throw 'the name field was not found' }
        [void][Drv098f]::SetText($fld, $c.Text, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve281 $id 90
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        Start-Sleep -Milliseconds 500
        $script:Msgs = @($r.Messages)
        $res = & $c.Check
        $msgs = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || ')
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and $res.Ok
        Row $Case 'RUN' (V $ok) ("seam {0}; lost={1}; on disk: {2}; asked: {3}{4}{5}" -f $c.Seam, $res.Lost, $res.Facts, $(if ($msgs) { $msgs } else { 'nothing' }), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- fixtures and checks -----------------------------------------------------------
function New-Case([string]$Case) { $d = $Root + '\' + $Case; NewDir $d; return $d }
function Res([bool]$Ok, [bool]$Lost, [string]$Facts) { return [pscustomobject]@{ Ok = $Ok; Lost = $Lost; Facts = $Facts } }
function Has-Short([string]$Dir, [string]$Short) {
    $r = Cmd ("dir /x `"{0}`"" -f $Dir)
    if ($r.Text -notmatch [regex]::Escape($Short)) { return ('no short name on this volume: ' + $r.Text) }
    return ''
}
# the other entry left aside: a salNNN entry holds $Content (a file, or keep.txt of a folder), and
# exactly one "Error Renaming File" box names it
function Left-Check([string]$Dir, [string]$Content, [bool]$IsDir, [int]$RenameBoxes = 1) {
    $sal = @([IO.Directory]::GetFileSystemEntries($LP + $Dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { $_ -cmatch '^sal[0-9A-F]{3}$' })
    $where = ''
    foreach ($s in $sal) {
        $f = $(if ($IsDir) { "$Dir\$s\keep.txt" } else { "$Dir\$s" })
        if ((ReadOr $f) -ceq $Content) { $where = $s }
    }
    $own = $(if ($IsDir) { (ReadOr "$Dir\longdirname\keep.txt") -ceq $Content } else { (ReadOr "$Dir\longfilename.txt") -ceq $Content })
    $boxes = @($script:Msgs | Where-Object { $_ -match "'Error Renaming File'" })
    # the box text holds the whole path of the entry (review of 281: the error dialog's painted
    # name field cut a long one); the capture stays as a picture of what the user sees
    # (the box breaks a long path into lines at a backslash; the fixture paths hold no white space)
    # ($RenameBoxes 2: Quick Rename's own error box after the undo, as 221 kept it)
    $naming = @($boxes | Where-Object { [bool]$where -and ($_ -replace '\s', '').Contains("$Dir\$where") })
    $named = ($boxes.Count -eq $RenameBoxes) -and ($naming.Count -eq 1)
    return (Res ([bool]$where -and $named) (-not ([bool]$where -or $own)) ((Snap $Dir) + "; left at: $(if ($where) { $where } else { '-' }); rename boxes: $($boxes.Count); the whole path in it: $named"))
}
# nothing left aside, the other entry under its own name, no rename box
function Brief-Check([string]$Dir, [string]$Content, [string]$Landed, [string]$LandedContent) {
    $sal = @([IO.Directory]::GetFileSystemEntries($LP + $Dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { $_ -cmatch '^sal[0-9A-F]{3}$' })
    $own = (ReadOr "$Dir\longfilename.txt") -ceq $Content
    $landedOk = (ReadOr "$Dir\$Landed") -ceq $LandedContent
    $boxes = @($script:Msgs | Where-Object { $_ -match "'Error Renaming File'" })
    $ok = ($sal.Count -eq 0) -and $own -and $landedOk -and ($boxes.Count -eq 0) -and ($script:Msgs.Count -eq 0)
    return (Res $ok (-not $own) ((Snap $Dir) + "; salNNN entries: $($sal.Count); copy there: $landedOk; rename boxes: $($boxes.Count)"))
}

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
function Zip-Make([string]$Zip, [string[]]$Names, [string]$Content) {
    $z = [IO.Compression.ZipFile]::Open($LP + $Zip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($n in $Names) {
            $w = New-Object IO.StreamWriter(($z.CreateEntry($n)).Open())
            $w.Write($Content); $w.Dispose()
        }
    }
    finally { $z.Dispose() }
}

$Cases = [ordered]@{}
$Cases['cp-left'] = {
    $d = New-Case 'cp-left'; NewDir "$d\src"; NewDir "$d\tgt"
    Put "$d\tgt\longfilename.txt" 'PRECIOUS-1'; Put "$d\src\LONGFI~1.TXT" 'COPIED-1'
    $s = Has-Short "$d\tgt" 'LONGFI~1.TXT'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 1000; Left = "$d\src"; Right = "$d\tgt"; Focus = "$d\src\LONGFI~1.TXT"; Cmd = 727; Text = "$d\tgt\"
       Check = { Left-Check "$d\tgt" 'PRECIOUS-1' $false }.GetNewClosure() }
}
# review of 281: a target deep enough that a painted path field cut the salNNN path with an ellipsis
$Cases['cp-long'] = {
    $d = New-Case 'cp-long'; $t = "$d\a_rather_long_folder_name_to_make_the_path_wide\second_long_folder_name_to_make_it_wider\tgt"
    NewDir "$d\src"; NewDir $t
    Put "$t\longfilename.txt" 'PRECIOUS-5'; Put "$d\src\LONGFI~1.TXT" 'COPIED-5'
    $s = Has-Short $t 'LONGFI~1.TXT'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 1000; Left = "$d\src"; Right = $t; Focus = "$d\src\LONGFI~1.TXT"; Cmd = 727; Text = "$t\"
       Check = { Left-Check $t 'PRECIOUS-5' $false }.GetNewClosure() }
}
$Cases['cp-brief'] = {
    $d = New-Case 'cp-brief'; NewDir "$d\src"; NewDir "$d\tgt"
    Put "$d\tgt\longfilename.txt" 'PRECIOUS-2'; Put "$d\src\LONGFI~1.TXT" 'COPIED-2'
    $s = Has-Short "$d\tgt" 'LONGFI~1.TXT'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 3; Left = "$d\src"; Right = "$d\tgt"; Focus = "$d\src\LONGFI~1.TXT"; Cmd = 727; Text = "$d\tgt\"
       Check = { Brief-Check "$d\tgt" 'PRECIOUS-2' 'LONGFI~1.TXT' 'COPIED-2' }.GetNewClosure() }
}
$Cases['dir-left'] = {
    $d = New-Case 'dir-left'; NewDir "$d\src"; NewDir "$d\tgt"; NewDir "$d\src\LONGDI~1"; NewDir "$d\tgt\longdirname"
    Put "$d\tgt\longdirname\keep.txt" 'PRECIOUS-D1'; Put "$d\src\LONGDI~1\a.txt" 'COPIED-D1'
    $s = Has-Short "$d\tgt" 'LONGDI~1'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 1000; Left = "$d\src"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = "$d\tgt\"
       Check = { Left-Check "$d\tgt" 'PRECIOUS-D1' $true }.GetNewClosure() }
}
$Cases['zip-left'] = {
    $d = New-Case 'zip-left'; NewDir "$d\tgt"
    Put "$d\tgt\longfilename.txt" 'PRECIOUS-3'
    Zip-Make "$d\a.zip" @('LONGFI~1.TXT') 'COPIED-3'
    $s = Has-Short "$d\tgt" 'LONGFI~1.TXT'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 1000; Left = "$d\a.zip"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = "$d\tgt\"
       Check = { Left-Check "$d\tgt" 'PRECIOUS-3' $false }.GetNewClosure() }
}
$Cases['zipdir-left'] = {
    $d = New-Case 'zipdir-left'; NewDir "$d\tgt"; NewDir "$d\tgt\longdirname"
    Put "$d\tgt\longdirname\keep.txt" 'PRECIOUS-D2'
    Zip-Make "$d\a.zip" @('LONGDI~1/a.txt') 'COPIED-D2'
    $s = Has-Short "$d\tgt" 'LONGDI~1'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 1000; Left = "$d\a.zip"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = "$d\tgt\"
       Check = { Left-Check "$d\tgt" 'PRECIOUS-D2' $true }.GetNewClosure() }
}
$Cases['f7-left'] = {
    $d = New-Case 'f7-left'; NewDir "$d\tgt"; NewDir "$d\tgt\longdirname"
    Put "$d\tgt\longdirname\keep.txt" 'PRECIOUS-D3'
    $s = Has-Short "$d\tgt" 'LONGDI~1'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 1000; Left = "$d\tgt"; Right = $StartDir; FocusLast = $true; Cmd = 730; Text = 'LONGDI~1'
       Check = { Left-Check "$d\tgt" 'PRECIOUS-D3' $true }.GetNewClosure() }
}
$Cases['new-left'] = {
    $d = New-Case 'new-left'; NewDir "$d\tgt"
    Put "$d\tgt\longfilename.txt" 'PRECIOUS-4'
    $s = Has-Short "$d\tgt" 'LONGFI~1.TXT'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 1000; Left = "$d\tgt"; Right = $StartDir; FocusLast = $true; Cmd = 744; Text = 'LONGFI~1.TXT'
       Check = { Left-Check "$d\tgt" 'PRECIOUS-4' $false }.GetNewClosure() }
}

# 221's routes (the rename / move of "x.txt" to "LONGFI~1.TXT" in the same folder): the box says
# where the other file stays - the worker's move now in the whole-path form. The worker's move is
# undone and, its reason being a sharing violation, retried by the worker - the short name is free
# then, so x.txt ends up as LONGFI~1.TXT (221's logic); Quick Rename stays undone and shows its own
# error box after the "left aside" one (221)
$Cases['mv-left'] = {
    $d = New-Case 'mv-left'
    Put "$d\longfilename.txt" 'PRECIOUS-6'; Put "$d\x.txt" 'MOVED-6'
    $s = Has-Short $d 'LONGFI~1.TXT'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 1000; Left = $d; Right = $StartDir; Focus = "$d\x.txt"; Cmd = 728; Text = "$d\LONGFI~1.TXT"
       Check = { $r = Left-Check $d 'PRECIOUS-6' $false; $x = ((ReadOr "$d\x.txt") -ceq 'MOVED-6') -or ((ReadOr "$d\LONGFI~1.TXT") -ceq 'MOVED-6'); Res ($r.Ok -and $x) ($r.Lost -or -not $x) ($r.Facts + "; x.txt's content kept: $x") }.GetNewClosure() }
}
$Cases['qr-left'] = {
    $d = New-Case 'qr-left'
    Put "$d\longfilename.txt" 'PRECIOUS-7'; Put "$d\x.txt" 'MOVED-7'
    $s = Has-Short $d 'LONGFI~1.TXT'; if ($s) { return @{ Skip = $s } }
    @{ Seam = 1000; Left = $d; Right = $StartDir; Focus = "$d\x.txt"; Cmd = 754; Text = 'LONGFI~1.TXT'
       Check = { $r = Left-Check $d 'PRECIOUS-7' $false 2; $x = (ReadOr "$d\x.txt") -ceq 'MOVED-7'; Res ($r.Ok -and $x) ($r.Lost -or -not $x) ($r.Facts + "; x.txt kept: $x") }.GetNewClosure() }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc281_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Set-Overwrite 1
    Out ("left281_probe (feature 281) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ''
    foreach ($k in @($Cases.Keys)) { if (Want $k) { Run-Case $k $Cases[$k] } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    [Environment]::SetEnvironmentVariable($SeamVar, $null, 'Process')
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
