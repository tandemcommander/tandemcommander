<#
.SYNOPSIS
    Small driver for the busy-state scenarios of feature 080: starts ONE
    instance of a given tandemcommander.exe and talks only to that process,
    by posting messages to its windows (no SendInput, no foreground games,
    nothing that could reach another instance the user may have open).

.DESCRIPTION
    Actions (-Action):
      start        start the program with -l/-r/-a paths and a title prefix,
                   wait until its main window exists, print the pid
      children     list the child windows of the main window (diagnostics)
      command      post WM_COMMAND <Id> to the main window
      key          post WM_KEYDOWN/WM_KEYUP <Vk> to a panel's file list
                   (-Panel 0 = left, 1 = right)
      dialogs      list visible top-level windows of the pid (class, title)
      click        post BM_CLICK to the button with control id <Id> in the
                   top-level dialog whose title contains <Title>
      close        post WM_CLOSE to the main window (a normal, interactive exit)

    Command ids used by the scenarios (src/resource.rh2):
      686 CM_CONFIGURATION   727 CM_COPYFILES   741 CM_FINDFILE   742 CM_VIEW

.NOTES
    Windows PowerShell 5.1 compatible.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('start', 'children', 'command', 'key', 'dialogs', 'click', 'close')][string]$Action,
    [string]$Exe,
    [int]$ProcessId,
    [string]$Left, [string]$Right,
    [string]$TitlePrefix = 'T080',
    [int]$Id,
    [int]$Vk,
    [int]$Panel = 0,
    [string]$Title
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Drv080
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(512); GetWindowTextW(h, s, 512); return s.ToString(); }

    public static List<IntPtr> Top(uint pid)
    {
        var l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { uint q; GetWindowThreadProcessId(h, out q); if (q == pid) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static List<IntPtr> Kids(IntPtr parent)
    {
        var l = new List<IntPtr>();
        EnumChildWindows(parent, delegate(IntPtr h, IntPtr p) { l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
}
'@

$MainClass = 'TandemCommanderMainWindowVer01'

function Get-Main([int]$TargetPid) {
    foreach ($h in [Drv080]::Top([uint32]$TargetPid)) { if ([Drv080]::Cls($h) -eq $MainClass) { return $h } }
    return [IntPtr]::Zero
}

switch ($Action) {
    'start' {
        if (-not $Exe) { throw '-Exe is required' }
        $a = @('-t', $TitlePrefix)
        if ($Left) { $a += @('-l', ('"{0}"' -f $Left)) }
        if ($Right) { $a += @('-r', ('"{0}"' -f $Right)) }
        $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 200 }
        Start-Sleep -Seconds 4   # let start-up finish (plug-ins, panels, icon readers)
        Write-Output $p.Id
    }
    'children' {
        $m = Get-Main $ProcessId
        foreach ($h in [Drv080]::Kids($m)) {
            Write-Host ("  0x{0:X8} id={1,-6} vis={2,-5} class='{3}' text='{4}'" -f $h.ToInt64(), [Drv080]::GetDlgCtrlID($h), [Drv080]::IsWindowVisible($h), [Drv080]::Cls($h), [Drv080]::Txt($h))
        }
    }
    'command' {
        $m = Get-Main $ProcessId
        if ($m -eq [IntPtr]::Zero) { throw "no main window for pid $ProcessId" }
        [void][Drv080]::PostMessageW($m, 0x0111, [IntPtr]$Id, [IntPtr]::Zero)   # WM_COMMAND
        Start-Sleep -Milliseconds 1500
    }
    'key' {
        $m = Get-Main $ProcessId
        # the two panel lists, in creation order: 0 = left, 1 = right
        $lists = @([Drv080]::Kids($m) | Where-Object { [Drv080]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv080]::IsWindowVisible($_) })
        if ($lists.Count -le $Panel) { throw 'panel list window not found - run -Action children' }
        $target = $lists[$Panel]
        [void][Drv080]::PostMessageW($target, 0x0100, [IntPtr]$Vk, [IntPtr]1)            # WM_KEYDOWN
        [void][Drv080]::PostMessageW($target, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)   # WM_KEYUP
        Start-Sleep -Milliseconds 500
    }
    'dialogs' {
        foreach ($h in [Drv080]::Top([uint32]$ProcessId)) {
            if ([Drv080]::IsWindowVisible($h)) {
                Write-Host ("  0x{0:X8} en={1,-5} class='{2}' text='{3}'" -f $h.ToInt64(), [Drv080]::IsWindowEnabled($h), [Drv080]::Cls($h), [Drv080]::Txt($h))
            }
        }
    }
    'click' {
        $done = $false
        foreach ($h in [Drv080]::Top([uint32]$ProcessId)) {
            if ([Drv080]::IsWindowVisible($h) -and [Drv080]::Txt($h) -like "*$Title*") {
                $b = [Drv080]::GetDlgItem($h, $Id)
                if ($b -ne [IntPtr]::Zero) { [void][Drv080]::PostMessageW($b, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero); $done = $true; break }   # BM_CLICK
            }
        }
        if (-not $done) { throw "no visible dialog titled '*$Title*' with control $Id" }
        Start-Sleep -Milliseconds 1000
    }
    'close' {
        $m = Get-Main $ProcessId
        if ($m -ne [IntPtr]::Zero) { [void][Drv080]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    }
}
