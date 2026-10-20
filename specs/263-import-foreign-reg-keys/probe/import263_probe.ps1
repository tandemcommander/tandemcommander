<#
.SYNOPSIS
    Feature 263 probe: the start-up import of a configuration file (-C <file>) never writes a key outside
    the program's own root HKCU\Software\Tandem Commander\0.1.

.DESCRIPTION
    Per row a fixture <row>\config.reg (UTF-16 "Windows Registry Editor Version 5.00", as regedit and the
    program's own export write it) is given with -C. Message boxes shown during the start are recorded and
    answered Yes (6) or OK (1) - the worst case of the old question. After the main window appears the
    program is closed and the registry is read.
      OURS    the control: only keys under our root - imported (Probe263 "v" = "1"), no message
      OWNDEL  the control: a delete line inside our root ([-...\0.1\Probe263Old]) and a key - Old removed,
              Probe263 imported, no message
      MIXED   our key + the foreign key HKCU\Software\TC263ProbeForeign - PASS = a message ("not a
              configuration file"), the foreign key NOT written and our key NOT imported
      NOROOT  only the foreign key - PASS = the foreign key NOT written, the refusal shown, no question
      DELROOTONLY  only [-HKCU\Software\Tandem Commander\0.1] - refused, no question, the configuration kept
      EMPTY   a .reg file without any key - refused, no question (review 2)
      DELETE  our key + [-HKCU\Software\TC263ProbeVictim] (the victim made by the probe) - PASS = the
              victim still exists
      EXPORTSHAPE  the shape of the program's own export: [HKCU\Software], [HKCU\Software\Tandem Commander],
              the root, our key - imported, no message (review 1)
      PARENTVAL   a value in [HKCU\Software\Tandem Commander] + our key - refused, the value not written
      PARENTDEL   [-HKCU\Software\Tandem Commander] + our key - refused, the configuration still there
      EXPORTCLEAR the clear-key export: [-root], the parents, the whole current configuration (reg export), our
              key - imported, no message
      REALBACKUP  the newest settings backup of feature 245 (a file the program wrote) - imported (the marker
              key Probe263Old made before the start is removed by its delete line of the root), no message;
              NOT DRIVEN when there is none
      HKCR    our key + [HKEY_CLASSES_ROOT\TC263ProbeClass] - PASS = a message, the class key exists
              neither in HKCU\Software\Classes nor in HKLM\Software\Classes, our key not imported
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified; the probe's
    own foreign keys are removed. Exit code = number of FAIL rows.
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
$Root = $TempRoot + '\tc263'
$StartDir = $Root + '\start'
$Ours = 'HKEY_CURRENT_USER\Software\Tandem Commander\0.1'
$PsOurs = 'HKCU:\Software\Tandem Commander\0.1'
$Foreign = 'TC263ProbeForeign'
$Victim = 'TC263ProbeVictim'
$Class = 'TC263ProbeClass'

function Clear-ProbeKeys {
    foreach ($k in @("HKCU:\Software\$Foreign", "HKCU:\Software\$Victim", "HKCU:\Software\Classes\$Class", "$PsOurs\Probe263", "$PsOurs\Probe263Old")) {
        if (Test-Path -LiteralPath $k) { Remove-Item -LiteralPath $k -Recurse -Force }
    }
    Remove-ItemProperty -LiteralPath 'HKCU:\Software\Tandem Commander' -Name 'TC263ProbeParentValue' -ErrorAction SilentlyContinue
}
function Has([string]$k) { return [bool](Test-Path -LiteralPath $k) }
function OurValue {
    try { return (Get-ItemProperty -LiteralPath "$PsOurs\Probe263" -Name 'v' -ErrorAction Stop).v } catch { return $null }
}

# serves the start: records message boxes (windows with buttons), answers Yes / OK; returns when the
# main window is there and no box is open
function Serve-Start([int]$Id, [double]$Seconds = 60) {
    $msgs = New-Object System.Collections.ArrayList
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $seen = @{}
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        $boxes = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and [Drv098f]::IsWindowVisible($_) -and (Buttons $_).Count -gt 0 })
        if (-not $boxes.Count) {
            if ((Get-Main $Id) -ne [IntPtr]::Zero) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        foreach ($h in $boxes) {
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.8) { continue }
            $seen.Remove($key)
            [void]$msgs.Add((WinDesc $h))
            $pick = Buttons $h | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Sort-Object { if ([Drv098f]::GetDlgCtrlID($_) -eq 6) { 0 } else { 1 } } | Select-Object -First 1
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
    }
    return , $msgs
}

