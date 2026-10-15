<#
.SYNOPSIS
    Feature 215: an FTP command for a long name (about 500 bytes of UTF-8 or more) is sent - or
    the item fails with an error - never an empty command, never a hang.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). Serves the row's server folder
    with ftpmini.py (127.0.0.1, loopback only; every received command logged). Driver of 205's
    sftp205_probe.ps1: every row is its own start of the program, the left panel connects by a
    typed address ftp://u:p@127.0.0.1:PORT/row, the core's command is posted, every dialog is
    answered Yes / OK (else Skip / Close).
    The long name: 170 CJK letters + '.txt' (514 bytes, 174 UTF-16 units - a valid Windows name).
    The plug-in's local side takes paths of up to 259 bytes: a download or upload of such a name
    is refused (an error) - never done under another name.
      DL-LONG   F5 (727) of the long-named file to the local folder: PASS = an error, no local file,
                no RETR of another name, no hang
      DL-CTL    the same with a short name (the control): downloaded
      DEL-LONG  F8 (729) of the long-named file: PASS = deleted on the server (DELE <514 bytes>),
                keep.txt kept
      DEL-TWIN  two names of 90 CJK letters + '1.txt' / '2.txt' (the same first 255 bytes); F8 of
                the second (End): PASS = only the first left on the server
      REN-LONG  F2 (Quick Rename, 754) of the long-named file to r.txt: PASS = r.txt on the server
      UP-LONG   F5 of a local long-named file to the server: PASS = an error, nothing stored, no STOR
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

$Root = $TempRoot + '\tc215'
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
            else { $v, $r = $c.Split(' ', 2); if ($r -and $r.Length -gt 40) { $v + ' <' + [Text.Encoding]::UTF8.GetByteCount($r) + ' bytes>' } else { $c } }
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
    $a = @('-t', 'T215', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
$backup = Join-Path $env:TEMP 'tc215_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $SrvRoot
    Set-Config
    $script:Srv = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f (Join-Path $PSScriptRoot 'ftpmini.py')), ('"{0}"' -f $SrvRoot), $Port, ('"{0}"' -f $SrvLog)) -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
    while ($sw.Elapsed.TotalSeconds -lt 15 -and -not $up) { Start-Sleep -Milliseconds 300; try { $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $Port); $c.Close(); $up = $true } catch { } }
    Out ("ftp215_probe (feature 215), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : ftpmini.py on 127.0.0.1:{0} - {1}; the long name has {2} bytes of UTF-8" -f $Port, $(if ($up) { 'up' } else { 'NOT UP' }), [Text.Encoding]::UTF8.GetByteCount($Long))
    Out ''
    if (-not $up) { throw 'the FTP server did not start' }
    Row-Ftp 'DL-LONG' -1 727 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Long, 'SERVER-LONG') } {
        param($t, $c, $s, $l, $conn)
        $n = @(Files $l).Count; $err = [bool](@($t | Where-Object { $_ -match 'Error' }).Count); $retr = Has-Cmd $c '^RETR'
        @{ Ok = ($n -eq 0 -and $err -and -not $retr); Facts = ("local files {0}; an error shown {1}; RETR sent {2}" -f $n, $err, $retr) } }
    Row-Ftp 'DL-CTL' 1 727 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\short.txt', 'SERVER-SHORT') } {
        param($t, $c, $s, $l, $conn)
        $got = ''; try { $got = [IO.File]::ReadAllText($LP + $l + '\short.txt') } catch { }
        @{ Ok = ($got -ceq 'SERVER-SHORT'); Facts = ("downloaded short.txt with its content {0}" -f ($got -ceq 'SERVER-SHORT')) } }
    Row-Ftp 'DEL-TWIN' -1 729 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $TwinP + '1.txt', 'ONE'); [IO.File]::WriteAllText($LP + $s + '\' + $TwinP + '2.txt', 'TWO') } {
        param($t, $c, $s, $l, $conn)
        $left = @(Files $s)
        @{ Ok = ($left.Count -eq 1 -and $left[0] -ceq ($TwinP + '1.txt') -and (Has-Cmd $c '^DELE <275 bytes>')); Facts = ("left on the server: {0}" -f (($left | ForEach-Object { if ($_.StartsWith($TwinP)) { '<twin>' + $_.Substring($TwinP.Length) } else { $_ } }) -join ',')) } }
    Row-Ftp 'REN-LONG' -1 754 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Long, 'SERVER-LONG') } {
        param($t, $c, $s, $l, $conn)
        $left = @(Files $s); $got = ''; try { $got = [IO.File]::ReadAllText($LP + $s + '\r.txt') } catch { }
        @{ Ok = ($left.Count -eq 1 -and $got -ceq 'SERVER-LONG' -and (Has-Cmd $c '^RNFR <514 bytes>')); Facts = ("on the server: {0}; r.txt holds '{1}'" -f (($left | ForEach-Object { if ($_.Length -gt 40) { '<long name>' } else { $_ } }) -join ','), $got) } } -Type 'r.txt'
    Row-Ftp 'DEL-LONG' -1 729 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Long, 'SERVER-LONG'); [IO.File]::WriteAllText($LP + $s + '\keep.txt', 'KEEP') } {
        param($t, $c, $s, $l, $conn)
        $left = @(Files $s)
        @{ Ok = ($left.Count -eq 1 -and $left[0] -ceq 'keep.txt' -and (Has-Cmd $c '^DELE <514 bytes>')); Facts = ("left on the server: {0}" -f (($left | ForEach-Object { if ($_.Length -gt 40) { '<long name>' } else { $_ } }) -join ',')) } }
    Row-Ftp 'UP-LONG' -1 727 { param($s, $l) [IO.File]::WriteAllText($LP + $l + '\' + $Long, 'LOCAL-LONG') } {
        param($t, $c, $s, $l, $conn)
        $n = @(Files $s).Count; $err = [bool](@($t | Where-Object { $_ -match 'Error' }).Count); $stor = Has-Cmd $c '^(STOR|APPE)'
        @{ Ok = ($n -eq 0 -and $err -and -not $stor); Facts = ("files on the server {0}; an error shown {1}; STOR sent {2}" -f $n, $err, $stor) } } -Up
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
