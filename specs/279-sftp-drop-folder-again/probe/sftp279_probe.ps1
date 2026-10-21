<#
.SYNOPSIS
    Feature 279: SFTP - a folder uploaded again into an upload-only ("drop") folder sends its
    files; a folder of which the server confirmed nothing fails with one box and is kept.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). Two servers:
    - dropsftp.py (next to this file; Python with paramiko; a copy of 258's that answers a request
      under a FILE with "no such file", as OpenSSH does) on 127.0.0.1:$Port, root under
      %TEMP%\tc279\srv: in /drop it refuses stat / lstat / listing / rename / remove;
    - the OpenSSH container 'tandem-sftp' (localhost:2222), prepared as root with fixture279.sh
      through 'docker exec' (a root 0700 folder and symbolic links to it).
    Every row is its own start of the program: the left panel holds the row's local folder, the
    right panel connects by a typed address, the probe's keys reach the left list; the target is
    typed into the Copy / Move dialog; every dialog is answered Yes / OK.

    Rows (drop server):
      DROPDIR    Copy the folder pack (a.txt, b.txt) to /drop (a first upload): PASS = both arrive, no box
      DROPDIR2   Move pack2 (c.txt) to /drop where drop\pack2 exists (the server will not show it):
                 PASS = drop\pack2\c.txt arrives, the local pack2 is gone, no box (FAIL before 279)
      DROPAGAIN  Copy pack3 (new.txt, old.txt) to /drop where drop\pack3\old.txt exists: PASS =
                 new.txt arrives, old.txt keeps its content, one "Cannot upload" box, no
                 "Cannot create" box
      DROPNEST   Move pack4 (sub\d.txt) to /drop where drop\pack4\sub exists: PASS = d.txt arrives,
                 the local pack4 is gone (a confirmed file confirms both unconfirmed folders), no box
      DROPHOLE   Move the EMPTY folder hole to /drop where drop\hole is a FILE: PASS = one box names
                 the folder ("nothing of it was confirmed"), the local folder stays, the file unchanged
      DROPEMPTY  Move the EMPTY folder empty to /drop where drop\empty exists: PASS = the same
                 (review 2 of 258, MUST-1: such a folder was deleted)
      DROPHOLE2  Move hole2 (a.txt, b.txt) to /drop where drop\hole2 is a FILE: PASS = ONE box
                 ("the folder is not there"), no box per file, the server was asked to create one
                 file only, the local files stay
    Rows (OpenSSH):
      OSSHCTL    Move the EMPTY folder ctl to tc279/pub (a plain folder): PASS = created, the local
                 folder gone, no box (an ordinary folder is not touched by the change)
      OSSHLINK   Move the EMPTY folder x to tc279 where x is a link into the root 0700 folder: PASS =
                 one box names the folder, the local folder stays, nothing arrived
      OSSHLINK2  Move x2 (c.txt) the same way: PASS = the folder box, the local c.txt stays, nothing
                 arrived (the file's own box is a recorded limit: a refusal for a right is the file's)
    The product's registry key is exported, restored and compared. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label = 'after',
    [string]$OutFile,
    [string[]]$Only,
    [int]$Port = 2279
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc279'
$StartDir = $Root + '\start'
$Srv = $Root + '\srv'
$SrvLog = $Root + '\server.log'
$Addr = 'sftp:tctest@localhost:' + $Port
$OsshAddr = 'sftp:tctest@localhost:2222'
$OsshBase = '/home/tctest/tc279'
$Password = 'tandem123'
$FixtureText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixture279.sh')).Replace("`r", '')

