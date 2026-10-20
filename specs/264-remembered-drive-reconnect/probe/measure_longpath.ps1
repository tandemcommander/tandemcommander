<#
.SYNOPSIS
    Feature 264 measurement (no GUI): does Windows keep and reconnect a remembered drive whose
    remote path is longer than 259 characters, and what do the ANSI and wide enumerations of
    remembered connections return for it and for a non-code-page path?
.NOTES
    Windows PowerShell 5.1, pure ASCII. Maps a free letter to \\localhost\C$\<fixture under %TEMP%>,
    remembered; removes the mapping, its HKCU\Network key and the fixture, and verifies against a
    snapshot taken at the start.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$OutFile, [int]$Length = 300, [switch]$Scan)
$ErrorActionPreference = 'Stop'

if (-not ('M264' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class M264
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public class NETRESOURCE { public int dwScope, dwType, dwDisplayType, dwUsage; public string lpLocalName, lpRemoteName, lpComment, lpProvider; }
    [StructLayout(LayoutKind.Sequential)]
    struct NRRAW { public int dwScope, dwType, dwDisplayType, dwUsage; public IntPtr lpLocalName, lpRemoteName, lpComment, lpProvider; }
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetAddConnection2W(NETRESOURCE nr, string pwd, string user, int flags);
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetAddConnection3W(IntPtr hwnd, NETRESOURCE nr, string pwd, string user, int flags);
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetCancelConnection2W(string name, int flags, bool force);
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetGetConnectionW(string local, StringBuilder remote, ref int len);
    [DllImport("mpr.dll", EntryPoint = "WNetOpenEnumW")] static extern int OpenEnumW(int scope, int type, int usage, IntPtr nr, out IntPtr h);
    [DllImport("mpr.dll", EntryPoint = "WNetOpenEnumA")] static extern int OpenEnumA(int scope, int type, int usage, IntPtr nr, out IntPtr h);
    [DllImport("mpr.dll", EntryPoint = "WNetEnumResourceW")] static extern int EnumW(IntPtr h, ref int count, IntPtr buf, ref int size);
    [DllImport("mpr.dll", EntryPoint = "WNetEnumResourceA")] static extern int EnumA(IntPtr h, ref int count, IntPtr buf, ref int size);
    [DllImport("mpr.dll")] static extern int WNetCloseEnum(IntPtr h);
    [DllImport("kernel32.dll")] public static extern uint GetLogicalDrives();
    public static int Map(string letter, string remote, bool remember) { var nr = new NETRESOURCE(); nr.dwType = 1; nr.lpLocalName = letter; nr.lpRemoteName = remote; return WNetAddConnection2W(nr, null, null, remember ? 1 : 0); }
    public static int Reconnect3(string letter, string remote) { var nr = new NETRESOURCE(); nr.dwType = 1; nr.lpLocalName = letter; nr.lpRemoteName = remote; return WNetAddConnection3W(IntPtr.Zero, nr, null, null, 1); }
    public static int Cancel(string letter, bool forget) { return WNetCancelConnection2W(letter, forget ? 1 : 0, true); }
    public static string Conn(string letter, out int res) { var sb = new StringBuilder(4096); int len = 4096; res = WNetGetConnectionW(letter, sb, ref len); return sb.ToString(); }
    public static bool Listed(char letter) { return (GetLogicalDrives() & (1u << (char.ToUpperInvariant(letter) - 'A'))) != 0; }
    // remembered remote name of 'letter' from the wide (wide=true) or ANSI enumeration; null when absent
    public static string Remembered(string letter, bool wide, out int err)
    {
        IntPtr h; err = wide ? OpenEnumW(3, 1, 1, IntPtr.Zero, out h) : OpenEnumA(3, 1, 1, IntPtr.Zero, out h);
        if (err != 0) return null;
        string found = null;
        IntPtr buf = Marshal.AllocHGlobal(65536);
        try {
            while (true) {
                int count = -1, size = 65536;
                int r = wide ? EnumW(h, ref count, buf, ref size) : EnumA(h, ref count, buf, ref size);
                if (r != 0 || count <= 0) break;
                int sz = Marshal.SizeOf(typeof(NRRAW));
                for (int i = 0; i < count; i++) {
                    NRRAW n = (NRRAW)Marshal.PtrToStructure(new IntPtr(buf.ToInt64() + i * sz), typeof(NRRAW));
                    string local = n.lpLocalName == IntPtr.Zero ? null : (wide ? Marshal.PtrToStringUni(n.lpLocalName) : Marshal.PtrToStringAnsi(n.lpLocalName));
                    if (local != null && string.Equals(local, letter, StringComparison.OrdinalIgnoreCase))
                        found = n.lpRemoteName == IntPtr.Zero ? "" : (wide ? Marshal.PtrToStringUni(n.lpRemoteName) : Marshal.PtrToStringAnsi(n.lpRemoteName));
                }
            }
        } finally { Marshal.FreeHGlobal(buf); WNetCloseEnum(h); }
        return found;
    }
}
'@
}

