# Feature 416 probe helpers: window captures (PrintWindow) and pixel comparisons.
# Dot-sourced by iconset416_probe.ps1 after specs\098-long-path-overruns\probe\fix_probe_lib.ps1.
Add-Type -AssemblyName System.Drawing
if (-not ('Cap416' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public static class Cap416
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int x, y; }
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(512); GetWindowTextW(h, s, 512); return s.ToString(); }

    public static IntPtr[] Kids(IntPtr parent)
    {
        var list = new List<IntPtr>();
        EnumChildWindows(parent, (h, l) => { list.Add(h); return true; }, IntPtr.Zero);
        return list.ToArray();
    }

    // the window's client area as the program paints it (PW_CLIENTONLY | PW_RENDERFULLCONTENT when 'full')
    public static Bitmap Capture(IntPtr h, bool full)
    {
        RECT r; GetClientRect(h, out r);
        int w = Math.Max(1, r.right), hh = Math.Max(1, r.bottom);
        var bmp = new Bitmap(w, hh, PixelFormat.Format32bppRgb);
        using (var g = Graphics.FromImage(bmp))
        {
            IntPtr dc = g.GetHdc();
            PrintWindow(h, dc, full ? 3u : 1u);
            g.ReleaseHdc(dc);
        }
        return bmp;
    }

    // the part of a window's capture that a child covers (client coordinates of 'top')
    public static Bitmap Crop(Bitmap src, IntPtr top, IntPtr child)
    {
        RECT rc; GetWindowRect(child, out rc);
        POINT o; o.x = 0; o.y = 0; ClientToScreen(top, ref o); // client origin of 'top' in screen coordinates
        int x = Math.Max(0, rc.left - o.x), y = Math.Max(0, rc.top - o.y);
        int w = Math.Min(src.Width - x, rc.right - rc.left), h = Math.Min(src.Height - y, rc.bottom - rc.top);
        if (w <= 0 || h <= 0) return new Bitmap(1, 1);
        return src.Clone(new Rectangle(x, y, w, h), PixelFormat.Format32bppRgb);
    }

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

    // number of differing pixels (-1 = different size)
    public static int Diff(Bitmap a, Bitmap b)
    {
        if (a.Width != b.Width || a.Height != b.Height) return -1;
        int[] pa = Pixels(a), pb = Pixels(b);
        int n = 0;
        for (int i = 0; i < pa.Length; i++) if (pa[i] != pb[i]) n++;
        return n;
    }

    // distinct colours and the share of the most frequent one (a blank capture is one colour)
    public static string Stats(Bitmap b)
    {
        int[] p = Pixels(b);
        var h = new Dictionary<int, int>();
        foreach (int c in p) { int v; h.TryGetValue(c, out v); h[c] = v + 1; }
        int top = 0; foreach (var kv in h) top = Math.Max(top, kv.Value);
        return string.Format("{0}x{1} colours {2} top {3:0.0}%", b.Width, b.Height, h.Count, 100.0 * top / Math.Max(1, p.Length));
    }

    public static int CountColor(Bitmap b, int rgb, int tol)
    {
        int[] p = Pixels(b); int n = 0;
        int r0 = (rgb >> 16) & 255, g0 = (rgb >> 8) & 255, b0 = rgb & 255;
        foreach (int c in p)
        {
            int r = (c >> 16) & 255, g = (c >> 8) & 255, bb = c & 255;
            if (Math.Abs(r - r0) <= tol && Math.Abs(g - g0) <= tol && Math.Abs(bb - b0) <= tol) n++;
        }
        return n;
    }

    public static IntPtr Send(IntPtr h, uint msg, IntPtr w, IntPtr l) { IntPtr r; SendMessageTimeoutW(h, msg, w, l, 0, 10000, out r); return r; }
}
'@
}

# the visible descendants of 'Top' of class 'Cls', top-left first
function Get-Desc([IntPtr]$Top, [string]$Cls) {
    $all = @([Cap416]::Kids($Top) | Where-Object { [Cap416]::IsWindowVisible($_) -and ([Cap416]::Cls($_) -eq $Cls) })
    return @($all | Sort-Object { $r = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($_, [ref]$r); $r.top * 100000 + $r.left })
}
function Save-Png([Drawing.Bitmap]$B, [string]$Path) { $B.Save($Path, [Drawing.Imaging.ImageFormat]::Png) }
