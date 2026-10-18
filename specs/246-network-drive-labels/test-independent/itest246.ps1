<#
.SYNOPSIS
    Independent black-box test of feature 246 (network drive names, disconnected icons,
    drive bar catch-up on activation). Written by an independent tester, not the implementer.

.DESCRIPTION
    Phase A  fixture: 7 network drives (connected unnamed / connected named / remembered-unavailable
             localhost named / remembered unreachable \\192.0.2.1\x named / \\192.0.2.1\y unnamed /
             connected Cyrillic folder unnamed / remembered-unavailable Cyrillic+CJK folder unnamed).
    Phase B  performance, both builds, same fixture, seam OFF, two rounds each (B,F,B,F):
             Change Drive menu opening time (post WM_COMMAND 707 -> visible PopupMenuClass),
             activation time (WM_ACTIVATEAPP 0/1 + WM_NULL round trip; and activation + menu FIFO),
             menu screenshots of round 1 for OCR (local drives, case 8) and the Cyrillic rows (case 5).
    Phase C  functional, fixed build with the seam: + 12 edge-case drives (names), texts, tooltips,
             deletion while running, 20 quiet activations, single bar / hidden bars, picking.
    Phase D  baseline picks the unreachable unnamed drive first (fresh; blocking time, INFO) -
             runs before phase C.
    Phase E  baseline picks the drive the fixed build picked in phase C (SMB negative cache, INFO).

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while tandemcommander.exe runs.
    Backs up and restores HKCU\Software\Tandem Commander (SHA-256 verified). Removes every mapping,
    remembered connection, HKCU\Network key, MountPoints2 key and folder it created and verifies
    against a snapshot taken before.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Fixed,
    [Parameter(Mandatory = $true)][string]$Baseline,
    [Parameter(Mandatory = $true)][string]$OutFile,
    [int]$Rounds = 2,
    [int]$PerRound = 6,
    [switch]$SkipBaselinePick,
    [switch]$Quick   # round 3: fixture, menu texts, tooltips, C9 boundaries, clean exit only
)
$ErrorActionPreference = 'Stop'
$Fixed = (Resolve-Path -LiteralPath $Fixed).Path
$Baseline = (Resolve-Path -LiteralPath $Baseline).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

$Exe = $Fixed
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
. (Join-Path $repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $repo 'specs\124-regedt-key-text\probe\shotocr_lib.ps1')

if (-not ('Tst246' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;
public static class Tst246
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public class NETRESOURCE { public int dwScope, dwType, dwDisplayType, dwUsage; public string lpLocalName, lpRemoteName, lpComment, lpProvider; }
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetAddConnection2W(NETRESOURCE nr, string pwd, string user, int flags);
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetCancelConnection2W(string name, int flags, bool force);
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetGetConnectionW(string local, StringBuilder remote, ref int len);
    [DllImport("kernel32.dll")] public static extern uint GetLogicalDrives();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowW(string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowExW(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)] static extern int RegSetValueExW(SafeRegistryHandle h, string name, int reserved, int type, byte[] data, int cb);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct SHFILEINFO { public IntPtr hIcon; public int iIcon; public uint dwAttributes; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szDisplayName; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)] public string szTypeName; }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SHGetFileInfoW(string path, uint attr, ref SHFILEINFO sfi, uint cb, uint flags);

    public static int Map(string letter, string remote, bool remember)
    {
        var nr = new NETRESOURCE(); nr.dwType = 1; nr.lpLocalName = letter; nr.lpRemoteName = remote;
        return WNetAddConnection2W(nr, null, null, remember ? 1 : 0);
    }
    public static int Cancel(string letter, bool forget) { return WNetCancelConnection2W(letter, forget ? 1 : 0, true); }
    public static string Conn(string letter, out int res) { var sb = new StringBuilder(4096); int len = 4096; res = WNetGetConnectionW(letter, sb, ref len); return sb.ToString(); }
    public static bool Listed(char letter) { return (GetLogicalDrives() & (1u << (char.ToUpperInvariant(letter) - 'A'))) != 0; }
    public static string ShellName(string path)
    {
        var sfi = new SHFILEINFO();
        IntPtr r = SHGetFileInfoW(path, 0, ref sfi, (uint)Marshal.SizeOf(typeof(SHFILEINFO)), 0x200 | 0x400);
        if (r == IntPtr.Zero) return null;
        return sfi.szDisplayName + " | " + sfi.szTypeName;
    }
    public static int SetRaw(Microsoft.Win32.RegistryKey key, string name, int type, byte[] data) { return RegSetValueExW(key.Handle, name, 0, type, data, data.Length); }

    static IntPtr FindPopup(uint pid)
    {
        IntPtr h = IntPtr.Zero;
        while ((h = FindWindowExW(IntPtr.Zero, h, "PopupMenuClass", null)) != IntPtr.Zero)
        {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid && IsWindowVisible(h)) return h;
        }
        return IntPtr.Zero;
    }
    public static bool AnyPopup(uint pid) { return FindPopup(pid) != IntPtr.Zero; }
    static bool Send(IntPtr h, uint msg, long w, uint timeout) { IntPtr r; return SendMessageTimeoutW(h, msg, (IntPtr)w, IntPtr.Zero, 0, timeout, out r) != IntPtr.Zero; }
    static double WaitPopup(Stopwatch sw, uint pid, int timeoutMs, out IntPtr popup)
    {
        popup = IntPtr.Zero;
        while (sw.ElapsedMilliseconds < timeoutMs)
        {
            IntPtr h = FindPopup(pid);
            if (h != IntPtr.Zero) { popup = h; return sw.Elapsed.TotalMilliseconds; }
            Thread.Sleep(0);
        }
        return -1;
    }
    // ms from posting WM_COMMAND cmd to a visible PopupMenuClass window of pid; -1 on timeout
    public static double TimeMenu(IntPtr main, uint pid, int cmd, int timeoutMs, out IntPtr popup)
    {
        var sw = Stopwatch.StartNew();
        PostMessageW(main, 0x0111, (IntPtr)cmd, IntPtr.Zero);
        return WaitPopup(sw, pid, timeoutMs, out popup);
    }
    // WM_ACTIVATEAPP 0, WM_ACTIVATEAPP 1, WM_NULL (all sent): ms; -1 when a send timed out
    public static double TimeActSync(IntPtr main)
    {
        var sw = Stopwatch.StartNew();
        if (!Send(main, 0x001C, 0, 30000)) return -1;
        if (!Send(main, 0x001C, 1, 30000)) return -1;
        if (!Send(main, 0x0000, 0, 30000)) return -1;
        return sw.Elapsed.TotalMilliseconds;
    }
    // WM_ACTIVATEAPP 0/1 sent, then WM_COMMAND cmd posted: the menu appears only after every message
    // the activation posted before it (FIFO) was handled: ms to the visible popup
    public static double TimeActMenu(IntPtr main, uint pid, int cmd, int timeoutMs, out IntPtr popup)
    {
        popup = IntPtr.Zero;
        var sw = Stopwatch.StartNew();
        if (!Send(main, 0x001C, 0, 30000)) return -2;
        if (!Send(main, 0x001C, 1, 30000)) return -2;
        PostMessageW(main, 0x0111, (IntPtr)cmd, IntPtr.Zero);
        return WaitPopup(sw, pid, timeoutMs, out popup);
    }
}
'@
}

# ---------------------------------------------------------------------------
$Root = $TempRoot + '\tc246test'
$Fx = $Root + '\fx'
$StartDir = $Root + '\start'
$ShotDir = $Root + '\shots'
$RegBackup = $Root + '\reg_backup.reg'
$MP2 = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2'
$CfgKey = 'HKCU\Software\Tandem Commander\0.1\Configuration'
$Utf8 = New-Object Text.UTF8Encoding($false)
$script:Fails = 0
$script:Lines = New-Object System.Collections.ArrayList
$script:Perf = @{}

