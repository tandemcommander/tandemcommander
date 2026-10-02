<#
.SYNOPSIS
    Feature 093 stage S2, evidence B: the 7-Zip plug-in's password through the
    PRODUCT (contract P1 of contracts/dialog-unicode.md).

.DESCRIPTION
    Per row a fresh instance of tandemcommander.exe (-Exe) is started in a
    folder that holds one file, and one operation is driven by command ids and
    window messages:

      unpack  CM_UNPACK (851) on an archive -> the plug-in's password prompt
              (edit id 1220, set by a wide WM_SETTEXT) -> OK; the unpacked
              files are compared with the source (SHA-256)
      pack    CM_PACK (850), packer "7-Zip (Plugin)" -> the plug-in's
              "Create New Archive" / "Add Files to Archive" dialog (Encrypt
              1211, password 1212, confirmation 1213) -> OK; the archive is
              then tested by the 7-Zip program with each form of the password

    The archives to unpack are made by the 7-Zip program (7z.exe). "legacy" is
    the form versions up to 0.1.8 derived from the typed text: its UTF-8 bytes
    read with the system code page (src/common/salarcpwd.h).

    Every window the instance shows meanwhile is recorded (class, title, text)
    and dismissed; a row passes only when the observed result equals the
    expectation written in the row. Run on the build under test and on the
    pre-093 build (negative control); the expectation column describes the
    FIXED behaviour, so the old build is expected to FAIL the rows that show
    the defect.

    SAFETY: as dialogs_probe.ps1 - only the processes started here are
    addressed, by pid; messages go only to windows of those pids; no SendInput.
    HKCU\Software\Tandem Commander is exported before the first start and
    restored and verified (SHA-256 of a second export) at the end. Values
    changed for the run: UI language (English), the exit confirmation, the
    7-Zip plug-in's "Show Extended Options". The fixture %TEMP%\tc093_pwd and,
    once the restore is verified, the registry backup file are removed.

.PARAMETER Exe
    tandemcommander.exe to drive.
.PARAMETER Only
    Run only the named rows (U1..U10, M1..M7 with M4a/M4b and M6a/M6b, V1, X1, Z1, D1, D2, P1..P5).
.PARAMETER Label
    Free text for the first line.
.PARAMETER OutFile
    Also write every printed line to this file (UTF-8, the content is ASCII).

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII (strings are built from
    character codes). The helper block is the one of dialogs_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Only,
    [string]$Label,
    [string]$OutFile,
    [switch]$Trace,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
if (-not (Test-Path -LiteralPath $SevenZip)) { throw "7z.exe not found: $SevenZip" }

# ---- helper block of dialogs_probe.ps1 (copied, unchanged) -------------------
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
    $a = @('-t', 'T093', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Dir), '-p', '1')
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

# ---- this probe --------------------------------------------------------------
if (-not ('P093.Pwd093Native' -as [type])) {
    Add-Type -Namespace P093 -Name Pwd093Native -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
public static extern int MultiByteToWideChar(uint cp, uint flags, byte[] src, int srcLen, [Out] char[] dst, int dstLen);
'@
}
# the legacy form as salarcpwd.h derives it (UTF-8 bytes fit the old buffer in these rows)
function Get-Legacy([string]$typed) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($typed)
    $dst = New-Object char[] ($bytes.Length + 1)
    $n = [P093.Pwd093Native]::MultiByteToWideChar(0, 0, $bytes, $bytes.Length, $dst, $dst.Length)
    return (New-Object string ($dst, 0, $n))
}
function Sha([string]$File) { return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash }
function Seven([string[]]$A) { & $SevenZip @A | Out-Null; return $LASTEXITCODE }
function SevenTest([string]$Arc, [string]$Pw) { return ((Seven @('t', '-bso0', '-bsp0', '-bse0', ('-p' + $Pw), $Arc)) -eq 0) }
function SevenNames([string]$Arc, [string]$Pw) {
    $o = & $SevenZip l -slt -ba ('-p' + $Pw) $Arc 2>$null
    return @($o | Where-Object { $_ -like 'Path = *' } | ForEach-Object { $_.Substring(7) })
}

$script:RowPass = 0; $script:RowFail = 0
function Result([string]$Row, [string]$What, [string]$Expect, [string]$Observed, [bool]$Ok, [string]$Windows) {
    Out ("{0,-4}| {1} | expected: {2} | observed: {3} | {4}" -f $Row, $What, $Expect, $Observed, $(if ($Ok) { 'PASS' } else { 'FAIL' }))
    if ($Windows) { Out ("    | messages shown: {0}" -f $Windows) }
    if ($Ok) { $script:RowPass++ } else { $script:RowFail++ }
}

