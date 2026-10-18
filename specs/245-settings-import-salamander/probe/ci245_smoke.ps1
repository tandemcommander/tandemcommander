<#
.SYNOPSIS
    Feature 245 smoke run: a fresh configuration, one Altap 4.0 fixture, the default import
    (Add groups), the preview and the result written to -OutDir. Registry restored at the end.
    MUST run through tools\run_on_hidden_desktop.ps1.
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$OutDir
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ci245_lib.ps1')
. (Join-Path $PSScriptRoot 'ci245_fixtures.ps1')
if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$backup = Join-Path $OutDir 'tc_backup.reg'
$existed = Backup-TC $backup
$before = Get-RegDump $script:TCPS
try {
    Remove-Fixtures
    $r = New-TCConfig $Exe $OutDir
    Write-Output ("newcfg: exit=$($r.Exit) timeout=$($r.Timeout) windows=" + ($r.Windows -join ' ; '))
    $blobs = Get-Blobs $Exe $OutDir 'pa55word' 'Master!23'
    Write-Output ("blobs: " + (($blobs.Keys | ForEach-Object { "$_=$($blobs[$_].Length)" }) -join ' '))
    New-AltapFixture -Blobs $blobs | Out-Null
    $tcBefore = Get-RegDump $script:TCRoot
    $r = Invoke-TC $Exe "[import]`r`ngroups=defaults`r`n" $OutDir 'smoke1' 120
    Write-Output ("smoke1: exit=$($r.Exit) timeout=$($r.Timeout) windows=" + ($r.Windows -join ' ; '))
    Write-Output '--- preview'; Write-Output $r.Preview
    Write-Output '--- result'; Write-Output $r.Result
    Write-Output '--- error'; Write-Output $r.Error
    $tcAfter = Get-RegDump $script:TCRoot
    $tcBefore | Set-Content -LiteralPath (Join-Path $OutDir 'smoke1_before.txt') -Encoding UTF8
    $tcAfter | Set-Content -LiteralPath (Join-Path $OutDir 'smoke1_after.txt') -Encoding UTF8
}
finally {
    Remove-Fixtures
    Restore-TC $backup $existed
    $after = Get-RegDump $script:TCPS
    $same = (($before -join "`n") -eq ($after -join "`n"))
    Write-Output "registry restored: $same"
}
