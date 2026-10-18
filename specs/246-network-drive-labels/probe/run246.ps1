<#
.SYNOPSIS
    Feature 246 GUI probe: names of mapped network drives in the Change Drive menu and the
    drive bar tooltip, the disconnected icon, the drive bars' rebuild, reconnection.

.DESCRIPTION
    Maps temporary network drives to folders under %TEMP%\tc246\fx through the
    administrative share \\localhost\C$ (remembered connections, WNetAddConnection2W with
    CONNECT_UPDATE_PROFILE), gives some of them a Windows name the way Explorer does
    (HKCU\...\Explorer\MountPoints2\##...\_LabelFromReg), starts tandemcommander.exe with two
    drive bars, and drives it with posted messages only.

    -Mode fixed     Debug build with the probe seam (TC_PROBE_DRIVES_DUMP, contracts/probe-seam.md):
                    exact texts, states, rebuilds and reconnections are read from the dump.
    -Mode baseline  any build without the seam (negative control): only what can be seen -
                    drive bar screenshots before/after a state change, menu screenshots.

    Rows (fixed):
      N1-N11  menu text of each fixture drive (unnamed, ASCII, Czech, Cyrillic, CJK, '&', '#',
              long, tab in name, name = path, blank name); both drive bars carry the same items
      T1      tooltip texts (hover scan over drive bar 1)
      R1      rename while running: menu and tooltip show the new name
      S1      connected -> unavailable (connection cancelled, profile kept) -> activation:
              CHECK quiet=1, REBUILD bar1+bar2, item acc=0; the bar image changed
      S2      activation without a change: no REBUILD
      S3      reconnected outside the program -> activation: REBUILD, acc=1
      S4      Ctrl+R (refresh) after a state change: REBUILD
      S5      Change Drive menu open/close after a state change: REBUILD
      P1      pick the unavailable drive in the drive bar: RESTORE with the exact remote path,
              the drive is connected again, the panel shows it
      P2      the same for the path with '&'
      M1      no message box at any time; no crash report; clean exit
    Rows (baseline):
      B-S1    the drive bar image after S1's state change + activation (expected unchanged = stale)
      B-N     menu screenshot with the fixture drives (names absent)

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs.
    Backs up and restores HKCU\Software\Tandem Commander (SHA-256 verified); removes every
    mapping, remembered connection, MountPoints2 key and folder it created and verifies the
    removal against the snapshot taken before. Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'baseline')][string]$Mode = 'fixed',
    [string]$OutFile,
    [string]$ShotDir
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\124-regedt-key-text\probe\shotocr_lib.ps1')

if (-not ('Net246' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class Net246
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public class NETRESOURCE
    {
        public int dwScope, dwType, dwDisplayType, dwUsage;
        public string lpLocalName, lpRemoteName, lpComment, lpProvider;
    }
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetAddConnection2W(NETRESOURCE nr, string pwd, string user, int flags);
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetCancelConnection2W(string name, int flags, bool force);
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetGetConnectionW(string local, StringBuilder remote, ref int len);
    [DllImport("kernel32.dll")] public static extern uint GetLogicalDrives();
    public const int CONNECT_UPDATE_PROFILE = 1;
    public static int Map(string letter, string remote, bool remember)
    {
        var nr = new NETRESOURCE(); nr.dwType = 1; nr.lpLocalName = letter; nr.lpRemoteName = remote;
        return WNetAddConnection2W(nr, null, null, remember ? CONNECT_UPDATE_PROFILE : 0);
    }
    // cancels the connection; with 'forget' FALSE the remembered entry stays (state "Unavailable")
    public static int Cancel(string letter, bool forget) { return WNetCancelConnection2W(letter, forget ? CONNECT_UPDATE_PROFILE : 0, true); }
    public static string Conn(string letter, out int res)
    {
        var sb = new StringBuilder(2048); int len = 2048; res = WNetGetConnectionW(letter, sb, ref len); return sb.ToString();
    }
    public static bool Listed(char letter) { return (GetLogicalDrives() & (1u << (char.ToUpperInvariant(letter) - 'A'))) != 0; }
}
'@
}

