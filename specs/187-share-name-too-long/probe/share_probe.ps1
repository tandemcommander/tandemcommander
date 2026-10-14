<#
.SYNOPSIS
    Feature 187 probe: a UNC path whose share part is too long is refused as "too long" - not as
    "a share name is missing" (with the share list of 125 offered).

.DESCRIPTION
    Change Directory (862) to \\localhost\ + 300 x 'a' + \x. PASS = the box says the path is too
    long; no share list dialog. The dialogs are closed; nothing is changed on disk.
      SHARE-LONG    the share part of 300 characters
      SERVER-LONG   a server part of 300 characters (\\aaa...\s\x)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc187'
$StartDir = $Root + '\start'

function Run-Case([string]$Case, [string]$Path) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $StartDir
        $dlg = Open-ByCmd $id 862 10
        [void][Drv098f]::SetText((Find-Ctl $dlg 210), $Path, 5000)
        Click-Ok $dlg
        # boxes: OK; a share list dialog or the Change Directory dialog again: Cancel (Serve does)
        $r = Serve $id 30 @(1)
        End-Row $Case $id $null $before; $id = 0
        $m = Msgs $r
        $ok = ($m -match 'too long') -and ($m -notmatch 'share name is missing')
        Row $Case 'MSG' (V $ok) ("windows: {0}" -f (Tail $m 300))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc187_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("share_probe (feature 187), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    $bs = [string][char]92
    Run-Case 'SHARE-LONG' ($bs + $bs + 'localhost' + $bs + ('a' * 300) + $bs + 'x')
    Run-Case 'SERVER-LONG' ($bs + $bs + ('a' * 300) + $bs + 's' + $bs + 'x')
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
if ($Expect -eq 'before') { exit 0 }
exit $nf
