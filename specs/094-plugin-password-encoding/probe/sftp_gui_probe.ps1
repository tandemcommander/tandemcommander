<#
.SYNOPSIS
    Feature 094 research probe: which BYTES the SFTP plug-in sends as the
    password. Measurement only.

.DESCRIPTION
    Starts sshlog_server.py (a local SSH server on 127.0.0.1 that logs the
    bytes of every password offered and refuses the login), then per row a
    fresh instance of tandemcommander.exe: Change Directory (862) to
    "sftp:probe@127.0.0.1:<port>/" -> the plug-in's host-key question (trust,
    button 643) -> its password prompt (IDD_PASSWORD, edit IDE_PROMPTPASSWORD =
    630, wide WM_SETTEXT) -> OK. The row prints what the server received.

    MUST be started through tools\run_on_hidden_desktop.ps1. Refuses to run
    while a tandemcommander.exe other than -Exe is running.
    HKCU\Software\Tandem Commander is exported before the first start and
    restored and verified (SHA-256 of a second export) at the end - that also
    removes the host key the run stores. The fixture %TEMP%\tc094_sftp_run and,
    once the restore is verified, the backup file are removed.

.PARAMETER Python
    A python.exe that has paramiko (a scratch venv).

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII. Helper block:
    specs/093-unicode-dialogs/probe/pwd_gui_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$Python,
    [int]$Port = 2223,
    [string[]]$Only,
    [string]$Label,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

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


