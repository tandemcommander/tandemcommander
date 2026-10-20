<#
.SYNOPSIS
    Feature 269: a file name with an unpaired UTF-16 surrogate (legal on NTFS, WTF-8 in the program)
    on a byte-transparent UTF-8 FTP server keeps its name - the listing read it in the code page.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). 215's ftpmini.py in its wtf-8 mode
    (UTF-8 names, FEAT announces UTF8, an unpaired surrogate carried byte for byte as a UNIX server
    does; 127.0.0.1 only) logs every command received. The name is "a" + U+D800 + ".txt". Rows
    (224's driver):
      DL        F5 of the server's file: PASS = the local folder holds exactly that name with its
                content (the listing kept the name; RETR went in UTF-8)
      UP-NEW    F5 of the local file into an empty server folder: PASS = the server holds exactly
                that name with its content (the control: STOR already went in WTF-8)
      UP-ASK    F5 of the local file into a server folder that holds the same name: PASS = the
                "Target File Already Exists" question came (answered Skip) and the server's file
                kept its content - the existence check missed it and STOR overwrote it
      DL-ASK    F5 of the server's file into a local folder that holds the same name: PASS = the
                question came (Skip) and the local file kept its content (review 1)
      DIR-DL    F5 of a server folder "d" + U+D800 holding f.txt: PASS = the local folder of that
                name with f.txt (CWD + PWD of the folder; review 1)
      DL-ACC    F5 of "cafe.txt" with e-acute from the same server: PASS = downloaded (the control:
                valid UTF-8 kept as it was)
      LEG-DL    the same server in its cp1250 mode, F5 of "cafe.txt" with e-acute: PASS = downloaded
                (feature 224's code-page detection still works)
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
    [int]$Port = 2121,
    [string]$Repo = $null,
    [string]$FtpMini = $null
)
$ErrorActionPreference = 'Stop'
if (-not $Repo) { $Repo = Join-Path $PSScriptRoot '..\..\..' }   # $PSScriptRoot is empty in a 5.1 param default
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$Repo = (Resolve-Path -LiteralPath $Repo).Path
if (-not $FtpMini) { $FtpMini = Join-Path $Repo 'specs\215-ftp-long-name-command\probe\ftpmini.py' }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc269'
$StartDir = $Root + '\start'
$SrvRoot = $Root + '\srv'
$SrvLog = $Root + '\ftp.log'
$script:Srv = $null

function Srv-Lines([int]$From) {
    if (-not [IO.File]::Exists($SrvLog)) { return @() }
    $fs = New-Object IO.FileStream($SrvLog, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $sr = New-Object IO.StreamReader($fs); $all = @(($sr.ReadToEnd() -split "`n") | Where-Object { $_.Trim() }) } finally { $fs.Dispose() }
    if ($all.Count -le $From) { return @() }
    return @($all[$From..($all.Count - 1)] | ForEach-Object { $_ | ConvertFrom-Json })
}
function Srv-Count { return @(Srv-Lines 0).Count }
function Srv-Cmds([int]$From) { return @(Srv-Lines $From | Where-Object { $_.cmd -ne $null } | ForEach-Object { $c = [string]$_.cmd; if ($c -eq '') { '(empty line)' } else { Esc $c } }) }
function Start-Srv([string]$Enc) {
    if ($script:Srv -and -not $script:Srv.HasExited) { Stop-Process -Id $script:Srv.Id -Force; Start-Sleep -Milliseconds 500 }
    $script:Srv = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f $FtpMini), ('"{0}"' -f $SrvRoot), $Port, ('"{0}"' -f $SrvLog), $Enc) -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew(); $up = $false
    while ($sw.Elapsed.TotalSeconds -lt 15 -and -not $up) { Start-Sleep -Milliseconds 300; try { $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $Port); $c.Close(); $up = $true } catch { } }
    return $up
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
            if ($ok) { $notes += ('box: ' + (Tail (WinDesc $h) 60)); Click $ok; $acted = $true; break }
        }
        if ($acted) { $quiet.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    Sync $Id
    $loc = Get-Loc $Id
    return [pscustomobject]@{ Loc = $loc; Notes = ($notes -join ', '); Ok = ($loc -like ('ftp:*' + $Dir + '*')) }
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T269', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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

# answers every dialog until none shows for $Quiet seconds: Skip (832) on an FTP problem dialog
# (also "Target File Already Exists" - nothing is overwritten), else Yes / OK, else Skip / Close
# by text; a dialog whose only button is Cancel (a progress window) is left alone
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
            if ($b) {
                $eds = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' } | ForEach-Object { Tail ([Drv098f]::GetText($_, 5000)) 120 })
                $desc = '[' + [Drv098f]::Txt($h) + '] ' + ($eds -join ' | ')
            }
            if (-not $b) { $b = BtnById $h @(6, 1) }
            if (-not $b) { $b = $bs | Where-Object { [Drv098f]::Txt($_) -match '^&?(Skip|Close)$' } | Select-Object -First 1 }
            $texts += (Tail (Esc $desc) 400)
            if ($b) { Click $b } else { Close-Win $h }
            $acted = $true
            break
        }
        if ($acted) { $last.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    return $texts
}
function Files([string]$Dir) { return @([IO.Directory]::GetFiles($LP + $Dir) | ForEach-Object { [IO.Path]::GetFileName($_) }) }
function Content([string]$Path) { try { return [IO.File]::ReadAllText($LP + $Path) } catch { return '(none)' } }

