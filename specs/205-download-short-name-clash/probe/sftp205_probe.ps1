<#
.SYNOPSIS
    Feature 205: an SFTP download whose local name is only the short (8.3) name of another local
    entry never writes into that entry.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). Needs the container
    'tandem-sftp' (localhost:2222, user tctest); the server side is prepared, read and removed
    with fixture205.sh through 'docker exec'. Driver of 133's sftp133_probe.ps1: every row is its
    own start of the program, the left panel connects by a typed address, F5 (727) downloads the
    focused item into the row's local folder, every dialog is answered Yes / OK.

    Rows (the local folder holds longfilename.txt "PRECIOUS" or the folder longdirname with
    keep.txt "PRECIOUS-D"; short names must be made on the volume - NOT DRIVEN otherwise):
      SF-FILE     download LONGFI~1.TXT: PASS = longfilename.txt keeps its content, the download is
                  its own file LONGFI~1.TXT (no question for the other file)
      SF-HELD     the same with longfilename.txt held open (no delete sharing): PASS = an error,
                  longfilename.txt keeps its content
      SF-MOVE     F6 (728) of LONGFI~1.TXT: an own file, longfilename.txt kept, the source gone
      SF-MOVEHELD the same with longfilename.txt held: an error, the source stays on the server
      SF-DIR      download the folder LONGDI~1 (a.txt): PASS = a folder LONGDI~1 of its own,
                  longdirname holds only keep.txt
      SF-DIRHELD  SF-DIR with keep.txt held open (longdirname cannot be moved aside): PASS = an error,
                  nothing downloaded into longdirname
      SF-DIRSAME  download LONGDI~1 holding keep.txt: PASS = longdirname\keep.txt keeps its content
    The product's registry key is exported, restored and compared. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [switch]$NoSeam
)
$ErrorActionPreference = 'Stop'
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ }) }   # -File passes 'A,B' as one string
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc205'
$StartDir = $Root + '\start'
$Base = '/home/tctest/tc205'
$Addr = 'sftp:tctest@localhost:2222'      # the form the plug-in shows; 'sftp://...' is the row URL
$Password = 'tandem123'
$FixtureText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixture205.sh')).Replace("`r", '')

# runs fixture133.sh in the container with one argument; returns its output lines
function Server([string]$Arg) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = 'docker'
    $psi.Arguments = 'exec -i -u tctest tandem-sftp bash -s ' + $Arg
    $psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($FixtureText); $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw ('docker exec failed (' + $p.ExitCode + '): ' + $err.Trim()) }
    return @($out -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
function State { $h = @{}; foreach ($l in (Server 'state')) { $kv = $l -split '=', 2; if ($kv.Count -eq 2) { $h[$kv[0]] = $kv[1] } }; return $h }

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T205', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function PostKey([int]$Id, [int]$Vk) {   # a key that opens a dialog: posted, the panel answers when it can
    $l = Get-LeftList $Id
    [void][Drv098f]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 700
}
function Dialogs([int]$Id) { return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) -and [Drv098f]::IsWindowVisible($_) }) }
function BtnById([IntPtr]$Dlg, [int[]]$Ids) { foreach ($w in $Ids) { $b = Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($b) { return $b } }; return $null }

