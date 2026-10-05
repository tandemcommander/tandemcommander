<#
.SYNOPSIS
    Feature 112 probe: a flush of the disk cache must not throw away a temporary copy with a
    pending edit (NEXT-WORK item 5, queue entries 2a and 3).

.DESCRIPTION
    One archive t.<fmt> holding x.txt (member tag 1) and y.txt (tag 2), both panels in the case's
    folder. The left panel (L) opens x.txt for editing (F4) and keeps it pending; then the right
    panel (R) flushes the archive's copies - by updating the archive itself (own-*: F4 y.txt +
    leave + Update) or by reopening it after another program rewrote it (ext-*: rewrite + Ctrl+R in
    R) - and then L looks the member up again (F3 / F4). Before feature 112 that look-up deleted
    L's edited copy and extracted the member over it; the time stamp then matched and nothing was
    offered at L's leave - the edit was lost without a word.

    The window opens only when L does NOT refresh in between (its own refresh reopens the archive
    and packs first). So every row sets its own refresh configuration in the probe's registry
    fixture (Configuration\Drive Special Settings):
      off : Fixed Automatic Refresh = 0          (the archive's folder is not watched)
      net : the archive opened through a "net use" drive (\\localhost\C$\...), Remote Automatic
            Refresh = 0 and Remote Do Not Refresh on Activation = 1 (no refresh on activation
            either - used when the hidden desktop delivers activation refreshes)
      on  : the defaults (controls: L must refresh and pack first)
    The probe DETECTS whether L refreshed anyway: L is the only panel with pending edits, so any
    "Archive file ... has changed. Archive will be reopened" box (IDS_ARCHIVEREFRESHEDIT) means L
    reopened the archive - the row is then CLOSED (not driven), or for a control row the expected
    outcome.

    Steps, driven by window messages on the hidden desktop, each in a given panel (Tab switches):
      cd      : Change Directory (command 862) to the archive ({DIR}\t.zip, or {NET}\t.zip)
      f4 n    : Home, Down x n (1 = x.txt, 2 = y.txt), CM_EDIT (743); the F4 editor is
                cmd.exe /c echo edited112>>"$(FullName)"
      f3 n    : Home, Down x n, CM_VIEW (742); the viewer for *.* is external:
                cmd.exe /c type "$(FullName)">>"%TEMP%\tc112\view.log" - what each F3 was given
      leave   : Backspace out of the archive; every window is recorded and answered OK / Yes
                (Archive Update: Update)
      rewrite : the archive is made anew from outside (arcfix.py; Arg = tag of x.txt, y.txt = Arg+1)
      refresh : CM_ACTIVEREFRESH (740, Ctrl+R) in the step's panel
    Verdict per row: the tag and the number of edit markers of each member read back from the
    archive (arcfix.py), what each F3 was given, whether a leave offered an Archive Update.
    Rows (zip unless named):
      own-F3       L F4 x; R F4 y; R leave (Update); L F3 x; L leave
                   before 112: F3 given x without the edit, nothing offered at L's leave, x lost the edit
      own-F4       ... L F4 x again; L leave: both edits of L packed (before: the first one lost)
      own-F3_7z    own-F3 on a 7z archive
      own-reenter  ... R enters the changed archive again, F3 x there: R's key is unique since 109
                   (size/time differ from L's listing), R gets the archive's x; L's edit is packed -
                   passes on both builds (the R-side trigger of research.md S1 is closed by 109)
      ext-ctrlR    L F4 x; R on the archive; rewrite (same content, new time); R Ctrl+R; L F3 x; L leave
      ext-x        the same, the rewrite changes x.txt (tag 9): L's pending edit on the old content is
                   kept and offered (it overwrites the external x - the 096 behaviour, documented)
      shared       L F4 x; R F4 x (the same copy); R leave; L F3 x; L leave: both edits
      stamp-race   L F3 x; L F4 x (the copy exists: its stamp was read AFTER the editor started); L leave
      *-auto       controls with the default refresh: L reopens first (window detected), no loss
      *@net        the loss rows through a network drive with no refresh at all
    Helper block copied from specs/109-disk-cache-archive-key/probe/diskcache_probe.ps1 (itself from
    094/096/108). MUST be started through tools\run_on_hidden_desktop.ps1. Refuses to run while a
    tandemcommander.exe other than -Exe is running. HKCU\Software\Tandem Commander is exported
    before, restored and verified after. Creates and removes a network drive (first free of W, Y, X)
    for the @net rows; existing mappings are never touched.

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
$Root = $TempRoot + '\tc112\dc'
$ViewLog = $TempRoot + '\tc112\view.log'
$ReportDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$Marker = 'edited112'
$ArcFix = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\108-archive-edit-name-collision\probe\arcfix.py'))
$DrvKey = "$RegKey\0.1\Configuration\Drive Special Settings"
$Members = @('x.txt', 'y.txt')
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

# the refresh configuration of one row (read by the program at start; the registry is restored at the end)
function Set-RefreshConfig([string]$Mode) {
    $fixed = $(if ($Mode -eq 'on') { 1 } else { 0 })
    $remote = $(if ($Mode -eq 'net') { 0 } else { 1 })
    $noAct = $(if ($Mode -eq 'net') { 1 } else { 0 })
    & reg.exe add $DrvKey /v 'Fixed Automatic Refresh' /t REG_DWORD /d $fixed /f | Out-Null
    & reg.exe add $DrvKey /v 'Remote Automatic Refresh' /t REG_DWORD /d $remote /f | Out-Null
    & reg.exe add $DrvKey /v 'Remote Do Not Refresh on Activation' /t REG_DWORD /d $noAct /f | Out-Null
    return ("Fixed Automatic Refresh={0}, Remote Automatic Refresh={1}, Remote Do Not Refresh on Activation={2}" -f $fixed, $remote, $noAct)
}

function Invoke-ArcFix([string]$Verb, [string]$Arc, [string]$Fmt, [string[]]$Members, [int]$First = 1) {
    $spec = $TempRoot + '\tc112\spec.json'
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

# (re)maps the probe's own network drive (first free of W, Y, X) to \\localhost\<drive>$\<path of Target>;
# existing mappings are never touched (a letter in use - also a remembered one - makes net use fail)
function Set-NetDrive([string]$Target) {
    $unc = '\\localhost\' + $Target.Substring(0, 1) + '$\' + $Target.Substring(3)
    if ($script:NetDrive) { return [IO.Directory]::Exists($script:NetDrive + '\') }
    foreach ($l in @('W', 'Y', 'X')) {
        if ([IO.Directory]::Exists($l + ':\')) { continue }
        & cmd.exe /c "net use $($l): `"$unc`" /persistent:no >nul 2>&1"
        if ($LASTEXITCODE -eq 0) {
            if ([IO.Directory]::Exists($l + ':\')) { $script:NetDrive = $l + ':'; return $true }
            # the mapping this call made is not usable: removed before the next letter is tried (review NIT4)
            & cmd.exe /c "net use $($l): /delete /y >nul 2>&1"
            Out ("NET USE : {0} mapped but not reachable - removed (exists now: {1})" -f ($l + ':'), [IO.Directory]::Exists($l + ':\'))
        }
    }
    return $false
}
function Remove-NetDrive {
    if ($script:NetDrive) { & cmd.exe /c "net use $($script:NetDrive) /delete /y >nul 2>&1"; Out ("NET USE : {0} removed (exists now: {1})" -f $script:NetDrive, [IO.Directory]::Exists($script:NetDrive + '\')); $script:NetDrive = $null }
}
# {DIR} the case folder, {NET} a network drive mapped to it (\\localhost\C$\...)
function Resolve-Path112([string]$Text, [string]$Dir, [ref]$Why) {
    $t = $Text.Replace('{DIR}', $Dir)
    if ($t.Contains('{NET}')) {
        if ($Dir -notmatch '^[A-Za-z]:\\') { $Why.Value = 'the folder is not on a drive letter'; return $null }
        if (-not (Set-NetDrive $Dir)) { $Why.Value = 'no free letter for net use (W, Y, X) or \\localhost\C$ not reachable'; return $null }
        $t = $t.Replace('{NET}', $script:NetDrive)
    }
    return $t
}

function Start-Tc112([string]$Dir) {
    $a = @('-t', 'T112', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Dir), '-p', '1')
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

$RefreshedRx = 'has changed\. Archive will be reopened'   # IDS_ARCHIVEREFRESHEDIT - only L has pending edits
$UpdateRx = "'Archive Update'"                            # the title of the Archive Update dialog (WinDesc)

$script:Table = New-Object System.Collections.ArrayList
function Run-Steps($c) {
    $N = $c.N
    $dir = $Root + '\' + $N.Replace('@', '_')
    [void][IO.Directory]::CreateDirectory($dir)
    $arcPath = $dir + '\' + $c.Arc
    [void](Invoke-ArcFix 'make' $arcPath $c.Fmt $Members 1)
    if ([IO.File]::Exists($ViewLog)) { [IO.File]::Delete($ViewLog) }
    $tmpBefore = @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp'))
    $before = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    Out ''
    Out ("--- {0}: '{1}' (x.txt tag 1, y.txt tag 2); refresh mode {2}{3}" -f $N, $c.Arc, $c.Mode, $(if ($c.Control) { ' (control: L must refresh first)' } else { '' }))
    $row = [ordered]@{ Case = $N; Verdict = 'NOT DRIVEN'; Archive = '-'; Views = '-'; Offers = '-'; Why = '' }
    $id = 0
    $views = @(); $stepMsgs = @{}
    try {
        $paths = @{}
        for ($i = 0; $i -lt $c.Steps.Count; $i++) {
            $s = $c.Steps[$i]
            if ($s.Op -eq 'cd') {
                $why = ''
                $p = Resolve-Path112 $s.Arg.Replace('{A}', $c.Spelling + '\' + $c.Arc) $dir ([ref]$why)
                if ($null -eq $p) { throw ('spelling not available: ' + $why) }
                $paths[$i] = $p
            }
        }
        Out ('   config: ' + (Set-RefreshConfig $c.Mode))
        $id = Start-Tc112 $dir
        $r0 = Serve $id 6
        if ($r0.Messages.Count) { Out ('   at start: ' + (MsgText $r0)) }
        if ((Get-Lists $id).Count -ne 2) { throw 'two panel lists not found' }
        $active = 0
        for ($i = 0; $i -lt $c.Steps.Count; $i++) {
            $s = $c.Steps[$i]
            if ($s.P -ne $active) {
                PostKeyP $id $active 0x09; Start-Sleep -Milliseconds 800
                $rt = Serve $id 10
                if ($rt.Messages.Count) { $stepMsgs[$i] += @($rt.Messages); Out ('   panel switch: ' + (MsgText $rt)) }
                $active = $s.P
            }
            $note = ''; $r = $null
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
                    $downs = [int]$s.Arg
                    $acted = $false
                    for ($try = 0; $try -lt 2 -and -not $acted; $try++) {
                        if ($try -eq 1) { $script:Retries++; Out ('   ' + $s.Op.ToUpper() + ' RETRY: the first post was not acted on; posted again after a 1.5 s idle wait') }
                        KeyP $id $s.P 0x24
                        for ($k = 0; $k -lt $downs; $k++) { KeyP $id $s.P 0x28 }
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
                    $mem = $Members[$downs - 1]
                    if ($s.Op -eq 'f3') {
                        $txt = ViewSince $v0
                        $m = [regex]::Match($txt, 'content-of-member-(\d+)')
                        $vt = $(if ($m.Success) { $m.Groups[1].Value } else { '?' })
                        $vm = ([regex]::Matches($txt, $Marker)).Count
                        $views += [pscustomobject]@{ Step = $i; Tag = $vt; Markers = $vm }
                        $note = ("F3 {0} in panel {1}: the viewer was given tag {2} with {3} edit(s); windows: {4}" -f $mem, $s.P, $vt, $vm, (MsgText $r))
                    }
                    else { $note = ("F4 {0} in panel {1}: windows: {2}" -f $mem, $s.P, (MsgText $r)) }
                    if ($r.Fatal) { throw ('FATAL window: ' + (MsgText $r)) }
                }
                'rewrite' {
                    # another program replaces the archive: x.txt gets tag Arg, y.txt Arg+1 (Arg 1 = the same
                    # content, only the time changes)
                    Start-Sleep -Milliseconds 1200
                    [void](Invoke-ArcFix 'make' $arcPath $c.Fmt $Members ([int]$s.Arg))
                    Start-Sleep -Milliseconds 2500
                    Settle $id 1500
                    $r = Serve $id 20
                    $note = ("rewrote {0} from outside (x.txt tag {1}); windows: {2}" -f $c.Arc, $s.Arg, (MsgText $r))
                }
                'refresh' {
                    Post-Cmd (Get-Main $id) 740 # CM_ACTIVEREFRESH: the active panel
                    Start-Sleep -Milliseconds 1500
                    Settle $id 1000
                    $r = Serve $id 30
                    $note = ("Ctrl+R in panel {0}: title '{1}'; windows: {2}" -f $s.P, (Tail (Title $id) 40), (MsgText $r))
                    if ($r.Fatal) { throw ('FATAL window: ' + (MsgText $r)) }
                }
                'leave' {
                    PostKeyP $id $s.P 0x08; Start-Sleep -Milliseconds 1000
                    $r = Serve $id 60
                    $note = ("leave panel {0}: title '{1}'; windows: {2}" -f $s.P, (Tail (Title $id) 40), (MsgText $r))
                    if ($r.Fatal) { throw ('FATAL window: ' + (MsgText $r)) }
                }
            }
            if ($r) { $stepMsgs[$i] += @($r.Messages) }
            $snap = Find-Tmp $tmpBefore
            Out ("   step {0} [{1}{2} P{3}]: {4}" -f $i, $s.Op, $(if ($null -ne $s.Arg -and $s.Op -ne 'cd') { ' ' + $s.Arg } else { '' }), $s.P, $note)
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
        $refreshedAt = @($stepMsgs.Keys | Where-Object { @($stepMsgs[$_] | Where-Object { $_ -match $RefreshedRx }).Count } | Sort-Object)
        $read = Invoke-ArcFix 'read' $arcPath $c.Fmt $Members
        foreach ($l in $read) { Out ("          {0}: {1}" -f $c.Arc, $l) }
        $e = @($read | Where-Object { $_ -like 'ENTRY *' } | ForEach-Object { $mm = [regex]::Match($_, '^ENTRY (.*) tag=(\S+) markers=(\d+) size=(\d+)$'); [pscustomobject]@{ Name = $mm.Groups[1].Value; Tag = $mm.Groups[2].Value; Markers = [int]$mm.Groups[3].Value } })
        foreach ($mn in $Members) {
            $exp = $c.Final[$mn]
            $got = @($e | Where-Object { $_.Name -eq $mn })
            if ($got.Count -ne 1) { $why += ("{0}: {1} entries (expected 1)" -f $mn, $got.Count); continue }
            $desc += ("{0}=m{1}+{2}" -f $mn, $got[0].Tag, $got[0].Markers)
            if ($got[0].Tag -ne [string]$exp[0]) { $why += ("{0} holds member {1} (expected {2})" -f $mn, $got[0].Tag, $exp[0]) }
            if ($got[0].Markers -ne $exp[1]) { $why += ("{0}: {1} edit(s) packed (expected {2})" -f $mn, $got[0].Markers, $exp[1]) }
        }
        if ($e.Count -ne $Members.Count) { $why += ("{0} entries in the archive (expected {1})" -f $e.Count, $Members.Count) }
        $k = 0
        foreach ($v in $views) {
            $exp = $c.Views[$k]; $k++
            if ($null -eq $exp) { continue }
            if ($v.Tag -ne [string]$exp.Tag -or $v.Markers -ne $exp.Markers) { $why += ("F3 at step {0} was given tag {1} with {2} edit(s) (expected tag {3} with {4})" -f $v.Step, $v.Tag, $v.Markers, $exp.Tag, $exp.Markers) }
        }
        if ($c.Views -and $views.Count -ne $c.Views.Count) { $why += ("{0} F3 results (expected {1})" -f $views.Count, $c.Views.Count) }
        $offers = @()
        if ($c.Offers) {
            foreach ($key in ($c.Offers.Keys | Sort-Object)) {
                $got = @($stepMsgs[$key] | Where-Object { $_ -match $UpdateRx }).Count -gt 0
                $offers += ("s{0}={1}" -f $key, $(if ($got) { 'offered' } else { 'none' }))
                if ($got -ne $c.Offers[$key]) { $why += ("step {0}: Archive Update {1} (expected {2})" -f $key, $(if ($got) { 'offered' } else { 'not offered' }), $(if ($c.Offers[$key]) { 'offered' } else { 'not offered' })) }
            }
        }
        if ($new.Count) { $why += "$($new.Count) crash report(s)" }
        $row.Archive = ($desc -join ' ')
        $row.Views = $(if ($views.Count) { ($views | ForEach-Object { "t{0}+{1}" -f $_.Tag, $_.Markers }) -join ',' } else { '-' })
        $row.Offers = $(if ($offers.Count) { $offers -join ',' } else { '-' })
        if ($refreshedAt.Count) { Out ("   the left panel reopened the archive (IDS_ARCHIVEREFRESHEDIT) at step(s) {0}" -f ($refreshedAt -join ', ')) }
        if ($c.Control) {
            if (-not $refreshedAt.Count) { $why += 'control: the left panel did not reopen the archive (no IDS_ARCHIVEREFRESHEDIT)' }
            $row.Verdict = $(if ($why.Count) { 'FAIL' } else { 'PASS' })
        }
        elseif ($refreshedAt.Count) {
            $row.Verdict = 'CLOSED'
            $why = @(("the left panel reopened the archive at step(s) {0} - the window was closed, row not driven" -f ($refreshedAt -join ', '))) + $why
        }
        else { $row.Verdict = $(if ($why.Count) { 'FAIL' } else { 'PASS' }) }
        $row.Why = ($why -join '; ')
        Out ("   VERDICT: {0} {1}" -f $row.Verdict, $row.Why)
    }
    catch { Out ('   exception: ' + $_.Exception.Message); $row.Why = 'NOT DRIVEN (no evidence either way): ' + $_.Exception.Message }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        Start-Sleep -Milliseconds 300
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
$backupDir = $TempRoot + '\tc112\reg'
[void][IO.Directory]::CreateDirectory($backupDir)
$backup = Join-Path $backupDir 'backup.reg'
$existed = Backup-TcRegistry $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $fresh = Set-ProbeConfig
    Out ("diskcache_edit_probe (feature 112) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; desktop '{2}'" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv093]::GetACP(), $deskName)
    Out ("Config  : registry key existed {0}; fresh defaults {1}; F4 editor = cmd.exe /c echo {2}>>`"`$(FullName)`"; F3 viewer = cmd.exe /c type `"`$(FullName)`">>view.log" -f $existed, $fresh, $Marker)
    if ($fresh) { throw 'no stored configuration - the F4 editor cannot be configured' }
    # steps: P = panel (0 = left L, 1 = right R); Arg of f3/f4 = Down presses (1 = x.txt, 2 = y.txt)
    $cdA = { param($p) @{ P = $p; Op = 'cd'; Arg = '{A}' } }
    $ownHead = @((& $cdA 0), @{ P = 0; Op = 'f4'; Arg = 1 }, (& $cdA 1), @{ P = 1; Op = 'f4'; Arg = 2 }, @{ P = 1; Op = 'leave' })
    $extHead = @((& $cdA 0), @{ P = 0; Op = 'f4'; Arg = 1 }, (& $cdA 1))
    $cases = @()
    $variants = @(@{ Sfx = ''; Mode = 'off'; Spelling = '{DIR}' }, @{ Sfx = '@net'; Mode = 'net'; Spelling = '{NET}' })
    foreach ($vr in $variants) {
        # S1 F3: L's pending edit, R's own update of y.txt, then L's F3 of x.txt
        $cases += @{ N = ('own-F3' + $vr.Sfx); Arc = 't.zip'; Fmt = 'zip'; Mode = $vr.Mode; Spelling = $vr.Spelling
            Steps = $ownHead + @(@{ P = 0; Op = 'f3'; Arg = 1 }, @{ P = 0; Op = 'leave' })
            Views = @(@{ Tag = 1; Markers = 1 }); Final = @{ 'x.txt' = @(1, 1); 'y.txt' = @(2, 1) }; Offers = @{ 4 = $true; 6 = $true } }
        # S1 F4: L's second F4 of x.txt after R's update
        $cases += @{ N = ('own-F4' + $vr.Sfx); Arc = 't.zip'; Fmt = 'zip'; Mode = $vr.Mode; Spelling = $vr.Spelling
            Steps = $ownHead + @(@{ P = 0; Op = 'f4'; Arg = 1 }, @{ P = 0; Op = 'leave' })
            Final = @{ 'x.txt' = @(1, 2); 'y.txt' = @(2, 1) }; Offers = @{ 4 = $true; 6 = $true } }
        # S4: another program rewrites the archive (same content / x.txt changed), R refreshes (Ctrl+R)
        $cases += @{ N = ('ext-ctrlR' + $vr.Sfx); Arc = 't.zip'; Fmt = 'zip'; Mode = $vr.Mode; Spelling = $vr.Spelling
            Steps = $extHead + @(@{ P = 1; Op = 'rewrite'; Arg = 1 }, @{ P = 1; Op = 'refresh' }, @{ P = 0; Op = 'f3'; Arg = 1 }, @{ P = 0; Op = 'leave' })
            Views = @(@{ Tag = 1; Markers = 1 }); Final = @{ 'x.txt' = @(1, 1); 'y.txt' = @(2, 0) }; Offers = @{ 6 = $true } }
        $cases += @{ N = ('ext-x' + $vr.Sfx); Arc = 't.zip'; Fmt = 'zip'; Mode = $vr.Mode; Spelling = $vr.Spelling
            Steps = $extHead + @(@{ P = 1; Op = 'rewrite'; Arg = 9 }, @{ P = 1; Op = 'refresh' }, @{ P = 0; Op = 'f3'; Arg = 1 }, @{ P = 0; Op = 'leave' })
            Views = @(@{ Tag = 1; Markers = 1 }); Final = @{ 'x.txt' = @(1, 1); 'y.txt' = @(10, 0) }; Offers = @{ 6 = $true } }
    }
    $cases += @{ N = 'own-F3_7z'; Arc = 't.7z'; Fmt = '7z'; Mode = 'off'; Spelling = '{DIR}'
        Steps = $ownHead + @(@{ P = 0; Op = 'f3'; Arg = 1 }, @{ P = 0; Op = 'leave' })
        Views = @(@{ Tag = 1; Markers = 1 }); Final = @{ 'x.txt' = @(1, 1); 'y.txt' = @(2, 1) }; Offers = @{ 4 = $true; 6 = $true } }
    # R re-enters the changed archive: since 109 its key is unique (size/time differ from L's listing),
    # so R gets the archive's x.txt and never touches L's copy - both builds
    $cases += @{ N = 'own-reenter'; Arc = 't.zip'; Fmt = 'zip'; Mode = 'off'; Spelling = '{DIR}'
        Steps = $ownHead + @((& $cdA 1), @{ P = 1; Op = 'f3'; Arg = 1 }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'leave' })
        Views = @(@{ Tag = 1; Markers = 0 }); Final = @{ 'x.txt' = @(1, 1); 'y.txt' = @(2, 1) }; Offers = @{ 4 = $true; 8 = $true } }
    # S6: both panels track one copy; R's F4 meets an existing copy (its stamp: before the editor
    # since 112; R must offer x.txt at its leave)
    $cases += @{ N = 'shared'; Arc = 't.zip'; Fmt = 'zip'; Mode = 'off'; Spelling = '{DIR}'
        Steps = @((& $cdA 0), @{ P = 0; Op = 'f4'; Arg = 1 }, (& $cdA 1), @{ P = 1; Op = 'f4'; Arg = 1 }, @{ P = 1; Op = 'leave' }, @{ P = 0; Op = 'f3'; Arg = 1 }, @{ P = 0; Op = 'leave' })
        Views = @(@{ Tag = 1; Markers = 2 }); Final = @{ 'x.txt' = @(1, 2); 'y.txt' = @(2, 0) }; Offers = @{ 4 = $true; 6 = $true } }
    # queue entry 3 / research 2: F3 first, then F4 of the same member in one panel - the copy exists, its
    # stamp was read AFTER the editor started (a fast editor's write became part of the stamp)
    $cases += @{ N = 'stamp-race'; Arc = 't.zip'; Fmt = 'zip'; Mode = 'off'; Spelling = '{DIR}'
        Steps = @((& $cdA 0), @{ P = 0; Op = 'f3'; Arg = 1 }, @{ P = 0; Op = 'f4'; Arg = 1 }, @{ P = 0; Op = 'leave' })
        Views = @(@{ Tag = 1; Markers = 0 }); Final = @{ 'x.txt' = @(1, 1); 'y.txt' = @(2, 0) }; Offers = @{ 3 = $true } }
    # controls: the default refresh - L reopens the archive (and packs) before its look-up
    $cases += @{ N = 'own-F3-auto'; Arc = 't.zip'; Fmt = 'zip'; Mode = 'on'; Spelling = '{DIR}'; Control = $true
        Steps = $ownHead + @(@{ P = 0; Op = 'f3'; Arg = 1 }, @{ P = 0; Op = 'leave' })
        Views = @(@{ Tag = 1; Markers = 1 }); Final = @{ 'x.txt' = @(1, 1); 'y.txt' = @(2, 1) } }
    $cases += @{ N = 'ext-ctrlR-auto'; Arc = 't.zip'; Fmt = 'zip'; Mode = 'on'; Spelling = '{DIR}'; Control = $true
        Steps = $extHead + @(@{ P = 1; Op = 'rewrite'; Arg = 1 }, @{ P = 1; Op = 'refresh' }, @{ P = 0; Op = 'f3'; Arg = 1 }, @{ P = 0; Op = 'leave' })
        Views = @(@{ Tag = 1; Markers = 1 }); Final = @{ 'x.txt' = @(1, 1); 'y.txt' = @(2, 0) } }
    if ($Only) { $cases = $cases | Where-Object { $Only -contains $_.N } }
    foreach ($c in $cases) { Run-Steps $c }
}
catch { Out ('FATAL: ' + $_.Exception.Message) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 500
    Remove-NetDrive
    $restored = Restore-TcRegistry $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if ($restored -and (Test-Path -LiteralPath $backupDir)) { Remove-Item -LiteralPath $backupDir -Recurse -Force }
    try { if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) } } catch { Out ("Fixture : could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    Out ''
    Out '=== summary ==='
    Out ('{0,-16} {1,-10} {2}' -f 'case', 'verdict', 'archive (member=tag+edits) | F3 given | Archive Update per leave step | why')
    foreach ($t in $script:Table) {
        Out ('{0,-16} {1,-10} {2} | {3} | {4}{5}' -f $t.Case, $t.Verdict, $t.Archive, $t.Views, $t.Offers, $(if ($t.Why) { ' | ' + $t.Why } else { '' }))
    }
    $nPass = @($script:Table | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nFail = @($script:Table | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nClosed = @($script:Table | Where-Object { $_.Verdict -eq 'CLOSED' }).Count
    $nNd = @($script:Table | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ("TOTAL: {0} PASS / {1} FAIL / {2} CLOSED / {3} NOT DRIVEN; F3/F4 retries {4}" -f $nPass, $nFail, $nClosed, $nNd, $script:Retries)
    Out ("Left running: {0}; fixture removed: {1}; registry restored+identical: {2}" -f $leftover.Count, (-not [IO.Directory]::Exists($Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit 0
