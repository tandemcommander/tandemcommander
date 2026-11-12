# Feature 427 probe (backlog item tmavy-motiv, GitHub #25): plug-in toolbars, File Comparator's
# chrome and plug-in checkbox labels in the Dark theme; the Default theme unchanged.
# MUST run through tools\run_on_hidden_desktop.ps1 (it starts the program and drives its windows).
# The registry key is exported first, restored afterwards and verified (fix_probe_lib Backup-Reg /
# Restore-Reg); the program is started from a fixture under %TEMP% only.
#
# Rows, per theme (DARK, DEFAULT):
#   PV-TOOLBAR  PictView viewer toolbar: neutral glyph pixels (outlines, shading) darker than the strip
#               (Dark: < 10 % of before; saturated colours are kept by the 029 rule, counted apart)
#   FC-TOOLBAR  File Comparator toolbar: the same
#   FC-GREY     File Comparator: light-grey (#F0F0F0 +-2) pixels outside its two text views
#               (Dark: < 1 % of before)
#   FC-LIGHT    the same for every light neutral pixel (white too: the rows below the rebar's bands)
#               (Dark: < 1 % of before + 200 for the glyphs' own highlights)
#   PV-LABELS   PictView settings, all five pages: every checkbox label contrast >= 4.5
#   RN-LABELS   Batch Rename: every checkbox label contrast >= 4.5
#   PV-COLOR / FC-COLOR coloured glyph pixels below 1.6:1 on the strip (Dark: < 10 % of before)
#   LIVE        Dark -> Default -> Dark with both windows open, File Comparator on two different files
#               (LIVE-D: opened in Default, then Default -> Dark -> Default -> Dark): every whole window
#               equals a window opened in that theme (File Comparator outside its views' text: 0 px;
#               the viewer outside its image: <= 120 px for the status bar's mouse-state icon)
#   PV-STATUS   light-grey pixels in the viewer's status bar (Dark: <= 1 %)
#   FC-LIST     the dropped list of differences in Dark: light pixels <= 2 %
#   DEFAULT-SAME (after only) the Default theme's toolbar and File Comparator captures equal the
#               before run's
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Exe, [Parameter(Mandatory = $true)][string]$Repo,
      [Parameter(Mandatory = $true)][string]$Label)
$ErrorActionPreference = 'Stop'
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
$Repo = [IO.Path]::GetFullPath($Repo)
$Exe = [IO.Path]::GetFullPath($Exe)
. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $Repo 'specs\416-fluent-icon-set\probe\capture416_lib.ps1')
$ProbeDir = Join-Path $Repo 'specs\427-dark-plugin-toolbars\probe'
$CapDir = Join-Path $ProbeDir ("captures_{0}" -f $Label)
$BeforeDir = Join-Path $ProbeDir 'captures_before'
$OutFile = Join-Path $ProbeDir ("result_{0}_rows.txt" -f $Label)
$Root = $TempRoot + '\tc427probe'
$StartDir = $Root + '\start'
$Left = $Root + '\left'
$LeftDiff = $Root + '\diff'   # two different images: File Comparator shows differences, its list has items
$CfgKey = "$RegKey\Settings\Configuration"
$Image = Join-Path $Repo 'backlog\items\tmavy-motiv\evidence\issue25-pictview-settings-advanced.png'
if (-not (Test-Path -LiteralPath $Image)) { $Image = Join-Path $ProbeDir 'captures_measure\pictview_page4.png' }
[void][IO.Directory]::CreateDirectory($CapDir)

