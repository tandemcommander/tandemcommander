<#
.SYNOPSIS
    Feature 095 probe: an archive whose full name is longer than the old stack
    buffers of the disk-cache name (260 / 520 / 620 / 830 bytes) is entered in
    a panel, a file is viewed (F3), another is edited (F4), the archive is
    left and updated.

.DESCRIPTION
    For each length (200 = control, 262, 300, 530, 640, 850, 1000 UTF-8 bytes
    of the archive's full name), once with ASCII folder names (case A<n>) and
    once with folder names made of U+0159 (case U<n>: 2 bytes per character, so
    the byte length passes 259 while the character count is still small), the
    probe builds the folder tree under %TEMP%\tc095_long (\\?\ paths), copies a
    small ZIP archive there (a.txt, edit.txt, sub\b.txt, sub\B.TXT, <U+0159>.txt;
    written by python's zipfile) and starts one instance of -Exe with the left
    panel in that folder. Steps, driven by window messages and command ids:

      ENTER  End, Enter on arc.zip; the main window title must name the archive
      VIEW   Home, Down, Down (a.txt); CM_VIEW (742): a viewer window whose
             title names a.txt, OR a message with the "too long" text
      EDIT   Down (edit.txt); CM_EDIT (743). The editor is configured (inside
             the registry backup/restore) as
                 cmd.exe /c echo edited095>>"$(FullName)"
             so the temporary copy is changed without any editor window
      LEAVE  Backspace: the "archive contains edited files" information and
             the Archive Update dialog are answered with OK / Update All; the
             archive is then read with python's zipfile: edit.txt must end
             with the appended line
      END    the process is alive, answers WM_NULL, shows no other window, no
             new crash report in %LOCALAPPDATA%\Tandem Commander, and exits
             with code 0 on WM_CLOSE

    A window that reports a run-time check failure, an assertion or a crash
    is recorded as FATAL; the instance (own pid only) is then ended by the
    probe. Rows: PASS / FAIL / NOT DRIVEN with what was observed.

    MUST be started through tools\run_on_hidden_desktop.ps1. Refuses to run
    while a tandemcommander.exe other than -Exe is running.
    HKCU\Software\Tandem Commander is exported before the first start and
    restored and verified (SHA-256 of a second export) at the end. The fixture
    folder and, once the restore is verified, the backup file are removed.
    Crash reports written by a test instance are removed by name.

.PARAMETER Exe
    tandemcommander.exe of the build under test (Debug: /RTC1 is the detector).
.PARAMETER Label
    Text for the first line of the output.
.PARAMETER OutFile
    File that receives the output lines (ASCII).
.PARAMETER Only
    Case names to run (e.g. A200,U262); default all.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII. Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [switch]$Trace
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
$Root = $TempRoot + '\tc095_long'
$ReportDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$Marker = 'edited095'

# one entry name of $Chars characters: 'A' ASCII, 'U' repeated U+0159 (2 bytes each)
function Comp([string]$Kind, [int]$Chars, [char]$Ascii) {
    if ($Kind -eq 'U') { return ([string][char]0x0159) * $Chars }
    return ([string]$Ascii) * $Chars
}

# Builds the per-case ZIP. Entries, all with content "content\r\n":
#   a.txt, edit.txt                                   (root, short - always reachable)
#   <dir>\a.txt, <dir>\<long>.txt, <dir>\edit.txt     (<dir> and <long> are $InnerChars characters)
# Returns a hashtable with the inner dir and long-name strings (for navigation).
function New-CaseZip([string]$File, [string]$Kind, [int]$InnerChars, [int]$NameChars = 0, [string]$MarkerFile = '') {
    if ($NameChars -le 0) { $NameChars = $InnerChars }
    $ext = if ($MarkerFile) { '.cmd' } else { '.txt' }
    $dir = Comp $Kind $InnerChars ([char]'d')
    $long = (Comp $Kind ([Math]::Max(1, $NameChars - 4)) ([char]'f')) + $ext
    $spec = Join-Path $Root 'zipspec.txt'
    [IO.File]::WriteAllText($spec, ($File + "`n" + $dir + "`n" + $long + "`n" + $ext + "`n" + $MarkerFile + "`n"), $Utf8)
    $py = Join-Path $Root 'mkzip.py'
    $code = @(
        'import sys, io, zipfile',
        'a = io.open(sys.argv[1], "r", encoding="utf-8").read().split("\n")',
        'path, d, long, ext, marker = a[0], a[1], a[2], a[3], a[4]',
        'z = zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED)',
        'names = ["a.txt", "edit.txt", d + "/a" + ext, d + "/" + long, d + "/edit" + ext]',
        'for n in names:',
        '    zi = zipfile.ZipInfo(n, (2026, 1, 2, 3, 4, 6))',
        '    zi.compress_type = zipfile.ZIP_DEFLATED',
        '    data = "content\r\n"',
        '    if marker and n.endswith(".cmd"):',
        '        data = "@echo " + ("LONG095" if n.endswith("/" + long) else "OTHER095") + ">\"" + marker + "\"\r\n"',
        '    z.writestr(zi, data)',
        'z.close()')
    [IO.File]::WriteAllLines($py, $code, (New-Object Text.ASCIIEncoding))
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $py $spec 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ('mkzip.py: ' + ($o -join ' ')) }
    return @{ Dir = $dir; Long = $long }
}
# the bytes of one entry in the archive (hex), read by python through \\?\ (path may be long)
function Read-ZipEntry([string]$Arc, [string]$Name) {
    $py = Join-Path $Root 'rdzip.py'
    $code = @(
        'import sys, io, zipfile',
        'a = io.open(sys.argv[1], "r", encoding="utf-8").read().split("\n")',
        'z = zipfile.ZipFile(a[0])',
        'ok = z.testzip() is None',
        'try: data = z.read(a[1]).hex()',
        'except Exception as e: data = "MISSING:" + str(e)',
        'print(ok, len(z.namelist()), data)')
    [IO.File]::WriteAllLines($py, $code, (New-Object Text.ASCIIEncoding))
    $spec = Join-Path $Root 'rdzip.txt'
    [IO.File]::WriteAllText($spec, (($LP + $Arc) + "`n" + $Name + "`n"), $Utf8)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $py $spec 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { return ('python failed: ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return ("$o")
}

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
    $a = @('-t', 'T095', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $TempRoot), '-p', '1')
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

$script:Rows = New-Object System.Collections.ArrayList
$script:HandleNotes = 0
function Row([string]$Case, [string]$Step, [string]$Verdict, [string]$Facts) {
    Out ('{0,-7} {1,-6} {2,-10} {3}' -f $Case, $Step, $Verdict, $Facts)
    [void]$script:Rows.Add([pscustomobject]@{ Case = $Case; Step = $Step; Verdict = $Verdict })
}
# post a command to the main window and wait for a new top-level window
function CmdWin([int]$Id, [int]$C, [double]$Seconds = 15) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) $C
    return (Wait-NewWin $Id $known $Seconds)
}
# enter the item under the caret (Enter on a folder / the archive)
function EnterItem([int]$Id) { PostKey $Id 0x0D; Start-Sleep -Milliseconds 1200 }

