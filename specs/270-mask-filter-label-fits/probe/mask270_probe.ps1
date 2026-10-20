<#
.SYNOPSIS
    Feature 270 probe: a mask, a filter, a volume label or a hot path name typed into a field whose
    UTF-8 form does not fit the program's buffer (260 bytes) is refused ("The path specified is too
    long."), never cut and acted upon or stored.

.DESCRIPTION
    Every typed text fits the field (UTF-16 units) but not the buffer (UTF-8 bytes; CJK letters take
    three bytes each). M = 86 CJK letters (258 bytes). Rows:
      sel-mask   Select (841), the mask M*Q (260 bytes): cut to M* (the panel holds M.txt and MxQ -
                 the cut mask also selects M.txt). PASS = refused, the dialog stays, nothing selected
      unsel-mask Unselect (843), the same mask after Select All: PASS = refused, both stay selected
      sel-ctl    Select, the mask M* (259 bytes + NUL): accepted, both selected, the next Select
                 shows it whole
      conv-mask  Convert (814), the focused file M.txt (LF line ends), the mask M*Q, line ends CRLF:
                 cut, M* matches M.txt and converts it. PASS = refused, the file unchanged
      conv-ctl   Convert, the mask M* (fits): accepted, M.txt converted to CRLF
      flt        Change Filter (779), Use filter, the mask M*Q: cut, the panel shows other files.
                 PASS = refused; FAIL = the next Change Filter shows another text
      flt-unused the same field with "Don't use filter": the text is still stored (masks string,
                 history) - PASS = refused
      flt-ctl    Change Filter, M* (fits): accepted, the next Change Filter shows it whole
      vol        Drive Information (752) of the fixture's drive, a label of 140 'r-caron' (280
                 bytes): cut to 129 letters and written with SetVolumeLabel. Driven only when the
                 probe is NOT elevated (the call then fails for the system drive, the label cannot
                 change); PASS = refused as too long before any write, the label unchanged
      hp-label   Configuration > Hot Paths (a seeded slot 1), F2 on the row (LVM_EDITLABEL), 100 CJK
                 letters (300 bytes), Enter: stored cut as the slot's name. PASS = OK refused, the
                 name field shows the whole name
      hp-label-ctl the same with 86 CJK letters (258 bytes): accepted, stored whole
    Driver of 251's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
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
$Root = $TempRoot + '\tc270_mask'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$Key01 = 'HKCU:\Software\Tandem Commander\0.1'
$WmUserConfiguration = 0x8000 + 115
$TooLong = 'too long'

