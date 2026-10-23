<#
.SYNOPSIS
    Feature 325: runs the TAR / cpio probes of features 306, 308, 309, 310 and 321 one after another on
    the hidden desktop against one build; each result goes to regress_<probe>.txt next to this script.
    Run from the repository root: powershell -File specs\325-tar-listed-hard-links\probe\run_regress.ps1 -Exe <exe>
#>
param([Parameter(Mandatory = $true)][string]$Exe, [string]$Label = 'regress325')
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = (Resolve-Path (Join-Path $Here '..\..\..')).Path
$probes = @(
    'specs\306-tar-pax-headers\probe\pax306_probe.ps1',
    'specs\308-pax-deep-unpack\probe\unp308_probe.ps1',
    'specs\309-tar-link-members\probe\link309_probe.ps1',
    'specs\310-cpio-link-members\probe\cpio310_probe.ps1',
    'specs\321-tar-long-component\probe\tar321_probe.ps1',
    'specs\321-tar-long-component\probe\unp321_probe.ps1'
)
foreach ($p in $probes) {
    $full = Join-Path $Repo $p
    $name = [IO.Path]::GetFileNameWithoutExtension($full)
    $out = Join-Path $Here ('regress_' + $name + '.txt')
    $log = Join-Path $Here ('log_regress_' + $name + '.txt')
    & powershell -File (Join-Path $Repo 'tools\run_on_hidden_desktop.ps1') -Log $log -CommandLine ("powershell -NoProfile -ExecutionPolicy Bypass -File {0} -Exe {1} -Label {2} -OutFile {3}" -f $full, $Exe, $Label, $out) | Out-Null
    $rows = '(no result)'
    if (Test-Path -LiteralPath $out) { $rows = (Get-Content -LiteralPath $out | Where-Object { $_ -like 'Rows:*' }) -join ' ' }
    Write-Output ('{0}: exit {1}; {2}' -f $name, $LASTEXITCODE, $rows)
}
