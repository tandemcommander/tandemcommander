<#
.SYNOPSIS
    Feature 258: SFTP upload into a write-only ("drop") folder, the overwrite question names the
    limits of a replacement, and temporary files left by a lost connection are offered for removal.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). The server is dropsftp.py (next
    to this file; Python with paramiko), started here on 127.0.0.1:$Port with its root under
    %TEMP%\tc258\srv: in /drop it refuses stat / lstat / listing / rename / remove (an upload-only
    folder); /cut drops the connection at the close of an upload while cut\.armed exists; /pub is
    a plain folder. The server's state is read from its root folder. Every row is its own start of
    the program: the left panel holds the row's local folder, the right panel connects by a typed
    address, the probe's keys reach the left list; every dialog is answered Yes / OK.

    Rows:
      DROPNEW    Copy up.txt to the typed target /drop: PASS = drop\up.txt holds the new content,
                 no .tcpart-* in drop, no error box
      DROPEXIST  the same with drop\up.txt there already: PASS = it keeps its content, an error
                 box says why, no .tcpart-* in drop (the server would let a truncating open
                 overwrite it: only the product's exclusive create keeps it)
      DROPMOVE   Move mv.txt to /drop: PASS = drop\mv.txt holds it, the local source is gone
      DROPDIR    Copy the folder pack (a.txt, b.txt) to /drop: PASS = drop\pack\a.txt, b.txt
      DROPFAIL   Copy big.bin (300,000 bytes) to /drop, the write fails after 1,000 bytes (debug seam
                 TC_SFTP_PROBE_XFER_FAIL): PASS = the box says a partial file may remain (the server
                 refuses its removal), the local file stays
      DROPDIR2   Move the folder pack2 (c.txt) to /drop where drop\pack2 exists already (the
                 server will not show it): PASS = a box names the folder, the local files stay
                 (a folder uploaded again into a drop folder is a recorded limit)
      DROPHOLE   Move the EMPTY folder hole to /drop where drop\hole is a file: PASS = a box
                 names the folder, the local folder stays (review 2 of 258, MUST-1)
      DROPNOEXCL Move mv.txt to /dropnx (a drop folder whose server IGNORES the exclusive create)
                 over an existing longer file: PASS = the server file holds exactly the new
                 content - never the new content over the old file's tail reported as complete
                 (review 3 of 258, SHOULD-1; the old file is lost there - a stated limit)
      REPL       Copy r.txt over /pub/r.txt (the question answered Yes): PASS = replaced, the
                 question names hard links and the ACL
      CUT        Copy c.txt to /cut, the connection is dropped at the close of its temporary file;
                 then Copy c.txt again: PASS = the second copy offers the removal of the left
                 .tcpart-*, it is gone, cut\c.txt holds the content
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
    [int]$Port = 2258
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc258'
$StartDir = $Root + '\start'
$Srv = $Root + '\srv'
$SrvLog = $Root + '\server.log'
$Addr = 'sftp:tctest@localhost:' + $Port
$Password = 'tandem123'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T258', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
function Connect([int]$Id, [string]$RemoteDir) {
    $notes = @()
    [void](Do-ChangeDir $Id ($Addr + $RemoteDir))
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
function BigText { return ('0123456789ABCDEF' * 18750) }      # 300,000 bytes
function Has([string[]]$Texts, [string]$Rx) { return [bool](@($Texts | Where-Object { $_ -match $Rx }).Count) }
function SrvText([string]$Rel) { $p = $Srv + '\' + $Rel; if ([IO.File]::Exists($LP + $p)) { return [IO.File]::ReadAllText($LP + $p) }; return '(none)' }
function SrvParts([string]$Dir) { $p = $Srv + '\' + $Dir; if (-not [IO.Directory]::Exists($LP + $p)) { return @() }; return @([IO.Directory]::GetFileSystemEntries($LP + $p) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { $_ -like '.tcpart-*' }) }

# one row: $Setup { param($local) } fills the row's local folder (left panel) and the server; the
# right panel connects to $Dir; the focus goes $Down times Down after Home; the core's command
# $Vk (727 Copy, 728 Move) runs $Times times; $Typed = the target typed into the Copy / Move dialog.
# $Judge { param($texts, $local, $conn) } returns @{ Ok; Facts }
function Row-Up([string]$Case, [string]$Dir, [int]$Down, [int]$Vk, [scriptblock]$Setup, [scriptblock]$Judge, [string]$Typed = '', [int]$Times = 1, [string]$Xfer = '') {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case
    try {
        NewDir $local
        & $Setup $local | Out-Null
        # 139's debug seam: the upload of a remote path ending with the suffix fails after N bytes
        if ($Xfer) { $env:TC_SFTP_PROBE_XFER_FAIL = $Xfer } else { Remove-Item Env:\TC_SFTP_PROBE_XFER_FAIL -ErrorAction SilentlyContinue }
        $id = Start-P
        [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09
        $conn = Connect $id $Dir
        Key $id 0x09
        $texts = @()
        for ($n = 1; $n -le $Times; $n++) {
            # a failed operation (and the reconnect of the refresh after it) can leave the server
            # panel active: the command would then act on its '..' - the source is the local panel
            if ($n -gt 1) { $act = Get-Loc $id; if ($act -like 'sftp:*') { Key $id 0x09; $texts += ('(the server panel was active: Tab; now ' + (Tail (Get-Loc $id) 40) + ')') } }
            Key $id 0x24
            for ($i = 0; $i -lt $Down; $i++) { Key $id 0x28 }
            if ($Times -gt 1) { $texts += ('--- run ' + $n) }
            Post-Cmd (Get-Main $id) $Vk; Start-Sleep -Milliseconds 700
            $texts += @(Answer $id 120 6 $(if ($Typed) { $Typed } else { $null }))
            Sync $id
        }
        $r = & $Judge $texts $local $conn
        Row $Case 'ROW' (V ([bool]$r.Ok)) ("{0}; connected: {1} [{2}] at '{3}'; dialogs: {4}" -f $r.Facts, $conn.Ok, $conn.Notes, (Tail $conn.Loc 60), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        Remove-Item Env:\TC_SFTP_PROBE_XFER_FAIL -ErrorAction SilentlyContinue
        if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before }
    }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc258_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0; $server = $null
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Srv
    Set-Config
    $server = Start-Process -FilePath 'python' -ArgumentList @(('"{0}"' -f (Join-Path $PSScriptRoot 'dropsftp.py')), $Port, ('"{0}"' -f $Srv), ('"{0}"' -f $SrvLog)) -WindowStyle Hidden -PassThru
    $sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
    while (-not $up -and $sw.Elapsed.TotalSeconds -lt 20) { try { $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $Port); $c.Close(); $up = $true } catch { Start-Sleep -Milliseconds 300 } }
    if (-not $up) { throw 'the test server did not start' }
    Out ("sftp258_probe (feature 258), run: {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : dropsftp.py pid {0} on 127.0.0.1:{1}, root {2}" -f $server.Id, $Port, $Srv)
    Out ''
    $Target = $Addr + '/drop'
    $Box = 'Cannot upload|denied|could not|error'
    Row-Up 'DROPNEW' '/pub' 1 727 { param($l) WriteFile ($l + '\up.txt') 'DROP-NEW' } { param($t, $l, $c) $v = SrvText 'drop\up.txt'; $tp = SrvParts 'drop'; @{ Ok = ($v -ceq 'DROP-NEW' -and $tp.Count -eq 0 -and -not (Has $t $Box)); Facts = ("drop\up.txt holds '{0}'; .tcpart-* in drop: {1}; an error box {2}" -f $v, $tp.Count, (Has $t $Box)) } } $Target
    Row-Up 'DROPEXIST' '/pub' 1 727 { param($l) WriteFile ($l + '\up.txt') 'DROP-NEW'; NewDir ($Srv + '\drop'); WriteFile ($Srv + '\drop\up.txt') 'OLD-DROP' } { param($t, $l, $c) $v = SrvText 'drop\up.txt'; $tp = SrvParts 'drop'; @{ Ok = ($v -ceq 'OLD-DROP' -and $tp.Count -eq 0 -and (Has $t 'Cannot upload')); Facts = ("drop\up.txt holds '{0}'; .tcpart-* in drop: {1}; the error box {2}" -f $v, $tp.Count, (Has $t 'Cannot upload')) } } $Target
    Row-Up 'DROPMOVE' '/pub' 1 728 { param($l) WriteFile ($l + '\mv.txt') 'DROP-MOVE' } { param($t, $l, $c) $v = SrvText 'drop\mv.txt'; $src = [IO.File]::Exists($LP + $l + '\mv.txt'); @{ Ok = ($v -ceq 'DROP-MOVE' -and -not $src -and (SrvParts 'drop').Count -eq 0); Facts = ("drop\mv.txt holds '{0}'; the local source still there {1}" -f $v, $src) } } $Target
    Row-Up 'DROPDIR' '/pub' 1 727 { param($l) NewDir ($l + '\pack'); WriteFile ($l + '\pack\a.txt') 'PACK-A'; WriteFile ($l + '\pack\b.txt') 'PACK-B' } { param($t, $l, $c) $a = SrvText 'drop\pack\a.txt'; $b = SrvText 'drop\pack\b.txt'; @{ Ok = ($a -ceq 'PACK-A' -and $b -ceq 'PACK-B' -and (SrvParts 'drop\pack').Count -eq 0 -and -not (Has $t $Box)); Facts = ("drop\pack\a.txt '{0}', b.txt '{1}'; an error box {2}" -f $a, $b, (Has $t $Box)) } } $Target
    Row-Up 'DROPFAIL' '/pub' 1 727 { param($l) WriteFile ($l + '\big.bin') (BigText) } { param($t, $l, $c) $p = $Srv + '\drop\big.bin'; $n = $(if ([IO.File]::Exists($LP + $p)) { (New-Object IO.FileInfo($LP + $p)).Length } else { -1 }); $said = Has $t 'Cannot upload.*partial file may remain'; @{ Ok = ($said -and $n -lt 300000 -and [IO.File]::Exists($LP + $l + '\big.bin')); Facts = ("the write fails after 1000 bytes (seam): drop\big.bin size {0} (the server refuses its removal); the box says a partial file may remain {1}" -f $n, $said) } } $Target 1 'big.bin;1000'
    Row-Up 'DROPDIR2' '/pub' 1 728 { param($l) NewDir ($l + '\pack2'); WriteFile ($l + '\pack2\c.txt') 'PACK2-C'; NewDir ($Srv + '\drop\pack2') } { param($t, $l, $c) $v = SrvText 'drop\pack2\c.txt'; $kept = [IO.File]::Exists($LP + $l + '\pack2\c.txt'); $said = Has $t 'Cannot create'; @{ Ok = ($said -and $kept); Facts = ("Move of pack2 into /drop where drop\pack2 is there already (the server refuses to show it): the box names the folder {0}; the local pack2\c.txt kept {1}; drop\pack2\c.txt '{2}'" -f $said, $kept, $v) } } $Target
    Row-Up 'DROPHOLE' '/pub' 1 728 { param($l) NewDir ($l + '\hole'); WriteFile ($Srv + '\drop\hole') 'A-FILE' } { param($t, $l, $c) $kept = [IO.Directory]::Exists($LP + $l + '\hole'); $said = Has $t 'Cannot create'; $f = SrvText 'drop\hole'; @{ Ok = ($said -and $kept -and $f -ceq 'A-FILE'); Facts = ("Move of the EMPTY folder hole into /drop where drop\hole is a file: the box names the folder {0}; the local folder kept {1}; drop\hole still the file '{2}' (review 2 MUST-1)" -f $said, $kept, $f) } } $Target
    Row-Up 'DROPNOEXCL' '/pub' 1 728 { param($l) WriteFile ($l + '\mv.txt') 'NEW-NX'; WriteFile ($Srv + '\dropnx\mv.txt') 'OLDOLDOLDOLDOLD' } { param($t, $l, $c) $v = SrvText 'dropnx\mv.txt'; $src = [IO.File]::Exists($LP + $l + '\mv.txt'); @{ Ok = ($v -ceq 'NEW-NX'); Facts = ("Move onto an existing file of a server that ignores the exclusive create: dropnx\mv.txt holds '{0}' (never the new content over the old tail); the local source still there {1}" -f $v, $src) } } ($Addr + '/dropnx')
    Row-Up 'REPL' '/pub' 1 727 { param($l) WriteFile ($l + '\r.txt') 'REPL-NEW'; WriteFile ($Srv + '\pub\r.txt') 'REPL-OLD' } { param($t, $l, $c) $v = SrvText 'pub\r.txt'; $q = @($t | Where-Object { $_ -match 'already exists' }) -join ' '; $named = ($q -match 'hard link' -and $q -match 'ACL'); @{ Ok = ($v -ceq 'REPL-NEW' -and $named -and (SrvParts 'pub').Count -eq 0); Facts = ("pub\r.txt holds '{0}'; the question names hard links and the ACL: {1}" -f $v, $named) } }
    Row-Up 'CUT' '/cut' 1 727 { param($l) WriteFile ($l + '\c.txt') 'CUT-NEW'; WriteFile ($Srv + '\cut\.armed') 'x' } { param($t, $l, $c) $v = SrvText 'cut\c.txt'; $tp = SrvParts 'cut'; $offer = Has $t 'left on the server.*Delete them'; @{ Ok = ($v -ceq 'CUT-NEW' -and $tp.Count -eq 0 -and $offer -and -not [IO.File]::Exists($LP + $Srv + '\cut\.armed')); Facts = ("cut\c.txt holds '{0}'; .tcpart-* left in cut: {1} ({2}); a dialog named the temporary file {3}" -f $v, $tp.Count, ($tp -join ','), $offer) } } '' 2
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
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
