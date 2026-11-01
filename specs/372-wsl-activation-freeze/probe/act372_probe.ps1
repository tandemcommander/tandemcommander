<#
.SYNOPSIS
    Feature 372 probe: how long the main window stops answering after the program is activated
    again while a panel shows a WSL folder (\\wsl.localhost\<distro>\...) - and, as the control, a
    local folder; and that the WSL panel still follows the folder's changes after the activation.

.DESCRIPTION
    Per row the program starts with the left panel on the row's folder and the right panel on a
    local fixture folder. After 3 s of rest it is deactivated and activated again the way Windows
    tells it (WM_ACTIVATEAPP FALSE, 400 ms, WM_ACTIVATEAPP TRUE, posted to the main window). From the
    activation on, for 1500 ms, the probe sends WM_NULL to the main window every 2 ms
    (SendMessageTimeout) and records every wait > 16 ms with its start offset = the times the UI
    thread did not run its message loop.
      LOCAL   the control: a local folder with 800 files; <Cycles> activations.
              PASS = the longest wait is not longer than -LocalBaseMs (140, measured at 50c47081) + 20 ms
      WSLROOT \\wsl.localhost\<distro>\ ; <Cycles> activations
      WSLBIG  \\wsl.localhost\<distro>\usr\bin ; <Cycles> activations
              PASS = every wait that starts later than 100 ms after an activation is below -LimitMs
              (SC-001) and the longest wait is within the LOCAL row's longest + 20 ms (SC-003)
      WSLNEW  the left panel on <fix>\new (holding the folder zzz); while inactive the folder aaa is
              created; after the activation Home, Down, Enter: PASS = the panel is in <fix>\new\aaa
              within 2 s (SC-002) and no late wait >= -LimitMs
      SHARE   the LOCAL folder through \\localhost\<drive>$ (US2), when reachable; verdict as WSLROOT
      WSLDEL  the left panel on <fix>\del\sub; while inactive sub is deleted; PASS = 3 s after the
              activation the panel shows <fix>\del (SC-004) and no late wait >= -LimitMs before
              the panel changed (recorded)
    <fix> = \\wsl.localhost\<distro>\tmp\tc372act (made and removed by the probe; every path the
    probe changes lies inside it or inside %TEMP%\tc372act). The busy cursor of another process is
    not readable on the hidden desktop (CURSOR rows NOT DRIVEN).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$Lib,
    [string]$Distro = 'Ubuntu',
    [int]$Cycles = 5,
    [int]$LimitMs = 50,
    [int]$LocalBaseMs = 140,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc372act'
$StartDir = $Root + '\start'
$LocalDir = $Root + '\local'
$Wsl = '\\wsl.localhost\' + $Distro + '\'
$WslFix = $Wsl + 'tmp\tc372act'
$script:WaitLog = @()
$script:LocalMax = $null

# every wait for an answer of the main window within $Ms milliseconds
function Measure-Answers([IntPtr]$Main, [int]$Ms) {
    $max = 0.0; $late = 0.0; $sum = 0.0; $n = 0; $waits = @()
    $total = [Diagnostics.Stopwatch]::StartNew(); $one = New-Object Diagnostics.Stopwatch
    while ($total.Elapsed.TotalMilliseconds -lt $Ms) {
        $at = $total.Elapsed.TotalMilliseconds
        $one.Restart()
        [void][Drv098f]::Send($Main, 0, 0, 0, 20000)
        $d = $one.Elapsed.TotalMilliseconds
        if ($d -gt $max) { $max = $d }
        if ($at -gt 100 -and $d -gt $late) { $late = $d }
        if ($d -gt 16) { $sum += $d; $waits += ('{0:N0}+{1:N0}' -f $at, $d) }
        $n++
        Start-Sleep -Milliseconds 2
    }
    return [pscustomobject]@{ Max = $max; Late = $late; Blocked = $sum; Pings = $n; Waits = ($waits -join ' ') }
}

function Start-Row([string]$Left) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T372', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 3000
    [void](Serve $p.Id 5)
    return $p.Id
}

function Deactivate([IntPtr]$Main) { [void][Drv098f]::PostMessageW($Main, 0x001C, [IntPtr]0, [IntPtr]::Zero) }  # WM_ACTIVATEAPP FALSE
function Activate([IntPtr]$Main) { [void][Drv098f]::PostMessageW($Main, 0x001C, [IntPtr]1, [IntPtr]::Zero) }    # WM_ACTIVATEAPP TRUE