# ---- this probe --------------------------------------------------------------
function Buttons([IntPtr]$H) { return @([Drv093]::Kids($H) | Where-Object { [Drv093]::Cls($_) -eq 'Button' -and [Drv093]::IsWindowVisible($_) }) }
function Click([IntPtr]$Btn) { [void][Drv093]::PostMessageW($Btn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
function Has-Edit([IntPtr]$H, [int]$CtlId) { return ((Find-Ctl $H $CtlId) -ne [IntPtr]::Zero) }
function Short([string]$s) { if ($s.Length -gt 40) { return ('{0} x {1}' -f $s.Length, (Esc $s.Substring(0, 1))) }; return (Esc $s) }
function Utf8Hex([string]$s) { return ((([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { '{0:x2}' -f $_ }) -join ' ') }
function LogLines() { if (Test-Path -LiteralPath $log) { return @(Get-Content -LiteralPath $log) }; return @() }

# Change Directory (862) to sftp:probe@127.0.0.1:<port>/ ; the host-key question
# is answered with "trust" (643), the password prompt (edit 630) gets $Typed.
function Row([string]$Name, [string]$Typed) {
    if ($Only -and ($Only -notcontains $Name)) { return }
    $id = 0
    $before = (LogLines).Count
    $msgs = New-Object System.Collections.ArrayList
    $prompts = 0; $uni = ''
    try {
        $id = Start-Tc $root
        $dlg = Open-ByCmd $id 862
        if ($dlg -eq [IntPtr]::Zero) { throw 'command 862 opened no window' }
        [void][Drv093]::SetText((Find-Ctl $dlg 210), ('sftp:probe@127.0.0.1:{0}/' -f $Port), 5000)
        [void](Click-Ok $dlg)
        $seen = @{}; $idleSince = $null; $typedAt = 0.0
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60) {
            if (-not (Test-Alive $id)) { [void]$msgs.Add('THE PROCESS ENDED'); break }
            $wins = @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -ne $MainClass })
            if (-not $wins.Count) {
                if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
                if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
                Start-Sleep -Milliseconds 100; continue
            }
            $idleSince = $null
            foreach ($h in $wins) {
                if (-not [Drv093]::IsWindow($h) -or -not [Drv093]::IsWindowEnabled($h)) { continue }
                $key = $h.ToInt64()
                $btn = Buttons $h
                $ids = @($btn | ForEach-Object { [Drv093]::GetDlgCtrlID($_) })
                if (Has-Edit $h 630) {
                    if ($prompts -eq 0) {
                        $prompts = 1
                        $e = Find-Ctl $h 630
                        $uni = ('dialog IsWindowUnicode={0}, edit IsWindowUnicode={1}' -f [Drv093]::IsWindowUnicode($h), [Drv093]::IsWindowUnicode($e))
                        [void][Drv093]::SetText($e, $Typed, 5000)
                        [void](Click-Ok $h)
                        $typedAt = $sw.Elapsed.TotalSeconds
                    }
                    elseif ($sw.Elapsed.TotalSeconds - $typedAt -gt 1.5) { $prompts++; Close-Win $id $h; $typedAt = $sw.Elapsed.TotalSeconds }
                    continue
                }
                if (Has-Edit $h 210) {      # the core shows Change Directory again after the failed connection
                    if (-not $seen.ContainsKey($key)) { $seen[$key] = 'changedir'; [void]$msgs.Add('(Change Directory shown again - cancelled)'); Close-Win $id $h }
                    continue
                }
                if ($ids -contains 643) {
                    if (-not $seen.ContainsKey($key)) { $seen[$key] = 'hostkey'; Click ($btn | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 643 } | Select-Object -First 1) }
                    continue
                }
                $isProgress = ($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)
                if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
                if ($isProgress -or ($seen[$key] -is [string])) { continue }
                if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
                [void]$msgs.Add(("[{0} '{1}'] {2}" -f [Drv093]::Cls($h), (Esc ([Drv093]::Txt($h))), (Get-DialogText $h)))
                $seen.Remove($key)
                $pick = $btn | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1
                if ($pick) { Click $pick } else { Close-Win $id $h }
                Start-Sleep -Milliseconds 500
            }
            Start-Sleep -Milliseconds 150
        }
        Clear-Wins $id 'row end' $false
    }
    catch { [void]$msgs.Add('NOT DRIVEN: ' + $_.Exception.Message) }
    finally { if ($id) { Stop-Tc $id } }
    $new = @(LogLines | Select-Object -Skip $before | Where-Object { $_ -like 'password *' })
    $want = Utf8Hex $Typed
    Out ("{0,-3}| typed: {1} ({2} UTF-16 units, {3} UTF-8 bytes) | prompts={4}; {5}" -f $Name, (Short $Typed), $Typed.Length, [Text.Encoding]::UTF8.GetByteCount($Typed), $prompts, $uni)
    if (-not $new.Count) { Out '   | the server saw NO password attempt' }
    foreach ($l in $new) {
        $got = ($l -split 'bytes=')[1]
        $verdict = if ($got -eq $want) { 'EQUAL to the UTF-8 bytes of the typed text' } else { 'DIFFERENT from the UTF-8 bytes of the typed text' }
        $show = if ($got.Length -gt 120) { $got.Substring(0, 120) + '...' } else { $got }
        Out ("   | server received: {0} -> {1} | {2}" -f (($l -split ' bytes=')[0]), $show, $verdict)
    }
    if ($msgs.Count) { Out ("   | messages shown: {0}" -f (($msgs | ForEach-Object { $_ }) -join ' || ')) }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc094_sftp_backup.reg'
$root = Join-Path $env:TEMP 'tc094_sftp_run'
$log = Join-Path $root 'server.log'
$stop = Join-Path $root 'stop.flag'
$existed = Backup-TcRegistry $backup
$regOk = $false; $server = $null
try {
    Out ("=== sftp_gui_probe: {0}  (built {1:yyyy-MM-dd HH:mm:ss}){2} ===" -f $Exe, (Get-Item -LiteralPath $Exe).LastWriteTime, $(if ($Label) { "  [$Label]" } else { '' }))
    $spl = Join-Path (Split-Path -Parent $Exe) 'plugins\sftp\sftp.spl'
    Out ("plug-in: {0} (built {1:yyyy-MM-dd HH:mm:ss}); system code page {2}" -f $spl, (Get-Item -LiteralPath $spl).LastWriteTime, [Drv093]::GetACP())
    if ($existed) { Out ("registry export before: SHA-256 {0}" -f (Get-FileHash -LiteralPath $backup).Hash) }
    if ([IO.Directory]::Exists($root)) { [IO.Directory]::Delete($root, $true) }
    [void][IO.Directory]::CreateDirectory($root)
    [IO.File]::WriteAllText((Join-Path $root 'file.txt'), 'x')

    $server = Start-Process -FilePath $Python -ArgumentList @(('"{0}"' -f (Join-Path $PSScriptRoot 'sshlog_server.py')), $Port, ('"{0}"' -f $log), ('"{0}"' -f $stop), 500) -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 20 -and -not (LogLines | Where-Object { $_ -like 'listening*' })) { Start-Sleep -Milliseconds 200 }
    if (-not (LogLines | Where-Object { $_ -like 'listening*' })) { throw 'the logging SSH server did not start' }
    Out ("server: {0}" -f @(LogLines)[0])
    Out ''

    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'no stored configuration to run with' }
    & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
    & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null

    Row 'S1' 'heslo123'
    Row 'S2' ('heslo-' + (S 0x159))
    Row 'S3' (S 0x43F, 0x430, 0x440, 0x43E, 0x43B, 0x44C)
    Row 'S4' ((S 0x159) * 255)       # 510 UTF-8 bytes: fits the 512-byte buffer
    Row 'S5' ((S 0x159) * 256)       # 512 UTF-8 bytes: does not fit
    Row 'S6' ((S 0x416) * 256)       # 512 UTF-8 bytes, outside the code page
}
catch { Out ("PROBE ERROR: " + $_.Exception.Message) }
finally {
    foreach ($s in @($Started)) { try { Stop-Tc $s } catch { Out "  (stop $s : $($_.Exception.Message))" } }
    $left = @($Started | Where-Object { Test-Alive $_ }).Count
    try { [IO.File]::WriteAllText($stop, 'stop') } catch { }
    if ($server) { if (-not $server.WaitForExit(8000)) { Stop-Process -Id $server.Id -Force }; $left += @(Get-Process -Id $server.Id -ErrorAction SilentlyContinue).Count }
    for ($k = 0; $k -lt 10 -and [IO.Directory]::Exists($root); $k++) {
        try { [IO.Directory]::Delete($root, $true) } catch { Start-Sleep -Milliseconds 500 }
    }
    $regOk = Restore-TcRegistry $backup $existed
    if ($regOk -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    Out ''
    Out ("Test processes left: {0}; fixture folder left: {1}; registry restored identical: {2}; process exit codes: {3}" -f $left, [IO.Directory]::Exists($root), $regOk, ($script:ExitCodes -join ','))
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines.ToArray([string]), (New-Object Text.UTF8Encoding($false))) }
}
if ($regOk) { exit 0 } else { exit 1 }