# types the address into Change Directory and answers the password / host key dialogs
function Connect([int]$Id, [string]$RemoteDir, [string]$Prefix = $Addr) {
    $notes = @()
    [void](Do-ChangeDir $Id ($Prefix + $RemoteDir))
    $sw = [Diagnostics.Stopwatch]::StartNew(); $quiet = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 45 -and $quiet.Elapsed.TotalSeconds -lt 4) {
        $acted = $false
        foreach ($h in (Dialogs $Id)) {
            if ([Drv098f]::Txt($h) -eq 'Change Directory') { $notes += 'Change Directory came back'; Close-Win $h; $acted = $true; break }
            $pw = Find-Ctl $h 630
            if ($pw -ne [IntPtr]::Zero) { [void][Drv098f]::SetText($pw, $Password, 5000); Click-Ok $h; $notes += 'password'; $acted = $true; break }
            $once = BtnById $h @(644, 643)
            if ($once) { Click $once; $notes += 'host key'; $acted = $true; break }
            $ok = BtnById $h @(1)
            if ($ok -and (Buttons $h).Count -le 2) { $notes += ('box: ' + (Tail (WinDesc $h) 200)); Click $ok; $acted = $true; break }
        }
        if ($acted) { $quiet.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    Sync $Id
    $loc = Get-Loc $Id
    return [pscustomobject]@{ Loc = $loc; Notes = ($notes -join ', '); Ok = ($loc -like ('sftp:*' + $RemoteDir.TrimEnd('/') + '*')) }
}

# answers every dialog until none shows for $Quiet seconds: the first of the wanted buttons by
# id (default Yes, OK), else Skip / Cancel by text; a dialog whose only button is Cancel (a
# progress or wait window) is left alone. $FirstEdit: text for the first dialog with an edit.
function Answer([int]$Id, [double]$Seconds = 90, [double]$Quiet = 5, [string]$FirstEdit = $null) {
    $texts = @(); $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew(); $typed = $false; $seenOp = $false
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and $last.Elapsed.TotalSeconds -lt $Quiet -and (Test-Alive $Id)) {
        $acted = $false
        foreach ($h in (Dialogs $Id)) {
            $bs = Buttons $h
            $ids = @($bs | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if ($ids.Count -eq 0 -or ($ids.Count -eq 1 -and $ids[0] -eq 2)) { continue }
            Start-Sleep -Milliseconds 500
            $desc = WinDesc $h
            if ($desc -match $FatalRx) { $texts += ('FATAL ' + (Tail $desc 300)); return $texts }
            if ([Drv098f]::Txt($h) -eq 'Change Directory') { $texts += 'Change Directory dialog'; Close-Win $h; $acted = $true; break }
            # the core shows its Copy / Move dialog again after an operation that failed: Cancel
            if (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 209 }).Count) {
                if ($seenOp) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
                $seenOp = $true
            }
            if ($FirstEdit -and -not $typed) {
                $edit = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
                if ($edit) { [void][Drv098f]::SetText($edit, $FirstEdit, 5000); $typed = $true; $texts += ('typed into [' + (Tail ([Drv098f]::Txt($h)) 40) + ']'); Click-Ok $h; $acted = $true; break }
            }
            # the dialog with the typed text came back after an error: Cancel
            if ($typed -and @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2477 }).Count -eq 0 -and @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) }).Count) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
            $b = $null
            if ($script:AnswerNo -and ($desc -match 'already exists')) { $b = BtnById $h @(7) }   # the overwrite question: No
            if (-not $b) { $b = BtnById $h @(6, 1) }
            if (-not $b) { $b = $bs | Where-Object { [Drv098f]::Txt($_) -match '^&?(Skip|Close)$' } | Select-Object -First 1 }
            $texts += (Shorten $desc)
            if ($b) { Click $b } else { Close-Win $h }
            $acted = $true
            break
        }
        if ($acted) { $last.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    return $texts
}
function Shorten([string]$t) { $e = [regex]::Replace((Esc $t), '(?:[def]{10,}[ /]?)+', '<long names>/'); if ($e.Length -le 520) { return $e }; return ($e.Substring(0, 300) + ' ...(' + ($e.Length - 450) + ')... ' + $e.Substring($e.Length - 150)) }
function LocalDirs([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return 'none' }
    $d = @([IO.Directory]::GetDirectories($LP + $Dir, '*', 'AllDirectories'))
    $deep = 0; foreach ($x in $d) { $n = $x.Substring(($LP + $Dir).Length).Split([char]92).Count - 1; if ($n -gt $deep) { $deep = $n } }
    return ('' + $d.Count + ' folders, ' + $deep + ' levels')
}
function LocalFiles([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetFiles($LP + $Dir, '*', 'AllDirectories') | ForEach-Object { $_.Substring(($LP + $Dir).Length + 1) })
}
function Has([string[]]$Texts, [string]$Rx) { return [bool](@($Texts | Where-Object { $_ -match $Rx }).Count) }

