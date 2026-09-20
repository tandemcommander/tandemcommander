<#
.SYNOPSIS
    Quickstart V8 (spec SC-006): the configuration stored by a close for an
    update must be equivalent to the one stored by a manual exit from the
    same state.

.DESCRIPTION
    Twice, from the SAME starting configuration (the given .reg backup is
    imported before each run):

      start the program on two known folders, open two more tabs in the left
      panel, step one tab back -> close it
         run 1: by hand   (WM_CLOSE to the main window = the ordinary exit)
         run 2: through the Restart Manager (rm_probe.ps1, the installer's request)

    After each run the configuration key is exported; the two exports are
    compared value by value and every difference is printed.

    WARNING: replaces HKCU\Software\Tandem Commander with the given backup
    (twice) and leaves the state of run 2 behind. Restore your own
    configuration afterwards (quickstart section 9).

.PARAMETER Exe
    tandemcommander.exe of the build under test.
.PARAMETER Backup
    .reg export of HKCU\Software\Tandem Commander used as the common start.
.PARAMETER Left
.PARAMETER Right
    Two existing folders.
.PARAMETER OutDir
    Where the two exports are written.
.PARAMETER SaveOnExit
    1 (default) or 0: the value of "Save Configuration On Exit" forced into
    the starting configuration.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$Backup,
    [Parameter(Mandatory = $true)][string]$Left,
    [Parameter(Mandatory = $true)][string]$Right,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [int]$SaveOnExit = 1
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$drive = Join-Path $here 'tc_drive.ps1'
$rm = Join-Path $here 'rm_probe.ps1'
$key = 'HKCU\Software\Tandem Commander'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Invoke-Ps([string]$file, [string[]]$a) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $file @a
}

function Reset-Config {
    # reg.exe reports success on stderr, which Windows PowerShell turns into an error record
    & cmd.exe /c "reg delete `"$key`" /f >nul 2>&1"
    & cmd.exe /c "reg import `"$Backup`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "reg import failed: $Backup" }
    & reg.exe add "$key\0.1\Configuration" /v 'Save Configuration On Exit' /t REG_DWORD /d $SaveOnExit /f | Out-Null
    & reg.exe add "$key\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
}

function Start-Prepared {
    $id = (Invoke-Ps $drive @('-Action', 'start', '-Exe', $Exe, '-Left', $Left, '-Right', $Right, '-TitlePrefix', 'V8')) | Select-Object -Last 1
    foreach ($cmd in 2861, 2861, 2870) {   # CM_LEFT_NEWTAB x2, CM_LEFT_PREVTAB
        Invoke-Ps $drive @('-Action', 'command', '-ProcessId', $id, '-Id', $cmd) | Out-Null
    }
    Start-Sleep -Seconds 2
    return [int]$id
}

function Wait-Exit([int]$id) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Get-Process -Id $id -ErrorAction SilentlyContinue)) { Start-Sleep -Milliseconds 200 }
    if (Get-Process -Id $id -ErrorAction SilentlyContinue) { throw "pid $id did not exit" }
}

# run 1: the ordinary exit
Reset-Config
$id = Start-Prepared
Invoke-Ps $drive @('-Action', 'close', '-ProcessId', $id) | Out-Null
Wait-Exit $id
$manual = Join-Path $OutDir 'cfg-manual-exit.reg'
& reg.exe export "$key\0.1" $manual /y | Out-Null

# run 2: the installer's request
Reset-Config
$id = Start-Prepared
Invoke-Ps $rm @('-ExePath', $Exe) | Where-Object { $_ -match 'RmShutdown|Survivors' } | ForEach-Object { Write-Host $_ }
Wait-Exit $id
$closeapp = Join-Path $OutDir 'cfg-closeapp.reg'
& reg.exe export "$key\0.1" $closeapp /y | Out-Null

# compare value by value
function Read-Reg([string]$file) {
    $map = @{}
    $section = ''
    $pending = $null
    foreach ($line in (Get-Content -LiteralPath $file -Encoding Unicode)) {
        if ($null -ne $pending) { $pending += $line.TrimStart(); if ($pending.EndsWith('\')) { $pending = $pending.TrimEnd('\'); continue }; $line = $pending; $pending = $null }
        elseif ($line.EndsWith('\')) { $pending = $line.TrimEnd('\'); continue }
        if ($line -match '^\[(.+)\]$') { $section = $Matches[1]; continue }
        if ($line -match '^(@|".*?")=(.*)$') { $map["$section :: $($Matches[1])"] = $Matches[2] }
    }
    return $map
}
$a = Read-Reg $manual
$b = Read-Reg $closeapp
$keys = @($a.Keys) + @($b.Keys) | Sort-Object -Unique
$diff = 0
foreach ($k in $keys) {
    if ($a[$k] -ne $b[$k]) {
        $diff++
        $va = $a[$k]; if ($null -eq $va) { $va = '<absent>' }
        $vb = $b[$k]; if ($null -eq $vb) { $vb = '<absent>' }
        if ($va.Length -gt 70) { $va = $va.Substring(0, 70) + '...' }
        if ($vb.Length -gt 70) { $vb = $vb.Substring(0, 70) + '...' }
        Write-Host ("DIFF {0}`n     manual  : {1}`n     closeapp: {2}" -f $k.Replace('HKEY_CURRENT_USER\Software\Tandem Commander\0.1', ''), $va, $vb)
    }
}
Write-Host ("Values: manual {0}, closeapp {1}; differing: {2}" -f $a.Count, $b.Count, $diff)
exit $diff
