# 077 probe: prove that the application periodically re-registers its top-level
# exception filter by supported means (FR-012, research R5).
#
# Starts the exe, attaches cdb for -WatchSec seconds with a breakpoint on
# kernel32!SetUnhandledExceptionFilter that logs rcx (the filter being
# installed) and continues. AddNewlyLoadedModulesToGlobalModulesStore() runs on
# the main window's 15-second timer (IDT_ADDNEWMODULES), so at least two hits
# are expected in 40 s, each with rcx == tandemcommander!TopLevelExceptionFilter
# (address taken from the Release PDB via .sympath; never .symfix - the
# Microsoft symbol server hangs the run, see 075 fix-log).
#
# The debugger is killed after -WatchSec (which terminates the debuggee, a
# throw-away instance). Prints RESULT: OK / FAIL, exits 0 / 1. ASCII only.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$SymDir = '',
    [int]$WatchSec = 40,
    [int]$MinHits = 2,
    [string]$Cdb = 'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe',
    [string]$Log = (Join-Path $env:TEMP 'tc077-reassert.log')
)

$ErrorActionPreference = 'Stop'
function Cleanup {
    foreach ($n in 'cdb', 'tandemcommander', 'salmon') {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch { } }
    }
}
function Fail([string]$m) { Write-Host "RESULT: FAIL - $m"; Cleanup; exit 1 }

if (-not (Test-Path -LiteralPath $Exe)) { Fail "exe not found: $Exe" }
if (-not (Test-Path -LiteralPath $Cdb)) { Fail "cdb not found: $Cdb" }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $SymDir) {
    # Release PDBs are redirected to build\obj\Release_x64\Intermediate (src/Directory.Build.targets)
    $SymDir = (Resolve-Path -LiteralPath (Join-Path (Split-Path $Exe) '..\..\obj\Release_x64\Intermediate')).Path
}
if (-not (Test-Path -LiteralPath (Join-Path $SymDir 'tandemcommander.pdb'))) { Fail "tandemcommander.pdb not found in $SymDir" }
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Fail 'tandemcommander.exe is already running - stop it first' }
if (Test-Path -LiteralPath $Log) { Remove-Item -LiteralPath $Log -Force }

$p = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -PassThru
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500; $p.Refresh()
    if ($p.HasExited) { Fail 'process exited before showing its window' }
    if ($p.MainWindowHandle -ne 0) { break }
}
if ($p.MainWindowHandle -eq 0) { Fail 'main window did not appear within 30 s' }
$p.Refresh()
if (-not $p.Responding) { Fail 'main window not responding (old bug report offered by salmon at start-up?)' }
$t0 = Get-Date

# The breakpoint command contains double quotes, which cannot survive the
# -c argument quoting; cdb reads the same commands from a script file (-cf).
$cmdFile = Join-Path $env:TEMP 'tc077-reassert.cdb'
@(
    ('.sympath "{0}"' -f $SymDir),
    '.reload',
    'x tandemcommander!TopLevelExceptionFilter',
    'bp kernel32!SetUnhandledExceptionFilter ".echo HIT; r rcx; g"',
    '.echo ARMED',
    'g'
) | Set-Content -LiteralPath $cmdFile -Encoding ASCII
$dbg = Start-Process -FilePath $Cdb -ArgumentList @('-p', $p.Id, '-cf', ('"' + $cmdFile + '"')) -RedirectStandardOutput $Log -PassThru -WindowStyle Hidden
Write-Host ("probe: cdb attached (pid {0}) for {1} s, log {2}" -f $dbg.Id, $WatchSec, $Log)
Start-Sleep -Seconds $WatchSec
Cleanup
Start-Sleep -Seconds 1

$text = Get-Content -LiteralPath $Log -ErrorAction SilentlyContinue
$armed = [bool]($text | Where-Object { $_ -match '^ARMED' })
# the address line ("00007ff6`d6c153c0 tandemcommander!TopLevelExceptionFilter (...)"),
# not the echoed command line that precedes it
$symLine = $text | Where-Object { $_ -match '^[0-9a-f`]+\s+tandemcommander!TopLevelExceptionFilter' } | Select-Object -First 1
$filterAddr = ''
if ($symLine -match '^([0-9a-f`]+)\s+tandemcommander!TopLevelExceptionFilter') { $filterAddr = $Matches[1] -replace '`', '' }
$hits = @()
for ($i = 0; $i -lt $text.Count; $i++) {
    if ($text[$i] -match '^HIT') {
        $rcx = ''
        for ($j = $i + 1; $j -lt [Math]::Min($i + 4, $text.Count); $j++) { if ($text[$j] -match 'rcx=([0-9a-f`]+)') { $rcx = $Matches[1] -replace '`', ''; break } }
        $hits += $rcx
    }
}
Write-Host ("probe: armed={0}  TopLevelExceptionFilter=0x{1}  hits in {2} s: {3}" -f $armed, $filterAddr, $WatchSec, $hits.Count)
$hits | ForEach-Object { Write-Host ("  SetUnhandledExceptionFilter(rcx=0x{0}) {1}" -f $_, $(if ($_ -eq $filterAddr) { 'ours' } else { 'OTHER' })) }
$ours = @($hits | Where-Object { $_ -eq $filterAddr }).Count
if ($armed -and $filterAddr -and $hits.Count -ge $MinHits -and $ours -eq $hits.Count) { Write-Host 'RESULT: OK'; exit 0 }
Write-Host ('RESULT: FAIL - expected >= {0} hits, all with our filter' -f $MinHits); exit 1
