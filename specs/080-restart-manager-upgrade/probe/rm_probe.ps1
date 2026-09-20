<#
.SYNOPSIS
    Issues the same close request an installer issues - through the Windows
    Restart Manager - against a running build of Tandem Commander, and
    optionally the same restart. No installer is built or run.

.DESCRIPTION
    Feature 080 (spec FR-002). Inno Setup closes applications that hold files
    it has to replace with exactly this sequence:

        RmStartSession -> RmRegisterResources(files) -> RmGetList
        -> RmShutdown(0) -> (install) -> RmRestart -> RmEndSession

    The probe performs it against ONE executable path and reports what the
    Restart Manager found, how long the shutdown took, whether the processes
    really ended, and whether they were started again.

    SAFETY: before it shuts anything down the probe checks that EVERY process
    the Restart Manager lists was started from the registered path. If the
    list contains anything else (Windows Explorer, another installation of
    the program) it stops without shutting down. It never uses
    RmForceShutdown unless -Force is given.

.PARAMETER ExePath
    Full path of the tandemcommander.exe whose running instances are the
    target. Only processes whose image is exactly this file are touched.

.PARAMETER InstallDir
    Alternative to -ExePath: register every *.exe, *.dll and *.chm below this
    directory - Inno Setup's default CloseApplicationsFilter - so the probe
    sees what the installer would see. Only processes whose image lies below
    this directory are touched.

.PARAMETER ListOnly
    Register and list, do not shut down.

.PARAMETER Restart
    After a successful shutdown call RmRestart and report the new processes.

.PARAMETER Force
    Pass RmForceShutdown (kills what does not close). Off by default; the
    installer does not use it.

