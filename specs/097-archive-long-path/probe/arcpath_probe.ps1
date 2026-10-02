<#
.SYNOPSIS
    Feature 097 probe (stage S1): an archive whose full path, or a folder
    inside an archive whose inner path, is longer than 259 bytes is either
    opened as exactly that archive or refused with one "path too long"
    message - never cut to another name.

.DESCRIPTION
    Fixtures under %TEMP%\tc097_arc (created through \\?\, removed at the
    end). Every archive is a small ZIP written by python's zipfile: a.txt and
    sub\b.txt ("real"), or twin.txt alone ("twin").

      C200   archive full name 200 bytes, ASCII (control)
      A259   exactly 259 bytes, ASCII (the last length that fits)
      A260   260 bytes, ASCII
      U130   folder name of U+0159: under 260 characters, over 259 bytes;
             byte 259 falls on a character boundary
      U200   about 420 bytes, accented
      MID    as U130, but byte 259 falls inside a two-byte character
      TWIN   300 bytes ASCII: <base>\<ppp>.zip<qqq>\arc.zip, where
             <base>\<ppp>.zip is exactly 259 bytes - and a second, different
             archive (twin.txt) exists as the FILE <base>\<ppp>.zip, i.e. at
             the name the old code cut the path to
      CL600  about 600 bytes accented, start-up route only (over the 519-byte
             command-line field)
      ISO    an .iso image at a 250-byte ASCII path that the ISO plug-in
             cannot open (held open for writing by the probe): the plug-in's
             "Cannot open file" text was built in a 260-byte buffer
      ISOU   the same at an accented path
      INNER  short archive path; folders d1\d2\d3 of 120 bytes each: the
             inner path of d3 is 362 bytes

    Routes, one instance of -Exe each:
      ENTER  left panel in the archive's folder; End, Enter
      CHDIR  Change Directory (command 862); the archive's full path is put
             into the field with a wide WM_SETTEXT; OK
      START  the program is started with -l "<archive path>"
    INNER: Enter on the archive, then Home, Down, Enter three times (d1, d2,
    d3); and Change Directory to <archive>\d1\d2\d3.

    Recorded per row: the main window title before and after, every dialog
    shown (class, title, texts) - answered with OK, a re-opened Change
    Directory dialog with Cancel -, whether the panel is inside an archive
    and WHICH one (End, F3 = command 742: the viewer's title names a.txt or
    twin.txt), then: process alive, WM_NULL answered, no run-time-check
    window, no new crash report, exit code 0.

    Verdict against the S1 expectation: C200 / A259 open the real archive
    with no message; every other case shows exactly one message containing
    "too long" and the panel stays; twin.txt is never shown. On the build
    before the feature the FAIL rows are the recorded old behaviour.

    MUST be started through tools\run_on_hidden_desktop.ps1. Refuses to run
    while a tandemcommander.exe other than -Exe is running.
    HKCU\Software\Tandem Commander is exported before the first start and
    restored and verified (SHA-256 of a second export) at the end.

.PARAMETER Exe
    tandemcommander.exe of the build under test.
.PARAMETER Label
    Text for the first line of the output.
.PARAMETER OutFile
    File that receives the output lines (ASCII).
.PARAMETER Only
    Case names to run (e.g. TWIN,A260); default all.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII. Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python'
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
$LP = '\\?\'
$Utf8 = New-Object Text.UTF8Encoding($false)
function U8Len([string]$s) { return $Utf8.GetByteCount($s) }
function Tail([string]$s, [int]$n = 60) { if ($s.Length -le $n) { return (Esc $s) }; return ('...' + (Esc $s.Substring($s.Length - $n))) }

$TempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$Root = $TempRoot + '\tc097_arc'
$StartDir = $Root + '\start'
$ReportDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$R = [string][char]0x0159
$FatalRx = 'Run-Time Check|Debug Error|Assertion|Runtime Library|Stack around|bug report|abnormal|has stopped|Unhandled exception|buffer overrun'
$TooLongRx = 'too long'
function Is-Fatal([string]$Desc) { return ($Desc -match $FatalRx) }
# the whole text of a window's visible controls (Get-DialogText stops at 400 characters: a long path would hide the message)
function FullText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv093]::Kids($H)) {
        $t = [Drv093]::Txt($c)
        if ($t -and [Drv093]::IsWindowVisible($c)) { $parts += ("[{0} id={1}] {2}" -f [Drv093]::Cls($c), [Drv093]::GetDlgCtrlID($c), (Esc ($t -replace '\s+', ' '))) }
    }
    return ($parts -join ' | ')
}
function WinDesc([IntPtr]$H) { return ("[{0} '{1}'] {2}" -f [Drv093]::Cls($H), (Tail ([Drv093]::Txt($H)) 70), (FullText $H)) }

# writes a ZIP: an entry ending with '/' is a folder, any other a file ("content of <name>")
function New-Zip([string]$File, [string[]]$Entries) {
    $spec = Join-Path $Root 'zipspec.txt'
    [IO.File]::WriteAllText($spec, ($File + "`n" + ($Entries -join "`n") + "`n"), $Utf8)
    $py = Join-Path $Root 'mkzip.py'
    $code = @(
        'import sys, io, zipfile',
        'a = io.open(sys.argv[1], "r", encoding="utf-8").read().split("\n")',
        'z = zipfile.ZipFile(a[0], "w", zipfile.ZIP_DEFLATED)',
        'for n in a[1:]:',
        '    if not n: continue',
        '    zi = zipfile.ZipInfo(n, (2026, 1, 2, 3, 4, 6))',
        '    if n.endswith("/"):',
        '        zi.external_attr = 0x10',
        '        z.writestr(zi, "")',
        '    else:',
        '        zi.compress_type = zipfile.ZIP_DEFLATED',
        '        z.writestr(zi, "content of " + n.split("/")[-1] + "\r\n")',
        'z.close()')
    [IO.File]::WriteAllLines($py, $code, (New-Object Text.ASCIIEncoding))
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $py $spec 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ('mkzip.py: ' + ($o -join ' ')) }
}

function Set-ProbeConfig {
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    $fresh = ($LASTEXITCODE -ne 0)
    if (-not $fresh) {
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
    }
    return $fresh
}

# ---- fixture paths -------------------------------------------------------------
function Base([string]$n) { return $Root + '\' + $n }
# ASCII folder components (each at most 200 bytes) of exactly $Bytes bytes, separators included
function FillA([int]$Bytes) {
    if ($Bytes -lt 1) { throw "fill of $Bytes bytes" }
    $c = @(); $rem = $Bytes
    while ($rem -gt 200) { $take = 200; if ($rem -eq 201) { $take = 199 }; $c += ('p' * $take); $rem -= ($take + 1) }
    $c += ('p' * $rem)
    return ($c -join '\')
}
# folder for an archive whose full name <folder>\arc.zip is exactly $Total bytes, ASCII
function DirA([string]$n, [int]$Total) { $b = Base $n; return ($b + '\' + (FillA ($Total - (U8Len $b) - 9))) }
# folder <base>\[x]<U+0159 x $Chars>; $CharAt = byte offset at which one of the U+0159 starts
# (258: a cut at 259 bytes tears it; 259: the cut falls between two characters)
function DirU([string]$n, [int]$Chars, [int]$CharAt) {
    $b = Base $n; $p = (U8Len $b) + 1
    $lead = [Math]::Abs(($CharAt - $p) % 2)
    return ($b + '\' + ('x' * $lead) + ($R * $Chars))
}
function Cut259([string]$s) {
    $bytes = $Utf8.GetBytes($s)
    if ($bytes.Length -le 259) { return '(fits)' }
    $torn = (($bytes[259] -band 0xC0) -eq 0x80)
    $n = 259; if ($torn) { $n = 258 }
    return ("'{0}'{1}" -f (Tail ($Utf8.GetString($bytes, 0, $n)) 24), $(if ($torn) { ' + half of a character' } else { '' }))
}

# ---- instance ------------------------------------------------------------------
$script:StartMsgs = @()
function Start-Tc097([string]$Left) {
    $a = @('-t', 'T097', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $TempRoot), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id)
    [void]$p.Handle
    $script:Procs[$p.Id] = $p
    $script:StartMsgs = @()
    $seen = @{}
    $sw = [Diagnostics.Stopwatch]::StartNew()
    # a message shown before the main window exists (command-line refusal) is recorded and answered
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) {
        foreach ($h in @(Get-Tops $p.Id | Where-Object { [Drv093]::Cls($_) -eq '#32770' })) {
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $script:StartMsgs += ('(before the main window) ' + (WinDesc $h))
            $seen.Remove($key)
            $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($b) { Click $b } else { [void][Drv093]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Alive $p.Id)) { throw 'the program ended before showing its main window' }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv093]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2500
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
    return [Drv093]::Send($m, 0, 0, 0, 10000)
}
function PostKey([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv093]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv093]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L)
}
function EnterItem([int]$Id) { PostKey $Id 0x0D; Start-Sleep -Milliseconds 1200 }
function CmdWin([int]$Id, [int]$C, [double]$Seconds = 15) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) $C
    return (Wait-NewWin $Id $known $Seconds)
}

