<#
.SYNOPSIS
    Features 302 / 323: the FTP panel's Create Directory and Quick Rename report their change to
    the upload listing cache of the right server (user, host, port in their places), and Create
    Directory with a path records only its last component as a new, empty folder (323).

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). One ftpmini_hide.py server (215's
    ftpmini.py that omits dot names from a plain LIST, as vsftpd / Pure-FTPd / ProFTPD do; 302
    review 2) serves an NTFS folder - path components resolve without case - on 127.0.0.1 only,
    UTF-8, user "u", and logs every command received. The left panel is local, the
    right one the server. The upload listing cache exists only while an upload operation to the
    server exists: each row first starts upload 1 of "o1.txt" to a folder that has it - the
    overwrite question keeps the operation (and its dialogs, which the probe never touches) open.
      MKD-ABS  upload 1 into /MKA/other (typed target; the cache lists /MKA/other); in the panel at
               /MKA/src, F7 "/MKA/other/new" (an absolute path outside the panel folder - the panel
               refreshes only the new folder); then upload 2 of the local folder "new" (f.txt) into
               /MKA/other: PASS = upload 2 sends no MKD of "new" (the cache knows the folder: join,
               the default) and f.txt arrives in /MKA/other/new
      REN-UP   the item's row: upload 1 into the panel folder /REN; Quick Rename a.txt -> b.txt in
               the panel; upload 2 of the local b.txt into /REN: PASS = no STOR b.txt and the
               server's b.txt keeps the content of a.txt (the overwrite question is left open).
               Before the fix: STOR b.txt, the renamed file replaced without the question.
      MKD-REN  (review 1) F7 "new" (the cache holds its listing as empty), Quick Rename new ->
               new_old and full -> new, upload 2 of the local folder "new" (f.txt): PASS = the
               overwrite question for f.txt, no STOR f.txt, the server's new/f.txt keeps SRV-F
      REN-PATH (review 1) F7 "new", Quick Rename x.txt -> new/x.txt, upload 2 of the local x.txt
               into /REN-PATH/new: PASS = the question, no STOR x.txt, new/x.txt keeps SRV-X
      MKD-HID  (302 review 2) the server has .cfg/f.txt (a plain LIST hides .cfg); F7 ".cfg/new";
               upload 2 of the local f.txt into /MKD-HID/.cfg: PASS = the question for f.txt, no
               STOR f.txt, .cfg/f.txt keeps SRV-F (302's state: .cfg cached as new and empty)
      MKD-CASE (302 review 2) the server has Docs/f.txt; F7 "docs/new"; upload 2 of the local
               f.txt into /MKD-CASE/docs: PASS = the question, no STOR f.txt, Docs/f.txt keeps SRV-F
      MKD-HIDABS (323 review) MKD-HID with the absolute path "/MKD-HIDABS/.cfg/new" (the absolute
               branch of the cache's Create Directory report)
      MKD-UPHID (323 review) panel at /MKD-UPHID/src, upload 1 into /MKD-UPHID (cached, .cfg
               hidden), F7 "../.cfg/new", upload 2 of f.txt into /MKD-UPHID/.cfg: PASS as MKD-HID
    The product's registry key is exported, restored and compared. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [int]$Port = 2131
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc302'
$StartDir = $Root + '\start'
$FtpSrv = @{ Root = ($Root + '\srv'); Log = ($Root + '\ftp.log'); Port = $Port; Enc = 'utf-8'; Proc = $null }
$MiniPy = Join-Path $PSScriptRoot 'ftpmini_hide.py'

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
    return @(Srv-Lines $S $From | Where-Object { $_.cmd -ne $null } | ForEach-Object { $c = [string]$_.cmd; if ($c -eq '') { '(empty line)' } else { Esc $c } })
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T302', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
    return (($w | ForEach-Object { "'" + (Esc ([Drv098f]::Txt($_))) + "' " + ((@([Drv098f]::Kids($_) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' } | ForEach-Object { Tail ([Drv098f]::GetText($_, 5000)) 60 })) -join ' | ') }) -join ' || ')
}
# the overwrite question of an operation for the target name $Name (waits up to $Seconds for it)
function OpQuestion([int]$Id, [string]$Name, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in @(OpWindows $Id | Where-Object { [Drv098f]::Txt($_) -eq 'Target File Already Exists' })) {
            if (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::GetText($_, 5000) -ceq $Name }).Count) { return $true }
        }
        Start-Sleep -Milliseconds 300
    }
    return $false
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

# one row: $Setup prepares <srv>\<Case> and <start>\<Case>; $Body { param($id, $srv, $local) } returns @{ Ok; Facts }
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
        $r = & $Body $id $srv $local
        Row $Case 'ROW' (V ([bool]$r.Ok)) $r.Facts
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; if (-not $fatal) { Close-Ops $id }; End-Row302 $Case $id $fatal $before } }
}
# 098's End-Row, except that the exit question about the operations this probe left unfinished on
# purpose ("Queue still contains some unfinished FTP operations") is expected: answered Yes, noted
function End-Row302([string]$Case, [int]$Id, [string]$Fatal, $Before) {
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

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc302_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $FtpSrv.Root
    Set-Config
    $up = Start-Srv $FtpSrv
    Out 'ftp302_probe (feature 302)'
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : ftpmini.py utf-8 on 127.0.0.1:{0} - {1}" -f $FtpSrv.Port, $(if ($up) { 'up' } else { 'NOT UP' }))
    Out ''
    if (-not $up) { throw 'the FTP server did not start' }

    Row-Case 'MKD-ABS' 'MKD-ABS/src' {
        param($s, $l)
        NewDir ($s + '\src'); NewDir ($s + '\other')
        WriteFile ($s + '\src\z.txt') 'Z'; WriteFile ($s + '\other\o1.txt') 'SRV-O1'
        NewDir ($l + '\new'); WriteFile ($l + '\new\f.txt') 'F'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        $toOther = { param($t) $t -replace '/MKD-ABS/src', '/MKD-ABS/other' }
        Focus $id 0 2                                              # o1.txt
        $t1 = @(Drive $id 727 $toOther)                            # upload 1 into /other: question, stays open
        $op1 = OpDesc $id
        KeyIn $id 0 0x09                                           # the server panel
        $t2 = @(Drive $id 730 { param($t) '/MKD-ABS/other/new' })  # F7 outside the panel folder
        $made = [IO.Directory]::Exists($LP + $s + '\other\new')
        KeyIn $id 1 0x09                                           # local
        Focus $id 0 1                                              # the folder "new"
        $from = Srv-Count $FtpSrv
        $t3 = @(Drive $id 727 $toOther 5 90)                       # upload 2 of the folder into /other
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $mkd = Has-Cmd $cmds '^MKD (.*/)?new$'
        $f = ReadSrv ($s + '\other\new\f.txt')
        @{ Ok = ($made -and -not $mkd -and $f -ceq 'F')
           Facts = ("F7 made other/new: {0}; upload 2 sent MKD new: {1}; other/new/f.txt '{2}'; other: {3}; upload 2 commands: {4}; dialogs: {5} | {6} | {7}; operation windows after upload 1: {8}; at the end: {9}" -f $made, $mkd, $f, (Show (Entries ($s + '\other'))), ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t3 -join ' ; '), $op1, (OpDesc $id)) }
    }

    Row-Case 'REN-UP' 'REN-UP' {
        param($s, $l)
        WriteFile ($s + '\a.txt') 'SRV-A'; WriteFile ($s + '\o1.txt') 'SRV-O1'
        WriteFile ($l + '\b.txt') 'LOCAL-B'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        $same = { param($t) $t }
        Focus $id 0 2                                              # o1.txt
        $t1 = @(Drive $id 727 $same)                               # upload 1 into the panel folder: question
        $op1 = OpDesc $id
        KeyIn $id 0 0x09
        Focus $id 1 1                                              # a.txt on the server
        $t2 = @(Drive $id 754 { param($t) 'b.txt' })               # Quick Rename
        $ren = [IO.File]::Exists($LP + $s + '\b.txt') -and -not [IO.File]::Exists($LP + $s + '\a.txt')
        KeyIn $id 1 0x09
        Focus $id 0 1                                              # local b.txt
        $from = Srv-Count $FtpSrv
        $t3 = @(Drive $id 727 $same 5 90)                          # upload 2 of b.txt
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?b\.txt$'
        $asked = OpQuestion $id 'b.txt'
        $b = ReadSrv ($s + '\b.txt')
        @{ Ok = ($ren -and -not $stor -and $asked -and $b -ceq 'SRV-A')
           Facts = ("renamed: {0}; upload 2 sent STOR b.txt: {1}; overwrite question for b.txt open: {2}; server b.txt '{3}'; upload 2 commands: {4}; dialogs: {5} | {6} | {7}; operation windows after upload 1: {8}; at the end: {9}" -f $ren, $stor, $asked, $b, ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t3 -join ' ; '), $op1, (OpDesc $id)) }
    }
    # review 1 of 302 (MUST): F7 "new" (the cache gets an EMPTY ready listing of /MKD-REN/new), Quick Rename
    # "new" -> "new_old" and "full" -> "new" (ReportRename invalidates only /MKD-REN), upload 2 of
    # the local folder "new" (f.txt) into /MKD-REN: PASS = the server's new/f.txt (was full/f.txt)
    # keeps SRV-F and no STOR f.txt is sent
    Row-Case 'MKD-REN' 'MKD-REN' {
        param($s, $l)
        NewDir ($s + '\full'); WriteFile ($s + '\full\f.txt') 'SRV-F'; WriteFile ($s + '\o1.txt') 'SRV-O1'
        NewDir ($l + '\new'); WriteFile ($l + '\new\f.txt') 'LOCAL-F'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        $same = { param($t) $t }
        Focus $id 0 2                                              # local o1.txt
        $t1 = @(Drive $id 727 $same)                               # upload 1 into the panel folder: question
        $op1 = OpDesc $id
        KeyIn $id 0 0x09                                           # the server panel
        $t2 = @(Drive $id 730 { param($t) 'new' })                 # F7 relative "new"
        $made = [IO.Directory]::Exists($LP + $s + '\new')
        $tr = @(Drive $id 725 $null 3 30)                          # CM_RIGHTREFRESH
        Focus $id 1 2                                              # .., full, new, o1.txt -> "new"
        $t2b = @(Drive $id 754 { param($t) 'new_old' })            # Quick Rename new -> new_old
        Focus $id 1 1                                              # .., full, new_old, o1.txt -> "full"
        $t2c = @(Drive $id 754 { param($t) 'new' })                # Quick Rename full -> new
        $ren = [IO.File]::Exists($LP + $s + '\new\f.txt') -and [IO.Directory]::Exists($LP + $s + '\new_old')
        KeyIn $id 1 0x09                                           # local
        Focus $id 0 1                                              # local folder "new"
        $from = Srv-Count $FtpSrv
        $t3 = @(Drive $id 727 $same 5 90)                          # upload 2 of the folder "new"
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?f\.txt$'
        $asked = OpQuestion $id 'f.txt' 8
        $f = ReadSrv ($s + '\new\f.txt')
        @{ Ok = ($made -and $ren -and -not $stor -and $asked -and $f -ceq 'SRV-F')
           Facts = ("F7 made new: {0}; renames done: {1}; upload 2 sent STOR f.txt: {2}; question for f.txt: {3}; server new/f.txt '{4}'; srv: {5}; upload 2 commands: {6}; dialogs: {7} | {8} | {9} | {10} | {11}; op after upload 1: {12}; at the end: {13}" -f $made, $ren, $stor, $asked, $f, (Show (Entries $s)), ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t2b -join ' ; '), ($t2c -join ' ; '), ($t3 -join ' ; '), $op1, (OpDesc $id)) }
    }

    # review 1 of 302 (MUST): same with a path in the Quick Rename name: F7 "new", Quick Rename x.txt ->
    # new/x.txt, upload 2 of the local x.txt into /REN-PATH/new: PASS = server new/x.txt keeps SRV-X
    Row-Case 'REN-PATH' 'REN-PATH' {
        param($s, $l)
        WriteFile ($s + '\x.txt') 'SRV-X'; WriteFile ($s + '\o1.txt') 'SRV-O1'
        WriteFile ($l + '\x.txt') 'LOCAL-X'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        $same = { param($t) $t }
        Focus $id 0 1                                              # local: .., o1.txt, x.txt -> o1.txt
        $t1 = @(Drive $id 727 $same)
        $op1 = OpDesc $id
        KeyIn $id 0 0x09
        $t2 = @(Drive $id 730 { param($t) 'new' })
        $made = [IO.Directory]::Exists($LP + $s + '\new')
        $tr = @(Drive $id 725 $null 3 30)                          # CM_RIGHTREFRESH
        Focus $id 1 3                                              # .., new, o1.txt, x.txt -> x.txt
        $t2b = @(Drive $id 754 { param($t) 'new/x.txt' })
        $ren = [IO.File]::Exists($LP + $s + '\new\x.txt')
        KeyIn $id 1 0x09
        Focus $id 0 2                                              # local x.txt
        $from = Srv-Count $FtpSrv
        $toNew = { param($t) $t -replace '/REN-PATH/', '/REN-PATH/new/' }
        $t3 = @(Drive $id 727 $toNew 5 90)
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?x\.txt$'
        $asked = OpQuestion $id 'x.txt' 8
        $x = ReadSrv ($s + '\new\x.txt')
        @{ Ok = ($made -and $ren -and -not $stor -and $asked -and $x -ceq 'SRV-X')
           Facts = ("F7 made new: {0}; renamed into new: {1}; upload 2 sent STOR x.txt: {2}; question for x.txt: {3}; server new/x.txt '{4}'; upload 2 commands: {5}; dialogs: {6} | {7} | {8} | {9}; op after upload 1: {10}; at the end: {11}" -f $made, $ren, $stor, $asked, $x, ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t2b -join ' ; '), ($t3 -join ' ; '), $op1, (OpDesc $id)) }
    }

    # review 2: F7 ".cfg/new" through an EXISTING folder that plain LIST hides (dot name) - the cache
    # records ".cfg" as created and empty; upload 2 of the local f.txt into /MKD-HID/.cfg
    Row-Case 'MKD-HID' 'MKD-HID' {
        param($s, $l)
        NewDir ($s + '\.cfg'); WriteFile ($s + '\.cfg\f.txt') 'SRV-F'; WriteFile ($s + '\o1.txt') 'SRV-O1'
        WriteFile ($l + '\f.txt') 'LOCAL-F'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        $same = { param($t) $t }
        Focus $id 0 2                                              # local: .., f.txt, o1.txt -> o1.txt
        $t1 = @(Drive $id 727 $same)
        $op1 = OpDesc $id
        KeyIn $id 0 0x09
        $t2 = @(Drive $id 730 { param($t) '.cfg/new' })
        $made = [IO.Directory]::Exists($LP + $s + '\.cfg\new')
        $tr = @(Drive $id 725 $null 3 30)                          # CM_RIGHTREFRESH
        KeyIn $id 1 0x09
        Focus $id 0 1                                              # local f.txt
        $from = Srv-Count $FtpSrv
        $toCfg = { param($t) $t -replace '/MKD-HID/', '/MKD-HID/.cfg/' }
        $t3 = @(Drive $id 727 $toCfg 5 90)
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?f\.txt$'
        $asked = OpQuestion $id 'f.txt' 8
        $f = ReadSrv ($s + '\.cfg\f.txt')
        @{ Ok = ($made -and -not $stor -and $asked -and $f -ceq 'SRV-F')
           Facts = ("F7 made .cfg/new: {0}; upload 2 sent STOR f.txt: {1}; question for f.txt: {2}; server .cfg/f.txt '{3}'; upload 2 commands: {4}; dialogs: {5} | {6} | {7}; op after upload 1: {8}; at the end: {9}" -f $made, $stor, $asked, $f, ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t3 -join ' ; '), $op1, (OpDesc $id)) }
    }

    # review 2: a case-insensitive server with Unix paths (NTFS under ftpmini): existing "Docs" with
    # f.txt; F7 "docs/new" - the cache (case-sensitive for Unix paths) records "docs" as created and
    # empty; upload 2 of the local f.txt into /MKD-CASE/docs
    Row-Case 'MKD-CASE' 'MKD-CASE' {
        param($s, $l)
        NewDir ($s + '\Docs'); WriteFile ($s + '\Docs\f.txt') 'SRV-F'; WriteFile ($s + '\o1.txt') 'SRV-O1'
        WriteFile ($l + '\f.txt') 'LOCAL-F'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        $same = { param($t) $t }
        Focus $id 0 2
        $t1 = @(Drive $id 727 $same)
        $op1 = OpDesc $id
        KeyIn $id 0 0x09
        $t2 = @(Drive $id 730 { param($t) 'docs/new' })
        $made = [IO.Directory]::Exists($LP + $s + '\Docs\new')
        $tr = @(Drive $id 725 $null 3 30)
        KeyIn $id 1 0x09
        Focus $id 0 1
        $from = Srv-Count $FtpSrv
        $toDocs = { param($t) $t -replace '/MKD-CASE/', '/MKD-CASE/docs/' }
        $t3 = @(Drive $id 727 $toDocs 5 90)
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?f\.txt$'
        $asked = OpQuestion $id 'f.txt' 8
        $f = ReadSrv ($s + '\Docs\f.txt')
        @{ Ok = ($made -and -not $stor -and $asked -and $f -ceq 'SRV-F')
           Facts = ("F7 made Docs/new: {0}; upload 2 sent STOR f.txt: {1}; question for f.txt: {2}; server Docs/f.txt '{3}'; upload 2 commands: {4}; dialogs: {5} | {6} | {7}; at the end: {8}" -f $made, $stor, $asked, $f, ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t3 -join ' ; '), (OpDesc $id)) }
    }

    # review of 323 (S1): MKD-HID with an absolute path (the absolute branch of ReportCreateDirs)
    Row-Case 'MKD-HIDABS' 'MKD-HIDABS' {
        param($s, $l)
        NewDir ($s + '\.cfg'); WriteFile ($s + '\.cfg\f.txt') 'SRV-F'; WriteFile ($s + '\o1.txt') 'SRV-O1'
        WriteFile ($l + '\f.txt') 'LOCAL-F'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        $same = { param($t) $t }
        Focus $id 0 2
        $t1 = @(Drive $id 727 $same)
        $op1 = OpDesc $id
        KeyIn $id 0 0x09
        $t2 = @(Drive $id 730 { param($t) '/MKD-HIDABS/.cfg/new' })
        $made = [IO.Directory]::Exists($LP + $s + '\.cfg\new')
        $tr = @(Drive $id 725 $null 3 30)
        KeyIn $id 1 0x09
        Focus $id 0 1
        $from = Srv-Count $FtpSrv
        $toCfg = { param($t) $t -replace '/MKD-HIDABS/', '/MKD-HIDABS/.cfg/' }
        $t3 = @(Drive $id 727 $toCfg 5 90)
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?f\.txt$'
        $asked = OpQuestion $id 'f.txt' 8
        $f = ReadSrv ($s + '\.cfg\f.txt')
        @{ Ok = ($made -and -not $stor -and $asked -and $f -ceq 'SRV-F')
           Facts = ("F7 made .cfg/new: {0}; upload 2 sent STOR f.txt: {1}; question for f.txt: {2}; server .cfg/f.txt '{3}'; upload 2 commands: {4}; dialogs: {5} | {6} | {7}; at the end: {8}" -f $made, $stor, $asked, $f, ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t3 -join ' ; '), (OpDesc $id)) }
    }

    # review of 323: a relative path through ".." to a hidden sibling: panel at /MKD-UPHID/src, F7 "../.cfg/new"
    Row-Case 'MKD-UPHID' 'MKD-UPHID/src' {
        param($s, $l)
        NewDir ($s + '\src'); WriteFile ($s + '\src\z.txt') 'Z'; WriteFile ($s + '\o1.txt') 'SRV-O1'
        NewDir ($s + '\.cfg'); WriteFile ($s + '\.cfg\f.txt') 'SRV-F'
        WriteFile ($l + '\f.txt') 'LOCAL-F'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        $toParent = { param($t) $t -replace '/MKD-UPHID/src', '/MKD-UPHID' }
        Focus $id 0 2
        $t1 = @(Drive $id 727 $toParent)                            # upload 1 into /MKD-UPHID (cached, .cfg hidden)
        KeyIn $id 0 0x09
        $t2 = @(Drive $id 730 { param($t) '../.cfg/new' })
        $made = [IO.Directory]::Exists($LP + $s + '\.cfg\new')
        KeyIn $id 1 0x09
        Focus $id 0 1
        $from = Srv-Count $FtpSrv
        $toCfg = { param($t) $t -replace '/MKD-UPHID/src', '/MKD-UPHID/.cfg' }
        $t3 = @(Drive $id 727 $toCfg 5 90)
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?f\.txt$'
        $asked = OpQuestion $id 'f.txt' 8
        $f = ReadSrv ($s + '\.cfg\f.txt')
        @{ Ok = ($made -and -not $stor -and $asked -and $f -ceq 'SRV-F')
           Facts = ("F7 made .cfg/new: {0}; upload 2 sent STOR f.txt: {1}; question for f.txt: {2}; server .cfg/f.txt '{3}'; upload 2 commands: {4}; dialogs: {5} | {6} | {7}; at the end: {8}" -f $made, $stor, $asked, $f, ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t3 -join ' ; '), (OpDesc $id)) }
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