function Run-Case([string]$Case, [string[]]$Body, [scriptblock]$Prepare, [scriptblock]$Judge, [string]$CopyFrom) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    NewDir $d
    $file = $d + '\config.reg'
    if ($CopyFrom) { [IO.File]::Copy($CopyFrom, $LP + $file, $true) }
    else {
        $text = "Windows Registry Editor Version 5.00`r`n`r`n" + (($Body | ForEach-Object { $_ }) -join "`r`n") + "`r`n"
        [IO.File]::WriteAllText($LP + $file, $text, (New-Object Text.UnicodeEncoding($false, $true)))
    }
    Clear-ProbeKeys
    if ($Prepare) { & $Prepare }
    $id = 0; $before = Reports
    try {
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T263', '-c', ('"{0}"' -f $file), '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $msgs = Serve-Start $id
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 1000
        $r = Serve $id 10
        foreach ($m in $r.Messages) { [void]$msgs.Add($m) }
        End-Row $Case $id $null $before; $id = 0
        $facts = [pscustomobject]@{
            Msgs = $(if ($msgs.Count) { $msgs -join ' || ' } else { 'no window' })
            Foreign = Has "HKCU:\Software\$Foreign"
            Victim = Has "HKCU:\Software\$Victim"
            Old = Has "$PsOurs\Probe263Old"
            Value = OurValue
            Class = (Has "HKCU:\Software\Classes\$Class") -or (Has "HKLM:\Software\Classes\$Class")
            ParentVal = $null -ne (Get-ItemProperty -LiteralPath 'HKCU:\Software\Tandem Commander' -Name 'TC263ProbeParentValue' -ErrorAction SilentlyContinue)
            Config = Has "$PsOurs\Configuration"
        }
        $ok = & $Judge $facts
        Row $Case 'RUN' (V $ok) ("foreign key {0}; victim {1}; class key {2}; parent value {3}; Probe263Old {4}; Probe263 v={5}; Configuration key {6}; windows: {7}" -f $facts.Foreign, $facts.Victim, $facts.Class, $facts.ParentVal, $facts.Old, $(if ($null -eq $facts.Value) { '<none>' } else { $facts.Value }), $facts.Config, $facts.Msgs)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before }; Clear-ProbeKeys }
}

