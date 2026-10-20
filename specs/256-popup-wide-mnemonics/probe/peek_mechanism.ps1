# Feature 256 measurement: what a code-page message loop (PeekMessageA, as CMenuPopup::TrackInternal)
# and a wide one (PeekMessageW) receive for a WM_CHAR posted as UTF-16 (PostMessageW) to a window of
# this thread. Prints one line per character.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Peek256
{
    [StructLayout(LayoutKind.Sequential)] public struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam; public uint time; public int x; public int y; }
    [DllImport("user32.dll")] public static extern IntPtr CreateWindowExW(uint ex, [MarshalAs(UnmanagedType.LPWStr)] string cls, [MarshalAs(UnmanagedType.LPWStr)] string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr param);
    [DllImport("user32.dll")] public static extern IntPtr CreateWindowExA(uint ex, [MarshalAs(UnmanagedType.LPStr)] string cls, [MarshalAs(UnmanagedType.LPStr)] string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr param);
    [DllImport("user32.dll")] public static extern bool DestroyWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool PeekMessageA(out MSG m, IntPtr h, uint a, uint b, uint r);
    [DllImport("user32.dll")] public static extern bool PeekMessageW(out MSG m, IntPtr h, uint a, uint b, uint r);
    [DllImport("kernel32.dll")] public static extern uint GetACP();
    public static string Run(bool ansiWindow, int ch)
    {
        IntPtr h = ansiWindow ? CreateWindowExA(0, "STATIC", "", 0, 0, 0, 0, 0, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero)
                              : CreateWindowExW(0, "STATIC", "", 0, 0, 0, 0, 0, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
        MSG m; string a = "", w = "";
        PostMessageW(h, 0x0102, (IntPtr)ch, (IntPtr)1);
        while (PeekMessageA(out m, h, 0x0102, 0x0102, 1)) a += string.Format("{0:X2} ", m.wParam.ToInt64());
        PostMessageW(h, 0x0102, (IntPtr)ch, (IntPtr)1);
        while (PeekMessageW(out m, h, 0x0102, 0x0102, 1)) w += string.Format("{0:X4} ", m.wParam.ToInt64());
        bool uni = IsWindowUnicode(h);
        DestroyWindow(h);
        return string.Format("window {0}: posted U+{1:X4} -> PeekMessageA wParam {2}| PeekMessageW wParam {3}", uni ? "Unicode" : "ANSI", ch, a, w);
    }
}
'@
'ACP ' + [Peek256]::GetACP()
foreach ($ansi in @($true, $false)) { foreach ($c in @(0x0416, 0x010D, 0x0071, 0x4E2D)) { [Peek256]::Run($ansi, $c) } }
