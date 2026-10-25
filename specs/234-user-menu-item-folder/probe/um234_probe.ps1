<#
.SYNOPSIS
    Feature 234 probe: a User Menu command without an Initial Directory runs in the folder of the
    item it was given - also from the Find window (which set no current folder: the command ran in
    the program's resting folder, or in a panel's folder another thread had just set).

.DESCRIPTION
    Fixture: <root>\found\a.txt ("REAL") - found by Find Files; the panel shows <root>\start, which holds
    another a.txt ("DECOY"). User Menu items copy "$(Name)" (a relative name) to <root>\out\<row>.txt:
      FINDABS     $(FullName) (an absolute name) from the Find window - the control that the route runs
      FINDREL     through a batch file (Execute Through Shell), run from the Find window's result
      FINDDIRECT  without a shell (cmd /c copy ... started directly), from the Find window
      PANELREL    through a batch file, from the panel (start\a.txt focused): the control
    PASS = the copy holds the found (or, PANELREL, the panel's) file's content.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc234'
$StartDir = $Root + '\start'
$Found = $Root + '\found'
$OutDir = $Root + '\out'
$script:FindDriven = $false
$UmKey = 'Software\Tandem Commander\Settings\User Menu'
$NoCurDir = $env:NoDefaultCurrentDirectoryInExePath
Remove-Item Env:NoDefaultCurrentDirectoryInExePath -ErrorAction SilentlyContinue

# row -> command, arguments, through a shell
$Cases = [ordered]@{
    'FINDABS'    = @('copy', '/y "$(FullName)" "{OUT}"', 1)
    'FINDREL'    = @('copy', '/y "$(Name)" "{OUT}"', 1)
    'FINDDIRECT' = @('cmd.exe', '/c copy /y "$(Name)" "{OUT}"', 0)
    'PANELREL'   = @('copy', '/y "$(Name)" "{OUT}"', 1)
}
function Seed-UserMenu {
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($UmKey, $false)
    $i = 0
    foreach ($c in $Cases.Keys) {
        $i++
        $v = $Cases[$c]
        $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($UmKey + '\' + $i)
        $k.SetValue('Item Name', ('tc234 ' + $c), 'String'); $k.SetValue('Command', $v[0], 'String')
        $k.SetValue('Arguments', $v[1].Replace('{OUT}', $OutDir + '\' + $c + '.txt'), 'String'); $k.SetValue('Initial Directory', '', 'String')
        $k.SetValue('Execute Through Shell', $v[2], 'DWord'); $k.SetValue('Close Shell Window', 1, 'DWord'); $k.SetValue('Open Shell Window', 0, 'DWord')
        $k.SetValue('Icon', '', 'String'); $k.SetValue('Type', 0, 'DWord'); $k.SetValue('Show In Toolbar', 0, 'DWord')
        $k.Close()
    }
}
function Wait-Out([int]$Id, [string]$Out, [double]$Seconds = 12) {
    $sw = [Diagnostics.Stopwatch]::StartNew(); $msgs = New-Object System.Collections.ArrayList
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and -not [IO.File]::Exists($LP + $Out)) { Start-Sleep -Milliseconds 250 }
    Start-Sleep -Milliseconds 500
    if ([IO.File]::Exists($LP + $Out)) { return [IO.File]::ReadAllText($LP + $Out) }
    return $null
}

function Run-Find([string]$Case, [int]$Index) {
    if (-not (Want $Case)) { return }
    $out = $OutDir + '\' + $Case + '.txt'
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $StartDir
        [void](Serve $id 10)
        $find = Open-ByCmd $id 741 10
        if ($find -eq [IntPtr]::Zero) { Row $Case 'RUN' 'NOT DRIVEN' 'Find (741) opened no window'; return }
        [void][Drv098f]::SetText((Find-Ctl $find 2505), 'a.txt', 5000)
        [void][Drv098f]::SetText((Find-Ctl $find 2501), $Found, 5000)
        Post-Cmd $find 1   # Find Now
        Start-Sleep -Milliseconds 3000
        $lv = @([Drv098f]::Kids($find) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
        if (-not $lv) { Row $Case 'RUN' 'NOT DRIVEN' 'no result list in the Find window'; return }
        $n = [Drv098f]::Send($lv, 0x1004, 0, 0, 5000)   # LVM_GETITEMCOUNT
        [void][Drv098f]::Send($lv, 0x0007, 0, 0, 5000)  # WM_SETFOCUS
        [void][Drv098f]::Send($lv, 0x0100, 0x24, 1, 5000); [void][Drv098f]::Send($lv, 0x0101, 0x24, 0xC0000001, 5000)   # Home: the first result selected
        Start-Sleep -Milliseconds 500
        # the Find window's User Menu is a popup (CM_FIND_USERMENU 2224, a menu loop that reads the
        # thread's queue): Down to the item, Enter
        Post-Cmd $find 2224; Start-Sleep -Milliseconds 1200
        for ($k = 0; $k -le $Index; $k++) { [void][Drv098f]::PostMessageW($find, 0x0100, [IntPtr]0x28, [IntPtr]1); Start-Sleep -Milliseconds 250 }
        [void][Drv098f]::PostMessageW($find, 0x0100, [IntPtr]0x0D, [IntPtr]1)
        $got = Wait-Out $id $out
        $ok = ($got -ceq 'REAL')
        Close-Win $find; [void](Serve $id 5)
        if ($Case -eq 'FINDABS') { $script:FindDriven = $ok }
        if (-not $script:FindDriven) { Row $Case 'RUN' 'NOT DRIVEN' ("the Find window's User Menu (a popup menu) did not run the control item - copy {0}" -f $(if ($null -eq $got) { 'missing' } else { "'" + $got + "'" })); return }
        Row $Case 'RUN' (V $ok) ("copy {0}" -f $(if ($null -eq $got) { 'missing' } else { "'" + $got + "'" }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}
function Run-Panel([string]$Case, [int]$Index) {
    if (-not (Want $Case)) { return }
    $out = $OutDir + '\' + $Case + '.txt'
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $StartDir
        [void](Serve $id 10)
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) (3000 + $Index)
        $got = Wait-Out $id $out
        $ok = ($got -ceq 'DECOY')   # the panel's own a.txt
        Row $Case 'RUN' (V $ok) ("copy {0}" -f $(if ($null -eq $got) { 'missing' } else { "'" + $got + "'" }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc234_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Found; NewDir $OutDir
    [IO.File]::WriteAllText($LP + $Found + '\a.txt', 'REAL'); [IO.File]::WriteAllText($LP + $StartDir + '\a.txt', 'DECOY')
    Set-Config
    Seed-UserMenu
    Out ("um234_probe (feature 234) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; NoDefaultCurrentDirectoryInExePath was '{3}' (removed for the run)" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), $NoCurDir)
    Out ''
    Run-Find 'FINDABS' 0
    Run-Find 'FINDREL' 1
    Run-Find 'FINDDIRECT' 2
    Run-Panel 'PANELREL' 3
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
