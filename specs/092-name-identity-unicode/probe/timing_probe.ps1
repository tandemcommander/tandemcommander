<#
.SYNOPSIS
    Feature 092 performance baseline: start-up, panel refresh and
    refresh-with-selection times of tandemcommander.exe on a folder with many
    files, half of them with non-ASCII names.

.DESCRIPTION
    1. Creates %TEMP%\tc092_timing_<Files> with -Files empty files. Odd
       numbers are ASCII ("f000001.txt"); even numbers rotate through seven
       accented / non-Latin / mixed-case stems (Czech, German, Cyrillic,
       Chinese), e.g. "Clanek" with C-caron and a-acute + "_000002.TXT".
       The names are built from character codes, so this script is pure
       ASCII and needs no BOM. An empty folder is created for the right panel.
    2. Starts the program -Runs times (-t T092 -l <folder> -r <empty> -p 1)
       and measures start -> main window exists + WaitForInputIdle + one
       WM_NULL round trip ("start to idle"). That moment comes before the
       panels are read (it does not grow with the number of files), so the
       script keeps sending WM_NULL and takes the end of the last round trip
       that was blocked for more than 50 ms as "start to panels listed"
       (equal to "start to idle" when no ping was blocked). The last
       instance is kept.
    3. Refresh: CM_LEFTREFRESH (724) is handled synchronously on the main
       thread: mainwnd3.cpp "case CM_LEFTREFRESH" does
       SendMessage(LeftPanel->HWindow, WM_USER_REFRESH_DIR, 0, t1), and
       fileswnb.cpp "case WM_USER_REFRESH_DIR" calls RefreshDirectory()
       (fileswn0.cpp), which reads, sorts and synchronises the listing before
       it returns. The command is therefore SENT:
       SendMessageTimeout(hwndMain, WM_COMMAND, 724) returns exactly when
       the command handler has returned, and that time is "refresh".
       (Painting is not included; it happens on the next WM_PAINT.)
       NOT used: PostMessage(WM_COMMAND) followed by a WM_NULL round trip.
       It was tried and returned in 0.0 ms every time: a message sent from
       another thread is dispatched BEFORE the posted messages in the
       queue, so the WM_NULL overtakes the command. Even without that race
       it could return early, because RefreshDirectory calls PeekMessage
       (the WM_USER_UPDATEPANEL clean-up) after reading and sorting but
       before the selection is carried over, and PeekMessage dispatches
       pending sent messages.
    4. CM_ACTIVESELECTALL (842) once (timed), then "refresh with selection"
       -Runs times: the refresh carries the selection over by name (the
       merge over both sorted listings in RefreshDirectory).
    5. Normal exit (WM_CLOSE to the main window), folders removed, results
       printed as "name: median ms (min-max)".

    Between measurements the script waits until the process is quiet (CPU
    time stops growing: the icon reader thread works after every refresh).

    SAFETY: only the processes started here are addressed, by pid; messages
    go only to their main window; no SendInput. HKCU\Software\Tandem Commander
    is exported to %TEMP%\tc092_timing_backup.reg before the first start and
    restored and verified (SHA-256 of a second export) at the end, unless
    -NoRegistryRestore is given. The only value changed for the run is the
    exit confirmation (Confirmation\Close Salamander = 0).

.PARAMETER Exe
    tandemcommander.exe under test.
.PARAMETER Files
    Number of files in the test folder (default 100000).
.PARAMETER Runs
    Number of measurements per item (default 5).
.PARAMETER NoRegistryRestore
    Do not back up / restore the registry key (the caller does it).

.NOTES
    Windows PowerShell 5.1 compatible. Exit code 0 = measured and cleaned up.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [int]$Files = 100000,
    [int]$Runs = 5,
    [switch]$NoRegistryRestore
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path

