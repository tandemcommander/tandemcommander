<#
.SYNOPSIS
    Feature 343 probe: the one-time move of the configuration from HKCU\Software\Tandem Commander\0.1
    to the version-free root HKCU\Software\Tandem Commander\Settings - complete, silent, never half
    applied, the old key never written; and the import of a configuration file written for 0.1.

.DESCRIPTION
    The 0.1 configuration is made at run time: -LegacyExe (a build from before the change) starts on an
    empty registry, saves its configuration and exits; its 0.1 key is exported to %TEMP% (no fixture
    with the maintainer's paths is kept). Without -LegacyExe the new build makes a Settings key, which
    is renamed to 0.1 (the format is the same). Every seeding adds Plugins Configuration\Probe343 with
    values of every registry type, non-ASCII names and 6 levels of keys.
      BASIC        0.1 only -> one start: Settings equals 0.1 (whole tree, dump hash), no window but the
                   main window (no import offer), 0.1 unchanged after the exit
      AGAIN        a save (Options > Save Configuration) recreates Settings\Window; 0.1 unchanged
      BOTH         both present, a value only in 0.1 -> not copied; a marker only in Settings kept
      FRESH        no root -> Settings made by the first save, 0.1 not made (the import offer of 245 may
                   appear: this machine has Altap / Open Salamander keys; it is cancelled)
      KILL         TC_CFGMIGRATE_FAIL_AT=kill-after-copy -> exit code 3, the side key left, no Settings,
                   0.1 unchanged; the next start completes the move, the side key gone
      FAIL-<step>  copy / compare / rename -> the message box, no Settings, no side key, the session
                   saves into 0.1 (its Window key recreated); the next start moves it
      CORRUPT      0.1 marked "Save In Progress" + a valid 0.1.backup.63A7CD13 -> the program uses the
                   backup's settings (marker), Settings.corrupted.63A7CD13 holds the damaged copy, the old
                   keys unchanged
      IMP-LEGACY   -C <file exported for the 0.1 root> -> its marker key under Settings
      IMP-FOREIGN  -C <file with HKCU\Software\Probe343Foreign> -> refused, the key not made
    MUST run through tools\run_on_hidden_desktop.ps1. The parent key HKCU\Software\Tandem Commander is
    exported, restored and verified (fix_probe_lib Backup-Reg / Restore-Reg). Exit code = FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$LegacyExe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($LegacyExe) { $LegacyExe = (Resolve-Path -LiteralPath $LegacyExe).Path }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\..\tools\tc_config_key.ps1')
$Root = $TempRoot + '\tc343'
$StartDir = $Root + '\start'
$Fixture = $Root + '\legacy_0_1.reg'
$SideName = $TcConfigKeyName + '.migrating' + $TcKeySuffix
$NewBackupName = $TcConfigKeyName + '.backup' + $TcKeySuffix
$NewCorruptName = $TcConfigKeyName + '.corrupted' + $TcKeySuffix
$LegacyBackupName = $TcLegacyKeyName + '.backup' + $TcKeySuffix
$HKCU = [Microsoft.Win32.Registry]::CurrentUser

# ---- registry helpers (relative names under HKCU) ---------------------------
function Key-Exists([string]$Name) { $k = $HKCU.OpenSubKey($Name); if ($k) { $k.Close(); return $true }; return $false }
function Del-Key([string]$Name) { if (Key-Exists $Name) { $HKCU.DeleteSubKeyTree($Name) } }
function Copy-Key([string]$From, [string]$To) {
    & cmd.exe /c "reg copy `"HKCU\$From`" `"HKCU\$To`" /s /f >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "reg copy $From -> $To failed" }
}
function Set-Val([string]$Key, [string]$Name, $Value, [Microsoft.Win32.RegistryValueKind]$Kind) {
    $k = $HKCU.CreateSubKey($Key); try { $k.SetValue($Name, $Value, $Kind) } finally { $k.Close() }
}
function Get-Val([string]$Key, [string]$Name) {
    $k = $HKCU.OpenSubKey($Key); if (-not $k) { return $null }
    try { return $k.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } finally { $k.Close() }
}
function Hex([byte[]]$b) { return (($b | ForEach-Object { $_.ToString('x2') }) -join '') }
# canonical dump of a tree: every key (relative path) and every value (name, kind, data as bytes)
function Tree-Lines([Microsoft.Win32.RegistryKey]$K, [string]$Rel, [System.Collections.ArrayList]$Out) {
    [void]$Out.Add('K ' + $Rel)
    foreach ($n in ($K.GetValueNames() | Sort-Object -CaseSensitive)) {
        $kind = $K.GetValueKind($n)
        $v = $K.GetValue($n, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        switch ($kind) {
            'String' { $d = Hex ([Text.Encoding]::Unicode.GetBytes([string]$v)) }
            'ExpandString' { $d = Hex ([Text.Encoding]::Unicode.GetBytes([string]$v)) }
            'MultiString' { $d = Hex ([Text.Encoding]::Unicode.GetBytes((@($v) -join [char]0))) }
            'Binary' { $d = Hex ([byte[]]$v) }
            'None' { if ($v) { $d = Hex ([byte[]]$v) } else { $d = '' } }
            default { $d = [string]$v }
        }
        [void]$Out.Add('V ' + $Rel + '|' + $n + '|' + $kind + '|' + $d)
    }
    foreach ($s in ($K.GetSubKeyNames() | Sort-Object -CaseSensitive)) {
        $c = $K.OpenSubKey($s); try { Tree-Lines $c ($Rel + '\' + $s) $Out } finally { $c.Close() }
    }
}
function Tree-Text([string]$Name) {
    $k = $HKCU.OpenSubKey($Name); if (-not $k) { return '<missing>' }
    $out = New-Object System.Collections.ArrayList
    try { Tree-Lines $k '' $out } finally { $k.Close() }
    return ($out -join "`n")
}
function Tree-Hash([string]$Name) {
    $t = Tree-Text $Name
    $sha = [Security.Cryptography.SHA256]::Create()
    return (Hex ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($t)))).Substring(0, 16)
}
function Tree-Count([string]$Name) { return @((Tree-Text $Name) -split "`n").Count }

# ---- program ------------------------------------------------------------------
# starts the exe; returns the pid after its main window appeared, or after it ended (KILL)
function Start-One([string]$Path, [string]$Seam, [string[]]$Extra) {
    $a = @('-t', 'T343', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1') + $Extra
    if ($Seam) { $env:TC_CFGMIGRATE_FAIL_AT = $Seam } else { Remove-Item Env:\TC_CFGMIGRATE_FAIL_AT -ErrorAction SilentlyContinue }
    try { $p = Start-Process -FilePath $Path -ArgumentList $a -PassThru }
    finally { Remove-Item Env:\TC_CFGMIGRATE_FAIL_AT -ErrorAction SilentlyContinue }
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if (Test-Alive $p.Id) { try { [void]$p.WaitForInputIdle(30000) } catch { }; Start-Sleep -Milliseconds 1500 }
    return $p.Id
}
# closes the instance: WM_CLOSE, confirmations answered Yes/OK; returns the exit code text
function Close-One([int]$Id) {
    if (-not (Test-Alive $Id)) { return (ExitCodeOf $Id) }
    [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
        Start-Sleep -Milliseconds 200
    }
    if (Test-Alive $Id) { Kill-Mine $Id; return 'killed' }
    return (ExitCodeOf $Id)
}
# the windows the start showed (other than the main window), answered with 'Want' (default Cancel/No)
function Start-Windows([int]$Id, [int[]]$Want = @(2, 7), [double]$Seconds = 8) {
    if (-not (Test-Alive $Id)) { return 'process ended' }
    $r = Serve $Id $Seconds $Want
    if ($r.Fatal) { return ('FATAL ' + $r.Fatal) }
    return (Msgs $r)
}

# ---- seeding ---------------------------------------------------------------
$U1 = -join @([char]0x017D, 'lu', [char]0x0165, 'ou', [char]0x010D, 'k', [char]0x00FD)  # Zlutoucky with accents
$U2 = -join @([char]0x65E5, [char]0x672C)                                                # CJK
function Add-Extras([string]$RootName) {
    $p = $RootName + '\Plugins Configuration\Probe343'
    Set-Val $p 'sz' 'text' ([Microsoft.Win32.RegistryValueKind]::String)
    Set-Val $p 'expand' '%TEMP%\x' ([Microsoft.Win32.RegistryValueKind]::ExpandString)
    Set-Val $p 'multi' ([string[]]@('a', '', 'b c')) ([Microsoft.Win32.RegistryValueKind]::MultiString)
    Set-Val $p 'bin' ([byte[]](0, 1, 2, 255, 128)) ([Microsoft.Win32.RegistryValueKind]::Binary)
    Set-Val $p 'binempty' ([byte[]]@()) ([Microsoft.Win32.RegistryValueKind]::Binary)
    Set-Val $p 'dword' ([int]-1) ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-Val $p 'qword' ([long]9007199254740993) ([Microsoft.Win32.RegistryValueKind]::QWord)
    Set-Val $p '' 'the default value' ([Microsoft.Win32.RegistryValueKind]::String)
    Set-Val $p ($U1 + ' ' + $U2) ($U2 + $U1) ([Microsoft.Win32.RegistryValueKind]::String)
    Set-Val ($p + '\' + $U1 + '\' + $U2) 'n' 'non-ASCII key names' ([Microsoft.Win32.RegistryValueKind]::String)
    $HKCU.CreateSubKey($p + '\empty').Close()
    Set-Val ($p + '\d1\d2\d3\d4\d5\d6') 'deep' 6 ([Microsoft.Win32.RegistryValueKind]::DWord)
}
function Clear-Roots { foreach ($n in @($TcConfigKeyName, $SideName, $NewBackupName, $NewCorruptName, $TcLegacyKeyName, $LegacyBackupName)) { Del-Key $n } }
function Seed-Legacy {
    Clear-Roots
    & cmd.exe /c "reg import `"$Fixture`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0 -or -not (Key-Exists ($TcLegacyKeyName + '\Configuration'))) { throw 'seeding the 0.1 configuration failed' }
    Add-Extras $TcLegacyKeyName
}
# quiet starts: English, no close confirmation (as fix_probe_lib Set-Config)
function Seed-Quiet([string]$RootName) {
    Set-Val ($RootName + '\Configuration') 'Language' 'english.slg' ([Microsoft.Win32.RegistryValueKind]::String)
    Set-Val ($RootName + '\Configuration\Confirmation') 'Close Salamander' 0 ([Microsoft.Win32.RegistryValueKind]::DWord)
}
function Make-Fixture {
    Clear-Roots
    $how = ''
    $maker = $Exe; $makerRoot = $TcConfigKeyName
    if ($LegacyExe) { $maker = $LegacyExe; $makerRoot = $TcLegacyKeyName }
    Seed-Quiet $makerRoot
    $id = Start-One $maker '' @()
    $w = Start-Windows $id @(1, 7)   # the language selection: OK; the import offer of 245 (Yes/No): No
    Post-Cmd (Get-Main $id) 687   # CM_SAVECONFIG: the whole configuration written
    $r = Serve $id 10 @(1, 6)
    $ec = Close-One $id
    if ($LegacyExe) { $how = "made by -LegacyExe (start windows: $w; save windows: $(Msgs $r); exit $ec)" }
    else {
        Copy-Key $TcConfigKeyName $TcLegacyKeyName; Del-Key $TcConfigKeyName
        $how = "made by the new build and renamed to 0.1 (start windows: $w; save windows: $(Msgs $r); exit $ec)"
    }
    if (-not (Key-Exists ($TcLegacyKeyName + '\Window'))) { throw "the 0.1 configuration was not saved ($how)" }
    Seed-Quiet $TcLegacyKeyName
    & cmd.exe /c "reg export `"$TcLegacyKeyReg`" `"$Fixture`" /y >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'reg export of the 0.1 fixture failed' }
    Clear-Roots
    return $how
}

# ---- rows ------------------------------------------------------------------
function Row-Basic {
    Seed-Legacy
    $h0 = Tree-Hash $TcLegacyKeyName; $n0 = Tree-Count $TcLegacyKeyName
    $before = Reports
    $id = Start-One $Exe '' @()
    $w = Start-Windows $id
    $equal = (Tree-Hash $TcConfigKeyName) -eq $h0
    $diff = ''
    if (-not $equal) {
        $a = @((Tree-Text $TcLegacyKeyName) -split "`n"); $b = @((Tree-Text $TcConfigKeyName) -split "`n")
        $diff = ' first differences: ' + ((Compare-Object $a $b | Select-Object -First 4 | ForEach-Object { $_.SideIndicator + (Tail $_.InputObject 90) }) -join ' ; ')
    }
    $probeEq = (Tree-Hash ($TcConfigKeyName + '\Plugins Configuration\Probe343')) -eq (Tree-Hash ($TcLegacyKeyName + '\Plugins Configuration\Probe343'))
    $pwdEq = (Tree-Hash ($TcConfigKeyName + '\Password Manager')) -eq (Tree-Hash ($TcLegacyKeyName + '\Password Manager'))
    $pwdThere = Key-Exists ($TcLegacyKeyName + '\Password Manager')
    $side = Key-Exists $SideName
    End-Row 'BASIC' $id $null $before
    $h1 = Tree-Hash $TcLegacyKeyName
    $ok = $equal -and $probeEq -and $pwdEq -and (-not $side) -and ($w -eq 'no window') -and ($h1 -eq $h0)
    Row 'BASIC' 'MOVE' (V $ok) ("0.1 {0} lines; Settings equal to 0.1 while running {1}{2}; Probe343 equal {3}; Password Manager equal {4} (present {5}); side key {6}; start windows: {7}; 0.1 unchanged after exit {8}" -f $n0, $equal, $diff, $probeEq, $pwdEq, $pwdThere, $side, $w, ($h1 -eq $h0))
    return $h0
}
function Row-Again([string]$H0) {
    Del-Key ($TcConfigKeyName + '\Window')
    $before = Reports
    $id = Start-One $Exe '' @()
    $w = Start-Windows $id
    Post-Cmd (Get-Main $id) 687   # CM_SAVECONFIG
    $r = Serve $id 10 @(1, 6)
    $win = Key-Exists ($TcConfigKeyName + '\Window')
    End-Row 'AGAIN' $id $null $before
    $h1 = Tree-Hash $TcLegacyKeyName
    $ok = $win -and ($h1 -eq $H0) -and ($w -eq 'no window')
    Row 'AGAIN' 'SAVE' (V $ok) ("Settings\Window recreated by the save {0}; 0.1 unchanged {1}; start windows: {2}; save windows: {3}" -f $win, ($h1 -eq $H0), $w, (Msgs $r))
}
function Row-Both {
    Set-Val ($TcLegacyKeyName + '\Plugins Configuration\Probe343') 'OnlyLegacy' 1 ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-Val ($TcConfigKeyName + '\Plugins Configuration\Probe343') 'OnlyNew' 1 ([Microsoft.Win32.RegistryValueKind]::DWord)
    $before = Reports
    $id = Start-One $Exe '' @()
    $w = Start-Windows $id
    End-Row 'BOTH' $id $null $before
    $noCopy = $null -eq (Get-Val ($TcConfigKeyName + '\Plugins Configuration\Probe343') 'OnlyLegacy')
    $kept = 1 -eq (Get-Val ($TcConfigKeyName + '\Plugins Configuration\Probe343') 'OnlyNew')
    Row 'BOTH' 'START' (V ($noCopy -and $kept -and ($w -eq 'no window'))) ("value only in 0.1 not copied {0}; marker only in Settings kept {1}; start windows: {2}" -f $noCopy, $kept, $w)
}
function Row-Fresh {
    Clear-Roots
    $before = Reports
    $id = Start-One $Exe '' @()
    $w = Start-Windows $id @(1, 7)   # the language selection: OK; the import offer of 245 (Yes/No): No
    $ec = Close-One $id
    $new = Key-Exists ($TcConfigKeyName + '\Configuration'); $old = Key-Exists $TcLegacyKeyName
    Row 'FRESH' 'START' (V ($new -and -not $old -and $ec -eq '0x00000000')) ("Settings\Configuration made {0}; 0.1 made {1}; exit {2}; start windows (Cancel/No): {3}" -f $new, $old, $ec, $w)
}
function Row-Kill {
    Seed-Legacy
    $h0 = Tree-Hash $TcLegacyKeyName
    $id = Start-One $Exe 'kill-after-copy' @()
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 20 -and (Test-Alive $id)) { Start-Sleep -Milliseconds 100 }
    $ec = ExitCodeOf $id
    if (Test-Alive $id) { Kill-Mine $id }
    $side = Key-Exists $SideName; $new = Key-Exists $TcConfigKeyName; $h1 = Tree-Hash $TcLegacyKeyName
    Row 'KILL' 'CUT' (V ($ec -eq '0x00000003' -and $side -and -not $new -and $h1 -eq $h0)) ("exit {0}; side key left {1}; Settings made {2}; 0.1 unchanged {3}" -f $ec, $side, $new, ($h1 -eq $h0))
    $before = Reports
    $id = Start-One $Exe '' @()
    $w = Start-Windows $id
    $equal = (Tree-Hash $TcConfigKeyName) -eq $h0
    $side2 = Key-Exists $SideName
    End-Row 'KILL' $id $null $before
    Row 'KILL' 'AGAIN' (V ($equal -and -not $side2 -and $w -eq 'no window')) ("next start: Settings equal to 0.1 {0}; side key gone {1}; start windows: {2}" -f $equal, (-not $side2), $w)
}
function Row-Fail([string]$Step) {
    $case = 'FAIL-' + $Step
    Seed-Legacy
    Del-Key ($TcLegacyKeyName + '\Window')
    $before = Reports
    $id = Start-One $Exe $Step @()
    $r = Serve $id 15 @(1, 2)
    $msg = Msgs $r
    $told = $msg -match 'could not move your settings'
    $new = Key-Exists $TcConfigKeyName; $side = Key-Exists $SideName; $bk = Key-Exists $NewBackupName
    Post-Cmd (Get-Main $id) 687   # CM_SAVECONFIG: this session saves into 0.1
    $r2 = Serve $id 10 @(1, 6)
    $saved = Key-Exists ($TcLegacyKeyName + '\Window')
    End-Row $case $id $null $before
    $new2 = Key-Exists $TcConfigKeyName
    Row $case 'SEAM' (V ($told -and -not $new -and -not $side -and -not $bk -and $saved -and -not $new2)) ("message shown {0}; Settings made {1}; side key {2}; Settings.backup {3}; the session saved into 0.1 (Window) {4}; Settings after exit {5}; windows: {6}" -f $told, $new, $side, $bk, $saved, $new2, (Tail $msg 160))
    $h0 = Tree-Hash $TcLegacyKeyName
    $before = Reports
    $id = Start-One $Exe '' @()
    $w = Start-Windows $id
    $equal = (Tree-Hash $TcConfigKeyName) -eq $h0
    End-Row $case $id $null $before
    Row $case 'AGAIN' (V ($equal -and $w -eq 'no window')) ("next start: Settings equal to 0.1 {0}; start windows: {1}" -f $equal, $w)
}
function Row-Corrupt {
    Seed-Legacy
    Copy-Key $TcLegacyKeyName $LegacyBackupName
    Set-Val $LegacyBackupName 'Copy Is OK' 1 ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-Val ($LegacyBackupName + '\Plugins Configuration\Probe343') 'FromBackup' 1 ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-Val $TcLegacyKeyName 'Save In Progress' 1 ([Microsoft.Win32.RegistryValueKind]::DWord)
    $h0 = Tree-Hash $TcLegacyKeyName; $hb = Tree-Hash $LegacyBackupName
    $before = Reports
    $id = Start-One $Exe '' @()
    $w = Start-Windows $id
    $fromBackup = 1 -eq (Get-Val ($TcConfigKeyName + '\Plugins Configuration\Probe343') 'FromBackup')
    $corrupt = Key-Exists $NewCorruptName
    $inProgress = $null -ne (Get-Val $TcConfigKeyName 'Save In Progress')
    End-Row 'CORRUPT' $id $null $before
    $same = ((Tree-Hash $TcLegacyKeyName) -eq $h0) -and ((Tree-Hash $LegacyBackupName) -eq $hb)
    Row 'CORRUPT' 'START' (V ($fromBackup -and $corrupt -and -not $inProgress -and $same -and $w -eq 'no window')) ("Settings holds the backup (marker) {0}; Settings.corrupted made {1}; Settings marked in progress {2}; old keys unchanged {3}; start windows: {4}" -f $fromBackup, $corrupt, $inProgress, $same, $w)
}
function Write-RegFile([string]$Path, [string[]]$Lines) {
    $text = "Windows Registry Editor Version 5.00`r`n`r`n" + ($Lines -join "`r`n") + "`r`n"
    [IO.File]::WriteAllText($Path, $text, (New-Object Text.UnicodeEncoding($false, $true)))
}
function Row-ImpLegacy {
    # a file as 0.1.x exported it: the delete line of the root, then the root's keys (the fixture), plus a marker key
    Seed-Legacy
    Move-Item -LiteralPath $Fixture -Destination ($Fixture + '.tmp') -Force
    try {
        & cmd.exe /c "reg export `"$TcLegacyKeyReg`" `"$Fixture`" /y >nul 2>&1"
        $body = [IO.File]::ReadAllText($Fixture)
    }
    finally { Move-Item -LiteralPath ($Fixture + '.tmp') -Destination $Fixture -Force }
    $body = $body -replace '^﻿?Windows Registry Editor Version 5\.00\s*', ''
    $file = $Root + '\imp_legacy.reg'
    Write-RegFile $file @(('[-' + $TcLegacyKeyRegFile + ']'), '', $body, ('[' + $TcLegacyKeyRegFile + '\Plugins Configuration\Probe343Imp]'), '"Imported"=dword:00000001')
    # the start migrates first (Settings made), then imports the file into Settings
    $before = Reports
    $id = Start-One $Exe '' @('-C', ('"{0}"' -f $file))
    $w = Start-Windows $id @(1, 6) 8
    $imp = 1 -eq (Get-Val ($TcConfigKeyName + '\Plugins Configuration\Probe343Imp') 'Imported')
    $legacyMarker = $null -ne (Get-Val ($TcLegacyKeyName + '\Plugins Configuration\Probe343Imp') 'Imported')
    End-Row 'IMP-LEGACY' $id $null $before
    Row 'IMP-LEGACY' 'IMPORT' (V ($imp -and -not $legacyMarker)) ("marker imported under Settings {0}; written under 0.1 {1}; windows: {2}" -f $imp, $legacyMarker, $w)
}
function Row-ImpForeign {
    Seed-Legacy   # an existing configuration: no first-start import offer
    $file = $Root + '\imp_foreign.reg'
    Write-RegFile $file @('[HKEY_CURRENT_USER\Software\Probe343Foreign]', '"x"=dword:00000001')
    $before = Reports
    $id = Start-One $Exe '' @('-C', ('"{0}"' -f $file))
    $w = Start-Windows $id @(1, 2) 8
    # the refusal comes before the main window exists (start-up import): wait for the window after it
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 1500
    $made = Key-Exists 'Software\Probe343Foreign'
    End-Row 'IMP-FOREIGN' $id $null $before
    Del-Key 'Software\Probe343Foreign'
    Row 'IMP-FOREIGN' 'IMPORT' (V (-not $made -and $w -ne 'no window')) ("foreign key made {0}; windows (a refusal expected): {1}" -f $made, (Tail $w 160))
}

$backup = Join-Path $env:TEMP 'tc343_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Out ("cfgroot343_probe (feature 343) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Legacy  : {0}" -f $(if ($LegacyExe) { $LegacyExe } else { '(none - the new build makes the 0.1 configuration)' }))
    Out ("Date    : {0}; parent key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    $how = Make-Fixture
    Out ("Fixture : 0.1 configuration {0}" -f $how)
    Out ''
    $h0 = $null
    if (Want 'BASIC') { try { $h0 = Row-Basic } catch { Row 'BASIC' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } }
    if ((Want 'AGAIN') -and $h0) { try { Row-Again $h0 } catch { Row 'AGAIN' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } }
    if ((Want 'BOTH') -and $h0) { try { Row-Both } catch { Row 'BOTH' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } }
    if (Want 'FRESH') { try { Row-Fresh } catch { Row 'FRESH' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } }
    if (Want 'KILL') { try { Row-Kill } catch { Row 'KILL' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } }
    foreach ($s in 'copy', 'compare', 'rename') { if (Want ('FAIL-' + $s)) { try { Row-Fail $s } catch { Row ('FAIL-' + $s) 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } } }
    if (Want 'CORRUPT') { try { Row-Corrupt } catch { Row 'CORRUPT' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } }
    if (Want 'IMP-LEGACY') { try { Row-ImpLegacy } catch { Row 'IMP-LEGACY' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } }
    if (Want 'IMP-FOREIGN') { try { Row-ImpForeign } catch { Row 'IMP-FOREIGN' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    Del-Key 'Software\Probe343Foreign'
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