# one row: the server folder <srv>\$Case and the local folder <start>\$Case prepared by $Setup;
# $Up: the local panel is the source (left), else the server is; Home + End focus the last item,
# then F5 (727); $Judge { param($texts, $cmds, $srv, $local) } -> @{ Ok; Facts }
function Row-Ftp([string]$Case, [scriptblock]$Setup, [scriptblock]$Judge, [switch]$Up) {
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
        Start-Sleep -Milliseconds 1500; Sync $id
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 700; Sync $id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Post-Cmd (Get-Main $id) 727; Start-Sleep -Milliseconds 700
        $texts = @(Answer $id 90 6)
        $secs = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        $cmds = @(Srv-Cmds $from)
        $r = & $Judge $texts $cmds $srv $local
        Row $Case 'ROW' (V ([bool]$r.Ok)) ("{0}; {1} s; connected: {2} [{3}] at '{4}'; server got: {5}; dialogs: {6}" -f $r.Facts, $secs, $conn.Ok, $conn.Notes, (Tail (Esc $conn.Loc) 50), ($cmds -join ' / '), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}
function Names([string[]]$N) { if ($N.Count -eq 0) { return '(none)' }; return (($N | ForEach-Object { Esc $_ }) -join ',') }

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc269_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $SrvRoot
    Set-Config
    $up = Start-Srv 'wtf-8'
    $Sur = 'a' + [char]0xD800 + '.txt'
    $Acc = 'caf' + [char]0xE9 + '.txt'
    Out "ftp269_probe (feature 269)"
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : {0} wtf-8 on 127.0.0.1:{1} - {2}; the name: {3}" -f $FtpMini, $Port, $(if ($up) { 'up' } else { 'NOT UP' }), (Esc $Sur))
    Out ''
    if (-not $up) { throw 'the FTP server did not start' }

    Row-Ftp 'DL' { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Sur, 'SRV') } {
        param($t, $c, $s, $l)
        $got = @(Files $l)
        @{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $Sur -and (Content ($l + '\' + $Sur)) -ceq 'SRV'); Facts = ("local folder: {0}" -f (Names $got)) } }
    Row-Ftp 'UP-NEW' { param($s, $l) [IO.File]::WriteAllText($LP + $l + '\' + $Sur, 'LOCAL') } {
        param($t, $c, $s, $l)
        $got = @(Files $s)
        @{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $Sur -and (Content ($s + '\' + $Sur)) -ceq 'LOCAL'); Facts = ("server folder: {0}" -f (Names $got)) } } -Up
    Row-Ftp 'UP-ASK' { param($s, $l) [IO.File]::WriteAllText($LP + $l + '\' + $Sur, 'LOCAL'); [IO.File]::WriteAllText($LP + $s + '\' + $Sur, 'SRV') } {
        param($t, $c, $s, $l)
        $got = @(Files $s); $kept = (Content ($s + '\' + $Sur)) -ceq 'SRV'; $asked = [bool](@($t | Where-Object { $_ -match 'Already Exists' }).Count)
        $stor = [bool](@($c | Where-Object { $_ -match '^(STOR|APPE) ' }).Count)
        @{ Ok = ($asked -and $kept -and -not $stor -and $got.Count -eq 1); Facts = ("asked 'already exists' {0}; the server's file kept its content {1}; STOR/APPE sent {2}; server folder: {3}" -f $asked, $kept, $stor, (Names $got)) } } -Up
    # review 1: the download now finds a local file of the same name - it must ask, not overwrite
    Row-Ftp 'DL-ASK' { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Sur, 'SRV'); [IO.File]::WriteAllText($LP + $l + '\' + $Sur, 'LOCAL') } {
        param($t, $c, $s, $l)
        $got = @(Files $l); $kept = (Content ($l + '\' + $Sur)) -ceq 'LOCAL'; $asked = [bool](@($t | Where-Object { $_ -match 'Already Exists' }).Count)
        @{ Ok = ($asked -and $kept -and $got.Count -eq 1); Facts = ("asked 'already exists' {0}; the local file kept its content {1}; local folder: {2}" -f $asked, $kept, (Names $got)) } }
    # review 1: a folder with the surrogate - CWD into it, its PWD path decoded by the same rule
    $Dir = 'd' + [char]0xD800
    Row-Ftp 'DIR-DL' { param($s, $l) NewDir ($s + '\' + $Dir); [IO.File]::WriteAllText($LP + $s + '\' + $Dir + '\f.txt', 'DIR') } {
        param($t, $c, $s, $l)
        $got = @([IO.Directory]::GetDirectories($LP + $l) | ForEach-Object { [IO.Path]::GetFileName($_) })
        @{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $Dir -and (Content ($l + '\' + $Dir + '\f.txt')) -ceq 'DIR'); Facts = ("local folders: {0}; f.txt in it {1}" -f (Names $got), (Content ($l + '\' + $Dir + '\f.txt'))) } }
    Row-Ftp 'DL-ACC' { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC') } {
        param($t, $c, $s, $l)
        $got = @(Files $l)
        @{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $Acc -and (Content ($l + '\' + $Acc)) -ceq 'ACC'); Facts = ("local folder: {0}" -f (Names $got)) } }

    $up = Start-Srv 'cp1250'
    if (-not $up) { throw 'the FTP server (cp1250) did not start' }
    Row-Ftp 'LEG-DL' { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC') } {
        param($t, $c, $s, $l)
        $got = @(Files $l)
        @{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $Acc -and (Content ($l + '\' + $Acc)) -ceq 'ACC'); Facts = ("local folder: {0}" -f (Names $got)) } }
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
