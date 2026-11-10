<#
.SYNOPSIS
    Feature 423 probe (backlog item square-panel-tabs-as-the-new-default-rounded-tabs-kept-as-an):
    square panel tabs by default, rounded tabs as a choice on Configuration > Appearance, darker
    inactive titles in the Light theme.

.DESCRIPTION
    The tabs of feature 413's THEME run (left Downloads fonts src, right R1 R2 R3, the second tab
    active; the main window activated: the left panel active, the right inactive). The main window's
    client area is captured (PrintWindow) and the active tab's box is read at the pixels of
    contract tabs (x0 = the tab's left column, x1 = its right column, yT = the content band's top row
    = strip top + 3, yB = the strip's bottom row):
      SQUARE  the four corners (x0,yT) (x1,yT) (x0,yB) (x1,yB) are the tab's fill; (x0-1,yB),
              (x1+1,yB) and (x0,yT-1) are the strip background (no feet, no arcs)
      ROUND   (x0,yT) is not the fill (the rounded corner) and (x0-1,yB) is not the background (the
              left foot)
    Rows:
      DEFAULT-<theme>     no "Panel Tab Style" value: SQUARE in both panels (Light, Dark)
      UNKNOWN             value 7: SQUARE; the page shows Square checked; OK without a change and
                          Save Configuration keep 7; value REG_SZ: SQUARE, no error window
      ROUNDED-<theme>     value 1: ROUND in both panels; the corner boxes (x0-7..x0+7 and x1-7..x1+7,
                          rows yT..yB) equal the capture of the build before 423
                          (captures_before\theme_<theme>_main.png, -BeforeDir)
      HOVER-<style>       WM_MOUSEMOVE over the third tab (inactive): Square -> the rounded pill's box
                          (inset 3 / 2 / 4 / 3) with square corners in the hover colour (CECECE on
                          DEDEDE), the strip one pixel outside each edge (only the active tab joins the
                          directory line; review 2), in the active panel and in the inactive one
                          (SQUARE-INACTIVE); Rounded -> the inset pill with rounded corners
      PAGE                Configuration > Appearance: Square checked by default; Rounded + OK -> ROUND
                          without a restart, stored 1 (Save Configuration); Rounded -> Square + OK ->
                          SQUARE, stored 0; Rounded + Cancel -> nothing changes
      TITLE-<theme>       an inactive title's most contrasting pixel against the strip: Light >= 7:1 and
                          lighter than the active title's; Dark: the same colour as before 423
      LAYOUT              the live English Appearance page: every control inside the page, no two
                          controls (other than group boxes) overlap, every control of a group box inside
                          it, the Tab style group below the Icon style group
      FIT                 (static, -SltRoot) the texts of the moved and new controls of the 8 enabled
                          languages fit their widths (text extent in "MS Shell Dlg 2" 8 pt)
    NOT DRIVEN: a real mouse hover (posted WM_MOUSEMOVE; on the hidden desktop the strip keeps the hover
    when there is no cursor, 404); 125 / 150 / 200 % (the hidden desktop's DPI is fixed; the square box
    is integer pixels at every scale).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label = 'after',
    [string]$OutFile,
    [string]$BeforeDir,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
if (-not $BeforeDir) { $BeforeDir = Join-Path $PSScriptRoot 'captures_before' }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $RepoRoot 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $RepoRoot 'specs\416-fluent-icon-set\probe\capture416_lib.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ('Tc423' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Tc423
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
    [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtrW(IntPtr h, int index);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static void SendRaw(IntPtr h, uint msg, IntPtr wp, IntPtr lp) { IntPtr r; SendMessageTimeoutW(h, msg, wp, lp, 0, 10000, out r); }
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
    public static int[] ClientSize(IntPtr h) { RECT r; GetClientRect(h, out r); return new int[] { r.right, r.bottom }; }
    public static int[] OffsetIn(IntPtr main, IntPtr h)
    {
        POINT o; o.x = 0; o.y = 0; ClientToScreen(main, ref o);
        POINT p; p.x = 0; p.y = 0; ClientToScreen(h, ref p);
        return new int[] { p.x - o.x, p.y - o.y };
    }
    // the rectangle of 'h' in the client coordinates of 'parent'
    public static int[] RectIn(IntPtr parent, IntPtr h)
    {
        POINT o; o.x = 0; o.y = 0; ClientToScreen(parent, ref o);
        RECT r; GetWindowRect(h, out r);
        return new int[] { r.left - o.x, r.top - o.y, r.right - o.x, r.bottom - o.y };
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
    public static void Send(IntPtr h, uint msg, int wp, int x, int y) { SendRaw(h, msg, (IntPtr)wp, LP(x, y)); }
    public static Bitmap Capture(IntPtr h)
    {
        int[] s = ClientSize(h);
        var bmp = new Bitmap(Math.Max(1, s[0]), Math.Max(1, s[1]), PixelFormat.Format32bppRgb);
        using (var g = Graphics.FromImage(bmp))
        {
            IntPtr dc = g.GetHdc();
            PrintWindow(h, dc, 3);
            g.ReleaseHdc(dc);
        }
        return bmp;
    }
    public static int Pixel(Bitmap b, int x, int y)
    {
        if (x < 0 || y < 0 || x >= b.Width || y >= b.Height) return -1;
        return b.GetPixel(x, y).ToArgb() & 0xFFFFFF;
    }
    static double Lin(int c) { double v = c / 255.0; return v <= 0.04045 ? v / 12.92 : Math.Pow((v + 0.055) / 1.055, 2.4); }
    public static double Lum(int rgb) { return 0.2126 * Lin((rgb >> 16) & 255) + 0.7152 * Lin((rgb >> 8) & 255) + 0.0722 * Lin(rgb & 255); }
    public static double Contrast(int a, int b) { double x = Lum(a) + 0.05, y = Lum(b) + 0.05; return x > y ? x / y : y / x; }
    // the pixel of the rectangle that contrasts most with 'bk'
    public static int MostContrasting(Bitmap b, int x0, int y0, int x1, int y1, int bk)
    {
        int best = bk; double r = 1.0;
        for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) { int p = Pixel(b, x, y); if (p < 0) continue; double c = Contrast(p, bk); if (c > r) { r = c; best = p; } }
        return best;
    }
    // pixels that differ between the w x h box at (ax, ay) of 'a' and the one at (bx, by) of 'b';
    // -1 when a box leaves its image
    public static int DiffBoxAt(Bitmap a, int ax, int ay, Bitmap b, int bx, int by, int w, int h)
    {
        int n = 0;
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            int p = Pixel(a, ax + x, ay + y), q = Pixel(b, bx + x, by + y);
            if (p < 0 || q < 0) return -1;
            if (p != q) n++;
        }
        return n;
    }
    // review 1 (S2): the active tab in a capture of another window size - the topmost row of
    // x0..x1 holding a run of at least 'minRun' pixels of 'fill' (the tab's top; the directory line
    // below has the same colour, the tab comes first), then the first pixel of 'fill' on the row 8 below
    // (past the rounded corner) = the tab's left column. {left, top} or {-1, -1}
    public static int[] FindTab(Bitmap b, int fill, int x0, int x1, int minRun)
    {
        for (int y = 0; y < b.Height - 8; y++)
        {
            int run = 0, best = 0;
            for (int x = x0; x < x1 && x < b.Width; x++) { if (Pixel(b, x, y) == fill) { run++; if (run > best) best = run; } else run = 0; }
            if (best >= minRun)
            {
                for (int x = x0; x < x1 && x < b.Width; x++) if (Pixel(b, x, y + 8) == fill) return new int[] { x, y };
                return new int[] { -1, -1 };
            }
        }
        return new int[] { -1, -1 };
    }
}
'@
}