function Has-Edit([IntPtr]$H, [int]$CtlId) { return ((Find-Ctl $H $CtlId) -ne [IntPtr]::Zero) }
function Buttons([IntPtr]$H) { return @([Drv093]::Kids($H) | Where-Object { [Drv093]::Cls($_) -eq 'Button' -and [Drv093]::IsWindowVisible($_) }) }
function Click([IntPtr]$Btn) { [void][Drv093]::PostMessageW($Btn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }

# Serves the windows of the operation until the instance is idle again.
#   password prompt (edit 1220): the first one gets $Typed + OK; a second one
#     is recorded and cancelled
#   any other window that stays, enabled, for 2.5 s without being the progress
#     dialog (its only button is Cancel): recorded as a message and dismissed
#     (Delete / OK / Yes when there is such a button, else Cancel / close)
function Serve-Operation([int]$Id, [string]$Typed, [double]$Seconds = 60, [string]$Overwrite = '', [string]$DataError = 'Delete') {
    $r = [pscustomobject]@{ Overwrites = 0; Prompts = 0; Messages = New-Object System.Collections.ArrayList; TimedOut = $false; PromptUnicode = ''; Seen = New-Object System.Collections.ArrayList }
    $seen = @{}
    $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { [void]$r.Messages.Add('THE PROCESS ENDED'); break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv093]::Cls($_) -ne $MainClass })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 1.5) { break }
            Start-Sleep -Milliseconds 100
            continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv093]::IsWindow($h) -or -not [Drv093]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (Has-Edit $h 1220) {
                if ($seen[$key] -eq 'prompt') { continue }
                $seen[$key] = 'prompt'
                $r.Prompts++
                $e = Find-Ctl $h 1220
                $r.PromptUnicode = ('dlg={0} edit={1}' -f [Drv093]::IsWindowUnicode($h), [Drv093]::IsWindowUnicode($e))
                if ($r.Prompts -eq 1) {
                    [void][Drv093]::SetText($e, $Typed, 5000)
                    [void](Click-Ok $h)
                }
                else { [void]$r.Messages.Add('SECOND PASSWORD PROMPT (cancelled)'); Close-Win $Id $h }
                continue
            }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv093]::GetDlgCtrlID($_) })
            # the core's overwrite question: answered with the button named by $Overwrite, counted
            if ($Overwrite -and $seen[$key] -ne 'overwrite') {
                # the dialog "Confirm File Overwrite": Yes 6, All 185, Skip 173, Skip all 174, Cancel 2
                $want = @{ 'Skip' = 173; 'Yes' = 6 }[$Overwrite]
                $ob = $btn | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1
                if ($ob -and ($ids -contains 173) -and ($ids -contains 174)) {
                    $seen[$key] = 'overwrite'
                    $r.Overwrites++
                    [void]$r.Seen.Add(("overwrite question: {0}" -f (Get-DialogText $h)))
                    Click $ob
                    continue
                }
            }
            $isProgress = ($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $sw.Elapsed.TotalSeconds
                [void]$r.Seen.Add(("{0:N1}s [{1} '{2}'] buttons {3}: {4}" -f $sw.Elapsed.TotalSeconds, [Drv093]::Cls($h), (Esc ([Drv093]::Txt($h))), ($ids -join ','), (Get-DialogText $h)))
                continue
            }
            if ($seen[$key] -is [string]) { continue }
            if ($isProgress) { continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            # a message: record and dismiss
            $text = ("[{0} '{1}'] {2} buttons: {3}" -f [Drv093]::Cls($h), (Esc ([Drv093]::Txt($h))), (Get-DialogText $h), (($btn | ForEach-Object { '{0}={1}' -f [Drv093]::GetDlgCtrlID($_), (Esc ([Drv093]::Txt($_))) }) -join ','))
            [void]$r.Messages.Add($text)
            $seen[$key] = 'message'
            # the plug-in's question about a damaged file: Delete = 6, Keep = 7
            $pick = $null
            if ($DataError -eq 'Keep') { $pick = $btn | Where-Object { [Drv093]::Txt($_) -match 'Keep' -and [Drv093]::GetDlgCtrlID($_) -eq 7 } | Select-Object -First 1 }
            if (-not $pick) { $pick = $btn | Where-Object { [Drv093]::Txt($_) -match 'Delete' } | Select-Object -First 1 }
            if (-not $pick) { $pick = $btn | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1 }
            if ($pick) { Click $pick } else { Close-Win $Id $h }
        }
        Start-Sleep -Milliseconds 150
    }
    if ($r.TimedOut) {
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv093]::Cls($_) -ne $MainClass })) {
            [void]$r.Messages.Add(("STILL OPEN AT TIMEOUT [{0} '{1}'] {2}" -f [Drv093]::Cls($h), (Esc ([Drv093]::Txt($h))), (Get-DialogText $h)))
        }
        Clear-Wins $Id 'timeout' $false
    }
    return $r
}

# CM_UNPACK on the one file of the panel's folder, target $OutDir, password $Typed.
# $Mask: the Unpack dialog's mask field; $Overwrite: the button for the overwrite question;
# $Again: a second unpack in the same instance with this password (was the first one forgotten?)
function Start-Unpack([int]$Id, [string]$OutDir, [string]$Mask, [bool]$DeleteArchive = $false) {
    Key $Id 0x23                                     # End: the one file
    $dlg = Open-ByCmd $Id 851
    if ($dlg -eq [IntPtr]::Zero) { throw 'command 851 opened no window' }
    $path = Find-Ctl $dlg 210
    if ($path -eq [IntPtr]::Zero) { throw 'no IDE_PATH in the Unpack dialog' }
    [void][Drv093]::SetText($path, $OutDir, 5000)
    if ($Mask) {
        $m = Find-Ctl $dlg 521
        if ($m -eq [IntPtr]::Zero) { throw 'no IDE_MASK in the Unpack dialog' }
        [void][Drv093]::SetText($m, $Mask, 5000)
    }
    if ($DeleteArchive) {
        $chk = @([Drv093]::Kids($dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 6210 }) | Select-Object -First 1   # IDC_DELETEARCHIVEFILES
        if (-not $chk -or -not [Drv093]::IsWindowEnabled($chk)) { throw 'the "Delete archive after unpacking" option is not available' }
        Click $chk
        Start-Sleep -Milliseconds 300
        [void][Drv093]::Send($dlg, 0, 0, 0, 5000)
    }
    [void](Click-Ok $dlg)
}
function Do-Unpack([string]$PanelDir, [string]$OutDir, [string]$Typed, [string]$Mask = '', [string]$Overwrite = '', [string]$Again = '', [bool]$DeleteArchive = $false, [string]$DataError = 'Delete') {
    $id = 0
    try {
        $id = Start-Tc $PanelDir
        Start-Unpack $id $OutDir $Mask $DeleteArchive
        $r = Serve-Operation $id $Typed 90 $Overwrite $DataError
        if ($Again) {
            $left = @([IO.Directory]::GetFiles($OutDir, '*', 'AllDirectories') | ForEach-Object { '{0} ({1} bytes)' -f [IO.Path]::GetFileName($_), (New-Object IO.FileInfo $_).Length })
            Sync $id
            Start-Unpack $id $OutDir $Mask
            $r2 = Serve-Operation $id $Again 60 $Overwrite
            $r | Add-Member -NotePropertyName LeftAfterFirst -NotePropertyValue $left
            $r | Add-Member -NotePropertyName Second -NotePropertyValue $r2
        }
        return $r
    }
    finally { if ($id) { Stop-Tc $id } }
}

