<#
.SYNOPSIS
    Feature 094 research probe: the ZIP plug-in's password through the PRODUCT.
    Rows for specs/094-plugin-password-encoding (contract zip-password-forms.md).

.DESCRIPTION
    Per row a fresh instance of tandemcommander.exe (-Exe) is started in a
    folder that holds one file and one operation is driven by command ids and
    window messages (technique and helper block: specs/093-unicode-dialogs/
    probe/pwd_gui_probe.ps1):

      unpack  CM_UNPACK (851) on an archive written by zipfix.py, each item
              keyed with an EXACT byte form of a password -> the plug-in's
              prompt (IDD_PASSWORD, edit IDC_PASSWORD = 120, wide WM_SETTEXT)
              -> OK; the unpacked files are compared with the plain content
              (SHA-256)
      pack    CM_PACK (850), packer "ZIP (Plugin)" -> "Extended Pack Options"
              (IDC_ENCRYPT 106, IDC_PASSWORD1 107, IDC_PASSWORD2 108,
              IDC_ENC_ZIP20 121 / IDC_ENC_AES256 123) -> OK; zipfix.py then
              says which byte form each item of the archive really opens with,
              7z.exe is asked to test it with the typed text, and for some rows
              the archive is unpacked through the product again

    Every row carries the result feature 094 specifies ("expected") and says
    AS EXPECTED or DIFFERENT. Run on the build under test and on the build
    before the feature (negative control: it must differ in the defect rows).

    MUST be started through toolsun_on_hidden_desktop.ps1. Refuses to run
    while a tandemcommander.exe other than -Exe is running.
    HKCU\Software\Tandem Commander is exported before the first start and
    restored and verified (SHA-256 of a second export) at the end. The fixture
    %TEMP%	c094_zip and, once the restore is verified, the backup file are
    removed.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Only,
    [string]$Label,
    [string]$OutFile,
    [switch]$Trace,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe',
    [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
$ZipFix = Join-Path $PSScriptRoot 'zipfix.py'
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
function Sha([string]$File) { return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash }
function CodePts([string]$s, [string]$Sep = ',') { return (($s.ToCharArray() | ForEach-Object { '{0:X}' -f [int]$_ }) -join $Sep) }
function Py([string[]]$A) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $ZipFix @A 2>&1
    $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ('zipfix.py: ' + ($o -join ' ')) }
    return @($o | ForEach-Object { "$_" })
}
function SevenTest([string]$Arc, [string]$Pw) { & $SevenZip t -bso0 -bsp0 -bse0 ('-p' + $Pw) $Arc | Out-Null; return ($LASTEXITCODE -eq 0) }
function Buttons([IntPtr]$H) { return @([Drv093]::Kids($H) | Where-Object { [Drv093]::Cls($_) -eq 'Button' -and [Drv093]::IsWindowVisible($_) }) }
function Click([IntPtr]$Btn) { [void][Drv093]::PostMessageW($Btn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
function Has-Edit([IntPtr]$H, [int]$CtlId) { return ((Find-Ctl $H $CtlId) -ne [IntPtr]::Zero) }
function TextLen([IntPtr]$H) { $res = [IntPtr]::Zero; [void][Drv093]::SendMessageTimeoutW($H, 0x000E, [IntPtr]::Zero, [IntPtr]::Zero, 0, 3000, [ref]$res); return [int]$res.ToInt64() }
function Short([string]$s) { if ($s.Length -gt 40) { return ('{0} x {1}' -f $s.Length, (Esc $s.Substring(0, 1))) }; return (Esc $s) }

$script:RowOk = 0; $script:RowDiff = 0
function Verdict([bool]$Ok) { if ($Ok) { $script:RowOk++; return 'AS EXPECTED' } else { $script:RowDiff++; return 'DIFFERENT' } }

# Serves the windows of the operation until the instance is idle again.
#   the plug-in's password prompt (edit 120, buttons Skip 118 / Skip All 119):
#     the n-th prompt gets $Typed[n] + OK; a prompt beyond the list is cancelled
#   any other window that stays, enabled, for 0.6 s and is not the progress
#     dialog: recorded as a message and dismissed (OK / Yes, else Cancel)
function Serve-Operation([int]$Id, [string[]]$Typed, [double]$Seconds = 60) {
    $r = [pscustomobject]@{ Prompts = 0; Messages = New-Object System.Collections.ArrayList; TimedOut = $false; PromptUnicode = ''; Seen = New-Object System.Collections.ArrayList }
    $seen = @{}
    $idleSince = $null; $typedAt = -10.0; $promptWin = [IntPtr]::Zero
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
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv093]::GetDlgCtrlID($_) })
            if ((Has-Edit $h 120) -and ($ids -contains 118)) {
                $e = Find-Ctl $h 120
                # a new prompt: another window, or the same handle with an empty field again
                $isNew = ($r.Prompts -eq 0) -or ($h -ne $promptWin) -or (($sw.Elapsed.TotalSeconds - $typedAt -gt 1.0) -and (TextLen $e) -eq 0) -or ($sw.Elapsed.TotalSeconds - $typedAt -gt 5.0)
                if (-not $isNew) { continue }
                $r.Prompts++; $promptWin = $h; $typedAt = $sw.Elapsed.TotalSeconds
                if ($r.Prompts -eq 1) { $r.PromptUnicode = ('dialog IsWindowUnicode={0}, edit IsWindowUnicode={1}' -f [Drv093]::IsWindowUnicode($h), [Drv093]::IsWindowUnicode($e)) }
                if ($r.Prompts -le $Typed.Count) {
                    [void][Drv093]::SetText($e, $Typed[$r.Prompts - 1], 5000)
                    [void](Click-Ok $h)
                }
                else { [void]$r.Messages.Add('PROMPT SHOWN AGAIN (cancelled)'); Close-Win $Id $h; $promptWin = [IntPtr]::Zero }
                continue
            }
            $isProgress = ($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $sw.Elapsed.TotalSeconds
                [void]$r.Seen.Add(("{0:N1}s [{1} '{2}'] buttons {3}: {4}" -f $sw.Elapsed.TotalSeconds, [Drv093]::Cls($h), (Esc ([Drv093]::Txt($h))), ($ids -join ','), (Get-DialogText $h)))
                continue
            }
            if ($isProgress) { continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $text = ("[{0} '{1}'] {2}" -f [Drv093]::Cls($h), (Esc ([Drv093]::Txt($h))), (Get-DialogText $h))
            [void]$r.Messages.Add($text)
            $seen.Remove($key)
            $pick = $btn | Where-Object { @(1, 6) -contains [Drv093]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($pick) { Click $pick } else { Close-Win $Id $h }
            Start-Sleep -Milliseconds 500
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

function Do-Unpack([string]$PanelDir, [string]$OutDir, [string[]]$Typed) {
    $id = 0
    try {
        $id = Start-Tc $PanelDir
        Key $id 0x23                                     # End: the one file
        $dlg = Open-ByCmd $id 851
        if ($dlg -eq [IntPtr]::Zero) { throw 'command 851 opened no window' }
        $path = Find-Ctl $dlg 210
        if ($path -eq [IntPtr]::Zero) { throw ('no IDE_PATH in the Unpack dialog: ' + (Get-DialogText $dlg)) }
        [void][Drv093]::SetText($path, $OutDir, 5000)
        [void](Click-Ok $dlg)
        return (Serve-Operation $id $Typed)
    }
    finally { if ($id) { Stop-Tc $id } }
}

# $Method: 121 = ZIP 2.0, 123 = AES-256; $Sfx: also "Create self-extracting archive" (104)
function Do-Pack([string]$PanelDir, [string]$Archive, [string]$Typed, [int]$Method, [bool]$Sfx = $false) {
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
        for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i] -match '^ZIP' -and $items[$i] -match '(?i)plugin') { $ix = $i; break } }
        if ($ix -lt 0) { throw ('no ZIP plug-in packer among: ' + ($items -join ' ; ')) }
        [void][Drv093]::Send($packer, 0x014E, $ix, 0, 5000)                                   # CB_SETCURSEL
        [void][Drv093]::Send($dlg, 0x0111, ((1 -shl 16) -bor 511), $packer.ToInt64(), 5000)  # CBN_SELCHANGE
        [void][Drv093]::SetText((Find-Ctl $dlg 210), $Archive, 5000)
        [void](Click-Ok $dlg)
        $opt = [IntPtr]::Zero; $added = $false
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $opt -eq [IntPtr]::Zero) {
            foreach ($h in (Get-Tops $id)) {
                if ((Has-Edit $h 107) -and (Has-Edit $h 108) -and [Drv093]::IsWindowEnabled($h)) { $opt = $h; continue }
                # the core's question for an existing archive: add into it or overwrite it -> Add
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
        $kid = { param($n) @([Drv093]::Kids($opt) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq $n }) | Select-Object -First 1 }
        if ($Sfx) {
            Click (& $kid 104)
            Start-Sleep -Milliseconds 400
            [void][Drv093]::Send($opt, 0, 0, 0, 5000)
        }
        Click (& $kid 106)                                # BN_CLICKED enables the fields
        Start-Sleep -Milliseconds 400
        [void][Drv093]::Send($opt, 0, 0, 0, 5000)
        Click (& $kid $Method)
        Start-Sleep -Milliseconds 300
        [void][Drv093]::Send($opt, 0, 0, 0, 5000)
        $e1 = Find-Ctl $opt 107; $e2 = Find-Ctl $opt 108
        $uni = ('dialog IsWindowUnicode={0}, edit IsWindowUnicode={1}' -f [Drv093]::IsWindowUnicode($opt), [Drv093]::IsWindowUnicode($e1))
        [void][Drv093]::SetText($e1, $Typed, 5000)
        [void][Drv093]::SetText($e2, $Typed, 5000)
        [void](Click-Ok $opt)
        $r = Serve-Operation $id @() 60
        $r.PromptUnicode = $uni
        return $r
    }
    finally { if ($id) { Stop-Tc $id } }
}

