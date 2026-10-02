<#
.SYNOPSIS
    Feature 093, stage S3: the command line of the main window (ComboBox id
    955 and its inner edit) with text outside the system code page.

.DESCRIPTION
    Starts tandemcommander.exe (-Exe) on a fixture folder and drives the
    command line with window messages only. Rows:

      C1   IsWindowUnicode of the combo box and of its inner edit
      C2   programmatic set (WM_SETTEXT, wide) and read back, combo and edit
      C3   typing: WM_CHAR posted per UTF-16 unit to the inner edit (served by
           the main message loop), read back; also U+010D / U+0109, whose low
           bytes are those of Enter and Tab
      C4   name insertion (Ctrl+Enter in the command line) for every fixture
           file: the text of the command line afterwards
      C5   the same into the middle of "ab": caret position (EM_GETSEL, UTF-16
           units) and where the next typed character lands
      C6   run a command: copy nul "<name>.flag" + Enter; the file on disk
      C7   history: first item of the drop-down after each command; recall
           of the newest item by Ctrl+Down; the stored
           "Command History" after a normal exit; the password of a URL is not
           stored (feature 085)
      C8   Ctrl+Backspace (word deletion) and Backspace
      C9   the path prefix (a Static child of the combo): informational
      C10  ASCII regression drive: typing, Home / End / Left, Shift+Left,
           replacing a selection (each checked by where the next typed
           character lands), Esc

    Each of C2, C3, C6, C8 is run with an ASCII text, a text of the system
    code page (1250: U+0159, U+017E, U+010D) and a text outside it (Cyrillic,
    CJK, a surrogate pair).

    Keys with Ctrl / Shift: the program reads the modifier with GetKeyState.
    The probe attaches its thread to the program's input queue
    (AttachThreadInput), sets the modifier in the shared key state
    (SetKeyboardState), SENDS WM_KEYDOWN + WM_KEYUP to the inner edit and
    takes the modifier back. No SendInput, nothing reaches another process.

    One line per row:
      row | case | what | exp=<...> | act=<...> | verdict | note
    Text is printed as hex UTF-16 units. Verdicts: PASS, FAIL, INFO,
    NOT DRIVEN.

    SAFETY: only the process started here is addressed, by pid; messages go
    only to its windows. HKCU\Software\Tandem Commander is exported before the
    start and restored and verified (SHA-256 of a second export) at the end.
    Values changed for the run: UI language (English), the exit confirmation,
    "Close Shell Window" (1, so that the shell of a command ends), the
    history switches and "Command Line" (shown). Shells started by the
    commands are children of the test process; any that is left is ended by
    pid. The fixture %TEMP%\tc093_cmd is removed.

.PARAMETER Exe
    tandemcommander.exe to measure.
.PARAMETER Label
    Free text printed in the first line (which build this is).
.PARAMETER OutFile
    Also write every printed line to this file (UTF-8, the content is ASCII).

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII (strings are built from
    character codes). Run it through tools\run_on_hidden_desktop.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path