function RowV([string]$Case, [string]$Step, [bool]$Ok, [string]$Facts) { $v = V $Ok; if (-not $Ok) { $script:Fails++ }; Row $Case $Step $v $Facts }
function UncOf([string]$LocalPath) { return '\\localhost\C$' + $LocalPath.Substring(2) }
function KeyOf([string]$Remote) { return '##' + $Remote.Substring(2).TrimEnd('\').Replace('\', '#') }
function Clean-Name($n) {
    if ($null -eq $n) { return $null }
    $sb = New-Object Text.StringBuilder
    foreach ($c in $n.ToCharArray()) { if ([int]$c -lt 0x20 -or [int]$c -eq 0x7F) { [void]$sb.Append(' ') } else { [void]$sb.Append($c) } }
    return $sb.ToString().Trim(' ')
}
function Exp-Text($Name, [string]$Remote, [bool]$Menu) {
    $n = Clean-Name $Name
    if ($null -eq $n -or $n -eq '' -or [string]::Equals($n, $Remote, [StringComparison]::OrdinalIgnoreCase)) { $t = $Remote } else { $t = $n + ' (' + $Remote + ')' }
    if ($Menu) { $t = $t.Replace('&', '&&') }
    return $t
}
# round 2 tooltip rule: the whole text when it fits 4999 UTF-8 bytes; otherwise the NAME is shortened
# to a whole-character prefix + U+2026 and ' (<exact path>)' stays whole, total <= 4999 bytes.
# Returns Ok, Mode (exact/shortened), Facts. A U+FFFD in the text = a torn character (invalid UTF-8).
$TipLimit = 4999
function Check-Tip($Tip, $Name, [string]$Remote) {
    $full = Exp-Text $Name $Remote $false
    $r = @{ Ok = $false; Mode = ''; Facts = '' }
    if ($null -eq $Tip) { $r.Facts = 'no TIP line'; return $r }
    $tb = $Utf8.GetByteCount($Tip)
    $torn = $Tip.Contains([string][char]0xFFFD)
    if ($Utf8.GetByteCount($full) -le $TipLimit) {
        $r.Mode = 'exact'; $r.Ok = ($Tip -ceq $full) -and -not $torn
        $r.Facts = ('exact expected ({0} bytes); tip {1} bytes; equal {2}; U+FFFD {3}' -f $Utf8.GetByteCount($full), $tb, ($Tip -ceq $full), $torn)
        return $r
    }
    $r.Mode = 'shortened'
    $n = Clean-Name $Name
    $suffix = ' (' + $Remote + ')'
    $endsOk = $Tip.EndsWith($suffix, [StringComparison]::Ordinal)
    $head = if ($endsOk) { $Tip.Substring(0, $Tip.Length - $suffix.Length) } else { '' }
    $ell = $head.Length -gt 0 -and $head[$head.Length - 1] -eq [char]0x2026
    $pre = if ($ell) { $head.Substring(0, $head.Length - 1) } else { '' }
    $isPrefix = $ell -and $pre.Length -lt $n.Length -and $n.StartsWith($pre, [StringComparison]::Ordinal)
    $whole = $isPrefix -and -not ($pre.Length -gt 0 -and [char]::IsHighSurrogate($pre[$pre.Length - 1]))
    $nextLen = 1; if ($isPrefix -and [char]::IsHighSurrogate($n[$pre.Length])) { $nextLen = 2 }
    $maximal = $isPrefix -and ($tb + $Utf8.GetByteCount($n.Substring($pre.Length, [Math]::Min($nextLen, $n.Length - $pre.Length))) -gt $TipLimit)
    $r.Ok = $endsOk -and ($tb -le $TipLimit) -and $ell -and $isPrefix -and $whole -and -not $torn
    $r.Facts = ('full text {0} bytes > {1}; tip {2} bytes; ends with exact path {3}; ellipsis {4}; name prefix {5} of {6} units, whole-character {7}; maximal {8}; U+FFFD {9}; head ends ...{10}' -f $Utf8.GetByteCount($full), $TipLimit, $tb, $endsOk, $ell, $pre.Length, $n.Length, $whole, $maximal, $torn, (Esc $(if ($head.Length -gt 6) { $head.Substring($head.Length - 6) } else { $head })))
    return $r
}
function Short([string]$s, [int]$n = 110) { if ($null -eq $s) { return '<null>' }; if ($s.Length -le $n) { return (Esc $s) }; return ((Esc $s.Substring(0, 40)) + ('...[{0} chars]...' -f $s.Length) + (Esc $s.Substring($s.Length - 50))) }
function Snap {
    $s = [ordered]@{}
    $s.NetUse = ((& net.exe use 2>&1) | Out-String)
    $s.Network = @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName } | Sort-Object) -join ','
    $s.MP2 = @(Get-ChildItem $MP2 -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like '##*' } | ForEach-Object { $_.PSChildName } | Sort-Object) -join '|'
    $s.Drives = '{0:X8}' -f [Tst246]::GetLogicalDrives()
    $s.NetUseEntries = @((& net.exe use 2>&1) | Where-Object { $_ -match '\\\\' } | ForEach-Object { ($_ -replace '\s+', ' ').Trim() }) -join ' ; '
    return $s
}
function Stat($a) {
    $v = @($a | Where-Object { $_ -ge 0 } | Sort-Object)
    if (-not $v.Count) { return 'no samples' }
    $med = if ($v.Count % 2) { $v[[int](($v.Count - 1) / 2)] } else { ($v[$v.Count / 2 - 1] + $v[$v.Count / 2]) / 2 }
    return ('n={0} median={1:N1} ms max={2:N1} ms min={3:N1} ms; all: {4}' -f $v.Count, $med, $v[-1], $v[0], (($a | ForEach-Object { '{0:N0}' -f $_ }) -join ' '))
}
function Median($a) { $v = @($a | Where-Object { $_ -ge 0 } | Sort-Object); if (-not $v.Count) { return -1 }; if ($v.Count % 2) { return $v[[int](($v.Count - 1) / 2)] }; return ($v[$v.Count / 2 - 1] + $v[$v.Count / 2]) / 2 }

# ---- seam dump ----------------------------------------------------------------
$script:Dump = $null
function Dump-Lines {
    if (-not $script:Dump -or -not (Test-Path -LiteralPath $script:Dump)) { return @() }
    $fs = New-Object IO.FileStream($script:Dump, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $sr = New-Object IO.StreamReader($fs, $Utf8); $t = $sr.ReadToEnd() } finally { $fs.Dispose() }
    return @($t -split "`r`n" | Where-Object { $_ -ne '' })
}
function Dump-Mark { return (Dump-Lines).Count }
function Dump-Since([int]$Mark) { $l = Dump-Lines; if ($l.Count -le $Mark) { return @() }; return @($l[$Mark..($l.Count - 1)]) }
function Last-Build([string[]]$L, [int]$Bar, [int]$Copy) {
    $start = -1
    for ($i = $L.Count - 1; $i -ge 0; $i--) { if ($L[$i] -like ('BUILD bar=' + $Bar + ' copy=' + $Copy + ' *')) { $start = $i; break } }
    if ($start -lt 0) { return $null }
    $items = @{}
    for ($i = $start + 1; $i -lt $L.Count; $i++) {
        $m = [regex]::Match($L[$i], '^ITEM (.) idx=(\d+) type=(\d+) acc=(\d) text=(.*)$')
        if (-not $m.Success) { break }
        $raw = $m.Groups[5].Value; $tab = $raw.IndexOf("`t"); $text = ''; if ($tab -ge 0) { $text = $raw.Substring($tab + 1) }
        $ty = [int]$m.Groups[3].Value; $lt = $m.Groups[1].Value
        # drive items (types 1..6) win over other items starting with the same character
        if ($items.ContainsKey($lt) -and $items[$lt].Type -ge 1 -and $items[$lt].Type -le 6) { continue }
        if ($items.ContainsKey($lt) -and -not ($ty -ge 1 -and $ty -le 6)) { continue }
        $items[$lt] = @{ Idx = [int]$m.Groups[2].Value; Type = $ty; Acc = [int]$m.Groups[4].Value; Text = $text; Raw = $raw }
    }
    return @{ Header = $L[$start]; Items = $items; Pos = $start }
}
function Tips([string[]]$L) { $t = @{}; foreach ($x in $L) { $m = [regex]::Match($x, '^TIP (.) (.*)$'); if ($m.Success) { $t[$m.Groups[1].Value] = $m.Groups[2].Value } }; return $t }
function Count-Like([string[]]$L, [string]$Pat) { return @($L | Where-Object { $_ -like $Pat }).Count }

