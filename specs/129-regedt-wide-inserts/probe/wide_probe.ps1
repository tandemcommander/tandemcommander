<#
.SYNOPSIS
    Feature 129 probe: the Registry Editor plug-in's texts and paths that are composed with a
    wide insert ("%ls") in a narrow format - with registry names that hold letters outside ASCII.

.DESCRIPTION
    Fixture (created and removed by the probe): HKCU\Software\TcProbe129 with two keys whose
    names hold Czech accents ("<accent> 1", "<accent> 2"), each with a text value "v"
    (ALPHA / OMEGA), and an ASCII pair ("plain 1", "plain 2") as the control.

      OPENKEY  Change Directory to a key that does not exist, with an accented name: the error
               box names the whole key and gives the Windows reason
      VIEW     F3 on "v" in the first key, then (the first viewer still open) F3 on "v" in the
               second key: each viewer shows the data of ITS key (read from a capture) and
               has its own file in the disk cache (the viewer's title). The name the plug-in
               gives the disk cache is composed from the key's path - with a failed
               composition both values get the same cache name and the same file
      VIEWA    the same with the ASCII pair (control)
      VIEWSEQ  the first viewer is closed before the second value is viewed
      VIEWFOLD two keys whose names differ only in letters that a byte-wise lower-case table of
               code page 1250 makes equal in UTF-8: still two files
      CREATE   F5 (Copy) of the first key to a target under a key that does not exist, with an
               accented name: the question whether to create it names the target
      SELF     F5 of the first key onto itself: the message names the key
      END      each instance ends with exit code 0, no stray window, no report

    With -Expect before the same checks run on a build without the fix (the control: the rows
    with accented names are expected to FAIL there).

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$ShotDir,
    [string]$Lang = 'czech'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\124-regedt-key-text\probe\shotocr_lib.ps1')

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$Root = $TempRoot + '\tc129'
$StartDir = $Root + '\start'
if (-not $ShotDir) { $ShotDir = $Root + '\shots' }
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# "Klic zlutoucky" with its Czech accents (pure ASCII source)
$Accent = 'Kl' + (Chars @(0x00ED, 0x010D)) + ' ' + [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD
$RegName = 'TcProbe129'
$RegPs = 'HKCU:\Software\' + $RegName
$RegFs = 'reg:\HKEY_CURRENT_USER\Software\' + $RegName
$RegFull = 'HKEY_CURRENT_USER\Software\' + $RegName

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P {
    $a = @('-t', 'T129', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
function Template([int]$Id, [string]$English) {
    if ($Lang -eq 'english') { return $English }
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $RepoRoot ("translations\{0}\regedt.slt" -f $Lang)), $Utf8)) {
        if ($line -match ('^' + $Id + ',\d+,"(.*)"\s*$')) { return $Matches[1].Replace('""', '"').Replace('\n', "`n").Replace('\t', "`t").Replace('\\', '\') }
    }
    throw "id $Id not found in the $Lang translation"
}
function End-P([string]$Case, [int]$Id, $Before) { $fatal = Fatal-Win $Id; End-Row $Case $Id $fatal $Before }
# letters that only a wrong reading of UTF-8 bytes in the code page produces
function Garbled([string]$t) { return [bool]($t -match ('[' + (Chars @(0x0102, 0x0139, 0x00C4, 0x00C3, 0x00C5, 0x00E2, 0x20AC, 0xFFFD)) + ']')) }
# every text of a dialog but its buttons (static 2477 of the program's message box first)
function Box-Text([IntPtr]$H) {
    $st = Kid $H 2477
    if ($st) { return [Drv098f]::GetText($st, 5000).Replace("`r", '') }
    return (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::Cls($_) -ne 'Button' } | ForEach-Object { [Drv098f]::GetText($_, 5000).Replace("`r", '') } | Where-Object { $_ }) -join "`n")
}
function New-Boxes([int]$Id, $Known, [double]$Seconds = 12) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $n = @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' })
        if ($n.Count) { Start-Sleep -Milliseconds 700; return $n }
        Start-Sleep -Milliseconds 150
    }
    return @()
}
function Press([IntPtr]$H, [int[]]$Ids) {
    if ($H -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($H)) { return }
    # the first id of $Ids that the window has (not the first button in the window's own order)
    $b = $null
    foreach ($want in $Ids) { $b = Buttons $H | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1; if ($b) { break } }
    if ($b) { Click $b } else { Close-Win $H }
    Start-Sleep -Milliseconds 600
}
function Close-Boxes([int]$Id) {
    for ($i = 0; $i -lt 6; $i++) {
        $b = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })
        if (-not $b.Count) { return }
        foreach ($h in $b) { Press $h @(2, 7, 1) }
    }
}
function Go([int]$Id, [string]$Path) { [void](Do-ChangeDir $Id $Path); Sync $Id; Start-Sleep -Milliseconds 1200 }