function New-RowDirs([string]$Row) {
    $d = Join-Path $root $Row
    $o = [pscustomobject]@{ Panel = (Join-Path $d 'panel'); Out = (Join-Path $d 'out'); Arc = (Join-Path $d 'arc'); Plain = (Join-Path $d 'plain') }
    foreach ($x in @($o.Panel, $o.Out, $o.Arc, $o.Plain)) { [void][IO.Directory]::CreateDirectory($x) }
    return $o
}
function Msgs($r) { return (($r.Messages | ForEach-Object { $_ }) -join ' || ') }

# item spec for zipfix.py make
function Item([string]$Name, [string]$Kind, [string]$Form, [string]$Pw, [string[]]$Opt = @()) {
    return ((@($Name, $Kind, $Form, (CodePts $Pw '.')) + $Opt) -join ',')
}
# what is in $OutDir against the plain files of $PlainDir: "<equal>/<files>" and the wrong ones
function Compare-Out([string]$OutDir, [string]$PlainDir) {
    $files = @([IO.Directory]::GetFiles($OutDir, '*', 'AllDirectories'))
    $equal = 0; $wrong = @()
    foreach ($f in $files) {
        $p = Join-Path $PlainDir ([IO.Path]::GetFileName($f))
        if ((Test-Path -LiteralPath $p) -and (Sha $f) -eq (Sha $p)) { $equal++ } else { $wrong += [IO.Path]::GetFileName($f) }
    }
    return [pscustomobject]@{ Files = $files.Count; Equal = $equal; Wrong = $wrong }
}

