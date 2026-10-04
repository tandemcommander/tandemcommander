<#
.SYNOPSIS
    Feature 109 probe: the disk cache keys an ARCHIVE by its name. Two archives
    whose names fold together in the code page must never share their members'
    temporary copies; one archive reached through two spellings should share
    them (or at least never let two copies of one member diverge).

.DESCRIPTION
    One instance of -Exe per case, both panels start in the case's folder. The
    archives (ZIP by python's zipfile, 7z by 7z.exe - specs/108-.../probe/arcfix.py)
    hold x.txt with "content-of-member-<tag>". Steps, driven by window messages
    on the hidden desktop, each in a given panel (Tab switches panels):
      cd    : Change Directory (command 862) to a path: the archive under some spelling
      f4    : Home, Down (x.txt), CM_EDIT (743); the F4 editor (inside the registry
              backup/restore) is   cmd.exe /c echo edited109>>"$(FullName)"
      f3    : Home, Down, CM_VIEW (742); the viewer for *.* is external:
              cmd.exe /c type "$(FullName)">>"%TEMP%\tc109\view.log"   - the probe reads
              what each F3 was given (member tag, edit markers)
      leave : Backspace out of the archive; every window is recorded and answered
              OK / Yes (Archive Update: Update; Confirm File Overwrite: Yes)
    After every step the files in new %TEMP%\SAL*.tmp folders are listed (folder,
    name, tag, markers, creation time). At the end the program is closed and every
    archive is read back by arcfix.py (zipfile / 7z.exe).
    Rows:
      twoarcF4 : <h-circumflex>.<fmt> and <L-acute>.<fmt> (UTF-8 names whose bytes fold together
                 on CP1250), F4 x.txt in each (left / right panel), leave both: each archive
                 its own x.txt with one edit
      twoarcF3 : the same archives, F3 in each: the second F3 must be given the second
                 archive's x.txt
      twoarcF4F3 : F4 in the first, F3 in the second: the second F3 shows the second's x.txt
      alias-*  : ONE archive, F4 x.txt in the left panel through one spelling, in the right
                 panel through another (ASCII case - control; accented case; the 8.3 name;
                 a SUBST drive; \\localhost\C$), leave both: x.txt holds BOTH edits
      prefix   : p.zip.zip edited (F4) in the left panel, p.zip entered and left in the
                 right panel, F4 x.txt again in the left panel: both edits packed (the cache
                 flushed every key that merely STARTS with the left archive's name)
      stale-*  : both panels on one archive (the same path; a SUBST path), F3 in the left one, the
                 archive replaced from outside (x.txt tag 9): F3 in either panel must give tag 9
      resubst / renet : a SUBST letter / a net use drive on folder A, the right panel opens the archive
                 through it, the left one through A (the same file - one key), F3 in the left; the right
                 leaves, the letter is re-pointed to folder B, the right opens <letter>:\arc.zip (another
                 file): F3 must give B's x.txt and its F4 edit must reach B\arc.zip only
      reuse    : F3 twice in one panel = one copy, not extracted again; F3 in the other
                 panel on the same archive (same spelling) = the same copy; leaving one panel
                 keeps it, leaving the other removes it
    Helper block copied from specs/108-archive-edit-name-collision/probe/namecoll_probe.ps1
    (itself from 094/096). MUST be started through tools\run_on_hidden_desktop.ps1.
    Refuses to run while a tandemcommander.exe other than -Exe is running.
    HKCU\Software\Tandem Commander is exported before, restored and verified after.
    Creates and removes a SUBST letter (first free of T, U, V, Q, R) for alias-subst.

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
$Root = $TempRoot + '\tc109\dc'
$ViewLog = $TempRoot + '\tc109\view.log'
$ReportDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$Marker = 'edited109'
$ArcFix = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\108-archive-edit-name-collision\probe\arcfix.py'))
$script:Subst = $null
$script:NetDrive = $null

function Set-ProbeConfig {
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    $fresh = ($LASTEXITCODE -ne 0)
    if (-not $fresh) {
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Archive' /t REG_DWORD /d 1 /f | Out-Null
        $cmd = Join-Path $env:SystemRoot 'System32\cmd.exe'
        $sys = Join-Path $env:SystemRoot 'System32'
        & cmd.exe /c "reg delete `"$RegKey\0.1\Editors`" /f >nul 2>&1"
        $k = "$RegKey\0.1\Editors\1"
        & reg.exe add $k /v 'Masks' /t REG_SZ /d '*.*' /f | Out-Null
        & reg.exe add $k /v 'Command' /t REG_SZ /d $cmd /f | Out-Null
        Set-ItemProperty -LiteralPath ('Registry::' + $k.Replace('HKCU\', 'HKEY_CURRENT_USER\')) -Name 'Arguments' -Value ('/c echo ' + $Marker + '>>"$(FullName)"')
        & reg.exe add $k /v 'Initial Directory' /t REG_SZ /d $sys /f | Out-Null
        & cmd.exe /c "reg delete `"$RegKey\0.1\Viewers`" /f >nul 2>&1"
        $v = "$RegKey\0.1\Viewers\1"
        & reg.exe add $v /v 'Masks' /t REG_SZ /d '*.*' /f | Out-Null
        & reg.exe add $v /v 'Type' /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add $v /v 'Command' /t REG_SZ /d $cmd /f | Out-Null
        Set-ItemProperty -LiteralPath ('Registry::' + $v.Replace('HKCU\', 'HKEY_CURRENT_USER\')) -Name 'Arguments' -Value ('/c type "$(FullName)">>"' + $ViewLog + '"')
        & reg.exe add $v /v 'Initial Directory' /t REG_SZ /d $sys /f | Out-Null
    }
    return $fresh
}

function Invoke-ArcFix([string]$Verb, [string]$Arc, [string]$Fmt, [string[]]$Members, [int]$First = 1) {
    $spec = $TempRoot + '\tc109\spec.json'
    $json = '{"arc": ' + (ConvertTo-Json $Arc) + ', "fmt": "' + $Fmt + '", "first": ' + $First + ', "sevenzip": ' + (ConvertTo-Json $SevenZip) +
            ', "members": [' + ((@($Members) | ForEach-Object { ConvertTo-Json $_ }) -join ', ') + ']}'
    [IO.File]::WriteAllText($spec, $json, $Utf8)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    if ($Verb -eq 'make') { $o = & $Python $ArcFix make $spec 2>&1 } else { $o = & $Python $ArcFix read $spec $Marker 2>&1 }
    $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    [IO.File]::Delete($spec)
    if ($rc -ne 0) { throw ("arcfix.py $Verb failed: " + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return @($o | ForEach-Object { "$_" })
}

# files in new SAL*.tmp folders: folder, name, member tag, marker count, size, creation time
function Find-Tmp($Before) {
    $r = @()
    foreach ($d in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp'))) {
        if ($Before -contains $d) { continue }
        try {
            foreach ($f in [IO.Directory]::GetFiles($d, '*', [IO.SearchOption]::AllDirectories)) {
                $b = $null; try { $b = [IO.File]::ReadAllBytes($f) } catch { }
                $t = $(if ($b) { [Text.Encoding]::GetEncoding(28591).GetString($b) } else { '' })
                $m = [regex]::Match($t, 'content-of-member-(\d+)')
                $fi = New-Object IO.FileInfo($f)
                $r += [pscustomobject]@{ Dir = [IO.Path]::GetFileName($d); Name = [IO.Path]::GetFileName($f)
                    Tag = $(if ($m.Success) { $m.Groups[1].Value } else { '?' }); Count = ([regex]::Matches($t, $Marker)).Count; Size = $(if ($b) { $b.Length } else { -1 })
                    Created = $fi.CreationTimeUtc.Ticks; Written = $fi.LastWriteTimeUtc.Ticks }
            }
        }
        catch { }
    }
    return , $r
}
function TmpDesc($l) { if (-not $l -or -not $l.Count) { return 'none' }; return (($l | ForEach-Object { "{0}\{1} (tag {2}, marker x{3}, {4} bytes)" -f $_.Dir, (Esc $_.Name), $_.Tag, $_.Count, $_.Size }) -join '; ') }
function TmpSig($l) { return ((@($l) | ForEach-Object { "{0}\{1}|{2}|{3}|{4}" -f $_.Dir, $_.Name, $_.Size, $_.Written, $_.Count }) -join ';') }
function ViewLen { if ([IO.File]::Exists($ViewLog)) { return (New-Object IO.FileInfo($ViewLog)).Length }; return 0 }
function ViewSince([long]$From) {
    if (-not [IO.File]::Exists($ViewLog)) { return '' }
    $b = [IO.File]::ReadAllBytes($ViewLog)
    if ($From -ge $b.Length) { return '' }
    return [Text.Encoding]::GetEncoding(28591).GetString($b, [int]$From, $b.Length - [int]$From)
}

# ---- spelling tokens: {DIR} the case folder, {UNC} its \\localhost\C$ form, {SUBST} a SUBST
# drive root mapped to it, {SFN:name} the 8.3 path of DIR\name. Returns $null (+ reason) when a
# spelling is not available on this machine.
function Resolve-Path109([string]$Text, [string]$Dir, [ref]$Why) {
    $t = $Text.Replace('{DIR}', $Dir)
    if ($t.Contains('{UNC}')) {
        if ($Dir -notmatch '^[A-Za-z]:\\') { $Why.Value = 'the folder is not on a drive letter'; return $null }
        $unc = '\\localhost\' + $Dir.Substring(0, 1) + '$\' + $Dir.Substring(3)
        if (-not [IO.Directory]::Exists($unc)) { $Why.Value = "$unc is not reachable"; return $null }
        $t = $t.Replace('{UNC}', $unc)
    }
    if ($t.Contains('{SUBST}')) {
        if (-not $script:Subst) {
            foreach ($l in @('T', 'U', 'V', 'Q', 'R')) {
                if ([IO.Directory]::Exists($l + ':\')) { continue }
                & subst.exe ($l + ':') $Dir | Out-Null
                if ($LASTEXITCODE -eq 0 -and [IO.Directory]::Exists($l + ':\')) { $script:Subst = $l + ':'; break }
            }
        }
        if (-not $script:Subst) { $Why.Value = 'no free SUBST letter'; return $null }
        $t = $t.Replace('{SUBST}', $script:Subst)
    }
    $m = [regex]::Match($t, '\{SUBST:([^}]+)\}')
    if ($m.Success) {
        if (-not (Set-Subst ($Dir + '\' + $m.Groups[1].Value))) { $Why.Value = 'no free SUBST letter'; return $null }
        $t = $t.Replace($m.Value, $script:Subst)
    }
    $m = [regex]::Match($t, '\{NET:([^}]+)\}')
    if ($m.Success) {
        if ($Dir -notmatch '^[A-Za-z]:\\') { $Why.Value = 'the folder is not on a drive letter'; return $null }
        if (-not (Set-NetDrive ($Dir + '\' + $m.Groups[1].Value))) { $Why.Value = 'no free letter for net use (W, Y, X) or \\localhost\C$ not reachable'; return $null }
        $t = $t.Replace($m.Value, $script:NetDrive)
    }
    $m = [regex]::Match($t, '\{SFN:([^}]+)\}')
    if ($m.Success) {
        $long = $Dir + '\' + $m.Groups[1].Value
        $fso = New-Object -ComObject Scripting.FileSystemObject
        $short = $fso.GetFile($long).ShortPath
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($fso)
        if (-not $short -or $short -ieq $long -or [IO.Path]::GetFileName($short) -ieq $m.Groups[1].Value) { $Why.Value = 'no 8.3 name on this volume'; return $null }
        $t = $t.Replace($m.Value, $short)
    }
    return $t
}
# (re)maps the probe's own SUBST letter (first free of T, U, V, Q, R) to 'Target'
function Set-Subst([string]$Target) {
    if ($script:Subst) {
        & subst.exe $script:Subst /d | Out-Null
        & subst.exe $script:Subst $Target | Out-Null
        return ($LASTEXITCODE -eq 0 -and [IO.Directory]::Exists($script:Subst + '\'))
    }
    foreach ($l in @('T', 'U', 'V', 'Q', 'R')) {
        if ([IO.Directory]::Exists($l + ':\')) { continue }
        & subst.exe ($l + ':') $Target | Out-Null
        if ($LASTEXITCODE -eq 0 -and [IO.Directory]::Exists($l + ':\')) { $script:Subst = $l + ':'; return $true }
    }
    return $false
}
# (re)maps the probe's own network drive (first free of W, Y, X) to \\localhost\<drive>$\<path of Target>;
# existing mappings are never touched (a letter in use - also a remembered one - makes net use fail)
function Set-NetDrive([string]$Target) {
    $unc = '\\localhost\' + $Target.Substring(0, 1) + '$\' + $Target.Substring(3)
    if ($script:NetDrive) {
        & cmd.exe /c "net use $($script:NetDrive) /delete /y >nul 2>&1"
        & cmd.exe /c "net use $($script:NetDrive) `"$unc`" /persistent:no >nul 2>&1"
        return ($LASTEXITCODE -eq 0 -and [IO.Directory]::Exists($script:NetDrive + '\'))
    }
    foreach ($l in @('W', 'Y', 'X')) {
        if ([IO.Directory]::Exists($l + ':\')) { continue }
        & cmd.exe /c "net use $($l): `"$unc`" /persistent:no >nul 2>&1"
        if ($LASTEXITCODE -eq 0 -and [IO.Directory]::Exists($l + ':\')) { $script:NetDrive = $l + ':'; return $true }
    }
    return $false
}
function Remove-NetDrive {
    if ($script:NetDrive) { & cmd.exe /c "net use $($script:NetDrive) /delete /y >nul 2>&1"; Out ("NET USE : {0} removed (exists now: {1})" -f $script:NetDrive, [IO.Directory]::Exists($script:NetDrive + '\')); $script:NetDrive = $null }
}
function Remove-Subst {
    if ($script:Subst) { & subst.exe $script:Subst /d | Out-Null; Out ("SUBST   : {0} removed (exists now: {1})" -f $script:Subst, [IO.Directory]::Exists($script:Subst + '\')); $script:Subst = $null }
}

function Start-Tc109([string]$Dir) {
    $a = @('-t', 'T109', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Dir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
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

$script:Table = New-Object System.Collections.ArrayList
function Run-Steps($c) {
    $N = $c.N
    $dir = $Root + '\' + $N
    [void][IO.Directory]::CreateDirectory($dir)
    foreach ($a in $c.Arcs) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dir + '\' + $a.Name)) }
    foreach ($a in $c.Arcs) { [void](Invoke-ArcFix 'make' ($dir + '\' + $a.Name) $a.Fmt @('x.txt') $(if ($a.MakeTag) { $a.MakeTag } else { $a.Tag })) }
    if ($c.Twin) {
        # the second archive gets the first one's time (same size: only a digit differs): the key choice
        # cannot be settled by size and time and must read the file identities
        $f0 = New-Object IO.FileInfo($dir + '\' + $c.Arcs[0].Name); $f1 = New-Object IO.FileInfo($dir + '\' + $c.Arcs[1].Name)
        $f1.LastWriteTimeUtc = $f0.LastWriteTimeUtc
        $t1 = (New-Object IO.FileInfo($f1.FullName)).LastWriteTimeUtc
        Out ("   twins: sizes {0} / {1}, times equal {2}" -f $f0.Length, $f1.Length, ($t1 -eq $f0.LastWriteTimeUtc))
    }
    if ([IO.File]::Exists($ViewLog)) { [IO.File]::Delete($ViewLog) }
    $tmpBefore = @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp'))
    $before = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    Out ''
    Out ("--- {0}: archives {1}" -f $N, ((@($c.Arcs) | ForEach-Object { "'" + (Esc $_.Name) + "' (x.txt tag " + $_.Tag + ")" }) -join ', '))
    $row = [ordered]@{ Case = $N; Verdict = 'NOT DRIVEN'; Archive = '-'; Views = '-'; Copies = '-'; Why = '' }
    $id = 0
    $snaps = @(); $views = @()
    try {
        # resolve every spelling before the program starts
        $paths = @{}
        for ($i = 0; $i -lt $c.Steps.Count; $i++) {
            $s = $c.Steps[$i]
            if ($s.Op -eq 'cd') {
                $why = ''
                $p = Resolve-Path109 $s.Arg $dir ([ref]$why)
                if ($null -eq $p) { throw ('spelling not available: ' + $why) }
                $paths[$i] = $p
            }
        }
        $id = Start-Tc109 $dir
        $r0 = Serve $id 6
        if ($r0.Messages.Count) { Out ('   at start: ' + (MsgText $r0)) }
        if ((Get-Lists $id).Count -ne 2) { throw 'two panel lists not found' }
        $active = 0
        for ($i = 0; $i -lt $c.Steps.Count; $i++) {
            $s = $c.Steps[$i]
            if ($s.P -ne $active) { PostKeyP $id $active 0x09; Start-Sleep -Milliseconds 800; [void](Serve $id 10); $active = $s.P }
            $note = ''
            switch ($s.Op) {
                'cd' {
                    $t0 = Title $id
                    $ok = Do-ChangeDir $id $paths[$i]
                    $r = Serve $id 30
                    $note = ("cd '{0}' (field held it: {1}); title '{2}'; windows: {3}" -f (Esc $paths[$i]), $ok, (Tail (Title $id) 40), (MsgText $r))
                    if ((Title $id) -eq $t0) { throw ('Change Directory did not change the path: ' + $note) }
                }
                { $_ -eq 'f4' -or $_ -eq 'f3' } {
                    $sig0 = TmpSig (Find-Tmp $tmpBefore); $v0 = ViewLen
                    $cmd = $(if ($s.Op -eq 'f4') { 743 } else { 742 })
                    $acted = $false
                    for ($try = 0; $try -lt 2 -and -not $acted; $try++) {
                        if ($try -eq 1) { $script:Retries++; Out ('   ' + $s.Op.ToUpper() + ' RETRY: the first post was not acted on; posted again after a 1.5 s idle wait') }
                        KeyP $id $s.P 0x24; KeyP $id $s.P 0x28
                        Settle $id $(if ($try -eq 0) { 800 } else { 1500 })
                        Post-Cmd (Get-Main $id) $cmd
                        $sw = [Diagnostics.Stopwatch]::StartNew()
                        while ($sw.Elapsed.TotalSeconds -lt 10) {
                            if ($s.Op -eq 'f4' -and (TmpSig (Find-Tmp $tmpBefore)) -ne $sig0) { $acted = $true; break }
                            if ($s.Op -eq 'f3' -and (ViewLen) -gt $v0) { $acted = $true; break }
                            if (@(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -ne $MainClass }).Count) { $acted = $true; break }
                            Start-Sleep -Milliseconds 300
                        }
                    }
                    Start-Sleep -Milliseconds 1500
                    $r = Serve $id 20
                    if ($s.Op -eq 'f3') {
                        $txt = ViewSince $v0
                        $m = [regex]::Match($txt, 'content-of-member-(\d+)')
                        $vt = $(if ($m.Success) { $m.Groups[1].Value } else { '?' })
                        $vm = ([regex]::Matches($txt, $Marker)).Count
                        $views += [pscustomobject]@{ Step = $i; Tag = $vt; Markers = $vm }
                        $note = ("F3 in panel {0}: the viewer was given tag {1} with {2} edit(s); windows: {3}" -f $s.P, $vt, $vm, (MsgText $r))
                    }
                    else { $note = ("F4 in panel {0}: windows: {1}" -f $s.P, (MsgText $r)) }
                    if ($r.Fatal) { throw ('FATAL window: ' + (MsgText $r)) }
                }
                'rewrite' {
                    # the archive is replaced from outside the program (another tool updates it): x.txt now
                    # carries tag Arg; then the program is given time to notice (its own refresh)
                    $a0 = $c.Arcs[0]
                    Start-Sleep -Milliseconds 1200
                    [void](Invoke-ArcFix 'make' ($dir + '\' + $a0.Name) $a0.Fmt @('x.txt') ([int]$s.Arg))
                    Start-Sleep -Milliseconds 2500
                    Settle $id 1500
                    $r = Serve $id 20
                    $note = ("rewrote {0} (x.txt tag {1}) from outside; windows: {2}" -f (Esc $a0.Name), $s.Arg, (MsgText $r))
                }
                'resubst' {
                    $ok = Set-Subst ($dir + '\' + $s.Arg)
                    if (-not $ok) { throw 'resubst failed' }
                    $note = ("{0} re-pointed to {1}" -f $script:Subst, (Esc ($dir + '\' + $s.Arg)))
                }
                'renet' {
                    $ok = Set-NetDrive ($dir + '\' + $s.Arg)
                    if (-not $ok) { throw 'renet failed' }
                    $note = ("{0} re-mapped to \\localhost\...\{1}" -f $script:NetDrive, (Esc $s.Arg))
                }
                'leave' {
                    PostKeyP $id $s.P 0x08; Start-Sleep -Milliseconds 1000
                    $r = Serve $id 60
                    $note = ("leave panel {0}: title '{1}'; windows: {2}" -f $s.P, (Tail (Title $id) 40), (MsgText $r))
                    if ($r.Fatal) { throw ('FATAL window: ' + (MsgText $r)) }
                }
            }
            $snap = Find-Tmp $tmpBefore
            $snaps += , $snap
            Out ("   step {0} [{1}]: {2}" -f $i, $s.Op, $note)
            Out ("          temporary copies: {0}" -f (TmpDesc $snap))
        }
        [void][Drv093]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $id)) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -eq '#32770' })) { $d = WinDesc $h; if ($d -notmatch 'monitored handles') { Out ('   at exit: ' + $d) }; $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
            Start-Sleep -Milliseconds 200
        }
        if (Test-Alive $id) { Kill-Mine $id; Out '   END  : did not exit in 30 s - ended by the probe' }
        Start-Sleep -Milliseconds 700
        $ec = ExitCodeOf $id
        $new = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Where-Object { $before -notcontains $_ })
        foreach ($n in $new) { Remove-Item -LiteralPath (Join-Path $ReportDir $n) -Force -ErrorAction SilentlyContinue }
        Out ("   END  : exit code {0}; new crash reports {1}" -f $ec, $new.Count)
        # ---- verdict
        $why = @(); $desc = @()
        foreach ($a in $c.Arcs) {
            $read = Invoke-ArcFix 'read' ($dir + '\' + $a.Name) $a.Fmt @('x.txt')
            foreach ($l in $read) { Out ("          {0}: {1}" -f (Esc $a.Name), $l) }
            $e = @($read | Where-Object { $_ -like 'ENTRY *' } | ForEach-Object { $mm = [regex]::Match($_, '^ENTRY (.*) tag=(\S+) markers=(\d+) size=(\d+)$'); [pscustomobject]@{ Tag = $mm.Groups[2].Value; Markers = [int]$mm.Groups[3].Value } })
            if ($e.Count -ne 1) { $why += ("{0}: {1} entries (expected 1)" -f (Esc $a.Name), $e.Count); continue }
            $desc += ("{0}:x.txt=m{1}+{2}" -f (Esc $a.Name), $e[0].Tag, $e[0].Markers)
            if ($e[0].Tag -ne [string]$a.Tag) { $why += ("{0}: x.txt holds the content of member {1} (expected {2} - another archive's x.txt)" -f (Esc $a.Name), $e[0].Tag, $a.Tag) }
            if ($e[0].Markers -ne $a.Edits) { $why += ("{0}: {1} edit(s) packed (expected {2})" -f (Esc $a.Name), $e[0].Markers, $a.Edits) }
        }
        $k = 0
        foreach ($v in $views) {
            $exp = $c.Views[$k]; $k++
            if ($null -eq $exp) { continue }
            if ($v.Tag -ne [string]$exp.Tag -or $v.Markers -ne $exp.Markers) { $why += ("F3 at step {0} was given tag {1} with {2} edit(s) (expected tag {3} with {4})" -f $v.Step, $v.Tag, $v.Markers, $exp.Tag, $exp.Markers) }
        }
        if ($c.Views -and $views.Count -ne $c.Views.Count) { $why += ("{0} F3 results (expected {1})" -f $views.Count, $c.Views.Count) }
        if ($c.Copies) {
            foreach ($key in $c.Copies.Keys) {
                $got = @($snaps[$key]).Count
                if ($got -ne $c.Copies[$key]) { $why += ("after step {0}: {1} temporary cop(y/ies) (expected {2})" -f $key, $got, $c.Copies[$key]) }
            }
        }
        if ($c.SameCopy) {
            foreach ($pair in $c.SameCopy) {
                $x = @($snaps[$pair[0]]); $y = @($snaps[$pair[1]])
                if ($x.Count -ne 1 -or $y.Count -ne 1 -or $x[0].Dir -ne $y[0].Dir -or $x[0].Created -ne $y[0].Created) { $why += ("steps {0} and {1}: not the same temporary copy (or it was extracted again)" -f $pair[0], $pair[1]) }
            }
        }
        if ($new.Count) { $why += "$($new.Count) crash report(s)" }
        $row.Archive = ($desc -join ' ')
        $row.Views = $(if ($views.Count) { ($views | ForEach-Object { "t{0}+{1}" -f $_.Tag, $_.Markers }) -join ',' } else { '-' })
        $row.Copies = (($snaps | ForEach-Object { @($_).Count }) -join '/')
        $row.Verdict = $(if ($why.Count) { 'FAIL' } else { 'PASS' })
        $row.Why = ($why -join '; ')
        Out ("   VERDICT: {0} {1}" -f $row.Verdict, $row.Why)
    }
    catch { Out ('   exception: ' + $_.Exception.Message); $row.Why = 'NOT DRIVEN: ' + $_.Exception.Message }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        Start-Sleep -Milliseconds 300
        Remove-Subst
        Remove-NetDrive
        foreach ($t in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp') | Where-Object { $tmpBefore -notcontains $_ })) {
            Out ("   left in the temp folder by the test instance, removed: {0}" -f [IO.Path]::GetFileName($t))
            try { [IO.Directory]::Delete($t, $true) } catch { }
        }
        if ([IO.File]::Exists($ViewLog)) { [IO.File]::Delete($ViewLog) }
        [void]$script:Table.Add([pscustomobject]$row)
    }
}

# ---- main ---------------------------------------------------------------------
$backupDir = $TempRoot + '\tc109\reg'
[void][IO.Directory]::CreateDirectory($backupDir)
$backup = Join-Path $backupDir 'backup.reg'
$existed = Backup-TcRegistry $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $fresh = Set-ProbeConfig
    Out ("diskcache_probe (feature 109) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv093]::GetACP())
    Out ("Config  : registry key existed {0}; fresh defaults {1}; F4 editor = cmd.exe /c echo {2}>>`"`$(FullName)`"; F3 viewer = cmd.exe /c type `"`$(FullName)`">>view.log" -f $existed, $fresh, $Marker)
    if ($fresh) { throw 'no stored configuration - the F4 editor cannot be configured' }
    $hc = [string][char]0x0125; $Lac = [string][char]0x0139            # h-circumflex / L-acute: C4 A5 / C4 B9
    $CcUp = [string][char]0x010C; $CcLow = [string][char]0x010D        # C-caron / c-caron: C4 8C / C4 8D
    $cases = @()
    foreach ($f in @('zip', '7z')) {
        $a1 = $hc + '.' + $f; $a2 = $Lac + '.' + $f
        $cases += @{ N = ('twoarcF4_' + $f); Arcs = @(@{ Name = $a1; Fmt = $f; Tag = 1; Edits = 1 }, @{ Name = $a2; Fmt = $f; Tag = 2; Edits = 1 })
            Steps = @(@{ P = 0; Op = 'cd'; Arg = ('{DIR}\' + $a1) }, @{ P = 0; Op = 'f4' }, @{ P = 1; Op = 'cd'; Arg = ('{DIR}\' + $a2) }, @{ P = 1; Op = 'f4' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
            Copies = @{ 3 = 2 } }
        $cases += @{ N = ('twoarcF3_' + $f); Arcs = @(@{ Name = $a1; Fmt = $f; Tag = 1; Edits = 0 }, @{ Name = $a2; Fmt = $f; Tag = 2; Edits = 0 })
            Steps = @(@{ P = 0; Op = 'cd'; Arg = ('{DIR}\' + $a1) }, @{ P = 0; Op = 'f3' }, @{ P = 1; Op = 'cd'; Arg = ('{DIR}\' + $a2) }, @{ P = 1; Op = 'f3' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
            Views = @(@{ Tag = 1; Markers = 0 }, @{ Tag = 2; Markers = 0 }); Copies = @{ 3 = 2; 5 = 0 } }
    }
    $a1 = $hc + '.zip'; $a2 = $Lac + '.zip'
    $cases += @{ N = 'twoarcF4F3_zip'; Arcs = @(@{ Name = $a1; Fmt = 'zip'; Tag = 1; Edits = 1 }, @{ Name = $a2; Fmt = 'zip'; Tag = 2; Edits = 0 })
        Steps = @(@{ P = 0; Op = 'cd'; Arg = ('{DIR}\' + $a1) }, @{ P = 0; Op = 'f4' }, @{ P = 1; Op = 'cd'; Arg = ('{DIR}\' + $a2) }, @{ P = 1; Op = 'f3' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
        Views = @(@{ Tag = 2; Markers = 0 }) }
    # one archive through two spellings: both F4 edits must reach the archive
    $alias = @(
        @{ N = 'alias-ascii'; Name = 'arc.zip'; A = '{DIR}\arc.zip'; B = '{DIR}\ARC.ZIP' },
        @{ N = 'alias-accent'; Name = ($CcUp + 'arc.zip'); A = ('{DIR}\' + $CcUp + 'arc.zip'); B = ('{DIR}\' + $CcLow + 'ARC.zip') },
        @{ N = 'alias-sfn'; Name = 'longarchivename109.zip'; A = '{DIR}\longarchivename109.zip'; B = '{SFN:longarchivename109.zip}' },
        @{ N = 'alias-subst'; Name = 'arc.zip'; A = '{DIR}\arc.zip'; B = '{SUBST}\arc.zip' },
        @{ N = 'alias-unc'; Name = 'arc.zip'; A = '{DIR}\arc.zip'; B = '{UNC}\arc.zip' })
    foreach ($al in $alias) {
        $cases += @{ N = $al.N; Arcs = @(@{ Name = $al.Name; Fmt = 'zip'; Tag = 1; Edits = 2 })
            Steps = @(@{ P = 0; Op = 'cd'; Arg = $al.A }, @{ P = 0; Op = 'f4' }, @{ P = 1; Op = 'cd'; Arg = $al.B }, @{ P = 1; Op = 'f4' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
            Copies = @{ 3 = 1 } }
    }
    $cases += @{ N = 'alias-accent_7z'; Arcs = @(@{ Name = ($CcUp + 'arc.7z'); Fmt = '7z'; Tag = 1; Edits = 2 })
        Steps = @(@{ P = 0; Op = 'cd'; Arg = ('{DIR}\' + $CcUp + 'arc.7z') }, @{ P = 0; Op = 'f4' }, @{ P = 1; Op = 'cd'; Arg = ('{DIR}\' + $CcLow + 'ARC.7z') }, @{ P = 1; Op = 'f4' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
        Copies = @{ 3 = 1 } }
    # a key that merely starts with another archive's key
    $cases += @{ N = 'prefix'; Arcs = @(@{ Name = 'p.zip.zip'; Fmt = 'zip'; Tag = 1; Edits = 2 }, @{ Name = 'p.zip'; Fmt = 'zip'; Tag = 2; Edits = 0 })
        Steps = @(@{ P = 0; Op = 'cd'; Arg = '{DIR}\p.zip.zip' }, @{ P = 0; Op = 'f4' }, @{ P = 1; Op = 'cd'; Arg = '{DIR}\p.zip' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'f4' }, @{ P = 0; Op = 'leave' }) }
    # ordinary cache behaviour
    $cases += @{ N = 'reuse'; Arcs = @(@{ Name = 'r.zip'; Fmt = 'zip'; Tag = 1; Edits = 0 })
        Steps = @(@{ P = 0; Op = 'cd'; Arg = '{DIR}\r.zip' }, @{ P = 0; Op = 'f3' }, @{ P = 0; Op = 'f3' }, @{ P = 1; Op = 'cd'; Arg = '{DIR}\r.zip' }, @{ P = 1; Op = 'f3' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
        Views = @(@{ Tag = 1; Markers = 0 }, @{ Tag = 1; Markers = 0 }, @{ Tag = 1; Markers = 0 }); Copies = @{ 1 = 1; 2 = 1; 4 = 1; 5 = 1; 6 = 0 }; SameCopy = @(@(1, 2), @(2, 4), @(4, 5)) }
    $cases += @{ N = 'reuse-accent'; Arcs = @(@{ Name = ($CcUp + 'r.zip'); Fmt = 'zip'; Tag = 1; Edits = 0 })
        Steps = @(@{ P = 0; Op = 'cd'; Arg = ('{DIR}\' + $CcUp + 'r.zip') }, @{ P = 0; Op = 'f3' }, @{ P = 1; Op = 'cd'; Arg = ('{DIR}\' + $CcLow + 'R.zip') }, @{ P = 1; Op = 'f3' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
        Views = @(@{ Tag = 1; Markers = 0 }, @{ Tag = 1; Markers = 0 }); Copies = @{ 1 = 1; 3 = 1; 4 = 1; 5 = 0 }; SameCopy = @(, @(1, 3)) }
    # both panels on one archive, the archive replaced from outside: F3 must give the new content
    # (a cached copy kept because the other panel still shows the archive would be stale)
    foreach ($sp in @(@{ N = 'stale-same'; B = '{DIR}\t.zip' }, @{ N = 'stale-subst'; B = '{SUBST}\t.zip' })) {
        $cases += @{ N = $sp.N; Arcs = @(@{ Name = 't.zip'; Fmt = 'zip'; MakeTag = 1; Tag = 9; Edits = 0 })
            Steps = @(@{ P = 0; Op = 'cd'; Arg = '{DIR}\t.zip' }, @{ P = 1; Op = 'cd'; Arg = $sp.B }, @{ P = 0; Op = 'f3' }, @{ P = 0; Op = 'rewrite'; Arg = 9 }, @{ P = 1; Op = 'f3' }, @{ P = 0; Op = 'f3' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
            Views = @(@{ Tag = 1; Markers = 0 }, @{ Tag = 9; Markers = 0 }, @{ Tag = 9; Markers = 0 }) }
    }
    # review of 109 (blocker): a key taken from a spelling that later names ANOTHER file. The right panel
    # opens <letter>:\arc.zip (letter -> A), the left one A\arc.zip (same file: shares the right's key),
    # F3 in the left; the right leaves, the letter is re-pointed to B, the right opens <letter>:\arc.zip
    # again - another file: F3 must give B's x.txt, and its edit must go into B\arc.zip only
    foreach ($rs in @(@{ N = 'resubst'; Tok = '{SUBST:A}'; Op = 'resubst'; Twin = $true }, @{ N = 'renet'; Tok = '{NET:A}'; Op = 'renet' })) {
        $st = @(@{ P = 1; Op = 'cd'; Arg = ($rs.Tok + '\arc.zip') }, @{ P = 0; Op = 'cd'; Arg = '{DIR}\A\arc.zip' }, @{ P = 0; Op = 'f3' }, @{ P = 1; Op = 'leave' })
        # a network drive cannot be re-mapped under a panel that shows its root ("W:\ is invalid"): the
        # right panel steps off it first
        if ($rs.Op -eq 'renet') { $st += @{ P = 1; Op = 'cd'; Arg = '{DIR}' } }
        $st += @(@{ P = 1; Op = $rs.Op; Arg = 'B' }, @{ P = 1; Op = 'cd'; Arg = ($rs.Tok + '\arc.zip') }, @{ P = 1; Op = 'f3' }, @{ P = 1; Op = 'f4' }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
        $cases += @{ N = $rs.N; Twin = $rs.Twin; Arcs = @(@{ Name = 'A\arc.zip'; Fmt = 'zip'; Tag = 1; Edits = 0 }, @{ Name = 'B\arc.zip'; Fmt = 'zip'; Tag = 2; Edits = 1 })
            Steps = $st; Views = @(@{ Tag = 1; Markers = 0 }, @{ Tag = 2; Markers = 0 }) }
    }
    if ($Only) { $cases = $cases | Where-Object { $Only -contains $_.N } }
    foreach ($c in $cases) { Run-Steps $c }
}
catch { Out ('FATAL: ' + $_.Exception.Message) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 500
    Remove-Subst
    Remove-NetDrive
    $restored = Restore-TcRegistry $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if ($restored -and (Test-Path -LiteralPath $backupDir)) { Remove-Item -LiteralPath $backupDir -Recurse -Force }
    try { if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) } } catch { Out ("Fixture : could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    Out ''
    Out '=== summary ==='
    Out ('{0,-16} {1,-10} {2}' -f 'case', 'verdict', 'archives (name=member tag+edits) | F3 given | copies after each step | why')
    foreach ($t in $script:Table) {
        Out ('{0,-16} {1,-10} {2} | {3} | {4}{5}' -f $t.Case, $t.Verdict, $t.Archive, $t.Views, $t.Copies, $(if ($t.Why) { ' | ' + $t.Why } else { '' }))
    }
    $nPass = @($script:Table | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nFail = @($script:Table | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nNd = @($script:Table | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ("TOTAL: {0} PASS / {1} FAIL / {2} NOT DRIVEN; F3/F4 retries {3}" -f $nPass, $nFail, $nNd, $script:Retries)
    Out ("Left running: {0}; fixture removed: {1}; registry restored+identical: {2}" -f $leftover.Count, (-not [IO.Directory]::Exists($Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit 0
