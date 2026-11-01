param([string]$P = '\\wsl.localhost\Ubuntu\')
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class WslPrim {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern uint GetFileAttributesW(string p);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern uint GetDriveTypeW(string p);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern bool GetDiskFreeSpaceExW(string p, out ulong a, out ulong b, out ulong c);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern bool GetVolumeInformationW(string p, StringBuilder n, int ns, out uint sn, out uint ml, out uint fl, StringBuilder f, int fs);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindFirstChangeNotificationW(string p, bool sub, uint filter);
    [DllImport("kernel32.dll")] public static extern bool FindCloseChangeNotification(IntPtr h);
}
'@
function T([string]$name, [scriptblock]$b) { $sw = [Diagnostics.Stopwatch]::StartNew(); $r = & $b; '{0,-28} {1,8:N1} ms  {2}' -f $name, $sw.Elapsed.TotalMilliseconds, $r }
for ($i = 0; $i -lt 3; $i++) {
    "--- round $i ($P)"
    T 'GetDriveTypeW' { [WslPrim]::GetDriveTypeW($P) }
    T 'GetFileAttributesW' { '0x{0:X}' -f [WslPrim]::GetFileAttributesW($P) }
    T 'GetDiskFreeSpaceExW' { $a = 0; $b = 0; $c = 0; [WslPrim]::GetDiskFreeSpaceExW($P, [ref]$a, [ref]$b, [ref]$c) }
    T 'GetVolumeInformationW' { $n = New-Object Text.StringBuilder 260; $f = New-Object Text.StringBuilder 260; $sn = 0; $ml = 0; $fl = 0; $ok = [WslPrim]::GetVolumeInformationW($P, $n, 260, [ref]$sn, [ref]$ml, [ref]$fl, $f, 260); "$ok fs=$f flags=0x{0:X}" -f $fl }
    T 'FindFirstChangeNotificationW' { $h = [WslPrim]::FindFirstChangeNotificationW($P, $false, 0x1F); $v = $h.ToInt64(); if ($v -ne -1) { [void][WslPrim]::FindCloseChangeNotification($h) }; "handle=$v" }
    T 'enumerate' { @([IO.Directory]::EnumerateFileSystemEntries($P)).Count }
}