# Archive of $Items (zipfix specs); $Typed: the texts for the prompts, in order.
# Expected: $ExpEqual files unpacked with the right content and nothing else left,
# $ExpPrompts prompts, messages shown ($ExpMsg) or not.
function Unpack-Row([string]$Row, [string]$What, [string[]]$Items, [string[]]$Typed, [int]$ExpEqual, [int]$ExpPrompts, [bool]$ExpMsg) {
    if (-not (Want $Row)) { return }
    try {
        $d = New-RowDirs $Row
        $arc = Join-Path $d.Panel 'secret.zip'
        $notes = Py (@('make', $arc, $d.Plain) + $Items)
        $r = Do-Unpack $d.Panel $d.Out $Typed
        if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
        $c = Compare-Out $d.Out $d.Plain
        $ok = ($c.Equal -eq $ExpEqual -and $c.Files -eq $ExpEqual -and $r.Prompts -eq $ExpPrompts -and (($r.Messages.Count -gt 0) -eq $ExpMsg) -and -not $r.TimedOut)
        Out ("{0,-4}| {1} | typed: {2} | unpacked with the right content: {3} of {4} items{5}; prompts={6}; messages={7}{8} | expected {9} items, {10} prompt(s), {11} | {12}" -f $Row, $What, (($Typed | ForEach-Object { Short $_ }) -join ' then '),
                $c.Equal, $Items.Count, $(if ($c.Wrong.Count) { '; WRONG CONTENT LEFT: ' + ($c.Wrong -join ',') } else { '' }), $r.Prompts, $r.Messages.Count, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }),
                $ExpEqual, $ExpPrompts, $(if ($ExpMsg) { 'a message' } else { 'no message' }), (Verdict $ok))
        foreach ($n in $notes) { Out "    | fixture: $n" }
        if ($r.Messages.Count) { Out ("    | messages shown: {0}" -f (Msgs $r)) }
    }
    catch { Out ("{0,-4}| {1} | NOT DRIVEN: {2} | {3}" -f $Row, $What, $_.Exception.Message, (Verdict $false)) }
}

