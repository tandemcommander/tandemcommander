<#
.SYNOPSIS
    Feature 315 probe: the Unpack dialog (Alt+F9, CM_UNPACK 851) never offers the other panel's path
    (or that path + the archive's subfolder) cut to the dialog's 260-byte buffer - a default that
    does not fit is left out, a default that fits is offered whole.

.DESCRIPTION
    Fixture per row: <row>\src\<zip> (members a.k = 'K', a.kp = 'KP', made by .NET) and the right
    panel's folder L under <row>\tgt (created through \\?\). The program starts with the left panel
    on <row>\src (active) and the right panel on L (-r); Home, End focuses the archive, Alt+F9 (851)
    opens the dialog (the ZIP plug-in is the unpacker offered for .zip). The settings "Use the other
    panel for unpacking" (UA) and "Use the archive name as a subfolder" (SD) are written to
    Packers & Unpackers\Custom Unpackers before the start. The path combo box (210) items are read
    (CB_GETLBTEXT); the row picks item $Pick (or item 0 when there is no such item), clicks OK and
    answers the boxes OK / Yes.
    A cut entry = an item that names a folder under <row>\tgt but is neither L nor L\<subfolder>.
      other-ascii  UA=1 SD=0, L 297 bytes ASCII, item 0. PASS = no cut entry, nothing new under tgt,
                   a.k / a.kp unpacked next to the archive (the empty entry; also the other-* / alt-*
                   rows)
      other-cjk    UA=1 SD=0, L 355 bytes (CJK letters), item 0. PASS likewise
      alt-ascii    UA=0 SD=0, L 297 bytes ASCII, item 1. PASS likewise
      alt-cjk      UA=0 SD=0, L 355 bytes CJK, item 1. PASS likewise
      subdir       UA=1 SD=1, L 245 bytes ASCII (fits), archive name of 20 letters: L\<name> is 266
                   bytes. PASS = no entry naming L without the subfolder (nor cut), nothing new
                   under tgt, a.k / a.kp unpacked into <src>\<name> (the name alone offered)
      src-long     UA=0 SD=0, the archive in a 297-byte left panel folder, the empty item 0, OK: the
                   empty target becomes the archive panel's path. PASS = "too long" shown, no file
                   but the archive and no new folder in the row (the reopened dialog is cancelled)
      longname-sd  UA=0 SD=1, the archive named 87 CJK letters + '.zip' (the subfolder name alone 261
                   bytes), the empty item 0, OK. PASS = "too long", nothing unpacked (review 1 of 315:
                   the empty entry unpacked next to the archive without the subfolder)
      longname-sd-ua  the same with UA=1 and a short other panel (the old code offered it bare)
      ctl          UA=1 SD=0, L 200 bytes: item 0 = L whole, a.k unpacked into L
      ctl-alt      UA=0 SD=0, L 200 bytes CJK (240+ bytes): item 1 = L whole, a.k unpacked into L
      ctl-subdir   UA=1 SD=1, L 200 bytes: item 0 = L\a whole, a.k unpacked into L\a
    Every row also requires: the dialog closed, nothing fatal. The plug-in unpack mask
    (PostOpenUnpackDlgForThisPlugin) is not driven: no plug-in of the tree passes a mask.
    Typing is not driven. Driver of 299's probe (098's library). MUST run through
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
if (-not ('Cb315' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Cb315
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    public static long Send(IntPtr h, uint msg, long w)
    {
        IntPtr res;
        if (SendMessageTimeoutW(h, msg, (IntPtr)w, IntPtr.Zero, 0, 5000, out res) == IntPtr.Zero) return -9;
        return res.ToInt64();
    }
    // CB_GETCOUNT, CB_GETLBTEXTLEN, CB_GETLBTEXT
    public static List<string> Items(IntPtr combo)
    {
        var l = new List<string>();
        long n = Send(combo, 0x0146, 0);
        for (long i = 0; i < n; i++)
        {
            long len = Send(combo, 0x0149, i);
            if (len < 0) { l.Add("<CB_ERR>"); continue; }
            var buf = new char[len + 1];
            IntPtr res;
            SendBuf(combo, 0x0148, (IntPtr)i, buf, 0, 5000, out res);
            int got = (int)res.ToInt64(); if (got < 0) got = 0; if (got > len) got = (int)len;
            l.Add(new string(buf, 0, got));
        }
        return l;
    }
}
'@
}
$Root = $TempRoot + '\tc315_unp'
$StartDir = $Root + '\start'
$UnpKey = $RegKey + '\0.1\Packers & Unpackers\Custom Unpackers'

