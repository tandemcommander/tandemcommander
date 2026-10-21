<#
.SYNOPSIS
    Backlog item share-root-parent-offers-share-list: what the parent of a share's root does
    without a Network plug-in - `..`, Backspace, Go to root in \\server\share.

.DESCRIPTION
    Rows (names for -Only); every row starts its own instance in English and ends it:

      B1  at \\localhost\C$ : Backspace            G1  at \\localhost\C$ : Go to root (823)
      P1  at \\localhost\C$ : the Parent directory command (822)
      N1  at \\localhost\C$ : Backspace, the list holds no folder share (IPC$, a printer)
      D1  at \\localhost\C$ : Home, Enter (the first item: `..` when it is listed)
      O1  at \\localhost\C$ : Home, open the focused item in the other panel and activate it (2941)
      X1  at \\localhost\C$ : Backspace, Esc in the share list
      E1  at \\localhost\C$ : Backspace, the server refuses the list (seam error 53)
      S1  at \\localhost\C$\Windows : Backspace (a folder inside a share - regression control)
      S2  at \\localhost\C$\Windows : Go to root (regression control)
      L1  at C:\ : Backspace (a drive root - regression control)

    The share list comes from the Debug-only seam of feature 125 (TC_PROBE_UNC_SHARES,
    specs/125-unc-server-shares/contracts/probe-seam.md): C$ and D$ (both hidden shares of this
    computer). The chosen share is opened by the ordinary path change against the real
    \\localhost.

    With -Expect measure (default) the rows are INFO - the probe only records. With -Expect fixed:
      N1           one box naming \\localhost\ with "share name is missing"; location \\localhost\C$
      B1, P1, G1, D1  the share list opens; Down, Down, Enter -> location \\localhost\D$, no window
      O1           the share list opens in the other panel; Down, Down, Enter -> the other
                   panel's location \\localhost\D$; the first panel stays at \\localhost\C$
      X1           Esc -> location \\localhost\C$, no window
      E1           one error box naming \\localhost\ and (53); location \\localhost\C$
      S1           location \\localhost\C$, no list, no window
      S2           location \\localhost\C$, no list, no window
      L1           location C:\, no list, no window

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.PARAMETER Exe   tandemcommander.exe under test (a Debug build: the seam)
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

$Root = $TempRoot + '\tcshareroot'
$StartDir = $Root + '\start'
$Fixed = ($Expect -eq 'fixed')
$MenuClass = 'PopupMenuClass'
$Share0 = '\\localhost\C$'
$Picked = '\\localhost\D$'
$SeamList = 'C$*2147483648|D$*2147483648|IPC$*2147483651'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function V2([bool]$ok) { if (-not $Fixed) { return 'INFO' }; return (V $ok) }
function Set-Seam([string]$Shares, [string]$Err) { $env:TC_PROBE_UNC_SHARES = $Shares; $env:TC_PROBE_UNC_DELAY = ''; $env:TC_PROBE_UNC_ERROR = $Err }
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
# the location of a panel: its Change Directory field as the dialog opens (862 active, 863 left, 864 right)
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

