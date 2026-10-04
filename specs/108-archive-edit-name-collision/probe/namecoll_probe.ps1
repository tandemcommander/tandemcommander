<#
.SYNOPSIS
    Feature 108 probe: two members of ONE archive whose names collide - in the
    code-page byte fold, in case, in UTF-8 length, in Unicode normalization - are
    edited (F4) and the archive is left. Does each member get its own edit, and
    no other member get lost?

.DESCRIPTION
    One instance of -Exe per case. The archive (ZIP written by python's zipfile,
    7z written by 7z.exe + "7z rn", see arcfix.py) holds the members of the case;
    member i holds "content-of-member-<i>". Steps, driven by window messages on
    the hidden desktop:
      End, Enter (into the archive) [Home, Down, Enter into the inner folder]
      for every edit: Home, Down x position; CM_EDIT (743)
        the F4 editor is configured (inside the registry backup/restore) as
            cmd.exe /c echo edited108>>"$(FullName)"
        the new %TEMP%\SAL*.tmp files are listed (name, member tag, markers)
      leave: Backspace out of the archive; every window is recorded and answered
      OK / Yes (Archive Update: Update; Confirm File Overwrite: Yes)
      the program is closed, the archive is read back by arcfix.py (zipfile / 7z.exe)
    Verdicts (per case kind):
      both    : every original member present once, its own content, exactly one marker
      one     : the edited member has its content and one marker, the other one is intact
      refused : both F4 refused with a message, the archive unchanged
      same    : the one member edited twice through one temporary copy: two markers
      typed   : the member opened through two spellings of its folder (Change Directory
                to <arc>\DIR, then Enter on the listed "Dir"): one entry, both edits
    -CacheKeyRows runs only the rows of a finding recorded by feature 108 and NOT fixed by it
    (the disk-cache key of an ARCHIVE is its code-page lower-cased name):
      twoarc  : two archives whose NAMES fold together (<h-circumflex>.zip, <L-acute>.zip), each with
                x.txt of its own content; F4 on x.txt of the first in the left panel, F4 on x.txt
                of the second in the right panel, both left and updated: each archive must keep
                its own x.txt with one edit
    Helper block copied from specs/096-archive-edit-accented/probe/archedit_probe.ps1
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
    [switch]$CacheKeyRows,
    [string]$Python = 'python',
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

# ---- helper block of specs/094-plugin-password-encoding/probe/zip_gui_probe.ps1 (copied, unchanged) ----
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
$script:Lines = New-Object System.Collections.ArrayList
$script:Retries = 0