# Serves the instance's windows until it is idle (no window but the main one for
# 1.5 s). Each window kept 0.6 s is recorded and answered with OK / Yes; a
# Change Directory dialog (re-opened after an error) is recorded and cancelled.
function Serve97([int]$Id, [double]$Seconds = 30) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Reopened = 0; Fatal = $false; TimedOut = $false; Died = $false }
    $seen = @{}; $idleSince = $null
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
            $seen.Remove($key)
            if ([Drv093]::Txt($h) -eq 'Change Directory') { $r.Reopened++; Close-Win $Id $h; Start-Sleep -Milliseconds 400; continue }
            [void]$r.Messages.Add($d)
            $want = @(1, 6)
            if ($d -match 'temporary director') { $want = @(4) }
            $pick = $btn | Where-Object { $want -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($pick) { Click $pick } else { Close-Win $Id $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function MsgList($m) { if ($m.Count) { return (($m | ForEach-Object { if ($_.Length -gt 360) { $_.Substring(0, 170) + ' ...(' + ($_.Length - 340) + ' characters)... ' + $_.Substring($_.Length - 170) } else { $_ } }) -join ' || ') } else { return 'no window' } }

# which archive is the panel in: End (the last item), F3; the viewer's title names the file
function Which([int]$Id) {
    Key $Id 0x23
    $w = CmdWin $Id 742 15
    if ($w -eq [IntPtr]::Zero) { return 'no viewer window in 15 s' }
    Start-Sleep -Milliseconds 800
    $d = WinDesc $w
    if (Is-Fatal $d) { return ('FATAL ' + $d) }
    if ([Drv093]::Cls($w) -eq '#32770') { [void](Click-Ok $w); return ('message: ' + $d) }
    $t = [Drv093]::Txt($w)
    [void][Drv093]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 700
    if ($t -match 'twin\.txt') { return 'twin.txt' }
    if ($t -match 'a\.txt') { return 'a.txt' }
    return ('viewer: ' + (Tail $t 50))
}

$script:Rows = New-Object System.Collections.ArrayList
function Row([string]$Case, [string]$Step, [string]$Verdict, [string]$Short, [string]$Facts) {
    Out ('{0,-6} {1,-9} {2,-10} {3}; {4}' -f $Case, $Step, $Verdict, $Short, $Facts)
    [void]$script:Rows.Add([pscustomobject]@{ Case = $Case; Step = $Step; Verdict = $Verdict; Short = $Short })
}

# END row: alive, responsive, no stray window, no new report, exit code 0
function End-Instance([string]$Case, [string]$Step, [int]$Id, [string]$Fatal, $Before) {
    $alive = Test-Alive $Id
    $resp = $false; if ($alive -and -not $Fatal) { $resp = Responsive $Id }
    $extra = @(); if ($alive -and -not $Fatal) { $extra = @(Get-Tops $Id | Where-Object { [Drv093]::Cls($_) -ne $MainClass } | ForEach-Object { WinDesc $_ }) }
    $ec = '-'
    if ($Fatal -or -not $resp) {
        if ($alive) { Kill-Mine $Id; $ec = 'ended by the probe (pid ' + $Id + ')' } else { $ec = ExitCodeOf $Id }
    }
    else {
        [void][Drv093]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
            foreach ($h in @(Get-Tops $Id | Where-Object { [Drv093]::Cls($_) -eq '#32770' })) { $extra += ('at exit: ' + (WinDesc $h)); $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
            Start-Sleep -Milliseconds 200
        }
        if (Test-Alive $Id) { Kill-Mine $Id; $ec = 'did not exit in 30 s - ended by the probe' } else { $ec = ExitCodeOf $Id }
    }
    Start-Sleep -Milliseconds 400
    $after = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $new = @($after | Where-Object { $Before -notcontains $_ })
    foreach ($n in $new) { Remove-Item -LiteralPath (Join-Path $ReportDir $n) -Force -ErrorAction SilentlyContinue }
    $notes = @($extra | Where-Object { $_ -match 'monitored handles remained opened' })
    $extra = @($extra | Where-Object { $_ -notmatch 'monitored handles remained opened' })
    $ok = (-not $Fatal) -and $resp -and ($extra.Count -eq 0) -and ($new.Count -eq 0) -and ($ec -eq '0x00000000')
    Row $Case $Step $(if ($ok) { 'PASS' } else { 'FAIL' }) ("exit {0}" -f $ec) ("alive {0}; WM_NULL {1}; stray windows {2}; new reports {3}{4}{5}{6}" -f `
            $alive, $resp, $(if ($extra.Count) { '' + $extra.Count + ' (' + ($extra -join ' || ') + ')' } else { '0' }), $new.Count, $(if ($new.Count) { ' (' + ($new -join ',') + ', removed)' } else { '' }), $(if ($Fatal) { '; FATAL: ' + $Fatal } else { '' }), $(if ($notes.Count) { '; Debug note: "Some monitored handles remained opened"' } else { '' }))
}
function Reports { return @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) }
function TmpDirs { return @(Get-ChildItem -LiteralPath $TempRoot -Directory -Filter 'SAL*.tmp' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) }
function Remove-NewTmp($Before) {
    foreach ($t in @(Get-ChildItem -LiteralPath $TempRoot -Directory -Filter 'SAL*.tmp' -ErrorAction SilentlyContinue | Where-Object { $Before -notcontains $_.Name })) {
        Remove-Item -LiteralPath $t.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}
# Change Directory: the text goes into the field with a wide WM_SETTEXT; OK
function Do-ChangeDir([int]$Id, [string]$Text) {
    $dlg = Open-ByCmd $Id 862
    if ($dlg -eq [IntPtr]::Zero) { throw 'Change Directory (command 862) opened no window' }
    $ctl = Find-Ctl $dlg 210
    if ($ctl -eq [IntPtr]::Zero) { throw 'the path field (id 210) was not found' }
    [void][Drv093]::SetText($ctl, $Text, 5000)
    $held = [Drv093]::GetText($ctl, 5000)
    [void](Click-Ok $dlg)
    Start-Sleep -Milliseconds 800
    return ($held -ceq $Text)
}

# one route of one case
function Run-Route($c, [string]$Route) {
    $before = Reports; $tmpBefore = TmpDirs
    $id = 0; $fatal = $null; $rowDone = $false; $endDone = $false
    try {
        $left = $c.Dir; if ($Route -eq 'CHDIR') { $left = $StartDir } elseif ($Route -eq 'START') { $left = $c.Arc }
        $id = Start-Tc097 $left
        $msgs = New-Object System.Collections.ArrayList
        foreach ($m in $script:StartMsgs) { [void]$msgs.Add($m) }
        $r0 = Serve97 $id 10
        if ($r0.Fatal -or $r0.Died) { $fatal = 'at start: ' + (MsgList $r0.Messages) }
        $title0 = if (Test-Alive $id) { Title $id } else { '<gone>' }
        $extraNote = ''; $reopened = 0
        if ($Route -eq 'START') { foreach ($m in $r0.Messages) { [void]$msgs.Add($m) } }
        elseif (-not $fatal) {
            if ($r0.Messages.Count) { $extraNote = '; at start: ' + (MsgList $r0.Messages) }
            if ($Route -eq 'ENTER') { Key $id 0x23; EnterItem $id }
            else { $heldOk = Do-ChangeDir $id $c.Arc; $extraNote += $(if ($heldOk) { '; the field held the text exactly' } else { '; THE FIELD DID NOT HOLD THE TEXT' }) }
            $r = Serve97 $id 30
            foreach ($m in $r.Messages) { [void]$msgs.Add($m) }
            $reopened = $r.Reopened
            if ($r.Fatal -or $r.Died) { $fatal = (MsgList $r.Messages) + $(if ($r.Died) { ' (process ended)' } else { '' }) }
        }
        $t1 = if (Test-Alive $id) { Title $id } else { '<gone>' }
        $nLong = @($msgs | Where-Object { $_ -match $TooLongRx }).Count
        $inside = (-not $fatal) -and ($t1 -match '\.zip - ') -and (($Route -eq 'START') -or ($t1 -ne $title0))
        $which = '-'
        if ($inside) { $which = Which $id; if ($which -match '^FATAL') { $fatal = $which }; $r2 = Serve97 $id 8; if ($r2.Fatal -or $r2.Died) { $fatal = 'after F3: ' + (MsgList $r2.Messages) } }
        $stays = ($Route -ne 'START') -and ($t1 -eq $title0)
        if ($fatal) { $short = 'FATAL' }
        elseif ($inside -and $which -eq 'a.txt') { $short = 'ENTERED the requested archive' }
        elseif ($inside -and $which -eq 'twin.txt') { $short = 'ENTERED THE TWIN (another archive)' }
        elseif ($inside) { $short = 'ENTERED an archive (' + $which + ')' }
        elseif ($nLong -gt 0) { $short = ('REFUSED: "too long" message x{0}' -f $nLong) }
        elseif ($msgs.Count -eq 0) { $short = 'SILENT: nothing shown, not in the archive' }
        else { $short = 'OTHER MESSAGE, not in the archive' }
        if ($Route -ne 'START' -and -not $inside -and -not $fatal) { $short += $(if ($stays) { ', panel stays' } else { ', PANEL MOVED' }) }
        if ($c.Expect -eq 'enter') { $ok = $inside -and ($which -eq 'a.txt') -and ($msgs.Count -eq 0) }
        else { $ok = (-not $inside) -and ($nLong -eq 1) -and ($msgs.Count -eq 1) -and (($Route -eq 'START') -or $stays) }
        if ($fatal) { $ok = $false }
        Row $c.N $Route $(if ($ok) { 'PASS' } else { 'FAIL' }) $short ("title before '{0}', after '{1}'; F3 on the last item: {2}; windows ({3}): {4}{5}{6}" -f `
                (Tail $title0 46), (Tail $t1 46), $which, $msgs.Count, (MsgList $msgs), $(if ($reopened) { '; the Change Directory dialog came back x' + $reopened + ' (cancelled)' } else { '' }), $extraNote)
        $rowDone = $true
        End-Instance $c.N ($Route + '.END') $id $fatal $before
        $endDone = $true
    }
    catch {
        Out ('       exception: ' + $_.Exception.Message)
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
    }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        if (-not $rowDone) { Row $c.N $Route 'NOT DRIVEN' 'not driven' 'see the exception above' }
        if (-not $endDone) { Row $c.N ($Route + '.END') 'NOT DRIVEN' 'not driven' 'an earlier step failed' }
        Start-Sleep -Milliseconds 300
        Remove-NewTmp $tmpBefore
    }
}

