<#
.SYNOPSIS
    Backlog item share-list-offers-sign-in: a server whose share list needs a name and password
    first - does \\server\ offer the sign-in and then the list, without a Network plug-in.

.DESCRIPTION
    Rows (names for -Only); every row starts its own instance in English and ends it. The share
    list and the sign-in come from Debug-only seams (TC_PROBE_UNC_*, feature 125
    contracts/probe-seam.md and this feature's contract); a chosen share is opened by the ordinary
    path change against the real \\localhost.

      A1  Change Directory \\localhost\ : list refused (5), the sign-in succeeds (seam 0)
      A2  at \\localhost\C$ : Backspace (feature 284 route), list refused (5), sign-in succeeds
      C1  Change Directory \\localhost\ : list refused (5), the sign-in is cancelled (1223)
      F1  Change Directory \\localhost\ : list refused (5), the sign-in fails (1326)
      W1  Change Directory \\localhost\ : list refused (5), the sign-in meets another user's
          connection (1219)
      K1  Change Directory \\localhost\ : list refused (5), the sign-in succeeds, the list is
          refused again (5)
      N1  Change Directory \\localhost\ : the server is not found (53) - no sign-in
      R1  Change Directory \\localhost\ : the list is given at once - no sign-in

    The sign-in seam appends each attempt's target (the name Windows would be asked to connect)
    to a log file; the probe reads how many attempts were made and to which target.

    With -Expect measure (default) the rows are INFO - the probe only records. With -Expect fixed:
      A1, A2  one sign-in to \\localhost\IPC$; the share list opens; Down, Down, Enter ->
              location \\localhost\D$; no message box
      C1      one sign-in; no list, no message box; the Change Directory dialog opens again;
              location unchanged (the start folder)
      F1      one sign-in; one box with (1326); no list; location unchanged
      W1      one sign-in; one box "Multiple connections to a server"; no list; location unchanged
      K1      one sign-in (not a second); one box naming \\localhost\ and (5); no list
      N1      no sign-in; one box naming \\localhost\ and (53); no list
      R1      no sign-in; the list opens; Down, Down, Enter -> \\localhost\D$; no message box

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.PARAMETER Exe   tandemcommander.exe under test (a Debug build: the seams)
.PARAMETER Repo  the repository root (default: three levels above this script)
.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('measure', 'fixed')][string]$Expect = 'measure',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Repo
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $Repo) { $Repo = Join-Path $PSScriptRoot '..\..\..' }
$Repo = (Resolve-Path -LiteralPath $Repo).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tcsignin'
$StartDir = $Root + '\start'
$SignLog = $Root + '\signin.log'
$Fixed = ($Expect -eq 'fixed')
$MenuClass = 'PopupMenuClass'
$Server = '\\localhost\'
$Share0 = '\\localhost\C$'
$Picked = '\\localhost\D$'
$Target = '\\localhost\IPC$'
$SeamList = 'C$*2147483648|D$*2147483648|IPC$*2147483651'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function V2([bool]$ok) { if (-not $Fixed) { return 'INFO' }; return (V $ok) }
function Set-Seam([string]$Shares, [string]$Err, [string]$SignIn, [string]$Keep) {
    $env:TC_PROBE_UNC_SHARES = $Shares; $env:TC_PROBE_UNC_DELAY = ''; $env:TC_PROBE_UNC_ERROR = $Err
    $env:TC_PROBE_UNC_SIGNIN = $SignIn; $env:TC_PROBE_UNC_SIGNIN_KEEP = $Keep
    $env:TC_PROBE_UNC_SIGNIN_LOG = $(if ($SignIn -ne '') { $SignLog } else { '' })
}
function Start-P {
    $a = @('-t', 'TSR', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    $r = Serve $p.Id 8
    if ($r.Messages.Count) { Out ('           at start: ' + (Msgs $r)) }
    return $p.Id
}
# the location of a panel: its Change Directory field as the dialog opens (862 active)
function Get-LocOf([int]$Id, [int]$Cmd) {
    if (-not (Test-Alive $Id)) { return '<gone>' }
    $dlg = Open-ByCmd $Id $Cmd
    if ($dlg -eq [IntPtr]::Zero) { return '<no dialog>' }
    $d = WinDesc $dlg
    if ($d -match $FatalRx) { return ('<FATAL ' + $d + '>') }
    $ctl = Find-Ctl $dlg 210
    $t = '<no field>'; if ($ctl -ne [IntPtr]::Zero) { $t = [Drv098f]::GetText($ctl, 5000) }
    Close-Win $dlg
    Start-Sleep -Milliseconds 300
    return $t
}
# a share list opened by the program (PopupMenuClass); [IntPtr]::Zero when none within the time
function Wait-Menu([int]$Id, [double]$Seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        $m = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq $MenuClass }) | Select-Object -First 1
        if ($m) { Start-Sleep -Milliseconds 500; return $m }
        $box = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::Txt($_) -ne '' }) | Select-Object -First 1
        if ($box) { return [IntPtr]::Zero }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
function Menu-Key([IntPtr]$Menu, [int]$Vk) {
    [void][Drv098f]::PostMessageW($Menu, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($Menu, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)
    Start-Sleep -Milliseconds 250
}
function Key-Post([int]$Id, [int]$Vk) {   # posted: the key may open a modal menu
    $l = Get-LeftList $Id
    [void][Drv098f]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)
}
function Go-Start([int]$Id, [string]$Where) {
    [void](Do-ChangeDir $Id $Where)
    $r = Serve $Id 60
    Sync $Id; Start-Sleep -Milliseconds 1200
    $loc = Get-LocOf $Id 862
    if ($loc -ine $Where) { throw ("could not open {0}: location '{1}', windows: {2}" -f $Where, (Esc $loc), (Msgs $r)) }
}
function Read-SignLog {
    if (-not [IO.File]::Exists($SignLog)) { return @() }
    return @([IO.File]::ReadAllLines($SignLog, $Utf8) | Where-Object { $_ -ne '' })
}
# the message boxes of a row (the Change Directory dialog reopening is counted apart)
function Boxes($r) { return @($r.Messages | Where-Object { $_ -ne 'Change Directory dialog opened' }) }
function Reopened($r) { return @($r.Messages | Where-Object { $_ -eq 'Change Directory dialog opened' }).Count -gt 0 }