$Root = $TempRoot + '\tc246probe'   # the probe's own folder: emptied at the start of every run
$Fx = $Root + '\fx'
$StartDir = $Root + '\start'
if (-not $ShotDir) { $ShotDir = $Root + '\shots_' + $Mode }
$Dump = $Root + '\dump_' + $Mode + '.txt'
$RegBackup = $Root + '\reg_backup.reg'
$Script:Lines = New-Object System.Collections.ArrayList
$Script:Procs = @{}
$Fails = 0
$MP2 = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2'
$Utf8 = New-Object Text.UTF8Encoding($false)

function RowV([string]$Case, [string]$Step, [bool]$Ok, [string]$Facts) {
    $v = V $Ok; if (-not $Ok) { $script:Fails++ }
    Row $Case $Step $v $Facts
}
function UncOf([string]$LocalPath) { return '\\localhost\C$' + $LocalPath.Substring(2) }   # C:\x -> \\localhost\C$\x
function KeyOf([string]$Remote) { return '##' + $Remote.Substring(2).TrimEnd('\').Replace('\', '#') }
function Set-Name([string]$Remote, $Name) {
    $k = $MP2 + '\' + (KeyOf $Remote)
    if (-not (Test-Path -LiteralPath $k)) { [void](New-Item -Path $MP2 -Name (KeyOf $Remote) -Force) }
    if ($null -eq $Name) { Remove-ItemProperty -LiteralPath $k -Name '_LabelFromReg' -ErrorAction SilentlyContinue }
    else { Set-ItemProperty -LiteralPath $k -Name '_LabelFromReg' -Value $Name -Type String }
}

# ---- snapshot of what the probe may touch -----------------------------------
function Snap {
    $s = [ordered]@{}
    $s.NetUse = ((& net.exe use 2>&1) | Out-String)
    $s.Network = @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName }) -join ','
    $s.MP2 = @(Get-ChildItem $MP2 -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like '##*' } | ForEach-Object { $_.PSChildName } | Sort-Object) -join '|'
    $s.Drives = '{0:X8}' -f [Net246]::GetLogicalDrives()
    return $s
}

# ---- fixture ------------------------------------------------------------------
$Zcar = [string][char]0x017E
$Ru = [string]([char]0x0410) + [char]0x0440 + [char]0x0445 + [char]0x0438 + [char]0x0432   # "Arkhiv" in Cyrillic
$Cjk = [string]([char]0x6863) + [char]0x6848                                               # "dang'an" (archive)
$longDir = 'long_' + ('d' * 60) + '\' + ('e' * 60) + '\' + ('f' * 40)
$longName = 'Long name ' + ('n' * 90)
# letter, folder, name to give ($null = none), expected menu text builder kind
$Spec = @(
    @{ Case = 'N1'; Dir = 'plain'; Name = $null },
    @{ Case = 'N2'; Dir = 'named'; Name = 'Archiv' },
    @{ Case = 'N3'; Dir = 'czech'; Name = ('Archiv Test ' + $Zcar) },
    @{ Case = 'N4'; Dir = 'cyril'; Name = $Ru },
    @{ Case = 'N5'; Dir = 'cjk'; Name = $Cjk },
    @{ Case = 'N6'; Dir = 'R&D x'; Name = 'R&D' },
    @{ Case = 'N7'; Dir = 'a#b'; Name = 'Hash' },
    @{ Case = 'N8'; Dir = $longDir; Name = $longName },
    @{ Case = 'N9'; Dir = 'tab'; Name = ("  Tab`tName  ") },
    @{ Case = 'N10'; Dir = 'eqpath'; Name = '<path-upper>' },
    @{ Case = 'N11'; Dir = 'blank'; Name = '   ' },
    @{ Case = 'D'; Dir = 'dyn'; Name = 'Dyn' }
)
function Expected-Text($e, [bool]$Menu) {
    $name = $e.ShownName
    $remote = $e.Remote
    if ($null -eq $name -or $name -eq '' -or $name -ieq $remote) { $t = $remote } else { $t = $name + ' (' + $remote + ')' }
    if ($Menu) { $t = $t.Replace('&', '&&') }
    return $t
}

