<#
.SYNOPSIS
    Feature 404 probe: the panel tab strip's variant F look (captured and compared with the
    evidence images), live drag reorder, close on release and the two other-panel commands.

.DESCRIPTION
    Runs (one program start each):
      LOOK-LIGHT / LOOK-DARK  six tabs in the left panel (the evidence set: Downloads, fonts,
               tandemcommander, src, 2021_silon_bubble_sort_visualisation under the fixture, and
               E:\), the third active; the main window is sized until the left strip is 786 px
               wide; states normal (WM_NCACTIVATE TRUE), inactive (WM_NCACTIVATE FALSE), hovered
               tab 4, hovered close glyph of the active tab, hovered plus (posted WM_MOUSEMOVE).
               Each capture (PrintWindow PW_CLIENTONLY of the strip) is compared with
               evidence\variantF_<theme>_<state>.png: a pixel may differ only where the evidence's
               3x3 neighbourhood is not uniform, by at most 64 per channel (spec clarification 1).
               With -Label before also evidence\current_<theme>_normal.png (the old look, control).
      MOUSE    tabs A B C D: drag A past C's centre (posted down / moves / up) -> B C A D; a drag
               cancelled by WM_CANCELMODE and one by WM_CAPTURECHANGED -> order unchanged; a drag
               that leaves the strip vertically -> still reorders; a press on a tab's X without
               release -> nothing closes, no switch; the release over the same X -> closes; press
               on X, move off, release -> nothing.
      MENU     left A B (B active), right R: the commands the context menu posts:
               Move to Other Panel (CM_LEFT_MOVETABTOOTHER 2885) -> left A, right R B (B active),
               Reopen Closed Tab brings nothing back; New Tab as Other Panel (CM_LEFT_NEWTABASOTHER
               2887) -> left A B; Move with a single tab -> nothing.
    State is read from the program itself: Options > Save Configuration (posted) writes both
    panels' tab lists (HKCU\Software\Tandem Commander\Settings\{Left,Right} Panel\Tabs).
    NOT DRIVEN here: Esc during a drag and the feel of the animation (real keyboard / mouse), a
    refused leave (no shipped plug-in refuses a leave - feature 078 deviation).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label = 'after',
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
Add-Type -AssemblyName System.Drawing

