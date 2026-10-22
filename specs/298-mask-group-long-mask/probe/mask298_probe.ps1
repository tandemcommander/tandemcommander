<#
.SYNOPSIS
    Feature 298 probe: a single mask longer than 259 bytes in a mask group - the program starts, stays
    responsive and exits cleanly (before the fix CMaskGroup::PrepareMasks copied it into 260-byte stack
    buffers without a bound).

.DESCRIPTION
    The source is the registry value ThumbnailMasks of a plug-in (HKCU\...\0.1\Plugins\<n>), read with a
    MAX_GROUPMASK (1001 byte) cap and prepared while the plug-in list loads at start - a hand edit or a
    settings import delivers it. Per row the value is written, the program started, served, closed with
    WM_CLOSE; the row passes when the start and the end are clean (no run-time check, no crash report,
    exit code 0).
      SHORT   the control: one mask of 252 bytes (fits the old buffers) - PASS before and after
      MULTI   the control: 140 short masks, 1000 bytes in all - PASS before and after
      M300    one mask of 300 bytes
      M1000   one mask of 1000 bytes (the longest the registry read keeps)
    (Whether the mask is used whole, not cut, is checked by saltests over src/common/salmaskgroup.h.)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
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
$Root = $TempRoot + '\tc298'
$StartDir = $Root + '\start'
$PlugKey = $RegKey + '\0.1\Plugins\1'

function Mask-Of([int]$Bytes) { return '*.' + ('b' * ($Bytes - 2)) }
function Multi-Mask {
    $parts = @(); $n = 0
    while ($true) { $m = ('*.e{0:D3}' -f $n); $next = ($parts + $m) -join ';'; if ($next.Length -gt 990) { break }; $parts += $m; $n++ }
    $s = $parts -join ';'
    return $s + (';*.' + ('c' * (1000 - $s.Length - 3)))
}
function Read-Thumb {
    $k = 'HKCU:\Software\Tandem Commander\0.1\Plugins\1'
    try { return [string](Get-ItemProperty -LiteralPath $k -Name 'ThumbnailMasks' -ErrorAction Stop).ThumbnailMasks } catch { return $null }
}

function Run-Case([string]$Case, [string]$Value) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        & reg.exe add $PlugKey /v 'ThumbnailMasks' /t REG_SZ /d $Value /f | Out-Null
        if ((Read-Thumb) -ne $Value) { throw 'the registry value was not written' }
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T298', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero -and -not (Fatal-Win $id)) { Start-Sleep -Milliseconds 100 }
        $fatal = Fatal-Win $id
        if (-not $fatal -and (Get-Main $id) -ne [IntPtr]::Zero) {
            try { [void]$p.WaitForInputIdle(30000) } catch { }
            Start-Sleep -Milliseconds 1500
            $r = Serve $id 10
            if ($r.Fatal) { $fatal = $r.Fatal }
        }
        $shown = (Get-Main $id) -ne [IntPtr]::Zero   # (not $started: it would hide the library's $Started)
        Row $Case 'START' (V ($shown -and -not $fatal)) ("{0} bytes; main window {1}; alive {2}{3}" -f $Value.Length, $shown, (Test-Alive $id), $(if ($fatal) { '; FATAL: ' + $fatal } else { '' }))
        End-Row $Case $id $fatal $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc298_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if (-not $existed) { throw 'the product registry key does not exist - start the program once first' }
    & cmd.exe /c "reg query `"$PlugKey`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "$PlugKey does not exist" }
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("mask298_probe (feature 298) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; value {3}\ThumbnailMasks" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), $PlugKey)
    Out ''
    Run-Case 'SHORT' (Mask-Of 252)
    Run-Case 'MULTI' (Multi-Mask)
    Run-Case 'M300' (Mask-Of 300)
    Run-Case 'M1000' (Mask-Of 1000)
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
exit $nf
