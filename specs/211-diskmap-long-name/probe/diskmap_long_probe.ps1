<#
.SYNOPSIS
    Feature 211 probe: Disk Map never hands the shell another item's path - a file whose full
    name does not fit the map's 781-byte name buffer got its FOLDER's path (the file's own name
    was skipped), and the shell's menu (Delete ...) acted on the folder.

.DESCRIPTION
    Rows (the map of the row's folder; a right press at the middle of the map selects the only, big
    file, the keyboard's context-menu request opens the shell's file menu; Delete is chosen and its
    confirmation READ, then answered No - nothing is deleted):
      deep  a folder chain of about 690 bytes, a file of a 114-letter name (its full name ~804
            bytes): PASS = no menu (refused) or a confirmation about a FILE; FAIL = about a folder
      ctl   the control: a short folder, a file - the confirmation about the file (or, without one,
            exactly that file gone - Windows deleted it unasked)
    The registry key of the program is exported before and restored and SHA-256-verified after.
    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while any tandemcommander.exe runs.
    Driver of 143's release_guard_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

if (-not ('Drv118' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv118
{
    [DllImport("user32.dll")] static extern IntPtr GetThreadDesktop(uint threadId);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool GetUserObjectInformationW(IntPtr h, int index, StringBuilder info, int length, out int needed);
    public static string DesktopName()
    {
        var sb = new StringBuilder(256); int needed;
        if (!GetUserObjectInformationW(GetThreadDesktop(GetCurrentThreadId()), 2, sb, sb.Capacity * 2, out needed)) return "";
        return sb.ToString();
    }
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetMenuState(IntPtr m, uint id, uint flags);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool DeviceIoControl(Microsoft.Win32.SafeHandles.SafeFileHandle h, uint code, IntPtr inBuf, uint inSize, IntPtr outBuf, uint outSize, out uint ret, IntPtr ov);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift): the probe thread shares the target thread's
    // input state and sets the key-state table - no real key press (the 100/102/104/115/117 method)
    public static string ModKey(IntPtr target, int vk, int mods)
    {
        uint pid; uint tid = GetWindowThreadProcessId(target, out pid);
        uint me = GetCurrentThreadId();
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed " + Marshal.GetLastWin32Error();
        var saved = new byte[256]; GetKeyboardState(saved);
        try
        {
            var k = (byte[])saved.Clone();
            if ((mods & 2) != 0) { k[0x10] = k[0xA0] = 0x80; }
            if ((mods & 1) != 0) { k[0x11] = k[0xA2] = 0x80; }
            if (!SetKeyboardState(k)) return "SetKeyboardState failed";
            PostMessageW(target, 0x0100, (IntPtr)vk, (IntPtr)1);
            IntPtr r; SendMessageTimeoutW(target, 0, IntPtr.Zero, IntPtr.Zero, 0, 3000, out r);
            Thread.Sleep(300);
            return "ok";
        }
        finally
        {
            SetKeyboardState(saved);
            PostMessageW(target, 0x0101, (IntPtr)vk, unchecked((IntPtr)0xC0000001));
            AttachThreadInput(me, tid, false);
        }
    }
    // a sparse file of 'size' bytes: reads as zeros, takes no disk space
    public static bool MakeSparse(string path, long size)
    {
        using (var fs = new System.IO.FileStream(path, System.IO.FileMode.Create, System.IO.FileAccess.ReadWrite))
        {
            uint r;
            bool ok = DeviceIoControl(fs.SafeFileHandle, 0x000900C4 /*FSCTL_SET_SPARSE*/, IntPtr.Zero, 0, IntPtr.Zero, 0, out r, IntPtr.Zero);
            fs.SetLength(size);
            return ok;
        }
    }
}
'@
}
$deskName = [Drv118]::DesktopName()
if (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon') { Write-Output ("REFUSED: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 98 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$RmProbe = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\080-restart-manager-upgrade\probe\rm_probe.ps1')).Path

$Fixed = ($Expect -eq 'fixed')
$Root = $TempRoot + '\tc211'
$WaitClass = 'SalamanderSaveBits'
$FcClass = 'SFC Window Class'
$DmClass = 'Zar.DM.MainWin.WC'
$DmLogClass = 'Zar.DM.LogWin.WC'
$script:HotKeyNote = 'not set'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Start-P([string]$Left, [string]$Right) {
    if (-not $Right) { $Right = $Left }
    $a = @('-t', 'T211', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
function End-P([string]$Case, [int]$Id, $Before) {
    if (-not (Test-Alive $Id)) { return }   # ended by the request: the RM row has checked the exit code and the reports
    if (Test-Alive $Id) {
        # End-Row counts every window but the main one as stray, so the row's windows are closed
        # first (as 117's End-P does): owned dialogs and boxes, then the plug-in windows themselves
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv118]::GetWindow($_, 4) -ne [IntPtr]::Zero })) { Close-Win $h }
        Start-Sleep -Milliseconds 500
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 10 -and @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass }).Count) { Start-Sleep -Milliseconds 200 }
    }
    End-Row $Case $Id $null $Before
}