if (-not ('Cmd093' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Cmd093
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int l, t, r, b; }
    [StructLayout(LayoutKind.Sequential)] public struct GUITHREADINFO { public int cbSize, flags; public IntPtr hwndActive, hwndFocus, hwndCapture, hwndMenuOwner, hwndMoveSize, hwndCaret; public RECT rcCaret; }
    [StructLayout(LayoutKind.Sequential)] public struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public int x, y; }

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendTextTimeout(IntPtr h, uint msg, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendGetText(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] public static extern bool GetKeyboardState(byte[] s);
    [DllImport("user32.dll")] public static extern bool SetKeyboardState(byte[] s);
    [DllImport("user32.dll")] public static extern bool GetGUIThreadInfo(uint tid, ref GUITHREADINFO gi);
    [DllImport("user32.dll")] public static extern bool PeekMessageW(out MSG m, IntPtr h, uint a, uint b, uint remove);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
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
    public static List<IntPtr> Kids(IntPtr parent)
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
    public static string GetText(IntPtr h, uint timeout)
    {
        IntPtr res; var buf = new char[8192];
        SendGetText(h, 0x000D, (IntPtr)buf.Length, buf, 0, timeout, out res);
        int n = (int)res.ToInt64();
        if (n < 0) n = 0; if (n > buf.Length) n = buf.Length;
        return new string(buf, 0, n);
    }
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
    // EM_GETSEL without pointers: start in the low word, end in the high word
    public static int[] GetSel(IntPtr h, uint timeout)
    {
        IntPtr res;
        if (SendMessageTimeoutW(h, 0x00B0, IntPtr.Zero, IntPtr.Zero, 0, timeout, out res) == IntPtr.Zero) return new int[] { -1, -1 };
        long v = res.ToInt64();
        return new int[] { (int)(v & 0xFFFF), (int)((v >> 16) & 0xFFFF) };
    }
    // WM_KEYDOWN + WM_KEYUP sent to 'h' while the shared key state says Ctrl / Shift
    // are down (or up). Returns "" or the reason it could not be done.
    public static string KeyMods(IntPtr h, int vk, bool ctrl, bool shift, uint timeout)
    {
        uint pid; uint tid = GetWindowThreadProcessId(h, out pid); uint me = GetCurrentThreadId();
        MSG m; PeekMessageW(out m, IntPtr.Zero, 0, 0, 0);       // makes sure this thread has a queue
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed";
        string err = "";
        try
        {
            var old = new byte[256];
            GetKeyboardState(old);
            var st = (byte[])old.Clone();
            foreach (int k in new int[] { 0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5 }) st[k] = 0;
            var clean = (byte[])st.Clone();
            if (ctrl) { st[0x11] = 0x80; st[0xA2] = 0x80; }
            if (shift) { st[0x10] = 0x80; st[0xA0] = 0x80; }
            if (!SetKeyboardState(st)) err = "SetKeyboardState failed";
            else
            {
                IntPtr res;
                if (SendMessageTimeoutW(h, 0x0100, (IntPtr)vk, (IntPtr)1, 0, timeout, out res) == IntPtr.Zero) err = "WM_KEYDOWN timed out";
                SendMessageTimeoutW(h, 0x0101, (IntPtr)vk, (IntPtr)unchecked((int)0xC0000001), 0, timeout, out res);
            }
            SetKeyboardState(clean);
        }
        finally { AttachThreadInput(me, tid, false); }
        return err;
    }
    public static IntPtr FocusOf(IntPtr anyWindowOfThread)
    {
        uint pid; uint tid = GetWindowThreadProcessId(anyWindowOfThread, out pid);
        var gi = new GUITHREADINFO(); gi.cbSize = Marshal.SizeOf(typeof(GUITHREADINFO));
        if (!GetGUIThreadInfo(tid, ref gi)) return IntPtr.Zero;
        return gi.hwndFocus;
    }
    public static int WidthOf(IntPtr h) { RECT r; if (!GetWindowRect(h, out r)) return -1; return r.r - r.l; }
}
'@
}

$MainClass = 'TandemCommanderMainWindowVer01'
$RegKey = 'HKCU\Software\Tandem Commander'
$Started = New-Object System.Collections.ArrayList
$script:Procs = @{}
$script:ExitCodes = New-Object System.Collections.ArrayList
$script:Lines = New-Object System.Collections.ArrayList
$script:Pass = 0; $script:Fail = 0; $script:NotDriven = 0; $script:Info = 0
$script:Unexpected = @()

