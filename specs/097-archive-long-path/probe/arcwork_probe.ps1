<#
.SYNOPSIS
    Feature 097 probe (stage S2): a ZIP, 7z or TAR archive at a path longer
    than 259 bytes (and longer than 259 characters) is entered and worked
    with like an archive at a short path.

.DESCRIPTION
    Fixtures under %TEMP%\tc097_work (created through \\?\, removed at the
    end). Each archive holds a.txt, del.txt and sub\b.txt; its folder also
    holds add.txt. Lengths of the archive's full name:

      C200   200 bytes ASCII (control)
      U130   about 280 bytes / 170 characters (folder name of U+0159)
      U200   about 417 bytes / 237 characters
      B259   259 characters, about 660 bytes (folder name of U+20AC, 3 bytes)
      L300A  300 characters ASCII (longer than MAX_PATH in characters)
      L300U  about 300 characters / 540 bytes, accented

    One instance of -Exe per archive (left panel in the archive's folder,
    right panel in a short output folder), driven by window messages:

      ENTER    End, Enter on the archive: the title names it
      VIEW     Home, Down, Down (a.txt); F3 (command 742): the viewer's title
               names a.txt
      UNPACK   F5 (command 727) with the short output folder as the target:
               the unpacked a.txt has the expected content
      EDIT     F4 (command 743); the editor is cmd.exe /c echo edited097>>file
      UPDATE   Backspace: "archive is about to close" + Archive Update are
               answered; the archive is read back (python / 7z.exe): a.txt
               ends with the marker                      (ZIP, 7z; TAR: leave)
      REENTER  End, Enter again
      DELETE   del.txt, F8 (command 729), confirmed; read back: del.txt is
               gone                                               (ZIP, 7z)
      LEAVE    Backspace: the panel is in the archive's folder
      ADD      add.txt, F5 with the target "<archive>\": read back: add.txt
               is in the archive                                  (ZIP, 7z)
      TWO      enter again; "right panel = left panel's path" (849); leave on
               the left; "left = right panel's path" (848): the left panel
               is in the archive again (so the right one was)
      HIST     Backspace, then Back (832): the panel is in the archive again
      TAB      New tab (2860), Backspace, Previous tab (2869): the first tab
               returns into the archive
      END      alive, WM_NULL answered, no stray window, no crash report,
               exit code 0
      RESTART  the program was closed with the panel inside the archive; it is
               started again without -l: the stored panel path (the archive's
               folder, by design) is restored without a message; END2 as END
    Further lengths: A1000 / E1000 / A5000 / E5000 (1,000 and 5,000 bytes,
    ASCII and U+20AC folders) for ZIP and 7z, A7000 for TAR.
    A run-time-check / assertion / crash window at any step is FATAL.

    Extra rows:
      CLIP     inside the U130 ZIP archive: Copy to clipboard (773) on a.txt
               (the pasted-data object holds the archive name in 260 bytes:
               expected "too long", or nothing when the shell-extension shared
               memory is not available)
      HDEAD    history over a dead archive (short path): arc.zip on a subst
               drive is entered, the panel goes elsewhere, the drive is removed,
               Back is pressed: each Back must move on (error for the archive,
               error for the drive, then the start folder), never the same
               error twice. The drive is removed in a finally block.
      RELL     start with a RELATIVE -l value that fits the 519-byte field but
               not once it is made absolute: expected one "too long" message

    MUST be started through tools\run_on_hidden_desktop.ps1. Refuses to run
    while a tandemcommander.exe other than -Exe is running.
    HKCU\Software\Tandem Commander is exported before the first start and
    restored and verified (SHA-256 of a second export) at the end.

.PARAMETER Exe
    tandemcommander.exe of the build under test.
.PARAMETER Only
    Case names to run (e.g. zipU130,7zB259,tarC200,CLIP,RELL); default all.

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
$LP = '\\?\'
$Utf8 = New-Object Text.UTF8Encoding($false)
function U8Len([string]$s) { return $Utf8.GetByteCount($s) }
function Tail([string]$s, [int]$n = 60) { if ($s.Length -le $n) { return (Esc $s) }; return ('...' + (Esc $s.Substring($s.Length - $n))) }

$TempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$Root = $TempRoot + '\tc097_work'
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
function Start-Tc097([string]$Left, [string]$Right = $TempRoot) {
    $a = @('-t', 'T097'); if ($Left) { $a += @('-l', ('"{0}"' -f $Left)) }; $a += @('-r', ('"{0}"' -f $Right), '-p', '1')
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

# ---- S2: working with an archive at a long path ---------------------------------
$Marker = 'edited097'
$Euro = [string][char]0x20AC
$Content = "content of a.txt`r`n"

function Set-WorkConfig {
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    $fresh = ($LASTEXITCODE -ne 0)
    if (-not $fresh) {
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Panel Tabs' /t REG_DWORD /d 1 /f | Out-Null
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

function Run-Py([string[]]$Code, [string[]]$PyArgs) {
    $py = Join-Path $Root 'tool.py'
    [IO.File]::WriteAllLines($py, $Code, (New-Object Text.ASCIIEncoding))
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $py @PyArgs 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ('python: ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}
# the three source archives, built once from a stage folder
function New-Sources {
    $st = $Root + '\stage'
    [void][IO.Directory]::CreateDirectory($st + '\sub')
    $enc = New-Object Text.ASCIIEncoding
    [IO.File]::WriteAllText($st + '\a.txt', $Content, $enc)
    [IO.File]::WriteAllText($st + '\del.txt', "content of del.txt`r`n", $enc)
    [IO.File]::WriteAllText($st + '\sub\b.txt', "content of b.txt`r`n", $enc)
    Run-Py @(
        'import sys, os, zipfile, tarfile',
        'st, root = sys.argv[1], sys.argv[2]',
        'names = ["a.txt", "del.txt", "sub/b.txt"]',
        'z = zipfile.ZipFile(os.path.join(root, "src.zip"), "w", zipfile.ZIP_DEFLATED)',
        'for n in names: z.write(os.path.join(st, n), n)',
        'z.close()',
        't = tarfile.open(os.path.join(root, "src.tar"), "w")',
        'for n in names: t.add(os.path.join(st, n), n)',
        't.close()') @($st, $Root)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $st
    try { $o = & $SevenZip a -t7z ($Root + '\src.7z') '*' -r 2>&1; $rc = $LASTEXITCODE } finally { Pop-Location; $ErrorActionPreference = $old }
    if ($rc -ne 0) { throw ('7z a: ' + ($o -join ' ')) }
}
# reads an archive back (a copy at a short path): the file names and the text of a.txt
function Read-Arc([string]$Fmt, [string]$Arc) {
    $chk = $Root + '\chk.' + $Fmt; $x = $Root + '\chkx'
    try {
        if ([IO.Directory]::Exists($x)) { [IO.Directory]::Delete($x, $true) }
        [IO.File]::Copy($LP + $Arc, $chk, $true)
        if ($Fmt -eq '7z') {
            $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            $o = & $SevenZip x $chk ('-o' + $x) -y 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
            if ($rc -ne 0) { return [pscustomobject]@{ Names = ('7z x failed rc ' + $rc); A = '' } }
        }
        else {
            Run-Py @(
                'import sys, zipfile, tarfile',
                'fmt, p, o = sys.argv[1], sys.argv[2], sys.argv[3]',
                'if fmt == "zip":',
                '    z = zipfile.ZipFile(p)',
                '    assert z.testzip() is None',
                '    z.extractall(o)',
                'else:',
                '    tarfile.open(p).extractall(o)') @($Fmt, $chk, $x)
        }
        $names = @([IO.Directory]::GetFiles($x, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($x.Length + 1).Replace('\', '/') } | Sort-Object)
        $a = ''; if ([IO.File]::Exists($x + '\a.txt')) { $a = [IO.File]::ReadAllText($x + '\a.txt') }
        return [pscustomobject]@{ Names = ($names -join ','); A = $a }
    }
    catch { return [pscustomobject]@{ Names = ('read failed: ' + $_.Exception.Message); A = '' } }
}

# the folder of the archive for each length
function Work-Dir([string]$Name, [string]$Kind) {
    $b = Base $Name
    switch ($Kind) {
        'C200' { return (DirA $Name 200) }
        'U130' { return (DirU $Name 112 259) }
        'U200' { return (DirU $Name 180 259) }
        'B259' { return ($b + '\' + ($Euro * (259 - $b.Length - 9))) }
        'L300A' { return (DirA $Name 300) }
        'L300U' { return ($b + '\' + ($R * 200) + '\' + ($R * (300 - $b.Length - 210))) }
    }
    if ($Kind -match '^A(\d+)$') { return (DirA $Name ([int]$Matches[1])) }
    if ($Kind -match '^E(\d+)$') {
        # folders of 200 x U+20AC (600 bytes each); the archive's full name has exactly the given bytes
        $rem = [int]$Matches[1] - (U8Len $b) - 9
        $d = $b
        while ($rem -gt 601) { $d += '\' + ($Euro * 200); $rem -= 601 }
        $k = [int][Math]::Floor($rem / 3)
        return ($d + '\' + ('x' * ($rem % 3)) + ($Euro * $k))
    }
    throw "kind $Kind"
}

function TitleOf([int]$Id) { if (Test-Alive $Id) { return (Title $Id) } else { return '<gone>' } }
function Short([string]$t) { return (Esc $t.Substring(0, [Math]::Min(26, $t.Length))) }
function Focus([int]$Id, [int]$Downs) { Key $Id 0x24; for ($i = 0; $i -lt $Downs; $i++) { Key $Id 0x28 } }
# F5 with an explicit target; returns $true when the field held the text
function Do-Copy([int]$Id, [string]$Target) {
    $dlg = Open-ByCmd $Id 727 10
    if ($dlg -eq [IntPtr]::Zero) { throw 'Copy (command 727) opened no window' }
    $d = WinDesc $dlg
    if (Is-Fatal $d) { throw ('FATAL ' + $d) }
    $ctl = Find-Ctl $dlg 210
    if ($ctl -eq [IntPtr]::Zero) { [void](Click-Ok $dlg); throw ('the window opened by Copy has no path field: ' + $d) }
    [void][Drv093]::SetText($ctl, $Target, 5000)
    $held = [Drv093]::GetText($ctl, 5000)
    [void](Click-Ok $dlg)
    Start-Sleep -Milliseconds 800
    return ($held -ceq $Target)
}

function Run-Work($c) {
    $N = $c.N; $fmt = $c.Fmt; $canEdit = ($fmt -ne 'tar')
    $before = Reports; $tmpBefore = TmpDirs
    $steps = 'ENTER', 'VIEW', 'UNPACK', 'EDIT', 'UPDATE', 'REENTER', 'DELETE', 'LEAVE', 'ADD', 'TWO', 'HIST', 'TAB', 'RESTART'
    $done = @{}; $id = 0; $fatal = $null; $endDone = $false
    $rx = 'arc\.' + $fmt + ' - '
    function Step([string]$S, [bool]$Ok, [string]$Short, [string]$Facts) { Row $N $S $(if ($Ok) { 'PASS' } else { 'FAIL' }) $Short $Facts; $done[$S] = 1 }
    function NA([string]$S) { Row $N $S 'n/a' 'not supported by this archive type' '-'; $done[$S] = 1 }
    function Chk($r, [string]$Where) { if ($r.Fatal -or $r.Died) { throw ('FATAL at ' + $Where + ': ' + (MsgList $r.Messages) + $(if ($r.Died) { ' (process ended)' } else { '' })) } }
    try {
        # the tabs stored by the previous instance would stand between "new tab" and "previous tab"
        foreach ($side in 'Left Panel', 'Right Panel') { & cmd.exe /c ('reg delete "' + $RegKey + '\0.1\' + $side + '\Tabs" /f >nul 2>&1') }
        # a folder of 520 bytes or more does not fit the -l field (519 bytes; refused with a message
        # since S1): the instance starts in the fixture root and goes there through Change Directory
        $viaDlg = ((U8Len $c.Dir) -ge 520)
        $id = Start-Tc097 $(if ($viaDlg) { $Root } else { $c.Dir }) $c.Out
        if ($script:StartMsgs.Count) { throw ('message at start: ' + (MsgList $script:StartMsgs)) }
        $r = Serve97 $id 10; Chk $r 'start'
        if ($r.Messages.Count) { throw ('message at start: ' + (MsgList $r.Messages)) }
        if ($viaDlg) {
            $heldDir = Do-ChangeDir $id $c.Dir
            $r = Serve97 $id 20; Chk $r 'Change Directory'
            if ($r.Messages.Count -or -not $heldDir) { throw ('Change Directory to the fixture folder: field held the text ' + $heldDir + '; ' + (MsgList $r.Messages)) }
            Out '       (folder of 520+ bytes: reached through Change Directory, not -l)'
        }
        $title0 = TitleOf $id
        if ($title0 -match 'T097 - tc097_work - ') { throw 'the left panel is not in the fixture folder' }
        # ENTER
        Key $id 0x23; EnterItem $id
        $r = Serve97 $id 30; Chk $r 'ENTER'
        $t = TitleOf $id; $in = ($t -match $rx)
        Step 'ENTER' ($in -and $r.Messages.Count -eq 0) $(if ($in) { 'entered' } elseif ($r.Messages.Count) { 'NOT entered: message' } else { 'NOT entered: nothing shown' }) ("title '{0}' -> '{1}'; windows ({2}): {3}" -f (Short $title0), (Short $t), $r.Messages.Count, (MsgList $r.Messages))
        if (-not $in) { throw 'the panel is not inside the archive' }
        # VIEW
        Focus $id 2
        $w = CmdWin $id 742 15; $what = 'no viewer window in 15 s'; $ok = $false
        if ($w -ne [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 800; $d = WinDesc $w
            if (Is-Fatal $d) { throw ('FATAL at VIEW: ' + $d) }
            if ([Drv093]::Cls($w) -eq '#32770') { $what = 'message: ' + $d; [void](Click-Ok $w) }
            else { $vt = [Drv093]::Txt($w); $ok = ($vt -match 'a\.txt'); $what = "viewer title (tail) '" + (Tail $vt 44) + "'"; [void][Drv093]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 700 }
        }
        $r = Serve97 $id 8; Chk $r 'VIEW'
        Step 'VIEW' $ok $(if ($ok) { 'a.txt shown' } else { 'a.txt NOT shown' }) $what
        # UNPACK
        Focus $id 2
        $held = Do-Copy $id $c.Out
        $r = Serve97 $id 40; Chk $r 'UNPACK'
        $got = ''; if ([IO.File]::Exists($c.Out + '\a.txt')) { $got = [IO.File]::ReadAllText($c.Out + '\a.txt') }
        Step 'UNPACK' ($got -ceq $Content) $(if ($got -ceq $Content) { 'a.txt unpacked, content equal' } else { 'a.txt NOT unpacked' }) ("target field held the text: {0}; windows ({1}): {2}" -f $held, $r.Messages.Count, (MsgList $r.Messages))
        # EDIT + UPDATE
        if ($canEdit) {
            Focus $id 2
            # the command is taken only when the program is idle and its command states are up to date
            # (a posted F4 right after the copy operation was sometimes ignored, on every build): the
            # probe waits, and posts it once more when nothing happened in 8 s
            Start-Sleep -Milliseconds 1500
            [void][Drv093]::Send((Get-Main $id), 0, 0, 0, 20000)
            $ran = $false; $attempts = 0
            while (-not $ran -and $attempts -lt 2) {
                $attempts++
                Post-Cmd (Get-Main $id) 743
                # wait until the editor command has appended the marker to the temporary copy
                $sw = [Diagnostics.Stopwatch]::StartNew()
                while ($sw.Elapsed.TotalSeconds -lt 8 -and -not $ran) {
                    Start-Sleep -Milliseconds 400
                    if (@(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -ne $MainClass }).Count) { break }
                    foreach ($d in @(Get-ChildItem -LiteralPath $TempRoot -Directory -Filter 'SAL*.tmp' -ErrorAction SilentlyContinue | Where-Object { $tmpBefore -notcontains $_.Name })) {
                        $f = Join-Path $d.FullName 'a.txt'
                        if ([IO.File]::Exists($f)) { try { if ([IO.File]::ReadAllText($f).Contains($Marker)) { $ran = $true } } catch { } }
                    }
                }
                if (@(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -ne $MainClass }).Count) { break }
            }
            Start-Sleep -Milliseconds 1500
            $r = Serve97 $id 20; Chk $r 'EDIT'
            Step 'EDIT' ($ran -and $r.Messages.Count -eq 0) $(if ($r.Messages.Count) { 'message' } elseif ($ran) { 'editor command ran (marker in the temporary copy)' } else { 'NO marker in a temporary copy' }) ("F4 posted x{0}; windows ({1}): {2}" -f $attempts, $r.Messages.Count, (MsgList $r.Messages))
        }
        else { NA 'EDIT' }
        Start-Sleep -Milliseconds 800
        PostKey $id 0x08; Start-Sleep -Milliseconds 1000
        $r = Serve97 $id 60; Chk $r 'UPDATE'
        $t = TitleOf $id; $left = ($t -eq $title0)
        if ($canEdit) {
            $a = Read-Arc $fmt $c.Arc
            $upd = $a.A.Contains($Marker)
            Step 'UPDATE' ($left -and $upd) $(if ($upd) { 'archive updated (a.txt ends with the marker)' } else { 'ARCHIVE NOT UPDATED' }) ("left the archive: {0}; archive now: {1}; windows ({2}): {3}" -f $left, $a.Names, $r.Messages.Count, (MsgList $r.Messages))
        }
        else { Step 'UPDATE' $left $(if ($left) { 'left the archive (nothing to update)' } else { 'DID NOT LEAVE' }) ("windows ({0}): {1}" -f $r.Messages.Count, (MsgList $r.Messages)) }
        if (-not $left) { throw 'the panel did not leave the archive' }
        # REENTER
        Key $id 0x23; EnterItem $id
        $r = Serve97 $id 30; Chk $r 'REENTER'
        $t = TitleOf $id; $in = ($t -match $rx)
        Step 'REENTER' ($in -and $r.Messages.Count -eq 0) $(if ($in) { 'entered' } else { 'NOT entered' }) ("title '{0}'; windows ({1}): {2}" -f (Short $t), $r.Messages.Count, (MsgList $r.Messages))
        if (-not $in) { throw 'the panel is not inside the archive (2)' }
        # DELETE
        if ($canEdit) {
            Focus $id 3
            Post-Cmd (Get-Main $id) 729
            Start-Sleep -Milliseconds 1200
            $r = Serve97 $id 60; Chk $r 'DELETE'
            $a = Read-Arc $fmt $c.Arc
            $gone = ($a.Names -notmatch 'del\.txt') -and ($a.Names -match 'a\.txt')
            Step 'DELETE' $gone $(if ($gone) { 'del.txt deleted from the archive' } else { 'del.txt NOT deleted' }) ("archive now: {0}; windows ({1}): {2}" -f $a.Names, $r.Messages.Count, (MsgList $r.Messages))
        }
        else { NA 'DELETE' }
        # LEAVE
        Start-Sleep -Milliseconds 500
        PostKey $id 0x08; Start-Sleep -Milliseconds 1000
        $r = Serve97 $id 40; Chk $r 'LEAVE'
        $t = TitleOf $id; $left = ($t -eq $title0)
        Step 'LEAVE' $left $(if ($left) { 'in the archive''s folder' } else { 'NOT in the archive''s folder' }) ("title '{0}'; windows ({1}): {2}" -f (Short $t), $r.Messages.Count, (MsgList $r.Messages))
        if (-not $left) { throw 'the panel did not leave the archive (2)' }
        # ADD
        if ($canEdit) {
            Focus $id 1
            $held = Do-Copy $id ($c.Arc + '\')
            $r = Serve97 $id 60; Chk $r 'ADD'
            $a = Read-Arc $fmt $c.Arc
            $added = ($a.Names -match 'add\.txt')
            Step 'ADD' $added $(if ($added) { 'add.txt packed into the archive' } else { 'add.txt NOT in the archive' }) ("target field held the text: {0}; archive now: {1}; windows ({2}): {3}" -f $held, $a.Names, $r.Messages.Count, (MsgList $r.Messages))
        }
        else { NA 'ADD' }
        # TWO panels
        Start-Sleep -Milliseconds 500
        Key $id 0x23; EnterItem $id
        $r = Serve97 $id 30; Chk $r 'TWO (enter)'
        $tA = TitleOf $id
        Post-Cmd (Get-Main $id) 849; Start-Sleep -Milliseconds 1500      # right panel = the left panel's path
        $r1 = Serve97 $id 30; Chk $r1 'TWO (849)'
        PostKey $id 0x08; Start-Sleep -Milliseconds 1000                 # leave on the left
        $r2 = Serve97 $id 30; Chk $r2 'TWO (leave)'
        $tB = TitleOf $id
        Post-Cmd (Get-Main $id) 848; Start-Sleep -Milliseconds 1500      # left panel = the right panel's path
        $r3 = Serve97 $id 30; Chk $r3 'TWO (848)'
        $tC = TitleOf $id
        $ok = ($tA -match $rx) -and ($tB -eq $title0) -and ($tC -match $rx)
        $nm = $r.Messages.Count + $r1.Messages.Count + $r2.Messages.Count + $r3.Messages.Count
        Step 'TWO' ($ok -and $nm -eq 0) $(if ($ok) { 'both panels were in the archive' } else { 'NOT both panels' }) ("titles '{0}' / '{1}' / '{2}'; windows ({3}): {4}" -f (Short $tA), (Short $tB), (Short $tC), $nm, (MsgList (@($r.Messages) + @($r1.Messages) + @($r2.Messages) + @($r3.Messages))))
        if (-not ($tC -match $rx)) { throw 'the left panel is not in the archive for HIST' }
        # HIST
        PostKey $id 0x08; Start-Sleep -Milliseconds 1000
        $r1 = Serve97 $id 30; Chk $r1 'HIST (leave)'
        $tB = TitleOf $id
        Post-Cmd (Get-Main $id) 832; Start-Sleep -Milliseconds 1500      # Back
        $r2 = Serve97 $id 30; Chk $r2 'HIST (back)'
        $tC = TitleOf $id
        $ok = ($tB -eq $title0) -and ($tC -match $rx)
        Step 'HIST' ($ok -and ($r1.Messages.Count + $r2.Messages.Count) -eq 0) $(if ($ok) { 'Back returned into the archive' } else { 'Back did NOT return into the archive' }) ("titles '{0}' / '{1}'; windows: {2}" -f (Short $tB), (Short $tC), (MsgList (@($r1.Messages) + @($r2.Messages))))
        # TAB
        if ($tC -match $rx) {
            Post-Cmd (Get-Main $id) 2860; Start-Sleep -Milliseconds 1500  # new tab
            $r1 = Serve97 $id 30; Chk $r1 'TAB (new)'
            $tN = TitleOf $id
            if ($tN -match $rx) { PostKey $id 0x08; Start-Sleep -Milliseconds 1000 }
            $r2 = Serve97 $id 30; Chk $r2 'TAB (leave)'
            $tB = TitleOf $id
            Post-Cmd (Get-Main $id) 2869; Start-Sleep -Milliseconds 1500  # previous tab
            $r3 = Serve97 $id 30; Chk $r3 'TAB (prev)'
            $tC = TitleOf $id
            $ok = ($tB -notmatch $rx) -and ($tC -match $rx)
            $nm = $r1.Messages.Count + $r2.Messages.Count + $r3.Messages.Count
            Step 'TAB' ($ok -and $nm -eq 0) $(if ($ok) { 'the tab returned into the archive' } else { 'the tab did NOT return into the archive' }) ("titles new tab '{0}' / after leaving '{1}' / previous tab '{2}'; windows ({3}): {4}" -f (Short $tN), (Short $tB), (Short $tC), $nm, (MsgList (@($r1.Messages) + @($r2.Messages) + @($r3.Messages))))
        }
        # RESTART: the program is closed with the panel inside the archive and started again without
        # -l: the stored panel path (the archive's folder, however long) is restored without a message
        $inAtExit = ((TitleOf $id) -match $rx)
        End-Instance $N 'END' $id $null $before
        $endDone = $true
        if ($inAtExit) {
            $id2 = Start-Tc097 '' $c.Out
            $id = $id2
            $sm = @($script:StartMsgs)
            $r = Serve97 $id2 20; Chk $r 'RESTART'
            $t = TitleOf $id2
            $nm = $sm.Count + $r.Messages.Count
            # (the program stores the archive's FOLDER as the panel path: by design it starts there, on every build)
            Step 'RESTART' (($t -eq $title0) -and $nm -eq 0) $(if ($t -eq $title0) { 'started in the archive''s folder (stored panel path)' } else { 'NOT in the archive''s folder after the start' }) ("title '{0}'; windows ({1}): {2}" -f (Short $t), $nm, (MsgList ($sm + @($r.Messages))))
            End-Instance $N 'END2' $id2 $null $before
        }
        else { Step 'RESTART' $false 'not driven: the panel was not in the archive at exit' '-' }
    }
    catch {
        $m = $_.Exception.Message
        Out ('       stopped: ' + $(if ($m.Length -gt 700) { $m.Substring(0, 700) + '...' } else { $m }))
        if ($m -match '^FATAL') { $fatal = $m }
        if ($id -and -not $endDone) { End-Instance $N 'END' $id $fatal $before; $endDone = $true }
    }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        foreach ($s in $steps) { if (-not $done.ContainsKey($s)) { Row $N $s 'NOT DRIVEN' 'not driven' 'an earlier step failed' } }
        if (-not $endDone) { Row $N 'END' 'NOT DRIVEN' 'not driven' 'the instance did not start' }
        Start-Sleep -Milliseconds 300
        Remove-NewTmp $tmpBefore
    }
}

# CLIP: Copy to clipboard inside the archive at a long path
function Run-Clip($c) {
    $before = Reports; $tmpBefore = TmpDirs; $id = 0; $endDone = $false; $rowDone = $false
    try {
        foreach ($side in 'Left Panel', 'Right Panel') { & cmd.exe /c ('reg delete "' + $RegKey + '\0.1\' + $side + '\Tabs" /f >nul 2>&1') }
        $id = Start-Tc097 $c.Dir $c.Out
        $r = Serve97 $id 10
        Key $id 0x23; EnterItem $id
        $r = Serve97 $id 30
        $t = TitleOf $id
        if ($t -notmatch 'arc\.zip - ') { Row 'CLIP' 'COPY' 'NOT DRIVEN' 'not driven' ('the archive was not entered; windows: ' + (MsgList $r.Messages)); $rowDone = $true }
        else {
            Focus $id 2
            Post-Cmd (Get-Main $id) 773; Start-Sleep -Milliseconds 1500
            $r = Serve97 $id 20
            $nLong = @($r.Messages | Where-Object { $_ -match $TooLongRx }).Count
            $fatal = $r.Fatal -or $r.Died
            $short = if ($fatal) { 'FATAL' } elseif ($nLong) { ('REFUSED: "too long" message x{0}' -f $nLong) } elseif ($r.Messages.Count) { 'other message' } else { 'nothing shown' }
            Row 'CLIP' 'COPY' $(if ($fatal -or ($r.Messages.Count -gt 0 -and -not $nLong)) { 'FAIL' } else { 'PASS' }) $short ("archive full name {0} bytes; windows ({1}): {2}" -f (U8Len $c.Arc), $r.Messages.Count, (MsgList $r.Messages))
            $rowDone = $true
        }
        End-Instance 'CLIP' 'END' $id $null $before; $endDone = $true
    }
    catch { Out ('       exception: ' + $_.Exception.Message) }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        if (-not $rowDone) { Row 'CLIP' 'COPY' 'NOT DRIVEN' 'not driven' 'see above' }
        if (-not $endDone) { Row 'CLIP' 'END' 'NOT DRIVEN' 'not driven' 'see above' }
        Remove-NewTmp $tmpBefore
    }
}

# RELL: a relative -l value (310 bytes) started from a folder of 200 bytes: absolute it has 560+ bytes
function Run-Rel {
    $before = Reports; $tmpBefore = TmpDirs; $id = 0; $endDone = $false; $rowDone = $false
    try {
        $cwd = (Base 'rel') + '\' + ('w' * 200)
        [void][IO.Directory]::CreateDirectory($cwd)
        $rel = ('q' * 150) + '\' + ('q' * 150) + '\arc.zip'
        $a = @('-t', 'T097', '-l', ('"{0}"' -f $rel), '-r', ('"{0}"' -f $TempRoot), '-p', '1')
        $p = Start-Process -FilePath $Exe -ArgumentList $a -WorkingDirectory $cwd -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
        $msgs = New-Object System.Collections.ArrayList; $seen = @{}
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) {
            foreach ($h in @(Get-Tops $p.Id | Where-Object { [Drv093]::Cls($_) -eq '#32770' })) {
                $key = $h.ToInt64()
                if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
                if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
                [void]$msgs.Add('(before the main window) ' + (WinDesc $h)); $seen.Remove($key)
                $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1
                if ($b) { Click $b }
                Start-Sleep -Milliseconds 500
            }
            Start-Sleep -Milliseconds 100
        }
        if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        $id = $p.Id
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2500
        $r = Serve97 $id 10
        foreach ($m in $r.Messages) { [void]$msgs.Add($m) }
        $nLong = @($msgs | Where-Object { $_ -match $TooLongRx }).Count
        $ok = ($nLong -eq 1) -and ($msgs.Count -eq 1)
        Row 'RELL' 'START' $(if ($ok) { 'PASS' } else { 'FAIL' }) $(if ($nLong) { ('REFUSED: "too long" message x{0}' -f $nLong) } elseif ($msgs.Count) { 'OTHER MESSAGE' } else { 'SILENT: nothing shown' }) ("relative value {0} bytes, current folder {1} bytes; title '{2}'; windows ({3}): {4}" -f (U8Len $rel), (U8Len $cwd), (Short (TitleOf $id)), $msgs.Count, (MsgList $msgs))
        $rowDone = $true
        End-Instance 'RELL' 'END' $id $null $before; $endDone = $true
    }
    catch { Out ('       exception: ' + $_.Exception.Message) }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        if (-not $rowDone) { Row 'RELL' 'START' 'NOT DRIVEN' 'not driven' 'see above' }
        if (-not $endDone) { Row 'RELL' 'END' 'NOT DRIVEN' 'not driven' 'see above' }
        Remove-NewTmp $tmpBefore
    }
}

# HDEAD: history Back over an archive whose drive is gone (SHORT path; second review, blocker 1).
# A subst drive holds arc.zip; the panel enters it, goes elsewhere, the drive is removed, Back is
# pressed until the panel is in the start folder again (at most 5 times). The history must move on
# after each error, as before the feature: the same error must not come twice.
function Run-HistDead {
    $before = Reports; $tmpBefore = TmpDirs; $id = 0; $endDone = $false; $rowDone = $false
    $drive = $null
    $src = (Base 'hdead') + '\drv'; $start = (Base 'hdead') + '\start'; $else = (Base 'hdead') + '\elsewhere'
    try {
        foreach ($d in $src, $start, $else) { [void][IO.Directory]::CreateDirectory($d) }
        [IO.File]::Copy(($Root + '\src.zip'), ($src + '\arc.zip'), $true)
        foreach ($l in 'Q', 'P', 'O', 'N', 'M', 'L', 'K') { if (-not [IO.Directory]::Exists($l + ':\')) { $drive = $l; break } }
        if (-not $drive) { throw 'no free drive letter' }
        & subst.exe ($drive + ':') $src | Out-Null
        if (-not [IO.File]::Exists($drive + ':\arc.zip')) { throw 'subst drive not created' }
        foreach ($side in 'Left Panel', 'Right Panel') { & cmd.exe /c ('reg delete "' + $RegKey + '\0.1\' + $side + '\Tabs" /f >nul 2>&1') }
        $id = Start-Tc097 $start
        $r = Serve97 $id 10
        $title0 = TitleOf $id
        [void](Do-ChangeDir $id ($drive + ':\'))
        $r = Serve97 $id 20
        Key $id 0x23; EnterItem $id
        $r = Serve97 $id 30
        $tArc = TitleOf $id
        [void](Do-ChangeDir $id $else)
        $r = Serve97 $id 20
        $tElse = TitleOf $id
        if ($tArc -notmatch 'arc\.zip - ') { throw ('the archive on the subst drive was not entered: ' + (Short $tArc)) }
        & subst.exe ($drive + ':') /D | Out-Null
        $seq = @(); $reached = 0; $errs = @()
        for ($i = 1; $i -le 5 -and -not $reached; $i++) {
            Post-Cmd (Get-Main $id) 832; Start-Sleep -Milliseconds 1500
            $r = Serve97 $id 30
            if ($r.Fatal -or $r.Died) { throw ('FATAL at Back ' + $i + ': ' + (MsgList $r.Messages)) }
            $t = TitleOf $id
            $m = (($r.Messages | ForEach-Object { $x = $_ -replace '^.*?\] \[Static id=\d+\] ', ''; if ($x.Length -gt 60) { $x.Substring(0, 60) } else { $x } }) -join ' / ')
            $errs += $m
            $seq += ("Back {0}: '{1}'{2}" -f $i, (Short $t), $(if ($m) { ' after "' + $m + '"' } else { '' }))
            if ($t -eq $title0) { $reached = $i }
        }
        $dup = $false
        for ($i = 1; $i -lt $errs.Count; $i++) { if ($errs[$i] -and $errs[$i] -eq $errs[$i - 1]) { $dup = $true } }
        $ok = ($reached -gt 0) -and -not $dup
        Row 'HDEAD' 'BACK' $(if ($ok) { 'PASS' } else { 'FAIL' }) $(if ($reached) { ('start folder reached at Back {0}' -f $reached) } else { 'STUCK: the start folder was not reached in 5 Backs' }) ("same error twice in a row: {0}; sequence: {1}" -f $dup, ($seq -join '; '))
        $rowDone = $true
        End-Instance 'HDEAD' 'END' $id $null $before; $endDone = $true
    }
    catch { Out ('       exception: ' + $_.Exception.Message) }
    finally {
        if ($drive) { & cmd.exe /c ('subst ' + $drive + ': /D >nul 2>&1') }
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        if (-not $rowDone) { Row 'HDEAD' 'BACK' 'NOT DRIVEN' 'not driven' 'see above' }
        if (-not $endDone) { Row 'HDEAD' 'END' 'NOT DRIVEN' 'not driven' 'see above' }
        Remove-NewTmp $tmpBefore
    }
}

# ---- main ---------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc097_arcwork_backup.reg'
$existed = Backup-TcRegistry $backup
$restored = $false
$nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $fresh = Set-WorkConfig
    if ($fresh) { throw 'no stored configuration - the F4 editor cannot be configured' }
    New-Sources

    $cases = @()
    foreach ($fmt in 'zip', '7z', 'tar') {
        foreach ($kind in 'C200', 'U130', 'U200', 'B259', 'L300A', 'L300U') {
            $n = $fmt + $kind
            $cases += @{ N = $n; Fmt = $fmt; Kind = $kind }
        }
    }
    # very long paths (second review): ASCII and three-byte-character folders
    foreach ($fmt in 'zip', '7z') { foreach ($kind in 'A1000', 'E1000', 'A5000', 'E5000') { $cases += @{ N = ($fmt + $kind); Fmt = $fmt; Kind = $kind } } }
    $cases += @{ N = 'tarA7000'; Fmt = 'tar'; Kind = 'A7000' }
    if ($Only) { $cases = @($cases | Where-Object { $Only -contains $_.N }) }

    Out ("arcwork_probe (feature 097, S2) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv093]::GetACP())
    Out ("Config  : registry key existed {0}; F4 editor = cmd.exe /c echo {1}>>`"`$(FullName)`"" -f $existed, $Marker)
    Out ''
    foreach ($c in $cases) {
        $c.Dir = Work-Dir $c.N $c.Kind
        $c.Arc = $c.Dir + '\arc.' + $c.Fmt
        $c.Out = $Root + '\o_' + $c.N
        [void][IO.Directory]::CreateDirectory($LP + $c.Dir)
        [void][IO.Directory]::CreateDirectory($c.Out)
        [IO.File]::Copy(($Root + '\src.' + $c.Fmt), $LP + $c.Arc, $true)
        [IO.File]::WriteAllText($LP + $c.Dir + '\add.txt', "added`r`n", (New-Object Text.ASCIIEncoding))
        Out ("fixture {0,-9} archive full name {1} bytes / {2} characters" -f $c.N, (U8Len $c.Arc), $c.Arc.Length)
    }
    foreach ($c in $cases) {
        Out ''
        Out ("--- {0}" -f $c.N)
        Run-Work $c
    }
    if (Want 'CLIP') {
        Out ''; Out '--- CLIP'
        $c = @{ N = 'clip'; Fmt = 'zip' }; $c.Dir = Work-Dir 'clip' 'U130'; $c.Arc = $c.Dir + '\arc.zip'; $c.Out = $Root + '\o_clip'
        [void][IO.Directory]::CreateDirectory($LP + $c.Dir); [void][IO.Directory]::CreateDirectory($c.Out)
        [IO.File]::Copy(($Root + '\src.zip'), $LP + $c.Arc, $true)
        Run-Clip $c
    }
    if (Want 'RELL') { Out ''; Out '--- RELL'; Run-Rel }
    if (Want 'HDEAD') { Out ''; Out '--- HDEAD'; Run-HistDead }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 500
    $restored = Restore-TcRegistry $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture : could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    Out ''
    Out '=== summary ==='
    $stepNames = 'ENTER', 'VIEW', 'UNPACK', 'EDIT', 'UPDATE', 'REENTER', 'DELETE', 'LEAVE', 'ADD', 'TWO', 'HIST', 'TAB', 'END', 'RESTART', 'END2'
    Out (('{0,-9} ' -f 'case') + (($stepNames | ForEach-Object { '{0,-8}' -f $_ }) -join ''))
    foreach ($n in @($script:Rows | ForEach-Object { $_.Case } | Select-Object -Unique)) {
        if ($n -eq 'CLIP' -or $n -eq 'RELL' -or $n -eq 'HDEAD') { continue }
        $v = @{}; foreach ($x in ($script:Rows | Where-Object { $_.Case -eq $n })) { $v[$x.Step] = $x.Verdict }
        Out (('{0,-9} ' -f $n) + (($stepNames | ForEach-Object { '{0,-8}' -f $(if ($v[$_] -eq 'NOT DRIVEN') { '-' } else { $v[$_] }) }) -join ''))
    }
    foreach ($x in @($script:Rows | Where-Object { $_.Case -eq 'CLIP' -or $_.Case -eq 'RELL' -or $_.Case -eq 'HDEAD' })) { Out ('{0,-6} {1,-8} {2,-10} {3}' -f $x.Case, $x.Step, $x.Verdict, $x.Short) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    $na = @($script:Rows | Where-Object { $_.Verdict -eq 'n/a' }).Count
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}, n/a {3}. Left running: {4}; fixture removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, $na, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
