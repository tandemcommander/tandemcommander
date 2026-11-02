<#
.SYNOPSIS
    Viewer Find pre-fill probe: the internal viewer's Find field is pre-filled with the selection
    decoded by the viewer's encoding (UTF-8 / code page), shortened at a whole character to what
    the field and its 200-byte buffer take, and the pre-filled text is found by the search.

.DESCRIPTION
    Each row has its own folder holding one file; the panel's first file is opened by Alt+F3
    (CM_ALTVIEW 753, the internal viewer), Select All (CM_SELECTALLTEXT 6066) is posted to the
    viewer, then Find (CM_FINDSET 6063). The field is read, OK is clicked, the message boxes that
    appear are answered and recorded; Find is opened again - it pre-fills the found text (the
    selection the search left), which proves what was found. Rows:
      u8-word    "caf" + U+00E9 (UTF-8, no BOM). PASS = field "caf" + U+00E9, nothing asked, found the same
      u8-long    199 x "a" + U+00E9 U+2026 (UTF-8; 311's review row). PASS = field 199 x "a" (the
                 whole letter that does not fit the 200 bytes left out), nothing asked, found the same
      u8-cjk     70 CJK letters U+4E01.. (UTF-8, 210 bytes). PASS = the first 66 letters (198 bytes;
                 67 would be 201), nothing asked, found the same
      u8-astral  198 x "a" + U+1F600 + "b" (UTF-8). PASS = 198 x "a" + U+1F600 (200 units, 202
                 bytes would not fit - so 198 x "a"), nothing asked, found the same
      legacy     "caf" + U+00E9 + " au lait" in the ANSI code page (byte E9 then a space: not UTF-8,
                 so the viewer shows it in the code page). PASS = field "caf" + U+00E9 + " au lait"
                 (as before 398); the search's answer is recorded only (known limit: the search
                 compares the field's UTF-8 bytes with the file's code-page bytes)
      u8-tail    "caf" + byte E9 at the end of the file: the viewer's detection accepts a sequence
                 cut by the end of its sample, so it shows the file as UTF-8 with U+FFFD for E9.
                 PASS = field "caf" + U+FFFD (the selection's last, incomplete character as the
                 viewer draws it); the search's answer is recorded only
      hex        control: "caf" + U+00E9 (UTF-8) with Hex on: Find, Hex ticked, "63" searched, then
                 Select All and Find again. PASS = field "63 61 66 C3 A9"
    Driver of 397's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
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
$Root = $TempRoot + '\tcseed_viewer'
$StartDir = $Root + '\start'