# runs fixture279.sh in the container as root with one argument; returns its output lines
function Ossh([string]$Arg) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = 'docker'
    $psi.Arguments = 'exec -i -u root tandem-sftp bash -s ' + $Arg
    $psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($FixtureText); $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw ('docker exec failed (' + $p.ExitCode + '): ' + $err.Trim()) }
    return @($out -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
function OsshState { $h = @{}; foreach ($l in (Ossh 'state')) { $kv = $l -split '=', 2; if ($kv.Count -eq 2) { $h[$kv[0]] = $kv[1] } }; return $h }

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T279', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
function Dialogs([int]$Id) { return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) -and [Drv098f]::IsWindowVisible($_) }) }
function BtnById([IntPtr]$Dlg, [int[]]$Ids) { foreach ($w in $Ids) { $b = Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($b) { return $b } }; return $null }
# the password and host key dialogs of a (re)connection; TRUE when one was answered
function Login([IntPtr]$h) {
    $pw = Find-Ctl $h 630
    if ($pw -ne [IntPtr]::Zero) { [void][Drv098f]::SetText($pw, $Password, 5000); Click-Ok $h; return 'password' }
    $once = BtnById $h @(644, 643)
    if ($once) { Click $once; return 'host key' }
    return $null
}

# types the address into Change Directory and answers the password / host key dialogs
function Connect([int]$Id, [string]$Prefix, [string]$RemoteDir) {
    $notes = @()
    [void](Do-ChangeDir $Id ($Prefix + $RemoteDir))
    $sw = [Diagnostics.Stopwatch]::StartNew(); $quiet = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 45 -and $quiet.Elapsed.TotalSeconds -lt 4) {
        $acted = $false
        foreach ($h in (Dialogs $Id)) {
            if ([Drv098f]::Txt($h) -eq 'Change Directory') { $notes += 'Change Directory came back'; Close-Win $h; $acted = $true; break }
            $l = Login $h
            if ($l) { $notes += $l; $acted = $true; break }
            $ok = BtnById $h @(1)
            if ($ok -and (Buttons $h).Count -le 2) { $notes += ('box: ' + (Tail (WinDesc $h) 200)); Click $ok; $acted = $true; break }
        }
        if ($acted) { $quiet.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    Sync $Id
    $loc = Get-Loc $Id
    return [pscustomobject]@{ Loc = $loc; Notes = ($notes -join ', '); Ok = ($loc -like ('sftp:*' + $RemoteDir.TrimEnd('/') + '*')) }
}

# answers every dialog until none shows for $Quiet seconds: a login dialog as Connect, else Yes /
# OK, else Skip / Close by text; a dialog whose only button is Cancel (a progress or wait window)
# is left alone. $FirstEdit: text for the first dialog with an edit (the Copy / Move target).
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
            $l = Login $h
            if ($l) { $texts += $l; $acted = $true; break }
            # the core shows its Copy / Move dialog again after an operation that failed: Cancel
            if (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 209 }).Count) {
                if ($seenOp) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
                $seenOp = $true
            }
            if ($FirstEdit -and -not $typed) {
                $edit = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
                if ($edit) { [void][Drv098f]::SetText($edit, $FirstEdit, 5000); $typed = $true; $texts += ('typed into [' + (Tail ([Drv098f]::Txt($h)) 40) + ']'); Click-Ok $h; $acted = $true; break }
            }
            $b = BtnById $h @(6, 1)
            if (-not $b) { $b = $bs | Where-Object { [Drv098f]::Txt($_) -match '^&?(Skip|Close)$' } | Select-Object -First 1 }
            $texts += (Esc $desc)
            if ($b) { Click $b } else { Close-Win $h }
            $acted = $true
            break
        }
        if ($acted) { $last.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    return $texts
}
function Has([string[]]$Texts, [string]$Rx) { return [bool](@($Texts | Where-Object { $_ -match $Rx }).Count) }
function Count([string[]]$Texts, [string]$Rx) { return @($Texts | Where-Object { $_ -match $Rx }).Count }
function SrvText([string]$Rel) { $p = $Srv + '\' + $Rel; if ([IO.File]::Exists($LP + $p)) { return [IO.File]::ReadAllText($LP + $p) }; return '(none)' }
function SrvOpens([string]$Prefix) { if (-not [IO.File]::Exists($LP + $SrvLog)) { return -1 }; return @([IO.File]::ReadAllLines($LP + $SrvLog) | Where-Object { $_ -match (' open ' + [regex]::Escape($Prefix) + '\S* flags=') }).Count }   # requests only (an error adds a line of its own)
function LocalHas([string]$p) { return [IO.File]::Exists($LP + $p) -or [IO.Directory]::Exists($LP + $p) }

# one row: $Setup { param($local) } fills the row's local folder (left panel) and the server; the
# right panel connects to $Prefix + $Dir; the focus goes $Down times Down after Home; the core's
# command $Vk (727 Copy, 728 Move) runs once; $Typed = the target typed into the Copy / Move dialog.
# $Judge { param($texts, $local, $conn) } returns @{ Ok; Facts }
function Row-Up([string]$Case, [string]$Prefix, [string]$Dir, [int]$Down, [int]$Vk, [scriptblock]$Setup, [scriptblock]$Judge, [string]$Typed) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case
    try {
        NewDir $local
        & $Setup $local | Out-Null
        $id = Start-P
        [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09
        $conn = Connect $id $Prefix $Dir
        Key $id 0x09
        Key $id 0x24
        for ($i = 0; $i -lt $Down; $i++) { Key $id 0x28 }
        Post-Cmd (Get-Main $id) $Vk; Start-Sleep -Milliseconds 700
        $texts = @(Answer $id 120 6 $Typed)
        Sync $id
        $r = & $Judge $texts $local $conn
        Row $Case 'ROW' (V ([bool]$r.Ok)) ("{0}; connected: {1} [{2}] at '{3}'; dialogs: {4}" -f $r.Facts, $conn.Ok, $conn.Notes, (Tail $conn.Loc 60), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before }
    }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc279_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0; $server = $null; $osshReady = $false
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Srv
    Set-Config
    $server = Start-Process -FilePath 'python' -ArgumentList @(('"{0}"' -f (Join-Path $PSScriptRoot 'dropsftp.py')), $Port, ('"{0}"' -f $Srv), ('"{0}"' -f $SrvLog)) -WindowStyle Hidden -PassThru
    $sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
    while (-not $up -and $sw.Elapsed.TotalSeconds -lt 20) { try { $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $Port); $c.Close(); $up = $true } catch { Start-Sleep -Milliseconds 300 } }
    if (-not $up) { throw 'the test server did not start' }
    Out ("sftp279_probe (feature 279), run: {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : dropsftp.py pid {0} on 127.0.0.1:{1}, root {2}; OpenSSH container tandem-sftp at {3}" -f $server.Id, $Port, $Srv, $OsshBase)
    Out ''
    $Target = $Addr + '/drop'
    $Box = 'Cannot upload|Cannot create|denied|could not|error'

    Row-Up 'DROPDIR' $Addr '/pub' 1 727 { param($l) NewDir ($l + '\pack'); WriteFile ($l + '\pack\a.txt') 'PACK-A'; WriteFile ($l + '\pack\b.txt') 'PACK-B' } { param($t, $l, $c) $a = SrvText 'drop\pack\a.txt'; $b = SrvText 'drop\pack\b.txt'; @{ Ok = ($a -ceq 'PACK-A' -and $b -ceq 'PACK-B' -and -not (Has $t $Box)); Facts = ("first upload: drop\pack\a.txt '{0}', b.txt '{1}'; an error box {2}" -f $a, $b, (Has $t $Box)) } } $Target
    Row-Up 'DROPDIR2' $Addr '/pub' 1 728 { param($l) NewDir ($l + '\pack2'); WriteFile ($l + '\pack2\c.txt') 'PACK2-C'; NewDir ($Srv + '\drop\pack2') } { param($t, $l, $c) $v = SrvText 'drop\pack2\c.txt'; $gone = -not (LocalHas ($l + '\pack2')); @{ Ok = ($v -ceq 'PACK2-C' -and $gone -and -not (Has $t $Box)); Facts = ("Move of pack2 into /drop where drop\pack2 exists (not shown): drop\pack2\c.txt '{0}'; the local pack2 gone {1}; an error box {2}" -f $v, $gone, (Has $t $Box)) } } $Target
    Row-Up 'DROPAGAIN' $Addr '/pub' 1 727 { param($l) NewDir ($l + '\pack3'); WriteFile ($l + '\pack3\new.txt') 'PACK3-NEW'; WriteFile ($l + '\pack3\old.txt') 'PACK3-LOCAL'; NewDir ($Srv + '\drop\pack3'); WriteFile ($Srv + '\drop\pack3\old.txt') 'OLD-3' } { param($t, $l, $c) $n = SrvText 'drop\pack3\new.txt'; $o = SrvText 'drop\pack3\old.txt'; $up = Count $t 'Cannot upload'; $cr = Has $t 'Cannot create'; @{ Ok = ($n -ceq 'PACK3-NEW' -and $o -ceq 'OLD-3' -and $up -eq 1 -and -not $cr); Facts = ("Copy of pack3 again: new.txt '{0}'; old.txt '{1}' (kept); 'Cannot upload' boxes {2}; a 'Cannot create' box {3}" -f $n, $o, $up, $cr) } } $Target
    Row-Up 'DROPNEST' $Addr '/pub' 1 728 { param($l) NewDir ($l + '\pack4'); NewDir ($l + '\pack4\sub'); WriteFile ($l + '\pack4\sub\d.txt') 'PACK4-D'; NewDir ($Srv + '\drop\pack4'); NewDir ($Srv + '\drop\pack4\sub') } { param($t, $l, $c) $v = SrvText 'drop\pack4\sub\d.txt'; $gone = -not (LocalHas ($l + '\pack4')); @{ Ok = ($v -ceq 'PACK4-D' -and $gone -and -not (Has $t $Box)); Facts = ("Move of pack4\sub\d.txt where drop\pack4\sub exists: d.txt '{0}'; the local pack4 gone {1}; an error box {2}" -f $v, $gone, (Has $t $Box)) } } $Target
    Row-Up 'DROPHOLE' $Addr '/pub' 1 728 { param($l) NewDir ($l + '\hole'); WriteFile ($Srv + '\drop\hole') 'A-FILE' } { param($t, $l, $c) $kept = [IO.Directory]::Exists($LP + $l + '\hole'); $n = Count $t 'Cannot create directory "/drop/hole".*nothing of it was confirmed'; $all = Count $t 'SFTP Error'; $f = SrvText 'drop\hole'; @{ Ok = ($n -eq 1 -and $all -eq 1 -and $kept -and $f -ceq 'A-FILE'); Facts = ("Move of the EMPTY folder hole where drop\hole is a file: folder boxes {0} (all error boxes {1}); the local folder kept {2}; drop\hole still '{3}'" -f $n, $all, $kept, $f) } } $Target
    Row-Up 'DROPEMPTY' $Addr '/pub' 1 728 { param($l) NewDir ($l + '\empty'); NewDir ($Srv + '\drop\empty') } { param($t, $l, $c) $kept = [IO.Directory]::Exists($LP + $l + '\empty'); $n = Count $t 'Cannot create directory "/drop/empty".*nothing of it was confirmed'; $all = Count $t 'SFTP Error'; @{ Ok = ($n -eq 1 -and $all -eq 1 -and $kept); Facts = ("Move of the EMPTY folder empty where drop\empty exists (not shown): folder boxes {0} (all error boxes {1}); the local folder kept {2} (review 2 of 258, MUST-1)" -f $n, $all, $kept) } } $Target
    Row-Up 'DROPHOLE2' $Addr '/pub' 1 728 { param($l) NewDir ($l + '\hole2'); WriteFile ($l + '\hole2\a.txt') 'H2-A'; WriteFile ($l + '\hole2\b.txt') 'H2-B'; WriteFile ($Srv + '\drop\hole2') 'A-FILE-2' } { param($t, $l, $c) $kept = [IO.File]::Exists($LP + $l + '\hole2\a.txt') -and [IO.File]::Exists($LP + $l + '\hole2\b.txt'); $n = Count $t 'Cannot create directory "/drop/hole2".*the folder is not there'; $all = Count $t 'SFTP Error'; $opens = SrvOpens '/drop/hole2/'; $f = SrvText 'drop\hole2'; @{ Ok = ($n -eq 1 -and $all -eq 1 -and $opens -eq 1 -and $kept -and $f -ceq 'A-FILE-2'); Facts = ("Move of hole2 (2 files) where drop\hole2 is a file: 'not there' boxes {0} (all error boxes {1}); creations asked of the server {2}; the local files kept {3}; drop\hole2 still '{4}'" -f $n, $all, $opens, $kept, $f) } } $Target

    # ---- OpenSSH (tandem-sftp) -------------------------------------------------------------
    if (@('OSSHCTL', 'OSSHLINK', 'OSSHLINK2' | Where-Object { Want $_ }).Count) {
        try { $ready = Ossh ''; $osshReady = ($ready -contains 'ready') } catch { $osshReady = $false; Out ('OpenSSH fixture: ' + $_.Exception.Message) }
        if (-not $osshReady) {
            foreach ($n in @('OSSHCTL', 'OSSHLINK', 'OSSHLINK2')) { if (Want $n) { Row $n 'ROW' 'NOT DRIVEN' 'the container tandem-sftp could not be prepared' } }
        }
        else {
            $OTarget = $OsshAddr + $OsshBase
            Row-Up 'OSSHCTL' $OsshAddr ($OsshBase + '/pub') 1 728 { param($l) NewDir ($l + '\ctl') } { param($t, $l, $c) $s = OsshState; $gone = -not (LocalHas ($l + '\ctl')); @{ Ok = ($s['ctl_dir'] -eq '1' -and $gone -and -not (Has $t $Box)); Facts = ("Move of the EMPTY folder ctl into tc279/pub: created on the server {0}; the local folder gone {1}; an error box {2}" -f $s['ctl_dir'], $gone, (Has $t $Box)) } } ($OsshAddr + $OsshBase + '/pub')
            Row-Up 'OSSHLINK' $OsshAddr ($OsshBase + '/pub') 1 728 { param($l) NewDir ($l + '\x') } { param($t, $l, $c) $s = OsshState; $kept = [IO.Directory]::Exists($LP + $l + '\x'); $n = Count $t ('Cannot create directory "' + $OsshBase + '/x".*nothing of it was confirmed'); $all = Count $t 'SFTP Error'; @{ Ok = ($n -eq 1 -and $all -eq 1 -and $kept -and $s['x_link'] -eq '1' -and $s['inner_entries'] -eq '0'); Facts = ("Move of the EMPTY folder x onto a link into a root 0700 folder: folder boxes {0} (all error boxes {1}); the local folder kept {2}; x still a link {3}; entries behind it {4}" -f $n, $all, $kept, $s['x_link'], $s['inner_entries']) } } $OTarget
            Row-Up 'OSSHLINK2' $OsshAddr ($OsshBase + '/pub') 1 728 { param($l) NewDir ($l + '\x2'); WriteFile ($l + '\x2\c.txt') 'X2-C' } { param($t, $l, $c) $s = OsshState; $kept = [IO.File]::Exists($LP + $l + '\x2\c.txt'); $n = Count $t ('Cannot create directory "' + $OsshBase + '/x2".*nothing of it was confirmed'); $all = Count $t 'SFTP Error'; @{ Ok = ($n -eq 1 -and $kept -and $s['inner2_entries'] -eq '0'); Facts = ("Move of x2 (c.txt) onto a link into a root 0700 folder: folder boxes {0} (all error boxes {1} - the file's own box is a recorded limit); the local c.txt kept {2}; entries behind the link {3}" -f $n, $all, $kept, $s['inner2_entries']) } } $OTarget
        }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
    if ($osshReady) { try { [void](Ossh 'clean') } catch { Out ('OpenSSH fixture clean: ' + $_.Exception.Message) } }
    Start-Sleep -Milliseconds 400
    if ([IO.File]::Exists($SrvLog)) { Out ''; Out 'Server log:'; foreach ($l in [IO.File]::ReadAllLines($SrvLog)) { Out ('  ' + (Esc $l)) } }
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
