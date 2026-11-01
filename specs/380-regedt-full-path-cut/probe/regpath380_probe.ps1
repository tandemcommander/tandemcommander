<#
.SYNOPSIS
    Feature 380 probe: Registry Editor - a path typed relative to the current key whose full path
    does not fit the core's MAX_PATH buffer (259 bytes of UTF-8) is refused, never cut into another
    key.

.DESCRIPTION
    Fixture (HKCU\Software\TcProbe380, created and removed by the probe):
      X  = 150 x 'x'           the current key of every row
      X\s                       the short target (control)
      X\R  (R = 100 x 'r')      the long target: "reg:\HKEY_CURRENT_USER\Software\TcProbe380\X\R"
                                is 294 bytes
      X\D  (D = R cut so that the full path is exactly 259 bytes): the key a cut path names
      C  = 40 CJK letters, C\T (T = 40 CJK letters): the cut lands inside a character
    Each row starts the program on a disk folder, changes the left panel to reg:...\X (or ...\C)
    with Change Directory (862), types the relative path into Change Directory and presses OK; the
    probe answers every message with OK and closes a re-opened Change Directory. The panel's
    location is then read from the Change Directory field.
      SHORT  type "s": the panel is at ...\X\s (control - passes before and after)
      LONG   type R: PASS = a message "too long" and the panel stays at ...\X
                     (before the fix: the panel goes to ...\X\D, an existing other key)
      CJK    type T under C: PASS = a message "too long" and the panel stays at ...\C
    MUST run through tools\run_on_hidden_desktop.ps1. The product's registry key is exported,
    restored and verified. Exit code = number of FAIL rows.
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
$Root = $TempRoot + '\tc380'
$StartDir = $Root + '\start'
$FixKey = 'Software\TcProbe380'
$FsPrefix = 'reg:\HKEY_CURRENT_USER\' + $FixKey
$X = 'x' * 150
$R = 'r' * 100
$C = -join (1..40 | ForEach-Object { [char](0x4E00 + $_) })
$T = -join (1..40 | ForEach-Object { [char](0x5E00 + $_) })
$baseX = $FsPrefix + '\' + $X
$cut = 259 - (U8Len ($baseX + '\'))
$D = $R.Substring(0, $cut)

function New-Fixture {
    $hk = [Microsoft.Win32.Registry]::CurrentUser
    foreach ($k in @(($FixKey + '\' + $X + '\s'), ($FixKey + '\' + $X + '\' + $R), ($FixKey + '\' + $X + '\' + $D), ($FixKey + '\' + $C + '\' + $T))) {
        $h = $hk.CreateSubKey($k); $h.Close()
    }
}
function Remove-Fixture {
    try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($FixKey, $false) } catch { Out ('Fixture key: ' + $_.Exception.Message) }
}
function Same([string]$a, [string]$b) { return [string]::Equals($a.TrimEnd('\'), $b.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) }
function Show([string]$s) { if ($null -eq $s) { return '<null>' }; return ('{0} ({1} bytes)' -f (Tail $s 60), (U8Len $s)) }

function Run-Case([string]$Case, [string]$Base, [string]$Typed, [string]$Expect, [bool]$WantRefusal, [string]$Wrong) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $StartDir
        $okBase = Do-ChangeDir $id $Base
        $r0 = Serve $id 15
        $loc0 = Get-Loc $id
        if (-not (Same $loc0 $Base)) { Row $Case 'SETUP' 'FAIL' ('the panel is not at the base key: ' + (Show $loc0) + '; field held text ' + $okBase + '; windows: ' + (Msgs $r0)); return }
        $held = Do-ChangeDir $id $Typed
        $r = Serve $id 20
        $loc = Get-Loc $id
        $msgs = Msgs $r
        $told = $msgs -match 'too long'
        $atExpect = Same $loc $Expect
        if ($WantRefusal) { $ok = $told -and $atExpect } else { $ok = $atExpect -and -not $told }
        $wrongNote = ''
        if ($Wrong -and (Same $loc $Wrong)) { $wrongNote = '; THE PANEL WENT TO ANOTHER EXISTING KEY (the cut path)' }
        Row $Case 'RUN' (V $ok) ("typed {0} bytes (field held it {1}); location {2}; expected {3}{4}; windows: {5}" -f (U8Len $Typed), $held, (Show $loc), (Show $Expect), $wrongNote, $msgs)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc380_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Remove-Fixture
    New-Fixture
    Set-Config
    Out ("regpath380_probe (feature 380) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; base {3} bytes; cut key D {4} chars" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), (U8Len ($baseX + '\')), $D.Length)
    Out ''
    Run-Case 'SHORT' $baseX 's' ($baseX + '\s') $false $null
    Run-Case 'LONG' $baseX $R $baseX $true ($baseX + '\' + $D)
    Run-Case 'CJK' ($FsPrefix + '\' + $C) $T ($FsPrefix + '\' + $C) $true $null
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    Remove-Fixture
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; fixture key removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), ($null -eq [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($FixKey)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