$EAcute = [string][char]0x00E9
$Ellip = [string][char]0x2026
$Word = 'caf' + $EAcute
$Cjk70 = -join (1..70 | ForEach-Object { [char](0x4E00 + $_) })
$Astral = [char]::ConvertFromUtf32(0x1F600)

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
}
function Get-Field([IntPtr]$Dlg, [int]$CtlId) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { return '<no field>' }
    return [Drv098f]::GetText($f, 5000)
}
function Serve-Box([int]$Id, $Keep = @(), [double]$Seconds = 15) {
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
            $btn = Buttons $h
            $pick = $null
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
function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch {
        Row $Case 'ERROR' 'FAIL' $_.Exception.Message
        if ($script:RowId -and (Test-Alive $script:RowId)) { foreach ($h in @(Get-Tops $script:RowId | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}
function Codes([string]$s) {
    if ($s.Length -gt 12) { return ('{0} units, {1} UTF-8 bytes, ends {2}' -f $s.Length, (U8Len $s), (Codes $s.Substring($s.Length - 4))) }
    return ((@($s.ToCharArray()) | ForEach-Object { 'U+{0:X4}' -f [int]$_ }) -join ' ')
}
function Brief([string]$s) { if ($s.Length -gt 24) { return ((Esc $s.Substring(0, 8)) + '...' + (Esc $s.Substring($s.Length - 8))) }; return (Esc $s) }

function Open-View([int]$Id, [string]$FileName) {
    Key $Id 0x24                                       # VK_HOME: ".."
    Key $Id 0x28                                       # VK_DOWN: the folder's only file
    Start-Sleep -Milliseconds 300
    $view = Open-ByCmd $Id 753 15                      # CM_ALTVIEW (Alt+F3): F3 on .txt is the Code Viewer plug-in
    if ($view -eq [IntPtr]::Zero) { throw 'Alt+F3 (753) opened no window' }
    Start-Sleep -Milliseconds 1000
    $vt = [Drv098f]::Txt($view)
    if ($vt -notmatch [regex]::Escape($FileName) -or [Drv098f]::Cls($view) -ne "Salamander's Viewer Window") { throw ("not the internal viewer on {0}: [{1}] '{2}'" -f $FileName, [Drv098f]::Cls($view), (Esc $vt)) }
    return $view
}
function Open-Find([int]$Id, [IntPtr]$View) {
    $known = Get-Tops $Id
    [void][Drv098f]::PostMessageW($View, 0x0111, [IntPtr]6063, [IntPtr]::Zero)   # CM_FINDSET
    $dlg = Wait-NewWin $Id $known 10
    if ($dlg -eq [IntPtr]::Zero) { throw 'CM_FINDSET opened no window' }
    Start-Sleep -Milliseconds 500
    return $dlg
}
function Select-All([IntPtr]$View) { [void][Drv098f]::PostMessageW($View, 0x0111, [IntPtr]6066, [IntPtr]::Zero); Start-Sleep -Milliseconds 600 }   # CM_SELECTALLTEXT
function Close-View([int]$Id, [IntPtr]$View) {
    if ([Drv098f]::IsWindow($View)) { [void][Drv098f]::PostMessageW($View, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 700 }
    [void](Serve-Box $Id @() 10)
}

# Select All, Find: the field must be $Expect; OK; the answers; Find again: the found text.
# -FieldOnly: the verdict is the field alone (the search's answer is recorded as a fact).
function Seed-Row([string]$Case, [string]$Dir, [string]$FileName, [string]$Expect, [switch]$FieldOnly) {
    Run-Row $Case {
        $id = Start-Tc $Dir; $script:RowId = $id
        $view = Open-View $id $FileName
        Select-All $view
        $dlg = Open-Find $id $view
        Set-Check $dlg 6127 $false                         # Hex off (the dialog keeps the last state)
        $seed = Get-Field $dlg 6125
        $fieldOk = ($seed -ceq $Expect)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 1000
        $r = Serve-Box $id @($dlg, $view) 15
        $shown = Shown $r
        if ([Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)) { Close-Win $dlg; Start-Sleep -Milliseconds 400; [void](Serve-Box $id @($view) 5) }
        $again = '<no window>'
        $dlg2 = Open-Find $id $view
        if ($dlg2 -ne [IntPtr]::Zero) { $again = Get-Field $dlg2 6125; Close-Win $dlg2; Start-Sleep -Milliseconds 400 }
        $script:RowFatal = Fatal-Win $id
        $foundOk = ($shown -eq 'nothing') -and ($again -ceq $Expect)
        $ok = (-not $script:RowFatal) -and $fieldOk -and ($FieldOnly -or $foundOk)
        Row $Case 'RUN' (V $ok) ("pre-filled '{0}' [{1}] (expected [{2}]); asked after OK: {3}; Find again pre-filled '{4}' [{5}]{6}" -f (Brief $seed), (Codes $seed), (Codes $Expect), $shown, (Brief $again), (Codes $again), $(if ($FieldOnly) { ' (search answer recorded only)' } else { '' }))
        Close-View $id $view
    }
}
function Hex-Row([string]$Case, [string]$Dir, [string]$FileName, [string]$Expect) {
    Run-Row $Case {
        $id = Start-Tc $Dir; $script:RowId = $id
        $view = Open-View $id $FileName
        $dlg = Open-Find $id $view
        Set-Check $dlg 6127 $true                          # Hex
        Set-Field $dlg 6125 '63'
        Click-Ok $dlg
        Start-Sleep -Milliseconds 1000
        $r = Serve-Box $id @($dlg, $view) 15
        if ([Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)) { Close-Win $dlg; Start-Sleep -Milliseconds 400 }
        Select-All $view
        $dlg2 = Open-Find $id $view
        $seed = Get-Field $dlg2 6125
        Set-Check $dlg2 6127 $false                        # leave Hex off for the next row
        Close-Win $dlg2; Start-Sleep -Milliseconds 400
        $script:RowFatal = Fatal-Win $id
        $ok = (-not $script:RowFatal) -and ($seed -ceq $Expect)
        Row $Case 'RUN' (V $ok) ("asked after searching 63: {0}; Select All + Find pre-filled '{1}' (expected '{2}')" -f (Shown $r), (Esc $seed), $Expect)
        Close-View $id $view
    }
}

$Cases = [ordered]@{
    'u8-word'   = @{ Text = $Word; Enc = 'utf8'; Expect = $Word }
    'u8-long'   = @{ Text = ('a' * 199) + $EAcute + $Ellip; Enc = 'utf8'; Expect = ('a' * 199) }
    'u8-cjk'    = @{ Text = $Cjk70; Enc = 'utf8'; Expect = $Cjk70.Substring(0, 66) }
    'u8-astral' = @{ Text = ('a' * 198) + $Astral + 'b'; Enc = 'utf8'; Expect = ('a' * 198) }
    'legacy'    = @{ Text = $Word + ' au lait'; Enc = 'acp'; Expect = $Word + ' au lait'; FieldOnly = $true }
    'u8-tail'   = @{ Text = $Word; Enc = 'acp'; Expect = 'caf' + [string][char]0xFFFD; FieldOnly = $true }
    'hex'       = @{ Text = $Word; Enc = 'utf8'; Expect = '63 61 66 C3 A9'; Hex = $true }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tcseed_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    WriteFile "$StartDir\a.txt" 'A'
    $acp = [Text.Encoding]::GetEncoding([int][Drv098f]::GetACP())
    foreach ($k in @($Cases.Keys)) {
        $d = $Root + '\' + $k; NewDir $d
        $enc = if ($Cases[$k].Enc -eq 'acp') { $acp } else { New-Object Text.UTF8Encoding($false) }
        [IO.File]::WriteAllText($LP + "$d\$k.txt", $Cases[$k].Text, $enc)
    }
    Set-Config
    Out ("seed_probe (viewer Find pre-fill) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ''
    foreach ($k in @($Cases.Keys)) {
        if (Want $k) {
            & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
            if ($existed) { & cmd.exe /c "reg import `"$backup`" >nul 2>&1" }
            Set-Config
            & reg.exe add "$RegKey\Settings\Viewer" /v 'Auto-Copy Selection' /t REG_DWORD /d 0 /f | Out-Null   # never touch the clipboard
            $d = $Root + '\' + $k
            if ($Cases[$k].Hex) { Hex-Row $k $d "$k.txt" $Cases[$k].Expect }
            elseif ($Cases[$k].FieldOnly) { Seed-Row $k $d "$k.txt" $Cases[$k].Expect -FieldOnly }
            else { Seed-Row $k $d "$k.txt" $Cases[$k].Expect }
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
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.UTF8Encoding($true))) }
}
exit $nf
