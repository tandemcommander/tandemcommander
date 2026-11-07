# Feature 418 probe: the Dark theme has the default theme's rebar layout (border + band borders) drawn in the
# Dark palette, the panel tab strip and the tab titles at the same rows; the default theme pixel-identical to
# the build of main; a run-time theme switch equals a fresh start; extra bars and a narrow window keep it.
# MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
#   -Exe      the build under test
#   -MainExe  the build of main (CLASSIC-EQ); without it CLASSIC-EQ is NOT DRIVEN
#   -Only     comma-separated row groups (DARK, CLASSIC, SWITCH, DRAG, EXTRA, NARROW)
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Exe, [Parameter(Mandatory = $true)][string]$Repo, [string]$MainExe,
      [string]$OutFile, [string]$CapDir, [string]$Only)
$ErrorActionPreference = 'Stop'
if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $Repo 'specs\416-fluent-icon-set\probe\capture416_lib.ps1')

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
public static class P418
{
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] public static extern IntPtr GetWindowLongPtr(IntPtr h, int index);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);

    public static int[] Pixels(Bitmap b)
    {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
        int[] px = new int[b.Width * b.Height];
        for (int y = 0; y < b.Height; y++)
            Marshal.Copy(IntPtr.Add(d.Scan0, y * d.Stride), px, y * b.Width, b.Width);
        b.UnlockBits(d);
        for (int i = 0; i < px.Length; i++) px[i] &= 0xFFFFFF;
        return px;
    }

    static bool Etched(int c) { return c == 0xA0A0A0 || c == 0xFFFFFF; }
    // a light pixel of the classic chrome: the etched pair or the system face (a grip's middle)
    static bool LightChrome(int c) { return Etched(c) || c == 0xF0F0F0; }
    static int DarkOf(int c) { return c == 0xA0A0A0 ? 0x1A1A1A : 0x464646; }

    // the pixels of the default theme's rebar (rows 0..h-1) that belong to the rebar's own etched lines must be the
    // Dark pair at the same place in the Dark capture. The rebar's lines: A0A0A0 / FFFFFF in a horizontal run
    // >= minH (the frame, the borders between band rows), and a vertical run >= minV that reaches such a line or
    // the rebar's edge at both ends (the frame's sides, the borders between bands of one row). Vertical runs inside
    // a band - the grips (checked by CheckGrips) and toolbar separators (the toolbar's own drawing) - do not
    // reach them and are only counted.
    public static string CheckLines(Bitmap light, Bitmap dark, int h, int minH, int minV)
    {
        if (light.Width != dark.Width) return "FAIL width " + light.Width + " vs " + dark.Width;
        int w = light.Width; h = Math.Min(h, Math.Min(light.Height, dark.Height));
        int[] pl = Pixels(light), pd = Pixels(dark);
        bool[] hor = new bool[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; )
            {
                int c = pl[y * w + x]; int e = x;
                while (e < w && pl[y * w + e] == c) e++;
                if (Etched(c) && e - x >= minH) for (int i = x; i < e; i++) hor[y * w + i] = true;
                x = e;
            }
        bool[] line = (bool[])hor.Clone();
        int inner = 0;
        for (int x = 0; x < w; x++)
            for (int y = 0; y < h; )
            {
                int c = pl[y * w + x]; int e = y;
                while (e < h && pl[e * w + x] == c) e++;
                if (Etched(c) && e - y >= minV)
                {
                    bool top = y == 0 || hor[(y - 1) * w + x] || (x > 0 && hor[(y - 1) * w + x - 1]) || (x + 1 < w && hor[(y - 1) * w + x + 1]);
                    bool bot = e == h || hor[e * w + x] || (x > 0 && hor[e * w + x - 1]) || (x + 1 < w && hor[e * w + x + 1]);
                    // an etched line is a pair: the shadow column, the highlight column right of it (a pressed
                    // toolbar button's edge spans a band too, but alone)
                    int mate = c == 0xA0A0A0 ? x + 1 : x - 1, mateColor = c == 0xA0A0A0 ? 0xFFFFFF : 0xA0A0A0;
                    bool pair = mate >= 0 && mate < w;
                    for (int i = y; pair && i < e; i++) if (pl[i * w + mate] != mateColor) pair = false;
                    if (top && bot && pair) for (int i = y; i < e; i++) line[i * w + x] = true;
                    else inner++;
                }
                y = e;
            }
        int n = 0, bad = 0; var sb = new StringBuilder();
        var rows = new System.Collections.Generic.SortedSet<int>();
        for (int i = 0; i < w * h; i++)
        {
            if (!line[i]) continue;
            n++;
            if (pd[i] != DarkOf(pl[i]))
            {
                bad++;
                if (bad <= 4) sb.AppendFormat(" ({0},{1}) {2:X6}->{3:X6}", i % w, i / w, pl[i], pd[i]);
            }
            else rows.Add(i / w);
        }
        var rs = new StringBuilder(); int prev = -10, start = -10;
        foreach (int r in rows) { if (r != prev + 1) { if (start >= 0) rs.AppendFormat("{0}-{1} ", start, prev); start = r; } prev = r; }
        if (start >= 0) rs.AppendFormat("{0}-{1}", start, prev);
        return string.Format("{0} line pixels, {1} not the Dark pair{2}; matched rows {3}; vertical runs inside bands (grips, toolbar separators, pressed buttons) not counted: {4}", n, bad, sb.ToString(), rs.ToString().Trim(), inner);
    }

    // the grips of the default theme's rebar (a raised bar: a FFFFFF column, its A0A0A0 column two pixels right, the
    // same rows, >= minV) must be drawn alike in the Dark capture: 464646 / the band face 2D2D2D / 1A1A1A (comctl32
    // fills the middle with the light system face; ThemeRebarCustomDraw repaints it)
    public static string CheckGrips(Bitmap light, Bitmap dark, int h, int minV)
    {
        if (light.Width != dark.Width) return "FAIL width";
        int w = light.Width; h = Math.Min(h, Math.Min(light.Height, dark.Height));
        int[] pl = Pixels(light), pd = Pixels(dark);
        int grips = 0, bad = 0; var sb = new StringBuilder();
        for (int x = 0; x + 2 < w; x++)
            for (int y = 0; y < h; )
            {
                int c = pl[y * w + x]; int e = y;
                while (e < h && pl[e * w + x] == c) e++;
                if (c == 0xFFFFFF && e - y >= minV)
                {
                    bool grip = true;
                    for (int i = y; grip && i < e; i++) if (pl[i * w + x + 2] != 0xA0A0A0 || (i > y && Etched(pl[i * w + x + 1]))) grip = false; // the top row is the bar's FFFFFF edge
                    if (grip)
                    {
                        grips++;
                        int miss = 0;
                        for (int i = y; i < e; i++) if (pd[i * w + x] != 0x464646 || (i > y && pd[i * w + x + 1] != 0x2D2D2D) || pd[i * w + x + 2] != 0x1A1A1A) miss++;
                        if (miss > 0) { bad++; if (bad <= 4) sb.AppendFormat(" x {0} y {1}-{2}: {3} rows not the Dark grip (Dark {4:X6} {5:X6} {6:X6})", x, y, e - 1, miss, pd[(y + 1) * w + x], pd[(y + 1) * w + x + 1], pd[(y + 1) * w + x + 2]); }
                        else sb.AppendFormat(" x {0} y {1}-{2}", x, y, e - 1);
                    }
                }
                y = e;
            }
        return string.Format("{0} grips, {1} not drawn alike in Dark;{2}", grips, bad, sb.ToString());
    }

    // the first column >= x0 of row y that differs from the background (the pixel at x0 of that row)
    public static int FirstContentCol(Bitmap b, int y, int x0, int x1)
    {
        Color bg = b.GetPixel(x0, y);
        for (int x = x0; x <= x1 && x < b.Width; x++)
        {
            Color c = b.GetPixel(x, y);
            if (Math.Abs(c.R - bg.R) > 40 || Math.Abs(c.G - bg.G) > 40 || Math.Abs(c.B - bg.B) > 40) return x;
        }
        return -1;
    }

    // horizontal or vertical runs >= minRun of the light etched colours in rows 0..h-1 (a light line on the dark chrome)
    public static string LightRuns(Bitmap b, int h, int minRun)
    {
        int w = b.Width; h = Math.Min(h, b.Height);
        int[] p = Pixels(b); int n = 0; var sb = new StringBuilder();
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; )
            {
                int c = p[y * w + x]; int e = x;
                while (e < w && p[y * w + e] == c) e++;
                if (LightChrome(c) && e - x >= minRun) { n++; if (n <= 4) sb.AppendFormat(" row {0} x {1}-{2} {3:X6}", y, x, e - 1, c); }
                x = e;
            }
        for (int x = 0; x < w; x++)
            for (int y = 0; y < h; )
            {
                int c = p[y * w + x]; int e = y;
                while (e < h && p[e * w + x] == c) e++;
                if (LightChrome(c) && e - y >= minRun) { n++; if (n <= 4) sb.AppendFormat(" col {0} y {1}-{2} {3:X6}", x, y, e - 1, c); }
                y = e;
            }
        return n + (n > 0 ? ":" + sb.ToString() : "");
    }

    // the first row in y0..y1 where a pixel of x0..x1 differs from the background (the pixel at bgX of that row)
    public static int FirstContentRow(Bitmap b, int x0, int x1, int y0, int y1, int bgX)
    {
        for (int y = y0; y <= y1 && y < b.Height; y++)
        {
            Color bg = b.GetPixel(bgX, y);
            for (int x = x0; x <= x1 && x < b.Width; x++)
            {
                Color c = b.GetPixel(x, y);
                if (Math.Abs(c.R - bg.R) > 40 || Math.Abs(c.G - bg.G) > 40 || Math.Abs(c.B - bg.B) > 40) return y;
            }
        }
        return -1;
    }

    // differing pixels in rows 0..h-1, with the bounding box
    // as DiffTop, with rectangles (x0, y0, x1, y1 exclusive, in fours) left out: the free-space figure of the
    // directory lines changes whenever another program writes to the disk between two starts
    public static string DiffMasked(Bitmap a, Bitmap b, int h, int[] mask)
    {
        if (a.Width != b.Width || a.Height < h || b.Height < h) return "size " + a.Width + "x" + a.Height + " vs " + b.Width + "x" + b.Height;
        int w = a.Width; int[] pa = Pixels(a), pb = Pixels(b);
        int n = 0, masked = 0, l = int.MaxValue, t = int.MaxValue, r = -1, bo = -1;
        for (int i = 0; i < w * h; i++)
        {
            if (pa[i] == pb[i]) continue;
            int x = i % w, y = i / w; bool m = false;
            for (int k = 0; k + 3 < mask.Length; k += 4) if (x >= mask[k] && y >= mask[k + 1] && x < mask[k + 2] && y < mask[k + 3]) m = true;
            if (m) { masked++; continue; }
            n++; l = Math.Min(l, x); t = Math.Min(t, y); r = Math.Max(r, x); bo = Math.Max(bo, y);
        }
        string tail = masked > 0 ? string.Format(" ({0} in the free-space figures left out)", masked) : "";
        return (n == 0 ? "0" : string.Format("{0} in ({1},{2})-({3},{4})", n, l, t, r, bo)) + tail;
    }

    public static string DiffTop(Bitmap a, Bitmap b, int h)
    {
        if (a.Width != b.Width || a.Height < h || b.Height < h) return "size " + a.Width + "x" + a.Height + " vs " + b.Width + "x" + b.Height;
        int w = a.Width; int[] pa = Pixels(a), pb = Pixels(b);
        int n = 0, l = int.MaxValue, t = int.MaxValue, r = -1, bo = -1;
        for (int i = 0; i < w * h; i++)
            if (pa[i] != pb[i]) { n++; int x = i % w, y = i / w; l = Math.Min(l, x); t = Math.Min(t, y); r = Math.Max(r, x); bo = Math.Max(bo, y); }
        return n == 0 ? "0" : string.Format("{0} in ({1},{2})-({3},{4})", n, l, t, r, bo);
    }
}
'@

