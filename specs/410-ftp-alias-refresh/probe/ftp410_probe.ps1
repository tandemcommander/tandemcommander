<#
.SYNOPSIS
    Feature 410: a change made through one name of an FTP server (localhost) refreshes an FTP panel
    showing the same folder through another name of it (127.0.0.1), and drops the listings cached
    under the other name.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). One server (ftpmini_sess.py:
    feature 323's ftpmini_hide.py with a session number in every log line) serves an NTFS folder on
    127.0.0.1 only, UTF-8, user "u", and logs every command with the number of its control
    connection. The left panel is local, the right one the server connected as
    ftp://u@127.0.0.1:<port>. Uploads typed to ftp://u:p@localhost:<port>/... reach the same server
    under another name. The panel's control connection is the last one connected before the upload;
    the probe watches what that connection sends.
      REFRESH-ALIAS   the item's row: upload of a new n.txt typed to localhost:/REFRESH-ALIAS (the
                      panel's folder at 127.0.0.1). PASS = the panel's connection lists its folder
                      again after the upload (before the fix: it sends nothing - the panel keeps
                      the listing without n.txt).
      REFRESH-SAME    control: the same upload typed to 127.0.0.1 - the panel lists again (before
                      and after the fix; proves the probe sees a refresh).
      REFRESH-ELSE    the path rule still holds: the upload typed to localhost:/OTHER-ELSE (another
                      folder). PASS = the panel's connection sends no listing command.
      CACHE-ALIAS     the listing cache (CListingCache) under the other name: the panel lists
                      /CACHE-ALIAS/sub, goes up (Backspace) to /CACHE-ALIAS; upload of n.txt typed
                      to localhost:/CACHE-ALIAS/sub/; the panel enters sub (Enter). PASS = the
                      panel's connection lists sub again (before the fix: the stale cached listing
                      is shown - no listing command).
      CACHE-SAME      control: the same with the upload typed to 127.0.0.1.
      VIEW-ALIAS      the viewer's cache under the other name (a finding of 410): x.txt viewed (F3)
                      in the panel at 127.0.0.1, the panel goes up to "/", an upload of n.txt typed
                      to localhost:/VIEW-ALIAS/, the panel goes back and views x.txt again. PASS =
                      x.txt downloaded again (RETR; before the fix: the old copy from the cache).
      VIEW-SAME       control: the same with the upload typed to 127.0.0.1.
    The product's registry key is exported, restored and compared. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Written in the style of 341's ftp341_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [int]$Port = 2143,
    [string]$Repo   # the repository root (default: three folders above this script)
)
$ErrorActionPreference = 'Stop'
if (-not $Repo) { $Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc410'
$StartDir = $Root + '\start'
$FtpSrv = @{ Root = ($Root + '\srv'); Log = ($Root + '\ftp.log'); Port = $Port; Enc = 'utf-8'; Proc = $null }
$MiniSess = Join-Path $PSScriptRoot 'ftpmini_sess.py'
$env:FTPMINI_DIR = Join-Path $Repo 'specs\323-ftp-upload-cache-args\probe'

function Start-Srv($S) {
    $S.Proc = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f $MiniSess), ('"{0}"' -f $S.Root), $S.Port, ('"{0}"' -f $S.Log), $S.Enc) -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
    while ($sw.Elapsed.TotalSeconds -lt 15 -and -not $up) { Start-Sleep -Milliseconds 300; try { $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $S.Port); $c.Close(); $up = $true } catch { } }
    return $up
}
function Srv-Lines($S, [int]$From) {
    if (-not [IO.File]::Exists($S.Log)) { return @() }
    $fs = New-Object IO.FileStream($S.Log, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $sr = New-Object IO.StreamReader($fs); $all = @(($sr.ReadToEnd() -split "`n") | Where-Object { $_.Trim() }) } finally { $fs.Dispose() }
    if ($all.Count -le $From) { return @() }
    return @($all[$From..($all.Count - 1)] | ForEach-Object { $_ | ConvertFrom-Json })
}
function Srv-Count($S) { return @(Srv-Lines $S 0).Count }
# the commands of control connection $Sid (all connections when $Sid is 0) from line $From on
function Srv-Cmds($S, [int]$From, [int]$Sid = 0) {
    return @(Srv-Lines $S $From | Where-Object { $_.cmd -ne $null -and ($Sid -eq 0 -or $_.sid -eq $Sid) } | ForEach-Object { $c = [string]$_.cmd; if ($c -eq '') { '(empty line)' } else { Esc $c } })
}
# the number of the last control connection the server accepted
function Last-Sid($S) { $c = @(Srv-Lines $S 0 | Where-Object { $_.event -eq 'connect' }); if (-not $c.Count) { return 0 }; return [int]$c[-1].sid }
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T410', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
function Has-Cmd($cmds, [string]$Rx) { return [bool](@($cmds | Where-Object { $_ -cmatch $Rx }).Count) }
function ReadSrv([string]$File) { try { return [IO.File]::ReadAllText($LP + $File) } catch { return '<none>' } }
$ListRx = '^(LIST|MLSD|NLST)\b'

