# 077 probe: prove the running program loads the Visual C++ runtime from its
# own directory (application-local deployment), not from System32.
#
# Starts the exe, waits for the main window, reads the process module list,
# prints where each runtime module came from, closes the program (WM_CLOSE via
# CloseMainWindow) and prints RESULT: OK / FAIL (exit 0 / 1).
# Windows PowerShell 5.1 and pwsh 7 compatible, ASCII only.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Runtime = @('vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll', 'concrt140.dll')
)

$ErrorActionPreference = 'Stop'
function Fail([string]$m) { Write-Host "RESULT: FAIL - $m"; Cleanup; exit 1 }
function Cleanup {
    foreach ($n in 'tandemcommander', 'salmon') {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
            try { if (-not $_.CloseMainWindow()) { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } } catch { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
        }
    }
    Start-Sleep -Seconds 2
    foreach ($n in 'tandemcommander', 'salmon') {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
    }
}

if (-not (Test-Path -LiteralPath $Exe)) { Fail "exe not found: $Exe" }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$appDir = Split-Path $Exe
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Fail 'tandemcommander.exe is already running - stop it first' }

$p = Start-Process -FilePath $Exe -WorkingDirectory $appDir -PassThru
$deadline = (Get-Date).AddSeconds(30)
$ready = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $p.Refresh()
    if ($p.HasExited) { Fail 'process exited before showing its window (missing runtime?)' }
    if ($p.MainWindowHandle -ne 0) { $ready = $true; break }
}
if (-not $ready) { Fail 'main window did not appear within 30 s' }
Start-Sleep -Seconds 2

$modules = @(Get-Process -Id $p.Id).Modules
$ok = $true
foreach ($name in $Runtime) {
    $m = $modules | Where-Object { $_.ModuleName -ieq $name } | Select-Object -First 1
    if (-not $m) { Write-Host ("  {0,-20} NOT LOADED" -f $name); $ok = $false; continue }
    $fromApp = $m.FileName.StartsWith($appDir, [System.StringComparison]::OrdinalIgnoreCase)
    $ver = $m.FileVersionInfo.FileVersion
    Write-Host ("  {0,-20} {1}  (v{2})  {3}" -f $name, $m.FileName, $ver, $(if ($fromApp) { 'app-local' } else { 'NOT app-local' }))
    if (-not $fromApp) { $ok = $false }
}
Cleanup
if ($ok) { Write-Host 'RESULT: OK'; exit 0 } else { Write-Host 'RESULT: FAIL - a runtime module was missing or loaded from outside the application directory'; exit 1 }