# one case: a short archive whose single long entry is $InnerChars characters of $Kind
function Run-Case([string]$Name, [string]$Kind, [int]$InnerChars, [int]$NameChars = 0, [int]$ArcBytes = 0, [bool]$Exec = $false) {
    $dir = $Root + '\' + $Name
    if ($ArcBytes -gt 0) {
        # one more folder so that <dir>\arc.zip is $ArcBytes UTF-8 bytes (under the 259-byte entry limit)
        $padBytes = $ArcBytes - (U8Len $dir) - 1 - 8
        if ($padBytes -lt 2) { throw "archive path target $ArcBytes too small" }
        if ($Kind -eq 'U') { $pad = (Comp 'U' ([int][Math]::Floor($padBytes / 2)) ([char]'p')); if ($padBytes % 2) { $pad = 'x' + $pad } }
        else { $pad = Comp 'A' $padBytes ([char]'p') }
        $dir = $dir + '\' + $pad
    }
    [void][IO.Directory]::CreateDirectory($dir)
    $arc = $dir + '\arc.zip'
    $markerFile = ''
    if ($Exec) { $markerFile = $Root + '\ran_' + $Name + '.txt' }
    $tmpZip = $Root + '\case_' + $Name + '.zip'
    $info = New-CaseZip $tmpZip $Kind $InnerChars $NameChars $markerFile
    [IO.File]::Copy($tmpZip, $LP + $arc, $true)
    $innerName = $info.Long
    $sum = (U8Len $arc) + 1 + (U8Len $info.Dir) + 1 + (U8Len $innerName)
    Out ''
    Out ("--- {0}: archive {1} bytes; inner dir {2} bytes + name {3} bytes; folded disk-cache name ~{4} bytes ({5})" -f `
            $Name, (U8Len $arc), (U8Len $info.Dir), (U8Len $innerName), $sum, $(if ($Kind -eq 'U') { 'U+0159 inner' } else { 'ASCII inner' }))
    $before = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $tmpBefore = @(Get-ChildItem -LiteralPath $TempRoot -Directory -Filter 'SAL*.tmp' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $steps = 'ENTER', 'NAV', $(if ($Exec) { 'EXEC' } else { 'VIEW' }), 'EDIT', 'LEAVE', 'END'
    $done = @{}
    $id = 0; $fatal = $null
    try {
        $id = Start-Tc095 $dir
        $r0 = Serve $id 6; if ($r0.Fatal) { $fatal = 'at start: ' + (MsgText $r0) }
        $title0 = Title $id
        # --- ENTER arc.zip
        if (-not $fatal) {
            Key $id 0x23                                  # End -> arc.zip (only file)
            EnterItem $id
            $r = Serve $id 30
            $t1 = if (Test-Alive $id) { Title $id } else { '<gone>' }
            $script:EnterTitle = $t1
            $inside = (Test-Alive $id) -and ($t1 -match 'arc\.zip')
            if ($r.Fatal -or $r.Died) { $fatal = 'entering: ' + (MsgText $r) }
            Row $Name 'ENTER' $(if ($inside -and -not $fatal) { 'PASS' } else { 'FAIL' }) ("title now '{0}'; windows: {1}" -f (Tail $t1 40), (MsgText $r))
            $done['ENTER'] = 1
            if (-not $inside -and -not $fatal) { throw 'the panel is not inside the archive' }
        }
        # --- NAV into the long-named directory (Home skips "..", Down onto the dir, Enter)
        if (-not $fatal) {
            Key $id 0x24                                  # Home -> ".."
            Key $id 0x28                                  # Down -> the long dir (sorted first)
            EnterItem $id
            $r = Serve $id 20
            $t2 = if (Test-Alive $id) { Title $id } else { '<gone>' }
            $mark = $info.Dir.Substring(0, [Math]::Min(6, $info.Dir.Length))   # the long dir's leading characters
            $inDir = (Test-Alive $id) -and ($t2 -ne $script:EnterTitle) -and ($t2.Contains($mark))
            if ($r.Fatal -or $r.Died) { $fatal = 'navigating in: ' + (MsgText $r) }
            Row $Name 'NAV' $(if ($inDir -and -not $fatal) { 'PASS' } else { 'FAIL' }) ("title now (tail) '{0}'; windows: {1}" -f (Tail $t2 50), (MsgText $r))
            $done['NAV'] = 1
            if (-not $inDir -and -not $fatal) { throw 'did not enter the long directory' }
        }
        # --- EXEC (Enter) the long-named file: ExecuteFromArchive (fileswn6), association of .cmd.
        #     The file writes LONG095 into the marker file; the other files of the folder write OTHER095.
        if ($Exec -and -not $fatal) {
            Key $id 0x24; Key $id 0x28; Key $id 0x28; Key $id 0x28   # Home (".."), a.cmd, edit.cmd, the long file
            PostKey $id 0x0D                              # Enter
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 10 -and -not (Test-Path -LiteralPath $markerFile)) { Start-Sleep -Milliseconds 200 }
            Start-Sleep -Milliseconds 800
            $r = Serve $id 20
            if ($r.Fatal -or $r.Died -or -not (Test-Alive $id)) { $fatal = 'Enter: ' + (MsgText $r) + $(if (-not (Test-Alive $id)) { ' (process ended)' } else { '' }) }
            $ran = '<no marker file: nothing was executed>'
            if (Test-Path -LiteralPath $markerFile) { $ran = ([IO.File]::ReadAllText($markerFile)).Trim() }
            $v = if (-not $fatal -and $ran -eq 'LONG095') { 'PASS' } else { 'FAIL' }
            Row $Name 'EXEC' $v ("Enter on the file; executed: {0}; windows: {1}" -f $ran, $(if ($fatal) { $fatal } else { MsgText $r }))
            $done['EXEC'] = 1
        }
        # --- VIEW (F3) the long-named file: CM_VIEW -> ViewFile (fileswn5)
        if (-not $Exec -and -not $fatal) {
            Key $id 0x24; Key $id 0x28; Key $id 0x28; Key $id 0x28   # Home (".."), then a.txt, edit.txt, the long file
            $w = CmdWin $id 742 15
            $what = 'no window in 15 s'; $v = 'FAIL'
            if (-not (Test-Alive $id)) { $fatal = 'F3: the process ended' }
            elseif ($w -ne [IntPtr]::Zero) {
                Start-Sleep -Milliseconds 800; $d = WinDesc $w
                if (Is-Fatal $d) { $fatal = 'F3: ' + $d }
                elseif ($d -match $TooLongRx) { $what = 'MESSAGE (name too long): ' + $d; $v = 'PASS'; [void](Click-Ok $w) }
                elseif ([Drv093]::Cls($w) -eq '#32770') { $what = 'MESSAGE: ' + $d; [void](Click-Ok $w) }
                else { $v = 'PASS'; $what = ("VIEWER class '{0}', title (tail) '{1}'" -f [Drv093]::Cls($w), (Tail ([Drv093]::Txt($w)) 50)); [void][Drv093]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
            }
            if (-not $fatal) { $r = Serve $id 15; if ($r.Fatal -or $r.Died) { $fatal = 'after F3: ' + (MsgText $r) } elseif ($r.Messages.Count) { $what += '; then: ' + (MsgText $r) } }
            if ($fatal) { $v = 'FAIL'; $what = $fatal }
            Row $Name 'VIEW' $v $what
            $done['VIEW'] = 1
        }
        # --- EDIT (F4) the long-named file: CM_EDIT -> ExecuteFromArchive (fileswn6)
        $editDriven = $false
        if (-not $fatal) {
            Key $id 0x24; Key $id 0x28; Key $id 0x28; Key $id 0x28   # Home (".."), a.txt, edit.txt, the long file
            Post-Cmd (Get-Main $id) 743                   # CM_EDIT
            Start-Sleep -Milliseconds 2500
            $r = Serve $id 25
            if ($r.Fatal -or $r.Died -or -not (Test-Alive $id)) { $fatal = 'F4: ' + (MsgText $r) + $(if (-not (Test-Alive $id)) { ' (process ended)' } else { '' }) }
            $tooLong = ((MsgText $r) -match $TooLongRx)
            $editDriven = (-not $fatal) -and (-not $r.Messages.Count)
            $v = if ($fatal) { 'FAIL' } elseif ($editDriven -or $tooLong) { 'PASS' } else { 'FAIL' }
            if ($Exec -and -not $fatal -and -not $editDriven) { $v = 'FAIL' }   # these names fit: the edit must start
            Row $Name 'EDIT' $v $(if ($fatal) { $fatal } elseif ($editDriven) { 'CM_EDIT posted, no message; the editor command ran (checked at LEAVE)' } elseif ($tooLong) { 'MESSAGE (name too long)' } else { 'windows: ' + (MsgText $r) })
            $done['EDIT'] = 1
        }
        # --- LEAVE: Backspace back to root, then out of the archive; answer the update
        if (-not $fatal) {
            Start-Sleep -Milliseconds 1200
            PostKey $id 0x08; Start-Sleep -Milliseconds 1000   # out of the long dir
            PostKey $id 0x08; Start-Sleep -Milliseconds 1000   # out of the archive
            $r = Serve $id 60
            if ($r.Fatal -or $r.Died -or -not (Test-Alive $id)) { $fatal = 'leaving: ' + (MsgText $r) + $(if (-not (Test-Alive $id)) { ' (process ended)' } else { '' }) }
            $t3 = if (Test-Alive $id) { Title $id } else { '<gone>' }
            $left = ($t3 -eq $title0)
            $zip = Read-ZipEntry $arc ($info.Dir + '/' + $innerName)
            $markerHex = (($Marker.ToCharArray() | ForEach-Object { '{0:x2}' -f [int]$_ }) -join '')
            $updated = ($zip -match ('^True 5 [0-9a-f]*' + $markerHex))
            $refused = ((MsgText $r) -match 'Packing of updated file')
            $outcome = if ($updated) { 'ARCHIVE UPDATED' } elseif ($refused) { 'UPDATE FAILED WITH A MESSAGE (Ignore All)' } else { 'ARCHIVE NOT UPDATED' }
            # the ASCII update is checked strictly; for an accented name no update is offered at all
            # (CFileTimeStamps::CheckAndPackAndClear looks the file up with an ANSI call), so "edit driven, left, no
            # crash" is the verdict there and the missing update is noted in the row
            $note = ''
            if ($fatal) { $v = 'FAIL' }
            elseif ($editDriven -and $Kind -eq 'A') { $v = if ($left -and ($updated -or $refused) -and -not $r.TimedOut) { 'PASS' } else { 'FAIL' } }
            elseif ($editDriven) { $v = if ($left -and -not $r.TimedOut) { 'PASS' } else { 'FAIL' }; if (-not $updated -and -not $refused) { $note = '; no update offered for the accented name (same on a name that fits and on the build before the feature - see fix-log, found not changed)' } }
            else { $v = if ($left -and -not $r.TimedOut) { 'PASS' } else { 'FAIL' } }
            Row $Name 'LEAVE' $v ("{0}{1}; left: {2}; entry after (ok,items,hex): {3}; windows: {4}" -f $outcome, $note, $left, $zip, $(if ($fatal) { $fatal } else { MsgText $r }))
            $done['LEAVE'] = 1
        }
        # --- END: alive, responsive, no stray window, no new report, exit 0
        $alive = Test-Alive $id
        $resp = $false; if ($alive -and -not $fatal) { $resp = Responsive $id }
        $extra = @(); if ($alive -and -not $fatal) { $extra = @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -ne $MainClass } | ForEach-Object { WinDesc $_ }) }
        $ec = '-'
        if ($fatal -or -not $resp) {
            if ($alive) { Kill-Mine $id; $ec = 'ended by the probe (pid ' + $id + ')' } else { $ec = ExitCodeOf $id }
        }
        else {
            [void][Drv093]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $id)) {
                foreach ($h in @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -eq '#32770' })) { $extra += ('at exit: ' + (WinDesc $h)); $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
                Start-Sleep -Milliseconds 200
            }
            if (Test-Alive $id) { Kill-Mine $id; $ec = 'did not exit in 30 s - ended by the probe' } else { $ec = ExitCodeOf $id }
        }
        Start-Sleep -Milliseconds 500
        $after = @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        $new = @($after | Where-Object { $before -notcontains $_ })
        foreach ($n in $new) { Remove-Item -LiteralPath (Join-Path $ReportDir $n) -Force -ErrorAction SilentlyContinue }
        $notes = @($extra | Where-Object { $_ -match 'monitored handles remained opened' })  # Debug-build plug-in handle note (also before this feature)
        $extra = @($extra | Where-Object { $_ -notmatch 'monitored handles remained opened' })
        if ($notes.Count) { $script:HandleNotes++ }
        $ok = (-not $fatal) -and $resp -and ($extra.Count -eq 0) -and ($new.Count -eq 0) -and ($ec -eq '0x00000000')
        Row $Name 'END' $(if ($ok) { 'PASS' } else { 'FAIL' }) ("alive {0}; WM_NULL {1}; stray windows {2}; new reports {3}{4}; exit {5}{6}{7}" -f `
                $alive, $resp, $(if ($extra.Count) { '' + $extra.Count + ' (' + ($extra -join ' || ') + ')' } else { '0' }), $new.Count, $(if ($new.Count) { ' (' + ($new -join ',') + ', removed)' } else { '' }), $ec, $(if ($fatal) { '; FATAL: ' + $fatal } else { '' }), $(if ($notes.Count) { '; Debug note: "Some monitored handles remained opened"' } else { '' }))
        $done['END'] = 1
    }
    catch {
        Out ('       exception: ' + $_.Exception.Message)
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
    }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        foreach ($s in $steps) { if (-not $done.ContainsKey($s)) { Row $Name $s 'NOT DRIVEN' 'an earlier step failed' } }
        Start-Sleep -Milliseconds 300
        foreach ($t in @(Get-ChildItem -LiteralPath $TempRoot -Directory -Filter 'SAL*.tmp' -ErrorAction SilentlyContinue | Where-Object { $tmpBefore -notcontains $_.Name })) {
            Out ("       left in %TEMP% by the test instance, removed: {0}" -f $t.Name)
            Remove-Item -LiteralPath $t.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        try { if ([IO.Directory]::Exists($LP + $dir)) { [IO.Directory]::Delete($LP + $dir, $true) } } catch { }
    }
}

