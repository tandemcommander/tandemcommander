<#
.SYNOPSIS
    Feature 417 probe: the plug-in icons follow the icon set - Fluent 2 draws the set's plug-in icons,
    Classic stays pixel-identical to the build of main.

.DESCRIPTION
    Each run starts the program with the Plugins bar shown ("Show Plugins Bar" = 1), a prepared "Toolbar Icon
    Set" (0 Fluent 2 / 1 Classic) and "Theme Mode" (0 / 1), the left panel on a plug-in file system (Windows
    Registry, "reg:\") and the right one in a fixture folder, and captures (PrintWindow, client only) the
    Plugins bar and the drive bar (rows of the top rebar), the left directory line's icon, the left tab's icon
    (review 1) and the list of the Plugins manager (Plugins > Plugins Manager, CM_PLUGINS). Rows:
      CLASSIC-EQ-<theme>  -Before (the build of main) vs this build, Classic: Plugins bar, drive bar, the RegEdit
                          directory line and tab and the Plugins-manager list - 0 px each
      FLUENT-<theme>      every Plugins-bar icon cell differs from Classic and is drawn (>= 8 colours); the drive
                          bar's six plug-in file-system buttons differ; the RegEdit directory line, its tab and
                          the Plugins-manager list differ
      FOLDERS             the left panel on the Folders file system ("fld:"): its directory-line icon (the shell
                          icon of its current folder) is the same in Fluent 2 and Classic
      SWITCH / SWITCHBACK Configuration > Appearance, the other set + OK (Light Fluent -> Classic; Dark Classic ->
                          Fluent): Plugins bar, drive bar and directory line equal a fresh start in the target set
      CACHE               the plug-ins' stored icon lists (PluginIconList values) after a Fluent 2 session equal
                          those after a Classic session - no set icon is ever stored
      OVR                 a copy of this build with plugins\regedt.svg emptied and plugins\ftp.svg removed: their
                          Plugins-bar cells equal Classic (today's icon), the other cells stay Fluent 2
      DARK-VERBATIM       a copy without plugins\dark\: in Dark its captures differ from this build's - the hand-made
                          dark variants are drawn, not the adapted standard files (review 1)
      PAGE / FIT         the Appearance page with the new label; "Icon style" fits its group box in English and
                          the 8 enabled languages
      CHDRV-<theme>       Alt+F1 (posted CM_LCHANGEDRIVE) and the Disconnect dialog (CM_DISCONNECTNET) with the RegEdit
                          FS open: their icon columns differ from Classic; Classic equals the build of main (review 2)
    NOT DRIVEN: the Plugins menu and View With (a real keyboard / mouse), hot states, 125-200 % (saltests
    TestPluginIcons417 rasterizes every file at 16 / 20 / 24 / 32 px).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Before,
    [string]$Label = 'after',
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Before) { $Before = (Resolve-Path -LiteralPath $Before).Path }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\416-fluent-icon-set\probe\capture416_lib.ps1')
if (-not ('Cells417' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Cells417
{
    // the pixels without alpha (as Cap416.Pixels, which lives in another assembly)
    static int[] Pixels(Bitmap b)
    {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
        int[] px = new int[b.Width * b.Height];
        for (int y = 0; y < b.Height; y++)
            Marshal.Copy(IntPtr.Add(d.Scan0, y * d.Stride), px, y * b.Width, b.Width);
        b.UnlockBits(d);
        for (int i = 0; i < px.Length; i++) px[i] &= 0xFFFFFF;
        return px;
    }
    // the icon cells of a bar: runs of columns holding a pixel that differs from the bar's background
    // (the colour of the most pixels); runs narrower than 'minWidth' (drop-down chevrons, separators) are dropped
    public static int[] Find(Bitmap b, int minWidth)
    {
        int[] p = Pixels(b);
        var h = new Dictionary<int, int>();
        foreach (int c in p) { int v; h.TryGetValue(c, out v); h[c] = v + 1; }
        int bk = 0, top = -1; foreach (var kv in h) if (kv.Value > top) { top = kv.Value; bk = kv.Key; }
        var res = new List<int>();
        int start = -1;
        for (int x = 0; x <= b.Width; x++)
        {
            bool ink = false;
            if (x < b.Width)
                for (int y = 0; y < b.Height && !ink; y++)
                    if (p[y * b.Width + x] != bk) ink = true;
            if (ink && start < 0) start = x;
            if (!ink && start >= 0) { if (x - start >= minWidth) { res.Add(start); res.Add(x); } start = -1; }
        }
        return res.ToArray();
    }
    public static int Diff(Bitmap a, Bitmap b, int x0, int x1)
    {
        if (a.Width != b.Width || a.Height != b.Height) return -1;
        int[] pa = Pixels(a), pb = Pixels(b);
        int n = 0;
        for (int y = 0; y < a.Height; y++)
            for (int x = x0; x < x1; x++)
                if (pa[y * a.Width + x] != pb[y * a.Width + x]) n++;
        return n;
    }
    public static int Colours(Bitmap a, int x0, int x1)
    {
        int[] pa = Pixels(a);
        var s = new HashSet<int>();
        for (int y = 0; y < a.Height; y++)
            for (int x = x0; x < x1; x++)
                s.Add(pa[y * a.Width + x]);
        return s.Count;
    }
}
'@
}
$Root = $TempRoot + '\tc417p'
$StartDir = $Root + '\start'
$CapDir = Join-Path $PSScriptRoot ('captures_' + $Label)
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$CfgKey = "$RegKey\Settings\Configuration"
$Caps = @{}
$RegFS = 'reg:\'
$FoldersFS = 'fld:'

function Set-Look([int]$Theme, [int]$Set) {
    & reg.exe add $CfgKey /v 'Theme Mode' /t REG_DWORD /d $Theme /f | Out-Null
    & reg.exe add $CfgKey /v 'Toolbar Icon Set' /t REG_DWORD /d $Set /f | Out-Null
    & reg.exe add $CfgKey /v 'Show Plugins Bar' /t REG_DWORD /d 1 /f | Out-Null
}
function Read-Set {
    $v = & cmd.exe /c "reg query `"$CfgKey`" /v `"Toolbar Icon Set`" 2>nul"
    $m = [regex]::Match(($v -join ' '), 'REG_\w+\s+(\S+)')
    if ($m.Success) { return $m.Groups[1].Value } else { return '<none>' }
}
# the plug-ins' stored icon lists (the registry cache that must never get a set icon)
function Read-IconCache {
    $v = & cmd.exe /c "reg query `"$RegKey\Settings`" /s /v PluginIconList 2>nul"
    return (@($v | Where-Object { $_ -match 'PluginIconList|^HKEY' }) -join "`n")
}
function Start-At([string]$ExePath, [string]$Left) {
    $a = @('-t', 'T417', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '2')
    $p = Start-Process -FilePath $ExePath -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2500
    return $p.Id
}
# the parts under test of the running instance
function Grab([int]$Id, [string]$Tag) {
    $main = Get-Main $Id
    [void][Drv098f]::Send($main, 0, 0, 0, 20000)
    $full = [Cap416]::Capture($main, $false)
    $rebar = @(Get-Desc $main 'ReBarWindow32')[0]
    $bars = @(Get-Desc $rebar 'WinLib Universal Window2') # top first: menu, Plugins bar, drive bar, top toolbar
    if ($bars.Count -lt 3) { throw ("the rebar holds {0} bars, expected the menu, the Plugins bar and the drive bar" -f $bars.Count) }
    $dirs = @([Cap416]::Kids($main) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::GetDlgCtrlID($_) -eq 952 })
    $dirs = @($dirs | Sort-Object { $r = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($_, [ref]$r); $r.left })
    # review 1: the left panel's tab strip (id 958; panel tabs are on by default), its first tab's icon
    $tabs = @([Cap416]::Kids($main) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::GetDlgCtrlID($_) -eq 958 })
    $tabs = @($tabs | Sort-Object { $r = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($_, [ref]$r); $r.left })
    if ($tabs.Count -lt 1) { throw 'no tab strip (id 958)' }
    $o = [pscustomobject]@{
        Plugins = [Cap416]::Crop($full, $main, $bars[1])
        Drives  = [Cap416]::Crop($full, $main, $bars[2])
        Dir     = [Cap416]::Crop($full, $main, $dirs[0])
        Tab     = [Cap416]::Crop($full, $main, $tabs[0])
    }
    # the directory line's icon only (16 px from x = 2): the path right of it changes between runs
    # (run 1: 24 px took in the first letters of the Folders path and differed by 9 px)
    $o.Dir = $o.Dir.Clone((New-Object Drawing.Rectangle(0, 0, [Math]::Min(20, $o.Dir.Width), $o.Dir.Height)), $o.Dir.PixelFormat)
    # the whole strip: the tab's icon is not at its start (run 4: x 358-373; a 32 px crop saw 0 px); the strip is
    # stable between runs (review 1: main vs this build's Classic 0 px)
    Save-Png $o.Plugins (Join-Path $CapDir ($Tag + '_pluginsbar.png'))
    Save-Png $o.Drives (Join-Path $CapDir ($Tag + '_drivebar.png'))
    Save-Png $o.Dir (Join-Path $CapDir ($Tag + '_dirline.png'))
    Save-Png $o.Tab (Join-Path $CapDir ($Tag + '_tab.png'))
    $full.Dispose()
    return $o
}
# Plugins > Plugins Manager: the list of plug-ins (icon column), then Cancel
function Grab-Manager([int]$Id, [string]$Tag) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 815 # CM_PLUGINS
    $dlg = Wait-NewWin $Id $known 15
    if ($null -eq $dlg -or $dlg -eq [IntPtr]::Zero) { throw 'the Plugins manager did not open' }
    Start-Sleep -Milliseconds 800
    $list = @([Cap416]::Kids($dlg) | Where-Object { [Cap416]::GetDlgCtrlID($_) -eq 2601 })[0]
    if ($null -eq $list) { throw 'no plug-in list (IDL_PLUGINS) in the Plugins manager' }
    [void][Drv098f]::Send($list, 0, 0, 0, 10000)
    $full = [Cap416]::Capture($dlg, $false)
    $b = [Cap416]::Crop($full, $dlg, $list)
    # the icon column only (the first 28 px): the texts (versions, paths) are not under test
    $b = $b.Clone((New-Object Drawing.Rectangle(0, 0, [Math]::Min(28, $b.Width), $b.Height)), $b.PixelFormat)
    Save-Png $b (Join-Path $CapDir ($Tag + '_manager.png'))
    $full.Dispose()
    Post-Cmd $dlg 2 # IDCANCEL
    [void](Serve $Id 6)
    return $b
}
function Run-Look([string]$ExePath, [int]$Theme, [int]$Set, [string]$Tag, [string]$Left = $RegFS, [switch]$Manager) {
    Set-Look $Theme $Set
    $id = Start-At $ExePath $Left
    $r = Serve $id 8
    $g = Grab $id $Tag
    for ($k = 0; $k -lt 6; $k++) { # until two captures a second apart are identical
        Start-Sleep -Milliseconds 1000
        $g2 = Grab $id $Tag
        $same = Zero (Same $g $g2)
        $g = $g2
        if ($same) { break }
    }
    if ($Manager) { $g | Add-Member -NotePropertyName Manager -NotePropertyValue (Grab-Manager $id $Tag) }
    $g | Add-Member -NotePropertyName Messages -NotePropertyValue (Msgs $r)
    Stop-Tc $id
    $script:Caps[$Tag] = $g
    return $g
}
function Same($a, $b) { return [pscustomobject]@{ Plugins = [Cap416]::Diff($a.Plugins, $b.Plugins); Drives = [Cap416]::Diff($a.Drives, $b.Drives); Dir = [Cap416]::Diff($a.Dir, $b.Dir); Tab = [Cap416]::Diff($a.Tab, $b.Tab) } }
function DiffText($d) { return ("Plugins bar {0}, drive bar {1}, directory line {2}, tab {3} px differ" -f $d.Plugins, $d.Drives, $d.Dir, $d.Tab) }
function Zero($d) { return ($d.Plugins -eq 0) -and ($d.Drives -eq 0) -and ($d.Dir -eq 0) -and ($d.Tab -eq 0) }
# per icon cell of the Classic capture 'c': [differing px, colours of 'f'] in 'f'
function CellReport([Drawing.Bitmap]$f, [Drawing.Bitmap]$c, [int]$MinWidth = 12) {
    $cells = [Cells417]::Find($c, $MinWidth)
    $out = @()
    for ($i = 0; $i -lt $cells.Length; $i += 2) {
        $out += [pscustomobject]@{ X0 = $cells[$i]; X1 = $cells[$i + 1]; Diff = [Cells417]::Diff($f, $c, $cells[$i], $cells[$i + 1]); Colours = [Cells417]::Colours($f, $cells[$i], $cells[$i + 1]) }
    }
    return $out
}

