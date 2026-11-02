<#
.SYNOPSIS
    Feature 389 probe: the User Menu's "names to compare" dialog (CCompareArgsDlg) and the Change Icon
    dialog (CChangeIconDialog) - a typed path whose UTF-8 form does not fit the program's buffer
    (MAX_PATH, 260 bytes with the NUL) is refused ("The path specified is too long."), never cut and
    used.

.DESCRIPTION
    Every typed text fits the field (UTF-16 units) but not the buffer (UTF-8 bytes; CJK letters take
    three bytes each). Rows:
      umc-name1  a seeded User Menu item (cmd.exe /c echo $(FileToCompareLeft)#$(FileToCompareRight)
                 > args.txt) run by its command (CM_USERMENU_MIN = 3000); the dialog's first name
                 C:\ + 86 CJK + 'a' (262 bytes): cut to C:\ + 85 CJK, the command was started with it.
                 PASS = OK refused ("too long"), the dialog stayed, the field whole, nothing started
      umc-name2  the same with the second name too long
      umc-ctl    both names fit exactly (C:\ + 85 CJK + 'a' = 259 bytes + NUL): accepted, nothing
                 asked, the command wrote both names whole (their ASCII tails 'a#' / 'b' prove it)
      chi-file   Configuration > User Menu, the seeded item, Change Icon (365); the file name
                 <fixture>\icons\<86 CJK>.exe (an existing copy of the program, > 259 bytes): the
                 first OK (the field changed) reloads the icons, the second OK ends the dialog.
                 Before: the icons were read for a code-page form of the name ("cannot find"), the
                 field replaced with SHELL32.DLL and stored. PASS = both OKs refused ("too long"),
                 the dialog stayed, the field whole
      chi-ctl    a copy whose full name fits exactly (259 bytes): the first OK loads its icons (the
                 list holds some), nothing asked; the second OK ends the dialog; Change Icon opened
                 again shows the name whole
    Typing is not driven: the field's text is set by WM_SETTEXT, buttons get BM_CLICK. Driver of
    291's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1. Registry exported,
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
$Root = $TempRoot + '\tc389_fit'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$IconDir = $Root + '\icons'
$ArgsFile = $OutDir + '\args.txt'
$Key01 = 'HKCU:\Software\Tandem Commander\Settings'
$WmUserConfiguration = 0x8000 + 115
$TooLong = 'too long'