function Cjk([int]$n, [int]$base = 0x4E00) { return (-join (1..$n | ForEach-Object { [char]($base + $_) })) }
$M = Cjk 86
function Reg-Set([string]$sub, [string]$name, $value, [string]$type) {
    $k = $Key01 + $(if ($sub) { '\' + $sub } else { '' })
    if (-not (Test-Path $k)) { [void](New-Item -Path $k -Force) }
    Set-ItemProperty -Path $k -Name $name -Value $value -Type $type
}
function Open-Config([int]$Id, [int]$Mode, [long]$Param) {
    $known = Get-Tops $Id
    [void][Drv098f]::PostMessageW((Get-Main $Id), $WmUserConfiguration, [IntPtr]$Mode, [IntPtr]$Param)
    return (Wait-NewWin $Id $known 15)
}
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
function Get-Field([IntPtr]$Dlg, [int]$CtlId) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { return '<no field>' }
    return [Drv098f]::GetText($f, 5000)
}
# the first history entry of a combo box (CB_GETLBTEXT 0)
function Combo-First([IntPtr]$Dlg, [int]$CtlId) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { return '<no field>' }
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($f, 0x0146, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # CB_GETCOUNT
    if ($res.ToInt64() -lt 1) { return '' }
    $buf = New-Object char[] 70000
    [void][Drv098f]::SendGetText($f, 0x0148, [IntPtr]::Zero, $buf, 0, 5000, [ref]$res)   # CB_GETLBTEXT
    $n = [int]$res.ToInt64(); if ($n -lt 0) { $n = 0 }
    return (New-Object string($buf, 0, $n))
}
# answers every window except $Keep: OK / Yes ('ok') or Cancel ('cancel'); until idle
function Serve270([int]$Id, $Keep = @(), [string]$Policy = 'ok', [double]$Seconds = 40) {
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
# OK on $Dlg, serves what follows; returns @{ Shown; Stayed; Fatal; TimedOut; Extra } and cancels a dialog that stayed
function Ok-AndServe([int]$Id, [IntPtr]$Dlg, [scriptblock]$OnStayed) {
    # the Configuration dialog's OK button is id 5 (feature 251)
    $tpdOk = Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 5 -and [Drv098f]::GetParent($_) -eq $Dlg } | Select-Object -First 1
    if ($tpdOk) { Click $tpdOk } else { Click-Ok $Dlg }
    Start-Sleep -Milliseconds 700
    $r = Serve270 $Id @($Dlg) 'ok'
    $stayed = [Drv098f]::IsWindow($Dlg) -and [Drv098f]::IsWindowVisible($Dlg)
    $extra = $null
    if ($stayed -and -not $r.Fatal -and $OnStayed) { $extra = & $OnStayed }
    if ($stayed -and -not $r.Fatal) { Close-Win $Dlg; Start-Sleep -Milliseconds 500; $r2 = Serve270 $Id @() 'cancel' 15; foreach ($m in $r2.Messages) { [void]$r.Messages.Add('after cancel: ' + $m) }; if ($r2.Fatal) { $r.Fatal = $r2.Fatal } }
    return [pscustomobject]@{ Shown = (Shown $r); Stayed = $stayed; Fatal = $r.Fatal; TimedOut = $r.TimedOut; Extra = $extra }
}
function U8([string]$s) { return $Utf8.GetByteCount($s) }
function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}
# ---- a mask dialog row ---------------------------------------------------------------
# opens the dialog by command $Cmd in a panel on $Dir (focus on $Focus when given), $Prep runs on the
# dialog, $Text goes into field $Field; refuse rows: PASS = stayed, "too long", the field whole at the
# refusal; -Fits rows: PASS = closed, nothing asked, the dialog opened again holds the text whole
# (field or first history entry, $Reopen = 'field' | 'history'); $Check runs last with the facts
function Mask-Row([string]$Case, [string]$Dir, [string]$Focus, [int]$Cmd, [int]$Field, [string]$Text, [scriptblock]$Prep, [string]$Reopen, [switch]$Fits, [scriptblock]$Check) {
    Run-Row $Case {
        $id = Start-Tc $Dir; $script:RowId = $id
        if ($Focus) { [void](Do-ChangeDir $id $Focus); Start-Sleep -Milliseconds 400 }
        $dlg = Open-ByCmd $id $Cmd 15
        if ($dlg -eq [IntPtr]::Zero) { throw "command $Cmd opened no window" }
        if ($Prep) { & $Prep $dlg; Start-Sleep -Milliseconds 400 }
        Set-Field $dlg $Field $Text
        $o = Ok-AndServe $id $dlg { Get-Field $dlg $Field }
        $script:RowFatal = $o.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $atRefusal = $o.Extra
        $after = $(if ($null -ne $atRefusal) { "(refused) the field at the refusal: {0} units, same as typed: {1}" -f $atRefusal.Length, ($atRefusal -ceq $Text) } else { '(not read)' })
        $kept = $true
        if (-not $o.Stayed -and -not $script:RowFatal) {
            $dlg2 = Open-ByCmd $id $Cmd 15
            if ($dlg2 -eq [IntPtr]::Zero) { throw "command $Cmd did not open again" }
            $now = $(if ($Reopen -eq 'history') { Combo-First $dlg2 $Field } else { Get-Field $dlg2 $Field })
            $kept = ($now -ceq $Text)
            $after = ("the next dialog's {0}: {1} units / {2} bytes, same as typed: {3}, tail '{4}'" -f $Reopen, $now.Length, (U8 $now), $kept, (Tail $now 6))
            Close-Win $dlg2; Start-Sleep -Milliseconds 400
            [void](Serve270 $id @() 'cancel' 10)
        }
        $res = $(if ($Check) { & $Check } else { [pscustomobject]@{ Ok = $true; Facts = '' } })
        $refused = $o.Stayed -and ($o.Shown -match $TooLong) -and ($atRefusal -ceq $Text)
        if ($Fits) { $verdictOk = (-not $o.Stayed) -and $kept -and ($o.Shown -eq 'nothing') } else { $verdictOk = $refused }
        $ok = (-not $script:RowFatal) -and (-not $o.TimedOut) -and $verdictOk -and $res.Ok
        Row $Case 'RUN' (V $ok) ("typed {0} units / {1} bytes; dialog stayed: {2}; asked: {3}; {4}{5}{6}" -f $Text.Length, (U8 $Text), $o.Stayed, $o.Shown, $after, $(if ($res.Facts) { '; ' + $res.Facts } else { '' }), $(if ($o.TimedOut) { '; TIMED OUT' } else { '' }))
    }
}
function Res270([bool]$Ok, [string]$Facts) { return [pscustomobject]@{ Ok = $Ok; Facts = $Facts } }
function ReadLE([string]$File) {
    $b = [IO.File]::ReadAllBytes($LP + $File)
    $crlf = 0; for ($i = 1; $i -lt $b.Length; $i++) { if ($b[$i] -eq 10 -and $b[$i - 1] -eq 13) { $crlf++ } }
    return $crlf
}
function Seed-ConvDir([string]$Case) {
    $d = $Root + '\' + $Case; NewDir $d
    [IO.File]::WriteAllBytes($LP + "$d\$M.txt", [byte[]](0x61, 0x0A, 0x62, 0x0A))
    WriteFile "$d\other.txt" 'X'
    return $d
}