$Lines = New-Object System.Collections.ArrayList
function Out([string]$s) { [void]$Lines.Add($s); Write-Output $s }
function Esc([string]$s) { if ($null -eq $s) { return '<null>' }; $b = New-Object Text.StringBuilder; foreach ($c in $s.ToCharArray()) { if ([int]$c -lt 32 -or [int]$c -gt 126) { [void]$b.AppendFormat('\u{0:X4}', [int]$c) } else { [void]$b.Append($c) } }; return $b.ToString() }
function Snap { return ((@(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName } | Sort-Object) -join ',') + ' / ' + ('{0:X8}' -f [M264]::GetLogicalDrives())) }

$Root = $env:TEMP + '\tc264m'
$before = Snap
Out ("264 long-path measurement; snapshot before: {0}" -f $before)
$letter = $null
try {
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
    $Cyr = [string]([char]0x0410) + [char]0x0440 + [char]0x0445 + [char]0x0438 + [char]0x0432
    foreach ($c in [char[]]'ZYXWVUTSRQPONMLKJIH') { if (-not [M264]::Listed($c) -and -not (Test-Path ('HKCU:\Network\' + $c))) { $letter = [string]$c + ':'; break } }
    # a folder whose remote path is exactly 'len' characters (last component padded, ends in Cyrillic)
    function Make([int]$len) {
        $base = $Root + '\d'
        $pre = '\\localhost\C$' + $base.Substring(2) + '\'
        $dir = $base
        $left = $len - $pre.Length
        while ($left -gt 120) { $dir = $dir + '\' + ('p' * 100); $left -= 101 }
        $last = ('q' * ($left - 5)) + $Cyr
        $dir = $dir + '\' + $last
        [void](New-Item -ItemType Directory -Path ('\\?\' + $dir) -Force)
        return '\\localhost\C$' + $dir.Substring(2)
    }
    if ($Scan) {
        foreach ($len in @(200, 240, 250, 255, 256, 257, 258, 259, 260, 261, 262, 270, 300, 400, 1000)) {
            $rm = Make $len
            $r = [M264]::Map($letter, $rm, $true)
            $rr = 0; $cx = ''; if ($r -eq 0) { $cx = [M264]::Conn($letter, [ref]$rr) }
            Out ("scan length {0}: map {1}; WNetGetConnectionW {2} exact {3}" -f $rm.Length, $r, $rr, ($cx -ceq $rm))
            [void][M264]::Cancel($letter, $true)
        }
    }
    $remote = Make $Length
    Out ("remote length {0}: {1}" -f $remote.Length, (Esc $remote))
    $r = [M264]::Map($letter, $remote, $true)
    Out ("map {0} remembered: {1}" -f $letter, $r)
    if ($r -eq 0) {
        $rr = 0; $c1 = [M264]::Conn($letter, [ref]$rr)
        Out ("connected: listed {0}; WNetGetConnectionW {1} len {2} exact {3}" -f [M264]::Listed($letter[0]), $rr, $c1.Length, ($c1 -ceq $remote))
        $reg = (Get-ItemProperty -LiteralPath ('HKCU:\Network\' + $letter[0]) -ErrorAction SilentlyContinue).RemotePath
        Out ("HKCU\Network\{0}\RemotePath len {1} exact {2}" -f $letter[0], $(if ($reg) { $reg.Length } else { -1 }), ($reg -ceq $remote))
        $r2 = [M264]::Cancel($letter, $false)
        $c2 = [M264]::Conn($letter, [ref]$rr)
        Out ("cancel (keep remembered): {0}; listed {1}; WNetGetConnectionW {2} len {3} exact {4}" -f $r2, [M264]::Listed($letter[0]), $rr, $c2.Length, ($c2 -ceq $remote))
        $e = 0
        $w = [M264]::Remembered($letter, $true, [ref]$e)
        Out ("wide enumeration: err {0}; len {1}; exact {2}" -f $e, $(if ($w) { $w.Length } else { -1 }), ($w -ceq $remote))
        $a = [M264]::Remembered($letter, $false, [ref]$e)
        Out ("ANSI enumeration: err {0}; len {1}; text {2}" -f $e, $(if ($a) { $a.Length } else { -1 }), (Esc $a))
        $r3 = [M264]::Reconnect3($letter, $remote)
        Out ("WNetAddConnection3W(exact long path, CONNECT_UPDATE_PROFILE): {0}; listed {1}" -f $r3, [M264]::Listed($letter[0]))
    }
}
catch { Out ('ERROR: ' + $_.Exception.Message) }
finally {
    if ($letter) { [void][M264]::Cancel($letter, $true); if ($before -notmatch ('(^|,)' + $letter[0] + '(,| )')) { Remove-Item -LiteralPath ('HKCU:\Network\' + $letter[0]) -Recurse -Force -ErrorAction SilentlyContinue } }
    try { if (Test-Path -LiteralPath $Root) { cmd.exe /c rd /s /q ('\\?\' + $Root) } } catch { Out ('cleanup: ' + $_.Exception.Message) }
    $after = Snap
    Out ("snapshot after: {0}; equal {1}; fixture removed {2}" -f $after, ($after -eq $before), (-not (Test-Path -LiteralPath $Root)))
    [IO.File]::WriteAllLines($OutFile, [string[]]$Lines, (New-Object Text.UTF8Encoding($false)))
}
