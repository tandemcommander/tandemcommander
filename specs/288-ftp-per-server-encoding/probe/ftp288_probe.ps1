<#
.SYNOPSIS
    Feature 288: names go to each FTP server in its own encoding - a new name (MKD, RNTO, STOR) goes
    in the code page to a server whose listing showed it speaks the code page, and a name seen in the
    code page on one server no longer goes in the code page to another.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). Two of 215's ftpmini.py servers
    (127.0.0.1 only) log every command received: a legacy one (names in cp1250 on the wire; FEAT
    announces nothing) on $Port and a UTF-8 one on $Port + 1. Rows (224's driver):
      LEG-MKD   legacy server, its folder lists "cafe.txt" with e-acute (the evidence); F7 "novy" with
                y-acute: PASS = the server has the folder by that name (MKD in cp1250)
      LEG-REN   the same folder; Quick Rename of a.txt to "caj.txt" with c-caron: PASS = the server
                has that name (RNTO in cp1250)
      LEG-UP    the same folder; F5 of the local "caj.txt" with c-caron to it: PASS = the server has
                the file by that name with its content (STOR in cp1250; an operation's worker)
      CROSS-DEL one program: the legacy server's folder lists "cafe.txt" (cp1250), then the panel goes
                to the UTF-8 server's folder with the same name and F8 deletes it: PASS = deleted
                (DELE in UTF-8 - the name seen in the code page on the other server does not count)
      UTF-MKD   the control: UTF-8 server, its folder lists "cafe.txt" in UTF-8; F7 "novy": PASS =
                the folder by that name (MKD in UTF-8 - before and after)
      UNK-MKD   the limit: the legacy server, a folder of ASCII names only (no evidence yet); F7
                "novy": PASS = MKD went in UTF-8 (an unknown server gets UTF-8, as since 224) - the
                server shows the name garbled
    The product's registry key is exported, restored and compared. Exit code = FAIL rows.
    -Expect before: every row is recorded, verdicts are the facts (PASS/FAIL as measured).

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
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

$Root = $TempRoot + '\tc288'
$StartDir = $Root + '\start'
$SrvL = @{ Root = ($Root + '\srvleg'); Log = ($Root + '\ftpleg.log'); Port = $Port; Enc = 'cp1250'; Proc = $null }
$SrvU = @{ Root = ($Root + '\srvutf'); Log = ($Root + '\ftputf.log'); Port = ($Port + 1); Enc = 'utf-8'; Proc = $null }
$MiniPy = Join-Path $PSScriptRoot '..\..\215-ftp-long-name-command\probe\ftpmini.py'

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
# the commands received since $From (as the server decoded them)
function Srv-Cmds($S, [int]$From) {
    return @(Srv-Lines $S $From | Where-Object { $_.cmd -ne $null } | ForEach-Object { $c = [string]$_.cmd; if ($c -eq '') { '(empty line)' } else { Esc $c } })
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
    $a = @('-t', 'T288', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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

# answers every dialog until none shows for $Quiet seconds (224's driver): the first of the wanted
# buttons by id (Yes, OK), else Skip / Close by text; $FirstEdit: text for the first dialog with an edit
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
            if (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 209 }).Count) {
                if ($seenOp) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
                $seenOp = $true
            }
            if ($FirstEdit -and -not $typed) {
                $edit = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
                if ($edit) { [void][Drv098f]::SetText($edit, $FirstEdit, 5000); $typed = $true; $texts += ('typed into [' + (Tail ([Drv098f]::Txt($h)) 40) + ']'); Click-Ok $h; $acted = $true; break }
            }
            if ($typed -and @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2477 }).Count -eq 0 -and @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) }).Count) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
            $b = BtnById $h @(832, 881)
            if ($b) {
                $eds = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' } | ForEach-Object { Tail ([Drv098f]::GetText($_, 5000)) 120 })
                $desc = '[' + [Drv098f]::Txt($h) + '] ' + ($eds -join ' | ')
            }
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
# $Up: the local panel is the source (left), else the server is (left, local on the right);
# Home + $Down x Down focus the item (-1: End); the command $Cmd; $Judge { param($texts, $cmds, $srv, $local, $conn) }
function Row-Ftp([string]$Case, $S, [int]$Down, [int]$Cmd, [scriptblock]$Setup, [scriptblock]$Judge, [switch]$Up, [string]$Type = $null) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case; $srv = $S.Root + '\' + $Case
    try {
        NewDir $local; NewDir $srv
        & $Setup $srv $local | Out-Null
        $from = Srv-Count $S
        $id = Start-P
        if ($Up) { [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09 }
        else { Key $id 0x09; [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09 }
        $conn = Connect $id $S $Case
        if ($Up) { Key $id 0x09 }
        Start-Sleep -Milliseconds 1500; Sync $id
        Key $id 0x24
        if ($Down -lt 0) { Key $id 0x23 } else { for ($i = 0; $i -lt $Down; $i++) { Key $id 0x28 } }
        Start-Sleep -Milliseconds 700; Sync $id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Post-Cmd (Get-Main $id) $Cmd; Start-Sleep -Milliseconds 700
        $texts = @(Answer $id 90 6 $Type)
        $secs = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        $cmds = @(Srv-Cmds $S $from)
        $r = & $Judge $texts $cmds $srv $local $conn
        Row $Case 'ROW' (V ([bool]$r.Ok)) ("{0}; {1} s; connected: {2} at '{3}'; server got: {4}; dialogs: {5}" -f $r.Facts, $secs, $conn.Ok, (Tail $conn.Loc 50), ($cmds -join ' / '), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc288_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $SrvL.Root; NewDir $SrvU.Root
    Set-Config
    $upL = Start-Srv $SrvL
    $upU = Start-Srv $SrvU
    Out 'ftp288_probe (feature 288)'
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Servers : ftpmini.py cp1250 on 127.0.0.1:{0} - {1}; utf-8 on 127.0.0.1:{2} - {3}" -f $SrvL.Port, $(if ($upL) { 'up' } else { 'NOT UP' }), $SrvU.Port, $(if ($upU) { 'up' } else { 'NOT UP' }))
    Out ''
    if (-not ($upL -and $upU)) { throw 'an FTP server did not start' }
    $Acc = 'caf' + [char]0xE9 + '.txt'
    $Novy = 'nov' + [char]0xFD
    $Caj = [char]0x010D + 'aj.txt'

    Row-Ftp 'LEG-MKD' $SrvL 0 730 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC') } {
        param($t, $c, $s, $l, $conn)
        $e = @(Entries $s)
        @{ Ok = ($e -ccontains $Novy); Facts = ("on the server: {0}" -f (Show $e)) } } -Type $Novy
    Row-Ftp 'LEG-REN' $SrvL 1 754 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\a.txt', 'A'); [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC') } {
        param($t, $c, $s, $l, $conn)
        $e = @(Entries $s)
        @{ Ok = ($e -ccontains $Caj -and -not ($e -ccontains 'a.txt')); Facts = ("on the server: {0}" -f (Show $e)) } } -Type $Caj
    Row-Ftp 'LEG-UP' $SrvL -1 727 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC'); [IO.File]::WriteAllText($LP + $l + '\' + $Caj, 'CAJ') } {
        param($t, $c, $s, $l, $conn)
        $e = @(Entries $s); $got = ''; try { $got = [IO.File]::ReadAllText($LP + $s + '\' + $Caj) } catch { }
        @{ Ok = ($got -ceq 'CAJ'); Facts = ("on the server: {0}; content {1}" -f (Show $e), ($got -ceq 'CAJ')) } } -Up

    # CROSS-DEL: the legacy server lists the name in cp1250, then the UTF-8 server's folder with it
    if (Want 'CROSS-DEL') {
        $before = Reports; $id = 0
        try {
            NewDir ($SrvL.Root + '\CROSS'); NewDir ($SrvU.Root + '\CROSS')
            [IO.File]::WriteAllText($LP + $SrvL.Root + '\CROSS\' + $Acc, 'LEG'); [IO.File]::WriteAllText($LP + $SrvU.Root + '\CROSS\' + $Acc, 'UTF'); [IO.File]::WriteAllText($LP + $SrvU.Root + '\CROSS\a-keep.txt', 'KEEP')
            $fromL = Srv-Count $SrvL; $fromU = Srv-Count $SrvU
            $id = Start-P
            $c1 = Connect $id $SrvL 'CROSS'
            Start-Sleep -Milliseconds 1500; Sync $id
            $c2 = Connect $id $SrvU 'CROSS'
            Start-Sleep -Milliseconds 1500; Sync $id
            Key $id 0x24; Key $id 0x23; Start-Sleep -Milliseconds 700; Sync $id
            Post-Cmd (Get-Main $id) 729; Start-Sleep -Milliseconds 700
            $texts = @(Answer $id 60 6)
            $eU = @(Entries ($SrvU.Root + '\CROSS')); $eL = @(Entries ($SrvL.Root + '\CROSS'))
            $ok = ($c1.Ok -and $c2.Ok -and $eU.Count -eq 1 -and $eU[0] -ceq 'a-keep.txt' -and ($eL -ccontains $Acc))
            Row 'CROSS-DEL' 'ROW' (V $ok) ("UTF-8 server: {0}; legacy server: {1}; at '{2}' then '{3}'; legacy got: {4}; UTF-8 got: {5}; dialogs: {6}" -f (Show $eU), (Show $eL), (Tail $c1.Loc 40), (Tail $c2.Loc 40), ((Srv-Cmds $SrvL $fromL) -join ' / '), ((Srv-Cmds $SrvU $fromU) -join ' / '), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
        }
        catch { Row 'CROSS-DEL' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { $fatal = Fatal-Win $id; End-Row 'CROSS-DEL' $id $fatal $before } }
    }

    Row-Ftp 'UTF-MKD' $SrvU 0 730 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\' + $Acc, 'ACC') } {
        param($t, $c, $s, $l, $conn)
        $e = @(Entries $s)
        @{ Ok = ($e -ccontains $Novy); Facts = ("on the server: {0}" -f (Show $e)) } } -Type $Novy
    # the limit: no evidence yet - UTF-8 (the cp1250 server decodes its bytes: another name)
    $NovyAsCp = [Text.Encoding]::GetEncoding(1250).GetString([Text.Encoding]::UTF8.GetBytes($Novy))
    Row-Ftp 'UNK-MKD' $SrvL 0 730 { param($s, $l) [IO.File]::WriteAllText($LP + $s + '\a.txt', 'A') } {
        param($t, $c, $s, $l, $conn)
        $e = @(Entries $s)
        @{ Ok = ($e -ccontains $NovyAsCp); Facts = ("on the server: {0} (UTF-8 read as cp1250 = '{1}')" -f (Show $e), (Esc $NovyAsCp)) } } -Type $Novy
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
