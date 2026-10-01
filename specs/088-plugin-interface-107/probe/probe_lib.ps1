<#
.SYNOPSIS
    Shared helpers of the feature 088 probes (viewers_probe.ps1,
    longpath_probe.ps1). Dot-sourced, not run.

.DESCRIPTION
    Builds on the feature 080 drivers, which are called, not copied:
      specs/080-restart-manager-upgrade/probe/tc_drive.ps1  start / command / key / click / close
      specs/080-restart-manager-upgrade/probe/rm_probe.ps1  the installer's Restart Manager request

    What is added here: an in-process window enumerator restricted to ONE
    process id (so that windows can be polled while rm_probe runs), posting a
    WM_COMMAND to a plug-in viewer window of that pid, test-file generators,
    and the registry backup / restore of HKCU\Software\Tandem Commander.

    SAFETY: every function takes the pid of an instance the probe started
    itself; nothing enumerates or touches windows of another process. Only
    PostMessage is used - no SendInput, nothing that needs the foreground.

.NOTES
    Windows PowerShell 5.1 compatible.
#>

$ErrorActionPreference = 'Stop'

$script:ProbeDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Probe080 = Join-Path (Split-Path -Parent (Split-Path -Parent $script:ProbeDir)) '080-restart-manager-upgrade\probe'
$script:TcDrive = Join-Path $script:Probe080 'tc_drive.ps1'
$script:RmProbe = Join-Path $script:Probe080 'rm_probe.ps1'
$script:RegKey = 'HKCU\Software\Tandem Commander'
$script:MainClass = 'TandemCommanderMainWindowVer01'
$script:Started = New-Object System.Collections.ArrayList   # pids this run started

if (-not ('Drv088' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Drv088
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
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(2048); GetWindowTextW(h, s, 2048); return s.ToString(); }

    // visible top-level windows of ONE process
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
    public static uint PidOf(IntPtr h) { uint q; GetWindowThreadProcessId(h, out q); return q; }
}
'@
}

function Invoke-Drive([string[]]$a) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script:TcDrive @a
}

# ---- registry --------------------------------------------------------------

# Exports the configuration key. Returns $true when the key existed.
function Backup-TcRegistry([string]$File) {
    & cmd.exe /c "reg query `"$script:RegKey`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    & cmd.exe /c "reg export `"$script:RegKey`" `"$File`" /y >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "reg export failed" }
    return $true
}

# Deletes the key, imports the backup, exports again and compares line by line.
function Restore-TcRegistry([string]$File, [bool]$Existed) {
    & cmd.exe /c "reg delete `"$script:RegKey`" /f >nul 2>&1"
    if (-not $Existed) { Write-Host "Registry   : the key did not exist before - deleted"; return $true }
    & cmd.exe /c "reg import `"$File`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Write-Host "Registry   : IMPORT FAILED - restore by hand from $File"; return $false }
    $check = "$File.check"
    & cmd.exe /c "reg export `"$script:RegKey`" `"$check`" /y >nul 2>&1"
    $a = Get-Content -LiteralPath $File -Encoding Unicode
    $b = Get-Content -LiteralPath $check -Encoding Unicode
    $same = ($a.Count -eq $b.Count) -and (-not (Compare-Object $a $b -SyncWindow 0))
    $ha = (Get-FileHash -LiteralPath $File).Hash; $hb = (Get-FileHash -LiteralPath $check).Hash
    Write-Host ("Registry   : restored; {0} lines vs {1}; identical={2}; SHA-256 {3} / {4}" -f $a.Count, $b.Count, $same, $ha.Substring(0, 12), $hb.Substring(0, 12))
    Remove-Item -LiteralPath $check -Force
    return $same
}

# The test configuration: the maintainer's own (so the viewer associations are
# the real ones), English UI, no exit confirmation.
function Set-TestConfig {
    & cmd.exe /c "reg query `"$script:RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return }   # a fresh registry: the defaults are English already
    & reg.exe add "$script:RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
    & reg.exe add "$script:RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
}

# ---- process and windows ---------------------------------------------------

