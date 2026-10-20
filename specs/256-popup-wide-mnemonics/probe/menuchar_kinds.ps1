# Feature 256 measurement: the wParam an owner window receives for WM_MENUCHAR sent with
# SendMessageW / SendMessageA, for a code-page (ANSI) and a Unicode window. The popup sends
# MAKEWPARAM(<UTF-16 unit>, MF_POPUP); the owners forward wParam to IContextMenu3::HandleMenuMsg2.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Kinds256
{
    public delegate IntPtr WndProc(IntPtr h, uint m, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)] public struct WNDCLASSA { public uint style; public WndProc proc; public int c1; public int c2; public IntPtr inst; public IntPtr icon; public IntPtr cursor; public IntPtr brush; public string menu; public string cls; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct WNDCLASSW { public uint style; public WndProc proc; public int c1; public int c2; public IntPtr inst; public IntPtr icon; public IntPtr cursor; public IntPtr brush; public string menu; public string cls; }
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] public static extern ushort RegisterClassA(ref WNDCLASSA c);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern ushort RegisterClassW(ref WNDCLASSW c);
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] public static extern IntPtr CreateWindowExA(uint ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr p, IntPtr menu, IntPtr inst, IntPtr param);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr CreateWindowExW(uint ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr p, IntPtr menu, IntPtr inst, IntPtr param);
    [DllImport("user32.dll")] public static extern IntPtr DefWindowProcA(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr DefWindowProcW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageA(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll")] public static extern bool DestroyWindow(IntPtr h);
    public static long Got;
    static WndProc pa = (h, m, w, l) => { if (m == 0x120) { Got = w.ToInt64(); return IntPtr.Zero; } return DefWindowProcA(h, m, w, l); };
    static WndProc pw = (h, m, w, l) => { if (m == 0x120) { Got = w.ToInt64(); return IntPtr.Zero; } return DefWindowProcW(h, m, w, l); };
    public static string Run()
    {
        var ca = new WNDCLASSA { proc = pa, cls = "tc256KindA" }; RegisterClassA(ref ca);
        var cw = new WNDCLASSW { proc = pw, cls = "tc256KindW" }; RegisterClassW(ref cw);
        IntPtr ha = CreateWindowExA(0, "tc256KindA", "", 0, 0, 0, 0, 0, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
        IntPtr hw = CreateWindowExW(0, "tc256KindW", "", 0, 0, 0, 0, 0, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
        string r = "";
        foreach (int ch in new int[] { 0x0071, 0x010D, 0x0416 })
        {
            IntPtr wp = (IntPtr)((0x10 << 16) | ch);
            foreach (var h in new IntPtr[] { ha, hw })
            {
                string kind = IsWindowUnicode(h) ? "Unicode" : "ANSI";
                Got = -1; SendMessageW(h, 0x120, wp, IntPtr.Zero); long gw = Got;
                Got = -1; SendMessageA(h, 0x120, wp, IntPtr.Zero); long ga = Got;
                r += string.Format("sent {0:X8} to {1,-7} window: SendMessageW -> {2:X8}, SendMessageA -> {3:X8}\n", wp.ToInt64(), kind, gw, ga);
            }
        }
        DestroyWindow(ha); DestroyWindow(hw);
        return r;
    }
}
'@
[Kinds256]::Run()
