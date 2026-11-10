<#
.SYNOPSIS
    Feature 413 probe (backlog item panel-tabs-drag-to-first-place-and-dark-strip-height): a panel
    tab dragged to the strip's left end takes the first place; the tab strip has the same height
    and look in the default and the dark theme.

.DESCRIPTION
    Runs (one program start each):
      FIRST     left A B C D (A active), right P Q R S (P active):
                LEFT      D dragged far past the left end of the left strip  -> D A B C
                NEAR      C (now index 3) dragged 1.4 tab widths left        -> D A C B (control:
                          the centre-over-centre rule still holds in the middle)
                RIGHT     S dragged far past the left end of the right strip -> S P Q R
                RIGHTEND  P (now index 1) dragged far past the right end     -> S Q R P (control)
                AGAIN     B (index 3) dragged to the left end                -> B D A C
                (the press activates the pressed tab, so the dragged tab is the active one)
      SCROLLED  left T00..T29 with T29 active (the strip shows a run of the last tabs,
                FirstVisible > 0): T29 dragged to the left end -> it takes the run's first place
                (index 30 - visible count), the other tabs keep their order.
      THEME     a start in the default theme and one in the dark theme, same tabs, the main
                window activated (WM_NCACTIVATE TRUE: the left panel is the active one, the right
                the inactive one): per panel the strip's and directory line's heights, the rows
                the active tab's fill covers and the colours above, in and under the strip; the
                main window's client area is saved to captures_<Label>\theme_<theme>_main.png.
                HEIGHT-<panel> passes when both themes give the same strip and directory line
                height and the same active-tab rows. LOOK-<theme>-<panel> passes when the active
                tab's fill differs from the strip and from the directory line's top row by at
                least 24 in the largest channel (the default theme's weakest pair is 31).
                TITLE-<theme>-<panel> passes when the title's most contrasting pixel has at least
                4.5:1 against the active tab's fill (review 2 of 413).
    State is read from the program itself: Options > Save Configuration (posted) writes both
    panels' tab lists. Drags are posted WM_LBUTTONDOWN / WM_MOUSEMOVE (MK_LBUTTON) / WM_LBUTTONUP.
    NOT DRIVEN: the feel of a real mouse drag (a release-checklist line).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label = 'after',
    [string]$OutFile,
    [string]$RepoRoot,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $RepoRoot 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
Add-Type -AssemblyName System.Drawing

if (-not ('Tc413' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Tc413
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int x, y; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct LOGFONTW
    {
        public int lfHeight, lfWidth, lfEscapement, lfOrientation, lfWeight;
        public byte lfItalic, lfUnderline, lfStrikeOut, lfCharSet, lfOutPrecision, lfClipPrecision, lfQuality, lfPitchAndFamily;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string lfFaceName;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct TEXTMETRICW
    {
        public int tmHeight, tmAscent, tmDescent, tmInternalLeading, tmExternalLeading, tmAveCharWidth, tmMaxCharWidth,
            tmWeight, tmOverhang, tmDigitizedAspectX, tmDigitizedAspectY;
        public char tmFirstChar, tmLastChar, tmDefaultChar, tmBreakChar;
        public byte tmItalic, tmUnderlined, tmStruckOut, tmPitchAndFamily, tmCharSet;
    }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, System.Text.StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static void SendRaw(IntPtr h, uint msg, IntPtr wp, IntPtr lp) { IntPtr r; SendMessageTimeoutW(h, msg, wp, lp, 0, 10000, out r); }
    [DllImport("user32.dll")] public static extern int GetDpiForWindow(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool SystemParametersInfoW(uint a, uint b, ref LOGFONTW lf, uint c);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateFontIndirectW(ref LOGFONTW lf);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern bool GetTextMetricsW(IntPtr dc, out TEXTMETRICW tm);

    // the visible child windows of 'main' with control id 958 (IDC_TABSTRIP), left first
    public static IntPtr[] Strips(IntPtr main)
    {
        var list = new List<IntPtr>();
        EnumChildWindows(main, (h, l) => { if (GetDlgCtrlID(h) == 958 && IsWindowVisible(h)) list.Add(h); return true; }, IntPtr.Zero);
        list.Sort((a, b) => { RECT ra, rb; GetWindowRect(a, out ra); GetWindowRect(b, out rb); return ra.left.CompareTo(rb.left); });
        return list.ToArray();
    }
    // every visible child of 'main': "class id left,top,width x height" (screen coordinates relative to main's client)
    public static string[] Children(IntPtr main)
    {
        var list = new List<string>();
        POINT o; o.x = 0; o.y = 0; ClientToScreen(main, ref o);
        EnumChildWindows(main, (h, l) =>
        {
            if (!IsWindowVisible(h)) return true;
            var sb = new System.Text.StringBuilder(128); GetClassNameW(h, sb, 128);
            RECT r; GetWindowRect(h, out r);
            list.Add(string.Format("{0} id {1} at {2},{3} size {4}x{5}", sb, GetDlgCtrlID(h), r.left - o.x, r.top - o.y, r.right - r.left, r.bottom - r.top));
            return true;
        }, IntPtr.Zero);
        return list.ToArray();
    }
    public static int[] ClientSize(IntPtr h) { RECT r; GetClientRect(h, out r); return new int[] { r.right, r.bottom }; }
    public static int[] OffsetIn(IntPtr main, IntPtr h)
    {
        POINT o; o.x = 0; o.y = 0; ClientToScreen(main, ref o);
        POINT p; p.x = 0; p.y = 0; ClientToScreen(h, ref p);
        return new int[] { p.x - o.x, p.y - o.y };
    }
    public static int[] FontMetrics()
    {
        LOGFONTW lf = new LOGFONTW();
        SystemParametersInfoW(0x1F, (uint)Marshal.SizeOf(typeof(LOGFONTW)), ref lf, 0);
        IntPtr f = CreateFontIndirectW(ref lf);
        IntPtr dc = GetDC(IntPtr.Zero);
        IntPtr old = SelectObject(dc, f);
        TEXTMETRICW tm; GetTextMetricsW(dc, out tm);
        SelectObject(dc, old); ReleaseDC(IntPtr.Zero, dc); DeleteObject(f);
        return new int[] { tm.tmHeight, tm.tmAveCharWidth };
    }
    public static IntPtr LP(int x, int y) { return (IntPtr)(((y & 0xFFFF) << 16) | (x & 0xFFFF)); }
    public static void Post(IntPtr h, uint msg, int wp, int x, int y) { PostMessageW(h, msg, (IntPtr)wp, LP(x, y)); }
    public static Bitmap Capture(IntPtr h, uint flags)
    {
        int[] s = ClientSize(h);
        var bmp = new Bitmap(Math.Max(1, s[0]), Math.Max(1, s[1]), PixelFormat.Format32bppRgb);
        using (var g = Graphics.FromImage(bmp))
        {
            IntPtr dc = g.GetHdc();
            PrintWindow(h, dc, flags);
            g.ReleaseHdc(dc);
        }
        return bmp;
    }
    public static int Pixel(Bitmap b, int x, int y) { return b.GetPixel(x, y).ToArgb() & 0xFFFFFF; }
    static double Lin(int c) { double v = c / 255.0; return v <= 0.04045 ? v / 12.92 : Math.Pow((v + 0.055) / 1.055, 2.4); }
    static double Lum(int rgb) { return 0.2126 * Lin((rgb >> 16) & 255) + 0.7152 * Lin((rgb >> 8) & 255) + 0.0722 * Lin(rgb & 255); }
    // WCAG 2 contrast ratio of two RRGGBB values
    public static double Contrast(int a, int b) { double x = Lum(a) + 0.05, y = Lum(b) + 0.05; return x > y ? x / y : y / x; }
    // the pixel of the rectangle that contrasts most with 'fill' (the title's own colour), "RRGGBB|ratio"
    public static string MostContrasting(Bitmap b, int x0, int y0, int x1, int y1, int fill)
    {
        int best = fill; double r = 1.0;
        for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) { int p = Pixel(b, x, y); double c = Contrast(p, fill); if (c > r) { r = c; best = p; } }
        return best.ToString("X6") + "|" + r.ToString("F2", System.Globalization.CultureInfo.InvariantCulture);
    }
    // the colours of column x from row 0 down, as "RRGGBBxN" runs
    public static string Column(Bitmap b, int x)
    {
        var parts = new List<string>();
        int prev = -1, n = 0;
        for (int y = 0; y < b.Height; y++)
        {
            int p = Pixel(b, x, y);
            if (p == prev) { n++; continue; }
            if (prev >= 0) parts.Add(string.Format("{0:X6}x{1}", prev, n));
            prev = p; n = 1;
        }
        if (prev >= 0) parts.Add(string.Format("{0:X6}x{1}", prev, n));
        return string.Join(" ", parts.ToArray());
    }
}
'@
}

$Root = $TempRoot + '\tc413'
$StartDir = $Root + '\start'
$CapDir = Join-Path $PSScriptRoot ('captures_' + $Label)
$CfgReg = $RegKey + '\Settings\Configuration'
$KeyL = 'HKCU:\Software\Tandem Commander\Settings\Left Panel'
$KeyR = 'HKCU:\Software\Tandem Commander\Settings\Right Panel'
$CM_SAVECONFIG = 687
$WM_MOUSEMOVE = 0x0200; $WM_LBUTTONDOWN = 0x0201; $WM_LBUTTONUP = 0x0202
$MK_LBUTTON = 1

function Prep-Registry([int]$Theme, $LeftTabs, [int]$LeftActive, $RightTabs, [int]$RightActive) {
    & cmd.exe /c "reg query `"$CfgReg`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    Set-Config
    & reg.exe add $CfgReg /v 'Panel Tabs' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add $CfgReg /v 'Theme Mode' /t REG_DWORD /d $Theme /f | Out-Null
    & reg.exe add $CfgReg /v 'Panel Tab Style' /t REG_DWORD /d 1 /f | Out-Null # feature 423: these rows test the rounded look (Square is the default since 423)
    foreach ($side in @(@('Left Panel', $LeftTabs, $LeftActive), @('Right Panel', $RightTabs, $RightActive))) {
        $p = $side[0]; $tabs = @($side[1]); $act = $side[2]
        & cmd.exe /c "reg delete `"$RegKey\Settings\$p\Tabs`" /f >nul 2>&1"
        for ($i = 0; $i -lt $tabs.Count; $i++) {
            $k = "$RegKey\Settings\$p\Tabs\$i"
            & reg.exe add $k /v 'Path' /t REG_SZ /d $tabs[$i] /f | Out-Null
            & reg.exe add $k /v 'View Type' /t REG_DWORD /d 2 /f | Out-Null
            & reg.exe add $k /v 'Sort Type' /t REG_DWORD /d 0 /f | Out-Null
            & reg.exe add $k /v 'Reverse Sort' /t REG_DWORD /d 0 /f | Out-Null
            & reg.exe add $k /v 'Enable Filter' /t REG_DWORD /d 0 /f | Out-Null
            & reg.exe add $k /v 'Filter' /t REG_SZ /d '*.*' /f | Out-Null
        }
        & reg.exe add "$RegKey\Settings\$p" /v 'Active Tab' /t REG_DWORD /d $act /f | Out-Null
    }
    return $true
}
function Start-Run([string]$Left, [string]$Right) {
    $a = @('-t', 'T413', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2000
    [void](Serve $p.Id 10)
    return $p.Id
}
function End-Run([int]$Id) {
    if ($Id -and (Test-Alive $Id)) {
        $f = Fatal-Win $Id
        if ($f) { Row 'RUN' 'FATAL' 'FAIL' $f }
        Kill-Mine $Id
    }
}
function Strips([int]$Id) {
    $s = @([Tc413]::Strips((Get-Main $Id)))
    if ($s.Count -lt 2) { throw ('{0} tab strip(s) (child id 958) found, 2 expected' -f $s.Count) }
    return $s
}
function Snap([int]$Id) {
    Post-Cmd (Get-Main $Id) $CM_SAVECONFIG
    Start-Sleep -Milliseconds 400
    [void](Serve $Id 15)
    $res = @{}
    foreach ($side in @(@('L', $KeyL), @('R', $KeyR))) {
        $tabs = @()
        if (Test-Path -LiteralPath "$($side[1])\Tabs") {
            foreach ($k in @(Get-ChildItem -LiteralPath "$($side[1])\Tabs" | Sort-Object { [int]$_.PSChildName })) { $tabs += [string](Get-ItemProperty -LiteralPath $k.PSPath).Path }
        }
        $res[$side[0]] = [pscustomobject]@{ Tabs = $tabs; Active = [int](Get-ItemProperty -LiteralPath $side[1]).'Active Tab' }
    }
    return [pscustomobject]$res
}
function Leaf([string]$p) { if (-not $p) { return '' }; $t = $p.TrimEnd('\'); $i = $t.LastIndexOf('\'); if ($i -ge 0) { return $t.Substring($i + 1) }; return $t }
function Order($side) { return (($side.Tabs | ForEach-Object { Leaf $_ }) -join ' ') }
function Desc($s) { return ("left [{0}] active {1}; right [{2}] active {3}" -f (Order $s.L), $s.L.Active, (Order $s.R), $s.R.Active) }

# the strip geometry as CTabWindow::Layout lays it out at 100 % (TabsLeft 8, square buttons of the
# strip's height, min / max tab width from SalTabStripWidths with a 16-px icon)
function Geo([IntPtr]$Hs, [int]$Count) {
    $sz = [Tc413]::ClientSize($Hs); $W = $sz[0]; $H = $sz[1]
    $avg = ([Tc413]::FontMetrics())[1]
    $fixed = 2 * 10 + 8 + 6 + 16
    $minW = 6 * $avg + $fixed; $maxW = 20 * $avg + $fixed
    $left = 8
    $avail = [Math]::Max(0, $W - $left - $H - 2)
    $tw = [Math]::Floor($avail / $Count); if ($tw -gt $maxW) { $tw = $maxW }
    $vc = $Count
    if ($tw -lt $minW) { $room = [Math]::Max(0, $avail - $H - 2); $tw = $minW; $vc = [Math]::Max(1, [Math]::Floor($room / $minW)); if ($vc -gt $Count) { $vc = $Count } }
    return [pscustomobject]@{ W = $W; H = $H; Left = $left; TabW = [int]$tw; Visible = [int]$vc; MidY = [int]((3 + $H) / 2) }
}
# the centre of the visible slot i (0 = the first visible tab)
function TabCx($g, [int]$i) { return [int]($g.Left + $i * $g.TabW + $g.TabW / 2) }

# a posted drag: press at X0, 12 moves to X1, release there
function Drag([IntPtr]$Hs, $g, [int]$X0, [int]$X1) {
    [Tc413]::Post($Hs, $WM_LBUTTONDOWN, $MK_LBUTTON, $X0, $g.MidY)
    Start-Sleep -Milliseconds 120
    for ($i = 1; $i -le 12; $i++) { [Tc413]::Post($Hs, $WM_MOUSEMOVE, $MK_LBUTTON, [int]($X0 + ($X1 - $X0) * $i / 12), $g.MidY); Start-Sleep -Milliseconds 30 }
    Start-Sleep -Milliseconds 100
    [Tc413]::Post($Hs, $WM_LBUTTONUP, 0, $X1, $g.MidY)
    Start-Sleep -Milliseconds 700
}

# ---------------------------------------------------------------------------
function Run-First {
    if (-not (Want 'FIRST')) { return }
    $F = $Root + '\first'
    if (-not (Prep-Registry 0 @("$F\A", "$F\B", "$F\C", "$F\D") 0 @("$F\P", "$F\Q", "$F\R", "$F\S") 0)) { Row 'FIRST' 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run "$F\A" "$F\P"
        $hs = Strips $id; $L = $hs[0]; $R = $hs[1]
        $gl = Geo $L 4; $gr = Geo $R 4
        $s = Snap $id
        Row 'FIRST' 'START' (V ((Order $s.L) -eq 'A B C D' -and (Order $s.R) -eq 'P Q R S')) ("{0}; left strip {1}x{2} tab width {3}; right strip {4}x{5} tab width {6}" -f (Desc $s), $gl.W, $gl.H, $gl.TabW, $gr.W, $gr.H, $gr.TabW)
        Drag $L $gl (TabCx $gl 3) ((TabCx $gl 0) - 2 * $gl.TabW)
        $s = Snap $id
        Row 'FIRST' 'LEFT' (V ((Order $s.L) -eq 'D A B C' -and $s.L.Active -eq 0)) ('left: D dragged far past the left end: ' + (Desc $s))
        Drag $L $gl (TabCx $gl 3) ([int]((TabCx $gl 3) - 1.4 * $gl.TabW))
        $s = Snap $id
        Row 'FIRST' 'NEAR' (V ((Order $s.L) -eq 'D A C B')) ('left: C (index 3) dragged 1.4 tab widths left (control): ' + (Desc $s))
        Drag $R $gr (TabCx $gr 3) ((TabCx $gr 0) - 2 * $gr.TabW)
        $s = Snap $id
        Row 'FIRST' 'RIGHT' (V ((Order $s.R) -eq 'S P Q R' -and $s.R.Active -eq 0)) ('right: S dragged far past the left end: ' + (Desc $s))
        Drag $R $gr (TabCx $gr 1) ((TabCx $gr 3) + 2 * $gr.TabW)
        $s = Snap $id
        Row 'FIRST' 'RIGHTEND' (V ((Order $s.R) -eq 'S Q R P')) ('right: P (index 1) dragged far past the right end (control): ' + (Desc $s))
        Drag $L $gl (TabCx $gl 3) ((TabCx $gl 0) - 2 * $gl.TabW)
        $s = Snap $id
        Row 'FIRST' 'AGAIN' (V ((Order $s.L) -eq 'B D A C' -and $s.L.Active -eq 0)) ('left: B (index 3) dragged to the left end: ' + (Desc $s))
    }
    catch { Row 'FIRST' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

function Run-Scrolled {
    if (-not (Want 'SCROLLED')) { return }
    $D = $Root + '\scrolled'
    $n = 30
    $tabs = @(); for ($i = 0; $i -lt $n; $i++) { $tabs += ('{0}\T{1:D2}' -f $D, $i) }
    if (-not (Prep-Registry 0 $tabs ($n - 1) @($StartDir) 0)) { Row 'SCROLLED' 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run $tabs[$n - 1] $StartDir
        $L = (Strips $id)[0]
        $g = Geo $L $n
        $fv = $n - $g.Visible
        $s = Snap $id
        Row 'SCROLLED' 'START' (V ($s.L.Tabs.Count -eq $n -and $s.L.Active -eq ($n - 1) -and $fv -gt 0)) ("{0} tabs, active {1}; strip {2}x{3}, tab width {4}, visible {5}, first visible {6}" -f $s.L.Tabs.Count, $s.L.Active, $g.W, $g.H, $g.TabW, $g.Visible, $fv)
        Drag $L $g (TabCx $g ($g.Visible - 1)) ((TabCx $g 0) - 2 * $g.TabW)
        $s = Snap $id
        $want = @(); for ($i = 0; $i -lt $fv; $i++) { $want += ('T{0:D2}' -f $i) }; $want += ('T{0:D2}' -f ($n - 1)); for ($i = $fv; $i -lt $n - 1; $i++) { $want += ('T{0:D2}' -f $i) }
        $got = Order $s.L
        Row 'SCROLLED' 'FIRSTVISIBLE' (V ($got -eq ($want -join ' ') -and $s.L.Active -eq $fv)) ("T29 dragged to the left end of the run: index {0} active {1} (expected index {2}); order {3}" -f [Array]::IndexOf([string[]]@($s.L.Tabs | ForEach-Object { Leaf $_ }), 'T29'), $s.L.Active, $fv, $got)
    }
    catch { Row 'SCROLLED' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

$script:Theme = @{}
# one panel's strip in the main window's capture: the active tab's fill, the rows it covers, the strip
# background, the row above the strip (the rebar) and the directory line's top row under the tab
function Measure-Strip($full, [IntPtr]$main, [IntPtr]$Hs, [IntPtr]$Line, [int]$Count, [int]$Active) {
    $g = Geo $Hs $Count
    $off = [Tc413]::OffsetIn($main, $Hs)
    $dlSize = [Tc413]::ClientSize($Line); $dlOff = [Tc413]::OffsetIn($main, $Line)
    $ax = $off[0] + $g.Left + $Active * $g.TabW + 12   # inside the active tab, past its rounded corner, left of its icon
    $fill = [Tc413]::Pixel($full, $ax, $off[1] + $g.H - 2)
    $rows = @(); for ($y = 0; $y -lt $g.H; $y++) { if ([Tc413]::Pixel($full, $ax, $off[1] + $y) -eq $fill) { $rows += $y } }
    $col = @(); $prev = -1; $n = 0
    for ($y = $off[1] - 4; $y -lt $dlOff[1] + 4; $y++) { $p = [Tc413]::Pixel($full, $ax, $y); if ($p -eq $prev) { $n++ } else { if ($prev -ge 0) { $col += ('{0:X6}x{1}' -f $prev, $n) }; $prev = $p; $n = 1 } }
    $col += ('{0:X6}x{1}' -f $prev, $n)
    # the title: the text area of the active tab (past the icon, before the close glyph), its most
    # contrasting pixel (review 2: the title on a lifted fill must keep 4.5:1)
    $tl = $off[0] + $g.Left + $Active * $g.TabW
    $tt = [Tc413]::MostContrasting($full, $tl + 34, $off[1] + 6, $tl + $g.TabW - 34, $off[1] + $g.H - 4, $fill).Split('|')
    return [pscustomobject]@{
        Title = [Convert]::ToInt32($tt[0], 16); TitleRatio = [double]::Parse($tt[1], [Globalization.CultureInfo]::InvariantCulture)
        StripH = $g.H; StripTop = $off[1]; DirLineH = $dlSize[1]; DirLineTop = $dlOff[1]; Rows = $rows; Fill = $fill
        Bk = [Tc413]::Pixel($full, $off[0] + 3, $off[1] + 2); Above = [Tc413]::Pixel($full, $off[0] + 3, $off[1] - 1)
        DirTop = [Tc413]::Pixel($full, $ax, $dlOff[1]); Column = ($col -join ' ')
    }
}
function Dir-Line([int]$Id, [IntPtr]$Hs) {
    # the directory line (id 952) of the panel whose strip is $Hs: the one with the same left edge
    $main = Get-Main $Id
    $o = [Tc413]::OffsetIn($main, $Hs)
    foreach ($h in [Drv098f]::Kids($main)) {
        if ([Tc413]::GetDlgCtrlID($h) -eq 952 -and [Drv098f]::IsWindowVisible($h)) { $p = [Tc413]::OffsetIn($main, $h); if ($p[0] -eq $o[0]) { return $h } }
    }
    throw 'no directory line (id 952) under the strip'
}
function Run-ThemeOne([string]$Name, [int]$Mode) {
    $T = $Root + '\theme'
    if (-not (Prep-Registry $Mode @("$T\Downloads", "$T\fonts", "$T\src") 1 @("$T\R1", "$T\R2", "$T\R3") 1)) { Row 'THEME' ($Name + '-SETUP') 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run "$T\fonts" "$T\R2"
        $main = Get-Main $id
        [Tc413]::SendRaw($main, 0x0086, [IntPtr]1, [IntPtr]::Zero)   # WM_NCACTIVATE TRUE: the left panel shows the active caption colours
        [Tc413]::Post((Strips $id)[0], $WM_MOUSEMOVE, 0, 2, 400)       # nothing hot
        Start-Sleep -Milliseconds 600
        [void](Serve $id 2)
        $hs = Strips $id
        if (-not (Test-Path -LiteralPath $CapDir)) { [void](New-Item -ItemType Directory -Path $CapDir) }
        $full = [Tc413]::Capture($main, 3)   # PW_CLIENTONLY | PW_RENDERFULLCONTENT
        $full.Save((Join-Path $CapDir "theme_${Name}_main.png"), [Drawing.Imaging.ImageFormat]::Png)
        $res = @{}
        foreach ($side in @(@('active', 0), @('inactive', 1))) {
            $h = $hs[$side[1]]
            $m = Measure-Strip $full $main $h (Dir-Line $id $h) 3 1
            $res[$side[0]] = $m
            Row 'THEME' ('{0}-{1}' -f $Name.ToUpper(), $side[0].ToUpper()) 'PASS' ("strip at y {0} height {1}; directory line at y {2} height {3}; above the strip {4:X6}, strip {5:X6}, active tab {6:X6} on rows {7}-{8}, directory line's top row {9:X6}; column {10}" -f $m.StripTop, $m.StripH, $m.DirLineTop, $m.DirLineH, $m.Above, $m.Bk, $m.Fill, ($m.Rows | Select-Object -First 1), ($m.Rows | Select-Object -Last 1), $m.DirTop, $m.Column)
        }
        $script:Theme[$Name] = $res
        Out ('    dpi {0}; children: {1}' -f [Tc413]::GetDpiForWindow($main), ([Tc413]::Children($main) -join '; '))
        $full.Dispose()
    }
    catch { Row 'THEME' ($Name + '-ERROR') 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}
# the largest channel difference of two RRGGBB values
function ColorDist([int]$a, [int]$b) {
    return [Math]::Max([Math]::Abs((($a -shr 16) -band 255) - (($b -shr 16) -band 255)), [Math]::Max([Math]::Abs((($a -shr 8) -band 255) - (($b -shr 8) -band 255)), [Math]::Abs(($a -band 255) - ($b -band 255))))
}
function Run-Theme {
    if (-not (Want 'THEME')) { return }
    Run-ThemeOne 'default' 0
    Run-ThemeOne 'dark' 1
    $a = $script:Theme['default']; $d = $script:Theme['dark']
    if (-not $a -or -not $d) { Row 'THEME' 'HEIGHT' 'FAIL' 'a theme was not measured'; return }
    foreach ($p in @('active', 'inactive')) {
        $x = $a[$p]; $y = $d[$p]
        $same = ($x.StripH -eq $y.StripH -and $x.DirLineH -eq $y.DirLineH -and (($x.Rows -join ',') -eq ($y.Rows -join ',')))
        Row 'THEME' ('HEIGHT-' + $p.ToUpper()) (V $same) ("{0} panel: strip {1} / {2} px, directory line {3} / {4} px, active-tab rows {5}-{6} / {7}-{8} (default / dark)" -f $p, $x.StripH, $y.StripH, $x.DirLineH, $y.DirLineH, ($x.Rows | Select-Object -First 1), ($x.Rows | Select-Object -Last 1), ($y.Rows | Select-Object -First 1), ($y.Rows | Select-Object -Last 1))
    }
    # the look: the active tab stands out from the strip and from the directory line under it, in both
    # themes and both panels, by at least 24 in the largest channel (the default theme's weakest pair,
    # the inactive panel's tab on the strip, is 31)
    foreach ($n in @('default', 'dark')) {
        foreach ($p in @('active', 'inactive')) {
            $t = $script:Theme[$n][$p]
            $vsBk = ColorDist $t.Fill $t.Bk; $vsLine = ColorDist $t.Fill $t.DirTop
            Row 'THEME' ('LOOK-{0}-{1}' -f $n.ToUpper(), $p.ToUpper()) (V ($vsBk -ge 24 -and $vsLine -ge 24)) ("active tab {0:X6} vs strip {1:X6}: {2}; vs the directory line's top row {3:X6}: {4} (both at least 24)" -f $t.Fill, $t.Bk, $vsBk, $t.DirTop, $vsLine)
            Row 'THEME' ('TITLE-{0}-{1}' -f $n.ToUpper(), $p.ToUpper()) (V ($t.TitleRatio -ge 4.5)) ("the title's most contrasting pixel {0:X6} on the active tab {1:X6}: {2}:1 (at least 4.5)" -f $t.Title, $t.Fill, $t.TitleRatio.ToString('F2', [Globalization.CultureInfo]::InvariantCulture))
        }
    }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc413_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    foreach ($n in @('A', 'B', 'C', 'D', 'P', 'Q', 'R', 'S')) { NewDir ($Root + '\first\' + $n) }
    for ($i = 0; $i -lt 30; $i++) { NewDir ('{0}\scrolled\T{1:D2}' -f $Root, $i) }
    foreach ($n in @('Downloads', 'fonts', 'src', 'R1', 'R2')) { NewDir ($Root + '\theme\' + $n) }
    Out ("tabs413_probe (feature 413) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    $fm = [Tc413]::FontMetrics()
    Out ("Date    : {0}; registry key existed {1}; fixture {2}; font height {3}, avg char {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, (Esc $Root), $fm[0], $fm[1])
    Out ''
    Run-First
    Run-Scrolled
    Run-Theme
    Row 'MOUSE' 'REAL' 'NOT DRIVEN' 'the feel of a real mouse drag to the first place needs an input desktop (release checklist)'
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