# the plug-in's hot key on the left panel; returns the first new top-level window (or Zero)
function Open-ByKey([int]$Id, [int]$Vk, [double]$Seconds = 10) {
    $known = Get-Tops $Id
    $note = [Drv118]::ModKey((Get-LeftList $Id), $Vk, 3)
    $h = Wait-NewWin $Id $known $Seconds
    if ($h -eq [IntPtr]::Zero) { throw ("Ctrl+Shift+{0} opened no window (key: {1}; hot keys: {2})" -f [char]$Vk, $note, $script:HotKeyNote) }
    return $h
}
function Wait-Class([int]$Id, [string]$Cls, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $h = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq $Cls }) | Select-Object -First 1
        if ($h) { return $h }
        Start-Sleep -Milliseconds 150
    }
    return [IntPtr]::Zero
}
function Wait-Enabled([IntPtr]$B, [double]$Seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if ([Drv098f]::IsWindowEnabled($B)) { return $true }; Start-Sleep -Milliseconds 200 }
    return $false
}
function Select-All([int]$Id) { Post-Cmd (Get-Main $Id) 842; Start-Sleep -Milliseconds 800; Sync $Id }
function Lv-Count([IntPtr]$Lv) { return [Drv118]::SendR($Lv, 0x1004, 0, 0) }   # LVM_GETITEMCOUNT
function Lv-Key([IntPtr]$Lv, [int]$Vk) {
    [void][Drv118]::SendR($Lv, 0x0100, $Vk, 1)
    [void][Drv118]::SendR($Lv, 0x0101, $Vk, 0xC0000001)
    Start-Sleep -Milliseconds 300
}