function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
function Esc([string]$s) {   # ASCII-safe rendering
    if ($null -eq $s) { return '<null>' }
    $sb = New-Object Text.StringBuilder
    foreach ($c in $s.ToCharArray()) { if ([int]$c -ge 32 -and [int]$c -lt 127) { [void]$sb.Append($c) } else { [void]$sb.AppendFormat('\u{0:X4}', [int]$c) } }
    return $sb.ToString()
}
function Out([string]$line) { Write-Host $line; [void]$script:Lines.Add($line) }

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
$SystemClasses = @('UAC_InputIndicatorOverlayWnd', 'UAC Input Indicator')
function Get-Tops([int]$Id) { return @([Drv093]::Top([uint32]$Id) | Where-Object { $SystemClasses -notcontains [Drv093]::Cls($_) }) }
function Get-Main([int]$Id) {
    foreach ($h in [Drv093]::Top([uint32]$Id)) { if ([Drv093]::Cls($h) -eq $MainClass) { return $h } }
    return [IntPtr]::Zero
}
function Get-DialogText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv093]::Kids($H)) {
        $t = [Drv093]::Txt($c)
        if ($t -and [Drv093]::IsWindowVisible($c)) { $parts += ("[{0} id={1}] {2}" -f [Drv093]::Cls($c), [Drv093]::GetDlgCtrlID($c), (Esc ($t -replace '\s+', ' '))) }
    }
    $r = ($parts -join ' | ')
    if ($r.Length -gt 500) { $r = $r.Substring(0, 500) + '...' }
    return $r
}
function Post-Cmd([IntPtr]$H, [int]$C) { [void][Drv093]::PostMessageW($H, 0x0111, [IntPtr]$C, [IntPtr]::Zero) }
function Close-Win([int]$Id, [IntPtr]$H) {
    if (-not [Drv093]::IsWindow($H)) { return }
    if ([Drv093]::PidOf($H) -ne [uint32]$Id) { throw 'window does not belong to the test process' }
    Post-Cmd $H 2
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv093]::IsWindow($H) -and [Drv093]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
    if ([Drv093]::IsWindow($H) -and [Drv093]::IsWindowVisible($H)) {
        [void][Drv093]::PostMessageW($H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw.Restart()
        while ($sw.Elapsed.TotalSeconds -lt 3 -and [Drv093]::IsWindow($H) -and [Drv093]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
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
function Open-ByCmd([int]$Id, [int]$C, [double]$Seconds = 8) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) $C
    return (Wait-NewWin $Id $known $Seconds)
}
if (-not ('Rect108' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Rect108
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    public static int Left(IntPtr h) { RECT r; GetWindowRect(h, out r); return r.L; }
}
'@
}
# the panel list windows, left to right on the screen
function Get-Lists([int]$Id) {
    $m = Get-Main $Id
    return @([Drv093]::Kids($m) | Where-Object { [Drv093]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv093]::IsWindowVisible($_) } | Sort-Object { [Rect108]::Left($_) })
}
function KeyP([int]$Id, [int]$Panel, [int]$Vk) {
    $l = (Get-Lists $Id)[$Panel]
    [void][Drv093]::Send($l, 0x0100, $Vk, 1, 20000)
    [void][Drv093]::Send($l, 0x0101, $Vk, 0xC0000001, 20000)
}
function PostKeyP([int]$Id, [int]$Panel, [int]$Vk) {
    $l = (Get-Lists $Id)[$Panel]
    [void][Drv093]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv093]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L)
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
function PostKey([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv093]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv093]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L)
}
function Title([int]$Id) { return [Drv093]::Txt((Get-Main $Id)) }
function Find-Ctl([IntPtr]$Dlg, [int]$CtlId) {
    $c = @([Drv093]::Kids($Dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq $CtlId -and @('ComboBox', 'Edit') -contains [Drv093]::Cls($_) })
    $v = @($c | Where-Object { [Drv093]::IsWindowVisible($_) })
    if ($v.Count) { return $v[0] }
    if ($c.Count) { return $c[0] }
    return [IntPtr]::Zero
}
function Click-Ok([IntPtr]$Dlg) {
    $ok = [Drv093]::Kids($Dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 1 -and [Drv093]::Cls($_) -eq 'Button' } | Select-Object -First 1
    if ($ok) { [void][Drv093]::PostMessageW($ok, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv093]::IsWindow($Dlg) -and [Drv093]::IsWindowEnabled($Dlg)) { Start-Sleep -Milliseconds 50 }
    if ([Drv093]::IsWindow($Dlg) -and [Drv093]::IsWindowEnabled($Dlg)) { Post-Cmd $Dlg 1 }
}
function Buttons([IntPtr]$H) { return @([Drv093]::Kids($H) | Where-Object { [Drv093]::Cls($_) -eq 'Button' -and [Drv093]::IsWindowVisible($_) }) }
function Click([IntPtr]$Btn) { [void][Drv093]::PostMessageW($Btn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
function Tail([string]$s, [int]$n = 60) { if ($s.Length -le $n) { return (Esc $s) }; return ('...' + (Esc $s.Substring($s.Length - $n))) }
function WinDesc([IntPtr]$H) { return ("[{0} '{1}'] {2}" -f [Drv093]::Cls($H), (Tail ([Drv093]::Txt($H)) 70), (Get-DialogText $H)) }
$FatalRx = 'Run-Time Check|Debug Error|Assertion|Runtime Library|Stack around|bug report|abnormal|has stopped|Unhandled exception|buffer overrun'
function Is-Fatal([string]$Desc) { return ($Desc -match $FatalRx) }

# feature 101: lets the instance go idle (the F4 command enabler is refreshed in the idle pass)
function Settle([int]$Id, [int]$Ms) {
    $m = Get-Main $Id
    if ($m -eq [IntPtr]::Zero) { return }
    [void][Drv093]::Send($m, 0, 0, 0, 20000)
    Start-Sleep -Milliseconds $Ms
    [void][Drv093]::Send($m, 0, 0, 0, 20000)
}

# Serves the instance's windows until it is idle (no window but the main one for
# 1.5 s). Each window kept 0.6 s is recorded and answered (OK/Yes, or No for the
# leftover-temp-dirs question, or Ignore All after a failed pack).
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
            $want = @(1, 6)
            if ($d -match 'temporary director') { $want = @(4) }
            elseif ($d -match 'Packing of updated file') { $want = @(7); $packFailed = $true }
            elseif ($packFailed -and [Drv093]::Txt($h) -eq 'Archive Update') { $want = @(2) }
            $pick = $btn | Where-Object { $want -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($pick) { Click $pick } else { Close-Win $Id $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function MsgText($r) { if ($r.Messages.Count) { return (($r.Messages | ForEach-Object { if ($_.Length -gt 420) { $_.Substring(0, 420) + '...' } else { $_ } }) -join ' || ') } else { return 'no window' } }

function Start-Tc108([string]$Dir) {
    $a = @('-t', 'T108', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $TempRoot), '-p', '1')
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
# Change Directory (command 862): the text goes into the field (id 210) with a wide WM_SETTEXT; OK
function Do-ChangeDir([int]$Id, [string]$Text) {
    $dlg = Open-ByCmd $Id 862
    if ($dlg -eq [IntPtr]::Zero) { throw 'Change Directory (command 862) opened no window' }
    $ctl = Find-Ctl $dlg 210
    if ($ctl -eq [IntPtr]::Zero) { throw 'the path field (id 210) was not found' }
    [void][Drv093]::SetText($ctl, $Text, 5000)
    $held = [Drv093]::GetText($ctl, 5000)
    Click-Ok $dlg
    Start-Sleep -Milliseconds 1200
    return ($held -ceq $Text)
}

# ---- this probe ----------------------------------------------------------------
$Utf8 = New-Object Text.UTF8Encoding($false)
$TempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$Root = $TempRoot + '\tc108\nc'
$ReportDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$Marker = 'edited108'
$ArcFix = Join-Path $PSScriptRoot 'arcfix.py'

function Set-ProbeConfig {
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    $fresh = ($LASTEXITCODE -ne 0)
    if (-not $fresh) {
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Archive' /t REG_DWORD /d 1 /f | Out-Null
        & cmd.exe /c "reg delete `"$RegKey\0.1\Editors`" /f >nul 2>&1"
        $k = "$RegKey\0.1\Editors\1"
        & reg.exe add $k /v 'Masks' /t REG_SZ /d '*.*' /f | Out-Null
        & reg.exe add $k /v 'Command' /t REG_SZ /d (Join-Path $env:SystemRoot 'System32\cmd.exe') /f | Out-Null
        Set-ItemProperty -LiteralPath ('Registry::' + $k.Replace('HKCU\', 'HKEY_CURRENT_USER\')) -Name 'Arguments' -Value ('/c echo ' + $Marker + '>>"$(FullName)"')
        & reg.exe add $k /v 'Initial Directory' /t REG_SZ /d (Join-Path $env:SystemRoot 'System32') /f | Out-Null
    }
    return $fresh
}

function Invoke-ArcFix([string]$Verb, [string]$Arc, [string]$Fmt, [string[]]$Members, [int]$First = 1) {
    $spec = Join-Path $Root 'spec.json'
    $json = '{"arc": ' + (ConvertTo-Json $Arc) + ', "fmt": "' + $Fmt + '", "first": ' + $First + ', "sevenzip": ' + (ConvertTo-Json $SevenZip) +
            ', "members": [' + ((@($Members) | ForEach-Object { ConvertTo-Json $_ }) -join ', ') + ']}'
    [IO.File]::WriteAllText($spec, $json, $Utf8)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    if ($Verb -eq 'make') { $o = & $Python $ArcFix make $spec 2>&1 } else { $o = & $Python $ArcFix read $spec $Marker 2>&1 }
    $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ("arcfix.py $Verb failed: " + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return @($o | ForEach-Object { "$_" })
}

# files in new SAL*.tmp folders: folder, name, member tag, marker count, size
function Find-Tmp($Before) {
    $r = @()
    foreach ($d in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp'))) {
        if ($Before -contains $d) { continue }
        try {
            foreach ($f in [IO.Directory]::GetFiles($d, '*', [IO.SearchOption]::AllDirectories)) {
                $b = $null; try { $b = [IO.File]::ReadAllBytes($f) } catch { }
                $t = $(if ($b) { [Text.Encoding]::GetEncoding(28591).GetString($b) } else { '' })
                $m = [regex]::Match($t, 'content-of-member-(\d+)')
                $r += [pscustomobject]@{ Dir = [IO.Path]::GetFileName($d); Name = [IO.Path]::GetFileName($f)
                    Tag = $(if ($m.Success) { $m.Groups[1].Value } else { '?' }); Count = ([regex]::Matches($t, $Marker)).Count; Size = $(if ($b) { $b.Length } else { -1 }) }
            }
        }
        catch { }
    }
    return , $r
}
function TmpDesc($l) { if (-not $l -or -not $l.Count) { return 'none' }; return (($l | ForEach-Object { "{0}\{1} (tag {2}, marker x{3}, {4} bytes)" -f $_.Dir, (Esc $_.Name), $_.Tag, $_.Count, $_.Size }) -join '; ') }
function MarkerSum($l) { $s = 0; foreach ($x in @($l)) { $s += $x.Count }; return $s }

$script:Table = New-Object System.Collections.ArrayList
function Run-Case($c) {
    $N = $c.N; $fmt = $c.Fmt
    $dir = $Root + '\' + $N
    [void][IO.Directory]::CreateDirectory($dir)
    $arc = $dir + '\arc.' + $fmt
    $members = @($c.Members | ForEach-Object { if ($c.Dir) { $c.Dir + '/' + $_ } else { $_ } })
    [void](Invoke-ArcFix 'make' $arc $fmt $members)
    $tmpBefore = @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp'))
    $before = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    Out ''
    Out ("--- {0}: {1} [{2}] members {3}; edits at panel positions {4}" -f $N, $fmt, $c.Kind, ((@($members) | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', '), ((@($c.Edits) | ForEach-Object { "$_" }) -join ','))
    $row = [ordered]@{ Case = $N; Fmt = $fmt; Kind = $c.Kind; Verdict = 'NOT DRIVEN'; Archive = '-'; Tmp = '-'; Msgs = ''; Why = '' }
    $id = 0
    $editMsgs = @(); $leaveMsgs = ''
    try {
        $id = Start-Tc108 $dir
        $r0 = Serve $id 6
        if ($r0.Messages.Count) { Out ('   at start: ' + (MsgText $r0)) }
        $title0 = Title $id
        if ($c.Kind -eq 'typed') {
            # into the archive by a typed path whose folder differs in case from the stored "Dir"
            $ok = Do-ChangeDir $id ($arc + '\DIR')
            $r = Serve $id 30
            if ((Title $id) -eq $title0) { throw ("Change Directory did not enter the archive: '" + (Tail (Title $id) 50) + "' " + (MsgText $r)) }
            Out ("   in the archive by the typed path '...\arc.{0}\DIR' (field held the text: {1}); title '{2}'" -f $fmt, $ok, (Tail (Title $id) 40))
        }
        else {
            Key $id 0x23; PostKey $id 0x0D; Start-Sleep -Milliseconds 1200
            $r = Serve $id 30
            if ((Title $id) -notmatch 'arc\.') { throw ("not inside the archive: title '" + (Tail (Title $id) 50) + "' windows: " + (MsgText $r)) }
            if ($c.Dir) {
                $t1 = Title $id
                Key $id 0x24; Key $id 0x28; PostKey $id 0x0D; Start-Sleep -Milliseconds 1200
                $r = Serve $id 20
                if ((Title $id) -eq $t1) { throw 'did not enter the inner folder' }
            }
        }
        $step = 0
        foreach ($pos in @($c.Edits)) {
            $step++
            if ($c.Kind -eq 'typed' -and $step -eq 2) {
                # back to the archive root, then Enter on the listed "Dir" (the stored spelling)
                $tA = Title $id
                PostKey $id 0x08; Start-Sleep -Milliseconds 1000
                $r = Serve $id 20
                Key $id 0x24; Key $id 0x28; PostKey $id 0x0D; Start-Sleep -Milliseconds 1200
                $r = Serve $id 20
                Out ("   then by the listed folder: title '{0}' (before '{1}')" -f (Tail (Title $id) 40), (Tail $tA 40))
            }
            $sumBefore = MarkerSum (Find-Tmp $tmpBefore)
            $script:Retry = ''
            function Focus-And-Edit([int]$Wait) {
                Key $id 0x24
                for ($k = 0; $k -lt $pos; $k++) { Key $id 0x28 }
                Settle $id $Wait
                Post-Cmd (Get-Main $id) 743
            }
            function Wait-Edit([double]$Seconds) {
                $sw = [Diagnostics.Stopwatch]::StartNew()
                while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
                    if ((MarkerSum (Find-Tmp $tmpBefore)) -gt $sumBefore) { return $true }
                    if (@(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -ne $MainClass }).Count) { return $true }
                    Start-Sleep -Milliseconds 300
                }
                return $false
            }
            Focus-And-Edit 500
            if (-not (Wait-Edit 10)) {
                $script:Retry = 'F4 RETRY: the first post was not acted on (no edit, no window); posted again after a 1.5 s idle wait'
                Out ('   ' + $script:Retry); $script:Retries++
                Focus-And-Edit 1500
                [void](Wait-Edit 10)
            }
            Start-Sleep -Milliseconds 1500
            $r = Serve $id 20
            $tmp = Find-Tmp $tmpBefore
            $m = MsgText $r
            Out ("   EDIT {0} (position {1}): temporary copies now: {2}; windows: {3}" -f $step, $pos, (TmpDesc $tmp), $m)
            if ($r.Messages.Count) { $editMsgs += ("edit {0}: {1}" -f $step, $m) }
            if ($r.Fatal) { throw ('FATAL window at edit: ' + $m) }
        }
        $row.Tmp = TmpDesc (Find-Tmp $tmpBefore)
        Start-Sleep -Milliseconds 1000
        PostKey $id 0x08; Start-Sleep -Milliseconds 1000
        if ($c.Dir -or $c.Kind -eq 'typed') { PostKey $id 0x08; Start-Sleep -Milliseconds 1000 }
        $r = Serve $id 60
        $leaveMsgs = MsgText $r
        $left = ((Title $id) -eq $title0)
        Out ("   LEAVE: left the archive {0}; windows: {1}" -f $left, $leaveMsgs)
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
        $new = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Where-Object { $before -notcontains $_ })
        foreach ($n in $new) { Remove-Item -LiteralPath (Join-Path $ReportDir $n) -Force -ErrorAction SilentlyContinue }
        $read = Invoke-ArcFix 'read' $arc $fmt $members
        Out ("   END  : exit code {0}; new crash reports {1}; archive read back:" -f $ec, $new.Count)
        foreach ($l in $read) { Out ('          ' + $l) }
        # ---- verdict
        $entries = @($read | Where-Object { $_ -like 'ENTRY *' } | ForEach-Object {
                $mm = [regex]::Match($_, '^ENTRY (.*) tag=(\S+) markers=(\d+) size=(\d+)$')
                [pscustomobject]@{ Name = $mm.Groups[1].Value; Tag = $mm.Groups[2].Value; Markers = [int]$mm.Groups[3].Value } })
        $row.Archive = (($entries | ForEach-Object { "{0}=m{1}+{2}" -f $_.Name, $_.Tag, $_.Markers }) -join ' ')
        $why = @()
        $byName = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)   # names differ in case
        foreach ($e in $entries) { if ($byName.ContainsKey($e.Name)) { $why += ('duplicate entry ' + $e.Name) } else { $byName[$e.Name] = $e } }
        for ($i = 0; $i -lt $members.Count; $i++) {
            $en = Esc $members[$i]
            if (-not $byName.ContainsKey($en)) { $why += ("member {0} '{1}' MISSING" -f ($i + 1), $en); continue }
            $e = $byName[$en]
            if ($e.Tag -ne [string]($i + 1)) { $why += ("member {0} '{1}' holds the content of member {2}" -f ($i + 1), $en, $e.Tag) }
        }
        if ($entries.Count -ne $members.Count) { $why += ("{0} entries, expected {1}" -f $entries.Count, $members.Count) }
        $marks = @($members | ForEach-Object { $en = Esc $_; if ($byName.ContainsKey($en)) { $byName[$en].Markers } else { -1 } })
        switch ($c.Kind) {
            'both' { for ($i = 0; $i -lt $marks.Count; $i++) { if ($marks[$i] -ne 1) { $why += ("member {0}: {1} edits (expected 1)" -f ($i + 1), $marks[$i]) } } }
            'one' {
                $ones = @($marks | Where-Object { $_ -eq 1 }).Count; $zeros = @($marks | Where-Object { $_ -eq 0 }).Count
                if ($ones -ne 1 -or $zeros -ne ($marks.Count - 1)) { $why += ('edits per member ' + ($marks -join '/') + ' (expected one 1, others 0)') }
            }
            'refused' {
                if (@($marks | Where-Object { $_ -ne 0 }).Count) { $why += ('edits per member ' + ($marks -join '/') + ' (expected none)') }
                if (@($editMsgs | Where-Object { $_ -match 'more than one file' }).Count -lt @($c.Edits).Count) { $why += 'F4 not refused with a message every time' }
            }
            'same' { if ($marks[0] -ne 2) { $why += ("the member has {0} edits (expected 2)" -f $marks[0]) } }
            'typed' { if ($marks[0] -ne 2) { $why += ("the member has {0} edits (expected 2: both opened the one member)" -f $marks[0]) } }
            'single' { if ($marks[0] -ne 1) { $why += ("the member has {0} edits (expected 1)" -f $marks[0]) } }
        }
        if ($new.Count) { $why += "$($new.Count) crash report(s)" }
        $row.Verdict = $(if ($why.Count) { 'FAIL' } else { 'PASS' })
        $row.Why = ($why -join '; ')
        $row.Msgs = ((@($editMsgs) + @('leave: ' + $leaveMsgs)) -join ' || ')
        Out ("   VERDICT: {0} {1}" -f $row.Verdict, $row.Why)
    }
    catch {
        Out ('   exception: ' + $_.Exception.Message); $row.Why = 'NOT DRIVEN: ' + $_.Exception.Message
    }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        Start-Sleep -Milliseconds 300
        foreach ($t in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp') | Where-Object { $tmpBefore -notcontains $_ })) {
            Out ("   left in the temp folder by the test instance, removed: {0}" -f [IO.Path]::GetFileName($t))
            try { [IO.Directory]::Delete($t, $true) } catch { }
        }
        [void]$script:Table.Add([pscustomobject]$row)
    }
}

# feature 108 finding (not fixed): two archives whose names fold together share the disk-cache key
function Run-TwoArc($c) {
    $N = $c.N; $fmt = $c.Fmt
    $dir = $Root + '\' + $N
    [void][IO.Directory]::CreateDirectory($dir)
    $arcs = @(($dir + '\' + $c.Arcs[0] + '.' + $fmt), ($dir + '\' + $c.Arcs[1] + '.' + $fmt))
    [void](Invoke-ArcFix 'make' $arcs[0] $fmt @('x.txt') 1)
    [void](Invoke-ArcFix 'make' $arcs[1] $fmt @('x.txt') 2)
    $tmpBefore = @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp'))
    $before = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    Out ''
    Out ("--- {0}: {1} [{2}] archives {3}, each with x.txt (tags 1 / 2); F4 in the left panel on the first listed archive's x.txt, in the right panel on the second's" -f $N, $fmt, $c.Kind, ((@($arcs) | ForEach-Object { "'" + (Esc ([IO.Path]::GetFileName($_))) + "'" }) -join ', '))
    $row = [ordered]@{ Case = $N; Fmt = $fmt; Kind = $c.Kind; Verdict = 'NOT DRIVEN'; Archive = '-'; Tmp = '-'; Msgs = ''; Why = '' }
    $id = 0
    try {
        $a = @('-t', 'T108', '-l', ('"{0}"' -f $dir), '-r', ('"{0}"' -f $dir), '-p', '1')
        $pr = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
        [void]$Started.Add($pr.Id); [void]$pr.Handle; $script:Procs[$pr.Id] = $pr
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $pr.Id) -and (Get-Main $pr.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $pr.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$pr.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 3000
        $id = $pr.Id
        $r0 = Serve $id 6
        if ($r0.Messages.Count) { Out ('   at start: ' + (MsgText $r0)) }
        if ((Get-Lists $id).Count -ne 2) { throw 'two panel lists not found' }
        $title0 = Title $id
        for ($panel = 0; $panel -lt 2; $panel++) {
            if ($panel -eq 1) { PostKeyP $id 0 0x09; Start-Sleep -Milliseconds 800; $r = Serve $id 10 }   # Tab: the right panel
            KeyP $id $panel 0x24
            for ($k = 0; $k -le $panel; $k++) { KeyP $id $panel 0x28 }
            PostKeyP $id $panel 0x0D; Start-Sleep -Milliseconds 1200
            $r = Serve $id 30
            $tIn = Title $id
            if ($tIn -eq $title0) { throw ("panel {0} did not enter the archive" -f $panel) }
            $sumBefore = MarkerSum (Find-Tmp $tmpBefore)
            KeyP $id $panel 0x24; KeyP $id $panel 0x28
            Settle $id 800
            Post-Cmd (Get-Main $id) 743
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 10 -and (MarkerSum (Find-Tmp $tmpBefore)) -le $sumBefore) { Start-Sleep -Milliseconds 300 }
            Start-Sleep -Milliseconds 1500
            $r = Serve $id 20
            Out ("   EDIT in panel {0} (title '{1}'): temporary copies now: {2}; windows: {3}" -f $panel, (Tail $tIn 30), (TmpDesc (Find-Tmp $tmpBefore)), (MsgText $r))
        }
        $row.Tmp = TmpDesc (Find-Tmp $tmpBefore)
        $leave = @()
        foreach ($panel in @(1, 0)) {
            if ($panel -eq 0) { PostKeyP $id 1 0x09; Start-Sleep -Milliseconds 800; $r = Serve $id 10 }
            PostKeyP $id $panel 0x08; Start-Sleep -Milliseconds 1000
            $r = Serve $id 60
            $leave += ("panel {0}: {1}" -f $panel, (MsgText $r))
            Out ("   LEAVE panel {0}: windows: {1}" -f $panel, (MsgText $r))
        }
        [void][Drv093]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $id)) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -eq '#32770' })) { $d = WinDesc $h; if ($d -notmatch 'monitored handles') { Out ('   at exit: ' + $d) }; $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
            Start-Sleep -Milliseconds 200
        }
        if (Test-Alive $id) { Kill-Mine $id; Out '   END  : did not exit in 30 s - ended by the probe' }
        Start-Sleep -Milliseconds 700
        $new = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Where-Object { $before -notcontains $_ })
        foreach ($n in $new) { Remove-Item -LiteralPath (Join-Path $ReportDir $n) -Force -ErrorAction SilentlyContinue }
        $why = @(); $desc = @()
        for ($i = 0; $i -lt 2; $i++) {
            $read = Invoke-ArcFix 'read' $arcs[$i] $fmt @('x.txt')
            foreach ($l in $read) { Out ("          {0}: {1}" -f (Esc ([IO.Path]::GetFileName($arcs[$i]))), $l) }
            $e = @($read | Where-Object { $_ -like 'ENTRY *' } | ForEach-Object { $mm = [regex]::Match($_, '^ENTRY (.*) tag=(\S+) markers=(\d+) size=(\d+)$'); [pscustomobject]@{ Tag = $mm.Groups[2].Value; Markers = [int]$mm.Groups[3].Value } })
            $nm = Esc ([IO.Path]::GetFileName($arcs[$i]))
            if ($e.Count -ne 1) { $why += ("{0}: {1} entries" -f $nm, $e.Count); continue }
            $desc += ("{0}:x.txt=m{1}+{2}" -f $nm, $e[0].Tag, $e[0].Markers)
            if ($e[0].Tag -ne [string]($i + 1)) { $why += ("{0}: x.txt holds the content of the OTHER archive's x.txt" -f $nm) }
        }
        $total = 0; foreach ($d in $desc) { $total += [int]($d -replace '^.*\+', '') }
        if ($total -ne 2) { $why += ("{0} edits in the two archives (expected 1 + 1)" -f $total) }
        if ($new.Count) { $why += "$($new.Count) crash report(s)" }
        $row.Archive = ($desc -join ' ')
        $row.Verdict = $(if ($why.Count) { 'FAIL' } else { 'PASS' })
        $row.Why = ($why -join '; ')
        $row.Msgs = ($leave -join ' || ')
        Out ("   VERDICT: {0} {1}" -f $row.Verdict, $row.Why)
    }
    catch { Out ('   exception: ' + $_.Exception.Message); $row.Why = 'NOT DRIVEN: ' + $_.Exception.Message }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        Start-Sleep -Milliseconds 300
        foreach ($t in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp') | Where-Object { $tmpBefore -notcontains $_ })) {
            Out ("   left in the temp folder by the test instance, removed: {0}" -f [IO.Path]::GetFileName($t))
            try { [IO.Directory]::Delete($t, $true) } catch { }
        }
        [void]$script:Table.Add([pscustomobject]$row)
    }
}

# ---- main ---------------------------------------------------------------------
$backupDir = $TempRoot + '\tc108\reg'
[void][IO.Directory]::CreateDirectory($backupDir)
$backup = Join-Path $backupDir 'backup.reg'
$existed = Backup-TcRegistry $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $fresh = Set-ProbeConfig
    Out ("namecoll_probe (feature 108) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv093]::GetACP())
    Out ("Config  : registry key existed {0}; fresh defaults {1}; F4 editor = cmd.exe /c echo {2}>>`"`$(FullName)`"" -f $existed, $fresh, $Marker)
    if ($fresh) { throw 'no stored configuration - the F4 editor cannot be configured' }
    $hc = [string][char]0x0125; $Lac = [string][char]0x0139            # h-circumflex / L-acute: C4 A5 / C4 B9
    $Ia = [string][char]0x00CD; $Ya = [string][char]0x00DD             # I-acute / Y-acute: C3 8D / C3 9D (Czech)
    $zc = [string][char]0x017E; $zd = [string][char]0x017C             # z-caron / z-dot: C5 BE / C5 BC
    $nine = [string][char]0x4E5D; $zha = [string][char]0x4E4D          # two CJK ideographs: E4 B9 9D / E4 B9 8D
    $em = [string][char]0x043C; $o = [string][char]0x043E              # Cyrillic em / o: D0 BC / D0 BE
    $CcUp = [string][char]0x010C; $CcLow = [string][char]0x010D        # C-caron / c-caron (case pair; PowerShell names are case-insensitive)
    $AbUp = [string][char]0x023A; $AbLow = [string][char]0x2C65        # A-stroke (2 bytes) / a-stroke (3 bytes) (case pair)
    $eNfc = [string][char]0x00E9; $eNfd = 'e' + [char]0x0301           # NFC / NFD
    $cl = [string][char]0x010D + 'l' + [char]0x00E1 + 'nek.txt'
    $kinds = @(
        @{ N = 'hL'; Kind = 'both'; Members = @(($hc + '.txt'), ($Lac + '.txt')); Edits = @(1, 2) },
        @{ N = 'IY'; Kind = 'both'; Members = @(($Ia + 'tem.txt'), ($Ya + 'tem.txt')); Edits = @(1, 2) },
        @{ N = 'zz'; Kind = 'both'; Members = @(($zc + '.txt'), ($zd + '.txt')); Edits = @(1, 2) },
        @{ N = 'cjk'; Kind = 'both'; Members = @(($nine + '.txt'), ($zha + '.txt')); Edits = @(1, 2) },
        @{ N = 'cyr'; Kind = 'both'; Members = @(($em + '.txt'), ($o + '.txt')); Edits = @(1, 2) },
        @{ N = 'hLsub'; Kind = 'both'; Dir = ('slo' + $zc + 'ka'); Members = @(($hc + '.txt'), ($Lac + '.txt')); Edits = @(1, 2) },
        @{ N = 'hL1'; Kind = 'one'; Members = @(($hc + '.txt'), ($Lac + '.txt')); Edits = @(1) },
        @{ N = 'hL2'; Kind = 'one'; Members = @(($hc + '.txt'), ($Lac + '.txt')); Edits = @(2) },
        @{ N = 'nfc'; Kind = 'both'; Members = @(($eNfc + '.txt'), ($eNfd + '.txt')); Edits = @(1, 2) },
        @{ N = 'Cc'; Kind = 'refused'; Members = @(($CcUp + '.txt'), ($CcLow + '.txt')); Edits = @(1, 2) },
        @{ N = 'Aa'; Kind = 'refused'; Members = @('A.txt', 'a.txt'); Edits = @(1, 2) },
        @{ N = 'len'; Kind = 'refused'; Members = @(($AbUp + '.txt'), ($AbLow + '.txt')); Edits = @(1, 2) },
        @{ N = 'same'; Kind = 'same'; Members = @(($hc + '.txt')); Edits = @(1, 1) },
        @{ N = 'typed'; Kind = 'typed'; Members = @('Dir/x.txt'); Edits = @(1, 1) },
        @{ N = 'single'; Kind = 'single'; Members = @($cl); Edits = @(1) })
    $cases = @()
    foreach ($k in $kinds) {
        foreach ($f in @('zip', '7z')) {
            $c = @{}; foreach ($key in $k.Keys) { $c[$key] = $k[$key] }
            $c.N = $k.N + '_' + $f; $c.Fmt = $f
            $cases += $c
        }
    }
    if ($CacheKeyRows) {
        $cases = @()
        foreach ($f in @('zip', '7z')) { $cases += @{ N = ('twoarc_' + $f); Fmt = $f; Kind = 'twoarc'; Arcs = @($hc, $Lac) } }
    }
    if ($Only) { $cases = $cases | Where-Object { $Only -contains $_.N } }
    foreach ($c in $cases) { if ($c.Kind -eq 'twoarc') { Run-TwoArc $c } else { Run-Case $c } }
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
    Out ('{0,-12} {1,-4} {2,-8} {3,-10} {4}' -f 'case', 'fmt', 'kind', 'verdict', 'archive (name=member tag+edits) | why')
    foreach ($t in $script:Table) {
        Out ('{0,-12} {1,-4} {2,-8} {3,-10} {4}{5}' -f $t.Case, $t.Fmt, $t.Kind, $t.Verdict, $t.Archive, $(if ($t.Why) { ' | ' + $t.Why } else { '' }))
    }
    $nPass = @($script:Table | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nFail = @($script:Table | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nNd = @($script:Table | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ("TOTAL: {0} PASS / {1} FAIL / {2} NOT DRIVEN; F4 retries {3}" -f $nPass, $nFail, $nNd, $script:Retries)
    Out ("Left running: {0}; fixture removed: {1}; registry restored+identical: {2}" -f $leftover.Count, (-not [IO.Directory]::Exists($Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit 0