function Make-Fixture {
    NewDir $StartDir
    [void][IO.Directory]::CreateDirectory($ShotDir)
    Remove-Item -LiteralPath $RegPs -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($k in @(@(($Accent + ' 1'), 'ALPHA'), @(($Accent + ' 2'), 'OMEGA'), @('plain 1', 'ALPHA'), @('plain 2', 'OMEGA'))) {
        [void](New-Item -Path ($RegPs + '\' + $k[0]) -Force)
        [void](New-ItemProperty -LiteralPath ($RegPs + '\' + $k[0]) -Name 'v' -Value $k[1] -PropertyType String -Force)
    }
    foreach ($k in @(@(('zfold ' + [char]0x00EA), 'ALPHA'), @(('zfold ' + [char]0x00FA), 'OMEGA'))) {
        [void](New-Item -Path ($RegPs + '\' + $k[0]) -Force)
        [void](New-ItemProperty -LiteralPath ($RegPs + '\' + $k[0]) -Name 'v' -Value $k[1] -PropertyType String -Force)
    }
    [void](New-Item -Path ($RegPs + '\' + $Accent + ' 1\sub') -Force)       # the target of the SELF row
}

# OPENKEY
function Row-OpenKey {
    if (-not (Want 'OPENKEY')) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P
        $missing = $Accent + ' nen' + [char]0x00ED
        $known = Get-Tops $id
        $dlg = Open-ByCmd $id 862
        if ($dlg -eq [IntPtr]::Zero) { throw 'Change Directory (862) opened no window' }
        [void][Drv098f]::SetText((Find-Ctl $dlg 210), ($RegFs + '\' + $missing), 5000)
        Click-Ok $dlg
        $seen = @(); $hit = $null; $sw = [Diagnostics.Stopwatch]::StartNew(); $done = @{}
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $null -eq $hit) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) {
                $k = $h.ToInt64(); if ($done.ContainsKey($k)) { continue }
                Start-Sleep -Milliseconds 600
                if (Kid $h 210) { $done[$k] = 1; continue }                 # the Change Directory dialog itself
                $t = Box-Text $h; $done[$k] = 1; $seen += ('[' + (Esc ([Drv098f]::Txt($h))) + '] ' + (Esc $t))
                $hit = $t; Press $h @(1, 2)
            }
            Start-Sleep -Milliseconds 200
        }
        $head = (Template 1037 'Unable to open registry key "%ls". ').Replace('%ls', ($RegFull + '\' + $missing))
        $err2 = (New-Object ComponentModel.Win32Exception 2).Message
        $ok = ($null -ne $hit) -and $hit.StartsWith($head.TrimEnd(), [StringComparison]::Ordinal) -and $hit.Contains($err2.TrimEnd('.', ' ')) -and -not (Garbled $hit)
        Row 'OPENKEY' 'TEXT' (V $ok) ("box text '{0}'; expected to start with '{1}' and to hold the Windows reason '{2}'; boxes: {3}" -f (Esc $hit), (Esc $head.TrimEnd()), (Esc $err2), ($seen -join ' || '))
        Close-Boxes $id
    }
    catch { Row 'OPENKEY' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Close-Boxes $id; End-P 'OPENKEY' $id $before } }
}

# VIEW / VIEWA
function Row-View([string]$Case, [string]$Base, [bool]$CloseFirst = $false, [string[]]$Names = $null) {
    if (-not $Names) { $Names = @(($Base + ' 1'), ($Base + ' 2')) }
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0; $views = @()
    try {
        $id = Start-P
        $read = @(); $titles = @()
        foreach ($n in 1, 2) {
            if ($CloseFirst -and $views.Count) { foreach ($w in $views) { if ([Drv098f]::IsWindow($w)) { Close-Win $w; Start-Sleep -Milliseconds 900 } }; $views = @() }
            Go $id ($RegFs + '\' + $Names[$n - 1])
            Key $id 0x23                                         # End: the value "v" (the last item)
            $known = Get-Tops $id
            Post-Cmd (Get-Main $id) 742                          # CM_VIEW
            $w = Wait-NewWin $id $known 15
            if ($w -eq [IntPtr]::Zero) { $read += '<no viewer>'; continue }
            if ([Drv098f]::Cls($w) -eq '#32770') { $read += ('<box> ' + (Esc (Box-Text $w))); Press $w @(1, 2); continue }
            $views += $w
            Start-Sleep -Milliseconds 1500
            $titles += [Drv098f]::Txt($w)
            $s = Shot-Read $w $w (Join-Path $ShotDir ("{0}_{1}_{2}.png" -f $Expect, $Case, $n)) 2
            $read += ('[' + (Esc ([Drv098f]::Txt($w))) + '] ' + (($s.Lines -join ' | ')))
        }
        $a = ($read.Count -ge 1) -and ((Ocr-Has @($read[0]) 'ALPHA') -ne 'no')
        $b = ($read.Count -ge 2) -and ((Ocr-Has @($read[1]) 'OMEGA') -ne 'no') -and ((Ocr-Has @($read[1]) 'ALPHA') -eq 'no')
        if (-not $CloseFirst) {
            # the viewer's title is the file in the disk cache: two values of two keys, two files
            $distinct = ($titles.Count -eq 2) -and ($titles[0] -cne $titles[1])
            Row $Case 'CACHE' (V $distinct) ("both viewers open: their cache files are different files: {0}; titles: {1}" -f $distinct, (($titles | ForEach-Object { "'" + (Esc $_) + "'" }) -join ' and '))
        }
        Row $Case 'DATA' (V ($a -and $b)) ("viewer of '{0} 1\v' shows ALPHA: {1}; viewer of '{0} 2\v' shows OMEGA and not ALPHA: {2}; recognized: {3}" -f (Esc $Base), $a, $b, (($read | ForEach-Object { Esc $_ }) -join ' || '))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        foreach ($w in $views) { if ([Drv098f]::IsWindow($w)) { Close-Win $w; Start-Sleep -Milliseconds 500 } }
        if ($id) { Close-Boxes $id; End-P $Case $id $before }
    }
}

# CREATE / SELF: Copy of the first key; the plug-in's own dialog asks for the target
function Row-Copy([string]$Case, [string]$Target, [int]$TemplId, [string]$English, [string[]]$Inserts) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        Make-Fixture                                             # (an earlier row may have left keys)
        $id = Start-P
        Go $id $RegFs
        Key $id 0x24; Key $id 0x28                               # "..", the first key (the accented names sort first)
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 727                              # CM_COPYFILES
        $dlg = Wait-NewWin $id $known 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'TEXT' 'FAIL' 'Copy opened no dialog'; return }
        $edit = @([Drv098f]::Kids($dlg) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) }) | Select-Object -First 1
        $what = WinDesc $dlg
        $pre = $(if ($edit) { [Drv098f]::GetText($edit, 5000) } else { '<no edit>' })
        if (-not $edit) { Row $Case 'TEXT' 'FAIL' ('no edit field in the Copy dialog: ' + $what); return }
        [void][Drv098f]::SetText($edit, $Target, 5000)
        $known2 = Get-Tops $id
        Click-Ok $dlg
        $boxes = New-Boxes $id $known2 12
        $want = Template $TemplId $English
        foreach ($ins in $Inserts) { $i = $want.IndexOf('%ls'); $want = $want.Substring(0, $i) + $ins + $want.Substring($i + 3) }
        $t = $(if ($boxes.Count) { Box-Text $boxes[0] } else { $null })
        $norm = $(if ($null -ne $t) { $t.Trim() } else { $null })
        Row $Case 'TEXT' (V ($norm -ceq $want.Trim())) ("the dialog offered '{0}'; typed '{1}'; box text '{2}'; expected '{3}'; box: {4}" -f (Esc $pre), (Esc $Target), (Esc $t), (Esc $want), $(if ($boxes.Count) { WinDesc $boxes[0] } else { 'none; windows: ' + ((Get-Tops $id | ForEach-Object { WinDesc $_ }) -join ' || ') }))
        Close-Boxes $id
        Start-Sleep -Milliseconds 800
        # nothing may have been copied or created: the row answers No / Cancel
        $subs = @(Get-ChildItem -LiteralPath $RegPs -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.Name.Substring($_.Name.IndexOf($RegName) + $RegName.Length) })
        Row $Case 'STATE' (V ($subs.Count -eq 7)) ("keys under the fixture after the answer: {0} (expected the 7 of the fixture): {1}" -f $subs.Count, (($subs | ForEach-Object { Esc $_ }) -join ' , '))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Close-Boxes $id; End-P $Case $id $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc129_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    Out ("wide_probe (feature 129), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Fixture : {0} with keys '{1} 1', '{1} 2', 'plain 1', 'plain 2', each with the text value 'v'" -f $RegPs, (Esc $Accent))
    Out ''
    Row-OpenKey
    Row-View 'VIEWA' 'plain'
    Row-View 'VIEW' $Accent
    Row-View 'VIEWSEQ' $Accent $true
    # two names that differ only in letters a byte-wise lower-case table of code page 1250 makes
    # equal in UTF-8 (e-circumflex C3 AA / u-acute C3 BA)
    Row-View 'VIEWFOLD' 'zfold' $false @(('zfold ' + [char]0x00EA), ('zfold ' + [char]0x00FA))
    $missingTarget = 'C' + [char]0x00ED + 'l ' + [char]0x0159 + 'x'
    Row-Copy 'CREATE' ('\HKEY_CURRENT_USER\Software\' + $RegName + '\' + $missingTarget + '\New') 1077 'Target key "%ls\%ls" doesn''t exist. Do you want to create it?' @('HKEY_CURRENT_USER', ('Software\' + $RegName + '\' + $missingTarget))
    Row-Copy 'SELF' ('\HKEY_CURRENT_USER\Software\' + $RegName + '\' + $Accent + ' 1\sub') 1065 ("Name:`t%ls`n`nError:`tCan't copy a key to itself.") @(($Accent + ' 1'))
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    Remove-Item -LiteralPath $RegPs -Recurse -Force -ErrorAction SilentlyContinue
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $StartDir)) { [IO.Directory]::Delete($LP + $StartDir, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture key removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not (Test-Path -LiteralPath $RegPs)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