if (-not ('Drv092' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Drv092
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(2048); GetWindowTextW(h, s, 2048); return s.ToString(); }

    // top-level windows of ONE process
    public static List<IntPtr> Top(uint pid)
    {
        var l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { uint q; GetWindowThreadProcessId(h, out q); if (q == pid) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static IntPtr MainWnd(uint pid, string cls)
    {
        foreach (var h in Top(pid)) if (IsWindowVisible(h) && Cls(h) == cls) return h;
        return IntPtr.Zero;
    }

    // SendMessageTimeout; returns elapsed ms, or -1 on timeout / failure
    public static double SendTimed(IntPtr h, uint msg, int w, uint flags, uint timeout)
    {
        IntPtr res;
        var sw = System.Diagnostics.Stopwatch.StartNew();
        IntPtr r = SendMessageTimeoutW(h, msg, (IntPtr)w, IntPtr.Zero, flags, timeout, out res);
        sw.Stop();
        return r == IntPtr.Zero ? -1.0 : sw.Elapsed.TotalMilliseconds;
    }

}
'@
}

$MainClass = 'TandemCommanderMainWindowVer01'
$RegKey = 'HKCU\Software\Tandem Commander'
$WM_COMMAND = 0x0111
$CM_LEFTREFRESH = 724
$CM_ACTIVESELECTALL = 842
$LongTimeout = 300000
$Started = New-Object System.Collections.ArrayList
$Inv = [Globalization.CultureInfo]::InvariantCulture

function Test-Alive([int]$Id) { return [bool](Get-Process -Id $Id -ErrorAction SilentlyContinue) }

# ---- registry (as in specs/088-plugin-interface-107/probe/probe_lib.ps1) ----
function Backup-TcRegistry([string]$File) {
    & cmd.exe /c "reg query `"$RegKey`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    & cmd.exe /c "reg export `"$RegKey`" `"$File`" /y >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'reg export failed' }
    return $true
}
function Restore-TcRegistry([string]$File, [bool]$Existed) {
    & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
    if (-not $Existed) { Write-Host 'Registry: the key did not exist before - deleted'; return $true }
    & cmd.exe /c "reg import `"$File`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Write-Host "Registry: IMPORT FAILED - restore by hand from $File"; return $false }
    $check = "$File.check"
    & cmd.exe /c "reg export `"$RegKey`" `"$check`" /y >nul 2>&1"
    $ha = (Get-FileHash -LiteralPath $File).Hash; $hb = (Get-FileHash -LiteralPath $check).Hash
    Write-Host ("Registry: restored; identical={0}; SHA-256 {1} / {2}" -f ($ha -eq $hb), $ha.Substring(0, 16), $hb.Substring(0, 16))
    Remove-Item -LiteralPath $check -Force
    return ($ha -eq $hb)
}

# ---- test folder -----------------------------------------------------------
function New-TestFolder([string]$Dir, [int]$Count) {
    if ([IO.Directory]::Exists($Dir)) { [IO.Directory]::Delete($Dir, $true) }
    [void][IO.Directory]::CreateDirectory($Dir)
    $c = { param([int[]]$codes) -join ($codes | ForEach-Object { [char]$_ }) }
    # stem + extension, rotated over the even numbers
    $stems = @(
        @((& $c 0x010C, 0x6C, 0xE1, 0x6E, 0x65, 0x6B), '.TXT'),                   # C-caron l a-acute n e k   "Clanek"
        @((& $c 0xE1, 0x62, 0x65, 0x6C), '.txt'),                                 # a-acute b e l
        @((& $c 0x017D, 0x6C, 0x75, 0x165, 0x6F, 0x75, 0x10D, 0x6B, 0xFD), '.Txt'), # Zlutoucky with carons
        @((& $c 0xF6, 0x73, 0x74, 0x65, 0x72, 0x72, 0x65, 0x69, 0x63, 0x68), '.txt'), # o-umlaut sterreich
        @((& $c 0x444, 0x430, 0x439, 0x43B), '.txt'),                             # Cyrillic "fajl"
        @((& $c 0x4E2D, 0x6587), '.txt'),                                         # Chinese
        @((& $c 0x10D, 0xC1, 0x70), '.TXT')                                       # c-caron A-acute p (mixed case)
    )
    $ascii = 0; $other = 0
    for ($i = 1; $i -le $Count; $i++) {
        if ($i % 2 -eq 1) { $name = 'f' + $i.ToString('D6') + '.txt'; $ascii++ }
        else { $s = $stems[($i / 2) % $stems.Count]; $name = $s[0] + '_' + $i.ToString('D6') + $s[1]; $other++ }
        [IO.File]::Create($Dir + '\' + $name).Dispose()
    }
    return ("{0} ASCII + {1} non-ASCII names" -f $ascii, $other)
}

# ---- process ---------------------------------------------------------------
# waits until the CPU time of the process grows by less than 16 ms in three
# consecutive 300 ms windows (the icon reader has finished) and the main
# thread answers a WM_NULL
function Wait-Quiet([int]$Id, [IntPtr]$Main, [int]$MaxSeconds = 180) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $calm = 0
    $p = Get-Process -Id $Id
    $last = $p.TotalProcessorTime.TotalMilliseconds
    while ($sw.Elapsed.TotalSeconds -lt $MaxSeconds -and $calm -lt 3) {
        Start-Sleep -Milliseconds 300
        $p.Refresh()
        $now = $p.TotalProcessorTime.TotalMilliseconds
        if (($now - $last) -lt 16) { $calm++ } else { $calm = 0 }
        $last = $now
    }
    if ([Drv092]::SendTimed($Main, 0, 0, 1, $LongTimeout) -lt 0) { throw 'the main thread does not answer' }
    return $sw.Elapsed.TotalSeconds
}

function Start-Instance([string]$Dir, [string]$Empty) {
    $a = @('-t', 'T092', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Empty), '-p', '1')
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id)
    $m = [IntPtr]::Zero
    while ($sw.Elapsed.TotalSeconds -lt 120 -and $m -eq [IntPtr]::Zero) {
        $m = [Drv092]::MainWnd([uint32]$p.Id, $MainClass)
        if ($m -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 5 }
    }
    if ($m -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    $tWindow = $sw.Elapsed.TotalMilliseconds
    [void]$p.WaitForInputIdle(120000)
    if ([Drv092]::SendTimed($m, 0, 0, 1, $LongTimeout) -lt 0) { throw 'the main thread does not answer' }
    $tIdle = $sw.Elapsed.TotalMilliseconds
    # The first idle moment comes BEFORE the panels are read (it does not grow
    # with the number of files), so keep pinging: the listing is done at the
    # end of the last WM_NULL round trip that was blocked for more than 50 ms.
    # The search stops after 1.5 s without such a blocked ping.
    $tListed = $tIdle
    $lastSlow = $sw.Elapsed.TotalMilliseconds
    while (($sw.Elapsed.TotalMilliseconds - $lastSlow) -lt 1500) {
        $t = [Drv092]::SendTimed($m, 0, 0, 1, $LongTimeout)
        if ($t -lt 0) { throw 'the main thread does not answer' }
        if ($t -gt 50) { $lastSlow = $sw.Elapsed.TotalMilliseconds; $tListed = $lastSlow }
        else { Start-Sleep -Milliseconds 2 }
    }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    return [pscustomobject]@{ Id = $p.Id; Main = $m; WindowMs = $tWindow; IdleMs = $tIdle; ListedMs = $tListed }
}