# ---- the installer's request, with the screen watched meanwhile -------------------------------
function Invoke-RmWatched([int]$Id) {
    $before = Get-Tops $Id
    $out = [IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $RmProbe), '-ExePath', ('"{0}"' -f $Exe)) `
        -RedirectStandardOutput $out -PassThru -WindowStyle Hidden
    $null = $p.Handle
    $new = @{}
    while (-not $p.HasExited) {
        foreach ($h in (Get-Tops $Id)) {
            if ($before -notcontains $h -and -not $new.ContainsKey($h.ToInt64())) { $new[$h.ToInt64()] = (WinDesc $h) }
        }
        Start-Sleep -Milliseconds 30
    }
    $p.WaitForExit()
    $text = @(Get-Content -LiteralPath $out)
    Remove-Item -LiteralPath $out -Force
    $line = ($text | Where-Object { $_ -match '^RmShutdown' } | Select-Object -First 1)
    $secs = $null
    if ($line -match 'after ([\d\.,]+) s') { $secs = [double]($Matches[1] -replace ',', '.') }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if ($p.ExitCode -eq 0) { while ($sw.Elapsed.TotalSeconds -lt 10 -and (Test-Alive $Id)) { Start-Sleep -Milliseconds 100 } }
    $alive = Test-Alive $Id
    $shown = @($new.Values)
    return [pscustomobject]@{ Exit = $p.ExitCode; Line = $line; Seconds = $secs; Shown = $shown; Alive = $alive; Before = $before; Output = $text
        Other = @($shown | Where-Object { -not $_.StartsWith('[' + $WaitClass + ' ') }); Wait = @($shown | Where-Object { $_.StartsWith('[' + $WaitClass + ' ') }) }
}

# One row. $Prepare (param $id) brings the instance into the row's state and returns
# @{ Reached = bool; State = text; Work = scriptblock or $null }. Work (param $id, $agreed) checks
# the work state after the request and returns @{ Ok = bool; Text = text }.
function Run-Row([string]$Name, [string]$What, [string]$LeftDir, [bool]$AgreeFixed, [bool]$AgreeBefore, [scriptblock]$Prepare, [string]$RightDir) {
    if (-not (Want $Name)) { return }
    $script:RowWin = [IntPtr]::Zero   # the plug-in window of the row, for its WORK check
    $script:LockFs = $null            # a file the row holds locked (C6), released at the end
    $agree = $(if ($Fixed) { $AgreeFixed } else { $AgreeBefore })
    Out ("--- {0}: {1} (expected: {2})" -f $Name, $What, $(if ($agree) { 'agree' } else { 'decline' }))
    $id = 0; $reports = Reports
    try {
        $id = Start-P $LeftDir $RightDir
        $st = & $Prepare $id
        $fatal = Fatal-Win $id
        if ($fatal) { Row $Name 'STATE' 'FAIL' ('FATAL ' + $fatal); return }
        if (-not $st.Reached) { Row $Name 'STATE' 'NOT DRIVEN' ('state not reached: ' + $st.State); return }
        Row $Name 'STATE' 'PASS' $st.State
        $r = Invoke-RmWatched $id
        foreach ($s in $r.Shown) { Out ("           shown: " + $s) }
        if ($agree) {
            $ec = ExitCodeOf $id
            $rep = @(Take-Reports $reports)
            $ok = ($r.Exit -eq 0) -and (-not $r.Alive) -and ($r.Other.Count -eq 0) -and ($ec -eq '0x00000000') -and ($rep.Count -eq 0)
            Row $Name 'RM' (V $ok) ("rm_probe exit {0}; {1}; process ended {2}, exit code {3}; new windows {4} (+{5} core wait window); new crash reports {6}{7}" -f `
                    $r.Exit, $r.Line, (-not $r.Alive), $ec, $r.Other.Count, $r.Wait.Count, $rep.Count, $(if ($rep.Count) { ' [' + ($rep -join ' ;; ') + ']' } else { '' }))
        }
        else {
            $still = Get-Tops $id
            $kept = @($r.Before | Where-Object { $still -contains $_ }).Count
            $ok = ($r.Exit -eq 1) -and $r.Alive -and ($r.Shown.Count -eq 0) -and ($null -ne $r.Seconds) -and ($r.Seconds -le 1.0) -and ($kept -eq @($r.Before).Count)
            Row $Name 'RM' (V $ok) ("rm_probe exit {0}; {1}; process alive {2}; windows kept {3}/{4}; new windows {5}" -f `
                    $r.Exit, $r.Line, $r.Alive, $kept, @($r.Before).Count, $r.Shown.Count)
        }
        if (-not $ok) { $r.Output | ForEach-Object { Out ("           rm> " + $_) } }
        if ($st.Work) {
            $w = & $st.Work $id ($r.Exit -eq 0)
            Row $Name 'WORK' (V $w.Ok) $w.Text
        }
    }
    catch { Row $Name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($script:LockFs) { try { $script:LockFs.Dispose() } catch { }; $script:LockFs = $null }
        if ($id) { End-P $Name $id $reports }
    }
}

# ---- the plug-in windows ------------------------------------------------------------------------
# File Comparator on the two selected files of the left panel; with $KeepDialog the Compare Files

function Open-DiskMap([int]$Id) {
    $h = Open-ByKey $Id 0x44   # Ctrl+Shift+D
    if ([Drv098f]::Cls($h) -ne $DmClass) { $h2 = Wait-Class $Id $DmClass 10; if ($h2 -ne [IntPtr]::Zero) { $h = $h2 } }
    if ([Drv098f]::Cls($h) -ne $DmClass) { throw ('not a Disk Map window: ' + (WinDesc $h)) }
    return $h
}
# TRUE while the map scans: its File > Abort item is enabled (the window updates the item states on
# WM_INITMENU, which is sent here first); $null when the menu cannot be read
function Dm-Scanning([IntPtr]$H) {
    $m = [Drv118]::GetMenu($H)
    if ($m -eq [IntPtr]::Zero) { return $null }
    [void][Drv118]::SendR($H, 0x0116, $m.ToInt64(), 0)   # WM_INITMENU
    $st = [Drv118]::GetMenuState($m, 113, 0)             # IDM_FILE_ABORT, MF_BYCOMMAND
    if ($st -eq -1) { return $null }
    return (($st -band 3) -eq 0)                         # neither MF_GRAYED nor MF_DISABLED
}
function Set-HotKeys {
    $plugins = 'HKCU:\Software\Tandem Commander\0.1\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key (defaults; Calculate has no key)' }
    $map = @(
        @{ Dll = 'filecomp\.spl$'; Id = 1; Key = 0x10343 },
        @{ Dll = 'diskmap\.spl$'; Id = 1; Key = 0x10344 },
        @{ Dll = 'renamer\.spl$'; Id = 1; Key = 0x10352 },
        @{ Dll = 'checksum\.spl$'; Id = 1; Key = 0x10355 },
        @{ Dll = 'checksum\.spl$'; Id = 2; Key = 0x10356 })
    $notes = @()
    foreach ($k in @(Get-ChildItem $plugins)) {
        $dll = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DLL
        if (-not $dll) { continue }
        foreach ($m in $map) {
            if ($dll -notmatch $m.Dll) { continue }
            $menu = Join-Path $k.PSPath 'Menu'
            if (-not (Test-Path $menu)) { $notes += ("{0}: no Menu key" -f $dll); continue }
            $set = 0
            foreach ($mi in @(Get-ChildItem $menu)) {
                if ((Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID -eq $m.Id) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value $m.Key -Type DWord; $set++ }
            }
            $notes += ("{0} id {1}: {2}" -f (Split-Path $dll -Leaf), $m.Id, $set)
        }
    }
    return ($notes -join '; ')
}


# ---- feature 143 -----------------------------------------------------------------------------
if (-not ('Drv143' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class Drv143
{
    [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr m);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetMenuStringW(IntPtr m, uint item, StringBuilder s, int n, uint flags);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    public static List<string> Items(IntPtr m)
    {
        var l = new List<string>();
        int n = GetMenuItemCount(m);
        for (int i = 0; i < n; i++) { var s = new StringBuilder(512); GetMenuStringW(m, (uint)i, s, 512, 0x400 /*MF_BYPOSITION*/); l.Add(s.ToString()); }
        return l;
    }
    public static uint Tid(IntPtr h) { uint pid; return GetWindowThreadProcessId(h, out pid); }
}
'@
}
$MenuClass = '#32768'
$DmViewClass = 'Zar.DM.DMView.WC'
$UncRoot = '\\localhost\' + $Root.Substring(0, 1) + '$' + $Root.Substring(2)

function Set-DmConfirm {
    $k = 'HKCU:\Software\Tandem Commander\0.1\Plugins Configuration\DISKMAP'
    if (-not (Test-Path $k)) { [void](New-Item -Path $k -Force) }
    Set-ItemProperty -LiteralPath $k -Name 'Confirm ESC Close' -Value 1 -Type DWord
}
function Make-Fixture143 {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    foreach ($d in @('dm', 'unc')) {
        NewDir ($Root + '\' + $d)
        for ($i = 1; $i -le 5; $i++) { WriteFile ($Root + '\' + $d + '\f' + $i + '.txt') ('x' * (1000 * $i * $i)) }
    }
    return ("{0}\dm and {0}\unc, 5 files each (1 to 25 KB); unc seen as {1}\unc" -f $Root, $UncRoot)
}
function Unc-Count { return @([IO.Directory]::GetFiles($LP + $Root + '\unc')).Count }

# the map of the left panel's folder, scan finished; returns its window
function Open-Map([int]$Id) {
    $h = Open-DiskMap $Id
    $sw = [Diagnostics.Stopwatch]::StartNew(); $scan = $true
    while ($sw.Elapsed.TotalSeconds -lt 20) { $scan = Dm-Scanning $h; if ($scan -eq $false) { break }; Start-Sleep -Milliseconds 300 }
    if ($scan -ne $false) { throw ("the map did not finish its scan in 20 s (scanning: {0})" -f $scan) }
    Start-Sleep -Milliseconds 500
    return $h
}
function Map-View([IntPtr]$H) { return @([Drv098f]::Kids($H) | Where-Object { [Drv098f]::Cls($_) -eq $DmViewClass }) | Select-Object -First 1 }
function Visible-Menu([int]$Id) { return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq $MenuClass }) | Select-Object -First 1 }
# the file context menu: a right button press selects the file under the middle of the map, then
# the keyboard's context-menu request (-1, -1) opens the shell menu of the selected file
function Open-FileMenu([int]$Id, [IntPtr]$H) {
    $v = Map-View $H
    if (-not $v) { return @{ Menu = [IntPtr]::Zero; Text = 'no map view child' } }
    $r = New-Object Drv098f+RECT
    [void][Drv098f]::GetClientRect($v, [ref]$r)
    $x = [int](($r.Right - $r.Left) / 2); $y = [int](($r.Bottom - $r.Top) / 2)
    [void][Drv098f]::PostMessageW($v, 0x0204, [IntPtr]2, [IntPtr](($y -shl 16) -bor $x))   # WM_RBUTTONDOWN, MK_RBUTTON
    Start-Sleep -Milliseconds 400
    [void][Drv098f]::PostMessageW($H, 0x007B, $H, [IntPtr](-1))                            # WM_CONTEXTMENU (-1, -1)
    $sw = [Diagnostics.Stopwatch]::StartNew(); $m = $null
    while ($sw.Elapsed.TotalSeconds -lt 8 -and -not $m) { $m = Visible-Menu $Id; if (-not $m) { Start-Sleep -Milliseconds 150 } }
    if (-not $m) { return @{ Menu = [IntPtr]::Zero; Text = ("no menu after a right press at {0},{1} of the map view" -f $x, $y) } }
    Start-Sleep -Milliseconds 600   # the shell fills its part of the menu
    $hm = [IntPtr][Drv118]::SendR($m, 0x01E1, 0, 0)                                          # MN_GETHMENU
    $items = @(); if ($hm -ne [IntPtr]::Zero) { $items = @([Drv143]::Items($hm)) }
    return @{ Menu = $m; HMenu = $hm; Items = $items; Text = ("menu {0}: {1} items ({2})" -f (WinDesc $m), $items.Count, (Tail (($items | Where-Object { $_ }) -join ' | ') 160)) }
}
# chooses the shell's Delete in an open file menu; returns the window that came (or Zero)
function Menu-Delete([int]$Id, $M) {
    $idx = -1
    for ($i = 0; $i -lt $M.Items.Count; $i++) {
        $t = ($M.Items[$i] -replace '&', '') -replace "`t.*$", ''
        if ($t -match '^(Delete|Odstranit)$') { $idx = $i; break }
    }
    if ($idx -lt 0) { return @{ Win = [IntPtr]::Zero; Text = 'no Delete item in the menu' } }
    $known = Get-Tops $Id
    [void][Drv118]::SendR($M.Menu, 0x01E5, $idx, 0)                                          # MN_SELECTITEM
    Start-Sleep -Milliseconds 200
    [void][Drv098f]::PostMessageW($M.Menu, 0x0100, [IntPtr]0x0D, [IntPtr]1)                  # Enter
    $w = Wait-NewWin $Id $known 10
    if ($w -eq [IntPtr]::Zero -or [Drv098f]::Cls($w) -eq $MenuClass) { return @{ Win = [IntPtr]::Zero; Text = ("Delete (item {0}) chosen, no confirmation came; files left {1}" -f $idx, (Unc-Count)) } }
    return @{ Win = $w; Text = ("Delete (item {0}) -> {1}; its thread {2} (the map's {3})" -f $idx, (WinDesc $w), [Drv143]::Tid($w), $script:MapTid) }
}
function Open-About([int]$Id, [IntPtr]$H) {
    $known = Get-Tops $Id
    Post-Cmd $H 131   # IDM_HELP_ABOUT
    $b = Wait-NewWin $Id $known 8
    return @{ Win = $b; Text = $(if ($b -ne [IntPtr]::Zero) { 'About box ' + (WinDesc $b) } else { 'no About box' }) }
}
function Open-EscConfirm([int]$Id, [IntPtr]$H) {
    $known = Get-Tops $Id
    [void][Drv098f]::PostMessageW($H, 0x0100, [IntPtr]0x1B, [IntPtr]1)   # WM_KEYDOWN Esc (scan finished: the close confirmation)
    $b = Wait-NewWin $Id $known 8
    return @{ Win = $b; Text = $(if ($b -ne [IntPtr]::Zero) { 'confirmation ' + (WinDesc $b) } else { 'no close confirmation' }) }
}
# brings a fresh map into state $State; returns @{ Reached; Text; Win }
function Prepare-Map([int]$Id, [string]$State) {
    $h = Open-Map $Id
    $script:MapWin = $h; $script:MapTid = [Drv143]::Tid($h)
    switch ($State) {
        'none' { return @{ Reached = $true; Text = ("map '{0}', scan finished" -f (Tail ([Drv098f]::Txt($h)) 80)); Win = [IntPtr]::Zero } }
        'menu' { $m = Open-FileMenu $Id $h; return @{ Reached = ($m.Menu -ne [IntPtr]::Zero); Text = $m.Text; Win = $m.Menu } }
        'about' { $a = Open-About $Id $h; return @{ Reached = ($a.Win -ne [IntPtr]::Zero); Text = $a.Text; Win = $a.Win } }
        'esc' { $a = Open-EscConfirm $Id $h; return @{ Reached = ($a.Win -ne [IntPtr]::Zero); Text = $a.Text; Win = $a.Win } }
        'shell' {
            $m = Open-FileMenu $Id $h
            if ($m.Menu -eq [IntPtr]::Zero) { return @{ Reached = $false; Text = $m.Text; Win = [IntPtr]::Zero } }
            $d = Menu-Delete $Id $m
            return @{ Reached = ($d.Win -ne [IntPtr]::Zero); Text = ($m.Text + ' ;; ' + $d.Text); Win = $d.Win }
        }
    }
    throw "unknown state $State"
}