# ---- program -------------------------------------------------------------------
function Start-P([string]$Path, [bool]$Seam, [string]$Tag) {
    if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { throw 'another tandemcommander.exe runs - refusing to start a second instance' }
    # the same start state for every run: both drive bars hidden (a previous run saved its own state)
    & reg.exe add $CfgKey /v 'Show Drive Bar' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add $CfgKey /v 'Show Drive Bar2' /t REG_DWORD /d 0 /f | Out-Null
    if ($Seam) { $env:TC_PROBE_DRIVES_DUMP = $script:Dump } else { Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue }
    $a = @('-t', $Tag, '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Path -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw ('the program did not show its main window: ' + $Path) }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    $r = Serve $p.Id 6
    if ($r.Messages.Count) { Out ('           at start: ' + (Msgs $r)) }
    return $p.Id
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 30000); Start-Sleep -Milliseconds 250 }
function Rebar-Kids([int]$Id) {
    $main = Get-Main $Id
    $rebar = @([Drv098f]::Kids($main) | Where-Object { [Drv098f]::Cls($_) -eq 'ReBarWindow32' }) | Select-Object -First 1
    if (-not $rebar) { return @() }
    return @([Drv098f]::Kids($rebar) | Where-Object { [Drv098f]::GetParent($_) -eq $rebar -and [Drv098f]::IsWindowVisible($_) })
}
function Toggle([int]$Id, [int]$Cmd) {
    $before = @(Rebar-Kids $Id | ForEach-Object { $_.ToInt64() })
    Post-Cmd (Get-Main $Id) $Cmd
    Start-Sleep -Milliseconds 1200; Sync $Id
    $after = @(Rebar-Kids $Id)
    $new = @($after | Where-Object { $before -notcontains $_.ToInt64() })
    $gone = @($before | Where-Object { @($after | ForEach-Object { $_.ToInt64() }) -notcontains $_ })
    return @{ New = $new; Gone = $gone.Count; Count = $after.Count }
}
# visible windows of the pid other than the main window
function Strays([int]$Id) { return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass } | ForEach-Object { WinDesc $_ }) }
function Close-Menu([int]$Id, [IntPtr]$M) {
    if ($M -eq [IntPtr]::Zero) { return }
    [void][Drv098f]::PostMessageW($M, 0x0100, [IntPtr]0x1B, [IntPtr]1)
    [void][Drv098f]::PostMessageW($M, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($M) -and [Drv098f]::IsWindowVisible($M)) { Start-Sleep -Milliseconds 50 }
    Start-Sleep -Milliseconds 600; Sync $Id
}
function Open-Menu([int]$Id, [string]$Shot) {
    $popup = [IntPtr]::Zero
    $ms = [Tst246]::TimeMenu((Get-Main $Id), [uint32]$Id, 707, 30000, [ref]$popup)
    if ($popup -ne [IntPtr]::Zero) {
        Start-Sleep -Milliseconds 500
        if ($Shot) { [void][Shot124]::Capture($popup, (Join-Path $ShotDir ($Shot + '.png'))) }
        Close-Menu $Id $popup
    }
    return $ms
}
function Activate([int]$Id) {
    $main = Get-Main $Id
    [void][Drv098f]::Send($main, 0x001C, 0, 0, 30000)
    [void][Drv098f]::Send($main, 0x001C, 1, 0, 30000)
    Start-Sleep -Milliseconds 700; Sync $Id
    return @(Strays $Id)
}
function Close-P([int]$Id) {
    if (-not (Test-Alive $Id)) { return ('already gone, exit ' + (ExitCodeOf $Id)) }
    $extra = @()
    [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) { $extra += ('at exit: ' + (WinDesc $h)); $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
        Start-Sleep -Milliseconds 200
    }
    if (Test-Alive $Id) { Kill-Mine $Id; return ('did not exit in 30 s - killed; ' + ($extra -join ' || ')) }
    return ('exit ' + (ExitCodeOf $Id) + $(if ($extra.Count) { '; ' + ($extra -join ' || ') } else { '' }))
}

# posts a drive bar command and serves the instance: records every window; prefers Cancel / No / OK;
# measures how long the UI thread did not answer
function Pick-Serve([int]$Id, [int]$Cmd) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Post-Cmd (Get-Main $Id) $Cmd
    $msgs = @(); $seen = @{}; $blockedMax = 0.0; $lastAnswer = 0.0; $idle = $null
    while ($sw.Elapsed.TotalSeconds -lt 150 -and (Test-Alive $Id)) {
        $ans = [Drv098f]::Send((Get-Main $Id), 0, 0, 0, 1000)
        if ($ans) { $gap = $sw.Elapsed.TotalSeconds - $lastAnswer; if ($gap -gt $blockedMax) { $blockedMax = $gap }; $lastAnswer = $sw.Elapsed.TotalSeconds }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
        if (-not $wins.Count -and $ans) { if ($null -eq $idle) { $idle = $sw.Elapsed.TotalSeconds }; if ($sw.Elapsed.TotalSeconds - $idle -gt 2.0) { break } } else { $idle = $null }
        foreach ($h in $wins) {
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; $msgs += ('{0:N1}s {1}' -f $sw.Elapsed.TotalSeconds, (WinDesc $h)); continue }
            if ($sw.Elapsed.TotalSeconds - $seen[$key] -lt 0.8 -or -not [Drv098f]::IsWindowEnabled($h)) { continue }
            $btn = Buttons $h; $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if ($ids.Count -eq 1 -and $ids[0] -eq 2 -and $sw.Elapsed.TotalSeconds - $seen[$key] -lt 60) { continue }   # progress window: wait
            $pick = $null
            foreach ($want in @(2, 7, 1)) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1; if ($pick) { break } }
            if ($pick) { $msgs += ('{0:N1}s answered button {1}' -f $sw.Elapsed.TotalSeconds, [Drv098f]::GetDlgCtrlID($pick)); Click $pick } else { Close-Win $h }
            $seen[$key] = 1e9
        }
        Start-Sleep -Milliseconds 200
    }
    $el = $sw.Elapsed.TotalSeconds
    $resp = [Drv098f]::Send((Get-Main $Id), 0, 0, 0, 5000)
    return [pscustomobject]@{ El = $el; Blocked = $blockedMax; Resp = $resp; Msgs = $(if ($msgs.Count) { $msgs -join ' || ' } else { 'none' }) }
}
# the drive bar index of a letter: drives come first, sorted by letter (listed or remembered)
function Bar-Idx([string]$Letter) {
    $mask = [Tst246]::GetLogicalDrives()
    foreach ($n in @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName.ToUpper() })) { $mask = $mask -bor (1 -shl ([int][char]$n[0] - 65)) }
    $i = 0
    for ($c = 0; $c -lt 26; $c++) { if ($mask -band (1 -shl $c)) { if ([string][char](65 + $c) -eq $Letter) { return $i }; $i++ } }
    return -1
}