$Root = $TempRoot + '\tc418'
$StartDir = $Root + '\start'
$CfgKey = "$RegKey\Settings\Configuration"
if (-not $CapDir) { $CapDir = Join-Path $env:TEMP 'tc418_caps' }
[void][IO.Directory]::CreateDirectory($CapDir)
$Groups = if ($Only) { $Only.Split(',') } else { @('DARK', 'CLASSIC', 'SWITCH', 'DRAG', 'EXTRA', 'NARROW') }
function Want([string]$g) { return $Groups -contains $g }

function Start-At([string]$ExePath) {
    $a = @('-t', 'TC418', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $ExePath -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 2500
    [void](Serve $p.Id 8)
    return $p.Id
}
function Rel([IntPtr]$main, [IntPtr]$h) {
    $r = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($h, [ref]$r)
    $o = New-Object Cap416+POINT; [void][Cap416]::ClientToScreen($main, [ref]$o)
    return @(($r.left - $o.x), ($r.top - $o.y), ($r.right - $o.x), ($r.bottom - $o.y))
}
function Settle([IntPtr]$main) { [void][Drv098f]::Send($main, 0, 0, 0, 20000); Start-Sleep -Milliseconds 1500; [void][Drv098f]::Send($main, 0, 0, 0, 20000) }
# one picture of the window: the capture, the rebar / strip / directory line rectangles, the rebar's style, the band count
function Snap([int]$id, [string]$name) {
    $main = Get-Main $id
    Settle $main
    $full = [Cap416]::Capture($main, $false)
    Save-Png $full (Join-Path $CapDir ($name + '.png'))
    $rebar = @(Get-Desc $main 'ReBarWindow32')[0]
    $tabs = @([Cap416]::Kids($main) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::GetDlgCtrlID($_) -eq 958 } | Sort-Object { (Rel $main $_)[0] })
    $dirs = @([Cap416]::Kids($main) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::GetDlgCtrlID($_) -eq 952 } | Sort-Object { (Rel $main $_)[0] })
    $s = [pscustomobject]@{
        Bmp = $full; Rebar = (Rel $main $rebar); Strip = (Rel $main $tabs[0]); Dir = (Rel $main $dirs[0]); Dirs = @($dirs | ForEach-Object { ,(Rel $main $_) })
        Style = ([int64][P418]::GetWindowLongPtr($rebar, -16)) -band 0xFFFFFFFF
        Bands = [int64][Cap416]::Send($rebar, 0x040C, [IntPtr]::Zero, [IntPtr]::Zero)
        TopIndex = [int64][Cap416]::Send($rebar, 0x0410, [IntPtr]2, [IntPtr]::Zero)   # RB_IDTOINDEX(BANDID_TOPTOOLBAR)
        Text = 0
    }
    $st = $s.Strip
    $s.Text = [P418]::FirstContentRow($full, $st[0] + 20, $st[0] + 120, $st[1], $st[3] - 1, $st[2] - 5)
    return $s
}
function Desc($s) {
    return ('rebar {0}; strip {1}; dirline {2}; style 0x{3:X8} (WS_BORDER {4}, RBS_BANDBORDERS {5}); bands {6}; first title row {7}' -f
        ($s.Rebar -join ','), ($s.Strip -join ','), ($s.Dir -join ','), $s.Style, [int](($s.Style -band 0x00800000) -ne 0), [int](($s.Style -band 0x0400) -ne 0), $s.Bands, $s.Text)
}
function Set-Theme([int]$t) { & reg.exe add $CfgKey /v 'Theme Mode' /t REG_DWORD /d $t /f | Out-Null }
# the program saves its configuration (bars shown, window placement) on exit: every start begins from the
# configuration exported once after Set-Config, so that the starts of a comparison see the same bars
$BaseReg = Join-Path $env:TEMP 'tc418_base.reg'
function Reset-Base { & cmd.exe /c "reg delete `"$RegKey\Settings`" /f >nul 2>&1"; & cmd.exe /c "reg import `"$BaseReg`" >nul 2>&1" }
function Fresh([string]$exePath, [int]$theme, [string]$name, [scriptblock]$prep, [hashtable]$regs) {
    Reset-Base
    Set-Theme $theme
    if ($regs) { foreach ($k in $regs.Keys) { & reg.exe add $CfgKey /v $k /t REG_DWORD /d $regs[$k] /f | Out-Null } }
    $id = Start-At $exePath
    if ($prep) { & $prep $id }
    $s = Snap $id $name
    Stop-Tc $id
    Out ("  {0}: {1}" -f $name, (Desc $s))
    return $s
}
# the right 160 px of every directory line (the free-space figure)
function FreeMask($s) { $m = @(); foreach ($r in $s.Dirs) { $m += @(($r[2] - 160), $r[1], $r[2], $r[3]) }; return [int[]]$m }
# Dark vs Default with the same bars: rows, lines, no light lines, title row
function Compare-Themes([string]$case, $L, $D) {
    $rowsEq = ($L.Rebar[3] -eq $D.Rebar[3]) -and ($L.Strip[1] -eq $D.Strip[1]) -and ($L.Strip[3] -eq $D.Strip[3]) -and ($L.Dir[1] -eq $D.Dir[1]) -and ($L.Dir[3] -eq $D.Dir[3])
    Row $case 'ROWS' (V $rowsEq) ('rebar bottom {0} / {1}; strip {2}-{3} / {4}-{5}; dirline {6}-{7} / {8}-{9} (Default / Dark)' -f $L.Rebar[3], $D.Rebar[3], $L.Strip[1], $L.Strip[3], $D.Strip[1], $D.Strip[3], $L.Dir[1], $L.Dir[3], $D.Dir[1], $D.Dir[3])
    $styleEq = (($L.Style -band 0x00800400) -eq ($D.Style -band 0x00800400)) -and (($D.Style -band 0x00800400) -eq 0x00800400)
    Row $case 'STYLE' (V $styleEq) ('WS_BORDER|RBS_BANDBORDERS Default 0x{0:X8} Dark 0x{1:X8}' -f ($L.Style -band 0x00800400), ($D.Style -band 0x00800400))
    $lines = [P418]::CheckLines($L.Bmp, $D.Bmp, $L.Rebar[3], 40, 12)
    $ok = $lines -match '^(\d+) line pixels, 0 not' -and [int]$Matches[1] -gt 0
    Row $case 'LINES' (V $ok) $lines
    $light = [P418]::LightRuns($D.Bmp, $D.Rebar[3], 12)
    # the detector's own control: on the Default rebar it must find the light lines
    $control = [P418]::LightRuns($L.Bmp, $L.Rebar[3], 12)
    $cn = [int]($control -replace ':.*$', '')
    Row $case 'NOLIGHT' (V (($light -eq '0') -and $cn -gt 0)) ('light runs (A0A0A0, FFFFFF, F0F0F0) >= 12 px in the Dark rebar: {0} (the same detector on the Default rebar: {1})' -f $light, $cn)
    $grips = [P418]::CheckGrips($L.Bmp, $D.Bmp, $L.Rebar[3], 12)
    $gOk = $grips -match '^(\d+) grips, 0 not' -and [int]$Matches[1] -gt 0
    # the menu bar's first item (its text) starts at the same column: the grip takes the same room in both themes
    # the bands' contents start at the same column: the menu (row 12) and the top toolbar (row 37), searched from x 8
    $mx = [P418]::FirstContentCol($L.Bmp, 12, 8, 300); $dx = [P418]::FirstContentCol($D.Bmp, 12, 8, 300)
    $tx = [P418]::FirstContentCol($L.Bmp, 37, 8, 300); $ux = [P418]::FirstContentCol($D.Bmp, 37, 8, 300)
    Row $case 'GRIPS' (V ($gOk -and $mx -gt 0 -and $mx -eq $dx -and $tx -gt 0 -and $tx -eq $ux)) ('{0} menu from x {1} / {2}, top toolbar from x {3} / {4} (Default / Dark)' -f $grips, $mx, $dx, $tx, $ux)
    $tOk = ($L.Text -ge 0) -and ($L.Text -eq $D.Text)
    Row $case 'TITLE' (V $tOk) ('first title row {0} / {1}; from the frame line above the strip (rebar bottom - 2): {2} / {3} px' -f $L.Text, $D.Text, ($L.Text - ($L.Rebar[3] - 2)), ($D.Text - ($D.Rebar[3] - 2)))
}

$backup = Join-Path $env:TEMP 'tc418_backup.reg'
$existed = Backup-Reg $backup
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    & cmd.exe /c "reg export `"$RegKey\Settings`" `"$BaseReg`" /y >nul 2>&1"
    if (-not (Test-Path -LiteralPath $BaseReg)) { throw 'the base configuration was not exported' }
    Out ("rebar418_probe on {0}{1}; groups {2}" -f $Exe, $(if ($MainExe) { "; main build $MainExe" } else { '' }), ($Groups -join ','))

    $L = Fresh $Exe 0 'default' $null
    $D = Fresh $Exe 1 'dark' $null
    if (Want 'DARK') { Compare-Themes 'DARK' $L $D }

    if (Want 'CLASSIC') {
        if ($MainExe) {
            $M = Fresh $MainExe 0 'main_default' $null
            $h = $L.Bmp.Height
            # (PowerShell names are case-insensitive: never $d / $l / $m here - they are $D / $L / $M)
            $dClassic = [P418]::DiffMasked($L.Bmp, $M.Bmp, [Math]::Min($h, $M.Bmp.Height), (FreeMask $L))
            Row 'CLASSIC' 'EQ' (V ($dClassic -match '^0( |$)')) ('Default theme, the whole client area {0}x{1} vs the build of main: {2} pixels differ' -f $L.Bmp.Width, $h, $dClassic)
            $M.Bmp.Dispose()
        }
        else { Row 'CLASSIC' 'EQ' 'NOT DRIVEN' 'no -MainExe' }
    }

    if (Want 'SWITCH') {
        $h = $L.Dir[3]
        Reset-Base
        Set-Theme 0
        $id = Start-At $Exe
        Post-Cmd (Get-Main $id) 2944   # CM_THEME_DARK
        Start-Sleep -Milliseconds 2500
        $S = Snap $id 'switch_to_dark'
        Out ("  switch_to_dark: {0}" -f (Desc $S))
        $d1 = [P418]::DiffMasked($S.Bmp, $D.Bmp, $h, (FreeMask $D))
        Row 'SWITCH' 'TODARK' (V ($d1 -match '^0( |$)')) ('Default -> Dark at run time vs a fresh Dark start, rows 0-{0}: {1} pixels differ' -f ($h - 1), $d1)
        Post-Cmd (Get-Main $id) 2943   # CM_THEME_DEFAULT
        Start-Sleep -Milliseconds 2500
        $S2 = Snap $id 'switch_back'
        Out ("  switch_back: {0}" -f (Desc $S2))
        $d2 = [P418]::DiffMasked($S2.Bmp, $L.Bmp, $h, (FreeMask $L))
        Row 'SWITCH' 'TOLIGHT' (V ($d2 -match '^0( |$)')) ('Dark -> Default at run time vs a fresh Default start, rows 0-{0}: {1} pixels differ' -f ($h - 1), $d2)
        Stop-Tc $id
        $S.Bmp.Dispose(); $S2.Bmp.Dispose()
    }

    if (Want 'DRAG') {
        # review 3: the Plugins bar beside the top toolbar and the second drive bar shown; the Plugins bar's grip
        # dragged onto a new last row and captured with the button still down - the drive bars' bands are hidden
        # while a band is dragged (RBN_BEGINDRAG) and keep their old rectangles; the dragged band's grip must be
        # repainted all the same (no light middle)
        $prepHid = {
            param($id)
            $m = Get-Main $id; Post-Cmd $m 756; Start-Sleep -Milliseconds 1500; Settle $m
            $rb = @(Get-Desc $m 'ReBarWindow32')[0]
            $kids = @([Cap416]::Kids($rb) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::GetParent($_) -eq $rb } | ForEach-Object { ,@($_, (Rel $m $_)) })
            $row2 = @($kids | Where-Object { $_[1][1] -ge 25 -and $_[1][1] -lt 50 } | Sort-Object { $_[1][0] })
            $script:HidInfo = ('{0} bands on the second row, lefts {1}' -f $row2.Count, (($row2 | ForEach-Object { $_[1][0] }) -join ','))
            if ($row2.Count -lt 2) { return }
            $plg = $row2[$row2.Count - 1][1]
            $o = New-Object Cap416+POINT; [void][Cap416]::ClientToScreen($rb, [ref]$o)
            $mo = New-Object Cap416+POINT; [void][Cap416]::ClientToScreen($m, [ref]$mo)
            $dx = $mo.x - $o.x; $dy = $mo.y - $o.y   # main-client -> rebar-client
            # the grip: the Dark pair (464646 ... 1A1A1A two pixels right) in the 16 px left of the band's child
            $cap = [Cap416]::Capture($m, $false); $gx = -1; $gy = $plg[1] + 10
            for ($x = $plg[0] - 16; $x -lt $plg[0] - 2 -and $gx -lt 0; $x++) {
                if (($cap.GetPixel($x, $gy).ToArgb() -band 0xFFFFFF) -eq 0x464646 -and ($cap.GetPixel($x + 2, $gy).ToArgb() -band 0xFFFFFF) -eq 0x1A1A1A) { $gx = $x + 1 }
            }
            $cap.Dispose()
            if ($gx -lt 0) { $script:HidInfo += '; no grip found left of the Plugins bar'; return }
            $plg = @(($gx + 10), $plg[1])
            $x = $plg[0] - 10 + $dx; $y0 = $plg[1] + 10 + $dy; $y1 = 90 + $dy
            [void][Cap416]::PostMessageW($rb, 0x0201, [IntPtr]1, [IntPtr](($y0 -shl 16) -bor $x)); Start-Sleep -Milliseconds 300
            foreach ($yy in ($y0 + 6), ($y0 + 14), ($y0 + 22), $y1) { [void][Cap416]::PostMessageW($rb, 0x0200, [IntPtr]1, [IntPtr](($yy -shl 16) -bor ($x + 10))); Start-Sleep -Milliseconds 250 }
            Start-Sleep -Milliseconds 1200
            $script:HidInfo += ('; grip pressed at main x {0}, dragged to y 90' -f ($plg[0] - 10))
        }
        $script:HidInfo = ''
        $HD = Fresh $Exe 1 'drag_hidden_dark' $prepHid @{ 'Show Plugins Bar' = 1; 'PluginsBar Index' = 2; 'PluginsBar Break' = 0; 'ToolBar Width' = 400 }
        $hidLight = [P418]::LightRuns($HD.Bmp, $HD.Rebar[3], 12)
        $dragged = $script:HidInfo -match 'grip pressed'
        Row 'DRAG' 'HIDDEN' (V ($dragged -and $hidLight -eq '0')) ('{0}; rebar {1} px during the drag; light runs >= 12 px in the Dark rebar: {2}' -f $script:HidInfo, $HD.Rebar[3], $hidLight)
        $HD.Bmp.Dispose()
    }

    # the Plugins bar and the second drive bar toggled the same way in both themes (from the same configuration)
    $prepExtra = { param($id) $m = Get-Main $id; Post-Cmd $m 2950; Start-Sleep -Milliseconds 1200; Post-Cmd $m 756; Start-Sleep -Milliseconds 1500 }
    $LE = $null
    if ((Want 'EXTRA') -or (Want 'NARROW')) { $LE = Fresh $Exe 0 'extra_default' $prepExtra }
    if (Want 'DRAG') {
        # the top toolbar's grip dragged onto the drive bar's row with posted mouse messages: the bands move in the
        # default theme, and the Dark theme does the same (a grip that is drawn is a grip that works)
        $prepDrag = {
            param($id)
            $m = Get-Main $id; Settle $m
            $rb = @(Get-Desc $m 'ReBarWindow32')[0]
            $o = New-Object Cap416+POINT; [void][Cap416]::ClientToScreen($rb, [ref]$o)
            $mo = New-Object Cap416+POINT; [void][Cap416]::ClientToScreen($m, [ref]$mo)
            $dx = $mo.x - $o.x; $dy = $mo.y - $o.y   # main-client -> rebar-client
            $x = 5 + $dx; $y0 = 37 + $dy; $y1 = 64 + $dy
            [void][Cap416]::PostMessageW($rb, 0x0201, [IntPtr]1, [IntPtr](($y0 -shl 16) -bor $x)); Start-Sleep -Milliseconds 300
            foreach ($yy in ($y0 + 6), ($y0 + 14), ($y0 + 22), $y1) { [void][Cap416]::PostMessageW($rb, 0x0200, [IntPtr]1, [IntPtr](($yy -shl 16) -bor ($x + 40))); Start-Sleep -Milliseconds 200 }
            [void][Cap416]::PostMessageW($rb, 0x0202, [IntPtr]0, [IntPtr](($y1 -shl 16) -bor ($x + 40))); Start-Sleep -Milliseconds 1200
        }
        $LG = Fresh $Exe 0 'drag_default' $prepDrag
        $DG = Fresh $Exe 1 'drag_dark' $prepDrag
        $moved = ($LG.TopIndex -ne $L.TopIndex)
        $same = ($LG.TopIndex -eq $DG.TopIndex) -and ($LG.Rebar[3] -eq $DG.Rebar[3]) -and ($LG.Strip[1] -eq $DG.Strip[1])
        $dragLines = [P418]::CheckLines($LG.Bmp, $DG.Bmp, $LG.Rebar[3], 40, 12)
        $lOk = $dragLines -match '^(\d+) line pixels, 0 not' -and [int]$Matches[1] -gt 0
        Row 'DRAG' 'MOVE' (V ($moved -and $same -and $lOk)) ('top toolbar band index {0} before, {1} / {2} after the drag; rebar bottom {3} / {4} (Default / Dark); lines: {5}' -f $L.TopIndex, $LG.TopIndex, $DG.TopIndex, $LG.Rebar[3], $DG.Rebar[3], $dragLines)
        $LG.Bmp.Dispose(); $DG.Bmp.Dispose()
    }

    if (Want 'EXTRA') {
        $DE = Fresh $Exe 1 'extra_dark' $prepExtra
        $changed = ($LE.Bands -ne $L.Bands) -and ($LE.Bands -eq $DE.Bands)
        Row 'EXTRA' 'BARS' (V $changed) ('bands {0} -> {1} (Default) / {2} (Dark) after toggling the Plugins bar and the second drive bar' -f $L.Bands, $LE.Bands, $DE.Bands)
        Compare-Themes 'EXTRA' $LE $DE
        $DE.Bmp.Dispose()
    }

    if (Want 'NARROW') {
        # the extra bars shown (two bands side by side), the window restored and narrowed: a rebar does not move
        # bands to new rows on a resize (only RBBS_BREAK or a drag does) - the bands of one row shrink, and the
        # lines must follow them
        $prep = { param($id) & $prepExtra $id; $m = Get-Main $id; if ([P418]::IsZoomed($m)) { [void][P418]::ShowWindow($m, 9); Start-Sleep -Milliseconds 800 }; [void][Cap416]::SetWindowPos($m, [IntPtr]::Zero, 20, 20, 520, 640, 0x0014); Start-Sleep -Milliseconds 1500 }
        $LN = Fresh $Exe 0 'narrow_default' $prep
        $DN = Fresh $Exe 1 'narrow_dark' $prep
        $narrowed = ($LN.Rebar[2] -lt $LE.Rebar[2] / 2) -and ($LN.Bands -eq $LE.Bands)
        Row 'NARROW' 'RESIZE' (V $narrowed) ('with the extra bars ({0} bands): rebar {1}x{2} at full width, {3}x{4} narrow (Default)' -f $LN.Bands, $LE.Rebar[2], $LE.Rebar[3], $LN.Rebar[2], $LN.Rebar[3])
        Compare-Themes 'NARROW' $LN $DN
        $LN.Bmp.Dispose(); $DN.Bmp.Dispose()
    }
    if ($LE) { $LE.Bmp.Dispose() }
    $L.Bmp.Dispose(); $D.Bmp.Dispose()
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace); Row 'PROBE' 'ERROR' 'FAIL' $_.Exception.Message }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if (Test-Path -LiteralPath $BaseReg) { Remove-Item -LiteralPath $BaseReg -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
