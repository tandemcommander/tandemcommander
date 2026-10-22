<#
.SYNOPSIS
    Feature 311 probe: Find's "Containing" text and the viewer's Find text - text whose UTF-8 form does not fit the
    program's buffer (GREP_TEXT_LEN / FIND_TEXT_LEN = 201 bytes) is refused ("The path specified is
    too long."), never cut, searched for or stored.

.DESCRIPTION
    Every typed text fits the field (200 UTF-16 units) but not the buffer (200 bytes + NUL; CJK
    letters take three bytes each). C66 = 66 CJK letters (198 bytes), C67 = 67 (201 bytes). The
    fixture folder holds cut.txt (C66 + "ZZ"), full.txt (C67) and other.txt ("C"), UTF-8 without a
    BOM. A cut C67 is C66, which both cut.txt and full.txt contain. Rows:
      grep        Find (741), "Search file content" on, Containing C67: cut, found 2. PASS = "too
                  long", nothing found, the field whole
      grep-ctl    Containing C66 + "Z" (199 bytes): found 1 (cut.txt), nothing asked, the field whole
      grep-regex  "Regular expression" on, Containing C66 + "ZZQ" (201 bytes): cut to C66 + "ZZ",
                  found cut.txt. PASS = refused as grep
      grep-hex    "Hex" on, Containing "C66" 5A 5A (quoted text, 206 bytes): cut to "C66", found 2.
                  PASS = refused as grep
      grep-add    Containing C67, Options > Add Current (CM_FIND_ADD_CURRENT): the field was written
                  back cut. PASS = "too long", the field whole
      grep-manage Containing C67, Options > Manage (CM_FIND_MANAGE): as grep-add (no window)
      grep-ignore Containing C67, Options > Ignore (CM_FIND_IGNORE): as grep-add
      grep-option a stored Find option without a Containing text (seeded), Containing C67, the
                  option chosen (CM_FIND_OPTIONS_FIRST): the field was kept cut. PASS = the field
                  whole after the option, then Find refused
      view-find   the internal viewer (Alt+F3 on cut.txt), Find (CM_FINDSET), C67: cut and searched.
                  PASS = the dialog stays, "too long", the field whole
      view-ctl    the viewer's Find with C66 + "Z": the dialog closes, nothing "too long"
      view-copy   Find with C66 + "Z" (found cut.txt), then Containing C67, the result viewed with
                  the internal viewer (CM_FIND_ALTVIEW): the Containing text was copied into the
                  viewer's Find cut (Configuration "copy find text", on by default). PASS = the
                  viewer's Find field is not the cut C66
      view-copy-ctl the same with Containing left at C66 + "Z" (fits): PASS = the viewer's Find
                  field holds C66 + "Z" (the copy still works)
      view-copy-keep the result viewed with C66 + "Z" first (copied), then with C67: PASS = the
                  viewer's Find still holds C66 + "Z" (its earlier text kept; added by review 1)
    Typing is not driven: the field's text is set by WM_SETTEXT, buttons are clicked by BM_CLICK.
    Driver of 291's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
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
$Root = $TempRoot + '\tc311_grep'
$StartDir = $Root + '\start'
$FindDir = $Root + '\find'
$Key01 = 'HKCU:\Software\Tandem Commander\0.1'
$TooLong = 'too long'

