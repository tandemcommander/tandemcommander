<#
.SYNOPSIS
    Feature 299 probe: the Unpack dialog (Alt+F9, CM_UNPACK 851) - a target path or a mask whose
    UTF-8 form does not fit the program's buffer (260 bytes) is refused ("The path specified is too
    long."), never cut and unpacked into another folder or with another mask.

.DESCRIPTION
    Fixture per row: <row>\src\a.zip (members a.k = 'K', a.kp = 'KP', made by .NET) and an empty
    <row>\tgt. The left panel shows <row>\src, Home, End focuses a.zip, Alt+F9 (851) opens the
    dialog (the ZIP plug-in is the unpacker offered for .zip); the path field (210, a combo box) and
    the mask field (521) are set by WM_SETTEXT, OK is clicked, the boxes answered OK / Yes.
    T = "<row>\tgt\": P258 = T + CJK letters + 'x' padding, 258 bytes of UTF-8; P255 likewise 255.
    R = 85 CJK letters (255 bytes). Rows:
      path-cjk    path P258 + "\sub" (262 bytes): cut to P258 + "\" - unpacked into another folder.
                  PASS = refused, the path field whole, nothing under tgt
      path-ascii  path T + 'p' padding to 258 bytes + "\sub" (ASCII; the combo box has no limit):
                  PASS = refused, the field whole, nothing under tgt
      mask-cjk    path T + "m", mask R + ";*.kp" (260 bytes): cut to R;*.k - a.k unpacked instead of
                  a.kp. PASS = refused, the mask field whole, nothing under tgt
      both        path as path-cjk, mask as mask-cjk, "Delete archive after unpacking" (6210) checked:
                  PASS = refused for the path field (the first), nothing under tgt, a.zip kept
                  (every refuse row also requires a.zip kept)
      ctl         the control: path T + "c", mask R + ";*.k" (259 bytes, fits): accepted, nothing
                  asked, tgt\c holds a.k only
      ctl-path    the control at the path limit: path P255 (fits), mask "*.k": accepted, nothing
                  asked, P255 holds a.k only
    Typing is not driven (WM_SETTEXT). Driver of 291's probe (098's library). MUST run through
    tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified. Exit code = FAIL rows.
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
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. $Lib
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$Root = $TempRoot + '\tc299_unp'
$StartDir = $Root + '\start'
$TooLong = 'too long'

function Cjk([int]$n, [int]$base = 0x4E00) { return (-join (1..$n | ForEach-Object { [char]($base + $_) })) }
function U8([string]$s) { return $Utf8.GetByteCount($s) }
$R = Cjk 85
# $Prefix + CJK letters + 'x' padding, exactly $Bytes bytes of UTF-8 ($Prefix is ASCII)
function Pad-Cjk([string]$Prefix, [int]$Bytes) {
    $left = $Bytes - (U8 $Prefix)
    $k = [Math]::Floor($left / 3)
    return ($Prefix + (Cjk $k 0x4E80) + ('x' * ($left - 3 * $k)))
}
function Pad-Ascii([string]$Prefix, [int]$Bytes) { return ($Prefix + ('p' * ($Bytes - (U8 $Prefix)))) }
function Zip-Make([string]$Zip) {
    $z = [IO.Compression.ZipFile]::Open($LP + $Zip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($m in @(@('a.k', 'K'), @('a.kp', 'KP'))) {
            $w = New-Object IO.StreamWriter($z.CreateEntry($m[0]).Open()); $w.Write($m[1]); $w.Dispose()
        }
    }
    finally { $z.Dispose() }
}
# every file under $Dir, relative, with its content
function Under([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetFiles($LP + $Dir, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object {
            $rel = $_.Substring(($LP + $Dir).Length + 1)
            $rel + '=' + [IO.File]::ReadAllText($_)
        } | Sort-Object)
}
function Short-Rel([string]$s) { if ($s.Length -gt 50) { return ('...(' + $s.Length + ' units) ' + (Tail $s 24)) } return (Esc $s) }
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
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
function Serve299([int]$Id, $Keep = @(), [string]$Policy = 'ok', [double]$Seconds = 60) {
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
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) { continue }   # progress
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            [void]$r.Messages.Add($d)
            $pick = $null
            if ($Policy -eq 'ok') { foreach ($want in @(6, 1)) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } } }
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