# one row: open $Where, run the action, see whether the share list opens; pick the second item
# (Down, Down, Enter) or press $MenuAnswer; then read the location(s)
function Row-Act([string]$Case, [string]$Where, [string]$What, [scriptblock]$Act, [string]$Kind, [string]$Err = '', [string]$List = $SeamList) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        Set-Seam $List $Err
        $id = Start-P
        Go-Start $id $Where
        & $Act $id
        $menu = Wait-Menu $id 15
        $hadMenu = ($menu -ne [IntPtr]::Zero)
        if ($hadMenu) {
            if ($Kind -eq 'esc') { Menu-Key $menu 0x1B }
            else { Menu-Key $menu 0x28; Menu-Key $menu 0x28; Menu-Key $menu 0x0D }
        }
        $r = Serve $id 60
        $fatal = $r.Fatal
        Sync $id; Start-Sleep -Milliseconds 1500
        $loc = Get-LocOf $id 862
        $locL = Get-LocOf $id 863
        $locR = Get-LocOf $id 864
        $facts = ("at '{0}': {1}; share list opened: {2}; windows: {3}; location '{4}'; left panel '{5}'; right panel '{6}'" -f (Esc $Where), $What, $hadMenu, (Msgs $r), (Esc $loc), (Esc $locL), (Esc $locR))
        $ok = -not $fatal
        switch ($Kind) {
            'pick'  { $ok = $ok -and $hadMenu -and $r.Messages.Count -eq 0 -and $loc -ieq $Picked }
            'other' { $ok = $ok -and $hadMenu -and $r.Messages.Count -eq 0 -and $locL -ieq $Where -and $locR -ieq $Picked -and $loc -ieq $Picked }   # the right panel is the active one now
            'esc'   { $ok = $ok -and $hadMenu -and $r.Messages.Count -eq 0 -and $loc -ieq $Where }
            'error' {
                $box = @($r.Messages)
                $ok = $ok -and (-not $hadMenu) -and $box.Count -eq 1 -and ($box[0] -match [regex]::Escape('\\localhost\')) -and ($box[0] -match '\(53\)') -and $loc -ieq $Where
            }
            'nofolder' {
                $box = @($r.Messages)
                $ok = $ok -and (-not $hadMenu) -and $box.Count -eq 1 -and ($box[0] -match [regex]::Escape('\\localhost\')) -and ($box[0] -match 'share name is missing') -and $loc -ieq $Where
            }
            'stay'  { $ok = $ok -and (-not $hadMenu) -and $r.Messages.Count -eq 0 -and $loc -ieq $script:ExpectLoc }
        }
        Row $Case 'ACT' (V2 $ok) $facts
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' ''; if ($id) { End-Row $Case $id $fatal $before } }
}

$Backspace = { param($id) Key-Post $id 0x08 }
$GoRoot = { param($id) Post-Cmd (Get-Main $id) 823 }
$ParentCmd = { param($id) Post-Cmd (Get-Main $id) 822 }
$HomeEnter = { param($id) Key $id 0x24; Start-Sleep -Milliseconds 300; Key-Post $id 0x0D }
$HomeOther = { param($id) Key $id 0x24; Start-Sleep -Milliseconds 300; Post-Cmd (Get-Main $id) 2941 }

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tcshareroot_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    Set-Config
    Out ("shareroot_probe (backlog item share-root-parent-offers-share-list), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; computer {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), $env:COMPUTERNAME, $existed, $regHash)
    Out ("Plug-in : plugins\nethood\nethood.spl present next to the program: {0}; seam list: {1}" -f (Test-Path -LiteralPath (Join-Path (Split-Path $Exe) 'plugins\nethood\nethood.spl')), $SeamList)
    Out ''
    Row-Act 'B1' $Share0 'Backspace' $Backspace 'pick'
    Row-Act 'P1' $Share0 'Parent directory command (822)' $ParentCmd 'pick'
    Row-Act 'G1' $Share0 'Go to root (823)' $GoRoot 'pick'
    Row-Act 'D1' $Share0 'Home, Enter' $HomeEnter 'pick'
    Row-Act 'O1' $Share0 'Home, open in the other panel + activate (2941)' $HomeOther 'other'
    Row-Act 'X1' $Share0 'Backspace, Esc in the list' $Backspace 'esc'
    Row-Act 'E1' $Share0 'Backspace, seam error 53' $Backspace 'error' '53'
    Row-Act 'N1' $Share0 'Backspace, no folder share in the list' $Backspace 'nofolder' '' 'IPC$*2147483651|HP LaserJet*1'
    $script:ExpectLoc = $Share0
    Row-Act 'S1' ($Share0 + '\Windows') 'Backspace' $Backspace 'stay'
    Row-Act 'S2' ($Share0 + '\Windows') 'Go to root (823)' $GoRoot 'stay'
    $script:ExpectLoc = 'C:\'
    Row-Act 'L1' 'C:\' 'Backspace' $Backspace 'stay'
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