# one row: from $Where (a start folder or a share's root), run the action; see whether the share
# list opens; pick the second item (Down, Down, Enter); read the location and the sign-in log
function Row-Act([string]$Case, [string]$Where, [string]$What, [scriptblock]$Act, [string]$Kind,
    [string]$Err, [string]$SignIn, [string]$Keep = '', [string]$List = $SeamList) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        if ([IO.File]::Exists($SignLog)) { [IO.File]::Delete($SignLog) }
        Set-Seam $List $Err $SignIn $Keep   # inherited by the program at its start
        $id = Start-P
        if ($Where -ne $StartDir) { Go-Start $id $Where }
        & $Act $id
        $menu = Wait-Menu $id 15
        $hadMenu = ($menu -ne [IntPtr]::Zero)
        if ($hadMenu) { Menu-Key $menu 0x28; Menu-Key $menu 0x28; Menu-Key $menu 0x0D }
        $r = Serve $id 60
        $fatal = $r.Fatal
        Sync $id; Start-Sleep -Milliseconds 1500
        $loc = Get-LocOf $id 862
        $log = @(Read-SignLog)
        $box = @(Boxes $r)
        $facts = ("from '{0}': {1}; sign-ins: {2} [{3}]; share list opened: {4}; windows: {5}; location '{6}'" -f (Esc $Where), $What, $log.Count, (Esc ($log -join ' | ')), $hadMenu, (Msgs $r), (Esc $loc))
        $ok = -not $fatal
        $one = ($log.Count -eq 1 -and $log[0] -ceq $Target)
        switch ($Kind) {
            'pick'     { $ok = $ok -and $one -and $hadMenu -and $box.Count -eq 0 -and $loc -ieq $Picked }
            'cancel'   { $ok = $ok -and $one -and (-not $hadMenu) -and $box.Count -eq 0 -and (Reopened $r) -and $loc -ieq $Where }
            'fail'     { $ok = $ok -and $one -and (-not $hadMenu) -and $box.Count -eq 1 -and ($box[0] -match '\(1326\)') -and $loc -ieq $Where }
            'conflict' { $ok = $ok -and $one -and (-not $hadMenu) -and $box.Count -eq 1 -and ($box[0] -match 'Multiple connections to a server') -and $loc -ieq $Where }
            'again'    { $ok = $ok -and $one -and (-not $hadMenu) -and $box.Count -eq 1 -and ($box[0] -match [regex]::Escape($Server)) -and ($box[0] -match '\(5\)') -and $loc -ieq $Where }
            'notfound' { $ok = $ok -and $log.Count -eq 0 -and (-not $hadMenu) -and $box.Count -eq 1 -and ($box[0] -match [regex]::Escape($Server)) -and ($box[0] -match '\(53\)') -and $loc -ieq $Where }
            'direct'   { $ok = $ok -and $log.Count -eq 0 -and $hadMenu -and $box.Count -eq 0 -and $loc -ieq $Picked }
        }
        Row $Case 'ACT' (V2 $ok) $facts
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' '' '' ''; if ($id) { End-Row $Case $id $fatal $before } }
}

$ToServer = { param($id) [void](Do-ChangeDir $id $Server) }
$Backspace = { param($id) Key-Post $id 0x08 }

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tcsignin_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    Set-Config
    Out ("signin_probe (backlog item share-list-offers-sign-in), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; computer {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), $env:COMPUTERNAME, $existed, $regHash)
    Out ("Plug-in : plugins\nethood\nethood.spl present next to the program: {0}; seam list: {1}" -f (Test-Path -LiteralPath (Join-Path (Split-Path $Exe) 'plugins\nethood\nethood.spl')), $SeamList)
    Out ''
    Row-Act 'A1' $StartDir 'Change Directory \\localhost\, list refused (5), sign-in 0' $ToServer 'pick' '5' '0'
    Row-Act 'A2' $Share0 'Backspace, list refused (5), sign-in 0' $Backspace 'pick' '5' '0'
    Row-Act 'C1' $StartDir 'Change Directory \\localhost\, list refused (5), sign-in cancelled (1223)' $ToServer 'cancel' '5' '1223'
    Row-Act 'F1' $StartDir 'Change Directory \\localhost\, list refused (5), sign-in fails (1326)' $ToServer 'fail' '5' '1326'
    Row-Act 'W1' $StartDir 'Change Directory \\localhost\, list refused (5), sign-in conflict (1219)' $ToServer 'conflict' '5' '1219'
    Row-Act 'K1' $StartDir 'Change Directory \\localhost\, list refused (5), sign-in 0, refused again' $ToServer 'again' '5' '0' '1'
    Row-Act 'N1' $StartDir 'Change Directory \\localhost\, server not found (53)' $ToServer 'notfound' '53' '0'
    Row-Act 'R1' $StartDir 'Change Directory \\localhost\, the list at once' $ToServer 'direct' '' '0'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    $ni = @($script:Rows | Where-Object { $_.Verdict -eq 'INFO' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}, INFO {3}. Left running: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $ni, $leftover.Count, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
