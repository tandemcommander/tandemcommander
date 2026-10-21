<#
.SYNOPSIS
    Feature 277: a PWD reply whose path does not fit the FTP plug-in's 300 bytes is refused, never
    cut and worked on (the cut path is an ancestor folder); a path of exactly 300 bytes is accepted.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). 215's ftpmini.py (127.0.0.1 only)
    logs every command; its PWDMAP option (feature 277) makes a folder reached "through a link": the
    PWD reply in it names another, long path, and a path the client sends that starts with that long
    path means the folder again. Each row copies (F5) the server's folder <row>/lnk to the local
    panel; the copy's explore step sends CWD lnk + PWD and lists the files under the path PWD gave:
      AIX      the reply in the German AIX form (257 '<path>' ist ...), path = A + "/deep" (305 bytes),
               A (300 bytes) = the server's <row>/anc, which holds x.txt "ANCESTOR"; lnk holds x.txt
               "DEEP". PASS = the local lnk\x.txt is never "ANCESTOR" (refused: missing + an error)
      CP       the same in the RFC form from a cp1250 server: A is 300 bytes of UTF-8 but 152 bytes
               of cp1250 - the reply fits, its UTF-8 form does not
      R301     the same in the RFC form (UTF-8): refused before and after (the control of the refusal)
      R300     the RFC form, the path exactly 300 bytes: PASS = the local x.txt is "DEEP300"
               (it was refused at 300 bytes, one byte before the buffer is full)
      CTL      the AIX form with a short path: PASS = "DEEP" (the mapping and the form work)
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
    [int]$Port = 2177,
    [string]$Lib,
    [string]$Server
)
$ErrorActionPreference = 'Stop'
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if (-not $Server) { $Server = Join-Path $PSScriptRoot '..\..\215-ftp-long-name-command\probe\ftpmini.py' }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$Server = (Resolve-Path -LiteralPath $Server).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. $Lib

$Root = $TempRoot + '\tc277'
$StartDir = $Root + '\start'
$SrvRoot = $Root + '\srv'
$SrvLog = $Root + '\ftp.log'
$MapFile = $Root + '\pwdmap.json'
$script:Srvs = @()

