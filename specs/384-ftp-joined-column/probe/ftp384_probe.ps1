<#
.SYNOPSIS
    Feature 384: a file name an FTP listing rule builds from several parts (IBM z/VM CMS: NAME + "."
    + TYPE, rule add_string_to_column) is decoded part by part - on a code-page server a name with
    letters outside ASCII in both parts is shown and addressed as the server has it.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). Two copies of this feature's
    ftpmini.py (215's server with a z/VM listing form; 127.0.0.1 only) log every command received:
    a legacy one (names in cp1250 on the wire; FEAT announces nothing) on $Port and a UTF-8 one on
    $Port + 1, both listing in the z/VM CMS form ("NAME TYPE V 80 ..."), which the client's
    autodetection parses with an "IBM z/VM (CMS)" rule. Rows:
      ZVM-CP-DEL    legacy server, folder holds "name<c-caron>.ext<c-caron>" and a-keep.txt; F8 on the
                    last item: PASS = only a-keep.txt is left (DELE named the server's file)
      ZVM-CP-DL     the same name; F5 to the local panel: PASS = the local folder holds the file by
                    that name with its content (RETR named the server's file; the local name is right)
      ZVM-CP-ASCII  control: legacy server, "name.ext<c-caron>" (only the joined part is not ASCII -
                    the old whole-text decode was right); F8: PASS = deleted (before and after)
      ZVM-UTF-DEL   control: UTF-8 server, "name<c-caron>.ext<c-caron>"; F8: PASS = deleted (before
                    and after)
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
    [int]$Port = 2141
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc384'
$StartDir = $Root + '\start'
$SrvL = @{ Root = ($Root + '\srvleg'); Log = ($Root + '\ftpleg.log'); Port = $Port; Enc = 'cp1250'; Proc = $null }
$SrvU = @{ Root = ($Root + '\srvutf'); Log = ($Root + '\ftputf.log'); Port = ($Port + 1); Enc = 'utf-8'; Proc = $null }
$MiniPy = Join-Path $PSScriptRoot 'ftpmini.py'

function Start-Srv($S) {
    $S.Proc = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f $MiniPy), ('"{0}"' -f $S.Root), $S.Port, ('"{0}"' -f $S.Log), $S.Enc, '/', '-', 'zvm') -PassThru -WindowStyle Hidden
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
# the commands received since $From (as the server decoded them), without the session's chatter
function Srv-Cmds($S, [int]$From) {
    return @(Srv-Lines $S $From | Where-Object { $_.cmd -ne $null } | ForEach-Object { [string]$_.cmd } |
        Where-Object { $_ -notmatch '^(USER|PASS|SYST|FEAT|OPTS|TYPE|PASV|EPSV|PORT|NOOP|CLNT|MODE|STRU|PWD|XPWD|QUIT)\b' } | ForEach-Object { Esc $_ })
}
function Connect([int]$Id, $S, [string]$Dir) {
    $notes = @()
    [void](Do-ChangeDir $Id ('ftp://u:p@127.0.0.1:' + $S.Port + '/' + $Dir))
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
    return [pscustomobject]@{ Loc = $loc; Notes = ($notes -join ', '); Ok = ($loc -like ('ftp:*:' + $S.Port + '/' + $Dir + '*')) }
}

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T384', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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

# answers every dialog until none shows for $Quiet seconds (224's driver): Yes / OK by id, else
# Skip / Close by text; an operation dialog that comes back a second time is cancelled
function Answer([int]$Id, [double]$Seconds = 90, [double]$Quiet = 5) {
    $texts = @(); $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew(); $seenOp = $false
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
            if (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 209 }).Count) {
                if ($seenOp) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
                $seenOp = $true
            }
            $b = BtnById $h @(832, 881)
            if (-not $b) { $b = BtnById $h @(6, 1) }
            if (-not $b) { $b = $bs | Where-Object { [Drv098f]::Txt($_) -match '^&?(Skip|Close)$' } | Select-Object -First 1 }
            $texts += (Tail $desc 400)
            if ($b) { Click $b } else { Close-Win $h }
            $acted = $true
            break
        }
        if ($acted) { $last.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    return $texts
}
function Entries([string]$Dir) { return @([IO.Directory]::GetFileSystemEntries($LP + $Dir) | ForEach-Object { [IO.Path]::GetFileName($_) }) }
function Show($names) { return (($names | ForEach-Object { Esc $_ }) -join ',') }

