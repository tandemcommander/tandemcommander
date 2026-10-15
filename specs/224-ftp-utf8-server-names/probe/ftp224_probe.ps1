<#
.SYNOPSIS
    Feature 224: an FTP command for a name with letters outside ASCII goes to a UTF-8 server in
    UTF-8 - the plug-in sent the ANSI code page's bytes when the name fitted it (another name).

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). 215's ftpmini.py (UTF-8 names,
    FEAT announces UTF8; 127.0.0.1 only) logs every command received. Rows (215's driver):
      DEL-ACC   F8 of "cafe.txt" with e-acute (the code page holds it): PASS = deleted, the server got
                DELE in UTF-8
      REN-ACC   Quick Rename of it to r.txt: PASS = RNFR in UTF-8, r.txt on the server
      DL-ACC    F5 of it: PASS = downloaded with its content (RETR in UTF-8)
      DEL-CJK   F8 of a CJK name (the code page cannot hold it - UTF-8 already): the control
      LEG-DEL / LEG-REN / LEG-DL   the same three against the server in its legacy mode (names in
                cp1250 on the wire): the name the listing gave in the code page goes back in it
      LEG-HOME  the legacy server starts a session in "/jiri" (i-acute, r-caron - a home folder known
                only from PWD); connected without a path, End + Enter opens its subfolder x: PASS =
                the panel in x (the CWD went in the code page)
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
    [string]$Python = 'python',
    [int]$Port = 2121
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc224'
$StartDir = $Root + '\start'
$SrvRoot = $Root + '\srv'
$SrvLog = $Root + '\ftp.log'
$Long = (-join (1..170 | ForEach-Object { [char](0x4E00 + $_) })) + '.txt'
$TwinP = (-join (1..90 | ForEach-Object { [char](0x4E00 + $_) }))
$script:Srv = $null

function Srv-Lines([int]$From) {
    if (-not [IO.File]::Exists($SrvLog)) { return @() }
    $fs = New-Object IO.FileStream($SrvLog, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $sr = New-Object IO.StreamReader($fs); $all = @(($sr.ReadToEnd() -split "`n") | Where-Object { $_.Trim() }) } finally { $fs.Dispose() }
    if ($all.Count -le $From) { return @() }
    return @($all[$From..($all.Count - 1)] | ForEach-Object { $_ | ConvertFrom-Json })
}
function Srv-Count { return @(Srv-Lines 0).Count }
# the commands received since $From, names shortened: "RETR <514 bytes>"
function Srv-Cmds([int]$From) {
    return @(Srv-Lines $From | Where-Object { $_.cmd -ne $null } | ForEach-Object {
            $c = [string]$_.cmd
            if ($c -eq '') { '(empty line)' }
            else { $v, $r = $c.Split(' ', 2); if ($r -and $r.Length -gt 40) { $v + ' <' + [Text.Encoding]::UTF8.GetByteCount($r) + ' bytes>' } else { Esc $c } }
        })
}
function Connect([int]$Id, [string]$Dir) {
    $notes = @()
    [void](Do-ChangeDir $Id ('ftp://u:p@127.0.0.1:' + $Port + '/' + $Dir))
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
    return [pscustomobject]@{ Loc = $loc; Notes = ($notes -join ', '); Ok = ($loc -like ('ftp:*' + $Dir + '*')) }
}

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T224', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
            # an FTP error dialog (Retry / Skip): Skip, and its texts (the edits) recorded
            if (-not $b) {
                $b = BtnById $h @(832, 881)
                if ($b) {
                    $eds = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' } | ForEach-Object { Tail ([Drv098f]::GetText($_, 5000)) 120 })
                    $desc = '[' + [Drv098f]::Txt($h) + '] ' + ($eds -join ' | ')
                }
            }
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


# one row: the server folder <srv>\$Case and the local folder <start>\$Case prepared by $Setup;
# $Up: the local panel is the source (left), else the server is (left, local on the right);
# Home + $Down x Down focus the item (-1: End); the command $Vk; $Judge { param($texts, $cmds, $srv, $local, $conn) }
function Row-Ftp([string]$Case, [int]$Down, [int]$Vk, [scriptblock]$Setup, [scriptblock]$Judge, [switch]$Up, [string]$Type = $null) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case; $srv = $SrvRoot + '\' + $Case
    try {
        NewDir $local; NewDir $srv
        & $Setup $srv $local | Out-Null
        $from = Srv-Count
        $id = Start-P
        if ($Up) { [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09 }
        else { Key $id 0x09; [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09 }
        $conn = Connect $id $Case
        if ($Up) { Key $id 0x09 }
        Start-Sleep -Milliseconds 1500; Sync $id   # the listing after the welcome box
        Key $id 0x24
        if ($Down -lt 0) { Key $id 0x23 } else { for ($i = 0; $i -lt $Down; $i++) { Key $id 0x28 } }   # -1: End (the last item)
        Start-Sleep -Milliseconds 700; Sync $id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Post-Cmd (Get-Main $id) $Vk; Start-Sleep -Milliseconds 700
        $texts = @(Answer $id 90 6 $Type)
        $secs = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        $cmds = @(Srv-Cmds $from)
        $r = & $Judge $texts $cmds $srv $local $conn
        $verdict = $(if ($Expect -eq 'before') { 'PASS' } else { V ([bool]$r.Ok) })
        Row $Case 'ROW' $verdict ("{0}; {1} s; connected: {2} [{3}] at '{4}'; server got: {5}; dialogs: {6}" -f $r.Facts, $secs, $conn.Ok, $conn.Notes, (Tail $conn.Loc 50), ($cmds -join ' / '), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}
function Has-Cmd($cmds, [string]$Rx) { return [bool](@($cmds | Where-Object { $_ -match $Rx }).Count) }
function Files([string]$Dir) { return @([IO.Directory]::GetFiles($LP + $Dir) | ForEach-Object { [IO.Path]::GetFileName($_) }) }

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc224_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $SrvRoot
    Set-Config
    $script:Srv = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f (Join-Path $PSScriptRoot '..\..\215-ftp-long-name-command\probe\ftpmini.py')), ('"{0}"' -f $SrvRoot), $Port, ('"{0}"' -f $SrvLog), 'utf-8') -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
    while ($sw.Elapsed.TotalSeconds -lt 15 -and -not $up) { Start-Sleep -Milliseconds 300; try { $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $Port); $c.Close(); $up = $true } catch { } }
    Out ("ftp224_probe (feature 224), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : ftpmini.py on 127.0.0.1:{0} - {1}; the long name has {2} bytes of UTF-8" -f $Port, $(if ($up) { 'up' } else { 'NOT UP' }), [Text.Encoding]::UTF8.GetByteCount($Long))
    Out ''
    if (-not $up) { throw 'the FTP server did not start' }
    $Acc = 'caf' + [char]0xE9 + '.txt'
    $Cjk = (-join (1..4 | ForEach-Object { [char](0x4E00 + $_) })) + '.txt'
    Row-Ftp 'DEL-ACC' -1 729 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC'); [IO.File]::WriteAllText($LP + $s + '\a-keep.txt', 'KEEP') } {
        param($t, $c, $s, $l, $conn)
        $left = @(Files $s)
        @{ Ok = ($left.Count -eq 1 -and $left[0] -ceq 'a-keep.txt'); Facts = ("left on the server: {0}" -f (($left | ForEach-Object { Esc $_ }) -join ',')) } }
    Row-Ftp 'REN-ACC' -1 754 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC') } {
        param($t, $c, $s, $l, $conn)
        $left = @(Files $s)
        @{ Ok = ($left.Count -eq 1 -and $left[0] -ceq 'r.txt'); Facts = ("on the server: {0}" -f (($left | ForEach-Object { Esc $_ }) -join ',')) } } -Type 'r.txt'
    Row-Ftp 'DL-ACC' -1 727 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC') } {
        param($t, $c, $s, $l, $conn)
        $got = ''; try { $got = [IO.File]::ReadAllText($LP + $l + '\' + $Acc) } catch { }
        @{ Ok = ($got -ceq 'ACC'); Facts = ("downloaded with its content {0}" -f ($got -ceq 'ACC')) } }
    Row-Ftp 'DEL-CJK' -1 729 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Cjk, 'CJK'); [IO.File]::WriteAllText($LP + $s + '\a-keep.txt', 'KEEP') } {
        param($t, $c, $s, $l, $conn)
        $left = @(Files $s)
        @{ Ok = ($left.Count -eq 1 -and $left[0] -ceq 'a-keep.txt'); Facts = ("left on the server: {0}" -f (($left | ForEach-Object { Esc $_ }) -join ',')) } }

    # the same server in its legacy mode (cp1250 names on the wire)
    if ($script:Srv -and -not $script:Srv.HasExited) { Stop-Process -Id $script:Srv.Id -Force; Start-Sleep -Milliseconds 500 }
    $script:Srv = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f (Join-Path $PSScriptRoot '..\..\215-ftp-long-name-command\probe\ftpmini.py')), ('"{0}"' -f $SrvRoot), $Port, ('"{0}"' -f $SrvLog), 'cp1250') -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
    while ($sw.Elapsed.TotalSeconds -lt 15 -and -not $up) { Start-Sleep -Milliseconds 300; try { $cl = New-Object Net.Sockets.TcpClient('127.0.0.1', $Port); $cl.Close(); $up = $true } catch { } }
    Row-Ftp 'LEG-DEL' -1 729 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC'); [IO.File]::WriteAllText($LP + $s + '\a-keep.txt', 'KEEP') } {
        param($t, $c, $s, $l, $conn)
        $left = @(Files $s)
        @{ Ok = ($left.Count -eq 1 -and $left[0] -ceq 'a-keep.txt'); Facts = ("left on the server: {0}" -f (($left | ForEach-Object { Esc $_ }) -join ',')) } }
    Row-Ftp 'LEG-REN' -1 754 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC') } {
        param($t, $c, $s, $l, $conn)
        $left = @(Files $s)
        @{ Ok = ($left.Count -eq 1 -and $left[0] -ceq 'r.txt'); Facts = ("on the server: {0}" -f (($left | ForEach-Object { Esc $_ }) -join ',')) } } -Type 'r.txt'
    Row-Ftp 'LEG-DL' -1 727 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC') } {
        param($t, $c, $s, $l, $conn)
        $got = ''; try { $got = [IO.File]::ReadAllText($LP + $l + '\' + $Acc) } catch { }
        @{ Ok = ($got -ceq 'ACC'); Facts = ("downloaded with its content {0}" -f ($got -ceq 'ACC')) } }

    # the legacy server with a non-ASCII home folder (known only from PWD)
    $Home224 = 'ji' + [char]0x0159 + [char]0xED
    if ($script:Srv -and -not $script:Srv.HasExited) { Stop-Process -Id $script:Srv.Id -Force; Start-Sleep -Milliseconds 500 }
    NewDir ($SrvRoot + '\' + $Home224); NewDir ($SrvRoot + '\' + $Home224 + '\x'); [IO.File]::WriteAllText($LP + $SrvRoot + '\' + $Home224 + '\x\f.txt', 'F')
    $script:Srv = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f (Join-Path $PSScriptRoot '..\..\215-ftp-long-name-command\probe\ftpmini.py')), ('"{0}"' -f $SrvRoot), $Port, ('"{0}"' -f $SrvLog), 'cp1250', ('"/{0}"' -f $Home224)) -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
    while ($sw.Elapsed.TotalSeconds -lt 15 -and -not $up) { Start-Sleep -Milliseconds 300; try { $cl = New-Object Net.Sockets.TcpClient('127.0.0.1', $Port); $cl.Close(); $up = $true } catch { } }
    $before = Reports; $id = 0; $from = Srv-Count
    try {
        $id = Start-P
        [void](Do-ChangeDir $id ('ftp://u:p@127.0.0.1:' + $Port))
        $sw = [Diagnostics.Stopwatch]::StartNew(); $quiet = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and $quiet.Elapsed.TotalSeconds -lt 3) {
            $acted = $false
            foreach ($h in (Dialogs $id)) { $ok = BtnById $h @(6, 1); if ($ok) { Click $ok; $acted = $true; break } }
            if ($acted) { $quiet.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
        }
        Sync $id; Start-Sleep -Milliseconds 1500
        $loc1 = Get-Loc $id
        Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 500
        Key $id 0x0D; Start-Sleep -Milliseconds 2000
        $texts = @(Answer $id 20 3)
        $loc2 = Get-Loc $id
        $cmds = @(Srv-Cmds $from)
        $ok = $loc2 -match '/x/?$'
        Row 'LEG-HOME' 'ROW' (V $ok) ("at '{0}', after Enter at '{1}'; server got: {2}; dialogs: {3}" -f (Esc $loc1), (Esc $loc2), ($cmds -join ' / '), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row 'LEG-HOME' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row 'LEG-HOME' $id $fatal $before } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    if ($script:Srv -and -not $script:Srv.HasExited) { Stop-Process -Id $script:Srv.Id -Force; Start-Sleep -Milliseconds 500 }
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