# CM_PACK of the one file of the panel's folder into $Archive by the plug-in, encrypted with $Typed
function Do-Pack([string]$PanelDir, [string]$Archive, [string]$Typed) {
    $id = 0
    try {
        $id = Start-Tc $PanelDir
        Key $id 0x23
        $dlg = Open-ByCmd $id 850
        if ($dlg -eq [IntPtr]::Zero) { throw 'command 850 opened no window' }
        $packer = @([Drv093]::Kids($dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 511 }) | Select-Object -First 1
        if (-not $packer) { throw 'no IDC_PACKER in the Pack dialog' }
        $items = @([Drv093]::ComboItems($packer, 5000))
        $ix = -1
        for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i] -match '7-?Zip' -and $items[$i] -match '(?i)plugin') { $ix = $i; break } }
        if ($ix -lt 0) { throw ('no 7-Zip plug-in packer among: ' + ($items -join ' ; ')) }
        [void][Drv093]::Send($packer, 0x014E, $ix, 0, 5000)                                   # CB_SETCURSEL
        [void][Drv093]::Send($dlg, 0x0111, ((1 -shl 16) -bor 511), $packer.ToInt64(), 5000)  # CBN_SELCHANGE
        $path = Find-Ctl $dlg 210
        [void][Drv093]::SetText($path, $Archive, 5000)
        $known = Get-Tops $id
        [void](Click-Ok $dlg)
        # the plug-in's options dialog
        $opt = [IntPtr]::Zero; $added = $false
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $opt -eq [IntPtr]::Zero) {
            foreach ($h in (Get-Tops $id)) {
                if ((Has-Edit $h 1212) -and [Drv093]::IsWindowEnabled($h)) { $opt = $h; continue }
                # the core's question for an existing archive: "add into it or overwrite it" -> Add
                if (-not $added -and [Drv093]::Cls($h) -eq '#32770' -and [Drv093]::IsWindowEnabled($h) -and (Get-DialogText $h) -match 'already exists') {
                    $add = Buttons $h | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
                    if ($add) { Click $add; $added = $true }
                }
            }
            Start-Sleep -Milliseconds 150
        }
        if ($opt -eq [IntPtr]::Zero) {
            $t = @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -ne $MainClass } | ForEach-Object { "[{0} '{1}'] {2}" -f [Drv093]::Cls($_), (Esc ([Drv093]::Txt($_))), (Get-DialogText $_) })
            Clear-Wins $id 'pack' $false
            throw ('the plug-in options dialog did not appear; windows: ' + ($t -join ' || '))
        }
        $title = [Drv093]::Txt($opt)
        $chk = @([Drv093]::Kids($opt) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 1211 }) | Select-Object -First 1
        Click $chk                                                                             # BN_CLICKED enables the fields
        Start-Sleep -Milliseconds 400
        [void][Drv093]::Send($opt, 0, 0, 0, 5000)
        [void][Drv093]::SetText((Find-Ctl $opt 1212), $Typed, 5000)
        [void][Drv093]::SetText((Find-Ctl $opt 1213), $Typed, 5000)
        [void](Click-Ok $opt)
        $r = Serve-Operation $id '' 90
        $r | Add-Member -NotePropertyName OptionsTitle -NotePropertyValue $title
        return $r
    }
    finally { if ($id) { Stop-Tc $id } }
}

function New-RowDirs([string]$Row) {
    $d = Join-Path $root $Row
    $o = [pscustomobject]@{ Panel = (Join-Path $d 'panel'); Out = (Join-Path $d 'out'); Arc = (Join-Path $d 'arc') }
    foreach ($x in @($o.Panel, $o.Out, $o.Arc)) { [void][IO.Directory]::CreateDirectory($x) }
    return $o
}
function Msgs($r) { return (($r.Messages | ForEach-Object { $_ }) -join ' || ') }

