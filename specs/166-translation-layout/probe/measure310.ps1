param([string]$Slt, [string]$Text311, [string]$Text3001)
# Measures the two texts of mdview's DIALOG 310 in the dialog font (MS Shell Dlg 2, 8 pt) at 96 DPI:
# the check box label on one line in its width (minus the glyph allowance), the note word-wrapped in
# its rectangle - both converted from dialog units with the font's base units, as Windows does.
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
        IntPtr f = CreateFontW(-11, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 0, 0, "MS Shell Dlg 2"); // 8 pt at 96 DPI
        SelectObject(dc, f);
        SIZE sz; GetTextExtentPoint32W(dc, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", 52, out sz);
        BaseX = (sz.cx / 26.0 + 1) / 2.0;
        TEXTMETRIC tm; GetTextMetricsW(dc, out tm); BaseY = tm.tmHeight;
    }
    public static int Width(string s) { SIZE sz; GetTextExtentPoint32W(dc, s, s.Length, out sz); return sz.cx; }
    public static int WrapHeight(string s, int widthPx) { RECT r = new RECT(); r.Right = widthPx; DrawTextW(dc, s, s.Length, ref r, 0x10 | 0x400 | 0x800); return r.Bottom; } // DT_WORDBREAK|DT_CALCRECT|DT_NOPREFIX
}
'@
[Gdi310]::Init()
function Px([double]$dlu) { return [int][Math]::Floor($dlu * [Gdi310]::BaseX / 4) }
function PxY([double]$dlu) { return [int][Math]::Floor($dlu * [Gdi310]::BaseY / 8) }
$lines = Get-Content -LiteralPath $Slt -Encoding UTF8
$in = $false; $c311 = $null; $c3001 = $null
foreach ($l in $lines) {
    if ($l -match '^\[DIALOG 310\]') { $in = $true; continue }
    if ($in -and $l -match '^\[') { break }
    if ($in -and $l -match '^311,(\d+),(\d+),(\d+),(\d+),\d+,"(.*)"$') { $c311 = $Matches }
    if ($in -and $l -match '^3001,(\d+),(\d+),(\d+),(\d+),\d+,"(.*)"$') { $c3001 = $Matches }
}
$t1 = $(if ($Text311) { $Text311 } else { $c311[5] }) -replace '&', ''
$t2 = $(if ($Text3001) { $Text3001 } else { $c3001[5] })
$w1 = (Px ([int]$c311[3])) - 16   # the check box glyph and its gap
$need1 = [Gdi310]::Width($t1)
$w2 = Px ([int]$c3001[3]); $h2 = PxY ([int]$c3001[4])
$need2 = [Gdi310]::WrapHeight($t2, $w2)
'{0}: 311 needs {1} px of {2} -> {3}; 3001 needs {4} px high of {5} -> {6}' -f (Split-Path (Split-Path $Slt) -Leaf), $need1, $w1, $(if ($need1 -le $w1) { 'fits' } else { 'CUT' }), $need2, $h2, $(if ($need2 -le $h2) { 'fits' } else { 'CUT' })