if (-not ('Tc404' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public static class Tc404
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int left, top, right, bottom; }
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
    [DllImport("user32.dll")] static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
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

    // EnvFont metrics as the program measures them (SPI_GETICONTITLELOGFONT)
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
    public static void Send(IntPtr h, uint msg, int wp, int x, int y) { IntPtr r; SendMessageTimeoutW(h, msg, (IntPtr)wp, LP(x, y), 0, 10000, out r); }
    public static void SendRaw(IntPtr h, uint msg, IntPtr wp, IntPtr lp) { IntPtr r; SendMessageTimeoutW(h, msg, wp, lp, 0, 10000, out r); }

    public static Bitmap Capture(IntPtr h)
    {
        int[] s = ClientSize(h);
        var bmp = new Bitmap(Math.Max(1, s[0]), Math.Max(1, s[1]), PixelFormat.Format32bppRgb);
        using (var g = Graphics.FromImage(bmp))
        {
            IntPtr dc = g.GetHdc();
            PrintWindow(h, dc, 1 /*PW_CLIENTONLY*/);
            g.ReleaseHdc(dc);
        }
        return bmp;
    }

    static int[] Pixels(Bitmap b)
    {
        var r = new Rectangle(0, 0, b.Width, b.Height);
        var d = b.LockBits(r, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var px = new int[b.Width * b.Height];
        Marshal.Copy(d.Scan0, px, 0, px.Length);
        b.UnlockBits(d);
        for (int i = 0; i < px.Length; i++) px[i] &= 0xFFFFFF;
        return px;
    }

    // returns "verdict|facts"; verdict PASS/FAIL; writes a diff image next to 'diffPng' on differences
    public static string Compare(Bitmap cap, string evidencePng, string diffPng)
    {
        using (var ev = new Bitmap(evidencePng))
        {
            if (cap.Width != ev.Width || cap.Height != ev.Height)
                return string.Format("FAIL|size {0}x{1}, evidence {2}x{3}", cap.Width, cap.Height, ev.Width, ev.Height);
            int w = ev.Width, h = ev.Height;
            int[] a = Pixels(cap), e = Pixels(ev);
            int exact = 0, edge = 0, fail = 0, maxEdge = 0, maxFail = 0, fx = -1, fy = -1;
            var diff = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    int p = a[y * w + x], q = e[y * w + x];
                    int d = Math.Max(Math.Abs(((p >> 16) & 255) - ((q >> 16) & 255)), Math.Max(Math.Abs(((p >> 8) & 255) - ((q >> 8) & 255)), Math.Abs((p & 255) - (q & 255))));
                    if (d == 0) { exact++; diff.SetPixel(x, y, Color.FromArgb(255, 255, 255, 255)); continue; }
                    bool uniform = true;
                    for (int dy = -1; dy <= 1 && uniform; dy++)
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            int xx = x + dx, yy = y + dy;
                            if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
                            if (e[yy * w + xx] != q) { uniform = false; break; }
                        }
                    if (!uniform && d <= 64) { edge++; if (d > maxEdge) maxEdge = d; diff.SetPixel(x, y, Color.FromArgb(255, 255, 200, 0)); }
                    else { fail++; if (d > maxFail) maxFail = d; if (fx < 0) { fx = x; fy = y; } diff.SetPixel(x, y, Color.FromArgb(255, 255, 0, 0)); }
                }
            if (edge + fail > 0 && diffPng != null) diff.Save(diffPng, ImageFormat.Png);
            diff.Dispose();
            string facts = string.Format("exact {0}, edge-tolerated {1} (max {2}), failing {3} (max {4}{5})", exact, edge, maxEdge, fail, maxFail,
                fail > 0 ? string.Format(", first at {0},{1}", fx, fy) : "");
            return (fail == 0 ? "PASS|" : "FAIL|") + facts;
        }
    }
}
'@
}

$Root = $TempRoot + '\tc404'
$StartDir = $Root + '\start'
$Ev = Join-Path $PSScriptRoot 'evidence'
$CapDir = Join-Path $PSScriptRoot ('captures_' + $Label)
$CfgReg = $RegKey + '\Settings\Configuration'
$KeyL = 'HKCU:\Software\Tandem Commander\Settings\Left Panel'
$KeyR = 'HKCU:\Software\Tandem Commander\Settings\Right Panel'
$CM_SAVECONFIG = 687
$CM_LEFT_REOPENTAB = 2882
$CM_LEFT_MOVETABTOOTHER = 2885
$CM_LEFT_NEWTABASOTHER = 2887
$WM_MOUSEMOVE = 0x0200; $WM_LBUTTONDOWN = 0x0201; $WM_LBUTTONUP = 0x0202; $WM_CANCELMODE = 0x001F; $WM_CAPTURECHANGED = 0x0215; $WM_NCACTIVATE = 0x0086
$MK_LBUTTON = 1