if (-not ('Px427' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Px427
{
    [DllImport("user32.dll")] public static extern int GetWindowLongW(IntPtr h, int i);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);
    public static int[] Px(Bitmap b)
    {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
        int[] px = new int[b.Width * b.Height];
        for (int y = 0; y < b.Height; y++) Marshal.Copy(IntPtr.Add(d.Scan0, y * d.Stride), px, y * b.Width, b.Width);
        b.UnlockBits(d);
        for (int i = 0; i < px.Length; i++) px[i] &= 0xFFFFFF;
        return px;
    }
    static double Lum(int c)
    {
        Func<int, double> f = v => { double s = v / 255.0; return s <= 0.03928 ? s / 12.92 : Math.Pow((s + 0.055) / 1.055, 2.4); };
        return 0.2126 * f((c >> 16) & 255) + 0.7152 * f((c >> 8) & 255) + 0.0722 * f(c & 255);
    }
    static double Contrast(int a, int b) { double x = Lum(a), y = Lum(b); return (Math.Max(x, y) + 0.05) / (Math.Min(x, y) + 0.05); }
    static int Mode(int[] px, int from, int width, int height, int stride)
    {
        var h = new Dictionary<int, int>();
        for (int y = 0; y < height; y++) for (int x = from; x < width; x++) { int c = px[y * stride + x]; int v; h.TryGetValue(c, out v); h[c] = v + 1; }
        int bg = 0, top = -1; foreach (var kv in h) if (kv.Value > top) { top = kv.Value; bg = kv.Key; }
        return bg;
    }
    // a checkbox label: the highest contrast of a pixel right of the glyph to the background
    public static double LabelContrast(Bitmap b, int glyph, out int bg, out int ink)
    {
        int[] px = Px(b);
        bg = Mode(px, glyph, b.Width, b.Height, b.Width);
        ink = bg; double best = 1;
        for (int y = 0; y < b.Height; y++) for (int x = glyph; x < b.Width; x++) { int c = px[y * b.Width + x]; double k = Contrast(c, bg); if (k > best) { best = k; ink = c; } }
        return best;
    }
    // toolbar glyphs: NEUTRAL pixels (outlines, shading) clearly darker than the strip's background
    // - what the core's Dark palette (feature 028/029) turns light; saturated colours with a
    // channel >= 120 are kept by that rule (as for the core's own Classic glyphs) and counted apart
    public static int DarkerThanStrip(Bitmap b, out int bg, out int saturated)
    {
        int[] px = Px(b);
        bg = Mode(px, 0, b.Width, b.Height, b.Width);
        double lb = Lum(bg); int n = 0; saturated = 0;
        foreach (int c in px)
        {
            if (c == bg || Lum(c) >= lb || Contrast(c, bg) <= 1.15) continue;
            // the toolbar's own chrome, not a glyph: separators and button frames in the Dark
            // palette's COLOR_BTNSHADOW (26,26,26) and COLOR_3DDKSHADOW (16,16,16)
            if (c == 0x1A1A1A || c == 0x101010) continue;
            int r = (c >> 16) & 255, g = (c >> 8) & 255, bb = c & 255;
            int mx = Math.Max(r, Math.Max(g, bb)), mn = Math.Min(r, Math.Min(g, bb));
            if (mx - mn < 32) n++; else saturated++;
        }
        return n;
    }
    // light neutral pixels (white and the classic face grey): every channel >= 230, max-min < 12
    public static int Light(Bitmap b, int x0, int y0, int x1, int y1)
    {
        int[] px = Px(b); int n = 0;
        for (int y = Math.Max(0, y0); y < Math.Min(b.Height, y1); y++)
            for (int x = Math.Max(0, x0); x < Math.Min(b.Width, x1); x++)
            {
                int c = px[y * b.Width + x], r = (c >> 16) & 255, g = (c >> 8) & 255, bb = c & 255;
                if (r >= 230 && g >= 230 && bb >= 230 && Math.Max(r, Math.Max(g, bb)) - Math.Min(r, Math.Min(g, bb)) < 12) n++;
            }
        return n;
    }
    // coloured glyph pixels (channel spread >= 32) nearly invisible on the strip: contrast < 1.6
    // (427 review M2: the blue arrows of PictView, ~1.2:1 before)
    public static int LowContrastColour(Bitmap b, out int bg)
    {
        int[] px = Px(b);
        bg = Mode(px, 0, b.Width, b.Height, b.Width);
        int n = 0;
        foreach (int c in px)
        {
            if (c == bg) continue;
            int r = (c >> 16) & 255, g = (c >> 8) & 255, bb = c & 255;
            int mx = Math.Max(r, Math.Max(g, bb)), mn = Math.Min(r, Math.Min(g, bb));
            // ClearType fringes of the zoom text ("100 %"): the strip's colour in two channels exactly
            int same = (r == ((bg >> 16) & 255) ? 1 : 0) + (g == ((bg >> 8) & 255) ? 1 : 0) + (bb == (bg & 255) ? 1 : 0);
            if (same >= 2) continue;
            if (mx - mn >= 32 && Contrast(c, bg) < 1.6) n++;
        }
        return n;
    }
    // pixels that differ between two captures of the same size outside the given rectangles
    // (x0,y0,x1,y1 quadruples): a stale part after a theme switch shows here
    public static int DiffOutside(Bitmap a, Bitmap b, int[] skip)
    {
        if (a.Width != b.Width || a.Height != b.Height) return -1;
        int[] pa = Px(a), pb = Px(b); int n = 0;
        for (int y = 0; y < a.Height; y++)
            for (int x = 0; x < a.Width; x++)
            {
                bool inside = false;
                for (int k = 0; k + 3 < skip.Length; k += 4)
                    if (x >= skip[k] && y >= skip[k + 1] && x < skip[k + 2] && y < skip[k + 3]) { inside = true; break; }
                if (!inside && pa[y * a.Width + x] != pb[y * a.Width + x]) n++;
            }
        return n;
    }
    [DllImport("user32.dll")] static extern bool RedrawWindow(IntPtr h, IntPtr r, IntPtr g, uint f);
    // INVALIDATE | ERASE | FRAME | ALLCHILDREN | UPDATENOW
    public static bool Repaint(IntPtr h) { return RedrawWindow(h, IntPtr.Zero, IntPtr.Zero, 0x0001 | 0x0004 | 0x0400 | 0x0080 | 0x0100); }
    public static int Grey(Bitmap b, int x0, int y0, int x1, int y1)
    {
        int[] px = Px(b); int n = 0;
        for (int y = Math.Max(0, y0); y < Math.Min(b.Height, y1); y++)
            for (int x = Math.Max(0, x0); x < Math.Min(b.Width, x1); x++)
            {
                int c = px[y * b.Width + x], r = (c >> 16) & 255, g = (c >> 8) & 255, bb = c & 255;
                if (Math.Abs(r - 0xF0) <= 2 && Math.Abs(g - 0xF0) <= 2 && Math.Abs(bb - 0xF0) <= 2) n++;
            }
        return n;
    }
    public static string CtrlShiftKey(IntPtr target, int vk)
    {
        uint pid; uint tid = GetWindowThreadProcessId(target, out pid);
        uint me = GetCurrentThreadId();
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed";
        var saved = new byte[256]; GetKeyboardState(saved);
        try
        {
            var k = (byte[])saved.Clone(); k[0x10] = k[0xA0] = 0x80; k[0x11] = k[0xA2] = 0x80;
            SetKeyboardState(k);
            PostMessageW(target, 0x0100, (IntPtr)vk, (IntPtr)1);
            IntPtr r; SendMessageTimeoutW(target, 0, IntPtr.Zero, IntPtr.Zero, 0, 3000, out r);
            System.Threading.Thread.Sleep(300);
            return "ok";
        }
        finally { SetKeyboardState(saved); PostMessageW(target, 0x0101, (IntPtr)vk, unchecked((IntPtr)0xC0000001)); AttachThreadInput(me, tid, false); }
    }
}
'@
}

