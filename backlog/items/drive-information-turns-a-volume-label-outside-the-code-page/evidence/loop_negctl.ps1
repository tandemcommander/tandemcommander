<#
    Negative control for the vol-cjk-type row of vol324_probe.ps1: a WM_CHAR posted with PostMessageW
    to a Unicode edit keeps a CJK letter when the message loop is wide (GetMessageW / DispatchMessageW)
    and loses it to '?' when the loop is the code-page one (GetMessageA / DispatchMessageA). Shows the
    probe's typing row would fail if the dialog's modal loop were a code-page loop.
#>
$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class LoopNeg
{
    [StructLayout(LayoutKind.Sequential)] public struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam; public uint time; public int x; public int y; }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateWindowExW(uint ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr p);
    [DllImport("user32.dll")] static extern bool DestroyWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern bool PeekMessageA(out MSG m, IntPtr h, uint a, uint b, uint r);
    [DllImport("user32.dll")] static extern bool PeekMessageW(out MSG m, IntPtr h, uint a, uint b, uint r);
    [DllImport("user32.dll")] static extern IntPtr DispatchMessageA(ref MSG m);
    [DllImport("user32.dll")] static extern IntPtr DispatchMessageW(ref MSG m);
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    public static string Run(string text, bool wide, out bool unicodeEdit)
    {
        IntPtr e = CreateWindowExW(0, "EDIT", "", 0x00000080 /*ES_AUTOHSCROLL*/, 0, 0, 200, 20, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
        unicodeEdit = IsWindowUnicode(e);
        foreach (char c in text) PostMessageW(e, 0x0102, (IntPtr)c, (IntPtr)1);
        MSG m;
        if (wide) { while (PeekMessageW(out m, e, 0, 0, 1)) DispatchMessageW(ref m); }
        else { while (PeekMessageA(out m, e, 0, 0, 1)) DispatchMessageA(ref m); }
        var sb = new StringBuilder(100); GetWindowTextW(e, sb, 100);
        DestroyWindow(e);
        return sb.ToString();
    }
}
'@
$t = [string]([char]0x4E2D) + [char]0x6587 + '2'
function Esc([string]$s) { return (($s.ToCharArray() | ForEach-Object { if ([int]$_ -lt 128) { [string]$_ } else { '\u{0:X4}' -f [int]$_ } }) -join '') }
$u = $false
$w = [LoopNeg]::Run($t, $true, [ref]$u)
"wide loop      : edit Unicode {0}; posted '{1}', edit holds '{2}'" -f $u, (Esc $t), (Esc $w)
$a = [LoopNeg]::Run($t, $false, [ref]$u)
"code-page loop : edit Unicode {0}; posted '{1}', edit holds '{2}'" -f $u, (Esc $t), (Esc $a)
"ACP {0}" -f [Text.Encoding]::Default.CodePage