function Run-Timing([string]$Case, [string]$Left) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        $id = Start-Row $Left
        $main = Get-Main $id
        $title = [Drv098f]::Txt($main)
        $rest = Measure-Answers $main 1000
        $maxes = @(); $lates = @()
        for ($c = 0; $c -lt $Cycles; $c++) {
            Deactivate $main
            Start-Sleep -Milliseconds 400
            Activate $main
            $m = Measure-Answers $main 1500
            $maxes += [math]::Round($m.Max, 1); $lates += [math]::Round($m.Late, 1)
            $script:WaitLog += ('{0} #{1}: {2}' -f $Case, $c, $m.Waits)
            Start-Sleep -Milliseconds 600
        }
        foreach ($w in $script:WaitLog) { Out ('  waits (start ms after activation + length ms): ' + $w) }
        $script:WaitLog = @()
        $r = Serve $id 3
        $worst = ($maxes | Measure-Object -Maximum).Maximum
        $worstLate = ($lates | Measure-Object -Maximum).Maximum
        if ($Case -eq 'LOCAL') {
            $script:LocalMax = $worst
            $ok = ($worst -le $LocalBaseMs + 20)
            $why = ('longest {0:N1} ms <= {1} + 20' -f $worst, $LocalBaseMs)
        }
        else {
            $ref = if ($null -ne $script:LocalMax) { $script:LocalMax } else { $LocalBaseMs }
            $ok = ($worstLate -lt $LimitMs) -and ($worst -le $ref + 20)
            $why = ('late waits < {0} ms: {1:N1}; longest {2:N1} <= LOCAL {3:N1} + 20' -f $LimitMs, $worstLate, $worst, $ref)
        }
        Row $Case 'ACTIVATE' (V $ok) ("{0}; left '{1}'; at rest max {2:N1} ms; per activation max [ms]: {3}; late (after +100 ms) max [ms]: {4}; title '{5}'; windows: {6}" -f $why, $Left, $rest.Max, ($maxes -join ', '), ($lates -join ', '), (Tail $title 60), (Msgs $r))
        Row $Case 'CURSOR' 'NOT DRIVEN' 'the busy cursor of another process is not readable on the hidden desktop'
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

# WSLNEW: a folder created while inactive is shown (entered) after the activation
function Run-New {
    if (-not (Want 'WSLNEW')) { return }
    $id = 0; $before = Reports
    $dir = $WslFix + '\new'
    try {
        [void][IO.Directory]::CreateDirectory($dir + '\zzz')
        $id = Start-Row $dir
        $main = Get-Main $id
        Deactivate $main
        Start-Sleep -Milliseconds 400
        [void][IO.Directory]::CreateDirectory($dir + '\aaa')
        Start-Sleep -Milliseconds 300
        Activate $main
        $m = Measure-Answers $main 1500
        Start-Sleep -Milliseconds 500   # 2 s after the activation
        Key $id 0x24; Key $id 0x28; Key $id 0x0D   # Home, Down, Enter
        Start-Sleep -Milliseconds 800
        $loc = Get-Loc $id
        $r = Serve $id 3
        $ok = ($loc -ieq ($dir + '\aaa')) -and ($m.Late -lt $LimitMs)
        Row 'WSLNEW' 'RUN' (V $ok) ("panel after Home, Down, Enter: '{0}' (expected '{1}\aaa'); late max {2:N1} ms; waits {3}; windows: {4}" -f $loc, $dir, $m.Late, $m.Waits, (Msgs $r))
        End-Row 'WSLNEW' $id $null $before; $id = 0
    }
    catch { Row 'WSLNEW' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'WSLNEW' $id $null $before } }
}

