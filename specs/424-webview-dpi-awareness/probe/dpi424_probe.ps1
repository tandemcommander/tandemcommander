<#
.SYNOPSIS
    Feature 424 probe (GitHub #29): the WebView2 viewers run per-monitor DPI aware, their browser
    process too, the program stays system aware; geometry unchanged at 100 %; WM_DPICHANGED handled.

.DESCRIPTION
    Fixture %TEMP%\tc424\files: a.txt (Code Viewer), b.md (Markdown Viewer). F3 (742) on each. Rows
    per viewer (CV, MD):
      AWARE       the viewer window and its controller window (Chrome_WidgetWin_0) awareness 2,
                  the browser process started by the program --embedded-browser-webview-dpi-awareness=2
                  and awareness 2, the program's main window and process awareness 1
                  (before the feature: viewer, controller and browser 1)
      GEOMETRY    the page window starts at the client origin and covers the client width and the
                  client height minus the status bar; with -Before <result file of the before build>
                  the GEO line (window rectangle, client size, status bar and menu bar height) is
                  identical; -Dark runs with the program's dark theme (owner-drawn viewer menus)
      DPICHANGED  WM_DPICHANGED (wParam 96/96, lParam = a rectangle 200 x 100 px smaller; Windows
                  marshals the rectangle) sent to the viewer: the window takes exactly that
                  rectangle and the page window still covers the client (before: the window keeps
                  its size)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$Before,
    [switch]$Dark,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Dpi424' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Dpi424
{
    [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, UIntPtr size, uint type, uint protect);
    [DllImport("kernel32.dll")] public static extern bool VirtualFreeEx(IntPtr p, IntPtr a, UIntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern bool WriteProcessMemory(IntPtr p, IntPtr a, int[] data, UIntPtr size, out UIntPtr written);
    [DllImport("user32.dll")] public static extern IntPtr GetDpiAwarenessContextForProcess(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll")] public static extern IntPtr GetWindowDpiAwarenessContext(IntPtr w);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr w, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr w, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr w, ref POINT p);
    [DllImport("user32.dll")] public static extern bool GetMenuBarInfo(IntPtr w, int obj, int item, ref MENUBARINFO mbi);
    [StructLayout(LayoutKind.Sequential)] public struct MENUBARINFO { public int cbSize; public RECT rcBar; public IntPtr hMenu; public IntPtr hwndMenu; public int flags; }
    [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr w);
    [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr m);
    [DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr m, uint pos, uint flags);
    // owner-drawn items of the menu bar (the viewers' dark menus, feature 037) and all items
    [StructLayout(LayoutKind.Sequential)] public struct MENUITEMINFOW { public int cbSize; public uint fMask, fType, fState, wID; public IntPtr hSubMenu, hbmpChecked, hbmpUnchecked, dwItemData, dwTypeData; public uint cch; public IntPtr hbmpItem; }
    [DllImport("user32.dll")] public static extern bool GetMenuItemInfoW(IntPtr m, uint item, bool byPos, ref MENUITEMINFOW mii);
    // MIIM_FTYPE 0x100, MFT_OWNERDRAW 0x100 (GetMenuState packs a popup's item count into the same bits)
    public static string OwnerDrawn(IntPtr w) { IntPtr m = GetMenu(w); int n = GetMenuItemCount(m), o = 0; for (int i = 0; i < n; i++) { var mi = new MENUITEMINFOW(); mi.cbSize = Marshal.SizeOf(typeof(MENUITEMINFOW)); mi.fMask = 0x100; if (GetMenuItemInfoW(m, (uint)i, true, ref mi) && (mi.fType & 0x100) != 0) o++; } return o + " of " + n; }
    public static int MenuBarHeight(IntPtr w) { var m = new MENUBARINFO(); m.cbSize = Marshal.SizeOf(typeof(MENUBARINFO)); if (!GetMenuBarInfo(w, unchecked((int)0xFFFFFFFD), 0, ref m)) return -1; return m.rcBar.B - m.rcBar.T; }
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr w, uint m, IntPtr wp, IntPtr lp, uint flags, uint ms, out IntPtr res);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    public static int ProcAware(uint pid)
    {
        IntPtr h = OpenProcess(0x1000, false, pid);
        if (h == IntPtr.Zero) return -1;
        try { return GetAwarenessFromDpiAwarenessContext(GetDpiAwarenessContextForProcess(h)); } finally { CloseHandle(h); }
    }
    public static int WinAware(IntPtr w) { return GetAwarenessFromDpiAwarenessContext(GetWindowDpiAwarenessContext(w)); }
    public static RECT Win(IntPtr w) { RECT r; GetWindowRect(w, out r); return r; }
    public static RECT Client(IntPtr w) { RECT r; GetClientRect(w, out r); return r; }
    public static POINT Origin(IntPtr w) { var p = new POINT(); ClientToScreen(w, ref p); return p; }
    // WM_DPICHANGED with lParam = a RECT: Windows marshals this message across processes (a pointer
    // into the program's memory is refused), so the rectangle lives in this process, pinned.
    public static string SendDpiChanged(IntPtr w, uint pid, int dpi, RECT r)
    {
        int[] data = new int[] { r.L, r.T, r.R, r.B };
        GCHandle g = GCHandle.Alloc(data, GCHandleType.Pinned);
        try
        {
            IntPtr lr;
            if (SendMessageTimeoutW(w, 0x02E0, (IntPtr)((dpi << 16) | dpi), g.AddrOfPinnedObject(), 0x0002, 10000, out lr) == IntPtr.Zero)
                return "SendMessageTimeout error " + Marshal.GetLastWin32Error();
            return "ok";
        }
        finally { g.Free(); }
    }
}
'@
}
$Root = $TempRoot + '\tc424'
$StartDir = $Root + '\start'
$Files = $Root + '\files'

function Child-Of([IntPtr]$W, [string]$Class) {
    $k = @([Drv098f]::Kids($W) | Where-Object { [Drv098f]::Cls($_) -eq $Class })
    if ($k.Count) { return $k[0] } else { return [IntPtr]::Zero }
}
function RectS($r) { return ('({0},{1})-({2},{3})' -f $r.L, $r.T, $r.R, $r.B) }
# the page window's rectangle relative to the viewer's client origin, and whether it covers the client
function Page-Fit([IntPtr]$W) {
    $page = Child-Of $W 'Chrome_WidgetWin_0'
    $st = Child-Of $W 'Static'
    $c = [Dpi424]::Client($W); $o = [Dpi424]::Origin($W)
    $sh = 0; if ($st -ne [IntPtr]::Zero) { $sr = [Dpi424]::Win($st); $sh = $sr.B - $sr.T }
    if ($page -eq [IntPtr]::Zero) { return @($false, 'no page window', $sh) }
    $p = [Dpi424]::Win($page)
    $x = $p.L - $o.X; $y = $p.T - $o.Y; $pw = $p.R - $p.L; $ph = $p.B - $p.T
    $ok = ($x -eq 0 -and $y -eq 0 -and $pw -eq $c.R -and $ph -eq ($c.B - $sh))
    return @($ok, ('page at ({0},{1}) {2} x {3}; client {4} x {5}; status {6}' -f $x, $y, $pw, $ph, $c.R, $c.B, $sh), $sh)
}
function Wait-Page([IntPtr]$W, [double]$Seconds = 6) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { $f = Page-Fit $W; if ($f[0]) { return $f }; Start-Sleep -Milliseconds 200 }
    return (Page-Fit $W)
}

