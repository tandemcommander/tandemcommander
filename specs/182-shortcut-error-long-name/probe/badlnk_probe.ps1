<#
.SYNOPSIS
    Feature 182 probe: Focus Shortcut Target (838) on a broken shortcut with a long name shows the
    error with the whole name - no stack overrun.

.DESCRIPTION
    A folder with a broken shortcut (a text file named *.lnk): BAD-SHORT "bad.lnk" (control) and
    BAD-LONG a name of 200 CJK letters (600 bytes of UTF-8) + ".lnk". The focus on it, 838. PASS =
    the program shows "not valid shortcut" naming the file, survives, no fatal window, no report.
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
$Root = $TempRoot + '\tc182'
$StartDir = $Root + '\start'

function Run-Case([string]$Case, [string]$Name) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case.ToLower(); NewDir $d
    WriteFile ($d + '\' + $Name) 'this is not a shortcut'
    $id = 0; $before = Reports; $fatal = $null
    try {
        $id = Start-Tc $d
        [void](Do-ChangeDir $id ($d + '\' + $Name))
        [void](Serve $id 5 @(2))
        Post-Cmd (Get-Main $id) 838
        $r = Serve $id 15 @(1)
        $fatal = $r.Fatal
        if (-not $fatal) { $fatal = Fatal-Win $id }
        $m = Msgs $r
        $named = $m -match 'not valid shortcut'
        End-Row $Case $id $fatal $before; $id = 0
        Row $Case 'MSG' (V ($named -and -not $fatal)) ("name {0} bytes; windows: {1}{2}" -f (U8Len $Name), (Tail $m 160), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc182_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("badlnk_probe (feature 182), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    Run-Case 'BAD-SHORT' 'bad.lnk'
    Run-Case 'BAD-LONG' (([string][char]0x4E2D) * 200 + '.lnk')
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
