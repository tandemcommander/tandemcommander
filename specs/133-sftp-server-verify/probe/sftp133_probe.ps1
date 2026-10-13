<#
.SYNOPSIS
    Feature 133: the SFTP plug-in driven in the program against the test server.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). Needs the container
    'tandem-sftp' (localhost:2222, user tctest); the server side is prepared, read and removed
    with fixture133.sh through 'docker exec'. Every row is its own start of the program: the
    left panel connects by a typed address (password and host-key dialogs are answered), the
    row's command is given, every dialog is answered and its text kept, then the state of the
    server and of the local target folder is compared.

    Rows (R / P are the rows feature 131 wrote down and could not run):
      R1  delete a file in a read-only directory      - the message carries the server's reason
      R2  create a directory there                    - the same
      R3  download an unreadable file                 - the same
      P1  enter a link to a directory 2,900 bytes deep, create a directory with a 250-byte name
      P4  delete a tree whose files are beyond 4,095 bytes - "too long", files still there
      P5  download that tree; P5M move it             - nothing under a shortened name, nothing deleted
      DEL delete an ordinary tree; DELKEEP a tree with a file that cannot be deleted - one message,
          no request to remove the directories above it
      QR250 / QRLONG  Quick Rename to a name of 250 letters / to one that does not fit the
          plug-in interface (feature 137)
      M1  move a directory of 30 files, M2 move a file; MTREE / MKEEP / MSKIP / MCASE / MBLOCK
          (feature 138): a tree with sub-directories; with one unreadable file; with a local file
          not overwritten; with two names that are one file on Windows; with a local folder
          that cannot be created
      URL the address typed as sftp://user@host:port/path
      LISTCOPY / LISTMOVE / LISTPANEL - the read of the 10th entry of the directory "many" fails
          once (debug seam TC_SFTP_PROBE_LIST_FAIL; rows are NOT DRIVEN on a build without it)
    -Expect fixed : expectations of the final build; -Expect before : outcomes are recorded only.
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