# Starts ONE instance. This is tc_drive.ps1's -Action start with one more
# argument: -p 1 makes the LEFT panel the active one (the stored
# configuration may have the right one active, and CM_VIEW acts on the
# active panel while the keys go to the left list).
function Start-Tc([string]$Exe, [string]$Dir, [string]$Prefix) {
    $a = @('-t', $Prefix, '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Dir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$script:Started.Add($p.Id)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Get-MainWnd $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 200 }
    if ((Get-MainWnd $p.Id) -eq [IntPtr]::Zero) { throw "the program did not show its main window" }
    Start-Sleep -Seconds 4   # let start-up finish (plug-ins, panels, icon readers)
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    return $p.Id
}

function Test-Alive([int]$Id) { return [bool](Get-Process -Id $Id -ErrorAction SilentlyContinue) }

# visible top-level windows of the pid as objects
function Get-Wins([int]$Id) {
    $r = @()
    foreach ($h in [Drv088]::Top([uint32]$Id)) {
        $r += [pscustomobject]@{ H = $h; Class = [Drv088]::Cls($h); Title = [Drv088]::Txt($h); Enabled = [Drv088]::IsWindowEnabled($h); Owner = [Drv088]::GetWindow($h, 4) }
    }
    return $r
}

function Format-Win($w) { return ("0x{0:X} class='{1}' title='{2}'" -f $w.H.ToInt64(), $w.Class, $w.Title) }

# text of the static controls and buttons of a dialog (for recording a prompt)
function Get-DialogText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv088]::Kids($H)) {
        $t = [Drv088]::Txt($c)
        if ($t) { $parts += ("[{0} id={1}] {2}" -f [Drv088]::Cls($c), [Drv088]::GetDlgCtrlID($c), ($t -replace "\s+", ' ')) }
    }
    return ($parts -join ' | ')
}

function Get-MainWnd([int]$Id) {
    foreach ($h in [Drv088]::Top([uint32]$Id)) { if ([Drv088]::Cls($h) -eq $script:MainClass) { return $h } }
    return [IntPtr]::Zero
}
# The same messages tc_drive.ps1 posts for -Action command / key, posted
# in-process (one PowerShell child per key made a scenario take minutes).
function Send-MainCommand([int]$Id, [int]$Cmd, [int]$WaitMs = 700) {
    $m = Get-MainWnd $Id
    if ($m -eq [IntPtr]::Zero) { throw "no main window for pid $Id" }
    [void][Drv088]::PostMessageW($m, 0x0111, [IntPtr]$Cmd, [IntPtr]::Zero)   # WM_COMMAND
    Start-Sleep -Milliseconds $WaitMs
}
function Send-PanelKey([int]$Id, [int]$Vk) {
    $m = Get-MainWnd $Id
    $lists = @([Drv088]::Kids($m) | Where-Object { [Drv088]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv088]::IsWindowVisible($_) })
    if ($lists.Count -lt 1) { throw 'panel list window not found' }
    [void][Drv088]::PostMessageW($lists[0], 0x0100, [IntPtr]$Vk, [IntPtr]1)            # WM_KEYDOWN
    [void][Drv088]::PostMessageW($lists[0], 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)   # WM_KEYUP
    Start-Sleep -Milliseconds 150
}

# WM_COMMAND to a window that belongs to the pid (checked)
function Send-WndCommand([int]$Id, [IntPtr]$H, [int]$Cmd) {
    if ([Drv088]::PidOf($H) -ne [uint32]$Id) { throw "window does not belong to pid $Id" }
    [void][Drv088]::PostMessageW($H, 0x0111, [IntPtr]$Cmd, [IntPtr]::Zero)
}
function Close-Wnd([int]$Id, [IntPtr]$H) {
    if ([Drv088]::PidOf($H) -ne [uint32]$Id) { return }
    [void][Drv088]::PostMessageW($H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
}

# waits until a visible top-level window not in $Known appears; returns it or $null
function Wait-NewWin([int]$Id, $Known, [double]$Seconds = 8) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($w in (Get-Wins $Id)) { if ($Known -notcontains $w.H) { return $w } }
        Start-Sleep -Milliseconds 150
    }
    return $null
}

# Opens the viewer on the file named $Name in the left (active) panel:
# Home, k x Down, CM_VIEW (742), for k = 0.. until a window whose title
# contains the name appears. Wrong windows are closed again.
# Returns the window object or $null.
function Open-Viewer([int]$Id, [string]$Name, [int]$MaxItems = 8) {
    foreach ($k in (@(1..$MaxItems) + 0)) {   # 0 is normally the ".." entry: tried last
        $known = @((Get-Wins $Id) | ForEach-Object { $_.H })
        Send-PanelKey $Id 0x24                                   # VK_HOME
        for ($i = 0; $i -lt $k; $i++) { Send-PanelKey $Id 0x28 } # VK_DOWN
        Send-MainCommand $Id 742                                 # CM_VIEW
        $w = Wait-NewWin $Id $known 3
        if ($w) {
            # the title is set when the file is loaded; give it a moment
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 5) {
                $t = [Drv088]::Txt($w.H)
                if ($t -like "*$Name*") { Start-Sleep -Milliseconds 800; return [pscustomobject]@{ H = $w.H; Class = $w.Class; Title = $t } }
                Start-Sleep -Milliseconds 200
            }
            Close-Wnd $Id $w.H
            Start-Sleep -Milliseconds 800
        }
    }
    return $null
}

