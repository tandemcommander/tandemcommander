<#
.SYNOPSIS
    Feature 126 (GitHub issue #6): the program's package lookup - now through functions resolved
    at run time - still answers what Windows itself reports on a supported system.

.DESCRIPTION
    For every installed package family that matches -Match (default: the packaged shells the
    presets know) "saltests.exe --package-path <family>" must print the InstallLocation that
    Get-AppxPackage reports for the family; for a family that does not exist it must print
    "(not found)" and return 1. Exit code = failed rows. No window is opened.

.PARAMETER SalTests   saltests.exe of the build under test
.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
param(
    [string]$SalTests = (Join-Path $PSScriptRoot '..\..\..\build\tandemcommander\Debug_x64\saltests\saltests.exe'),
    [string]$Match = 'WindowsTerminal|PowerShell|WindowsCalculator|Notepad',
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$SalTests = (Resolve-Path -LiteralPath $SalTests).Path
$lines = New-Object System.Collections.ArrayList
function Out([string]$s) { Write-Output $s; [void]$lines.Add($s) }
$fail = 0
Out ("package_live (feature 126): {0}" -f $SalTests)
Out ("Windows {0}; {1}" -f [Environment]::OSVersion.Version, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$pk = @(Get-AppxPackage | Where-Object { $_.PackageFamilyName -match $Match -and $_.InstallLocation -and -not $_.IsFramework } | Group-Object PackageFamilyName)
if (-not $pk.Count) { Out 'NOT DRIVEN: no matching package is installed on this machine' }
foreach ($g in $pk) {
    $family = $g.Name
    $expected = @($g.Group | ForEach-Object { $_.InstallLocation })
    $out = @(& $SalTests --package-path $family); $code = $LASTEXITCODE   # (a cut pipeline would lose the exit code)
    $got = $out[0]
    # the lookup returns the first package of the family; with several versions installed any of them is right
    $ok = ($code -eq 0) -and ($expected -contains $got)
    if (-not $ok) { $fail++ }
    Out ("{0}  {1}: program '{2}' (exit {3}); Windows: {4}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $family, $got, $code, ($expected -join ' | '))
}
$none = 'TandemCommander.NoSuchFamily126_0000000000000'
$out = @(& $SalTests --package-path $none); $code = $LASTEXITCODE; $got = $out[0]
$ok = ($code -eq 1) -and ($got -eq '(not found)')
if (-not $ok) { $fail++ }
Out ("{0}  {1}: program '{2}' (exit {3}); expected '(not found)', exit 1" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $none, $got, $code)
Out ("Rows failed: {0}" -f $fail)
if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$lines, (New-Object Text.ASCIIEncoding)) }
exit $fail