.PARAMETER HoldSeconds
    Seconds to wait between the shutdown and the restart (the time an
    installer would spend replacing files). Default 2.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File rm_probe.ps1 `
        -ExePath E:\Projects\tandemcommander\build\tandemcommander\Release_x64\tandemcommander.exe -Restart

.NOTES
    Windows PowerShell 5.1 compatible (the sign_release.ps1 / publish.ps1
    tier). Exit code: 0 = every listed process ended (and, with -Restart,
    RmRestart succeeded); 1 = shutdown failed or processes survived;
    2 = refused for safety / nothing to do; 3 = usage or API error.
#>
[CmdletBinding()]
param(
    [string]$ExePath,
    [string]$InstallDir,
    [switch]$ListOnly,
    [switch]$Restart,
    [switch]$Force,
    [int]$HoldSeconds = 2
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class Rm080
{
    public const int CCH_RM_MAX_APP_NAME = 255;
    public const int CCH_RM_MAX_SVC_NAME = 63;
    public const int CCH_RM_SESSION_KEY = 32;

    [StructLayout(LayoutKind.Sequential)]
    public struct RM_UNIQUE_PROCESS
    {
        public int dwProcessId;
        public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct RM_PROCESS_INFO
    {
        public RM_UNIQUE_PROCESS Process;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_APP_NAME + 1)]
        public string strAppName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_SVC_NAME + 1)]
        public string strServiceShortName;
        public int ApplicationType;
        public uint AppStatus;
        public uint TSSessionId;
        [MarshalAs(UnmanagedType.Bool)]
        public bool bRestartable;
    }

    public delegate void RM_WRITE_STATUS_CALLBACK(uint nPercentComplete);

    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    public static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, System.Text.StringBuilder strSessionKey);

    [DllImport("rstrtmgr.dll")]
    public static extern int RmEndSession(uint dwSessionHandle);

    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    public static extern int RmRegisterResources(uint dwSessionHandle, uint nFiles, string[] rgsFilenames,
        uint nApplications, IntPtr rgApplications, uint nServices, string[] rgsServiceNames);

    [DllImport("rstrtmgr.dll")]
    public static extern int RmGetList(uint dwSessionHandle, out uint pnProcInfoNeeded, ref uint pnProcInfo,
        [In, Out] RM_PROCESS_INFO[] rgAffectedApps, out uint lpdwRebootReasons);

    [DllImport("rstrtmgr.dll")]
    public static extern int RmShutdown(uint dwSessionHandle, uint lActionFlags, RM_WRITE_STATUS_CALLBACK fnStatus);

    [DllImport("rstrtmgr.dll")]
    public static extern int RmRestart(uint dwSessionHandle, int dwRestartFlags, RM_WRITE_STATUS_CALLBACK fnStatus);
}
'@

function Get-ImagePath([int]$ProcessId) {
    try { return (Get-Process -Id $ProcessId -ErrorAction Stop).Path } catch { return $null }
}

function Get-RmList([uint32]$Session) {
    [uint32]$needed = 0
    [uint32]$count = 0
    [uint32]$reasons = 0
    $rc = [Rm080]::RmGetList($Session, [ref]$needed, [ref]$count, $null, [ref]$reasons)
    if ($rc -eq 0 -and $needed -eq 0) { return , @() }
    if ($rc -ne 234 -and $rc -ne 0) { throw "RmGetList (size query) failed: $rc" }   # 234 = ERROR_MORE_DATA
    $arr = New-Object 'Rm080+RM_PROCESS_INFO[]' ([int]$needed)
    $count = $needed
    $rc = [Rm080]::RmGetList($Session, [ref]$needed, [ref]$count, $arr, [ref]$reasons)
    if ($rc -ne 0) { throw "RmGetList failed: $rc" }
    $script:RebootReasons = $reasons
    return , @($arr | Select-Object -First ([int]$count))
}

$appTypes = @{ 0 = 'RmUnknownApp'; 1 = 'RmMainWindow'; 2 = 'RmOtherWindow'; 3 = 'RmService'; 4 = 'RmExplorer'; 5 = 'RmConsole'; 1000 = 'RmCritical' }

if ([bool]$ExePath -eq [bool]$InstallDir) { Write-Host "ERROR: give exactly one of -ExePath, -InstallDir"; exit 3 }
if ($ExePath) {
    if (-not (Test-Path -LiteralPath $ExePath)) { Write-Host "ERROR: not found: $ExePath"; exit 3 }
    $ExePath = (Resolve-Path -LiteralPath $ExePath).Path
    $files = [string[]]@($ExePath)
    $root = $null
}
else {
    if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) { Write-Host "ERROR: not a directory: $InstallDir"; exit 3 }
    $root = (Resolve-Path -LiteralPath $InstallDir).Path.TrimEnd('\') + '\'
    $files = [string[]]@(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -match '^\.(exe|dll|chm)$' } | ForEach-Object FullName)
    if ($files.Count -eq 0) { Write-Host "ERROR: no *.exe/*.dll/*.chm below $root"; exit 3 }
}

# TRUE when the image is one the probe is allowed to shut down
function Test-Own([string]$Image) {
    if (-not $Image) { return $false }
    if ($root) { return $Image.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) }
    return ($Image -ieq $ExePath)
}

$session = [uint32]0
$key = New-Object System.Text.StringBuilder 64
$rc = [Rm080]::RmStartSession([ref]$session, 0, $key)
if ($rc -ne 0) { Write-Host "ERROR: RmStartSession failed: $rc"; exit 3 }

function Invoke-Probe {
$exit = 3
try {
    $rc = [Rm080]::RmRegisterResources($session, [uint32]$files.Count, $files, 0, [IntPtr]::Zero, 0, $null)
    if ($rc -ne 0) { throw "RmRegisterResources failed: $rc" }

    $list = Get-RmList $session
    if ($root) { Write-Host ("Registered : {0} file(s) below {1}" -f $files.Count, $root) } else { Write-Host ("Registered : {0}" -f $ExePath) }
    Write-Host ("Affected   : {0} process(es), reboot reasons: {1}" -f $list.Count, $script:RebootReasons)
    $foreign = $false
    $pids = @()
    foreach ($p in $list) {
        $img = Get-ImagePath $p.Process.dwProcessId
        $own = Test-Own $img
        if (-not $own) { $foreign = $true }
        $pids += $p.Process.dwProcessId
        Write-Host ("  pid {0,-6} {1,-14} restartable={2,-5} status=0x{3:X} own={4}  '{5}'  {6}" -f `
                $p.Process.dwProcessId, $appTypes[[int]$p.ApplicationType], $p.bRestartable, $p.AppStatus, $own, $p.strAppName, $img)
    }

    if ($list.Count -eq 0) { Write-Host "Nothing is using the file - nothing to do."; return 2 }
    if ($foreign) { Write-Host "REFUSED: the list contains a process that was not started from the registered location."; return 2 }
    if ($ListOnly) { return 0 }

    $flags = [uint32]0
    if ($Force) { $flags = 1 }   # RmForceShutdown
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $rc = [Rm080]::RmShutdown($session, $flags, $null)
    $sw.Stop()
    $names = @{ 0 = 'ERROR_SUCCESS'; 351 = 'ERROR_FAIL_SHUTDOWN'; 1223 = 'ERROR_CANCELLED'; 121 = 'ERROR_SEM_TIMEOUT' }
    $rcName = $names[[int]$rc]; if (-not $rcName) { $rcName = '?' }
    Write-Host ("RmShutdown : {0} ({1}) after {2:N1} s" -f $rc, $rcName, $sw.Elapsed.TotalSeconds)

    $alive = @()
    foreach ($id in $pids) { if (Get-Process -Id $id -ErrorAction SilentlyContinue) { $alive += $id } }
    if ($alive.Count -gt 0) { Write-Host ("Survivors  : {0}" -f ($alive -join ', ')) } else { Write-Host "Survivors  : none - every listed process ended" }

    $after = Get-RmList $session
    foreach ($p in $after) {
        Write-Host ("  after: pid {0} status=0x{1:X} restartable={2}" -f $p.Process.dwProcessId, $p.AppStatus, $p.bRestartable)
    }

    if ($rc -ne 0 -or $alive.Count -gt 0) { return 1 }
    $exit = 0

    if ($Restart) {
        Start-Sleep -Seconds $HoldSeconds
        $before = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { Test-Own $_.Path } | ForEach-Object Id)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $rc = [Rm080]::RmRestart($session, 0, $null)
        $sw.Stop()
        Write-Host ("RmRestart  : {0} after {1:N1} s" -f $rc, $sw.Elapsed.TotalSeconds)
        Start-Sleep -Seconds 3
        $now = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { Test-Own $_.Path })
        $new = @($now | Where-Object { $before -notcontains $_.Id })
        if ($new.Count -gt 0) {
            foreach ($n in $new) { Write-Host ("Restarted  : pid {0}, started {1:HH:mm:ss}" -f $n.Id, $n.StartTime) }
        }
        else { Write-Host "Restarted  : nothing was started again" }
        if ($rc -ne 0) { $exit = 1 }
    }
}
catch {
    Write-Host ("ERROR: {0}" -f $_.Exception.Message)
    $exit = 3
}
finally {
    [void][Rm080]::RmEndSession($session)
}
return $exit
}

exit (Invoke-Probe)
