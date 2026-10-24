<#
.SYNOPSIS
    Feature 341: a change made through one name of an FTP server (127.0.0.1) reaches the upload
    listing cache of a running upload opened through another name of it (localhost).

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). One ftpmini_hide.py server
    (feature 323's copy) serves an NTFS folder on 127.0.0.1 only, UTF-8, user "u", and logs every
    command received. The left panel is local, the right one the server connected as
    ftp://u@127.0.0.1:<port>. Uploads typed to ftp://u:p@localhost:<port>/... reach the same
    server under another name. The upload listing cache exists only while an upload operation to
    the server exists: each row first starts upload 1 of "o1.txt" to a folder that has it - the
    overwrite question keeps the operation (and its cache) open; the probe never answers it.
      ALIAS-REN  the item's row: upload 1 to localhost:/ALIAS-REN (the cache lists the folder);
                 Quick Rename a.txt -> b.txt in the panel (127.0.0.1); upload 2 of the local b.txt
                 to localhost:/ALIAS-REN: PASS = no STOR b.txt, the overwrite question for b.txt,
                 the server's b.txt keeps the content of a.txt. Before the fix: STOR b.txt (the
                 renamed file replaced without the question).
      ALIAS-UP   upload 1 to localhost:/ALIAS-UP kept open; upload 2 of the local n.txt to the
                 panel folder (127.0.0.1, a new name there - stored); upload 3 of another local
                 n.txt (folder "second") to localhost:/ALIAS-UP: PASS = no second STOR n.txt, the
                 question for n.txt, the server's n.txt keeps upload 2's content.
      SAME-REN   control (feature 323's REN-UP): everything at 127.0.0.1 - must stay PASS.
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
    [int]$Port = 2141,
    [string]$Repo = (Join-Path $PSScriptRoot '..\..\..')
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc341'
$StartDir = $Root + '\start'
$FtpSrv = @{ Root = ($Root + '\srv'); Log = ($Root + '\ftp.log'); Port = $Port; Enc = 'utf-8'; Proc = $null }
$MiniPy = Join-Path $Repo 'specs\323-ftp-upload-cache-args\probe\ftpmini_hide.py'

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
    $a = @('-t', 'T341', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
    finally { if ($id) { $fatal = Fatal-Win $id; if (-not $fatal) { Close-Ops $id }; End-Row341 $Case $id $fatal $before } }
}
# 098's End-Row, except that the exit question about the operations this probe left unfinished on
# purpose ("Queue still contains some unfinished FTP operations") is expected: answered Yes, noted
function End-Row341([string]$Case, [int]$Id, [string]$Fatal, $Before) {
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
$backup = Join-Path $env:TEMP 'tc341_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $FtpSrv.Root
    Set-Config
    $up = Start-Srv $FtpSrv
    Out 'ftp341_probe (feature 341)'
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : ftpmini.py utf-8 on 127.0.0.1:{0} - {1}" -f $FtpSrv.Port, $(if ($up) { 'up' } else { 'NOT UP' }))
    Out ''
    if (-not $up) { throw 'the FTP server did not start' }

    $toAlias = { param($t) $t -replace '//u@127\.0\.0\.1:', '//u:p@localhost:' }
    $same = { param($t) $t }

    # the item's row: upload 1 kept open at localhost; Quick Rename a.txt -> b.txt in the panel at
    # 127.0.0.1; upload 2 of the local b.txt to localhost
    Row-Case 'ALIAS-REN' 'ALIAS-REN' {
        param($s, $l)
        WriteFile ($s + '\a.txt') 'SRV-A'; WriteFile ($s + '\o1.txt') 'SRV-O1'
        WriteFile ($l + '\b.txt') 'LOCAL-B'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        Focus $id 0 2                                              # local: .., b.txt, o1.txt -> o1.txt
        $t1 = @(Drive $id 727 $toAlias)                            # upload 1 to localhost: question, stays open
        $op1 = OpDesc $id
        KeyIn $id 0 0x09
        Focus $id 1 1                                              # a.txt on the server (127.0.0.1)
        $t2 = @(Drive $id 754 { param($t) 'b.txt' })               # Quick Rename
        $ren = [IO.File]::Exists($LP + $s + '\b.txt') -and -not [IO.File]::Exists($LP + $s + '\a.txt')
        KeyIn $id 1 0x09
        Focus $id 0 1                                              # local b.txt
        $from = Srv-Count $FtpSrv
        $t3 = @(Drive $id 727 $toAlias 5 90)                       # upload 2 of b.txt to localhost
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?b\.txt$'
        $asked = OpQuestion $id 'b.txt'
        $b = ReadSrv ($s + '\b.txt')
        @{ Ok = ($ren -and -not $stor -and $asked -and $b -ceq 'SRV-A')
           Facts = ("renamed: {0}; upload 2 sent STOR b.txt: {1}; overwrite question for b.txt open: {2}; server b.txt '{3}'; upload 2 commands: {4}; dialogs: {5} | {6} | {7}; operation windows after upload 1: {8}; at the end: {9}" -f $ren, $stor, $asked, $b, ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t3 -join ' ; '), $op1, (OpDesc $id)) }
    }

    # upload 1 kept open at localhost; upload 2 stores a new n.txt through 127.0.0.1; upload 3 of a
    # changed local n.txt to localhost
    Row-Case 'ALIAS-UP' 'ALIAS-UP' {
        param($s, $l)
        WriteFile ($s + '\o1.txt') 'SRV-O1'
        WriteFile ($l + '\n.txt') 'UP2'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        Focus $id 0 2                                              # local: .., n.txt, o1.txt -> o1.txt
        $t1 = @(Drive $id 727 $toAlias)                            # upload 1 to localhost: question, stays open
        $op1 = OpDesc $id
        Focus $id 0 1                                              # local n.txt
        $from2 = Srv-Count $FtpSrv
        $t2 = @(Drive $id 727 $same 5 90)                          # upload 2 of n.txt to 127.0.0.1 (new there)
        $cmds2 = @(Srv-Cmds $FtpSrv $from2)
        $stored2 = (ReadSrv ($s + '\n.txt')) -ceq 'UP2'
        WriteFile ($l + '\n.txt') 'UP3'                            # the local file changes
        $from = Srv-Count $FtpSrv
        $t3 = @(Drive $id 727 $toAlias 5 90)                       # upload 3 of n.txt to localhost
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?n\.txt$'
        $asked = OpQuestion $id 'n.txt'
        $n = ReadSrv ($s + '\n.txt')
        @{ Ok = ($stored2 -and -not $stor -and $asked -and $n -ceq 'UP2')
           Facts = ("upload 2 stored n.txt: {0}; upload 3 sent STOR n.txt: {1}; question for n.txt open: {2}; server n.txt '{3}'; upload 2 commands: {4}; upload 3 commands: {5}; dialogs: {6} | {7} | {8}; operation windows after upload 1: {9}; at the end: {10}" -f $stored2, $stor, $asked, $n, ($cmds2 -join ' / '), ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t3 -join ' ; '), $op1, (OpDesc $id)) }
    }

    # control: feature 323's REN-UP, one name everywhere
    Row-Case 'SAME-REN' 'SAME-REN' {
        param($s, $l)
        WriteFile ($s + '\a.txt') 'SRV-A'; WriteFile ($s + '\o1.txt') 'SRV-O1'
        WriteFile ($l + '\b.txt') 'LOCAL-B'; WriteFile ($l + '\o1.txt') 'L1'
    } {
        param($id, $s, $l)
        Focus $id 0 2
        $t1 = @(Drive $id 727 $same)
        $op1 = OpDesc $id
        KeyIn $id 0 0x09
        Focus $id 1 1
        $t2 = @(Drive $id 754 { param($t) 'b.txt' })
        $ren = [IO.File]::Exists($LP + $s + '\b.txt') -and -not [IO.File]::Exists($LP + $s + '\a.txt')
        KeyIn $id 1 0x09
        Focus $id 0 1
        $from = Srv-Count $FtpSrv
        $t3 = @(Drive $id 727 $same 5 90)
        $cmds = @(Srv-Cmds $FtpSrv $from)
        $stor = Has-Cmd $cmds '^STOR (.*/)?b\.txt$'
        $asked = OpQuestion $id 'b.txt'
        $b = ReadSrv ($s + '\b.txt')
        @{ Ok = ($ren -and -not $stor -and $asked -and $b -ceq 'SRV-A')
           Facts = ("renamed: {0}; upload 2 sent STOR b.txt: {1}; overwrite question for b.txt open: {2}; server b.txt '{3}'; upload 2 commands: {4}; dialogs: {5} | {6} | {7}; operation windows after upload 1: {8}; at the end: {9}" -f $ren, $stor, $asked, $b, ($cmds -join ' / '), ($t1 -join ' ; '), ($t2 -join ' ; '), ($t3 -join ' ; '), $op1, (OpDesc $id)) }
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