$beforeGeo = @{}
if ($Before -and (Test-Path -LiteralPath $Before)) {
    foreach ($l in (Get-Content -LiteralPath $Before)) { if ($l -match '^GEO (\w+) (.*)$') { $beforeGeo[$Matches[1]] = $Matches[2] } }
}

$backup = Join-Path $env:TEMP 'tc424_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Files
    Set-Config
    if ($Dark) { & reg.exe add "$RegKey\Settings\Configuration" /v 'Theme Mode' /t REG_DWORD /d 1 /f | Out-Null }
    $text = ''; for ($i = 1; $i -le 300; $i++) { $text += ("line {0:D4} the quick brown fox jumps over the lazy dog`r`n" -f $i) }
    WriteFile "$Files\a.txt" $text
    WriteFile "$Files\b.md" "# Heading`r`n`r`nSome *text* for the Markdown Viewer.`r`n`r`n- one`r`n- two`r`n"
    Out ("dpi424_probe (feature 424) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; baseline {2}; theme {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $(if ($Before) { $Before } else { '-' }), $(if ($Dark) { 'Dark' } else { 'default' }))
    Out ''

    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        $main = Get-Main $id
        foreach ($v in @(@{ Tag = 'CV'; Downs = 1; Title = '*Code Viewer*' }, @{ Tag = 'MD'; Downs = 2; Title = '*Markdown Viewer*' })) {
            $tag = $v.Tag
            Key $id 0x24; for ($i = 0; $i -lt $v.Downs; $i++) { Key $id 0x28 }
            Start-Sleep -Milliseconds 400
            $w = Open-ByCmd $id 742 20
            if ($w -eq [IntPtr]::Zero -or [Drv098f]::Txt($w) -notlike $v.Title) {
                $d = '<none>'; if ($w -ne [IntPtr]::Zero) { $d = WinDesc $w; Close-Win $w }
                Row $tag 'OPEN' 'NOT DRIVEN' ('F3 opened no ' + $v.Title + ': ' + $d); continue
            }
            $fit = Wait-Page $w 10
            Start-Sleep -Seconds 2
            $fit = Page-Fit $w
            # AWARE
            $page = Child-Of $w 'Chrome_WidgetWin_0'
            $kids = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = {0}" -f $id) | Where-Object { $_.Name -eq 'msedgewebview2.exe' })
            $sw = '<no browser>'; $ba = -9
            if ($kids.Count) {
                $sw = (([regex]::Matches([string]$kids[0].CommandLine, '--embedded-browser-webview-dpi-awareness=[^ ]*') | ForEach-Object { $_.Value }) -join ' ')
                $ba = [Dpi424]::ProcAware([uint32]$kids[0].ProcessId)
            }
            $va = [Dpi424]::WinAware($w); $ca = -9; if ($page -ne [IntPtr]::Zero) { $ca = [Dpi424]::WinAware($page) }
            $ma = [Dpi424]::WinAware($main); $pa = [Dpi424]::ProcAware([uint32]$id)
            $ok = ($va -eq 2 -and $ca -eq 2 -and $kids.Count -eq 1 -and $sw -eq '--embedded-browser-webview-dpi-awareness=2' -and $ba -eq 2 -and $ma -eq 1 -and $pa -eq 1)
            Row $tag 'AWARE' (V $ok) ("viewer {0}, controller {1}; browsers {2} '{3}' awareness {4}; main window {5}, program {6}" -f $va, $ca, $kids.Count, $sw, $ba, $ma, $pa)
            # GEOMETRY
            $wr = [Dpi424]::Win($w); $c = [Dpi424]::Client($w)
            $geo = ('window {0} client {1} x {2} status {3} menubar {4}' -f (RectS $wr), $c.R, $c.B, $fit[2], [Dpi424]::MenuBarHeight($w))
            Out ("GEO {0} {1}" -f $tag, $geo)
            Out ("MENU {0} owner-drawn bar items {1}" -f $tag, [Dpi424]::OwnerDrawn($w))
            $same = $true; $cmp = 'no baseline'
            if ($beforeGeo.ContainsKey($tag)) { $same = ($beforeGeo[$tag] -eq $geo); $cmp = ("before '{0}'" -f $beforeGeo[$tag]) }
            Row $tag 'GEOMETRY' (V ($fit[0] -and $same)) ("{0}; {1}; {2}" -f $fit[1], $geo, $cmp)
            # DPICHANGED
            $want = New-Object Dpi424+RECT
            $want.L = $wr.L + 40; $want.T = $wr.T + 30; $want.R = $wr.R - 160; $want.B = $wr.B - 70
            $sent = [Dpi424]::SendDpiChanged($w, [uint32]$id, 96, $want)
            Start-Sleep -Milliseconds 800
            $got = [Dpi424]::Win($w)
            $fit2 = Wait-Page $w 6
            $ok = ($sent -eq 'ok' -and $got.L -eq $want.L -and $got.T -eq $want.T -and $got.R -eq $want.R -and $got.B -eq $want.B -and $fit2[0])
            Row $tag 'DPICHANGED' (V $ok) ("sent {0}; wanted {1}, window {2}; {3}" -f $sent, (RectS $want), (RectS $got), $fit2[1])
            Close-Win $w
            $t = [Diagnostics.Stopwatch]::StartNew(); while ($t.Elapsed.TotalSeconds -lt 6 -and [Drv098f]::IsWindow($w)) { Start-Sleep -Milliseconds 150 }
        }
    }
    catch { Row 'RUN' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'RUN' $id $null $before } }
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
