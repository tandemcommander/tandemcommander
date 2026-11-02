<#
.SYNOPSIS
    Feature 397 probe: hex mode of Find (Containing) and of the viewer's Find keeps quoted letters
    outside the code page as typed while the user types, and searches them as their UTF-8 bytes.

.DESCRIPTION
    Typing is driven by WM_CHAR sent to the combo box's edit (the real keyboard is not available on
    the hidden desktop; a WM_CHAR runs the same edit -> EN_UPDATE -> CBN_EDITUPDATE ->
    DoHexValidation path as a key press). C5 = five CJK letters (U+4E01..U+4E05), Q = '"'.
    Fixture: hit.txt = "x" + C5 + "A" (UTF-8, no BOM); miss1.txt and miss2.txt = "?????A" (what a
    search for C5 turned into question marks finds). Rows:
      grep-type   Find (741), Search file content + Hex on, Containing set to Q C5 Q (WM_SETTEXT),
                  the caret put at the end, "4" "1" typed. PASS = the field is Q C5 Q " 41" (the
                  validation's space after the closing quote, letters kept), the caret at the end
                  (10), Find finds 1 file (hit.txt; the text turned into ????? found 2: miss1/miss2)
      grep-group  control (behaviour kept): Containing empty, "4" "1" "4" "2" "4" typed. PASS = the
                  field "41 42 4", the caret 7
      grep-mid    the caret inside the text: Containing Q C5 Q " 41", the caret put after the third
                  letter (4), "a" typed. PASS = Q C5[0..2] "a" C5[3..4] Q " 41", the caret 5
      view-type   the internal viewer (Alt+F3 on hit.txt), Find (CM_FINDSET 6063), Hex on (6127),
                  the field set to Q C5 Q, "4" "1" typed, OK. PASS = the field showed Q C5 Q " 41"
                  before OK; the viewer found the text: Find opened again pre-fills the selection
                  as hex - the UTF-8 bytes of C5 + "A" (E4 B8 81 ... 41)
    Driver of 311's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
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
$Root = $TempRoot + '\tc397_hex'
$FindDir = $Root + '\find'
$StartDir = $Root + '\start'

$C5 = -join (1..5 | ForEach-Object { [char](0x4E00 + $_) })
$Q = [string][char]0x22
$Typed = $Q + $C5 + $Q + ' 41'
$HitHex = ((@($Utf8.GetBytes($C5 + 'A')) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')

function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Get-Check([IntPtr]$Btn) {
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($Btn, 0x00F0, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # BM_GETCHECK
    return ($res.ToInt64() -eq 1)
}
function Set-Check([IntPtr]$Dlg, [int]$CtlId, [bool]$On) {
    $b = Find-Btn $Dlg $CtlId
    if (-not $b) { throw "check box $CtlId not found" }
    if ((Get-Check $b) -ne $On) { Click $b; Start-Sleep -Milliseconds 400 }
    if ((Get-Check $b) -ne $On) { throw "check box $CtlId did not change" }
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    $held = [Drv098f]::GetText($f, 5000)
    if ($held -cne $Text) { throw ("field $CtlId did not take the text ({0} of {1} units)" -f $held.Length, $Text.Length) }
}
function Get-Field([IntPtr]$Dlg, [int]$CtlId) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { return '<no field>' }
    return [Drv098f]::GetText($f, 5000)
}
function Combo-Edit([IntPtr]$Dlg, [int]$CtlId) {   # the edit inside the combo box
    $c = Find-Ctl $Dlg $CtlId
    $e = @([Drv098f]::Kids($c) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' }) | Select-Object -First 1
    if (-not $e) { throw "combo $CtlId has no edit" }
    return $e
}
function Set-Caret([IntPtr]$Edit, [int]$Pos) { [void][Drv098f]::Send($Edit, 0x00B1, $Pos, $Pos, 5000) }   # EM_SETSEL
function Type-Chars([IntPtr]$Edit, [string]$Chars) {
    foreach ($ch in $Chars.ToCharArray()) { [void][Drv098f]::Send($Edit, 0x0102, [int]$ch, 1, 5000); Start-Sleep -Milliseconds 150 }   # WM_CHAR
}
function Get-Sel([IntPtr]$Dlg, [int]$CtlId) {   # CB_GETEDITSEL: "start-end"
    $c = Find-Ctl $Dlg $CtlId
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($c, 0x0140, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)
    $v = $res.ToInt64()
    return ('{0}-{1}' -f ($v -band 0xFFFF), (($v -shr 16) -band 0xFFFF))
}
function Serve-Grep([int]$Id, $Keep = @(), [string]$Policy = 'ok', [double]$Seconds = 40) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and $Keep -notcontains $_ -and [Drv098f]::IsWindowVisible($_) })
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
            $pick = $null
            if ($Policy -eq 'ok') { $btn = Buttons $h; foreach ($want in @(6, 1)) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } } }
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
    if ($s.Length -gt 200) { $s = $s.Substring(0, 200) + '...' }
    return $s.Trim()
}
function Shown($r) { $m = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || '); if ($m) { return $m } else { return 'nothing' } }
function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch {
        Row $Case 'ERROR' 'FAIL' $_.Exception.Message
        if ($script:RowId -and (Test-Alive $script:RowId)) { foreach ($h in @(Get-Tops $script:RowId | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}
function Find-Count([IntPtr]$Dlg) {
    $lv = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' }) | Select-Object -First 1
    if (-not $lv) { return -1 }
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($lv, 0x1004, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # LVM_GETITEMCOUNT
    return [int]$res.ToInt64()
}
function Codes([string]$s) { return ((@($s.ToCharArray()) | ForEach-Object { 'U+{0:X4}' -f [int]$_ }) -join ' ') }

# ---- the Find dialog rows ------------------------------------------------------------
# $Start: the text set first (WM_SETTEXT, no validation); $Caret: the caret before typing (-1 = end);
# $Keys: typed by WM_CHAR; $Expect / $ExpectSel: the field and the caret after typing; $Search: click
# Find and expect $ExpectFound files
function Grep-Row([string]$Case, [string]$Start, [int]$Caret, [string]$Keys, [string]$Expect, [string]$ExpectSel, [switch]$Search, [int]$ExpectFound = 1) {
    Run-Row $Case {
        $id = Start-Tc $FindDir; $script:RowId = $id
        $dlg = Open-ByCmd $id 741 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
        Start-Sleep -Milliseconds 600
        Set-Field $dlg 2501 $FindDir
        Set-Field $dlg 2505 '*.txt'
        Set-Check $dlg 2508 $true                          # Search file content: the Containing field shows
        Set-Check $dlg 2516 $true                          # Hex
        if ($Start) { Set-Field $dlg 2504 $Start } else { Set-Field $dlg 2504 '' }
        $edit = Combo-Edit $dlg 2504
        Set-Caret $edit $(if ($Caret -lt 0) { $Start.Length } else { $Caret })
        Type-Chars $edit $Keys
        Start-Sleep -Milliseconds 300
        $now = Get-Field $dlg 2504
        $sel = Get-Sel $dlg 2504
        $fieldOk = ($now -ceq $Expect) -and ($sel -eq $ExpectSel)
        $facts = ("typed '{0}' into {1} units: the field '{2}' [{3}], caret {4} (expected '{5}', caret {6})" -f $Keys, $Start.Length, (Esc $now), (Codes $now), $sel, (Esc $Expect), $ExpectSel)
        $searchOk = $true
        if ($Search) {
            Click (Find-Btn $dlg 1)
            Start-Sleep -Milliseconds 1500
            $r = Serve-Grep $id @($dlg) 'ok'
            Start-Sleep -Milliseconds 1000
            $count = Find-Count $dlg
            $shown = Shown $r
            $searchOk = ($shown -eq 'nothing') -and ($count -eq $ExpectFound)
            $facts += ("; Find asked: {0}; found: {1} (expected {2})" -f $shown, $count, $ExpectFound)
        }
        $script:RowFatal = Fatal-Win $id
        $ok = (-not $script:RowFatal) -and $fieldOk -and $searchOk
        Row $Case 'RUN' (V $ok) $facts
        Close-Win $dlg; Start-Sleep -Milliseconds 500
        [void](Serve-Grep $id @() 'cancel' 10)
    }
}

# ---- the internal viewer's Find --------------------------------------------------------
function View-Row([string]$Case) {
    Run-Row $Case {
        $id = Start-Tc $FindDir; $script:RowId = $id
        Key $id 0x24                                       # VK_HOME: ".."
        Key $id 0x28                                       # VK_DOWN: the first file, hit.txt
        Start-Sleep -Milliseconds 300
        $view = Open-ByCmd $id 753 15                      # CM_ALTVIEW (Alt+F3): F3 on .txt is the Code Viewer plug-in
        if ($view -eq [IntPtr]::Zero) { throw 'Alt+F3 (753) opened no window' }
        Start-Sleep -Milliseconds 1000
        $vt = [Drv098f]::Txt($view)
        if ($vt -notmatch 'hit\.txt' -or [Drv098f]::Cls($view) -ne "Salamander's Viewer Window") { throw ("not the internal viewer on hit.txt: [{0}] '{1}'" -f [Drv098f]::Cls($view), (Esc $vt)) }
        $known = Get-Tops $id
        [void][Drv098f]::PostMessageW($view, 0x0111, [IntPtr]6063, [IntPtr]::Zero)   # CM_FINDSET
        $dlg = Wait-NewWin $id $known 10
        if ($dlg -eq [IntPtr]::Zero) { throw 'CM_FINDSET opened no window' }
        Start-Sleep -Milliseconds 500
        Set-Check $dlg 6127 $true                          # Hex
        $start = $Q + $C5 + $Q
        Set-Field $dlg 6125 $start
        $edit = Combo-Edit $dlg 6125
        Set-Caret $edit $start.Length
        Type-Chars $edit '41'
        Start-Sleep -Milliseconds 300
        $now = Get-Field $dlg 6125
        $sel = Get-Sel $dlg 6125
        $fieldOk = ($now -ceq $Typed) -and ($sel -eq '10-10')
        Click-Ok $dlg
        Start-Sleep -Milliseconds 1000
        $r = Serve-Grep $id @($dlg, $view) 'ok' 15
        $shown = Shown $r
        $known = Get-Tops $id
        [void][Drv098f]::PostMessageW($view, 0x0111, [IntPtr]6063, [IntPtr]::Zero)   # CM_FINDSET again
        $dlg2 = Wait-NewWin $id $known 10
        $again = '<no window>'
        if ($dlg2 -ne [IntPtr]::Zero) { Start-Sleep -Milliseconds 500; $again = Get-Field $dlg2 6125; Close-Win $dlg2; Start-Sleep -Milliseconds 400 }
        $script:RowFatal = Fatal-Win $id
        $foundOk = ($again -ceq $HitHex)
        $ok = (-not $script:RowFatal) -and $fieldOk -and $foundOk -and ($shown -eq 'nothing')
        Row $Case 'RUN' (V $ok) ("the field after typing '41': '{0}' [{1}], caret {2}; asked after OK: {3}; Find again pre-filled '{4}' (found text = '{5}')" -f (Esc $now), (Codes $now), $sel, $shown, (Esc $again), $HitHex)
        if ([Drv098f]::IsWindow($view)) { [void][Drv098f]::PostMessageW($view, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 700 }
        [void](Serve-Grep $id @() 'cancel' 10)
    }
}

$Cases = [ordered]@{}
$Cases['grep-type'] = { Grep-Row 'grep-type' ($Q + $C5 + $Q) -1 '41' $Typed '10-10' -Search -ExpectFound 1 }
$Cases['grep-group'] = { Grep-Row 'grep-group' '' -1 '41424' '41 42 4' '7-7' }
$Cases['grep-mid'] = { Grep-Row 'grep-mid' $Typed 4 'a' ($Q + $C5.Substring(0, 3) + 'a' + $C5.Substring(3) + $Q + ' 41') '5-5' }
$Cases['view-type'] = { View-Row 'view-type' }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc397_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $FindDir
    WriteFile "$StartDir\a.txt" 'A'
    [IO.File]::WriteAllText($LP + "$FindDir\hit.txt", ('x' + $C5 + 'A'), (New-Object Text.UTF8Encoding($false)))
    WriteFile "$FindDir\miss1.txt" '?????A'
    WriteFile "$FindDir\miss2.txt" '?????A'
    Set-Config
    Out ("hex397_probe (feature 397) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ("C5 = {0}; hit.txt = x C5 A; miss1.txt, miss2.txt = ?????A" -f (Codes $C5))
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
