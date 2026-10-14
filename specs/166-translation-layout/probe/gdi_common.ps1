if (-not ('Gdi310' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Gdi310
{
    [StructLayout(LayoutKind.Sequential)] public struct SIZE { public int cx, cy; }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct TEXTMETRIC { public int tmHeight, tmAscent, tmDescent, tmInternalLeading, tmExternalLeading, tmAveCharWidth, tmMaxCharWidth, tmWeight, tmOverhang, tmDigitizedAspectX, tmDigitizedAspectY; public char tmFirstChar, tmLastChar, tmDefaultChar, tmBreakChar; public byte tmItalic, tmUnderlined, tmStruckOut, tmPitchAndFamily, tmCharSet; }
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateFontW(int h, int w, int e, int o, int weight, uint i, uint u, uint s, uint cs, uint op, uint cp, uint q, uint pf, string face);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr h);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern bool GetTextExtentPoint32W(IntPtr dc, string s, int n, out SIZE sz);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern bool GetTextMetricsW(IntPtr dc, out TEXTMETRIC tm);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int DrawTextW(IntPtr dc, string s, int n, ref RECT r, uint f);
    static IntPtr dc;
    public static double BaseX, BaseY;
    public static void Init()
    {
        dc = CreateCompatibleDC(IntPtr.Zero);
        IntPtr f = CreateFontW(-11, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 0, 0, "MS Shell Dlg 2");
        SelectObject(dc, f);
        SIZE sz; GetTextExtentPoint32W(dc, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", 52, out sz);
        BaseX = (sz.cx / 26.0 + 1) / 2.0;
        TEXTMETRIC tm; GetTextMetricsW(dc, out tm); BaseY = tm.tmHeight;
    }
    public static int Width(string s) { SIZE sz; GetTextExtentPoint32W(dc, s, s.Length, out sz); return sz.cx; }
    public static int WrapHeight(string s, int widthPx) { RECT r = new RECT(); r.Right = widthPx; DrawTextW(dc, s, s.Length, ref r, 0x10 | 0x400 | 0x800); return r.Bottom; }
}
'@
}
[Gdi310]::Init()
function Px([double]$dlu) { return [int][Math]::Floor($dlu * [Gdi310]::BaseX / 4) }
function PxY([double]$dlu) { return [int][Math]::Floor($dlu * [Gdi310]::BaseY / 8) }