# E row: the program's normal exit while the map is in $State. With the shell's confirmation
# open the person has two orders: answer the confirmation first and then the core's "rejected to
# unload - force?" question Yes (E4, -ForceFirst off), or answer the core's question Yes first
# (E5: the core forces the plug-in, which terminates the map's thread inside the shell - the force
# semantics of every release; the Debug build then reports "monitored handles remained opened",
# answered No and recorded as a Debug note, as End-Row does)
function Exit-Row([string]$Name, [string]$What, [string]$State, [bool]$ForceFirst = $false) {
    if (-not (Want $Name)) { return }
    $debugNote = $false
    Out ("--- {0}: {1} (expected: the program ends cleanly)" -f $Name, $What)
    $left = $(if ($State -eq 'shell') { $UncRoot + '\unc' } else { $Root + '\dm' })
    $id = 0; $reports = Reports; $files0 = Unc-Count
    try {
        $id = Start-P $left ($Root + '\dm')
        $st = Prepare-Map $id $State
        $fatal = Fatal-Win $id
        if ($fatal) { Row $Name 'STATE' 'FAIL' ('FATAL ' + $fatal); return }
        if (-not $st.Reached) { Row $Name 'STATE' 'NOT DRIVEN' ('state not reached: ' + $st.Text); return }
        Row $Name 'STATE' 'PASS' $st.Text
        $before = Get-Tops $id
        $seen = @{}; $fatalSeen = $null; $answered = @(); $script:ForceAsked = $false
        [void][Drv098f]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)   # WM_CLOSE: the normal exit
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 25 -and (Test-Alive $id)) {
            foreach ($w in @(Get-Tops $id)) {
                if ($before -contains $w) { continue }
                $k = $w.ToInt64()
                if (-not $seen.ContainsKey($k)) { $d = WinDesc $w; $seen[$k] = ('{0:N1} s {1}' -f $sw.Elapsed.TotalSeconds, $d); if ($d -match $FatalRx) { $fatalSeen = $d } }
                $full = FullText $w
                if ($full -match 'rejected to unload') { $script:ForceAsked = $true }
                if ($full -match 'rejected to unload' -and ($State -ne 'shell' -or $ForceFirst -or $answered -contains -1)) {
                    $y = Buttons $w | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
                    if ($y -and $answered -notcontains $k) { $answered += $k; Start-Sleep -Milliseconds 400; Click $y }
                }
                if ($full -match 'monitored handles remained opened' -and $answered -notcontains $k) {
                    $n = Buttons $w | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 7 } | Select-Object -First 1
                    if ($n) { $answered += $k; $debugNote = $true; Click $n }
                }
                # only after a forced unload (E5): the Debug CRT's leak report of the terminated thread
                if ($ForceFirst -and $full -match 'Detected memory leaks' -and $answered -notcontains $k) {
                    $n = Buttons $w | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2 } | Select-Object -First 1
                    if ($n) { $answered += $k; $debugNote = $true; Click $n }
                }
            }
            # E4, the person: the shell's confirmation stays 3 s after the exit request, then No
            if ($State -eq 'shell' -and -not $ForceFirst -and $sw.Elapsed.TotalSeconds -ge 3 -and $st.Win -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($st.Win) -and $answered -notcontains -1) {
                $answered += -1
                $no = Buttons $st.Win | Where-Object { @(7, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Sort-Object { -[Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
                if ($no) { Click $no } else { Close-Win $st.Win }
                $seen[-1] = ('{0:N1} s the probe answered the shell confirmation No ({1})' -f $sw.Elapsed.TotalSeconds, $(if ($no) { 'button ' + [Drv098f]::GetDlgCtrlID($no) } else { 'WM_CLOSE' }))
            }
            if ($fatalSeen) { break }
            Start-Sleep -Milliseconds 100
        }
        $alive = Test-Alive $id
        $secs = $sw.Elapsed.TotalSeconds
        if ($alive) { Kill-Mine $id; $ec = 'still running after 25 s - ended by the probe' } else { $ec = ExitCodeOf $id }
        Start-Sleep -Milliseconds 600
        $rep = @(Take-Reports $reports)
        foreach ($s in @($seen.Values)) { Out ('           shown: ' + $s) }
        $ok = (-not $alive) -and ($ec -eq '0x00000000') -and ($rep.Count -eq 0) -and (-not $fatalSeen) -and ($State -eq 'shell' -or -not $script:ForceAsked)
        $files = Unc-Count
        if ($State -eq 'shell') { $ok = $ok -and ($files -eq $files0) }
        Row $Name 'EXIT' (V $ok) ("{0}; after {1:N1} s; crash reports {2}{3}; fatal window {4}; the core's force question {7}{5}{6}" -f $ec, $secs, $rep.Count, $(if ($rep.Count) { ' [' + ($rep -join ' ;; ') + ']' } else { '' }), [bool]$fatalSeen,
                $(if ($State -eq 'shell') { ("; files in the folder {0} (before {1})" -f $files, $files0) } else { '' }), $(if ($debugNote) { '; Debug note: the leak reports of a forced unload (handles, CRT)' } else { '' }),
                $(if ($script:ForceAsked) { 'asked' } else { 'not asked' }))
        $id = 0
    }
    catch { Row $Name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Name $id $reports } }
}