# INNER: folders d1\d2\d3 inside a short-path archive; the inner path of d3 does not fit 259 bytes
function Run-Inner($c) {
    $before = Reports; $tmpBefore = TmpDirs
    $id = 0; $fatal = $null; $endDone = $false
    $steps = 'ENTER', 'd1', 'd2', 'd3'; $done = @{}
    try {
        $id = Start-Tc097 $c.Dir
        $r0 = Serve97 $id 10
        if ($r0.Fatal -or $r0.Died) { $fatal = 'at start: ' + (MsgList $r0.Messages) }
        $prev = Title $id
        foreach ($s in $steps) {
            if ($fatal) { break }
            if ($s -eq 'ENTER') { Key $id 0x23 } else { Key $id 0x24; Key $id 0x28 }
            EnterItem $id
            $r = Serve97 $id 20
            if ($r.Fatal -or $r.Died) { $fatal = (MsgList $r.Messages) }
            $t = if (Test-Alive $id) { Title $id } else { '<gone>' }
            $nLong = @($r.Messages | Where-Object { $_ -match $TooLongRx }).Count
            $mark = if ($s -eq 'ENTER') { 'arc.zip' } else { $s + 'x' }
            $in = $t.Contains($mark)
            if ($s -eq 'd3') {
                $ok = (-not $fatal) -and (-not $in) -and ($t -eq $prev) -and ($nLong -eq 1) -and ($r.Messages.Count -eq 1)
                $short = if ($in) { 'ENTERED d3' } elseif ($nLong) { ('REFUSED: "too long" message x{0}' -f $nLong) } elseif ($r.Messages.Count) { 'OTHER MESSAGE' } else { 'SILENT: nothing shown' }
                $short += $(if ($t -eq $prev) { ', panel stays in d2' } elseif (-not $in) { ', PANEL MOVED' } else { '' })
            }
            else {
                $ok = (-not $fatal) -and $in -and ($r.Messages.Count -eq 0)
                $short = if ($in) { 'entered' } else { 'NOT entered' }
            }
            Row $c.N $s $(if ($ok) { 'PASS' } else { 'FAIL' }) $short ("title starts '{0}' before, '{1}' after; windows ({2}): {3}" -f (Esc $prev.Substring(0, [Math]::Min(16, $prev.Length))), (Esc $t.Substring(0, [Math]::Min(16, $t.Length))), $r.Messages.Count, (MsgList $r.Messages))
            $done[$s] = 1
            if (-not $ok -and $s -ne 'd3') { break }
            $prev = $t
        }
        End-Instance $c.N 'END' $id $fatal $before
        $endDone = $true
    }
    catch {
        Out ('       exception: ' + $_.Exception.Message)
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
    }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        foreach ($s in $steps) { if (-not $done.ContainsKey($s)) { Row $c.N $s 'NOT DRIVEN' 'not driven' 'an earlier step failed' } }
        if (-not $endDone) { Row $c.N 'END' 'NOT DRIVEN' 'not driven' 'an earlier step failed' }
        Start-Sleep -Milliseconds 300
        Remove-NewTmp $tmpBefore
    }
    # Change Directory straight to <archive>\d1\d2\d3
    $deep = @{ N = $c.N; Dir = $c.Dir; Arc = ($c.Arc + '\' + $c.Inner); Expect = 'refuse' }
    Run-Route $deep 'CHDIR'
}

# ISO / ISOU: an image that the plug-in cannot open (the probe holds it open for writing: the core's
# own open shares writing, the plug-in's does not). The plug-in builds "Cannot open file '<name>'."
# in a 260-byte buffer; the name is 250 bytes.
function Run-Iso($c) {
    $before = Reports; $tmpBefore = TmpDirs
    $id = 0; $fatal = $null; $rowDone = $false; $endDone = $false; $hold = $null
    try {
        $hold = [IO.File]::Open($LP + $c.Arc, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
        $id = Start-Tc097 $c.Dir
        $r0 = Serve97 $id 10
        if ($r0.Fatal -or $r0.Died) { $fatal = 'at start: ' + (MsgList $r0.Messages) }
        $title0 = Title $id
        $r = $null
        if (-not $fatal) {
            Key $id 0x23; EnterItem $id
            $r = Serve97 $id 30
            if ($r.Fatal -or $r.Died) { $fatal = (MsgList $r.Messages) + $(if ($r.Died) { ' (process ended)' } else { '' }) }
        }
        $t1 = if (Test-Alive $id) { Title $id } else { '<gone>' }
        $msgs = @(); if ($r) { $msgs = @($r.Messages) }
        $nOpen = @($msgs | Where-Object { $_ -match 'Cannot open file' }).Count
        $bad = @($msgs | Where-Object { $_ -match '\uFFFD|\?\?' }).Count
        $ok = (-not $fatal) -and ($nOpen -ge 1) -and ($t1 -eq $title0)
        $short = if ($fatal) { 'FATAL (run-time check / crash window)' } elseif ($nOpen) { ('plug-in message "Cannot open file" x{0}, panel stays' -f $nOpen) } else { 'no "Cannot open file" message' }
        Row $c.N 'ENTER' $(if ($ok) { 'PASS' } else { 'FAIL' }) $short ("windows ({0}): {1}{2}" -f $msgs.Count, (MsgList $msgs), $(if ($bad) { '; (the text holds a replacement character or ??)' } else { '' }))
        $rowDone = $true
        End-Instance $c.N 'ENTER.END' $id $fatal $before
        $endDone = $true
    }
    catch {
        Out ('       exception: ' + $_.Exception.Message)
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
    }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        if ($hold) { $hold.Dispose() }
        if (-not $rowDone) { Row $c.N 'ENTER' 'NOT DRIVEN' 'not driven' 'see the exception above' }
        if (-not $endDone) { Row $c.N 'ENTER.END' 'NOT DRIVEN' 'not driven' 'an earlier step failed' }
        Start-Sleep -Milliseconds 300
        Remove-NewTmp $tmpBefore
    }
}

# ---- main ---------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc097_arcpath_backup.reg'
$existed = Backup-TcRegistry $backup
$restored = $false
$nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    [void][IO.Directory]::CreateDirectory($StartDir)
    $fresh = Set-ProbeConfig

    $realZip = $Root + '\real.zip'; New-Zip $realZip @('a.txt', 'sub/', 'sub/b.txt')
    $twinZip = $Root + '\twin.zip'; New-Zip $twinZip @('twin.txt')

    $all = 'ENTER', 'CHDIR', 'START'
    $cases = @(
        @{ N = 'C200'; Dir = (DirA 'C200' 200); Expect = 'enter'; Routes = $all },
        @{ N = 'A259'; Dir = (DirA 'A259' 259); Expect = 'enter'; Routes = $all },
        @{ N = 'A260'; Dir = (DirA 'A260' 260); Expect = 'refuse'; Routes = $all },
        @{ N = 'U130'; Dir = (DirU 'U130' 112 259); Expect = 'refuse'; Routes = $all },
        @{ N = 'U200'; Dir = (DirU 'U200' 180 259); Expect = 'refuse'; Routes = $all },
        @{ N = 'MID'; Dir = (DirU 'MID' 112 258); Expect = 'refuse'; Routes = $all })
    # TWIN: <base>\<ppp>.zip is 259 bytes and is a FILE (the twin archive); the requested archive is in
    # the FOLDER <base>\<ppp>.zip<qqq>
    $tb = Base 'TWIN'
    $twinFile = $tb + '\' + ('p' * (259 - (U8Len $tb) - 5)) + '.zip'
    $cases += @{ N = 'TWIN'; Dir = ($twinFile + ('q' * 33)); Expect = 'refuse'; Routes = $all; Twin = $twinFile }
    $cases += @{ N = 'CL600'; Dir = ((Base 'CL600') + '\' + ($R * 200) + '\' + ($R * 80)); Expect = 'refuse'; Routes = @('START') }
    $d1 = 'd1' + ('x' * 118); $d2 = 'd2' + ('x' * 118); $d3 = 'd3' + ('x' * 118)
    $cases += @{ N = 'INNER'; Dir = (Base 'INNER'); Expect = 'enter'; Inner = ($d1 + '\' + $d2 + '\' + $d3); Zip = @('a.txt', ($d1 + '/'), ($d1 + '/' + $d2 + '/'), ($d1 + '/' + $d2 + '/' + $d3 + '/')) }
    # ISO: <folder>\arc.iso of 250 bytes (ASCII) / about 250 bytes (accented)
    $cases += @{ N = 'ISO'; Dir = (DirA 'ISO' 250); Expect = 'plug-in message'; Iso = $true }
    $cases += @{ N = 'ISOU'; Dir = (DirU 'ISOU' 97 258); Expect = 'plug-in message'; Iso = $true }
    if ($Only) { $cases = @($cases | Where-Object { $Only -contains $_.N }) }

    Out ("arcpath_probe (feature 097, S1) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv093]::GetACP())
    Out ("Config  : registry key existed {0}; fresh defaults {1}" -f $existed, $fresh)
    Out 'Routes  : ENTER (End, Enter in the archive''s folder); CHDIR (Change Directory, command 862, wide WM_SETTEXT, OK); START (-l "<archive>")'
    Out 'Verdict : against the S1 expectation (C200, A259 open the requested archive without a message; every other case: exactly one "too long" message, panel stays, never twin.txt)'
    Out ''
    foreach ($c in $cases) {
        $c.Arc = $c.Dir + $(if ($c.Iso) { '\arc.iso' } else { '\arc.zip' })
        [void][IO.Directory]::CreateDirectory($LP + $c.Dir)
        if ($c.Iso) { [IO.File]::WriteAllBytes($LP + $c.Arc, (New-Object byte[] 65536)) }
        elseif ($c.Zip) { $z = $Root + '\case_' + $c.N + '.zip'; New-Zip $z $c.Zip; [IO.File]::Copy($z, $LP + $c.Arc, $true) }
        else { [IO.File]::Copy($realZip, $LP + $c.Arc, $true) }
        if ($c.Twin) { [IO.File]::Copy($twinZip, $LP + $c.Twin, $true) }
        if (-not [IO.File]::Exists($LP + $c.Arc)) { throw ('fixture not created: ' + $c.N) }
        Out ("fixture {0,-6} archive full name {1} bytes / {2} characters; first 259 bytes end with {3}{4}{5}" -f $c.N, (U8Len $c.Arc), $c.Arc.Length, (Cut259 $c.Arc), `
                $(if ($c.Twin) { '; twin archive (twin.txt) at exactly that name, ' + (U8Len $c.Twin) + ' bytes, exists=' + [IO.File]::Exists($LP + $c.Twin) } else { '' }), `
                $(if ($c.Inner) { '; inner path of d3 ' + (U8Len $c.Inner) + ' bytes (d1\d2 ' + ((U8Len $d1) + 1 + (U8Len $d2)) + ')' } else { '' }))
    }
    foreach ($c in $cases) {
        Out ''
        Out ("--- {0} (expected: {1})" -f $c.N, $c.Expect)
        if ($c.Iso) { Run-Iso $c }
        elseif ($c.Inner) { Run-Inner $c }
        else { foreach ($rt in $c.Routes) { Run-Route $c $rt } }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message) ; $script:ProbeError = $true }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 500
    $restored = Restore-TcRegistry $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture : could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    Out ''
    Out '=== summary ==='
    foreach ($x in $script:Rows) { Out ('{0,-6} {1,-10} {2,-10} {3}' -f $x.Case, $x.Step, $x.Verdict, $x.Short) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    $twinShown = @($script:Rows | Where-Object { $_.Short -match 'TWIN' }).Count
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}; rows that showed the twin archive: {3}. Left running: {4}; fixture removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, $twinShown, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
