<#
.SYNOPSIS
    End-to-end check of feature 080: runs a real installer silently over a
    running per-user installation in a scratch folder - the unattended update
    a package manager performs - and reports what happened.

.DESCRIPTION
    Sequence:
      1. (optional) start <InstallDir>\tandemcommander.exe and let it settle
      2. run the installer with the switches winget passes to an Inno Setup
         package, plus /CURRENTUSER and /DIR so nothing outside the scratch
         folder and HKCU is touched and no elevation is needed:
             /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /CURRENTUSER
             /NOICONS /DIR=<InstallDir> /LOG=<log>
      3. print the exit code, the Restart Manager lines of the log and the
         log's tail
      4. report which processes run from <InstallDir> afterwards (closed?
         restarted? same pid = never closed)

    The probe never touches a process that does not run from <InstallDir>.

.PARAMETER Installer
    The setup executable to run.

.PARAMETER InstallDir
    The scratch installation directory (/DIR).

.PARAMETER Start
    Number of instances to start from InstallDir before the installer runs
    (default 1; 0 = use whatever is already running).

.PARAMETER SettleSeconds
    Seconds to wait after starting the program (default 8).

.PARAMETER ExtraArgs
    Additional installer switches, e.g. /NORESTARTAPPLICATIONS.

.PARAMETER Log
    Installer log path. Default: <InstallDir>\..\upgrade-<timestamp>.log

.NOTES
    Windows PowerShell 5.1 compatible. Exit code = the installer's exit code.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Installer,
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [int]$Start = 1,
    [int]$SettleSeconds = 8,
    [string[]]$ExtraArgs = @(),
    [string]$Log
)

$ErrorActionPreference = 'Stop'

$InstallDir = $InstallDir.TrimEnd('\')
$exe = Join-Path $InstallDir 'tandemcommander.exe'
if (-not (Test-Path -LiteralPath $Installer)) { Write-Host "ERROR: installer not found: $Installer"; exit 3 }
if (-not $Log) { $Log = Join-Path (Split-Path $InstallDir -Parent) ("upgrade-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date)) }

function Get-Own {
    @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($InstallDir + '\', [StringComparison]::OrdinalIgnoreCase) })
}

for ($i = 0; $i -lt $Start; $i++) {
    if (-not (Test-Path -LiteralPath $exe)) { Write-Host "ERROR: not installed: $exe"; exit 3 }
    $p = Start-Process -FilePath $exe -PassThru
    Write-Host ("Started    : pid {0}" -f $p.Id)
    Start-Sleep -Seconds 2
}
if ($Start -gt 0) { Start-Sleep -Seconds $SettleSeconds }

$before = Get-Own
Write-Host ("Before     : {0}" -f (($before | ForEach-Object { "{0}:{1}" -f $_.ProcessName, $_.Id }) -join ', '))

$argList = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/CURRENTUSER', '/NOICONS', "/DIR=$InstallDir", "/LOG=$Log") + $ExtraArgs
$sw = [Diagnostics.Stopwatch]::StartNew()
$inst = Start-Process -FilePath $Installer -ArgumentList $argList -Wait -PassThru
$sw.Stop()
Write-Host ("EXIT CODE  : {0}   ({1:N1} s)   log: {2}" -f $inst.ExitCode, $sw.Elapsed.TotalSeconds, $Log)

if (Test-Path -LiteralPath $Log) {
    $lines = Get-Content -LiteralPath $Log
    Write-Host "--- Restart Manager / close / restart lines ---"
    $lines | Where-Object { $_ -match 'RestartManager|Restart Manager|shut down|Shutting down|applications|Defaulting to|Abort|in use|Restarting|restart the' } | ForEach-Object { Write-Host ("  " + $_) }
    Write-Host "--- tail ---"
    $lines | Select-Object -Last 6 | ForEach-Object { Write-Host ("  " + $_) }
}

Start-Sleep -Seconds 5
$after = Get-Own
$beforeIds = @($before | ForEach-Object Id)
foreach ($a in $after) {
    $kind = 'NEW (restarted)'
    if ($beforeIds -contains $a.Id) { $kind = 'SAME pid - never closed' }
    Write-Host ("After      : {0}:{1}  {2}" -f $a.ProcessName, $a.Id, $kind)
}
if ($after.Count -eq 0) { Write-Host "After      : nothing runs from the installation folder" }
exit $inst.ExitCode
