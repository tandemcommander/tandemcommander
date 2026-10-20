Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Mc256
{
    [DllImport("user32.dll")] public static extern IntPtr DefWindowProcW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr DefWindowProcA(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr CreatePopupMenu();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool AppendMenuW(IntPtr m, uint f, IntPtr id, string s);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr CreateWindowExW(uint ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr p, IntPtr menu, IntPtr inst, IntPtr param);
}
'@
$h = [Mc256]::CreateWindowExW(0, 'STATIC', '', 0, 0, 0, 0, 0, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
$m = [Mc256]::CreatePopupMenu(); [void][Mc256]::AppendMenuW($m, 0, [IntPtr]1, '&Alpha'); [void][Mc256]::AppendMenuW($m, 0, [IntPtr]2, '&Beta')
foreach ($w in @(0x10, 0x00100061, 0x00100062, 0x00100071, 0x00102000 + 0x20)) {
  'wParam {0:X8}: DefWindowProcW {1:X8}, DefWindowProcA {2:X8}' -f $w, [Mc256]::DefWindowProcW($h, 0x120, [IntPtr]$w, $m).ToInt64(), [Mc256]::DefWindowProcA($h, 0x120, [IntPtr]$w, $m).ToInt64()
}