$backup = Join-Path $env:TEMP 'tc263_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("import263_probe (feature 263) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    $ourKey = @("[$Ours\Probe263]", '"v"="1"', '')
    $foreignKey = @("[HKEY_CURRENT_USER\Software\$Foreign]", '"x"="1"', '')
    Run-Case 'OURS' $ourKey $null { param($f) $f.Value -eq '1' -and $f.Msgs -eq 'no window' }
    Run-Case 'OWNDEL' (@("[-$Ours\Probe263Old]", '') + $ourKey) { [void](New-Item -Path "$PsOurs\Probe263Old" -Force) } { param($f) $f.Value -eq '1' -and -not $f.Old -and $f.Msgs -eq 'no window' }
    Run-Case 'MIXED' ($ourKey + $foreignKey) $null { param($f) -not $f.Foreign -and $null -eq $f.Value -and $f.Msgs -match 'not a configuration file' }
    Run-Case 'NOROOT' $foreignKey $null { param($f) -not $f.Foreign -and $f.Msgs -match 'not a configuration file' -and $f.Msgs -notmatch 'anyway' }
    # review 2: the files the old question let through without a foreign key - Yes wiped the configuration
    Run-Case 'DELROOTONLY' @("[-$Ours]", '') $null { param($f) $f.Config -and $f.Msgs -match 'not a configuration file' -and $f.Msgs -notmatch 'anyway' }
    Run-Case 'EMPTY' @() $null { param($f) $f.Config -and $f.Msgs -match 'not a configuration file' -and $f.Msgs -notmatch 'anyway' }
    Run-Case 'DELETE' ($ourKey + @("[-HKEY_CURRENT_USER\Software\$Victim]", '')) { $k = New-Item -Path "HKCU:\Software\$Victim" -Force; [void](New-ItemProperty -LiteralPath "HKCU:\Software\$Victim" -Name 'keep' -Value 'me' -Force) } { param($f) $f.Victim -and $null -eq $f.Value }
    Run-Case 'HKCR' ($ourKey + @("[HKEY_CLASSES_ROOT\$Class]", '"x"="1"', '')) $null { param($f) -not $f.Class -and $null -eq $f.Value -and $f.Msgs -match 'not a configuration file' }
    # review 1 (MUST): the program's own export writes the keys above the root as lines of their own
    $parents = @('[HKEY_CURRENT_USER\Software]', '', '[HKEY_CURRENT_USER\Software\Tandem Commander]', '', "[$Ours]", '')
    Run-Case 'EXPORTSHAPE' ($parents + $ourKey) $null { param($f) $f.Value -eq '1' -and $f.Msgs -eq 'no window' }
    Run-Case 'PARENTVAL' (@('[HKEY_CURRENT_USER\Software\Tandem Commander]', '"TC263ProbeParentValue"="1"', '') + $ourKey) $null { param($f) -not $f.ParentVal -and $null -eq $f.Value -and $f.Msgs -match 'not a configuration file' }
    Run-Case 'PARENTDEL' (@('[-HKEY_CURRENT_USER\Software\Tandem Commander]', '') + $ourKey) $null { param($f) $f.Config -and $null -eq $f.Value -and $f.Msgs -match 'not a configuration file' }
    if (Want 'EXPORTCLEAR') {
        # the export with "clear the key before import": the delete line of the root, the parents, the whole configuration
        $tmp = $Root + '\current.reg'
        & cmd.exe /c "reg export `"$RegKey\0.1`" `"$tmp`" /y >nul 2>&1"
        $cur = @([IO.File]::ReadAllLines($LP + $tmp, [Text.Encoding]::Unicode) | Select-Object -Skip 1)
        Run-Case 'EXPORTCLEAR' (@("[-$Ours]", '') + $parents + $cur + @('') + $ourKey) $null { param($f) $f.Value -eq '1' -and $f.Config -and $f.Msgs -eq 'no window' }
    }
    if (Want 'REALBACKUP') {
        # a file the program wrote: the newest settings backup of feature 245 (ExportConfiguration with the clear-key line)
        $bk = @(Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'Tandem Commander\Settings backups') -Filter '*.reg' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1)
        # the marker key Probe263Old is not in the backup: its delete line of the root removes it - proof of the import
        if ($bk.Count) { Run-Case 'REALBACKUP' $null { [void](New-Item -Path "$PsOurs\Probe263Old" -Force) } { param($f) $f.Config -and -not $f.Old -and $f.Msgs -eq 'no window' } $bk[0].FullName; Out ('           (REALBACKUP = ' + $bk[0].Name + ')') }
        else { Row 'REALBACKUP' 'RUN' 'NOT DRIVEN' 'no settings backup of feature 245 on this machine' }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    Clear-ProbeKeys
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; probe keys left: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), ((Has "HKCU:\Software\$Foreign") -or (Has "HKCU:\Software\$Victim") -or (Has "HKCU:\Software\Classes\$Class")), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
