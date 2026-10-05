# Feature 098 probe library: window driving, registry, clipboard and report helpers
# shared by fix_probe.ps1 and click_debug.ps1 (dot-sourced; needs $Exe). Pure ASCII.

Add-Type -AssemblyName System.Windows.Forms
# feature 119 (code review SF3): every probe that dot-sources this library drives the program's
# windows - never on the user's desktop (Default / Winlogon); only through
# tools\run_on_hidden_desktop.ps1. A run the user agreed to watch on the visible desktop sets
# TC_PROBE_ALLOW_VISIBLE_DESKTOP=1 for that one run.
if (-not ('DeskLib098' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class DeskLib098
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
if ($env:TC_PROBE_ALLOW_VISIBLE_DESKTOP -ne '1') {
    $libDesk = [DeskLib098]::Name()
    # (exit in a dot-sourced file ends only this file - the probe itself must end, before it touches anything)
    if (-not $libDesk -or $libDesk -ieq 'Default' -or $libDesk -ieq 'Winlogon') { [Console]::Out.WriteLine(("NOT RUN: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $libDesk)); [Console]::Out.Flush(); [Environment]::Exit(3) }
}
if (-not ('Drv098f' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class Drv098f
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendTextTimeout(IntPtr h, uint msg, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendGetText(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll")] public static extern uint GetACP();
    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(40000); GetWindowTextW(h, s, 40000); return s.ToString(); }
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
        IntPtr res; var buf = new char[70000];
        SendGetText(h, 0x000D, (IntPtr)buf.Length, buf, 0, timeout, out res);
        int n = (int)res.ToInt64();
        if (n < 0) n = 0; if (n > buf.Length) n = buf.Length;
        return new string(buf, 0, n);
    }
    // ISO image from a folder through IMAPI2FS (ImageStream is a COM IStream)
    public static void SaveStream(object stream, string file)
    {
        var s = (System.Runtime.InteropServices.ComTypes.IStream)stream;
        var buf = new byte[65536];
        IntPtr pRead = Marshal.AllocHGlobal(4);
        try
        {
            using (var fs = new System.IO.FileStream(file, System.IO.FileMode.Create))
            {
                while (true)
                {
                    s.Read(buf, buf.Length, pRead);
                    int n = Marshal.ReadInt32(pRead);
                    if (n <= 0) break;
                    fs.Write(buf, 0, n);
                }
            }
        }
        finally { Marshal.FreeHGlobal(pRead); }
    }
}
'@
}

$MainClass = 'TandemCommanderMainWindowVer01'
$LineClass = 'WinLib Universal Window2'
$RegKey = 'HKCU\Software\Tandem Commander'
$SystemClasses = @('UAC_InputIndicatorOverlayWnd', 'UAC Input Indicator')
$Started = New-Object System.Collections.ArrayList
$script:Procs = @{}
$script:Lines = New-Object System.Collections.ArrayList
$script:Rows = New-Object System.Collections.ArrayList
$LP = '\\?\'
$Utf8 = New-Object Text.UTF8Encoding($false)
$ReportDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$TempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$Root = $TempRoot + '\tc098_fix'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$Euro = [string][char]0x20AC
$Rz = [string][char]0x0159
$Cc = [string][char]0x010D
$Zh = [string][char]0x4E2D
$FatalRx = 'Run-Time Check|Debug Error|Assertion|Runtime Library|Stack around|bug report|problem has occurred|abnormal|has stopped|Unhandled exception|buffer overrun|Buffer is too small'

function Out([string]$s) { Write-Host $s; [void]$script:Lines.Add($s) }
function Esc([string]$s) {
    if ($null -eq $s) { return '<null>' }
    $sb = New-Object Text.StringBuilder
    foreach ($c in $s.ToCharArray()) { if ([int]$c -ge 32 -and [int]$c -lt 127) { [void]$sb.Append($c) } else { [void]$sb.AppendFormat('\u{0:X4}', [int]$c) } }
    return $sb.ToString()
}
function Tail([string]$s, [int]$n = 50) { if ($null -eq $s) { return '<null>' }; if ($s.Length -le $n) { return (Esc $s) }; return ('...' + (Esc $s.Substring($s.Length - $n))) }
function U8Len([string]$s) { return $Utf8.GetByteCount($s) }
function Row([string]$Case, [string]$Step, [string]$Verdict, [string]$Facts) {
    Out ('{0,-10} {1,-6} {2,-11} {3}' -f $Case, $Step, $Verdict, $Facts)
    [void]$script:Rows.Add([pscustomobject]@{ Case = $Case; Step = $Step; Verdict = $Verdict })
}
function V([bool]$ok) { if ($ok) { return 'PASS' } else { return 'FAIL' } }

# ---- registry / clipboard ----------------------------------------------------
function Backup-Reg([string]$File) {
    & cmd.exe /c "reg query `"$RegKey`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    & cmd.exe /c "reg export `"$RegKey`" `"$File`" /y >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'reg export failed' }
    return $true
}
function Restore-Reg([string]$File, [bool]$Existed) {
    & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
    if (-not $Existed) { Out 'Registry: key did not exist before - deleted'; return $true }
    & cmd.exe /c "reg import `"$File`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Out "Registry: IMPORT FAILED - restore by hand from $File"; return $false }
    $check = "$File.check"
    & cmd.exe /c "reg export `"$RegKey`" `"$check`" /y >nul 2>&1"
    $ha = (Get-FileHash -LiteralPath $File).Hash; $hb = (Get-FileHash -LiteralPath $check).Hash
    Out ("Registry: restored; identical={0}; SHA-256 before {1} / after {2}" -f ($ha -eq $hb), $ha, $hb)
    Remove-Item -LiteralPath $check -Force
    return ($ha -eq $hb)
}
function Set-Config {
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) {
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
    }
}
$script:ClipSaved = $null; $script:ClipOk = $false
function Save-Clip {
    try {
        $do = [Windows.Forms.Clipboard]::GetDataObject()
        $fmts = @(); if ($do -ne $null) { $fmts = @($do.GetFormats()) }
        $textual = @('Text', 'UnicodeText', 'System.String', 'OEMText', 'Locale')
        $other = @($fmts | Where-Object { $textual -notcontains $_ })
        if ($other.Count) { Out ('Clipboard: holds non-text data (' + ($other -join ',') + ') - the paste rows are not driven'); return }
        if ([Windows.Forms.Clipboard]::ContainsText()) { $script:ClipSaved = [Windows.Forms.Clipboard]::GetText() } else { $script:ClipSaved = '' }
        $script:ClipOk = $true
        Out ('Clipboard: user text saved ({0} characters)' -f $script:ClipSaved.Length)
    }
    catch { Out ('Clipboard: cannot read (' + $_.Exception.Message + ') - the paste rows are not driven') }
}
function Restore-Clip {
    if (-not $script:ClipOk) { return }
    try {
        if ($script:ClipSaved.Length) { [Windows.Forms.Clipboard]::SetText($script:ClipSaved) } else { [Windows.Forms.Clipboard]::Clear() }
        $now = ''; if ([Windows.Forms.Clipboard]::ContainsText()) { $now = [Windows.Forms.Clipboard]::GetText() }
        Out ('Clipboard: user text restored; identical={0}' -f ($now -ceq $script:ClipSaved))
    }
    catch { Out ('Clipboard: RESTORE FAILED: ' + $_.Exception.Message) }
}

# ---- process / windows -------------------------------------------------------
function Test-Alive([int]$Id) { return [bool](Get-Process -Id $Id -ErrorAction SilentlyContinue) }
function Get-Tops([int]$Id) { return @([Drv098f]::Top([uint32]$Id) | Where-Object { $SystemClasses -notcontains [Drv098f]::Cls($_) }) }
function Get-Main([int]$Id) { foreach ($h in [Drv098f]::Top([uint32]$Id)) { if ([Drv098f]::Cls($h) -eq $MainClass) { return $h } }; return [IntPtr]::Zero }
function FullText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv098f]::Kids($H)) { $t = [Drv098f]::Txt($c); if ($t -and [Drv098f]::IsWindowVisible($c)) { $parts += ("[{0} id={1}] {2}" -f [Drv098f]::Cls($c), [Drv098f]::GetDlgCtrlID($c), (Esc ($t -replace '\s+', ' '))) } }
    $r = ($parts -join ' | '); if ($r.Length -gt 600) { $r = $r.Substring(0, 300) + ' ...(' + ($r.Length - 600) + ')... ' + $r.Substring($r.Length - 300) }; return $r
}
function WinDesc([IntPtr]$H) { return ("[{0} '{1}'] {2}" -f [Drv098f]::Cls($H), (Tail ([Drv098f]::Txt($H)) 70), (FullText $H)) }
function Reports { return @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) }
function Post-Cmd([IntPtr]$H, [int]$C) { [void][Drv098f]::PostMessageW($H, 0x0111, [IntPtr]$C, [IntPtr]::Zero) }
function Buttons([IntPtr]$H) { return @([Drv098f]::Kids($H) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::IsWindowVisible($_) }) }
function Click([IntPtr]$B) { [void][Drv098f]::PostMessageW($B, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
function Find-Ctl([IntPtr]$Dlg, [int]$CtlId) {
    $c = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and @('ComboBox', 'Edit') -contains [Drv098f]::Cls($_) })
    $v = @($c | Where-Object { [Drv098f]::IsWindowVisible($_) }); if ($v.Count) { return $v[0] }; if ($c.Count) { return $c[0] }
    return [IntPtr]::Zero
}
function Close-Win([IntPtr]$H) {
    if (-not [Drv098f]::IsWindow($H)) { return }
    Post-Cmd $H 2
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv098f]::IsWindow($H) -and [Drv098f]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
    if ([Drv098f]::IsWindow($H) -and [Drv098f]::IsWindowVisible($H)) { [void][Drv098f]::PostMessageW($H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 500 }
}
function Click-Ok([IntPtr]$Dlg) {
    $ok = Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
    if ($ok) { Click $ok }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv098f]::IsWindow($Dlg) -and [Drv098f]::IsWindowEnabled($Dlg)) { Start-Sleep -Milliseconds 50 }
    if ([Drv098f]::IsWindow($Dlg) -and [Drv098f]::IsWindowEnabled($Dlg)) { Post-Cmd $Dlg 1 }
}
function Wait-NewWin([int]$Id, $Known, [double]$Seconds = 8) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in (Get-Tops $Id)) { if ($Known -notcontains $h) { Start-Sleep -Milliseconds 400; return $h } }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
function Open-ByCmd([int]$Id, [int]$C, [double]$Seconds = 10) { $known = Get-Tops $Id; Post-Cmd (Get-Main $Id) $C; return (Wait-NewWin $Id $known $Seconds) }
function Get-LeftList([int]$Id) {
    $lists = @([Drv098f]::Kids((Get-Main $Id)) | Where-Object { [Drv098f]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv098f]::IsWindowVisible($_) })
    if ($lists.Count -lt 1) { throw 'panel list window not found' }
    return $lists[0]
}
function Key([int]$Id, [int]$Vk) {   # synchronous: returns when the key was handled (or after 30 s)
    $l = Get-LeftList $Id
    [void][Drv098f]::Send($l, 0x0100, $Vk, 1, 30000)
    [void][Drv098f]::Send($l, 0x0101, $Vk, 0xC0000001, 30000)
}
function Start-Tc([string]$Left) {
    $a = @('-t', 'T098', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2000
    return $p.Id
}
function Kill-Mine([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    if ($Started -notcontains $Id) { throw "pid $Id was not started by this probe" }
    Stop-Process -Id $Id -Force; Start-Sleep -Milliseconds 700
}
function ExitCodeOf([int]$Id) {
    if (-not $script:Procs.ContainsKey($Id)) { return 'unknown' }
    try { [void]$script:Procs[$Id].WaitForExit(5000); return ('0x{0:X8}' -f $script:Procs[$Id].ExitCode) } catch { return 'unknown' }
}
# the first fatal window of the pid (run-time check, assertion, crash message) or $null
function Fatal-Win([int]$Id) {
    if (-not (Test-Alive $Id)) { return $null }
    foreach ($h in (Get-Tops $Id)) { if ([Drv098f]::Cls($h) -ne $MainClass) { $d = WinDesc $h; if ($d -match $FatalRx) { return $d } } }
    return $null
}
# serves the instance until idle; records windows, answers OK/Yes (or the ids given), cancels a re-opened Change Directory
function Serve([int]$Id, [double]$Seconds = 30, [int[]]$Want = @(1, 6)) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; Died = $false; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { $r.Died = $true; break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 1.5) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) { continue }   # progress
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            if ([Drv098f]::Txt($h) -eq 'Change Directory') { [void]$r.Messages.Add('Change Directory dialog opened'); Close-Win $h; Start-Sleep -Milliseconds 400; continue }
            [void]$r.Messages.Add($d)
            $pick = $btn | Where-Object { $Want -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function Msgs($r) { if ($r.Messages.Count) { return ($r.Messages -join ' || ') } else { return 'no window' } }
# reads the report(s) a fatal case left: the RTC lines and the first call-stack lines; removes them
function Take-Reports($Before) {
    $out = @()
    foreach ($n in @((Reports) | Where-Object { $Before -notcontains $_ })) {
        $p = Join-Path $ReportDir $n
        try {
            $lines = @(Get-Content -LiteralPath $p -TotalCount 40)
            $keep = @($lines | Where-Object { $_ -match 'Error Number|Description|Exception:|::|\(\)' } | Select-Object -First 12 | ForEach-Object { $_.Trim() })
            $out += ($n + ': ' + ($keep -join ' / '))
        }
        catch { $out += ($n + ': unreadable') }
        Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    }
    return $out
}
# END row
function End-Row([string]$Case, [int]$Id, [string]$Fatal, $Before) {
    $alive = Test-Alive $Id
    $resp = $false; if ($alive -and -not $Fatal) { $resp = [Drv098f]::Send((Get-Main $Id), 0, 0, 0, 10000) }
    $extra = @(); if ($alive -and -not $Fatal) { $extra = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass } | ForEach-Object { WinDesc $_ }) }
    $ec = '-'
    if ($Fatal -or -not $resp) { if ($alive) { Kill-Mine $Id; $ec = 'ended by the probe' } else { $ec = ExitCodeOf $Id } }
    else {
        [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
            foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) { $extra += ('at exit: ' + (WinDesc $h)); $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
            Start-Sleep -Milliseconds 200
        }
        if (Test-Alive $Id) { Kill-Mine $Id; $ec = 'did not exit in 30 s - ended by the probe' } else { $ec = ExitCodeOf $Id }
    }
    Start-Sleep -Milliseconds 400
    $rep = Take-Reports $Before
    $notes = @($extra | Where-Object { $_ -match 'monitored handles remained opened' })
    $extra = @($extra | Where-Object { $_ -notmatch 'monitored handles remained opened' })
    $ok = (-not $Fatal) -and $resp -and ($extra.Count -eq 0) -and ($rep.Count -eq 0) -and ($ec -eq '0x00000000')
    Row $Case 'END' (V $ok) ("exit {0}; alive {1}; WM_NULL {2}; stray {3}; new reports {4}{5}{6}{7}" -f $ec, $alive, $resp, $(if ($extra.Count) { '' + $extra.Count + ' (' + ($extra -join ' || ') + ')' } else { '0' }), $rep.Count, $(if ($rep.Count) { ' [' + ($rep -join ' ;; ') + ']' } else { '' }), $(if ($Fatal) { '; FATAL: ' + $Fatal } else { '' }), $(if ($notes.Count) { '; Debug note: monitored handles' } else { '' }))
}
# Change Directory: wide WM_SETTEXT into field 210, OK; returns $true when the field held the text
function Do-ChangeDir([int]$Id, [string]$Text) {
    $dlg = Open-ByCmd $Id 862
    if ($dlg -eq [IntPtr]::Zero) { throw 'Change Directory (862) opened no window' }
    $ctl = Find-Ctl $dlg 210
    if ($ctl -eq [IntPtr]::Zero) { throw 'path field 210 not found' }
    [void][Drv098f]::SetText($ctl, $Text, 5000)
    $held = [Drv098f]::GetText($ctl, 5000)
    Click-Ok $dlg
    Start-Sleep -Milliseconds 600
    return ($held -ceq $Text)
}
# the panel's location: the Change Directory field as the dialog opens, then Cancel
function Get-Loc([int]$Id) {
    if (-not (Test-Alive $Id)) { return '<gone>' }
    $dlg = Open-ByCmd $Id 862
    if ($dlg -eq [IntPtr]::Zero) { return '<no dialog>' }
    $d = WinDesc $dlg
    if ($d -match $FatalRx) { return ('<FATAL ' + $d + '>') }
    $ctl = Find-Ctl $dlg 210
    $t = '<no field>'; if ($ctl -ne [IntPtr]::Zero) { $t = [Drv098f]::GetText($ctl, 5000) }
    Close-Win $dlg
    Start-Sleep -Milliseconds 300
    return $t
}
function Which-Viewer([int]$Id) {   # F3 on the focused item: the viewer window's title
    $w = Open-ByCmd $Id 742 15
    if ($w -eq [IntPtr]::Zero) { return '<no viewer window>' }
    Start-Sleep -Milliseconds 800
    $d = WinDesc $w
    if ($d -match $FatalRx) { return ('<FATAL ' + $d + '>') }
    if ([Drv098f]::Cls($w) -eq '#32770') { $t = '<message> ' + $d; Click-Ok $w; return $t }
    $t = [Drv098f]::Txt($w)
    [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 700
    return $t
}
function Stop-Tc([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 20 -and (Test-Alive $Id)) { Start-Sleep -Milliseconds 200 }
    Kill-Mine $Id
}
# the directory line of the left panel: the universal-window child of the panel that ends right
# above the list box (the window above it is the tab strip of feature 078; the directory line
# holds the 30-px drive toolbar at its left)
function Find-DirLine([int]$Id) {
    $list = Get-LeftList $Id
    $panel = [Drv098f]::GetParent($list)
    $lr = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($list, [ref]$lr)
    $line = [IntPtr]::Zero; $best = -1e9
    foreach ($h in @([Drv098f]::Kids($panel) | Where-Object { [Drv098f]::Cls($_) -eq $LineClass -and [Drv098f]::GetParent($_) -eq $panel -and [Drv098f]::IsWindowVisible($_) })) {
        $wr = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($h, [ref]$wr)
        if ($wr.Bottom -le $lr.Top + 1 -and $wr.Bottom -gt $best) { $best = $wr.Bottom; $line = $h }
    }
    return $line
}
# posts a left click at client x,y of window H
function Post-Click([IntPtr]$H, [int]$X, [int]$Y) {
    $lParam = [IntPtr](($Y -shl 16) -bor $X)
    [void][Drv098f]::PostMessageW($H, 0x0200, [IntPtr]::Zero, $lParam)   # WM_MOUSEMOVE
    [void][Drv098f]::PostMessageW($H, 0x0201, [IntPtr]1, $lParam)        # WM_LBUTTONDOWN
    [void][Drv098f]::PostMessageW($H, 0x0202, [IntPtr]::Zero, $lParam)   # WM_LBUTTONUP
}
function NewDir([string]$p) { [void][IO.Directory]::CreateDirectory($LP + $p) }
function WriteFile([string]$p, [string]$text) { [IO.File]::WriteAllText($LP + $p, $text, (New-Object Text.ASCIIEncoding)) }