# ---- the installer's request, with the screen watched meanwhile ------------

# Runs rm_probe.ps1 -ExePath <exe> as a child process and polls the visible
# top-level windows of the pid until it returns. Returns exit code, the
# RmShutdown line, the seconds, every window that was NOT there before, and
# what is left.
function Invoke-RmWatched([string]$Exe, [int]$Id) {
    $before = @((Get-Wins $Id) | ForEach-Object { $_.H })
    $out = [IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $script:RmProbe), '-ExePath', ('"{0}"' -f $Exe)) `
        -RedirectStandardOutput $out -PassThru -WindowStyle Hidden
    $null = $p.Handle   # keeps the exit code readable after the child ended
    $new = @{}
    while (-not $p.HasExited) {
        foreach ($w in (Get-Wins $Id)) {
            if ($before -notcontains $w.H -and -not $new.ContainsKey($w.H)) { $new[$w.H] = (Format-Win $w) + ' :: ' + (Get-DialogText $w.H) }
        }
        Start-Sleep -Milliseconds 30
    }
    $p.WaitForExit()
    $text = Get-Content -LiteralPath $out
    Remove-Item -LiteralPath $out -Force
    $line = ($text | Where-Object { $_ -match '^RmShutdown' } | Select-Object -First 1)
    $secs = $null
    if ($line -match 'after ([\d\.,]+) s') { $secs = [double]($Matches[1] -replace ',', '.') }
    # a process that agreed may need a moment after RmShutdown returned
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if ($p.ExitCode -eq 0) { while ($sw.Elapsed.TotalSeconds -lt 5 -and (Test-Alive $Id)) { Start-Sleep -Milliseconds 100 } }
    $alive = Test-Alive $Id
    $left = @(); if ($alive) { $left = Get-Wins $Id }
    return [pscustomobject]@{ Exit = $p.ExitCode; Line = $line; Seconds = $secs; Shown = @($new.Values); Alive = $alive; Left = $left; Output = $text }
}

# Ends an instance the probe started: first the ordinary way (any prompt is
# answered Yes / closed), then by pid.
function Stop-Tc([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    if ($script:Started -notcontains $Id) { throw "pid $Id was not started by this probe" }
    foreach ($w in (Get-Wins $Id)) { if ($w.Class -eq '#32770') { Close-Wnd $Id $w.H } }
    Start-Sleep -Milliseconds 500
    foreach ($w in (Get-Wins $Id)) { if ($w.Class -ne $script:MainClass) { Close-Wnd $Id $w.H } }
    Start-Sleep -Milliseconds 800
    Invoke-Drive @('-Action', 'close', '-ProcessId', $Id) | Out-Null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 8 -and (Test-Alive $Id)) {
        foreach ($w in (Get-Wins $Id)) {
            if ($w.Class -eq '#32770') {
                $yes = [Drv088]::Kids($w.H) | Where-Object { [Drv088]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1   # IDYES
                if ($yes) { [void][Drv088]::PostMessageW($yes, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
            }
        }
        Start-Sleep -Milliseconds 300
    }
    if (Test-Alive $Id) { Stop-Process -Id $Id -Force; Start-Sleep -Milliseconds 500 }
}

function Stop-AllStarted { foreach ($id in @($script:Started)) { try { Stop-Tc $id } catch { Write-Host "  (stop $id : $($_.Exception.Message))" } } }

# ---- test files ------------------------------------------------------------

function New-Png([string]$Path, [int]$W = 48, [int]$H = 32, [string]$Color = 'SteelBlue') {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromName($Color)); $g.Dispose()
    $ms = New-Object IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    [IO.File]::WriteAllBytes($Path, $ms.ToArray()); $ms.Dispose()   # File API: works with a \\?\ path
}

function New-Csv([string]$Path, [string]$Tag = 'x') {
    [IO.File]::WriteAllText($Path, "id,name,value`r`n1,$Tag-alpha,10`r`n2,$Tag-beta,20`r`n3,$Tag-gamma,30`r`n", [Text.Encoding]::ASCII)
}

# Posts WM_COMMAND $Cmd to the viewer window (and, when nothing appears, to
# its child windows - PictView handles its commands in the frame, but that is
# not assumed) and waits for a new visible top-level window. Returns it or $null.
function Open-ViewerDialog([int]$Id, [IntPtr]$Viewer, [int]$Cmd) {
    $known = @(Get-Wins $Id | ForEach-Object { $_.H })
    Send-WndCommand $Id $Viewer $Cmd
    $w = Wait-NewWin $Id $known 3
    if ($w) { return $w }
    foreach ($c in [Drv088]::Kids($Viewer)) {
        Send-WndCommand $Id $c $Cmd
        $w = Wait-NewWin $Id $known 1
        if ($w) { return $w }
    }
    return $null
}
