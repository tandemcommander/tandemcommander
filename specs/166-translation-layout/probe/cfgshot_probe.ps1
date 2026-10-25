<#
.SYNOPSIS
    Feature 166 probe: a picture of a translated dialog as the program draws it - evidence for the
    clipped labels layout_check.py measures (Configuration > Viewer in Czech: "Velikost
    tabulatoru:" 90 px of 57, "Vynutit sestnactkovy rezim pro soubory:" 188 px of 145).

.DESCRIPTION
    Starts the program in -Lang, sets Configuration\Last Focused Page = -Page (22 = Viewer),
    opens Configuration (command 686), captures the dialog (PrintWindow, works on a hidden
    desktop) into -Png, cancels. A person (or the agent) looks at the picture.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored, verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string]$Lang = 'czech',
    [int]$Page = 22,
    [Parameter(Mandatory = $true)][string]$Png
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\124-regedt-key-text\probe\shotocr_lib.ps1')
$Root = $TempRoot + '\tc166'
$StartDir = $Root + '\start'
$backup = Join-Path $env:TEMP 'tc166_backup.reg'
$existed = Backup-Reg $backup
$restored = $false
try {
    NewDir $StartDir
    Set-Config
    & reg.exe add "$RegKey\Settings\Configuration" /v 'Language' /t REG_SZ /d ($Lang + '.slg') /f | Out-Null
    & reg.exe add "$RegKey\Settings\Configuration" /v 'Last Focused Page' /t REG_DWORD /d $Page /f | Out-Null
    $id = Start-Tc $StartDir
    $dlg = Open-ByCmd $id 686 15
    if ($dlg -eq [IntPtr]::Zero) { Row 'SHOT' 'PNG' 'NOT DRIVEN' 'Configuration opened no window' }
    else {
        Start-Sleep -Milliseconds 1500
        $ok = [Shot124]::Capture($dlg, $Png)
        Row 'SHOT' 'PNG' $(if ($ok) { 'PASS' } else { 'FAIL' }) ("{0} page {1}: '{2}' captured {3} -> {4}" -f $Lang, $Page, (Esc ([Drv098f]::Txt($dlg))), $ok, $Png)
        Close-Win $dlg
    }
    End-Row 'SHOT' $id $null (Reports)
}
catch { Row 'SHOT' 'ERROR' 'FAIL' ($_.Exception.Message) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    Out ("Registry restored+identical: {0}" -f $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
