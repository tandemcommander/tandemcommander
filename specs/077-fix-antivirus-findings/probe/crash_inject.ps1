# 077 probe: prove crash reporting parity by injecting an unhandled fault.
#
# Starts the built tandemcommander.exe, attaches cdb, moves the instruction
# pointer of the thread that owns the main window to an unmapped/non-executable
# address, DETACHES before the fault is dispatched (with a debugger attached the
# filter registered by SetUnhandledExceptionFilter is never called), wakes the
# thread with a WM_NULL so it leaves GetMessage, and waits for the bug report
# (.TXT) that the application writes after salmon.exe has processed the crash.
#
#   -Target app     : rip = 0                          (fault in no module)
#   -Target plugin  : rip = image base of a loaded plugin module (header page,
#                     not executable -> access violation inside the plugin's
#                     address range; -PluginModule picks which, default zip.spl,
#                     falls back to the first loaded *.spl)
#
# Learned while building the harness (recorded in fix-log.md):
#   * an old report left in %LOCALAPPDATA%\Tandem Commander\ makes salmon offer
#     it at start-up while the application's main thread blocks in
#     SalmonCheckBugs - the injected fault then never executes. The probe
#     therefore moves every existing report aside (-Archive) before starting.
#   * salmon loads dbghelp.dll only from its own utils\ directory, which the
#     product does not ship, so no .DMP is ever produced (pre-existing, out of
#     scope); parity means the .TXT report.
#   * the faulting address is recorded as "execution address = 0x..." in the
#     report's "Information About Exception" section.
#
# Prints RESULT: OK / FAIL and exits 0 / 1. Closes salmon.exe (crash dialog)
# and any leftover tandemcommander.exe; moves the produced report to -Archive
# with the -Tag prefix. Windows PowerShell 5.1 and pwsh 7 compatible, ASCII.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('app', 'plugin')][string]$Target = 'app',
    [string]$PluginModule = 'zip.spl',
    [int]$TimeoutSec = 60,
    [int]$SettleSec = 5,
    [string]$Tag = 'run',
    [string]$Archive = (Join-Path $env:TEMP 'tc077-bugreports'),
    [string]$Cdb = 'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe'
)

$ErrorActionPreference = 'Stop'
Add-Type -Namespace TC077 -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
'@

function Cleanup {
    foreach ($n in 'salmon', 'tandemcommander') {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
            try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
}
function Fail([string]$m) { Write-Host "RESULT: FAIL - $m"; Cleanup; exit 1 }

if (-not (Test-Path -LiteralPath $Exe)) { Fail "exe not found: $Exe" }
if (-not (Test-Path -LiteralPath $Cdb)) { Fail "cdb not found: $Cdb" }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$bugDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Fail 'tandemcommander.exe is already running - stop it first' }
New-Item -ItemType Directory -Force -Path $Archive | Out-Null

# 1. move every existing report aside (see header)
if (Test-Path -LiteralPath $bugDir) {
    Get-ChildItem -LiteralPath $bugDir -File | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $Archive ('old-' + $_.Name)) -Force
        Write-Host ("probe: moved old report aside: {0}" -f $_.Name)
    }
}

# 2. start and wait for the main window + salmon. Plugins are loaded on demand
#    (the start-up auto-registration loads and unloads them again), so for the
#    plugin target the left panel is opened inside a small ZIP archive created
#    here: zip.spl then stays loaded for as long as the panel shows the archive.
$startArgs = @()
if ($Target -eq 'plugin' -and $PluginModule -ieq 'zip.spl') {
    $zipDir = Join-Path $Archive 'probe-archive'
    New-Item -ItemType Directory -Force -Path $zipDir | Out-Null
    $zipSrc = Join-Path $zipDir 'hello.txt'
    Set-Content -LiteralPath $zipSrc -Value 'tandem commander 077 probe' -Encoding ASCII
    $zipPath = Join-Path $Archive 'probe.zip'
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -LiteralPath $zipSrc -DestinationPath $zipPath
    $startArgs = @('-l', ('"' + $zipPath + '"'))
    Write-Host ("probe: left panel will open inside {0} so that zip.spl stays loaded" -f $zipPath)
}
Write-Host ("probe: starting {0} {1}" -f $Exe, ($startArgs -join ' '))
if ($startArgs.Count -gt 0) {
    $p = Start-Process -FilePath $Exe -ArgumentList $startArgs -WorkingDirectory (Split-Path $Exe) -PassThru
} else {
    $p = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -PassThru
}
$deadline = (Get-Date).AddSeconds(30)
$ready = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $p.Refresh()
    if ($p.HasExited) { Fail 'process exited before showing its window' }
    if ($p.MainWindowHandle -ne 0 -and (Get-Process -Name salmon -ErrorAction SilentlyContinue)) { $ready = $true; break }
}
if (-not $ready) { Fail 'main window or salmon.exe did not appear within 30 s' }
Start-Sleep -Seconds $SettleSec
$p.Refresh()
if (-not $p.Responding) { Fail 'main window is not responding before injection (salmon dialog at start-up?)' }
$hwnd = $p.MainWindowHandle
$ownerPid = 0
$tid = [TC077.User32]::GetWindowThreadProcessId([IntPtr]$hwnd, [ref]$ownerPid)
if ($tid -eq 0 -or $ownerPid -ne $p.Id) { Fail 'could not determine the window-owning thread' }