function Checkboxes([IntPtr]$Top) {
    return @([Cap416]::Kids($Top) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::Cls($_) -eq 'Button' -and (@(2, 3, 5, 6) -contains ([Px427]::GetWindowLongW($_, -16) -band 0xF)) })
}
# the lowest label contrast of a window's checkboxes; details into the log
function Labels([IntPtr]$Top, [string]$Tag) {
    [void][Drv098f]::Send($Top, 0, 0, 0, 10000); Start-Sleep -Milliseconds 700
    $cap = [Cap416]::Capture($Top, $true); Save-Png $cap (Join-Path $CapDir ("{0}.png" -f $Tag))
    $min = 99.0; $n = 0
    foreach ($c in (Checkboxes $Top)) {
        $crop = [Cap416]::Crop($cap, $Top, $c); $bg = 0; $ink = 0
        $k = [Px427]::LabelContrast($crop, 18, [ref]$bg, [ref]$ink)
        Out ("  {0}: id {1} '{2}' bg #{3:X6} ink #{4:X6} contrast {5:0.00}" -f $Tag, [Cap416]::GetDlgCtrlID($c), (Tail ([Cap416]::Txt($c)) 36), $bg, $ink, $k)
        if ($k -lt $min) { $min = $k }; $n++; $crop.Dispose()
    }
    $cap.Dispose()
    return @{ N = $n; Min = $min }
}
# a toolbar's glyph pixels darker than its strip; the crop saved
function Toolbar-Dark([IntPtr]$Top, [IntPtr]$Tb, [string]$Tag) {
    $cap = [Cap416]::Capture($Top, $true)
    $crop = [Cap416]::Crop($cap, $Top, $Tb)
    Save-Png $crop (Join-Path $CapDir ("{0}.png" -f $Tag))
    $bg = 0; $sat = 0; $n = [Px427]::DarkerThanStrip($crop, [ref]$bg, [ref]$sat)
    $bg2 = 0; $low = [Px427]::LowContrastColour($crop, [ref]$bg2)
    $crop.Dispose(); $cap.Dispose()
    return @{ N = $n; Bg = $bg; Sat = $sat; Low = $low }
}
function Same-As-Before([string]$Name) {
    $a = Join-Path $BeforeDir $Name; $b = Join-Path $CapDir $Name
    if (-not (Test-Path $a) -or -not (Test-Path $b)) { return 'missing' }
    $x = New-Object Drawing.Bitmap $a; $y = New-Object Drawing.Bitmap $b
    try { return [Cap416]::Diff($x, $y) } finally { $x.Dispose(); $y.Dispose() }
}
function Set-HotKeys {
    $plugins = 'HKCU:\Software\Tandem Commander\Settings\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key' }
    $map = @(@{ Dll = 'filecomp\.spl$'; Id = 1; Key = 0x10343 }, @{ Dll = 'renamer\.spl$'; Id = 1; Key = 0x10352 })
    $notes = @()
    foreach ($k in @(Get-ChildItem $plugins)) {
        $dll = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DLL
        if (-not $dll) { continue }
        foreach ($m in $map) {
            if ($dll -notmatch $m.Dll) { continue }
            $menu = Join-Path $k.PSPath 'Menu'
            if (-not (Test-Path $menu)) { continue }
            foreach ($mi in @(Get-ChildItem $menu)) {
                if ((Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID -eq $m.Id) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value $m.Key -Type DWord; $notes += (Split-Path $dll -Leaf) }
            }
        }
    }
    return ($notes -join ', ')
}
function Open-ByKey([int]$Id, [int]$Vk, [double]$Seconds = 15) {
    $known = Get-Tops $Id
    [void][Px427]::CtrlShiftKey((Get-LeftList $Id), $Vk)
    return (Wait-NewWin $Id $known $Seconds)
}
function Open-Viewer([int]$Id, [string]$File = '') {
    if (-not $File) { $File = Join-Path $Left 'image.png' }
    [void](Do-ChangeDir $Id $File); [void](Serve $Id 8)
    [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000)
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 742
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -ne '#32770' }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 2500; return $w }
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}