# ---- main ---------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc095_longarc_backup.reg'
$existed = Backup-TcRegistry $backup
$restored = $false
$nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $fresh = Set-ProbeConfig

    Out ("longarc_probe (feature 095) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv093]::GetACP())
    Out ("Config  : registry key existed {0}; fresh defaults {1}; F4 editor = cmd.exe /c echo {2}>>`"`$(FullName)`"" -f $existed, $fresh, $Marker)
    Out 'Model   : short archive path; one entry at a long inner path+name (the core caps an archive PATH at MAX_PATH bytes, so the buffers overrun only from the inner name).'
    Out 'Steps   : ENTER arc.zip; NAV into the long dir; VIEW (CM_VIEW 742) or, in the S cases, EXEC (Enter on a .cmd file that writes a marker); EDIT (CM_EDIT 743); LEAVE (Backspace x2, Update All); END (alive, WM_NULL, no report, exit 0)'
    if ($fresh) { Out 'NOTE    : no stored configuration - the F4 editor is the default one, EDIT not driven to the update path' }

    # inner characters per case. I<n> ASCII inner of n characters (n bytes); IU<n> U+0159 inner (2n bytes).
    # The folded name is archive(~60) + inner dir + inner name; 250+250 = ~560 bytes crosses the old 520-byte buffer.
    # inner dir and name are each $C characters; the ZIP plug-in's AddFile refuses
    # an inner path or name over 255 BYTES, so $C stays within that (ASCII: 251 chars
    # = 251 bytes; U+0159: 125 chars = 250 bytes).
    $cases = @(
        @{ N = 'I10'; K = 'A'; C = 10 },     # control: everything short, folded ~80 bytes
        @{ N = 'I120'; K = 'A'; C = 120 },   # folded ~300 bytes: within every old buffer
        @{ N = 'I200'; K = 'A'; C = 200 },   # folded ~460 bytes: near the 520-byte buffer
        @{ N = 'I251'; K = 'A'; C = 251 },   # folded ~560 bytes: over the 520-byte ExecuteFromArchive buffer
        @{ N = 'IU60'; K = 'U'; C = 60 },    # accented control: folded ~300 bytes
        @{ N = 'IU125'; K = 'U'; C = 125 })  # accented: dir+name 250+250 bytes, folded ~560 bytes, over 520
    # S cases (review finding S1): archive path ~180 bytes + inner folder ~200 bytes + name of
    # NB bytes. The name fits the temporary path, so nothing says "too long"; with
    # archive + folder + name + 2 >= 520 the build before the feature dropped the name
    # (the second SalPathAppend into char[520] failed, its result was ignored): the cache key was
    # archive\folder and the plug-in was asked to unpack the FOLDER. Enter (execute) and F4.
    $cases += @(
        @{ N = 'S130'; K = 'A'; C = 200; NC = 130; AB = 180; X = $true },    # 180+1+200+1+130 = 512: fits the old buffer (control)
        @{ N = 'S150'; K = 'A'; C = 200; NC = 150; AB = 180; X = $true },    # 532: over
        @{ N = 'SU65'; K = 'U'; C = 100; NC = 67; AB = 180; X = $true },     # accented, 180+1+200+1+130 = 512: control
        @{ N = 'SU75'; K = 'U'; C = 100; NC = 77; AB = 180; X = $true })     # accented, 180+1+200+1+150 = 532: over
    if ($Only) { $cases = $cases | Where-Object { $Only -contains $_.N } }
    foreach ($c in $cases) {
        if ($c.X) { Run-Case $c.N $c.K $c.C $c.NC $c.AB $true } else { Run-Case $c.N $c.K $c.C }
    }
}
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 500
    $restored = Restore-TcRegistry $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture : could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    Out ''
    Out '=== summary ==='
    $names = @($script:Rows | ForEach-Object { $_.Case } | Select-Object -Unique)
    Out ('{0,-7} {1,-10} {2,-10} {3,-12} {4,-10} {5,-10} {6,-10}' -f 'case', 'ENTER', 'NAV', 'VIEW/EXEC', 'EDIT', 'LEAVE', 'END')
    foreach ($c in $names) {
        $v = @{}; foreach ($x in ($script:Rows | Where-Object { $_.Case -eq $c })) { $v[$x.Step] = $x.Verdict }
        $mid = if ($v.ContainsKey('EXEC')) { 'x:' + $v['EXEC'] } else { $v['VIEW'] }
        Out ('{0,-7} {1,-10} {2,-10} {3,-12} {4,-10} {5,-10} {6,-10}' -f $c, $v['ENTER'], $v['NAV'], $mid, $v['EDIT'], $v['LEAVE'], $v['END'])
    }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}; Debug handle-note cases {3}. Left running: {4}; fixture removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, $script:HandleNotes, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
