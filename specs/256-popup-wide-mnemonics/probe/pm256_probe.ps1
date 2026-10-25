<#
.SYNOPSIS
    Feature 256 probe: a popup menu item is chosen by its hot key typed as a character the code
    page cannot hold - the popup's message loop took the key as a code-page byte.

.DESCRIPTION
    The User Menu (CM_USERMENU 751, a CMenuPopup loop) holds four items, each writing
    <root>\out\<row>.txt (cmd.exe /c echo, no shell window):
      ZH  "tc256 &<U+0416>"  (Cyrillic Zhe - outside code page 1250)
      CC  "tc256 &<U+010C>"  (C caron - inside code page 1250): the control
      AS  "tc256 &Q"         (ASCII): the control
      QM  "tc256 &?"         the item a code-page loop picks for a character it cannot hold
    Each row opens the menu and posts one wide WM_CHAR (PostMessageW) to the popup window:
      ZH  U+0416 -> PASS = ZH.txt written and QM.txt not
      CC  U+010D (lower case c caron) -> PASS = CC.txt
      AS  'q' -> PASS = AS.txt
    The popup window not found = NOT DRIVEN (a menu may close by itself on the hidden desktop).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc256'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$UmKey = 'Software\Tandem Commander\Settings\User Menu'
$PopupClass = 'PopupMenuClass'

$Items = [ordered]@{
    'ZH' = ('tc256 &' + [char]0x0416)
    'CC' = ('tc256 &' + [char]0x010C)
    'AS' = 'tc256 &Q'
    'QM' = 'tc256 &?'
}
function Seed-UserMenu {
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($UmKey, $false)
    $i = 0
    foreach ($c in $Items.Keys) {
        $i++
        $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($UmKey + '\' + $i)
        $k.SetValue('Item Name', $Items[$c], 'String'); $k.SetValue('Command', 'cmd.exe', 'String')
        $k.SetValue('Arguments', ('/c echo ' + $c + '>"' + $OutDir + '\' + $c + '.txt"'), 'String'); $k.SetValue('Initial Directory', '', 'String')
        $k.SetValue('Execute Through Shell', 0, 'DWord'); $k.SetValue('Close Shell Window', 1, 'DWord'); $k.SetValue('Open Shell Window', 0, 'DWord')
        $k.SetValue('Icon', '', 'String'); $k.SetValue('Type', 0, 'DWord'); $k.SetValue('Show In Toolbar', 0, 'DWord')
        $k.Close()
    }
}
function Written {
    return @(Get-ChildItem -LiteralPath $OutDir -Filter '*.txt' -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName } | Sort-Object)
}
function Find-Popup([int]$Id, [double]$Seconds = 5) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $p = @([Drv098f]::Top([uint32]$Id) | Where-Object { [Drv098f]::Cls($_) -eq $PopupClass -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
        if ($p) { return $p }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}

function Run-Row([string]$Case, [int]$Char, [string]$Expect) {
    $id = 0; $before = Reports
    try {
        foreach ($f in (Written)) { [IO.File]::Delete($LP + $OutDir + '\' + $f + '.txt') }
        $id = Start-Tc $StartDir
        [void](Serve $id 10)
        Post-Cmd (Get-Main $id) 751   # CM_USERMENU
        $pop = Find-Popup $id
        if ($pop -eq [IntPtr]::Zero) { Row $Case 'RUN' 'NOT DRIVEN' 'the User Menu popup window did not show'; return }
        [void][Drv098f]::PostMessageW($pop, 0x0102, [IntPtr]$Char, [IntPtr]1)   # WM_CHAR, UTF-16
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 8 -and (Written).Count -eq 0) { Start-Sleep -Milliseconds 200 }
        Start-Sleep -Milliseconds 800
        $got = @(Written)
        $stillOpen = [Drv098f]::IsWindow($pop) -and [Drv098f]::IsWindowVisible($pop)
        if ($stillOpen) { [void][Drv098f]::PostMessageW($pop, 0x0100, [IntPtr]0x1B, [IntPtr]1); Start-Sleep -Milliseconds 500 }   # Esc
        $ok = ($got.Count -eq 1 -and $got[0] -eq $Expect)
        Row $Case 'RUN' (V $ok) ("typed U+{0:X4}; items run: {1}; popup still open: {2}" -f $Char, $(if ($got.Count) { $got -join ',' } else { 'none' }), $stillOpen)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc256_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir
    Set-Config
    Seed-UserMenu
    Out ("pm256_probe (feature 256) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-Row 'ZH' 0x0416 'ZH'
    Run-Row 'CC' 0x010D 'CC'
    Run-Row 'AS' 0x0071 'AS'
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