# one unpack row. $Mode: 'extract' = both source files unpacked, equal, no message, one prompt;
#                        'refuse'  = nothing usable unpacked and the user is told
function Unpack-Row([string]$Row, [string]$What, [string]$ArcPw, [bool]$Headers, [string]$Typed, [string]$Mode) {
    if (-not (Want $Row)) { return }
    try {
        $d = New-RowDirs $Row
        $arc = Join-Path $d.Panel 'secret.7z'
        $a = @('a', '-bso0', '-bsp0', ('-p' + $ArcPw))
        if ($Headers) { $a += '-mhe=on' }
        $a += @($arc, (Join-Path $src '*'))
        if ((Seven $a) -ne 0) { throw '7z.exe could not make the archive' }
        $r = Do-Unpack $d.Panel $d.Out $Typed
        if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
        $files = @([IO.Directory]::GetFiles($d.Out, '*', 'AllDirectories'))
        $equal = 0
        foreach ($f in $files) { $s = Join-Path $src ([IO.Path]::GetFileName($f)); if ((Test-Path -LiteralPath $s) -and (Sha $f) -eq (Sha $s)) { $equal++ } }
        $obs = "prompts={0} ({1}); files unpacked={2}, equal to the source={3} of {4}; messages={5}{6}" -f $r.Prompts, $r.PromptUnicode, $files.Count, $equal, $srcCount, $r.Messages.Count, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' })
        if ($Mode -eq 'extract') {
            $ok = ($r.Prompts -eq 1 -and $files.Count -eq $srcCount -and $equal -eq $srcCount -and $r.Messages.Count -eq 0 -and -not $r.TimedOut)
            Result $Row $What 'one prompt, every file unpacked once and equal, no message' $obs $ok (Msgs $r)
        }
        else {
            $ok = ($r.Prompts -eq 1 -and $equal -eq 0 -and $r.Messages.Count -ge 1 -and -not $r.TimedOut)
            Result $Row $What 'one prompt, no file with the right content, the user is told' $obs $ok (Msgs $r)
        }
    }
    catch { Result $Row $What '-' ('NOT DRIVEN: ' + $_.Exception.Message) $false '' }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc093_pwd_backup.reg'
$root = Join-Path $env:TEMP 'tc093_pwd'
$existed = Backup-TcRegistry $backup
$regOk = $false
try {
    Out ("=== pwd_gui_probe: {0}  (built {1:yyyy-MM-dd HH:mm:ss}){2} ===" -f $Exe, (Get-Item -LiteralPath $Exe).LastWriteTime, $(if ($Label) { "  [$Label]" } else { '' }))
    $spl = Join-Path (Split-Path -Parent $Exe) 'plugins\7zip\7zip.spl'
    Out ("plug-in: {0} (built {1:yyyy-MM-dd HH:mm:ss}); system code page {2}; {3}" -f $spl, (Get-Item -LiteralPath $spl).LastWriteTime, [Drv093]::GetACP(), ((& $SevenZip | Select-Object -Index 1)))

    $typedR = 'heslo-' + (S 0x159)
    $typedC = S 0x43F, 0x430, 0x440, 0x43E, 0x43B, 0x44C
    $legR = Get-Legacy $typedR
    $wrongU = 'spatne-' + (S 0x17E)
    $otherU = 'jine-' + (S 0x161)
    $longC = (S 0x416) * 70
    Out ("typed-r = {0}; legacy-r = {1}; typed-c = {2}; wrong-u = {3}; other-u = {4}; long-c = 70 x U+0416" -f (Esc $typedR), (Esc $legR), (Esc $typedC), (Esc $wrongU), (Esc $otherU))
    Out ''

    if ([IO.Directory]::Exists($root)) { [IO.Directory]::Delete($root, $true) }
    $src = Join-Path $root 'src'
    [void][IO.Directory]::CreateDirectory($src)
    [IO.File]::WriteAllText((Join-Path $src 'a.txt'), ('feature 093 password probe ' * 400))
    [IO.File]::WriteAllText((Join-Path $src 'b.txt'), 'second file of the probe')
    $srcCount = 2

    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'no stored configuration to run with' }
    & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
    & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add "$RegKey\0.1\Plugins Configuration\7zip" /v 'Show Extended Options' /t REG_DWORD /d 1 /f | Out-Null

    # ---- unpack ----
    Unpack-Row 'U1' "archive by 7-Zip, content encrypted with typed-r; typed: typed-r" $typedR $false $typedR 'extract'
    Unpack-Row 'U2' "archive by 7-Zip, headers encrypted with typed-r; typed: typed-r" $typedR $true $typedR 'extract'
    Unpack-Row 'U3' "LEGACY archive, content encrypted with legacy-r; typed: typed-r" $legR $false $typedR 'extract'
    Unpack-Row 'U4' "LEGACY archive, headers encrypted with legacy-r; typed: typed-r" $legR $true $typedR 'extract'
    Unpack-Row 'U5' "archive by 7-Zip, content encrypted with typed-c (Cyrillic); typed: typed-c" $typedC $false $typedC 'extract'
    Unpack-Row 'U6' "archive by 7-Zip, headers encrypted with typed-c (Cyrillic); typed: typed-c" $typedC $true $typedC 'extract'
    Unpack-Row 'U7' "ASCII control, content encrypted with heslo123; typed: heslo123" 'heslo123' $false 'heslo123' 'extract'
    Unpack-Row 'U8' "wrong ASCII password: content encrypted with heslo123; typed: spatne" 'heslo123' $false 'spatne' 'refuse'
    Unpack-Row 'U9' "wrong non-ASCII password: content encrypted with typed-r; typed: wrong-u" $typedR $false $wrongU 'refuse'
    Unpack-Row 'U10' "wrong non-ASCII password: headers encrypted with typed-r; typed: wrong-u" $typedR $true $wrongU 'refuse'

    # ---- mixed archives, damaged items, existing files (the review of S2) ----
    $big = Join-Path $root 'big'; $tiny = Join-Path $root 'tiny'; $zdir = Join-Path $root 'z'
    foreach ($x in @($big, $tiny, $zdir)) { [void][IO.Directory]::CreateDirectory($x) }
    [IO.File]::WriteAllText((Join-Path $big 'c.txt'), ('c added by an older version; ' * 760))      # about 22 KB
    [IO.File]::WriteAllText((Join-Path $tiny 'c.txt'), 'tiny')
    [IO.File]::WriteAllText((Join-Path $zdir 'zadded.txt'), ('added later under another password ' * 50))

    # a.txt + b.txt under $Pw1 (made by 7-Zip), then one more file under $Pw2 - what 0.1.8 left behind
    function New-Mixed([string]$Arc, [string]$Pw1, [string]$Pw2, [string]$Extra) {
        if ((Seven @('a', '-bso0', '-bsp0', ('-p' + $Pw1), $Arc, (Join-Path $src '*'))) -ne 0) { throw '7z.exe could not make the archive' }
        if ((Seven @('a', '-bso0', '-bsp0', ('-p' + $Pw2), $Arc, $Extra)) -ne 0) { throw '7z.exe could not add the second-password file' }
    }
    # name -> 'equal' / 'DIFFERENT' / 'not expected' for every file in $OutDir, against the files of $Expect (name -> source path)
    function Compare-Out([string]$OutDir, [hashtable]$Expect) {
        $res = @{}
        foreach ($f in [IO.Directory]::GetFiles($OutDir, '*', 'AllDirectories')) {
            $n = [IO.Path]::GetFileName($f)
            if (-not $Expect.ContainsKey($n)) { $res[$n] = 'not expected' }
            elseif ((Sha $f) -eq (Sha $Expect[$n])) { $res[$n] = 'equal' } else { $res[$n] = 'DIFFERENT' }
        }
        return $res
    }
    function Show-Out([hashtable]$Cmp) { if (-not $Cmp.Count) { return '(nothing)' }; return (($Cmp.Keys | Sort-Object | ForEach-Object { '{0}={1}' -f $_, $Cmp[$_] }) -join ', ') }
    # exactly the names of $Names in the target, each equal to its source
    function Only-Equal([hashtable]$Cmp, [string[]]$Names) {
        if ($Cmp.Count -ne $Names.Count) { return $false }
        foreach ($n in $Names) { if ($Cmp[$n] -ne 'equal') { return $false } }
        return $true
    }
    function Mixed-Row([string]$Row, [string]$What, [scriptblock]$Make, [string]$Typed, [string]$Mask, [hashtable]$Expect, [string[]]$Names, [int]$Messages, [string]$ExpectText) {
        if (-not (Want $Row)) { return }
        try {
            $d = New-RowDirs $Row
            $arc = Join-Path $d.Panel 'secret.7z'
            & $Make $arc
            $r = Do-Unpack $d.Panel $d.Out $Typed $Mask
            if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
            $cmp = Compare-Out $d.Out $Expect
            $obs = "prompts={0}; in the target: {1}; messages={2}{3}" -f $r.Prompts, (Show-Out $cmp), $r.Messages.Count, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' })
            # one message expected: the "data error" message. With a wrong password the decoder now and then
            # (it depends on the archive's random salt) writes some output before it fails; the plug-in then
            # asks its keep-or-delete question for that file first - as pre-093 did. That question is allowed.
            $asked = @($r.Messages | Where-Object { $_ -match 'delete or keep' }).Count
            $told = $r.Messages.Count - $asked
            if ($Messages -eq 1) { $msgOk = ($r.Messages.Count -ge 1 -and $told -le 1 -and $asked -le 1) } else { $msgOk = ($r.Messages.Count -eq $Messages) }
            if ($asked) { $obs += " ($asked of them the keep-or-delete question)" }
            $ok = ($r.Prompts -eq 1 -and (Only-Equal $cmp $Names) -and $msgOk -and -not $r.TimedOut)
            Result $Row $What $ExpectText $obs $ok (Msgs $r)
        }
        catch { Result $Row $What '-' ('NOT DRIVEN: ' + $_.Exception.Message) $false '' }
    }
    $expBig = @{ 'a.txt' = (Join-Path $src 'a.txt'); 'b.txt' = (Join-Path $src 'b.txt'); 'c.txt' = (Join-Path $big 'c.txt') }
    $expTiny = @{ 'a.txt' = (Join-Path $src 'a.txt'); 'b.txt' = (Join-Path $src 'b.txt'); 'c.txt' = (Join-Path $tiny 'c.txt') }
    $expZ = @{ 'a.txt' = (Join-Path $src 'a.txt'); 'b.txt' = (Join-Path $src 'b.txt'); 'zadded.txt' = (Join-Path $zdir 'zadded.txt') }

    Mixed-Row 'M1' 'MIXED: a.txt, b.txt under typed-r (7-Zip) + c.txt (22 KB) under legacy-r; unpack all, typed: typed-r' { param($arc) New-Mixed $arc $typedR $legR (Join-Path $big 'c.txt') } $typedR '' $expBig @('a.txt', 'b.txt', 'c.txt') 0 'one prompt, all three files equal, no message'
    Mixed-Row 'M2' 'MIXED with a tiny c.txt (the cheapest item is the legacy one); unpack all, typed: typed-r' { param($arc) New-Mixed $arc $typedR $legR (Join-Path $tiny 'c.txt') } $typedR '' $expTiny @('a.txt', 'b.txt', 'c.txt') 0 'one prompt, all three files equal, no message'
    Mixed-Row 'M3' 'MIXED (as M1): only c.txt unpacked (mask c.txt in the Unpack dialog), typed: typed-r' { param($arc) New-Mixed $arc $typedR $legR (Join-Path $big 'c.txt') } $typedR 'c.txt' $expBig @('c.txt') 0 'one prompt, c.txt equal, no message'
    Mixed-Row 'M4a' 'ASCII mixed: a.txt, b.txt under pw1 + zadded.txt under pw2; typed: pw2' { param($arc) New-Mixed $arc 'pw1' 'pw2' (Join-Path $zdir 'zadded.txt') } 'pw2' '' $expZ @('zadded.txt') 1 'zadded.txt unpacked (as pre-093), one message about the others'
    Mixed-Row 'M4b' 'ASCII mixed: the same archive; typed: pw1' { param($arc) New-Mixed $arc 'pw1' 'pw2' (Join-Path $zdir 'zadded.txt') } 'pw1' '' $expZ @('a.txt', 'b.txt') 1 'a.txt, b.txt unpacked (as pre-093), one message about the other'

    # M5: a legacy archive without solid blocks; the packed bytes of the smallest item (b.txt) are damaged
    Mixed-Row 'M5' 'DAMAGED cheapest item: legacy archive (legacy-r, not solid), packed bytes of b.txt flipped; typed: typed-r' {
        param($arc)
        if ((Seven @('a', '-bso0', '-bsp0', '-ms=off', ('-p' + $legR), $arc, (Join-Path $src '*'))) -ne 0) { throw '7z.exe could not make the archive' }
        $names = @(); $packed = @()
        foreach ($l in (& $SevenZip l -slt -ba ('-p' + $legR) $arc)) {
            if ($l -like 'Path = *') { $names += $l.Substring(7) }
            if ($l -like 'Packed Size = *') { $packed += [int64]$l.Substring(14) }
        }
        if ($names.Count -ne 2 -or $names[0] -ne 'a.txt' -or $names[1] -ne 'b.txt' -or $packed.Count -ne 2 -or $packed[1] -lt 16) { throw ('unexpected archive layout: ' + ($names -join ',') + ' / ' + ($packed -join ',')) }
        $fs = [IO.File]::Open($arc, 'Open', 'ReadWrite')
        try {
            $at = 32 + $packed[0] + [int64][Math]::Floor($packed[1] / 2) - 4      # the packed streams follow the 32-byte start header in item order
            $buf = New-Object byte[] 8
            [void]$fs.Seek($at, 'Begin'); [void]$fs.Read($buf, 0, 8)
            for ($k = 0; $k -lt 8; $k++) { $buf[$k] = $buf[$k] -bxor 0xFF }
            [void]$fs.Seek($at, 'Begin'); $fs.Write($buf, 0, 8)
        }
        finally { $fs.Dispose() }
        $aOk = ((Seven @('t', '-bso0', '-bsp0', '-bse0', ('-p' + $legR), $arc, 'a.txt')) -eq 0)
        $bOk = ((Seven @('t', '-bso0', '-bsp0', '-bse0', ('-p' + $legR), $arc, 'b.txt')) -eq 0)
        if (-not $aOk -or $bOk) { throw "the damage did not land in b.txt only (7z t: a.txt ok=$aOk, b.txt ok=$bOk)" }
    } $typedR '' $expBig @('a.txt') 1 'the intact a.txt unpacked and equal, one message for the damaged b.txt'

    # M6: the target already holds a.txt with other content; the overwrite question is answered Skip
    function Skip-Row([string]$Row, [string]$What, [string]$Extra, [hashtable]$Expect) {
        if (-not (Want $Row)) { return }
        try {
            $d = New-RowDirs $Row
            $arc = Join-Path $d.Panel 'secret.7z'
            New-Mixed $arc $typedR $legR $Extra
            $mine = Join-Path $d.Out 'a.txt'
            [IO.File]::WriteAllText($mine, 'the user''s own a.txt - must stay')
            $before = Sha $mine
            $r = Do-Unpack $d.Panel $d.Out $typedR '' 'Skip'
            if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
            $kept = ((Test-Path -LiteralPath $mine) -and (Sha $mine) -eq $before)
            $cmp = Compare-Out $d.Out $Expect
            $obs = "prompts={0}; overwrite question asked {1} time(s); the user's a.txt unchanged: {2}; in the target: {3}; messages={4}{5}" -f $r.Prompts, $r.Overwrites, $kept, (Show-Out $cmp), $r.Messages.Count, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' })
            $ok = ($r.Prompts -eq 1 -and $r.Overwrites -eq 1 -and $kept -and $cmp['b.txt'] -eq 'equal' -and $cmp['c.txt'] -eq 'equal' -and $cmp.Count -eq 3 -and $r.Messages.Count -eq 0 -and -not $r.TimedOut)
            Result $Row $What 'asked once, a.txt on disk unchanged, b.txt and c.txt unpacked and equal, no message' $obs $ok (Msgs $r)
        }
        catch { Result $Row $What '-' ('NOT DRIVEN: ' + $_.Exception.Message) $false '' }
    }
    Skip-Row 'M6a' 'EXISTING a.txt in the target, MIXED as M1 (a.txt is met in the first pass); overwrite question: Skip' (Join-Path $big 'c.txt') $expBig
    Skip-Row 'M6b' 'EXISTING a.txt in the target, MIXED as M2 (a.txt is met in the second pass); overwrite question: Skip' (Join-Path $tiny 'c.txt') $expTiny

    # M7: a wrong non-ASCII password, then the right one in the same instance
    if (Want 'M7') {
        $Row = 'M7'; $What = 'wrong non-ASCII password (wrong-u) on an archive by 7-Zip (typed-r); then Unpack again with typed-r'
        try {
            $d = New-RowDirs $Row
            $arc = Join-Path $d.Panel 'secret.7z'
            if ((Seven @('a', '-bso0', '-bsp0', ('-p' + $typedR), $arc, (Join-Path $src '*'))) -ne 0) { throw '7z.exe could not make the archive' }
            $r = Do-Unpack $d.Panel $d.Out $wrongU '' '' $typedR
            if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
            $cmp = Compare-Out $d.Out @{ 'a.txt' = (Join-Path $src 'a.txt'); 'b.txt' = (Join-Path $src 'b.txt') }
            $obs = "first: prompts={0}, messages={1}, files left in the target: {2}; second: prompts={3}, messages={4}, in the target: {5}" -f $r.Prompts, $r.Messages.Count, $(if ($r.LeftAfterFirst.Count) { $r.LeftAfterFirst -join ', ' } else { 'none' }), $r.Second.Prompts, $r.Second.Messages.Count, (Show-Out $cmp)
            $ok = ($r.Prompts -eq 1 -and $r.Messages.Count -eq 1 -and $r.LeftAfterFirst.Count -eq 0 -and $r.Second.Prompts -eq 1 -and $r.Second.Messages.Count -eq 0 -and (Only-Equal $cmp @('a.txt', 'b.txt')))
            Result $Row $What 'one message, nothing (not even an empty file) in the target; a second Unpack command (a new session, so it asks in any case) unpacks with the right password' $obs $ok ((Msgs $r) + $(if ($r.Second.Messages.Count) { ' || second: ' + (Msgs $r.Second) } else { '' }))
        }
        catch { Result $Row $What '-' ('NOT DRIVEN: ' + $_.Exception.Message) $false '' }
    }

    # ---- the second review: result accounting, the damaged item ----
    $edir = Join-Path $root 'e'; $ddir = Join-Path $root 'd'; $pdir = Join-Path $root 'p'
    foreach ($x in @($edir, $ddir, $pdir)) { [void][IO.Directory]::CreateDirectory($x) }
    [IO.File]::Copy((Join-Path $src 'a.txt'), (Join-Path $edir 'a.txt')); [IO.File]::Copy((Join-Path $src 'b.txt'), (Join-Path $edir 'b.txt'))
    [IO.File]::WriteAllText((Join-Path $edir 'e.txt'), ('e: the last item of the solid block ' * 300))
    [IO.File]::WriteAllText((Join-Path $ddir 'd.txt'), 'd')
    # p.txt: about 2.7 MB that do not pack to nothing; s.txt: small
    $rnd = New-Object Random 93
    $sb = New-Object Text.StringBuilder
    while ($sb.Length -lt 2700000) { [void]$sb.Append($rnd.Next()).Append(' ').Append($rnd.Next()).Append("`r`n") }
    [IO.File]::WriteAllText((Join-Path $pdir 'p.txt'), $sb.ToString())
    [IO.File]::WriteAllText((Join-Path $pdir 's.txt'), 'small and intact')
    # one solid block a, b, e under legacy-r (what 0.1.8 made) + a 1-byte d.txt under typed-r (added by 7-Zip)
    function New-LegacyBlock([string]$Arc) {
        if ((Seven @('a', '-bso0', '-bsp0', ('-p' + $legR), $Arc, (Join-Path $edir '*'))) -ne 0) { throw '7z.exe could not make the archive' }
        if ((Seven @('a', '-bso0', '-bsp0', ('-p' + $typedR), $Arc, (Join-Path $ddir 'd.txt'))) -ne 0) { throw '7z.exe could not add d.txt' }
    }

    # V1: inside the archive in the panel, e.txt copied out twice (F5): the password is asked once
    if (Want 'V1') {
        $Row = 'V1'; $What = 'IN THE PANEL: block a, b, e under legacy-r + d.txt under typed-r; e.txt copied out (CM_COPYFILES) twice; typed: typed-r'
        $id = 0
        try {
            $d = New-RowDirs $Row
            $arc = Join-Path $d.Panel 'secret.7z'
            New-LegacyBlock $arc
            $out2 = Join-Path $d.Arc 'second'; [void][IO.Directory]::CreateDirectory($out2)
            $id = Start-Tc $d.Panel
            Key $id 0x23; Key $id 0x0D                        # End, Enter: into the archive
            Start-Sleep -Milliseconds 1500; Sync $id
            Clear-Wins $id 'V1 enter' $true
            $runs = @()
            foreach ($target in @($d.Out, $out2)) {
                Key $id 0x23                                  # End: e.txt is the last item
                $dlg = Open-ByCmd $id 727
                if ($dlg -eq [IntPtr]::Zero) { throw 'command 727 opened no window' }
                $path = Find-Ctl $dlg 210
                if ($path -eq [IntPtr]::Zero) { throw ('no IDE_PATH in the Copy dialog: ' + (Get-DialogText $dlg)) }
                [void][Drv093]::SetText($path, $target, 5000)
                [void](Click-Ok $dlg)
                $r = Serve-Operation $id $typedR 60
                if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
                $runs += $r
                Sync $id
            }
            $exp = @{ 'e.txt' = (Join-Path $edir 'e.txt') }
            $c1 = Compare-Out $d.Out $exp; $c2 = Compare-Out $out2 $exp
            $obs = "first copy: prompts={0}, messages={1}, target: {2}; second copy: prompts={3}, messages={4}, target: {5}" -f $runs[0].Prompts, $runs[0].Messages.Count, (Show-Out $c1), $runs[1].Prompts, $runs[1].Messages.Count, (Show-Out $c2)
            $ok = ($runs[0].Prompts -eq 1 -and $runs[0].Messages.Count -eq 0 -and (Only-Equal $c1 @('e.txt')) -and $runs[1].Prompts -eq 0 -and $runs[1].Messages.Count -eq 0 -and (Only-Equal $c2 @('e.txt')))
            Result $Row $What 'e.txt equal both times, asked once (the password stays remembered), no message' $obs $ok ((Msgs $runs[0]) + ' ' + (Msgs $runs[1])).Trim()
        }
        catch { Result $Row $What '-' ('NOT DRIVEN: ' + $_.Exception.Message) $false '' }
        finally { if ($id) { Stop-Tc $id } }
    }

    # X1: the result of the operation, seen through "Delete archive after unpacking"
    if (Want 'X1') {
        $Row = 'X1'; $What = 'RESULT: the same archive, Unpack with mask e.txt and "Delete archive after unpacking"; typed: typed-r'
        try {
            $d = New-RowDirs $Row
            $arc = Join-Path $d.Panel 'secret.7z'
            New-LegacyBlock $arc
            $r = Do-Unpack $d.Panel $d.Out $typedR 'e.txt' '' '' $true
            if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
            $cmp = Compare-Out $d.Out @{ 'e.txt' = (Join-Path $edir 'e.txt') }
            $gone = -not (Test-Path -LiteralPath $arc)
            $obs = "prompts={0}; in the target: {1}; archive deleted (= the operation reported success): {2}; messages={3}{4}" -f $r.Prompts, (Show-Out $cmp), $gone, $r.Messages.Count, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' })
            Result $Row $What 'e.txt equal, no message, the archive is deleted' $obs ($r.Prompts -eq 1 -and (Only-Equal $cmp @('e.txt')) -and $gone -and $r.Messages.Count -eq 0 -and -not $r.TimedOut) (Msgs $r)
        }
        catch { Result $Row $What '-' ('NOT DRIVEN: ' + $_.Exception.Message) $false '' }
    }

    # Z1: a damaged large item keeps its recoverable part (the keep-or-delete question, answered Keep)
    if (Want 'Z1') {
        $Row = 'Z1'; $What = 'DAMAGED large item: legacy archive (legacy-r, not solid), p.txt (2.7 MB) with 16 packed bytes flipped + intact s.txt; typed: typed-r; question answered Keep'
        try {
            $d = New-RowDirs $Row
            $arc = Join-Path $d.Panel 'secret.7z'
            if ((Seven @('a', '-bso0', '-bsp0', '-ms=off', ('-p' + $legR), $arc, (Join-Path $pdir '*'))) -ne 0) { throw '7z.exe could not make the archive' }
            $names = @(); $packed = @()
            foreach ($l in (& $SevenZip l -slt -ba ('-p' + $legR) $arc)) {
                if ($l -like 'Path = *') { $names += $l.Substring(7) }
                if ($l -like 'Packed Size = *') { $packed += [int64]$l.Substring(14) }
            }
            if ($names.Count -ne 2 -or $names[0] -ne 'p.txt' -or $packed.Count -ne 2 -or $packed[0] -lt 100000) { throw ('unexpected archive layout: ' + ($names -join ',') + ' / ' + ($packed -join ',')) }
            $fs = [IO.File]::Open($arc, 'Open', 'ReadWrite')
            try {
                $at = 32 + [int64][Math]::Floor($packed[0] / 2)
                $buf = New-Object byte[] 16
                [void]$fs.Seek($at, 'Begin'); [void]$fs.Read($buf, 0, 16)
                for ($k = 0; $k -lt 16; $k++) { $buf[$k] = $buf[$k] -bxor 0xFF }
                [void]$fs.Seek($at, 'Begin'); $fs.Write($buf, 0, 16)
            }
            finally { $fs.Dispose() }
            $pOk = ((Seven @('t', '-bso0', '-bsp0', '-bse0', ('-p' + $legR), $arc, 'p.txt')) -eq 0)
            $sOk = ((Seven @('t', '-bso0', '-bsp0', '-bse0', ('-p' + $legR), $arc, 's.txt')) -eq 0)
            if ($pOk -or -not $sOk) { throw "the damage did not land in p.txt only (7z t: p.txt ok=$pOk, s.txt ok=$sOk)" }
            $r = Do-Unpack $d.Panel $d.Out $typedR '' '' '' $false 'Keep'
            if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
            $pf = Join-Path $d.Out 'p.txt'
            $size = 0; if (Test-Path -LiteralPath $pf) { $size = (New-Object IO.FileInfo $pf).Length }
            $sEq = ((Test-Path -LiteralPath (Join-Path $d.Out 's.txt')) -and (Sha (Join-Path $d.Out 's.txt')) -eq (Sha (Join-Path $pdir 's.txt')))
            $asked = @($r.Messages | Where-Object { $_ -match 'Keep' }).Count
            $obs = "prompts={0}; s.txt equal: {1}; kept part of p.txt: {2} bytes (of {3}); keep-or-delete question asked {4} time(s); messages={5}{6}" -f $r.Prompts, $sEq, $size, (New-Object IO.FileInfo (Join-Path $pdir 'p.txt')).Length, $asked, $r.Messages.Count, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' })
            Result $Row $What 's.txt equal; the question is asked once and Keep leaves the decoded part of p.txt (size above 0, as pre-093)' $obs ($r.Prompts -eq 1 -and $sEq -and $size -gt 0 -and $asked -eq 1 -and $r.Messages.Count -eq 1 -and -not $r.TimedOut) (Msgs $r)
        }
        catch { Result $Row $What '-' ('NOT DRIVEN: ' + $_.Exception.Message) $false '' }
    }

    # D1 / D2: a skipped file in a block read with the wrong form must not turn the operation into a failure.
    # a.txt, b.txt in one solid block under typed-r with a Delta filter (output precedes the failure),
    # a tiny c.txt under legacy-r (so the preferred form is the legacy one); Unpack with mask b.txt.
    function Delta-Row([string]$Row, [string]$What, [bool]$Existing) {
        if (-not (Want $Row)) { return }
        try {
            $d = New-RowDirs $Row
            $arc = Join-Path $d.Panel 'secret.7z'
            if ((Seven @('a', '-bso0', '-bsp0', '-mf=Delta:4', ('-p' + $typedR), $arc, (Join-Path $src '*'))) -ne 0) { throw '7z.exe could not make the archive' }
            if ((Seven @('a', '-bso0', '-bsp0', ('-p' + $legR), $arc, (Join-Path $tiny 'c.txt'))) -ne 0) { throw '7z.exe could not add c.txt' }
            $mine = Join-Path $d.Out 'b.txt'; $before = ''
            if ($Existing) { [IO.File]::WriteAllText($mine, 'the user''s own b.txt - must stay'); $before = Sha $mine }
            $r = Do-Unpack $d.Panel $d.Out $typedR 'b.txt' $(if ($Existing) { 'Skip' } else { '' }) '' $true
            if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
            $gone = -not (Test-Path -LiteralPath $arc)
            if ($Existing) {
                $kept = ((Test-Path -LiteralPath $mine) -and (Sha $mine) -eq $before)
                $files = @([IO.Directory]::GetFiles($d.Out, '*', 'AllDirectories')).Count
                $obs = "prompts={0}; overwrite question asked {1} time(s); the user's b.txt unchanged: {2}; files in the target: {3}; archive deleted (= success reported): {4}; messages={5}{6}" -f $r.Prompts, $r.Overwrites, $kept, $files, $gone, $r.Messages.Count, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' })
                Result $Row $What 'asked once, the user''s b.txt unchanged, no message, the archive is deleted (a skipped file is no failure)' $obs ($r.Prompts -eq 1 -and $r.Overwrites -eq 1 -and $kept -and $files -eq 1 -and $gone -and $r.Messages.Count -eq 0 -and -not $r.TimedOut) (Msgs $r)
            }
            else {
                $cmp = Compare-Out $d.Out @{ 'b.txt' = (Join-Path $src 'b.txt') }
                $obs = "prompts={0}; in the target: {1}; archive deleted (= success reported): {2}; messages={3}{4}" -f $r.Prompts, (Show-Out $cmp), $gone, $r.Messages.Count, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' })
                Result $Row $What 'b.txt equal, no message, the archive is deleted' $obs ($r.Prompts -eq 1 -and (Only-Equal $cmp @('b.txt')) -and $gone -and $r.Messages.Count -eq 0 -and -not $r.TimedOut) (Msgs $r)
            }
        }
        catch { Result $Row $What '-' ('NOT DRIVEN: ' + $_.Exception.Message) $false '' }
    }
    Delta-Row 'D1' 'SKIP in a mis-keyed block: a, b (Delta filter, typed-r) + tiny c (legacy-r); mask b.txt, existing b.txt in the target, Skip, "Delete archive"; typed: typed-r' $true
    Delta-Row 'D2' 'control for D1: the same archive and mask, no existing file' $false

    # ---- pack ----
    function Pack-Row([string]$Row, [string]$What, [string]$Prepare, [string]$Typed, [scriptblock]$Judge) {
        if (-not (Want $Row)) { return }
        try {
            $d = New-RowDirs $Row
            [IO.File]::Copy((Join-Path $src 'b.txt'), (Join-Path $d.Panel 'added.txt'))
            $arc = Join-Path $d.Arc 'made.7z'
            $before = ''
            if ($Prepare) {
                if ((Seven @('a', '-bso0', '-bsp0', ('-p' + $Prepare), $arc, (Join-Path $src '*'))) -ne 0) { throw '7z.exe could not make the archive' }
                $before = Sha $arc
            }
            $r = Do-Pack $d.Panel $arc $Typed
            if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
            $after = ''; if (Test-Path -LiteralPath $arc) { $after = Sha $arc }
            & $Judge $Row $What $arc $r ($before -ne '' -and $before -eq $after)
        }
        catch { Result $Row $What '-' ('NOT DRIVEN: ' + $_.Exception.Message) $false '' }
    }
    function Forms([string]$Arc, [string]$Typed) {
        $leg = Get-Legacy $Typed
        return [pscustomobject]@{ True = (SevenTest $Arc $Typed); Legacy = (SevenTest $Arc $leg); NamesTrue = (SevenNames $Arc $Typed); NamesLegacy = (SevenNames $Arc $leg) }
    }

    Pack-Row 'P1' 'new archive packed by the plug-in, password typed-r' '' $typedR {
        param($Row, $What, $arc, $r, $unchanged)
        $f = Forms $arc $typedR
        $obs = "dialog '{0}'; 7z t -p<typed-r>: {1}; 7z t -p<legacy-r>: {2}; messages={3}" -f $r.OptionsTitle, $f.True, $f.Legacy, $r.Messages.Count
        Result $Row $What '7-Zip tests it with typed-r, not with legacy-r' $obs ($f.True -and -not $f.Legacy -and $r.Messages.Count -eq 0) (Msgs $r)
    }
    Pack-Row 'P2' 'file added to a LEGACY archive (content encrypted with legacy-r), password typed-r' $legR $typedR {
        param($Row, $What, $arc, $r, $unchanged)
        $f = Forms $arc $typedR
        $has = ($f.NamesLegacy -contains 'added.txt')
        $obs = "dialog '{0}'; whole archive tests with legacy-r: {1}; with typed-r: {2}; added.txt in it: {3}; items: {4}; messages={5}" -f $r.OptionsTitle, $f.Legacy, $f.True, $has, $f.NamesLegacy.Count, $r.Messages.Count
        Result $Row $What 'one password: the whole archive tests with legacy-r, the file is in it' $obs ($f.Legacy -and -not $f.True -and $has -and $f.NamesLegacy.Count -eq 3 -and $r.Messages.Count -eq 0) (Msgs $r)
    }
    Pack-Row 'P3' 'file added to an archive by 7-Zip (content encrypted with typed-r), password typed-r' $typedR $typedR {
        param($Row, $What, $arc, $r, $unchanged)
        $f = Forms $arc $typedR
        $has = ($f.NamesTrue -contains 'added.txt')
        $obs = "whole archive tests with typed-r: {0}; with legacy-r: {1}; added.txt in it: {2}; items: {3}; messages={4}" -f $f.True, $f.Legacy, $has, $f.NamesTrue.Count, $r.Messages.Count
        Result $Row $What 'one password: the whole archive tests with typed-r, the file is in it' $obs ($f.True -and -not $f.Legacy -and $has -and $f.NamesTrue.Count -eq 3 -and $r.Messages.Count -eq 0) (Msgs $r)
    }
    Pack-Row 'P4' 'file added to an archive encrypted with ANOTHER password (other-u), password typed-r' $otherU $typedR {
        param($Row, $What, $arc, $r, $unchanged)
        $legacy = Get-Legacy $typedR
        $addTrue = ((Seven @('t', '-bso0', '-bsp0', '-bse0', ('-p' + $typedR), $arc, 'added.txt')) -eq 0)
        $addLegacy = ((Seven @('t', '-bso0', '-bsp0', '-bse0', ('-p' + $legacy), $arc, 'added.txt')) -eq 0)
        $orig = ((Seven @('t', '-bso0', '-bsp0', '-bse0', ('-p' + $otherU), $arc, 'a.txt', 'b.txt')) -eq 0)
        $names = SevenNames $arc $typedR
        $obs = "added.txt tests with typed-r: {0}; with legacy-r: {1}; a.txt and b.txt still test with other-u: {2}; items: {3}; messages={4}" -f $addTrue, $addLegacy, $orig, $names.Count, $r.Messages.Count
        Result $Row $What 'written with the typed password: 7z t with typed-r passes for the added file, the original files still test with their own password; nothing refused' $obs ($addTrue -and -not $addLegacy -and $orig -and $names.Count -eq 3 -and $r.Messages.Count -eq 0) (Msgs $r)
    }
    Pack-Row 'P5' 'new archive, password of 70 Cyrillic letters (140 UTF-8 bytes: over the old 128-byte buffer)' '' $longC {
        param($Row, $What, $arc, $r, $unchanged)
        $ok = SevenTest $arc $longC
        $obs = "7z t -p<the same 70 letters>: {0}; messages={1}" -f $ok, $r.Messages.Count
        Result $Row $What '7-Zip tests it with the typed text' $obs ($ok -and $r.Messages.Count -eq 0) (Msgs $r)
    }
}
catch { Out ("PROBE ERROR: " + $_.Exception.Message) }
finally {
    foreach ($s in @($Started)) { try { Stop-Tc $s } catch { Out "  (stop $s : $($_.Exception.Message))" } }
    $left = @($Started | Where-Object { Test-Alive $_ }).Count
    for ($k = 0; $k -lt 10 -and [IO.Directory]::Exists($root); $k++) {
        try { [IO.Directory]::Delete($root, $true) } catch { Start-Sleep -Milliseconds 500 }
    }
    $regOk = Restore-TcRegistry $backup $existed
    if ($regOk -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }   # kept only when the restore could not be verified
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}; unexpected windows at start: {2}" -f $script:RowPass, $script:RowFail, $script:Unexpected.Count)
    Out ("Test processes left: {0}; fixture folder left: {1}; registry restored identical: {2}; process exit codes: {3}" -f $left, [IO.Directory]::Exists($root), $regOk, ($script:ExitCodes -join ','))
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines.ToArray([string]), (New-Object Text.UTF8Encoding($false))) }
}
if ($regOk) { exit 0 } else { exit 1 }
