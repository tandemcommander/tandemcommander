# Standalone experiment (backlog item tmavy-motiv): what makes a DarkMode_Explorer checkbox draw its
# label light or black? No Tandem Commander process, no registry. Run through run_on_hidden_desktop.ps1.
param([Parameter(Mandatory = $true)][string]$OutFile, [Parameter(Mandatory = $true)][string]$CapDir)
$ErrorActionPreference = 'Stop'
[void][IO.Directory]::CreateDirectory($CapDir)
$manifest = Join-Path $CapDir 'cc6.manifest'
[IO.File]::WriteAllText($manifest, @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <dependency><dependentAssembly>
    <assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" version="6.0.0.0" processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*"/>
  </dependentAssembly></dependency>
</assembly>
'@)
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
public static class Chk427
{
    delegate IntPtr WndProc(IntPtr h, uint m, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] struct WNDCLASS { public uint style; public WndProc proc; public int cls, wnd; public IntPtr inst, icon, cursor, bg; public string menu, name; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] struct ACTCTX { public int cbSize; public uint dwFlags; public string lpSource; public ushort a, b; public string c, d, e; public IntPtr f; }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int l, t, r, b; }
    [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr h; public uint m; public IntPtr w, l; public uint t; public int x, y; }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern ushort RegisterClassW(ref WNDCLASS c);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateWindowExW(uint ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr p);
    [DllImport("user32.dll")] static extern IntPtr DefWindowProcW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern bool DestroyWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] static extern bool UpdateWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref Point p);
    [DllImport("user32.dll")] static extern bool PeekMessageW(out MSG m, IntPtr h, uint a, uint b, uint r);
    [DllImport("user32.dll")] static extern bool TranslateMessage(ref MSG m);
    [DllImport("user32.dll")] static extern IntPtr DispatchMessageW(ref MSG m);
    [DllImport("user32.dll")] static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("gdi32.dll")] static extern IntPtr CreateSolidBrush(int c);
    [DllImport("gdi32.dll")] static extern int SetTextColor(IntPtr dc, int c);
    [DllImport("gdi32.dll")] static extern int SetBkColor(IntPtr dc, int c);
    [DllImport("gdi32.dll")] static extern IntPtr GetStockObject(int i);
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] static extern int SetWindowTheme(IntPtr h, string app, string id);
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateActCtxW(ref ACTCTX a);
    [DllImport("kernel32.dll")] static extern bool ActivateActCtx(IntPtr h, out IntPtr cookie);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandleW(string n);

    const int BG = 0x202020;   // COLORREF of the dark face
    const int FG = 0xE0E0E0;   // light text
    static IntPtr brush;
    static WndProc proc = Proc;
    static IntPtr Proc(IntPtr h, uint m, IntPtr w, IntPtr l)
    {
        if (m == 0x0138 || m == 0x0135) { SetTextColor(w, FG); SetBkColor(w, BG); return brush; } // CTLCOLORSTATIC / BTN
        if (m == 0x0014) { RECT r; GetClientRect(h, out r); using (var g = Graphics.FromHdc(w)) g.FillRectangle(new SolidBrush(Color.FromArgb(0x20, 0x20, 0x20)), 0, 0, r.r, r.b); return (IntPtr)1; }
        return DefWindowProcW(h, m, w, l);
    }
    static IntPtr ctx = IntPtr.Zero;
    public static void Init(string manifest)
    {
        brush = CreateSolidBrush(BG);
        var a = new ACTCTX(); a.cbSize = Marshal.SizeOf(typeof(ACTCTX)); a.lpSource = manifest;
        ctx = CreateActCtxW(ref a);
        var c = new WNDCLASS(); c.proc = proc; c.inst = GetModuleHandleW(null); c.name = "Chk427"; c.bg = IntPtr.Zero;
        RegisterClassW(ref c);
    }
    static void Pump() { MSG m; for (int i = 0; i < 50; i++) { while (PeekMessageW(out m, IntPtr.Zero, 0, 0, 1)) { TranslateMessage(ref m); DispatchMessageW(ref m); } Thread.Sleep(10); } }
    // one case: returns "bg ink contrast" of the checkbox label
    public static string Case(string capDir, string tag, bool dwmDark, bool inChild, string themeApp)
    {
        IntPtr cookie; ActivateActCtx(ctx, out cookie);
        IntPtr top = CreateWindowExW(0, "Chk427", tag, 0x10CF0000, 0, 0, 360, 160, IntPtr.Zero, IntPtr.Zero, GetModuleHandleW(null), IntPtr.Zero);
        if (dwmDark) { int v = 1; DwmSetWindowAttribute(top, 20, ref v, 4); }
        IntPtr parent = top;
        if (inChild) parent = CreateWindowExW(0x00010000, "Chk427", "", 0x50000000, 10, 10, 320, 90, top, (IntPtr)5, GetModuleHandleW(null), IntPtr.Zero);
        IntPtr chk = CreateWindowExW(0, "Button", "Checkbox label text WWW", 0x50010003, 10, 10, 250, 24, parent, (IntPtr)100, GetModuleHandleW(null), IntPtr.Zero);
        SendMessageW(chk, 0x0030, GetStockObject(17), (IntPtr)1);
        if (themeApp != null) SetWindowTheme(chk, themeApp, null);
        ShowWindow(top, 5); UpdateWindow(top); Pump();
        RECT rc; GetClientRect(top, out rc);
        var bmp = new Bitmap(Math.Max(1, rc.r), Math.Max(1, rc.b), PixelFormat.Format32bppRgb);
        using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(top, dc, 3); g.ReleaseHdc(dc); }
        bmp.Save(System.IO.Path.Combine(capDir, tag + ".png"), ImageFormat.Png);
        RECT cr; GetWindowRect(chk, out cr); Point o = new Point(0, 0); ClientToScreen(top, ref o);
        var crop = bmp.Clone(new Rectangle(cr.l - o.X + 18, cr.t - o.Y, 200, cr.b - cr.t), PixelFormat.Format32bppRgb);
        string res = Label(crop);
        DestroyWindow(top); Pump();
        return res;
    }
    static double Lum(int c) { Func<int, double> f = v => { double s = v / 255.0; return s <= 0.03928 ? s / 12.92 : Math.Pow((s + 0.055) / 1.055, 2.4); }; return 0.2126 * f((c >> 16) & 255) + 0.7152 * f((c >> 8) & 255) + 0.0722 * f(c & 255); }
    static double Contrast(int a, int b) { double x = Lum(a), y = Lum(b); return (Math.Max(x, y) + 0.05) / (Math.Min(x, y) + 0.05); }
    static string Label(Bitmap b)
    {
        var h = new Dictionary<int, int>();
        for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) { int c = b.GetPixel(x, y).ToArgb() & 0xFFFFFF; int v; h.TryGetValue(c, out v); h[c] = v + 1; }
        int bg = 0, top = -1; foreach (var kv in h) if (kv.Value > top) { top = kv.Value; bg = kv.Key; }
        int ink = bg; double best = 1; foreach (var kv in h) { double c = Contrast(kv.Key, bg); if (c > best) { best = c; ink = kv.Key; } }
        return string.Format("bg #{0:X6} ink #{1:X6} contrast {2:0.00} {3}", bg, ink, best, Lum(ink) > Lum(bg) ? "LIGHT label" : "DARK label");
    }
    public static string OnThread(string capDir, string tag, bool dwmDark, bool inChild, string themeApp)
    {
        string r = null;
        var t = new Thread(() => { r = Case(capDir, tag, dwmDark, inChild, themeApp); });
        t.SetApartmentState(ApartmentState.STA); t.Start(); t.Join();
        return r;
    }
}
'@
$lines = New-Object System.Collections.ArrayList
[Chk427]::Init($manifest)
$cases = @(
    @('main_dwm_explorer', $true, $false, 'DarkMode_Explorer', $false),
    @('main_nodwm_explorer', $false, $false, 'DarkMode_Explorer', $false),
    @('main_dwm_child_explorer', $true, $true, 'DarkMode_Explorer', $false),
    @('main_dwm_default', $true, $false, $null, $false),
    @('main_dwm_classic', $true, $false, '', $false),
    @('thread_dwm_explorer', $true, $false, 'DarkMode_Explorer', $true),
    @('thread_dwm_child_explorer', $true, $true, 'DarkMode_Explorer', $true)
)
foreach ($c in $cases) {
    $r = if ($c[4]) { [Chk427]::OnThread($CapDir, $c[0], $c[1], $c[2], $c[3]) } else { [Chk427]::Case($CapDir, $c[0], $c[1], $c[2], $c[3]) }
    [void]$lines.Add(("{0}: {1}" -f $c[0], $r))
}
[void]$lines.Add(("OS {0}" -f [Environment]::OSVersion.Version))
[IO.File]::WriteAllLines($OutFile, [string[]]$lines)