function Prep-Registry([int]$Theme, $LeftTabs, [int]$LeftActive, $RightTabs, [int]$RightActive) {
    & cmd.exe /c "reg query `"$CfgReg`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    Set-Config
    & reg.exe add $CfgReg /v 'Panel Tabs' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add $CfgReg /v 'Theme Mode' /t REG_DWORD /d $Theme /f | Out-Null
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
    $a = @('-t', 'T404', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
function Strip([int]$Id) {
    $s = @([Tc404]::Strips((Get-Main $Id)))
    if ($s.Count -lt 1) { throw 'no tab strip (child id 958) found' }
    return $s[0]
}
# sizes the main window until the left strip's client area is $Want px wide
function Size-Strip([int]$Id, [int]$Want) {
    $main = Get-Main $Id
    [void][Drv098f]::PostMessageW($main, 0x0112, [IntPtr]0xF120, [IntPtr]::Zero)   # SC_RESTORE
    Start-Sleep -Milliseconds 500
    $w = 1700
    for ($i = 0; $i -lt 16; $i++) {
        [void][Tc404]::SetWindowPos($main, [IntPtr]::Zero, 0, 0, $w, 720, 0x0014)   # SWP_NOZORDER | SWP_NOACTIVATE
        Start-Sleep -Milliseconds 400
        [void](Serve $Id 3)
        $sw = ([Tc404]::ClientSize((Strip $Id)))[0]
        if ($sw -eq $Want) { return $true }
        $step = ($Want - $sw) * 2
        if ([Math]::Abs($step) -le 2) { $step = [Math]::Sign($Want - $sw) }
        $w += $step
    }
    return $false
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

# the strip geometry as the program lays it out (old: 21 px, TabsLeft 1, pad 4; new: TabsLeft 8, pad 10)
function Geo([IntPtr]$Hs, [int]$Count) {
    $sz = [Tc404]::ClientSize($Hs); $W = $sz[0]; $H = $sz[1]
    $fm = [Tc404]::FontMetrics(); $avg = $fm[1]
    $old = ($H -le $fm[0] + 6)
    if ($old) { $left = 1; $maxW = 20 * $avg + 2 * 4 + 8; $closePad = 4; $top = 0 } else { $left = 8; $maxW = 20 * $avg + 2 * 10 + 8 + 16 + 6; $closePad = 8; $top = 3 }
    $tw = [Math]::Floor(($W - $left - $H - 2) / $Count); if ($tw -gt $maxW) { $tw = $maxW }
    $cy = if ($old) { [int][Math]::Floor(($H - 8) / 2) + 4 } else { 3 + [int][Math]::Floor(($H - 3 - 8) / 2) + 4 }
    return [pscustomobject]@{ W = $W; H = $H; Left = $left; TabW = $tw; ClosePad = $closePad; Old = $old; CloseY = $cy; MidY = [int](($top + $H) / 2) }
}
function TabCx($g, [int]$i) { return [int]($g.Left + $i * $g.TabW + $g.TabW / 2) }
function CloseCx($g, [int]$i) { return [int]($g.Left + ($i + 1) * $g.TabW - 1 - $g.ClosePad - 4) }
function PlusCx($g, [int]$n) { return [int]($g.Left + $n * $g.TabW + 2 + $g.H / 2) }

function Cap-Compare([string]$Run, [string]$State, [IntPtr]$Hs, [string]$EvName) {
    Start-Sleep -Milliseconds 300
    $bmp = [Tc404]::Capture($Hs)
    if (-not (Test-Path -LiteralPath $CapDir)) { [void](New-Item -ItemType Directory -Path $CapDir) }
    $capFile = Join-Path $CapDir ($EvName -replace '\.png$', '_capture.png')
    $bmp.Save($capFile, [Drawing.Imaging.ImageFormat]::Png)
    $evFile = Join-Path $Ev $EvName
    $r = [Tc404]::Compare($bmp, $evFile, ($capFile -replace '_capture\.png$', '_diff.png'))
    $bmp.Dispose()
    $parts = $r.Split('|', 2)
    Row $Run $State $parts[0] ("vs {0}: {1}" -f $EvName, $parts[1])
}

# ---------------------------------------------------------------------------
function Run-Look([string]$Theme) {
    $name = 'LOOK-' + $Theme.ToUpper()
    if (-not (Want $name)) { return }
    if (-not [IO.Directory]::Exists('E:\')) { Row $name 'SETUP' 'NOT DRIVEN' 'no drive E: on this machine (the evidence set has an E:\ tab)'; return }
    $D = $Root + '\look'
    $tabs = @("$D\Downloads", "$D\fonts", "$D\tandemcommander", "$D\src", "$D\2021_silon_bubble_sort_visualisation", 'E:\')
    if (-not (Prep-Registry ([int]($Theme -eq 'dark')) $tabs 2 @($StartDir) 0)) { Row $name 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run "$D\tandemcommander" $StartDir
        if (-not (Size-Strip $id 786)) { Row $name 'SIZE' 'FAIL' ("strip width {0}, wanted 786" -f ([Tc404]::ClientSize((Strip $id)))[0]); return }
        $Hs = Strip $id; $main = Get-Main $id
        $g = Geo $Hs 6
        [Tc404]::SendRaw($main, $WM_NCACTIVATE, [IntPtr]1, [IntPtr]::Zero)
        [Tc404]::Send($Hs, $WM_MOUSEMOVE, 0, 2, 400)    # out of the strip: nothing hot
        Cap-Compare $name 'NORMAL' $Hs "variantF_${Theme}_normal.png"
        if ($Label -eq 'before') { Cap-Compare $name 'CONTROL' $Hs "current_${Theme}_normal.png" }
        [Tc404]::SendRaw($main, $WM_NCACTIVATE, [IntPtr]0, [IntPtr]::Zero)
        Cap-Compare $name 'INACTIVE' $Hs "variantF_${Theme}_inactive.png"
        [Tc404]::SendRaw($main, $WM_NCACTIVATE, [IntPtr]1, [IntPtr]::Zero)
        [Tc404]::Send($Hs, $WM_MOUSEMOVE, 0, (TabCx $g 4), $g.MidY)
        Cap-Compare $name 'HOVERTAB' $Hs "variantF_${Theme}_hovertab.png"
        [Tc404]::Send($Hs, $WM_MOUSEMOVE, 0, (CloseCx $g 2), $g.CloseY)
        Cap-Compare $name 'HOVERCLOSE' $Hs "variantF_${Theme}_hoverclose.png"
        [Tc404]::Send($Hs, $WM_MOUSEMOVE, 0, (PlusCx $g 6), $g.MidY)
        Cap-Compare $name 'HOVERPLUS' $Hs "variantF_${Theme}_hoverplus.png"
        $s = Snap $id
        Row $name 'TABS' (V ((Order $s.L) -eq 'Downloads fonts tandemcommander src 2021_silon_bubble_sort_visualisation E:' -and $s.L.Active -eq 2)) (Desc $s)
    }
    catch { Row $name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

function Drag([IntPtr]$Hs, [int]$X0, [int]$Y0, [int[]]$Xs, [int[]]$Ys) {
    [Tc404]::Post($Hs, $WM_LBUTTONDOWN, $MK_LBUTTON, $X0, $Y0)
    Start-Sleep -Milliseconds 120
    for ($i = 0; $i -lt $Xs.Count; $i++) { [Tc404]::Post($Hs, $WM_MOUSEMOVE, $MK_LBUTTON, $Xs[$i], $Ys[$i]); Start-Sleep -Milliseconds 30 }
}
function Steps([int]$From, [int]$To, [int]$Y) {
    $xs = @(); $ys = @(); $n = 12
    for ($i = 1; $i -le $n; $i++) { $xs += [int]($From + ($To - $From) * $i / $n); $ys += $Y }
    return [pscustomobject]@{ X = [int[]]$xs; Y = [int[]]$ys }
}

function Run-Mouse {
    if (-not (Want 'MOUSE')) { return }
    $M = $Root + '\mouse'
    $tabs = @("$M\A", "$M\B", "$M\C", "$M\D")
    if (-not (Prep-Registry 0 $tabs 0 @($StartDir) 0)) { Row 'MOUSE' 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run "$M\A" $StartDir
        $Hs = Strip $id
        $g = Geo $Hs 4
        $s = Snap $id
        Row 'MOUSE' 'START' (V ((Order $s.L) -eq 'A B C D' -and $s.L.Active -eq 0)) ("{0}; strip {1}x{2}, tab width {3}" -f (Desc $s), $g.W, $g.H, $g.TabW)
        # A past C's centre
        $st = Steps (TabCx $g 0) ((TabCx $g 2) + 6) $g.MidY
        Drag $Hs (TabCx $g 0) $g.MidY $st.X $st.Y
        [Tc404]::Post($Hs, $WM_LBUTTONUP, 0, (TabCx $g 2) + 6, $g.MidY)
        Start-Sleep -Milliseconds 700
        $s = Snap $id
        Row 'MOUSE' 'DRAG' (V ((Order $s.L) -eq 'B C A D' -and $s.L.Active -eq 2)) ('A dragged past the centre of C, released: ' + (Desc $s))
        # cancelled by WM_CANCELMODE
        $st = Steps (TabCx $g 0) (TabCx $g 3) $g.MidY
        Drag $Hs (TabCx $g 0) $g.MidY $st.X $st.Y
        [Tc404]::Post($Hs, $WM_CANCELMODE, 0, 0, 0)
        Start-Sleep -Milliseconds 200
        [Tc404]::Post($Hs, $WM_LBUTTONUP, 0, (TabCx $g 3), $g.MidY)
        Start-Sleep -Milliseconds 700
        $s = Snap $id
        Row 'MOUSE' 'CANCELMODE' (V ((Order $s.L) -eq 'B C A D')) ('B dragged onto D, WM_CANCELMODE, released: ' + (Desc $s))
        # cancelled by losing the capture
        $st = Steps (TabCx $g 0) (TabCx $g 3) $g.MidY
        Drag $Hs (TabCx $g 0) $g.MidY $st.X $st.Y
        [Tc404]::Post($Hs, $WM_CAPTURECHANGED, 0, 0, 0)
        Start-Sleep -Milliseconds 200
        [Tc404]::Post($Hs, $WM_LBUTTONUP, 0, (TabCx $g 3), $g.MidY)
        Start-Sleep -Milliseconds 700
        $s = Snap $id
        Row 'MOUSE' 'CAPLOST' (V ((Order $s.L) -eq 'B C A D')) ('B dragged onto D, WM_CAPTURECHANGED, released: ' + (Desc $s))
        # no tear-off: the cursor leaves the strip vertically, the drag goes on
        $xs = @(); $ys = @()
        for ($i = 1; $i -le 12; $i++) { $xs += [int]((TabCx $g 0) + ((TabCx $g 1) + 6 - (TabCx $g 0)) * $i / 12); $ys += [int]($g.MidY + 6 * $i) }
        Drag $Hs (TabCx $g 0) $g.MidY ([int[]]$xs) ([int[]]$ys)
        [Tc404]::Post($Hs, $WM_LBUTTONUP, 0, (TabCx $g 1) + 6, $g.MidY + 72)
        Start-Sleep -Milliseconds 700
        $s = Snap $id
        Row 'MOUSE' 'NOTEAR' (V ((Order $s.L) -eq 'C B A D')) ('B dragged past the centre of C, 72 px below the strip: ' + (Desc $s))
        # close on release: press on the X of tab 1 (B, not active)
        $act0 = $s.L.Active
        [Tc404]::Post($Hs, $WM_MOUSEMOVE, 0, (CloseCx $g 1), $g.CloseY); Start-Sleep -Milliseconds 100
        [Tc404]::Post($Hs, $WM_LBUTTONDOWN, $MK_LBUTTON, (CloseCx $g 1), $g.CloseY)
        Start-Sleep -Milliseconds 400
        $s = Snap $id
        Row 'MOUSE' 'XPRESS' (V ((Order $s.L) -eq 'C B A D' -and $s.L.Active -eq $act0)) ('left button down on the X of B, not released: ' + (Desc $s))
        [Tc404]::Post($Hs, $WM_LBUTTONUP, 0, (CloseCx $g 1), $g.CloseY)
        Start-Sleep -Milliseconds 500
        $s = Snap $id
        Row 'MOUSE' 'XRELEASE' (V ((Order $s.L) -eq 'C A D')) ('released over the same X: ' + (Desc $s))
        # press on the X of tab 2 (D), move off onto the tab body, release there
        $g = Geo $Hs 3
        $act0 = $s.L.Active
        [Tc404]::Post($Hs, $WM_MOUSEMOVE, 0, (CloseCx $g 2), $g.CloseY); Start-Sleep -Milliseconds 100
        [Tc404]::Post($Hs, $WM_LBUTTONDOWN, $MK_LBUTTON, (CloseCx $g 2), $g.CloseY)
        Start-Sleep -Milliseconds 150
        [Tc404]::Post($Hs, $WM_MOUSEMOVE, $MK_LBUTTON, (TabCx $g 2) - 20, $g.MidY)
        Start-Sleep -Milliseconds 150
        [Tc404]::Post($Hs, $WM_LBUTTONUP, 0, (TabCx $g 2) - 20, $g.MidY)
        Start-Sleep -Milliseconds 500
        $s = Snap $id
        Row 'MOUSE' 'XOFF' (V ((Order $s.L) -eq 'C A D' -and $s.L.Active -eq $act0)) ('pressed on the X of D, moved off, released: ' + (Desc $s))
    }
    catch { Row 'MOUSE' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

function Run-Menu {
    if (-not (Want 'MENU')) { return }
    $N = $Root + '\menu'
    if (-not (Prep-Registry 0 @("$N\A", "$N\B") 1 @("$N\R") 0)) { Row 'MENU' 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run "$N\B" "$N\R"
        $s = Snap $id
        Row 'MENU' 'START' (V ((Order $s.L) -eq 'A B' -and $s.L.Active -eq 1 -and (Order $s.R) -eq 'R')) (Desc $s)
        Post-Cmd (Get-Main $id) $CM_LEFT_MOVETABTOOTHER
        [void](Serve $id 10)
        $s = Snap $id
        Row 'MENU' 'MOVE' (V ((Order $s.L) -eq 'A' -and (Order $s.R) -eq 'R B' -and $s.R.Active -eq 1)) ('Move to Other Panel on B: ' + (Desc $s))
        Post-Cmd (Get-Main $id) $CM_LEFT_REOPENTAB
        [void](Serve $id 10)
        $s = Snap $id
        Row 'MENU' 'NOREOPEN' (V ((Order $s.L) -eq 'A')) ('Reopen Closed Tab after the move: ' + (Desc $s))
        Post-Cmd (Get-Main $id) $CM_LEFT_MOVETABTOOTHER
        [void](Serve $id 10)
        $s = Snap $id
        Row 'MENU' 'MOVE-SINGLE' (V ((Order $s.L) -eq 'A' -and (Order $s.R) -eq 'R B')) ('Move to Other Panel with a single tab: ' + (Desc $s))
        Post-Cmd (Get-Main $id) $CM_LEFT_NEWTABASOTHER
        [void](Serve $id 10)
        $s = Snap $id
        Row 'MENU' 'NEWASOTHER' (V ((Order $s.L) -eq 'A B' -and $s.L.Active -eq 1 -and (Order $s.R) -eq 'R B')) ('New Tab as Other Panel (right shows B): ' + (Desc $s))
        Row 'MENU' 'REFUSED' 'NOT DRIVEN' 'a refused leave needs a plug-in that refuses (CHPPFR_CANNOTCLOSEPATH); no shipped plug-in does (feature 078 deviation) - verified by reading MoveTabToOtherPanel'
    }
    catch { Row 'MENU' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc404_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    foreach ($n in @('Downloads', 'fonts', 'tandemcommander', 'src', '2021_silon_bubble_sort_visualisation')) { NewDir ($Root + '\look\' + $n) }
    foreach ($n in @('A', 'B', 'C', 'D')) { NewDir ($Root + '\mouse\' + $n) }
    foreach ($n in @('A', 'B', 'R')) { NewDir ($Root + '\menu\' + $n) }
    Out ("tabs404_probe (feature 404) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    $fm = [Tc404]::FontMetrics()
    Out ("Date    : {0}; registry key existed {1}; fixture {2}; font height {3}, avg char {4}; DPI scale {5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, (Esc $Root), $fm[0], $fm[1], ([Tc404]::GetSystemMetrics(0)))
    Out ''
    Run-Look 'light'
    Run-Look 'dark'
    Run-Mouse
    Run-Menu
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