# one row: connect to $Dir, optionally move the focus ($Down times Down after Home), post the core's
# command $Vk (727 Copy, 728 Move, 729 Delete, 730 Create Directory),
# answer, then $Judge { param($texts, $state, $local, $conn) } returns @{ Ok; Facts }
function Row-Op([string]$Case, [string]$Dir, [int]$Down, [int]$Vk, [string]$TypeText, [scriptblock]$Judge, [string]$Seam = '', [bool]$Enter = $false, [string]$LocalSub = '', [string]$Prefix = '', [string]$Mode = '') {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case + $(if ($LocalSub) { '\' + $LocalSub } else { '' })
    try {
        NewDir $local
        $script:AnswerNo = $false
        if ($Mode -like 'File*') { [IO.File]::WriteAllText($LP + $local + '\longfilename.txt', 'PRECIOUS') }
        if ($Mode -like 'Dir*') { NewDir ($local + '\longdirname'); [IO.File]::WriteAllText($LP + $local + '\longdirname\keep.txt', 'PRECIOUS-D') }
        $dx = (& cmd.exe /c ('dir /x "' + $local + '"') 2>&1 | ForEach-Object { "$_" }) -join ' '
        if ($Mode -and $dx -notmatch 'LONG(FI|DI)~1') { Row $Case 'ROW' 'NOT DRIVEN' ('no short name on this volume: ' + $dx); return }
        if ($Mode -eq 'DirHeld') { $global:Held205 = [IO.File]::Open($LP + $local + '\longdirname\keep.txt', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
        if ($Mode -eq 'FileHeld') { $global:Held205 = [IO.File]::Open($LP + $local + '\longfilename.txt', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
        if ($Seam) { $env:TC_SFTP_PROBE_LIST_FAIL = $Seam } else { Remove-Item Env:\TC_SFTP_PROBE_LIST_FAIL -ErrorAction SilentlyContinue }
        if ($script:XferSeam) { $env:TC_SFTP_PROBE_XFER_FAIL = $script:XferSeam } else { Remove-Item Env:\TC_SFTP_PROBE_XFER_FAIL -ErrorAction SilentlyContinue }
        if ($script:DeadSeam) { $env:TC_SFTP_PROBE_TIMEOUT_AT = $script:DeadSeam } else { Remove-Item Env:\TC_SFTP_PROBE_TIMEOUT_AT -ErrorAction SilentlyContinue }
        $id = Start-P
        # the right (target) panel shows this row's own local folder
        Key $id 0x09; [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09
        $conn = $(if ($Prefix) { Connect $id ($Base + '/' + $Dir) $Prefix } else { Connect $id ($Base + '/' + $Dir) })
        $texts = @()
        if ($Vk -ne 0 -or $Enter) {
            Key $id 0x24
            for ($i = 0; $i -lt $Down; $i++) { Key $id 0x28 }
            if ($Enter) { Key $id 0x0D; Start-Sleep -Milliseconds 1500; $texts += (Answer $id 30 4); Sync $id; $conn = [pscustomobject]@{ Loc = (Get-Loc $id); Notes = $conn.Notes; Ok = $conn.Ok } }
            if ($Vk -ne 0) { Post-Cmd (Get-Main $id) $Vk; Start-Sleep -Milliseconds 700; $texts += (Answer $id 120 6 $TypeText) }
        }
        else { $texts += (Answer $id 20 4) }
        $st = State
        $r = & $Judge $texts $st (LocalFiles $local) $conn
        $verdict = $(if ($r.Skip) { 'NOT DRIVEN' } elseif ($Expect -eq 'before') { 'PASS' } else { V ([bool]$r.Ok) })
        Row $Case 'ROW' $verdict ("{0}; local target: {5}; connected: {1} [{2}] at '{3}'; dialogs: {4}" -f $r.Facts, $conn.Ok, $conn.Notes, (Tail $conn.Loc 60), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }), (LocalDirs $local))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        Remove-Item Env:\TC_SFTP_PROBE_LIST_FAIL -ErrorAction SilentlyContinue
        Remove-Item Env:\TC_SFTP_PROBE_XFER_FAIL -ErrorAction SilentlyContinue
        $script:XferSeam = ''
        Remove-Item Env:\TC_SFTP_PROBE_TIMEOUT_AT -ErrorAction SilentlyContinue
        $script:DeadSeam = ''
        if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before }
    }
}

# feature 139 - one row in the other direction: $Setup { param($local) } fills this row's local
# folder, the server directory $Dir is the target; the local panel gets the focus ($Down times
# Down after Home) and the core's command $Vk (727 Copy, 728 Move).
# $Judge { param($texts, $state, $local, $conn) } - $local is the row's local folder (a path).
function Row-Up([string]$Case, [string]$Dir, [int]$Down, [int]$Vk, [scriptblock]$Setup, [scriptblock]$Judge, [string]$Xfer = '', [bool]$No = $false) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case
    try {
        NewDir $local
        & $Setup $local | Out-Null
        $script:AnswerNo = $No
        Remove-Item Env:\TC_SFTP_PROBE_LIST_FAIL -ErrorAction SilentlyContinue
        if ($Xfer) { $env:TC_SFTP_PROBE_XFER_FAIL = $Xfer } else { Remove-Item Env:\TC_SFTP_PROBE_XFER_FAIL -ErrorAction SilentlyContinue }
        $id = Start-P
        # the probe's keys go to the left list: the local source is on the left, the server on the right
        [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09
        $conn = Connect $id ($Base + '/' + $Dir)
        Key $id 0x09
        Key $id 0x24
        for ($i = 0; $i -lt $Down; $i++) { Key $id 0x28 }
        Post-Cmd (Get-Main $id) $Vk; Start-Sleep -Milliseconds 700
        $texts = @(Answer $id 120 6)
        $st = State
        $r = & $Judge $texts $st $local $conn
        $verdict = $(if ($Expect -eq 'before') { 'PASS' } else { V ([bool]$r.Ok) })
        Row $Case 'ROW' $verdict ("{0}; connected: {1} [{2}] at '{3}'; dialogs: {4}" -f $r.Facts, $conn.Ok, $conn.Notes, (Tail $conn.Loc 60), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        Remove-Item Env:\TC_SFTP_PROBE_XFER_FAIL -ErrorAction SilentlyContinue
        $script:AnswerNo = $false
        if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before }
    }
}
function Rel([string]$Dir) {    # files and folders under $Dir, relative, with '/', sorted
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return 'gone' }
    return ((@([IO.Directory]::GetFileSystemEntries($LP + $Dir, '*', 'AllDirectories')) | ForEach-Object { $_.Substring(($LP + $Dir).Length + 1).Replace([string][char]92, '/') } | Sort-Object) -join ' ')
}
function BigText { return ('0123456789ABCDEF' * 18750) }      # 300,000 bytes

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc205_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
$SeamIn = (-not $NoSeam)
try {
    NewDir $StartDir
    Set-Config
    $prep = (Server '') -join ' '
    Out ("sftp205_probe (feature 205), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : {0}" -f $prep)
    Out ''
    $Kept = { param($d) $c = ''; try { $c = [IO.File]::ReadAllText($LP + $d + '\longfilename.txt') } catch { $c = '(gone)' }; $c }
    $Own = { param($d) $n = @([IO.Directory]::GetFileSystemEntries($LP + $d) | ForEach-Object { [IO.Path]::GetFileName($_) }); $n }
    $Free = { if ($global:Held205) { $global:Held205.Dispose(); $global:Held205 = $null } }
    Row-Op 'SF-FILE' 'f1' 1 727 $null { param($t, $s, $l, $c) $d = $StartDir + '\SF-FILE'; $k = & $Kept $d; $n = & $Own $d; $dl = ''; try { $dl = [IO.File]::ReadAllText($LP + $d + '\LONGFI~1.TXT') } catch { }; $mine = $n -ccontains 'LONGFI~1.TXT'; @{ Ok = ($k -ceq 'PRECIOUS' -and $mine -and $dl -ceq 'SERVER-F1' -and -not (Has $t 'already exists')); Facts = ("download LONGFI~1.TXT next to longfilename.txt: longfilename.txt holds '{0}'; entries '{1}'; an own LONGFI~1.TXT {2} holding '{3}'; the overwrite question {4}" -f $k, ($n -join ','), $mine, $dl, (Has $t 'already exists')) } } '' $false '' '' 'File'
    Row-Op 'SF-HELD' 'f2' 1 727 $null { param($t, $s, $l, $c) & $Free; $d = $StartDir + '\SF-HELD'; $k = & $Kept $d; $n = & $Own $d; @{ Ok = ($k -ceq 'PRECIOUS' -and -not (Has $t 'already exists') -and (Has $t 'Cannot|Unable|error|denied|used')); Facts = ("the same, longfilename.txt held open: it holds '{0}'; entries '{1}'; the overwrite question {2}; an error shown {3}" -f $k, ($n -join ','), (Has $t 'already exists'), (Has $t 'Cannot|Unable|error|denied|used')) } } '' $false '' '' 'FileHeld'
    Row-Op 'SF-MOVE' 'm1' 1 728 $null { param($t, $s, $l, $c) $d = $StartDir + '\SF-MOVE'; $k = & $Kept $d; $dl = ''; try { $dl = [IO.File]::ReadAllText($LP + $d + '\LONGFI~1.TXT') } catch { }; $left = ('' + $s.m1_entries).Trim(); @{ Ok = ($k -ceq 'PRECIOUS' -and $dl -ceq 'SERVER-M1' -and $left -eq '' -and -not (Has $t 'already exists')); Facts = ("move LONGFI~1.TXT next to longfilename.txt: longfilename.txt holds '{0}'; the own LONGFI~1.TXT holds '{1}'; left on the server '{2}' (expected nothing)" -f $k, $dl, $left) } } '' $false '' '' 'File'
    Row-Op 'SF-MOVEHELD' 'm2' 1 728 $null { param($t, $s, $l, $c) & $Free; $d = $StartDir + '\SF-MOVEHELD'; $k = & $Kept $d; $left = ('' + $s.m2_entries).Trim(); @{ Ok = ($k -ceq 'PRECIOUS' -and $left -eq './LONGFI~1.TXT' -and -not (Has $t 'already exists')); Facts = ("the same with longfilename.txt held open: it holds '{0}'; left on the server '{1}' (expected './LONGFI~1.TXT')" -f $k, $left) } } '' $false '' '' 'FileHeld'
    Row-Op 'SF-DIR' 'd1' 1 727 $null { param($t, $s, $l, $c) $d = $StartDir + '\SF-DIR'; $in = (& $Own ($d + '\longdirname')) -join ','; $n = & $Own $d; $mine = ($n -ccontains 'LONGDI~1') -and [IO.File]::Exists($LP + $d + '\LONGDI~1\a.txt'); @{ Ok = ($in -ceq 'keep.txt' -and $mine); Facts = ("download the folder LONGDI~1 next to longdirname: longdirname holds '{0}'; entries '{1}'; an own LONGDI~1 with a.txt {2}" -f $in, ($n -join ','), $mine) } } '' $false '' '' 'Dir'
    Row-Op 'SF-DIRHELD' 'd1' 1 727 $null { param($t, $s, $l, $c) & $Free; $d = $StartDir + '\SF-DIRHELD'; $in = (& $Own ($d + '\longdirname')) -join ','; @{ Ok = ($in -ceq 'keep.txt' -and (Has $t 'Cannot|Unable|error|denied|used')); Facts = ("download the folder LONGDI~1 next to longdirname with keep.txt held open: longdirname holds '{0}'; an error shown {1}" -f $in, (Has $t 'Cannot|Unable|error|denied|used')) } } '' $false '' '' 'DirHeld'
    Row-Op 'SF-DIRSAME' 'd2' 1 727 $null { param($t, $s, $l, $c) $d = $StartDir + '\SF-DIRSAME'; $k = ''; try { $k = [IO.File]::ReadAllText($LP + $d + '\longdirname\keep.txt') } catch { $k = '(gone)' }; $in = (& $Own ($d + '\longdirname')) -join ','; @{ Ok = ($k -ceq 'PRECIOUS-D' -and $in -ceq 'keep.txt' -and -not (Has $t 'already exists')); Facts = ("download LONGDI~1 holding keep.txt next to longdirname: longdirname\keep.txt holds '{0}'; longdirname holds '{1}'; the overwrite question {2}" -f $k, $in, (Has $t 'already exists')) } } '' $false '' '' 'Dir'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { [void](Server 'clean') } catch { Out ('Server: could not clean: ' + $_.Exception.Message) }
    if ($global:Held205) { $global:Held205.Dispose(); $global:Held205 = $null }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } }
    catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