# one row: the server folder <srv root>\$Case and the local folder <start>\$Case prepared by $Setup;
# the server panel is the left one (the local folder on the right); Home + End focus the last item;
# the command $Cmd; $Judge { param($texts, $cmds, $srv, $local, $conn) }
function Row-Ftp([string]$Case, $S, [int]$Cmd, [scriptblock]$Setup, [scriptblock]$Judge) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case; $srv = $S.Root + '\' + $Case
    try {
        NewDir $local; NewDir $srv
        & $Setup $srv $local | Out-Null
        $from = Srv-Count $S
        $id = Start-P
        Key $id 0x09; [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09
        $conn = Connect $id $S $Case
        Start-Sleep -Milliseconds 1500; Sync $id
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 700; Sync $id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Post-Cmd (Get-Main $id) $Cmd; Start-Sleep -Milliseconds 700
        $texts = @(Answer $id 90 6)
        $secs = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        $cmds = @(Srv-Cmds $S $from)
        $r = & $Judge $texts $cmds $srv $local $conn
        Row $Case 'ROW' (V ([bool]$r.Ok)) ("{0}; {1} s; connected: {2} at '{3}'; server got: {4}; dialogs: {5}" -f $r.Facts, $secs, $conn.Ok, (Tail $conn.Loc 50), ($cmds -join ' / '), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc384_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $SrvL.Root; NewDir $SrvU.Root
    Set-Config
    $upL = Start-Srv $SrvL
    $upU = Start-Srv $SrvU
    Out 'ftp384_probe (feature 384)'
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Servers : ftpmini.py (z/VM listing) cp1250 on 127.0.0.1:{0} - {1}; utf-8 on 127.0.0.1:{2} - {3}" -f $SrvL.Port, $(if ($upL) { 'up' } else { 'NOT UP' }), $SrvU.Port, $(if ($upU) { 'up' } else { 'NOT UP' }))
    Out ''
    if (-not ($upL -and $upU)) { throw 'an FTP server did not start' }
    $Cc = [string][char]0x010D
    $Both = 'name' + $Cc + '.ext' + $Cc          # both parts outside ASCII
    $Tail1 = 'name.ext' + $Cc                     # only the joined part
    # what the old whole-text decode showed for $Both on a cp1250 server: the UTF-8 bytes of the
    # first part read in cp1250 again
    $Garbled = [Text.Encoding]::GetEncoding(1250).GetString([Text.Encoding]::UTF8.GetBytes('name' + $Cc)) + '.ext' + $Cc

    Row-Ftp 'ZVM-CP-DEL' $SrvL 729 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Both, 'ZVM'); [IO.File]::WriteAllText($LP + $s + '\a-keep.txt', 'KEEP') } {
        param($t, $c, $s, $l, $conn)
        $e = @(Entries $s)
        $sentGarbled = [bool](@($c | Where-Object { $_ -clike ('*' + (Esc $Garbled)) }).Count)
        @{ Ok = ($e.Count -eq 1 -and $e[0] -ceq 'a-keep.txt'); Facts = ("on the server: {0}; a command named the garbled '{1}': {2}" -f (Show $e), (Esc $Garbled), $sentGarbled) } }
    Row-Ftp 'ZVM-CP-DL' $SrvL 727 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Both, 'ZVM'); [IO.File]::WriteAllText($LP + $s + '\a-keep.txt', 'KEEP') } {
        param($t, $c, $s, $l, $conn)
        $e = @(Entries $l); $got = ''; try { $got = [IO.File]::ReadAllText($LP + $l + '\' + $Both) } catch { }
        @{ Ok = ($got -ceq 'ZVM'); Facts = ("local folder: {0}; content {1}" -f (Show $e), ($got -ceq 'ZVM')) } }
    Row-Ftp 'ZVM-CP-ASCII' $SrvL 729 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Tail1, 'ZVM'); [IO.File]::WriteAllText($LP + $s + '\a-keep.txt', 'KEEP') } {
        param($t, $c, $s, $l, $conn)
        $e = @(Entries $s)
        @{ Ok = ($e.Count -eq 1 -and $e[0] -ceq 'a-keep.txt'); Facts = ("on the server: {0}" -f (Show $e)) } }
    Row-Ftp 'ZVM-UTF-DEL' $SrvU 729 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Both, 'ZVM'); [IO.File]::WriteAllText($LP + $s + '\a-keep.txt', 'KEEP') } {
        param($t, $c, $s, $l, $conn)
        $e = @(Entries $s)
        @{ Ok = ($e.Count -eq 1 -and $e[0] -ceq 'a-keep.txt'); Facts = ("on the server: {0}" -f (Show $e)) } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    foreach ($S in @($SrvL, $SrvU)) { if ($S.Proc -and -not $S.Proc.HasExited) { Stop-Process -Id $S.Proc.Id -Force } }
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