# M row (review of 143): the map's own close routes - File > Exit, Esc answered Yes / No - close
# (or keep) the map and leave the program running; then the program's normal exit (End-P)
function Map-Row([string]$Name, [string]$What, [string]$Route) {
    if (-not (Want $Name)) { return }
    Out ("--- {0}: {1}" -f $Name, $What)
    $id = 0; $reports = Reports
    try {
        $id = Start-P ($Root + '\dm') ($Root + '\dm')
        $h = Open-Map $id
        $want = 'closed'
        switch ($Route) {
            'exit' { Post-Cmd $h 115; $how = 'File > Exit (115)' }   # IDM_FILE_EXIT
            'escyes' {
                $b = Open-EscConfirm $id $h
                if ($b.Win -eq [IntPtr]::Zero) { Row $Name 'STATE' 'NOT DRIVEN' $b.Text; return }
                $y = Buttons $b.Win | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1; Click $y; $how = 'Esc, confirmation Yes'
            }
            'escno' {
                $b = Open-EscConfirm $id $h
                if ($b.Win -eq [IntPtr]::Zero) { Row $Name 'STATE' 'NOT DRIVEN' $b.Text; return }
                $n = Buttons $b.Win | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 7 } | Select-Object -First 1; Click $n; $how = 'Esc, confirmation No'; $want = 'kept'
            }
        }
        Start-Sleep -Seconds 3
        $mapOpen = [Drv098f]::IsWindow($h)
        $boxes = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' } | ForEach-Object { WinDesc $_ })
        $ok = (Test-Alive $id) -and ($boxes.Count -eq 0) -and ($mapOpen -eq ($want -eq 'kept')) -and -not (Fatal-Win $id)
        Row $Name 'MAP' (V $ok) ("{0}: the map is {1} (want {2}); the program runs {3}; boxes {4}" -f $how, $(if ($mapOpen) { 'open' } else { 'closed' }), $want, (Test-Alive $id), $(if ($boxes.Count) { $boxes -join ' || ' } else { 0 }))
    }
    catch { Row $Name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Name $id $reports } }
}

