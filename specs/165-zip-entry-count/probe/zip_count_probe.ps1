<#
.SYNOPSIS
    Feature 165 probe: the entry counts the ZIP plug-in writes into an archive's end records when
    the archive has (or had) 65,535 entries or more.

.DESCRIPTION
    The 16-bit count fields of the end of central directory record hold at most 65,534; 65,535 or
    more entries need the zip64 end record (APPNOTE 4.4.21-22). zipcount.py reads what was
    written: the records walked, the 16-bit counts, the zip64 counts, the EFFECTIVE count (what a
    reader that trusts the end record gets) - PASS when it equals the records and a count of
    65,535+ is in a zip64 record.
      DEL-2K     2,000 members (Python), *.del deleted (Select 841, F8 729)     -> 1,000 (control)
      DEL-70K    70,000 members (zip64, Python), *.del deleted                   -> 35,000
      DEL-140K   140,000 members (zip64), *.del deleted                          -> 70,000 (zip64)
      WRONG-70K  70,000 members whose end record says 4,464 (as an earlier version packed it),
                 *.del deleted                                                    -> 35,000
      PACK-70K   70,000 files on disk, all selected, Pack (850, ZIP) into a new archive -> 70,000
      PACK-70K-RE  the archive of PACK-70K opened again, f00*.txt (10,000) deleted -> 60,000
                 (the program reads the zip64 end record it wrote)
      ADD-66K    an archive of 65,000 members + 1,000 files packed into it (Add)  -> 66,000
    Python's zipfile must read every archive too (all members, testzip clean).
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
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs'); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc165'
$StartDir = $Root + '\start'
$Py = 'python'
$Zc = Join-Path $PSScriptRoot 'zipcount.py'

function Count-Row([string]$Case, [string]$Arc, [int]$Expected, [string]$What, $r) {
    $c = (& $Py $Zc eocd ($LP + $Arc) 2>&1) -join ' '
    $ok = $c -match ' OK 1$' -and $c -match ('^RECORDS ' + $Expected + ' ')
    Row $Case 'COUNT' (V $ok) ("{0}: expected {1}; {2}; windows: {3}" -f $What, $Expected, $c, (Msgs $r))
}
function Select-Mask([int]$Id, [string]$Mask) {
    $dlg = Open-ByCmd $Id 841 10
    if ($dlg -eq [IntPtr]::Zero) { throw 'no Select dialog' }
    [void][Drv098f]::SetText((Find-Ctl $dlg 101), $Mask, 5000); Click-Ok $dlg
    Start-Sleep -Milliseconds 800
}
function Row-Del([string]$Case, [int]$N, [string]$Make = 'make') {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case; NewDir $d
    $arc = $d + '\big.zip'
    $o = (& $Py $Zc $Make ($LP + $arc) $N 2>&1) -join ' '
    if ($o -notmatch 'ok') { Row $Case 'COUNT' 'FAIL' ('fixture: ' + $o); return }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Do-ChangeDir $id ($arc + '\d')); [void](Serve $id 120)
        Select-Mask $id '*.del'
        Post-Cmd (Get-Main $id) 729
        $r = Serve $id 900 @(6, 1)
        End-Row $Case $id $null $before; $id = 0
        Count-Row $Case $arc ([int]($N / 2)) ("{0} members, *.del deleted" -f $N) $r
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}
# Pack (850) of every *.txt of the panel into $Arc (ZIP packer - the dialog's packer is checked)
function Row-Pack([string]$Case, [int]$Files, [int]$Existing) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case; NewDir $d
    $src = $d + '\src'
    $arc = $d + '\out.zip'
    $o = (& $Py $Zc files ($LP + $src) $Files 'f' 2>&1) -join ' '
    if ($Existing -gt 0) { $o += ' ' + ((& $Py $Zc make ($LP + $arc) $Existing 2>&1) -join ' ') }
    if ($o -match 'Error|Traceback') { Row $Case 'COUNT' 'FAIL' ('fixture: ' + $o); return }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $src
        [void](Serve $id 60)
        Select-Mask $id '*.txt'
        $dlg = Open-ByCmd $id 850 15
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'COUNT' 'NOT DRIVEN' 'Pack opened no window'; return }
        $packer = [Drv098f]::GetText((Find-Ctl $dlg 511), 5000)
        if ($packer -notmatch 'ZIP') { Close-Win $dlg; Row $Case 'COUNT' 'NOT DRIVEN' ("the Pack dialog's packer is '{0}', not ZIP" -f (Esc $packer)); return }
        [void][Drv098f]::SetText((Find-Ctl $dlg 210), $arc, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 500
        $r = Serve $id 1200 @(6, 1)                     # "already exists" -> Add (6); options -> OK
        End-Row $Case $id $null $before; $id = 0
        Count-Row $Case $arc ($Files + $Existing) ("{0} files packed{1}" -f $Files, $(if ($Existing) { ' into an archive of ' + $Existing } else { ' into a new archive' })) $r
        if ($Existing -eq 0) {   # the program reads the archive it wrote: delete f00*.txt (10,000) in it
            $id = Start-Tc $d
            [void](Do-ChangeDir $id $arc); [void](Serve $id 120)
            Select-Mask $id 'f00*.txt'
            Post-Cmd (Get-Main $id) 729
            $r = Serve $id 900 @(6, 1)
            End-Row ($Case + '-RE') $id $null $before; $id = 0
            Count-Row ($Case + '-RE') $arc ($Files - 10000) 'the archive the program packed, f00*.txt (10,000) deleted in it' $r
        }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc165_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    & reg.exe add "$RegKey\Settings\Configuration" /v 'Use Recycle Bin' /t REG_DWORD /d 0 /f | Out-Null
    Out ("zip_count_probe (feature 165), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash)
    Out ''
    Row-Del 'DEL-2K' 2000
    Row-Del 'DEL-70K' 70000
    Row-Del 'DEL-140K' 140000
    Row-Del 'WRONG-70K' 70000 'makewrong'
    Row-Pack 'PACK-70K' 70000 0
    Row-Pack 'ADD-66K' 1000 65000
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