# ---- Configuration > Appearance (as the 416 probe) -----------------------------------------------
function Open-Appearance([int]$Id) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 686
    $dlg = Wait-NewWin $Id $known 15
    if ($null -eq $dlg -or $dlg -eq [IntPtr]::Zero) { throw 'the Configuration dialog did not open' }
    $tree = @([Cap416]::Kids($dlg) | Where-Object { [Cap416]::Cls($_) -eq 'SysTreeView32' })[0]
    $items = New-Object System.Collections.ArrayList
    $stack = New-Object System.Collections.Stack
    $h = [Cap416]::Send($tree, 0x110A, [IntPtr]0, [IntPtr]::Zero)
    $guard = 0
    while ($h -ne [IntPtr]::Zero -and $guard -lt 200) {
        $guard++
        [void]$items.Add($h)
        [void][Cap416]::Send($tree, 0x1102, [IntPtr]2, $h)
        $child = [Cap416]::Send($tree, 0x110A, [IntPtr]4, $h)
        $next = [Cap416]::Send($tree, 0x110A, [IntPtr]1, $h)
        if ($child -ne [IntPtr]::Zero) { if ($next -ne [IntPtr]::Zero) { $stack.Push($next) }; $h = $child }
        elseif ($next -ne [IntPtr]::Zero) { $h = $next }
        elseif ($stack.Count) { $h = $stack.Pop() }
        else { $h = [IntPtr]::Zero }
    }
    foreach ($it in $items) {
        [void][Cap416]::Send($tree, 0x110B, [IntPtr]9, $it)
        Start-Sleep -Milliseconds 300
        $radio = @([Cap416]::Kids($dlg) | Where-Object { [Cap416]::GetDlgCtrlID($_) -eq 6292 -and [Cap416]::IsWindowVisible($_) })
        if ($radio.Count) { return [pscustomobject]@{ Dlg = $dlg; Page = [Cap416]::GetParent($radio[0]) } }
    }
    throw 'the Appearance page was not found'
}
function Ctl([IntPtr]$Page, [int]$CtlId) { return @([Cap416]::Kids($Page) | Where-Object { [Cap416]::GetDlgCtrlID($_) -eq $CtlId })[0] }
function Switch-Set([int]$Id, [int]$ToCtl) {
    $a = Open-Appearance $Id
    [void][Cap416]::Send((Ctl $a.Page $ToCtl), 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) # BM_CLICK
    Start-Sleep -Milliseconds 300
    $okBtn = @([Cap416]::Kids($a.Dlg) | Where-Object { [Cap416]::Cls($_) -eq 'Button' -and [Cap416]::GetDlgCtrlID($_) -eq 5 })[0]
    if ($null -eq $okBtn) { throw 'no OK button (id 5)' }
    Click $okBtn
    $r = Serve $Id 15
    Start-Sleep -Milliseconds 2000
    return $r
}

