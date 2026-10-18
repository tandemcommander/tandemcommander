<#
.SYNOPSIS
    Feature 245 diagnostic: what the first start of a fresh configuration shows (windows and their
    texts, once per second for 25 s). Registry exported and restored. Hidden desktop only.
#>
param([Parameter(Mandatory = $true)][string]$Exe, [Parameter(Mandatory = $true)][string]$OutDir)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ci245_lib.ps1')
. (Join-Path $PSScriptRoot 'ci245_fixtures.ps1')
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$backup = Join-Path $OutDir 'tc_backup.reg'
$existed = Backup-TC $backup
try {
    Remove-Fixtures
    New-AltapFixture | Out-Null
    if (Test-Path $script:TCPS) { Remove-Item -LiteralPath $script:TCPS -Recurse -Force }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Resolve-Path $Exe).Path
    $psi.UseShellExecute = $false
    $psi.EnvironmentVariables['TC_CFGIMPORT_TEST_ROOT'] = $script:FixRel
    $p = [System.Diagnostics.Process]::Start($psi)
    for ($s = 0; $s -lt 25; $s++) {
        Start-Sleep -Seconds 1
        Write-Output ("t=$s " + ([Win245]::TopWindows([uint32]$p.Id) -join ' ; '))
        Write-Output ("   cfg exists: " + (Test-Path "$script:TCRoot\Configuration"))
    }
    try { $p.Kill() } catch {}
}
finally {
    Remove-Fixtures
    Restore-TC $backup $existed
}
