<#
.SYNOPSIS
    Feature 100 measurement: how a caption with a character outside the code
    page survives on an ANSI top-level window (the class of every viewer
    window of the product) - SetWindowTextW versus DefWindowProcW(WM_SETTEXT).

.DESCRIPTION
    Creates, in this process, one window of an ANSI class (window procedure =
    user32!DefWindowProcA, like a winlib CWindow of an ANSI build) and one of
    a Unicode class (DefWindowProcW, control). For each it sets the caption
    "f" + U+65E5 + ".txt" (and the emoji U+1F600 variant) by
      W   SetWindowTextW                     (what codeview/mdview/viewer3 do)
      D   DefWindowProcW(hwnd, WM_SETTEXT)   (the proposed fix)
    and reads back the stored caption (InternalGetWindowText - what the
    caption bar, the taskbar and Alt+Tab show, and what GetWindowTextW of
    another process returns) and GetWindowTextW in the owning process (which
    sends WM_GETTEXT through the window procedure).

    No product code runs. MUST run through tools\run_on_hidden_desktop.ps1
    (it creates windows). Nothing persistent is touched.
#>
[CmdletBinding()]
param([string]$OutFile)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Cap100
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct WNDCLASSEXA { public uint cbSize, style; public IntPtr lpfnWndProc; public int cbClsExtra, cbWndExtra; public IntPtr hInstance, hIcon, hCursor, hbrBackground; public string lpszMenuName, lpszClassName; public IntPtr hIconSm; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct WNDCLASSEXW { public uint cbSize, style; public IntPtr lpfnWndProc; public int cbClsExtra, cbWndExtra; public IntPtr hInstance, hIcon, hCursor, hbrBackground; public string lpszMenuName, lpszClassName; public IntPtr hIconSm; }
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] public static extern ushort RegisterClassExA(ref WNDCLASSEXA c);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern ushort RegisterClassExW(ref WNDCLASSEXW c);
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] public static extern IntPtr CreateWindowExA(int ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr p);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr CreateWindowExW(int ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr p);
    [DllImport("user32.dll")] public static extern bool DestroyWindow(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] public static extern bool UnregisterClassA(string cls, IntPtr inst);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool UnregisterClassW(string cls, IntPtr inst);
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SetWindowTextW(IntPtr h, string s);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "DefWindowProcW")] public static extern IntPtr DefWindowProcWStr(IntPtr h, uint msg, IntPtr w, string l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int InternalGetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)] public static extern IntPtr GetModuleHandleA(string n);
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr m, string n);
    public static string Internal(IntPtr h) { var s = new StringBuilder(512); InternalGetWindowText(h, s, 512); return s.ToString(); }
    public static string Get(IntPtr h) { var s = new StringBuilder(512); GetWindowTextW(h, s, 512); return s.ToString(); }
}
'@
$lines = New-Object System.Collections.ArrayList
function Out([string]$s) { Write-Host $s; [void]$lines.Add($s) }
function Esc([string]$s) { $sb = New-Object Text.StringBuilder; foreach ($c in $s.ToCharArray()) { if ([int]$c -ge 32 -and [int]$c -lt 127) { [void]$sb.Append($c) } else { [void]$sb.AppendFormat('\u{0:X4}', [int]$c) } }; return $sb.ToString() }

$user32 = [Cap100]::GetModuleHandleA('user32.dll')
$inst = [Cap100]::GetModuleHandleA($null)
$clsA = 'tc100_ansi_' + $PID; $clsW = 'tc100_wide_' + $PID
$ca = New-Object Cap100+WNDCLASSEXA; $ca.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($ca); $ca.lpfnWndProc = [Cap100]::GetProcAddress($user32, 'DefWindowProcA'); $ca.hInstance = $inst; $ca.lpszClassName = $clsA
$cw = New-Object Cap100+WNDCLASSEXW; $cw.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($cw); $cw.lpfnWndProc = [Cap100]::GetProcAddress($user32, 'DefWindowProcW'); $cw.hInstance = $inst; $cw.lpszClassName = $clsW
if (-not [Cap100]::RegisterClassExA([ref]$ca)) { throw 'RegisterClassExA failed' }
if (-not [Cap100]::RegisterClassExW([ref]$cw)) { throw 'RegisterClassExW failed' }
$fail = 0
try {
    $hA = [Cap100]::CreateWindowExA(0, $clsA, 'x', 0x00CF0000, 0, 0, 300, 200, [IntPtr]::Zero, [IntPtr]::Zero, $inst, [IntPtr]::Zero)
    $hW = [Cap100]::CreateWindowExW(0, $clsW, 'x', 0x00CF0000, 0, 0, 300, 200, [IntPtr]::Zero, [IntPtr]::Zero, $inst, [IntPtr]::Zero)
    Out ("caption_technique_probe (feature 100); ACP-class window unicode={0}; W-class window unicode={1}" -f [Cap100]::IsWindowUnicode($hA), [Cap100]::IsWindowUnicode($hW))
    foreach ($name in @(('f' + [char]0x65E5 + '.txt'), ('f' + [char]::ConvertFromUtf32(0x1F600) + '.txt'), ('f' + [char]0x0159 + '.txt'))) {
        foreach ($win in @(@('ANSI class', $hA), @('W class', $hW))) {
            foreach ($how in 'SetWindowTextW', 'DefWindowProcW(WM_SETTEXT)') {
                [void][Cap100]::SetWindowTextW($win[1], 'reset')
                if ($how -eq 'SetWindowTextW') { [void][Cap100]::SetWindowTextW($win[1], $name) } else { [void][Cap100]::DefWindowProcWStr($win[1], 0x000C, [IntPtr]::Zero, $name) }
                $stored = [Cap100]::Internal($win[1]); $own = [Cap100]::Get($win[1])
                Out ("{0,-8} {1,-10} {2,-27} stored caption '{3}' exact={4}; GetWindowTextW in-process '{5}'" -f (Esc $name), $win[0], $how, (Esc $stored), ($stored -ceq $name), (Esc $own))
            }
        }
    }
}
finally {
    if ($hA) { [void][Cap100]::DestroyWindow($hA) }
    if ($hW) { [void][Cap100]::DestroyWindow($hW) }
    [void][Cap100]::UnregisterClassA($clsA, $inst); [void][Cap100]::UnregisterClassW($clsW, $inst)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$lines, (New-Object Text.ASCIIEncoding)) }
}
