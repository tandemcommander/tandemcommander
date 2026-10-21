<#
.SYNOPSIS
    Feature 283 probe: a "*.ext" mask whose extension is not ASCII matches names by whole letters,
    not by code-page bytes of their UTF-8 form.

.DESCRIPTION
    The panel's Convert (814) converts the focused file (LF -> CRLF, button 2494) only when it
    matches the dialog's mask (101) - the file's line ends show what the mask decided. Every row has
    its own folder with one file holding "a<LF>b<LF>". Rows:
      miss        A.<C-caron>TX, mask *.<c-caron>tx: the other case of an accented letter.
                  PASS = converted (2 CRLF)
      miss-hash   the same with ten ASCII "*.aNN" masks first (eleven *.ext masks use the hash
                  table): PASS = converted
      miss-excl   the same file, mask |*.<c-caron>tx (everything except): PASS = unchanged
      false       ACP 1250: x.<L-acute> (U+0139), mask *.<h-circumflex> (U+0125) - two different
                  letters whose second UTF-8 bytes fold together in the code page; ACP 1252:
                  x.<E-caron> (U+011A), mask *.<C-dot> (U+010A); another ACP: NOT DRIVEN.
                  PASS = unchanged
      false-hash  the same with the ten ASCII masks first: PASS = unchanged
      nfd         A.C+U+030C+TX (decomposed), mask *.<c-caron>tx: PASS = converted
      same        b.<c-caron>tx, mask *.<c-caron>tx (control): PASS = converted
      ascii       c.TXT, mask *.txt (control): PASS = converted
      ascii-hash  c.TXT, the ten ASCII masks + *.txt (control): PASS = converted
      ascii-no    c.TXT, mask *.doc (control): PASS = unchanged
    Driver of 270's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
    Registry exported, restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. $Lib
$Root = $TempRoot + '\tc283_mask'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'

$CcUp = [string][char]0x010C   # C-caron
$CcLo = [string][char]0x010D   # c-caron
$Acp = [Drv098f]::GetACP()
if ($Acp -eq 1250) { $FalseName = [string][char]0x0139; $FalseMask = [string][char]0x0125 }
elseif ($Acp -eq 1252) { $FalseName = [string][char]0x011A; $FalseMask = [string][char]0x010A }
else { $FalseName = $null; $FalseMask = $null }
$Ten = (1..10 | ForEach-Object { '*.a{0:D2}' -f $_ }) -join ';'

function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    $held = [Drv098f]::GetText($f, 5000)
    if ($held -cne $Text) { throw ("field $CtlId did not take the text ({0} of {1} units)" -f $held.Length, $Text.Length) }
}
function CrlfOf([string]$File) {
    $b = [IO.File]::ReadAllBytes($LP + $File)
    $crlf = 0; for ($i = 1; $i -lt $b.Length; $i++) { if ($b[$i] -eq 10 -and $b[$i - 1] -eq 13) { $crlf++ } }
    return $crlf
}
function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}
# one Convert row: the folder $Case holds $File; focus it, Convert with $Mask to CRLF; $Expect =
# 'converted' | 'unchanged'
function Conv-Row([string]$Case, [string]$File, [string]$Mask, [string]$Expect) {
    Run-Row $Case {
        $d = $Root + '\' + $Case; NewDir $d
        $path = "$d\$File"
        [IO.File]::WriteAllBytes($LP + $path, [byte[]](0x61, 0x0A, 0x62, 0x0A))
        $id = Start-Tc $d; $script:RowId = $id
        if (-not $path.StartsWith($Root + '\')) { throw "the typed path is outside the fixture: $path" }
        if (-not (Do-ChangeDir $id $path)) { throw 'Change Directory did not take the path' }
        Start-Sleep -Milliseconds 400
        $dlg = Open-ByCmd $id 814 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Convert (814) opened no window' }
        Click (Find-Btn $dlg 2494); Start-Sleep -Milliseconds 400
        Set-Field $dlg 101 $Mask
        Click-Ok $dlg
        Start-Sleep -Milliseconds 700
        $r = Serve $id 30
        $script:RowFatal = $r.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $n = CrlfOf $path
        $got = $(if ($n -eq 2) { 'converted' } elseif ($n -eq 0) { 'unchanged' } else { "$n CRLF" })
        $ok = (-not $script:RowFatal) -and (-not $r.TimedOut) -and ($got -eq $Expect)
        Row $Case 'RUN' (V $ok) ("file '{0}', mask '{1}': {2} (expected {3}); asked: {4}" -f (Esc $File), (Tail $Mask 40), $got, $Expect, (Msgs $r))
    }
}

$Cases = [ordered]@{}
$Cases['miss'] = { Conv-Row 'miss' ('A.' + $CcUp + 'TX') ('*.' + $CcLo + 'tx') 'converted' }
$Cases['miss-hash'] = { Conv-Row 'miss-hash' ('A.' + $CcUp + 'TX') ($Ten + ';*.' + $CcLo + 'tx') 'converted' }
$Cases['miss-excl'] = { Conv-Row 'miss-excl' ('A.' + $CcUp + 'TX') ('|*.' + $CcLo + 'tx') 'unchanged' }
$Cases['false'] = {
    if (-not $FalseName) { Row 'false' 'RUN' 'NOT DRIVEN' "ACP $Acp has no pair chosen"; return }
    Conv-Row 'false' ('x.' + $FalseName) ('*.' + $FalseMask) 'unchanged'
}
$Cases['false-hash'] = {
    if (-not $FalseName) { Row 'false-hash' 'RUN' 'NOT DRIVEN' "ACP $Acp has no pair chosen"; return }
    Conv-Row 'false-hash' ('x.' + $FalseName) ($Ten + ';*.' + $FalseMask) 'unchanged'
}
$Cases['nfd'] = { Conv-Row 'nfd' ('A.C' + [string][char]0x030C + 'TX') ('*.' + $CcLo + 'tx') 'converted' }
$Cases['same'] = { Conv-Row 'same' ('b.' + $CcLo + 'tx') ('*.' + $CcLo + 'tx') 'converted' }
$Cases['ascii'] = { Conv-Row 'ascii' 'c.TXT' '*.txt' 'converted' }
$Cases['ascii-hash'] = { Conv-Row 'ascii-hash' 'c.TXT' ($Ten + ';*.txt') 'converted' }
$Cases['ascii-no'] = { Conv-Row 'ascii-no' 'c.TXT' '*.doc' 'unchanged' }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc283_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir
    Set-Config
    Out ("mask283_probe (feature 283) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $Acp, $existed)
    Out ''
    foreach ($k in @($Cases.Keys)) {
        if (Want $k) {
            & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
            if ($existed) { & cmd.exe /c "reg import `"$backup`" >nul 2>&1" }
            Set-Config
            & $Cases[$k]
        }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
