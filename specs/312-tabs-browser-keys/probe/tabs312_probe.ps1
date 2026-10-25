<#
.SYNOPSIS
    Feature 312 probe: the classic and the browser-like tab shortcuts (panel and command line),
    Reopen Closed Tab, the Tabs toggle, the Tabs configuration page and the remembered page of an
    older configuration.

.DESCRIPTION
    Fixture %TEMP%\tc312\R with the folders A B C D (A holds the folder "sub" and a file) and, beside
    them, more folders E..M for the cap row. The left panel starts in R; before each start the stored
    tab lists of both panels are removed, so every run starts with one tab per panel.

    State is read from the program itself: Options > Save Configuration (posted) writes the tab list
    of the left panel (HKCU\Software\Tandem Commander\Settings\Left Panel\Tabs\<n>\Path, Sort Type,
    Active Tab), which the probe reads after the instance went idle.

    Keys with Ctrl / Shift: the probe attaches its thread to the program's input queue
    (AttachThreadInput), sets the modifiers in the shared key state (SetKeyboardState) and SENDS
    WM_KEYDOWN + WM_KEYUP to the panel list or to the command line's edit (the technique of
    specs/093-unicode-dialogs/probe/cmdline_probe.ps1). No SendInput: no real keyboard - the person
    step owes the real keys.

    Runs (one program start each):
      CLASSIC  option off: each key of the decision table in the panel and in the command line; the
               Tabs toggle (Options > Show > Tabs) with two tabs: No keeps them, Yes turns tabs off
      BROWSER  option on: the keys in the panel and the command line, Reopen after Close Other Tabs
               (order and sort), Reopen with nothing closed, the cap of 10, tabs off -> classic keys
      LASTPG   a configuration without "Browser Tab Shortcuts" remembering page 8 (Keyboard in
               0.1.10): Configuration opens Keyboard
      PAGE     the Tabs page: list rows (classic), the option clicked -> browser rows at once, tabs
               unchecked -> option and list disabled; Cancel
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

if (-not ('Tc312' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Tc312
{
    [StructLayout(LayoutKind.Sequential)] public struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public int x, y; }
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] public static extern bool GetKeyboardState(byte[] s);
    [DllImport("user32.dll")] public static extern bool SetKeyboardState(byte[] s);
    [DllImport("user32.dll")] public static extern bool PeekMessageW(out MSG m, IntPtr h, uint a, uint b, uint remove);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, IntPtr size, uint type, uint protect);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern bool VirtualFreeEx(IntPtr p, IntPtr a, IntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern bool WriteProcessMemory(IntPtr p, IntPtr a, byte[] b, IntPtr size, out IntPtr written);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, IntPtr size, out IntPtr read);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);

    // WM_KEYDOWN + WM_KEYUP sent to 'h' while the shared key state says Ctrl / Shift are down
    public static string KeyMods(IntPtr h, int vk, bool ctrl, bool shift, uint timeout)
    {
        uint pid; uint tid = GetWindowThreadProcessId(h, out pid); uint me = GetCurrentThreadId();
        MSG m; PeekMessageW(out m, IntPtr.Zero, 0, 0, 0);
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed";
        string err = "";
        try
        {
            var old = new byte[256];
            GetKeyboardState(old);
            var st = (byte[])old.Clone();
            foreach (int k in new int[] { 0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5 }) st[k] = 0;
            var clean = (byte[])st.Clone();
            if (ctrl) { st[0x11] = 0x80; st[0xA2] = 0x80; }
            if (shift) { st[0x10] = 0x80; st[0xA0] = 0x80; }
            if (!SetKeyboardState(st)) err = "SetKeyboardState failed";
            else
            {
                IntPtr res;
                if (SendMessageTimeoutW(h, 0x0100, (IntPtr)vk, (IntPtr)1, 0, timeout, out res) == IntPtr.Zero) err = "WM_KEYDOWN timed out";
                SendMessageTimeoutW(h, 0x0101, (IntPtr)vk, (IntPtr)unchecked((int)0xC0000001), 0, timeout, out res);
            }
            SetKeyboardState(clean);
        }
        finally { AttachThreadInput(me, tid, false); }
        return err;
    }

    // the text of a list view item of another process (LVM_GETITEMTEXTW through its memory)
    public static string LvText(IntPtr list, int item, int sub)
    {
        uint pid; GetWindowThreadProcessId(list, out pid);
        IntPtr p = OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid);
        if (p == IntPtr.Zero) return "<OpenProcess failed>";
        IntPtr mem = VirtualAllocEx(p, IntPtr.Zero, (IntPtr)4096, 0x3000, 0x04);
        try
        {
            if (mem == IntPtr.Zero) return "<VirtualAllocEx failed>";
            var lvi = new byte[0x60];
            BitConverter.GetBytes(0x1).CopyTo(lvi, 0);       // mask LVIF_TEXT
            BitConverter.GetBytes(item).CopyTo(lvi, 4);
            BitConverter.GetBytes(sub).CopyTo(lvi, 8);
            BitConverter.GetBytes(mem.ToInt64() + 0x100).CopyTo(lvi, 24); // pszText
            BitConverter.GetBytes(1000).CopyTo(lvi, 32);       // cchTextMax
            IntPtr n;
            WriteProcessMemory(p, mem, lvi, (IntPtr)lvi.Length, out n);
            IntPtr res;
            SendMessageTimeoutW(list, 0x1073, (IntPtr)item, mem, 0, 10000, out res); // LVM_GETITEMTEXTW
            int len = (int)res.ToInt64(); if (len < 0) len = 0; if (len > 1000) len = 1000;
            var buf = new byte[len * 2];
            ReadProcessMemory(p, (IntPtr)(mem.ToInt64() + 0x100), buf, (IntPtr)buf.Length, out n);
            return Encoding.Unicode.GetString(buf);
        }
        finally
        {
            if (mem != IntPtr.Zero) VirtualFreeEx(p, mem, IntPtr.Zero, 0x8000);
            CloseHandle(p);
        }
    }
    public static int LvCount(IntPtr list)
    {
        IntPtr res;
        SendMessageTimeoutW(list, 0x1004, IntPtr.Zero, IntPtr.Zero, 0, 10000, out res); // LVM_GETITEMCOUNT
        return (int)res.ToInt64();
    }
}
'@
}