$Root = $TempRoot + '\tc133'
$StartDir = $Root + '\start'
$Base = '/home/tctest/tc133'
$Addr = 'sftp:tctest@localhost:2222'      # the form the plug-in shows; 'sftp://...' is the row URL
$Password = 'tandem123'
$FixtureText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixture133.sh')).Replace("`r", '')

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
    $a = @('-t', 'T133', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
        if ($Mode -eq 'NoToOverwrite') { NewDir ($local + '\tree'); [IO.File]::WriteAllText($LP + $local + '\tree\exists.txt', 'LOCAL-ORIGINAL') }
        $script:AnswerNo = ($Mode -eq 'NoToOverwrite')
        if ($Mode -eq 'FileInTheWay') { [IO.File]::WriteAllText($LP + $local + '\proj', 'a file where the directory should go') }
        if ($Mode -eq 'LocalBigExists') { [IO.File]::WriteAllText($LP + $local + '\big.bin', 'LOCAL-ORIGINAL') }
        if ($Seam) { $env:TC_SFTP_PROBE_LIST_FAIL = $Seam } else { Remove-Item Env:\TC_SFTP_PROBE_LIST_FAIL -ErrorAction SilentlyContinue }
        if ($script:XferSeam) { $env:TC_SFTP_PROBE_XFER_FAIL = $script:XferSeam } else { Remove-Item Env:\TC_SFTP_PROBE_XFER_FAIL -ErrorAction SilentlyContinue }
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
$backup = Join-Path $env:TEMP 'tc133_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
$SeamIn = (-not $NoSeam)
try {
    NewDir $StartDir
    Set-Config
    $prep = (Server '') -join ' '
    Out ("sftp133_probe (feature 133), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : {0}" -f $prep)
    Out ''
    $PD = 'Permission denied'
    Row-Op 'R1' 'ro1' 1 729 $null { param($t, $s, $l, $c) @{ Ok = ((Has $t $PD) -and $s.ro1_f -eq '1'); Facts = ("delete in a read-only directory: reason shown {0}; file on the server {1}" -f (Has $t $PD), $s.ro1_f) } }
    Row-Op 'R2' 'ro2' 0 730 'newdir' { param($t, $s, $l, $c) @{ Ok = ((Has $t $PD) -and $s.ro2_entries -eq '0'); Facts = ("create a directory in a read-only directory: reason shown {0}; entries on the server {1}" -f (Has $t $PD), $s.ro2_entries) } }
    Row-Op 'R3' 'r3' 1 727 $null { param($t, $s, $l, $c) @{ Ok = ((Has $t $PD) -and @($l | Where-Object { $_ -match 'secret' -and (Get-Item -LiteralPath ($StartDir + '\R3\' + $_)).Length -gt 0 }).Count -eq 0); Facts = ("download an unreadable file: reason shown {0}; local files: {1}" -f (Has $t $PD), ($l -join ', ')) } }
    $x250 = 'x' * 250
    Row-Op 'P1' 'p1/deep' 0 730 $x250 { param($t, $s, $l, $c) @{ Ok = (($c.Loc -match '/p1/deep') -and $s.deep_longest -eq '250' -and $s.deep_entries -eq '2'); Facts = ("go to the deep link and create a directory with a 250-byte name: panel at '.../{0}'; entries in the deep directory {1}, longest name {2} bytes" -f (($c.Loc -split '/')[-2..-1] -join '/'), $s.deep_entries, $s.deep_longest) } }
    $TL = 'too long'
    $RD = 'Cannot remove directory'
    Row-Op 'P4' 'p4' 1 729 $null { param($t, $s, $l, $c) $n = @($t | Where-Object { $_ -match $RD }).Count; $noReason = @($t | Where-Object { $_ -match $RD -and $_ -notmatch 'error \d+: |denied' }).Count; @{ Ok = ($s.p4_deepfiles -eq '2' -and $n -gt 0 -and $noReason -eq 0); Facts = ("delete a tree whose two files the server does not list (beyond its PATH_MAX): files still on the server {0} of 2; 'cannot remove directory' messages {1}, of them without their reason at the end {2}" -f $s.p4_deepfiles, $n, $noReason) } }
    $L80 = 'L' * 80
    $short = { param($l) @($l | Where-Object { $_ } | Where-Object { $n = $_.Split([char]92)[-1]; $n -match '^f+' -and $n.Length -lt 250 }) }
    Row-Op 'P5' 'p5' 1 727 $null { param($t, $s, $l, $c) $sh = & $short $l; @{ Ok = ((Has $t $TL) -and $sh.Count -eq 0 -and $l.Count -eq 0 -and $s.p5_deepfiles -eq '2'); Facts = ("download a tree whose files would get local names beyond 4,095 bytes: 'too long' shown {0}; local files {1}, with a shortened name {2}; files on the server {3} of 2" -f (Has $t $TL), $l.Count, $sh.Count, $s.p5_deepfiles) } } '' $false $L80
    Row-Op 'P5M' 'p5m' 1 728 $null { param($t, $s, $l, $c) $sh = & $short $l; @{ Ok = ((Has $t $TL) -and $sh.Count -eq 0 -and $s.p5m_deepfiles -eq '2'); Facts = ("move that tree: 'too long' shown {0}; local files {1}, with a shortened name {2}; files on the server {3} of 2" -f (Has $t $TL), $l.Count, $sh.Count, $s.p5m_deepfiles) } } '' $false $L80
    Row-Op 'DEL' 'd1' 1 729 $null { param($t, $s, $l, $c) $err = (Has $t 'Cannot'); @{ Ok = ($s.d1_tree -eq '0' -and -not $err); Facts = ("delete an ordinary tree: gone from the server {0}; an error shown {1}" -f ($s.d1_tree -eq '0'), $err) } }
    Row-Op 'DELKEEP' 'd2' 1 729 $null { param($t, $s, $l, $c) $n = @($t | Where-Object { $_ -match 'Cannot' }).Count; @{ Ok = ($s.d2_kept -eq '1' -and $s.d2_free -eq '0' -and $n -eq 1 -and (Has $t $PD)); Facts = ("delete a tree with one file that cannot be deleted: that file is still there {0}; the rest is gone {1}; messages {2} (one, with the reason: {3})" -f $s.d2_kept, ($s.d2_free -eq '0'), $n, (Has $t $PD)) } }
    # feature 138: a moved directory leaves the server - and only what arrived whole
    $M138 = ($Expect -eq 'fixed')
    Row-Op 'M1' 'm1' 1 728 $null { param($t, $s, $l, $c) @{ Ok = ($l.Count -eq 30 -and $s.m1_dir -eq '0'); Facts = ("move a directory of 30 files: local files {0}; the directory still on the server {1} (files in it {2})" -f $l.Count, $s.m1_dir, $s.m1_many) } }
    Row-Op 'MTREE' 'mt' 1 728 $null { param($t, $s, $l, $c) $names = (($l | ForEach-Object { $_.Replace([string][char]92, '/') } | Sort-Object) -join ' '); @{ Ok = ($s.mt_tree -eq '0' -and $l.Count -eq 3 -and $names -eq 'tree/a/b/x.txt tree/a/y.txt tree/z.txt' -and [IO.Directory]::Exists($LP + $StartDir + '\MTREE\tree\empty') -and -not (Has $t 'Cannot')); Facts = ("move a tree with sub-directories and an empty directory: local files '{0}'; the empty directory local {1}; the tree still on the server {2}; errors shown {3}" -f $names, [IO.Directory]::Exists($LP + $StartDir + '\MTREE\tree\empty'), $s.mt_tree, (Has $t 'Cannot')) } }
    Row-Op 'MKEEP' 'mk' 1 728 $null { param($t, $s, $l, $c) $names = (($l | ForEach-Object { $_.Replace([string][char]92, '/') } | Sort-Object) -join ' '); $left = ('' + $s.mk_left).Trim(); @{ Ok = ($s.mk_secret -eq '1' -and $left -eq './sub ./sub/secret.txt' -and $names -eq 'tree/other/fine.txt tree/sub/good.txt tree/top.txt' -and (Has $t 'Permission denied')); Facts = ("move a tree with one unreadable file: left on the server '{0}' (expected './sub ./sub/secret.txt'); local files '{1}'; the reason shown {2}" -f $left, $names, (Has $t 'Permission denied')) } }
    Row-Op 'MSKIP' 'ms' 1 728 $null { param($t, $s, $l, $c) $left = ('' + $s.ms_left).Trim(); $old = ''; try { $old = [IO.File]::ReadAllText($LP + $StartDir + '\MSKIP\tree\exists.txt').Trim() } catch { }; @{ Ok = ($left -eq './exists.txt' -and $old -eq 'LOCAL-ORIGINAL' -and $l.Count -eq 2); Facts = ("move a tree with a file that exists locally, answer No: left on the server '{0}' (expected './exists.txt'); the local file still holds '{1}'; local files {2}" -f $left, $old, $l.Count) } } '' $false '' '' 'NoToOverwrite'
    Row-Op 'MCASE' 'mc' 1 728 $null { param($t, $s, $l, $c) $left = ('' + $s.mc_left).Trim(); $dir = $LP + $StartDir + '\MCASE\tree'; $got = @{}; foreach ($f in @([IO.Directory]::GetFiles($dir))) { $got[[IO.Path]::GetFileName($f)] = [IO.File]::ReadAllText($f).Trim() }; $one = @($got.Keys | Where-Object { $_ -ieq 'a.txt' }); $content = $(if ($one.Count -eq 1) { $got[$one[0]] } else { '' }); $kept = $(if ($content -eq 'first-content-AAAA') { './a.txt' } elseif ($content -eq 'second') { './A.txt' } else { '?' }); @{ Ok = ($one.Count -eq 1 -and $kept -ne '?' -and $left -eq $kept -and $got['b.txt'] -eq 'third' -and (Has $t 'same local name')); Facts = ("move a directory with A.txt and a.txt (one file on Windows): local '{0}' holds '{1}'; left on the server '{2}' (must be the other one: '{3}'); b.txt moved {4}; the collision said {5}" -f ($one -join ','), $content, $left, $kept, ($got['b.txt'] -eq 'third'), (Has $t 'same local name')) } }
    Row-Op 'MBLOCK' 'mb' 1 728 $null { param($t, $s, $l, $c) $left = ('' + $s.mb_left).Trim(); @{ Ok = ($left -eq './a ./b ./b/c' -and (Has $t 'Cannot')); Facts = ("move a tree of empty directories whose local folder cannot be made (a file is in its place): left on the server '{0}' (expected './a ./b ./b/c'); an error shown {1}; the local file is still a file {2}" -f $left, (Has $t 'Cannot'), [IO.File]::Exists($LP + $StartDir + '\MBLOCK\proj')) } } '' $false '' '' 'FileInTheWay'
    Row-Op 'M2' 'm2' 1 728 $null { param($t, $s, $l, $c) @{ Ok = ($l.Count -eq 1 -and $s.m2_file -eq '0'); Facts = ("move one file: local files {0}; still on the server {1}" -f $l.Count, $s.m2_file) } }
    Row-Op 'URL' 'm2' 0 0 $null { param($t, $s, $l, $c) @{ Ok = $c.Ok; Facts = ("the address typed with two slashes (sftp://user@host:port/path): connected {0}" -f $c.Ok) } } '' $false '' 'sftp://tctest@localhost:2222'
    # feature 137: Quick Rename (command 754) with a name that fits and with one that does not
    $y250 = 'y' * 250
    Row-Op 'QR250' 'q1' 1 754 $y250 { param($t, $s, $l, $c) @{ Ok = ($s.q1_one -eq '0' -and $s.q1_entries -eq '1' -and $s.q1_longest -eq '250'); Facts = ("Quick Rename to a name of 250 letters: the old name is gone {0}; entries {1}; the name on the server has {2} bytes" -f ($s.q1_one -eq '0'), $s.q1_entries, $s.q1_longest) } }
    $cjk = ([string][char]0x4E2D) * 100 + '.txt'      # 100 CJK letters: 304 bytes of UTF-8
    Row-Op 'QRLONG' 'q2' 1 754 $cjk { param($t, $s, $l, $c) $said = (Has $t 'too long'); @{ Ok = ($s.q2_one -eq '1' -and $s.q2_entries -eq '1' -and $said); Facts = ("Quick Rename to a name of 304 bytes (100 CJK letters): 'too long' said {0}; the file kept its name {1}; entries {2}; longest name on the server {3} bytes; the names there are valid UTF-8 {4}" -f $said, ($s.q2_one -eq '1'), $s.q2_entries, $s.q2_longest, ($s.q2_validutf8 -eq '1')) } }
    # feature 139: nothing is replaced without a question, and never before its replacement is whole
    $AE = 'already exists'
    $one = { param($d) [IO.File]::WriteAllText($LP + $d + '\report.txt', 'LOCAL-NEW-CONTENT') }
    $big = { param($d) [IO.File]::WriteAllText($LP + $d + '\big.bin', (BigText)) }
    Row-Up 'UPASKNO' 'ua' 1 727 $one { param($t, $s, $l, $c) @{ Ok = ((Has $t $AE) -and $s.ua_content -eq 'SERVER-OLD' -and $s.ua_entries -eq '1'); Facts = ("upload over an existing file, answer No: the question came {0}; the server's file holds '{1}'; entries there {2}" -f (Has $t $AE), $s.ua_content, $s.ua_entries) } } '' $true
    Row-Up 'UPASKYES' 'ub' 1 727 $one { param($t, $s, $l, $c) @{ Ok = ((Has $t $AE) -and $s.ub_content -eq 'LOCAL-NEW-CONTENT' -and $s.ub_mode -eq '640' -and $s.ub_entries -eq '1'); Facts = ("upload over an existing file, answer Yes: the question came {0}; the server's file holds '{1}', mode {2} (was 640); entries there {3}" -f (Has $t $AE), $s.ub_content, $s.ub_mode, $s.ub_entries) } }
    Row-Up 'UPFAIL' 'uf' 1 727 $big { param($t, $s, $l, $c) @{ Ok = ($s.uf_content -eq 'SERVER-OLD' -and $s.uf_entries -eq '1' -and (Has $t 'Cannot|error|failed')); Facts = ("upload over an existing file, cut after 100,000 of 300,000 bytes: the server's file holds '{0}' ({1} bytes); entries there {2}; an error shown {3}" -f $s.uf_content, $s.uf_size, $s.uf_entries, (Has $t 'Cannot|error|failed')) } } '/big.bin;100000'
    Row-Up 'UPNEWFAIL' 'un' 1 727 $big { param($t, $s, $l, $c) @{ Ok = ($s.un_entries -eq '0' -and (Has $t 'Cannot|error|failed')); Facts = ("upload of a new file, cut after 100,000 bytes: entries on the server {0} (expected 0); an error shown {1}" -f $s.un_entries, (Has $t 'Cannot|error|failed')) } } '/big.bin;100000'
    $script:XferSeam = '/big.bin;100000'
    Row-Op 'DLFAIL' 'df' 1 727 $null { param($t, $s, $l, $c) $d = $LP + $StartDir + '\DLFAIL'; $old = ''; try { $old = [IO.File]::ReadAllText($d + '\big.bin') } catch { $old = '(no file)' }; if ($old.Length -gt 40) { $old = '(' + $old.Length + ' bytes)' }; $n = @([IO.Directory]::GetFiles($d)).Count; @{ Ok = ($old -eq 'LOCAL-ORIGINAL' -and $n -eq 1 -and (Has $t $AE)); Facts = ("download over an existing local file (Yes), cut after 100,000 bytes: the local file holds '{0}'; files in the folder {1}; the question came {2}" -f $old, $n, (Has $t $AE)) } } '' $false '' '' 'LocalBigExists'
    Row-Op 'RENEXIST' 'rn' 1 754 'b.txt' { param($t, $s, $l, $c) @{ Ok = ($s.rn_a -eq 'AAA' -and $s.rn_b -eq 'BBB' -and (Has $t $AE)); Facts = ("Quick Rename of a.txt to b.txt, which exists: a.txt holds '{0}', b.txt holds '{1}'; 'already exists' said {2}" -f $s.rn_a, $s.rn_b, (Has $t $AE)) } }
    Row-Up 'UPSYM' 'us' 1 727 $one { param($t, $s, $l, $c) @{ Ok = ((Has $t $AE) -and $s.us_link -eq '1' -and $s.us_real -eq 'LOCAL-NEW-CONTENT' -and $s.us_entries -eq '2'); Facts = ("upload over a symbolic link (Yes): the question came {0}; the link is still a link {1}; the file it points to holds '{2}'; entries there {3} (expected 2)" -f (Has $t $AE), $s.us_link, $s.us_real, $s.us_entries) } }
    Row-Op 'RENCASE' 'rc' 1 754 'A.txt' { param($t, $s, $l, $c) $n = ('' + $s.rc_names).Trim(); @{ Ok = ($n -eq 'A.txt' -and $s.rc_content -eq 'CCC' -and -not (Has $t 'Cannot')); Facts = ("Quick Rename of a.txt to A.txt (only the case differs): names on the server '{0}'; content '{1}'; an error shown {2}" -f $n, $s.rc_content, (Has $t 'Cannot')) } }
    $mvok = { param($d) NewDir ($d + '\tree\a'); NewDir ($d + '\tree\e'); [IO.File]::WriteAllText($LP + $d + '\tree\a\x.txt', 'xx'); [IO.File]::WriteAllText($LP + $d + '\tree\y.txt', 'yy') }
    Row-Up 'UPMV' 'uv' 1 728 $mvok { param($t, $s, $l, $c) $left = ('' + $s.uv_left).Trim(); $loc = Rel $l; @{ Ok = ($left -eq './tree ./tree/a ./tree/a/x.txt ./tree/e ./tree/y.txt' -and $loc -eq '' -and -not (Has $t 'Cannot')); Facts = ("move a local tree to the server: on the server '{0}'; left on the disk '{1}'; errors shown {2}" -f $left, $loc, (Has $t 'Cannot')) } }
    # the server holds a FILE named tree/blocked: that folder cannot be created there
    $mvblk = { param($d) NewDir ($d + '\tree\blocked\deep'); NewDir ($d + '\tree\ok'); [IO.File]::WriteAllText($LP + $d + '\tree\ok\1.txt', 'one'); [IO.File]::WriteAllText($LP + $d + '\tree\3.txt', 'three') }
    Row-Up 'UPMOVE' 'um' 1 728 $mvblk { param($t, $s, $l, $c) $left = ('' + $s.um_left).Trim(); $loc = Rel $l; @{ Ok = ($left -eq './tree ./tree/3.txt ./tree/blocked ./tree/ok ./tree/ok/1.txt' -and $s.um_blocked -eq 'a-file' -and $loc -eq 'tree tree/blocked tree/blocked/deep' -and (Has $t 'Cannot')); Facts = ("move a local tree, one folder of which the server cannot create: on the server '{0}' (blocked is still '{1}'); left on the disk '{2}' (expected 'tree tree/blocked tree/blocked/deep'); an error shown {3}" -f $left, $s.um_blocked, $loc, (Has $t 'Cannot')) } }
    $lnk = { param($d) NewDir ($d + '\tree\real'); NewDir ($d + '\elsewhere'); [IO.File]::WriteAllText($LP + $d + '\tree\real\r.txt', 'r'); [IO.File]::WriteAllText($LP + $d + '\elsewhere\t.txt', 't'); [void](& cmd /c mklink /J ($d + '\tree\link') ($d + '\elsewhere') 2>&1) }
    Row-Up 'UPLINK' 'ul' 2 727 $lnk { param($t, $s, $l, $c) $left = ('' + $s.ul_left).Trim(); $said = (Has $t 'link|skipped|junction'); @{ Ok = ($left -eq './tree ./tree/real ./tree/real/r.txt' -and $said); Facts = ("copy a local tree with a junction in it: on the server '{0}'; the skipped link was said {1}" -f $left, $said) } }
    $seam = '/many;10;1'
    $LE = 'many'
    Row-Op 'LISTCOPY' 'l1' 1 727 $null { param($t, $s, $l, $c) $said = [bool](@($t | Where-Object { $_ -match 'many' -and $_ -notmatch 'Copy|typed' -and $_ -match 'list|read|Cannot|Unable|error' }).Count); @{ Skip = ($l.Count -eq 30); Ok = ($said -and $s.l1_many -eq '30'); Facts = ("copy a directory whose listing fails at the 10th entry: local files {0} of 30; an error names the directory {1}; files on the server {2}{3}" -f $l.Count, $said, $s.l1_many, $(if ($l.Count -eq 30) { ' - the seam is not in this build' } else { '' })) } } $seam
    Row-Op 'LISTMOVE' 'l2' 1 728 $null { param($t, $s, $l, $c) $said = [bool](@($t | Where-Object { $_ -match 'many' -and $_ -notmatch 'Move|typed' -and $_ -match 'list|read|Cannot|Unable|error' }).Count); @{ Skip = ($l.Count -eq 30); Ok = ($said -and $s.l2_many -eq '30'); Facts = ("move it: local files {0} of 30; an error names the directory {1}; files on the server {2} of 30{3}" -f $l.Count, $said, $s.l2_many, $(if ($l.Count -eq 30) { ' - the seam is not in this build' } else { '' })) } } $seam
    Row-Op 'LISTPANEL' 'l3/many' 0 0 $null { param($t, $s, $l, $c) $said = (Has $t 'Cannot list directory.*many') -or ($c.Notes -match 'Cannot list directory.*many'); $back = ($c.Loc -match '/l3$'); @{ Ok = ($said -and $back); Facts = ("go to the directory while its listing fails: an error box names it {0}; the panel shows the parent directory instead of a partial list {1} ('{2}')" -f $said, $back, (Tail $c.Loc 30)) } } $seam
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { [void](Server 'clean') } catch { Out ('Server: could not clean: ' + $_.Exception.Message) }
    $junction = $StartDir + '\UPLINK\tree\link'      # a junction is removed as a link, before the tree
    if ([IO.Directory]::Exists($junction)) { [void](& cmd /c rmdir $junction 2>&1) }
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