function Cjk([int]$n, [int]$base = 0x4E00) { return (-join (1..$n | ForEach-Object { [char]($base + $_) })) }
function U8([string]$s) { return $Utf8.GetByteCount($s) }
# $Prefix + components of letters ('p' or CJK) of at most 100 units each, exactly $Bytes bytes of UTF-8
function Long-Path([string]$Prefix, [int]$Bytes, [switch]$Cjk) {
    $p = $Prefix
    while ((U8 $p) -lt $Bytes) {
        $left = $Bytes - (U8 $p) - 1   # one separator
        if ($left -le 0) { $p += 'q'; continue }
        if ($Cjk) {
            $k = [Math]::Min(80, [Math]::Floor($left / 3))
            $comp = (Cjk $k 0x4E80) + ('x' * $(if ($k -lt 80) { $left - 3 * $k } else { 0 }))
        }
        else { $comp = 'p' * [Math]::Min(100, $left) }
        $p += '\' + $comp
    }
    return $p
}
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
function Dirs-Under([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetDirectories($LP + $Dir, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($LP.Length) } | Sort-Object)
}
function Short-Rel([string]$s) { if ($s.Length -gt 50) { return ('...(' + $s.Length + ' units) ' + (Tail $s 24)) } return (Esc $s) }
function Item-Desc([string]$s, [string]$L) {
    if ($s -eq '') { return "''" }
    $tag = ''
    if ($s -ceq $L) { $tag = 'L' }
    elseif ($s.StartsWith($L + '\')) { $tag = 'L\' + $s.Substring($L.Length + 1) }
    elseif ($L.StartsWith($s)) { $tag = 'CUT (prefix of L)' }
    return ("{0} units / {1} bytes [{2}] {3}" -f $s.Length, (U8 $s), $tag, (Tail $s 20))
}
function Start-Tc315([string]$Left, [string]$Right) {
    $a = @('-t', 'T315', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2000
    return $p.Id
}
# answers every window except $Keep: OK / Yes; until idle
function Serve315([int]$Id, $Keep = @(), [double]$Seconds = 60) {
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
            if ([Drv098f]::Txt($h) -eq 'Unpack') {   # the dialog opened again (DO_AGAIN): Cancel
                [void]$r.Messages.Add('the Unpack dialog again'); Close-Win $h; Start-Sleep -Milliseconds 500; continue
            }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) { continue }   # progress
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            [void]$r.Messages.Add($d)
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
    if ($s.Length -gt 200) { $s = $s.Substring(0, 200) + '...' }
    return $s.Trim()
}
function Shown($r) { $m = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || '); if ($m) { return $m } else { return 'nothing' } }
function Set-Unp([int]$UA, [int]$SD) {
    & reg.exe add $UnpKey /v 'Use Another Panel' /t REG_DWORD /d $UA /f | Out-Null
    & reg.exe add $UnpKey /v 'Use Subdir Name By Archive' /t REG_DWORD /d $SD /f | Out-Null
}

# one row. $Make: param($Tgt) -> @{ L = <right panel folder>; Zip = <archive name> }.
# $Pick: the combo item OK is pressed on. Refuse-to-offer rows: PASS = no entry naming a folder
# under tgt except L\<subfolder> when $AllowSub (and never L itself when $NoBareL), nothing new
# under tgt. -Fits rows: PASS = item $Pick is exactly $t.Want, files under tgt exactly $t.Expect.
# -Refuse rows ($t.Src = a long left panel folder, the archive in it): PASS = "too long" shown,
# no file but the archive and no new folder anywhere under the row.
function Unpack-Row([string]$Case, [int]$UA, [int]$SD, [int]$Pick, [scriptblock]$Make, [switch]$Fits, [switch]$NoBareL, [switch]$Refuse) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $tgt = $d + '\tgt'
    NewDir ($d + '\src'); NewDir $tgt
    $t = & $Make $tgt
    $L = $t.L
    $src = $(if ($t.Src) { $t.Src } else { $d + '\src' })
    if (-not $L.StartsWith($tgt + '\')) { throw "L is not inside the fixture: $L" }
    if (-not $src.StartsWith($d + '\src')) { throw "Src is not inside the fixture: $src" }
    NewDir $L; NewDir $src
    Zip-Make ($src + '\' + $t.Zip)
    $dirsBefore = @(Dirs-Under $tgt)
    $rowDirsBefore = @(Dirs-Under $d)
    Set-Unp $UA $SD
    $id = 0; $fatal = $null; $before = Reports
    try {
        $id = Start-Tc315 $src $L
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 851 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Unpack') { throw ("851 opened '{0}', not the Unpack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        $combo = Find-Ctl $dlg 210
        if ($combo -eq [IntPtr]::Zero) { throw 'the path combo box 210 was not found' }
        $items = @([Cb315]::Items($combo))
        $used = $(if ($items.Count -gt $Pick) { $Pick } else { 0 })
        [void][Cb315]::Send($combo, 0x014E, $used)   # CB_SETCURSEL
        Start-Sleep -Milliseconds 200
        $chosen = [Drv098f]::GetText($combo, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve315 $id @($dlg)
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        if ($stayed -and -not $fatal) { Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](Serve315 $id @() 15) }
        Start-Sleep -Milliseconds 500
        $files = @(Under $tgt)
        $newDirs = @(Dirs-Under $tgt | Where-Object { $dirsBefore -notcontains $_ })
        $srcFiles = @(Under $src | Where-Object { $_ -notlike ($t.Zip + '=*') })
        $rowFiles = @(Under $d | Where-Object { $_ -notlike ('*\' + $t.Zip + '=*') })
        $rowNewDirs = @(Dirs-Under $d | Where-Object { $rowDirsBefore -notcontains $_ })
        $bad = @($items | Where-Object {
                $s = $_
                $underTgt = $s.StartsWith($tgt + '\') -or ($tgt.StartsWith($s) -and $s.Length -gt 3)
                $isL = ($s -ceq $L)
                $isSub = $s.StartsWith($L + '\') -and $s.Substring($L.Length + 1).IndexOf('\') -lt 0
                ($underTgt -and -not $isL -and -not $isSub) -or ($NoBareL -and $isL) -or ($s -match [char]0xFFFD) -or ($s.IndexOf('?') -ge 0)
            })
        $why = ''
        if ($Fits) {
            $c1 = ($items.Count -gt $Pick) -and ($items[$Pick] -ceq $t.Want)
            $c2 = ((($files | Sort-Object) -join '|') -ceq ((@($t.Expect) | Sort-Object) -join '|'))
            $verdictOk = (-not $stayed) -and $c1 -and $c2 -and ($bad.Count -eq 0)
            if (-not $verdictOk) { $why = (" [item {0} whole: {1}; files as expected: {2} (expected {3}); bad items: {4}]" -f $Pick, $c1, $c2, ((@($t.Expect) | ForEach-Object { Short-Rel $_ }) -join ', '), $bad.Count) }
        }
        elseif ($Refuse) {
            $verdictOk = (-not $stayed) -and ((Shown $r) -match 'too long') -and ($rowFiles.Count -eq 0) -and ($rowNewDirs.Count -eq 0)
            $why = (" [source {0} bytes; files in the row: {1}; new folders in the row: {2}]" -f (U8 $src), $(if ($rowFiles.Count) { ($rowFiles | ForEach-Object { Short-Rel $_ }) -join ', ' } else { 'none' }), $rowNewDirs.Count)
        }
        else {
            $verdictOk = (-not $stayed) -and ($bad.Count -eq 0) -and ($files.Count -eq 0) -and ($newDirs.Count -eq 0)
            if ($t.SrcExpect) {   # where OK must have unpacked (next to the archive)
                $c3 = ((($srcFiles | Sort-Object) -join '|') -ceq ((@($t.SrcExpect) | Sort-Object) -join '|'))
                $verdictOk = $verdictOk -and $c3
                if (-not $c3) { $why = (" [expected next to the archive: {0}]" -f ((@($t.SrcExpect) | ForEach-Object { Short-Rel $_ }) -join ', ')) }
            }
        }
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and $verdictOk
        $itemText = (@($items | ForEach-Object { Item-Desc $_ $L }) -join ' ; ')
        Row $Case 'RUN' (V $ok) ("UA={0} SD={1}; L {2} units / {3} bytes; items ({4}): {5}; OK on item {6} ({7} bytes); dialog stayed: {8}; asked: {9}; new under tgt: {10}{11}; unpacked next to the archive: {12}{13}" -f $UA, $SD, $L.Length, (U8 $L), $items.Count, $itemText, $used, (U8 $chosen), $stayed, (Shown $r), $(if ($files.Count) { ($files | ForEach-Object { Short-Rel $_ }) -join ', ' } else { 'no file' }), $(if ($newDirs.Count) { '; ' + $newDirs.Count + ' new folder(s)' } else { '' }), $(if ($srcFiles.Count) { ($srcFiles | ForEach-Object { Short-Rel $_ }) -join ', ' } else { 'nothing' }), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }) + $why)
    }
    catch {
        Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace)
        if ($id -and (Test-Alive $id)) { foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc315_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("unpack315_probe (feature 315) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ("Fixture {0}" -f $Root)
    Out ''
    Unpack-Row 'other-ascii' 1 0 0 { param($T) @{ L = (Long-Path ($T + '\L') 297); Zip = 'a.zip'; SrcExpect = @('a.k=K', 'a.kp=KP') } }
    Unpack-Row 'other-cjk' 1 0 0 { param($T) @{ L = (Long-Path ($T + '\L') 355 -Cjk); Zip = 'a.zip'; SrcExpect = @('a.k=K', 'a.kp=KP') } }
    Unpack-Row 'alt-ascii' 0 0 1 { param($T) @{ L = (Long-Path ($T + '\L') 297); Zip = 'a.zip'; SrcExpect = @('a.k=K', 'a.kp=KP') } }
    Unpack-Row 'alt-cjk' 0 0 1 { param($T) @{ L = (Long-Path ($T + '\L') 355 -Cjk); Zip = 'a.zip'; SrcExpect = @('a.k=K', 'a.kp=KP') } }
    Unpack-Row 'subdir' 1 1 0 { param($T) @{ L = (Long-Path ($T + '\L') 245); Zip = ('s' * 20) + '.zip'; SrcExpect = @((('s' * 20) + '\a.k=K'), (('s' * 20) + '\a.kp=KP')) } } -NoBareL
    Unpack-Row 'src-long' 0 0 0 { param($T) @{ L = ($T + '\L'); Src = (Long-Path ((Split-Path $T) + '\src\S') 297); Zip = 'a.zip' } } -Refuse
    Unpack-Row 'longname-sd' 0 1 0 { param($T) @{ L = ($T + '\L'); Zip = ((Cjk 87 0x4E80) + '.zip') } } -Refuse
    Unpack-Row 'longname-sd-ua' 1 1 0 { param($T) @{ L = ($T + '\L'); Zip = ((Cjk 87 0x4E80) + '.zip') } } -Refuse
    Unpack-Row 'ctl' 1 0 0 { param($T) $l = Long-Path ($T + '\L') 200; @{ L = $l; Zip = 'a.zip'; Want = $l; Expect = @(($l.Substring($T.Length + 1) + '\a.k=K'), ($l.Substring($T.Length + 1) + '\a.kp=KP')) } } -Fits
    Unpack-Row 'ctl-alt' 0 0 1 { param($T) $l = Long-Path ($T + '\L') 250 -Cjk; @{ L = $l; Zip = 'a.zip'; Want = $l; Expect = @(($l.Substring($T.Length + 1) + '\a.k=K'), ($l.Substring($T.Length + 1) + '\a.kp=KP')) } } -Fits
    Unpack-Row 'ctl-subdir' 1 1 0 { param($T) $l = Long-Path ($T + '\L') 200; @{ L = $l; Zip = 'a.zip'; Want = ($l + '\a'); Expect = @(($l.Substring($T.Length + 1) + '\a\a.k=K'), ($l.Substring($T.Length + 1) + '\a\a.kp=KP')) } } -Fits
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