# normal exit: WM_CLOSE to the main window; by pid if it does not end
function Stop-Instance([int]$Id) {
    if (-not (Test-Alive $Id)) { return 'already gone' }
    if ($Started -notcontains $Id) { throw "pid $Id was not started by this probe" }
    $m = [Drv092]::MainWnd([uint32]$Id, $MainClass)
    if ($m -ne [IntPtr]::Zero) { [void][Drv092]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 90 -and (Test-Alive $Id)) { Start-Sleep -Milliseconds 100 }
    if (Test-Alive $Id) {
        $w = ([Drv092]::Top([uint32]$Id) | Where-Object { [Drv092]::IsWindowVisible($_) } | ForEach-Object { "'" + [Drv092]::Cls($_) + "' '" + [Drv092]::Txt($_) + "'" }) -join '; '
        Stop-Process -Id $Id -Force; Start-Sleep -Milliseconds 500
        return "KILLED (did not exit in 90 s; windows: $w)"
    }
    return 'normal'
}

function Stat([string]$Name, [double[]]$V) {
    $s = @($V | Sort-Object)
    $n = $s.Count
    if ($n % 2) { $med = $s[($n - 1) / 2] } else { $med = ($s[$n / 2 - 1] + $s[$n / 2]) / 2 }
    $line = [string]::Format($Inv, '{0}: {1:F1} ms ({2:F1}-{3:F1})', $Name, $med, $s[0], $s[$n - 1])
    $script:Lines += $line
    Write-Host ('  ' + [string]::Format($Inv, '{0}: runs = {1}', $Name, (($V | ForEach-Object { $_.ToString('F1', $Inv) }) -join ', ')))
}

# ---------------------------------------------------------------------------
$script:Lines = @()
$backup = Join-Path $env:TEMP 'tc092_timing_backup.reg'
$dir = Join-Path $env:TEMP ("tc092_timing_{0}" -f $Files)
$empty = Join-Path $env:TEMP 'tc092_timing_empty'
$existed = $true
$ok = $false
$exitHow = @()

