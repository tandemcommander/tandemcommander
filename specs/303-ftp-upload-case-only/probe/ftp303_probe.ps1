<#
.SYNOPSIS
    An FTP upload whose target name differs from a listed server name only in case asks the
    overwrite question - never replaces the other file silently (backlog item
    ftp-an-upload-to-a-case-insensitive-server-with-unix-paths).

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). One of 215's ftpmini.py servers
    (127.0.0.1 only, UTF-8, user "u") serves an NTFS folder with Unix-style listings - a
    case-insensitive server with Unix paths, as FileZilla Server or another Windows-backed server.
    The left panel is local, the right one the server; F5 of one local file into the server panel.
      CASE-UP   server b.txt = SRV-B; upload of the local B.txt (LOCAL-B): PASS = the "Target File
                Already Exists" question for B.txt, no STOR, the server's file keeps SRV-B
      CASE-CZ   the same with a non-ASCII letter: server U+010C "aj.txt" (C-caron), local U+010D
                "aj.txt" (c-caron) - the file system's rule of feature 092, not the ASCII fold
      CASE-NEW  control: server b.txt, upload of the local c.txt: PASS = STOR c.txt, no question,
                c.txt = LOCAL-C, b.txt keeps SRV-B
      CASE-OVR  the question answered Overwrite (button 1308): PASS = STOR B.txt sent and the
                server's file holds LOCAL-B (the user's choice is carried out)
    The product's registry key is exported, restored and compared. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. -Repo is the repository root (default: three levels above
    this script, i.e. specs\<feature>\probe).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Repo = (Join-Path $PSScriptRoot '..\..\..'),
    [string]$Python = 'python',
    [int]$Port = 2132
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$Repo = (Resolve-Path -LiteralPath $Repo).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tcftpcase'
$StartDir = $Root + '\start'
$FtpSrv = @{ Root = ($Root + '\srv'); Log = ($Root + '\ftp.log'); Port = $Port; Enc = 'utf-8'; Proc = $null }
$MiniPy = Join-Path $Repo 'specs\215-ftp-long-name-command\probe\ftpmini.py'
$CzUp = [string][char]0x010C + 'aj.txt'
$CzLow = [string][char]0x010D + 'aj.txt'

function Start-Srv($S) {
    $S.Proc = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f $MiniPy), ('"{0}"' -f $S.Root), $S.Port, ('"{0}"' -f $S.Log), $S.Enc) -PassThru -WindowStyle Hidden
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
function Srv-Cmds($S, [int]$From) {
    return @(Srv-Lines $S $From | Where-Object { $_.cmd -ne $null } | ForEach-Object { $c = [string]$_.cmd; if ($c -eq '') { '(empty line)' } else { $c } })
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'TCASE', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
function Entries([string]$Dir) { if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }; return @([IO.Directory]::GetFileSystemEntries($LP + $Dir) | ForEach-Object { [IO.Path]::GetFileName($_) }) }
function Show($names) { return (($names | ForEach-Object { Esc $_ }) -join ',') }
function ReadSrv([string]$File) { try { return [IO.File]::ReadAllText($LP + $File) } catch { return '<none>' } }

