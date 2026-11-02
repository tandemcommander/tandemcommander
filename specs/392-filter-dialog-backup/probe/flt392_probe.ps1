<#
.SYNOPSIS
    Probe of the Filter dialog: a refused edit (a mask with a syntax error, OK, the error box,
    Cancel) must leave the panel's filter exactly as it was - also a filter longer than 259 bytes.

.DESCRIPTION
    The left panel gets two tabs from the registry (Left Panel\Tabs\0 and \1, both on the fixture's
    start folder); tab 1 carries the filter under test. The probe switches to tab 1
    (CM_LEFT_NEXTTAB), opens Change Filter (CM_CHANGEFILTER) and reads the field. Rows:
      long-refused   tab filter F = 300 bytes of valid ASCII masks (*.x001;...;*.last). The field is
                     set to '*.txt|' (a '|' with no mask after it = syntax error), OK; the error box
                     is answered, the dialog cancelled; Change Filter opened again must show F
                     whole. FAIL = it shows the first 259 bytes of F (the backup cut at MAX_PATH)
      short-refused  the same with a short tab filter '*.abc;*.def' (control: passes before and after)
      long-valid     tab filter F, the field set to '*.txt' (valid), OK: accepted, nothing asked,
                     the next Change Filter shows '*.txt' (control: an accepted edit is stored)
      long-refused-then-valid  tab filter F, '*.txt|' refused (error box), the same dialog corrected
                     to '*.cpp', OK: accepted without a second question, the next Change Filter
                     shows '*.cpp'
    Driver of 098's library. MUST run through tools\run_on_hidden_desktop.ps1. Registry exported,
    restored and verified.
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
$Root = $TempRoot + '\tcflt_filter'
$StartDir = $Root + '\start'
$Key01 = 'HKCU:\Software\Tandem Commander\Settings'
$CM_CHANGEFILTER = 779; $CM_LEFT_NEXTTAB = 2867
$IDE_FILTER = 409; $IDC_USEFILTER = 407
$Syntax = 'syntactically incorrect'

# F: 42 masks *.x001..*.x042 (293 bytes) + ';*.last' = 300 bytes, a valid group
$F = ((1..42 | ForEach-Object { '*.x{0:D3}' -f $_ }) -join ';') + ';*.last'

