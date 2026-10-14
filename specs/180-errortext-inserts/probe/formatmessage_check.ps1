<#
.SYNOPSIS
    Feature 180 check: FormatMessageW with the flags GetErrorText used (FROM_SYSTEM only) fails for a
    Windows text with inserts (%1); with ARGUMENT_ARRAY and placeholder strings it gives the text.
    Prints one line per error code: the old result and the new one. No program is started.
#>
param([string]$OutFile)
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Fm180b
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern int FormatMessageW(int flags, IntPtr src, int id, int lang, StringBuilder buf, int size, IntPtr args);
    public static string WithoutArgs(int err)
    {
        var sb = new StringBuilder(300);
        int n = FormatMessageW(0x1000, IntPtr.Zero, err, 0x400, sb, 300, IntPtr.Zero);
        return n == 0 ? ("FAILED, last error " + Marshal.GetLastWin32Error()) : sb.ToString().Trim();
    }
    public static string WithArgs(int err)
    {
        IntPtr ph = Marshal.StringToHGlobalUni("...");
        IntPtr arr = Marshal.AllocHGlobal(IntPtr.Size * 99);
        for (int i = 0; i < 99; i++) Marshal.WriteIntPtr(arr, i * IntPtr.Size, ph);
        var sb = new StringBuilder(300);
        int n = FormatMessageW(0x1000 | 0x2000, IntPtr.Zero, err, 0x400, sb, 300, arr);
        Marshal.FreeHGlobal(arr); Marshal.FreeHGlobal(ph);
        return n == 0 ? ("FAILED, last error " + Marshal.GetLastWin32Error()) : sb.ToString().Trim();
    }
}
'@
$lines = @()
foreach ($e in @(2, 5, 32, 123, 193, 216, 34, 1392)) {
    $lines += ('{0,5}  old: {1}' -f $e, [Fm180b]::WithoutArgs($e))
    $lines += ('       new: {0}' -f [Fm180b]::WithArgs($e))
}
$lines | ForEach-Object { Write-Output $_ }
if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$lines, (New-Object Text.UTF8Encoding($true))) }
