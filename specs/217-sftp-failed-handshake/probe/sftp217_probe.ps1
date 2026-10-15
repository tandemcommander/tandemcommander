<#
.SYNOPSIS
    Feature 217: an SFTP connection whose SSH handshake fails leaves nothing behind - no memory
    leak report and no hang at the program's exit.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). fakessh.py (127.0.0.1 only)
    fails every handshake in its MODE; each row is its own start of the program: the left panel
    connects by the typed address sftp://tctest@127.0.0.1:PORT/x, every dialog is answered (OK /
    Close / Cancel), then the program is closed - the END row fails on any window at the exit
    (a Debug build's leak report) or an exit that takes over 30 s.
      CLOSE    the server accepts and closes at once
      BANNER   the server sends its banner, reads the client's, closes
      GARBAGE  the banner, then bytes that are no SSH packet
      KEXDROP  the banner, the client's key exchange read, then closed (the server ends it)
      FLIPSIG  a proxy to the real test server flips a byte of the server's signed key exchange
               reply: the key exchange fails after the server's host key was taken (the leak)
      CUT-KEX / CUT-AUTH / CUT-LATE  a proxy to the real test server (tandem-sftp, 2222) cuts the
               connection after 1200 / 3000 / 6000 bytes from the server
      CTL      no connection made at all (Change Directory not used) - the control
    The product's registry key is exported, restored and compared. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [int]$Port = 2223,
    [int]$Repeat = 1
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc217'
$StartDir = $Root + '\start'
$SrvLog = $Root + '\fakessh.log'
$script:Srv = $null

function Start-Srv([string]$Mode) {
    Stop-Srv
    $script:Srv = Start-Process -FilePath $Python -ArgumentList @('-I', ('"{0}"' -f (Join-Path $PSScriptRoot 'fakessh.py')), $Port, $Mode, ('"{0}"' -f $SrvLog)) -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) { Start-Sleep -Milliseconds 300; try { $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $Port); $c.Close(); return $true } catch { } }
    return $false
}
function Stop-Srv { if ($script:Srv -and -not $script:Srv.HasExited) { Stop-Process -Id $script:Srv.Id -Force; Start-Sleep -Milliseconds 400 }; $script:Srv = $null }

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T217', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
                $edit = Find-Ctl $h 630; if ($edit -eq [IntPtr]::Zero) { $edit = $null }   # only the password field
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
            if (-not $b) { $b = BtnById $h @(644, 643) }   # a host key: accept ONCE (never stored)
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

function Row-Hs([string]$Case, [string]$Mode) {
    if (-not (Want $Case)) { return }
    for ($k = 1; $k -le $Repeat; $k++) {
        $name = $(if ($Repeat -gt 1) { $Case + '#' + $k } else { $Case })
        $before = Reports; $id = 0
        try {
            if ($Mode -and $Mode -ne 'real' -and -not (Start-Srv $Mode)) { Row $name 'ROW' 'NOT DRIVEN' 'the fake server did not start'; continue }
            $id = Start-P
            $texts = @()
            if ($Mode) {
                [void](Do-ChangeDir $id ($(if ($Mode -eq 'real') { 'sftp://tctest@localhost:2222/home/tctest' } else { 'sftp://tctest@127.0.0.1:' + $Port + '/x' })))
                Start-Sleep -Milliseconds 800
                $texts = @(Answer $id 60 5 $(if ($Mode -like 'cut*' -or $Mode -eq 'real' -or $Mode -eq 'flipsig') { 'tandem123' } else { $null }))
            }
            Row $name 'ROW' 'PASS' ("dialogs: {0}" -f $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
        }
        catch { Row $name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { $fatal = Fatal-Win $id; End-Row $name $id $fatal $before } }
    }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc217_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("sftp217_probe (feature 217) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ''
    Row-Hs 'CTL' ''
    Row-Hs 'CLOSE' 'close'
    Row-Hs 'BANNER' 'banner'
    Row-Hs 'GARBAGE' 'garbage'
    Row-Hs 'KEXDROP' 'kexdrop'
    Row-Hs 'FLIPSIG' 'flipsig'
    Row-Hs 'CUT-KEX' 'cut1200'
    Row-Hs 'CUT-AUTH' 'cut3000'
    Row-Hs 'CUT-LATE' 'cut6000'
    if ($Repeat -gt 1) { Row-Hs 'REAL' 'real' }   # the real server, $Repeat connections (the leak was seen on the ninth)
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    Stop-Srv
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if ([IO.File]::Exists($SrvLog)) { Out ''; Out 'Server log:'; foreach ($l in [IO.File]::ReadAllLines($SrvLog)) { Out ('  ' + $l) } }
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
