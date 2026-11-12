<#
.SYNOPSIS
    Measurement for backlog item remove-indentation-for-text-viewers (GitHub #29): the DPI awareness
    and the system DPI of tandemcommander.exe and of the WebView2 browser process it starts, and the
    windows of a Code Viewer window (class, process, DPI awareness, rectangle).

.DESCRIPTION
    Fixture %TEMP%\tc29\files\a.txt. F3 (742) opens the Code Viewer; after the page settled the probe
    reads, for the program and for every msedgewebview2.exe whose parent is the program:
    GetAwarenessFromDpiAwarenessContext(GetDpiAwarenessContextForProcess) and GetSystemDpiForProcess,
    and the browser's command line (its DPI switches). Then every descendant window of the viewer
    (EnumChildWindows crosses into the browser's windows). Nothing is changed on the display.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. 'E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1'
if (-not ('Dpi29' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Dpi29
{
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetDpiAwarenessContextForProcess(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll")] public static extern uint GetSystemDpiForProcess(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetWindowDpiAwarenessContext(IntPtr w);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr w);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr w, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr w, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr w, out RECT r);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr w);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr w);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr w, StringBuilder s, int n);
    public delegate bool EnumProc(IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr w, EnumProc p, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public static string Proc(uint pid)
    {
        IntPtr h = OpenProcess(0x1000, false, pid);
        if (h == IntPtr.Zero) return "pid " + pid + ": cannot open";
        try
        {
            int a = GetAwarenessFromDpiAwarenessContext(GetDpiAwarenessContextForProcess(h));
            return "pid " + pid + ": awareness " + a + " (0 unaware, 1 system, 2 per-monitor), system DPI " + GetSystemDpiForProcess(h);
        }
        finally { CloseHandle(h); }
    }
    public static List<string> Tree(IntPtr top)
    {
        var res = new List<string>();
        EnumChildWindows(top, (w, l) =>
        {
            var c = new StringBuilder(256); GetClassNameW(w, c, 256);
            uint pid; GetWindowThreadProcessId(w, out pid);
            RECT r; GetWindowRect(w, out r);
            int a = GetAwarenessFromDpiAwarenessContext(GetWindowDpiAwarenessContext(w));
            res.Add(string.Format("0x{0:X} parent 0x{1:X} '{2}' pid {3} visible {4} awareness {5} dpi {6} rect ({7},{8})-({9},{10})",
                w.ToInt64(), GetParent(w).ToInt64(), c, pid, IsWindowVisible(w), a, GetDpiForWindow(w), r.L, r.T, r.R, r.B));
            return true;
        }, IntPtr.Zero);
        return res;
    }
}
'@
}
$Root = $TempRoot + '\tc29'
$StartDir = $Root + '\start'
$Files = $Root + '\files'

$backup = Join-Path $env:TEMP 'tc29_backup.reg'
$existed = Backup-Reg $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Files
    Set-Config
    $text = ''; for ($i = 1; $i -le 200; $i++) { $text += ("line {0:D4} the quick brown fox jumps over the lazy dog`r`n" -f $i) }
    WriteFile "$Files\a.txt" $text
    Out ("dpi29_probe {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        Key $id 0x24; Key $id 0x28
        Start-Sleep -Milliseconds 400
        $w = Open-ByCmd $id 742 20
        if ($w -eq [IntPtr]::Zero) { Out 'F3 opened no window' }
        else {
            Start-Sleep -Seconds 5
            Out ("viewer window: {0}" -f (WinDesc $w))
            $r = New-Object Dpi29+RECT; [void][Dpi29]::GetWindowRect($w, [ref]$r)
            $c = New-Object Dpi29+RECT; [void][Dpi29]::GetClientRect($w, [ref]$c)
            Out ("viewer rect ({0},{1})-({2},{3}); client {4} x {5}; window awareness {6}, dpi {7}" -f $r.L, $r.T, $r.R, $r.B, $c.R, $c.B, [Dpi29]::GetAwarenessFromDpiAwarenessContext([Dpi29]::GetWindowDpiAwarenessContext($w)), [Dpi29]::GetDpiForWindow($w))
            Out ("program  {0}" -f [Dpi29]::Proc([uint32]$id))
            $kids = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = {0}" -f $id) | Where-Object { $_.Name -eq 'msedgewebview2.exe' })
            Out ("browser processes started by the program: {0}" -f $kids.Count)
            foreach ($k in $kids) {
                Out ("browser  {0}" -f [Dpi29]::Proc([uint32]$k.ProcessId))
                $sw = @([regex]::Matches([string]$k.CommandLine, '--[^ ]*(dpi|scale|device)[^ ]*') | ForEach-Object { $_.Value })
                Out ("  DPI switches: {0}" -f ($(if ($sw.Count) { $sw -join ' ' } else { '<none>' })))
                Out ("  command line: {0}" -f (Esc ([string]$k.CommandLine)))
                $subs = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = {0}" -f $k.ProcessId))
                foreach ($s in $subs) {
                    $t = ([regex]::Match([string]$s.CommandLine, '--type=[^ ]*')).Value
                    Out ("  child {0} {1}: {2}" -f $s.ProcessId, $t, [Dpi29]::Proc([uint32]$s.ProcessId))
                }
            }
            Out 'viewer window tree:'
            foreach ($l in [Dpi29]::Tree($w)) { Out ('  ' + $l) }
            Close-Win $w
        }
    }
    catch { Out ('ERROR ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'RUN' $id $null $before } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    Out ''
    Out ("Left running: {0}; fixture removed: {1}; registry restored+identical: {2}" -f @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit 0
