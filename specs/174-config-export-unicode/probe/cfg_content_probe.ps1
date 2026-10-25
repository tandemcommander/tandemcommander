<#
.SYNOPSIS
    Feature 174 probe: Export Configuration keeps every letter of the configuration's values and
    names, and importing the file (-C) restores them; older REGEDIT4 files still import.

.DESCRIPTION
    Fixture (written wide with .NET into the product's key, which the probe backs up and restores):
    HKCU\Software\Tandem Commander\Settings\Probe174 with
      Ascii   "plain text"                                  (control)
      Cz      Czech letters (inside code page 1250)
      Cyr     Cyrillic letters (outside 1250)
      Emoji   a letter outside the BMP (a surrogate pair)
      <Cyrillic value name> = "y"
      Exp     REG_EXPAND_SZ with Cyrillic letters
      Multi   REG_MULTI_SZ: the Czech and the Cyrillic text
      subkey  <Cyrillic key name> with "v" = "x"
    Rows (VAL: the values with ASCII names; NAME: the Cyrillic value name and key name alone):
      *-EXP-*   Options > Export Configuration (855) into a new file; the file is read (UTF-16 with
                a BOM, else code page 1250) and must hold each value's line exactly
      *-IMP-*   the Probe174 key deleted, the program started with -C <exported file>: each value
                read back (wide) must equal the original
      LONG-*    a value name of 601 Cyrillic characters and a key name of 200 (400 bytes of UTF-8)
      KEEPOLD   an existing backup.reg held open by another program (sharing read + delete): the
                old export could not write it and deleted it - now replaced or kept, never gone
      KEEPLOCK  the same, sharing read only: nothing can replace it - it keeps its old content
      LEGACY    a REGEDIT4 file in code page 1250 (as older versions wrote) with a Czech value,
                imported with -C: the value must come back with its Czech letters
      REG5      a "Windows Registry Editor Version 5.00" (UTF-16) file with a Cyrillic value,
                imported with -C
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
$Root = $TempRoot + '\tc174'
$StartDir = $Root + '\start'
function C([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
$Cz = C @(0x17D, 0x6C, 0x75, 0x165, 0x6F, 0x75, 0x10D, 0x6B, 0xFD, 0x20, 0x6B, 0x16F, 0x148)   # zlutoucky kun
$Cyr = C @(0x41F, 0x440, 0x438, 0x432, 0x435, 0x442, 0x20, 0x43C, 0x438, 0x440)               # privet mir
$Emoji = 'smile ' + (C @(0xD83D, 0xDE00))
$CyrName = C @(0x418, 0x43C, 0x44F)                                                            # imya
$CyrKey = C @(0x41A, 0x43B, 0x44E, 0x447)                                                      # klyuch
$SubPath = 'Software\Tandem Commander\Settings\Probe174'
$LongName = 'L' + ((C @(0x416)) * 600)       # a value name of 601 characters (the facade's stack buffer holds 511)
$LongKey = (C @(0x416)) * 200                 # a key name of 200 characters = 400 bytes of UTF-8
$Expected = [ordered]@{ 'Ascii' = 'plain text'; 'Cz' = $Cz; 'Cyr' = $Cyr; 'Emoji' = $Emoji }
$ExpText = '%TEMP%\' + $Cyr
$MultiText = @($Cz, $Cyr)

function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function NameBox([IntPtr]$Dlg) {
    if (-not (Kid $Dlg 1121 $null)) { return $null }
    return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::Cls([Drv098f]::GetParent($_)) -match 'ComboBox' -and ([Drv098f]::GetDlgCtrlID($_) -eq 1001 -or [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148) }) | Select-Object -First 1
}
# the export command: No to "save first?", OK to the information, the name typed, Save
function Drive-Export([int]$Id, [string]$Full) {
    $r = [pscustomobject]@{ Note = ''; Pre = @() }
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 855
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 20 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($c) {
            $sw2 = [Diagnostics.Stopwatch]::StartNew()
            while ($sw2.Elapsed.TotalSeconds -lt 5 -and -not (NameBox $c) -and [Drv098f]::Txt($c) -notmatch '^(Question|Information)$') { Start-Sleep -Milliseconds 200 }
            Start-Sleep -Milliseconds 600
            if ((NameBox $c)) { $od = $c; break }
            $d = WinDesc $c
            $r.Pre += $d
            $want = $(if ($d -match 'Do you want to save configuration') { 7 } elseif ($d -match 'If you want to import configuration') { 1 } else { 2 })
            $y = Buttons $c | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1
            if ($y) { Click $y } else { Post-Cmd $c 2 }
            $known = @($known) + @($c); Start-Sleep -Milliseconds 800; continue
        }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) { $r.Note = 'no save dialog; before it: ' + ($r.Pre -join ' || '); return $r }
    [void][Drv098f]::SetText((NameBox $od), $Full, 5000)
    $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
    $known2 = Get-Tops $Id
    if ($ok) { Click $ok } else { Post-Cmd $od 1 }
    # an existing file: the dialog's own "replace?" (a task dialog whose buttons have no ids) - Yes
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 4 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) {
        $cf = @(Get-Tops $Id | Where-Object { $known2 -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($cf) {
            Start-Sleep -Milliseconds 500
            $yes = @(Buttons $cf | Where-Object { [Drv098f]::Txt($_) -match '^&?(Ano|Yes)$' }) | Select-Object -First 1
            $r.Pre += ('replace? ' + (WinDesc $cf))
            if ($yes) { Click $yes } else { Close-Win $cf }
            break
        }
        Start-Sleep -Milliseconds 100
    }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
    if ([Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { $r.Note = 'the save dialog stayed open'; Post-Cmd $od 2; Start-Sleep -Milliseconds 800 }
    return $r
}
function Start-TcC([string]$CfgFile) {
    $a = @('-t', 'T098', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1', '-C', ('"{0}"' -f $CfgFile))
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $msgs = @()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) {
        foreach ($h in @(Get-Tops $p.Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowVisible($_) })) {
            $msgs += (WinDesc $h)
            $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($b) { Click $b } else { Close-Win $h }
            Start-Sleep -Milliseconds 600
        }
        Start-Sleep -Milliseconds 100
    }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw ('the program did not show its main window; boxes: ' + ($msgs -join ' || ')) }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return [pscustomobject]@{ Id = $p.Id; Boxes = $msgs }
}
function Write-Fixture([bool]$Names, [bool]$Long) {
    $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($SubPath)
    if ($Long) {
        $k.SetValue($LongName, 'z', [Microsoft.Win32.RegistryValueKind]::String)
        $s = $k.CreateSubKey($LongKey); $s.SetValue('w', 'q', [Microsoft.Win32.RegistryValueKind]::String); $s.Close()
    }
    elseif ($Names) {
        $k.SetValue($CyrName, 'y', [Microsoft.Win32.RegistryValueKind]::String)
        $s = $k.CreateSubKey($CyrKey); $s.SetValue('v', 'x', [Microsoft.Win32.RegistryValueKind]::String); $s.Close()
    }
    else {
        foreach ($n in $Expected.Keys) { $k.SetValue($n, $Expected[$n], [Microsoft.Win32.RegistryValueKind]::String) }
        $k.SetValue('Exp', $ExpText, [Microsoft.Win32.RegistryValueKind]::ExpandString)
        $k.SetValue('Multi', [string[]]$MultiText, [Microsoft.Win32.RegistryValueKind]::MultiString)
    }
    $k.Close()
}
function Remove-Fixture { try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($SubPath, $false) } catch { } }
function Read-Back {
    $o = @{}
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($SubPath)
    if ($null -eq $k) { return $null }
    foreach ($n in $k.GetValueNames()) { $o[$n] = $k.GetValue($n, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
    $s = $k.OpenSubKey($CyrKey); if ($s) { $o['<subkey>v'] = $s.GetValue('v'); $s.Close() }
    $s = $k.OpenSubKey($LongKey); if ($s) { $o['<longkey>w'] = $s.GetValue('w'); $s.Close() }
    $k.Close()
    return $o
}
function Read-RegFile([string]$p) {
    $b = [IO.File]::ReadAllBytes($LP + $p)
    if ($b.Length -ge 2 -and $b[0] -eq 0xFF -and $b[1] -eq 0xFE) { return [pscustomobject]@{ Kind = 'UTF-16'; Text = [Text.Encoding]::Unicode.GetString($b, 2, $b.Length - 2) } }
    return [pscustomobject]@{ Kind = 'code page'; Text = [Text.Encoding]::GetEncoding(1250).GetString($b) }
}
function RegQuote([string]$s) { return '"' + ($s -replace '\\', '\\' -replace '"', '\"') + '"' }

# VAL: values with letters outside the code page (ASCII names); NAME: a value name and a key name
# in Cyrillic. Export, read the file, delete the fixture, import with -C, read the values back.
function Run-ExportImport([string]$Tag, [bool]$Names, [bool]$Long) {
    if (-not (Want $Tag)) { return }
    $d = $Root + '\exp-' + $Tag.ToLower(); NewDir $d
    $file = $d + '\cfg.reg'
    Remove-Fixture; Write-Fixture $Names $Long
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $StartDir
        $r = Drive-Export $id $file
        $after = Serve $id 20 @(1, 6)
        End-Row ($Tag + '-EXP') $id $null $before; $id = 0
        if (-not [IO.File]::Exists($LP + $file)) { Row ($Tag + '-EXP') 'FILE' 'FAIL' ('no file; ' + $r.Note + '; ' + (Msgs $after)); return }
        $f = Read-RegFile $file
        $lines = $f.Text -split "`r`n"
        Out ('           file: ' + $f.Kind + ', header ' + (Esc $lines[0]) + ', ' + $lines.Count + ' lines')
        if ($Long) {
            $want = (RegQuote $LongName) + '="z"'
            $got = @($lines | Where-Object { $_.StartsWith('"L') -and $_.EndsWith('="z"') }) | Select-Object -First 1
            Row 'LONG-EXP-VNAME' 'LINE' (V ($got -ceq $want)) ("a value name of {0} characters; the file's line has {1}" -f $LongName.Length, $(if ($got) { $got.Length - 6 } else { 'none' }))
            $keyLine = @($lines | Where-Object { $_.EndsWith('\Probe174\' + $LongKey + ']') }) | Select-Object -First 1
            Row 'LONG-EXP-KEY' 'LINE' (V ($null -ne $keyLine)) ("a key name of {0} characters: {1}" -f $LongKey.Length, $(if ($keyLine) { 'in the file' } else { 'missing' }))
        }
        elseif ($Names) {
            $want = (RegQuote $CyrName) + '="y"'
            $got = @($lines | Where-Object { $_ -match '^"[^"]{3}"="y"$' }) | Select-Object -First 1
            Row 'NAME-EXP-VNAME' 'LINE' (V ($got -ceq $want)) ("want {0}; file {1}" -f (Esc $want), (Esc $got))
            $keyLine = @($lines | Where-Object { $_ -like '*\Probe174\*]' }) | Select-Object -First 1
            Row 'NAME-EXP-KEY' 'LINE' (V ($null -ne $keyLine -and $keyLine.EndsWith('\Probe174\' + $CyrKey + ']'))) ("file {0}" -f (Esc $keyLine))
        }
        else {
            foreach ($n in $Expected.Keys) {
                $want = (RegQuote $n) + '=' + (RegQuote $Expected[$n])
                $got = @($lines | Where-Object { $_.StartsWith((RegQuote $n) + '=') }) | Select-Object -First 1
                Row ('VAL-EXP-' + $n.ToUpper()) 'LINE' (V ($got -ceq $want)) ("want {0}; file {1}" -f (Esc $want), (Esc $got))
            }
        }

        Remove-Fixture
        $s = Start-TcC $file
        $id = $s.Id
        $back = Read-Back
        Out ('           import boxes: ' + (Esc ($s.Boxes -join ' || ')))
        End-Row ($Tag + '-IMP') $id $null $before; $id = 0
        if ($null -eq $back) { Row ($Tag + '-IMP') 'KEY' 'FAIL' 'the Probe174 key was not imported'; return }
        if ($Long) {
            $g = $back[$LongName]; Row 'LONG-IMP-VNAME' 'VALUE' (V ($g -ceq 'z')) ("the long value name: '{0}'" -f (Esc ([string]$g)))
            $g = $back['<longkey>w']; Row 'LONG-IMP-KEY' 'VALUE' (V ($g -ceq 'q')) ("the long key's w: '{0}'" -f (Esc ([string]$g)))
        }
        elseif ($Names) {
            $g = $back[$CyrName]; Row 'NAME-IMP-VNAME' 'VALUE' (V ($g -ceq 'y')) ("the Cyrillic value name: '{0}'; names read back: {1}" -f (Esc ([string]$g)), (Esc (@($back.Keys) -join ',')))
            $g = $back['<subkey>v']; Row 'NAME-IMP-KEY' 'VALUE' (V ($g -ceq 'x')) ("the Cyrillic subkey's v: '{0}'" -f (Esc ([string]$g)))
        }
        else {
            foreach ($n in $Expected.Keys) {
                $g = $back[$n]
                Row ('VAL-IMP-' + $n.ToUpper()) 'VALUE' (V ($g -is [string] -and $g -ceq $Expected[$n])) ("want '{0}'; got '{1}'" -f (Esc $Expected[$n]), (Esc ([string]$g)))
            }
            $g = $back['Exp']; Row 'VAL-IMP-EXP' 'VALUE' (V ($g -ceq $ExpText)) ("want '{0}'; got '{1}'" -f (Esc $ExpText), (Esc ([string]$g)))
            $g = $back['Multi']; Row 'VAL-IMP-MULTI' 'VALUE' (V ($g -is [array] -and $g.Count -eq 2 -and $g[0] -ceq $MultiText[0] -and $g[1] -ceq $MultiText[1])) ("want '{0}'; got '{1}'" -f (Esc ($MultiText -join '|')), (Esc (@($g) -join '|')))
        }
    }
    catch { Row $Tag 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Tag $id $null $before }; Remove-Fixture }
}

# an existing backup held open by another program: KEEPOLD shares reading and deleting (the old
# export could not open it for writing and then deleted it), KEEPLOCK shares reading only (nothing
# can replace it) - afterwards the backup holds its old content or a complete new export, never
# nothing, and no temporary file is left in its folder
function Run-ExportLocked([string]$Case, [IO.FileShare]$Share) {
    if (-not (Want $Case)) { return }
    Remove-Fixture
    $d = $Root + '\' + $Case.ToLower(); NewDir $d
    $file = $d + '\backup.reg'
    $old = "REGEDIT4`r`n`r`n; the user's older backup`r`n"
    [IO.File]::WriteAllText($LP + $file, $old, (New-Object Text.ASCIIEncoding))
    $held = [IO.File]::Open($LP + $file, [IO.FileMode]::Open, [IO.FileAccess]::Read, $Share)
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $StartDir
        $r = Drive-Export $id $file
        # the dialog asks before overwriting an existing file (a task dialog: Yes has no id) - Alt+Y is
        # not available on the hidden desktop: the confirmation is answered through its first button
        $after = Serve $id 20 @(1, 6)
        $held.Close(); $held = $null; Start-Sleep -Milliseconds 300
        End-Row $Case $id $null $before; $id = 0
        $now = $null; if ([IO.File]::Exists($LP + $file)) { $now = [IO.File]::ReadAllText($LP + $file) }
        $left = @([IO.Directory]::GetFiles($LP + $d) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { $_ -ne 'backup.reg' })
        Row $Case 'FILE' (V (($now -ceq $old -or ($null -ne $now -and $now.StartsWith([string][char]0xFEFF + 'Windows Registry Editor'))) -and $left.Count -eq 0)) ("the backup now: {0}; other files: {1}; {2}windows: {3}" -f $(if ($null -eq $now) { 'MISSING' } elseif ($now -ceq $old) { 'the old content' } else { 'new content' }), ($left -join ', '), $(if ($r.Note) { $r.Note + '; ' } else { '' }), (Msgs $after))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($held) { $held.Close() }; if ($id) { End-Row $Case $id $null $before } }
}

# a .reg file written by the probe, imported with -C; $check gets the read-back values
function Run-FileImport([string]$Case, [byte[]]$Bytes, [string]$Value, [string]$Want) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case.ToLower(); NewDir $d
    $file = $d + '\in.reg'
    [IO.File]::WriteAllBytes($LP + $file, $Bytes)
    Remove-Fixture
    $id = 0; $before = Reports
    try {
        $s = Start-TcC $file
        $id = $s.Id
        $back = Read-Back
        End-Row $Case $id $null $before; $id = 0
        $g = $null; if ($back) { $g = $back[$Value] }
        Row $Case 'VALUE' (V ($g -ceq $Want)) ("want '{0}'; got '{1}'; boxes: {2}" -f (Esc $Want), (Esc ([string]$g)), (Esc ($s.Boxes -join ' || ')))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc174_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
$AppDir = Join-Path $env:APPDATA 'Tandem Commander'
$AppDirExisted = Test-Path -LiteralPath $AppDir
$AppDirBefore = @(); if ($AppDirExisted) { $AppDirBefore = @(Get-ChildItem -LiteralPath $AppDir -Force | ForEach-Object { $_.Name }) }
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cfg_content_probe (feature 174), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    Run-ExportImport 'VAL' $false $false
    Run-ExportImport 'NAME' $true $false
    Run-ExportImport 'LONG' $false $true
    Run-ExportLocked 'KEEPOLD' ([IO.FileShare]::Read -bor [IO.FileShare]::Delete)
    Run-ExportLocked 'KEEPLOCK' ([IO.FileShare]::Read)
    $root01 = '[HKEY_CURRENT_USER\Software\Tandem Commander\Settings]'
    $legacy = "REGEDIT4`r`n`r`n" + $root01 + "`r`n`r`n[HKEY_CURRENT_USER\" + $SubPath + "]`r`n" + '"Legacy"=' + (RegQuote $Cz) + "`r`n"
    Run-FileImport 'LEGACY' ([Text.Encoding]::GetEncoding(1250).GetBytes($legacy)) 'Legacy' $Cz
    $reg5 = "Windows Registry Editor Version 5.00`r`n`r`n" + $root01 + "`r`n`r`n[HKEY_CURRENT_USER\" + $SubPath + "]`r`n" + '"Reg5"=' + (RegQuote $Cyr) + "`r`n"
    Run-FileImport 'REG5' ([byte[]](@(0xFF, 0xFE) + [Text.Encoding]::Unicode.GetBytes($reg5))) 'Reg5' $Cyr
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $AppDirNow = @(); if (Test-Path -LiteralPath $AppDir) { $AppDirNow = @(Get-ChildItem -LiteralPath $AppDir -Force | ForEach-Object { $_.Name }) }
    $newInApp = @($AppDirNow | Where-Object { $AppDirBefore -notcontains $_ })
    if ($newInApp.Count) { Out ('APPDATA: NEW ITEMS in ' + $AppDir + ': ' + ($newInApp -join ', ') + ' - left for a look') }
    elseif (-not $AppDirExisted -and (Test-Path -LiteralPath $AppDir)) { Remove-Item -LiteralPath $AppDir -Force; Out ('APPDATA: the folder the export created removed (it was empty)') }
    else { Out 'APPDATA: unchanged' }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
if ($Expect -eq 'before') { exit 0 }
exit $nf