function Run-Theme([int]$Theme) {
    $t = if ($Theme -eq 1) { 'DARK' } else { 'DEFAULT' }
    & reg.exe add $CfgKey /v 'Theme Mode' /t REG_DWORD /d $Theme /f | Out-Null
    $id = Start-Tc $Left
    [void](Serve $id 6)
    try {
        # PictView viewer: its toolbar (the widest visible child whose class names a tool bar)
        $viewer = Open-Viewer $id
        if ($viewer -eq [IntPtr]::Zero) { Row $t 'PV-TOOLBAR' 'FAIL' 'the viewer did not open'; return }
        # the viewer's rebar holds the menu bar and the toolbar (both core GUI windows): the lower one
        $rb = @(Get-Desc $viewer 'ReBarWindow32') | Select-Object -First 1
        $tbs = @()
        if ($rb) { $bars = @(Get-Desc $rb 'WinLib Universal Window2'); if ($bars.Count -ge 2) { $tbs = @($bars[$bars.Count - 1]) } }
        if ($tbs.Count -eq 0) { Out ("  viewer children: {0}" -f ((@([Cap416]::Kids($viewer)) | ForEach-Object { [Cap416]::Cls($_) } | Sort-Object -Unique) -join ', ')); Row $t 'PV-TOOLBAR' 'FAIL' 'no toolbar found' }
        else {
            $r = Toolbar-Dark $viewer $tbs[0] ("pv_toolbar_{0}" -f $t)
            $script:Num["PV-TOOLBAR $t"] = $r.N
            $script:Num["PV-COLOR $t"] = $r.Low
            Row $t 'PV-COLOR' 'INFO' ("coloured glyph pixels below 1.6:1 on the strip: {0}" -f $r.Low)
            Row $t 'PV-TOOLBAR' 'INFO' ("class {0}; strip #{1:X6}; neutral glyph pixels darker than the strip: {2} (saturated, kept by the palette rule: {3})" -f [Cap416]::Cls($tbs[0]), $r.Bg, $r.N, $r.Sat)
        }
        # the viewer's status bar (review 3, S2): light grey in Dark before
        $vcap = [Cap416]::Capture($viewer, $true); Save-Png $vcap (Join-Path $CapDir ("pv_window_{0}.png" -f $t))
        $sb = @(Get-Desc $viewer 'msctls_statusbar32') | Select-Object -First 1
        if ($sb) {
            $o = New-Object Cap416+POINT; $o.x = 0; $o.y = 0; [void][Cap416]::ClientToScreen($viewer, [ref]$o)
            $rc = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($sb, [ref]$rc)
            $g = [Px427]::Grey($vcap, $rc.left - $o.x, $rc.top - $o.y, $rc.right - $o.x, $rc.bottom - $o.y)
            $area = ($rc.right - $rc.left) * ($rc.bottom - $rc.top)
            $script:Num["PV-STATUS $t"] = $g
            $v = if ($Theme -eq 1) { V ($g -le [Math]::Floor($area * 0.01)) } else { 'INFO' }
            Row $t 'PV-STATUS' $v ("light-grey pixels in the status bar: {0} of {1}" -f $g, $area)
        }
        $vcap.Dispose()
        # PictView settings (CMD_CFG 112 in the viewer), five pages
        $known = Get-Tops $id
        Post-Cmd $viewer 112
        $pv = Wait-NewWin $id $known 15
        if ($pv -eq [IntPtr]::Zero) { Row $t 'PV-LABELS' 'FAIL' 'PictView settings did not open' }
        else {
            $min = 99.0; $n = 0
            for ($page = 0; $page -lt 5; $page++) {
                [void][Cap416]::Send($pv, 0x0465, [IntPtr]$page, [IntPtr]::Zero); Start-Sleep -Milliseconds 600
                $r = Labels $pv ("pv_page{0}_{1}" -f $page, $t); $n += $r.N; if ($r.Min -lt $min) { $min = $r.Min }
            }
            $v = if ($Theme -eq 1) { V ($n -ge 6 -and $min -ge 4.5) } else { 'INFO' }
            Row $t 'PV-LABELS' $v ("{0} checkboxes on 5 pages, lowest label contrast {1:0.00}" -f $n, $min)
            Close-Win $pv
        }
        [void][Drv098f]::PostMessageW($viewer, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 1500
        # Batch Rename (Ctrl+Shift+R) on the two files
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        $rn = Open-ByKey $id 0x52
        if ($rn -eq [IntPtr]::Zero) { Row $t 'RN-LABELS' 'FAIL' 'Batch Rename did not open' }
        else {
            Start-Sleep -Milliseconds 1500
            $r = Labels $rn ("renamer_{0}" -f $t)
            $v = if ($Theme -eq 1) { V ($r.N -ge 8 -and $r.Min -ge 4.5) } else { 'INFO' }
            Row $t 'RN-LABELS' $v ("{0} checkboxes, lowest label contrast {1:0.00}" -f $r.N, $r.Min)
            [void][Drv098f]::PostMessageW($rn, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 1200
        }
        # File Comparator (Ctrl+Shift+C) on the two files: the Compare Files dialog, then its window
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        $fc = Open-ByKey $id 0x43
        if ($fc -ne [IntPtr]::Zero -and [Drv098f]::Cls($fc) -eq '#32770') { $known = Get-Tops $id; Click-Ok $fc; $fc = Wait-NewWin $id $known 20 }
        if ($fc -eq [IntPtr]::Zero) { Row $t 'FC-TOOLBAR' 'FAIL' 'File Comparator did not open'; return }
        Start-Sleep -Milliseconds 3000
        [void][Drv098f]::Send($fc, 0, 0, 0, 10000)
        $tb = @(Get-Desc $fc 'ToolbarWindow32') | Select-Object -First 1
        if ($tb) {
            $r = Toolbar-Dark $fc $tb ("fc_toolbar_{0}" -f $t)
            $script:Num["FC-TOOLBAR $t"] = $r.N
            $script:Num["FC-COLOR $t"] = $r.Low
            Row $t 'FC-COLOR' 'INFO' ("coloured glyph pixels below 1.6:1 on the strip: {0}" -f $r.Low)
            Row $t 'FC-TOOLBAR' 'INFO' ("strip #{0:X6}; neutral glyph pixels darker than the strip: {1} (saturated: {2})" -f $r.Bg, $r.N, $r.Sat)
        }
        else { Row $t 'FC-TOOLBAR' 'FAIL' 'no toolbar' }
        $cap = [Cap416]::Capture($fc, $true); Save-Png $cap (Join-Path $CapDir ("fc_window_{0}.png" -f $t))
        $grey = [Px427]::Grey($cap, 0, 0, $cap.Width, $cap.Height)
        # minus the text of the two views (their client areas; their scrollbars are chrome and count)
        $o = New-Object Cap416+POINT; $o.x = 0; $o.y = 0; [void][Cap416]::ClientToScreen($fc, [ref]$o)
        foreach ($k in @([Cap416]::Kids($fc) | Where-Object { [Cap416]::IsWindowVisible($_) })) {
            $rc = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($k, [ref]$rc)
            Out ("  fc child {0} id {1}: {2},{3}-{4},{5}" -f [Cap416]::Cls($k), [Cap416]::GetDlgCtrlID($k), ($rc.left - $o.x), ($rc.top - $o.y), ($rc.right - $o.x), ($rc.bottom - $o.y))
        }
        $views = @(Get-Desc $fc 'SFC File View Window Class')
        $sized = @($views | ForEach-Object {
                $cr = New-Object Cap416+RECT; [void][Cap416]::GetClientRect($_, [ref]$cr)
                $p = New-Object Cap416+POINT; $p.x = 0; $p.y = 0; [void][Cap416]::ClientToScreen($_, [ref]$p)
                [pscustomobject]@{ H = $_; X0 = $p.x - $o.x; Y0 = $p.y - $o.y; X1 = $p.x - $o.x + $cr.right; Y1 = $p.y - $o.y + $cr.bottom } })
        $inViews = 0
        foreach ($s in $sized) { Out ("  view client {0},{1}-{2},{3} of {4}x{5}" -f $s.X0, $s.Y0, $s.X1, $s.Y1, $cap.Width, $cap.Height); $inViews += [Px427]::Grey($cap, $s.X0, $s.Y0, $s.X1, $s.Y1) }
        $light = [Px427]::Light($cap, 0, 0, $cap.Width, $cap.Height)
        foreach ($s in $sized) { $light -= [Px427]::Light($cap, $s.X0, $s.Y0, $s.X1, $s.Y1) }
        $cap.Dispose()
        $script:Num["FC-LIGHT $t"] = $light
        Row $t 'FC-LIGHT' 'INFO' ("light neutral pixels (white or face grey) outside the text views: {0}" -f $light)
        $script:Num["FC-GREY $t"] = $grey - $inViews
        $script:Views[$t] = $sized
        Row $t 'FC-GREY' 'INFO' ("light-grey pixels outside the text views: {0} (in the views {1}; views: {2})" -f ($grey - $inViews), $inViews, (($sized | ForEach-Object { [Cap416]::Cls($_.H) }) -join ', '))
    }
    finally { Stop-Tc $id }
}

# 427 reviews 1-3: a live theme switch with a viewer and File Comparator open (File Comparator on two
# DIFFERENT files). Every capture is compared, after both runs, with the start capture of the run that
# opened its windows in that theme: whole windows (File Comparator without its views' text, the
# viewer without its image area) - a stale part anywhere shows (review 3, S4)
function Sb-State([IntPtr]$Sb) {
    if (-not $Sb) { return 'no status bar' }
    $parts = [Cap416]::Send($Sb, 0x0406, [IntPtr]::Zero, [IntPtr]::Zero).ToInt64()   # SB_GETPARTS
    $d = @(); for ($i = 0; $i -lt $parts; $i++) { $d += ("{0}/{1}" -f ([Cap416]::Send($Sb, 0x040C, [IntPtr]$i, [IntPtr]::Zero).ToInt64() -band 0xFFFF), [int]([Cap416]::Send($Sb, 0x0414, [IntPtr]$i, [IntPtr]::Zero).ToInt64() -ne 0)) }
    return ("{0} parts, text length/icon {1}" -f $parts, ($d -join ' '))
}
function Live-Capture([int]$Id, [IntPtr]$Viewer, [IntPtr]$Fc, [string]$Name) {
    [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 10000); [void][Drv098f]::Send($Viewer, 0, 0, 0, 10000); [void][Drv098f]::Send($Fc, 0, 0, 0, 10000)
    Start-Sleep -Milliseconds 1500
    # every capture shows the window's current state: a full repaint first (the captures read the
    # window's surface; a window under another one may still show an older paint - measured: the
    # viewer's status bar, under File Comparator, blank in one capture and filled in the next)
    foreach ($w in @($Viewer, $Fc)) { [void][Px427]::Repaint($w) }
    Start-Sleep -Milliseconds 800
    foreach ($w in @(@($Viewer, 'pv'), @($Fc, 'fc'))) {
        $cap = [Cap416]::Capture($w[0], $true); Save-Png $cap (Join-Path $CapDir ("live_{0}_{1}.png" -f $w[1], $Name))
        if ($w[1] -eq 'pv' -and $script:PvSkip.Count -eq 4) {
            $sbc = $cap.Clone((New-Object Drawing.Rectangle($script:PvSkip[0], $script:PvSkip[1], ($script:PvSkip[2] - $script:PvSkip[0]), ($script:PvSkip[3] - $script:PvSkip[1]))), [Drawing.Imaging.PixelFormat]::Format32bppRgb)
            $bg = 0; $sat = 0; [void][Px427]::DarkerThanStrip($sbc, [ref]$bg, [ref]$sat); $sbc.Dispose()
            $script:SbInfo[$Name] = @{ State = (Sb-State $script:PvSb); Bg = $bg }
        }
        $cap.Dispose()
    }
}
function Skip-Rects([IntPtr]$Top, [string]$Cls) {
    $o = New-Object Cap416+POINT; $o.x = 0; $o.y = 0; [void][Cap416]::ClientToScreen($Top, [ref]$o)
    $r = @()
    foreach ($h in @(Get-Desc $Top $Cls)) {
        $cr = New-Object Cap416+RECT; [void][Cap416]::GetClientRect($h, [ref]$cr)
        $p = New-Object Cap416+POINT; $p.x = 0; $p.y = 0; [void][Cap416]::ClientToScreen($h, [ref]$p)
        $r += @(($p.x - $o.x), ($p.y - $o.y), ($p.x - $o.x + $cr.right), ($p.y - $o.y + $cr.bottom))
    }
    return , [int[]]$r
}
function Run-Live([int]$StartTheme) {
    & reg.exe add $CfgKey /v 'Theme Mode' /t REG_DWORD /d $StartTheme /f | Out-Null
    $tag = if ($StartTheme -eq 1) { 'LIVE' } else { 'LIVE-D' }
    $start = if ($StartTheme -eq 1) { 'DARK' } else { 'DEFAULT' }
    $id = Start-Tc $Left
    [void](Serve $id 6)
    try {
        $viewer = Open-Viewer $id ($Root + '\big\big.png')
        if ($viewer -ne [IntPtr]::Zero) { Post-Cmd $viewer 137; Start-Sleep -Milliseconds 5000 }   # CMD_ZOOMACTUAL: 1:1, scrollbars; the status bar filled
        [void](Do-ChangeDir $id $LeftDiff); [void](Serve $id 8)
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        $fc = Open-ByKey $id 0x43
        if ($fc -ne [IntPtr]::Zero -and [Drv098f]::Cls($fc) -eq '#32770') { $known = Get-Tops $id; Click-Ok $fc; $fc = Wait-NewWin $id $known 20 }
        if ($viewer -eq [IntPtr]::Zero -or $fc -eq [IntPtr]::Zero) { Row $tag 'OPEN' 'FAIL' 'the viewer or File Comparator did not open'; return }
        Start-Sleep -Milliseconds 4000
        $script:FcSkip = Skip-Rects $fc 'SFC File View Window Class'
        # the whole viewer counts - the image (1:1) and its scrollbars - except the status bar's content,
        # which follows the mouse and activation state and, under File Comparator, the moment of its
        # last paint (measured with a separate debug probe: its parts, texts and icons are the same
        # before and after a switch); the status bar is checked by its state and its colour instead
        $script:PvSb = @(Get-Desc $viewer 'msctls_statusbar32') | Select-Object -First 1
        $script:PvSkip = [int[]]@()
        if ($script:PvSb) { $o = New-Object Cap416+POINT; $o.x = 0; $o.y = 0; [void][Cap416]::ClientToScreen($viewer, [ref]$o); $rc = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($script:PvSb, [ref]$rc); $script:PvSkip = [int[]]@(($rc.left - $o.x), ($rc.top - $o.y), ($rc.right - $o.x), ($rc.bottom - $o.y)) }
        Live-Capture $id $viewer $fc ("{0}_start_{1}" -f $tag, $start)
        # the drop-down list of differences in Dark (review 3, S3)
        if ($StartTheme -eq 1) {
            $combo = @(Get-Desc $fc 'ComboBox') | Select-Object -First 1
            if ($combo) {
                $count = [Cap416]::Send($combo, 0x0146, [IntPtr]::Zero, [IntPtr]::Zero).ToInt64()   # CB_GETCOUNT
                $known = @([Drv098f]::Top([uint32]$id))
                [void][Drv098f]::PostMessageW($combo, 0x014F, [IntPtr]1, [IntPtr]::Zero)               # CB_SHOWDROPDOWN
                Start-Sleep -Milliseconds 1200
                $list = @([Drv098f]::Top([uint32]$id) | Where-Object { [Drv098f]::Cls($_) -eq 'ComboLBox' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
                if ($list) {
                    $lc = [Cap416]::Capture($list, $true); Save-Png $lc (Join-Path $CapDir 'live_fc_list_DARK.png')
                    $l = [Px427]::Light($lc, 0, 0, $lc.Width, $lc.Height); $area = $lc.Width * $lc.Height; $lc.Dispose()
                    Row 'DARK' 'FC-LIST' (V ($count -gt 0 -and $l -le [Math]::Floor($area * 0.02))) ("{0} items; light neutral pixels in the dropped list: {1} of {2}" -f $count, $l, $area)
                }
                else { Row 'DARK' 'FC-LIST' 'FAIL' ("{0} items; the list did not drop" -f $count) }
                [void][Drv098f]::PostMessageW($combo, 0x014F, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 600
            }
        }
        $steps = if ($StartTheme -eq 1) { @(@(2943, 'DEFAULT'), @(2944, 'DARK')) } else { @(@(2944, 'DARK'), @(2943, 'DEFAULT'), @(2944, 'DARK')) }
        $k = 0
        foreach ($step in $steps) {
            $k++
            Post-Cmd (Get-Main $id) $step[0]
            Start-Sleep -Milliseconds 3000
            Live-Capture $id $viewer $fc ("{0}_{1}_{2}" -f $tag, $k, $step[1])
            [void]$script:LiveSteps.Add(@($tag, $k, $step[1]))
        }
    }
    finally { Stop-Tc $id }
}
function Compare-Live {
    foreach ($st in $script:LiveSteps) {
        $tag = $st[0]; $k = $st[1]; $theme = $st[2]
        $refTag = if ($theme -eq 'DARK') { 'LIVE' } else { 'LIVE-D' }
        $ref = $script:SbInfo[("{0}_start_{1}" -f $refTag, $theme)]; $got = $script:SbInfo[("{0}_{1}_{2}" -f $tag, $k, $theme)]
        if ($ref -and $got) {
            $wantBg = if ($theme -eq 'DARK') { 0x2D2D2D } else { 0xF0F0F0 }
            Row $tag ("SB-{0}->{1}" -f $k, $theme) (V ($got.State -eq $ref.State -and $got.Bg -eq $wantBg)) ("status bar after the switch: {0}, background #{1:X6} (a window opened in {2}: {3}, #{4:X6})" -f $got.State, $got.Bg, $theme, $ref.State, $ref.Bg)
        }
        foreach ($pair in @(@('fc', $script:FcSkip), @('pv', $script:PvSkip))) {
            $a = Join-Path $CapDir ("live_{0}_{1}_start_{2}.png" -f $pair[0], $refTag, $theme)
            $b = Join-Path $CapDir ("live_{0}_{1}_{2}_{3}.png" -f $pair[0], $tag, $k, $theme)
            if (-not (Test-Path $a) -or -not (Test-Path $b)) { Row $tag ("{0}-{1}->{2}" -f $pair[0].ToUpper(), $k, $theme) 'FAIL' 'capture missing'; continue }
            $x = New-Object Drawing.Bitmap $a; $y = New-Object Drawing.Bitmap $b
            $d = [Px427]::DiffOutside($x, $y, [int[]]$pair[1]); $x.Dispose(); $y.Dispose()
            $allowed = 0
            Row $tag ("{0}-{1}->{2}" -f $pair[0].ToUpper(), $k, $theme) (V ($d -ge 0 -and $d -le $allowed)) ("whole window after the switch: {0} px differ from a window opened in {1} ({2}; allowed {3})" -f $d, $theme, $(if ($pair[0] -eq 'fc') { "outside the views' text" } else { 'the whole window with the image 1:1 and its scrollbars, the status bar apart' }), $allowed)
        }
    }
}

$backup = Join-Path $env:TEMP 'tc427_backup.reg'
$existed = Backup-Reg $backup
$restored = $false
$script:Num = @{}
$script:Views = @{}
$script:LiveSteps = New-Object System.Collections.ArrayList
$script:FcSkip = @(); $script:PvSkip = @(); $script:PvSb = $null; $script:SbInfo = @{}
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Left
    Copy-Item -LiteralPath $Image -Destination (Join-Path $Left 'image.png')
    Copy-Item -LiteralPath $Image -Destination (Join-Path $Left 'image2.png')
    NewDir $LeftDiff
    # a large image for the LIVE viewer: shown 1:1 it gives the image window scrollbars (review 4, S6)
    $big = New-Object Drawing.Bitmap 2600, 2200
    $gr = [Drawing.Graphics]::FromImage($big); $gr.Clear([Drawing.Color]::FromArgb(90, 120, 160))
    for ($q = 0; $q -lt 20; $q++) { $gr.FillEllipse([Drawing.Brushes]::Orange, $q * 120, $q * 100, 200, 150) }
    $gr.Dispose(); NewDir ($Root + '\big'); $big.Save(($Root + '\big\big.png'), [Drawing.Imaging.ImageFormat]::Png); $big.Dispose()
    Copy-Item -LiteralPath $Image -Destination (Join-Path $LeftDiff 'a.png')
    $other = Join-Path $Repo 'specs\427-dark-plugin-toolbars\evidence\issue25-batch-rename.png'
    Copy-Item -LiteralPath $other -Destination (Join-Path $LeftDiff 'b.png')
    Set-Config
    & reg.exe add $CfgKey /v 'Toolbar Icon Set' /t REG_DWORD /d 0 /f | Out-Null
    Out ("dark427_probe {0} on {1}; hot keys: {2}; OS {3}" -f $Label, $Exe, (Set-HotKeys), [Environment]::OSVersion.Version)
    Run-Theme 1
    Run-Theme 0
    Run-Live 1
    Run-Live 0
    Compare-Live
    # compare with the before run
    if ($Label -ne 'before' -and (Test-Path $BeforeDir)) {
        # the before values: the same measurement on the captures the before run saved
        $old = @{}
        foreach ($pair in @(@('PV', 'pv_toolbar_DARK.png'), @('FC', 'fc_toolbar_DARK.png'))) {
            $f = Join-Path $BeforeDir $pair[1]
            if (Test-Path $f) {
                $bm = New-Object Drawing.Bitmap $f; $bg = 0; $sat = 0
                $old[$pair[0] + '-TOOLBAR DARK'] = [Px427]::DarkerThanStrip($bm, [ref]$bg, [ref]$sat)
                $old[$pair[0] + '-COLOR DARK'] = [Px427]::LowContrastColour($bm, [ref]$bg)
                $bm.Dispose()
                Out ("  before {0}: {1} neutral, {2} saturated, {3} coloured below 1.6:1" -f $pair[0], $old[$pair[0] + '-TOOLBAR DARK'], $sat, $old[$pair[0] + '-COLOR DARK'])
            }
        }
        $f = Join-Path $BeforeDir 'fc_window_DARK.png'
        if ((Test-Path $f) -and $script:Views.ContainsKey('DARK')) {
            $bm = New-Object Drawing.Bitmap $f
            $g = [Px427]::Grey($bm, 0, 0, $bm.Width, $bm.Height)
            foreach ($v in $script:Views['DARK']) { $g -= [Px427]::Grey($bm, $v.X0, $v.Y0, $v.X1, $v.Y1) }
            $old['FC-GREY DARK'] = $g
            $l = [Px427]::Light($bm, 0, 0, $bm.Width, $bm.Height)
            foreach ($v in $script:Views['DARK']) { $l -= [Px427]::Light($bm, $v.X0, $v.Y0, $v.X1, $v.Y1) }
            $old['FC-LIGHT DARK'] = $l
            $bm.Dispose(); Out ("  before FC-GREY DARK: {0}, FC-LIGHT DARK: {1}" -f $g, $l)
        }
        foreach ($k in @('PV-COLOR DARK', 'FC-COLOR DARK')) {
            if ($old.ContainsKey($k) -and $script:Num.ContainsKey($k)) { Row 'DARK' ($k -replace ' DARK') (V ($script:Num[$k] -le [Math]::Max(5, [Math]::Floor($old[$k] * 0.1)))) ("{0} -> {1} coloured glyph pixels below 1.6:1 (needs <= 10 %, at least 5 allowed)" -f $old[$k], $script:Num[$k]) }
        }
        foreach ($k in @('PV-TOOLBAR DARK', 'FC-TOOLBAR DARK')) {
            if ($old.ContainsKey($k) -and $script:Num.ContainsKey($k)) { Row 'DARK' ($k -replace ' DARK') (V ($script:Num[$k] -le [Math]::Floor($old[$k] * 0.1))) ("{0} -> {1} neutral glyph pixels darker than the strip (needs <= 10 %)" -f $old[$k], $script:Num[$k]) }
        }
        if ($old.ContainsKey('FC-GREY DARK') -and $script:Num.ContainsKey('FC-GREY DARK')) { Row 'DARK' 'FC-GREY' (V ($script:Num['FC-GREY DARK'] -le [Math]::Floor($old['FC-GREY DARK'] * 0.01))) ("{0} -> {1} light-grey pixels (needs <= 1 %)" -f $old['FC-GREY DARK'], $script:Num['FC-GREY DARK']) }
        if ($old.ContainsKey('FC-LIGHT DARK') -and $script:Num.ContainsKey('FC-LIGHT DARK')) { Row 'DARK' 'FC-LIGHT' (V ($script:Num['FC-LIGHT DARK'] -le [Math]::Floor($old['FC-LIGHT DARK'] * 0.01) + 200)) ("{0} -> {1} light neutral pixels outside the text (needs <= 1 % + 200 for glyph highlights)" -f $old['FC-LIGHT DARK'], $script:Num['FC-LIGHT DARK']) }
        foreach ($n in @('pv_toolbar_DEFAULT.png', 'fc_toolbar_DEFAULT.png')) { $d = Same-As-Before $n; Row 'DEFAULT' 'DEFAULT-SAME' (V ($d -eq 0)) ("{0}: {1} pixels differ from the before run" -f $n, $d) }
        $a = Join-Path $BeforeDir 'fc_window_DEFAULT.png'; $b = Join-Path $CapDir 'fc_window_DEFAULT.png'
        if ((Test-Path $a) -and (Test-Path $b) -and $script:Views.ContainsKey('DEFAULT')) {
            $skip = @(); foreach ($v in $script:Views['DEFAULT']) { $skip += @($v.X0, $v.Y0, $v.X1, $v.Y1) }
            $x = New-Object Drawing.Bitmap $a; $y = New-Object Drawing.Bitmap $b
            $d = [Px427]::DiffOutside($x, $y, [int[]]$skip); $x.Dispose(); $y.Dispose()
            Row 'DEFAULT' 'DEFAULT-SAME' (V ($d -eq 0)) ("fc_window_DEFAULT.png outside the views' text: {0} pixels differ from the before run" -f $d)
        }
    }
}
catch { Row 'PROBE' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    Out ("registry restored+identical: {0}" -f $restored)
    foreach ($k in $script:Num.Keys) { Out ("NUM {0} {1}" -f $k, $script:Num[$k]) }
    $fails = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ("ROWS: {0} FAIL" -f $fails)
    [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding))
}