# one row: $PathText / $MaskText into the dialog ($null = keep the field), OK.
# Refuse rows ($Field = the field that must be refused): PASS = the dialog stayed, "too long", that
# field whole at the refusal, nothing under tgt. -Fits rows: PASS = closed, nothing asked, the files
# under tgt are exactly $Expect.
function Unpack-Row([string]$Case, [scriptblock]$Texts, [int]$Field, [string[]]$Expect, [switch]$Fits) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    NewDir ($d + '\src'); NewDir ($d + '\tgt')
    Zip-Make ($d + '\src\a.zip')
    $t = & $Texts ($d + '\tgt\')
    if ($t.Expect) { $Expect = $t.Expect }
    $id = 0; $fatal = $null; $before = Reports
    try {
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 851 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Unpack') { throw ("851 opened '{0}', not the Unpack dialog" -f [Drv098f]::Txt($dlg)) }
        if ((Find-Ctl $dlg 521) -eq [IntPtr]::Zero) { throw 'the mask field 521 was not found' }
        Start-Sleep -Milliseconds 400
        $wasPath = Get-Field $dlg 210; $wasMask = Get-Field $dlg 521
        if ($null -ne $t.Path) { Set-Field $dlg 210 $t.Path }
        if ($null -ne $t.Mask) { Set-Field $dlg 521 $t.Mask }
        if ($t.DeleteArc) {
            $b = Find-Btn $dlg 6210
            if (-not $b -or -not [Drv098f]::IsWindowEnabled($b)) { throw 'the box "Delete archive after unpacking" (6210) is missing or disabled' }
            [void][Drv098f]::Send($b, 0x00F1, 1, 0, 5000)   # BM_SETCHECK BST_CHECKED
        }
        $typed = $(if ($Field -eq 521) { $t.Mask } else { $t.Path })
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve299 $id @($dlg) 'ok'
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        $atRefusal = $null
        if ($stayed -and -not $fatal) {
            $atRefusal = Get-Field $dlg $Field
            Close-Win $dlg; Start-Sleep -Milliseconds 500
            $r2 = Serve299 $id @() 'cancel' 15
            foreach ($m in $r2.Messages) { [void]$r.Messages.Add('after cancel: ' + $m) }
            if ($r2.Fatal) { $fatal = $r2.Fatal }
        }
        Start-Sleep -Milliseconds 500
        $files = @(Under ($d + '\tgt'))
        $arcKept = [IO.File]::Exists($LP + $d + '\src\a.zip')
        $shown = Shown $r
        if ($Fits) { $verdictOk = (-not $stayed) -and ($shown -eq 'nothing') -and ((($files | Sort-Object) -join '|') -ceq (($Expect | Sort-Object) -join '|')) }
        else { $verdictOk = $stayed -and ($shown -match $TooLong) -and ($atRefusal -ceq $typed) -and ($files.Count -eq 0) -and $arcKept }
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and $verdictOk
        $atText = $(if ($null -ne $atRefusal) { "{0} units, whole: {1}" -f $atRefusal.Length, ($atRefusal -ceq $typed) } else { '(not read)' })
        Row $Case 'RUN' (V $ok) ("field {0} typed {1} units / {2} bytes (path was {3} bytes, mask '{4}'); dialog stayed: {5}; at the refusal: {6}; asked: {7}; under tgt: {8}; a.zip kept: {9}{10}" -f $Field, $typed.Length, (U8 $typed), (U8 $wasPath), (Esc $wasMask), $stayed, $atText, $shown, $(if ($files.Count) { ($files | ForEach-Object { Short-Rel $_ }) -join ', ' } else { 'nothing' }), $arcKept, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }))
    }
    catch {
        Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace)
        if ($id -and (Test-Alive $id)) { foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc299_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("unpack299_probe (feature 299) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ("R = 85 CJK letters (255 bytes); fixture {0}" -f $Root)
    Out ''
    Unpack-Row 'path-cjk' { param($T) @{ Path = ((Pad-Cjk $T 258) + '\sub'); Mask = $null } } 210 @()
    Unpack-Row 'path-ascii' { param($T) @{ Path = ((Pad-Ascii $T 258) + '\sub'); Mask = $null } } 210 @()
    Unpack-Row 'mask-cjk' { param($T) @{ Path = ($T + 'm'); Mask = ($R + ';*.kp') } } 521 @()
    Unpack-Row 'both' { param($T) @{ Path = ((Pad-Cjk $T 258) + '\sub'); Mask = ($R + ';*.kp'); DeleteArc = $true } } 210 @()
    Unpack-Row 'ctl' { param($T) @{ Path = ($T + 'c'); Mask = ($R + ';*.k') } } 521 @('c\a.k=K') -Fits
    Unpack-Row 'ctl-path' { param($T) $p = Pad-Cjk $T 255; @{ Path = $p; Mask = '*.k'; Expect = @($p.Substring($T.Length) + '\a.k=K') } } 210 @() -Fits
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
