<#
.SYNOPSIS
    Feature 153 probe: the Archive Update dialog marks a file whose member was changed in the
    archive by another program since the file was opened for editing (F4).

.DESCRIPTION
    t.zip with x.txt (tag 1) and y.txt (tag 2), made by probe\arcfix153.py (one fixed member
    time, so a member written again with its tag is the same member). The left panel enters the
    archive, F4 on x.txt (the editor: cmd.exe /c echo edited153>>"$(FullName)"), then another
    program rewrites the archive, then Ctrl+R ("Archive ... has changed. Archive will be reopened"
    and the update) or Backspace (leave, no refresh: Fixed Automatic Refresh = 0). The Archive
    Update dialog's list (id 2732) is read item by item: x.txt's line is plain or marked.

    Rows: x-changed, x-deleted (marked); y-changed, same, untouched (plain); x-same-stamp (plain:
    the limit - another content with the same size and time is not told apart); zip-corrupt,
    7z-corrupt (the archive unreadable after the F4: the new listing fails - no crash, marked; the
    review found a use after free of the 7zip plug-in's data there); 7z-changed (marked), 7z-same
    (plain); x-changed-leave (marked, the panel never re-listed the archive).

    Helper block copied from specs/112-cache-pending-edit/probe/diskcache_edit_probe.ps1
    (Drv093 renamed Drv153, a list-box reader added, Serve records the Archive Update list).
    MUST be started through tools\run_on_hidden_desktop.ps1. HKCU\Software\Tandem Commander is
    exported before, restored and verified after.

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
# feature 112 (review NIT4): only on a desktop of its own (tools\run_on_hidden_desktop.ps1), never on the user's
if (-not ('Desk112' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Desk112
{
    [DllImport("user32.dll")] public static extern IntPtr GetThreadDesktop(uint threadId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool GetUserObjectInformationW(IntPtr h, int index, StringBuilder info, int length, out int needed);
    public static string Name()
    {
        var sb = new StringBuilder(256); int needed;
        if (!GetUserObjectInformationW(GetThreadDesktop(GetCurrentThreadId()), 2, sb, sb.Capacity * 2, out needed)) return "";
        return sb.ToString();
    }
}
'@
}
$deskName = [Desk112]::Name()
if (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon') { Write-Output ("NOT RUN: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 3 }

# ---- helper block of specs/094-plugin-password-encoding/probe/zip_gui_probe.ps1 (copied, unchanged) ----
# ---- helper block of specs/094-plugin-password-encoding/probe/zip_gui_probe.ps1 (copied, unchanged) ----
if (-not ('Drv153' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Drv153
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
    // feature 153: the items of a list box (LB_GETCOUNT, LB_GETTEXTLEN, LB_GETTEXT - wide)
    public static List<string> LbItems(IntPtr h, uint timeout)
    {
        var l = new List<string>(); IntPtr res;
        if (SendMessageTimeoutW(h, 0x018B, IntPtr.Zero, IntPtr.Zero, 0, timeout, out res) == IntPtr.Zero) return l;
        int n = (int)res.ToInt64();
        for (int i = 0; i < n; i++)
        {
            IntPtr len;
            if (SendMessageTimeoutW(h, 0x018A, (IntPtr)i, IntPtr.Zero, 0, timeout, out len) == IntPtr.Zero) break;
            var buf = new char[(int)len.ToInt64() + 2];
            IntPtr got;
            SendGetText(h, 0x0189, (IntPtr)i, buf, 0, timeout, out got);
            int k = (int)got.ToInt64(); if (k < 0) k = 0; if (k > buf.Length) k = buf.Length;
            l.Add(new string(buf, 0, k));
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
    & cmd.exe /c "reg query `"$RegKey\Settings\Configuration`" >nul 2>&1 || (reg query `"$RegKey\0.1\Configuration`" >nul 2>&1 && reg copy `"$RegKey\0.1`" `"$RegKey\Settings`" /s /f >nul 2>&1)"   # feature 343: copy 0.1 to Settings after the backup (what the program does at its first start; the restore removes it)
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
function Get-Tops([int]$Id) { return @([Drv153]::Top([uint32]$Id) | Where-Object { $SystemClasses -notcontains [Drv153]::Cls($_) }) }
function Get-Main([int]$Id) {
    foreach ($h in [Drv153]::Top([uint32]$Id)) { if ([Drv153]::Cls($h) -eq $MainClass) { return $h } }
    return [IntPtr]::Zero
}
function Get-DialogText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv153]::Kids($H)) {
        $t = [Drv153]::Txt($c)
        if ($t -and [Drv153]::IsWindowVisible($c)) { $parts += ("[{0} id={1}] {2}" -f [Drv153]::Cls($c), [Drv153]::GetDlgCtrlID($c), (Esc ($t -replace '\s+', ' '))) }
    }
    $r = ($parts -join ' | ')
    if ($r.Length -gt 500) { $r = $r.Substring(0, 500) + '...' }
    return $r
}
function Post-Cmd([IntPtr]$H, [int]$C) { [void][Drv153]::PostMessageW($H, 0x0111, [IntPtr]$C, [IntPtr]::Zero) }
function Close-Win([int]$Id, [IntPtr]$H) {
    if (-not [Drv153]::IsWindow($H)) { return }
    if ([Drv153]::PidOf($H) -ne [uint32]$Id) { throw 'window does not belong to the test process' }
    Post-Cmd $H 2
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv153]::IsWindow($H) -and [Drv153]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
    if ([Drv153]::IsWindow($H) -and [Drv153]::IsWindowVisible($H)) {
        [void][Drv153]::PostMessageW($H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw.Restart()
        while ($sw.Elapsed.TotalSeconds -lt 3 -and [Drv153]::IsWindow($H) -and [Drv153]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
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
    return @([Drv153]::Kids($m) | Where-Object { [Drv153]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv153]::IsWindowVisible($_) } | Sort-Object { [Rect108]::Left($_) })
}
function KeyP([int]$Id, [int]$Panel, [int]$Vk) {
    $l = (Get-Lists $Id)[$Panel]
    [void][Drv153]::Send($l, 0x0100, $Vk, 1, 20000)
    [void][Drv153]::Send($l, 0x0101, $Vk, 0xC0000001, 20000)
}
function PostKeyP([int]$Id, [int]$Panel, [int]$Vk) {
    $l = (Get-Lists $Id)[$Panel]
    [void][Drv153]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv153]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L)
}
function Get-LeftList([int]$Id) {
    $m = Get-Main $Id
    $lists = @([Drv153]::Kids($m) | Where-Object { [Drv153]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv153]::IsWindowVisible($_) })
    if ($lists.Count -lt 1) { throw 'panel list window not found' }
    return $lists[0]
}
function Key([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv153]::Send($l, 0x0100, $Vk, 1, 20000)
    [void][Drv153]::Send($l, 0x0101, $Vk, 0xC0000001, 20000)
}
function PostKey([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv153]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv153]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L)
}
function Title([int]$Id) { return [Drv153]::Txt((Get-Main $Id)) }
function Find-Ctl([IntPtr]$Dlg, [int]$CtlId) {
    $c = @([Drv153]::Kids($Dlg) | Where-Object { [Drv153]::GetDlgCtrlID($_) -eq $CtlId -and @('ComboBox', 'Edit') -contains [Drv153]::Cls($_) })
    $v = @($c | Where-Object { [Drv153]::IsWindowVisible($_) })
    if ($v.Count) { return $v[0] }
    if ($c.Count) { return $c[0] }
    return [IntPtr]::Zero
}
function Click-Ok([IntPtr]$Dlg) {
    $ok = [Drv153]::Kids($Dlg) | Where-Object { [Drv153]::GetDlgCtrlID($_) -eq 1 -and [Drv153]::Cls($_) -eq 'Button' } | Select-Object -First 1
    if ($ok) { [void][Drv153]::PostMessageW($ok, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv153]::IsWindow($Dlg) -and [Drv153]::IsWindowEnabled($Dlg)) { Start-Sleep -Milliseconds 50 }
    if ([Drv153]::IsWindow($Dlg) -and [Drv153]::IsWindowEnabled($Dlg)) { Post-Cmd $Dlg 1 }
}
function Buttons([IntPtr]$H) { return @([Drv153]::Kids($H) | Where-Object { [Drv153]::Cls($_) -eq 'Button' -and [Drv153]::IsWindowVisible($_) }) }
function Click([IntPtr]$Btn) { [void][Drv153]::PostMessageW($Btn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
function Tail([string]$s, [int]$n = 60) { if ($s.Length -le $n) { return (Esc $s) }; return ('...' + (Esc $s.Substring($s.Length - $n))) }
function WinDesc([IntPtr]$H) { return ("[{0} '{1}'] {2}" -f [Drv153]::Cls($H), (Tail ([Drv153]::Txt($H)) 70), (Get-DialogText $H)) }
$FatalRx = 'Run-Time Check|Debug Error|Assertion|Runtime Library|Stack around|bug report|abnormal|has stopped|Unhandled exception|buffer overrun'
function Is-Fatal([string]$Desc) { return ($Desc -match $FatalRx) }

# feature 101: lets the instance go idle (the F4 command enabler is refreshed in the idle pass)
function Settle([int]$Id, [int]$Ms) {
    $m = Get-Main $Id
    if ($m -eq [IntPtr]::Zero) { return }
    [void][Drv153]::Send($m, 0, 0, 0, 20000)
    Start-Sleep -Milliseconds $Ms
    [void][Drv153]::Send($m, 0, 0, 0, 20000)
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
        $wins = @(Get-Tops $Id | Where-Object { [Drv153]::Cls($_) -ne $MainClass })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 1.5) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv153]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if (Is-Fatal $d) { [void]$r.Messages.Add('FATAL ' + $d); $r.Fatal = $true; return $r }
            if (-not [Drv153]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv153]::GetDlgCtrlID($_) })
            $isProgress = ($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)
            if ($isProgress) { continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            [void]$r.Messages.Add($d)
            if ([Drv153]::Txt($h) -eq 'Archive Update') {   # feature 153: its list, item by item
                $lb = @([Drv153]::Kids($h) | Where-Object { [Drv153]::GetDlgCtrlID($_) -eq 2732 }) | Select-Object -First 1
                if ($lb) { [void]$r.Messages.Add('[Archive Update list] ' + ((@([Drv153]::LbItems($lb, 5000)) | ForEach-Object { Esc $_ }) -join ' || ')) }
            }
            $seen.Remove($key)
            $want = @(1, 6)
            if ($d -match 'temporary director') { $want = @(4) }
            elseif ($d -match 'multi-volume archive or is corrupted') { $want = @(2) }
            elseif ($d -match 'Packing of updated file') { $want = @(7); $packFailed = $true }
            elseif ($packFailed -and [Drv153]::Txt($h) -eq 'Archive Update') { $want = @(2) }
            $pick = $btn | Where-Object { $want -contains [Drv153]::GetDlgCtrlID($_) } | Select-Object -First 1
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
    [void][Drv153]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
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
    [void][Drv153]::SetText($ctl, $Text, 5000)
    $held = [Drv153]::GetText($ctl, 5000)
    Click-Ok $dlg
    Start-Sleep -Milliseconds 1200
    return ($held -ceq $Text)
}



# ---- this probe ----------------------------------------------------------------
$Utf8 = New-Object Text.UTF8Encoding($false)
$TempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$Root = $TempRoot + '\tc153\p'
$ReportDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$Marker = 'edited153'
$ArcFix = Join-Path $PSScriptRoot 'arcfix153.py'
$DrvKey = "$RegKey\Settings\Configuration\Drive Special Settings"

function Set-ProbeConfig {
    & cmd.exe /c "reg query `"$RegKey\Settings\Configuration`" >nul 2>&1"
    $fresh = ($LASTEXITCODE -ne 0)
    if (-not $fresh) {
        & reg.exe add "$RegKey\Settings\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$RegKey\Settings\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "$RegKey\Settings\Configuration\Confirmation" /v 'Close Archive' /t REG_DWORD /d 1 /f | Out-Null
        $cmd = Join-Path $env:SystemRoot 'System32\cmd.exe'
        $sys = Join-Path $env:SystemRoot 'System32'
        & cmd.exe /c "reg delete `"$RegKey\Settings\Editors`" /f >nul 2>&1"
        $k = "$RegKey\Settings\Editors\1"
        & reg.exe add $k /v 'Masks' /t REG_SZ /d '*.*' /f | Out-Null
        & reg.exe add $k /v 'Command' /t REG_SZ /d $cmd /f | Out-Null
        Set-ItemProperty -LiteralPath ('Registry::' + $k.Replace('HKCU\', 'HKEY_CURRENT_USER\')) -Name 'Arguments' -Value ('/c echo ' + $Marker + '>>"$(FullName)"')
        & reg.exe add $k /v 'Initial Directory' /t REG_SZ /d $sys /f | Out-Null
        # the archive's folder is not watched: the left panel refreshes only when told (Ctrl+R)
        & reg.exe add $DrvKey /v 'Fixed Automatic Refresh' /t REG_DWORD /d 0 /f | Out-Null
    }
    return $fresh
}
function ArcFix([string[]]$a) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $ArcFix @a 2>&1
    $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ('arcfix153.py failed: ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return @($o | ForEach-Object { "$_" })
}
function Start-Tc153([string]$Dir) {
    $a = @('-t', 'T153', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Dir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv153]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 3000
    return $p.Id
}

# One row: the archive t.zip with x.txt (tag 1) and y.txt (tag 2); the left panel enters it, F4 on
# x.txt (the editor appends a marker); then $Change rewrites the archive from outside ('' = not at
# all); then $Then: 'refresh' (Ctrl+R: "has changed, reopened" and the update) or 'leave' (Backspace).
# The Archive Update dialog's list is read: x.txt's line is plain or carries the warning.
function Run-Case([string]$N, [string[]]$Change, [string]$Then, [bool]$WantMark, [string]$Note, [string]$ArcName = 't.zip') {
    if ($Only -and $Only -notcontains $N) { return }
    $dir = $Root + '\' + $N
    [void][IO.Directory]::CreateDirectory($dir)
    $arc = $dir + '\' + $ArcName
    [void](ArcFix @('make', $arc, 'x.txt=1', 'y.txt=2'))
    $before = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    Out ''
    Out ("--- {0}: {1}" -f $N, $Note)
    $id = 0; $verdict = 'NOT DRIVEN'; $why = ''
    try {
        $id = Start-Tc153 $dir
        [void](Serve $id 6)
        $ok = Do-ChangeDir $id $arc
        $r = Serve $id 30
        Out ("   cd t.zip (field held it: {0}); title '{1}'; windows: {2}" -f $ok, (Tail (Title $id) 40), (MsgText $r))
        KeyP $id 0 0x24; KeyP $id 0 0x28; Settle $id 800
        Post-Cmd (Get-Main $id) 743   # CM_EDIT on x.txt
        Start-Sleep -Milliseconds 3000
        $r = Serve $id 20
        Out ("   F4 x.txt: windows: {0}" -f (MsgText $r))
        if ($Change.Count) {
            Start-Sleep -Milliseconds 1500
            if ($Change[0] -eq 'CORRUPT') { [void](ArcFix @('corrupt', $arc)) } else { [void](ArcFix (@('make', $arc) + $Change)) }
            Start-Sleep -Milliseconds 1500
            Out ("   the archive rewritten from outside: {0}" -f ($Change -join ' '))
        }
        if ($Then -eq 'refresh') { Post-Cmd (Get-Main $id) 740 } else { PostKeyP $id 0 0x08 }
        Start-Sleep -Milliseconds 1500
        $r = Serve $id 60
        Out ("   {0}: windows: {1}" -f $Then, (MsgText $r))
        $lists = @($r.Messages | Where-Object { "$_".StartsWith('[Archive Update list] ') })
        if (-not $lists.Count) { $verdict = 'FAIL'; $why = 'no Archive Update dialog' }
        else {
            $items = @("$($lists[0])".Substring(22) -split ' \|\| ')
            $xLine = @($items | Where-Object { "$_".StartsWith('x.txt') }) | Select-Object -First 1
            $marked = $xLine -and $xLine -ne 'x.txt'
            $verdict = $(if ($marked -eq $WantMark) { 'PASS' } else { 'FAIL' })
            $why = ("x.txt's line '{0}' ({1}; want {2})" -f (Esc $xLine), $(if ($marked) { 'marked' } else { 'plain' }), $(if ($WantMark) { 'marked' } else { 'plain' }))
        }
        foreach ($l in (ArcFix @('read', $arc, $Marker))) { Out ("   t.zip: {0}" -f $l) }
        [void][Drv153]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $id)) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv153]::Cls($_) -eq '#32770' })) { $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv153]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
            Start-Sleep -Milliseconds 200
        }
        if (Test-Alive $id) { Kill-Mine $id; $why += '; did not exit in 30 s' ; $verdict = 'FAIL' }
        Start-Sleep -Milliseconds 700
        $ec = ExitCodeOf $id
        $new = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Where-Object { $before -notcontains $_ })
        foreach ($n2 in $new) { Remove-Item -LiteralPath (Join-Path $ReportDir $n2) -Force -ErrorAction SilentlyContinue }
        if ($ec -ne '0x00000000' -or $new.Count) { $verdict = 'FAIL'; $why += ("; exit {0}, crash reports {1}" -f $ec, $new.Count) }
    }
    catch { $verdict = 'FAIL'; $why = 'exception: ' + $_.Exception.Message }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        foreach ($t in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp') | Where-Object { $script:TmpBefore -notcontains $_ })) { try { [IO.Directory]::Delete($t, $true) } catch { } }
    }
    Out ("   VERDICT: {0} {1}" -f $verdict, $why)
    [void]$script:Table.Add([pscustomobject]@{ Case = $N; Verdict = $verdict; Why = $why })
}

# ---- main ---------------------------------------------------------------------
$script:Table = New-Object System.Collections.ArrayList
$script:TmpBefore = @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp'))
$backupDir = $TempRoot + '\tc153\reg'
[void][IO.Directory]::CreateDirectory($backupDir)
$backup = Join-Path $backupDir 'backup.reg'
$existed = Backup-TcRegistry $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $fresh = Set-ProbeConfig
    Out ("member_changed_probe (feature 153) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; F4 editor = cmd.exe /c echo {2}>>`"`$(FullName)`"; Fixed Automatic Refresh = 0" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $deskName, $Marker)
    if ($fresh) { throw 'no stored configuration - the F4 editor cannot be configured' }
    Run-Case 'x-changed' @('x.txt=9', 'y.txt=2') 'refresh' $true 'x.txt changed in the archive, Ctrl+R: x.txt marked'
    Run-Case 'x-deleted' @('y.txt=2') 'refresh' $true 'x.txt removed from the archive, Ctrl+R: x.txt marked'
    Run-Case 'y-changed' @('x.txt=1', 'y.txt=7') 'refresh' $false 'only y.txt changed (x.txt written again as it was), Ctrl+R: x.txt plain'
    Run-Case 'same' @('x.txt=1', 'y.txt=2') 'refresh' $false 'the archive written again with the same members, Ctrl+R: x.txt plain'
    Run-Case 'untouched' @() 'leave' $false 'the archive not changed, leave: x.txt plain'
    Run-Case 'x-same-stamp' @('x.txt=9:1', 'y.txt=2') 'refresh' $false 'LIMIT: x.txt another content with the size and time it had - not told apart, plain'
    # review of 153: a listing that fails (the 7zip plug-in left its deleted data behind) - no crash, marked
    Run-Case 'zip-corrupt' @('CORRUPT') 'refresh' $true 'the archive unreadable after the F4, Ctrl+R: no crash, x.txt marked (cannot be told)'
    Run-Case '7z-changed' @('x.txt=9', 'y.txt=2') 'refresh' $true 'a 7z archive (the 7zip plug-in), x.txt changed, Ctrl+R: x.txt marked' 't.7z'
    Run-Case '7z-same' @('x.txt=1', 'y.txt=2') 'refresh' $false 'a 7z archive written again with the same members, Ctrl+R: x.txt plain' 't.7z'
    Run-Case '7z-corrupt' @('CORRUPT') 'refresh' $true 'a 7z archive unreadable after the F4, Ctrl+R: no crash (the use after free of the review), x.txt marked' 't.7z'
    Run-Case 'x-changed-leave' @('x.txt=9', 'y.txt=2') 'leave' $true 'x.txt changed in the archive, leave without a refresh: x.txt marked'
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
    foreach ($t in $script:Table) { Out ('{0,-16} {1,-10} {2}' -f $t.Case, $t.Verdict, $t.Why) }
    $nPass = @($script:Table | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nFail = @($script:Table | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ("TOTAL: {0} PASS / {1} FAIL" -f $nPass, $nFail)
    Out ("Left running: {0}; fixture removed: {1}; registry restored+identical: {2}" -f $leftover.Count, (-not [IO.Directory]::Exists($Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit 0