# ---- dump --------------------------------------------------------------------
function Dump-Lines { if (Test-Path -LiteralPath $Dump) { return @([IO.File]::ReadAllLines($Dump, $Utf8)) } else { return @() } }
function Dump-Mark { return (Dump-Lines).Count }
function Dump-Since([int]$Mark) { $l = Dump-Lines; if ($l.Count -le $Mark) { return @() }; return @($l[$Mark..($l.Count - 1)]) }
# the items of the last BUILD block in 'Lines' matching bar/copy: hashtable letter -> @{Idx;Acc;Text}
function Last-Build([string[]]$Lines, [int]$Bar, [int]$Copy) {
    $start = -1
    for ($i = $Lines.Count - 1; $i -ge 0; $i--) { if ($Lines[$i] -like ('BUILD bar=' + $Bar + ' copy=' + $Copy + ' *')) { $start = $i; break } }
    if ($start -lt 0) { return $null }
    $items = @{}
    for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
        $m = [regex]::Match($Lines[$i], '^ITEM (.) idx=(\d+) type=(\d+) acc=(\d) text=(.*)$')
        if (-not $m.Success) { break }
        $raw = $m.Groups[5].Value
        $tab = $raw.IndexOf("`t"); $text = ''; if ($tab -ge 0) { $text = $raw.Substring($tab + 1) }
        $items[$m.Groups[1].Value] = @{ Idx = [int]$m.Groups[2].Value; Type = [int]$m.Groups[3].Value; Acc = [int]$m.Groups[4].Value; Text = $text }
    }
    return @{ Header = $Lines[$start]; Items = $items }
}

# ---- program -----------------------------------------------------------------
function Start-P {
    $env:TC_PROBE_DRIVES_DUMP = $Dump
    $a = @('-t', 'T246', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    $r = Serve $p.Id 8
    if ($r.Messages.Count) { Out ('           at start: ' + (Msgs $r)) }
    return $p.Id
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000); Start-Sleep -Milliseconds 300 }
function Rebar-Kids([int]$Id) {
    $main = Get-Main $Id
    $rebar = @([Drv098f]::Kids($main) | Where-Object { [Drv098f]::Cls($_) -eq 'ReBarWindow32' }) | Select-Object -First 1
    if (-not $rebar) { return @() }
    return @([Drv098f]::Kids($rebar) | Where-Object { [Drv098f]::GetParent($_) -eq $rebar -and [Drv098f]::IsWindowVisible($_) })
}
# shows two drive bars; returns the two bar windows (left to right)
function Show-Bars([int]$Id) {
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $before = @(Rebar-Kids $Id | ForEach-Object { $_.ToInt64() })
        Post-Cmd (Get-Main $Id) 756   # CM_TOGGLEDRIVEBAR2
        Start-Sleep -Milliseconds 1200; Sync $Id
        $after = @(Rebar-Kids $Id)
        $new = @($after | Where-Object { $before -notcontains $_.ToInt64() })
        if ($new.Count -ge 2) {
            return @($new | Sort-Object { $rc = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($_, [ref]$rc); $rc.Left })
        }
    }
    throw 'two drive bars could not be shown'
}
function Bar-Shot([IntPtr]$Bar, [string]$Name) {
    $png = Join-Path $ShotDir ($Name + '.png'); [void][Shot124]::Capture($Bar, $png); return $png
}
function Same-Image([string]$A, [string]$B) {
    $ba = [IO.File]::ReadAllBytes($A); $bb = [IO.File]::ReadAllBytes($B)
    if ($ba.Length -ne $bb.Length) { return $false }
    for ($i = 0; $i -lt $ba.Length; $i++) { if ($ba[$i] -ne $bb[$i]) { return $false } }
    return $true
}
function Activate([int]$Id) {
    $main = Get-Main $Id
    [void][Drv098f]::Send($main, 0x001C, 0, 0, 20000)   # WM_ACTIVATEAPP deactivate
    [void][Drv098f]::Send($main, 0x001C, 1, 0, 20000)   # WM_ACTIVATEAPP activate -> WM_USER_END_SUSPMODE
    Start-Sleep -Milliseconds 1500; Sync $Id
}
function Wait-Menu([int]$Id, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        $m = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq 'PopupMenuClass' }) | Select-Object -First 1
        if ($m) { Start-Sleep -Milliseconds 400; return $m }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