function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
function Hex([string]$s) {
    if ($null -eq $s) { return '<null>' }
    if ($s.Length -eq 0) { return '<empty>' }
    return (($s.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ')
}
function Esc([string]$s) {
    if ($null -eq $s) { return '<null>' }
    $sb = New-Object Text.StringBuilder
    foreach ($c in $s.ToCharArray()) { if ([int]$c -ge 32 -and [int]$c -lt 127) { [void]$sb.Append($c) } else { [void]$sb.AppendFormat('\u{0:X4}', [int]$c) } }
    return $sb.ToString()
}
function Out([string]$line) { Write-Host $line; [void]$script:Lines.Add($line) }
function Row([string]$Id, [string]$Case, [string]$What, [string]$Exp, [string]$Act, [string]$Verdict, [string]$Note) {
    $line = "{0,-4}| {1,-6}| {2,-44}| exp={3} | act={4} | {5}" -f $Id, $Case, $What, $Exp, $Act, $Verdict
    if ($Note) { $line += " | $Note" }
    Out $line
    if ($Verdict -eq 'PASS') { $script:Pass++ } elseif ($Verdict -eq 'FAIL') { $script:Fail++ } elseif ($Verdict -like 'NOT DRIVEN*') { $script:NotDriven++ } else { $script:Info++ }
}
function Verdict([bool]$ok) { if ($ok) { return 'PASS' } else { return 'FAIL' } }

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
    if ($ha -eq $hb) { Remove-Item -LiteralPath $File -Force }
    return ($ha -eq $hb)
}

# ---- process and windows ----------------------------------------------------
function Test-Alive([int]$Id) { return [bool](Get-Process -Id $Id -ErrorAction SilentlyContinue) }
function Get-Tops([int]$Id) { return @([Cmd093]::Top([uint32]$Id)) }
function Get-Main([int]$Id) {
    foreach ($h in [Cmd093]::Top([uint32]$Id)) { if ([Cmd093]::Cls($h) -eq $MainClass) { return $h } }
    return [IntPtr]::Zero
}
function Sync([int]$Id) {
    $m = Get-Main $Id
    if ($m -eq [IntPtr]::Zero) { throw 'no main window' }
    [void][Cmd093]::Send($m, 0, 0, 0, 20000)
}
function Get-DialogText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Cmd093]::Kids($H)) {
        $t = [Cmd093]::Txt($c)
        if ($t -and [Cmd093]::IsWindowVisible($c)) { $parts += ("[{0} id={1}] {2}" -f [Cmd093]::Cls($c), [Cmd093]::GetDlgCtrlID($c), (Esc ($t -replace '\s+', ' '))) }
    }
    $r = ($parts -join ' | ')
    if ($r.Length -gt 400) { $r = $r.Substring(0, 400) + '...' }
    return $r
}
function Close-Win([int]$Id, [IntPtr]$H) {
    if (-not [Cmd093]::IsWindow($H)) { return }
    if ([Cmd093]::PidOf($H) -ne [uint32]$Id) { throw 'window does not belong to the test process' }
    [void][Cmd093]::PostMessageW($H, 0x0111, [IntPtr]2, [IntPtr]::Zero)      # IDCANCEL
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Cmd093]::IsWindow($H) -and [Cmd093]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
    if ([Cmd093]::IsWindow($H) -and [Cmd093]::IsWindowVisible($H)) {
        [void][Cmd093]::PostMessageW($H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw.Restart()
        while ($sw.Elapsed.TotalSeconds -lt 3 -and [Cmd093]::IsWindow($H) -and [Cmd093]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
    }
}
# closes every top-level window of the pid except the main one; returns their descriptions
function Clear-Wins([int]$Id, [string]$Where, [bool]$Record = $true) {
    $seen = @()
    for ($round = 0; $round -lt 4; $round++) {
        # (the system's "UAC Input Indicator" windows of a hidden desktop are not the program's)
        $extra = @(Get-Tops $Id | Where-Object { [Cmd093]::Cls($_) -ne $MainClass -and [Cmd093]::Cls($_) -notlike 'UAC*' })
        if (-not $extra.Count) { break }
        foreach ($h in $extra) {
            $d = ("{0}: window class={1} title='{2}': {3}" -f $Where, [Cmd093]::Cls($h), (Esc ([Cmd093]::Txt($h))), (Get-DialogText $h))
            $seen += $d
            if ($Record) { Out "   UNEXPECTED $d"; $script:Unexpected += $d }
            Close-Win $Id $h
        }
    }
    return $seen
}
function Start-Tc([string]$Dir) {
    $a = @('-t', 'T093C', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Dir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id)
    [void]$p.Handle
    $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 3000
    Sync $p.Id
    [void](Clear-Wins $p.Id 'start')
    return $p.Id
}
function Stop-Children([int]$Id) {
    $n = 0
    foreach ($c in @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$Id" -ErrorAction SilentlyContinue)) {
        if ($c.Name -ieq 'cmd.exe' -or $c.Name -ieq 'conhost.exe') { try { Stop-Process -Id $c.ProcessId -Force -ErrorAction Stop; $n++ } catch { } }
    }
    return $n
}
function Stop-Tc([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    if ($Started -notcontains $Id) { throw "pid $Id was not started by this probe" }
    [void](Stop-Children $Id)
    [void](Clear-Wins $Id 'stop' $false)
    $m = Get-Main $Id
    if ($m -ne [IntPtr]::Zero) { [void][Cmd093]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
        foreach ($h in (Get-Tops $Id)) {
            if ([Cmd093]::Cls($h) -eq '#32770') {
                $yes = [Cmd093]::Kids($h) | Where-Object { [Cmd093]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
                if ($yes) { [void][Cmd093]::PostMessageW($yes, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
                else { [void][Cmd093]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
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
    $lists = @([Cmd093]::Kids($m) | Where-Object { [Cmd093]::Cls($_) -eq 'SalamanderItemsBox' -and [Cmd093]::IsWindowVisible($_) })
    if ($lists.Count -lt 1) { throw 'panel list window not found' }
    return $lists[0]
}
function PanelKey([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Cmd093]::Send($l, 0x0100, $Vk, 1, 20000)
    [void][Cmd093]::Send($l, 0x0101, $Vk, 0xC0000001, 20000)
}
# reads the text until it has stopped changing (posted messages are served by
# the program's own loop; a sent message would overtake them)
function Read-Settled([IntPtr]$Main, [IntPtr]$H, [int]$WantLen) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $prev = $null; $same = 0
    while ($sw.Elapsed.TotalSeconds -lt 4) {
        [void][Cmd093]::Send($Main, 0, 0, 0, 5000)
        $t = [Cmd093]::GetText($H, 5000)
        if ($t -ceq $prev) { $same++ } else { $same = 0 }
        if ($same -ge 3 -and ($t.Length -ge $WantLen -or $sw.Elapsed.TotalMilliseconds -gt 1200)) { return $t }
        $prev = $t
        Start-Sleep -Milliseconds 100
    }
    return $prev
}
function Type-Text([IntPtr]$Edit, [string]$Text) {
    foreach ($u in $Text.ToCharArray()) { [void][Cmd093]::PostMessageW($Edit, 0x0102, [IntPtr][int]$u, [IntPtr]1) }
}
function SelStr($sel) { return ("{0},{1}" -f $sel[0], $sel[1]) }

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc093_cmd_backup.reg'
$root = Join-Path $env:TEMP 'tc093_cmd'
$existed = Backup-TcRegistry $backup
$regOk = $false

# texts
$cR = [string][char]0x159; $cZ = [string][char]0x17E; $cC = [string][char]0x10D
$cyr = S 0x416, 0x436; $cjk = S 0x65E5, 0x672C; $emo = S 0xD83D, 0xDCC1
$Texts = [ordered]@{
    'ascii' = 'echo abc'
    'cp'    = ('a' + $cR + $cZ + ' b')
    'non'   = ('a' + $cR + [char]0x416 + [char]0x65E5 + $emo)
}
# fixture files (the folder itself has a name outside the code page)
$Files = [ordered]@{
    'ascii' = 'a b.txt'
    'cp'    = ($cR + '.txt')
    'cyr'   = ($cyr + '.txt')
    'cjk'   = ($cjk + '.txt')
    'emo'   = ($emo + 'x.txt')
}
$dirName = (S 0x416, 0x2D, 0x159, 0x2D, 0x65E5)
$dir = Join-Path $root $dirName

try {
    Out ("=== cmdline_probe: {0}  (built {1:yyyy-MM-dd HH:mm:ss}){2} ===" -f $Exe, (Get-Item -LiteralPath $Exe).LastWriteTime, $(if ($Label) { "  [$Label]" } else { '' }))
    Out ("System code page {0}." -f [Cmd093]::GetACP())

    if ([IO.Directory]::Exists($root)) { [IO.Directory]::Delete($root, $true) }
    [void][IO.Directory]::CreateDirectory($dir)
    foreach ($k in $Files.Keys) { [IO.File]::WriteAllText((Join-Path $dir $Files[$k]), 'feature 093 probe') }
    Out ("Fixture: {0}\{1}\ with files: {2}" -f (Esc $root), (Hex $dirName), (($Files.Keys | ForEach-Object { "$_=" + (Hex $Files[$_]) }) -join ' ; '))

    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) {
        $cfg = "$RegKey\0.1\Configuration"
        & reg.exe add $cfg /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$cfg\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
        foreach ($v in @('Close Shell Window', 'Save History', 'Enable CmdLine History', 'Save CmdLine History', 'Save Configuration On Exit', 'Command Line')) {
            & reg.exe add $cfg /v $v /t REG_DWORD /d 1 /f | Out-Null
        }
    }
    else { Out 'No stored configuration: the program starts with its defaults (first-start windows are closed).' }

    $id = Start-Tc $dir
    $main = Get-Main $id
    Out ("Main window title: '{0}'; IsWindowUnicode={1}" -f (Esc ([Cmd093]::Txt($main))), [Cmd093]::IsWindowUnicode($main))

    $findCombo = { @([Cmd093]::Kids($main) | Where-Object { [Cmd093]::GetDlgCtrlID($_) -eq 955 -and [Cmd093]::Cls($_) -eq 'ComboBox' }) | Select-Object -First 1 }
    $cb = & $findCombo
    if (-not $cb) { [void][Cmd093]::PostMessageW($main, 0x0111, [IntPtr]745, [IntPtr]::Zero); Start-Sleep -Milliseconds 800; $cb = & $findCombo }
    if (-not $cb) { throw 'no ComboBox id 955 under the main window' }
    $ed = @([Cmd093]::Kids($cb) | Where-Object { [Cmd093]::Cls($_) -eq 'Edit' }) | Select-Object -First 1
    if (-not $ed) { throw 'the combo box has no inner Edit' }
    $clear = { [void][Cmd093]::SetText($cb, '', 5000) }

    # ---- C1 ----
    Row 'C1' '-' 'IsWindowUnicode combo / inner edit' 'True / True' ("{0} / {1}" -f [Cmd093]::IsWindowUnicode($cb), [Cmd093]::IsWindowUnicode($ed)) (Verdict ([Cmd093]::IsWindowUnicode($cb) -and [Cmd093]::IsWindowUnicode($ed))) ''

    # ---- C2: programmatic set ----
    foreach ($k in $Texts.Keys) {
        $t = $Texts[$k]
        [void][Cmd093]::SetText($cb, $t, 5000)
        $a = [Cmd093]::GetText($cb, 5000); $ia = [Cmd093]::GetText($ed, 5000)
        Row 'C2' $k 'WM_SETTEXT to the combo, read combo' (Hex $t) (Hex $a) (Verdict ($a -ceq $t)) $(if ($ia -cne $a) { 'inner edit reads ' + (Hex $ia) } else { 'inner edit reads the same' })
        & $clear
        [void][Cmd093]::SetText($ed, $t, 5000)
        $a = [Cmd093]::GetText($ed, 5000)
        Row 'C2' $k 'WM_SETTEXT to the inner edit, read edit' (Hex $t) (Hex $a) (Verdict ($a -ceq $t)) ''
        & $clear
    }

    # ---- C3: typing ----
    foreach ($k in $Texts.Keys) {
        $t = $Texts[$k]
        & $clear
        Type-Text $ed $t
        $a = Read-Settled $main $ed $t.Length
        Row 'C3' $k 'WM_CHAR posted per unit to the inner edit' (Hex $t) (Hex $a) (Verdict ($a -ceq $t)) ("flags now: combo={0} edit={1}" -f [Cmd093]::IsWindowUnicode($cb), [Cmd093]::IsWindowUnicode($ed))
    }
    # U+010D (in the code page) and U+0109 (not in it): low bytes 0D and 09
    & $clear
    $t = 'x' + $cC + [char]0x109 + 'y'
    $tops = (Get-Tops $id).Count
    $focusBefore = [Cmd093]::FocusOf($main)
    Type-Text $ed $t
    $a = Read-Settled $main $ed $t.Length
    $extra = @(Clear-Wins $id 'C3 U+010D' $false)
    Stop-Children $id | Out-Null
    $note = ''
    if ($extra.Count) { $note = 'a window appeared: ' + ($extra -join ' ; ') }
    Row 'C3' 'enter' 'typed x U+010D U+0109 y: no Enter, no Tab' (Hex $t) (Hex $a) (Verdict ($a -ceq $t -and -not $extra.Count)) $note
    & $clear

    # ---- C4: name insertion (Ctrl+Enter) ----
    $count = $Files.Count
    $seenAt = @{}       # inserted text -> panel position
    $driven = $true
    for ($pos = 1; $pos -le $count; $pos++) {
        & $clear
        PanelKey $id 0x24                                   # Home
        for ($j = 0; $j -lt $pos; $j++) { PanelKey $id 0x28 }  # Down
        $err = [Cmd093]::KeyMods($ed, 0x0D, $true, $false, 10000)
        if ($err) { $driven = $false; Row 'C4' '-' 'Ctrl+Enter in the command line' '-' '-' 'NOT DRIVEN' $err; break }
        $a = [Cmd093]::GetText($ed, 5000)
        if (-not $seenAt.ContainsKey($a)) { $seenAt[$a] = $pos }
    }
    $posOf = @{}
    if ($driven) {
        foreach ($k in $Files.Keys) {
            $exp = $Files[$k] + ' '
            $hit = @($seenAt.Keys | Where-Object { $_ -ceq $exp })
            if ($hit.Count) { $posOf[$k] = $seenAt[$hit[0]]; Row 'C4' $k 'name of the focused file inserted' (Hex $exp) (Hex $hit[0]) 'PASS' ("panel position {0}" -f $seenAt[$hit[0]]) }
            else { Row 'C4' $k 'name of the focused file inserted' (Hex $exp) '-' 'FAIL' ('texts seen at the positions: ' + ((($seenAt.Keys | Sort-Object { $seenAt[$_] }) | ForEach-Object { "[{0}] {1}" -f $seenAt[$_], (Hex $_) }) -join ' ; ')) }
        }
    }

    # ---- C5: insertion into the middle, caret, next character ----
    if ($driven) {
        # where each file is in the panel, independent of what C4 could read: by elimination when the text was lossy
        foreach ($k in $Files.Keys) {
            if (-not $posOf.ContainsKey($k)) { Row 'C5' $k 'insert into "ab" at 1' '-' '-' 'NOT DRIVEN' 'C4 did not find the panel position of this file'; continue }
            $name = $Files[$k]
            [void][Cmd093]::SetText($ed, 'ab', 5000)
            [void][Cmd093]::Send($ed, 0x00B1, 1, 1, 5000)                  # EM_SETSEL 1,1
            PanelKey $id 0x24
            for ($j = 0; $j -lt $posOf[$k]; $j++) { PanelKey $id 0x28 }
            [void][Cmd093]::KeyMods($ed, 0x0D, $true, $false, 10000)
            $a = [Cmd093]::GetText($ed, 5000)
            $sel = [Cmd093]::GetSel($ed, 5000)
            $expText = 'a' + $name + ' b'
            $expSel = 1 + $name.Length + 1
            Row 'C5' $k 'insert into "ab" at 1: text' (Hex $expText) (Hex $a) (Verdict ($a -ceq $expText)) ''
            Row 'C5' $k 'caret after the insertion (units)' ("{0},{0}" -f $expSel) (SelStr $sel) (Verdict ($sel[0] -eq $expSel -and $sel[1] -eq $expSel)) ''
            Type-Text $ed 'X'
            $expText2 = 'a' + $name + ' Xb'
            $a = Read-Settled $main $ed $expText2.Length
            Row 'C5' $k 'next typed character lands at the caret' (Hex $expText2) (Hex $a) (Verdict ($a -ceq $expText2)) ''
        }
    }
    & $clear

    # ---- C6 / C7: run a command, history ----
    $flags = [ordered]@{ 'ascii' = 'plain 1'; 'cp' = ($cR + '-' + $cZ); 'non' = ($cyr + $cjk + $emo) }
    $cmds = @{}
    foreach ($k in $flags.Keys) {
        $file = $flags[$k] + '.flag'
        $cmd = 'copy nul "' + $file + '"'
        $cmds[$k] = $cmd
        & $clear
        [void][Cmd093]::SetText($cb, $cmd, 5000)
        $held = [Cmd093]::GetText($ed, 5000)
        [void][Cmd093]::PostMessageW($ed, 0x0102, [IntPtr]13, [IntPtr]1)     # Enter
        $target = Join-Path $dir $file
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 12 -and -not [IO.File]::Exists($target)) { Start-Sleep -Milliseconds 200 }
        Start-Sleep -Milliseconds 800
        $made = @([IO.Directory]::GetFiles($dir, '*.flag') | ForEach-Object { [IO.Path]::GetFileName($_) })
        $extra = @(Clear-Wins $id "C6 $k" $false)
        $killed = Stop-Children $id
        $note = "the line held " + (Hex $held)
        if ($extra.Count) { $note += '; window: ' + ($extra -join ' ; ') }
        if ($killed) { $note += "; $killed shell process(es) ended by pid" }
        Row 'C6' $k 'copy nul "<name>.flag" + Enter: file on disk' (Hex $file) ((($made | ForEach-Object { Hex $_ }) -join ' ; ')) (Verdict ($made -ccontains $file)) $note
        $after = Read-Settled $main $ed 0
        Row 'C6' $k 'the line is empty after the command' '<empty>' (Hex $after) (Verdict ($after.Length -eq 0)) ''
        $items = @([Cmd093]::ComboItems($cb, 5000))
        $first = $null; if ($items.Count) { $first = $items[0] }
        Row 'C7' $k 'first item of the drop-down = the command' (Hex $cmd) (Hex $first) (Verdict ($first -ceq $cmd)) ("{0} items" -f $items.Count)
    }
    # history recall: Ctrl+Down in the empty line takes the newest item into the line
    & $clear
    $err = [Cmd093]::KeyMods($ed, 0x28, $true, $false, 10000)
    if ($err) { Row 'C7' 'non' 'Ctrl+Down recalls the newest command' '-' '-' 'NOT DRIVEN' $err }
    else {
        $a = Read-Settled $main $ed 1
        Row 'C7' 'non' 'Ctrl+Down recalls the newest command' (Hex $cmds['non']) (Hex $a) (Verdict ($a -ceq $cmds['non'])) ''
    }
    [void][Cmd093]::Send($cb, 0x014F, 0, 0, 5000)   # CB_SHOWDROPDOWN FALSE, should the list have opened
    # feature 085: the password of a URL does not reach the history
    $cmdPwd = 'echo ftp://user:secret@host.invalid/x >nul'
    $expPwd = 'echo ftp://user@host.invalid/x >nul'
    & $clear
    [void][Cmd093]::SetText($cb, $cmdPwd, 5000)
    [void][Cmd093]::PostMessageW($ed, 0x0102, [IntPtr]13, [IntPtr]1)
    Start-Sleep -Milliseconds 2500
    [void](Clear-Wins $id 'C7 pwd' $false); [void](Stop-Children $id)
    $after = Read-Settled $main $ed 0
    $items = @([Cmd093]::ComboItems($cb, 5000))
    $first = $null; if ($items.Count) { $first = $items[0] }
    Row 'C7' 'pwd' 'URL password stripped in the history' (Esc $expPwd) (Esc $first) (Verdict ($first -ceq $expPwd)) ''

    # ---- C8: Ctrl+Backspace, Backspace ----
    $w = @{
        'ascii' = @('echo ab.cd efx', 'echo ab.cd ', 'echo ab.')
        'cp'    = @(('echo ' + $cR + $cR + '.' + $cZ + $cZ + ' ' + $cC + 'x'), ('echo ' + $cR + $cR + '.' + $cZ + $cZ + ' '), ('echo ' + $cR + $cR + '.'))
        'non'   = @(('echo ' + $cyr + '.' + $cjk + ' ' + $emo + 'x'), ('echo ' + $cyr + '.' + $cjk + ' '), ('echo ' + $cyr + '.'))
    }
    foreach ($k in @('ascii', 'cp', 'non')) {
        $t = $w[$k][0]
        [void][Cmd093]::SetText($ed, $t, 5000)
        $held = [Cmd093]::GetText($ed, 5000)
        [void][Cmd093]::Send($ed, 0x00B1, $held.Length, $held.Length, 5000)
        $err = [Cmd093]::KeyMods($ed, 0x08, $true, $false, 10000)
        if ($err) { Row 'C8' $k 'Ctrl+Backspace' '-' '-' 'NOT DRIVEN' $err; continue }
        $a = [Cmd093]::GetText($ed, 5000)
        Row 'C8' $k 'Ctrl+Backspace at the end: last word gone' (Hex $w[$k][1]) (Hex $a) (Verdict ($a -ceq $w[$k][1])) $(if ($held -cne $t) { 'the line held ' + (Hex $held) } else { '' })
        [void][Cmd093]::KeyMods($ed, 0x08, $true, $false, 10000)
        $a = [Cmd093]::GetText($ed, 5000)
        $sel = [Cmd093]::GetSel($ed, 5000)
        Row 'C8' $k 'Ctrl+Backspace again: up to the dot' (Hex $w[$k][2]) (Hex $a) (Verdict ($a -ceq $w[$k][2])) ("caret " + (SelStr $sel))
    }
    $b = [ordered]@{ 'ascii' = 'ab'; 'cp' = ('a' + $cR); 'non' = ('a' + [char]0x416); 'emo' = ('a' + $emo) }
    foreach ($k in $b.Keys) {
        $t = $b[$k]
        [void][Cmd093]::SetText($ed, $t, 5000)
        $held = [Cmd093]::GetText($ed, 5000)
        [void][Cmd093]::Send($ed, 0x00B1, $held.Length, $held.Length, 5000)
        [void][Cmd093]::PostMessageW($ed, 0x0102, [IntPtr]8, [IntPtr]1)
        Start-Sleep -Milliseconds 300
        $a = Read-Settled $main $ed 0
        Row 'C8' $k 'Backspace (WM_CHAR 8) removes one character' (Hex 'a') (Hex $a) (Verdict ($a -ceq 'a')) $(if ($held -cne $t) { 'the line held ' + (Hex $held) } else { '' })
    }
    & $clear

    # ---- C9: the path prefix ----
    $st = @([Cmd093]::Kids($cb) | Where-Object { [Cmd093]::Cls($_) -eq 'Static' }) | Select-Object -First 1
    if ($st) { Row 'C9' '-' 'path prefix (Static in the combo)' '-' ("IsWindowUnicode={0}; window text {1}; width {2} px; edit width {3} px" -f [Cmd093]::IsWindowUnicode($st), (Hex ([Cmd093]::Txt($st))), [Cmd093]::WidthOf($st), [Cmd093]::WidthOf($ed)) 'INFO' 'the control paints the path itself (wide), its window text is not used' }
    else { Row 'C9' '-' 'path prefix (Static in the combo)' '-' '-' 'NOT DRIVEN' 'no Static child' }

    # ---- C10: ASCII regression drive ----
    & $clear
    Type-Text $ed 'echo'
    $a = Read-Settled $main $ed 4
    $sel = [Cmd093]::GetSel($ed, 5000)
    Row 'C10' 'ascii' 'typed echo' 'echo' $a (Verdict ($a -ceq 'echo')) ("EM_GETSEL: " + (SelStr $sel))
    # every key is checked by where the next typed character lands (the read-out of
    # EM_GETSEL is in the note: through a code-page subclass it is not the caret)
    $steps = @(@('Home, typed 1', 0x24, $false, '1', '1echo'), @('End, typed 2', 0x23, $false, '2', '1echo2'), @('Left, typed 3', 0x25, $false, '3', '1echo32'), @('Shift+Left, typed X (replaces 3)', 0x25, $true, 'X', '1echoX2'))
    foreach ($s in $steps) {
        $err = [Cmd093]::KeyMods($ed, $s[1], $false, $s[2], 10000)
        $sel = [Cmd093]::GetSel($ed, 5000)
        if ($err) { Row 'C10' 'ascii' ($s[0]) $s[4] '-' 'NOT DRIVEN' $err; continue }
        Type-Text $ed $s[3]
        $a = Read-Settled $main $ed $s[4].Length
        Row 'C10' 'ascii' $s[0] $s[4] $a (Verdict ($a -ceq $s[4])) ("EM_GETSEL after the key: " + (SelStr $sel))
    }
    # focus: CM_EDITLINE puts it into the command line, Esc clears the line and returns it to the panel
    [void][Cmd093]::Send($main, 0x0111, 745, 0, 10000)
    $f1 = [Cmd093]::FocusOf($main)
    $f1c = '-'; if ($f1 -ne [IntPtr]::Zero) { $f1c = [Cmd093]::Cls($f1) }
    $err = [Cmd093]::KeyMods($ed, 0x1B, $false, $false, 10000)
    $a = [Cmd093]::GetText($ed, 5000)
    $f2 = [Cmd093]::FocusOf($main)
    $f2c = '-'; if ($f2 -ne [IntPtr]::Zero) { $f2c = [Cmd093]::Cls($f2) }
    Row 'C10' 'ascii' 'Esc clears the line' '<empty>' (Hex $a) (Verdict ($a.Length -eq 0)) $err
    Row 'C10' 'ascii' 'focus: after CM_EDITLINE -> after Esc' 'Edit -> SalamanderItemsBox' ("{0} -> {1}" -f $f1c, $f2c) $(if ($f1c -eq 'Edit' -and $f2c -eq 'SalamanderItemsBox') { 'PASS' } elseif ($f1c -eq '-' -and $f2c -eq '-') { 'NOT DRIVEN' } else { 'FAIL' }) 'thread focus window by GetGUIThreadInfo (a hidden desktop has no foreground window)'

    # ---- exit, stored history ----
    Stop-Tc $id
    $hist = @()
    $hk = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Tandem Commander\0.1\Configuration\Command History')
    if ($hk) { foreach ($n in $hk.GetValueNames()) { $hist += [string]$hk.GetValue($n) }; $hk.Close() }
    foreach ($k in $flags.Keys) {
        $ok = ($hist -ccontains $cmds[$k])
        Row 'C7' $k 'stored Command History holds the command' (Hex $cmds[$k]) $(if ($ok) { Hex $cmds[$k] } else { 'not among: ' + ((($hist | Select-Object -First 5) | ForEach-Object { Esc $_ }) -join ' ; ') }) (Verdict $ok) ("{0} stored values" -f $hist.Count)
    }
    $ok = ($hist -ccontains $expPwd) -and -not (@($hist | Where-Object { $_ -like '*secret*' }).Count)
    Row 'C7' 'pwd' 'stored history: URL without the password' (Esc $expPwd) $(if ($ok) { Esc $expPwd } else { 'not as expected: ' + ((($hist | Select-Object -First 5) | ForEach-Object { Esc $_ }) -join ' ; ') }) (Verdict $ok) ''
}
catch { Out ("PROBE ERROR: {0} (line {1})" -f $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber) }
finally {
    foreach ($s in @($Started)) { try { Stop-Tc $s } catch { Out "  (stop $s : $($_.Exception.Message))" } }
    $left = @($Started | Where-Object { Test-Alive $_ }).Count
    for ($k = 0; $k -lt 10 -and [IO.Directory]::Exists($root); $k++) {
        try { [IO.Directory]::Delete($root, $true) } catch { Start-Sleep -Milliseconds 500 }
    }
    $regOk = Restore-TcRegistry $backup $existed
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}, INFO {3}; unexpected windows: {4}" -f $script:Pass, $script:Fail, $script:NotDriven, $script:Info, $script:Unexpected.Count)
    Out ("Test processes left: {0}; fixture folder left: {1}; registry restored identical: {2}; process exit codes: {3}" -f $left, [IO.Directory]::Exists($root), $regOk, ($script:ExitCodes -join ','))
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines.ToArray([string]), (New-Object Text.UTF8Encoding($false))) }
}
if ($regOk) { exit 0 } else { exit 1 }
