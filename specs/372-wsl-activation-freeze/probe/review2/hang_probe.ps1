<#
  Review 2 of feature 372: a hung background check (simulated by a one-shot 15 s Sleep in the
  worker of a hooked build, armed by creating the marker file hang.on) must not swallow later
  activations. Runs only through tools\run_on_hidden_desktop.ps1. Registry backed up + restored.
  H1  the check of folder A hangs; the panel moves to the parent P; while inactive P\aaa is
      created; activation; at +2 s Home, Down, Enter -> expected P\aaa (the activation refreshed P)
  H2  the check of folder A hangs; 11 s later (past SAL_BKCHK_ABANDON_MS) while inactive A\aaa is
      created; activation; at +2 s Home, Down, Enter -> expected A\aaa
  H3  H2 continued: wait until the hung worker's stale result arrives (+15 s), then the program is
      alive, answers, no bug report
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$Distro = 'Ubuntu'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
$Lib = 'E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1'
. $Lib
$Marker = 'C:\Users\pavel\AppData\Local\Temp\rev372b\hang.on'
$Root = $TempRoot + '\tc372hang'
$StartDir = $Root + '\start'
$Wsl = '\\wsl.localhost\' + $Distro + '\'
$WslFix = $Wsl + 'tmp\tc372hang'

function Start-Row([string]$Left) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T372H', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 3000
    [void](Serve $p.Id 3)
    return $p.Id
}
function Deactivate([IntPtr]$Main) { [void][Drv098f]::PostMessageW($Main, 0x001C, [IntPtr]0, [IntPtr]::Zero) }
function Activate([IntPtr]$Main) { [void][Drv098f]::PostMessageW($Main, 0x001C, [IntPtr]1, [IntPtr]::Zero) }
function Arm { [IO.File]::WriteAllText($Marker, 'x') }
function HangCycle([IntPtr]$main) {   # an activation whose background check hangs 15 s
    Arm
    Deactivate $main; Start-Sleep -Milliseconds 400; Activate $main
    Start-Sleep -Milliseconds 700
    return (-not (Test-Path -LiteralPath $Marker))   # the worker consumed the marker
}

function Run-H1 {
    $id = 0; $before = Reports
    $a = $WslFix + '\h1\adir'; $p = $WslFix + '\h1'
    try {
        [void][IO.Directory]::CreateDirectory($a + '\x')
        $id = Start-Row $a
        $main = Get-Main $id
        $hung = HangCycle $main
        Key $id 0x08   # Backspace: to the parent
        Start-Sleep -Milliseconds 600
        $loc1 = Get-Loc $id
        Deactivate $main; Start-Sleep -Milliseconds 400
        [void][IO.Directory]::CreateDirectory($p + '\aaa')
        Start-Sleep -Milliseconds 300
        Activate $main
        Start-Sleep -Milliseconds 2000
        Key $id 0x24; Key $id 0x28; Key $id 0x0D
        Start-Sleep -Milliseconds 800
        $loc = Get-Loc $id
        $r = Serve $id 2
        $ok = $hung -and ($loc -ieq ($p + '\aaa'))
        Row 'H1' 'RUN' (V $ok) ("hung check started {0}; after Backspace '{1}'; after the activation Home, Down, Enter: '{2}' (expected '{3}\aaa'); windows: {4}" -f $hung, $loc1, $loc, $p, (Msgs $r))
        Start-Sleep -Milliseconds 12000   # the stale result of the hung worker arrives
        $r = Serve $id 2
        Row 'H1' 'STALE' (V (Test-Alive $id)) ("alive after the hung worker's late result: {0}; windows: {1}" -f (Test-Alive $id), (Msgs $r))
        End-Row 'H1' $id $null $before; $id = 0
    }
    catch { Row 'H1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'H1' $id $null $before } }
}

function Run-H2 {
    $id = 0; $before = Reports
    $a = $WslFix + '\h2\adir'
    try {
        [void][IO.Directory]::CreateDirectory($a + '\zzz')
        $id = Start-Row $a
        $main = Get-Main $id
        $hung = HangCycle $main
        Start-Sleep -Milliseconds 10500   # the running check is now older than 10 s
        Deactivate $main; Start-Sleep -Milliseconds 400
        [void][IO.Directory]::CreateDirectory($a + '\aaa')
        Start-Sleep -Milliseconds 300
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Activate $main
        Start-Sleep -Milliseconds 1500
        Key $id 0x24; Key $id 0x28; Key $id 0x0D
        Start-Sleep -Milliseconds 300
        $at = $sw.Elapsed.TotalMilliseconds
        $loc = Get-Loc $id
        $r = Serve $id 2
        $ok = $hung -and ($loc -ieq ($a + '\aaa'))
        Row 'H2' 'RUN' (V $ok) ("hung check started {0}; after the activation (+{1:N0} ms, the hung worker answers at ~+3500 ms) Home, Down, Enter: '{2}' (expected '{3}\aaa'); windows: {4}" -f $hung, $at, $loc, $a, (Msgs $r))
        Start-Sleep -Milliseconds 6000
        $r = Serve $id 2
        Row 'H3' 'STALE' (V (Test-Alive $id)) ("alive after the abandoned worker's late result: {0}; windows: {1}" -f (Test-Alive $id), (Msgs $r))
        End-Row 'H2' $id $null $before; $id = 0
    }
    catch { Row 'H2' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'H2' $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc372h_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("hang_probe (review 2 of 372) {0}; program {1}" -f $Label, $Exe)
    if ([IO.Directory]::Exists($WslFix)) { [IO.Directory]::Delete($WslFix, $true) }
    [void][IO.Directory]::CreateDirectory($WslFix)
    Run-H1
    Run-H2
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    if (Test-Path -LiteralPath $Marker) { Remove-Item -LiteralPath $Marker -Force }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    try { if ([IO.Directory]::Exists($WslFix)) { [IO.Directory]::Delete($WslFix, $true) } } catch { Out ('WSL fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ("Rows: PASS {0}, FAIL {1}; registry restored+identical: {2}" -f $np, $nf, $restored)
}
exit $nf