# The target folder already holds the user's own plain.txt; the archive is keyed with $KeyPw and
# its header lets TWO forms of the wrong text $Typed pass the one-byte check. Specified: the wrong
# password is refused before the target file is touched (the file stays, the prompt comes again).
function Keep-Row([string]$Row, [string]$What, [string]$KeyPw, [string]$Typed) {
    if (-not (Want $Row)) { return }
    try {
        $d = New-RowDirs $Row
        $arc = Join-Path $d.Panel 'secret.zip'
        $notes = Py @('make', $arc, $d.Plain, (Item 'plain.txt' 'zipcrypto' 'acp' $KeyPw @('deflate', ('fpw2=' + (CodePts $Typed '.')))))
        $own = Join-Path $d.Out 'plain.txt'
        [IO.File]::WriteAllText($own, 'the file of the user, which a wrong password must not cost')
        $before = Sha $own
        $r = Do-Unpack $d.Panel $d.Out @($Typed)
        if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
        $state = if (-not (Test-Path -LiteralPath $own)) { 'DELETED' } elseif ((Sha $own) -eq $before) { 'untouched' } else { 'OVERWRITTEN' }
        $asked = @($r.Messages | Where-Object { $_ -match '(?i)overwrite' }).Count
        $ok = ($state -eq 'untouched' -and $r.Prompts -eq 2 -and $asked -eq 0 -and -not $r.TimedOut)
        Out ("{0,-4}| {1} | typed: {2} | the user's file: {3}; prompts={4}; overwrite questions={5}; messages={6}{7} | expected untouched, 2 prompts (the second one cancelled), no overwrite question | {8}" -f $Row, $What, (Short $Typed), $state, $r.Prompts, $asked, $r.Messages.Count, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), (Verdict $ok))
        foreach ($n in $notes) { Out "    | fixture: $n" }
        if ($r.Messages.Count) { Out ("    | messages shown: {0}" -f (Msgs $r)) }
    }
    catch { Out ("{0,-4}| {1} | NOT DRIVEN: {2} | {3}" -f $Row, $What, $_.Exception.Message, (Verdict $false)) }
}

