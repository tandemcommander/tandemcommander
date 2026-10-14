<#
.SYNOPSIS
    Feature 181 probe: a shortcut (.lnk) in a folder whose path has more than MAX_PATH bytes of
    UTF-8 (fewer than MAX_PATH characters) opens its target - Enter on it.

.DESCRIPTION
    A folder named with Czech letters so that its full path is about 200 characters / 330 bytes;
    in it go.lnk pointing to the folder ...\target (made in a short folder by WScript.Shell, then
    moved in). The panel on the long folder, the focus on go.lnk, Enter (VK_RETURN).
      LNK-SHORT   the same shortcut in a short folder                         (control)
      LNK-LONG    in the long folder: the panel must end in ...\target (before: "name too long")
      LNK-VERYLONG  a folder path of more than MAX_PATH characters (ASCII)
      FOCUS-*     the same with Focus Shortcut Target (838) instead of Enter
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
$Root = $TempRoot + '\tc181'
$StartDir = $Root + '\start'
function C([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }

function Make-Lnk([string]$Dir, [string]$Target) {
    $tmp = $Root + '\mk'; NewDir $tmp
    $sh = New-Object -ComObject WScript.Shell
    $l = $sh.CreateShortcut($tmp + '\go.lnk'); $l.TargetPath = $Target; $l.Save()
    [IO.File]::Move($LP + $tmp + '\go.lnk', $LP + $Dir + '\go.lnk')
}
function Run-Case([string]$Case, [string]$Dir, [int]$How = 0) {
    if (-not (Want $Case)) { return }
    NewDir $Dir
    $target = $Root + '\target'; NewDir $target
    Make-Lnk $Dir $target
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $StartDir
        [void](Do-ChangeDir $id ($Dir + '\go.lnk'))   # the panel in the folder, the focus on go.lnk
        [void](Serve $id 5 @(2))
        $loc1 = Get-Loc $id
        if ($How -eq 838) { Post-Cmd (Get-Main $id) 838 } else { Key $id 0x0D }   # Focus Shortcut Target / Enter
        $r = Serve $id 15 @(1)
        $loc = Get-Loc $id
        End-Row $Case $id $null $before; $id = 0
        $ok = $loc.TrimEnd('\') -ieq $target
        Row $Case 'TARGET' (V $ok) ("folder {0} bytes; panel before Enter '{1}', after '{2}'; windows: {3}" -f (U8Len $Dir), (Tail $loc1 40), (Tail $loc 40), (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc181_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("lnk_probe (feature 181), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    $cz = (C @(0x10D, 0x159, 0x17E, 0x161, 0x11B)) * 14   # 70 Czech letters = 140 bytes
    Run-Case 'LNK-SHORT' ($Root + '\short')
    Run-Case 'LNK-LONG' ($Root + '\' + $cz + '\' + $cz)
    $lat = 'x' * 130
    Run-Case 'LNK-VERYLONG' ($Root + '\' + $lat + '\' + $lat)   # more than MAX_PATH characters
    Run-Case 'FOCUS-LONG' ($Root + '\f' + $cz + '\' + $cz) 838
    Run-Case 'FOCUS-VERYLONG' ($Root + '\f' + $lat + '\' + $lat) 838
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