function Cjk([int]$n, [int]$base = 0x4E00) { return (-join (1..$n | ForEach-Object { [char]($base + $_) })) }
function U8([string]$s) { return $Utf8.GetByteCount($s) }
function Reg-Set([string]$sub, [string]$name, $value, [string]$type) {
    $k = $Key01 + $(if ($sub) { '\' + $sub } else { '' })
    if (-not (Test-Path $k)) { [void](New-Item -Path $k -Force) }
    Set-ItemProperty -Path $k -Name $name -Value $value -Type $type
}
# one seeded user menu item (the probe's registry backup restores the user's own)
function Seed-UserMenu {
    $k = $Key01 + '\User Menu'
    if (Test-Path $k) { Remove-Item -Path $k -Recurse -Force }
    Reg-Set 'User Menu\1' 'Item Name' 'probe389' String
    Reg-Set 'User Menu\1' 'Command' $env:ComSpec String
    Reg-Set 'User Menu\1' 'Arguments' ('/c echo $(FileToCompareLeft)#$(FileToCompareRight)>"' + $ArgsFile + '"') String
    Reg-Set 'User Menu\1' 'Initial Directory' $OutDir String
    Reg-Set 'User Menu\1' 'Execute Through Shell' 0 DWord
    Reg-Set 'User Menu\1' 'Close Shell Window' 0 DWord
    Reg-Set 'User Menu\1' 'Open Shell Window' 0 DWord
    Reg-Set 'User Menu\1' 'Type' 0 DWord
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
# answers every window except $Keep: OK / Yes ('ok') or Cancel ('cancel'); until idle
function Serve389([int]$Id, $Keep = @(), [string]$Policy = 'ok', [double]$Seconds = 40) {
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
# OK on a modal dialog $Dlg (keeps $Keep open too), serves what follows; @{ Shown; Stayed; Fatal; TimedOut }
function Ok-Serve([int]$Id, [IntPtr]$Dlg, $Keep = @()) {
    $ok = Find-Btn $Dlg 1
    if (-not $ok) { throw 'the OK button was not found' }
    Click $ok
    Start-Sleep -Milliseconds 900
    $r = Serve389 $Id (@($Dlg) + @($Keep)) 'ok'
    $stayed = [Drv098f]::IsWindow($Dlg) -and [Drv098f]::IsWindowVisible($Dlg)
    return [pscustomobject]@{ Shown = (Shown $r); Stayed = $stayed; Fatal = $r.Fatal; TimedOut = $r.TimedOut }
}
function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch {
        Row $Case 'ERROR' 'FAIL' $_.Exception.Message
        if ($script:RowId -and (Test-Alive $script:RowId)) { foreach ($h in @(Get-Tops $script:RowId | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}
function Read-Args {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 8) {
        if ([IO.File]::Exists($LP + $ArgsFile)) {
            Start-Sleep -Milliseconds 400
            try { return ([IO.File]::ReadAllText($LP + $ArgsFile, [Text.Encoding]::Default)).Trim() } catch { }
        }
        Start-Sleep -Milliseconds 200
    }
    return $null
}

# ---- the names-to-compare dialog -----------------------------------------------------
# $N1 / $N2 go into IDE_UMC_NAME1 (2803) / IDE_UMC_NAME2 (2804); refuse rows: PASS = stayed, "too
# long", the field whole, nothing started; -Fits: closed, nothing asked, args.txt holds both tails
function Umc-Row([string]$Case, [string]$N1, [string]$N2, [int]$LongField, [switch]$Fits) {
    Run-Row $Case {
        Seed-UserMenu
        if ([IO.File]::Exists($LP + $ArgsFile)) { [IO.File]::Delete($LP + $ArgsFile) }
        $id = Start-Tc $StartDir; $script:RowId = $id
        $dlg = Open-ByCmd $id 3000 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'the user menu item (3000) opened no window' }
        if ((Find-Ctl $dlg 2803) -eq [IntPtr]::Zero) { throw ('not the names-to-compare dialog: ' + (Short (WinDesc $dlg))) }
        Set-Field $dlg 2803 $N1
        Set-Field $dlg 2804 $N2
        $o = Ok-Serve $id $dlg
        $script:RowFatal = $o.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $field = $(if ($LongField -eq 2) { $N2 } else { $N1 })
        $now = $null
        if ($o.Stayed) { $now = Get-Field $dlg $(if ($LongField -eq 2) { 2804 } else { 2803 }); Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](Serve389 $id @() 'cancel' 10) }
        $written = Read-Args
        $argsFacts = $(if ($null -eq $written) { 'the command wrote nothing' } else { "the command wrote {0} chars, tail '{1}'" -f $written.Length, (Tail $written 8) })
        if ($Fits) {
            # cmd writes the code page: the CJK letters become '?', the ASCII tails stay; whole = 85 letters + 'a' # 85 + 'b'
            $want = ('C:\' + ('?' * 85) + 'a#C:\' + ('?' * 85) + 'b')
            $verdictOk = (-not $o.Stayed) -and ($o.Shown -eq 'nothing') -and ($written -ceq $want)
            $after = $argsFacts + ('; whole: {0}' -f ($written -ceq $want))
        }
        else {
            $verdictOk = $o.Stayed -and ($o.Shown -match $TooLong) -and ($now -ceq $field) -and ($null -eq $written)
            $after = $(if ($o.Stayed) { "(refused) the field: {0} units, same as typed: {1}; {2}" -f $now.Length, ($now -ceq $field), $argsFacts } else { $argsFacts })
        }
        $ok = (-not $script:RowFatal) -and (-not $o.TimedOut) -and $verdictOk
        Row $Case 'RUN' (V $ok) ("names {0} / {1} bytes; dialog stayed: {2}; asked: {3}; {4}{5}" -f (U8 $N1), (U8 $N2), $o.Stayed, $o.Shown, $after, $(if ($o.TimedOut) { '; TIMED OUT' } else { '' }))
    }
}

# ---- the Change Icon dialog ----------------------------------------------------------
# selects item 0 of the User Menu page's list box (351)
function Select-First([IntPtr]$Dlg, [int]$ListId) {
    $lb = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $ListId -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
    if (-not $lb) { throw "list $ListId not found" }
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($lb, 0x018B, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # LB_GETCOUNT
    if ($res.ToInt64() -lt 2) { throw "list $ListId holds no item" }
    [void][Drv098f]::Send($lb, 0x0186, 0, 0, 5000)   # LB_SETCURSEL 0
    $page = [Drv098f]::GetParent($lb)
    [void][Drv098f]::Send($page, 0x0111, ((1 -shl 16) -bor $ListId), $lb.ToInt64(), 5000)   # WM_COMMAND LBN_SELCHANGE
    Start-Sleep -Milliseconds 300
}
function Open-ChangeIcon([int]$Id, [IntPtr]$Cfg) {
    $b = Find-Btn $Cfg 365
    if (-not $b) { throw 'Change Icon (365) not found' }
    $known = Get-Tops $Id
    Click $b
    $h = Wait-NewWin $Id $known 15
    if ($h -eq [IntPtr]::Zero) { throw 'Change Icon opened no window' }
    $r = Serve389 $Id @($Cfg, $h) 'ok' 6   # a message at the opening (the seeded command's icons)
    if ((Find-Ctl $h 661) -eq [IntPtr]::Zero) { throw ('not the Change Icon dialog: ' + (Short (WinDesc $h))) }
    return $h
}
function Icon-Count([IntPtr]$Dlg) {
    $lb = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 662 }) | Select-Object -First 1
    if (-not $lb) { return -1 }
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($lb, 0x018B, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # LB_GETCOUNT
    return [int]$res.ToInt64()
}
function Chi-Row([string]$Case, [string]$File, [switch]$Fits) {
    Run-Row $Case {
        Seed-UserMenu
        $id = Start-Tc $StartDir; $script:RowId = $id
        $cfg = Open-Config $id 2 0
        if ($cfg -eq [IntPtr]::Zero) { throw 'Configuration (User Menu) opened no window' }
        Select-First $cfg 351
        $dlg = Open-ChangeIcon $id $cfg
        Set-Field $dlg 661 $File
        $o1 = Ok-Serve $id $dlg @($cfg)
        $n1 = $(if ($o1.Stayed) { Icon-Count $dlg } else { -1 })
        $f1 = $(if ($o1.Stayed) { Get-Field $dlg 661 } else { '<closed>' })
        $o2 = $null; $f2 = '<closed>'
        if ($o1.Stayed -and -not $o1.Fatal) {
            $o2 = Ok-Serve $id $dlg @($cfg)
            if ($o2.Stayed) { $f2 = Get-Field $dlg 661 }
        }
        $script:RowFatal = $o1.Fatal; if (-not $script:RowFatal -and $o2) { $script:RowFatal = $o2.Fatal }; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $again = '(not opened)'
        $closed = (-not $o1.Stayed) -or ($o2 -and -not $o2.Stayed)
        if (-not $closed) { Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](Serve389 $id @($cfg) 'cancel' 10) }
        elseif (-not $script:RowFatal) {
            $dlg2 = Open-ChangeIcon $id $cfg
            $again = Get-Field $dlg2 661
            Close-Win $dlg2; Start-Sleep -Milliseconds 500; [void](Serve389 $id @($cfg) 'cancel' 10)
        }
        Close-Win $cfg; Start-Sleep -Milliseconds 500; [void](Serve389 $id @() 'cancel' 10)
        $s2 = $(if ($o2) { $o2.Shown } else { '-' })
        if ($Fits) {
            # the OK button takes the focus first: the edit's EN_KILLFOCUS loads the icons and the
            # click usually ends the dialog at once; if it stayed (icons loaded), the second OK ends it
            $quiet = ($o1.Shown -eq 'nothing') -and ((-not $o2) -or ($o2.Shown -eq 'nothing'))
            $loaded = (-not $o1.Stayed) -or (($n1 -gt 0) -and ($f1 -ceq $File))
            $verdictOk = $closed -and $quiet -and $loaded -and ($again -ceq $File)
        }
        else {
            $verdictOk = $o1.Stayed -and ($o1.Shown -match $TooLong) -and ($f1 -ceq $File) -and $o2 -and $o2.Stayed -and ($o2.Shown -match $TooLong) -and ($f2 -ceq $File)
        }
        $timed = $o1.TimedOut -or ($o2 -and $o2.TimedOut)
        $ok = (-not $script:RowFatal) -and (-not $timed) -and $verdictOk
        $fd = { param($t) if ($t -like '<*') { $t } else { "{0} units / {1} bytes, whole: {2}, tail '{3}'" -f $t.Length, (U8 $t), ($t -ceq $File), (Tail $t 14) } }
        Row $Case 'RUN' (V $ok) ("file {0} units / {1} bytes; OK 1: stayed {2}, asked: {3}, icons {4}, field {5}; OK 2: stayed {6}, asked: {7}, field {8}; opened again: {9}{10}" -f $File.Length, (U8 $File), $o1.Stayed, $o1.Shown, $n1, (& $fd $f1), $(if ($o2) { $o2.Stayed } else { '-' }), $s2, (& $fd $f2), (& $fd $again), $(if ($timed) { '; TIMED OUT' } else { '' }))
    }
}

$LongIcon = $IconDir + '\' + (Cjk 86) + '.exe'
$room = 259 - (U8 ($IconDir + '\')) - 4
$FitIcon = $IconDir + '\' + (Cjk ([Math]::Floor($room / 3))) + ('f' * ($room % 3)) + '.exe'
$Cases = [ordered]@{}
$Cases['umc-name1'] = { Umc-Row 'umc-name1' ('C:\' + (Cjk 86) + 'a') 'C:\b' 1 }
$Cases['umc-name2'] = { Umc-Row 'umc-name2' 'C:\a' ('C:\' + (Cjk 86) + 'b') 2 }
$Cases['umc-ctl'] = { Umc-Row 'umc-ctl' ('C:\' + (Cjk 85) + 'a') ('C:\' + (Cjk 85) + 'b') 1 -Fits }
$Cases['chi-file'] = { Chi-Row 'chi-file' $LongIcon }
$Cases['chi-ctl'] = { Chi-Row 'chi-ctl' $FitIcon -Fits }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc389_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir; NewDir $IconDir
    WriteFile "$StartDir\a.txt" 'A'
    [IO.File]::Copy($Exe, $LP + $LongIcon)
    [IO.File]::Copy($Exe, $LP + $FitIcon)
    Set-Config
    Out ("fit389_probe (feature 389) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ("Icon files: long {0} bytes, fitting {1} bytes" -f (U8 $LongIcon), (U8 $FitIcon))
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