# ---- the hot path label edit row -----------------------------------------------------
function Hp-Label-Row([string]$Case, [string]$Name, [switch]$Fits) {
    Run-Row $Case {
        Reg-Set 'Hot Paths\1' 'Name' 'C:\' String; Reg-Set 'Hot Paths\1' 'Path' 'C:\' String; Reg-Set 'Hot Paths\1' 'Visible' 1 DWord
        $id = Start-Tc $StartDir; $script:RowId = $id
        $dlg = Open-Config $id 1 -1
        if ($dlg -eq [IntPtr]::Zero) { throw 'Configuration (Hot Paths) opened no window' }
        $lv = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
        if (-not $lv) { throw 'the hot path list was not found' }
        $res = [IntPtr]::Zero
        # the list view must have the focus (LVM_EDITLABEL refuses otherwise): WM_NEXTDLGCTL on its page
        [void][Drv098f]::Send([Drv098f]::GetParent($lv), 0x0028, $lv.ToInt64(), 1, 5000)
        Start-Sleep -Milliseconds 300
        [void][Drv098f]::SendMessageTimeoutW($lv, 0x1076, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # LVM_EDITLABELW 0
        $edit = $res
        if ($edit -eq [IntPtr]::Zero) { Close-Win $dlg; Row $Case 'RUN' 'NOT DRIVEN' 'LVM_EDITLABEL opened no edit'; return }
        [void][Drv098f]::SetText($edit, $Name, 5000)
        $held = [Drv098f]::GetText($edit, 5000)
        if ($held -cne $Name) { throw ("the label edit did not take the text ({0} of {1} units)" -f $held.Length, $Name.Length) }
        [void][Drv098f]::Send($edit, 0x0100, 0x0D, 0x001C0001, 5000)   # WM_KEYDOWN VK_RETURN
        Start-Sleep -Milliseconds 500
        if ([Drv098f]::IsWindow($edit)) { throw 'the label edit did not end on Enter' }
        $inField = Get-Field $dlg 376
        $o = Ok-AndServe $id $dlg { Get-Field $dlg 376 }
        $script:RowFatal = $o.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $atRefusal = $o.Extra
        $after = $(if ($null -ne $atRefusal) { "(refused) the name field at the refusal: {0} units, same as typed: {1}" -f $atRefusal.Length, ($atRefusal -ceq $Name) } else { '(not read)' })
        $kept = $true
        if (-not $o.Stayed -and -not $script:RowFatal) {
            $dlg2 = Open-Config $id 1 -1
            if ($dlg2 -eq [IntPtr]::Zero) { throw 'Configuration did not open again' }
            $now = Get-Field $dlg2 376
            $kept = ($now -ceq $Name)
            $after = ("stored name: {0} units / {1} bytes, same as typed: {2}, tail '{3}'" -f $now.Length, (U8 $now), $kept, (Tail $now 6))
            Close-Win $dlg2; Start-Sleep -Milliseconds 400
            [void](Serve270 $id @() 'cancel' 10)
        }
        $refused = $o.Stayed -and ($o.Shown -match $TooLong) -and ($atRefusal -ceq $Name)
        if ($Fits) { $verdictOk = (-not $o.Stayed) -and $kept -and ($o.Shown -eq 'nothing') } else { $verdictOk = $refused }
        $ok = (-not $script:RowFatal) -and (-not $o.TimedOut) -and $verdictOk
        Row $Case 'RUN' (V $ok) ("typed {0} units / {1} bytes; the name field after Enter: {2} units; dialog stayed: {3}; asked: {4}; {5}{6}" -f $Name.Length, (U8 $Name), $inField.Length, $o.Stayed, $o.Shown, $after, $(if ($o.TimedOut) { '; TIMED OUT' } else { '' }))
    }
}

$Cases = [ordered]@{}
$Cases['sel-mask'] = { Mask-Row 'sel-mask' $StartDir $null 841 101 ($M + '*Q') $null 'field' }
$Cases['unsel-mask'] = { Mask-Row 'unsel-mask' $StartDir $null 843 101 ($M + '*Q') $null 'field' }
$Cases['sel-ctl'] = { Mask-Row 'sel-ctl' $StartDir $null 841 101 ($M + '*') $null 'field' -Fits }
$Cases['conv-mask'] = {
    $d = Seed-ConvDir 'conv-mask'
    Mask-Row 'conv-mask' $d "$d\$M.txt" 814 101 ($M + '*Q') { param($g) Click (Find-Btn $g 2494) } 'history' -Check { $n = ReadLE "$d\$M.txt"; Res270 ($n -eq 0) ("$M.txt CRLF line ends: $n (0 = unchanged)" -replace [regex]::Escape($M), 'M') }
}
$Cases['conv-ctl'] = {
    $d = Seed-ConvDir 'conv-ctl'
    Mask-Row 'conv-ctl' $d "$d\$M.txt" 814 101 ($M + '*') { param($g) Click (Find-Btn $g 2494) } 'history' -Fits -Check { $n = ReadLE "$d\$M.txt"; Res270 ($n -eq 2) ("M.txt CRLF line ends: $n (2 = converted)") }
}
$Cases['flt'] = { Mask-Row 'flt' $StartDir $null 779 409 ($M + '*Q') { param($g) Click (Find-Btn $g 407) } 'field' }
$Cases['flt-unused'] = { Mask-Row 'flt-unused' $StartDir $null 779 409 ($M + '*Q') { param($g) Click (Find-Btn $g 406) } 'history' }
$Cases['flt-ctl'] = { Mask-Row 'flt-ctl' $StartDir $null 779 409 ($M + '*') { param($g) Click (Find-Btn $g 407) } 'field' -Fits }
$Cases['vol'] = {
    $elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $drive = New-Object IO.DriveInfo ($TempRoot.Substring(0, 1))
    if ($elevated -or $drive.DriveType -ne 'Fixed') { Row 'vol' 'RUN' 'NOT DRIVEN' ("elevated: {0}, drive type {1} - the label could be written" -f $elevated, $drive.DriveType); return }
    $labelBefore = $drive.VolumeLabel
    $t = [string]([char]0x0159) * 140
    Mask-Row 'vol' $StartDir $null 752 552 $t $null 'field' -Check { $now = (New-Object IO.DriveInfo ($TempRoot.Substring(0, 1))).VolumeLabel; Res270 ($now -ceq $labelBefore) ("label of {0}: before '{1}', after '{2}'" -f $drive.Name, (Esc $labelBefore), (Esc $now)) }
}
$Cases['hp-label'] = { Hp-Label-Row 'hp-label' (Cjk 100) }
$Cases['hp-label-ctl'] = { Hp-Label-Row 'hp-label-ctl' $M -Fits }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc270_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir
    [IO.File]::WriteAllText($LP + "$StartDir\$M.txt", 'A')
    [IO.File]::WriteAllText($LP + "$StartDir\${M}xQ", 'B')
    Set-Config
    Out ("mask270_probe (feature 270) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out 'M = 86 CJK letters (258 bytes)'
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