function Reg-Set([string]$sub, [string]$name, $value, [string]$type) {
    $k = $Key01 + $(if ($sub) { '\' + $sub } else { '' })
    if (-not (Test-Path $k)) { [void](New-Item -Path $k -Force) }
    Set-ItemProperty -Path $k -Name $name -Value $value -Type $type
}
function Seed-Tabs([string]$Filter) {
    Reg-Set 'Configuration' 'Panel Tabs' 1 DWord
    & cmd.exe /c "reg delete `"$RegKey\Settings\Left Panel\Tabs`" /f >nul 2>&1"
    Reg-Set 'Left Panel\Tabs\0' 'Path' $StartDir String
    Reg-Set 'Left Panel\Tabs\1' 'Path' $StartDir String
    Reg-Set 'Left Panel\Tabs\1' 'Enable Filter' 1 DWord
    Reg-Set 'Left Panel\Tabs\1' 'Filter' $Filter String
    Reg-Set 'Left Panel' 'Active Tab' 0 DWord
}
function Get-Field([IntPtr]$Dlg, [int]$CtlId) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { return '<no field>' }
    return [Drv098f]::GetText($f, 5000)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    $held = [Drv098f]::GetText($f, 5000)
    if ($held -cne $Text) { throw ("field $CtlId did not take the text ({0} of {1} units)" -f $held.Length, $Text.Length) }
}
# answers every window except $Keep (OK / Yes, else Cancel) until idle; returns the texts it saw
function Serve-Flt([int]$Id, $Keep = @(), [double]$Seconds = 30) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and $Keep -notcontains $_ })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            [void]$r.Messages.Add($d)
            $btn = Buttons $h; $pick = $null
            foreach ($want in @(6, 1)) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } }
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function Short([string]$s) {
    $s = $s -replace '\[Button id=\d+\] [^|]*(\||$)', ''
    $s = $s -replace '\[Static id=-?\d+\] ', ''
    if ($s.Length -gt 160) { $s = $s.Substring(0, 160) + '...' }
    return $s.Trim()
}
function Shown($r) { $m = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || '); if ($m) { return $m } else { return 'nothing' } }
function U8([string]$s) { return $Utf8.GetByteCount($s) }
function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}
# $TabFilter into tab 1, switch to it, Change Filter, field := $Text, OK (+ serve), Cancel if it
# stayed, Change Filter again: returns the facts; $Expect = the text the second dialog must show
function Flt-Row([string]$Case, [string]$TabFilter, [string]$Text, [string]$Expect, [switch]$Accepted, [string]$Then) {
    Run-Row $Case {
        Seed-Tabs $TabFilter
        $id = Start-Tc $StartDir; $script:RowId = $id
        Post-Cmd (Get-Main $id) $CM_LEFT_NEXTTAB
        Start-Sleep -Milliseconds 1500
        [void][Drv098f]::Send((Get-Main $id), 0, 0, 0, 20000)
        $dlg = Open-ByCmd $id $CM_CHANGEFILTER 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Change Filter opened no window' }
        $first = Get-Field $dlg $IDE_FILTER
        $firstWhole = ($first -ceq $TabFilter)
        $useBtn = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $IDC_USEFILTER }) | Select-Object -First 1
        if ($useBtn) { Click $useBtn; Start-Sleep -Milliseconds 300 }
        Set-Field $dlg $IDE_FILTER $Text
        Click-Ok $dlg
        Start-Sleep -Milliseconds 700
        $r = Serve-Flt $id @($dlg)
        $script:RowFatal = $r.Fatal
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        $thenFacts = ''
        if ($Then -and $stayed -and -not $r.Fatal) {
            # the refused dialog is corrected with a valid text and confirmed
            Set-Field $dlg $IDE_FILTER $Then
            Click-Ok $dlg
            Start-Sleep -Milliseconds 700
            $r3 = Serve-Flt $id @($dlg)
            foreach ($m in $r3.Messages) { [void]$r.Messages.Add('after the correction: ' + $m) }
            if ($r3.Fatal) { $r.Fatal = $r3.Fatal; $script:RowFatal = $r3.Fatal }
            $stayedAgain = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
            $thenFacts = ("; corrected to '{0}', OK, dialog stayed again: {1}" -f $Then, $stayedAgain)
            $stayed = $stayedAgain
            $Accepted = $true
        }
        if ($stayed -and -not $r.Fatal) { Close-Win $dlg; Start-Sleep -Milliseconds 500; $r2 = Serve-Flt $id @() 15; foreach ($m in $r2.Messages) { [void]$r.Messages.Add('after cancel: ' + $m) }; if ($r2.Fatal) { $script:RowFatal = $r2.Fatal } }
        if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $now = '<not read>'
        if (-not $script:RowFatal) {
            $dlg2 = Open-ByCmd $id $CM_CHANGEFILTER 15
            if ($dlg2 -eq [IntPtr]::Zero) { throw 'Change Filter did not open again' }
            $now = Get-Field $dlg2 $IDE_FILTER
            Close-Win $dlg2; Start-Sleep -Milliseconds 400
            [void](Serve-Flt $id @() 10)
        }
        $kept = ($now -ceq $Expect)
        $shown = Shown $r
        if ($Then) { $verdictOk = (-not $stayed) -and ($shown -match $Syntax) -and ($shown -notmatch 'after the correction') -and $kept }
        elseif ($Accepted) { $verdictOk = (-not $stayed) -and ($shown -eq 'nothing') -and $kept }
        else { $verdictOk = $stayed -and ($shown -match $Syntax) -and $kept }
        $ok = (-not $script:RowFatal) -and (-not $r.TimedOut) -and $firstWhole -and $verdictOk
        Row $Case 'RUN' (V $ok) ("tab filter {0} bytes; the first dialog showed {1} bytes (whole: {2}); typed '{3}'; dialog stayed: {4}; asked: {5}; the next dialog shows {6} bytes, as expected ({7} bytes): {8}, tail '{9}'{10}" -f (U8 $TabFilter), (U8 $first), $firstWhole, $Text, $stayed, $shown, (U8 $now), (U8 $Expect), $kept, (Tail $now 12), ($thenFacts + $(if ($r.TimedOut) { '; TIMED OUT' } else { '' })))
    }
}

$Cases = [ordered]@{}
$Cases['long-refused'] = { Flt-Row 'long-refused' $F '*.txt|' $F }
$Cases['short-refused'] = { Flt-Row 'short-refused' '*.abc;*.def' '*.txt|' '*.abc;*.def' }
$Cases['long-valid'] = { Flt-Row 'long-valid' $F '*.txt' '*.txt' -Accepted }
$Cases['long-refused-then-valid'] = { Flt-Row 'long-refused-then-valid' $F '*.txt|' '*.cpp' -Then '*.cpp' }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tcflt_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    WriteFile "$StartDir\a.last" 'A'
    WriteFile "$StartDir\b.txt" 'B'
    Set-Config
    Out ("filter probe {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ("F = {0} bytes, tail '{1}'" -f (U8 $F), (Tail $F 12))
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
