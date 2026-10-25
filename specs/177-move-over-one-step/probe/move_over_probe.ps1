<#
.SYNOPSIS
    Feature 177 probe: F6 Move onto an existing file never loses the target - the move replaces it
    in one step, or both files stay as they were.

.DESCRIPTION
    Left panel: src\ with b.txt; right panel: dst\ with b.txt (another content). b.txt focused in
    the left panel, F6 (728), OK, the overwrite question Yes, any error box Cancel.
      MV-PLAIN   dst\b.txt now holds the source's content, src\b.txt gone          (control)
      MV-HELD    src\b.txt held open by another program without FILE_SHARE_DELETE (it cannot be
                 renamed): the move fails - dst\b.txt must still hold its old content (before: the
                 core deleted it, then the move failed)
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
$Root = $TempRoot + '\tc177'
$StartDir = $Root + '\start'
function Body([string]$p) { if (-not [IO.File]::Exists($LP + $p)) { return $null }; return [IO.File]::ReadAllText($LP + $p) }

function Run-Case([string]$Case) {
    if (-not (Want $Case)) { return }
    $src = $Root + '\' + $Case.ToLower() + '\src'; $dst = $Root + '\' + $Case.ToLower() + '\dst'
    NewDir $src; NewDir $dst
    WriteFile ($src + '\b.txt') 'the source'
    WriteFile ($dst + '\b.txt') 'the old target'
    $script:StartDir = $dst   # the right panel
    $held = $null
    if ($Case -eq 'MV-HELD') { $held = [IO.File]::Open($LP + $src + '\b.txt', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $src
        [void](Do-ChangeDir $id ($src + '\b.txt'))   # focuses b.txt
        [void](Serve $id 5 @(2))
        $dlg = Open-ByCmd $id 728 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'FILE' 'NOT DRIVEN' 'no Move dialog'; return }
        $t = [Drv098f]::GetText((Find-Ctl $dlg 210), 5000)
        Click-Ok $dlg
        # the overwrite question: Yes (6); an error box (Retry 4 / Skip / Cancel 2): Cancel
        $r = Serve $id 30 @(6, 2)
        if ($held) { $held.Close(); $held = $null; Start-Sleep -Milliseconds 300 }
        End-Row $Case $id $null $before; $id = 0
        $s = Body ($src + '\b.txt'); $d = Body ($dst + '\b.txt')
        if ($Case -eq 'MV-HELD') { $ok = ($s -ceq 'the source') -and ($d -ceq 'the old target') }
        else { $ok = ($null -eq $s) -and ($d -ceq 'the source') }
        Row $Case 'FILE' (V $ok) ("target field '{0}'; src\b.txt {1}; dst\b.txt {2}; windows: {3}" -f (Esc $t), $(if ($null -eq $s) { 'gone' } else { "'" + $s + "'" }), $(if ($null -eq $d) { 'GONE' } else { "'" + $d + "'" }), (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($held) { $held.Close() }; if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc177_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    & reg.exe add "$RegKey\Settings\Configuration\Confirmation" /v 'File Overwrite' /t REG_DWORD /d 1 /f | Out-Null
    Out ("move_over_probe (feature 177), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    Run-Case 'MV-PLAIN'
    Run-Case 'MV-HELD'
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