function Srv-Lines([int]$From) {
    if (-not [IO.File]::Exists($SrvLog)) { return @() }
    $fs = New-Object IO.FileStream($SrvLog, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $sr = New-Object IO.StreamReader($fs); $all = @(($sr.ReadToEnd() -split "`n") | Where-Object { $_.Trim() }) } finally { $fs.Dispose() }
    if ($all.Count -le $From) { return @() }
    return @($all[$From..($all.Count - 1)] | ForEach-Object { $_ | ConvertFrom-Json })
}
function Srv-Count { return @(Srv-Lines 0).Count }
# the commands received since $From, long arguments shortened: "CWD <300 bytes>"
function Srv-Cmds([int]$From) {
    return @(Srv-Lines $From | Where-Object { $_.cmd -ne $null -or $_.event -eq 'drop' } | ForEach-Object {
            $c = [string]$_.cmd
            if ($_.event -eq 'drop') { '(the server closed the session)' }
            elseif ($c -eq '') { '(empty line)' }
            else { $v, $r = $c.Split(' ', 2); if ($r -and $r.Length -gt 40) { $v + ' <' + [Text.Encoding]::UTF8.GetByteCount($r) + ' bytes>' } else { Esc $c } }
        })
}
function Connect([int]$Id, [int]$P, [string]$Dir) {
    $notes = @()
    [void](Do-ChangeDir $Id ('ftp://u:p@127.0.0.1:' + $P + '/' + $Dir))
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
    $a = @('-t', 'T277', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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

# answers every dialog until none shows for $Quiet seconds: the first of the wanted buttons by id
# (Yes, OK), else Skip / Close by text; a dialog whose only button is Cancel (a progress or wait
# window) is left alone; the Copy dialog shown again after a failed operation is cancelled; the
# operation's progress window (its Pause button, 761) is left alone unless -CloseOps
function Answer([int]$Id, [double]$Seconds = 90, [double]$Quiet = 5, [switch]$CloseOps) {
    $texts = @(); $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew(); $seenOp = $false
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and $last.Elapsed.TotalSeconds -lt $Quiet -and (Test-Alive $Id)) {
        $acted = $false
        foreach ($h in (Dialogs $Id)) {
            $bs = Buttons $h
            $ids = @($bs | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if ($ids.Count -eq 0 -or ($ids.Count -eq 1 -and $ids[0] -eq 2)) { continue }
            if (-not $CloseOps -and ($ids -contains 761)) { continue }
            Start-Sleep -Milliseconds 500
            $desc = WinDesc $h
            if ($desc -match $FatalRx) { $texts += ('FATAL ' + (Tail $desc 300)); return $texts }
            if ([Drv098f]::Txt($h) -eq 'Change Directory') { $texts += 'Change Directory dialog'; Close-Win $h; $acted = $true; break }
            if (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 209 }).Count) {
                if ($seenOp) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
                $seenOp = $true
            }
            # an FTP error dialog (Retry / Skip): Skip, and its texts (the edits) recorded
            $b = BtnById $h @(832, 881)
            if ($b) {
                $eds = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' } | ForEach-Object { Tail ([Drv098f]::GetText($_, 5000)) 120 })
                $desc = '[' + [Drv098f]::Txt($h) + '] ' + ($eds -join ' | ')
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
function Shorten([string]$t) { $e = [regex]::Replace((Esc $t), '(?:[p]{10,}[ /]?)+', '<long>/'); if ($e.Length -le 520) { return $e }; return ($e.Substring(0, 300) + ' ...(' + ($e.Length - 450) + ')... ' + $e.Substring($e.Length - 150)) }
function Has([string[]]$Texts, [string]$Rx) { return [bool](@($Texts | Where-Object { $_ -match $Rx }).Count) }
function Read([string]$f) { try { return [IO.File]::ReadAllText($LP + $f) } catch { return '<missing>' } }

# one row: the server folder <srv>\$Case with anc\x.txt "ANCESTOR" and lnk\x.txt $Deep, the local
# panel <start>\$Case; F5 of the server's lnk (left panel) to the local panel (right)
function Row-Copy([string]$Case, [int]$P, [string]$Deep, [scriptblock]$Judge) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $local = $StartDir + '\' + $Case; $srv = $SrvRoot + '\' + $Case
    try {
        NewDir $local; NewDir $srv; NewDir ($srv + '\anc'); NewDir ($srv + '\lnk')
        [IO.File]::WriteAllText($LP + $srv + '\anc\x.txt', 'ANCESTOR')
        [IO.File]::WriteAllText($LP + $srv + '\lnk\x.txt', $Deep)
        $from = Srv-Count
        $id = Start-P
        Key $id 0x09; [void](Do-ChangeDir $id $local); Sync $id; Key $id 0x09
        $conn = Connect $id $P $Case
        Start-Sleep -Milliseconds 1500; Sync $id
        Key $id 0x24; Key $id 0x28; Key $id 0x28   # Home, Down, Down: ".." / anc / lnk
        Start-Sleep -Milliseconds 700; Sync $id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Post-Cmd (Get-Main $id) 727; Start-Sleep -Milliseconds 700
        # the copy, a reconnect (the server drops the session after the listing) and its result:
        # the file, or the error about the working path
        $texts = @()
        while ($sw.Elapsed.TotalSeconds -lt 75) {
            $texts += @(Answer $id 10 2)
            if ([IO.File]::Exists($LP + $local + '\lnk\x.txt')) { Start-Sleep -Milliseconds 1500; break }
            if (Has $texts 'Working Path|working directory') { break }
        }
        $texts += @(Answer $id 20 3 -CloseOps)
        $secs = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        $cmds = @(Srv-Cmds $from)
        $got = Read ($local + '\lnk\x.txt')
        $r = & $Judge $got $texts $cmds
        $verdict = $(if ($Expect -eq 'before') { 'PASS' } else { V ([bool]$r) })
        Row $Case 'ROW' $verdict ("local lnk\x.txt '{0}'; {1} s; connected: {2} [{3}] at '{4}'; server got: {5}; dialogs: {6}" -f $got, $secs, $conn.Ok, $conn.Notes, (Tail $conn.Loc 50), ($cmds -join ' / '), $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}
function Start-Srv([int]$P, [string]$Enc) {
    $s = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f $Server), ('"{0}"' -f $SrvRoot), $P, ('"{0}"' -f $SrvLog), $Enc, '/', ('"{0}"' -f $MapFile)) -PassThru -WindowStyle Hidden
    $script:Srvs += $s
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) { Start-Sleep -Milliseconds 300; try { $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $P); $c.Close(); return $true } catch { } }
    return $false
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc277_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $SrvRoot
    Set-Config
    # A: a 300-byte path that the server names <row>/anc by; A + "/deep" names <row>/lnk
    function PadTo([string]$Head, [int]$Bytes, [string]$Ch) { $s = $Head; while ([Text.Encoding]::UTF8.GetByteCount($s + $Ch) -le $Bytes) { $s += $Ch }; return $s }
    $aAix = PadTo '/AIX/' 300 'p'
    $aR = PadTo '/R301/' 300 'p'
    $a300 = PadTo '/R300/' 300 'p'
    $aCp = PadTo '/CP/' 300 ([string][char]0x010D)   # c-caron: 2 bytes of UTF-8, 1 of cp1250
    $map = @(
        @('/AIX/anc', $aAix, 'aix'), @('/AIX/lnk', ($aAix + '/deep'), 'aix', 'drop'),
        @('/R301/anc', $aR, 'rfc'), @('/R301/lnk', ($aR + '/deep'), 'rfc', 'drop'),
        @('/R300/lnk', $a300, 'rfc', 'drop'),
        @('/CP/anc', $aCp, 'rfc'), @('/CP/lnk', ($aCp + '/deep'), 'rfc', 'drop'),
        @('/CTL/lnk', '/CTL/elsewhere', 'aix', 'drop'))
    $esc = [Text.RegularExpressions.MatchEvaluator] { param($m) '\u{0:x4}' -f [int][char]$m.Value }
    $json = '[' + (($map | ForEach-Object { '[' + (($_ | ForEach-Object { '"' + [regex]::Replace($_, '[^\x20-\x7E]', $esc) + '"' }) -join ',') + ']' }) -join ',') + ']'
    [IO.File]::WriteAllText($LP + $MapFile, $json, (New-Object Text.UTF8Encoding($false)))
    $up1 = Start-Srv $Port 'utf-8'
    $up2 = Start-Srv ($Port + 1) 'cp1250'
    Out ("ftp277_probe (feature 277), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : ftpmini.py on 127.0.0.1:{0} utf-8 - {1}, :{2} cp1250 - {3}" -f $Port, $(if ($up1) { 'up' } else { 'NOT UP' }), ($Port + 1), $(if ($up2) { 'up' } else { 'NOT UP' }))
    Out ("Paths   : A (AIX) {0} bytes, A (R301) {1}, R300 {2}, A (cp1250) {3} bytes of UTF-8 / {4} of cp1250; + '/deep' = 5 bytes more" -f [Text.Encoding]::UTF8.GetByteCount($aAix), [Text.Encoding]::UTF8.GetByteCount($aR), [Text.Encoding]::UTF8.GetByteCount($a300), [Text.Encoding]::UTF8.GetByteCount($aCp), [Text.Encoding]::GetEncoding(1250).GetByteCount($aCp))
    Out ''
    if (-not ($up1 -and $up2)) { throw 'an FTP server did not start' }
    # refused = the working path is refused at the PWD (never a command sent to a cut path: before 277
    # the CP row ended with "Error Changing Working Path" after a CWD to the cut path)
    $refused = { param($got, $t, $c) ($got -eq '<missing>') -and (Has $t 'Error Getting Working Path') -and -not (Has $c '^CWD <') }
    Row-Copy 'AIX' $Port 'DEEP' $refused
    Row-Copy 'CP' ($Port + 1) 'DEEP' $refused
    Row-Copy 'R301' $Port 'DEEP' $refused
    Row-Copy 'R300' $Port 'DEEP300' { param($got, $t, $c) $got -ceq 'DEEP300' }
    Row-Copy 'CTL' $Port 'DEEP' { param($got, $t, $c) $got -ceq 'DEEP' }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    foreach ($s in $script:Srvs) { if ($s -and -not $s.HasExited) { Stop-Process -Id $s.Id -Force } }
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
