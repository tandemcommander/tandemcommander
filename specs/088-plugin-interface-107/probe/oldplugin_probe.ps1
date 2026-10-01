<#
.SYNOPSIS
    Feature 088, SC-005 / contract B3: a plug-in BUILT FOR AN OLDER INTERFACE
    in the new program.

.DESCRIPTION
    Makes a private copy of a built program tree under %TEMP%, replaces one
    plug-in folder in it by the same plug-in from an installed older version
    (interface 106 or older), and runs the two probes of this feature against
    the copy. Nothing in the build tree or in the installation is changed.

    Expected with PictView of 0.1.8 (interface 106):
      longpath_probe  L1 PASS  (the old plug-in loads and opens a picture)
                      L2-L4 FAIL as "title did not change" - the names do
                      not fit the 260 bytes its header promised, so the core
                      steps over them (contract B3) - and L9 PASS: the
                      process is alive, no run-time check, no crash
      viewers_probe   P3 FAIL as "declined": the old plug-in does not
                      declare its window, so the program still declines
                      (the behaviour of 0.1.8); P1 and R1 PASS

.PARAMETER Tree
    The built tree to copy (e.g. build\tandemcommander\Release_x64).

.PARAMETER OldPluginDir
    The plug-in folder of the older version (e.g.
    C:\Program Files\Tandem Commander\plugins\pictview).

.NOTES
    Windows PowerShell 5.1 compatible. The registry key of the program is
    exported before and compared after.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Tree,
    [Parameter(Mandatory = $true)][string]$OldPluginDir
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mix = Join-Path $env:TEMP 'tc088_mix'
if (Test-Path -LiteralPath $mix) { [System.IO.Directory]::Delete($mix, $true) }
Copy-Item -LiteralPath $Tree -Destination $mix -Recurse
$name = Split-Path -Leaf $OldPluginDir
$dst = Join-Path $mix "plugins\$name"
[System.IO.Directory]::Delete($dst, $true)
Copy-Item -LiteralPath $OldPluginDir -Destination $dst -Recurse
$spl = Get-ChildItem -LiteralPath $dst -Filter *.spl | Select-Object -First 1
"old plug-in: $($spl.Name) file version $($spl.VersionInfo.FileVersion), product $($spl.VersionInfo.ProductVersion)"

$before = Join-Path $env:TEMP 'tc088_old_before.reg'
$after = Join-Path $env:TEMP 'tc088_old_after.reg'
& reg.exe export 'HKCU\Software\Tandem Commander' $before /y | Out-Null

$exe = Join-Path $mix 'tandemcommander.exe'
'--- longpath_probe'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'longpath_probe.ps1') -Exe $exe 2>$null |
    Select-String -Pattern '^L\d|^Failures'
'--- viewers_probe'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'viewers_probe.ps1') -Exe $exe 2>$null |
    Select-String -Pattern '^P\d|^N\d|^R\d|^Failures'

& reg.exe export 'HKCU\Software\Tandem Commander' $after /y | Out-Null
'registry identical: ' + ((Get-FileHash $before).Hash -eq (Get-FileHash $after).Hash)
'test processes left: ' + (@(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$mix*" }).Count)
[System.IO.Directory]::Delete($mix, $true)