function Cjk([int]$n, [int]$base = 0x4E00) { return (-join (1..$n | ForEach-Object { [char]($base + $_) })) }
$C66 = Cjk 66
$C67 = Cjk 67
$Q = [string][char]0x22
function Reg-Set([string]$sub, [string]$name, $value, [string]$type) {
    $k = $Key01 + $(if ($sub) { '\' + $sub } else { '' })
    if (-not (Test-Path $k)) { [void](New-Item -Path $k -Force) }
    Set-ItemProperty -Path $k -Name $name -Value $value -Type $type
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
# answers every window except $Keep: OK / Yes ('ok') or Cancel ('cancel'); until idle
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

# ---- the Find dialog rows ------------------------------------------------------------
function Find-Count([IntPtr]$Dlg) {
    $lv = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' }) | Select-Object -First 1
    if (-not $lv) { return -1 }
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($lv, 0x1004, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # LVM_GETITEMCOUNT
    return [int]$res.ToInt64()
}
# $Action: 'find' (Find), or a command id posted to the dialog (then Find is not started); $Expect:
# 'refuse' (a "too long" answer, nothing found, the field whole) or 'found1' (no question, 1 found,
# the field whole); $Mode: 'text', 'regex' or 'hex'; $SeedOption: a stored option without a
# Containing text is chosen before the action
function Grep-Row([string]$Case, [string]$Text, $Action, [string]$Expect, [string]$Mode = 'text', [switch]$SeedOption) {
    Run-Row $Case {
        if ($SeedOption) {
            & cmd.exe /c "reg delete `"$RegKey\0.1\Configuration\Find Options`" /f >nul 2>&1"
            Reg-Set 'Configuration\Find Options\1' 'ItemName' 'probe311' String
        }
        $id = Start-Tc $FindDir; $script:RowId = $id
        $dlg = Open-ByCmd $id 741 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
        Start-Sleep -Milliseconds 600
        Set-Field $dlg 2501 $FindDir
        Set-Field $dlg 2505 '*.txt'
        Set-Check $dlg 2508 $true                          # Search file content: the Containing field shows
        if ($Mode -eq 'regex') { Set-Check $dlg 2513 $true }
        if ($Mode -eq 'hex') { Set-Check $dlg 2516 $true }
        Set-Field $dlg 2504 $Text
        $optFacts = ''
        if ($SeedOption) {
            [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]2250, [IntPtr]::Zero)   # CM_FIND_OPTIONS_FIRST
            Start-Sleep -Milliseconds 800
            $afterOpt = Get-Field $dlg 2504
            $optFacts = ("after the option the field: {0} units, whole: {1}; " -f $afterOpt.Length, ($afterOpt -ceq $Text))
        }
        if ($Action -eq 'find') { Click (Find-Btn $dlg 1) } else { [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr][int]$Action, [IntPtr]::Zero) }
        Start-Sleep -Milliseconds 1500
        $r = Serve-Grep $id @($dlg) 'ok'
        Start-Sleep -Milliseconds 1500
        $script:RowFatal = $r.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $count = Find-Count $dlg
        $now = Get-Field $dlg 2504
        $whole = ($now -ceq $Text)
        $shown = Shown $r
        if ($Expect -eq 'refuse') { $verdictOk = ($shown -match $TooLong) -and ($count -le 0) -and $whole }
        else { $verdictOk = ($shown -eq 'nothing') -and ($count -eq 1) -and $whole }
        if ($SeedOption) { $verdictOk = $verdictOk -and ($afterOpt -ceq $Text) }
        $ok = (-not $script:RowFatal) -and (-not $r.TimedOut) -and $verdictOk
        Row $Case 'RUN' (V $ok) ("{0}: typed {1} units / {2} bytes; {3}asked: {4}; found: {5}; the field after: {6} units / {7} bytes, whole: {8}{9}" -f $Mode, $Text.Length, (U8 $Text), $optFacts, $shown, $count, $now.Length, (U8 $now), $whole, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }))
        Close-Win $dlg; Start-Sleep -Milliseconds 500
        [void](Serve-Grep $id @() 'cancel' 10)
    }
}

# ---- the internal viewer's Find --------------------------------------------------------
# F3 on cut.txt, CM_FINDSET (6063) to the viewer, $Text into IDC_FINDTEXT (6125), OK; refuse rows:
# PASS = the dialog stayed, "too long", the field whole; -Fits: the dialog closed, nothing "too long"
function View-Row([string]$Case, [string]$Text, [switch]$Fits) {
    Run-Row $Case {
        $id = Start-Tc $FindDir; $script:RowId = $id
        Key $id 0x24                                       # VK_HOME: ".."
        Key $id 0x28                                       # VK_DOWN: the first file, cut.txt
        Start-Sleep -Milliseconds 300
        $view = Open-ByCmd $id 753 15                      # CM_ALTVIEW (Alt+F3): F3 on .txt is the Code Viewer plug-in
        if ($view -eq [IntPtr]::Zero) { throw 'Alt+F3 (753) opened no window' }
        Start-Sleep -Milliseconds 1000
        $vt = [Drv098f]::Txt($view)
        if ($vt -notmatch 'cut\.txt' -or [Drv098f]::Cls($view) -ne "Salamander's Viewer Window") { throw ("not the internal viewer on cut.txt: [{0}] '{1}'" -f [Drv098f]::Cls($view), (Esc $vt)) }
        $known = Get-Tops $id
        [void][Drv098f]::PostMessageW($view, 0x0111, [IntPtr]6063, [IntPtr]::Zero)   # CM_FINDSET
        $dlg = Wait-NewWin $id $known 10
        if ($dlg -eq [IntPtr]::Zero) { throw ("CM_FINDSET opened no window; viewer class '{0}'; windows: {1}" -f [Drv098f]::Cls($view), ((@(Get-Tops $id) | ForEach-Object { WinDesc $_ }) -join ' || ')) }
        Start-Sleep -Milliseconds 500
        Set-Field $dlg 6125 $Text
        Click-Ok $dlg
        Start-Sleep -Milliseconds 1000
        $r = Serve-Grep $id @($dlg, $view) 'ok' 20
        $script:RowFatal = $r.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        $now = $(if ($stayed) { Get-Field $dlg 6125 } else { '<closed>' })
        $shown = Shown $r
        if ($Fits) { $verdictOk = (-not $stayed) -and ($shown -notmatch $TooLong) }
        else { $verdictOk = $stayed -and ($shown -match $TooLong) -and ($now -ceq $Text) }
        $ok = (-not $script:RowFatal) -and (-not $r.TimedOut) -and $verdictOk
        Row $Case 'RUN' (V $ok) ("typed {0} units / {1} bytes; dialog stayed: {2}; asked: {3}; the field: {4}{5}" -f $Text.Length, (U8 $Text), $stayed, $shown, $(if ($stayed) { "{0} units, whole: {1}" -f $now.Length, ($now -ceq $Text) } else { '(closed)' }), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }))
        if ($stayed) { Close-Win $dlg; Start-Sleep -Milliseconds 400 }
        if ([Drv098f]::IsWindow($view)) { [void][Drv098f]::PostMessageW($view, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 700 }
        [void](Serve-Grep $id @() 'cancel' 10)
    }
}


# ---- the copy of Containing into the viewer's Find -------------------------------------
# Find with a text that fits (found cut.txt), then the Containing field changed to C67, the found
# file viewed with the internal viewer (CM_FIND_ALTVIEW 2222); its Find (CM_FINDSET) shows the text
# the Find dialog copied (GlobalFindDialog): PASS = not the cut C66. -Fits: Containing stays C66 + Z,
# PASS = the viewer shows it. -Keep: the result is viewed once with C66 + Z first, PASS = the viewer
# still shows C66 + Z after the view with C67 (its earlier find text kept)
function AltView-FindText([int]$Id, [IntPtr]$Dlg) {   # the focused result viewed (Alt+F3), the viewer's Find field read
    $lv = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' }) | Select-Object -First 1
    [void][Drv098f]::Send($Dlg, 0x0028, $lv.ToInt64(), 1, 5000)   # WM_NEXTDLGCTL: the result list
    [void][Drv098f]::Send($lv, 0x0100, 0x24, 0x01470001, 5000)    # VK_HOME: the found file focused
    Start-Sleep -Milliseconds 300
    $known = Get-Tops $Id
    [void][Drv098f]::PostMessageW($Dlg, 0x0111, [IntPtr]2222, [IntPtr]::Zero)   # CM_FIND_ALTVIEW
    $view = Wait-NewWin $Id $known 15
    if ($view -eq [IntPtr]::Zero) { throw 'CM_FIND_ALTVIEW opened no window' }
    Start-Sleep -Milliseconds 1000
    if ([Drv098f]::Cls($view) -ne "Salamander's Viewer Window") { throw ("not the internal viewer: {0}" -f (WinDesc $view)) }
    $known = Get-Tops $Id
    [void][Drv098f]::PostMessageW($view, 0x0111, [IntPtr]6063, [IntPtr]::Zero)   # CM_FINDSET
    $fd = Wait-NewWin $Id $known 10
    if ($fd -eq [IntPtr]::Zero) { throw 'CM_FINDSET opened no window' }
    Start-Sleep -Milliseconds 500
    $t = Get-Field $fd 6125
    Close-Win $fd; Start-Sleep -Milliseconds 400
    if ([Drv098f]::IsWindow($view)) { [void][Drv098f]::PostMessageW($view, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 700 }
    return $t
}
function Copy-Row([string]$Case, [switch]$Fits, [switch]$Keep) {
    Run-Row $Case {
        $id = Start-Tc $FindDir; $script:RowId = $id
        $dlg = Open-ByCmd $id 741 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
        Start-Sleep -Milliseconds 600
        Set-Field $dlg 2501 $FindDir
        Set-Field $dlg 2505 '*.txt'
        Set-Check $dlg 2508 $true
        Set-Field $dlg 2504 ($C66 + 'Z')
        Click (Find-Btn $dlg 1)
        Start-Sleep -Milliseconds 1500
        $r = Serve-Grep $id @($dlg) 'ok'
        Start-Sleep -Milliseconds 1000
        $count = Find-Count $dlg
        if ($count -ne 1) { throw ("the search that fits found {0}, not 1 ({1})" -f $count, (Shown $r)) }
        $firstFacts = ''
        if ($Keep) {
            $first = AltView-FindText $id $dlg
            if ($first -cne ($C66 + 'Z')) { throw ("the first view did not copy C66 + Z: {0} units" -f $first.Length) }
            $firstFacts = 'first view copied C66 + Z; '
        }
        $typed = $(if ($Fits) { $C66 + 'Z' } else { $C67 })
        Set-Field $dlg 2504 $typed
        $now = AltView-FindText $id $dlg
        $field = Get-Field $dlg 2504
        $script:RowFatal = Fatal-Win $id
        $cut = ($now -ceq $C66)
        if ($Fits) { $verdictOk = ($now -ceq $typed) }
        elseif ($Keep) { $verdictOk = ($now -ceq ($C66 + 'Z')) }
        else { $verdictOk = (-not $cut) -and ($now -cne '<no field>') }
        $ok = (-not $script:RowFatal) -and $verdictOk
        Row $Case 'RUN' (V $ok) ("{0}the Find field: {1} units / {2} bytes, whole: {3}; the viewer's Find field: {4} units / {5} bytes, the cut C66: {6}, same as the Find field: {7}, '{8}'" -f $firstFacts, $field.Length, (U8 $field), ($field -ceq $typed), $now.Length, (U8 $now), $cut, ($now -ceq $typed), (Tail $now 8))
        Close-Win $dlg; Start-Sleep -Milliseconds 500
        [void](Serve-Grep $id @() 'cancel' 10)
    }
}

$Cases = [ordered]@{}
$Cases['grep'] = { Grep-Row 'grep' $C67 'find' 'refuse' }
$Cases['grep-ctl'] = { Grep-Row 'grep-ctl' ($C66 + 'Z') 'find' 'found1' }
$Cases['grep-regex'] = { Grep-Row 'grep-regex' ($C66 + 'ZZQ') 'find' 'refuse' 'regex' }
$Cases['grep-hex'] = { Grep-Row 'grep-hex' ($Q + $C66 + $Q + ' 5A 5A') 'find' 'refuse' 'hex' }
$Cases['grep-add'] = { Grep-Row 'grep-add' $C67 2247 'refuse' }
$Cases['grep-manage'] = { Grep-Row 'grep-manage' $C67 2248 'refuse' }
$Cases['grep-ignore'] = { Grep-Row 'grep-ignore' $C67 2293 'refuse' }
$Cases['grep-option'] = { Grep-Row 'grep-option' $C67 'find' 'refuse' -SeedOption }
$Cases['view-find'] = { View-Row 'view-find' $C67 }
$Cases['view-ctl'] = { View-Row 'view-ctl' ($C66 + 'Z') -Fits }
$Cases['view-copy'] = { Copy-Row 'view-copy' }
$Cases['view-copy-ctl'] = { Copy-Row 'view-copy-ctl' -Fits }
$Cases['view-copy-keep'] = { Copy-Row 'view-copy-keep' -Keep }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc311_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $FindDir
    WriteFile "$StartDir\a.txt" 'A'
    [IO.File]::WriteAllText($LP + "$FindDir\cut.txt", ($C66 + 'ZZ'), $Utf8)
    [IO.File]::WriteAllText($LP + "$FindDir\full.txt", $C67, $Utf8)
    WriteFile "$FindDir\other.txt" 'C'
    Set-Config
    Out ("grep311_probe (feature 311) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out 'C66 = 66 CJK letters (198 bytes), C67 = 67 (201 bytes); cut.txt = C66 + ZZ, full.txt = C67'
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
