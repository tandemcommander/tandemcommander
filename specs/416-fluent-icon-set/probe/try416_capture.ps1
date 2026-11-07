<#
.SYNOPSIS
    Feature 416 experiment: which capture method sees the toolbars on the hidden desktop. Starts the
    program once, lists the visible child windows and saves PrintWindow captures (client-only, and
    client-only + render-full-content) of the main window into -OutDir. Registry backed up / restored.
    MUST run through tools\run_on_hidden_desktop.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot 'capture416_lib.ps1')
$Root = $TempRoot + '\tc416try'
$StartDir = $Root + '\start'
[void][IO.Directory]::CreateDirectory($OutDir)
$backup = Join-Path $env:TEMP 'tc416_backup.reg'
$existed = Backup-Reg $backup
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    $id = Start-Tc $StartDir
    $main = Get-Main $id
    foreach ($h in [Cap416]::Kids($main)) {
        if (-not [Cap416]::IsWindowVisible($h)) { continue }
        $r = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($h, [ref]$r)
        Out ("{0} cls '{1}' id {2} parent {3} rect {4},{5}-{6},{7}" -f $h, [Cap416]::Cls($h), [Cap416]::GetDlgCtrlID($h), [Cap416]::GetParent($h), $r.left, $r.top, $r.right, $r.bottom)
    }
    $a = [Cap416]::Capture($main, $false); Save-Png $a (Join-Path $OutDir 'main_client.png'); Out ('client-only: ' + [Cap416]::Stats($a))
    $b = [Cap416]::Capture($main, $true); Save-Png $b (Join-Path $OutDir 'main_full.png'); Out ('full-content: ' + [Cap416]::Stats($b))
    Stop-Tc $id
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
