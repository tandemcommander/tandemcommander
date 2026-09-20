<#
.SYNOPSIS
    Diagnostic companion of rm_probe.ps1: lists every top-level window of ONE
    process and, on request, plays the Restart Manager's window protocol by
    hand so that each window's answer and timing become visible.

.DESCRIPTION
    Feature 080. The Restart Manager closes a GUI application by sending, to
    every top-level window of the process:

        WM_QUERYENDSESSION (wParam 0, lParam ENDSESSION_CLOSEAPP)
        WM_ENDSESSION      (wParam TRUE if everyone agreed, else FALSE;
                            lParam ENDSESSION_CLOSEAPP)

    RmShutdown only reports success or failure. This probe sends the same
    messages with SendMessageTimeout and prints what each window answered and
    how long it took, then watches whether the process ends.

    It addresses exactly one process id - never a window of another process.

.PARAMETER ProcessId
    The process to inspect.

.PARAMETER Query
    Send WM_QUERYENDSESSION / ENDSESSION_CLOSEAPP to every top-level window.

.PARAMETER EndSession
    After -Query, send WM_ENDSESSION with wParam = (all agreed) to every
    window that still exists.

.PARAMETER Flags
    lParam to use. Default 1 (ENDSESSION_CLOSEAPP). 0 imitates an ordinary
    sign-out query - use with care, the program really closes.

.PARAMETER WaitExitSeconds
    How long to watch for the process to end after the messages. Default 30.

.NOTES
    Windows PowerShell 5.1 compatible. Exit code: 0 = listed / process ended,
    1 = process still alive after the wait, 3 = usage error.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [switch]$Query,
    [switch]$EndSession,
    [int]$Flags = 1,
    [int]$TimeoutMs = 30000,
    [int]$WaitExitSeconds = 30
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Wnd080
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr hWnd, uint cmd);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SendMessageTimeoutW(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);

    public static List<IntPtr> TopLevel(uint pid)
    {
        var list = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid) list.Add(h);
            return true;
        }, IntPtr.Zero);
        return list;
    }

    public static string Class(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Text(IntPtr h) { var s = new StringBuilder(256); GetWindowTextW(h, s, 256); return s.ToString(); }
    public static uint Thread(IntPtr h) { uint p; return GetWindowThreadProcessId(h, out p); }
}
'@

$WM_QUERYENDSESSION = 0x0011
$WM_ENDSESSION = 0x0016
$SMTO_ABORTIFHUNG = 0x0002

$proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
if (-not $proc) { Write-Host "ERROR: no process $ProcessId"; exit 3 }
Write-Host ("Process    : {0} ({1}), threads: {2}" -f $ProcessId, $proc.Path, $proc.Threads.Count)

$wins = [Wnd080]::TopLevel([uint32]$ProcessId)
Write-Host ("Top-level  : {0} window(s)" -f $wins.Count)
foreach ($h in $wins) {
    $owner = [Wnd080]::GetWindow($h, 4)   # GW_OWNER
    Write-Host ("  0x{0:X8} tid {1,-6} vis={2,-5} en={3,-5} owner=0x{4:X} class='{5}' text='{6}'" -f `
            $h.ToInt64(), [Wnd080]::Thread($h), [Wnd080]::IsWindowVisible($h), [Wnd080]::IsWindowEnabled($h), $owner.ToInt64(), [Wnd080]::Class($h), [Wnd080]::Text($h))
}
if (-not $Query) { exit 0 }

$allAgreed = $true
Write-Host ("WM_QUERYENDSESSION, lParam=0x{0:X}:" -f $Flags)
foreach ($h in $wins) {
    if (-not [Wnd080]::IsWindow($h)) { Write-Host ("  0x{0:X8} gone before it was asked" -f $h.ToInt64()); continue }
    $res = [IntPtr]::Zero
    $cls = [Wnd080]::Class($h)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $ok = [Wnd080]::SendMessageTimeoutW($h, $WM_QUERYENDSESSION, [IntPtr]::Zero, [IntPtr]$Flags, $SMTO_ABORTIFHUNG, [uint32]$TimeoutMs, [ref]$res)
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $sw.Stop()
    if ($ok -eq [IntPtr]::Zero) {
        Write-Host ("  0x{0:X8} '{1}' NO ANSWER after {2:N1} s (error {3}; window exists now: {4})" -f $h.ToInt64(), $cls, $sw.Elapsed.TotalSeconds, $err, [Wnd080]::IsWindow($h))
        if ([Wnd080]::IsWindow($h)) { $allAgreed = $false }
    }
    else {
        Write-Host ("  0x{0:X8} '{1}' answered {2} after {3:N2} s" -f $h.ToInt64(), $cls, $res.ToInt64(), $sw.Elapsed.TotalSeconds)
        if ($res -eq [IntPtr]::Zero) { $allAgreed = $false }
    }
}
Write-Host ("All agreed : {0}; process alive: {1}" -f $allAgreed, [bool](Get-Process -Id $ProcessId -ErrorAction SilentlyContinue))

if ($EndSession) {
    $w = 0; if ($allAgreed) { $w = 1 }
    Write-Host ("WM_ENDSESSION, wParam={0}, lParam=0x{1:X}:" -f $w, $Flags)
    foreach ($h in $wins) {
        if (-not [Wnd080]::IsWindow($h)) { continue }
        $res = [IntPtr]::Zero
        $cls = [Wnd080]::Class($h)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $ok = [Wnd080]::SendMessageTimeoutW($h, $WM_ENDSESSION, [IntPtr]$w, [IntPtr]$Flags, $SMTO_ABORTIFHUNG, [uint32]$TimeoutMs, [ref]$res)
        $sw.Stop()
        Write-Host ("  0x{0:X8} '{1}' returned={2} after {3:N2} s" -f $h.ToInt64(), $cls, ($ok -ne [IntPtr]::Zero), $sw.Elapsed.TotalSeconds)
    }
}

$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $WaitExitSeconds) {
    if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        Write-Host ("Process ended {0:N1} s after the last message" -f $sw.Elapsed.TotalSeconds)
        exit 0
    }
    Start-Sleep -Milliseconds 200
}
$left = [Wnd080]::TopLevel([uint32]$ProcessId)
Write-Host ("Process STILL ALIVE after {0} s; top-level windows left: {1}" -f $WaitExitSeconds, $left.Count)
foreach ($h in $left) { Write-Host ("  0x{0:X8} class='{1}' text='{2}'" -f $h.ToInt64(), [Wnd080]::Class($h), [Wnd080]::Text($h)) }
exit 1