# 3. pick the target address
$modules = @(Get-Process -Id $p.Id).Modules
$spl = @($modules | Where-Object { $_.ModuleName -match '\.spl$' })
Write-Host ("probe: loaded plugin modules: {0}" -f (($spl | ForEach-Object { $_.ModuleName }) -join ', '))
$targetAddr = [int64]0; $targetName = '(no module: address 0)'; $targetBase = [int64]0; $targetSize = [int64]0
if ($Target -eq 'plugin') {
    $m = $spl | Where-Object { $_.ModuleName -ieq $PluginModule } | Select-Object -First 1
    if (-not $m) { $m = $spl | Select-Object -First 1 }
    if (-not $m) { Fail 'no plugin module is loaded in the process; cannot target a plugin' }
    $targetAddr = [int64]$m.BaseAddress; $targetBase = $targetAddr; $targetSize = [int64]$m.ModuleMemorySize
    $targetName = $m.ModuleName
}
Write-Host ("probe: ui thread {0}; target = {1} (rip=0x{2:X})" -f $tid, $targetName, $targetAddr)

# 4. inject via cdb, detach, wake the thread
$cmd = ('~~[0x{0:X}] r rip=0x{1:X}; ~~[0x{0:X}] r rip; .detach; q' -f $tid, $targetAddr)
$cdbOut = & $Cdb -p $p.Id -c $cmd 2>&1 | ForEach-Object { $_.ToString() }
$cdbText = ($cdbOut -join "`n")
if ($cdbText -notmatch 'Detached') { Write-Host $cdbText; Fail 'cdb did not report Detached' }
[void][TC077.User32]::PostMessage([IntPtr]$hwnd, 0, [IntPtr]::Zero, [IntPtr]::Zero)
Write-Host 'probe: fault injected, debugger detached, WM_NULL posted; waiting for the bug report...'

# 5. wait for the .TXT report
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$txt = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    if (-not (Test-Path -LiteralPath $bugDir)) { continue }
    $txt = Get-ChildItem -LiteralPath $bugDir -File -Filter '*.TXT' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($txt -and $txt.Length -gt 0) { Start-Sleep -Seconds 1; break }
}
if (-not $txt) { Fail ("no bug report (.TXT) under {0} within {1} s" -f $bugDir, $TimeoutSec) }
$dmp = Get-ChildItem -LiteralPath $bugDir -File -Filter '*.DMP' | Select-Object -First 1

$report = Get-Content -LiteralPath $txt.FullName -ErrorAction SilentlyContinue
$excLine = $report | Where-Object { $_ -match '^\s*Exception:' } | Select-Object -First 1
$addrLine = $report | Where-Object { $_ -match 'execution address = 0x([0-9A-Fa-f]+)' } | Select-Object -First 1
$rip = [int64]-1
if ($addrLine -match 'execution address = 0x([0-9A-Fa-f]+)') { $rip = [Convert]::ToInt64($Matches[1], 16) }
$p.Refresh()
Write-Host ("probe: report   = {0} ({1} bytes)" -f $txt.Name, $txt.Length)
Write-Host ("probe: minidump = {0}" -f $(if ($dmp) { $dmp.Name } else { 'none (dbghelp.dll not shipped - pre-existing)' }))
Write-Host ("probe: {0}" -f $excLine.Trim())
Write-Host ("probe: {0}" -f $addrLine.Trim())
Write-Host ("probe: application exited after the report: {0}; salmon dialog: '{1}'" -f $p.HasExited, ((Get-Process -Name salmon -ErrorAction SilentlyContinue | Select-Object -First 1).MainWindowTitle))

$ok = $false
if ($Target -eq 'app') { $ok = ($rip -eq 0) }
else {
    $ok = ($rip -ge $targetBase -and $rip -lt ($targetBase + $targetSize))
    Write-Host ("probe: faulting address inside {0} [0x{1:X}..0x{2:X}): {3}" -f $targetName, $targetBase, ($targetBase + $targetSize), $ok)
}

# 6. archive the report, close the dialog
Get-ChildItem -LiteralPath $bugDir -File | ForEach-Object {
    Move-Item -LiteralPath $_.FullName -Destination (Join-Path $Archive ($Tag + '-' + $_.Name)) -Force
}
Cleanup
if ($ok) { Write-Host 'RESULT: OK'; exit 0 } else { Write-Host 'RESULT: FAIL - report produced but faulting address does not match the target'; exit 1 }