# 288's connect (only before any operation exists: it answers every dialog of the process)
function Connect([int]$Id, [string]$Dir) {
    $notes = @()
    [void](Do-ChangeDir $Id ('ftp://u:p@127.0.0.1:' + $FtpSrv.Port + '/' + $Dir))
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
    return (($w | ForEach-Object { "'" + (Esc ([Drv098f]::Txt($_))) + "' " + ((@([Drv098f]::Kids($_) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' } | ForEach-Object { Tail (Esc ([Drv098f]::GetText($_, 5000))) 60 })) -join ' | ') }) -join ' || ')
}
# the overwrite question of an operation for the target name $Name (waits up to $Seconds for it)
function OpQuestion([int]$Id, [string]$Name, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in @(OpWindows $Id | Where-Object { [Drv098f]::Txt($_) -eq 'Target File Already Exists' })) {
            if (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::GetText($_, 5000) -ceq $Name }).Count) { return $h }
        }
        Start-Sleep -Milliseconds 300
    }
    return [IntPtr]::Zero
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
# waits until the server log is quiet for $Quiet seconds (at most $Max)
function Wait-SrvQuiet([double]$Quiet = 3, [double]$Max = 30) {
    $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew(); $cnt = Srv-Count $FtpSrv
    while ($sw.Elapsed.TotalSeconds -lt $Max -and $last.Elapsed.TotalSeconds -lt $Quiet) {
        Start-Sleep -Milliseconds 300
        $n = Srv-Count $FtpSrv; if ($n -ne $cnt) { $cnt = $n; $last.Restart() }
    }
}

# one row: $Setup prepares <srv>\<Case> and <start>\<Case>; $Body { param($id, $srv, $local) } returns @{ Ok; Facts }
function Row-Case([string]$Case, [scriptblock]$Setup, [scriptblock]$Body) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case; $srv = $FtpSrv.Root + '\' + $Case
    try {
        NewDir $local; NewDir $srv
        & $Setup $srv $local | Out-Null
        $id = Start-P
        [void](Do-ChangeDir $id $local); Sync $id
        KeyIn $id 0 0x09                       # right panel active
        $conn = Connect $id $Case
        KeyIn $id 1 0x09                       # left (local) active
        Start-Sleep -Milliseconds 1000; Sync $id
        if (-not $conn.Ok) { Row $Case 'ROW' 'FAIL' ("not connected: '{0}' {1}" -f (Tail $conn.Loc 60), $conn.Notes); return }
        $r = & $Body $id $srv $local
        Row $Case 'ROW' (V ([bool]$r.Ok)) $r.Facts
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; if (-not $fatal) { Close-Ops $id }; End-RowOps $Case $id $fatal $before } }
}
# 098's End-Row, except that the exit question about an operation a row left unfinished on purpose
# ("Queue still contains some unfinished FTP operations") is expected: answered Yes, noted
function End-RowOps([string]$Case, [int]$Id, [string]$Fatal, $Before) {
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
    Row $Case 'END' (V $ok) ("exit {0}; alive {1}; WM_NULL {2}; stray {3}; expected exit question (unfinished operations) {4}; new reports {5}{6}{7}" -f $ec, $alive, $resp, $(if ($extra.Count) { '' + $extra.Count + ' (' + ($extra -join ' || ') + ')' } else { '0' }), $expected, $rep.Count, $(if ($rep.Count) { ' [' + ($rep -join ' ;; ') + ']' } else { '' }), $(if ($Fatal) { '; FATAL: ' + $Fatal } else { '' }))
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

# one upload of the local file at list position $Pos into the server panel's folder; returns the
# facts: the server commands it sent, whether STOR of $TgtName went out, the question window
function Upload-One([int]$Id, [int]$Pos, [string]$TgtName) {
    Focus $Id 0 $Pos
    $from = Srv-Count $FtpSrv
    $t = @(Drive $Id 727 { param($x) $x } 5 90)                    # F5 into the other panel's folder
    $q = OpQuestion $Id $TgtName 8
    $cmds = @(Srv-Cmds $FtpSrv $from)
    $stor = Has-Cmd $cmds ('^STOR (.*/)?' + [regex]::Escape($TgtName) + '$')
    return [pscustomobject]@{ From = $from; Dialogs = ($t -join ' ; '); Question = $q; Cmds = $cmds; Stor = $stor }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tcftpcase_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $FtpSrv.Root
    Set-Config
    $up = Start-Srv $FtpSrv
    Out 'ftp303_probe (feature 303: an upload to a case-insensitive server with Unix paths)'
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : ftpmini.py utf-8 on 127.0.0.1:{0} (NTFS: case-insensitive, Unix listings) - {1}" -f $FtpSrv.Port, $(if ($up) { 'up' } else { 'NOT UP' }))
    Out ''
    if (-not $up) { throw 'the FTP server did not start' }

    Row-Case 'CASE-UP' {
        param($s, $l)
        WriteFile ($s + '\b.txt') 'SRV-B'; WriteFile ($l + '\B.txt') 'LOCAL-B'
    } {
        param($id, $s, $l)
        $u = Upload-One $id 1 'B.txt'
        $asked = $u.Question -ne [IntPtr]::Zero
        $b = ReadSrv ($s + '\b.txt')
        @{ Ok = ($asked -and -not $u.Stor -and $b -ceq 'SRV-B')
           Facts = ("question for B.txt: {0}; STOR B.txt sent: {1}; server file '{2}'; server: {3}; commands: {4}; dialogs: {5}; operation windows: {6}" -f $asked, $u.Stor, $b, (Show (Entries $s)), (($u.Cmds | ForEach-Object { Esc $_ }) -join ' / '), $u.Dialogs, (OpDesc $id)) }
    }

    Row-Case 'CASE-CZ' {
        param($s, $l)
        WriteFile ($s + '\' + $CzUp) 'SRV-C'; WriteFile ($l + '\' + $CzLow) 'LOCAL-C'
    } {
        param($id, $s, $l)
        $u = Upload-One $id 1 $CzLow
        $asked = $u.Question -ne [IntPtr]::Zero
        $c = ReadSrv ($s + '\' + $CzUp)
        @{ Ok = ($asked -and -not $u.Stor -and $c -ceq 'SRV-C')
           Facts = ("question for c-caron: {0}; STOR sent: {1}; server file '{2}'; server: {3}; commands: {4}; dialogs: {5}; operation windows: {6}" -f $asked, $u.Stor, $c, (Show (Entries $s)), (($u.Cmds | ForEach-Object { Esc $_ }) -join ' / '), $u.Dialogs, (OpDesc $id)) }
    }

    Row-Case 'CASE-NEW' {
        param($s, $l)
        WriteFile ($s + '\b.txt') 'SRV-B'; WriteFile ($l + '\c.txt') 'LOCAL-C'
    } {
        param($id, $s, $l)
        $u = Upload-One $id 1 'c.txt'
        $asked = $u.Question -ne [IntPtr]::Zero
        Wait-SrvQuiet
        $b = ReadSrv ($s + '\b.txt'); $c = ReadSrv ($s + '\c.txt')
        @{ Ok = ((-not $asked) -and $u.Stor -and $c -ceq 'LOCAL-C' -and $b -ceq 'SRV-B')
           Facts = ("question: {0}; STOR c.txt sent: {1}; server c.txt '{2}', b.txt '{3}'; server: {4}; commands: {5}; dialogs: {6}" -f $asked, $u.Stor, $c, $b, (Show (Entries $s)), (($u.Cmds | ForEach-Object { Esc $_ }) -join ' / '), $u.Dialogs) }
    }

    Row-Case 'CASE-OVR' {
        param($s, $l)
        WriteFile ($s + '\b.txt') 'SRV-B'; WriteFile ($l + '\B.txt') 'LOCAL-B'
    } {
        param($id, $s, $l)
        $u = Upload-One $id 1 'B.txt'
        $asked = $u.Question -ne [IntPtr]::Zero
        $clicked = $false
        if ($asked) {
            $ov = BtnById $u.Question @(1308)
            if ($ov) { Click $ov; $clicked = $true; Start-Sleep -Milliseconds 1500; Wait-SrvQuiet }
        }
        $cmds = @(Srv-Cmds $FtpSrv $u.From)
        $stor = Has-Cmd $cmds '^STOR (.*/)?B\.txt$'
        $b = ReadSrv ($s + '\b.txt')
        @{ Ok = ($asked -and $clicked -and $stor -and $b -ceq 'LOCAL-B')
           Facts = ("question for B.txt: {0}; Overwrite clicked: {1}; STOR B.txt sent: {2}; server file '{3}'; server: {4}; commands: {5}; dialogs: {6}; operation windows: {7}" -f $asked, $clicked, $stor, $b, (Show (Entries $s)), (($cmds | ForEach-Object { Esc $_ }) -join ' / '), $u.Dialogs, (OpDesc $id)) }
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