if (-not $NoRegistryRestore) { $existed = Backup-TcRegistry $backup }
try {
    Write-Host ("Program : {0}  ({1:yyyy-MM-dd HH:mm:ss})" -f $Exe, (Get-Item -LiteralPath $Exe).LastWriteTime)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $what = New-TestFolder $dir $Files
    if ([IO.Directory]::Exists($empty)) { [IO.Directory]::Delete($empty, $true) }
    [void][IO.Directory]::CreateDirectory($empty)
    Write-Host ("Folder  : {0}  ({1}; created in {2:F1} s)" -f $dir, $what, $sw.Elapsed.TotalSeconds)

    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) {
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
    }

    # ---- start-up ----
    $startIdle = @(); $startWin = @(); $startListed = @()
    $inst = $null
    for ($r = 1; $r -le $Runs; $r++) {
        $inst = Start-Instance $dir $empty
        $startWin += $inst.WindowMs; $startIdle += $inst.IdleMs; $startListed += $inst.ListedMs
        $title = [Drv092]::Txt($inst.Main)
        if ($title -notlike "*$(Split-Path -Leaf $dir)*") { throw "the left panel is not in the test folder; title: $title" }
        [void](Wait-Quiet $inst.Id $inst.Main)
        if ($r -lt $Runs) { $exitHow += (Stop-Instance $inst.Id) }
    }
    Write-Host ("Title   : {0}" -f [Drv092]::Txt($inst.Main))
    Stat 'start to main window' $startWin
    Stat 'start to idle' $startIdle
    Stat 'start to panels listed' $startListed

    $id = $inst.Id; $m = $inst.Main

    # one unmeasured refresh (first-use costs), then the measurements
    if ([Drv092]::SendTimed($m, $WM_COMMAND, $CM_LEFTREFRESH, 0, $LongTimeout) -lt 0) { throw 'refresh timed out' }
    [void](Wait-Quiet $id $m)

    $v = @()
    for ($r = 1; $r -le $Runs; $r++) {
        $t = [Drv092]::SendTimed($m, $WM_COMMAND, $CM_LEFTREFRESH, 0, $LongTimeout)
        if ($t -lt 0) { throw 'refresh timed out' }
        $v += $t
        [void](Wait-Quiet $id $m)
    }
    Stat 'refresh' $v

    # ---- select all, then refresh ----
    $t = [Drv092]::SendTimed($m, $WM_COMMAND, $CM_ACTIVESELECTALL, 0, $LongTimeout)
    if ($t -lt 0) { throw 'select all timed out' }
    Stat 'select all (once)' @($t)
    [void](Wait-Quiet $id $m)

    $v = @()
    for ($r = 1; $r -le $Runs; $r++) {
        $t = [Drv092]::SendTimed($m, $WM_COMMAND, $CM_LEFTREFRESH, 0, $LongTimeout)
        if ($t -lt 0) { throw 'refresh timed out' }
        $v += $t
        [void](Wait-Quiet $id $m)
    }
    Stat 'refresh with selection' $v

    $exitHow += (Stop-Instance $id)
    $ok = $true
}
finally {
    foreach ($s in @($Started)) { if (Test-Alive $s) { $exitHow += (Stop-Instance $s) } }
    $left = @($Started | Where-Object { Test-Alive $_ }).Count
    foreach ($d in @($dir, $empty)) {
        for ($k = 0; $k -lt 5 -and [IO.Directory]::Exists($d); $k++) {
            try { [IO.Directory]::Delete($d, $true) } catch { Start-Sleep -Milliseconds 500 }
        }
    }
    $regOk = $true
    if (-not $NoRegistryRestore) { $regOk = Restore-TcRegistry $backup $existed }
    Write-Host ''
    Write-Host ("=== results: {0} files, {1} runs ===" -f $Files, $Runs)
    $script:Lines | ForEach-Object { Write-Host $_ }
    Write-Host ("Exits: {0}" -f (($exitHow | Group-Object | ForEach-Object { "{0} x {1}" -f $_.Count, $_.Name }) -join ', '))
    Write-Host ("Test processes left: {0}; folders left: {1}" -f $left, @(@($dir, $empty) | Where-Object { [IO.Directory]::Exists($_) }).Count)
    if (-not $regOk) { $ok = $false }
}
if ($ok) { exit 0 } else { exit 1 }