function Menu-OpenClose([int]$Id, [string]$ShotName) {
    Post-Cmd (Get-Main $Id) 707   # CM_LCHANGEDRIVE (Alt+F1)
    $m = Wait-Menu $Id
    if ($m -eq [IntPtr]::Zero) { return $false }
    if ($ShotName) { [void][Shot124]::Capture($m, (Join-Path $ShotDir ($ShotName + '.png'))) }
    [void][Drv098f]::PostMessageW($m, 0x0100, [IntPtr]0x1B, [IntPtr]1)
    [void][Drv098f]::PostMessageW($m, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($m)) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 500; Sync $Id
    return $true
}
# moves the "mouse" over drive bar 1 from left to right (posted WM_MOUSEMOVE); the tooltip
# asks the drive list for each button it is shown for - the seam records "TIP" lines
function Hover-Scan([IntPtr]$Bar) {
    $rc = New-Object Drv098f+RECT; [void][Drv098f]::GetClientRect($Bar, [ref]$rc)
    $y = [int](($rc.Bottom - $rc.Top) / 2)
    for ($x = 3; $x -lt $rc.Right; $x += 4) {
        [void][Drv098f]::PostMessageW($Bar, 0x0200, [IntPtr]::Zero, [IntPtr](($y -shl 16) -bor $x))
        Start-Sleep -Milliseconds 120
    }
    [void][Drv098f]::PostMessageW($Bar, 0x02A3, [IntPtr]::Zero, [IntPtr]::Zero)   # WM_MOUSELEAVE
    Start-Sleep -Milliseconds 400
}
function Tips([string[]]$Lines) {
    $t = @{}
    foreach ($l in $Lines) { $m = [regex]::Match($l, '^TIP (.) (.*)$'); if ($m.Success) { $t[$m.Groups[1].Value] = $m.Groups[2].Value } }
    return $t
}