# 288's connect (only before any operation exists: it answers every dialog of the process)
function Connect([int]$Id, [string]$Dir, [string]$SrvHost = '127.0.0.1') {
    $notes = @()
    [void](Do-ChangeDir $Id ('ftp://u:p@' + $SrvHost + ':' + $FtpSrv.Port + '/' + $Dir))
    $sw = [Diagnostics.Stopwatch]::StartNew(); $quiet = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and $quiet.Elapsed.TotalSeconds -lt 3) {
        $acted = $false
        foreach ($h in (Dialogs $Id)) {
            if ([Drv098f]::Txt($h) -eq 'Change Directory') { $notes += 'Change Directory came back'; Close-Win $h; $acted = $true; break }
            $ok = BtnById $h @(6, 1)
            if ($ok) { $notes += ('box: ' + (Tail (WinDesc $h) 200)); Click $ok; $acted = $true; break }
        }
        if ($acted) { $quiet.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    Sync $Id
    $loc = Get-Loc $Id
    return [pscustomobject]@{ Loc = $loc; Notes = ($notes -join ', '); Ok = ($loc -like ('ftp:*:' + $FtpSrv.Port + '/' + $Dir + '*')) }
}

# ---- windows of the main thread vs the operation threads ---------------------------------
function ThreadOf([IntPtr]$H) { [uint32]$procId = 0; return [Drv098f]::GetWindowThreadProcessId($H, [ref]$procId) }
function MainDialogs([int]$Id) { $t = ThreadOf (Get-Main $Id); return @(Dialogs $Id | Where-Object { (ThreadOf $_) -eq $t }) }
function OpWindows([int]$Id) {
    $t = ThreadOf (Get-Main $Id)
    return @(Get-Tops $Id | Where-Object { (ThreadOf $_) -ne $t -and [Drv098f]::IsWindowVisible($_) })
}
function OpDesc([int]$Id) {
    $w = @(OpWindows $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' }); if (-not $w.Count) { return 'none' }
    return (($w | ForEach-Object { "'" + (Esc ([Drv098f]::Txt($_))) + "' " + ((@([Drv098f]::Kids($_) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' } | ForEach-Object { Tail ([Drv098f]::GetText($_, 5000)) 60 })) -join ' | ') }) -join ' || ')
}
# the panels' list boxes, left first
function Lists([int]$Id) {
    $l = @([Drv098f]::Kids((Get-Main $Id)) | Where-Object { [Drv098f]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv098f]::IsWindowVisible($_) })
    if ($l.Count -lt 2) { throw 'two panel list windows not found' }
    return @($l | Sort-Object { $r = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($_, [ref]$r); $r.Left })
}
function KeyIn([int]$Id, [int]$Side, [int]$Vk) {
    $l = (Lists $Id)[$Side]
    [void][Drv098f]::Send($l, 0x0100, $Vk, 1, 30000)
    [void][Drv098f]::Send($l, 0x0101, $Vk, 0xC0000001, 30000)
}
function Focus([int]$Id, [int]$Side, [int]$Down) { KeyIn $Id $Side 0x24; for ($i = 0; $i -lt $Down; $i++) { KeyIn $Id $Side 0x28 }; Start-Sleep -Milliseconds 500; Sync $Id }
# waits until the server log has been quiet for $Quiet seconds (at most $Max)
function Wait-Quiet([int]$Id, [double]$Quiet = 4, [double]$Max = 30) {
    $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew(); $cnt = Srv-Count $FtpSrv
    while ($sw.Elapsed.TotalSeconds -lt $Max -and $last.Elapsed.TotalSeconds -lt $Quiet) {
        Start-Sleep -Milliseconds 300
        $n = Srv-Count $FtpSrv; if ($n -ne $cnt) { $cnt = $n; $last.Restart() }
    }
    Sync $Id
}

# posts the command and serves the dialogs of the main thread until they and the server are quiet:
# the first dialog with a visible edit gets & $Edit (old text -> new text) and OK; a dialog with an
# edit coming back is cancelled; other dialogs: Yes / OK. Windows of other threads are left alone.
function Drive([int]$Id, [int]$Cmd, [scriptblock]$Edit, [double]$Quiet = 4, [double]$Max = 60) {
    $texts = @(); $typed = $false
    $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew(); $cnt = Srv-Count $FtpSrv
    Post-Cmd (Get-Main $Id) $Cmd; Start-Sleep -Milliseconds 700
    while ($sw.Elapsed.TotalSeconds -lt $Max -and $last.Elapsed.TotalSeconds -lt $Quiet -and (Test-Alive $Id)) {
        $acted = $false
        foreach ($h in (MainDialogs $Id)) {
            $ids = @(Buttons $h | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if ($ids.Count -eq 0 -or ($ids.Count -eq 1 -and $ids[0] -eq 2)) { continue }
            Start-Sleep -Milliseconds 400
            $desc = WinDesc $h
            if ($desc -match $FatalRx) { $texts += ('FATAL ' + (Tail $desc 300)); return $texts }
            $ed = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
            if ($ed -and $typed) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
            if ($ed -and $Edit) {
                $old = [Drv098f]::GetText($ed, 5000); $new = & $Edit $old
                [void][Drv098f]::SetText($ed, $new, 5000); $typed = $true
                $texts += ("[{0}] '{1}' -> '{2}'" -f (Tail ([Drv098f]::Txt($h)) 40), (Esc $old), (Esc $new))
                Click-Ok $h; $acted = $true; break
            }
            $b = BtnById $h @(6, 1)
            $texts += (Tail $desc 300)
            if ($b) { Click $b } else { Close-Win $h }
            $acted = $true; break
        }
        $n = Srv-Count $FtpSrv
        if ($n -ne $cnt) { $cnt = $n; $acted = $true }
        if ($acted) { $last.Restart(); Start-Sleep -Milliseconds 700 } else { Start-Sleep -Milliseconds 250 }
    }
    Sync $Id
    return $texts
}

# one row: $Setup prepares <srv>\<Case> and <start>\<Case>; $Body { param($id, $srv, $local, $sid) } returns @{ Ok; Facts }
function Row-Case([string]$Case, [string]$SrvDir, [scriptblock]$Setup, [scriptblock]$Body) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case; $srv = $FtpSrv.Root + '\' + $Case
    try {
        NewDir $local; NewDir $srv
        & $Setup $srv $local | Out-Null
        $id = Start-P
        [void](Do-ChangeDir $id $local); Sync $id
        KeyIn $id 0 0x09                       # right panel active
        $conn = Connect $id $SrvDir
        KeyIn $id 1 0x09                       # left (local) active
        Start-Sleep -Milliseconds 1000; Sync $id
        if (-not $conn.Ok) { Row $Case 'ROW' 'FAIL' ("not connected: '{0}' {1}" -f (Tail $conn.Loc 60), $conn.Notes); return }
        $sid = Last-Sid $FtpSrv
        $r = & $Body $id $srv $local $sid
        Row $Case 'ROW' (V ([bool]$r.Ok)) ("panel connection #{0}; {1}" -f $sid, $r.Facts)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; if (-not $fatal) { Close-Ops $id }; End-Row410 $Case $id $fatal $before } }
}
# 341's End-Row341: the exit question about unfinished operations is answered Yes and noted
function End-Row410([string]$Case, [int]$Id, [string]$Fatal, $Before) {
    $alive = Test-Alive $Id
    $resp = $false; if ($alive -and -not $Fatal) { $resp = [Drv098f]::Send((Get-Main $Id), 0, 0, 0, 10000) }
    $extra = @(); if ($alive -and -not $Fatal) { $extra = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass } | ForEach-Object { WinDesc $_ }) }
    $expected = 0; $ec = '-'
    if ($Fatal -or -not $resp) { if ($alive) { Kill-Mine $Id; $ec = 'ended by the probe' } else { $ec = ExitCodeOf $Id } }
    else {
        [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
            foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) {
                $d = WinDesc $h
                if ($d -match 'Queue still contains some unfinished FTP operations') { $expected++ } else { $extra += ('at exit: ' + $d) }
                $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b }
            }
            Start-Sleep -Milliseconds 200
        }
        if (Test-Alive $Id) { Kill-Mine $Id; $ec = 'did not exit in 30 s - ended by the probe' } else { $ec = ExitCodeOf $Id }
    }
    Start-Sleep -Milliseconds 400
    $rep = Take-Reports $Before
    $extra = @($extra | Where-Object { $_ -notmatch 'monitored handles remained opened' })
    $ok = (-not $Fatal) -and $resp -and ($extra.Count -eq 0) -and ($rep.Count -eq 0) -and ($ec -eq '0x00000000')
    Row $Case 'END' (V $ok) ("exit {0}; alive {1}; WM_NULL {2}; stray {3}; exit question (unfinished operations) {4}; new reports {5}{6}{7}" -f $ec, $alive, $resp, $(if ($extra.Count) { '' + $extra.Count + ' (' + ($extra -join ' || ') + ')' } else { '0' }), $expected, $rep.Count, $(if ($rep.Count) { ' [' + ($rep -join ' ;; ') + ']' } else { '' }), $(if ($Fatal) { '; FATAL: ' + $Fatal } else { '' }))
}
# after the verdict: closes the operations' windows (questions: Cancel; operation dialogs: Close;
# a confirmation box of an operation thread: Yes) so the END row sees only the program's exit
function Close-Ops([int]$Id) {
    $sw = [Diagnostics.Stopwatch]::StartNew(); $n = 0
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
        $w = @(OpWindows $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) })
        if (-not $w.Count) { if (-not @(OpWindows $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' }).Count) { break }; Start-Sleep -Milliseconds 300; continue }
        $h = $w[0]
        $yes = BtnById $h @(6)
        if ($yes) { Click $yes } else { Close-Win $h }
        $n++; Start-Sleep -Milliseconds 800
    }
    Sync $Id
    Out ("{0,-10} (closed {1} operation window(s); left: {2})" -f '', $n, @(OpWindows $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' }).Count)
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc410_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $FtpSrv.Root
    Set-Config
    $up = Start-Srv $FtpSrv
    Out 'ftp410_probe (feature 410)'
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : ftpmini_sess.py utf-8 on 127.0.0.1:{0} - {1}" -f $FtpSrv.Port, $(if ($up) { 'up' } else { 'NOT UP' }))
    Out ''
    if (-not $up) { throw 'the FTP server did not start' }

    $toAlias = { param($t) $t -replace '//u@127\.0\.0\.1:', '//u:p@localhost:' }
    $same = { param($t) $t }

    # the upload of a new n.txt into the panel's folder (REFRESH-ALIAS / -SAME) or into another
    # folder (REFRESH-ELSE); the verdict: did the panel's connection list again after it
    foreach ($rc in @(@('REFRESH-ALIAS', $toAlias, $true), @('REFRESH-SAME', $same, $true),
                      @('REFRESH-ELSE', { param($t) ($t -replace '//u@127\.0\.0\.1:', '//u:p@localhost:') -replace 'REFRESH-ELSE', 'OTHER-ELSE' }, $false))) {
        $script:rcEdit = $rc[1]; $script:rcWant = $rc[2]
        Row-Case $rc[0] $rc[0] {
            param($s, $l)
            WriteFile ($s + '\x.txt') 'SRV-X'
            WriteFile ($l + '\n.txt') 'UP'
            NewDir ($FtpSrv.Root + '\OTHER-ELSE')
        } {
            param($id, $s, $l, $sid)
            Focus $id 0 1                                          # local: .., n.txt -> n.txt
            $from = Srv-Count $FtpSrv
            $t = @(Drive $id 727 $script:rcEdit 5 90)              # the upload of n.txt
            Start-Sleep -Milliseconds 3000; Wait-Quiet $id 4 30
            $all = @(Srv-Cmds $FtpSrv $from)
            $stored = Has-Cmd $all '^STOR (.*/)?n\.txt$'
            $panel = @(Srv-Cmds $FtpSrv $from $sid)
            $listed = Has-Cmd $panel $ListRx
            @{ Ok = ($stored -and ($listed -eq $script:rcWant))
               Facts = ("upload sent STOR n.txt: {0}; the panel's connection listed again: {1} (wanted {2}); panel connection commands: {3}; all commands: {4}; dialogs: {5}; op windows: {6}" -f $stored, $listed, $script:rcWant, ($panel -join ' / '), ($all -join ' / '), ($t -join ' ; '), (OpDesc $id)) }
        }
    }

    # the listing cache under the other name: sub listed and cached at 127.0.0.1, the panel goes up,
    # the upload into sub (typed to localhost / 127.0.0.1), the panel enters sub again
    $sub = { param($t) ($t -replace '/(\*\.\*)?$', '') + '/sub/' }
    foreach ($rc in @(@('CACHE-ALIAS', { param($t) & $sub ($t -replace '//u@127\.0\.0\.1:', '//u:p@localhost:') }), @('CACHE-SAME', $sub))) {
        $script:rcEdit = $rc[1]
        Row-Case $rc[0] ($rc[0] + '/sub') {
            param($s, $l)
            NewDir ($s + '\sub'); WriteFile ($s + '\sub\x.txt') 'SRV-X'
            WriteFile ($l + '\n.txt') 'UP'
        } {
            param($id, $s, $l, $sid)
            KeyIn $id 0 0x09                                       # right (server) active
            KeyIn $id 1 0x08                                       # Backspace: up to the row's folder
            Wait-Quiet $id 3 20
            $up1 = Get-Loc $id
            KeyIn $id 1 0x09                                       # left active
            Focus $id 0 1                                          # local: .., n.txt -> n.txt
            $from = Srv-Count $FtpSrv
            $t = @(Drive $id 727 $script:rcEdit 5 90)              # the upload of n.txt into sub
            Start-Sleep -Milliseconds 2000; Wait-Quiet $id 4 30
            $all = @(Srv-Cmds $FtpSrv $from)
            $stored = (ReadSrv ($s + '\sub\n.txt')) -ceq 'UP'
            KeyIn $id 0 0x09                                       # right active
            Focus $id 1 1                                          # .., sub -> sub
            $from2 = Srv-Count $FtpSrv
            KeyIn $id 1 0x0D                                       # Enter: into sub
            Wait-Quiet $id 4 30
            $loc = Get-Loc $id
            $panel = @(Srv-Cmds $FtpSrv $from2 $sid)
            $listed = Has-Cmd $panel $ListRx
            $inSub = $loc -like '*/sub*'
            @{ Ok = ($stored -and $inSub -and $listed)
               Facts = ("after Backspace '{0}'; upload stored sub/n.txt: {1}; after Enter '{2}'; the panel's connection listed sub again: {3}; its commands after Enter: {4}; upload commands: {5}; dialogs: {6}; op windows: {7}" -f (Tail $up1 60), $stored, (Tail $loc 60), $listed, ($panel -join ' / '), ($all -join ' / '), ($t -join ' ; '), (OpDesc $id)) }
        }
    }

    # the viewer's cache under the other name (FR-007): x.txt viewed (F3) in the panel at 127.0.0.1,
    # the panel goes up to "/", an upload into the row's folder typed to localhost / 127.0.0.1, the
    # panel goes back and views x.txt again: PASS = x.txt downloaded again (RETR)
    $Viewers = { param($id) @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and [Drv098f]::Cls($_) -ne '#32770' -and [Drv098f]::IsWindowVisible($_) }) }
    function View-X([int]$Id) {
        $from = Srv-Count $FtpSrv
        Post-Cmd (Get-Main $Id) 742                                # F3
        $sw = [Diagnostics.Stopwatch]::StartNew(); $seen = 0
        while ($sw.Elapsed.TotalSeconds -lt 20 -and -not $seen) { Start-Sleep -Milliseconds 300; $seen = @(& $Viewers $Id).Count }
        Start-Sleep -Milliseconds 800
        foreach ($v in @(& $Viewers $Id)) { Close-Win $v }
        Start-Sleep -Milliseconds 800; Sync $Id
        $cmds = @(Srv-Cmds $FtpSrv $from)
        return [pscustomobject]@{ Seen = $seen; Retr = (Has-Cmd $cmds '^RETR (.*/)?x\.txt$'); Cmds = ($cmds -join ' / ') }
    }
    foreach ($rc in @(@('VIEW-ALIAS', 'u:p@localhost'), @('VIEW-SAME', 'u@127.0.0.1'))) {
        $script:rcTarget = 'ftp://' + $rc[1] + ':' + $FtpSrv.Port + '/' + $rc[0] + '/'
        $script:rcCase = $rc[0]
        Row-Case $rc[0] $rc[0] {
            param($s, $l)
            WriteFile ($s + '\x.txt') 'SRV-X1'
            WriteFile ($l + '\n.txt') 'UP'
        } {
            param($id, $s, $l, $sid)
            KeyIn $id 0 0x09                                       # right (server) active
            Focus $id 1 1                                          # .., x.txt -> x.txt
            $v1 = View-X $id
            KeyIn $id 1 0x08                                       # Backspace: up to "/"
            Wait-Quiet $id 3 20
            $up1 = Get-Loc $id
            KeyIn $id 1 0x09                                       # left active
            Focus $id 0 1                                          # local: .., n.txt -> n.txt
            $t = @(Drive $id 727 { param($x) $script:rcTarget } 5 90)
            Start-Sleep -Milliseconds 2000; Wait-Quiet $id 4 30
            $stored = (ReadSrv ($s + '\n.txt')) -ceq 'UP'
            KeyIn $id 0 0x09                                       # right active
            [void](Do-ChangeDir $id ('ftp://u@127.0.0.1:' + $FtpSrv.Port + '/' + $script:rcCase)); Wait-Quiet $id 3 20
            $back = Get-Loc $id
            Focus $id 1 2                                          # .., n.txt, x.txt -> x.txt (names sorted)
            $v2 = View-X $id
            @{ Ok = ($v1.Seen -gt 0 -and $v1.Retr -and $stored -and $v2.Seen -gt 0 -and $v2.Retr)
               Facts = ("view 1: viewer {0}, RETR x.txt {1}; after Backspace '{2}'; upload stored n.txt: {3}; back '{4}'; view 2: viewer {5}, x.txt downloaded again {6}; view 2 commands: {7}; dialogs: {8}" -f $v1.Seen, $v1.Retr, (Tail $up1 50), $stored, (Tail $back 50), $v2.Seen, $v2.Retr, $v2.Cmds, ($t -join ' ; ')) }
        }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    if ($FtpSrv.Proc -and -not $FtpSrv.Proc.HasExited) { Stop-Process -Id $FtpSrv.Proc.Id -Force }
    Start-Sleep -Milliseconds 500
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
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