# WSLDEL: a folder deleted while inactive is left after the activation
function Run-Del {
    if (-not (Want 'WSLDEL')) { return }
    $id = 0; $before = Reports
    $dir = $WslFix + '\del'
    try {
        [void][IO.Directory]::CreateDirectory($dir + '\sub')
        [IO.File]::WriteAllText($dir + '\sub\f.txt', 'x')
        $id = Start-Row ($dir + '\sub')
        $main = Get-Main $id
        Deactivate $main
        Start-Sleep -Milliseconds 400
        [IO.Directory]::Delete($dir + '\sub', $true)
        Start-Sleep -Milliseconds 300
        Activate $main
        $m = Measure-Answers $main 1500
        $r = Serve $id 3   # answers a message about the folder, if any (records it)
        $loc = Get-Loc $id
        $ok = ($loc -ieq $dir) -or ($loc -ieq ($dir + '\'))
        Row 'WSLDEL' 'RUN' (V $ok) ("panel after the activation: '{0}' (expected '{1}'); late max {2:N1} ms (the panel's change of folder included); waits {3}; windows: {4}" -f $loc, $dir, $m.Late, $m.Waits, (Msgs $r))
        End-Row 'WSLDEL' $id $null $before; $id = 0
    }
    catch { Row 'WSLDEL' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'WSLDEL' $id $null $before } }
}

# VEARLY / VLATE (from the first review): the deferred verification that replaced Sleep(400) + the
# second listing. The folder is deleted <AtMs> after the activation: at +300 ms it is after the
# activation's refresh (~+220 ms) and before the verification (refresh + 400 ms) - the panel must
# leave it; at +1500 ms it is after the verification - the panel stays (no change notification on
# 9P), which shows that the verification and nothing else made VEARLY leave.
function Run-DelAt([string]$Case, [int]$AtMs, [bool]$ExpectLeave) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    $dir = $WslFix + '\' + $Case.ToLower()
    try {
        [void][IO.Directory]::CreateDirectory($dir + '\sub')
        [IO.File]::WriteAllText($dir + '\sub\f.txt', 'x')
        $id = Start-Row ($dir + '\sub')
        $main = Get-Main $id
        Deactivate $main
        Start-Sleep -Milliseconds 400
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Activate $main
        while ($sw.Elapsed.TotalMilliseconds -lt $AtMs) { Start-Sleep -Milliseconds 5 }
        $delAt = $sw.Elapsed.TotalMilliseconds
        [IO.Directory]::Delete($dir + '\sub', $true)
        $delEnd = $sw.Elapsed.TotalMilliseconds
        Start-Sleep -Milliseconds 2500
        $r = Serve $id 2
        $loc = Get-Loc $id
        $left = ($loc -ieq $dir) -or ($loc -ieq ($dir + '\'))
        $ok = ($left -eq $ExpectLeave)
        Row $Case 'RUN' (V $ok) ("deleted at +{0:N0}..{1:N0} ms; panel: '{2}'; left the folder {3} (expected {4}); windows: {5}" -f $delAt, $delEnd, $loc, $left, $ExpectLeave, (Msgs $r))
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc372_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $LocalDir
    for ($i = 0; $i -lt 800; $i++) { WriteFile ('{0}\f{1:D4}.txt' -f $LocalDir, $i) 'x' }
    Set-Config
    Out ("act372_probe (feature 372) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    $wslOk = Test-Path -LiteralPath $Wsl
    Out ("Date    : {0}; registry key existed {1}; WSL path {2} reachable {3}; limit {4} ms; {5} activations a timing row" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $Wsl, $wslOk, $LimitMs, $Cycles)
    Out ''
    Run-Timing 'LOCAL' $LocalDir
    if ($wslOk) {
        if ([IO.Directory]::Exists($WslFix)) { [IO.Directory]::Delete($WslFix, $true) }
        [void][IO.Directory]::CreateDirectory($WslFix)
        Run-Timing 'WSLROOT' $Wsl
        Run-Timing 'WSLBIG' ($Wsl + 'usr\bin')
        Run-New
        Run-Del
        Run-DelAt 'VEARLY' 300 $true
        Run-DelAt 'VLATE' 1500 $false
    }
    else { Row 'WSL' 'ACTIVATE' 'NOT DRIVEN' ("{0} not reachable on this machine" -f $Wsl) }
    # SHARE (US2): the local fixture through the administrative share of its drive
    if (Want 'SHARE') {
        $share = '\\localhost\' + $LocalDir.Substring(0, 1) + '$' + $LocalDir.Substring(2)
        if (Test-Path -LiteralPath $share) { Run-Timing 'SHARE' $share }
        else { Row 'SHARE' 'ACTIVATE' 'NOT DRIVEN' ("{0} not reachable (no administrative share for this user)" -f $share) }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    try { if ($WslFix -and [IO.Directory]::Exists($WslFix)) { [IO.Directory]::Delete($WslFix, $true) } } catch { Out ('WSL fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; WSL fixture removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), (-not [IO.Directory]::Exists($WslFix)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