# ---- the rows ------------------------------------------------------------------------------------
function Row-ClassicEq([int]$Theme) {
    $n = 'CLASSIC-EQ-' + @('LIGHT', 'DARK')[$Theme]
    if (-not (Want $n)) { return }
    if (-not $Before) { Row $n 'RUN' 'NOT DRIVEN' 'no -Before build given'; return }
    try {
        $b = Run-Look $Before $Theme 1 ('before_classic_t' + $Theme) -Manager
        $a = Run-Look $Exe $Theme 1 ('classic_t' + $Theme) -Manager
        $d = Same $a $b
        $dm = [Cap416]::Diff($a.Manager, $b.Manager)
        Row $n 'COMPARE' (V ((Zero $d) -and $dm -eq 0)) ((DiffText $d) + ("; Plugins-manager icons {0} px; Plugins bar {1}; windows: {2}" -f $dm, [Cap416]::Stats($a.Plugins), $a.Messages))
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}
function Row-Fluent([int]$Theme) {
    $n = 'FLUENT-' + @('LIGHT', 'DARK')[$Theme]
    if (-not (Want $n)) { return }
    try {
        if (-not $script:Caps.ContainsKey('classic_t' + $Theme)) { [void](Run-Look $Exe $Theme 1 ('classic_t' + $Theme) -Manager) }
        $c = $script:Caps['classic_t' + $Theme]
        $script:CacheClassic = Read-IconCache
        $f = Run-Look $Exe $Theme 0 ('fluent_t' + $Theme) -Manager
        $script:CacheFluent = Read-IconCache
        $cells = @(CellReport $f.Plugins $c.Plugins)
        $bad = @($cells | Where-Object { $_.Diff -lt 20 -or $_.Colours -lt 8 })
        Row $n 'PLUGINS-BAR' (V ($cells.Count -ge 11 -and $bad.Count -eq 0)) ("{0} icon cells, {1} not replaced or not drawn; diff/colours per cell: {2}" -f $cells.Count, $bad.Count, (($cells | ForEach-Object { "{0}/{1}" -f $_.Diff, $_.Colours }) -join ' '))
        # 5 px: the Portables phone is narrow (with 12 px it was dropped and Network, a 416 icon, was counted instead)
        $dc = @(CellReport $f.Drives $c.Drives 5)
        $fs = @($dc | Select-Object -Last 6)
        $fsBad = @($fs | Where-Object { $_.Diff -lt 20 -or $_.Colours -lt 8 })
        Row $n 'DRIVE-BAR-FS' (V ($dc.Count -ge 6 -and $fsBad.Count -eq 0)) ("{0} cells; the last 6 (plug-in file systems): {1}" -f $dc.Count, (($fs | ForEach-Object { "{0}/{1}" -f $_.Diff, $_.Colours }) -join ' '))
        $dd = [Cap416]::Diff($f.Dir, $c.Dir)
        Row $n 'DIRLINE-REGEDIT' (V ($dd -gt 20 -and (Colours $f.Dir) -ge 8)) ("RegEdit FS directory-line icon: {0} px differ from Classic; {1}" -f $dd, [Cap416]::Stats($f.Dir))
        $dt = [Cap416]::Diff($f.Tab, $c.Tab)
        Row $n 'TAB-REGEDIT' (V ($dt -gt 20)) ("the RegEdit FS tab's icon: {0} px differ from Classic; {1}" -f $dt, [Cap416]::Stats($f.Tab))
        $dm = [Cap416]::Diff($f.Manager, $c.Manager)
        Row $n 'MANAGER' (V ($dm -gt 100)) ("Plugins-manager icon column: {0} px differ from Classic" -f $dm)
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}
function Colours([Drawing.Bitmap]$B) { return [int](([Cap416]::Stats($B) -split ' ')[2]) }
function Row-Cache {
    $n = 'CACHE'
    if (-not (Want $n)) { return }
    if (-not $script:CacheFluent) { Row $n 'COMPARE' 'NOT DRIVEN' 'row FLUENT-LIGHT did not run'; return }
    $lines = @($script:CacheFluent -split "`n" | Where-Object { $_ -match 'PluginIconList' }).Count
    Row $n 'COMPARE' (V ($lines -ge 10 -and $script:CacheFluent -eq $script:CacheClassic)) ("{0} stored PluginIconList values; after a Fluent 2 session equal to after a Classic session: {1}" -f $lines, ($script:CacheFluent -eq $script:CacheClassic))
}
function Row-Folders {
    $n = 'FOLDERS'
    if (-not (Want $n)) { return }
    try {
        $c = Run-Look $Exe 0 1 'folders_classic' $FoldersFS
        $f = Run-Look $Exe 0 0 'folders_fluent' $FoldersFS
        $d = [Cap416]::Diff($f.Dir, $c.Dir)
        Row $n 'DIRLINE-KEPT' (V ($d -eq 0 -and (Colours $f.Dir) -ge 8)) ("Folders FS directory-line icon Fluent 2 vs Classic: {0} px differ; {1}" -f $d, [Cap416]::Stats($f.Dir))
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}
function Row-Switch([string]$n, [int]$Theme, [int]$From, [int]$ToCtl, [string]$Target) {
    if (-not (Want $n)) { return }
    $id = 0
    try {
        if (-not $script:Caps.ContainsKey($Target)) { [void](Run-Look $Exe $Theme (1 - $From) $Target -Manager) }
        Set-Look $Theme $From
        $id = Start-At $Exe $RegFS
        [void](Serve $id 8)
        $r = Switch-Set $id $ToCtl
        $g = Grab $id ($n.ToLower() + '_after_ok')
        $d = Same $g $script:Caps[$Target]
        Row $n 'APPLIED-NO-RESTART' (V (Zero $d)) ((DiffText $d) + (" (vs a fresh start {0}); windows: {1}" -f $Target, (Msgs $r)))
        Stop-Tc $id; $id = 0
        Row $n 'STORED' (V ((Read-Set) -eq ('0x' + (1 - $From)))) ("stored: {0}" -f (Read-Set))
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Stop-Tc $id } }
}
function Copy-Tree([string]$From, [string]$To) {
    & robocopy.exe (Split-Path $From) $To /E /XF *.pdb *.ilk /XD Intermediate saltests translator /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $From -> $To failed ($LASTEXITCODE)" }
    return (Join-Path $To (Split-Path $From -Leaf))
}
function Row-Ovr {
    $n = 'OVR'
    if (-not (Want $n)) { return }
    try {
        if (-not $script:Caps.ContainsKey('classic_t0')) { [void](Run-Look $Exe 0 1 'classic_t0' -Manager) }
        if (-not $script:Caps.ContainsKey('fluent_t0')) { [void](Run-Look $Exe 0 0 'fluent_t0' -Manager) }
        $tree = $Root + '\tree_ovr'
        $exe2 = Copy-Tree $Exe $tree
        $pdir = $tree + '\iconsets\fluent\plugins'
        [IO.File]::WriteAllText(($pdir + '\regedt.svg'), '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"></svg>')
        [IO.File]::Delete($pdir + '\ftp.svg')
        $o = Run-Look $exe2 0 0 'ovr_fluent_t0'
        $c = $script:Caps['classic_t0']; $f = $script:Caps['fluent_t0']
        $cells = @(CellReport $o.Plugins $c.Plugins)
        $classicLike = @(); $fluentLike = 0
        for ($i = 0; $i -lt $cells.Count; $i++) {
            if ($cells[$i].Diff -eq 0) { $classicLike += $i }
            elseif ([Cells417]::Diff($o.Plugins, $f.Plugins, $cells[$i].X0, $cells[$i].X1) -eq 0) { $fluentLike++ }
        }
        # the Plugins bar is sorted by name: 7-Zip, Checksum, DiskMap, FTP (3), File Comparator, PictView, RegEdit (6), ...
        Row $n 'MISSING-EMPTY=TODAY' (V (($classicLike -join ',') -eq '3,6' -and $fluentLike -eq $cells.Count - 2)) ("cells equal to Classic: {0} (expected FTP 3 and RegEdit 6); cells equal to Fluent 2: {1} of {2}" -f ($classicLike -join ','), $fluentLike, $cells.Count)
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}
# review 1: the Dark rows above only compare with Classic; this one shows the hand-made dark variants are drawn
# (a copy without plugins\dark\ draws the standard files with the automatic adaptation, which must look different)
function Row-DarkVerbatim {
    $n = 'DARK-VERBATIM'
    if (-not (Want $n)) { return }
    try {
        if (-not $script:Caps.ContainsKey('fluent_t1')) { [void](Run-Look $Exe 1 0 'fluent_t1' -Manager) }
        $tree = $Root + '\tree_nodark'
        $exe2 = Copy-Tree $Exe $tree
        [IO.Directory]::Delete(($tree + '\iconsets\fluent\plugins\dark'), $true)
        $x = Run-Look $exe2 1 0 'nodark_fluent_t1'
        $d = Same $x $script:Caps['fluent_t1']
        Row $n 'DARK-FILES-USED' (V ($d.Plugins -gt 200 -and $d.Drives -gt 100 -and $d.Dir -gt 20 -and $d.Tab -gt 20)) ("without plugins\dark\ vs this build, Dark: " + (DiffText $d))
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}
function Row-Page {
    $n = 'PAGE'
    if (-not (Want $n)) { return }
    $id = 0
    try {
        Set-Look 0 0
        $id = Start-At $Exe $StartDir
        [void](Serve $id 8)
        $a = Open-Appearance $id
        [void][Drv098f]::Send($a.Page, 0, 0, 0, 10000)
        $pg = [Cap416]::Capture($a.Page, $false)
        Save-Png $pg (Join-Path $CapDir 'page_appearance.png')
        $grp = Ctl $a.Page 6291
        $text = [Cap416]::Txt($grp)
        $r = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($grp, [ref]$r)
        $script:LiveGroupPx = $r.right - $r.left
        Row $n 'LABEL' (V ($text -eq ' &Icon style ')) ("group text '{0}', {1} px wide" -f $text, $script:LiveGroupPx)
        Post-Cmd $a.Dlg 2
        [void](Serve $id 8)
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Stop-Tc $id } }
}
function Row-Fit {
    $n = 'FIT'
    if (-not (Want $n)) { return }
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $font = New-Object Drawing.Font('MS Shell Dlg 2', 8)
        $bmp = New-Object Drawing.Bitmap(10, 10); $g = [Drawing.Graphics]::FromImage($bmp)
        $flags = [Windows.Forms.TextFormatFlags]::SingleLine -bor [Windows.Forms.TextFormatFlags]::NoPadding
        if (-not $script:LiveGroupPx) { Row $n 'DLU' 'NOT DRIVEN' 'row PAGE did not measure the live group box'; return }
        $baseX = $script:LiveGroupPx * 4.0 / 295 # the group box is 295 DLU wide
        $tpl = Join-Path (Split-Path (Split-Path $Exe)) 'translator\templates\salamand.slt'
        $files = @(, @('english', $tpl)) + @('czech', 'slovak', 'german', 'french', 'dutch', 'hungarian', 'romanian', 'spanish' | ForEach-Object { , @($_, (Join-Path $RepoRoot ("translations\{0}\salamand.slt" -f $_))) })
        foreach ($pair in $files) {
            if (-not (Test-Path -LiteralPath $pair[1])) { Row $n $pair[0] 'FAIL' ('missing ' + $pair[1]); continue }
            $line = @([IO.File]::ReadAllLines($pair[1], [Text.Encoding]::UTF8) | Where-Object { $_ -like '6291,*' })[0]
            $m = [regex]::Match($line, '^\d+,(-?\d+),(-?\d+),(\d+),(\d+),\d+,"(.*)"$')
            $text = $m.Groups[5].Value -replace '&&', "`0" -replace '&', '' -replace "`0", '&'
            $px = [int][Math]::Round([int]$m.Groups[3].Value * $baseX / 4)
            $tw = [Windows.Forms.TextRenderer]::MeasureText($g, $text.Trim(), $font, (New-Object Drawing.Size(4000, 100)), $flags).Width
            $room = $px - [int](16 * $g.DpiX / 96) # the group box frame and its caption gap
            Row $n $pair[0] (V ($tw -le $room)) ("'{0}' {1}/{2} px" -f $text.Trim(), $tw, $room)
        }
        $g.Dispose(); $bmp.Dispose()
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}

# ---- review 2: the Change Drive menu (Alt+F1) and the Disconnect dialog, opened by posted commands (as the
# probes of 374 / 289 do) - the left panel on the RegEdit FS, so both list an open plug-in file system ----------
function Wait-Menu([int]$Id, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        $m = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq 'PopupMenuClass' }) | Select-Object -First 1
        if ($m) { Start-Sleep -Milliseconds 800; return $m }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
function MenuKey([IntPtr]$M, [int]$Vk) {
    [void][Drv098f]::PostMessageW($M, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($M, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)
    Start-Sleep -Milliseconds 150
}
function Grab-ChDrv([string]$ExePath, [int]$Theme, [int]$Set, [string]$Tag) {
    Set-Look $Theme $Set
    $id = Start-At $ExePath $RegFS
    try {
        [void](Serve $id 8)
        Post-Cmd (Get-Main $id) 707 # CM_LCHANGEDRIVE (Alt+F1)
        $m = Wait-Menu $id
        if ($m -eq [IntPtr]::Zero) { throw 'the Change Drive menu did not open' }
        $b = [Cap416]::Capture($m, $false)
        # the icon column only: the free-space figures of the drives change between runs (review 2: 51 px)
        $b = $b.Clone((New-Object Drawing.Rectangle(0, 0, [Math]::Min(32, $b.Width), $b.Height)), $b.PixelFormat)
        Save-Png $b (Join-Path $CapDir ($Tag + '_chdrv.png'))
        MenuKey $m 0x1B
        Start-Sleep -Milliseconds 500
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 736 # CM_DISCONNECTNET (F12)
        $dlg = Wait-NewWin $id $known 15
        $lb = $null
        if ($null -ne $dlg -and $dlg -ne [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 800
            $list = @([Cap416]::Kids($dlg) | Where-Object { [Cap416]::Cls($_) -eq 'SysListView32' })[0]
            if ($null -ne $list) {
                $full = [Cap416]::Capture($dlg, $false)
                $lb = [Cap416]::Crop($full, $dlg, $list)
                $lb = $lb.Clone((New-Object Drawing.Rectangle(0, 0, [Math]::Min(40, $lb.Width), $lb.Height)), $lb.PixelFormat)
                Save-Png $lb (Join-Path $CapDir ($Tag + '_disconnect.png'))
                $full.Dispose()
            }
            Post-Cmd $dlg 2
            [void](Serve $id 6)
        }
        return [pscustomobject]@{ Menu = $b; Disc = $lb }
    }
    finally { Stop-Tc $id }
}
function Row-Menus([int]$Theme) {
    $n = 'CHDRV-' + @('LIGHT', 'DARK')[$Theme]
    if (-not (Want $n)) { return }
    try {
        $c = Grab-ChDrv $Exe $Theme 1 ('chdrv_classic_t' + $Theme)
        $f = Grab-ChDrv $Exe $Theme 0 ('chdrv_fluent_t' + $Theme)
        $d = [Cap416]::Diff($f.Menu, $c.Menu)
        Row $n 'MENU-FLUENT' (V ($d -gt 200)) ("Change Drive menu icon column {0}x{1}: {2} px differ from Classic" -f $f.Menu.Width, $f.Menu.Height, $d)
        if ($f.Disc -and $c.Disc) {
            $dd = [Cap416]::Diff($f.Disc, $c.Disc)
            Row $n 'DISCONNECT-FLUENT' (V ($dd -gt 20)) ("Disconnect dialog icon column: {0} px differ from Classic" -f $dd)
        } else { Row $n 'DISCONNECT-FLUENT' 'FAIL' 'the Disconnect dialog / its list was not captured' }
        if ($Before) {
            # Fluent 2 of this build vs Fluent 2 of main: the drive icons (416) are the same, only the plug-in
            # file systems' icons differ (MENU-FLUENT alone passes on main too: 1171 px of 416's drive icons)
            $bf = Grab-ChDrv $Before $Theme 0 ('chdrv_before_fluent_t' + $Theme)
            $dp = [Cap416]::Diff($f.Menu, $bf.Menu)
            Row $n 'MENU-PLUGIN-ICONS' (V ($dp -gt 200)) ("Change Drive menu icon column, Fluent 2 of this build vs of main: {0} px differ" -f $dp)
            $b = Grab-ChDrv $Before $Theme 1 ('chdrv_before_classic_t' + $Theme)
            $db = [Cap416]::Diff($b.Menu, $c.Menu)
            $ddb = if ($b.Disc -and $c.Disc) { [Cap416]::Diff($b.Disc, $c.Disc) } else { -1 }
            Row $n 'CLASSIC-EQ' (V ($db -eq 0 -and $ddb -eq 0)) ("Classic, the build of main vs this build: Change Drive menu {0} px, Disconnect list {1} px" -f $db, $ddb)
        }
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}

$backup = Join-Path $env:TEMP 'tc417_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    foreach ($f in 'a.tc417', 'b.tc417') { $p = $StartDir + '\' + $f; [IO.File]::WriteAllText($p, 'x'); [IO.File]::SetLastWriteTime($p, [datetime]'2026-01-02 03:04:05') }
    [void][IO.Directory]::CreateDirectory($CapDir)
    Set-Config
    Out ("plugin417_probe (feature 417) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Before  : {0}" -f $Before)
    Out ("Date    : {0}; registry key existed {1}; captures in {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $CapDir)
    Out ''
    Row-ClassicEq 0
    Row-ClassicEq 1
    Row-Fluent 0
    Row-Cache
    Row-Fluent 1
    Row-Folders
    Row-Switch 'SWITCH' 0 0 6293 'classic_t0'
    Row-Switch 'SWITCHBACK' 1 1 6292 'fluent_t1'
    Row-Ovr
    Row-DarkVerbatim
    Row-Menus 0
    Row-Menus 1
    Row-Page
    Row-Fit
    Row 'MENUS' 'OPEN' 'NOT DRIVEN' 'the Plugins menu and View With need a real keyboard or mouse (a posted Alt+P does not open the menu bar; they draw from CreateIconsList, captured here through the Plugins bar and the Plugins manager); Alt+F1 and Disconnect: rows CHDRV-*'
    Row 'STATES' 'HOT' 'NOT DRIVEN' 'hot / pressed buttons need a real mouse; the highlight background is measured offline (saltests TestPluginIcons417)'
    Row 'DPI' '125-200' 'NOT DRIVEN' 'the hidden desktop runs at the session system DPI; saltests rasterizes every file at 20 / 24 / 32 px'
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
