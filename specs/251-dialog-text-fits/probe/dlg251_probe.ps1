<#
.SYNOPSIS
    Feature 251 probe: text typed into a field whose UTF-8 form does not fit the caller's buffer
    is refused ("The path specified is too long."), never cut and acted upon.

.DESCRIPTION
    Every typed text fits the field (UTF-16 units) but not the buffer (UTF-8 bytes; CJK letters
    take three bytes each). Rows:
      mfl-name   Make File List (811), destination File, the file name typed as out\<CJK>.txt
                 (> 260 bytes): cut, it names ANOTHER file. PASS = refused, out\ empty
      mfl-line   Make File List, the line format $(FileName)<CJK>END$(CRLF) (> 260 bytes), file
                 out\list.txt: cut, END and the line end are lost. PASS = refused, no file
      mfl-ctl    Make File List, out\list.txt and the default line: PASS = the file holds a.txt
      um-cmd     Configuration > User Menu (a seeded item), Command <CJK>.exe (> 260 bytes)
      um-args    the same item, Arguments of 11,000 CJK letters (> 32,772 bytes)
      vw-cmd     Configuration > Viewers, the first item's Command (> 260 bytes)
      ed-cmd     Configuration > Editors, the first item's Command (> 260 bytes)
      hp-path    Configuration > Hot Paths, slot 1's path of 400 CJK letters (> 1,040 bytes;
                 the code-page fallback stored '?')
      hp-name    the same slot's name of 100 CJK letters (> 260 bytes)
      drv-goto   Configuration > Drives, "If path is inaccessible go to" (> 260 bytes)
      drv-browse the same field, then its browse button: the browse started from a cut path.
                 PASS = refused, no browse window
      en-default Edit New (744), its menu "Save as default" with a name of > 260 bytes
    Config rows: PASS = refused and the dialog stays open (the probe cancels it); FAIL = the
    dialog closed and the field, opened again, holds another text than typed.
    Driver of 214's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
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
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. $Lib
$Root = $TempRoot + '\tc251_dlg'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$Key01 = 'HKCU:\Software\Tandem Commander\0.1'
$WmUserConfiguration = 0x8000 + 115
$TooLong = 'too long'

