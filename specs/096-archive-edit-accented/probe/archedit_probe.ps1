<#
.SYNOPSIS
    Feature 096 measurement probe: a file inside an archive is edited (F4, or
    opened by Enter through its association) and the archive is left (or the
    program is closed). Is the Archive Update question shown, and does the
    archive get the edit?

.DESCRIPTION
    One instance of -Exe per case. The archive (ZIP written by python's
    zipfile, 7z written by 7z.exe) holds exactly one file. Steps, driven by
    window messages on the hidden desktop:
      End, Enter (into the archive) [Home, Down, Enter into the inner folder]
      Home, Down (the file); CM_EDIT (743) or Enter
        the F4 editor is configured (inside the registry backup/restore) as
            cmd.exe /c echo edited096>>"$(FullName)"
        the Enter cases use a .cmd file that appends a line to itself
      the temporary copy in the new %TEMP%\SAL*.tmp folder is read: did the edit happen?
      leave: Backspace out of the archive  |  exit: WM_CLOSE with the archive open
      every window is recorded and answered OK / Yes (Archive Update: Update All)
      the archive is read back (python zipfile / 7z.exe x) and the temporary
      folder is looked at again, after the leave and after the program's exit
    Helper block copied from specs/095-archive-path-buffers/probe/longarc_probe.ps1
    (itself from 094). MUST be started through tools\run_on_hidden_desktop.ps1.
    Refuses to run while a tandemcommander.exe other than -Exe is running.
    HKCU\Software\Tandem Commander is exported before, restored and verified after.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