# Packs plain.txt with the plug-in. $ExpForm: the forms (zipfix names) the new item must open with.
# $Existing: zipfix spec of an item the archive holds already (add to an existing archive).
# $Reopen: pairs text / expected ('EXTRACTED' or 'refused') - the produced archive is unpacked through the product again.
function Pack-Row([string]$Row, [string]$What, [int]$Method, [string]$Typed, [string]$ExpForm, [string]$Existing = '', [object[]]$Reopen = @(), [bool]$Sfx = $false, [bool]$ExpArchive = $true) {
    if (-not (Want $Row)) { return }
    try {
        $d = New-RowDirs $Row
        $srcFile = Join-Path $d.Panel 'plain.txt'
        [IO.File]::WriteAllText($srcFile, ('feature 094 zip password probe, packed by the plug-in ' * 40))
        Copy-Item -LiteralPath $srcFile -Destination (Join-Path $d.Plain 'plain.txt')
        $arc = Join-Path $d.Arc 'packed.zip'
        if ($Existing) { [void](Py @('make', $arc, $d.Plain, $Existing)) }
        $r = Do-Pack $d.Panel $arc $Typed $Method $Sfx
        if ($Trace) { foreach ($t in $r.Seen) { Out "    trace: $t" } }
        if ($Sfx) { $made = @([IO.Directory]::GetFiles($d.Arc)); if ($made.Count) { $arc = $made[0] } }
        if (-not (Test-Path -LiteralPath $arc)) {
            Out ("{0,-4}| {1} | typed: {2} | NO ARCHIVE WRITTEN; messages={3} | expected {4} | {5}" -f $Row, $What, (Short $Typed), $r.Messages.Count, $(if ($ExpArchive) { 'an archive' } else { 'no archive and a message' }), (Verdict (-not $ExpArchive -and $r.Messages.Count -gt 0)))
            if ($r.Messages.Count) { Out ("    | messages shown: {0}" -f (Msgs $r)) }
            return
        }
        $w = @(Py @('which', $arc, (CodePts $Typed)))
        $new = @($w | Where-Object { $_ -like 'plain.txt|*' }) | Select-Object -First 1
        $forms = if ($new) { ($new -split '\|')[2] } else { '<no plain.txt item>' }
        $ok = ($ExpArchive -and $forms -eq $ExpForm -and $r.Messages.Count -eq 0)
        $seven = SevenTest $arc $Typed
        Out ("{0,-4}| {1} | typed: {2} | items: {3} | 7z t -p<typed>: {4} | {5}; messages={6} | expected plain.txt keyed with: {7} | {8}" -f $Row, $What, (Short $Typed), ($w -join ' ; '), $(if ($seven) { 'opens' } else { 'refused' }), $r.PromptUnicode, $r.Messages.Count, $ExpForm, (Verdict $ok))
        if ($r.Messages.Count) { Out ("    | messages shown: {0}" -f (Msgs $r)) }
        $n = 0
        foreach ($re in $Reopen) {
            $n++
            $d2 = New-RowDirs ("{0}r{1}" -f $Row, $n)
            Copy-Item -LiteralPath $arc -Destination (Join-Path $d2.Panel 'packed.zip')
            $r2 = Do-Unpack $d2.Panel $d2.Out @($re.Typed)
            $c = Compare-Out $d2.Out $d.Plain
            $obs = if ($c.Files -eq 0) { 'refused' } elseif ($c.Wrong.Count -eq 0) { 'EXTRACTED' } else { 'WRONG CONTENT LEFT' }
            Out ("    | the archive unpacked through the product with {0}: {1} ({2} of {3} files equal; prompts={4}; messages={5}) | expected {6} | {7}" -f (Short $re.Typed), $obs, $c.Equal, $w.Count, $r2.Prompts, $r2.Messages.Count, $re.Expect, (Verdict ($obs -eq $re.Expect)))
        }
    }
    catch { Out ("{0,-4}| {1} | NOT DRIVEN: {2} | {3}" -f $Row, $What, $_.Exception.Message, (Verdict $false)) }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc094_zip_backup.reg'
$root = Join-Path $env:TEMP 'tc094_zip'
$existed = Backup-TcRegistry $backup
$regOk = $false
try {
    Out ("=== zip_gui_probe: {0}  (built {1:yyyy-MM-dd HH:mm:ss}){2} ===" -f $Exe, (Get-Item -LiteralPath $Exe).LastWriteTime, $(if ($Label) { "  [$Label]" } else { '' }))
    $spl = Join-Path (Split-Path -Parent $Exe) 'plugins\zip\zip.spl'
    Out ("plug-in: {0} (built {1:yyyy-MM-dd HH:mm:ss}); system code page {2}" -f $spl, (Get-Item -LiteralPath $spl).LastWriteTime, [Drv093]::GetACP())
    Out 'The "expected" column is the behaviour feature 094 specifies; the build before it is expected to differ in the rows that show the defects.'
    if ($existed) { Out ("registry export before: SHA-256 {0}" -f (Get-FileHash -LiteralPath $backup).Hash) }

    $ascii = 'heslo123'
    $ascii2 = 'jine456'
    $wrongA = 'spatne'
    $typedR = 'heslo-' + (S 0x159)
    $typedC = S 0x43F, 0x430, 0x440, 0x43E, 0x43B, 0x44C
    $otherC = S 0x434, 0x440, 0x443, 0x433, 0x43E, 0x439
    Out ("ascii = {0}; ascii2 = {1}; typed-r = {2}; typed-c = {3}; other-c = {4}" -f $ascii, $ascii2, (Esc $typedR), (Esc $typedC), (Esc $otherC))
    foreach ($t in @($typedR, $typedC)) { Out ("forms of {0}: {1}" -f (Esc $t), ((Py @('forms', (CodePts $t))) -join ' ; ')) }
    Out ''

    if ([IO.Directory]::Exists($root)) { [IO.Directory]::Delete($root, $true) }
    [void][IO.Directory]::CreateDirectory($root)

    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'no stored configuration to run with' }
    & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
    & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add "$RegKey\0.1\Plugins Configuration\ZIP" /v 'Show Extended Options' /t REG_DWORD /d 1 /f | Out-Null

    # ---- every form x both methods: the typed text opens the archive ----
    $n = 0
    foreach ($kind in @('zipcrypto', 'aes256')) {
        foreach ($case in @(@($ascii, 'acp'), @($typedR, 'acp'), @($typedR, 'oem'), @($typedR, 'utf8'), @($typedC, 'utf8'), @($typedC, 'oldread'))) {
            $n++
            Unpack-Row ("U$n") ("{0} keyed with {1} of {2}" -f $kind, $case[1], (Short $case[0])) @((Item 'plain.txt' $kind $case[1] $case[0])) @($case[0]) 1 1 $false
        }
    }
    # deflated items (the fixtures above are stored)
    Unpack-Row 'U13' 'zipcrypto, deflated, keyed with utf8 of typed-r' @((Item 'plain.txt' 'zipcrypto' 'utf8' $typedR @('deflate'))) @($typedR) 1 1 $false
    Unpack-Row 'U14' 'aes256, deflated, keyed with oem of typed-r' @((Item 'plain.txt' 'aes256' 'oem' $typedR @('deflate'))) @($typedR) 1 1 $false

    # ---- wrong passwords: refused as before ----
    Unpack-Row 'W1' 'zipcrypto keyed with ascii; wrong ASCII text typed' @((Item 'plain.txt' 'zipcrypto' 'acp' $ascii)) @($wrongA) 0 2 $true
    Unpack-Row 'W2' 'aes256 keyed with ascii; wrong ASCII text typed' @((Item 'plain.txt' 'aes256' 'acp' $ascii)) @($wrongA) 0 2 $true
    Unpack-Row 'W3' 'zipcrypto keyed with utf8 of typed-c; ANOTHER Cyrillic word typed' @((Item 'plain.txt' 'zipcrypto' 'utf8' $typedC)) @($otherC) 0 2 $true
    Unpack-Row 'W4' 'aes256 keyed with utf8 of typed-c; ANOTHER Cyrillic word typed' @((Item 'plain.txt' 'aes256' 'utf8' $typedC)) @($otherC) 0 2 $true
    Unpack-Row 'W5' 'zipcrypto keyed with typed-r in the code page; wrong non-ASCII text typed' @((Item 'plain.txt' 'zipcrypto' 'acp' $typedR)) @(('spatne-' + (S 0x17E))) 0 2 $true
    # an archive an EARLIER version made with a Cyrillic word is keyed with "??????": any word of that
    # length opens it - the old archive's weakness, which no later version can repair
    Unpack-Row 'W6' 'OLD archive (zipcrypto keyed with the old read of typed-c = ??????); another Cyrillic word typed' @((Item 'plain.txt' 'zipcrypto' 'oldread' $typedC)) @($otherC) 1 1 $false
    # a wrong password that passes the one-byte check: the checksum error, as before
    Unpack-Row 'W7' 'zipcrypto keyed with ascii, header chosen so that the wrong text "spatne" passes the check' @((Item 'plain.txt' 'zipcrypto' 'acp' $ascii @(('fpw=' + (CodePts $wrongA '.'))))) @($wrongA) 0 1 $true

    # ---- the one-byte check passed by a wrong form (1 in 256): the right form is still found ----
    Unpack-Row 'F1' 'zipcrypto keyed with oem of typed-r; the code-page form passes the check by chance (deflated)' @((Item 'plain.txt' 'zipcrypto' 'oem' $typedR @('deflate', 'fp=acp'))) @($typedR) 1 1 $false
    Unpack-Row 'F2' 'zipcrypto keyed with utf8 of typed-r; the code-page form passes the check by chance (stored)' @((Item 'plain.txt' 'zipcrypto' 'utf8' $typedR @('fp=acp'))) @($typedR) 1 1 $false
    Unpack-Row 'F3' 'zipcrypto keyed with utf8 of typed-r; code-page AND OEM forms pass the check by chance (deflated)' @((Item 'plain.txt' 'zipcrypto' 'utf8' $typedR @('deflate', 'fp=acp+oem'))) @($typedR) 1 1 $false
    Unpack-Row 'F4' 'zipcrypto keyed with the old read of typed-c; the utf8 form passes the check by chance (deflated)' @((Item 'plain.txt' 'zipcrypto' 'oldread' $typedC @('deflate', 'fp=utf8'))) @($typedC) 1 1 $false

    # ---- a wrong password, two of whose forms pass the check byte, and a file of the user in the target ----
    Keep-Row 'K1' 'zipcrypto keyed with ascii; code-page and utf8 forms of a WRONG non-ASCII text pass the check; the target file exists' $ascii ('spatne-' + (S 0x17E))

    # ---- several items ----
    Unpack-Row 'M1' 'zipcrypto: item 1 keyed with the code page, item 2 with utf8 of the same text' @((Item 'one.txt' 'zipcrypto' 'acp' $typedR), (Item 'two.txt' 'zipcrypto' 'utf8' $typedR)) @($typedR) 2 1 $false
    Unpack-Row 'M2' 'aes256: item 1 keyed with the code page, item 2 with utf8, item 3 with oem of the same text' @((Item 'one.txt' 'aes256' 'acp' $typedR), (Item 'two.txt' 'aes256' 'utf8' $typedR), (Item 'three.txt' 'aes256' 'oem' $typedR)) @($typedR) 3 1 $false
    Unpack-Row 'M3' 'zipcrypto: item 1 code page; item 2 utf8 with the (now preferred) code-page form passing the check by chance; item 3 code page' @((Item 'one.txt' 'zipcrypto' 'acp' $typedR), (Item 'two.txt' 'zipcrypto' 'utf8' $typedR @('deflate', 'fp=acp')), (Item 'three.txt' 'zipcrypto' 'acp' $typedR)) @($typedR) 3 1 $false
    Unpack-Row 'M4' 'zipcrypto: two items under two different PASSWORDS; the second prompt gets the second password' @((Item 'one.txt' 'zipcrypto' 'acp' $ascii), (Item 'two.txt' 'zipcrypto' 'acp' $ascii2)) @($ascii, $ascii2) 2 2 $false
    Unpack-Row 'M5' 'aes256: two items under two different PASSWORDS; the second prompt gets the second password' @((Item 'one.txt' 'aes256' 'acp' $ascii), (Item 'two.txt' 'aes256' 'acp' $ascii2)) @($ascii, $ascii2) 2 2 $false
    Unpack-Row 'M6' 'zipcrypto: three items, all ascii - one prompt' @((Item 'one.txt' 'zipcrypto' 'acp' $ascii), (Item 'two.txt' 'zipcrypto' 'acp' $ascii @('deflate')), (Item 'three.txt' 'zipcrypto' 'acp' $ascii)) @($ascii) 3 1 $false

    # ---- packing: new archives ----
    Pack-Row 'P1' 'new archive, ZIP 2.0' 121 $ascii 'acp'
    Pack-Row 'P2' 'new archive, ZIP 2.0' 121 $typedR 'acp' '' @(@{ Typed = $typedR; Expect = 'EXTRACTED' })
    Pack-Row 'P3' 'new archive, ZIP 2.0' 121 $typedC 'utf8' '' @(@{ Typed = $typedC; Expect = 'EXTRACTED' }, @{ Typed = $otherC; Expect = 'refused' })
    Pack-Row 'P4' 'new archive, AES-256' 123 $ascii 'acp'
    Pack-Row 'P5' 'new archive, AES-256' 123 $typedR 'acp' '' @(@{ Typed = $typedR; Expect = 'EXTRACTED' })
    Pack-Row 'P6' 'new archive, AES-256' 123 $typedC 'utf8' '' @(@{ Typed = $typedC; Expect = 'EXTRACTED' }, @{ Typed = $otherC; Expect = 'refused' })
    # ---- packing: adding to an existing archive ----
    Pack-Row 'A1' 'file added to an archive keyed with ascii, ZIP 2.0' 121 $ascii 'acp' (Item 'old.txt' 'zipcrypto' 'acp' $ascii)
    Pack-Row 'A2' 'file added to an archive keyed with typed-r (code page), ZIP 2.0' 121 $typedR 'acp' (Item 'old.txt' 'zipcrypto' 'acp' $typedR) @(@{ Typed = $typedR; Expect = 'EXTRACTED' })
    Pack-Row 'A3' 'file added to an OLD archive keyed with ?????? (old read of typed-c), ZIP 2.0' 121 $typedC 'utf8' (Item 'old.txt' 'zipcrypto' 'oldread' $typedC) @(@{ Typed = $typedC; Expect = 'EXTRACTED' })
    Pack-Row 'A4' 'file added to an OLD archive keyed with ?????? (old read of typed-c), AES-256' 123 $typedC 'utf8' (Item 'old.txt' 'aes256' 'oldread' $typedC) @(@{ Typed = $typedC; Expect = 'EXTRACTED' })
    # ---- lengths ----
    Pack-Row 'L1' 'new archive, ZIP 2.0, 255 characters (the field limit)' 121 ('a' * 255) 'acp'
    Pack-Row 'L2' 'new archive, AES-256, 129 characters: over the AES limit of 128 bytes' 123 ('a' * 129) '-' '' @() $false $false
    Pack-Row 'L3' 'new archive, AES-256, 65 two-byte letters: 65 bytes in the code page (130 as UTF-8)' 123 ((S 0x159) * 65) 'acp'
    Pack-Row 'L4' 'new archive, AES-256, 43 Cyrillic letters: 86 bytes as UTF-8' 123 ((S 0x416) * 43) 'utf8'
    Pack-Row 'L5' 'new archive, AES-256, 65 Cyrillic letters: 130 bytes as UTF-8 - over the AES limit for the form used' 123 ((S 0x416) * 65) '-' '' @() $false $false
    # ---- self-extracting archive: keeps the old read (the stub's own prompt reads that way) ----
    # (the Debug output tree holds no self-extractor packages: the row is expected NOT to be drivable there)
    Pack-Row 'X1' 'new SELF-EXTRACTING archive, ZIP 2.0' 121 $typedC 'oldread' '' @() $true
}
catch { Out ("PROBE ERROR: " + $_.Exception.Message) }
finally {
    foreach ($s in @($Started)) { try { Stop-Tc $s } catch { Out "  (stop $s : $($_.Exception.Message))" } }
    $left = @($Started | Where-Object { Test-Alive $_ }).Count
    for ($k = 0; $k -lt 10 -and [IO.Directory]::Exists($root); $k++) {
        try { [IO.Directory]::Delete($root, $true) } catch { Start-Sleep -Milliseconds 500 }
    }
    $regOk = Restore-TcRegistry $backup $existed
    if ($regOk -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    Out ''
    Out ("Rows and sub-rows: AS EXPECTED {0}, DIFFERENT {1}; unexpected windows at start: {2}" -f $script:RowOk, $script:RowDiff, $script:Unexpected.Count)
    Out ("Test processes left: {0}; fixture folder left: {1}; registry restored identical: {2}; process exit codes: {3}" -f $left, [IO.Directory]::Exists($root), $regOk, ($script:ExitCodes -join ','))
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines.ToArray([string]), (New-Object Text.UTF8Encoding($false))) }
}
if ($regOk) { exit 0 } else { exit 1 }