function Cjk([int]$n, [int]$base = 0x4E00) { return (-join (1..$n | ForEach-Object { [char]($base + $_) })) }
function Reg-Set([string]$sub, [string]$name, $value, [string]$type) {
    $k = $Key01 + $(if ($sub) { '\' + $sub } else { '' })
    if (-not (Test-Path $k)) { [void](New-Item -Path $k -Force) }
    Set-ItemProperty -Path $k -Name $name -Value $value -Type $type
}
# one seeded user menu item (the probe's registry backup restores the user's own)
function Seed-UserMenu {
    $k = $Key01 + '\User Menu'
    if (Test-Path $k) { Remove-Item -Path $k -Recurse -Force }
    Reg-Set 'User Menu\1' 'Item Name' 'probe251' String
    Reg-Set 'User Menu\1' 'Command' 'notepad.exe' String
    Reg-Set 'User Menu\1' 'Arguments' '' String
    Reg-Set 'User Menu\1' 'Initial Directory' '$(FullPath)' String
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
function Serve251([int]$Id, $Keep = @(), [string]$Policy = 'ok', [double]$Seconds = 40) {
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
# OK on $Dlg, serves what follows; returns @{ Shown; Stayed; Fatal; TimedOut } and cancels a dialog that stayed
function Ok-AndServe([int]$Id, [IntPtr]$Dlg) {
    # the Configuration dialog (winlib's tree property dialog) has its OK button as id 5; a posted
    # IDOK would reach the page and end the page alone
    $tpdOk = Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 5 -and [Drv098f]::GetParent($_) -eq $Dlg } | Select-Object -First 1
    if ($tpdOk) { Click $tpdOk } else { Click-Ok $Dlg }
    Start-Sleep -Milliseconds 700
    $r = Serve251 $Id @($Dlg) 'ok'
    $stayed = [Drv098f]::IsWindow($Dlg) -and [Drv098f]::IsWindowVisible($Dlg)
    if ($stayed -and -not $r.Fatal) { Close-Win $Dlg; Start-Sleep -Milliseconds 500; $r2 = Serve251 $Id @() 'cancel' 15; foreach ($m in $r2.Messages) { [void]$r.Messages.Add('after cancel: ' + $m) }; if ($r2.Fatal) { $r.Fatal = $r2.Fatal } }
    return [pscustomobject]@{ Shown = (Shown $r); Stayed = $stayed; Fatal = $r.Fatal; TimedOut = $r.TimedOut }
}
function Files([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetFiles($LP + $Dir) | ForEach-Object { [IO.Path]::GetFileName($_) })
}
function U8([string]$s) { return $Utf8.GetByteCount($s) }

# ---- rows ----------------------------------------------------------------------------
function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}

# Make File List: $Name into the file name (2384), $Line (or $null) into the line format (2382)
function Mfl-Row([string]$Case, [string]$Name, $Line, [scriptblock]$Check) {
    Run-Row $Case {
        $d = $Root + '\' + $Case; NewDir "$d\src"; NewDir "$d\out"
        WriteFile "$d\src\a.txt" 'A'
        $id = Start-Tc "$d\src"; $script:RowId = $id
        [void](Do-ChangeDir $id "$d\src\a.txt")
        Start-Sleep -Milliseconds 400
        $dlg = Open-ByCmd $id 811 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Make File List (811) opened no window' }
        $radio = Find-Btn $dlg 2390
        if (-not $radio) { throw 'the File destination (2390) was not found' }
        Click $radio; Start-Sleep -Milliseconds 400
        Set-Field $dlg 2384 $Name
        if ($null -ne $Line) { Set-Field $dlg 2382 $Line }
        $o = Ok-AndServe $id $dlg
        $script:RowFatal = $o.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $res = & $Check $d $o
        $ok = (-not $script:RowFatal) -and (-not $o.TimedOut) -and $res.Ok
        Row $Case 'RUN' (V $ok) ("{0}; name {1} bytes / {2} units; dialog stayed: {3}; asked: {4}{5}" -f $res.Facts, (U8 $Name), $Name.Length, $o.Stayed, $o.Shown, $(if ($o.TimedOut) { '; TIMED OUT' } else { '' }))
    }
}

# a Configuration page: $Prep (before the start), mode / param, $Fill sets the fields; PASS = refused
# and the dialog stayed; otherwise the field is read again in a re-opened dialog
function Cfg-Row([string]$Case, [scriptblock]$Prep, [int]$Mode, [long]$Param, [int]$Field, [string]$Text, [scriptblock]$Select) {
    Run-Row $Case {
        if ($Prep) { & $Prep }
        $id = Start-Tc $StartDir; $script:RowId = $id
        $dlg = Open-Config $id $Mode $Param
        if ($dlg -eq [IntPtr]::Zero) { throw "Configuration (mode $Mode) opened no window" }
        if ($Select) { & $Select $dlg }
        $was = Get-Field $dlg $Field
        Set-Field $dlg $Field $Text
        $o = Ok-AndServe $id $dlg
        $script:RowFatal = $o.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $after = '(not read: refused)'
        $keptText = $true
        if (-not $o.Stayed -and -not $script:RowFatal) {
            $dlg2 = Open-Config $id $Mode $Param
            if ($dlg2 -eq [IntPtr]::Zero) { throw 'Configuration did not open again' }
            if ($Select) { & $Select $dlg2 }
            $now = Get-Field $dlg2 $Field
            $keptText = ($now -ceq $Text)
            $after = ("{0} units / {1} bytes, same as typed: {2}, tail '{3}'" -f $now.Length, (U8 $now), $keptText, (Tail $now 12))
            Close-Win $dlg2; Start-Sleep -Milliseconds 400
            [void](Serve251 $id @() 'cancel' 10)
        }
        $refused = $o.Stayed -and ($o.Shown -match $TooLong)
        $ok = (-not $script:RowFatal) -and (-not $o.TimedOut) -and $refused
        Row $Case 'RUN' (V $ok) ("typed {0} units / {1} bytes (field was {2} units); dialog stayed: {3}; asked: {4}; field after OK: {5}{6}" -f $Text.Length, (U8 $Text), $was.Length, $o.Stayed, $o.Shown, $after, $(if ($o.TimedOut) { '; TIMED OUT' } else { '' }))
    }
}
# selects item 0 of the page's list box (user menu 351, viewers / editors 584)
function Select-First([IntPtr]$Dlg, [int]$ListId) {
    $lb = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $ListId -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
    if (-not $lb) { throw "list $ListId not found" }
    $n = 0; $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($lb, 0x018B, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)   # LB_GETCOUNT
    $n = $res.ToInt64()
    if ($n -lt 2) { throw "list $ListId holds no item (count $n, the last row is the new-item row)" }
    [void][Drv098f]::Send($lb, 0x0186, 0, 0, 5000)   # LB_SETCURSEL 0
    $page = [Drv098f]::GetParent($lb)
    [void][Drv098f]::Send($page, 0x0111, ((1 -shl 16) -bor $ListId), $lb.ToInt64(), 5000)   # WM_COMMAND LBN_SELCHANGE
    Start-Sleep -Milliseconds 300
}

$Cases = [ordered]@{}
$Cases['mfl-name'] = {
    $d = $Root + '\mfl-name'
    $room = 275 - (U8 "$d\out\") - 4
    $name = "$d\out\" + (Cjk ([Math]::Floor($room / 3))) + '.txt'
    Mfl-Row 'mfl-name' $name $null { param($d, $o) $f = @(Files "$d\out"); Res251 ($f.Count -eq 0 -and $o.Stayed -and $o.Shown -match $TooLong) ('out: ' + $(if ($f.Count) { ($f | ForEach-Object { "$(Esc $_) ($($_.Length) units)" }) -join '; ' } else { '(empty)' })) }
}
$Cases['mfl-line'] = {
    $d = $Root + '\mfl-line'
    $line = '$(FileName)' + (Cjk 90) + 'END$(CRLF)'
    Mfl-Row 'mfl-line' "$d\out\list.txt" $line { param($d, $o) $f = @(Files "$d\out"); $c = $(if ($f.Count) { [IO.File]::ReadAllText($LP + "$d\out\list.txt", $Utf8) } else { '' }); Res251 ($f.Count -eq 0 -and $o.Stayed -and $o.Shown -match $TooLong) ("line {0} bytes; out: {1}; list.txt ends with END+CRLF: {2}" -f (U8 $line), $(if ($f.Count) { $f -join '; ' } else { '(empty)' }), ($c -match "END`r`n$")) }
}
$Cases['mfl-ctl'] = {
    $d = $Root + '\mfl-ctl'
    Mfl-Row 'mfl-ctl' "$d\out\list.txt" $null { param($d, $o) $f = @(Files "$d\out"); $c = $(if ($f.Count) { [IO.File]::ReadAllText($LP + "$d\out\list.txt", $Utf8) } else { '' }); Res251 (($f -join ';') -eq 'list.txt' -and $c -match 'a\.txt' -and -not $o.Stayed) ("out: {0}; content '{1}'" -f $(if ($f.Count) { $f -join '; ' } else { '(empty)' }), (Esc $c.Trim())) }
}
$Cases['um-cmd'] = { Cfg-Row 'um-cmd' { Seed-UserMenu } 2 0 352 ('C:\' + (Cjk 90) + '.exe') { param($g) Select-First $g 351 } }
$Cases['um-args'] = { Cfg-Row 'um-args' { Seed-UserMenu } 2 0 359 (Cjk 11000) { param($g) Select-First $g 351 } }
$Cases['vw-cmd'] = { Cfg-Row 'vw-cmd' { Reg-Set 'Configuration' 'Last Focused Page' 19 DWord } 0 0 352 ('C:\' + (Cjk 90) + '.exe') { param($g) Select-First $g 584 } }
$Cases['ed-cmd'] = { Cfg-Row 'ed-cmd' { Reg-Set 'Configuration' 'Last Focused Page' 21 DWord } 0 0 352 ('C:\' + (Cjk 90) + '.exe') { param($g) Select-First $g 584 } }
$Cases['hp-path'] = { Cfg-Row 'hp-path' $null 1 -1 373 ('C:\' + (Cjk 400)) $null }
$Cases['hp-name'] = { Cfg-Row 'hp-name' { Reg-Set 'Hot Paths\1' 'Name' 'C:\' String; Reg-Set 'Hot Paths\1' 'Path' 'C:\' String; Reg-Set 'Hot Paths\1' 'Visible' 1 DWord } 1 -1 376 (Cjk 100) $null }
$Cases['drv-goto'] = { Cfg-Row 'drv-goto' $null 6 0 488 ('C:\' + (Cjk 90)) $null }
$Cases['drv-browse'] = {
    Run-Row 'drv-browse' {
        $id = Start-Tc $StartDir; $script:RowId = $id
        $dlg = Open-Config $id 6 0
        if ($dlg -eq [IntPtr]::Zero) { throw 'Configuration (mode 6) opened no window' }
        $t = 'C:\' + (Cjk 90)
        Set-Field $dlg 488 $t
        $b = Find-Btn $dlg 360
        if (-not $b) { throw 'the browse button (360) was not found' }
        Click $b; Start-Sleep -Milliseconds 1500
        $r = Serve251 $id @($dlg) 'cancel'
        $script:RowFatal = $r.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $s = Shown $r
        Close-Win $dlg; Start-Sleep -Milliseconds 400; [void](Serve251 $id @() 'cancel' 10)
        $ok = (-not $script:RowFatal) -and ($s -match $TooLong) -and (@($r.Messages).Count -eq 1)
        Row 'drv-browse' 'RUN' (V $ok) ("typed {0} bytes; windows after the browse button: {1}" -f (U8 $t), $s)
    }
}
$Cases['en-default'] = {
    Run-Row 'en-default' {
        $id = Start-Tc $StartDir; $script:RowId = $id
        $dlg = Open-ByCmd $id 744 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Edit New (744) opened no window' }
        $was = Get-Field $dlg 210
        $t = (Cjk 90) + '.txt'
        Set-Field $dlg 210 $t
        $b = Find-Btn $dlg 362
        if (-not $b) { throw 'the menu button (362) was not found' }
        $known = Get-Tops $id
        Click $b
        $menu = Wait-NewWin $id $known 5
        if ($menu -eq [IntPtr]::Zero -or [Drv098f]::Cls($menu) -ne '#32768') { Close-Win $dlg; Row 'en-default' 'RUN' 'NOT DRIVEN' 'the menu did not open'; return }
        foreach ($vk in @(0x28, 0x0D)) { [void][Drv098f]::PostMessageW($menu, 0x0100, [IntPtr]$vk, [IntPtr]1); Start-Sleep -Milliseconds 300 }
        Start-Sleep -Milliseconds 800
        if ([Drv098f]::IsWindow($menu) -and [Drv098f]::IsWindowVisible($menu)) { [void][Drv098f]::PostMessageW($menu, 0x0100, [IntPtr]0x1B, [IntPtr]1); Start-Sleep -Milliseconds 500; Close-Win $dlg; Row 'en-default' 'RUN' 'NOT DRIVEN' 'the menu did not take the posted keys'; return }
        $r = Serve251 $id @($dlg) 'ok'
        $script:RowFatal = $r.Fatal
        Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](Serve251 $id @() 'cancel' 10)
        $dlg2 = Open-ByCmd $id 744 15
        $now = Get-Field $dlg2 210
        Close-Win $dlg2; Start-Sleep -Milliseconds 400; [void](Serve251 $id @() 'cancel' 10)
        $s = Shown $r
        $ok = (-not $script:RowFatal) -and ($s -match $TooLong) -and ($now -ceq $was)
        Row 'en-default' 'RUN' (V $ok) ("typed {0} units / {1} bytes; default before '{2}'; asked: {3}; the field of a new Edit New: {4} units / {5} bytes, tail '{6}'" -f $t.Length, (U8 $t), (Tail $was 20), $s, $now.Length, (U8 $now), (Tail $now 12))
    }
}
function Res251([bool]$Ok, [string]$Facts) { return [pscustomobject]@{ Ok = $Ok; Facts = $Facts } }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc251_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir
    Set-Config
    Out ("dlg251_probe (feature 251) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ''
    foreach ($k in @($Cases.Keys)) {
        if (Want $k) {
            # every row starts from the user's configuration (a row's exit writes it back)
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