$Root = $TempRoot + '\tc423'
$T = $Root + '\theme'
$CapDir = Join-Path $PSScriptRoot ('captures_' + $Label)
$CfgReg = $RegKey + '\Settings\Configuration'
$CM_CONFIGURATION = 686
$CM_SAVECONFIG = 687
$WM_MOUSEMOVE = 0x0200
$TabsL = @("$T\Downloads", "$T\fonts", "$T\src")
$TabsR = @("$T\R1", "$T\R2", "$T\R3")
$IDC_ICONSET_GROUP = 6291; $IDC_TABSTYLE_GROUP = 6302; $IDC_TABSTYLE_SQUARE = 6303; $IDC_TABSTYLE_ROUNDED = 6304

function Prep-Registry([int]$Theme, $Style) {
    & cmd.exe /c "reg query `"$CfgReg`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    Set-Config
    & reg.exe add $CfgReg /v 'Panel Tabs' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add $CfgReg /v 'Theme Mode' /t REG_DWORD /d $Theme /f | Out-Null
    if ($null -eq $Style) { & cmd.exe /c "reg delete `"$CfgReg`" /v `"Panel Tab Style`" /f >nul 2>&1" }
    elseif ($Style -is [string]) { & reg.exe add $CfgReg /v 'Panel Tab Style' /t REG_SZ /d $Style /f | Out-Null }
    else { & reg.exe add $CfgReg /v 'Panel Tab Style' /t REG_DWORD /d $Style /f | Out-Null }
    foreach ($side in @(@('Left Panel', $TabsL), @('Right Panel', $TabsR))) {
        $p = $side[0]; $tabs = @($side[1])
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
        & reg.exe add "$RegKey\Settings\$p" /v 'Active Tab' /t REG_DWORD /d 1 /f | Out-Null
    }
    return $true
}
function Read-Style {
    $v = & cmd.exe /c "reg query `"$CfgReg`" /v `"Panel Tab Style`" 2>nul"
    $m = [regex]::Match(($v -join ' '), '(REG_\w+)\s+(\S+)')
    if ($m.Success) { return ($m.Groups[1].Value + ' ' + $m.Groups[2].Value) } else { return '<none>' }
}
function Start-Run {
    $a = @('-t', 'T423', '-l', ('"{0}"' -f $TabsL[1]), '-r', ('"{0}"' -f $TabsR[1]), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2000
    $r = Serve $p.Id 10
    $script:StartMsgs = Msgs $r
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
    $s = @([Tc423]::Strips((Get-Main $Id)))
    if ($s.Count -lt 2) { throw ('{0} tab strip(s) (child id 958) found, 2 expected' -f $s.Count) }
    return $s
}
# the strip geometry as CTabWindow::Layout lays it out at 100 % (as tabs413_probe)
function Geo([IntPtr]$Hs, [int]$Count) {
    $sz = [Tc423]::ClientSize($Hs); $W = $sz[0]; $H = $sz[1]
    $avg = ([Tc423]::FontMetrics())[1]
    $fixed = 2 * 10 + 8 + 6 + 16
    $minW = 6 * $avg + $fixed; $maxW = 20 * $avg + $fixed
    $left = 8
    $avail = [Math]::Max(0, $W - $left - $H - 2)
    $tw = [Math]::Floor($avail / $Count); if ($tw -gt $maxW) { $tw = $maxW }
    if ($tw -lt $minW) { $tw = $minW }
    return [pscustomobject]@{ W = $W; H = $H; Left = $left; TabW = [int]$tw; MidY = [int]((3 + $H) / 2) }
}
# focus the main window's caption colours (the left panel active), nothing hot
function Settle([int]$Id) {
    $main = Get-Main $Id
    [Tc423]::SendRaw($main, 0x0086, [IntPtr]1, [IntPtr]::Zero)   # WM_NCACTIVATE TRUE
    [Tc423]::Send((Strips $Id)[0], $WM_MOUSEMOVE, 0, 2, 400)     # out of the tabs
    [Tc423]::Send((Strips $Id)[1], $WM_MOUSEMOVE, 0, 2, 400)
    Start-Sleep -Milliseconds 500
    [void](Serve $Id 2)
}
function Grab-Main([int]$Id, [string]$Name) {
    $main = Get-Main $Id
    [void][Drv098f]::Send($main, 0, 0, 0, 10000)
    $full = [Tc423]::Capture($main)
    if (-not (Test-Path -LiteralPath $CapDir)) { [void](New-Item -ItemType Directory -Path $CapDir) }
    if ($Name) { $full.Save((Join-Path $CapDir ($Name + '.png')), [Drawing.Imaging.ImageFormat]::Png) }
    return $full
}
# the box of tab 'index' of a panel's strip in the main window's capture
function Box([int]$Id, [IntPtr]$Hs, [int]$Index) {
    $main = Get-Main $Id
    $g = Geo $Hs 3
    $off = [Tc423]::OffsetIn($main, $Hs)
    $x0 = $off[0] + $g.Left + $Index * $g.TabW
    return [pscustomobject]@{ X0 = $x0; X1 = $x0 + $g.TabW - 1; YT = $off[1] + 3; YB = $off[1] + $g.H - 1; StripX = $off[0]; StripY = $off[1]; G = $g }
}
function P($bmp, [int]$x, [int]$y) { return [Tc423]::Pixel($bmp, $x, $y) }
function Hex([int]$c) { if ($c -lt 0) { return 'outside' }; return ('{0:X6}' -f $c) }
# the shape of the active tab (index 1): Square or Round, with the facts
function Shape($bmp, $b) {
    $bk = P $bmp ($b.StripX + 3) ($b.StripY + 1)
    $fill = P $bmp ($b.X0 + 4) ($b.YB - 1)
    $corners = @((P $bmp $b.X0 $b.YT), (P $bmp $b.X1 $b.YT), (P $bmp $b.X0 $b.YB), (P $bmp $b.X1 $b.YB))
    $outside = @((P $bmp ($b.X0 - 1) $b.YB), (P $bmp ($b.X1 + 1) $b.YB), (P $bmp $b.X0 ($b.YT - 1)))
    $square = (@($corners | Where-Object { $_ -ne $fill }).Count -eq 0) -and (@($outside | Where-Object { $_ -ne $bk }).Count -eq 0) -and ($fill -ne $bk)
    $round = ((P $bmp $b.X0 $b.YT) -ne $fill) -and ((P $bmp ($b.X0 - 1) $b.YB) -ne $bk)
    $facts = ("fill {0}, strip {1}; corners {2}; outside (left foot, right foot, above) {3}; box x {4}..{5}, y {6}..{7}" -f (Hex $fill), (Hex $bk), (($corners | ForEach-Object { Hex $_ }) -join ' '), (($outside | ForEach-Object { Hex $_ }) -join ' '), $b.X0, $b.X1, $b.YT, $b.YB)
    return [pscustomobject]@{ Square = $square; Round = $round; Fill = $fill; Bk = $bk; Facts = $facts }
}
function Check-Panels([string]$Case, [string]$Step, [int]$Id, $bmp, [string]$Want) {
    $hs = Strips $Id
    $i = 0
    foreach ($h in $hs) {
        $s = Shape $bmp (Box $Id $h 1)
        $ok = if ($Want -eq 'square') { $s.Square } else { $s.Round -and -not $s.Square }
        Row $Case ('{0}-{1}' -f $Step, @('LEFT', 'RIGHT')[$i]) (V $ok) ("want {0}: {1}" -f $Want, $s.Facts)
        $i++
    }
}

# ---- Configuration > Appearance (as iconset416_probe) -----------------------------------------
function Open-Appearance([int]$Id) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) $CM_CONFIGURATION
    $dlg = Wait-NewWin $Id $known 15
    if ($null -eq $dlg -or $dlg -eq [IntPtr]::Zero) { throw 'the Configuration dialog did not open' }
    $tree = @([Cap416]::Kids($dlg) | Where-Object { [Cap416]::Cls($_) -eq 'SysTreeView32' })[0]
    if ($null -eq $tree) { throw 'no tree view in the Configuration dialog' }
    $items = New-Object System.Collections.ArrayList
    $stack = New-Object System.Collections.Stack
    $h = [Cap416]::Send($tree, 0x110A, [IntPtr]0, [IntPtr]::Zero) # TVM_GETNEXTITEM TVGN_ROOT
    $guard = 0
    while ($h -ne [IntPtr]::Zero -and $guard -lt 200) {
        $guard++
        [void]$items.Add($h)
        [void][Cap416]::Send($tree, 0x1102, [IntPtr]2, $h)            # TVM_EXPAND TVE_EXPAND
        $child = [Cap416]::Send($tree, 0x110A, [IntPtr]4, $h)         # TVGN_CHILD
        $next = [Cap416]::Send($tree, 0x110A, [IntPtr]1, $h)          # TVGN_NEXT
        if ($child -ne [IntPtr]::Zero) { if ($next -ne [IntPtr]::Zero) { $stack.Push($next) }; $h = $child }
        elseif ($next -ne [IntPtr]::Zero) { $h = $next }
        elseif ($stack.Count) { $h = $stack.Pop() }
        else { $h = [IntPtr]::Zero }
    }
    foreach ($it in $items) {
        [void][Cap416]::Send($tree, 0x110B, [IntPtr]9, $it)            # TVM_SELECTITEM TVGN_CARET
        Start-Sleep -Milliseconds 250
        $radio = @([Cap416]::Kids($dlg) | Where-Object { [Cap416]::GetDlgCtrlID($_) -eq $IDC_TABSTYLE_SQUARE -and [Cap416]::IsWindowVisible($_) })
        if ($radio.Count) { return [pscustomobject]@{ Dlg = $dlg; Page = [Cap416]::GetParent($radio[0]); Items = $items.Count } }
    }
    throw ("the Appearance page with the Tab style group was not found among {0} tree items" -f $items.Count)
}
function Ctl([IntPtr]$Page, [int]$CtlId) { return @([Cap416]::Kids($Page) | Where-Object { [Cap416]::GetDlgCtrlID($_) -eq $CtlId })[0] }
function Checked([IntPtr]$H) { return [int][Cap416]::Send($H, 0x00F0, [IntPtr]::Zero, [IntPtr]::Zero) }
function Press([IntPtr]$H) { [void][Cap416]::Send($H, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 250 } # BM_CLICK
function Close-Config([int]$Id, $A, [int]$Button) {
    $b = @([Cap416]::Kids($A.Dlg) | Where-Object { [Cap416]::Cls($_) -eq 'Button' -and [Cap416]::GetDlgCtrlID($_) -eq $Button })[0] # 5 = OK (_TPD_IDC_OK), 2 = Cancel
    if ($null -eq $b) { throw ("no button {0} in the Configuration dialog" -f $Button) }
    Click $b
    $r = Serve $Id 15
    Start-Sleep -Milliseconds 1200
    return (Msgs $r)
}
function Save-Now([int]$Id) {
    Post-Cmd (Get-Main $Id) $CM_SAVECONFIG
    Start-Sleep -Milliseconds 500
    [void](Serve $Id 10)
}

# ---- the rows ---------------------------------------------------------------------------------
function Run-Default {
    foreach ($th in @(@('LIGHT', 0), @('DARK', 1))) {
        $n = 'DEFAULT-' + $th[0]
        if (-not (Want $n)) { continue }
        if (-not (Prep-Registry $th[1] $null)) { Row $n 'SETUP' 'NOT DRIVEN' 'no stored configuration'; continue }
        $id = 0
        try {
            $id = Start-Run
            Settle $id
            $bmp = Grab-Main $id ('default_' + $th[0].ToLower())
            Check-Panels $n 'SQUARE' $id $bmp 'square'
            if ($th[1] -eq 0) { $script:LightDefault = $bmp; $script:LightId = $id; Title-Rows 'LIGHT' $id $bmp }
            else { Title-Rows 'DARK' $id $bmp; $bmp.Dispose() }
        }
        catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { End-Run $id }
    }
}
# the most contrasting pixel of an inactive title (tab 0, past its icon) against the strip, and of the
# active title (tab 1) against its fill
function Title-Facts([int]$Id, $bmp, [IntPtr]$Hs) {
    $b0 = Box $Id $Hs 0; $b1 = Box $Id $Hs 1
    $bk = P $bmp ($b0.StripX + 3) ($b0.StripY + 1)
    $dim = [Tc423]::MostContrasting($bmp, $b0.X0 + 34, $b0.YT + 3, $b0.X1 - 4, $b0.YB - 2, $bk)
    $fill = P $bmp ($b1.X0 + 4) ($b1.YB - 1)
    $act = [Tc423]::MostContrasting($bmp, $b1.X0 + 34, $b1.YT + 3, $b1.X1 - 34, $b1.YB - 2, $fill)
    return [pscustomobject]@{ Dim = $dim; Bk = $bk; DimRatio = [Tc423]::Contrast($dim, $bk); Act = $act; Fill = $fill }
}
function Fmt([double]$d) { return $d.ToString('F2', [Globalization.CultureInfo]::InvariantCulture) }
function Title-Rows([string]$Theme, [int]$Id, $bmp) {
    $n = 'TITLE-' + $Theme
    if (-not (Want $n)) { return }
    $hs = Strips $Id
    $t = Title-Facts $Id $bmp $hs[0]
    $beforeFile = Join-Path $BeforeDir ("theme_{0}_main.png" -f @('default', 'dark')[[int]($Theme -eq 'DARK')])
    $old = $null
    if (Test-Path -LiteralPath $beforeFile) {
        $ob = New-Object Drawing.Bitmap($beforeFile)
        $old = Title-Facts $Id $ob $hs[0]
        $ob.Dispose()
    }
    $oldText = if ($old) { ("before 423: {0} on {1} = {2}:1" -f (Hex $old.Dim), (Hex $old.Bk), (Fmt $old.DimRatio)) } else { 'no before capture' }
    if ($Theme -eq 'LIGHT') {
        $ok = $t.DimRatio -ge 7.0 -and ([Tc423]::Lum($t.Dim) -gt [Tc423]::Lum($t.Act))
        Row $n 'INACTIVE' (V $ok) ("inactive title {0} on the strip {1} = {2}:1 (at least 7), lighter than the active title {3} (on {4}); {5}" -f (Hex $t.Dim), (Hex $t.Bk), (Fmt $t.DimRatio), (Hex $t.Act), (Hex $t.Fill), $oldText)
    } else {
        $ok = ($null -ne $old) -and ($t.Dim -eq $old.Dim) -and ($t.Bk -eq $old.Bk)
        Row $n 'UNCHANGED' (V $ok) ("inactive title {0} on the strip {1} = {2}:1; {3}" -f (Hex $t.Dim), (Hex $t.Bk), (Fmt $t.DimRatio), $oldText)
    }
}

function Run-Unknown {
    $n = 'UNKNOWN'
    if (-not (Want $n)) { return }
    if (-not (Prep-Registry 0 7)) { Row $n 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run
        Settle $id
        $bmp = Grab-Main $id 'unknown7'
        Check-Panels $n 'VALUE7' $id $bmp 'square'
        $bmp.Dispose()
        $a = Open-Appearance $id
        $sq = Ctl $a.Page $IDC_TABSTYLE_SQUARE; $ro = Ctl $a.Page $IDC_TABSTYLE_ROUNDED
        Row $n 'PAGE-SHOWS' (V ((Checked $sq) -eq 1 -and (Checked $ro) -eq 0)) ("Square {0}, Rounded {1}" -f (Checked $sq), (Checked $ro))
        $m = Close-Config $id $a 5
        Save-Now $id
        $v = Read-Style
        Row $n 'KEPT' (V ($v -eq 'REG_DWORD 0x7')) ("after OK without a change and Save Configuration: {0}; windows: {1}" -f $v, $m)
    }
    catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
    if (-not (Prep-Registry 0 'rounded')) { return }
    $id = 0
    try {
        $id = Start-Run
        Settle $id
        $bmp = Grab-Main $id 'unknown_sz'
        Check-Panels $n 'REGSZ' $id $bmp 'square'
        $bmp.Dispose()
        Row $n 'REGSZ-QUIET' (V ($script:StartMsgs -eq 'no window')) ("windows at start: {0}" -f $script:StartMsgs)
    }
    catch { Row $n 'ERROR-SZ' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

function Run-Rounded {
    foreach ($th in @(@('LIGHT', 0, 'default'), @('DARK', 1, 'dark'))) {
        $n = 'ROUNDED-' + $th[0]
        if (-not (Want $n)) { continue }
        if (-not (Prep-Registry $th[1] 1)) { Row $n 'SETUP' 'NOT DRIVEN' 'no stored configuration'; continue }
        $id = 0
        try {
            $id = Start-Run
            Settle $id
            $bmp = Grab-Main $id ('rounded_' + $th[0].ToLower())
            Check-Panels $n 'ROUND' $id $bmp 'round'
            $beforeFile = Join-Path $BeforeDir ("theme_{0}_main.png" -f $th[2])
            if (-not (Test-Path -LiteralPath $beforeFile)) { Row $n 'SAME-AS-BEFORE' 'NOT DRIVEN' ('no ' + $beforeFile) }
            else {
                $ob = New-Object Drawing.Bitmap($beforeFile)
                $i = 0
                foreach ($h in (Strips $id)) {
                    $b = Box $id $h 1
                    $fill = (Shape $bmp $b).Fill
                    # each capture's own tab position (review 1, S2: the window size is the one stored in the
                    # registry key and may differ from the before capture's); the left / right panel = the
                    # left / right half of each capture
                    $cur = [Tc423]::FindTab($bmp, $fill, [int]($i * $bmp.Width / 2), [int](($i + 1) * $bmp.Width / 2), 20)
                    $old = [Tc423]::FindTab($ob, $fill, [int]($i * $ob.Width / 2), [int](($i + 1) * $ob.Width / 2), 20)
                    $w = $b.X1 - $b.X0
                    $hh = $b.YB - $b.YT + 2
                    $dl = [Tc423]::DiffBoxAt($bmp, $cur[0] - 7, $cur[1] - 1, $ob, $old[0] - 7, $old[1] - 1, 15, $hh)
                    $dr = [Tc423]::DiffBoxAt($bmp, $cur[0] + $w - 7, $cur[1] - 1, $ob, $old[0] + $w - 7, $old[1] - 1, 15, $hh)
                    $found = ($cur[0] -eq $b.X0) -and ($cur[1] -eq $b.YT) -and ($old[0] -ge 0)
                    Row $n ('SAME-AS-BEFORE-' + @('LEFT', 'RIGHT')[$i]) (V ($found -and $dl -eq 0 -and $dr -eq 0)) ("the active tab's left / right corner boxes (15 x {0} px) differ from the capture before 423 in {1} / {2} px; tab found at {3},{4} (expected {5},{6}), before at {7},{8} (capture {9}x{10}, before {11}x{12})" -f $hh, $dl, $dr, $cur[0], $cur[1], $b.X0, $b.YT, $old[0], $old[1], $bmp.Width, $bmp.Height, $ob.Width, $ob.Height)
                    $i++
                }
                $ob.Dispose()
            }
            $bmp.Dispose()
        }
        catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { End-Run $id }
    }
}

function Run-Hover {
    # the third tab hovered, in the active (left) and - review 2 - the inactive (right) panel
    foreach ($st in @(@('SQUARE', $null, 0), @('SQUARE-INACTIVE', $null, 1), @('ROUNDED', 1, 0))) {
        $n = 'HOVER-' + $st[0]
        if (-not (Want $n)) { continue }
        if (-not (Prep-Registry 0 $st[1])) { Row $n 'SETUP' 'NOT DRIVEN' 'no stored configuration'; continue }
        $id = 0
        try {
            $id = Start-Run
            Settle $id
            $hs = (Strips $id)[$st[2]]
            $g = Geo $hs 3
            [Tc423]::Send($hs, $WM_MOUSEMOVE, 0, [int]($g.Left + 2 * $g.TabW + $g.TabW / 2), $g.MidY)
            Start-Sleep -Milliseconds 400
            [void](Serve $id 2)
            $bmp = Grab-Main $id ('hover_' + $st[0].ToLower())
            $b = Box $id $hs 2
            $bk = P $bmp ($b.StripX + 3) ($b.StripY + 1)
            $hov = P $bmp ($b.X0 + 6) ($b.StripY + 6)
            if ($st[0] -like 'SQUARE*') {
                # the square hover = the rounded pill's box without its corners (the maintainer,
                # 2026-11-10): columns X0 + 3 .. X1 - 3, rows strip top + 4 .. YB - 3 (at 100 %) - its four
                # corners are the hover colour; one pixel outside each edge is the strip, so it never
                # joins the directory line as the active tab does (review 2) and keeps Rounded's insets
                $yTop = $b.StripY + 4
                $corn = @((P $bmp ($b.X0 + 3) $yTop), (P $bmp ($b.X1 - 3) $yTop), (P $bmp ($b.X0 + 3) ($b.YB - 3)), (P $bmp ($b.X1 - 3) ($b.YB - 3)))
                $out = @((P $bmp ($b.X0 + 2) ($b.StripY + 14)), (P $bmp ($b.X1 - 2) ($b.StripY + 14)), (P $bmp ($b.X0 + 8) ($yTop - 1)), (P $bmp ($b.X0 + 8) ($b.YB - 2)), (P $bmp ($b.X0 + 8) $b.YB))
                $act = Shape $bmp (Box $id $hs 1)
                $ok = ($hov -eq 0xCECECE) -and (@($corn | Where-Object { $_ -ne $hov }).Count -eq 0) -and (@($out | Where-Object { $_ -ne $bk }).Count -eq 0) -and $act.Square
                Row $n 'BOX' (V $ok) ("want the pill's box in CECECE with square corners (x {0}..{1}, y {2}..{3}): inside {4}, strip {5}; corners {6}; outside (left, right, above, below, bottom row) {7}; the active tab next to it: {8}" -f ($b.X0 + 3), ($b.X1 - 3), $yTop, ($b.YB - 3), (Hex $hov), (Hex $bk), (($corn | ForEach-Object { Hex $_ }) -join ' '), (($out | ForEach-Object { Hex $_ }) -join ' '), $act.Facts)
            } else {
                $corners = @((P $bmp $b.X0 $b.YT), (P $bmp $b.X1 $b.YT), (P $bmp $b.X0 $b.YB), (P $bmp $b.X1 $b.YB))
                $above = P $bmp ($b.X0 + 6) ($b.YT - 1)
                $facts = ("hovered tab x {0}..{1}: inside {2}, strip {3}; corners {4}; above {5}" -f $b.X0, $b.X1, (Hex $hov), (Hex $bk), (($corners | ForEach-Object { Hex $_ }) -join ' '), (Hex $above))
                # the pill (404): x from left + 3, y 4 .. H - 3 of the strip; its inside sampled at
                # (left + 6, strip top + 6); the box's right corners stay the strip (the left ones may be
                # the active tab's right foot)
                $pill = P $bmp ($b.X0 + 6) ($b.StripY + 6)
                $ok = ($pill -eq 0xCECECE) -and ((P $bmp $b.X1 $b.YT) -eq $bk) -and ((P $bmp $b.X1 $b.YB) -eq $bk)
                Row $n 'PILL' (V $ok) (("want the inset pill: inside the pill {0}; " -f (Hex $pill)) + $facts)
            }
            $bmp.Dispose()
        }
        catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { End-Run $id }
    }
}

function Run-Page {
    $n = 'PAGE'
    if (-not (Want $n) -and -not (Want 'LAYOUT')) { return }
    if (-not (Prep-Registry 0 $null)) { Row $n 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run
        Settle $id
        $a = Open-Appearance $id
        $sq = Ctl $a.Page $IDC_TABSTYLE_SQUARE; $ro = Ctl $a.Page $IDC_TABSTYLE_ROUNDED
        Row $n 'DEFAULT-CHECKED' (V ((Checked $sq) -eq 1 -and (Checked $ro) -eq 0)) ("{0} tree items walked; Square {1}, Rounded {2}" -f $a.Items, (Checked $sq), (Checked $ro))
        if (Want 'LAYOUT') { Layout-Rows $a }
        $pg = [Cap416]::Capture($a.Page, $false); Save-Png $pg (Join-Path $CapDir 'page_appearance.png'); $pg.Dispose()
        # Rounded + Cancel: nothing changes
        Press $ro
        $m = Close-Config $id $a 2
        Settle $id
        $bmp = Grab-Main $id 'page_cancel'
        Check-Panels $n 'CANCEL' $id $bmp 'square'; $bmp.Dispose()
        Save-Now $id
        Row $n 'CANCEL-STORED' (V ((Read-Style) -eq 'REG_DWORD 0x0')) ("after Rounded + Cancel and Save Configuration: {0}; windows: {1}" -f (Read-Style), $m)
        # Rounded + OK
        $a = Open-Appearance $id
        $sq = Ctl $a.Page $IDC_TABSTYLE_SQUARE; $ro = Ctl $a.Page $IDC_TABSTYLE_ROUNDED
        Press $ro
        Row $n 'ROUNDED-CLICKED' (V ((Checked $ro) -eq 1 -and (Checked $sq) -eq 0)) ("Square {0}, Rounded {1}" -f (Checked $sq), (Checked $ro))
        $m = Close-Config $id $a 5
        Settle $id
        $bmp = Grab-Main $id 'page_rounded_ok'
        Check-Panels $n 'ROUNDED-OK' $id $bmp 'round'; $bmp.Dispose()
        Save-Now $id
        Row $n 'ROUNDED-STORED' (V ((Read-Style) -eq 'REG_DWORD 0x1')) ("after Rounded + OK and Save Configuration: {0}; windows: {1}" -f (Read-Style), $m)
        # back to Square + OK
        $a = Open-Appearance $id
        $sq = Ctl $a.Page $IDC_TABSTYLE_SQUARE; $ro = Ctl $a.Page $IDC_TABSTYLE_ROUNDED
        Row $n 'ROUNDED-SHOWN' (V ((Checked $ro) -eq 1 -and (Checked $sq) -eq 0)) ("reopened: Square {0}, Rounded {1}" -f (Checked $sq), (Checked $ro))
        Press $sq
        $m = Close-Config $id $a 5
        Settle $id
        $bmp = Grab-Main $id 'page_square_ok'
        Check-Panels $n 'SQUARE-OK' $id $bmp 'square'; $bmp.Dispose()
        Save-Now $id
        Row $n 'SQUARE-STORED' (V ((Read-Style) -eq 'REG_DWORD 0x0')) ("after Square + OK and Save Configuration: {0}; windows: {1}" -f (Read-Style), $m)
    }
    catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}
function Intersects($a, $b) { return ($a[0] -lt $b[2]) -and ($b[0] -lt $a[2]) -and ($a[1] -lt $b[3]) -and ($b[1] -lt $a[3]) }
# an overlap of more than one pixel in both directions (dialog units round to pixels: the page's
# check boxes, 12 DLU apart and 12 DLU tall, touch by a pixel - as before 423)
function Overlaps($a, $b) {
    $w = [Math]::Min($a[2], $b[2]) - [Math]::Max($a[0], $b[0]); $h = [Math]::Min($a[3], $b[3]) - [Math]::Max($a[1], $b[1])
    return ($w -gt 1) -and ($h -gt 1)
}
function Inside($inner, $outer) { return ($inner[0] -ge $outer[0]) -and ($inner[1] -ge $outer[1]) -and ($inner[2] -le $outer[2]) -and ($inner[3] -le $outer[3]) }
function Layout-Rows($A) {
    $n = 'LAYOUT'
    $page = $A.Page
    $ps = [Tc423]::ClientSize($page)
    $ctls = @()
    foreach ($h in [Cap416]::Kids($page)) {
        if ([Cap416]::GetParent($h) -ne $page -or -not [Cap416]::IsWindowVisible($h)) { continue }
        $r = [Tc423]::RectIn($page, $h)
        $style = [int64]([Tc423]::GetWindowLongPtrW($h, -16))
        $isGroup = ([Cap416]::Cls($h) -eq 'Button') -and (($style -band 0xF) -eq 7) # BS_GROUPBOX
        $ctls += [pscustomobject]@{ H = $h; Id = [Tc423]::GetDlgCtrlID($h); R = $r; Group = $isGroup; Cls = [Cap416]::Cls($h) }
    }
    $outside = @($ctls | Where-Object { $_.R[0] -lt 0 -or $_.R[1] -lt 0 -or $_.R[2] -gt $ps[0] -or $_.R[3] -gt $ps[1] })
    Row $n 'INSIDE-PAGE' (V ($outside.Count -eq 0 -and $ctls.Count -ge 20)) ("{0} controls on the {1}x{2} page; outside: {3}" -f $ctls.Count, $ps[0], $ps[1], (($outside | ForEach-Object { '{0} {1}' -f $_.Id, ($_.R -join ',') }) -join '; '))
    $plain = @($ctls | Where-Object { -not $_.Group })
    $over = @()
    for ($i = 0; $i -lt $plain.Count; $i++) { for ($j = $i + 1; $j -lt $plain.Count; $j++) {
        $x = $plain[$i]; $y = $plain[$j]
        if (Overlaps $x.R $y.R) {
            # the thumbnail size's up-down control sits on its edit's right end (UDS_ALIGNRIGHT, as before 423)
            if (($x.Cls -eq 'msctls_updown32' -and $y.Id -eq 620) -or ($y.Cls -eq 'msctls_updown32' -and $x.Id -eq 620)) { continue }
            $over += ('{0}/{1}' -f $x.Id, $y.Id)
        } } }
    Row $n 'NO-OVERLAP' (V ($over.Count -eq 0)) ("overlapping controls: {0}" -f $(if ($over.Count) { $over -join ', ' } else { 'none' }))
    $groups = @($ctls | Where-Object { $_.Group })
    $loose = @()
    foreach ($c in $plain) {
        $hit = @($groups | Where-Object { Intersects $_.R $c.R })
        foreach ($g in $hit) { if (-not (Inside $c.R $g.R)) { $loose += ('{0} in group {1}' -f $c.Id, $g.Id) } }
    }
    $gIcon = @($groups | Where-Object { $_.Id -eq $IDC_ICONSET_GROUP })[0]; $gTab = @($groups | Where-Object { $_.Id -eq $IDC_TABSTYLE_GROUP })[0]
    $order = ($null -ne $gIcon) -and ($null -ne $gTab) -and ($gTab.R[1] -ge $gIcon.R[3])
    $radios = @($plain | Where-Object { $_.Id -eq $IDC_TABSTYLE_SQUARE -or $_.Id -eq $IDC_TABSTYLE_ROUNDED })
    $inTab = ($radios.Count -eq 2) -and (@($radios | Where-Object { -not (Inside $_.R $gTab.R) }).Count -eq 0)
    Row $n 'GROUPS' (V ($loose.Count -eq 0 -and $order -and $inTab)) ("controls crossing a group box edge: {0}; Icon style y {1}..{2}, Tab style y {3}..{4}; both radios inside Tab style: {5}" -f $(if ($loose.Count) { $loose -join ', ' } else { 'none' }), $gIcon.R[1], $gIcon.R[3], $gTab.R[1], $gTab.R[3], $inTab)
    # the dialog base unit from two controls whose DLU widths are fixed: Icon style (295) and Fluent 2 (70)
    $fl = @($plain | Where-Object { $_.Id -eq 6292 })[0]
    $script:LivePage = [pscustomobject]@{ GroupPx = ($gIcon.R[2] - $gIcon.R[0]); RadioPx = ($fl.R[2] - $fl.R[0]) }
}

# static: the texts of the moved and new controls of every enabled language fit their widths
function Run-Fit {
    $n = 'FIT'
    if (-not (Want $n)) { return }
    try {
        $font = New-Object Drawing.Font('MS Shell Dlg 2', 8)
        $bmp = New-Object Drawing.Bitmap(10, 10); $g = [Drawing.Graphics]::FromImage($bmp)
        $flags = [Windows.Forms.TextFormatFlags]::SingleLine -bor [Windows.Forms.TextFormatFlags]::NoPadding
        $dpi = $g.DpiX
        $baseX = 0
        if ($script:LivePage) { $baseX = ($script:LivePage.GroupPx * 4.0 / 295 + $script:LivePage.RadioPx * 4.0 / 70) / 2 }
        else { $abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'; $baseX = ([Windows.Forms.TextRenderer]::MeasureText($g, $abc, $font, (New-Object Drawing.Size(2000, 100)), $flags).Width / 26 + 1) / 2 }
        $check = [int](13 * $dpi / 96) + [int](4 * $dpi / 96)
        $tpl = Join-Path (Split-Path (Split-Path $Exe)) 'translator\templates\salamand.slt'
        $langs = @()
        foreach ($sec in ((Get-Content -LiteralPath (Join-Path $RepoRoot 'translations\languages.cfg') -Raw) -split '(?m)^\[')) {
            $m = [regex]::Match($sec, '^(\w+)\]'); if (-not $m.Success) { continue }
            if ($sec -match '(?m)^enabled\s*=\s*on') { $langs += $m.Groups[1].Value }
        }
        $files = @(, @('english', $tpl)) + @($langs | ForEach-Object { , @($_, (Join-Path $RepoRoot ("translations\{0}\salamand.slt" -f $_))) })
        # control id -> kind (group = a group box title, radio, text = a static)
        $kinds = @{ 1151 = 'group'; 1153 = 'group'; 1154 = 'text'; 1155 = 'text'; 6291 = 'group'; 6302 = 'group'; 6303 = 'radio'; 6304 = 'radio'; 6292 = 'radio'; 6293 = 'radio' }
        foreach ($pair in $files) {
            $lang = $pair[0]
            if (-not (Test-Path -LiteralPath $pair[1])) { Row $n $lang 'FAIL' ('missing ' + $pair[1]); continue }
            $lines = [IO.File]::ReadAllLines($pair[1], [Text.Encoding]::UTF8)
            # the Appearance dialog: the section that holds control 6302 (or 6291 before the refresh)
            $start = -1
            for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -like '[[]DIALOG *') { $start = $i }; if ($lines[$i] -like '6291,*') { break } }
            $sect = @(); for ($i = $start + 1; $i -lt $lines.Count -and $lines[$i] -notlike '[[]*'; $i++) { $sect += $lines[$i] }
            $ok = $true; $facts = @()
            foreach ($ctl in @(1151, 1153, 1154, 1155, 6291, 6292, 6293, 6302, 6303, 6304)) {
                $line = @($sect | Where-Object { $_ -like ("{0},*" -f $ctl) })[0]
                if (-not $line) { $ok = $false; $facts += ('{0} missing' -f $ctl); continue }
                $m = [regex]::Match($line, '^\d+,(-?\d+),(-?\d+),(\d+),(\d+),\d+,"(.*)"$')
                $text = $m.Groups[5].Value -replace '&&', "`0" -replace '&', '' -replace "`0", '&'
                $px = [int][Math]::Round([int]$m.Groups[3].Value * $baseX / 4)
                $tw = [Windows.Forms.TextRenderer]::MeasureText($g, $text.Trim(), $font, (New-Object Drawing.Size(4000, 100)), $flags).Width
                $room = switch ($kinds[$ctl]) { 'group' { $px - [int](16 * $dpi / 96) } 'radio' { $px - $check } default { $px } }
                $x = [int]$m.Groups[1].Value; $w = [int]$m.Groups[3].Value
                $fits = ($tw -le $room) -and ($x + $w -le 299)
                if (-not $fits) { $ok = $false }
                $facts += ("{0} '{1}' {2}/{3} px{4}" -f $ctl, $text.Trim(), $tw, $room, $(if ($fits) { '' } else { ' CLIPPED' }))
            }
            Row $n $lang (V $ok) ($facts -join '; ')
            # review 1 (S1): the Panel Font field (612) shows IDS_FONTDESCRIPTION "%d pt. %s (%s)" with
            # IDS_FONTDESCRIPTION_DEF / _CST in the panel font at the field's height (Segoe UI 8 pt here);
            # both forms with a long face name must fit the field (2 px border + 2 px margin each side)
            $l612 = @($sect | Where-Object { $_ -like '612,*' })[0]
            $fmt = @($lines | Where-Object { $_ -like '10280,*' })[0]; $def = @($lines | Where-Object { $_ -like '10281,*' })[0]; $cst = @($lines | Where-Object { $_ -like '10282,*' })[0]
            if (-not $l612 -or -not $fmt -or -not $def -or -not $cst) { Row $n ($lang + '-FONTFIELD') 'FAIL' 'a row (612, 10280-10282) is missing'; continue }
            $w612 = [int]([regex]::Match($l612, '^\d+,-?\d+,-?\d+,(\d+),').Groups[1].Value)
            $px612 = [int][Math]::Round($w612 * $baseX / 4) - 8
            $q = { param($r) [regex]::Match($r, '^\d+,\d+,"(.*)"$').Groups[1].Value }
            $f = (& $q $fmt) -replace '%d', '{0}' -replace '%s', '{1}'
            $i = $f.IndexOf('{1}'); $f = $f.Substring(0, $i) + '{1}' + $f.Substring($i + 3).Replace('{1}', '{2}')
            $seg = New-Object Drawing.Font('Segoe UI', 8)
            $worstF = 0; $worstT = ''
            foreach ($t in @(($f -f 9, 'Segoe UI', (& $q $def)), ($f -f 10, 'Microsoft Sans Serif', (& $q $cst)))) {
                $tw = [Windows.Forms.TextRenderer]::MeasureText($g, $t, $seg, (New-Object Drawing.Size(4000, 100)), $flags).Width
                if ($tw -gt $worstF) { $worstF = $tw; $worstT = $t }
            }
            $seg.Dispose()
            Row $n ($lang + '-FONTFIELD') (V ($worstF -le $px612)) ("612 widest '{0}' {1}/{2} px" -f $worstT, $worstF, $px612)
        }
        $g.Dispose(); $bmp.Dispose()
    } catch { Row $n 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc423_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    foreach ($d in ($TabsL + $TabsR)) { NewDir $d }
    if (-not (Test-Path -LiteralPath $CapDir)) { [void](New-Item -ItemType Directory -Path $CapDir) }
    Out ("tabs423_probe (feature 423) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    $fm = [Tc423]::FontMetrics()
    Out ("Date    : {0}; registry key existed {1}; fixture {2}; font height {3}, avg char {4}; before captures {5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, (Esc $Root), $fm[0], $fm[1], $BeforeDir)
    Out ''
    Run-Default
    Run-Unknown
    Run-Rounded
    Run-Hover
    Run-Page
    Run-Fit
    Row 'MOUSE' 'REAL' 'NOT DRIVEN' 'a real mouse hover over a square tab needs an input desktop (release checklist)'
    Row 'DPI' 'SCALES' 'NOT DRIVEN' 'the hidden desktop runs at one system DPI; the square box is whole pixels at every scale'
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
