<#
.SYNOPSIS
    Feature 123 (New Version Check) - the independent tester's behaviour probe.
    Rows are derived from specs/123-new-version-check/spec.md and contracts/*.md, not from the
    code. Every row prints PASS / FAIL / NOT DRIVEN with the facts observed. The exit code is
    the number of FAIL (and ERROR) rows.
    MUST run through tools\run_on_hidden_desktop.ps1 (the shared library refuses the visible
    desktop). Debug builds only (TC_UPDATECHECK_* seams). Refuses to run while any
    tandemcommander.exe is running. Backs up the whole registry key of the product, restores
    it in a finally block and verifies the restore by SHA-256. A crash report the probe
    causes is printed and deleted (only reports that did not exist before the run).
    On the hidden desktop there is no real keyboard or mouse and no foreground window:
    everything is driven with posted / sent window messages. Rows that need real input are
    reported NOT DRIVEN (group ND).
.PARAMETER Exe       tandemcommander.exe of a Debug build with the feature
.PARAMETER Only      group names to run (wildcards allowed), e.g. -Only A1,E*  (default: all)
.PARAMETER Sc1Runs   number of starts of the SC-001 loop (default 20)
.PARAMETER FreqRuns  number of starts of the SC-003 / SC-004 loops (default 20)
.PARAMETER TimeRuns  number of starts per variant of the SC-002 timing row (default 8)
.PARAMETER OldExe    a program version without the feature (row J); default: the installed copy
.PARAMETER Result    result file (default: updcheck_result.txt beside the probe)
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Only = @(),
    [int]$Sc1Runs = 20,
    [int]$FreqRuns = 20,
    [int]$TimeRuns = 8,
    [string]$OldExe = 'C:\Program Files\Tandem Commander\tandemcommander.exe',
    [string]$Result = '',
    [int]$MaxMinutes = 80
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not $Result) { $Result = Join-Path $PSScriptRoot 'updcheck_result.txt' }
if ($Only.Count -eq 1 -and $Only[0] -match ',') { $Only = @($Only[0] -split ',') }
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Write-Host 'NOT RUN: a tandemcommander.exe is running (the registry key is shared with it)'; exit 99 }
if (-not ('P123' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
public static class P123
{
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct GUITHREADINFO { public int cbSize; public int flags; public IntPtr hwndActive, hwndFocus, hwndCapture, hwndMenuOwner, hwndMoveSize, hwndCaret; public RECT rcCaret; }
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr GetPropW(IntPtr h, string name);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] public static extern int GetWindowLong(IntPtr h, int idx);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool GetGUIThreadInfo(uint tid, ref GUITHREADINFO g);
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)] static extern int RegCreateKeyExW(IntPtr root, string sub, int res, string cls, int opt, int sam, IntPtr sa, out IntPtr key, out int disp);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)] static extern int RegSetValueExW(IntPtr key, string name, int res, int type, byte[] data, int size);
    [DllImport("advapi32.dll")] static extern int RegCloseKey(IntPtr key);
    [DllImport("user32.dll")] public static extern bool EnableWindow(IntPtr h, bool enable);
    [DllImport("user32.dll")] static extern IntPtr GetThreadDesktop(uint tid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool GetUserObjectInformationW(IntPtr h, int index, System.Text.StringBuilder info, int length, out int needed);
    // the name of the desktop a process's threads are attached to ("" while no thread has one)
    public static string DesktopOf(int pid)
    {
        try
        {
            foreach (System.Diagnostics.ProcessThread t in System.Diagnostics.Process.GetProcessById(pid).Threads)
            {
                IntPtr d = GetThreadDesktop((uint)t.Id);
                if (d == IntPtr.Zero) continue;
                var sb = new System.Text.StringBuilder(256); int needed;
                if (GetUserObjectInformationW(d, 2, sb, 512, out needed) && sb.Length > 0) return sb.ToString();
            }
        }
        catch { }
        return "";
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr LoadLibraryExW(string file, IntPtr res, uint flags);
    [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int LoadStringW(IntPtr h, uint id, System.Text.StringBuilder sb, int max);
    // strings of a language module, read from the built file (data file load, nothing is executed)
    public static string[] LoadStrings(string file, int[] ids)
    {
        var res = new string[ids.Length];
        IntPtr h = LoadLibraryExW(file, IntPtr.Zero, 2);
        if (h == IntPtr.Zero) return null;
        try { for (int i = 0; i < ids.Length; i++) { var sb = new System.Text.StringBuilder(4000); int n = LoadStringW(h, (uint)ids[i], sb, 4000); res[i] = n > 0 ? sb.ToString() : null; } }
        finally { FreeLibrary(h); }
        return res;
    }
    // long.MinValue = the message was not answered in time
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout)
    {
        IntPtr res;
        if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out res) == IntPtr.Zero) return long.MinValue;
        return res.ToInt64();
    }
    // every visible top-level window of this desktop that carries the notification property
    public static List<IntPtr> Notices()
    {
        var l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { if (IsWindowVisible(h) && GetPropW(h, "TandemCommander.UpdateNotice") != IntPtr.Zero) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    // direct children in z-order = the dialog's tab order
    public static List<IntPtr> ChildOrder(IntPtr dlg)
    {
        var l = new List<IntPtr>();
        IntPtr c = GetWindow(dlg, 5);
        while (c != IntPtr.Zero && l.Count < 500) { l.Add(c); c = GetWindow(c, 2); }
        return l;
    }
    public static IntPtr FocusOf(IntPtr h)
    {
        uint pid; uint tid = GetWindowThreadProcessId(h, out pid);
        var g = new GUITHREADINFO(); g.cbSize = Marshal.SizeOf(typeof(GUITHREADINFO));
        if (!GetGUIThreadInfo(tid, ref g)) return IntPtr.Zero;
        return g.hwndFocus;
    }
    public static IntPtr ActiveOf(IntPtr h)
    {
        uint pid; uint tid = GetWindowThreadProcessId(h, out pid);
        var g = new GUITHREADINFO(); g.cbSize = Marshal.SizeOf(typeof(GUITHREADINFO));
        if (!GetGUIThreadInfo(tid, ref g)) return IntPtr.Zero;
        return g.hwndActive;
    }
    public static bool Capture(IntPtr h, string file)
    {
        RECT r; if (!GetWindowRect(h, out r)) return false;
        int w = r.R - r.L, hh = r.B - r.T; if (w <= 0 || hh <= 0) return false;
        using (var bmp = new Bitmap(w, hh))
        {
            bool ok;
            using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); ok = PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
            bmp.Save(file, System.Drawing.Imaging.ImageFormat.Png);
            return ok;
        }
    }
    // a registry value with any type and any bytes (garbage rows); HKEY_CURRENT_USER
    public static int RegSetRaw(string sub, string name, int type, byte[] data)
    {
        IntPtr key; int disp;
        int e = RegCreateKeyExW(new IntPtr(unchecked((int)0x80000001)), sub, 0, null, 0, 0x20006, IntPtr.Zero, out key, out disp);
        if (e != 0) return e;
        e = RegSetValueExW(key, name, 0, type, data, data.Length);
        RegCloseKey(key);
        return e;
    }
}
'@
}
$UiaOk = $false
try { Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; $UiaOk = $true } catch { }
# ---- constants ----------------------------------------------------------------
$Z = [IntPtr]::Zero
$UcPath = 'Software\Tandem Commander\0.1\Update Check'
$CfgPath = 'Software\Tandem Commander\0.1\Configuration'
$HKCU = [Microsoft.Win32.Registry]::CurrentUser
$Work = Join-Path $env:TEMP 'tc123_probe'
$ShotDir = Join-Path $PSScriptRoot 'shots'
$SrvLog = Join-Path $Work 'requests.log'
$OpenLog = Join-Path $Work 'opened.log'
$RegFile = Join-Path $Work 'reg_backup.reg'
$NoticeProp = 'TandemCommander.UpdateNotice'
$InstUrl = 'https://github.com/tandemcommander/tandemcommander/releases/download/v{0}/tandemcommander-{0}-x64-setup.exe'
$NotesUrl = 'https://github.com/tandemcommander/tandemcommander/releases/tag/v{0}'
$TitleAns = 'Check for New Version'
$KnownNames = @('Check At Startup', 'Last Attempt', 'Last Attempt Answered', 'Last Success', 'Latest Version', 'Latest Published', 'Skipped Version')
[void][IO.Directory]::CreateDirectory($Work)
[void][IO.Directory]::CreateDirectory($ShotDir)
[void][IO.Directory]::CreateDirectory($StartDir)
function T([string]$Case, [string]$Step, [bool]$Ok, [string]$Facts) { Row $Case $Step (V $Ok) $Facts }
function ND([string]$Case, [string]$Step, [string]$Facts) { Row $Case $Step 'NOT DRIVEN' $Facts }
function Info([string]$Case, [string]$Step, [string]$Facts) { Out ('{0,-10} {1,-6} {2,-11} {3}' -f $Case, $Step, 'note', $Facts) }
function Norm([string]$s) { if ($null -eq $s) { return '' }; return (($s -replace '\s+', ' ').Trim()) }
function S2([double]$x) { return $x.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture) }
# ---- free ports, fixture server ----------------------------------------------------
function Free-Port { $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0); $l.Start(); $p = $l.LocalEndpoint.Port; $l.Stop(); return $p }
$Port = Free-Port
$DeadPort = Free-Port
while ($DeadPort -eq $Port) { $DeadPort = Free-Port }
$script:Srv = $null
function Http-Get([string]$Path) {
    $wc = New-Object Net.WebClient; $wc.Proxy = $null
    try { [void]$wc.DownloadString("http://127.0.0.1:$Port$Path"); return $true } catch { return $false } finally { $wc.Dispose() }
}
function Start-Server {
    Remove-Item -LiteralPath $SrvLog -Force -ErrorAction SilentlyContinue
    $script:Srv = Start-Process -FilePath python -ArgumentList @(('"{0}"' -f (Join-Path $PSScriptRoot 'updserver.py')), '--port', $Port, '--log', ('"{0}"' -f $SrvLog)) -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) { if (Http-Get '/control/set/same') { return }; Start-Sleep -Milliseconds 200 }
    throw 'the fixture server did not start'
}
function Stop-Server { if ($script:Srv -and -not $script:Srv.HasExited) { [void](Http-Get '/stop'); Start-Sleep -Milliseconds 400; if (-not $script:Srv.HasExited) { Stop-Process -Id $script:Srv.Id -Force } } }
function Dyn([string]$Fixture) { if (-not (Http-Get "/control/set/$Fixture")) { throw "the fixture server did not accept /control/set/$Fixture" } }
# the version requests logged so far (objects: method, path, version, headers)
function Reqs {
    $o = @()
    if (Test-Path -LiteralPath $SrvLog) {
        foreach ($line in @(Get-Content -LiteralPath $SrvLog)) { if ($line) { $j = $line | ConvertFrom-Json; if ($j.path -like '/latest/*') { $o += $j } } }
    }
    return , $o
}
function Ends {
    $o = @()
    if (Test-Path -LiteralPath $SrvLog) { foreach ($line in @(Get-Content -LiteralPath $SrvLog)) { if ($line) { $j = $line | ConvertFrom-Json; if ($j.path -like '/end/*') { $o += $j } } } }
    return , $o
}
# how long the server saw the last connection for $Fixture stay open (seconds), or 'still open'
function Conn-Sec([string]$Fixture, [int]$EndsBefore) {
    $e = Ends
    for ($i = $e.Count - 1; $i -ge $EndsBefore; $i--) { if ($e[$i].path -eq ('/end/' + $Fixture)) { return [double]$e[$i].seconds } }
    return -1.0
}
function Req-Count { return (Reqs).Count }
function Wait-Req([int]$Count, [double]$Seconds) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if ((Req-Count) -ge $Count) { return $true }; Start-Sleep -Milliseconds 100 }; return $false }
function Hdrs($Req) { return (@($Req.headers | ForEach-Object { $_[0] + ': ' + $_[1] }) -join ' | ') }
# ---- environment (the Debug seams) ---------------------------------------------------
function Set-Env([string]$Fixture, [string]$Pretend = '0.1.8') {
    if ($Fixture -eq 'DEAD') { $env:TC_UPDATECHECK_URL = "http://127.0.0.1:$DeadPort/latest/newer" }
    else { $env:TC_UPDATECHECK_URL = "http://127.0.0.1:$Port/latest/$Fixture" }
    $env:TC_UPDATECHECK_PRETEND_VERSION = $Pretend
    $env:TC_UPDATECHECK_OPENLOG = $OpenLog
}
function Clear-Env { Remove-Item Env:\TC_UPDATECHECK_URL, Env:\TC_UPDATECHECK_PRETEND_VERSION, Env:\TC_UPDATECHECK_OPENLOG -ErrorAction SilentlyContinue }
function Opened { if (Test-Path -LiteralPath $OpenLog) { return , @(Get-Content -LiteralPath $OpenLog | Where-Object { $_ }) }; return , @() }
function Clear-Opened { Remove-Item -LiteralPath $OpenLog -Force -ErrorAction SilentlyContinue }
# ---- stored state --------------------------------------------------------------------
function Uc-Clear { $HKCU.DeleteSubKeyTree($UcPath, $false) }
function Uc-Set([string]$Name, $Value, [string]$Kind) {
    $k = $HKCU.CreateSubKey($UcPath)
    try { if ($Kind -eq 'QWord') { $k.SetValue($Name, [long]$Value, [Microsoft.Win32.RegistryValueKind]::QWord) } elseif ($Kind -eq 'DWord') { $k.SetValue($Name, [int]$Value, [Microsoft.Win32.RegistryValueKind]::DWord) } else { $k.SetValue($Name, [string]$Value, [Microsoft.Win32.RegistryValueKind]::String) } } finally { $k.Close() }
}
function Uc-Del([string]$Name) { $k = $HKCU.OpenSubKey($UcPath, $true); if ($k) { try { $k.DeleteValue($Name, $false) } finally { $k.Close() } } }
function Uc-Get {
    $h = [ordered]@{}
    $k = $HKCU.OpenSubKey($UcPath)
    if (-not $k) { return $h }
    try {
        foreach ($n in @($k.GetValueNames() | Sort-Object)) {
            $kind = $k.GetValueKind($n)
            $v = $k.GetValue($n, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($v -is [byte[]]) { $v = 'hex ' + (($v | Select-Object -First 24 | ForEach-Object { $_.ToString('X2') }) -join '') }
            elseif ($v -is [string] -and $v.Length -gt 60) { $v = $v.Substring(0, 60) + '...(' + $v.Length + ' chars)' }
            $h[$n] = ('{0}:{1}' -f $kind, $v)
        }
    }
    finally { $k.Close() }
    return $h
}
function Uc-Str($h = $null) { if ($null -eq $h) { $h = Uc-Get }; if (-not $h.Count) { return '(no values)' }; return (@($h.Keys | ForEach-Object { $_ + '=' + $h[$_] }) -join '; ') }
function Uc-V([string]$Name) { $h = Uc-Get; if ($h.Contains($Name)) { return $h[$Name] }; return '<absent>' }
function Knowledge($h = $null) { if ($null -eq $h) { $h = Uc-Get }; return ('{0} | {1} | {2}' -f $h['Latest Version'], $h['Latest Published'], $h['Last Success']) }
function FtAt([double]$HoursFromNow) { return [DateTime]::UtcNow.AddHours($HoursFromNow).ToFileTimeUtc() }
function Uc-Age([string]$Name) {   # seconds since the stored FILETIME (negative = future), $null when not a QWORD
    $k = $HKCU.OpenSubKey($UcPath); if (-not $k) { return $null }
    try { if (@($k.GetValueNames()) -notcontains $Name) { return $null }; if ($k.GetValueKind($Name) -ne [Microsoft.Win32.RegistryValueKind]::QWord) { return $null }; $v = [long]$k.GetValue($Name); return ([DateTime]::UtcNow - [DateTime]::FromFileTimeUtc($v)).TotalSeconds } catch { return $null } finally { $k.Close() }
}
# what a start-up check that failed must leave alone
function Seed-Knowledge {
    Uc-Clear
    Uc-Set 'Latest Version' '0.1.9' 'String'
    Uc-Set 'Latest Published' '2026-10-14T08:00:00Z' 'String'
    Uc-Set 'Last Success' (FtAt -72) 'QWord'
    Uc-Set 'Last Attempt' (FtAt -48) 'QWord'
    Uc-Set 'Last Attempt Answered' 1 'DWord'
}
function Cfg-Set([string]$Name, [int]$Value) { $k = $HKCU.OpenSubKey($CfgPath, $true); if ($k) { try { $k.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::DWord) } finally { $k.Close() } } }
function Cfg-SetStr([string]$Name, [string]$Value) { $k = $HKCU.OpenSubKey($CfgPath, $true); if ($k) { try { $k.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::String) } finally { $k.Close() } } }
function Cfg-Get([string]$Name) { $k = $HKCU.OpenSubKey($CfgPath); if (-not $k) { return $null }; try { return $k.GetValue($Name, $null) } finally { $k.Close() } }
$script:OrigTheme = '?'
function Reset-Base {
    Set-Config
    if ($script:OrigTheme -eq '?') { $script:OrigTheme = Cfg-Get 'Theme Mode' }
    if ($null -ne $script:OrigTheme) { Cfg-Set 'Theme Mode' ([int]$script:OrigTheme) } else { $k = $HKCU.OpenSubKey($CfgPath, $true); if ($k) { $k.DeleteValue('Theme Mode', $false); $k.Close() } }
    Cfg-Set 'Only One Instance' 0
    Cfg-Set 'Last Focused Page' 0
    Uc-Clear
    Clear-Opened
}
# ---- process and windows -----------------------------------------------------------
function Start-Raw([string]$Path = $Exe, [string]$Title = 'T123') {
    $a = @('-t', $Title, '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Path -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    return $p
}
# starts the program and returns as soon as its main window is visible; Sw runs from that moment
function Start-Fast([string]$Path = $Exe) {
    $sw0 = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Raw $Path
    while ($sw0.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq $Z) { Start-Sleep -Milliseconds 25 }
    $main = Get-Main $p.Id
    if ($main -eq $Z) { throw 'the program did not show its main window in 60 s' }
    return [pscustomobject]@{ Id = $p.Id; Sw = [Diagnostics.Stopwatch]::StartNew(); TMain = $sw0.Elapsed.TotalSeconds; Main = $main }
}
function Alive-Main([int]$Id) { return ([P123]::SendR((Get-Main $Id), 0, 0, 0, 5000) -ne [long]::MinValue) }
function Other-Wins([int]$Id) { return , @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass }) }
function Is-Notice([IntPtr]$H) { return ([P123]::GetPropW($H, $NoticeProp) -ne $Z) }
function Get-Notice([int]$Id) { foreach ($h in (Get-Tops $Id)) { if (Is-Notice $h) { return $h } }; return $Z }
function Wait-Notice([int]$Id, [double]$Seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) { $h = Get-Notice $Id; if ($h -ne $Z) { return $h }; Start-Sleep -Milliseconds 40 }
    return $Z
}
function Ctl([IntPtr]$Dlg, [int]$CtlId) { foreach ($k in [Drv098f]::Kids($Dlg)) { if ([Drv098f]::GetDlgCtrlID($k) -eq $CtlId) { return $k } }; return $Z }
function CtlText([IntPtr]$Dlg, [int]$CtlId) { $c = Ctl $Dlg $CtlId; if ($c -eq $Z) { return '<no control>' }; return [Drv098f]::GetText($c, 3000) }
function Checked([IntPtr]$Dlg, [int]$CtlId) { $c = Ctl $Dlg $CtlId; if ($c -eq $Z) { return $null }; return ([P123]::SendR($c, 0x00F0, 0, 0, 3000) -eq 1) }
function AllText([IntPtr]$H) { $parts = @(); foreach ($c in [Drv098f]::Kids($H)) { $t = [Drv098f]::Txt($c); if ($t -and [Drv098f]::IsWindowVisible($c) -and [Drv098f]::Cls($c) -ne 'Button') { $parts += $t } }; return (Norm ($parts -join ' ')) }
function BtnText([IntPtr]$H) { return (@(Buttons $H | ForEach-Object { '[' + [Drv098f]::GetDlgCtrlID($_) + ' ' + [Drv098f]::Txt($_) + ']' }) -join '') }
function Kind([IntPtr]$H) {
    if (Is-Notice $H) { return 'notice' }
    if ((Ctl $H 6252) -ne $Z) { return 'wait' }
    if ((Ctl $H 6253) -ne $Z) { return 'about' }
    if ([Drv098f]::Txt($H) -eq $TitleAns) { return 'msg' }
    if ($script:AnyDialogIsMsg -and [Drv098f]::Cls($H) -eq '#32770') { return 'msg' }
    return ('other[' + [Drv098f]::Cls($H) + '](' + [Drv098f]::Txt($H) + ')')
}
function Desc([IntPtr]$H) { return ("{0} '{1}' text '{2}' buttons {3}" -f (Kind $H), (Esc ([Drv098f]::Txt($H))), (Esc (AllText $H)), (Esc (BtnText $H))) }
function Gone([IntPtr]$H, [double]$Seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if (-not [Drv098f]::IsWindow($H) -or -not [Drv098f]::IsWindowVisible($H)) { return $true }; Start-Sleep -Milliseconds 30 }
    return (-not [Drv098f]::IsWindow($H) -or -not [Drv098f]::IsWindowVisible($H))
}
# presses a button that is expected to close its dialog: posted BM_CLICK; when the window stays, WM_COMMAND
function Press-Close([IntPtr]$Dlg, [int]$CtlId, [double]$Seconds = 2) {
    $b = Ctl $Dlg $CtlId
    if ($b -eq $Z) { return [pscustomobject]@{ How = 'no control ' + $CtlId; Gone = $false; Sec = 0 } }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Click $b
    if (Gone $Dlg $Seconds) { return [pscustomobject]@{ How = 'BM_CLICK'; Gone = $true; Sec = $sw.Elapsed.TotalSeconds } }
    Post-Cmd $Dlg $CtlId
    $g = Gone $Dlg $Seconds
    return [pscustomobject]@{ How = 'WM_COMMAND (a posted BM_CLICK had no effect)'; Gone = $g; Sec = $sw.Elapsed.TotalSeconds }
}
function Send-Key([IntPtr]$H, [int]$Vk) { [void][Drv098f]::Send($H, 0x0100, $Vk, 1, 3000); [void][Drv098f]::Send($H, 0x0101, $Vk, 0xC0000001, 3000) }
function Post-Key([IntPtr]$H, [int]$Vk) { [void][Drv098f]::PostMessageW($H, 0x0100, [IntPtr]$Vk, [IntPtr]1); [void][Drv098f]::PostMessageW($H, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L) }
function Uia([IntPtr]$H) {
    if (-not $UiaOk -or $H -eq $Z) { return '<no uia>' }
    try { $e = [Windows.Automation.AutomationElement]::FromHandle($H); return ('{0}|{1}' -f $e.Current.Name, $e.Current.ControlType.ProgrammaticName.Replace('ControlType.', '')) } catch { return ('<uia failed: ' + $_.Exception.Message + '>') }
}
# Is the text of control $CtlId cut at its right edge? Looks at the capture $Name of window $H: text-coloured
# (non-background) pixels in the last two pixel columns of the control mean the text runs out of it.
function Clip-Right([IntPtr]$H, [int]$CtlId, [string]$Name) {
    try {
        $c = Ctl $H $CtlId
        $rw = New-Object P123+RECT; [void][P123]::GetWindowRect($H, [ref]$rw)
        $rc = New-Object P123+RECT; [void][P123]::GetWindowRect($c, [ref]$rc)
        $bmp = New-Object Drawing.Bitmap((Join-Path $ShotDir $Name))
        try {
            $x1 = $rc.R - $rw.L - 1; $y0 = $rc.T - $rw.T; $y1 = $rc.B - $rw.T
            $bg = $bmp.GetPixel(($rc.L - $rw.L + 1), ($y0 + 1))
            $hits = 0
            for ($x = $x1 - 1; $x -le $x1; $x++) { for ($y = $y0; $y -lt $y1; $y++) { $px = $bmp.GetPixel($x, $y); if ([Math]::Abs($px.R - $bg.R) + [Math]::Abs($px.G - $bg.G) + [Math]::Abs($px.B - $bg.B) -gt 90) { $hits++ } } }
            return ($(if ($hits -gt 0) { 'CLIPPED' } else { 'fits' }) + ' (' + $hits + ' text pixels in the last 2 columns of a ' + ($rc.R - $rc.L) + ' px wide control)')
        }
        finally { $bmp.Dispose() }
    }
    catch { return ('not measured: ' + $_.Exception.Message) }
}
function Shot([IntPtr]$H, [string]$Name) { $f = Join-Path $ShotDir $Name; try { $ok = [P123]::Capture($H, $f); return ('shot ' + $Name + ' ' + $ok) } catch { return ('shot ' + $Name + ' failed: ' + $_.Exception.Message) } }
function TabOrder([IntPtr]$Dlg) { $ids = @(); foreach ($c in [P123]::ChildOrder($Dlg)) { $st = [P123]::GetWindowLong($c, -16); if (($st -band 0x00010000) -and ($st -band 0x10000000)) { $ids += [Drv098f]::GetDlgCtrlID($c) } }; return , $ids }
# watches the instance: every window (except the main one and $Allowed) seen during $Seconds
function Watch-Wins([int]$Id, [double]$Seconds, $Allowed = @()) {
    $seen = @{}; $out = @()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        foreach ($h in (Other-Wins $Id)) { if ($Allowed -contains $h) { continue }; $key = $h.ToInt64(); if (-not $seen.ContainsKey($key)) { $seen[$key] = 1; Start-Sleep -Milliseconds 150; $out += ((S2 $sw.Elapsed.TotalSeconds) + ' s: ' + (Desc $h)) } }
        Start-Sleep -Milliseconds 120
    }
    return , $out
}
function Close-Any([IntPtr]$H) {
    if (-not [Drv098f]::IsWindow($H)) { return }
    if (Is-Notice $H) { [void][Drv098f]::PostMessageW($H, 0x0010, $Z, $Z); [void](Gone $H 2); return }
    $b = Buttons $H | Where-Object { @(1, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
    if ($b) { Click $b; if (Gone $H 1.5) { return } }
    Close-Win $H
}
function Close-Others([int]$Id) { for ($i = 0; $i -lt 6; $i++) { $w = Other-Wins $Id; if (-not $w.Count) { return }; Close-Any $w[$w.Count - 1]; Start-Sleep -Milliseconds 200 } }
# closes the program with WM_CLOSE to the main window; reports seconds, exit code, windows met on the way
function Quit([int]$Id, [double]$Max = 20) {
    $r = [pscustomobject]@{ Sec = 0.0; Code = '?'; Stray = @(); Killed = $false }
    if (-not (Test-Alive $Id)) { $r.Code = ExitCodeOf $Id; return $r }
    $main = Get-Main $Id
    $sw = [Diagnostics.Stopwatch]::StartNew()
    [void][Drv098f]::PostMessageW($main, 0x0010, $Z, $Z)
    $seen = @{}
    while ($sw.Elapsed.TotalSeconds -lt $Max -and (Test-Alive $Id)) {
        if ($sw.Elapsed.TotalSeconds -gt 1.0) {
            foreach ($h in (Other-Wins $Id)) {
                if (Is-Notice $h) { continue }
                $key = $h.ToInt64(); if (-not $seen.ContainsKey($key)) { $seen[$key] = 1; $r.Stray += (Desc $h) }
                $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b }
            }
        }
        Start-Sleep -Milliseconds 40
    }
    $r.Sec = $sw.Elapsed.TotalSeconds
    if (Test-Alive $Id) { Kill-Mine $Id; $r.Killed = $true; $r.Code = 'killed by the probe after ' + $Max + ' s' } else { $r.Code = ExitCodeOf $Id }
    return $r
}
function QStr($q) { return ('exit {0} s, code {1}{2}' -f (S2 $q.Sec), $q.Code, $(if ($q.Stray.Count) { '; windows at exit: ' + ($q.Stray -join ' || ') } else { '' })) }
function QOk($q, [double]$Limit = 4.0) { return ($q.Code -eq '0x00000000' -and -not $q.Killed -and $q.Stray.Count -eq 0 -and $q.Sec -le $Limit) }
function Quit-All { foreach ($i in @($Started)) { if (Test-Alive $i) { Close-Others $i; [void](Quit $i) } } }
# Help > Check for New Version (WM_COMMAND 2217 to the main window). Returns the first new window
# that is not the wait dialog (or the wait dialog itself with -StopAtWait).
function Manual-Check([int]$Id, [double]$Seconds = 22, [switch]$StopAtWait, [IntPtr]$Target = [IntPtr]::Zero) {
    $known = Other-Wins $Id
    $r = [pscustomobject]@{ Kind = 'none'; H = $Z; T = -1.0; WaitT = -1.0; WaitH = $Z; WaitGone = -1.0; Text = ''; Sw = $null }
    $sw = [Diagnostics.Stopwatch]::StartNew(); $r.Sw = $sw
    if ($Target -ne $Z) { [void][Drv098f]::Send($Target, 0x0100, 0x20, 1, 3000) } else { Post-Cmd (Get-Main $Id) 2217 }
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        foreach ($h in (Other-Wins $Id)) {
            if ($known -contains $h) { continue }
            $k = Kind $h
            if ($k -eq 'wait') {
                if ($r.WaitT -lt 0) { $r.WaitT = $sw.Elapsed.TotalSeconds; $r.WaitH = $h; if ($StopAtWait) { $r.Kind = 'wait'; $r.H = $h; $r.T = $r.WaitT; return $r } }
                continue
            }
            $r.Kind = $k; $r.H = $h; $r.T = $sw.Elapsed.TotalSeconds
            Start-Sleep -Milliseconds 200
            $r.Text = AllText $h
            return $r
        }
        Start-Sleep -Milliseconds 30
    }
    return $r
}
function MStr($r) { return ("answer '{0}' after {1} s{2}: '{3}' {4}" -f $r.Kind, (S2 $r.T), $(if ($r.WaitT -ge 0) { ' (wait dialog at ' + (S2 $r.WaitT) + ' s)' } else { ' (no wait dialog)' }), (Esc $r.Text), $(if ($r.H -ne $Z) { 'buttons ' + (Esc (BtnText $r.H)) } else { '' })) }
function Answer([IntPtr]$H) { if ($H -eq $Z) { return }; $p = Press-Close $H 1 2; if (-not $p.Gone) { Close-Win $H } }
function Open-About([int]$Id) {
    $h = Open-ByCmd $Id 2216 8
    if ($h -eq $Z -or (Kind $h) -ne 'about') { throw ('the About dialog did not open: ' + $(if ($h -ne $Z) { Desc $h } else { 'no window' })) }
    Start-Sleep -Milliseconds 300
    return $h
}
function LinkText([IntPtr]$Link) { $t = [Drv098f]::GetText($Link, 3000); if ($t) { return $t }; $u = Uia $Link; return ('<window text empty; UIA ' + $u + '>') }
function About-Line([IntPtr]$H) {
    $link = Ctl $H 6254
    $vis = ($link -ne $Z -and [Drv098f]::IsWindowVisible($link))
    return [pscustomobject]@{ Text = (Norm (CtlText $H 6253)); LinkVisible = $vis; Link = $(if ($vis) { LinkText $link } else { '' }); LinkH = $link }
}
function AStr($a) { return ("line '{0}' link {1}" -f (Esc $a.Text), $(if ($a.LinkVisible) { "'" + (Esc $a.Link) + "'" } else { 'hidden' })) }
function Open-Config([int]$Id) {
    $h = Open-ByCmd $Id 686 10
    if ($h -eq $Z) { throw 'the Configuration dialog did not open' }
    Start-Sleep -Milliseconds 500
    return $h
}
function Cfg-Box([IntPtr]$Dlg) { foreach ($k in [Drv098f]::Kids($Dlg)) { if ([Drv098f]::GetDlgCtrlID($k) -eq 6255 -and [Drv098f]::Cls($k) -eq 'Button') { return $k } }; return $Z }
function Box-Checked([IntPtr]$Box) { return ([P123]::SendR($Box, 0x00F0, 0, 0, 3000) -eq 1) }
# toggles an auto check box: posted BM_CLICK; when the state stays, BM_SETCHECK + the BN_CLICKED notification
function Toggle([IntPtr]$Box) {
    $before = Box-Checked $Box
    Click $Box
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 1.5) { if ((Box-Checked $Box) -ne $before) { return 'BM_CLICK' }; Start-Sleep -Milliseconds 50 }
    [void][P123]::SendR($Box, 0x00F1, $(if ($before) { 0 } else { 1 }), 0, 3000)
    [void][P123]::SendR([Drv098f]::GetParent($Box), 0x0111, [Drv098f]::GetDlgCtrlID($Box), $Box.ToInt64(), 3000)
    return 'BM_SETCHECK + WM_COMMAND (a posted BM_CLICK had no effect)'
}
function Cfg-Close([IntPtr]$Dlg, [int]$BtnId) {   # 1 = OK (the dialog's own OK button, whatever its id), 2 = Cancel
    $b = $null
    if ($BtnId -eq 1) { $b = Buttons $Dlg | Where-Object { ([Drv098f]::Txt($_) -eq 'OK' -or [Drv098f]::GetDlgCtrlID($_) -eq 5) -and [Drv098f]::GetParent($_) -eq $Dlg } | Select-Object -First 1 }
    else { $b = Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $BtnId -and [Drv098f]::GetParent($_) -eq $Dlg } | Select-Object -First 1 }
    if (-not $b) { throw ('the Configuration dialog has no button for ' + $BtnId + ': ' + (BtnText $Dlg)) }
    $cid = [Drv098f]::GetDlgCtrlID($b)
    Click $b
    if (-not (Gone $Dlg 4)) { Post-Cmd $Dlg $cid; if (-not (Gone $Dlg 4)) { throw 'the Configuration dialog did not close' } }
    Start-Sleep -Milliseconds 300
}
function Notice-Vers([IntPtr]$N) { return ('{0} -> {1}' -f (CtlText $N 6242), (CtlText $N 6245)) }
$script:AnyDialogIsMsg = $false   # language rows: the answers' title is translated
# posts a left click at client x,y of a control (the lib's Post-Click) and reports the control's size
function Ctl-Size([IntPtr]$C) { $r = New-Object P123+RECT; [void][P123]::GetWindowRect($C, [ref]$r); return @(($r.R - $r.L), ($r.B - $r.T)) }
function Not-In-Notice([IntPtr]$N, [IntPtr]$F) { return ($F -ne $N -and ($F -eq $Z -or [Drv098f]::GetParent($F) -ne $N)) }
# the text of a control is cut? right edge (last 2 columns) or bottom edge (last row) of the control in a capture
function Clip-Ctl([IntPtr]$H, [IntPtr]$C, [string]$File) {
    try {
        $rw = New-Object P123+RECT; [void][P123]::GetWindowRect($H, [ref]$rw)
        $rc = New-Object P123+RECT; [void][P123]::GetWindowRect($C, [ref]$rc)
        $bmp = New-Object Drawing.Bitmap($File)
        try {
            $x0 = $rc.L - $rw.L; $x1 = $rc.R - $rw.L - 1; $y0 = $rc.T - $rw.T; $y1 = $rc.B - $rw.T - 1
            if ($x1 -ge $bmp.Width -or $y1 -ge $bmp.Height -or $x0 -lt 0 -or $y0 -lt 0) { return 'outside the capture' }
            $bg = $bmp.GetPixel($x1, $y0)
            $right = 0; $bottom = 0
            for ($x = $x1 - 1; $x -le $x1; $x++) { for ($y = $y0; $y -le $y1; $y++) { $px = $bmp.GetPixel($x, $y); if ([Math]::Abs($px.R - $bg.R) + [Math]::Abs($px.G - $bg.G) + [Math]::Abs($px.B - $bg.B) -gt 90) { $right++ } } }
            for ($x = $x0; $x -le $x1; $x++) { $px = $bmp.GetPixel($x, $y1); if ([Math]::Abs($px.R - $bg.R) + [Math]::Abs($px.G - $bg.G) + [Math]::Abs($px.B - $bg.B) -gt 90) { $bottom++ } }
            if ($right -gt 0) { return ('CUT right ' + $right) }
            return 'fits'
        }
        finally { $bmp.Dispose() }
    }
    catch { return ('not measured: ' + $_.Exception.Message) }
}
$MeasureFont = New-Object Drawing.Font('MS Shell Dlg', 8)
# approximate width of a caption in the dialog font against the width of its button / check box
function Fit-Button([IntPtr]$C, [int]$Reserve) {
    $t = ([Drv098f]::GetText($C, 3000)) -replace '&', ''
    $w = [Windows.Forms.TextRenderer]::MeasureText($t, $MeasureFont).Width
    $have = (Ctl-Size $C)[0] - $Reserve
    return [pscustomobject]@{ Text = $t; Need = $w; Have = $have; Ok = ($w -le $have) }
}
# a word-wrapped static: the height its text needs in the dialog font against the height it has (approximation)
function Fit-Wrap([IntPtr]$C) {
    $t = [Drv098f]::GetText($C, 3000)
    $sz = Ctl-Size $C
    $need = [Windows.Forms.TextRenderer]::MeasureText($t, $MeasureFont, (New-Object Drawing.Size($sz[0], 0)), [Windows.Forms.TextFormatFlags]::WordBreak).Height
    return [pscustomobject]@{ Need = $need; Have = $sz[1]; Ok = ($need -le $sz[1] + 2) }
}
# ---- groups ---------------------------------------------------------------------------
$Groups = [ordered]@{}
$script:BaseQuit = 2.0
# BASE: the option off - how long start and exit take when the feature does nothing
$Groups['BASE'] = {
    Uc-Set 'Check At Startup' 0 'DWord'
    Set-Env 'same'
    $tm = @(); $tq = @(); $codes = @()
    for ($i = 0; $i -lt 3; $i++) {
        $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 2500
        $stray = Other-Wins $s.Id
        if ($stray.Count) { Info 'BASE' 'start' ('windows at start-up that are not part of the feature: ' + (@($stray | ForEach-Object { Desc $_ }) -join ' || ')); Close-Others $s.Id }
        $q = Quit $s.Id; $tm += $s.TMain; $tq += $q.Sec; $codes += $q.Code
    }
    $script:BaseQuit = ($tq | Measure-Object -Maximum).Maximum
    T 'BASE' 'exit' (@($codes | Where-Object { $_ -ne '0x00000000' }).Count -eq 0) ('option off, 3 starts: main window after {0} s; exit takes {1} s; exit codes {2}' -f ((@($tm | ForEach-Object { S2 $_ })) -join '/'), ((@($tq | ForEach-Object { S2 $_ })) -join '/'), ($codes -join '/'))
}
# A1: the start-up notification (US1-1, FR-012..FR-015, contracts/ui.md 1)
$Groups['A1'] = {
    Set-Env 'newer-0.1.9'
    $m0 = Req-Count
    $s = Start-Fast
    $n = Wait-Notice $s.Id 15
    $t = $s.Sw.Elapsed.TotalSeconds
    if ($n -eq $Z) { T 'A1' 'shown' $false ('no notification within 15 s of the main window; windows: ' + (@((Other-Wins $s.Id) | ForEach-Object { Desc $_ }) -join ' || ') + '; state ' + (Uc-Str)); return }
    T 'A1' 'shown' ($t -le 10) ('notification {0} s after the main window became visible (main window {1} s after the process start); SC-001 limit 10 s' -f (S2 $t), (S2 $s.TMain))
    Start-Sleep -Milliseconds 700
    $owner = [P123]::GetWindow($n, 4)
    $en = [Drv098f]::IsWindowEnabled($s.Main); $resp = Alive-Main $s.Id
    T 'A1' 'usable' ($en -and $resp -and $owner -eq $s.Main) ('main window enabled {0}, answers WM_NULL {1}, the notification is owned by the main window {2} (modeless)' -f $en, $resp, ($owner -eq $s.Main))
    $inst = CtlText $n 6242; $new = CtlText $n 6245; $rel = CtlText $n 6246; $title = CtlText $n 6238
    $loc = [DateTime]::Parse('2026-10-14T08:00:00Z', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal).ToLocalTime()
    $relOk = ($rel -match '^Released ') -and ($rel -match ('\b' + $loc.Day + '\b')) -and ($rel -match '2026')
    T 'A1' 'text' ($inst -eq '0.1.8' -and $new -eq '0.1.9' -and $relOk -and $title -eq 'A new version is available') ("caption '{0}'; heading '{1}'; installed '{2}' (label '{3}'); available '{4}' (label '{5}'); released '{6}' (expected the local date of 2026-10-14T08:00Z = day {7}); hint '{8}'" -f (Esc ([Drv098f]::Txt($n))), $title, $inst, (CtlText $n 6241), $new, (CtlText $n 6244), (Esc $rel), $loc.Day, (Esc (CtlText $n 6248)))
    $bt = @{}; foreach ($i in 1, 2, 6250, 6249) { $bt[$i] = CtlText $n $i }
    $order = TabOrder $n
    $defStyle = ([P123]::GetWindowLong((Ctl $n 1), -16) -band 0xF)
    $defId = ([P123]::SendR($n, 0x0400, 0, 0, 3000) -band 0xFFFF)
    $link = Ctl $n 6247
    $ctlOk = ($bt[1] -eq '&Download' -and $bt[2] -eq 'Remind Me &Later' -and $bt[6250] -eq '&Skip This Version' -and $bt[6249] -eq '&Check for a new version at start-up' -and $link -ne $Z -and [Drv098f]::IsWindowVisible($link))
    T 'A1' 'ctls' $ctlOk ("buttons '{0}' '{1}' '{2}'; check box '{3}' checked {4}; link control 6247 present {5}" -f $bt[1], $bt[2], $bt[6250], $bt[6249], (Checked $n 6249), ($link -ne $Z))
    T 'A1' 'tab' ((($order -join ',') -eq '1,2,6250,6249,6247') -and $defId -eq 1) ('tab order (visible WS_TABSTOP children in z-order) {0}; contract: Download(1), Remind Me Later(2), Skip(6250), check box(6249), link(6247); default button id {1} (button style {2})' -f ($order -join ','), $defId, $defStyle)
    $names = @{}; foreach ($i in 1, 2, 6250, 6249, 6247, 6242, 6245, 6246) { $names[$i] = Uia (Ctl $n $i) }
    $linkName = ($names[6247] -split '\|')[0]
    $linkWt = [Drv098f]::GetText($link, 3000)
    # UI Automation on the hidden desktop returns ControlType Pane for every control (also the buttons), so it is
    # not a faithful screen-reader view; the verdict uses WM_GETTEXT (what the standard MSAA proxies read)
    $prevInst = ''; $prevNew = ''; $ord = @([P123]::ChildOrder($n))
    for ($i = 1; $i -lt $ord.Count; $i++) { $cid = [Drv098f]::GetDlgCtrlID($ord[$i]); if ($cid -eq 6242) { $prevInst = [Drv098f]::GetText($ord[$i - 1], 3000) }; if ($cid -eq 6245) { $prevNew = [Drv098f]::GetText($ord[$i - 1], 3000) } }
    T 'A1' 'names' ($linkWt -eq 'Release notes' -and $prevInst -eq 'Installed version' -and $prevNew -eq 'Available version') ("names by WM_GETTEXT: link '{0}' (GetWindowText without the message: '{1}'); the static before '0.1.8' is '{2}', before '0.1.9' is '{3}' (contract: accessible names 'Installed version: 0.1.8' / 'Available version: 0.1.9' - here two separate statics each). UI Automation (Name|ControlType, unreliable on the hidden desktop): Download '{4}', link '{5}', installed '{6}', available '{7}'" -f (Esc $linkWt), (Esc ([Drv098f]::Txt($link))), $prevInst, $prevNew, $names[1], (Esc $names[6247]), $names[6242], $names[6245])
    $h = Uc-Get
    $extra = @($h.Keys | Where-Object { $KnownNames -notcontains $_ })
    $aLs = Uc-Age 'Last Success'; $aLa = Uc-Age 'Last Attempt'
    $stOk = ($h['Latest Version'] -eq 'String:0.1.9' -and $h['Latest Published'] -eq 'String:2026-10-14T08:00:00Z' -and $h['Last Attempt Answered'] -eq 'DWord:1' -and $null -ne $aLs -and $aLs -ge 0 -and $aLs -lt 60 -and $null -ne $aLa -and $aLa -ge 0 -and $aLa -lt 60 -and -not $extra.Count -and -not $h.Contains('Skipped Version'))
    T 'A1' 'state' $stOk ('stored: {0}; Last Attempt {1} s old, Last Success {2} s old; values outside the contract: {3}' -f (Uc-Str $h), (S2 $aLa), (S2 $aLs), $(if ($extra.Count) { $extra -join ',' } else { 'none' }))
    $cu = [P123]::GetPropW($n, 'TandemCommander.ClosesUnattended')
    T 'A1' 'props' ($cu -ne $Z) ('window property TandemCommander.UpdateNotice set; TandemCommander.ClosesUnattended set {0}' -f ($cu -ne $Z))
    T 'A1' 'req' (((Req-Count) - $m0) -eq 1) ('version requests of this start: {0}; nothing opened: {1}' -f ((Req-Count) - $m0), ((Opened).Count -eq 0))
    Info 'A1' 'shot' (Shot $n 'notice_0.1.9.png')
    $actM = [P123]::ActiveOf($s.Main); $focM = [P123]::FocusOf($s.Main)
    T 'A1' 'nofoc' ($actM -eq $s.Main -and (Not-In-Notice $n $focM)) ('start-up notification: active window of the program''s GUI thread is the main window {0} (is the notification {1}); the keyboard focus is inside the notification {2} (focus window class {3}, id {4})' -f ($actM -eq $s.Main), ($actM -eq $n), (-not (Not-In-Notice $n $focM)), $(if ($focM -ne $Z) { [Drv098f]::Cls($focM) } else { 'none' }), $(if ($focM -ne $Z) { [Drv098f]::GetDlgCtrlID($focM) } else { '-' }))
    Info 'A1' 'focus' ('thread focus window id {0}, active window is the notification {1} (hidden desktop: no foreground window)' -f [Drv098f]::GetDlgCtrlID([P123]::FocusOf($n)), ([P123]::ActiveOf($n) -eq $n))
    [void][Drv098f]::PostMessageW($n, 0x0010, $Z, $Z); [void](Gone $n 2)
    $q = Quit $s.Id
    T 'A1' 'exit' (QOk $q) (QStr $q)
}
# A1X: SC-001 - 20 of 20 starts show the notification within 10 s; the program is closed with it open
$Groups['A1X'] = {
    Set-Env 'newer-0.1.9'
    $ts = @(); $bad = @(); $qbad = @(); $qs = @()
    for ($i = 1; $i -le $Sc1Runs; $i++) {
        Uc-Clear
        $s = Start-Fast
        $n = Wait-Notice $s.Id 15
        $t = $s.Sw.Elapsed.TotalSeconds
        if ($n -eq $Z) { $bad += "run $i none in 15 s" } else { $ts += $t; if ($t -gt 10) { $bad += ("run $i " + (S2 $t) + ' s') } }
        Start-Sleep -Milliseconds 300
        $q = Quit $s.Id   # with the notification open (contracts/ui.md 1, Showing 5)
        $qs += $q.Sec
        if (-not (QOk $q)) { $qbad += ("run $i " + (QStr $q)) }
    }
    $mm = $ts | Measure-Object -Minimum -Maximum -Average
    T 'A1X' 'sc001' ($bad.Count -eq 0 -and $ts.Count -eq $Sc1Runs) ('{0} of {1} starts showed the notification within 10 s; seconds after the main window: min {2} / avg {3} / max {4}{5}' -f ($ts.Count - @($bad | Where-Object { $_ -notmatch 'none' }).Count), $Sc1Runs, (S2 $mm.Minimum), (S2 $mm.Average), (S2 $mm.Maximum), $(if ($bad.Count) { '; ' + ($bad -join '; ') } else { '' }))
    $qm = $qs | Measure-Object -Minimum -Maximum
    T 'A1X' 'close' ($qbad.Count -eq 0) ('program closed {0} times with the notification open: exit {1}..{2} s, all exit code 0 and nothing left on screen: {3}{4}' -f $Sc1Runs, (S2 $qm.Minimum), (S2 $qm.Maximum), ($qbad.Count -eq 0), $(if ($qbad.Count) { '; ' + ($qbad -join ' ;; ') } else { '' }))
}
# A2: equal or lower version -> nothing shown, knowledge stored (US1-6, FR-003, edge "installed newer")
$Groups['A2'] = {
    $cases = @(@('same', '0.1.8', '0.1.8'), @('older', '0.1.8', '0.0.1'), @('newer-0.1.9', '0.1.9', '0.1.9'), @('newer-0.1.9', '0.1.10', '0.1.9'), @('ver-0.2.0', '0.10.0', '0.2.0'), @('ver-0.9.99999', '1.0.0', '0.9.99999'))
    foreach ($c in $cases) {
        Uc-Clear; Clear-Opened; Set-Env $c[0] $c[1]
        $m0 = Req-Count
        $s = Start-Fast
        [void](Wait-Req ($m0 + 1) 8)
        $w = Watch-Wins $s.Id 3
        $h = Uc-Get
        $about = ''
        $aOk = $true
        if ($c[0] -eq 'same') { $a = Open-About $s.Id; $al = About-Line $a; $about = '; About: ' + (AStr $al); $aOk = ($al.Text -match '^This is the latest version \(checked .+\)\.$' -and -not $al.LinkVisible); Close-Any $a }
        $q = Quit $s.Id
        $ok = ($w.Count -eq 0 -and ((Req-Count) - $m0) -eq 1 -and $h['Latest Version'] -eq ('String:' + $c[2]) -and $h['Last Attempt Answered'] -eq 'DWord:1' -and $h.Contains('Last Success') -and (Opened).Count -eq 0 -and $aOk -and (QOk $q))
        T 'A2' ($c[0] + '/' + $c[1]) $ok ('release {0}, installed {1}: windows shown: {2}; requests {3}; stored {4}{5}; {6}' -f $c[2], $c[1], $(if ($w.Count) { $w -join ' || ' } else { 'none' }), ((Req-Count) - $m0), (Uc-Str $h), $about, (QStr $q))
    }
}
# A4: valid answers in unusual shapes and the product's version order -> notification (FR-001..FR-003)
$Groups['A4'] = {
    $cases = @(@('ver-0.1.10', '0.1.9', '0.1.10'), @('ver-0.10.0', '0.9.5', '0.10.0'), @('ver-1.0.0', '0.99999.99999', '1.0.0'), @('two-assets', '0.1.8', '9.9.9'), @('nested-tag-first', '0.1.8', '9.9.9'), @('chunked', '0.1.8', '9.9.9'), @('slow-ok', '0.1.8', '9.9.9'), @('ver-10.12.345', '9.20.1234', '10.12.345'), @('ver-99999.99999.99999', '0.1.8', '99999.99999.99999'), @('bom', '0.1.8', '9.9.9'))
    $clipLong = 'not measured'; $clipMid = 'not measured'
    foreach ($c in $cases) {
        Uc-Clear; Clear-Opened; Set-Env $c[0] $c[1]
        $s = Start-Fast
        $n = Wait-Notice $s.Id 12
        $t = $s.Sw.Elapsed.TotalSeconds
        $v = ''; $shot = ''
        if ($n -ne $Z) {
            Start-Sleep -Milliseconds 400; $v = Notice-Vers $n
            if ($c[0] -eq 'ver-99999.99999.99999') { $shot = '; ' + (Shot $n 'notice_longest_version.png'); $clipLong = Clip-Right $n 6245 'notice_longest_version.png' }
            if ($c[0] -eq 'ver-10.12.345') { $shot = '; ' + (Shot $n 'notice_10.12.345.png'); $clipMid = (Clip-Right $n 6245 'notice_10.12.345.png') + ' / installed: ' + (Clip-Right $n 6242 'notice_10.12.345.png') }
            $p = Press-Close $n 1 2   # Download: the address is built from the validated numbers
        }
        $op = Opened
        $q = Quit $s.Id
        if ($c[0] -eq 'ver-99999.99999.99999') { T 'A4' 'clip' ($clipLong -notmatch 'CLIPPED' -and $clipMid -notmatch 'CLIPPED') ('the two version numbers must not be cut off (contracts/ui.md 1: nothing clipped; a version part has up to 5 digits): 9.20.1234 -> 10.12.345: available ' + $clipMid + '; 99999.99999.99999: ' + $clipLong) }
        if ($c[0] -eq 'bom') { Info 'A4' 'bom' ('a record preceded by a UTF-8 byte order mark (no requirement either way): notification {0}; stored {1}' -f ($n -ne $Z), (Uc-Str)); continue }
        $ok = ($n -ne $Z -and $v -eq ($c[1] + ' -> ' + $c[2]) -and $op.Count -eq 1 -and $op[0] -eq ($InstUrl -f $c[2]) -and (QOk $q))
        T 'A4' ($c[0] + '/' + $c[1]) $ok ('notification {0} after {1} s showing {2}; Download opened: {3}; {4}{5}' -f ($n -ne $Z), (S2 $t), $v, $(if ($op.Count) { $op -join ' , ' } else { 'nothing' }), (QStr $q), $shot)
    }
}
# A3: every failing answer at start-up -> nothing shown, knowledge kept, nothing opened, exit not delayed
# (US1-7, FR-002, FR-004, FR-009, SC-007, SC-008, edge cases)
$Groups['A3'] = {
    # fixture, seconds to watch after the request, expected "Last Attempt Answered" (1 = an HTTP status was received)
    $cases = @(
        @('prerelease', 2.5, 1), @('draft', 2.5, 1), @('noasset', 2.5, 1), @('asset-not-uploaded', 2.5, 1), @('foreign-url', 2.5, 1), @('foreign-html-url', 2.5, 1),
        @('bad-tag', 2.5, 1), @('dup-tag', 2.5, 1), @('oversized', 3.5, 1), @('truncated', 2.5, 1), @('short-body', 4, 1), @('html', 2.5, 1), @('empty', 2.5, 1),
        @('403', 2.5, 1), @('429', 2.5, 1), @('500', 2.5, 1), @('404', 2.5, 1), @('redirect', 3, 1), @('auth401', 3, 1),
        @('ver-0.01.9', 2.5, 1), @('zero-tag', 2.5, 1), @('ver-0.1.100000', 2.5, 1), @('bad-date', 2.5, 1), @('wrong-asset-name', 2.5, 1), @('deep-nesting', 2.5, 1), @('array', 2.5, 1),
        @('hang', 11, 0), @('slow', 14.5, 1), @('DEAD', 7, 0))
    $ansBad = @(); $conn = @{}; $connOk = @{}
    foreach ($c in $cases) {
        $f = $c[0]
        Seed-Knowledge; Clear-Opened; Set-Env $f
        $k0 = Knowledge; $m0 = Req-Count; $e0 = (Ends).Count
        $s = Start-Fast
        $got = $true; if ($f -ne 'DEAD') { $got = Wait-Req ($m0 + 1) 8 }
        $w = @(); $w += (Watch-Wins $s.Id $c[1])
        $h = Uc-Get; $k1 = Knowledge $h
        $alive = Alive-Main $s.Id
        if ($f -eq 'hang' -or $f -eq 'slow') {
            $limit = $(if ($f -eq 'hang') { 20 } else { 45 })
            while ($s.Sw.Elapsed.TotalSeconds -lt $limit -and (Conn-Sec $f $e0) -lt 0) { $w += (Watch-Wins $s.Id 1) }
        }
        if ($f -eq 'hang' -or $f -eq 'slow') { $cs = Conn-Sec $f $e0; $conn[$f] = $(if ($cs -lt 0) { 'still open after ' + (S2 $s.Sw.Elapsed.TotalSeconds) + ' s' } else { (S2 $cs) + ' s' }); $connOk[$f] = ($cs -ge 0 -and $cs -le 12.6) }
        $h = Uc-Get; $k1 = Knowledge $h
        $rq = (Req-Count) - $m0
        $op = Opened
        $q = Quit $s.Id
        $wantReq = $(if ($f -eq 'DEAD') { 0 } else { 1 })
        $claim = Uc-Age 'Last Attempt'
        $ok = ($w.Count -eq 0 -and $k0 -eq $k1 -and $op.Count -eq 0 -and $rq -eq $wantReq -and $alive -and (QOk $q ($script:BaseQuit + 1.5)) -and -not $h.Contains('Skipped Version'))
        T 'A3' $f $ok ('windows shown: {0}; knowledge unchanged {1} ({2}); requests {3}; opened {4}; Last Attempt {5} s old, Answered {6}; {7}' -f $(if ($w.Count) { $w -join ' || ' } else { 'none' }), ($k0 -eq $k1), $k1, $rq, $op.Count, (S2 $claim), $h['Last Attempt Answered'], (QStr $q))
        if ($h['Last Attempt Answered'] -ne ('DWord:' + $c[2])) { $ansBad += ('{0}: {1} (an HTTP status was {2})' -f $f, $h['Last Attempt Answered'], $(if ($c[2]) { 'received' } else { 'not received' })) }
    }
    T 'A3' 'deadln' ($connOk['hang'] -and $connOk['slow']) ('how long the automatic request stayed connected, seen by the server (contracts/update-source.md: receive 8 s, whole request 12 s): never answering server: {0}; server sending 1 byte per 50 ms: {1}' -f $conn['hang'], $conn['slow'])
    T 'A3' 'answrd' ($ansBad.Count -eq 0) ("'Last Attempt Answered' must be 1 exactly when the attempt received an HTTP status (contracts/stored-state.md): " + $(if ($ansBad.Count) { 'differs for ' + ($ansBad -join '; ') } else { 'as specified for all ' + $cases.Count + ' fixtures' }))
}
# B: what is sent (FR-006, contracts/update-source.md "Request")
$Groups['B'] = {
    Set-Env 'same'
    $m0 = Req-Count
    $s = Start-Fast
    [void](Wait-Req ($m0 + 1) 8); Start-Sleep -Milliseconds 800
    $r = Reqs
    $auto = $null; if ($r.Count -gt $m0) { $auto = $r[$m0] }
    if ($null -eq $auto) { T 'B' 'hdrs' $false 'no request arrived'; [void](Quit $s.Id); return }
    $names = @($auto.headers | ForEach-Object { $_[0].ToLower() })
    $hv = @{}; foreach ($x in $auto.headers) { $hv[$x[0].ToLower()] = $x[1] }
    $allowed = @('host', 'user-agent', 'accept', 'x-github-api-version', 'connection')
    $unknown = @($names | Where-Object { $allowed -notcontains $_ })
    $ok = ($auto.method -eq 'GET' -and $auto.version -eq 'HTTP/1.1' -and $auto.path -eq '/latest/same' -and $hv['user-agent'] -eq 'TandemCommander-updatecheck' -and $hv['accept'] -eq 'application/vnd.github+json' -and $hv['x-github-api-version'] -eq '2022-11-28' -and $unknown.Count -eq 0)
    T 'B' 'hdrs' $ok ('{0} {1} {2}; headers: {3}; headers outside the contract (Connection is transport): {4}' -f $auto.method, $auto.path, $auto.version, (Hdrs $auto), $(if ($unknown.Count) { $unknown -join ',' } else { 'none' }))
    T 'B' 'ua' ($hv['user-agent'] -notmatch '\d') ("User-Agent '{0}' carries no version or other number" -f $hv['user-agent'])
    # the manual check sends the same request, twice in one process: no cookie comes back
    [void](Quit $s.Id)
    Uc-Clear; Set-Env 'dyn'; Dyn 'setcookie'
    $m1 = Req-Count
    $s = Start-Fast
    [void](Wait-Req ($m1 + 1) 8); Start-Sleep -Milliseconds 800
    $a1 = Manual-Check $s.Id; Answer $a1.H
    $a2 = Manual-Check $s.Id; Answer $a2.H
    [void](Quit $s.Id)
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    $a3 = Manual-Check $s.Id; Answer $a3.H
    [void](Quit $s.Id)
    $r = Reqs
    $mine = @($r | Select-Object -Skip $m1)
    $cook = @($mine | Where-Object { @($_.headers | ForEach-Object { $_[0].ToLower() }) -contains 'cookie' })
    $sets = @($mine | ForEach-Object { (@($_.headers | ForEach-Object { $_[0].ToLower() } | Sort-Object)) -join ',' } | Select-Object -Unique)
    T 'B' 'cookie' ($mine.Count -eq 4 -and $cook.Count -eq 0) ('the server sets a cookie with every answer; {0} requests followed (1 automatic + 2 manual in one process, 1 manual in a new process): requests carrying Cookie: {1}' -f $mine.Count, $cook.Count)
    T 'B' 'manual' ($sets.Count -eq 1) ('automatic and manual requests carry the same header names (nothing tells them apart): {0}' -f ($sets -join ' ## '))
    foreach ($f in 'auth401', 'redirect') {
        Uc-Clear; Set-Env $f
        $m2 = Req-Count
        $s = Start-Fast
        [void](Wait-Req ($m2 + 1) 8); Start-Sleep -Milliseconds 3500
        [void](Quit $s.Id)
        $mine = @((Reqs) | Select-Object -Skip $m2)
        $auth = @($mine | Where-Object { @($_.headers | ForEach-Object { $_[0].ToLower() }) -match 'authorization' })
        T 'B' $f ($mine.Count -eq 1 -and $auth.Count -eq 0) ('requests after the {0} answer: {1} ({2}); with Authorization / Proxy-Authorization: {3}' -f $f, $mine.Count, (@($mine | ForEach-Object { $_.path }) -join ','), $auth.Count)
    }
}
# C1: option off -> no request at all, winhttp.dll never loaded (FR-011, SC-003, US4-2)
$Groups['C1'] = {
    Uc-Set 'Check At Startup' 0 'DWord'
    Set-Env 'newer-0.1.9'
    $m0 = Req-Count; $st0 = Uc-Str
    $wins = @(); $mod = '?'
    for ($i = 1; $i -le $FreqRuns; $i++) {
        $s = Start-Fast; [void](Alive-Main $s.Id)
        $w = Watch-Wins $s.Id 3
        if ($w.Count) { $wins += ("run $i " + ($w -join ' || ')); Close-Others $s.Id }
        if ($i -eq 1) { try { $mod = [bool](@((Get-Process -Id $s.Id).Modules | Where-Object { $_.ModuleName -ieq 'winhttp.dll' }).Count) } catch { $mod = 'unreadable' } }
        [void](Quit $s.Id)
    }
    T 'C1' 'sc003' (((Req-Count) - $m0) -eq 0 -and $wins.Count -eq 0 -and (Uc-Str) -eq $st0) ('option off, {0} starts with a newer release published: requests {1}; windows {2}; stored state unchanged {3} ({4})' -f $FreqRuns, ((Req-Count) - $m0), $(if ($wins.Count) { $wins -join ' ;; ' } else { 'none' }), ((Uc-Str) -eq $st0), (Uc-Str))
    T 'C1' 'dll' ($mod -eq $false) ('winhttp.dll loaded in the process with the option off: {0}' -f $mod)
}
# C2: option on -> one request over many consecutive starts (FR-008, SC-004); Remind Me Later does not repeat within the day
$Groups['C2'] = {
    Set-Env 'newer-0.1.9'
    $m0 = Req-Count
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    $first = ($n -ne $Z)
    $mod = '?'; try { $mod = [bool](@((Get-Process -Id $s.Id).Modules | Where-Object { $_.ModuleName -ieq 'winhttp.dll' }).Count) } catch { $mod = 'unreadable' }
    if ($first) { [void](Press-Close $n 2 2) }
    [void](Quit $s.Id)
    $wins = @()
    for ($i = 2; $i -le $FreqRuns; $i++) {
        $s = Start-Fast; [void](Alive-Main $s.Id)
        $w = Watch-Wins $s.Id 3
        if ($w.Count) { $wins += ("run $i " + ($w -join ' || ')); Close-Others $s.Id }
        [void](Quit $s.Id)
    }
    T 'C2' 'sc004' ($first -and ((Req-Count) - $m0) -eq 1 -and $wins.Count -eq 0) ('option on, {0} consecutive starts: requests {1}; first start showed the notification {2} (closed with Remind Me Later); windows in the later starts: {3}; winhttp.dll loaded in the checking process: {4}' -f $FreqRuns, ((Req-Count) - $m0), $first, $(if ($wins.Count) { $wins -join ' ;; ' } else { 'none' }), $mod)
}
# C3: instances started together -> one request, one notification (FR-008, FR-018, edge "several instances")
$Groups['C3'] = {
    Set-Env 'newer-0.1.9'
    $res = @(); $allOk = $true
    for ($rep = 1; $rep -le 3; $rep++) {
        Uc-Clear
        $m0 = Req-Count
        $p1 = Start-Raw $Exe 'T123a'; $p2 = Start-Raw $Exe 'T123b'; $p3 = Start-Raw $Exe 'T123c'
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and ((Get-Main $p1.Id) -eq $Z -or (Get-Main $p2.Id) -eq $Z -or (Get-Main $p3.Id) -eq $Z)) { Start-Sleep -Milliseconds 50 }
        Start-Sleep -Seconds 8
        $nn = [P123]::Notices().Count; $rq = (Req-Count) - $m0
        $mains = @($p1, $p2, $p3 | Where-Object { (Get-Main $_.Id) -ne $Z }).Count
        if ($nn -ne 1 -or $rq -ne 1 -or $mains -ne 3) { $allOk = $false }
        $res += ("rep $rep" + ': instances ' + $mains + ', requests ' + $rq + ', notifications ' + $nn)
        foreach ($p in $p1, $p2, $p3) { Close-Others $p.Id; [void](Quit $p.Id) }
    }
    T 'C3' 'three' $allOk ('3 instances started at the same moment, 3 repetitions: ' + ($res -join '; '))
}
# C4: a notification is open in instance A; instance B's check is due and finds the release too -> still one
# notification; a manual check in B does not open a second one (FR-018, contracts/ui.md 1 Showing 2 + 4)
$Groups['C4'] = {
    Set-Env 'newer-0.1.9'
    $m0 = Req-Count
    $a = Start-Fast
    $n = Wait-Notice $a.Id 12
    if ($n -eq $Z) { T 'C4' 'setup' $false 'instance A showed no notification'; return }
    Uc-Set 'Last Attempt' (FtAt -25) 'QWord'
    $b = Start-Fast
    [void](Wait-Req ($m0 + 2) 8)
    $wb = Watch-Wins $b.Id 5
    $nn = [P123]::Notices().Count
    T 'C4' 'auto' ($nn -eq 1 -and $wb.Count -eq 0 -and ((Req-Count) - $m0) -eq 2) ('A shows the notification; B started 25 h "later": requests {0} (2 allowed), notifications on the desktop {1}, windows of B: {2}' -f ((Req-Count) - $m0), $nn, $(if ($wb.Count) { $wb -join ' || ' } else { 'none' }))
    Post-Cmd (Get-Main $b.Id) 2217
    [void](Wait-Req ($m0 + 3) 8)
    $wb = Watch-Wins $b.Id 4
    $nn = [P123]::Notices().Count
    T 'C4' 'manual' ($nn -eq 1 -and $wb.Count -eq 0 -and [Drv098f]::IsWindow($n)) ('manual check in B while A shows the notification: requests {0}, notifications {1}, A''s window still there {2}, windows of B: {3} (that A''s window is brought to the front cannot be observed here)' -f ((Req-Count) - $m0), $nn, [Drv098f]::IsWindow($n), $(if ($wb.Count) { $wb -join ' || ' } else { 'none' }))
    Close-Others $b.Id; [void](Quit $b.Id); Close-Others $a.Id; [void](Quit $a.Id)
}
# C5/C6: the throttle rule from stored values (FR-008, data-model "SalUpdAutoCheckDue", edge "clock")
$Groups['C6'] = {
    Set-Env 'same'
    # label, Last Attempt (hours from now or $null), Answered (0/1/$null), expected requests, special
    $cases = @(
        @('future+1y', 8760, 1, 1, ''), @('-2h unanswered', -2, 0, 1, ''), @('-30min unanswered', -0.5, 0, 0, ''), @('-61min no flag', -1.02, $null, 1, ''),
        @('-2h answered', -2, 1, 0, ''), @('-23h answered', -23, 1, 0, ''), @('-25h answered', -25, 1, 1, ''),
        @('attempt=0', $null, 1, 1, 'zero'), @('attempt REG_SZ', $null, 1, 1, 'sz'), @('answered REG_SZ -2h', -2, $null, 1, 'anssz'), @('option REG_SZ "0"', -25, 1, 1, 'optsz'), @('option=0 -25h', -25, 1, 0, 'off'))
    foreach ($c in $cases) {
        Uc-Clear
        if ($null -ne $c[1]) { Uc-Set 'Last Attempt' (FtAt $c[1]) 'QWord' }
        if ($null -ne $c[2]) { Uc-Set 'Last Attempt Answered' $c[2] 'DWord' }
        switch ($c[4]) { 'zero' { Uc-Set 'Last Attempt' 0 'QWord' } 'sz' { Uc-Set 'Last Attempt' 'yesterday' 'String' } 'anssz' { Uc-Set 'Last Attempt Answered' '1' 'String' } 'optsz' { Uc-Set 'Check At Startup' '0' 'String' } 'off' { Uc-Set 'Check At Startup' 0 'DWord' } }
        $before = Uc-Str
        $m0 = Req-Count
        $s = Start-Fast; [void](Alive-Main $s.Id)
        $w = Watch-Wins $s.Id 3.5
        $rq = (Req-Count) - $m0
        $age = Uc-Age 'Last Attempt'
        $claimOk = $true; if ($c[3] -eq 1) { $claimOk = ($null -ne $age -and $age -ge 0 -and $age -lt 60) }
        Close-Others $s.Id; $q = Quit $s.Id
        T 'C6' $c[0] ($rq -eq $c[3] -and $w.Count -eq 0 -and $claimOk) ('before: {0}; requests {1} (expected {2}); after: {3}; windows {4}' -f $before, $rq, $c[3], (Uc-Str), $(if ($w.Count) { $w -join ' || ' } else { 'none' }))
    }
}
# C7: the retry rule end to end: unreachable -> again after 1 h; refused -> another day (data-model Limits, edge "too many requests")
$Groups['C7'] = {
    Set-Env 'DEAD'
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Seconds 6; [void](Quit $s.Id)
    $st = Uc-Str; $ans = Uc-V 'Last Attempt Answered'
    Uc-Set 'Last Attempt' (FtAt -1.02) 'QWord'
    Set-Env 'same'; $m0 = Req-Count
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 3500; [void](Quit $s.Id)
    T 'C7' 'unreach' ($ans -eq 'DWord:0' -and ((Req-Count) - $m0) -eq 1) ('after a start with the server not running: {0}; the next start 61 min later sends {1} request(s) (expected 1)' -f $st, ((Req-Count) - $m0))
    Uc-Clear; Set-Env '403'; $m0 = Req-Count
    $s = Start-Fast; [void](Wait-Req ($m0 + 1) 8); Start-Sleep -Milliseconds 2000; [void](Quit $s.Id)
    $st = Uc-Str; $ans = Uc-V 'Last Attempt Answered'
    Uc-Set 'Last Attempt' (FtAt -1.02) 'QWord'
    Set-Env 'same'; $m1 = Req-Count
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 3500; [void](Quit $s.Id)
    $r1 = (Req-Count) - $m1
    Uc-Set 'Last Attempt' (FtAt -25) 'QWord'; $m2 = Req-Count
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 3500; [void](Quit $s.Id)
    T 'C7' 'refused' ($ans -eq 'DWord:1' -and $r1 -eq 0 -and ((Req-Count) - $m2) -eq 1) ('after a start answered 403: {0}; 61 min later {1} request(s) (expected 0); 25 h later {2} (expected 1)' -f $st, $r1, ((Req-Count) - $m2))
}
# D1/D2: Download and Release notes open exactly the constructed addresses (FR-013, FR-014, SC-005, C15)
$Groups['D1'] = {
    Set-Env 'newer-0.1.9'
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    if ($n -eq $Z) { T 'D1' 'setup' $false 'no notification'; return }
    Start-Sleep -Milliseconds 400
    $st0 = Uc-Str
    $link = Ctl $n 6247
    Send-Key $link 0x20   # Space on the link control
    Start-Sleep -Milliseconds 900
    $op = Opened
    T 'D1' 'notes' ($op.Count -eq 1 -and $op[0] -eq ($NotesUrl -f '0.1.9') -and [Drv098f]::IsWindowVisible($n) -and (Uc-Str) -eq $st0) ('Space key sent to the link control: opened {0}; expected {1}; the notification stays open {2}; stored state unchanged {3}' -f $(if ($op.Count) { $op -join ' , ' } else { 'nothing' }), ($NotesUrl -f '0.1.9'), [Drv098f]::IsWindowVisible($n), ((Uc-Str) -eq $st0))
    Clear-Opened
    Send-Key $link 0x0D   # Enter on the link control
    Start-Sleep -Milliseconds 900
    $op = Opened
    T 'D1' 'notes2' ($op.Count -eq 1 -and $op[0] -eq ($NotesUrl -f '0.1.9') -and [Drv098f]::IsWindowVisible($n)) ('Enter key sent to the link control (contract: "Tab stop, Enter/Space" opens the release notes): opened {0}; the notification stays open {1}' -f $(if ($op.Count) { $op -join ' , ' } else { 'nothing' }), [Drv098f]::IsWindowVisible($n))
    Clear-Opened
    if (-not [Drv098f]::IsWindow($n)) { $n = $Z }
    if ($n -eq $Z) { T 'D1' 'dl' $false 'the notification is gone after the link row'; [void](Quit $s.Id); return }
    $p = Press-Close $n 1 2
    Start-Sleep -Milliseconds 300
    $op = Opened
    T 'D1' 'dl' ($op.Count -eq 1 -and $op[0] -eq ($InstUrl -f '0.1.9') -and $p.Gone -and (Uc-Str) -eq $st0) ('Download ({0}): opened {1}; expected {2}; the notification closed {3}; stored state unchanged {4}' -f $p.How, $(if ($op.Count) { $op -join ' , ' } else { 'nothing' }), ($InstUrl -f '0.1.9'), $p.Gone, ((Uc-Str) -eq $st0))
    $q = Quit $s.Id
    T 'D1' 'exit' (QOk $q) (QStr $q)
}
# D3: Remind Me Later / close button / Esc -> nothing stored, not again today, again after a day (US1-3, FR-016)
$Groups['D3'] = {
    Set-Env 'newer-0.1.9'
    foreach ($how in 'button', 'close', 'esc') {
        Uc-Clear
        $m0 = Req-Count
        $s = Start-Fast
        $n = Wait-Notice $s.Id 12
        if ($n -eq $Z) { T 'D3' $how $false 'no notification'; [void](Quit $s.Id); continue }
        Start-Sleep -Milliseconds 400
        $st0 = Uc-Str
        $via = ''; $gone = $false
        if ($how -eq 'button') { $p = Press-Close $n 2 2; $via = $p.How; $gone = $p.Gone }
        elseif ($how -eq 'close') { [void][Drv098f]::PostMessageW($n, 0x0112, [IntPtr]0xF060, $Z); $gone = Gone $n 2; $via = 'WM_SYSCOMMAND SC_CLOSE (the caption close button)' }
        else {
            # round 2: a start-up notification has no keyboard focus (row A1 nofoc), so Esc is driven on one opened by the command
            [void][Drv098f]::PostMessageW($n, 0x0010, $Z, $Z); [void](Gone $n 2)
            $rm = Manual-Check $s.Id
            if ($rm.Kind -ne 'notice') { T 'D3' $how $false ('no notification from the command: ' + (MStr $rm)); Close-Others $s.Id; [void](Quit $s.Id); continue }
            $n = $rm.H; Start-Sleep -Milliseconds 400; $st0 = Uc-Str
            $fh = [P123]::FocusOf($n); if (Not-In-Notice $n $fh) { $fh = Ctl $n 1 }
            Post-Key $fh 0x1B; $gone = Gone $n 2; $via = 'WM_KEYDOWN VK_ESCAPE posted to the focused control (id ' + [Drv098f]::GetDlgCtrlID($fh) + ') of a notification opened by the command'
        }
        $same = ((Uc-Str) -eq $st0)
        if (-not $gone) { Close-Any $n }
        [void](Quit $s.Id)
        $m1 = Req-Count
        $s = Start-Fast; [void](Alive-Main $s.Id)
        $w = Watch-Wins $s.Id 3.5
        $again0 = (Req-Count) - $m1
        Close-Others $s.Id; [void](Quit $s.Id)
        Uc-Set 'Last Attempt' (FtAt -25) 'QWord'
        $s = Start-Fast
        $n2 = Wait-Notice $s.Id 12
        Close-Others $s.Id; [void](Quit $s.Id)
        T 'D3' $how ($gone -and $same -and $w.Count -eq 0 -and $again0 -eq 0 -and $n2 -ne $Z) ('{0}: the notification closed {1}; stored state unchanged {2} ({3}); restart at once: requests {4}, windows {5}; restart 25 h later: notification again {6}' -f $via, $gone, $same, $st0, $again0, $(if ($w.Count) { $w -join ' || ' } else { 'none' }), ($n2 -ne $Z))
    }
}
# D4: Skip This Version (US1-4, US2-1, US3-4, FR-017, C7)
$Groups['D4'] = {
    Set-Env 'newer-0.1.9'
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    if ($n -eq $Z) { T 'D4' 'setup' $false 'no notification'; return }
    Start-Sleep -Milliseconds 400
    $h0 = Uc-Get
    $p = Press-Close $n 6250 2
    $h1 = Uc-Get
    $others = (@($h0.Keys | Where-Object { $h0[$_] -ne $h1[$_] }).Count -eq 0)
    T 'D4' 'store' ($p.Gone -and $h1['Skipped Version'] -eq 'String:0.1.9' -and $others) ('Skip This Version ({0}): closed {1}; stored {2}; the other values unchanged {3}' -f $p.How, $p.Gone, (Uc-Str $h1), $others)
    [void](Quit $s.Id)
    # the next day: asked again, the same version -> silent
    Uc-Set 'Last Attempt' (FtAt -25) 'QWord'; $m0 = Req-Count
    $s = Start-Fast
    [void](Wait-Req ($m0 + 1) 8)
    $w = Watch-Wins $s.Id 4
    T 'D4' 'silent' ($w.Count -eq 0 -and ((Req-Count) - $m0) -eq 1) ('start 25 h later, same release: requests {0}, windows {1}' -f ((Req-Count) - $m0), $(if ($w.Count) { $w -join ' || ' } else { 'none' }))
    Close-Others $s.Id
    $a = Open-About $s.Id; $al = About-Line $a
    T 'D4' 'about' ($al.Text -eq 'Version 0.1.9 is available.' -and $al.LinkVisible) ('About after the skip: ' + (AStr $al))
    Close-Any $a
    $r = Manual-Check $s.Id
    $v = ''; if ($r.Kind -eq 'notice') { $v = Notice-Vers $r.H }
    T 'D4' 'manual' ($r.Kind -eq 'notice' -and $v -eq '0.1.8 -> 0.1.9') ('manual check after the skip: ' + (MStr $r) + ' versions ' + $v + '; Skipped Version still ' + (Uc-V 'Skipped Version'))
    Close-Others $s.Id; [void](Quit $s.Id)
    # a still newer version is offered
    Uc-Set 'Last Attempt' (FtAt -25) 'QWord'; Set-Env 'ver-0.1.10'
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    $v = ''; if ($n -ne $Z) { Start-Sleep -Milliseconds 300; $v = Notice-Vers $n }
    T 'D4' 'newer' ($n -ne $Z -and $v -eq '0.1.8 -> 0.1.10') ('0.1.9 skipped, 0.1.10 published, start 25 h later: notification {0} showing {1}' -f ($n -ne $Z), $v)
    Close-Others $s.Id; [void](Quit $s.Id)
    # a choice made in one instance holds for instances started later: a second process sees the skip too (registry, read fresh)
    Uc-Set 'Skipped Version' '0.1.10' 'String'; Uc-Set 'Last Attempt' (FtAt -25) 'QWord'
    $s = Start-Fast; [void](Alive-Main $s.Id)
    $w = Watch-Wins $s.Id 4
    T 'D4' 'other' ($w.Count -eq 0) ('Skipped Version written from outside (as another instance would), start 25 h later: windows {0}' -f $(if ($w.Count) { $w -join ' || ' } else { 'none' }))
    Close-Others $s.Id; [void](Quit $s.Id)
}
# D5: the check box of the notification = the option of Configuration > General (US1-5, US4-3, FR-014, FR-025, C9)
$Groups['D5'] = {
    Set-Env 'newer-0.1.9'
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    if ($n -eq $Z) { T 'D5' 'setup' $false 'no notification'; return }
    Start-Sleep -Milliseconds 400
    $box = Ctl $n 6249
    $c0 = Box-Checked $box
    $how = Toggle $box
    Start-Sleep -Milliseconds 300
    $v1 = Uc-V 'Check At Startup'
    T 'D5' 'off' ($c0 -and -not (Box-Checked $box) -and $v1 -eq 'DWord:0' -and [Drv098f]::IsWindowVisible($n)) ('check box was checked {0}; cleared by {1}; stored at once: Check At Startup={2}; the notification stays open {3}' -f $c0, $how, $v1, [Drv098f]::IsWindowVisible($n))
    $cfg = Open-Config $s.Id
    $cb = Cfg-Box $cfg
    $cfgState = $(if ($cb -ne $Z) { Box-Checked $cb } else { $null })
    T 'D5' 'cfg' ($cb -ne $Z -and $cfgState -eq $false) ('Configuration > General opened while the notification is open: check box 6255 present {0}, checked {1} (expected not checked)' -f ($cb -ne $Z), $cfgState)
    Cfg-Close $cfg 2
    [void](Toggle $box); Start-Sleep -Milliseconds 300; $v2 = Uc-V 'Check At Startup'
    [void](Toggle $box); Start-Sleep -Milliseconds 300; $v3 = Uc-V 'Check At Startup'
    T 'D5' 'toggle' ($v2 -eq 'DWord:1' -and $v3 -eq 'DWord:0') ('checked again -> {0}; cleared again -> {1}' -f $v2, $v3)
    # round 2, claim 9: changed in Configuration > General while the notification is open
    $cfg = Open-Config $s.Id; $cb = Cfg-Box $cfg
    [void](Toggle $cb); Cfg-Close $cfg 1; Start-Sleep -Milliseconds 500
    $vCfg = Uc-V 'Check At Startup'
    $b1 = Box-Checked $box; $actAfter = ([P123]::ActiveOf($n) -eq $n)
    [void][P123]::SendR($n, 0x0006, 2, 0, 3000)   # WM_ACTIVATE, WA_CLICKACTIVE: what the window gets when the user clicks it
    Start-Sleep -Milliseconds 200
    $b2 = Box-Checked $box
    T 'D5' 'follow' ($vCfg -eq 'DWord:1' -and ($b1 -or $b2)) ('option turned on in Configuration > General while the notification (unchecked) is open: stored {0}; its check box right after the Configuration dialog closed: checked {1} (the notification is the active window then: {2}); after WM_ACTIVATE sent to it (stands for the user clicking it): checked {3}' -f $vCfg, $b1, $actAfter, $b2)
    Uc-Set 'Check At Startup' 0 'DWord'   # off again for the following rows
    Close-Others $s.Id; [void](Quit $s.Id)
    Uc-Set 'Last Attempt' (FtAt -25) 'QWord'; $m0 = Req-Count
    $w = @()
    for ($i = 0; $i -lt 3; $i++) { $s = Start-Fast; [void](Alive-Main $s.Id); $w += (Watch-Wins $s.Id 3); Close-Others $s.Id; if ($i -lt 2) { [void](Quit $s.Id) } }
    T 'D5' 'later' (((Req-Count) - $m0) -eq 0 -and $w.Count -eq 0) ('3 starts 25 h later with the option cleared in the notification: requests {0}, windows {1}' -f ((Req-Count) - $m0), $(if ($w.Count) { $w -join ' || ' } else { 'none' }))
    # turning it on in the configuration restores the start-up check
    $cfg = Open-Config $s.Id
    $cb = Cfg-Box $cfg
    if ($cb -eq $Z) { T 'D5' 'on' $false 'no check box 6255 on the page'; Cfg-Close $cfg 2; [void](Quit $s.Id); return }
    $how = Toggle $cb
    Cfg-Close $cfg 1
    Start-Sleep -Milliseconds 500
    $v4 = Uc-V 'Check At Startup'
    [void](Quit $s.Id)
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    T 'D5' 'on' ($v4 -eq 'DWord:1' -and $n -ne $Z) ('checked in Configuration > General ({0}) + OK: Check At Startup={1} while the program still runs; next start: notification {2}, requests {3}' -f $how, $v4, ($n -ne $Z), ((Req-Count) - $m0))
    Close-Others $s.Id; [void](Quit $s.Id)
}
# D6: keyboard of the notification through the message loop: Enter = Download, access keys (FR-015, contracts/ui.md 1)
$Groups['D6'] = {
    # a start-up notification takes no focus (row A1 nofoc); the keyboard rows use one opened by the command
    Uc-Set 'Check At Startup' 0 'DWord'
    Set-Env 'newer-0.1.9'
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    $r = Manual-Check $s.Id
    if ($r.Kind -ne 'notice') { T 'D6' 'setup' $false ('no notification from the command: ' + (MStr $r)); return }
    $n = $r.H; Start-Sleep -Milliseconds 400
    $fh = [P123]::FocusOf($n)
    if (Not-In-Notice $n $fh) { ND 'D6' 'enter' 'the notification opened by the command has no keyboard focus on the hidden desktop'; Close-Others $s.Id; [void](Quit $s.Id); return }
    Post-Key $fh 0x0D   # Enter on the focused default button
    $gone = Gone $n 2
    $op = Opened
    T 'D6' 'enter' ($gone -and $op.Count -eq 1 -and $op[0] -eq ($InstUrl -f '0.1.9')) ('Enter posted to the focused control (id {0}) of a notification opened by the command: closed {1}; opened {2}' -f [Drv098f]::GetDlgCtrlID($fh), $gone, $(if ($op.Count) { $op -join ' , ' } else { 'nothing' }))
    Close-Others $s.Id; Clear-Opened
    $r = Manual-Check $s.Id
    if ($r.Kind -ne 'notice') { T 'D6' 'setup2' $false ('no notification: ' + (MStr $r)); return }
    $n = $r.H; Start-Sleep -Milliseconds 400
    $seq = @([Drv098f]::GetDlgCtrlID([P123]::FocusOf($n)))
    for ($i = 0; $i -lt 5; $i++) { $fh = [P123]::FocusOf($n); if ($fh -eq $Z) { break }; Post-Key $fh 0x09; Start-Sleep -Milliseconds 250; $seq += [Drv098f]::GetDlgCtrlID([P123]::FocusOf($n)) }
    T 'D6' 'tabkey' (($seq -join ',') -eq '1,2,6250,6249,6247,1') ('focus sequence with five posted Tab keys: ' + ($seq -join ',') + ' (contract: 1,2,6250,6249,6247 and round)')
    # Enter while the link has the focus: the release notes, not Download; the window stays (claim 4)
    for ($i = 0; $i -lt 6 -and [Drv098f]::GetDlgCtrlID([P123]::FocusOf($n)) -ne 6247; $i++) { Post-Key ([P123]::FocusOf($n)) 0x09; Start-Sleep -Milliseconds 250 }
    $fh = [P123]::FocusOf($n)
    if ([Drv098f]::GetDlgCtrlID($fh) -ne 6247) { ND 'D6' 'lnkent' ('the focus could not be moved to the link with Tab (focus id ' + [Drv098f]::GetDlgCtrlID($fh) + ')') }
    else {
        Clear-Opened
        Post-Key $fh 0x0D
        Start-Sleep -Milliseconds 900
        $op = Opened
        T 'D6' 'lnkent' ($op.Count -eq 1 -and $op[0] -eq ($NotesUrl -f '0.1.9') -and [Drv098f]::IsWindow($n) -and [Drv098f]::IsWindowVisible($n)) ('Enter posted while the Release notes link has the focus: opened {0} (expected only {1}); the notification stays open {2}' -f $(if ($op.Count) { $op -join ' , ' } else { 'nothing' }), ($NotesUrl -f '0.1.9'), ([Drv098f]::IsWindow($n) -and [Drv098f]::IsWindowVisible($n)))
    }
    if (-not [Drv098f]::IsWindow($n)) { Clear-Opened; $r = Manual-Check $s.Id; $n = $r.H; Start-Sleep -Milliseconds 400 }
    Clear-Opened
    # Alt+S = Skip This Version
    [void][Drv098f]::PostMessageW([P123]::FocusOf($n), 0x0106, [IntPtr][int][char]'s', [IntPtr]0x20000001)
    $gone = Gone $n 2
    $sk = Uc-V 'Skipped Version'
    if (-not $gone) { ND 'D6' 'alt-s' ('WM_SYSCHAR "s" posted to the focused control did not act (Skipped Version ' + $sk + ')') }
    else { T 'D6' 'alt-s' ($sk -eq 'String:0.1.9') ('WM_SYSCHAR "s" posted (Alt+S): closed ' + $gone + '; Skipped Version ' + $sk) }
    Close-Others $s.Id; [void](Quit $s.Id)
}
# LK: mouse on the two links (round 2, claim 4). CHyperLink hit-tests with GetMessagePos, i.e. the position of the
# REAL cursor when the message was posted - a posted click carries no position of its own on a hidden desktop.
$Groups['LK'] = {
    Uc-Set 'Check At Startup' 0 'DWord'
    Set-Env 'newer-0.1.9'
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    $r = Manual-Check $s.Id
    if ($r.Kind -ne 'notice') { T 'LK' 'setup' $false ('no notification: ' + (MStr $r)); return }
    $n = $r.H; Start-Sleep -Milliseconds 400
    $link = Ctl $n 6247; $sz = Ctl-Size $link
    $cur = [Windows.Forms.Cursor]::Position
    $rl = New-Object P123+RECT; [void][P123]::GetWindowRect($link, [ref]$rl)
    Clear-Opened
    Post-Click $link ($sz[0] - 4) ([int]($sz[1] / 2)); Start-Sleep -Milliseconds 800
    $e = Opened
    T 'LK' 'n-empty' ($e.Count -eq 0 -and [Drv098f]::IsWindowVisible($n)) ('notification link control {0} x {1} px at screen {2},{3}; WM_LBUTTONDOWN/UP posted at its right end (x {4}): opened {5} address(es) (expected none)' -f $sz[0], $sz[1], $rl.L, $rl.T, ($sz[0] - 4), $e.Count)
    Clear-Opened
    Post-Click $link 6 ([int]($sz[1] / 2)); Start-Sleep -Milliseconds 800
    $e = Opened
    if ($e.Count -eq 0) { ND 'LK' 'n-text' ('WM_LBUTTONDOWN/UP posted on the text (x 6) opened nothing: the control decides by the real cursor position (GetMessagePos; the cursor is at {0},{1} on the user''s desktop), which a posted click cannot set' -f $cur.X, $cur.Y) }
    else { T 'LK' 'n-text' ($e.Count -eq 1 -and $e[0] -eq ($NotesUrl -f '0.1.9')) ('click posted on the text: opened ' + ($e -join ' , ') + ' (' + $e.Count + ' line(s), expected exactly 1)') }
    Close-Others $s.Id
    # About: the Download link
    Uc-Clear; Uc-Set 'Check At Startup' 0 'DWord'; Uc-Set 'Latest Version' '0.1.9' 'String'
    $a = Open-About $s.Id; $al = About-Line $a
    $sz = Ctl-Size $al.LinkH
    Clear-Opened
    Post-Click $al.LinkH ($sz[0] - 2) ([int]($sz[1] / 2)); Start-Sleep -Milliseconds 800
    $e = Opened
    $ra = New-Object P123+RECT; [void][P123]::GetWindowRect($a, [ref]$ra)
    $rl = New-Object P123+RECT; [void][P123]::GetWindowRect($al.LinkH, [ref]$rl)
    T 'LK' 'a-empty' ($e.Count -eq 0 -and [Drv098f]::IsWindowVisible($a)) ("About 'Download' link control {0} x {1} px (the dialog is {2} px wide, the control ends {3} px before its right edge); click posted at its right end: opened {4} address(es) (expected none)" -f $sz[0], $sz[1], ($ra.R - $ra.L), ($ra.R - $rl.R), $e.Count)
    Clear-Opened
    Post-Click $al.LinkH 5 ([int]($sz[1] / 2)); Start-Sleep -Milliseconds 800
    $e = Opened
    if ($e.Count -eq 0) { ND 'LK' 'a-text' 'click posted on the text opened nothing: same reason as row n-text (real cursor position)' }
    else { T 'LK' 'a-text' ($e.Count -eq 1 -and $e[0] -eq ($InstUrl -f '0.1.9')) ('click posted on the text: opened ' + ($e -join ' , ')) }
    # Enter while the link has the focus: the installer address once, About stays open
    Clear-Opened
    $seq = @()
    for ($i = 0; $i -lt 6 -and [Drv098f]::GetDlgCtrlID([P123]::FocusOf($a)) -ne 6254; $i++) { $fh = [P123]::FocusOf($a); if ($fh -eq $Z) { break }; Post-Key $fh 0x09; Start-Sleep -Milliseconds 250; $seq += [Drv098f]::GetDlgCtrlID([P123]::FocusOf($a)) }
    $fh = [P123]::FocusOf($a)
    if ([Drv098f]::GetDlgCtrlID($fh) -ne 6254) { ND 'LK' 'a-enter' ('the focus could not be moved to the About link with Tab (focus ids ' + ($seq -join ',') + ')') }
    else {
        Post-Key $fh 0x0D; Start-Sleep -Milliseconds 900
        $e = Opened
        T 'LK' 'a-enter' ($e.Count -eq 1 -and $e[0] -eq ($InstUrl -f '0.1.9') -and [Drv098f]::IsWindow($a) -and [Drv098f]::IsWindowVisible($a)) ('Enter posted while the About link has the focus (reached with Tab: ' + ($seq -join ',') + '): opened ' + $(if ($e.Count) { $e -join ' , ' } else { 'nothing' }) + '; About stays open ' + ([Drv098f]::IsWindow($a) -and [Drv098f]::IsWindowVisible($a)))
    }
    Close-Others $s.Id; [void](Quit $s.Id)
}
# E1: the manual command, option off: newer / not throttled / up to date / every failure class (US2, FR-019..FR-022, SC-006, C10)
$Groups['E1'] = {
    Uc-Set 'Check At Startup' 0 'DWord'
    Set-Env 'dyn'; Dyn 'newer-0.1.9'
    $m0 = Req-Count
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 2500
    T 'E1' 'quiet' (((Req-Count) - $m0) -eq 0) ('option off: requests before the command: {0}' -f ((Req-Count) - $m0))
    $r = Manual-Check $s.Id
    $v = ''; if ($r.Kind -eq 'notice') { $v = Notice-Vers $r.H }
    $h = Uc-Get
    T 'E1' 'newer' ($r.Kind -eq 'notice' -and $r.T -le 15 -and $v -eq '0.1.8 -> 0.1.9' -and $h['Check At Startup'] -eq 'DWord:0' -and $h['Latest Version'] -eq 'String:0.1.9' -and ((Req-Count) - $m0) -eq 1) ((MStr $r) + '; versions ' + $v + '; requests ' + ((Req-Count) - $m0) + '; stored ' + (Uc-Str $h))
    if ($r.Kind -eq 'notice') { Start-Sleep -Milliseconds 300; $fo = [P123]::FocusOf($r.H); T 'E1' 'activ' ([P123]::ActiveOf($r.H) -eq $r.H -and -not (Not-In-Notice $r.H $fo)) ('notification opened by the command: it is the active window of the GUI thread {0}; focus control id {1} (expected inside it, the Download button)' -f ([P123]::ActiveOf($r.H) -eq $r.H), $(if ($fo -ne $Z) { [Drv098f]::GetDlgCtrlID($fo) } else { 'none' })) }
    if ($r.Kind -eq 'notice') { T 'E1' 'ckbox' ((Checked $r.H 6249) -eq $false) ('the check box of the notification shows the option as it is (off): checked ' + (Checked $r.H 6249)) }
    Close-Others $s.Id
    $r = Manual-Check $s.Id
    T 'E1' 'again' ($r.Kind -eq 'notice' -and ((Req-Count) - $m0) -eq 2) ('the command again at once (not throttled): ' + (MStr $r) + '; requests ' + ((Req-Count) - $m0))
    Close-Others $s.Id
    foreach ($f in 'same', 'older') {
        Dyn $f; $m1 = Req-Count
        $r = Manual-Check $s.Id
        $ok = ($r.Kind -eq 'msg' -and $r.T -le 15 -and $r.Text -eq 'Tandem Commander 0.1.8 is the latest version.' -and ((Req-Count) - $m1) -eq 1)
        if ($f -eq 'same' -and $r.H -ne $Z) { Info 'E1' 'shot' (Shot $r.H 'answer_uptodate.png') }
        T 'E1' $f $ok (MStr $r)
        Answer $r.H
    }
    T 'E1' 'optoff' ((Uc-V 'Check At Startup') -eq 'DWord:0') ('after the manual checks the start-up option is still ' + (Uc-V 'Check At Startup'))
    $k0 = Knowledge
    $refusedRx = '^Could not check for a new version: the release server refused the request\. Too many requests may have come from your network[.;] try again in an hour\.$'
    $unexpRx = '^Could not check for a new version: the release server gave an unexpected answer\. Try again later, or visit tandemcommander\.org\.$'
    $unreachRx = '^Could not check for a new version: the release server could not be reached\. Check your internet connection and try again\.$'
    $shots = @{ '403' = 'answer_refused.png'; 'html' = 'answer_unexpected.png' }
    foreach ($f in '403', '429', '500', '404', 'html', 'empty', 'redirect', 'auth401', 'prerelease', 'draft', 'noasset', 'foreign-url', 'bad-tag', 'zero-tag', 'truncated', 'oversized') {
        Dyn $f; $m1 = Req-Count
        $r = Manual-Check $s.Id
        $rx = $(if ($f -eq '403' -or $f -eq '429') { $refusedRx } else { $unexpRx })
        $k1 = Knowledge
        if ($shots.ContainsKey($f) -and $r.H -ne $Z) { Info 'E1' 'shot' (Shot $r.H $shots[$f]) }
        T 'E1' $f ($r.Kind -eq 'msg' -and $r.T -le 15 -and $r.Text -imatch $rx -and $k1 -eq $k0 -and ((Req-Count) - $m1) -eq 1) ((MStr $r) + '; knowledge unchanged ' + ($k1 -eq $k0) + '; requests ' + ((Req-Count) - $m1))
        Answer $r.H
    }
    Dyn 'short-body'
    $r = Manual-Check $s.Id
    T 'E1' 'shortb' ($r.Kind -eq 'msg' -and $r.T -le 15 -and $r.Text -imatch $unexpRx -and (Knowledge) -eq $k0) ('answer 200 whose body ends before its Content-Length (contract round 2: unexpected): ' + (MStr $r))
    Close-Others $s.Id
    Dyn 'same'; $r = Manual-Check $s.Id; Answer $r.H; $k0 = Knowledge
    # the give-up time (FR-021): a server that accepts and never answers, and one that sends too slowly
    foreach ($f in 'hang', 'slow') {
        Dyn $f
        $r = Manual-Check $s.Id 25
        $ansF = Uc-V 'Last Attempt Answered'
        T 'E1' $f ($r.Kind -eq 'msg' -and $r.T -le 13.0 -and $r.WaitT -ge 0 -and $r.WaitT -le 2 -and $r.Text -imatch $unreachRx -and (Knowledge) -eq $k0 -and $ansF -eq $(if ($f -eq 'slow') { 'DWord:1' } else { 'DWord:0' })) ((MStr $r) + '; the request''s own limit is 12 s (SC-006: 15 s); Last Attempt Answered ' + $ansF + ' (expected ' + $(if ($f -eq 'slow') { '1: a status arrived' } else { '0: nothing answered' }) + ')')
        if ($f -eq 'hang' -and $r.H -ne $Z) { Info 'E1' 'shot' (Shot $r.H 'answer_unreachable.png') }
        Answer $r.H
    }
    Close-Others $s.Id
    $q = Quit $s.Id
    T 'E1' 'exit' (QOk $q) (QStr $q)
}
# E2: the wait dialog and Cancel (US2-4, FR-021, C11)
$Groups['E2'] = {
    Uc-Set 'Check At Startup' 0 'DWord'
    Set-Env 'dyn'; Dyn 'hang'
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 2000
    foreach ($how in 'button', 'esc') {
        $st0 = Knowledge
        $r = Manual-Check $s.Id 10 -StopAtWait
        if ($r.Kind -ne 'wait') { T 'E2' $how $false ('no wait dialog: ' + (MStr $r)); Close-Others $s.Id; continue }
        Start-Sleep -Milliseconds 300
        $txt = CtlText $r.H 6252; $btn = BtnText $r.H; $cap = [Drv098f]::Txt($r.H)
        $mainEn = [Drv098f]::IsWindowEnabled($s.Main); $resp = Alive-Main $s.Id
        if ($how -eq 'button') { Info 'E2' 'shot' (Shot $r.H 'wait_dialog.png') }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $via = ''
        if ($how -eq 'button') { $c = Ctl $r.H 2; Click $c; $via = 'BM_CLICK on Cancel'; if (-not (Gone $r.H 2)) { Post-Cmd $r.H 2; $via = 'WM_COMMAND IDCANCEL (a posted BM_CLICK had no effect)' } }
        else { Post-Key (Ctl $r.H 2) 0x1B; $via = 'WM_KEYDOWN VK_ESCAPE posted to the dialog' }
        $gone = Gone $r.H 3
        $tc = $sw.Elapsed.TotalSeconds
        $w = Watch-Wins $s.Id 3
        $ok = ($r.WaitT -le 2 -and $txt -match '^Checking for a new version' -and $btn -match 'Cancel' -and $gone -and $tc -le 1.5 -and $w.Count -eq 0 -and [Drv098f]::IsWindowEnabled($s.Main) -and (Knowledge) -eq $st0 -and (Uc-V 'Last Attempt Answered') -eq 'DWord:0')
        T 'E2' $how $ok ("wait dialog after {0} s: caption '{1}', text '{2}', buttons {3}; main window enabled meanwhile {4}, answers WM_NULL {5}; {6}: closed {7} after {8} s; windows afterwards: {9}; knowledge unchanged {10}; stored {11}" -f (S2 $r.WaitT), $cap, (Esc $txt), $btn, $mainEn, $resp, $via, $gone, (S2 $tc), $(if ($w.Count) { $w -join ' || ' } else { 'none' }), ((Knowledge) -eq $st0), (Uc-Str))
        Close-Others $s.Id
    }
    # the program is usable after a cancel: the next check works
    Dyn 'same'
    $r = Manual-Check $s.Id
    T 'E2' 'after' ($r.Kind -eq 'msg' -and $r.Text -eq 'Tandem Commander 0.1.8 is the latest version.') ('a check right after the cancelled ones: ' + (MStr $r))
    Answer $r.H
    $q = Quit $s.Id
    T 'E2' 'exit' (QOk $q) (QStr $q)
}
# E3: server not running (US2-3, FR-020)
$Groups['E3'] = {
    Seed-Knowledge; Uc-Set 'Check At Startup' 0 'DWord'
    Set-Env 'DEAD'
    $k0 = Knowledge
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 2000
    $r = Manual-Check $s.Id 25
    T 'E3' 'dead' ($r.Kind -eq 'msg' -and $r.T -le 15 -and $r.Text -imatch '^Could not check for a new version: the release server could not be reached\. Check your internet connection and try again\.$' -and (Knowledge) -eq $k0) ((MStr $r) + '; knowledge unchanged ' + ((Knowledge) -eq $k0) + '; stored ' + (Uc-Str))
    Answer $r.H
    $a = Open-About $s.Id; $al = About-Line $a
    T 'E3' 'about' ($al.Text -eq 'Version 0.1.9 is available.') ('About after the failed check still shows what was known: ' + (AStr $al))
    Close-Any $a
    [void](Quit $s.Id)
}
# E4: the manual command while the automatic check is in flight (data-model: "attaches to it")
$Groups['E4'] = {
    Uc-Set 'Skipped Version' '9.9.9' 'String'
    Set-Env 'slow-ok'
    $m0 = Req-Count
    $s = Start-Fast
    $got = Wait-Req ($m0 + 1) 8
    $r = Manual-Check $s.Id
    Start-Sleep -Milliseconds 1500
    $rq = (Req-Count) - $m0
    $v = ''; if ($r.Kind -eq 'notice') { $v = Notice-Vers $r.H }
    T 'E4' 'join' ($got -and $r.Kind -eq 'notice' -and $v -eq '0.1.8 -> 9.9.9' -and $rq -eq 1 -and [P123]::Notices().Count -eq 1) ('automatic check in flight (answer takes 2 s, its version is skipped), then the command: ' + (MStr $r) + ' versions ' + $v + '; requests ' + $rq + ' (1 = the command joined the running check); notifications ' + [P123]::Notices().Count)
    Close-Others $s.Id; [void](Quit $s.Id)
    Uc-Clear; Set-Env 'hang'
    $m0 = Req-Count
    $s = Start-Fast
    $got = Wait-Req ($m0 + 1) 8
    $r = Manual-Check $s.Id 10 -StopAtWait
    $via = 'no wait dialog'
    if ($r.Kind -eq 'wait') { Start-Sleep -Milliseconds 300; $c = Ctl $r.H 2; Click $c; $via = 'BM_CLICK'; if (-not (Gone $r.H 2)) { Post-Cmd $r.H 2; $via = 'WM_COMMAND' } }
    $gone = ($r.Kind -eq 'wait' -and (Gone $r.H 3))
    $w = Watch-Wins $s.Id 3
    T 'E4' 'cancel' ($got -and $r.Kind -eq 'wait' -and $gone -and $w.Count -eq 0 -and ((Req-Count) - $m0) -eq 1) ('automatic check hanging, then the command: wait dialog {0} at {1} s; Cancel ({2}) closed it {3}; windows afterwards {4}; requests {5}' -f ($r.Kind -eq 'wait'), (S2 $r.WaitT), $via, $gone, $(if ($w.Count) { $w -join ' || ' } else { 'none' }), ((Req-Count) - $m0))
    Close-Others $s.Id
    $q = Quit $s.Id
    T 'E4' 'exit' (QOk $q) (QStr $q)
}
# E5: the command while a notification is already open (contracts/ui.md 1 Showing 4; US2-1 "the new version is shown")
$Groups['E5'] = {
    Set-Env 'dyn'; Dyn 'newer-0.1.9'
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    if ($n -eq $Z) { T 'E5' 'setup' $false 'no notification'; return }
    $m0 = Req-Count
    Post-Cmd $s.Main 2217
    [void](Wait-Req ($m0 + 1) 8)
    $w = Watch-Wins $s.Id 3 @($n)
    T 'E5' 'same' ([P123]::Notices().Count -eq 1 -and $w.Count -eq 0 -and [Drv098f]::IsWindow($n)) ('command with the notification for the same version open: notifications {0}, other windows {1}, requests {2}' -f [P123]::Notices().Count, $(if ($w.Count) { $w -join ' || ' } else { 'none' }), ((Req-Count) - $m0))
    Dyn 'ver-0.1.10'; $m0 = Req-Count
    Post-Cmd $s.Main 2217
    [void](Wait-Req ($m0 + 1) 8)
    $w = Watch-Wins $s.Id 3 @($n)
    $nn = @([P123]::Notices())
    $v = @($nn | ForEach-Object { Notice-Vers $_ }) -join ' ; '
    T 'E5' 'newer' ($nn.Count -eq 1 -and $v -eq '0.1.8 -> 0.1.10') ('0.1.10 published while the notification for 0.1.9 is open, then the command (US2-1: the notification with the new version is shown): notifications {0} showing {1}; stored Latest Version {2}; other windows {3}' -f $nn.Count, $v, (Uc-V 'Latest Version'), $(if ($w.Count) { $w -join ' || ' } else { 'none' }))
    if ($nn.Count -ge 1) {
        Clear-Opened; [void](Press-Close $nn[0] 1 2); Start-Sleep -Milliseconds 300; $op = Opened
        T 'E5' 'dl' ($op.Count -eq 1 -and $op[0] -eq ($InstUrl -f '0.1.10')) ('Download in that window opens {0} (the latest known release is 0.1.10)' -f $(if ($op.Count) { $op -join ' , ' } else { 'nothing' }))
    }
    Close-Others $s.Id; [void](Quit $s.Id)
}
# F1: the About dialog from stored values; opening it sends nothing (US3, FR-023, FR-024, C16)
$Groups['F1'] = {
    Set-Env 'newer-0.1.9'
    $dateRx = '^This is the latest version \(checked .+\)\.$'
    # label, values to store, expected line (regex), link expected (text or ''), shot
    $cases = @(
        @('none', @(), '^Not checked for a new version\.$', 'Check now', 'about_notchecked.png'),
        @('newer', @(@('Latest Version', '0.1.9', 'String'), @('Latest Published', '2026-10-14T08:00:00Z', 'String'), @('Last Success', -3, 'QWord')), '^Version 0\.1\.9 is available\.$', 'Download', 'about_newer.png'),
        @('newer+skip', @(@('Latest Version', '0.1.9', 'String'), @('Skipped Version', '0.1.9', 'String'), @('Last Success', -3, 'QWord')), '^Version 0\.1\.9 is available\.$', 'Download', ''),
        @('equal', @(@('Latest Version', '0.1.8', 'String'), @('Last Success', -3, 'QWord')), $dateRx, '', 'about_latest.png'),
        @('lower', @(@('Latest Version', '0.1.5', 'String'), @('Last Success', -3, 'QWord')), $dateRx, '', ''),
        @('equal nodate', @(, @('Latest Version', '0.1.8', 'String')), '^This is the latest version\.$', '', ''),
        @('equal future', @(@('Latest Version', '0.1.8', 'String'), @('Last Success', 8760, 'QWord')), '^This is the latest version\.$', '', ''),
        @('numeric', @(, @('Latest Version', '0.1.10', 'String')), '^Version 0\.1\.10 is available\.$', 'Download', ''),
        @('bad abc', @(, @('Latest Version', 'abc', 'String')), '^Not checked for a new version\.$', 'Check now', ''),
        @('bad 0.1', @(, @('Latest Version', '0.1', 'String')), '^Not checked for a new version\.$', 'Check now', ''),
        @('bad 0.1.9.1', @(, @('Latest Version', '0.1.9.1', 'String')), '^Not checked for a new version\.$', 'Check now', ''),
        @('bad v0.1.9', @(, @('Latest Version', 'v0.1.9', 'String')), '^Not checked for a new version\.$', 'Check now', ''),
        @('bad space', @(, @('Latest Version', ' 0.1.9', 'String')), '^Not checked for a new version\.$', 'Check now', ''),
        @('bad 6 digits', @(, @('Latest Version', '0.1.123456', 'String')), '^Not checked for a new version\.$', 'Check now', ''),
        @('bad -1', @(, @('Latest Version', '0.1.-9', 'String')), '^Not checked for a new version\.$', 'Check now', ''),
        @('bad huge', @(, @('Latest Version', ('9' * 20000), 'String')), '^Not checked for a new version\.$', 'Check now', ''),
        @('bad dword', @(, @('Latest Version', 19, 'DWord')), '^Not checked for a new version\.$', 'Check now', ''),
        @('raw odd', @(, @('Latest Version', 'RAW', 'odd')), '^Not checked for a new version\.$', 'Check now', ''),
        @('raw expand', @(, @('Latest Version', 'RAW', 'expand')), '^Not checked for a new version\.$', 'Check now', ''),
        @('raw noterm', @(, @('Latest Version', 'RAW', 'noterm')), '^Version 0\.1\.9 is available\.$', 'Download', ''))
    Uc-Set 'Check At Startup' 0 'DWord'
    $m0 = Req-Count
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    foreach ($c in $cases) {
        Uc-Clear; Uc-Set 'Check At Startup' 0 'DWord'
        foreach ($v in $c[1]) {
            if ($v[2] -eq 'QWord') { Uc-Set $v[0] (FtAt ($v[1] * 24)) 'QWord' }
            elseif ($v[2] -eq 'odd') { [void][P123]::RegSetRaw($UcPath, $v[0], 1, [byte[]](0x30, 0x00, 0x2E)) }
            elseif ($v[2] -eq 'expand') { [void][P123]::RegSetRaw($UcPath, $v[0], 2, [Text.Encoding]::Unicode.GetBytes("0.1.9`0")) }
            elseif ($v[2] -eq 'noterm') { [void][P123]::RegSetRaw($UcPath, $v[0], 1, [Text.Encoding]::Unicode.GetBytes('0.1.9')) }
            else { Uc-Set $v[0] $v[1] $v[2] }
        }
        $st = Uc-Str
        if (-not (Test-Alive $s.Id)) { T 'F1' $c[0] $false ('the program is gone (exit code ' + (ExitCodeOf $s.Id) + ') before this case; stored ' + $st); $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500; continue }
        $a = $Z
        try { $a = Open-About $s.Id } catch { T 'F1' $c[0] $false ('About did not open with stored ' + $st + ': ' + $_.Exception.Message + '; alive ' + (Test-Alive $s.Id)); Close-Others $s.Id; continue }
        $al = About-Line $a
        $linkOk = $(if ($c[3]) { $al.LinkVisible -and $al.Link -match [regex]::Escape($c[3]) } else { -not $al.LinkVisible })
        $shot = ''; if ($c[4]) { $shot = '; ' + (Shot $a $c[4]) }
        T 'F1' $c[0] ($al.Text -match $c[2] -and $linkOk) ('stored: {0}; {1}{2}' -f $st, (AStr $al), $shot)
        if ($c[0] -eq 'newer') {
            Clear-Opened; Send-Key $al.LinkH 0x20; Start-Sleep -Milliseconds 800; $op = Opened
            T 'F1' 'dl' ($op.Count -eq 1 -and $op[0] -eq ($InstUrl -f '0.1.9') -and [Drv098f]::IsWindowVisible($a)) ('Space key sent to the Download link: opened {0}; expected {1}; About stays open {2}; link tab stop {3}; UIA {4}' -f $(if ($op.Count) { $op -join ' , ' } else { 'nothing' }), ($InstUrl -f '0.1.9'), [Drv098f]::IsWindowVisible($a), [bool]([P123]::GetWindowLong($al.LinkH, -16) -band 0x10000), (Esc (Uia $al.LinkH)))
            Info 'F1' 'tab' ('About tab order (visible WS_TABSTOP children): ' + ((TabOrder $a) -join ','))
        }
        Close-Any $a
        if (-not (Gone $a 2)) { Close-Win $a }
    }
    T 'F1' 'noreq' (((Req-Count) - $m0) -eq 0) ('the About dialog was opened {0} times: version requests {1} (FR-024: none)' -f $cases.Count, ((Req-Count) - $m0))
    $q = Quit $s.Id
    T 'F1' 'exit' (QOk $q) (QStr $q)
}
# F2: "Check now" in the About dialog (contracts/ui.md 4)
$Groups['F2'] = {
    Uc-Set 'Check At Startup' 0 'DWord'
    Set-Env 'dyn'; Dyn '403'
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    $a = Open-About $s.Id
    $al = About-Line $a
    if (-not $al.LinkVisible) { T 'F2' 'setup' $false ('no Check now link: ' + (AStr $al)); Close-Any $a; [void](Quit $s.Id); return }
    $m0 = Req-Count
    $r = Manual-Check $s.Id 22 -Target $al.LinkH
    Answer $r.H; Start-Sleep -Milliseconds 400
    $al2 = About-Line $a
    T 'F2' '403' ($r.Kind -eq 'msg' -and $r.Text -match 'refused the request' -and [Drv098f]::IsWindowVisible($a) -and $al2.Text -eq 'Not checked for a new version.' -and ((Req-Count) - $m0) -eq 1) ('Space on "Check now", server answers 403: ' + (MStr $r) + '; afterwards About open ' + [Drv098f]::IsWindowVisible($a) + ', ' + (AStr $al2) + '; requests ' + ((Req-Count) - $m0))
    Dyn 'same'
    $r = Manual-Check $s.Id 22 -Target $al2.LinkH
    Answer $r.H; Start-Sleep -Milliseconds 400
    $al3 = About-Line $a
    T 'F2' 'same' ($r.Kind -eq 'msg' -and $r.Text -eq 'Tandem Commander 0.1.8 is the latest version.' -and [Drv098f]::IsWindowVisible($a) -and $al3.Text -match '^This is the latest version \(checked .+\)\.$' -and -not $al3.LinkVisible) ('"Check now", up to date: ' + (MStr $r) + '; afterwards ' + (AStr $al3))
    Close-Any $a; [void](Gone $a 2)
    Uc-Clear; Uc-Set 'Check At Startup' 0 'DWord'; Dyn 'newer-0.1.9'
    $a = Open-About $s.Id; $al = About-Line $a
    $r = Manual-Check $s.Id 6 -Target $al.LinkH
    Start-Sleep -Milliseconds 500
    $al4 = About-Line $a
    T 'F2' 'newer' ([Drv098f]::IsWindowVisible($a) -and $al4.Text -eq 'Version 0.1.9 is available.' -and $al4.LinkVisible -and $al4.Link -match 'Download') ('"Check now", newer release: window after the check: ' + $(if ($r.Kind -eq 'none') { 'none (the line shows the result)' } else { MStr $r }) + '; ' + (AStr $al4))
    Close-Any $a; [void](Gone $a 2)
    Uc-Clear; Uc-Set 'Check At Startup' 0 'DWord'; Dyn 'hang'
    $a = Open-About $s.Id; $al = About-Line $a
    $r = Manual-Check $s.Id 10 -Target $al.LinkH -StopAtWait
    $gone = $false
    if ($r.Kind -eq 'wait') { Start-Sleep -Milliseconds 300; Click (Ctl $r.H 2); if (-not (Gone $r.H 2)) { Post-Cmd $r.H 2 }; $gone = Gone $r.H 3 }
    $w = Watch-Wins $s.Id 2.5 @($a)
    $al5 = About-Line $a
    T 'F2' 'cancel' ($r.Kind -eq 'wait' -and $gone -and $w.Count -eq 0 -and [Drv098f]::IsWindowVisible($a) -and [Drv098f]::IsWindowEnabled($a) -and $al5.Text -eq 'Not checked for a new version.') ('"Check now" against a server that never answers: wait dialog {0} at {1} s; Cancel closed it {2}; windows afterwards {3}; About still open {4} and enabled {5}; {6}' -f ($r.Kind -eq 'wait'), (S2 $r.WaitT), $gone, $(if ($w.Count) { $w -join ' || ' } else { 'none' }), [Drv098f]::IsWindowVisible($a), [Drv098f]::IsWindowEnabled($a), (AStr $al5))
    Close-Others $s.Id
    $q = Quit $s.Id
    T 'F2' 'exit' (QOk $q) (QStr $q)
}
# F3 / H2: the About dialog (a modal window) is open while the start-up check finds a newer version:
# the line follows the result (FR-024); the notification waits and appears after the dialog closes (FR-012, C13)
$Groups['F3'] = {
    Set-Env 'slow-ok'
    $s = Start-Fast
    $a = $Z
    try { $a = Open-About $s.Id } catch { T 'F3' 'setup' $false $_.Exception.Message; return }
    $al0 = About-Line $a
    $early = Get-Notice $s.Id
    $seenWhile = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 6) { if ((Get-Notice $s.Id) -ne $Z) { $seenWhile = $true; break }; Start-Sleep -Milliseconds 100 }
    $al1 = About-Line $a
    T 'F3' 'line' ($al1.Text -eq 'Version 9.9.9 is available.' -and $al1.LinkVisible) ('About opened right at start: ' + (AStr $al0) + '; 6 s later (the check finished meanwhile, stored Latest Version ' + (Uc-V 'Latest Version') + '): ' + (AStr $al1))
    T 'F3' 'waits' (-not $seenWhile) ('notification shown while the About dialog (modal) was open: ' + $seenWhile)
    Close-Any $a; [void](Gone $a 2)
    $n = Wait-Notice $s.Id 5
    $t = $sw.Elapsed.TotalSeconds
    T 'F3' 'after' ($n -ne $Z) ('after the About dialog closed: notification {0} ({1} s after the watch began)' -f ($n -ne $Z), (S2 $t))
    Close-Others $s.Id; [void](Quit $s.Id)
}
# F3B: the same with the Configuration dialog; F3C: a dialog of the main thread that does NOT disable the main
# window (round 2, claim 8) - constructed by re-enabling the main window from outside while About is open
$Groups['F3B'] = {
    Set-Env 'slow-ok'
    $s = Start-Fast
    $cfg = Open-Config $s.Id
    $seen = $false; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 6) { if ((Get-Notice $s.Id) -ne $Z) { $seen = $true; break }; Start-Sleep -Milliseconds 100 }
    $lv = Uc-V 'Latest Version'
    Cfg-Close $cfg 2
    $n = Wait-Notice $s.Id 5
    T 'F3B' 'cfg' (-not $seen -and $lv -eq 'String:9.9.9' -and $n -ne $Z) ('Configuration dialog open while the start-up check finishes (stored Latest Version {0}): notification shown meanwhile {1}; after Cancel: notification {2}' -f $lv, $seen, ($n -ne $Z))
    if ($n -ne $Z) { $actM = [P123]::ActiveOf($s.Main); T 'F3B' 'nofoc' ((Not-In-Notice $n ([P123]::FocusOf($s.Main)))) ('the delayed notification takes no focus: focus inside it {0}; active window is the notification {1}' -f (-not (Not-In-Notice $n ([P123]::FocusOf($s.Main)))), ($actM -eq $n)) }
    Close-Others $s.Id; [void](Quit $s.Id)
}
$Groups['F3C'] = {
    Set-Env 'slow-ok'
    $s = Start-Fast
    $a = $Z
    try { $a = Open-About $s.Id } catch { T 'F3C' 'setup' $false $_.Exception.Message; return }
    [void][P123]::EnableWindow($s.Main, $true)
    $en = [Drv098f]::IsWindowEnabled($s.Main)
    $seen = $false; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 7) { if ((Get-Notice $s.Id) -ne $Z) { $seen = $true; break }; Start-Sleep -Milliseconds 100 }
    $lv = Uc-V 'Latest Version'
    $tSeen = $sw.Elapsed.TotalSeconds
    $still = [Drv098f]::IsWindowVisible($a)
    Close-Any $a; [void](Gone $a 2)
    $n = Wait-Notice $s.Id 5
    if (-not $en) { ND 'F3C' 'dlg' 'the main window could not be re-enabled from outside while About was open'; Close-Others $s.Id; [void](Quit $s.Id); return }
    T 'F3C' 'dlg' (-not $seen -and $lv -eq 'String:9.9.9' -and $n -ne $Z) ('About open and the main window ENABLED (EnableWindow from the probe: a dialog of the main thread that does not disable it); the start-up check finished (Latest Version {0}): notification shown while the dialog was on screen {1}{2}; dialog still open then {3}; after it closed: notification {4}' -f $lv, $seen, $(if ($seen) { ' after ' + (S2 $tSeen) + ' s' } else { '' }), $still, ($n -ne $Z))
    Close-Others $s.Id; [void](Quit $s.Id)
}
# H7: no debug box about handles left open, whatever happened to the request before the exit (round 2, claim 1)
$Groups['H7'] = {
    Uc-Set 'Check At Startup' 0 'DWord'
    Set-Env 'dyn'; Dyn 'hang'
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    $r = Manual-Check $s.Id 10 -StopAtWait
    if ($r.Kind -eq 'wait') { Start-Sleep -Milliseconds 300; Click (Ctl $r.H 2); if (-not (Gone $r.H 2)) { Post-Cmd $r.H 2; [void](Gone $r.H 2) } }
    Start-Sleep -Milliseconds 300
    $q = Quit $s.Id
    T 'H7' 'cancel' ($r.Kind -eq 'wait' -and (QOk $q)) ('exit right after one cancelled manual check: ' + (QStr $q))
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    $ts = @()
    for ($i = 0; $i -lt 5; $i++) {
        $r = Manual-Check $s.Id 10 -StopAtWait
        if ($r.Kind -ne 'wait') { $ts += ('no wait dialog: ' + (MStr $r)); Close-Others $s.Id; continue }
        Start-Sleep -Milliseconds 200; $sw = [Diagnostics.Stopwatch]::StartNew(); Click (Ctl $r.H 2); if (-not (Gone $r.H 2)) { Post-Cmd $r.H 2; [void](Gone $r.H 2) }; $ts += (S2 $sw.Elapsed.TotalSeconds)
    }
    $w = Watch-Wins $s.Id 1.5
    $q = Quit $s.Id
    T 'H7' 'five' ((QOk $q) -and $w.Count -eq 0 -and @($ts | Where-Object { $_ -match 'no wait' }).Count -eq 0) ('five manual checks cancelled in a row (Cancel took ' + ($ts -join '/') + ' s), then exit: ' + (QStr $q) + '; windows before the exit: ' + $(if ($w.Count) { $w -join ' || ' } else { 'none' }))
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    $r = Manual-Check $s.Id 25
    Answer $r.H; Start-Sleep -Milliseconds 300
    $q = Quit $s.Id
    T 'H7' 'timed' ($r.Kind -eq 'msg' -and (QOk $q)) ('exit after a manual check that ran into its time limit (' + (S2 $r.T) + ' s): ' + (QStr $q))
    Dyn 'slow'
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    $r = Manual-Check $s.Id 10 -StopAtWait
    if ($r.Kind -eq 'wait') { Start-Sleep -Milliseconds 1500; Click (Ctl $r.H 2); if (-not (Gone $r.H 2)) { Post-Cmd $r.H 2; [void](Gone $r.H 2) } }
    $q = Quit $s.Id
    T 'H7' 'slowc' ($r.Kind -eq 'wait' -and (QOk $q)) ('exit after a manual check cancelled while the body was dripping in: ' + (QStr $q))
}
# G1: Configuration > General (US4, FR-025, contracts/ui.md 5)
$Groups['G1'] = {
    Set-Env 'same'
    Uc-Set 'Last Attempt' (FtAt -0.1) 'QWord'; Uc-Set 'Last Attempt Answered' 1 'DWord'   # no request in this row
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1500
    $cfg = Open-Config $s.Id
    $cb = Cfg-Box $cfg
    if ($cb -eq $Z) { T 'G1' 'box' $false ('no control 6255 in the Configuration dialog: ' + (Desc $cfg)); Close-Any $cfg; [void](Quit $s.Id); return }
    $page = [Drv098f]::GetParent($cb)
    $txt = [Drv098f]::Txt($cb)
    # the control before it in the page's z-order (contract: below "Keep environment variables updated ...")
    $ord = @([P123]::ChildOrder($page)); $prev = ''
    for ($i = 1; $i -lt $ord.Count; $i++) { if ($ord[$i] -eq $cb) { $prev = [Drv098f]::Txt($ord[$i - 1]) } }
    $rb = New-Object P123+RECT; [void][P123]::GetWindowRect($cb, [ref]$rb)
    $rp = New-Object P123+RECT; [void][P123]::GetWindowRect($page, [ref]$rp)
    T 'G1' 'box' ((Box-Checked $cb) -and [Drv098f]::IsWindowVisible($cb) -and (Norm ($txt -replace '&', '')) -eq 'Check for a new version of Tandem Commander at start-up' -and $rb.B -le $rp.B) ("no 'Check At Startup' value stored: check box '{0}' visible {1}, checked {2}; previous control in the tab order '{3}'; box bottom {4} within the page bottom {5}; UIA {6}" -f $txt, [Drv098f]::IsWindowVisible($cb), (Box-Checked $cb), (Esc $prev), $rb.B, $rp.B, (Esc (Uia $cb)))
    Info 'G1' 'shot' (Shot $cfg 'config_general.png')
    $how = Toggle $cb
    $mid = Uc-V 'Check At Startup'
    Cfg-Close $cfg 2
    Start-Sleep -Milliseconds 300
    T 'G1' 'cancel' ((Uc-V 'Check At Startup') -eq '<absent>') ('cleared ({0}) then Cancel: stored value while the dialog was open {1}, after Cancel {2} (expected absent = on)' -f $how, $mid, (Uc-V 'Check At Startup'))
    $cfg = Open-Config $s.Id; $cb = Cfg-Box $cfg
    $c1 = Box-Checked $cb
    [void](Toggle $cb)
    Cfg-Close $cfg 1
    Start-Sleep -Milliseconds 400
    $v = Uc-V 'Check At Startup'
    T 'G1' 'ok-off' ($c1 -and $v -eq 'DWord:0') ('reopened: checked {0}; cleared + OK: stored at once (program still running) Check At Startup={1}' -f $c1, $v)
    $cfg = Open-Config $s.Id; $cb = Cfg-Box $cfg
    $c2 = Box-Checked $cb
    Cfg-Close $cfg 1
    Start-Sleep -Milliseconds 300
    T 'G1' 'shows' ($c2 -eq $false -and (Uc-V 'Check At Startup') -eq 'DWord:0') ('reopened with the stored value 0: checked {0}; OK without a change keeps {1}' -f $c2, (Uc-V 'Check At Startup'))
    # the value changed from outside (another instance, the notification) while this instance runs: read fresh
    Uc-Set 'Check At Startup' 1 'DWord'
    $cfg = Open-Config $s.Id; $cb = Cfg-Box $cfg
    $c3 = Box-Checked $cb
    Cfg-Close $cfg 2
    T 'G1' 'fresh' ($c3 -eq $true) ('value set to 1 from outside while the program runs: the page shows checked {0}' -f $c3)
    $st = Uc-Str
    $q = Quit $s.Id
    T 'G1' 'exit' ((QOk $q) -and (Uc-V 'Check At Startup') -eq 'DWord:1') ((QStr $q) + '; the exit (configuration saved) leaves the value: before ' + $st + ' / after ' + (Uc-Str))
}
# G2: a brand-new user (no registry key at all): option on, the first start checks (US4-1, FR-010)
$Groups['G2'] = {
    & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
    Set-Env 'newer-0.1.9'
    $m0 = Req-Count
    # a first start asks for the language before the main window exists: answer that dialog with OK
    $p = Start-Raw
    $first = @()
    $sw0 = [Diagnostics.Stopwatch]::StartNew()
    while ($sw0.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq $Z) {
        foreach ($h in (Get-Tops $p.Id)) {
            if ([Drv098f]::Cls($h) -eq '#32770' -and (AllText $h) -match 'Select one of the installed languages') {
                $first += ('language dialog (answered OK) before the main window; version requests so far: ' + ((Req-Count) - $m0))
                $ok = Buttons $h | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
                Click $ok; if (-not (Gone $h 3)) { Post-Cmd $h 1; [void](Gone $h 3) }
            }
        }
        Start-Sleep -Milliseconds 50
    }
    if ((Get-Main $p.Id) -eq $Z) { throw ('no main window on a first start; windows: ' + (@(Get-Tops $p.Id | ForEach-Object { Desc $_ }) -join ' || ')) }
    $s = [pscustomobject]@{ Id = $p.Id; Sw = [Diagnostics.Stopwatch]::StartNew(); TMain = $sw0.Elapsed.TotalSeconds; Main = (Get-Main $p.Id) }
    $n = Wait-Notice $s.Id 15
    $t = $s.Sw.Elapsed.TotalSeconds
    $others = @($first) + @((Other-Wins $s.Id) | Where-Object { -not (Is-Notice $_) } | ForEach-Object { Desc $_ })
    T 'G2' 'first' ($n -ne $Z -and ((Req-Count) - $m0) -eq 1) ('no registry key of the product at all: first start: notification {0} after {1} s; requests {2}; other first-run windows: {3}; stored {4}' -f ($n -ne $Z), (S2 $t), ((Req-Count) - $m0), $(if ($others.Count) { $others -join ' || ' } else { 'none' }), (Uc-Str))
    Close-Others $s.Id
    Start-Sleep -Milliseconds 300
    try {
        $cfg = Open-Config $s.Id; $cb = Cfg-Box $cfg
        T 'G2' 'cfg' ($cb -ne $Z -and (Box-Checked $cb)) ('Configuration: check box present {0}, checked {1}' -f ($cb -ne $Z), $(if ($cb -ne $Z) { Box-Checked $cb } else { '-' }))
        Cfg-Close $cfg 2
    }
    catch { T 'G2' 'cfg' $false ('Configuration: ' + $_.Exception.Message) }
    Close-Others $s.Id
    $q = Quit $s.Id
    Info 'G2' 'exit' (QStr $q)
}
# H1: exit while a request is in flight (edge "closed while the check is running", SC-007, C12)
$Groups['H1'] = {
    foreach ($f in 'hang', 'slow') {
        Uc-Clear; Set-Env $f
        $m0 = Req-Count
        $s = Start-Fast
        $got = Wait-Req ($m0 + 1) 8
        Start-Sleep -Milliseconds 700
        $q = Quit $s.Id
        T 'H1' $f ($got -and (QOk $q ($script:BaseQuit + 1.0))) ('request in flight {0}; {1}; exit without the feature takes up to {2} s; stored {3}' -f $got, (QStr $q), (S2 $script:BaseQuit), (Uc-Str))
    }
    # started and closed at once
    Uc-Clear; Set-Env 'hang'
    $bad = @(); $ts = @()
    for ($i = 0; $i -lt 5; $i++) { $s = Start-Fast; $q = Quit $s.Id; $ts += $q.Sec; if (-not (QOk $q ($script:BaseQuit + 1.5))) { $bad += (QStr $q) }; Uc-Clear }
    T 'H1' 'quick' ($bad.Count -eq 0) ('closed the moment the main window appeared, 5 times: exit {0} s{1}' -f ((@($ts | ForEach-Object { S2 $_ })) -join '/'), $(if ($bad.Count) { '; ' + ($bad -join ' ;; ') } else { '' }))
    # exit while the wait dialog of a manual check is open is not possible for a user (modal); a session end is: see H3
}
# H3: an installer closes the program (feature 080) while the notification is open (edge case; contracts/ui.md 1 Showing 5)
$Groups['H3'] = {
    # control: the same two session messages the Restart Manager sends, without a notification
    Uc-Set 'Check At Startup' 0 'DWord'; Set-Env 'newer-0.1.9'
    $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 2500
    $ctl = [P123]::SendR($s.Main, 0x0011, 0, 1, 8000)   # WM_QUERYENDSESSION, ENDSESSION_CLOSEAPP
    [void][P123]::SendR($s.Main, 0x0016, 1, 1, 15000)   # WM_ENDSESSION, ending, ENDSESSION_CLOSEAPP
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 10 -and (Test-Alive $s.Id)) { Start-Sleep -Milliseconds 100 }
    $ctlEnded = -not (Test-Alive $s.Id); $ctlCode = $(if ($ctlEnded) { ExitCodeOf $s.Id } else { '-' })
    if (-not $ctlEnded) { Close-Others $s.Id; [void](Quit $s.Id) }
    Uc-Clear
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    if ($n -eq $Z) { T 'H3' 'setup' $false 'no notification'; return }
    Start-Sleep -Milliseconds 500
    $ans = [P123]::SendR($s.Main, 0x0011, 0, 1, 8000)
    if ($ctl -ne 1 -or -not $ctlEnded) { ND 'H3' 'agree' ('the control instance (no notification) answered WM_QUERYENDSESSION(ENDSESSION_CLOSEAPP) with ' + $ctl + ' and ended after WM_ENDSESSION: ' + $ctlEnded + ' - the close request cannot be judged with sent messages; with the notification open the answer was ' + $ans); Close-Others $s.Id; [void](Quit $s.Id); return }
    T 'H3' 'agree' ($ans -eq 1) ('WM_QUERYENDSESSION(ENDSESSION_CLOSEAPP) answered {0} with the notification open (control without it: {1}); 1 = the program agrees to be closed' -f $ans, $ctl)
    [void][P123]::SendR($s.Main, 0x0016, 1, 1, 15000)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 10 -and (Test-Alive $s.Id)) { Start-Sleep -Milliseconds 100 }
    $alive = Test-Alive $s.Id
    $left = [P123]::Notices().Count
    T 'H3' 'closes' (-not $alive -and $left -eq 0) ('WM_ENDSESSION(TRUE, ENDSESSION_CLOSEAPP) sent: process ended {0} after {1} s, exit code {2} (control: ended {3}, code {4}); notifications left {5}; windows {6}' -f (-not $alive), (S2 $sw.Elapsed.TotalSeconds), $(if (-not $alive) { ExitCodeOf $s.Id } else { '-' }), $ctlEnded, $ctlCode, $left, $(if ($alive) { (@((Other-Wins $s.Id) | ForEach-Object { Desc $_ }) -join ' || ') } else { 'none' }))
    if ($alive) { Close-Others $s.Id; [void](Quit $s.Id) }
}
# H4: garbage in every stored value: no crash, nothing misleading, the next check repairs it (stored-state rule 2)
$Groups['H4'] = {
    Set-Env 'newer-0.1.9'
    [void][P123]::RegSetRaw($UcPath, 'Check At Startup', 3, [byte[]](1..40))
    [void][P123]::RegSetRaw($UcPath, 'Last Attempt', 11, [byte[]](1, 2, 3))
    [void][P123]::RegSetRaw($UcPath, 'Last Attempt Answered', 1, [Text.Encoding]::Unicode.GetBytes("yes`0"))
    [void][P123]::RegSetRaw($UcPath, 'Last Success', 4, [byte[]](255, 255, 255, 255))
    [void][P123]::RegSetRaw($UcPath, 'Latest Version', 1, [Text.Encoding]::Unicode.GetBytes(('7' * 9000)))
    [void][P123]::RegSetRaw($UcPath, 'Latest Published', 7, [Text.Encoding]::Unicode.GetBytes("a`0b`0`0"))
    [void][P123]::RegSetRaw($UcPath, 'Skipped Version', 1, [Text.Encoding]::Unicode.GetBytes("0.1.9; DROP`0"))
    $before = Uc-Str
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    $v = ''; if ($n -ne $Z) { Start-Sleep -Milliseconds 300; $v = Notice-Vers $n }
    $h = Uc-Get
    T 'H4' 'start' ($n -ne $Z -and $v -eq '0.1.8 -> 0.1.9' -and $h['Latest Version'] -eq 'String:0.1.9' -and $h['Last Attempt Answered'] -eq 'DWord:1') ('garbage before: {0}; start: notification {1} {2}; after: {3}' -f $before, ($n -ne $Z), $v, (Uc-Str $h))
    if ($n -ne $Z) { T 'H4' 'ckbox' ((Checked $n 6249) -eq $true) ('Check At Startup of the wrong type reads as the default (on): check box checked ' + (Checked $n 6249)) }
    Close-Others $s.Id
    $a = Open-About $s.Id; $al = About-Line $a
    T 'H4' 'about' ($al.Text -eq 'Version 0.1.9 is available.') ('About: ' + (AStr $al))
    Close-Any $a
    $q = Quit $s.Id
    T 'H4' 'exit' (QOk $q) (QStr $q)
    # a published date that is garbage beside a valid version; Skipped garbage must not hide a release
    Uc-Clear
    Uc-Set 'Skipped Version' '0.1' 'String'
    Uc-Set 'Latest Version' '0.1.9' 'String'; Uc-Set 'Latest Published' '2026-13-45T99:99:99Z' 'String'
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    T 'H4' 'skipg' ($n -ne $Z) ("Skipped Version '0.1' (unparsable) reads as no skip: notification " + ($n -ne $Z))
    Close-Others $s.Id; [void](Quit $s.Id)
}
# H5: the browser cannot be started -> the user is told, the address can be copied, the notification stays (edge case)
$Groups['H5'] = {
    Set-Env 'newer-0.1.9'
    $env:TC_UPDATECHECK_OPENLOG = (Join-Path $Work 'no_such_dir\sub\opened.log')   # the seam's stand-in for "the browser did not start"
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    if ($n -eq $Z) { T 'H5' 'setup' $false 'no notification'; return }
    Start-Sleep -Milliseconds 400
    $known = Get-Tops $s.Id
    Click (Ctl $n 1)
    $m = Wait-NewWin $s.Id $known 3
    if ($m -eq $Z) { Post-Cmd $n 1; $m = Wait-NewWin $s.Id $known 3 }
    if ($m -eq $Z) { T 'H5' 'msg' $false ('Download with the open failing: no message; notification still open ' + [Drv098f]::IsWindowVisible($n)); Close-Others $s.Id; [void](Quit $s.Id); return }
    Start-Sleep -Milliseconds 300
    $txt = AllText $m; $btn = BtnText $m
    Info 'H5' 'shot' (Shot $m 'answer_browser_failed.png')
    $urlWhole = ($txt -match [regex]::Escape(($InstUrl -f '0.1.9')))
    T 'H5' 'msg' ((($txt -replace ' ', '').Contains(($InstUrl -f '0.1.9'))) -and [Drv098f]::IsWindowVisible($n)) ("Download when the address cannot be opened: message '{0}' text '{1}' buttons {2}; the notification stays open {3}" -f (Esc ([Drv098f]::Txt($m))), (Esc $txt), (Esc $btn), [Drv098f]::IsWindowVisible($n))
    T 'H5' 'copy' ($txt -match 'copy the address to the clipboard' -and $btn -match 'Yes') ("the address can be copied: the message asks 'Do you want to copy the address to the clipboard?' with buttons " + (Esc $btn) + " (contract ui.md 1 words it as 'a message with the address and a Copy button'); the address is shown in one piece (no line break inside it): " + $urlWhole + '; pressing Yes was NOT driven - the clipboard is shared with the user''s desktop')
    $no = Buttons $m | Where-Object { @(7, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
    if ($no) { Click $no; if (-not (Gone $m 2)) { Post-Cmd $m ([Drv098f]::GetDlgCtrlID($no)) } } else { Close-Win $m }
    [void](Gone $m 2)
    T 'H5' 'stays' ([Drv098f]::IsWindow($n) -and [Drv098f]::IsWindowVisible($n)) ('after the message was answered "No": the notification is still open ' + ([Drv098f]::IsWindow($n) -and [Drv098f]::IsWindowVisible($n)))
    Close-Others $s.Id; [void](Quit $s.Id)
}
# H6: a configuration store that cannot be written (edge case; stored-state rule 5)
function Uc-Lock([bool]$Lock) {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = New-Object Security.AccessControl.RegistryAccessRule($me, [Security.AccessControl.RegistryRights]'SetValue,CreateSubKey', [Security.AccessControl.AccessControlType]::Deny)
    $k = $HKCU.OpenSubKey($UcPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [Security.AccessControl.RegistryRights]'ChangePermissions,ReadPermissions,QueryValues')
    if (-not $k) { return }
    try { $sec = $k.GetAccessControl([Security.AccessControl.AccessControlSections]::Access); if ($Lock) { $sec.AddAccessRule($rule) } else { [void]$sec.RemoveAccessRule($rule) }; $k.SetAccessControl($sec) } finally { $k.Close() }
}
$Groups['H6'] = {
    Set-Env 'newer-0.1.9'
    Uc-Set 'Check At Startup' 1 'DWord'
    Uc-Lock $true
    try {
        $st0 = Uc-Str
        $m0 = Req-Count
        $s = Start-Fast
        $n = Wait-Notice $s.Id 12
        $w = @((Other-Wins $s.Id) | Where-Object { -not (Is-Notice $_) } | ForEach-Object { Desc $_ })
        T 'H6' 'check' ($n -ne $Z -and $w.Count -eq 0 -and ((Req-Count) - $m0) -eq 1) ('Update Check key denies writing: the check still runs: notification {0}, requests {1}, error windows: {2}; stored {3}' -f ($n -ne $Z), ((Req-Count) - $m0), $(if ($w.Count) { $w -join ' || ' } else { 'none' }), (Uc-Str))
        if ($n -ne $Z) {
            $p = Press-Close $n 6250 2
            $w = Watch-Wins $s.Id 1.5
            T 'H6' 'skip' ($p.Gone -and $w.Count -eq 0 -and (Uc-Str) -eq $st0) ('Skip This Version with the store read-only: closed {0}, error windows {1}, stored unchanged {2}' -f $p.Gone, $(if ($w.Count) { $w -join ' || ' } else { 'none' }), ((Uc-Str) -eq $st0))
        }
        Close-Others $s.Id
        $q = Quit $s.Id
        T 'H6' 'exit' (QOk $q) (QStr $q)
    }
    finally { Uc-Lock $false }
}
# ---- round 2: languages, dark theme, the strings of the built language modules, the real Restart Manager ----
$Langs = @('english', 'czech', 'german', 'french', 'dutch', 'hungarian', 'romanian', 'slovak', 'spanish')
$script:EnTexts = @{}
# one pass through every window of the feature in one language / theme; captures into shots\<dir>
function Tour([string]$Case, [string]$Lang, [string]$Dir, [bool]$Dark) {
    $out = Join-Path $ShotDir $Dir
    [void][IO.Directory]::CreateDirectory($out)
    Cfg-SetStr 'Language' ($Lang + '.slg')
    if ($Dark) { Cfg-Set 'Theme Mode' 1 }
    $script:AnyDialogIsMsg = $true
    $texts = [ordered]@{}; $cut = @(); $notes = @()
    function Cap([IntPtr]$H, [string]$Name) { $f = Join-Path $out $Name; try { [void][P123]::Capture($H, $f) } catch { }; return $f }
    Set-Env 'dyn'; Dyn 'newer-0.1.9'
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    if ($n -eq $Z) { T $Case $Lang $false 'no start-up notification'; Close-Others $s.Id; [void](Quit $s.Id); return }
    Start-Sleep -Milliseconds 600
    $f = Cap $n 'notice_startup.png'
    $texts['notice.caption'] = [Drv098f]::Txt($n)
    foreach ($id in 6238, 6241, 6244, 6246, 6247, 6248, 1, 2, 6250, 6249) { $texts['notice.' + $id] = [Drv098f]::GetText((Ctl $n $id), 3000) }
    foreach ($id in 6238, 6241, 6244, 6242, 6245, 6246) { $c = Clip-Ctl $n (Ctl $n $id) $f; if ($c -ne 'fits') { $cut += ('notice ' + $id + ' ' + $c) } }
    $hw = Fit-Wrap (Ctl $n 6248); if (-not $hw.Ok) { $cut += ('notice hint text needs about ' + $hw.Need + ' px of height, has ' + $hw.Have) }
    foreach ($id in 1, 2, 6250) { $b = Fit-Button (Ctl $n $id) 12; if (-not $b.Ok) { $cut += ("notice button $id '" + $b.Text + "' needs about " + $b.Need + ' px, has ' + $b.Have) } }
    $b = Fit-Button (Ctl $n 6249) 20; if (-not $b.Ok) { $cut += ("notice check box '" + $b.Text + "' needs about " + $b.Need + ' px, has ' + $b.Have) }
    if ($Dark) { try { $bmp = New-Object Drawing.Bitmap($f); $px = $bmp.GetPixel(40, [int]($bmp.Height / 2)); $hd = $bmp.GetPixel(20, 45); $bmp.Dispose(); $notes += ('dark: header pixel RGB ' + $hd.R + ',' + $hd.G + ',' + $hd.B + '; body pixel RGB ' + $px.R + ',' + $px.G + ',' + $px.B); if ($hd.R + $hd.G + $hd.B -gt 300) { $cut += 'dark theme: the header band is light' }; if ($px.R + $px.G + $px.B -gt 450) { $cut += 'dark theme: the body is light' } } catch { } }
    [void][Drv098f]::PostMessageW($n, 0x0010, $Z, $Z); [void](Gone $n 2)
    $r = Manual-Check $s.Id
    if ($r.Kind -eq 'notice') { Start-Sleep -Milliseconds 400; [void](Cap $r.H 'notice_manual.png') } else { $notes += ('manual check gave ' + (MStr $r)) }
    Close-Others $s.Id
    if (-not $Dark) {
        Dyn 'hang'
        $r = Manual-Check $s.Id 10 -StopAtWait
        if ($r.Kind -eq 'wait') {
            Start-Sleep -Milliseconds 300; $f = Cap $r.H 'wait.png'
            $texts['wait.caption'] = [Drv098f]::Txt($r.H); $texts['wait.text'] = CtlText $r.H 6252; $texts['wait.cancel'] = CtlText $r.H 2
            $c = Clip-Ctl $r.H (Ctl $r.H 6252) $f; if ($c -ne 'fits') { $cut += ('wait text ' + $c) }
            $b = Fit-Button (Ctl $r.H 2) 12; if (-not $b.Ok) { $cut += ("wait button '" + $b.Text + "' needs about " + $b.Need + ' px, has ' + $b.Have) }
            Click (Ctl $r.H 2); if (-not (Gone $r.H 2)) { Post-Cmd $r.H 2; [void](Gone $r.H 2) }
        }
        else { $notes += ('no wait dialog: ' + (MStr $r)); Close-Others $s.Id }
    }
    $answers = @(@('same', 'msg_uptodate'), @('403', 'msg_refused'), @('html', 'msg_unexpected'))
    if ($Dark) { $answers = @(, @('same', 'msg_uptodate')) }
    foreach ($a in $answers) {
        Dyn $a[0]
        $r = Manual-Check $s.Id
        if ($r.Kind -eq 'msg') { [void](Cap $r.H ($a[1] + '.png')); $texts[$a[1] + '.caption'] = [Drv098f]::Txt($r.H); $texts[$a[1]] = $r.Text } else { $notes += ($a[1] + ': ' + (MStr $r)) }
        Answer $r.H; Close-Others $s.Id
    }
    [void](Quit $s.Id)
    if (-not $Dark) {
        # "not reached": the port nobody listens on
        Set-Env 'DEAD'
        $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1200
        $r = Manual-Check $s.Id 25
        if ($r.Kind -eq 'msg') { [void](Cap $r.H 'msg_unreachable.png'); $texts['msg_unreachable'] = $r.Text } else { $notes += ('msg_unreachable: ' + (MStr $r)) }
        Answer $r.H; Close-Others $s.Id
    }
    else { Uc-Set 'Check At Startup' 0 'DWord'; $s = Start-Fast; [void](Alive-Main $s.Id); Start-Sleep -Milliseconds 1200 }
    # About in its three states
    $states = @(@('about_notchecked', $null), @('about_newer', '0.1.9'), @('about_latest', '0.1.8'))
    foreach ($st in $states) {
        Uc-Clear; Uc-Set 'Check At Startup' 0 'DWord'
        if ($st[1]) { Uc-Set 'Latest Version' $st[1] 'String'; Uc-Set 'Last Success' (FtAt -72) 'QWord' }
        try {
            $a = Open-About $s.Id; $al = About-Line $a
            $f = Cap $a ($st[0] + '.png')
            $texts[$st[0]] = $al.Text; if ($al.LinkVisible) { $texts[$st[0] + '.link'] = $al.Link }
            $ra = New-Object P123+RECT; [void][P123]::GetWindowRect($a, [ref]$ra)
            $rt = New-Object P123+RECT; [void][P123]::GetWindowRect((Ctl $a 6253), [ref]$rt)
            $right = $rt.R
            if ($al.LinkVisible) { $rl = New-Object P123+RECT; [void][P123]::GetWindowRect($al.LinkH, [ref]$rl); $right = $rl.R; if ($rl.L -lt $rt.R - 1) { $cut += ($st[0] + ': the link starts ' + ($rt.R - $rl.L) + ' px inside the text') }; $c = Clip-Ctl $a $al.LinkH $f; if ($c -match 'CUT right') { $cut += ($st[0] + ' link ' + $c) } }
            if ($right -gt $ra.R - 8) { $cut += ($st[0] + ': the line ends ' + ($ra.R - $right) + ' px from the right edge of the dialog') }
            Close-Any $a; if (-not (Gone $a 2)) { Close-Win $a }
        }
        catch { $notes += ($st[0] + ': ' + $_.Exception.Message); Close-Others $s.Id }
    }
    if (-not $Dark) {
        try {
            $cfg = Open-Config $s.Id; $cb = Cfg-Box $cfg
            [void](Cap $cfg 'config_general.png')
            if ($cb -ne $Z) { $texts['config.box'] = [Drv098f]::GetText($cb, 3000); $b = Fit-Button $cb 20; if (-not $b.Ok) { $cut += ("configuration check box '" + $b.Text + "' needs about " + $b.Need + ' px, has ' + $b.Have) } } else { $notes += 'no check box 6255 on the General page' }
            Cfg-Close $cfg 2
        }
        catch { $notes += ('configuration: ' + $_.Exception.Message); Close-Others $s.Id }
    }
    $q = Quit $s.Id
    # verdict: every text present; in another language none may be left in English (except words that are the same)
    $empty = @($texts.Keys | Where-Object { -not $texts[$_] })
    $same = @()
    if ($Lang -eq 'english') { if (-not $Dark) { foreach ($k in $texts.Keys) { $script:EnTexts[$k] = $texts[$k] } } }
    elseif ($script:EnTexts.Count) { $same = @($texts.Keys | Where-Object { $script:EnTexts.ContainsKey($_) -and $texts[$_] -ceq $script:EnTexts[$_] -and $_ -ne 'notice.caption' }) }
    T $Case $Lang ($empty.Count -eq 0 -and $cut.Count -eq 0 -and $notes.Where({ $_ -notmatch '^dark:' }).Count -eq 0 -and (QOk $q)) ('captures in shots\{0}; texts read {1}; empty: {2}; identical to English: {3}; cut or overlapping (measured): {4}; {5}{6}' -f $Dir, $texts.Count, $(if ($empty.Count) { $empty -join ',' } else { 'none' }), $(if ($same.Count) { (@($same | ForEach-Object { $_ + "='" + (Esc $texts[$_]) + "'" }) -join ', ') } else { 'none' }), $(if ($cut.Count) { $cut -join ' ; ' } else { 'none' }), (QStr $q), $(if ($notes.Count) { '; notes: ' + ($notes -join ' ; ') } else { '' }))
    Out ('      texts ' + $Lang + ': ' + (@($texts.Keys | ForEach-Object { $_ + "='" + (Esc $texts[$_]) + "'" }) -join ' | '))
}
$Groups['L'] = { foreach ($l in $Langs) { Reset-Base; Tour 'L' $l $l $false } }
$Groups['K'] = { foreach ($l in 'english', 'czech', 'german') { Reset-Base; Tour 'K' $l ('dark_' + $l) $true } }
# ST: the strings of the feature in the BUILT language modules: present, placeholders as in English, the Czech menu name
$Groups['ST'] = {
    $ids = @(13201) + (14103..14111) + (14144..14149)
    $dir = Join-Path (Split-Path -Parent $Exe) 'lang'
    $en = [P123]::LoadStrings((Join-Path $dir 'english.slg'), [int[]]$ids)
    if ($null -eq $en) { T 'ST' 'load' $false 'english.slg could not be loaded as a data file'; return }
    Out ('      english: ' + (@(0..($ids.Count - 1) | ForEach-Object { '' + $ids[$_] + "='" + (Esc $en[$_]) + "'" }) -join ' | '))
    T 'ST' 'english' (($en[0] -replace '&', '') -eq 'Check for New Version' -and @($en | Where-Object { -not $_ }).Count -eq 0) ("string 13201 in english.slg: '" + $en[0] + "'; all " + $ids.Count + ' strings present: ' + (@($en | Where-Object { -not $_ }).Count -eq 0))
    function Count-Ph([string]$t) { return ([regex]::Matches($t, '%[^%\s]')).Count }
    function Phs([string]$t) { return (@([regex]::Matches($t, '%.') | ForEach-Object { $_.Value }) -join '') }
    foreach ($l in ($Langs | Where-Object { $_ -ne 'english' })) {
        $tr = [P123]::LoadStrings((Join-Path $dir ($l + '.slg')), [int[]]$ids)
        if ($null -eq $tr) { T 'ST' $l $false ($l + '.slg could not be loaded'); continue }
        $bad = @(); $same = @(); $nl = @()
        for ($i = 0; $i -lt $ids.Count; $i++) {
            if (-not $tr[$i]) { $bad += ('' + $ids[$i] + ' missing'); continue }
            if ((Phs $tr[$i]) -ne (Phs $en[$i])) { $bad += ('' + $ids[$i] + " placeholders '" + (Phs $tr[$i]) + "' instead of '" + (Phs $en[$i]) + "'") }
            if ($tr[$i] -ceq $en[$i]) { $same += ('' + $ids[$i] + "='" + $tr[$i] + "'") }
            if (([regex]::Matches($tr[$i], "`n")).Count -ne ([regex]::Matches($en[$i], "`n")).Count) { $nl += ('' + $ids[$i]) }
            if ($tr[$i] -notmatch 'Tandem Commander' -and $en[$i] -match 'Tandem Commander') { $bad += ('' + $ids[$i] + ' lost the product name') }
            if ($tr[$i] -notmatch 'tandemcommander\.org' -and $en[$i] -match 'tandemcommander\.org') { $bad += ('' + $ids[$i] + ' lost the address') }
        }
        $czOk = $true; $cz = ''
        if ($l -eq 'czech') { $cz = ($tr[0] -replace '&', ''); $czOk = ($cz -ceq 'Zkontrolovat novou verzi') }
        T 'ST' $l ($bad.Count -eq 0 -and $czOk) ('{0}.slg: {1} strings; placeholder / content faults: {2}; identical to English: {3}; different number of line breaks: {4}{5}' -f $l, $ids.Count, $(if ($bad.Count) { $bad -join ' ; ' } else { 'none' }), $(if ($same.Count) { Esc ($same -join ', ') } else { 'none' }), $(if ($nl.Count) { $nl -join ',' } else { 'none' }), $(if ($l -eq 'czech') { "; menu command 13201 = '" + (Esc $tr[0]) + "' (required: Zkontrolovat novou verzi): " + $czOk } else { '' }))
        Out ('      ' + $l + ': ' + (@(0..($ids.Count - 1) | ForEach-Object { '' + $ids[$_] + "='" + (Esc $tr[$_]) + "'" }) -join ' | '))
    }
}
# R: feature 080 with the real Restart Manager (specs/080-restart-manager-upgrade/probe/rm_probe.ps1 -Restart):
# the notification open (start-up path) / a request in flight (quickstart D)
function Rm-Run([string]$Case, [string]$Step, [int]$Id, [int]$ReqBefore) {
    $rm = Join-Path $PSScriptRoot '..\..\080-restart-manager-upgrade\probe\rm_probe.ps1'
    $log = Join-Path $Work ('rm_' + $Step + '.txt')
    Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
    $before = @(Get-Process -Name tandemcommander -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $child = Start-Process -FilePath powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $rm), '-ExePath', ('"{0}"' -f $Exe), '-Restart') -PassThru -WindowStyle Hidden -RedirectStandardOutput $log
    $seen = @{}; $shown = @(); $other = @()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $newPid = 0; $tNew = -1.0; $onDesk = $false; $second = $false; $newDesk = ''; $killedAt = -1.0
    $myDesk = [DeskLib098]::Name()
    while ($sw.Elapsed.TotalSeconds -lt 90 -and -not $child.HasExited) {
        if (Test-Alive $Id) { foreach ($h in (Other-Wins $Id)) { if (Is-Notice $h) { continue }; $k = $h.ToInt64(); if (-not $seen.ContainsKey($k)) { $seen[$k] = 1; if ([Drv098f]::Cls($h) -eq '#32770') { $shown += (Desc $h) } else { $other += ('[' + [Drv098f]::Cls($h) + ']') } } } }
        if ($newPid -and -not $newDesk -and (Test-Alive $newPid)) { $newDesk = [P123]::DesktopOf($newPid); if ($newDesk -and $newDesk -ine $myDesk) { try { Kill-Mine $newPid } catch { }; $killedAt = $sw.Elapsed.TotalSeconds - $tNew } }
        if (-not $newPid) { $np = @(Get-Process -Name tandemcommander -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id -and $_.Path -ieq $Exe }); if ($np.Count) { $newPid = $np[0].Id; $tNew = $sw.Elapsed.TotalSeconds; [void]$Started.Add($newPid); [void]$np[0].Handle; $script:Procs[$newPid] = $np[0] } }
        Start-Sleep -Milliseconds 50
    }
    if (-not $child.HasExited) { try { Stop-Process -Id $child.Id -Force } catch { } }
    $outText = ''; try { $outText = (@(Get-Content -LiteralPath $log) -join ' / ') } catch { }
    if (-not $newPid) { $np = @(Get-Process -Name tandemcommander -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id -and $_.Path -ieq $Exe }); if ($np.Count) { $newPid = $np[0].Id; [void]$Started.Add($newPid); [void]$np[0].Handle; $script:Procs[$newPid] = $np[0] } }
    $oldGone = -not (Test-Alive $Id)
    $oldCode = $(if ($oldGone) { ExitCodeOf $Id } else { 'still running' })
    $restartInfo = 'nothing was started again'
    if ($newPid) {
        $sw2 = [Diagnostics.Stopwatch]::StartNew()
        while ($sw2.Elapsed.TotalSeconds -lt 8 -and (Test-Alive $newPid) -and (Get-Main $newPid) -eq $Z) {
            if (-not $newDesk) { $newDesk = [P123]::DesktopOf($newPid) }
            if ($newDesk -and $newDesk -ine $myDesk) { try { Kill-Mine $newPid } catch { }; if ($killedAt -lt 0) { $killedAt = 0 }; break }
            if (-not $newDesk -and $sw2.Elapsed.TotalSeconds -gt 1.5) { try { Kill-Mine $newPid } catch { }; break }   # unknown desktop: do not let it stay
            Start-Sleep -Milliseconds 30
        }
        $onDesk = ((Test-Alive $newPid) -and (Get-Main $newPid) -ne $Z)
        if ($onDesk) {
            $w = Watch-Wins $newPid 6
            $second = ([P123]::Notices().Count -gt 0)
            $restartInfo = ('restarted pid {0} on the probe''s desktop; within 6 s: windows {1}; notification {2}' -f $newPid, $(if ($w.Count) { $w -join ' || ' } else { 'none' }), $second)
            Close-Others $newPid; $q = Quit $newPid; $restartInfo += '; ' + (QStr $q)
        }
        else { try { Kill-Mine $newPid } catch { }; $restartInfo = ("the Restart Manager started the program again (pid {0}); it has no window on the probe's desktop '{2}' (name of its desktop as far as it could be read: '{1}') - the probe ended it at once (so that no window stays on the user's screen); whether it would show a second notification could not be observed; no further version request reached the fixture server before that" -f $newPid, $newDesk, $myDesk) }
    }
    $ok = ($outText -match 'RmShutdown : 0 ' -and $outText -match 'Survivors  : none' -and $outText -match 'RmRestart  : 0 ' -and $oldGone -and $oldCode -eq '0x00000000' -and $shown.Count -eq 0 -and $newPid -ne 0)
    T $Case $Step $ok ('rm_probe: {0}; old process ended {1} (exit code {2}); dialogs or message boxes shown while closing: {3} (other windows of the closing program: {4}); version requests since the start of the row: {5}' -f $outText, $oldGone, $oldCode, $(if ($shown.Count) { $shown -join ' || ' } else { 'none' }), $(if ($other.Count) { $other -join '' } else { 'none' }), ((Req-Count) - $ReqBefore))
    if ($newPid -and $onDesk) { T $Case ($Step + '2') (-not $second -and ((Req-Count) - $ReqBefore) -le 1) ($restartInfo + '; version requests in the whole row: ' + ((Req-Count) - $ReqBefore) + ' (the one before the update only)') }
    else { ND $Case ($Step + '2') $restartInfo }
    if (-not $oldGone) { Close-Others $Id; [void](Quit $Id) }
}
$Groups['R'] = {
    Set-Env 'newer-0.1.9'
    $m0 = Req-Count
    $s = Start-Fast
    $n = Wait-Notice $s.Id 12
    if ($n -eq $Z) { T 'R' 'notice' $false 'no notification' } else { Start-Sleep -Milliseconds 800; Rm-Run 'R' 'notice' $s.Id $m0 }
    foreach ($i in @($Started)) { if (Test-Alive $i) { Close-Others $i; [void](Quit $i) } }
    Uc-Clear; Set-Env 'hang'
    $m0 = Req-Count
    $s = Start-Fast
    $got = Wait-Req ($m0 + 1) 8
    Start-Sleep -Milliseconds 500
    if (-not $got) { T 'R' 'hang' $false 'the request did not start' } else { Rm-Run 'R' 'hang' $s.Id $m0 }
}
# J: a version without the feature started with the values present (FR-026, stored-state rule 6, quickstart E)
$Groups['J'] = {
    if (-not (Test-Path -LiteralPath $OldExe)) { ND 'J' 'old' ('no older program at ' + $OldExe); return }
    $ver = (Get-Item -LiteralPath $OldExe).VersionInfo.ProductVersion
    Clear-Env
    Uc-Set 'Check At Startup' 0 'DWord'; Uc-Set 'Last Attempt' (FtAt -30) 'QWord'; Uc-Set 'Last Attempt Answered' 1 'DWord'; Uc-Set 'Last Success' (FtAt -30) 'QWord'
    Uc-Set 'Latest Version' '0.1.9' 'String'; Uc-Set 'Latest Published' '2026-10-14T08:00:00Z' 'String'; Uc-Set 'Skipped Version' '0.1.9' 'String'
    $st0 = Uc-Str
    $s = Start-Fast $OldExe; $resp = Alive-Main $s.Id
    $w = Watch-Wins $s.Id 4
    Close-Others $s.Id
    $q = Quit $s.Id
    T 'J' 'old' ($resp -and $q.Code -eq '0x00000000' -and (Uc-Str) -eq $st0) ('{0} (product version {1}) started with the Update Check values present: answers {2}; windows {3}; {4}; values unchanged {5}' -f $OldExe, $ver, $resp, $(if ($w.Count) { $w -join ' || ' } else { 'none' }), (QStr $q), ((Uc-Str) -eq $st0))
}
# S2: start-up time with the option on / off / server unreachable / server silent (SC-002, C17)
$Groups['S2'] = {
    $res = [ordered]@{}
    foreach ($variant in 'off', 'on-same', 'on-dead', 'on-hang') {
        $tm = @(); $tu = @()
        for ($i = 0; $i -lt $TimeRuns; $i++) {
            Uc-Clear
            if ($variant -eq 'off') { Uc-Set 'Check At Startup' 0 'DWord'; Set-Env 'same' } elseif ($variant -eq 'on-same') { Set-Env 'same' } elseif ($variant -eq 'on-dead') { Set-Env 'DEAD' } else { Set-Env 'hang' }
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $s = Start-Fast
            [void](Alive-Main $s.Id)
            $tu += $sw.Elapsed.TotalSeconds; $tm += $s.TMain
            Start-Sleep -Milliseconds 300
            Close-Others $s.Id; [void](Quit $s.Id)
        }
        $sorted = @($tu | Sort-Object); $med = $sorted[[int][Math]::Floor($sorted.Count / 2)]
        $sm = @($tm | Sort-Object); $medm = $sm[[int][Math]::Floor($sm.Count / 2)]
        $res[$variant] = @($med, $medm, ($tu | Measure-Object -Minimum).Minimum, ($tu | Measure-Object -Maximum).Maximum)
    }
    $base = $res['off'][0]
    $worst = 0.0; foreach ($k in $res.Keys) { $d = $res[$k][0] - $base; if ($d -gt $worst) { $worst = $d } }
    T 'S2' 'sc002' ($worst -le [Math]::Max(0.25, $base * 0.15)) (('{0} starts each; seconds from process start to a main window that answers (median; visible median; min..max): ' -f $TimeRuns) + (@($res.Keys | ForEach-Object { '{0} {1}; {2}; {3}..{4}' -f $_, (S2 $res[$_][0]), (S2 $res[$_][1]), (S2 $res[$_][2]), (S2 $res[$_][3]) }) -join ' | ') + ('; largest median difference to "off": {0} s (limit: 15 % or 0.25 s)' -f (S2 $worst)))
}
# ND: promises that cannot be driven on a hidden desktop or with this build tree
$Groups['ND'] = {
    ND 'ND' 'activ' 'contracts/ui.md 1 Showing 3: activation only when the main window is the foreground window, the command line is empty and no input for 2 s - there is no foreground window and no input on a hidden desktop'
    ND 'ND' 'typing' 'edge case: the notification never takes the keyboard away from text being typed - needs a real keyboard'
    ND 'ND' 'menu' 'contracts/ui.md 1 Showing 1: never while a menu is open - a menu cannot be held open with posted messages; FR-019 placement of the command in the Help menu (the menu bar is a custom control without an HMENU) - only the command id 2217 was driven'
    ND 'ND' 'dpi' 'SC-009: 150 % / 200 % scaling, the maintainer''s acceptance of the design - captures at the desktop''s scaling only'
    ND 'ND' 'https' 'FR-004: TLS, certificate and host verification, proxy behaviour - the Debug seam is plain HTTP on the loopback interface; the real endpoint was not contacted'
    ND 'ND' 'browsr' 'US1-2: the default browser really starts the download - the seam logs the address instead'
    ND 'ND' 'clip' 'edge case "the address can be copied": pressing Yes in the "could not be opened" message (row H5) - the clipboard is shared with the user''s desktop'
    ND 'ND' 'narr' 'screen reader pass - only UI Automation names were read (rows A1 names, F1 dl, G1 box)'
}
# ---- run -------------------------------------------------------------------------------
$RunSw = [Diagnostics.Stopwatch]::StartNew()
$repBefore = @(Reports)
$existed = Backup-Reg $RegFile
$failCount = 0
try {
    Out ('Feature 123 behaviour probe; exe ' + $Exe + ' (' + (Get-Item -LiteralPath $Exe).LastWriteTime.ToString('s') + '); desktop ' + [DeskLib098]::Name() + '; ' + (Get-Date).ToString('s'))
    Start-Server
    Out ("fixture server on 127.0.0.1:$Port; dead port $DeadPort; UI Automation available: $UiaOk; old exe: $OldExe")
    $names = @($Groups.Keys)
    foreach ($g in $names) {
        $sel = ($Only.Count -eq 0) -or ($g -eq 'BASE') -or (@($Only | Where-Object { $g -like $_ }).Count -gt 0)
        if (-not $sel) { continue }
        if ($RunSw.Elapsed.TotalMinutes -gt $MaxMinutes) { Row $g 'TIME' 'ERROR' ('not run: the probe''s time limit of ' + $MaxMinutes + ' min is over'); continue }
        $script:AnyDialogIsMsg = $false
        Out ('--- ' + $g)
        $gsw = [Diagnostics.Stopwatch]::StartNew()
        try { Reset-Base; & $Groups[$g] }
        catch { Row $g 'ERR' 'ERROR' ('probe exception: ' + $_.Exception.Message + ' at ' + $_.InvocationInfo.ScriptLineNumber + ': ' + (Norm $_.InvocationInfo.Line)) }
        finally {
            foreach ($i in @($Started)) { if (Test-Alive $i) { Out ("   (cleanup: pid $i still running after group $g - windows: " + (@((Other-Wins $i) | ForEach-Object { Desc $_ }) -join ' || ') + ')'); try { Kill-Mine $i } catch { } } }
            Clear-Env
            foreach ($n in @((Reports) | Where-Object { $repBefore -notcontains $_ })) {
                $p = Join-Path $ReportDir $n
                $head = @(); try { $head = @(Get-Content -LiteralPath $p -TotalCount 60) } catch { }
                Row $g 'REPORT' 'FAIL' ('crash report created: ' + $n)
                foreach ($l in $head) { Out ('      | ' + $l) }
                Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            }
            if (-not (Test-Path "Registry::HKEY_CURRENT_USER\Software\Tandem Commander\0.1\Configuration")) {
                # group G2 removed the key: bring the user's configuration back for the next groups
                if ($existed) { & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"; & cmd.exe /c "reg import `"$RegFile`" >nul 2>&1" }
            }
            elseif ($g -eq 'G2' -and $existed) { & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"; & cmd.exe /c "reg import `"$RegFile`" >nul 2>&1" }
        }
        Out ('    (' + $g + ' took ' + [int]$gsw.Elapsed.TotalSeconds + ' s)')
    }
}
finally {
    foreach ($i in @($Started)) { if (Test-Alive $i) { try { Kill-Mine $i } catch { } } }
    Clear-Env
    try { Uc-Lock $false } catch { }
    Stop-Server
    $restored = Restore-Reg $RegFile $existed
    if (-not $restored) { Out 'REGISTRY RESTORE NOT VERIFIED - see above' }
    $pass = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $fail = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' -or $_.Verdict -eq 'ERROR' }).Count
    $nd = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ('TOTAL: {0} PASS, {1} FAIL, {2} NOT DRIVEN' -f $pass, $fail, $nd)
    foreach ($r in @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' -or $_.Verdict -eq 'ERROR' })) { Out ('   ' + $r.Verdict + ': ' + $r.Case + ' ' + $r.Step) }
    $failCount = $fail
    try { [IO.File]::WriteAllLines($Result, [string[]]@($script:Lines), (New-Object Text.UTF8Encoding($false))) } catch { Write-Host ('could not write ' + $Result + ': ' + $_.Exception.Message) }
}
exit $failCount
