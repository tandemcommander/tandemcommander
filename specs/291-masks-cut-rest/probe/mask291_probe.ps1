<#
.SYNOPSIS
    Feature 291 probe: the Recycle Bin masks, the Find dialog's "Named" mask, the viewer's text /
    hex masks, the compare ignore masks and the Views list's in-place name edit - text whose UTF-8
    form does not fit the program's buffer is refused ("The path specified is too long."), never
    cut and acted upon or stored.

.DESCRIPTION
    Every typed text fits the field (UTF-16 units) but not the buffer (UTF-8 bytes; CJK letters take
    three bytes each). M = 86 CJK letters (258 bytes); R = 85 CJK letters (255 bytes). Rows:
      rb-mask    Configuration > System, "Move following files to the Recycle Bin", masks R;*.kp
                 (260 bytes): cut to R;*.k - files *.kp would be deleted permanently. PASS = OK
                 refused, the field whole; FAIL = the next Configuration shows another text
      rb-unused  the same masks with "Move all deleted files to the Recycle Bin": the text is still
                 stored - PASS = refused
      rb-ctl     R;*.k (259 bytes + NUL) with the masks radio: accepted, stored whole
      find-named Find (741), Look in = a folder holding M.txt, MxQ and other.txt, Named M*Q (260
                 bytes): cut to M*, found M.txt too. PASS = "too long", nothing found, the field whole
      find-ctl   Named M* (259 bytes): found 2 (M.txt, MxQ), nothing asked, the field whole
      find-add   Named M*Q, Options > Add Current (CM_FIND_ADD_CURRENT): the field was written back
                 cut (a later Find used it). PASS = "too long", the field whole
      find-ignore Named M*Q, Options > Ignore (CM_FIND_IGNORE): as find-add
      find-option a stored Find option without a Named text (seeded), Named M*Q, the option chosen
                 (CM_FIND_OPTIONS_FIRST): the field was kept cut. PASS = the field whole after the
                 option, then Find refused
      view-text  Configuration > Viewer, "Text mode" masks M*Q: stored cut. PASS = refused
      view-hex   the "Hex mode" masks M*Q: PASS = refused
      view-ctl   the "Text mode" masks M* (fits): accepted, stored whole
      cmp-files  Compare Directories (737), "Ignore files" checked, masks M*Q: stored cut. PASS =
                 refused, the field whole
      cmp-dirs-unused "Ignore directories" unchecked, its masks M*Q: stored anyway - PASS = refused
      cmp-ctl    "Ignore files", M* (fits): accepted, stored whole
      vname      Configuration > Views, the first free row (7), in-place edit (LVM_EDITLABEL), 11
                 CJK letters (33 bytes; the name holds 29 bytes): stored cut to 9 letters. PASS =
                 "too long", the row stays empty
      vname-ascii 30 ASCII letters (30 bytes): stored cut to 29. PASS = refused, the row empty
      vname-ctl  9 CJK letters + 'ab' (29 bytes): accepted, the row shows it whole
    The Views rows read the row's label back by opening its in-place edit once more (comctl32
    seeds it with the row text) and cancelling it with Escape. Typing is not driven: the edit's text
    is set by WM_SETTEXT, Enter is posted. Driver of 251's / 270's probes (098's library). MUST run
    through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
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
$Root = $TempRoot + '\tc291_mask'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$FindDir = $Root + '\find'
$Key01 = 'HKCU:\Software\Tandem Commander\0.1'
$WmUserConfiguration = 0x8000 + 115
$TooLong = 'too long'

function Cjk([int]$n, [int]$base = 0x4E00) { return (-join (1..$n | ForEach-Object { [char]($base + $_) })) }
$M = Cjk 86
$R = Cjk 85
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
    if ((Get-Check $b) -ne $On) { Click $b; Start-Sleep -Milliseconds 300 }
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
# answers every window except $Keep: OK / Yes ('ok') or Cancel ('cancel'); until idle
function Serve291([int]$Id, $Keep = @(), [string]$Policy = 'ok', [double]$Seconds = 40) {
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
# OK on $Dlg, serves what follows; returns @{ Shown; Stayed; Fatal; TimedOut; Extra } and cancels a dialog that stayed
function Ok-AndServe([int]$Id, [IntPtr]$Dlg, [scriptblock]$OnStayed) {
    # the Configuration dialog's OK button is id 5 (feature 251)
    $tpdOk = Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 5 -and [Drv098f]::GetParent($_) -eq $Dlg } | Select-Object -First 1
    if ($tpdOk) { Click $tpdOk } else { Click-Ok $Dlg }
    Start-Sleep -Milliseconds 700
    $r = Serve291 $Id @($Dlg) 'ok'
    $stayed = [Drv098f]::IsWindow($Dlg) -and [Drv098f]::IsWindowVisible($Dlg)
    $extra = $null
    if ($stayed -and -not $r.Fatal -and $OnStayed) { $extra = & $OnStayed }
    if ($stayed -and -not $r.Fatal) { Close-Win $Dlg; Start-Sleep -Milliseconds 500; $r2 = Serve291 $Id @() 'cancel' 15; foreach ($m in $r2.Messages) { [void]$r.Messages.Add('after cancel: ' + $m) }; if ($r2.Fatal) { $r.Fatal = $r2.Fatal } }
    return [pscustomobject]@{ Shown = (Shown $r); Stayed = $stayed; Fatal = $r.Fatal; TimedOut = $r.TimedOut; Extra = $extra }
}
function U8([string]$s) { return $Utf8.GetByteCount($s) }
function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch {
        Row $Case 'ERROR' 'FAIL' $_.Exception.Message
        if ($script:RowId -and (Test-Alive $script:RowId)) { foreach ($h in @(Get-Tops $script:RowId | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}

# ---- a modal mask dialog row ---------------------------------------------------------
# $Open opens the dialog (param: the instance id, returns its window); $Prep runs on it; $Text goes
# into field $Field; refuse rows: PASS = stayed, "too long", the field whole at the refusal; -Fits
# rows: PASS = closed, nothing asked, the dialog opened again holds the text whole
function Mask-Row([string]$Case, [string]$Left, [scriptblock]$PreStart, [scriptblock]$Open, [int]$Field, [string]$Text, [scriptblock]$Prep, [switch]$Fits) {
    Run-Row $Case {
        if ($PreStart) { & $PreStart }
        $id = Start-Tc $Left; $script:RowId = $id
        $dlg = & $Open $id
        if ($dlg -eq [IntPtr]::Zero) { throw 'the dialog did not open' }
        if ($Prep) { & $Prep $dlg; Start-Sleep -Milliseconds 400 }
        Set-Field $dlg $Field $Text
        $o = Ok-AndServe $id $dlg { Get-Field $dlg $Field }
        $script:RowFatal = $o.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $atRefusal = $o.Extra
        $after = $(if ($null -ne $atRefusal) { "(refused) the field at the refusal: {0} units, same as typed: {1}" -f $atRefusal.Length, ($atRefusal -ceq $Text) } else { '(not read)' })
        $kept = $true
        if (-not $o.Stayed -and -not $script:RowFatal) {
            $dlg2 = & $Open $id
            if ($dlg2 -eq [IntPtr]::Zero) { throw 'the dialog did not open again' }
            $now = Get-Field $dlg2 $Field
            $kept = ($now -ceq $Text)
            $after = ("the next dialog's field: {0} units / {1} bytes, same as typed: {2}, tail '{3}'" -f $now.Length, (U8 $now), $kept, (Tail $now 6))
            Close-Win $dlg2; Start-Sleep -Milliseconds 400
            [void](Serve291 $id @() 'cancel' 10)
        }
        $refused = $o.Stayed -and ($o.Shown -match $TooLong) -and ($atRefusal -ceq $Text)
        if ($Fits) { $verdictOk = (-not $o.Stayed) -and $kept -and ($o.Shown -eq 'nothing') } else { $verdictOk = $refused }
        $ok = (-not $script:RowFatal) -and (-not $o.TimedOut) -and $verdictOk
        Row $Case 'RUN' (V $ok) ("typed {0} units / {1} bytes; dialog stayed: {2}; asked: {3}; {4}{5}" -f $Text.Length, (U8 $Text), $o.Stayed, $o.Shown, $after, $(if ($o.TimedOut) { '; TIMED OUT' } else { '' }))
    }
}
$OpenSystem = { param($i) Open-Config $i 0 0 }    # Last Focused Page = 3 (System), set before the start
$OpenViewer = { param($i) Open-Config $i 3 0 }    # page 22
$OpenCompare = { param($i) Open-ByCmd $i 737 15 }
$SystemPage = { Reg-Set 'Configuration' 'Last Focused Page' 3 DWord }

# ---- the Find dialog rows ------------------------------------------------------------
function Find-Count([IntPtr]$Dlg) {
    $lv = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' }) | Select-Object -First 1
    if (-not $lv) { return -1 }
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($lv, 0x1004, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # LVM_GETITEMCOUNT
    return [int]$res.ToInt64()
}
# $Action: 'find' (Find), or a command id posted to the dialog (then Find is not started); $Expect:
# 'refuse' (a "too long" answer, nothing found, the field whole) or 'found2' (no question, 2 found,
# the field whole); $SeedOption: a stored option without a Named text is chosen before the action
function Find-Row([string]$Case, [string]$Text, $Action, [string]$Expect, [switch]$SeedOption) {
    Run-Row $Case {
        if ($SeedOption) {
            & cmd.exe /c "reg delete `"$RegKey\0.1\Configuration\Find Options`" /f >nul 2>&1"
            Reg-Set 'Configuration\Find Options\1' 'ItemName' 'probe291' String
        }
        $id = Start-Tc $FindDir; $script:RowId = $id
        $dlg = Open-ByCmd $id 741 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
        Start-Sleep -Milliseconds 600
        Set-Field $dlg 2501 $FindDir
        Set-Field $dlg 2505 $Text
        $optFacts = ''
        if ($SeedOption) {
            [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]2250, [IntPtr]::Zero)   # CM_FIND_OPTIONS_FIRST
            Start-Sleep -Milliseconds 800
            $afterOpt = Get-Field $dlg 2505
            $optFacts = ("after the option the field: {0} units, whole: {1}; " -f $afterOpt.Length, ($afterOpt -ceq $Text))
        }
        if ($Action -eq 'find') { Click (Find-Btn $dlg 1) } else { [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr][int]$Action, [IntPtr]::Zero) }
        Start-Sleep -Milliseconds 1500
        $r = Serve291 $id @($dlg) 'ok'
        Start-Sleep -Milliseconds 1500
        $script:RowFatal = $r.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $count = Find-Count $dlg
        $now = Get-Field $dlg 2505
        $whole = ($now -ceq $Text)
        $shown = Shown $r
        if ($Expect -eq 'refuse') { $verdictOk = ($shown -match $TooLong) -and ($count -le 0) -and $whole }
        else { $verdictOk = ($shown -eq 'nothing') -and ($count -eq 2) -and $whole }
        if ($SeedOption) { $verdictOk = $verdictOk -and ($afterOpt -ceq $Text) }
        $ok = (-not $script:RowFatal) -and (-not $r.TimedOut) -and $verdictOk
        Row $Case 'RUN' (V $ok) ("typed {0} units / {1} bytes; {2}asked: {3}; found: {4}; the field after: {5} units / {6} bytes, whole: {7}{8}" -f $Text.Length, (U8 $Text), $optFacts, $shown, $count, $now.Length, (U8 $now), $whole, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }))
        Close-Win $dlg; Start-Sleep -Milliseconds 500
        [void](Serve291 $id @() 'cancel' 10)
    }
}

# ---- the Views list's in-place name edit ---------------------------------------------
function Views-List([IntPtr]$Dlg) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' -and [Drv098f]::GetDlgCtrlID($_) -eq 322 }) | Select-Object -First 1)
}
function Edit-Label([IntPtr]$Lv, [int]$Index) {
    [void][Drv098f]::Send([Drv098f]::GetParent($Lv), 0x0028, $Lv.ToInt64(), 1, 5000)   # WM_NEXTDLGCTL: the list has the focus
    Start-Sleep -Milliseconds 200
    [void][Drv098f]::Send($Lv, 0x0100, 0x24, 0x01470001, 5000)   # VK_HOME
    for ($k = 0; $k -lt $Index; $k++) { [void][Drv098f]::Send($Lv, 0x0100, 0x28, 0x01500001, 5000) }   # VK_DOWN
    Start-Sleep -Milliseconds 300
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($Lv, 0x1076, [IntPtr]$Index, [IntPtr]::Zero, 0, 5000, [ref]$res)   # LVM_EDITLABELW
    return $res
}
function Read-Label([IntPtr]$Lv, [int]$Index) {
    $e = Edit-Label $Lv $Index
    if ($e -eq [IntPtr]::Zero) { return '<no edit>' }
    $t = [Drv098f]::GetText($e, 5000)
    [void][Drv098f]::PostMessageW($e, 0x0100, [IntPtr]0x1B, [IntPtr]0x00010001)   # VK_ESCAPE
    Start-Sleep -Milliseconds 400
    return $t
}
function Vname-Row([string]$Case, [string]$Name, [switch]$Fits) {
    Run-Row $Case {
        $id = Start-Tc $StartDir; $script:RowId = $id
        $dlg = Open-Config $id 4 -1
        if ($dlg -eq [IntPtr]::Zero) { throw 'Configuration (Views) opened no window' }
        Start-Sleep -Milliseconds 500
        $lv = Views-List $dlg
        if (-not $lv) { throw 'the Views list was not found' }
        $was = Read-Label $lv 7
        $edit = Edit-Label $lv 7
        if ($edit -eq [IntPtr]::Zero) { Close-Win $dlg; Row $Case 'RUN' 'NOT DRIVEN' 'LVM_EDITLABEL opened no edit'; return }
        [void][Drv098f]::SetText($edit, $Name, 5000)
        $held = [Drv098f]::GetText($edit, 5000)
        if ($held -cne $Name) { throw ("the label edit did not take the text ({0} of {1} units)" -f $held.Length, $Name.Length) }
        [void][Drv098f]::PostMessageW($edit, 0x0100, [IntPtr]0x0D, [IntPtr]0x001C0001)   # VK_RETURN
        Start-Sleep -Milliseconds 800
        $r = Serve291 $id @($dlg) 'ok'
        $script:RowFatal = $r.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $ended = -not [Drv098f]::IsWindow($edit)
        $now = Read-Label $lv 7
        $shown = Shown $r
        if ($Fits) { $verdictOk = ($shown -eq 'nothing') -and ($now -ceq $Name) }
        else { $verdictOk = ($shown -match $TooLong) -and ($now -ceq $was) }
        $ok = (-not $script:RowFatal) -and (-not $r.TimedOut) -and $ended -and $verdictOk
        Row $Case 'RUN' (V $ok) ("typed {0} units / {1} bytes; row 7 before: '{2}'; edit ended: {3}; asked: {4}; row 7 after: {5} units / {6} bytes '{7}'{8}" -f $Name.Length, (U8 $Name), (Esc $was), $ended, $shown, $now.Length, (U8 $now), (Tail $now 12), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }))
        Close-Win $dlg; Start-Sleep -Milliseconds 500
        [void](Serve291 $id @() 'cancel' 10)
    }
}

$Cases = [ordered]@{}
$Cases['rb-mask'] = { Mask-Row 'rb-mask' $StartDir $SystemPage $OpenSystem 541 ($R + ';*.kp') { param($g) Click (Find-Btn $g 540) } }
$Cases['rb-unused'] = { Mask-Row 'rb-unused' $StartDir $SystemPage $OpenSystem 541 ($R + ';*.kp') { param($g) Click (Find-Btn $g 539) } }
$Cases['rb-ctl'] = { Mask-Row 'rb-ctl' $StartDir $SystemPage $OpenSystem 541 ($R + ';*.k') { param($g) Click (Find-Btn $g 540) } -Fits }
$Cases['find-named'] = { Find-Row 'find-named' ($M + '*Q') 'find' 'refuse' }
$Cases['find-ctl'] = { Find-Row 'find-ctl' ($M + '*') 'find' 'found2' }
$Cases['find-add'] = { Find-Row 'find-add' ($M + '*Q') 2247 'refuse' }
$Cases['find-ignore'] = { Find-Row 'find-ignore' ($M + '*Q') 2293 'refuse' }
$Cases['find-option'] = { Find-Row 'find-option' ($M + '*Q') 'find' 'refuse' -SeedOption }
$Cases['view-text'] = { Mask-Row 'view-text' $StartDir $null $OpenViewer 643 ($M + '*Q') $null }
$Cases['view-hex'] = { Mask-Row 'view-hex' $StartDir $null $OpenViewer 644 ($M + '*Q') $null }
$Cases['view-ctl'] = { Mask-Row 'view-ctl' $StartDir $null $OpenViewer 643 ($M + '*') $null -Fits }
$Cases['cmp-files'] = { Mask-Row 'cmp-files' $FindDir $null $OpenCompare 235 ($M + '*Q') { param($g) Set-Check $g 234 $true } }
$Cases['cmp-dirs-unused'] = { Mask-Row 'cmp-dirs-unused' $FindDir $null $OpenCompare 237 ($M + '*Q') { param($g) [void][Drv098f]::Send((Find-Btn $g 236), 0x00F1, 0, 0, 5000) } }
$Cases['cmp-ctl'] = { Mask-Row 'cmp-ctl' $FindDir $null $OpenCompare 235 ($M + '*') { param($g) Set-Check $g 234 $true } -Fits }
$Cases['vname'] = { Vname-Row 'vname' (Cjk 11) }
$Cases['vname-ascii'] = { Vname-Row 'vname-ascii' ('v' * 30) }
$Cases['vname-ctl'] = { Vname-Row 'vname-ctl' ((Cjk 9) + 'ab') -Fits }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc291_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir; NewDir $FindDir
    WriteFile "$StartDir\a.txt" 'A'
    [IO.File]::WriteAllText($LP + "$FindDir\$M.txt", 'A')
    [IO.File]::WriteAllText($LP + "$FindDir\${M}xQ", 'B')
    WriteFile "$FindDir\other.txt" 'C'
    Set-Config
    Out ("mask291_probe (feature 291) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out 'M = 86 CJK letters (258 bytes), R = 85 (255 bytes)'
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