# E6 (review of 143): the normal exit with the shell's confirmation open, the core's force question
# answered NO (the person keeps the program), then the shell's confirmation No: the close asked for
# was given up - the map must stay open (it closed by itself before the review fix) and the
# program runs; then the program's normal exit (End-P: the map without a loop closes)
function Keep-Row([string]$Name, [string]$What) {
    if (-not (Want $Name)) { return }
    Out ("--- {0}: {1}" -f $Name, $What)
    $id = 0; $reports = Reports; $files0 = Unc-Count
    try {
        $id = Start-P ($UncRoot + '\unc') ($Root + '\dm')
        $st = Prepare-Map $id 'shell'
        if (-not $st.Reached) { Row $Name 'STATE' 'NOT DRIVEN' ('state not reached: ' + $st.Text); return }
        Row $Name 'STATE' 'PASS' $st.Text
        $h = $script:MapWin
        [void][Drv098f]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew(); $q = $null
        while ($sw.Elapsed.TotalSeconds -lt 10 -and -not $q) {
            $q = @(Get-Tops $id | Where-Object { (FullText $_) -match 'rejected to unload' }) | Select-Object -First 1
            if (-not $q) { Start-Sleep -Milliseconds 100 }
        }
        if (-not $q) { Row $Name 'QUESTION' 'FAIL' 'the core did not ask about the plug-in that does not unload'; return }
        $n = Buttons $q | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 7 } | Select-Object -First 1; Click $n
        Start-Sleep -Milliseconds 1500
        $no = Buttons $st.Win | Where-Object { @(7, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Sort-Object { -[Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
        if ($no) { Click $no } else { Close-Win $st.Win }
        Start-Sleep -Seconds 3
        $mapOpen = [Drv098f]::IsWindow($h)
        $ok = (Test-Alive $id) -and $mapOpen -and ((Unc-Count) -eq $files0) -and -not (Fatal-Win $id)
        Row $Name 'KEPT' (V $ok) ("force question answered No, then the shell's No: the program runs {0}; the map is open {1}; files {2} (before {3})" -f (Test-Alive $id), $mapOpen, (Unc-Count), $files0)
    }
    catch { Row $Name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Name $id $reports } }
}

# U row: an installer's close while the map is in $State (always expected: decline)
function Rm-Row([string]$Name, [string]$What, [string]$State) {
    if (-not (Want $Name)) { return }
    $left = $(if ($State -eq 'shell') { $UncRoot + '\unc' } else { $Root + '\dm' })
    $files0 = Unc-Count
    Run-Row $Name $What $left $false $false {
        param($id)
        $st = Prepare-Map $id $State
        $script:RowWin = $st.Win
        $work = $null
        if ($State -eq 'shell') {
            $work = {
                param($id, $agreed)
                $w = $script:RowWin; $open = [Drv098f]::IsWindow($w)
                if ($open) { $no = Buttons $w | Where-Object { @(7, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Sort-Object { -[Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($no) { Click $no } else { Close-Win $w }; Start-Sleep -Milliseconds 800 }
                $n = Unc-Count
                return @{ Ok = ($open -and $n -eq $files0); Text = ("the shell confirmation was still open {0} (answered No by the probe); files {1} (before {2})" -f $open, $n, $files0) }
            }
        }
        return @{ Reached = $st.Reached; State = $st.Text; Work = $work }
    } ($Root + '\dm')
}

# ---- feature 211 ------------------------------------------------------------------------------
function Make-Fixture211 {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    $deep = $Root + '\deep\' + ('a' * 200) + '\' + ('b' * 200) + '\' + ('c' * 240)
    NewDir $deep
    $script:DeepName = ('f' * 110) + '.bin'
    WriteFile ($deep + '\' + $script:DeepName) ('x' * 50000)
    $script:DeepDir = $deep
    NewDir ($Root + '\ctl')
    NewDir ($Root + '\unc')   # Menu-Delete (143) counts its files
    WriteFile ($Root + '\ctl\big.bin') ('x' * 50000)
    $full = ($deep + '\' + $script:DeepName).Length
    return ("deep folder {0} bytes, the file's full name {1} bytes; ctl\big.bin" -f $deep.Length, $full)
}
function Deep-Row([string]$Name, [string]$What, [string]$Folder, [string]$File) {
    if (-not (Want $Name)) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P $Root   # a long path on the command line is not taken: Change Directory
        [void](Do-ChangeDir $id $Folder); Start-Sleep -Milliseconds 600; Sync $id
        $h = Open-Map $id
        $m = Open-FileMenu $id $h
        $kept = { [IO.File]::Exists($LP + $Folder + '\' + $File) }
        if ($m.Menu -eq [IntPtr]::Zero) {
            $ok = ($Name -ne 'ctl') -and (& $kept)
            Row $Name 'RUN' (V $ok) ("{0}: no file menu ({1}); the file still there {2}" -f $What, $m.Text, (& $kept))
            return
        }
        $d = Menu-Delete $id $m
        $text = $(if ($d.Win -ne [IntPtr]::Zero) { WinDesc $d.Win } else { $d.Text })
        if ($d.Win -ne [IntPtr]::Zero) {
            $no = Buttons $d.Win | Where-Object { @(7, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Sort-Object { -[Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($no) { Click $no } else { Close-Win $d.Win }
            Start-Sleep -Milliseconds 800
        }
        $aboutFolder = $text -match 'slo\\u017Eku|folder|adres\\u00E1\\u0159'
        $aboutFile = $text -match 'soubor|file'
        # a confirmation about the file (answered No: the file kept), or none at all and exactly that file gone
        $deletedRight = ($d.Win -eq [IntPtr]::Zero) -and -not (& $kept) -and [IO.Directory]::Exists($LP + $Folder)
        $ok = (-not $aboutFolder) -and (($aboutFile -and (& $kept)) -or $deletedRight) -and [IO.Directory]::Exists($LP + $Folder)
        Row $Name 'RUN' (V $ok) ("{0}: the Delete confirmation is about a folder {1}, about a file {2}; the file still there {3}; {4}" -f $What, $aboutFolder, $aboutFile, (& $kept), (Tail $text 300))
    }
    catch { Row $Name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Name $id $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc211_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    $fx = Make-Fixture211
    Set-Config
    Set-DmConfirm
    $script:HotKeyNote = Set-HotKeys
    Out ("diskmap_long_probe (feature 211), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; registry key existed {2}; export SHA-256 {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $deskName, $existed, $regHash)
    Out ("Fixture : {0}" -f $fx)
    Out ("Hot keys: {0}" -f $script:HotKeyNote)
    Out ''
    Deep-Row 'ctl' 'a short folder' ($Root + '\ctl') 'big.bin'
    Deep-Row 'deep' 'a file whose full name has ~804 bytes' $script:DeepDir $script:DeepName
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
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