$Root = $TempRoot + '\tc312'
$R = $Root + '\R'
$StartDir = $Root + '\start'
$Cfg = 'HKCU:\Software\Tandem Commander\Settings\Configuration'
$CfgReg = $RegKey + '\Settings\Configuration'
$LeftKey = 'HKCU:\Software\Tandem Commander\Settings\Left Panel'

# commands (src/resource.rh2)
$CM_SAVECONFIG = 687; $CM_CONFIGURATION = 686; $CM_EDITLINE = 745; $CM_TOGGLEEDITLINE = 746
$CM_ACTIVESIZE = 703; $CM_LEFT_CLOSEOTHERTABS = 2876; $CM_TOGGLEPANELTABS = 2884
$VK_T = 0x54; $VK_W = 0x57; $VK_G = 0x47; $VK_NEXT = 0x22; $VK_PRIOR = 0x21; $VK_HOME = 0x24; $VK_DOWN = 0x28; $VK_RETURN = 0x0D

function Prep-Registry([int]$BrowserKeys, [int]$Lfp) {
    # one tab per panel at start; English; no exit question; command line shown
    & cmd.exe /c "reg query `"$CfgReg`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    Set-Config
    foreach ($p in @('Left Panel', 'Right Panel')) { & cmd.exe /c "reg delete `"$RegKey\Settings\$p\Tabs`" /f >nul 2>&1" }
    & reg.exe add $CfgReg /v 'Panel Tabs' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add $CfgReg /v 'Command Line' /t REG_DWORD /d 1 /f | Out-Null
    if ($BrowserKeys -lt 0) { & cmd.exe /c "reg delete `"$CfgReg`" /v `"Browser Tab Shortcuts`" /f >nul 2>&1" }
    else { & reg.exe add $CfgReg /v 'Browser Tab Shortcuts' /t REG_DWORD /d $BrowserKeys /f | Out-Null }
    if ($Lfp -ge 0) { & reg.exe add $CfgReg /v 'Last Focused Page' /t REG_DWORD /d $Lfp /f | Out-Null }
    return $true
}

function List([int]$Id) { return (Get-LeftList $Id) }
function KeyM([int]$Id, [int]$Vk, [bool]$Ctrl, [bool]$Shift) {
    $e = [Tc312]::KeyMods((List $Id), $Vk, $Ctrl, $Shift, 30000)
    if ($e) { throw "key not driven: $e" }
    Start-Sleep -Milliseconds 250
    [void](Serve $Id 10)
}
function CmdEdit([int]$Id) {
    $main = Get-Main $Id
    $cb = @([Drv098f]::Kids($main) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 955 -and [Drv098f]::Cls($_) -eq 'ComboBox' }) | Select-Object -First 1
    if (-not $cb) { throw 'no command line (ComboBox id 955)' }
    $ed = @([Drv098f]::Kids($cb) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' }) | Select-Object -First 1
    if (-not $ed) { throw 'the command line has no inner Edit' }
    return $ed
}
function KeyC([int]$Id, [int]$Vk, [bool]$Ctrl, [bool]$Shift) {
    $e = [Tc312]::KeyMods((CmdEdit $Id), $Vk, $Ctrl, $Shift, 30000)
    if ($e) { throw "key not driven: $e" }
    Start-Sleep -Milliseconds 250
    [void](Serve $Id 10)
}
function FocusItem([int]$Id, [int]$Downs) {
    Key $Id $VK_HOME
    for ($i = 0; $i -lt $Downs; $i++) { Key $Id $VK_DOWN }
}
# Options > Save Configuration, then the left panel's tabs as written
function Snap([int]$Id) {
    Post-Cmd (Get-Main $Id) $CM_SAVECONFIG
    Start-Sleep -Milliseconds 400
    [void](Serve $Id 15)
    $tabs = @()
    if (Test-Path -LiteralPath "$LeftKey\Tabs") {
        $keys = @(Get-ChildItem -LiteralPath "$LeftKey\Tabs" | Sort-Object { [int]$_.PSChildName })
        foreach ($k in $keys) {
            $p = Get-ItemProperty -LiteralPath $k.PSPath
            $tabs += [pscustomobject]@{ Path = [string]$p.Path; Sort = [int]$p.'Sort Type' }
        }
    }
    $active = [int](Get-ItemProperty -LiteralPath $LeftKey).'Active Tab'
    $panelPath = [string](Get-ItemProperty -LiteralPath $LeftKey).Path
    $tabsOn = [int](Get-ItemProperty -LiteralPath $Cfg).'Panel Tabs'
    return [pscustomobject]@{ Count = $tabs.Count; Active = $active; Tabs = $tabs; PanelPath = $panelPath; TabsOn = $tabsOn }
}
function Leaf([string]$p) { if (-not $p) { return '' }; $t = $p.TrimEnd('\'); $i = $t.LastIndexOf('\'); if ($i -ge 0) { return $t.Substring($i + 1) }; return $t }
function Desc($s) { return ("tabs={0} active={1} [{2}] panel={3}" -f $s.Count, $s.Active, (($s.Tabs | ForEach-Object { (Leaf $_.Path) + $(if ($_.Sort -ne 0) { '/s' + $_.Sort } else { '' }) }) -join ' '), (Leaf $s.PanelPath)) }
function ActLeaf($s) { if ($s.Count -gt 0 -and $s.Active -lt $s.Count) { return (Leaf $s.Tabs[$s.Active].Path) }; return (Leaf $s.PanelPath) }
function End-Run([int]$Id) {
    if ($Id -and (Test-Alive $Id)) {
        $f = Fatal-Win $Id
        if ($f) { Row 'RUN' 'FATAL' 'FAIL' $f }
        Kill-Mine $Id
    }
}
function Start-Run { return (Start-Tc $R) }

# ---------------------------------------------------------------------------
function Run-Classic {
    if (-not (Want 'CLASSIC')) { return }
    if (-not (Prep-Registry 0 -1)) { Row 'CLASSIC' 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run
        $s0 = Snap $id
        Row 'CLASSIC' 'START' (V ($s0.Count -eq 1 -and (Leaf $s0.PanelPath) -eq 'R')) (Desc $s0)
        # Ctrl+T / Ctrl+W / Ctrl+Shift+G: no tab (A focused: not a shortcut, Restore Selection has nothing)
        FocusItem $id 1
        KeyM $id $VK_T $true $false; KeyM $id $VK_W $true $false; KeyM $id $VK_G $true $true
        $s = Snap $id
        Row 'CLASSIC' 'C-T-W-G' (V ($s.Count -eq 1)) ('Ctrl+T, Ctrl+W, Ctrl+Shift+G in the panel open/close no tab: ' + (Desc $s))
        # Ctrl+PgDn enters the focused folder A, Ctrl+PgUp goes back up
        FocusItem $id 1
        KeyM $id $VK_NEXT $true $false
        $s = Snap $id
        Row 'CLASSIC' 'C-PGDN' (V ($s.Count -eq 1 -and (ActLeaf $s) -eq 'A')) ('Ctrl+PgDn on A: ' + (Desc $s))
        KeyM $id $VK_PRIOR $true $false
        $s = Snap $id
        Row 'CLASSIC' 'C-PGUP' (V ($s.Count -eq 1 -and (ActLeaf $s) -eq 'R')) ('Ctrl+PgUp: ' + (Desc $s))
        # Ctrl+Shift+T opens a tab, Ctrl+Shift+PgUp/PgDn switch, Ctrl+Shift+W closes
        KeyM $id $VK_T $true $true
        $s = Snap $id
        Row 'CLASSIC' 'CS-T' (V ($s.Count -eq 2 -and $s.Active -eq 1)) ('Ctrl+Shift+T: ' + (Desc $s))
        KeyM $id $VK_PRIOR $true $true
        $s = Snap $id
        Row 'CLASSIC' 'CS-PGUP' (V ($s.Count -eq 2 -and $s.Active -eq 0)) ('Ctrl+Shift+PgUp: ' + (Desc $s))
        KeyM $id $VK_NEXT $true $true
        $s = Snap $id
        Row 'CLASSIC' 'CS-PGDN' (V ($s.Count -eq 2 -and $s.Active -eq 1)) ('Ctrl+Shift+PgDn: ' + (Desc $s))
        KeyM $id $VK_W $true $true
        $s = Snap $id
        Row 'CLASSIC' 'CS-W' (V ($s.Count -eq 1)) ('Ctrl+Shift+W: ' + (Desc $s))
        # command line: Ctrl+T, Ctrl+W, Ctrl+Shift+T, Ctrl+Shift+W do nothing (as in 0.1.10)
        $ed = CmdEdit $id
        [void][Drv098f]::SetText($ed, 'abc', 5000)
        KeyC $id $VK_T $true $false; KeyC $id $VK_W $true $false; KeyC $id $VK_T $true $true; KeyC $id $VK_W $true $true
        $txt = [Drv098f]::GetText($ed, 5000)
        $s = Snap $id
        Row 'CLASSIC' 'CMDLINE' (V ($s.Count -eq 1 -and $txt -ceq 'abc')) ("Ctrl+T, Ctrl+W, Ctrl+Shift+T, Ctrl+Shift+W in the command line: text '{0}'; {1}" -f (Esc $txt), (Desc $s))
        [void][Drv098f]::SetText($ed, '', 5000)
        # Options > Show > Tabs with two tabs: the question; No keeps tabs, Yes turns them off
        KeyM $id $VK_T $true $true
        Post-Cmd (Get-Main $id) $CM_TOGGLEPANELTABS
        $r = Serve $id 15 @(7)
        $s = Snap $id
        Row 'CLASSIC' 'TOGGLE-NO' (V ($s.Count -eq 2 -and $s.TabsOn -eq 1 -and (Msgs $r) -match 'will be closed')) ("question: {0}; {1}" -f (Msgs $r), (Desc $s))
        Post-Cmd (Get-Main $id) $CM_TOGGLEPANELTABS
        $r = Serve $id 15 @(6)
        $s = Snap $id
        Row 'CLASSIC' 'TOGGLE-YES' (V ($s.TabsOn -eq 0 -and $s.Count -le 1)) ("question: {0}; {1} tabsOn={2}" -f (Msgs $r), (Desc $s), $s.TabsOn)
        Post-Cmd (Get-Main $id) $CM_TOGGLEPANELTABS
        $r = Serve $id 15 @(6)
        $s = Snap $id
        Row 'CLASSIC' 'TOGGLE-ON' (V ($s.TabsOn -eq 1 -and (Msgs $r) -eq 'no window')) ("{0} tabsOn={1}; windows: {2}" -f (Desc $s), $s.TabsOn, (Msgs $r))
    }
    catch { Row 'CLASSIC' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

function Run-Browser {
    if (-not (Want 'BROWSER')) { return }
    if (-not (Prep-Registry 1 -1)) { Row 'BROWSER' 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run
        $s0 = Snap $id
        Row 'BROWSER' 'START' (V ($s0.Count -eq 1)) (Desc $s0)
        KeyM $id $VK_T $true $true   # nothing closed yet in this run
        $s = Snap $id
        Row 'BROWSER' 'REOPEN-EMPTY' (V ($s.Count -eq 1)) ('Ctrl+Shift+T with nothing closed: ' + (Desc $s))
        FocusItem $id 1
        KeyM $id $VK_T $true $false
        $s = Snap $id
        Row 'BROWSER' 'C-T' (V ($s.Count -eq 2 -and $s.Active -eq 1)) ('Ctrl+T: ' + (Desc $s))
        FocusItem $id 1
        KeyM $id $VK_PRIOR $true $false
        $s = Snap $id
        Row 'BROWSER' 'C-PGUP' (V ($s.Count -eq 2 -and $s.Active -eq 0 -and (ActLeaf $s) -eq 'R')) ('Ctrl+PgUp: previous tab, no parent: ' + (Desc $s))
        FocusItem $id 1
        KeyM $id $VK_NEXT $true $false
        $s = Snap $id
        Row 'BROWSER' 'C-PGDN' (V ($s.Count -eq 2 -and $s.Active -eq 1 -and (ActLeaf $s) -eq 'R')) ('Ctrl+PgDn on A: next tab, A not entered: ' + (Desc $s))
        KeyM $id $VK_W $true $false
        $s = Snap $id
        Row 'BROWSER' 'C-W' (V ($s.Count -eq 1)) ('Ctrl+W: ' + (Desc $s))
        KeyM $id $VK_T $true $true
        $s = Snap $id
        Row 'BROWSER' 'CS-T' (V ($s.Count -eq 2 -and $s.Active -eq 1)) ('Ctrl+Shift+T reopens: ' + (Desc $s))
        KeyM $id $VK_PRIOR $true $true
        $s = Snap $id
        Row 'BROWSER' 'CS-PGUP' (V ($s.Count -eq 2 -and $s.Active -eq 0)) ('Ctrl+Shift+PgUp kept: ' + (Desc $s))
        KeyM $id $VK_NEXT $true $true
        $s = Snap $id
        Row 'BROWSER' 'CS-PGDN' (V ($s.Count -eq 2 -and $s.Active -eq 1)) ('Ctrl+Shift+PgDn kept: ' + (Desc $s))
        KeyM $id $VK_W $true $false

        # the command line: the same keys, the typed text kept
        $ed = CmdEdit $id
        [void][Drv098f]::SetText($ed, 'abc', 5000)
        KeyC $id $VK_T $true $false
        $s1 = Snap $id
        KeyC $id $VK_W $true $false
        $s2 = Snap $id
        KeyC $id $VK_T $true $true
        $s3 = Snap $id
        KeyC $id $VK_NEXT $true $false
        $s4 = Snap $id
        $txt = [Drv098f]::GetText($ed, 5000)
        Row 'BROWSER' 'CMDLINE' (V ($s1.Count -eq 2 -and $s2.Count -eq 1 -and $s3.Count -eq 2 -and $s3.Active -eq 1 -and $s4.Active -eq 0 -and $txt -ceq 'abc')) ("Ctrl+T -> {0}; Ctrl+W -> {1}; Ctrl+Shift+T -> {2}; Ctrl+PgDn -> active {3}; text '{4}'" -f $s1.Count, $s2.Count, $s3.Count, $s4.Active, (Esc $txt))
        [void][Drv098f]::SetText($ed, '', 5000)
        Post-Cmd (Get-Main $id) $CM_LEFT_CLOSEOTHERTABS
        [void](Serve $id 10)

        # A B C D in four tabs (C sorted by size), B active, Close Other Tabs, Reopen x3
        $names = @('A', 'B', 'C', 'D')
        for ($i = 0; $i -lt 4; $i++) {
            if ($i -gt 0) { KeyM $id $VK_T $true $false; KeyM $id 0x08 $false $false }   # new tab, Backspace up to R
            FocusItem $id ($i + 1); Key $id $VK_RETURN; [void](Serve $id 10)
            if ($i -eq 2) { Post-Cmd (Get-Main $id) $CM_ACTIVESIZE; [void](Serve $id 10) }
        }
        $s = Snap $id
        $order0 = (($s.Tabs | ForEach-Object { Leaf $_.Path }) -join '')
        Row 'BROWSER' 'SETUP4' (V ($order0 -eq 'ABCD')) (Desc $s)
        KeyM $id $VK_PRIOR $true $false; KeyM $id $VK_PRIOR $true $false   # to B
        Post-Cmd (Get-Main $id) $CM_LEFT_CLOSEOTHERTABS
        [void](Serve $id 10)
        $s = Snap $id
        Row 'BROWSER' 'CLOSEOTH' (V ($s.Count -eq 1 -and (ActLeaf $s) -eq 'B')) ('Close Other Tabs on B: ' + (Desc $s))
        KeyM $id $VK_T $true $true; KeyM $id $VK_T $true $true; KeyM $id $VK_T $true $true
        $s = Snap $id
        $order = (($s.Tabs | ForEach-Object { Leaf $_.Path }) -join '')
        $cSort = @($s.Tabs | Where-Object { (Leaf $_.Path) -eq 'C' } | ForEach-Object { $_.Sort })
        Row 'BROWSER' 'REOPEN3' (V ($order -eq 'ABCD' -and $cSort.Count -eq 1 -and $cSort[0] -ne 0 -and (ActLeaf $s) -eq 'D')) ('Ctrl+Shift+T x3: ' + (Desc $s))
        # what was closed before in this run (Ctrl+W, Close Other Tabs: two tabs on R) comes next, at index 1
        KeyM $id $VK_T $true $true
        $s = Snap $id
        Row 'BROWSER' 'REOPEN-OLDER' (V ($s.Count -eq 5 -and $s.Active -eq 1 -and (ActLeaf $s) -eq 'R')) ('the next Ctrl+Shift+T brings the tab closed before: ' + (Desc $s))

        # the cap: 12 tabs, Close Other Tabs closes 11, at most 10 come back
        Post-Cmd (Get-Main $id) $CM_LEFT_CLOSEOTHERTABS; [void](Serve $id 10)
        for ($i = 0; $i -lt 11; $i++) { KeyM $id $VK_T $true $false }
        $s = Snap $id; $n12 = $s.Count
        Post-Cmd (Get-Main $id) $CM_LEFT_CLOSEOTHERTABS; [void](Serve $id 10)
        for ($i = 0; $i -lt 12; $i++) { KeyM $id $VK_T $true $true }
        $s = Snap $id
        Row 'BROWSER' 'CAP' (V ($n12 -eq 12 -and $s.Count -eq 11)) ("12 tabs ({0}), Close Other Tabs, Ctrl+Shift+T x12 -> {1} tabs" -f $n12, $s.Count)

        # tabs off: the browser-like keys fall back to the classic ones
        Post-Cmd (Get-Main $id) $CM_LEFT_CLOSEOTHERTABS; [void](Serve $id 10)
        Post-Cmd (Get-Main $id) $CM_TOGGLEPANELTABS; [void](Serve $id 10 @(6))
        FocusItem $id 1   # the remaining tab is the reopened one on R (REOPEN-OLDER)
        $e = [Tc312]::KeyMods((List $id), $VK_T, $true, $false, 30000); Start-Sleep -Milliseconds 250
        $r = Serve $id 10
        $s1 = Snap $id
        FocusItem $id 1
        KeyM $id $VK_NEXT $true $false
        $s = Snap $id
        Row 'BROWSER' 'TABS-OFF' (V ($s.TabsOn -eq 0 -and $s1.Count -le 1 -and (Leaf $s1.PanelPath) -eq 'R' -and (Leaf $s.PanelPath) -eq 'A')) ("tabs off: Ctrl+T on A -> {0} (windows: {1}); Ctrl+PgDn on A -> panel {2}; tabsOn={3}" -f (Desc $s1), (Msgs $r), (Leaf $s.PanelPath), $s.TabsOn)
    }
    catch { Row 'BROWSER' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

function Open-Config([int]$Id) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) $CM_CONFIGURATION
    $dlg = Wait-NewWin $Id $known 15
    if ($dlg -eq [IntPtr]::Zero) { throw 'the Configuration dialog did not open' }
    Start-Sleep -Milliseconds 800
    return $dlg
}
# the caption of the visible page (pages are child dialogs with a caption)
function Visible-Page([IntPtr]$Dlg) {
    $pages = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowVisible($_) })
    return (($pages | ForEach-Object { [Drv098f]::Txt($_) }) -join '|')
}
function Ctl([IntPtr]$Dlg, [int]$CtlId) { return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1) }
function Rows-Of([IntPtr]$List) {
    $n = [Tc312]::LvCount($List)
    $out = @()
    for ($i = 0; $i -lt $n; $i++) { $out += ([Tc312]::LvText($List, $i, 0) + '=' + [Tc312]::LvText($List, $i, 1)) }
    return $out
}

function Run-LastPage {
    if (-not (Want 'LASTPG')) { return }
    if (-not (Prep-Registry -1 8)) { Row 'LASTPG' 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run
        $dlg = Open-Config $id
        $page = Visible-Page $dlg
        Row 'LASTPG' 'OPEN' (V ($page -eq 'Keyboard')) ("0.1.10 configuration remembering page 8 (Keyboard) without the new value: the dialog shows '{0}'" -f (Esc $page))
        Close-Win $dlg
    }
    catch { Row 'LASTPG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

function Run-Page {
    if (-not (Want 'PAGE')) { return }
    if (-not (Prep-Registry 0 7)) { Row 'PAGE' 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run
        $dlg = Open-Config $id
        $page = Visible-Page $dlg
        $list = Ctl $dlg 6289; $opt = Ctl $dlg 6287; $tabs = Ctl $dlg 6235
        if (-not $list -or -not $opt -or -not $tabs) { throw ("Tabs page controls not found; visible page '{0}'" -f (Esc $page)) }
        $rows = Rows-Of $list
        $expC = @('Ctrl+T=Go to Shortcut or Link Target', 'Ctrl+W=Restore Selection', 'Ctrl+Page Down=Go into the focused folder or archive', 'Ctrl+Page Up=Go to the parent folder', 'Ctrl+Shift+T=New Tab', 'Ctrl+Shift+W=Close Tab', 'Ctrl+Shift+G=(none)', 'Ctrl+Shift+Page Down=Next Tab', 'Ctrl+Shift+Page Up=Previous Tab', 'Ctrl+Tab=Move between the panel and the command line', '(none)=Reopen Closed Tab')
        Row 'PAGE' 'CLASSIC' (V ($page -eq 'Tabs' -and (($rows -join '|') -ceq ($expC -join '|')))) ("page '{0}'; rows: {1}" -f (Esc $page), (Esc ($rows -join ' | ')))
        Click $opt; Start-Sleep -Milliseconds 600
        $rows = Rows-Of $list
        $expB = @('Ctrl+T=New Tab', 'Ctrl+W=Close Tab', 'Ctrl+Page Down=Next Tab', 'Ctrl+Page Up=Previous Tab', 'Ctrl+Shift+T=Reopen Closed Tab', 'Ctrl+Shift+W=Restore Selection', 'Ctrl+Shift+G=Go to Shortcut or Link Target', 'Ctrl+Shift+Page Down=Next Tab', 'Ctrl+Shift+Page Up=Previous Tab', 'Ctrl+Tab=Move between the panel and the command line')
        Row 'PAGE' 'BROWSER' (V ((($rows -join '|') -ceq ($expB -join '|')))) ("after clicking the option: {0}" -f (Esc ($rows -join ' | ')))
        Click $tabs; Start-Sleep -Milliseconds 600
        Row 'PAGE' 'DISABLE' (V (-not [Drv098f]::IsWindowEnabled($opt) -and -not [Drv098f]::IsWindowEnabled($list))) ("tabs unchecked: option enabled={0}, list enabled={1}" -f [Drv098f]::IsWindowEnabled($opt), [Drv098f]::IsWindowEnabled($list))
        Close-Win $dlg   # Cancel: nothing stored
        [void](Serve $id 10)
        $s = Snap $id
        $bk = [int](Get-ItemProperty -LiteralPath $Cfg).'Browser Tab Shortcuts'
        Row 'PAGE' 'CANCEL' (V ($s.TabsOn -eq 1 -and $bk -eq 0)) ("after Cancel: Panel Tabs={0}, Browser Tab Shortcuts={1}" -f $s.TabsOn, $bk)
    }
    catch { Row 'PAGE' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc312_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    foreach ($n in @('A', 'B', 'C', 'D')) { NewDir ($R + '\' + $n) }
    NewDir ($R + '\A\sub')
    [IO.File]::WriteAllText($LP + $R + '\A\x.txt', 'X')
    [IO.File]::WriteAllText($LP + $R + '\C\big.txt', ('B' * 5000)); [IO.File]::WriteAllText($LP + $R + '\C\small.txt', 'S')
    Out ("tabs312_probe (feature 312) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; fixture {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, (Esc $R))
    Out ''
    Run-Classic
    Run-Browser
    Run-LastPage
    Run-Page
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