# ---- helper block of specs/094-plugin-password-encoding/probe/zip_gui_probe.ps1 (copied, unchanged) ----
if (-not ('Drv093' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Drv093
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendTextTimeout(IntPtr h, uint msg, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendGetText(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll")] public static extern uint GetACP();

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(4096); GetWindowTextW(h, s, 4096); return s.ToString(); }
    public static uint PidOf(IntPtr h) { uint q; GetWindowThreadProcessId(h, out q); return q; }

    public static List<IntPtr> Top(uint pid)
    {
        var l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { uint q; GetWindowThreadProcessId(h, out q); if (q == pid && IsWindowVisible(h)) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static List<IntPtr> Kids(IntPtr parent)   // all descendants
    {
        var l = new List<IntPtr>();
        EnumChildWindows(parent, delegate(IntPtr h, IntPtr p) { l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static bool Send(IntPtr h, uint msg, long w, long l, uint timeout)
    {
        IntPtr res;
        return SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, timeout, out res) != IntPtr.Zero;
    }
    public static bool SetText(IntPtr h, string s, uint timeout)
    {
        IntPtr res;
        return SendTextTimeout(h, 0x000C, IntPtr.Zero, s, 0, timeout, out res) != IntPtr.Zero;
    }
    // items of a combo box list (CB_GETCOUNT / CB_GETLBTEXT, marshalled by USER32)
    public static List<string> ComboItems(IntPtr h, uint timeout)
    {
        var l = new List<string>(); IntPtr res;
        if (SendMessageTimeoutW(h, 0x0146, IntPtr.Zero, IntPtr.Zero, 0, timeout, out res) == IntPtr.Zero) return l;
        int n = (int)res.ToInt64();
        for (int i = 0; i < n && i < 40; i++)
        {
            var buf = new char[8192];
            if (SendGetText(h, 0x0148, (IntPtr)i, buf, 0, timeout, out res) == IntPtr.Zero) break;
            int len = (int)res.ToInt64(); if (len < 0) len = 0; if (len > buf.Length) len = buf.Length;
            l.Add(new string(buf, 0, len));
        }
        return l;
    }
    // WM_GETTEXT, wide, by the returned length (code units as they are, no
    // stop at anything but the count the window reports)
    public static string GetText(IntPtr h, uint timeout)
    {
        IntPtr res; var buf = new char[8192];
        SendGetText(h, 0x000D, (IntPtr)buf.Length, buf, 0, timeout, out res);
        int n = (int)res.ToInt64();
        if (n < 0) n = 0; if (n > buf.Length) n = buf.Length;
        return new string(buf, 0, n);
    }
}
'@
}

$MainClass = 'TandemCommanderMainWindowVer01'
$RegKey = 'HKCU\Software\Tandem Commander'
$Started = New-Object System.Collections.ArrayList
$script:Procs = @{}
$script:ExitCodes = New-Object System.Collections.ArrayList
$script:Lines = New-Object System.Collections.ArrayList
$script:Lossy = 0; $script:Pass = 0; $script:NotDriven = 0; $script:Fail = 0
$script:Unexpected = @()

function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
function Hex([string]$s) {
    if ($null -eq $s) { return '<null>' }
    if ($s.Length -eq 0) { return '<empty>' }
    return (($s.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ')
}
function Esc([string]$s) {   # ASCII-safe rendering
    if ($null -eq $s) { return '<null>' }
    $sb = New-Object Text.StringBuilder
    foreach ($c in $s.ToCharArray()) { if ([int]$c -ge 32 -and [int]$c -lt 127) { [void]$sb.Append($c) } else { [void]$sb.AppendFormat('\u{0:X4}', [int]$c) } }
    return $sb.ToString()
}
function Out([string]$line) { Write-Host $line; [void]$script:Lines.Add($line) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }

# ---- registry ---------------------------------------------------------------
function Backup-TcRegistry([string]$File) {
    & cmd.exe /c "reg query `"$RegKey`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    & cmd.exe /c "reg export `"$RegKey`" `"$File`" /y >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'reg export failed' }
    return $true
}
function Restore-TcRegistry([string]$File, [bool]$Existed) {
    & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
    if (-not $Existed) { Out 'Registry: the key did not exist before - deleted'; return $true }
    & cmd.exe /c "reg import `"$File`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Out "Registry: IMPORT FAILED - restore by hand from $File"; return $false }
    $check = "$File.check"
    & cmd.exe /c "reg export `"$RegKey`" `"$check`" /y >nul 2>&1"
    $ha = (Get-FileHash -LiteralPath $File).Hash; $hb = (Get-FileHash -LiteralPath $check).Hash
    Out ("Registry: restored; identical={0}; SHA-256 before {1} / after {2}" -f ($ha -eq $hb), $ha, $hb)
    Remove-Item -LiteralPath $check -Force
    return ($ha -eq $hb)
}

# ---- process and windows ----------------------------------------------------
function Test-Alive([int]$Id) { return [bool](Get-Process -Id $Id -ErrorAction SilentlyContinue) }
# (on a hidden desktop the process also owns the system's "UAC Input Indicator" windows: not the program's)
$SystemClasses = @('UAC_InputIndicatorOverlayWnd', 'UAC Input Indicator')
function Get-Tops([int]$Id) { return @([Drv093]::Top([uint32]$Id) | Where-Object { $SystemClasses -notcontains [Drv093]::Cls($_) }) }
function Get-Main([int]$Id) {
    foreach ($h in [Drv093]::Top([uint32]$Id)) { if ([Drv093]::Cls($h) -eq $MainClass) { return $h } }
    return [IntPtr]::Zero
}
function Assert-Mine([int]$Id, [IntPtr]$H) { if ([Drv093]::PidOf($H) -ne [uint32]$Id) { throw 'window does not belong to the test process' } }
function Sync([int]$Id) {
    $m = Get-Main $Id
    if ($m -eq [IntPtr]::Zero) { throw 'no main window' }
    [void][Drv093]::Send($m, 0, 0, 0, 20000)
}
function Get-DialogText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv093]::Kids($H)) {
        $t = [Drv093]::Txt($c)
        if ($t -and [Drv093]::IsWindowVisible($c)) { $parts += ("[{0} id={1}] {2}" -f [Drv093]::Cls($c), [Drv093]::GetDlgCtrlID($c), (Esc ($t -replace '\s+', ' '))) }
    }
    $r = ($parts -join ' | ')
    if ($r.Length -gt 400) { $r = $r.Substring(0, 400) + '...' }
    return $r
}
function Post-Cmd([IntPtr]$H, [int]$C) { [void][Drv093]::PostMessageW($H, 0x0111, [IntPtr]$C, [IntPtr]::Zero) }

# closes a window of the pid: Cancel command first, then WM_CLOSE
function Close-Win([int]$Id, [IntPtr]$H) {
    if (-not [Drv093]::IsWindow($H)) { return }
    Assert-Mine $Id $H
    Post-Cmd $H 2                                        # IDCANCEL
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv093]::IsWindow($H) -and [Drv093]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
    if ([Drv093]::IsWindow($H) -and [Drv093]::IsWindowVisible($H)) {
        [void][Drv093]::PostMessageW($H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw.Restart()
        while ($sw.Elapsed.TotalSeconds -lt 3 -and [Drv093]::IsWindow($H) -and [Drv093]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
    }
}
# closes every top-level window of the pid except the main one; records them
function Clear-Wins([int]$Id, [string]$Where, [bool]$Record = $true) {
    for ($round = 0; $round -lt 4; $round++) {
        $extra = @(Get-Tops $Id | Where-Object { [Drv093]::Cls($_) -ne $MainClass })
        if (-not $extra.Count) { return }
        foreach ($h in $extra) {
            if ($Record) {
                $d = ("{0}: window class={1} title='{2}': {3}" -f $Where, [Drv093]::Cls($h), (Esc ([Drv093]::Txt($h))), (Get-DialogText $h))
                Out "   UNEXPECTED $d"; $script:Unexpected += $d
            }
            Close-Win $Id $h
        }
    }
}
function Wait-NewWin([int]$Id, $Known, [double]$Seconds = 8) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in (Get-Tops $Id)) { if ($Known -notcontains $h) { Start-Sleep -Milliseconds 400; return $h } }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
# posts a command to the main window and returns the new top-level window (or Zero)
function Open-ByCmd([int]$Id, [int]$C, [double]$Seconds = 8) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) $C
    return (Wait-NewWin $Id $known $Seconds)
}

function Start-Tc([string]$Dir) {
    $a = @('-t', 'T094', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Dir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id)
    [void]$p.Handle                      # keeps the exit code readable after the process has ended
    $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 3000
    Sync $p.Id
    Clear-Wins $p.Id 'start'
    return $p.Id
}
function Stop-Tc([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    if ($Started -notcontains $Id) { throw "pid $Id was not started by this probe" }
    Clear-Wins $Id 'stop' $false
    $m = Get-Main $Id
    if ($m -ne [IntPtr]::Zero) { [void][Drv093]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
        foreach ($h in (Get-Tops $Id)) {
            if ([Drv093]::Cls($h) -eq '#32770') {
                $yes = [Drv093]::Kids($h) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
                if ($yes) { [void][Drv093]::PostMessageW($yes, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
                else { [void][Drv093]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
            }
        }
        Start-Sleep -Milliseconds 200
    }
    if (Test-Alive $Id) { Out "   (pid $Id did not exit in 30 s - ended by pid)"; [void]$script:ExitCodes.Add('killed'); Stop-Process -Id $Id -Force; Start-Sleep -Milliseconds 500 }
    elseif ($script:Procs.ContainsKey($Id)) {
        $pr = $script:Procs[$Id]; $script:Procs.Remove($Id)
        try { [void]$pr.WaitForExit(5000); $ec = $pr.ExitCode } catch { $ec = 'unknown' }
        [void]$script:ExitCodes.Add("$ec")
        Out ("   process exit code: {0}" -f $ec)
    }
}

function Get-LeftList([int]$Id) {
    $m = Get-Main $Id
    $lists = @([Drv093]::Kids($m) | Where-Object { [Drv093]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv093]::IsWindowVisible($_) })
    if ($lists.Count -lt 1) { throw 'panel list window not found' }
    return $lists[0]
}
function Key([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv093]::Send($l, 0x0100, $Vk, 1, 20000)
    [void][Drv093]::Send($l, 0x0101, $Vk, 0xC0000001, 20000)
}
function Title([int]$Id) { return [Drv093]::Txt((Get-Main $Id)) }

function Find-Ctl([IntPtr]$Dlg, [int]$CtlId) {
    $c = @([Drv093]::Kids($Dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq $CtlId -and @('ComboBox', 'Edit') -contains [Drv093]::Cls($_) })
    $v = @($c | Where-Object { [Drv093]::IsWindowVisible($_) })
    if ($v.Count) { return $v[0] }
    if ($c.Count) { return $c[0] }
    return [IntPtr]::Zero
}

# OK: BM_CLICK on the IDOK button; when the dialog stays, WM_COMMAND IDOK
function Click-Ok([IntPtr]$Dlg) {
    $ok = [Drv093]::Kids($Dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 1 -and [Drv093]::Cls($_) -eq 'Button' } | Select-Object -First 1
    $how = 'BM_CLICK'
    if ($ok) { [void][Drv093]::PostMessageW($ok, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv093]::IsWindow($Dlg) -and [Drv093]::IsWindowEnabled($Dlg)) { Start-Sleep -Milliseconds 50 }
    if ([Drv093]::IsWindow($Dlg) -and [Drv093]::IsWindowEnabled($Dlg)) { Post-Cmd $Dlg 1; $how = 'WM_COMMAND IDOK (BM_CLICK had no effect)' }
    return $how
}


function Buttons([IntPtr]$H) { return @([Drv093]::Kids($H) | Where-Object { [Drv093]::Cls($_) -eq 'Button' -and [Drv093]::IsWindowVisible($_) }) }
function Click([IntPtr]$Btn) { [void][Drv093]::PostMessageW($Btn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }

# ---- this probe --------------------------------------------------------------
# The core truncates an archive's full path to MAX_PATH (259) bytes in
# ChangePathToArchive (a bounded lstrcpyn), so an archive whose PATH exceeds
# that cannot be entered at all - the disk-cache buffers can overrun only from
# the path and name INSIDE the archive, which each reach 255 bytes (the ZIP
# plug-in's AddFile limit). So every archive sits at a short path and holds one
# entry at a long inner path with a long name; the sum
#     <archive> \ <inner dir> \ <inner name>
# is what the four functions fold into their buffer. ExecuteFromArchive
# (fileswn6, char[2*MAX_PATH] = 520) is the one this exceeds in practice
# (archive ~60 + inner dir ~250 + name ~254); the disk-cache name must still be
# byte-for-byte what it was for inputs that fit.
$LP = '\\?\'
$Utf8 = New-Object Text.UTF8Encoding($false)
function U8Len([string]$s) { return $Utf8.GetByteCount($s) }
function Tail([string]$s, [int]$n = 60) { if ($s.Length -le $n) { return (Esc $s) }; return ('...' + (Esc $s.Substring($s.Length - $n))) }

$TempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$Root = $TempRoot + '\tc096_accent'
$ReportDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$Marker = 'edited096'

function Set-ProbeConfig {
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    $fresh = ($LASTEXITCODE -ne 0)
    if (-not $fresh) {
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Archive' /t REG_DWORD /d 1 /f | Out-Null
        # the F4 editor: a console command that appends one line to the temporary copy and ends
        & cmd.exe /c "reg delete `"$RegKey\0.1\Editors`" /f >nul 2>&1"
        $k = "$RegKey\0.1\Editors\1"
        & reg.exe add $k /v 'Masks' /t REG_SZ /d '*.*' /f | Out-Null
        & reg.exe add $k /v 'Command' /t REG_SZ /d (Join-Path $env:SystemRoot 'System32\cmd.exe') /f | Out-Null
        Set-ItemProperty -LiteralPath ('Registry::' + $k.Replace('HKCU\', 'HKEY_CURRENT_USER\')) -Name 'Arguments' -Value ('/c echo ' + $Marker + '>>"$(FullName)"')
        & reg.exe add $k /v 'Initial Directory' /t REG_SZ /d (Join-Path $env:SystemRoot 'System32') /f | Out-Null
    }
    return $fresh
}

function Start-Tc095([string]$Dir) {
    $a = @('-t', 'T096', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $TempRoot), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id)
    [void]$p.Handle
    $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Alive $p.Id)) { throw 'the program ended before showing its main window' }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv093]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 3000
    return $p.Id
}
function ExitCodeOf([int]$Id) {
    if (-not $script:Procs.ContainsKey($Id)) { return 'unknown' }
    $pr = $script:Procs[$Id]
    try { [void]$pr.WaitForExit(5000); return ('0x{0:X8}' -f $pr.ExitCode) } catch { return 'unknown' }
}
function Kill-Mine([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    if ($Started -notcontains $Id) { throw "pid $Id was not started by this probe" }
    Stop-Process -Id $Id -Force
    Start-Sleep -Milliseconds 700
}
function Responsive([int]$Id) {
    if (-not (Test-Alive $Id)) { return $false }
    $m = Get-Main $Id
    if ($m -eq [IntPtr]::Zero) { return $false }
    return [Drv093]::Send($m, 0, 0, 0, 10000)       # WM_NULL round trip
}
function PostKey([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv093]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv093]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L)
}
function WinDesc([IntPtr]$H) { return ("[{0} '{1}'] {2}" -f [Drv093]::Cls($H), (Tail ([Drv093]::Txt($H)) 70), (Get-DialogText $H)) }
$FatalRx = 'Run-Time Check|Debug Error|Assertion|Runtime Library|Stack around|bug report|abnormal|has stopped|Unhandled exception|buffer overrun'
$TooLongRx = 'too long'
function Is-Fatal([string]$Desc) { return ($Desc -match $FatalRx) }

# Serves the instance's windows until it is idle (no window but the main one for
# 1.5 s). Each window kept 0.6 s is recorded and answered (OK/Yes, or Ignore All
# when a pack failed, or No for the leftover-temp-dirs question). A run-time
# check / assertion / crash window is recorded FATAL and the loop stops.
function Serve([int]$Id, [double]$Seconds = 45) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $false; TimedOut = $false; Died = $false }
    $seen = @{}; $idleSince = $null; $packFailed = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { $r.Died = $true; break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv093]::Cls($_) -ne $MainClass })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 1.5) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv093]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if (Is-Fatal $d) { [void]$r.Messages.Add('FATAL ' + $d); $r.Fatal = $true; return $r }
            if (-not [Drv093]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv093]::GetDlgCtrlID($_) })
            $isProgress = ($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)
            if ($isProgress) { continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            [void]$r.Messages.Add($d)
            $seen.Remove($key)
            $want = @(1, 6)                                                              # OK / Yes
            if ($d -match 'temporary director') { $want = @(4) }                         # leftovers of earlier instances: No
            elseif ($d -match 'Packing of updated file') { $want = @(7); $packFailed = $true }  # no retry
            elseif ($packFailed -and [Drv093]::Txt($h) -eq 'Archive Update') { $want = @(2) }    # Ignore All
            $pick = $btn | Where-Object { $want -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($pick) { Click $pick } else { Close-Win $Id $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function MsgText($r) { if ($r.Messages.Count) { return (($r.Messages | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) + '...' } else { $_ } }) -join ' || ') } else { return 'no window' } }


# ---- feature 096 -------------------------------------------------------------
$Rr = [string][char]0x0159
function Count-Marker([byte[]]$Bytes) {
    if ($null -eq $Bytes) { return -1 }
    $t = [Text.Encoding]::GetEncoding(28591).GetString($Bytes)
    return ([regex]::Matches($t, [regex]::Escape($Marker))).Count
}
# files in SAL*.tmp folders of $TmpDir that were not there before: name, marker count, size
function Find-Tmp([string[]]$TmpDir, $Before) {
    $r = @()
    foreach ($d in @($TmpDir | ForEach-Object { [IO.Directory]::GetDirectories($_, 'SAL*.tmp') })) {
        if ($Before -contains $d) { continue }
        try {
            foreach ($f in [IO.Directory]::GetFiles($d, '*', [IO.SearchOption]::AllDirectories)) {
                $b = $null; try { $b = [IO.File]::ReadAllBytes($f) } catch { }
                $r += [pscustomobject]@{ Dir = $(if ($TmpDir.Count -gt 1) { Esc $d } else { [IO.Path]::GetFileName($d) }); Name = [IO.Path]::GetFileName($f); Count = (Count-Marker $b); Size = $(if ($b) { $b.Length } else { -1 }) }
            }
        }
        catch { }
    }
    return , $r
}
function TmpDesc($l) { if (-not $l -or -not $l.Count) { return 'none' }; return (($l | ForEach-Object { "{0}\{1} ({2} bytes, marker x{3})" -f $_.Dir, (Tail $_.Name 24), $_.Size, $_.Count }) -join '; ') }

function New-Zip([string]$Arc, [string]$Inner, [string]$Data) {
    $py = Join-Path $Root 'mkzip.py'
    $code = @(
        'import sys, io, zipfile',
        'a = io.open(sys.argv[1], "r", encoding="utf-8", newline="").read().split("\n")',
        'z = zipfile.ZipFile(a[0], "w", zipfile.ZIP_DEFLATED)',
        'zi = zipfile.ZipInfo(a[1], (2026, 1, 2, 3, 4, 6))',
        'zi.compress_type = zipfile.ZIP_DEFLATED',
        'z.writestr(zi, a[2].replace("<CRLF>", "\r\n").encode("ascii"))',
        'z.close()')
    [IO.File]::WriteAllLines($py, $code, (New-Object Text.ASCIIEncoding))
    $spec = Join-Path $Root 'zipspec.txt'
    [IO.File]::WriteAllText($spec, ($Arc + "`n" + $Inner + "`n" + $Data.Replace("`r`n", '<CRLF>') + "`n"), $Utf8)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $py $spec 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ('mkzip.py: ' + ($o -join ' ')) }
}
function Read-Zip([string]$Arc, [string]$Inner) {
    # -> "ok items markerCount" or an error text
    $py = Join-Path $Root 'rdzip.py'
    $code = @(
        'import sys, io, zipfile',
        'a = io.open(sys.argv[1], "r", encoding="utf-8").read().split("\n")',
        'z = zipfile.ZipFile(a[0])',
        'ok = z.testzip() is None',
        'try: n = z.read(a[1]).count(a[2].encode("ascii"))',
        'except Exception as e: n = "MISSING"',
        'print(ok, len(z.namelist()), n)')
    [IO.File]::WriteAllLines($py, $code, (New-Object Text.ASCIIEncoding))
    $spec = Join-Path $Root 'rdzip.txt'
    [IO.File]::WriteAllText($spec, ($Arc + "`n" + $Inner + "`n" + $Marker + "`n"), $Utf8)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $py $spec 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { return ('python failed: ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return ("$o")
}
function New-7z([string]$Arc, [string]$Inner, [string]$Data, [string]$Stage) {
    $f = Join-Path $Stage ($Inner.Replace('/', '\'))
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($f))
    [IO.File]::WriteAllText($f, $Data, (New-Object Text.ASCIIEncoding))
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $Stage
    try { $o = & $SevenZip a -t7z $Arc '*' -r 2>&1; $rc = $LASTEXITCODE } finally { Pop-Location; $ErrorActionPreference = $old }
    if ($rc -ne 0) { throw ('7z a: ' + ($o -join ' ')) }
}
function Read-7z([string]$Arc, [string]$Inner, [string]$OutDir) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $SevenZip x $Arc ('-o' + $OutDir) -y 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { return ('7z x failed rc ' + $rc) }
    $all = @([IO.Directory]::GetFiles($OutDir, '*', [IO.SearchOption]::AllDirectories))
    $f = Join-Path $OutDir ($Inner.Replace('/', '\'))
    if (-not [IO.File]::Exists($f)) { return ("True {0} MISSING" -f $all.Count) }
    return ("True {0} {1}" -f $all.Count, (Count-Marker ([IO.File]::ReadAllBytes($f))))
}

$script:Table = New-Object System.Collections.ArrayList
function Run-Case($c) {
    $N = $c.N; $fmt = $c.Fmt; $inner = $(if ($c.Dir) { $c.Dir + '/' + $c.Name } else { $c.Name })
    $dir = $Root + '\' + $N
    [void][IO.Directory]::CreateDirectory($dir)
    $arc = $dir + '\arc.' + $fmt
    $isCmd = $c.Name.EndsWith('.cmd')
    $data = $(if ($isCmd) { '@echo rem ' + $Marker + '>>"%~f0"' + "`r`n" } else { "content`r`n" })
    $base = $(if ($isCmd) { 1 } else { 0 })
    if ($fmt -eq 'zip') { New-Zip $arc $inner $data } else { $st = $Root + '\stage_' + $N; [void][IO.Directory]::CreateDirectory($st); New-7z $arc $inner $data $st }
    $tmpDir = $TempRoot
    $oldTemp = $env:TEMP; $oldTmp = $env:TMP
    if ($c.TempAcc) { $tmpDir = $Root + '\do' + [char]0x010D + 'asn' + [char]0x00FD; [void][IO.Directory]::CreateDirectory($tmpDir); $env:TEMP = $tmpDir; $env:TMP = $tmpDir; $tmpDir = @($tmpDir, $TempRoot) }
    $tmpBefore = @($tmpDir | ForEach-Object { [IO.Directory]::GetDirectories($_, 'SAL*.tmp') })
    $before = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    Out ''
    Out ("--- {0}: {1} entry '{2}' ({3} UTF-8 bytes in the name); mode {4}/{5}{6}" -f $N, $fmt, (Tail $inner 40), (U8Len $c.Name), $c.Mode, $c.Leave, $(if ($c.TempAcc) { '; TEMP=' + (Esc $tmpDir[0]) } else { '' }))
    $row = [ordered]@{ Case = $N; Fmt = $fmt; Name = (Esc $inner); Mode = ($c.Mode + '/' + $c.Leave); EditRan = '-'; Info = '-'; UpdateDlg = '-'; Archive = '-'; TmpAfterLeave = '-'; TmpAfterExit = '-'; Other = '' }
    $id = 0
    try {
        if ($c.TempAcc) {
            # Start-Process does not hand the changed TEMP/TMP to the child here; start with an explicit environment
            $psi = New-Object Diagnostics.ProcessStartInfo
            $psi.FileName = $Exe; $psi.UseShellExecute = $false
            $psi.Arguments = ('-t T096 -l "{0}" -r "{1}" -p 1' -f $dir, $TempRoot)
            $psi.EnvironmentVariables['TEMP'] = $tmpDir[0]; $psi.EnvironmentVariables['TMP'] = $tmpDir[0]
            $p = [Diagnostics.Process]::Start($psi)
            [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
            if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
            try { [void]$p.WaitForInputIdle(30000) } catch { }
            [void][Drv093]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
            Start-Sleep -Milliseconds 3000
            $id = $p.Id
        }
        else { $id = Start-Tc095 $dir }
        $r0 = Serve $id 6
        if ($r0.Messages.Count) { Out ('   at start: ' + (MsgText $r0)) }
        $title0 = Title $id
        Key $id 0x23; PostKey $id 0x0D; Start-Sleep -Milliseconds 1200
        $r = Serve $id 30
        $t1 = Title $id
        if ($t1 -notmatch 'arc\.') { throw ("not inside the archive: title '" + (Tail $t1 50) + "' windows: " + (MsgText $r)) }
        if ($c.Dir) {
            Key $id 0x24; Key $id 0x28; PostKey $id 0x0D; Start-Sleep -Milliseconds 1200
            $r = Serve $id 20
            if ((Title $id) -eq $t1) { throw 'did not enter the inner folder' }
        }
        Key $id 0x24; Key $id 0x28
        if ($c.Mode -eq 'edit') { Post-Cmd (Get-Main $id) 743 } else { PostKey $id 0x0D }
        $sw = [Diagnostics.Stopwatch]::StartNew(); $tmp1 = @()
        while ($sw.Elapsed.TotalSeconds -lt 10) {
            $tmp1 = Find-Tmp $tmpDir $tmpBefore
            if (@($tmp1 | Where-Object { $_.Count -gt $base }).Count) { break }
            Start-Sleep -Milliseconds 300
        }
        Start-Sleep -Milliseconds 800
        $r = Serve $id 20
        $tmp1 = Find-Tmp $tmpDir $tmpBefore
        $edited = @($tmp1 | Where-Object { $_.Count -gt $base }).Count -gt 0
        $sameName = @($tmp1 | Where-Object { $_.Name -ceq $c.Name }).Count -gt 0
        $row.EditRan = $(if ($edited) { 'yes' } else { 'NO' })
        Out ("   EDIT : temporary copy: {0}; tmp name equals archive name: {1}; windows: {2}" -f (TmpDesc $tmp1), $sameName, (MsgText $r))
        if ($r.Messages.Count) { $row.Other += 'at edit: ' + (MsgText $r) + ' ' }
        Start-Sleep -Milliseconds 1200
        if ($c.Leave -eq 'leave') {
            PostKey $id 0x08; Start-Sleep -Milliseconds 1000
            if ($c.Dir) { PostKey $id 0x08; Start-Sleep -Milliseconds 1000 }
            $r = Serve $id 60
        }
        else {
            [void][Drv093]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            $r = Serve $id 60
        }
        $m = MsgText $r
        $row.Info = $(if ($m -match 'is about to close|save changes') { 'yes' } else { 'no' })
        $row.UpdateDlg = $(if ($m -match "'Archive Update'") { 'yes' } else { 'NO' })
        $others = @($r.Messages | Where-Object { $_ -notmatch "about to close|'Archive Update'|monitored handles|'Add Files to Archive'|'Confirm File Overwrite'" })
        if ($others.Count) { $row.Other += 'at leave: ' + (($others | ForEach-Object { if ($_.Length -gt 200) { $_.Substring(0, 200) } else { $_ } }) -join ' || ') }
        if ($c.Leave -eq 'leave') { $left = ((Title $id) -eq $title0) } else { $left = (-not (Test-Alive $id)) }
        Start-Sleep -Milliseconds 500
        $tmp2 = Find-Tmp $tmpDir $tmpBefore
        if ($c.Leave -eq 'leave') { $row.TmpAfterLeave = $(if ($tmp2.Count) { 'present' } else { 'deleted' }) }
        Out ("   LEAVE: left/ended {0}; windows: {1}" -f $left, $m)
        Out ("          temporary copy after: {0}" -f (TmpDesc $tmp2))
        if (Test-Alive $id) {
            [void][Drv093]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $id)) {
                foreach ($h in @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -eq '#32770' })) { $d = WinDesc $h; if ($d -notmatch 'monitored handles') { Out ('   at exit: ' + $d) }; $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
                Start-Sleep -Milliseconds 200
            }
            if (Test-Alive $id) { Kill-Mine $id; Out '   END  : did not exit in 30 s - ended by the probe' }
        }
        Start-Sleep -Milliseconds 700
        $ec = ExitCodeOf $id
        $tmp3 = Find-Tmp $tmpDir $tmpBefore
        $row.TmpAfterExit = $(if ($tmp3.Count) { 'present' } else { 'deleted' })
        if ($fmt -eq 'zip') { $z = Read-Zip $arc $inner } else { $z = Read-7z $arc $inner ($Root + '\x_' + $N) }
        $cnt = ($z -split ' ')[-1]
        $row.Archive = $(if ($cnt -match '^\d+$' -and [int]$cnt -gt $base) { 'UPDATED' } elseif ($cnt -match '^\d+$') { 'unchanged' } else { $z })
        $new = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Where-Object { $before -notcontains $_ })
        foreach ($n in $new) { Remove-Item -LiteralPath (Join-Path $ReportDir $n) -Force -ErrorAction SilentlyContinue }
        Out ("   END  : exit code {0}; new crash reports {1}; archive (ok items markers): {2}; temporary copy after exit: {3}" -f $ec, $new.Count, $z, (TmpDesc $tmp3))
    }
    catch {
        Out ('   exception: ' + $_.Exception.Message); $row.Other += 'NOT DRIVEN: ' + $_.Exception.Message
    }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        $env:TEMP = $oldTemp; $env:TMP = $oldTmp
        Start-Sleep -Milliseconds 300
        foreach ($t in @($tmpDir | ForEach-Object { [IO.Directory]::GetDirectories($_, 'SAL*.tmp') } | Where-Object { $tmpBefore -notcontains $_ })) {
            Out ("   left in the temp folder by the test instance, removed: {0}" -f [IO.Path]::GetFileName($t))
            try { [IO.Directory]::Delete($t, $true) } catch { }
        }
        [void]$script:Table.Add([pscustomobject]$row)
    }
}

# ---- main ---------------------------------------------------------------------
$backupDir = Join-Path $env:TEMP 'tc096_accent_reg'
[void][IO.Directory]::CreateDirectory($backupDir)
$backup = Join-Path $backupDir 'backup.reg'
$existed = Backup-TcRegistry $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $fresh = Set-ProbeConfig
    Out ("archedit_probe (feature 096 measurement) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv093]::GetACP())
    Out ("Config  : registry key existed {0}; fresh defaults {1}; F4 editor = cmd.exe /c echo {2}>>`"`$(FullName)`"" -f $existed, $fresh, $Marker)
    if ($fresh) { throw 'no stored configuration - the F4 editor cannot be configured' }
    $cl = [string][char]0x010D + 'l' + [char]0x00E1 + 'nek.txt'
    $cyr = (S 0x041A, 0x0438, 0x0440, 0x0438, 0x043B) + '.txt'
    $accDir = 'slo' + [char]0x017E + 'ka'
    $cases = @(
        @{ N = 'ascii'; Fmt = 'zip'; Name = 'a.txt'; Mode = 'edit'; Leave = 'leave' },
        @{ N = 'clanek'; Fmt = 'zip'; Name = $cl; Mode = 'edit'; Leave = 'leave' },
        @{ N = 'r'; Fmt = 'zip'; Name = ($Rr + '.txt'); Mode = 'edit'; Leave = 'leave' },
        @{ N = 'cyr'; Fmt = 'zip'; Name = $cyr; Mode = 'edit'; Leave = 'leave' },
        @{ N = 'space'; Fmt = 'zip'; Name = 'a b.txt'; Mode = 'edit'; Leave = 'leave' },
        @{ N = 'subasc'; Fmt = 'zip'; Name = 'a.txt'; Dir = $accDir; Mode = 'edit'; Leave = 'leave' },
        @{ N = 'subacc'; Fmt = 'zip'; Name = ($Rr + '.txt'); Dir = $accDir; Mode = 'edit'; Leave = 'leave' },
        @{ N = 'L60'; Fmt = 'zip'; Name = ($Rr * 56 + '.txt'); Mode = 'edit'; Leave = 'leave' },
        @{ N = 'L67'; Fmt = 'zip'; Name = ($Rr * 63 + '.txt'); Mode = 'edit'; Leave = 'leave' },
        @{ N = 'L77'; Fmt = 'zip'; Name = ($Rr * 73 + '.txt'); Mode = 'edit'; Leave = 'leave' },
        @{ N = 'xascii'; Fmt = 'zip'; Name = 'a.txt'; Mode = 'edit'; Leave = 'exit' },
        @{ N = 'xr'; Fmt = 'zip'; Name = ($Rr + '.txt'); Mode = 'edit'; Leave = 'exit' },
        @{ N = 'eascii'; Fmt = 'zip'; Name = 'a.cmd'; Mode = 'enter'; Leave = 'leave' },
        @{ N = 'er'; Fmt = 'zip'; Name = ($Rr + '.cmd'); Mode = 'enter'; Leave = 'leave' },
        @{ N = 'tmpacc'; Fmt = 'zip'; Name = 'a.txt'; Mode = 'edit'; Leave = 'leave'; TempAcc = $true },
        @{ N = '7ascii'; Fmt = '7z'; Name = 'a.txt'; Mode = 'edit'; Leave = 'leave' },
        @{ N = '7r'; Fmt = '7z'; Name = ($Rr + '.txt'); Mode = 'edit'; Leave = 'leave' })
    if ($Only) { $cases = $cases | Where-Object { $Only -contains $_.N } }
    foreach ($c in $cases) { Run-Case $c }
}
catch { Out ('FATAL: ' + $_.Exception.Message) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 500
    $restored = Restore-TcRegistry $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if ($restored -and (Test-Path -LiteralPath $backupDir)) { Remove-Item -LiteralPath $backupDir -Recurse -Force }
    try { if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) } } catch { Out ("Fixture : could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    Out ''
    Out '=== summary ==='
    Out ('{0,-7} {1,-4} {2,-11} {3,-8} {4,-5} {5,-10} {6,-10} {7,-10} {8,-10} {9}' -f 'case', 'fmt', 'mode', 'editRan', 'info', 'updateDlg', 'archive', 'tmp@leave', 'tmp@exit', 'name / other')
    foreach ($t in $script:Table) {
        $nm = $t.Name; if ($nm.Length -gt 60) { $nm = $nm.Substring(0, 30) + '...(' + $nm.Length + ' chars escaped)' }
        Out ('{0,-7} {1,-4} {2,-11} {3,-8} {4,-5} {5,-10} {6,-10} {7,-10} {8,-10} {9} {10}' -f $t.Case, $t.Fmt, $t.Mode, $t.EditRan, $t.Info, $t.UpdateDlg, $t.Archive, $t.TmpAfterLeave, $t.TmpAfterExit, $nm, $(if ($t.Other) { '| ' + $t.Other } else { '' }))
    }
    Out ("Left running: {0}; fixture removed: {1}; registry restored+identical: {2}" -f $leftover.Count, (-not [IO.Directory]::Exists($Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit 0