# ============================================================================
$snapBefore = Snap
Out ("246 probe, mode {0}, exe {1}" -f $Mode, $Exe)
Out ("snapshot before: drives {0}; HKCU\Network [{1}]; MountPoints2 ##* count {2}" -f $snapBefore.Drives, $snapBefore.Network, (@($snapBefore.MP2 -split '\|' | Where-Object { $_ })).Count)
$existed = $false; $regOk = $true
$Mapped = New-Object System.Collections.ArrayList
$CreatedKeys = New-Object System.Collections.ArrayList
$id = 0
try {
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
    [void](New-Item -ItemType Directory -Path $Fx, $StartDir, $ShotDir -Force)
    $existed = Backup-Reg $RegBackup
    Set-Config

    # free letters: not listed, not remembered, from Z down
    $remembered = @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName.ToUpper() })
    $free = @()
    foreach ($c in [char[]]'ZYXWVUTSRQPONMLKJIH') { if (-not [Net246]::Listed($c) -and $remembered -notcontains [string]$c) { $free += [string]$c } }
    if ($free.Count -lt $Spec.Count) { throw ('not enough free drive letters: ' + ($free -join '')) }

    $i = 0
    foreach ($e in $Spec) {
        $e.Letter = $free[$i]; $i++
        $dir = Join-Path $Fx $e.Dir
        [void](New-Item -ItemType Directory -Path $dir -Force)
        [IO.File]::WriteAllText((Join-Path $dir ('marker_' + $e.Case + '.txt')), $e.Case)
        $e.Remote = UncOf $dir
        $res = [Net246]::Map(($e.Letter + ':'), $e.Remote, $true)
        if ($res -ne 0) { throw ("mapping {0}: to {1} failed: {2}" -f $e.Letter, $e.Remote, $res) }
        [void]$Mapped.Add($e.Letter)
        $key = KeyOf $e.Remote
        if (-not (($snapBefore.MP2 -split '\|') -contains $key)) { [void]$CreatedKeys.Add($key) }
        $name = $e.Name
        if ($name -eq '<path-upper>') { $name = $e.Remote.ToUpper() }
        if ($null -ne $name) { Set-Name $e.Remote $name }
        # what the program should show: cleaned as salnetdrive.h does
        if ($null -eq $name) { $e.ShownName = $null } else { $e.ShownName = ($name -replace '[\x00-\x1F\x7F]', ' ').Trim(' ') }
        Out ("  fixture {0}: {1}: -> {2}; name {3}" -f $e.Case, $e.Letter, (Tail $e.Remote 60), $(if ($null -eq $name) { '<none>' } else { "'" + (Esc $name) + "'" }))
    }
    $D = $Spec | Where-Object { $_.Case -eq 'D' }
    $Amp = $Spec | Where-Object { $_.Case -eq 'N6' }
    $Named = $Spec | Where-Object { $_.Case -eq 'N2' }

    $before = Reports
    $id = Start-P
    $bars = Show-Bars $id
    Out ("  drive bars: {0}" -f (($bars | ForEach-Object { '0x{0:X}' -f $_.ToInt64() }) -join ', '))

    if ($Mode -eq 'fixed') {
        # ---- N rows: menu texts ---------------------------------------------
        $mark = Dump-Mark
        $opened = Menu-OpenClose $id 'menu_names'
        $dl = Dump-Since $mark
        $menu = Last-Build $dl 0 0
        $all = Dump-Lines
        $bar1 = Last-Build $all 1 0
        $bar2 = Last-Build $all 1 1
        RowV 'N0' 'MENU' ($opened -and $null -ne $menu) ("menu opened {0}; build {1}" -f $opened, $(if ($menu) { $menu.Header } else { '<none>' }))
        foreach ($e in ($Spec | Where-Object { $_.Case -like 'N*' })) {
            $exp = Expected-Text $e $true
            $got = $null; $acc = -1
            if ($menu -and $menu.Items.ContainsKey($e.Letter)) { $got = $menu.Items[$e.Letter].Text; $acc = $menu.Items[$e.Letter].Acc }
            $b1 = $bar1 -and $bar1.Items.ContainsKey($e.Letter) -and $bar1.Items[$e.Letter].Text -ceq $exp
            $b2 = $bar2 -and $bar2.Items.ContainsKey($e.Letter) -and $bar2.Items[$e.Letter].Text -ceq $exp
            RowV $e.Case 'TEXT' (($got -ceq $exp) -and $acc -eq 1 -and $b1 -and $b2) ("{0}: menu '{1}' acc={2}; expected '{3}'; bar1 {4} bar2 {5}" -f $e.Letter, (Tail $got 90), $acc, (Tail $exp 90), $b1, $b2)
        }
        # local drives untouched (spot check: C)
        $c = $null; if ($menu -and $menu.Items.ContainsKey('C')) { $c = $menu.Items['C'] }
        RowV 'N12' 'LOCAL' ($null -ne $c -and $c.Type -eq 3 -and $c.Acc -eq 1) ("C: type {0} text '{1}'" -f $(if ($c) { $c.Type } else { '-' }), $(if ($c) { Esc $c.Text } else { '<none>' }))

        # ---- T1: tooltips ----------------------------------------------------
        # the hover cannot be driven here (the tooltip follows GetCursorPos / WindowFromPoint,
        # which see the real cursor on the input desktop); the seam calls the bar's tooltip
        # function for every network drive at each bar check - activation without a change
        $mark = Dump-Mark
        Activate $id
        $dl = Dump-Since $mark
        $tips = Tips $dl
        Row 'T1' 'HOVER' 'NOT DRIVEN' 'hovering a drive bar button needs the real cursor (step owed to a person)'
        foreach ($e in ($Spec | Where-Object { $_.Case -like 'N*' })) {
            $exp = Expected-Text $e $false
            $got = $null; if ($tips.ContainsKey($e.Letter)) { $got = $tips[$e.Letter] }
            RowV ('T1-' + $e.Case) 'TIP' ($got -ceq $exp) ("{0}: tip '{1}'; expected '{2}'" -f $e.Letter, (Tail $got 90), (Tail $exp 90))
        }

        # ---- R1: rename while running ---------------------------------------
        $newName = 'Archiv 2 ' + $Zcar
        Set-Name $Named.Remote $newName
        $Named.ShownName = $newName
        $mark = Dump-Mark
        [void](Menu-OpenClose $id '')
        $dl = Dump-Since $mark
        $menu = Last-Build $dl 0 0
        $got = $null; if ($menu -and $menu.Items.ContainsKey($Named.Letter)) { $got = $menu.Items[$Named.Letter].Text }
        RowV 'R1' 'MENU' ($got -ceq (Expected-Text $Named $true)) ("{0}: '{1}'" -f $Named.Letter, (Esc $got))
        # the bar is not rebuilt by a rename (no mask changed): its tooltip still shows the new name
        $tips = Tips $dl
        $got = $null; if ($tips.ContainsKey($Named.Letter)) { $got = $tips[$Named.Letter] }
        $noRebuild = @($dl | Where-Object { $_ -like 'REBUILD*' }).Count -eq 0
        RowV 'R1' 'TIP' (($got -ceq (Expected-Text $Named $false)) -and $noRebuild) ("{0}: tip '{1}'; bar rebuilt: {2}" -f $Named.Letter, (Esc $got), (-not $noRebuild))
    }
    else {
        [void](Menu-OpenClose $id 'menu_names')
        Row 'B-N' 'MENU' 'INFO' ("menu screenshot: " + (Join-Path $ShotDir 'menu_names.png'))
    }

    # ---- S1: connected -> unavailable -> activation ----------------------------
    $shotA = Bar-Shot $bars[0] 'bar1_connected'
    $shotA2 = Bar-Shot $bars[1] 'bar2_connected'
    $cr = [Net246]::Cancel(($D.Letter + ':'), $false)
    $res = 0; [void][Net246]::Conn(($D.Letter + ':'), [ref]$res)
    Out ("  {0}: cancelled (profile kept): {1}; listed {2}; WNetGetConnection {3}" -f $D.Letter, $cr, [Net246]::Listed($D.Letter[0]), $res)
    $mark = Dump-Mark
    Activate $id
    $dl = Dump-Since $mark
    $shotB = Bar-Shot $bars[0] 'bar1_after_unavailable'
    $shotB2 = Bar-Shot $bars[1] 'bar2_after_unavailable'
    $changed1 = -not (Same-Image $shotA $shotB); $changed2 = -not (Same-Image $shotA2 $shotB2)
    if ($Mode -eq 'fixed') {
        $check = @($dl | Where-Object { $_ -like 'CHECK quiet=1 *' })
        $rb1 = @($dl | Where-Object { $_ -eq 'REBUILD bar1' }).Count; $rb2 = @($dl | Where-Object { $_ -eq 'REBUILD bar2' }).Count
        $b1 = Last-Build $dl 1 0; $b2 = Last-Build $dl 1 1
        $acc1 = if ($b1 -and $b1.Items.ContainsKey($D.Letter)) { $b1.Items[$D.Letter].Acc } else { -1 }
        $acc2 = if ($b2 -and $b2.Items.ContainsKey($D.Letter)) { $b2.Items[$D.Letter].Acc } else { -1 }
        RowV 'S1' 'STATE' ($check.Count -ge 1 -and $rb1 -ge 1 -and $rb2 -ge 1 -and $acc1 -eq 0 -and $acc2 -eq 0 -and $changed1 -and $changed2) ("{0}; REBUILD bar1 x{1} bar2 x{2}; acc bar1 {3} bar2 {4}; bar images changed {5}/{6}" -f ($check -join ' / '), $rb1, $rb2, $acc1, $acc2, $changed1, $changed2)
        $mark = Dump-Mark
        [void](Menu-OpenClose $id 'menu_unavailable')
        $menu = Last-Build (Dump-Since $mark) 0 0
        $acc = if ($menu -and $menu.Items.ContainsKey($D.Letter)) { $menu.Items[$D.Letter].Acc } else { -1 }
        $txt = if ($menu -and $menu.Items.ContainsKey($D.Letter)) { $menu.Items[$D.Letter].Text } else { $null }
        RowV 'S1' 'MENU' ($acc -eq 0 -and $txt -ceq (Expected-Text $D $true)) ("{0}: acc {1}; text '{2}' (the name stays while unavailable)" -f $D.Letter, $acc, (Esc $txt))

        # ---- S2: activation without a change ----------------------------------
        $mark = Dump-Mark
        Activate $id
        $dl = Dump-Since $mark
        $rb = @($dl | Where-Object { $_ -like 'REBUILD*' }).Count
        RowV 'S2' 'NOCHANGE' (@($dl | Where-Object { $_ -like 'CHECK quiet=1 *' }).Count -ge 1 -and $rb -eq 0) ("lines: {0}" -f (($dl | Select-Object -First 4) -join ' / '))

        # ---- S3: reconnected outside -> activation ------------------------------
        $mr = [Net246]::Map(($D.Letter + ':'), $D.Remote, $true)
        $mark = Dump-Mark
        Activate $id
        $dl = Dump-Since $mark
        $b1 = Last-Build $dl 1 0
        $acc1 = if ($b1 -and $b1.Items.ContainsKey($D.Letter)) { $b1.Items[$D.Letter].Acc } else { -1 }
        RowV 'S3' 'STATE' ($mr -eq 0 -and @($dl | Where-Object { $_ -eq 'REBUILD bar1' }).Count -ge 1 -and $acc1 -eq 1) ("map {0}; acc bar1 {1}; {2}" -f $mr, $acc1, (($dl | Where-Object { $_ -like 'CHECK*' -or $_ -like 'REBUILD*' }) -join ' / '))
        $shotC = Bar-Shot $bars[0] 'bar1_reconnected'
        RowV 'S3' 'IMAGE' (Same-Image $shotA $shotC) 'drive bar 1 looks as before the disconnection'

        # ---- S4: refresh after a state change -----------------------------------
        [void][Net246]::Cancel(($D.Letter + ':'), $false)
        $mark = Dump-Mark
        Post-Cmd (Get-Main $id) 740   # CM_ACTIVEREFRESH (Ctrl+R)
        Start-Sleep -Milliseconds 1500; Sync $id
        $dl = Dump-Since $mark
        RowV 'S4' 'REFRESH' (@($dl | Where-Object { $_ -like 'CHECK quiet=0 *' }).Count -ge 1 -and @($dl | Where-Object { $_ -eq 'REBUILD bar1' }).Count -ge 1) (($dl | Where-Object { $_ -like 'CHECK*' -or $_ -like 'REBUILD*' }) -join ' / ')

        # ---- S5: menu open/close after a state change ---------------------------
        [void][Net246]::Map(($D.Letter + ':'), $D.Remote, $true)
        $mark = Dump-Mark
        [void](Menu-OpenClose $id '')
        $dl = Dump-Since $mark
        RowV 'S5' 'MENU' (@($dl | Where-Object { $_ -eq 'REBUILD bar1' }).Count -ge 1) (($dl | Where-Object { $_ -like 'CHECK*' -or $_ -like 'REBUILD*' }) -join ' / ')

        # ---- P1 / P2: pick an unavailable drive in drive bar 1 --------------------
        foreach ($pe in @(@{ Case = 'P1'; E = $D }, @{ Case = 'P2'; E = $Amp })) {
            $e = $pe.E
            [void][Net246]::Cancel(($e.Letter + ':'), $false)
            Activate $id
            $b1 = Last-Build (Dump-Lines) 1 0
            if (-not ($b1 -and $b1.Items.ContainsKey($e.Letter))) { RowV $pe.Case 'PICK' $false 'drive not on bar 1'; continue }
            $item = $b1.Items[$e.Letter]
            $mark = Dump-Mark
            Post-Cmd (Get-Main $id) (3500 + $item.Idx)   # CM_DRIVEBAR_MIN + index
            $r = Serve $id 20
            Sync $id
            $dl = Dump-Since $mark
            $restore = @($dl | Where-Object { $_ -like ('RESTORE ' + $e.Letter + ' *') })
            $exact = $restore.Count -ge 1 -and $restore[0].Substring(10) -ceq $e.Remote
            $listed = [Net246]::Listed($e.Letter[0])
            $loc = Get-Loc $id
            $okLoc = $loc -like ($e.Letter + ':\*')
            RowV $pe.Case 'PICK' ($item.Acc -eq 0 -and $exact -and $listed -and $okLoc -and $r.Messages.Count -eq 0) ("{0}: acc before {1}; {2}; listed after {3}; panel '{4}'; windows: {5}" -f $e.Letter, $item.Acc, ($restore -join ' / '), $listed, (Esc $loc), (Msgs $r))
        }
    }
    else {
        Row 'B-S1' 'STATE' 'INFO' ("bar 1 image changed after unavailable + activation: {0}; bar 2: {1} (fixed build: both change)" -f $changed1, $changed2)
        # the menu itself is rebuilt at opening: screenshot for the record
        [void](Menu-OpenClose $id 'menu_unavailable')
        $shotM = Bar-Shot $bars[0] 'bar1_after_menu'
        Row 'B-S5' 'STATE' 'INFO' ("bar 1 image changed after the Change Drive menu open/close: {0}" -f (-not (Same-Image $shotA $shotM)))
        [void]$Mapped.Count
    }

    # ---- M1 ---------------------------------------------------------------------
    $r = Serve $id 5
    $fatal = Fatal-Win $id
    Stop-Tc $id
    $ec = ExitCodeOf $id
    $rep = Take-Reports $before
    RowV 'M1' 'CLEAN' ($r.Messages.Count -eq 0 -and $null -eq $fatal -and $rep.Count -eq 0) ("windows: {0}; fatal: {1}; exit {2}; reports {3}" -f (Msgs $r), $fatal, $ec, $rep.Count)
}
catch {
    $script:Fails++
    Out ('PROBE ERROR: ' + $_.Exception.Message + ' at ' + $_.InvocationInfo.PositionMessage)
}
finally {
    foreach ($p in $Started) { if (Test-Alive $p) { Kill-Mine $p } }
    Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
    foreach ($l in $Mapped) { [void][Net246]::Cancel(($l + ':'), $true) }
    foreach ($k in $CreatedKeys) { Remove-Item -LiteralPath ($MP2 + '\' + $k) -Recurse -Force -ErrorAction SilentlyContinue }
    # a name the probe set on a key that existed before is not possible: fixture paths are new
    $regOk = Restore-Reg $RegBackup $existed
    try { Remove-Item -LiteralPath $Fx -Recurse -Force } catch { Out ('cleanup: fixture folder not removed: ' + $_.Exception.Message) }
    $snapAfter = Snap
    $same = ($snapAfter.Network -eq $snapBefore.Network) -and ($snapAfter.MP2 -eq $snapBefore.MP2) -and ($snapAfter.Drives -eq $snapBefore.Drives)
    if (-not $same) { $script:Fails++ }
    Out ("cleanup verified: {0} (drives {1}->{2}; HKCU\Network [{3}]->[{4}]; MountPoints2 equal {5}); registry restored: {6}" -f $same, $snapBefore.Drives, $snapAfter.Drives, $snapBefore.Network, $snapAfter.Network, ($snapAfter.MP2 -eq $snapBefore.MP2), $regOk)
    Out ("RESULT: {0} FAIL row(s)" -f $Fails)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$Script:Lines, $Utf8) }
}
exit $Fails