# ---- fixture helpers ---------------------------------------------------------------
$script:Mapped = New-Object System.Collections.ArrayList
$script:NetKeys = New-Object System.Collections.ArrayList
$script:MyKeys = New-Object System.Collections.ArrayList
function Mp2Key([string]$Remote, [bool]$Create) {
    $k = $MP2 + '\' + (KeyOf $Remote)
    if (-not (($snapBefore.MP2 -split '\|') -contains (KeyOf $Remote))) { if ($script:MyKeys -notcontains (KeyOf $Remote)) { [void]$script:MyKeys.Add((KeyOf $Remote)) } }
    else { throw ('MountPoints2 key existed before the test: ' + (KeyOf $Remote)) }
    if ($Create -and -not (Test-Path -LiteralPath $k)) { [void](New-Item -Path $MP2 -Name (KeyOf $Remote) -Force) }
    return $k
}
function Set-Label($e) {
    $k = Mp2Key $e.KeyRemote $true
    switch ($e.Kind) {
        'sz' { Set-ItemProperty -LiteralPath $k -Name '_LabelFromReg' -Value $e.Raw -Type String }
        'expand' { Set-ItemProperty -LiteralPath $k -Name '_LabelFromReg' -Value $e.Raw -Type ExpandString }
        'dword' { Set-ItemProperty -LiteralPath $k -Name '_LabelFromReg' -Value 1234 -Type DWord }
        'nonul' {
            $rk = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(('Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\' + (KeyOf $e.KeyRemote)), $true)
            try { $r = [Tst246]::SetRaw($rk, '_LabelFromReg', 1, [Text.Encoding]::Unicode.GetBytes($e.Raw)) } finally { $rk.Close() }
            if ($r -ne 0) { throw ('RegSetValueEx failed ' + $r) }
        }
        'ini' { Remove-ItemProperty -LiteralPath $k -Name '_LabelFromReg' -ErrorAction SilentlyContinue; Set-ItemProperty -LiteralPath $k -Name '_LabelFromDesktopINI' -Value $e.Raw -Type String }
        'none' { }
    }
}
function Add-Drive($e, [bool]$Remember) {
    if ($e.Dir) {
        $dir = Join-Path $Fx $e.Dir
        [void](New-Item -ItemType Directory -Path $dir -Force)
        [IO.File]::WriteAllText((Join-Path $dir ('marker_' + $e.Case + '.txt')), $e.Case)
        $e.Local = $dir
        if (-not $e.MapRemote) { $e.MapRemote = UncOf $dir }
        $res = [Tst246]::Map(($e.Letter + ':'), $e.MapRemote, $Remember)
        if ($res -ne 0) { Out ("  fixture {0}: mapping {1}: to {2} FAILED {3}" -f $e.Case, $e.Letter, (Esc $e.MapRemote), $res); $e.Failed = $true; return }
        [void]$script:Mapped.Add($e.Letter)
        if ($Remember) { [void]$script:NetKeys.Add($e.Letter) }
        $rr = 0; $e.Remote = [Tst246]::Conn(($e.Letter + ':'), [ref]$rr)
        if (-not $e.KeyRemote) { $e.KeyRemote = $e.Remote }
    }
    if ($e.Kind -ne 'none') { Set-Label $e } elseif ($e.KeyRemote) { [void](Mp2Key $e.KeyRemote $false) }
    if ($e.Kind -eq 'sz' -or $e.Kind -eq 'nonul') { $e.ShownName = $e.Raw }
    elseif ($e.Kind -eq 'expand') { $e.ShownName = [Environment]::ExpandEnvironmentVariables($e.Raw) }   # round 2: expanded, as Explorer shows it
    else { $e.ShownName = $null }
    Out ("  fixture {0}: {1}: -> {2}; label kind {3} '{4}'" -f $e.Case, $e.Letter, (Short $e.Remote 90), $e.Kind, (Short $e.Raw 60))
}

# ==================================================================================
$snapBefore = Snap
Out ("246 independent test; fixed {0}; baseline {1}" -f $Fixed, $Baseline)
Out ("snapshot before: drives {0}; HKCU\Network [{1}]; MountPoints2 ##*: {2}; net use entries: [{3}]" -f $snapBefore.Drives, $snapBefore.Network, $snapBefore.MP2, $snapBefore.NetUseEntries)
$existed = $false; $regOk = $true
$id = 0
$before = Reports
try {
    if ($snapBefore.MP2 -match '##192\.0\.2\.1') { throw 'a MountPoints2 key for 192.0.2.1 exists before the test - refusing' }
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
    [void](New-Item -ItemType Directory -Path $Fx, $StartDir, $ShotDir -Force)
    $existed = Backup-Reg $RegBackup
    if (-not $existed) { throw 'the product registry key does not exist - this test expects a configured product' }
    Set-Config
    & reg.exe add $CfgKey /v 'Show Drive Bar' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add $CfgKey /v 'Show Drive Bar2' /t REG_DWORD /d 0 /f | Out-Null

    $remembered = @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName.ToUpper() })
    $free = New-Object System.Collections.ArrayList
    foreach ($c in [char[]]'ZYXWVUTSRQPONMLKJIH') { if (-not [Tst246]::Listed($c) -and $remembered -notcontains [string]$c) { [void]$free.Add([string]$c) } }
    Out ('free letters: ' + ($free -join ''))
    function Next-Letter { if (-not $free.Count) { return $null }; $l = $free[0]; $free.RemoveAt(0); return $l }

    $Cyr = [string]([char]0x0410) + [char]0x0440 + [char]0x0445 + [char]0x0438 + [char]0x0432 + '_' + [char]0x0436
    $Cjk = [string]([char]0x4E2D) + [char]0x6587 + [char]0x6863
    # ---- Phase A: performance fixture -----------------------------------------------
    $P1 = @{ Case = 'P1'; Dir = 'plain'; Kind = 'none' }
    $P2 = @{ Case = 'P2'; Dir = 'named'; Kind = 'sz'; Raw = 'Archiv' }
    $P3 = @{ Case = 'P3'; Dir = 'remem'; Kind = 'sz'; Raw = 'RemName' }
    $X1 = @{ Case = 'X1'; Dir = ('cyr_' + $Cyr); Kind = 'none' }
    $X2 = @{ Case = 'X2'; Dir = ('rem_' + $Cjk + '_' + $Cyr); Kind = 'none' }
    foreach ($e in @($P1, $P2, $P3, $X1, $X2)) { $e.Letter = Next-Letter; Add-Drive $e $true; if ($e.Failed) { throw ('perf fixture mapping failed: ' + $e.Case) } }
    foreach ($e in @($P3, $X2)) {
        $cr = [Tst246]::Cancel(($e.Letter + ':'), $false)
        $rr = 0; $rem = [Tst246]::Conn(($e.Letter + ':'), [ref]$rr)
        Out ("  {0}: {1}: connection cancelled (profile kept): {2}; listed {3}; WNetGetConnection {4} '{5}'" -f $e.Case, $e.Letter, $cr, [Tst246]::Listed($e.Letter[0]), $rr, (Short $rem 80))
    }
    # the hand-written unreachable remembered drives: the value layout copied from P3's real entry
    $tmpl = Get-ItemProperty -LiteralPath ('HKCU:\Network\' + $P3.Letter)
    $tmplNames = @($tmpl.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object { $_.Name })
    Out ('  HKCU\Network\' + $P3.Letter + ' values: ' + (($tmplNames | ForEach-Object { $_ + '=' + (Esc ('' + $tmpl.$_)) }) -join '; '))
    $P4 = @{ Case = 'P4'; Kind = 'sz'; Raw = 'Unreach'; Remote = '\\192.0.2.1\x' }
    $P5 = @{ Case = 'P5'; Kind = 'none'; Remote = '\\192.0.2.1\y' }
    foreach ($e in @($P4, $P5)) {
        $e.Letter = Next-Letter; $e.KeyRemote = $e.Remote
        $k = 'HKCU:\Network\' + $e.Letter
        [void](New-Item -Path 'HKCU:\Network' -Name $e.Letter -Force); [void]$script:NetKeys.Add($e.Letter)
        $src = Get-Item -LiteralPath ('HKCU:\Network\' + $P3.Letter)
        foreach ($n in $src.GetValueNames()) { New-ItemProperty -LiteralPath $k -Name $n -Value $src.GetValue($n) -PropertyType $src.GetValueKind($n) -Force | Out-Null }
        Set-ItemProperty -LiteralPath $k -Name 'RemotePath' -Value $e.Remote
        Add-Drive $e $false
    }
    $snapFx = Snap
    Out ("  net use now: [{0}]; drives {1}" -f $snapFx.NetUseEntries, $snapFx.Drives)
    $PerfSet = @($P1, $P2, $P3, $P4, $P5, $X1, $X2)

    if (-not $Quick) {   # round 3: skipped by -Quick
    # ---- Phase B: performance, both builds, seam off -------------------------------------
    foreach ($bn in @('baseline', 'fixed')) { $script:Perf[$bn] = @{ Menu = @(); Warm = @(); ActSync = @(); ActMenu = @(); Strays = @() } }
    for ($round = 1; $round -le $Rounds; $round++) {
        foreach ($bn in @('baseline', 'fixed')) {
            $path = if ($bn -eq 'fixed') { $Fixed } else { $Baseline }
            $id = Start-P $path $false ('T246' + $bn.Substring(0, 1))
            $t = Toggle $id 756
            $pf = $script:Perf[$bn]
            Out ("  [{0} round {1}] pid {2}; two drive bars: {3} new rebar children (count {4})" -f $bn, $round, $id, $t.New.Count, $t.Count)
            Start-Sleep -Milliseconds 800
            $pf.Warm += (Open-Menu $id $(if ($round -eq 1) { $bn + '_perf_menu' } else { '' }))
            for ($i = 0; $i -lt $PerRound; $i++) {
                $pf.Menu += (Open-Menu $id '')
                $s = @(Strays $id); if ($s.Count) { $pf.Strays += $s }
            }
            for ($i = 0; $i -lt $PerRound; $i++) {
                Start-Sleep -Milliseconds 500
                $pf.ActSync += [Tst246]::TimeActSync((Get-Main $id))
                Start-Sleep -Milliseconds 1200; Sync $id
                $s = @(Strays $id); if ($s.Count) { $pf.Strays += ('after activation: ' + ($s -join ' || ')) }
            }
            for ($i = 0; $i -lt $PerRound; $i++) {
                $popup = [IntPtr]::Zero
                $pf.ActMenu += [Tst246]::TimeActMenu((Get-Main $id), [uint32]$id, 707, 30000, [ref]$popup)
                Start-Sleep -Milliseconds 300
                Close-Menu $id $popup
            }
            $cl = Close-P $id
            Out ("  [{0} round {1}] closed: {2}" -f $bn, $round, $cl)
            $pf.Strays += @($(if ($cl -notlike 'exit 0x00000000*') { 'close: ' + $cl }))
        }
    }
    foreach ($bn in @('baseline', 'fixed')) {
        $pf = $script:Perf[$bn]
        Row ('PERF-' + $bn) 'MENU' 'INFO' ('Change Drive menu open (707 -> PopupMenuClass): ' + (Stat $pf.Menu))
        Row ('PERF-' + $bn) 'WARM' 'INFO' ('first opening after start: ' + (Stat $pf.Warm))
        Row ('PERF-' + $bn) 'ACTSYN' 'INFO' ('WM_ACTIVATEAPP 0/1 + WM_NULL round trip: ' + (Stat $pf.ActSync))
        Row ('PERF-' + $bn) 'ACTMNU' 'INFO' ('activation + menu (FIFO): ' + (Stat $pf.ActMenu))
    }
    $mb = Median $script:Perf['baseline'].Menu; $mf = Median $script:Perf['fixed'].Menu
    $xb = @($script:Perf['baseline'].Menu | Sort-Object)[-1]; $xf = @($script:Perf['fixed'].Menu | Sort-Object)[-1]
    RowV 'SC-004' 'MENU' (($mf -ge 0) -and ($mb -ge 0) -and ($mf -le $mb + 50) -and ($xf -le $xb + 50)) ("median fixed {0:N1} vs baseline {1:N1} ms (delta {2:N1}); max fixed {3:N1} vs baseline {4:N1} ms (delta {5:N1}); limit +50 ms" -f $mf, $mb, ($mf - $mb), $xf, $xb, ($xf - $xb))
    $ab = (Median $script:Perf['baseline'].ActMenu) - $mb; $af = (Median $script:Perf['fixed'].ActMenu) - $mf
    $sb = Median $script:Perf['baseline'].ActSync; $sf = Median $script:Perf['fixed'].ActSync
    RowV 'ACT-T' 'TIME' (($af - $ab) -le 50 -and ($sf - $sb) -le 50) ("activation cost (act+menu median - menu median): fixed {0:N1} vs baseline {1:N1} ms; sync round trip median fixed {2:N1} vs baseline {3:N1} ms" -f $af, $ab, $sf, $sb)
    $allStr = @($script:Perf['baseline'].Strays + $script:Perf['fixed'].Strays | Where-Object { $_ })
    RowV 'PERF' 'WINDOWS' ($allStr.Count -eq 0) ("stray windows / unclean exits during the timing runs: " + $(if ($allStr.Count) { $allStr -join ' || ' } else { 'none' }))

    # case 8 / case 5 from the round-1 menu screenshots (OCR; the PNGs stay for a visual check)
    $ocr = @{}
    foreach ($bn in @('baseline', 'fixed')) {
        $png = Join-Path $ShotDir ($bn + '_perf_menu.png')
        if (Test-Path -LiteralPath $png) {
            $big = Join-Path $ShotDir ($bn + '_perf_menu_x3.png')
            $img = New-Object Drawing.Bitmap($png); $w = $img.Width; $h = $img.Height; $img.Dispose()
            [Shot124]::Crop($png, $big, 0, 0, $w, $h, 3)
            $ocr[$bn] = @(Ocr-File $big)
            Out ("  OCR {0} menu ({1}x{2}): {3}" -f $bn, $w, $h, (($ocr[$bn] | ForEach-Object { Esc $_ }) -join ' / '))
        }
    }

    }
    # ---- Phase C: functional, fixed build with the seam -------------------------------------
    $L2000 = ('LongA_' + ('abcdefghij' * 200)).Substring(0, 2000)
    $C2000 = [string]::new([char]0x6863, 2000)
    $Emoji = 'Box ' + [char]::ConvertFromUtf32(0x1F4C1) + ' end'
    $Edge = @(
        @{ Case = 'E1'; Dir = 'expand'; Kind = 'expand'; Raw = '%USERNAME% share' },
        @{ Case = 'E2'; Dir = 'ctrl'; Kind = 'sz'; Raw = ([string]([char]1) + [char]2 + [char]0x1F + [char]0x7F + [char]9) },
        @{ Case = 'E3'; Dir = 'spaces'; Kind = 'sz'; Raw = ("  Lead`tIn`r`nner  Trail  ") },
        @{ Case = 'E4'; Dir = 'emoji'; Kind = 'sz'; Raw = $Emoji },
        @{ Case = 'E5'; Dir = 'ampamp'; Kind = 'sz'; Raw = 'A && B' },
        @{ Case = 'E6'; Dir = 'longascii'; Kind = 'sz'; Raw = $L2000 },
        @{ Case = 'E7'; Dir = 'delete'; Kind = 'sz'; Raw = 'TempName' },
        @{ Case = 'E8'; Dir = 'inionly'; Kind = 'ini'; Raw = 'IniName' },
        @{ Case = 'E9'; Dir = 'longcjk'; Kind = 'sz'; Raw = $C2000 },
        @{ Case = 'E10'; Dir = 'nonul'; Kind = 'nonul'; Raw = 'NoNul' },
        @{ Case = 'E11'; Dir = 'dword'; Kind = 'dword'; Raw = '<DWORD 1234>' },
        @{ Case = 'E12'; Dir = 'trail'; Kind = 'sz'; Raw = 'Trail' }
    )
    $EdgeOk = @()
    foreach ($e in $Edge) {
        $e.Letter = Next-Letter
        if (-not $e.Letter) { Row $e.Case 'FIXTURE' 'NOT RUN' 'no free drive letter left'; continue }
        if ($e.Case -eq 'E12') {
            # mapped with a trailing backslash and the server in upper case; the name stored under the
            # key of the lower-case path without the trailing backslash
            $dir = Join-Path $Fx $e.Dir
            [void](New-Item -ItemType Directory -Path $dir -Force)
            $e.MapRemote = ('\\LOCALHOST\C$' + $dir.Substring(2) + '\')
            $e.KeyRemote = ('\\localhost\c$' + $dir.Substring(2)).ToLower()
        }
        Add-Drive $e $false
        if (-not $e.Failed) { $EdgeOk += $e }
    }
    $All = @($PerfSet + $EdgeOk)
    foreach ($e in $All) { $e.ExpMenu = Exp-Text $e.ShownName $e.Remote $true; $e.ExpTip = Exp-Text $e.ShownName $e.Remote $false }
    # Explorer's own display names (oracle, INFO)
    foreach ($e in $All) { $e.Shell = [Tst246]::ShellName($e.Letter + ':\') }

    # ---- Phase D: the baseline picks the unreachable unnamed drive T: first (fresh, no SMB cache) --
    $script:P5Idx = Bar-Idx $P5.Letter
    if (-not $SkipBaselinePick) {
        $before2 = Reports
        $id = Start-P $Baseline $false 'T246D'
        $t = Toggle $id 756
        $pr = Pick-Serve $id (3500 + $script:P5Idx)
        $loc = Get-Loc $id
        Row 'D-P5' 'BASE' 'INFO' ("baseline picks {0}: (predicted idx {1}) first: done after {2:N1} s; UI blocked up to {3:N1} s; responsive {4}; panel '{5}'; windows: {6}" -f $P5.Letter, $script:P5Idx, $pr.El, $pr.Blocked, $pr.Resp, (Esc $loc), $pr.Msgs)
        $cl = Close-P $id
        $rep = Take-Reports $before2
        Row 'D-P5' 'CLEAN' 'INFO' ("baseline: {0}; reports {1}" -f $cl, $rep.Count)
    }

    $script:Dump = $Root + '\dump_fixed.txt'
    $id = Start-P $Fixed $true 'T246C'
    $t = Toggle $id 756
    Out ("  functional run pid {0}; two drive bars: {1} new rebar children" -f $id, $t.New.Count)

    # C1: menu texts
    $mark = Dump-Mark
    $ms = Open-Menu $id 'fixed_func_menu'
    $dl = Dump-Since $mark
    $menu = Last-Build $dl 0 0
    RowV 'C1' 'MENU' ($ms -ge 0 -and $null -ne $menu) ("menu opened in {0:N0} ms; {1}" -f $ms, $(if ($menu) { $menu.Header } else { '<no BUILD bar=0>' }))
    $dumpAll = Dump-Lines
    $bar1 = Last-Build $dumpAll 1 0; $bar2 = Last-Build $dumpAll 1 1
    foreach ($e in $All) {
        $it = $null; if ($menu -and $menu.Items.ContainsKey($e.Letter)) { $it = $menu.Items[$e.Letter] }
        $got = if ($it) { $it.Text } else { $null }
        $expAcc = if ($e.Case -in @('P3', 'P4', 'P5', 'X2')) { 0 } else { 1 }
        $acc = if ($it) { $it.Acc } else { -1 }
        $b1 = $bar1 -and $bar1.Items.ContainsKey($e.Letter) -and $bar1.Items[$e.Letter].Text -ceq $e.ExpMenu -and $bar1.Items[$e.Letter].Acc -eq $expAcc
        $b2 = $bar2 -and $bar2.Items.ContainsKey($e.Letter) -and $bar2.Items[$e.Letter].Text -ceq $e.ExpMenu -and $bar2.Items[$e.Letter].Acc -eq $expAcc
        $ok = ($got -ceq $e.ExpMenu) -and ($acc -eq $expAcc) -and $b1 -and $b2
        $note = ''
        if (-not ($got -ceq $e.ExpMenu) -and $got) { $note = ('; got {0} chars, expected {1}; first diff at {2}' -f $got.Length, $e.ExpMenu.Length, $(for ($q = 0; $q -lt [Math]::Min($got.Length, $e.ExpMenu.Length); $q++) { if ($got[$q] -cne $e.ExpMenu[$q]) { $q; break } })) }
        RowV $e.Case 'MENU' $ok ("{0}: acc={1} (exp {2}) text '{3}'; expected '{4}'; bar1 {5} bar2 {6}{7}" -f $e.Letter, $acc, $expAcc, (Short $got), (Short $e.ExpMenu), $b1, $b2, $note)
    }
    $seamIdx = if ($bar1 -and $bar1.Items.ContainsKey($P5.Letter)) { $bar1.Items[$P5.Letter].Idx } else { -1 }
    Row 'D-IDX' 'CHECK' $(if ($seamIdx -eq $script:P5Idx) { 'PASS' } else { 'INFO' }) ("predicted bar index of {0}: {1}; seam {2} (the baseline pick in phase D used the predicted one)" -f $P5.Letter, $script:P5Idx, $seamIdx)
    foreach ($e in $All) { Row ($e.Case) 'SHELL' 'INFO' ("Explorer shows {0}: '{1}'" -f $e.Letter, (Short $e.Shell 120)) }
    # case 5: exact UTF-8 bytes of the Cyrillic / CJK paths
    foreach ($e in @($X1, $X2)) {
        $raw = $null; if ($menu -and $menu.Items.ContainsKey($e.Letter)) { $raw = $menu.Items[$e.Letter].Text }
        $hasQ = ($raw -and $raw.Contains('?'))
        RowV ('5-' + $e.Case) 'EXACT' (($raw -ceq $e.Remote) -and -not $hasQ) ("{0}: '{1}' contains '?': {2}; UTF-8 bytes of the folder part: {3}" -f $e.Letter, (Esc $raw), $hasQ, $(if ($raw) { (($Utf8.GetBytes($raw.Substring($raw.LastIndexOf('\') + 1)) | ForEach-Object { '{0:X2}' -f $_ }) -join '') } else { '-' }))
    }
    if (-not $Quick) {   # round 3: skipped by -Quick
    # case 8: local drives (seam) vs the baseline OCR
    $locals = @(); if ($menu) { $locals = @($menu.Items.Keys | Where-Object { @(1, 2, 3, 5, 6) -contains $menu.Items[$_].Type } | Sort-Object) }
    foreach ($lt in $locals) {
        $it = $menu.Items[$lt]
        # the recognizer returns each menu column as its own line: every column of the seam text
        # (name, free space) must be found in the baseline menu's recognized lines
        $cols = @($it.Text -split "`t" | Where-Object { $_ -ne '' })
        $hb = 'no OCR'; $hf = 'no OCR'
        if ($ocr.ContainsKey('baseline')) { $hb = (@($cols | ForEach-Object { $c0 = $_; if (@($ocr['baseline'] | Where-Object { (Ocr-Norm $_) -eq (Ocr-Norm $c0) }).Count) { 'exact' } else { 'no' } }) -join ',') }
        if ($ocr.ContainsKey('fixed')) { $hf = (@($cols | ForEach-Object { $c0 = $_; if (@($ocr['fixed'] | Where-Object { (Ocr-Norm $_) -eq (Ocr-Norm $c0) }).Count) { 'exact' } else { 'no' } }) -join ',') }
        $v = if ($hb -notmatch 'no') { 'PASS' } elseif ($lt -eq 'C') { 'FAIL' } else { 'INFO' }
        if ($v -eq 'FAIL') { $script:Fails++ }
        Row ('8-' + $lt) 'LOCAL' $v ("seam type={0} acc={1} text '{2}'; in baseline menu OCR: {3}; in fixed menu OCR: {4}" -f $it.Type, $it.Acc, (Esc $it.Raw), $hb, $hf)
    }

    }
    # C2: tooltips (seam TIP lines at an activation check) + order of CHECK
    $mark = Dump-Mark
    $s = Activate $id
    $dl = Dump-Since $mark
    $tips = Tips $dl
    RowV 'C2' 'ACT' ($s.Count -eq 0 -and (Count-Like $dl 'CHECK quiet=1 *') -eq 1 -and (Count-Like $dl 'REBUILD*') -eq 0) ("windows: {0}; {1}" -f $(if ($s.Count) { $s -join ' || ' } else { 'none' }), (($dl | Where-Object { $_ -like 'CHECK*' -or $_ -like 'REBUILD*' }) -join ' / '))
    Row 'T-HOVER' 'TIP' 'NOT DRIVEN' 'the drive bar tooltip follows the real cursor (GetCursorPos) - hover is a step owed to a person; TIP rows below are the seam calling the same tooltip function'
    foreach ($e in $All) {
        $got = if ($tips.ContainsKey($e.Letter)) { $tips[$e.Letter] } else { $null }
        $ct = Check-Tip $got $e.ShownName $e.Remote
        RowV ('T-' + $e.Case) 'TIP' $ct.Ok ("{0}: [{1}] tip '{2}'; expected '{3}'; {4}" -f $e.Letter, $ct.Mode, (Short $got), (Short $e.ExpTip), $ct.Facts)
    }
    $nd = [regex]::Match((($dl | Where-Object { $_ -like 'CHECK*' }) -join ''), 'netdisc=([0-9A-F]{8})').Groups[1].Value
    $expMask = 0; foreach ($e in @($P3, $P4, $P5, $X2)) { $expMask = $expMask -bor (1 -shl ([int][char]$e.Letter - 65)) }
    RowV 'C2' 'MASK' ($nd -eq ('{0:X8}' -f $expMask)) ("netdisc {0}; expected {1:X8} (P3,P4,P5,X2)" -f $nd, $expMask)

    if (-not $Quick) {   # round 3: skipped by -Quick
    # C3: deletion of the name while running
    $E7 = $EdgeOk | Where-Object { $_.Case -eq 'E7' }
    if ($E7) {
        $k = $MP2 + '\' + (KeyOf $E7.KeyRemote)
        Remove-ItemProperty -LiteralPath $k -Name '_LabelFromReg'
        $mark = Dump-Mark; [void](Open-Menu $id ''); $dl = Dump-Since $mark
        $m = Last-Build $dl 0 0; $got = if ($m -and $m.Items.ContainsKey($E7.Letter)) { $m.Items[$E7.Letter].Text } else { $null }
        $tg = (Tips (Dump-Since $mark))[$E7.Letter]
        RowV 'E7' 'DELVAL' ($got -ceq $E7.Remote) ("value removed: menu '{0}'; tip at the menu's bar check '{1}'" -f (Esc $got), (Esc $tg))
        Remove-Item -LiteralPath $k -Recurse -Force
        $mark = Dump-Mark; [void](Open-Menu $id ''); $s = Activate $id; $dl = Dump-Since $mark
        $m = Last-Build $dl 0 0; $got = if ($m -and $m.Items.ContainsKey($E7.Letter)) { $m.Items[$E7.Letter].Text } else { $null }
        $tg = (Tips $dl)[$E7.Letter]
        RowV 'E7' 'DELKEY' (($got -ceq $E7.Remote) -and ($tg -ceq $E7.Remote) -and $s.Count -eq 0) ("key removed: menu '{0}'; tip '{1}'; windows {2}" -f (Esc $got), (Esc $tg), $s.Count)
        [void](New-Item -Path $MP2 -Name (KeyOf $E7.KeyRemote) -Force)
        Set-ItemProperty -LiteralPath $k -Name '_LabelFromReg' -Value 'Back' -Type String
        $mark = Dump-Mark; [void](Open-Menu $id ''); $dl = Dump-Since $mark
        $m = Last-Build $dl 0 0; $got = if ($m -and $m.Items.ContainsKey($E7.Letter)) { $m.Items[$E7.Letter].Text } else { $null }
        RowV 'E7' 'READD' ($got -ceq ('Back (' + $E7.Remote + ')')) ("key and name re-created: menu '{0}'" -f (Esc $got))
    }

    # C4: 20 activations without a change
    $mark = Dump-Mark
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $strayAll = @()
    for ($i = 0; $i -lt 20; $i++) { $s = Activate $id; if ($s.Count) { $strayAll += $s } }
    $dl = Dump-Since $mark
    RowV 'C4' 'QUIET20' ((Count-Like $dl 'CHECK quiet=1 *') -eq 20 -and (Count-Like $dl 'REBUILD*') -eq 0 -and (Count-Like $dl 'BUILD bar=1*') -eq 0 -and $strayAll.Count -eq 0) ("CHECK quiet=1 x{0}; REBUILD x{1}; BUILD bar=1 x{2}; windows {3}; masks seen: {4}" -f (Count-Like $dl 'CHECK quiet=1 *'), (Count-Like $dl 'REBUILD*'), (Count-Like $dl 'BUILD bar=1*'), $strayAll.Count, ((@($dl | Where-Object { $_ -like 'CHECK*' } | ForEach-Object { $_.Substring(14) }) | Sort-Object -Unique) -join ' | '))

    }
    # C9 (round 2): tooltip limit boundaries on drive E6, renamed while running: fits exactly / one
    # byte over (ASCII, 4-byte last character, '&'), CJK and emoji names with every residue of the cut
    # position, a mixed 1-2-3-4-byte name; the menu keeps the whole text every time
    $E6 = $EdgeOk | Where-Object { $_.Case -eq 'E6' }
    if ($E6) {
        $k6 = $MP2 + '\' + (KeyOf $E6.KeyRemote)
        $suf = $Utf8.GetByteCount(' (' + $E6.Remote + ')')
        $Em = [char]::ConvertFromUtf32(0x1F4C1); $CJ = [string][char]0x6863
        $mixUnit = 'ab' + $Em + [string][char]0x00E9 + $CJ
        $B = @(
            @('B0', 'ASCII, whole text exactly 4999 bytes', ('F' * ($TipLimit - $suf))),
            @('B1', 'ASCII, whole text 5000 bytes (one over)', ('F' * ($TipLimit + 1 - $suf))),
            @('B2', 'ends with an emoji, exactly 4999 bytes', (('F' * ($TipLimit - $suf - 4)) + $Em)),
            @('B3', 'ends with an emoji, 5000 bytes (the emoji must go whole)', (('F' * ($TipLimit + 1 - $suf - 4)) + $Em)),
            @('B4', 'CJK x1700, offset 0', ($CJ * 1700)),
            @('B5', 'CJK x1700, offset 1', ('a' + ($CJ * 1700))),
            @('B6', 'CJK x1700, offset 2', ('aa' + ($CJ * 1700))),
            @('B7', 'emoji x1300, offset 0', ($Em * 1300)),
            @('B8', 'emoji x1300, offset 1', ('b' + ($Em * 1300))),
            @('B9', 'emoji x1300, offset 2', ('bb' + ($Em * 1300))),
            @('B10', 'emoji x1300, offset 3', ('bbb' + ($Em * 1300))),
            @('B11', 'mixed 1/2/3/4-byte characters x500', ($mixUnit * 500)),
            @('B12', "'&' only, single-& text exactly 4999 bytes (the menu's doubled text is longer)", ('&' * ($TipLimit - $suf))),
            @('B13', "'&' only, single-& text 5000 bytes", ('&' * ($TipLimit + 1 - $suf))),
            @('B14', "'x&' x2600 (doubled '&&' in the stored text at the cut)", ('x&' * 2600)),
            @('B15', 'name equal to the path in upper case (round 3: never shortened, the path alone)', $E6.Remote.ToUpper()),
            @('B16', 'name equal to the path in lower case', $E6.Remote.ToLower())
        )
        foreach ($v in $B) {
            Set-ItemProperty -LiteralPath $k6 -Name '_LabelFromReg' -Value $v[2] -Type String
            $mark = Dump-Mark; [void](Open-Menu $id ''); $s = Activate $id; $dl = Dump-Since $mark
            $m = Last-Build $dl 0 0
            $mt = if ($m -and $m.Items.ContainsKey($E6.Letter)) { $m.Items[$E6.Letter].Text } else { $null }
            $expM = Exp-Text $v[2] $E6.Remote $true
            $tip = (Tips $dl)[$E6.Letter]
            $ct = Check-Tip $tip $v[2] $E6.Remote
            $menuOk = ($mt -ceq $expM)
            RowV ('C9-' + $v[0]) 'TIP' ($ct.Ok -and $menuOk -and $s.Count -eq 0) ("{0}: name {1} units / {2} bytes; [{3}] {4}; menu whole text {5} ({6} units); windows {7}" -f $v[1], $v[2].Length, $Utf8.GetByteCount($v[2]), $ct.Mode, $ct.Facts, $menuOk, $(if ($mt) { $mt.Length } else { -1 }), $s.Count)
        }
    }
    else { Row 'C9' 'TIP' 'NOT RUN' 'drive E6 missing' }

    if (-not $Quick) {   # round 3: skipped by -Quick
    # C5: single drive bar mode and hidden bars
    $t1 = Toggle $id 756   # two bars off
    $t2 = Toggle $id 755   # one bar on
    Out ("  bars: 756 -> new {0} gone {1} count {2}; 755 -> new {3} gone {4} count {5}" -f $t1.New.Count, $t1.Gone, $t1.Count, $t2.New.Count, $t2.Gone, $t2.Count)
    $cr = [Tst246]::Cancel(($P1.Letter + ':'), $false)
    $mark = Dump-Mark
    $s = Activate $id
    $dl = Dump-Since $mark
    $b1 = Last-Build $dl 1 0
    $acc = if ($b1 -and $b1.Items.ContainsKey($P1.Letter)) { $b1.Items[$P1.Letter].Acc } else { -1 }
    RowV 'C5' 'ONEBAR' ($t2.New.Count -eq 1 -and (Count-Like $dl 'REBUILD bar1') -eq 1 -and (Count-Like $dl 'REBUILD bar2') -eq 0 -and $acc -eq 0 -and $s.Count -eq 0) ("P1 {0}: cancelled {1}; {2}; bar1 acc {3}; windows {4}" -f $P1.Letter, $cr, (($dl | Where-Object { $_ -like 'CHECK*' -or $_ -like 'REBUILD*' -or $_ -like 'BUILD*' }) -join ' / '), $acc, $(if ($s.Count) { $s -join ' || ' } else { 'none' }))
    $t3 = Toggle $id 755   # bars hidden
    $mr = [Tst246]::Map(($P1.Letter + ':'), $P1.Remote, $true)
    $mark = Dump-Mark
    $s = Activate $id
    $alive = Test-Alive $id
    $dl = Dump-Since $mark
    RowV 'C5' 'NOBARS' ($alive -and $s.Count -eq 0 -and (Count-Like $dl 'REBUILD*') -eq 0 -and $t3.Gone -ge 1) ("bars hidden (gone {0}, count {1}); P1 reconnected {2}; alive {3}; windows {4}; dump: {5}" -f $t3.Gone, $t3.Count, $mr, $alive, $(if ($s.Count) { $s -join ' || ' } else { 'none' }), $(if ($dl.Count) { ($dl | Select-Object -First 3) -join ' / ' } else { '<nothing>' }))
    $mark = Dump-Mark
    $t4 = Toggle $id 756   # two bars again
    $dl = Dump-Since $mark
    $b1 = Last-Build $dl 1 0
    $acc = if ($b1 -and $b1.Items.ContainsKey($P1.Letter)) { $b1.Items[$P1.Letter].Acc } else { -1 }
    RowV 'C5' 'SHOWN' ($t4.New.Count -eq 2 -and $acc -eq 1) ("two bars shown again (new {0}); P1 acc in the fresh bar {1}" -f $t4.New.Count, $acc)
    # after re-showing: an activation must not rebuild (the bars were built with the current state)
    $mark = Dump-Mark; $s = Activate $id; $dl = Dump-Since $mark
    RowV 'C5' 'NOSTALE' ((Count-Like $dl 'REBUILD*') -eq 0) ("activation after re-show: {0}" -f (($dl | Where-Object { $_ -like 'CHECK*' -or $_ -like 'REBUILD*' }) -join ' / '))

    # C6: picking (drive bar 1 commands)
    $b1 = Last-Build (Dump-Lines) 1 0
    $pickP3 = $null
    if ($b1 -and $b1.Items.ContainsKey($P3.Letter)) {
        $it = $b1.Items[$P3.Letter]
        $mark = Dump-Mark
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Post-Cmd (Get-Main $id) (3500 + $it.Idx)
        $r = Serve $id 40
        Sync $id
        $el = $sw.Elapsed.TotalSeconds
        $dl = Dump-Since $mark
        $rest = @($dl | Where-Object { $_ -like ('RESTORE ' + $P3.Letter + ' *') -or $_ -like ('NORESTORE ' + $P3.Letter + ' *') })
        $exact = $rest.Count -ge 1 -and $rest[0] -ceq ('RESTORE ' + $P3.Letter + ' ' + $P3.Remote)
        $listed = [Tst246]::Listed($P3.Letter[0])
        $loc = Get-Loc $id
        RowV '6-P3' 'PICK' ($it.Acc -eq 0 -and $exact -and $listed -and $loc -like ($P3.Letter + ':\*') -and $r.Messages.Count -eq 0) ("{0}: idx {1} acc {2}; {3}; listed after {4}; panel '{5}'; windows: {6}; {7:N1} s" -f $P3.Letter, $it.Idx, $it.Acc, (Esc ($rest -join ' / ')), $listed, (Esc $loc), (Msgs $r), $el)
        # the bars may already be rebuilt by the reconnection itself (shell drive notification): the
        # last bar build since the pick counts
        $s = Activate $id; $dl = Dump-Since $mark
        $bb = Last-Build $dl 1 0
        $acc = -1; $txt = $null
        if ($bb -and $bb.Items.ContainsKey($P3.Letter)) { $acc = $bb.Items[$P3.Letter].Acc; $txt = $bb.Items[$P3.Letter].Text }
        RowV '6-P3' 'AFTER' ($acc -eq 1 -and ($txt -ceq $P3.ExpMenu)) ("after reconnect + activation: bar1 acc {0} text '{1}'; {2}" -f $acc, (Esc $txt), (($dl | Where-Object { $_ -like 'CHECK*' -or $_ -like 'REBUILD*' }) -join ' / '))
    }
    else { RowV '6-P3' 'PICK' $false 'P3 not on drive bar 1' }

    $b1 = Last-Build (Dump-Lines) 1 0
    $script:UnreachIdx = -1
    if ($b1 -and $b1.Items.ContainsKey($P4.Letter)) {
        $it = $b1.Items[$P4.Letter]; $script:UnreachIdx = $it.Idx
        $mark = Dump-Mark
        $pr = Pick-Serve $id (3500 + $it.Idx)
        $el = $pr.El; $blockedMax = $pr.Blocked; $resp = $pr.Resp; $msgs = @($pr.Msgs)
        $dl = Dump-Since $mark
        $rest = @($dl | Where-Object { $_ -like ('RESTORE ' + $P4.Letter + ' *') -or $_ -like ('NORESTORE ' + $P4.Letter + ' *') })
        $fatal = Fatal-Win $id
        RowV '6-P4' 'PICK' ((Test-Alive $id) -and $resp -and $null -eq $fatal -and $rest.Count -ge 1 -and $rest[0] -ceq ('RESTORE ' + $P4.Letter + ' \\192.0.2.1\x')) ("{0}: idx {1} acc {2}; {3}; done after {4:N1} s; UI blocked up to {5:N1} s; responsive {6}; windows: {7}" -f $P4.Letter, $it.Idx, $it.Acc, (Esc ($rest -join ' / ')), $el, $blockedMax, $resp, $pr.Msgs)
        $loc = Get-Loc $id
        $mark = Dump-Mark; [void](Open-Menu $id ''); $dl = Dump-Since $mark
        $m = Last-Build $dl 0 0
        $acc = -1; $txt = $null
        if ($m -and $m.Items.ContainsKey($P4.Letter)) { $acc = $m.Items[$P4.Letter].Acc; $txt = $m.Items[$P4.Letter].Text }
        RowV '6-P4' 'AFTER' ($acc -eq 0 -and (Test-Alive $id) -and $txt -ceq $P4.ExpMenu) ("panel after '{0}'; menu P4 acc {1} text '{2}'; HKCU\Network\{3} RemotePath '{4}'" -f (Esc $loc), $acc, (Esc $txt), $P4.Letter, (Esc ((Get-ItemProperty -LiteralPath ('HKCU:\Network\' + $P4.Letter) -ErrorAction SilentlyContinue).RemotePath)))
    }
    else { RowV '6-P4' 'PICK' $false 'P4 not on drive bar 1' }

    # C8 (extra): a state change + activation while the Change Drive menu is open, then while the
    # Change Directory dialog is open (bars rebuilt inside another modal loop)
    $cr = [Tst246]::Cancel(($P1.Letter + ':'), $false)
    $mark = Dump-Mark
    $popup = [IntPtr]::Zero
    $ms = [Tst246]::TimeMenu((Get-Main $id), [uint32]$id, 707, 30000, [ref]$popup)
    Start-Sleep -Milliseconds 500
    [void][Drv098f]::Send((Get-Main $id), 0x001C, 0, 0, 30000)
    [void][Drv098f]::Send((Get-Main $id), 0x001C, 1, 0, 30000)
    Start-Sleep -Milliseconds 1500
    $popupAlive = [Drv098f]::IsWindow($popup) -and [Drv098f]::IsWindowVisible($popup)
    $fatal = Fatal-Win $id
    Close-Menu $id $popup
    $dl = Dump-Since $mark
    $b1 = Last-Build $dl 1 0
    $acc = if ($b1 -and $b1.Items.ContainsKey($P1.Letter)) { $b1.Items[$P1.Letter].Acc } else { -1 }
    $resp = [Drv098f]::Send((Get-Main $id), 0, 0, 0, 5000)
    RowV 'C8' 'INMENU' ((Test-Alive $id) -and $resp -and $null -eq $fatal -and $acc -eq 0 -and @(Strays $id).Count -eq 0) ("P1 cancelled {0}; popup open during activation {1}; after: responsive {2}; bar1 P1 acc {3}; fatal {4}; seam: {5}" -f $cr, $popupAlive, $resp, $acc, $fatal, (($dl | Where-Object { $_ -like 'CHECK*' -or $_ -like 'REBUILD*' -or $_ -like 'BUILD*' }) -join ' / '))
    $mr = [Tst246]::Map(($P1.Letter + ':'), $P1.Remote, $true)
    $mark = Dump-Mark
    $dlg = Open-ByCmd $id 862
    [void][Drv098f]::Send((Get-Main $id), 0x001C, 0, 0, 30000)
    [void][Drv098f]::Send((Get-Main $id), 0x001C, 1, 0, 30000)
    Start-Sleep -Milliseconds 1500
    $others = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and $_ -ne $dlg } | ForEach-Object { WinDesc $_ })
    $fatal = Fatal-Win $id
    if ($dlg -ne [IntPtr]::Zero) { Close-Win $dlg; Start-Sleep -Milliseconds 500 }
    Sync $id
    $dl = Dump-Since $mark
    $b1 = Last-Build $dl 1 0
    $acc = if ($b1 -and $b1.Items.ContainsKey($P1.Letter)) { $b1.Items[$P1.Letter].Acc } else { -1 }
    RowV 'C8' 'INDLG' ((Test-Alive $id) -and $dlg -ne [IntPtr]::Zero -and $null -eq $fatal -and $others.Count -eq 0 -and $acc -eq 1) ("P1 reconnected {0}; dialog {1}; other windows {2}; bar1 P1 acc {3}; seam: {4}" -f $mr, $(if ($dlg -ne [IntPtr]::Zero) { [Drv098f]::Txt($dlg) } else { '<none>' }), $(if ($others.Count) { $others -join ' || ' } else { 'none' }), $acc, (($dl | Where-Object { $_ -like 'CHECK*' -or $_ -like 'REBUILD*' -or $_ -like 'BUILD*' }) -join ' / '))

    }
    # C7: end
    $s = @(Strays $id)
    $fatal = Fatal-Win $id
    $cl = Close-P $id
    $rep = Take-Reports $before
    RowV 'C7' 'CLEAN' ($s.Count -eq 0 -and $null -eq $fatal -and $cl -like 'exit 0x00000000*' -and $rep.Count -eq 0) ("windows {0}; fatal {1}; {2}; new crash reports {3} {4}" -f $s.Count, $fatal, $cl, $rep.Count, ($rep -join ' ;; '))
    $dAll = Dump-Lines
    Out ("  dump: {0} lines; message-box-free activations counted above" -f $dAll.Count)

    # ---- Phase E: the baseline picks the drive the fixed build just picked (SMB negative cache) --
    if (-not $SkipBaselinePick -and $script:UnreachIdx -ge 0) {
        $before2 = Reports
        $id = Start-P $Baseline $false 'T246E'
        $t = Toggle $id 756
        $pr = Pick-Serve $id (3500 + $script:UnreachIdx)
        $loc = Get-Loc $id
        Row 'E-P4' 'BASE' 'INFO' ("baseline picks U: (idx {0}) right after the fixed build did: done after {1:N1} s; UI blocked up to {2:N1} s; responsive {3}; panel '{4}'; windows: {5}" -f $script:UnreachIdx, $pr.El, $pr.Blocked, $pr.Resp, (Esc $loc), $pr.Msgs)
        $cl = Close-P $id
        $rep = Take-Reports $before2
        Row 'E-P4' 'CLEAN' 'INFO' ("baseline: {0}; reports {1}" -f $cl, $rep.Count)
    }
}
catch {
    $script:Fails++
    Out ('TEST ERROR: ' + $_.Exception.Message + ' at ' + $_.InvocationInfo.PositionMessage)
}
finally {
    foreach ($p in $Started) { if (Test-Alive $p) { Kill-Mine $p } }
    Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
    foreach ($l in $script:Mapped) { [void][Tst246]::Cancel(($l + ':'), $true) }
    foreach ($l in $script:NetKeys) { [void][Tst246]::Cancel(($l + ':'), $true); if ($snapBefore.Network -split ',' -notcontains $l) { Remove-Item -LiteralPath ('HKCU:\Network\' + $l) -Recurse -Force -ErrorAction SilentlyContinue } }
    for ($pass = 0; $pass -lt 3; $pass++) {
        foreach ($k in $script:MyKeys) { Remove-Item -LiteralPath ($MP2 + '\' + $k) -Recurse -Force -ErrorAction SilentlyContinue }
        # keys Explorer created for the fixture paths after the test removed them
        foreach ($k in @(Get-ChildItem $MP2 -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like '##*' -and ($snapBefore.MP2 -split '\|') -notcontains $_.PSChildName -and ($_.PSChildName -like '*tc246test*' -or $_.PSChildName -like '##192.0.2.1#*') } | ForEach-Object { $_.PSChildName })) { Remove-Item -LiteralPath ($MP2 + '\' + $k) -Recurse -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Milliseconds 1500
    }
    if ($existed) { $regOk = Restore-Reg $RegBackup $existed }
    try { if (Test-Path -LiteralPath $Fx) { Remove-Item -LiteralPath $Fx -Recurse -Force } } catch { Out ('cleanup: fixture folder not removed: ' + $_.Exception.Message) }
    $snapAfter = Snap
    $same = ($snapAfter.Network -eq $snapBefore.Network) -and ($snapAfter.MP2 -eq $snapBefore.MP2) -and ($snapAfter.Drives -eq $snapBefore.Drives) -and ($snapAfter.NetUseEntries -eq $snapBefore.NetUseEntries)
    if (-not $same) { $script:Fails++ }
    Out ("cleanup verified: {0} (drives {1}->{2}; HKCU\Network [{3}]->[{4}]; MountPoints2 equal {5}; net use entries [{6}]->[{7}]; fixture folder exists {8}); registry restored: {9}" -f $same, $snapBefore.Drives, $snapAfter.Drives, $snapBefore.Network, $snapAfter.Network, ($snapAfter.MP2 -eq $snapBefore.MP2), $snapBefore.NetUseEntries, $snapAfter.NetUseEntries, (Test-Path -LiteralPath $Fx), $regOk)
    if ($snapAfter.MP2 -ne $snapBefore.MP2) { Out ('  MountPoints2 after: ' + $snapAfter.MP2) }
    Out ("RESULT: {0} FAIL row(s)" -f $script:Fails)
    [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, $Utf8)
}
exit $script:Fails
