<#
.SYNOPSIS
    Feature 316 probe: the Unpack dialog (Alt+F9, CM_UNPACK 851) unpacks into the folder its entry
    shows - a relative target that starts with a space (the archive's name as a subfolder for an
    archive named ' ssss.zip', or a typed ' typed') keeps the space; it was unpacked into 'ssss'
    (SalGetFullName strips leading spaces of a relative name).

.DESCRIPTION
    Fixture per row: <row>\src\<zip> (members a.k = 'K', a.kp = 'KP', made by .NET) and the right
    panel's folder L under <row>\tgt (created through \\?\). The program starts with the left panel
    on <row>\src (active) and the right panel on L (-r); Home, End focuses the archive (the last
    item), Alt+F9 (851) opens the dialog (the ZIP plug-in is the unpacker offered for .zip). The
    settings "Use the other panel for unpacking" (UA) and "Use the archive name as a subfolder" (SD)
    are written to Packers & Unpackers\Custom Unpackers before the start. The path combo box (210)
    items are read (CB_GETLBTEXT); the row picks item $Pick, or - $Type rows - puts a text into the
    entry with a wide WM_SETTEXT (not a keyboard), clicks OK and answers the boxes OK / Yes.
    PASS = the dialog closed, nothing fatal, the files and folders under src (but the archive) and
    under tgt are exactly the expected ones:
      space-sd        UA=0 SD=1, archive ' ssss.zip', a folder 'ssss' (keep.k = 'OLD') already next
                      to it; item 0 (' ssss'). Expected: ' ssss\a.k', ' ssss\a.kp'; 'ssss' untouched
      space-sd-long   UA=1 SD=1, L 245 bytes, archive ' ' + 19 letters + '.zip': L\<name> does not fit,
                      the name alone is offered (feature 315); item 0. Expected under src\<name>
      space2-sd       UA=0 SD=1, archive '  ss.zip' (two spaces); item 0. Expected under '  ss'
      typed-space     UA=0 SD=0, the entry set to ' typed'. Expected under ' typed'
      ctl-abs-space   UA=1 SD=1, L short: item 0 = L\ ssss (absolute) - files in L\ ssss (control:
                      worked before)
      ctl-typed       UA=0 SD=0, the entry 'typed': files in 'typed' (control)
      ctl-blank       UA=0 SD=0, the entry '   ' (spaces only): an empty target - next to the
                      archive (control: unchanged)
    Driver of 315's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
    Registry exported, restored and verified. Exit code = FAIL rows.
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
if (-not ('Cb316' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Cb316
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
$Root = $TempRoot + '\tc316_unp'
$StartDir = $Root + '\start'
$UnpKey = $RegKey + '\0.1\Packers & Unpackers\Custom Unpackers'

function U8([string]$s) { return $Utf8.GetByteCount($s) }
# $Prefix + components of 'p' of at most 100 units each, exactly $Bytes bytes
function Long-Path([string]$Prefix, [int]$Bytes) {
    $p = $Prefix
    while ((U8 $p) -lt $Bytes) {
        $left = $Bytes - (U8 $p) - 1
        if ($left -le 0) { $p += 'q'; continue }
        $p += '\' + ('p' * [Math]::Min(100, $left))
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
# every file under $Dir, relative, with its content; names shown with their spaces as <sp>
function Under([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetFiles($LP + $Dir, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object {
            $_.Substring(($LP + $Dir).Length + 1) + '=' + [IO.File]::ReadAllText($_)
        } | Sort-Object)
}
function Dirs-Under([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetDirectories($LP + $Dir, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring(($LP + $Dir).Length + 1) } | Sort-Object)
}
function Vis([string]$s) { if ($s.Length -gt 60) { $s = '...(' + $s.Length + ') ' + $s.Substring($s.Length - 30) }; return ("'" + ($s -replace ' ', '<sp>') + "'") }
function Join-Vis($a) { if (@($a).Count) { return ((@($a) | ForEach-Object { Vis $_ }) -join ', ') } return 'none' }
function Start-Tc316([string]$Left, [string]$Right) {
    $a = @('-t', 'T316', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
# answers every window except $Keep: OK / Yes; the Unpack dialog shown again is cancelled; until idle
function Serve316([int]$Id, $Keep = @(), [double]$Seconds = 60) {
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
            if ([Drv098f]::Txt($h) -eq 'Unpack') {
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

# one row. $Make: param($Tgt) -> @{ L = <right panel folder>; Zip = <archive name>;
#   Pre = @{ <rel file under src> = <content> } (made before); SrcFiles / SrcDirs / TgtFiles = the
#   expected relative files ('<rel>=<content>', the archive left out) and folders after OK }.
# $Pick: the combo item OK is pressed on; $Type (not $null): the text put into the entry instead.
function Unpack-Row([string]$Case, [int]$UA, [int]$SD, [int]$Pick, $Type, [scriptblock]$Make) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $tgt = $d + '\tgt'
    $src = $d + '\src'
    NewDir $src; NewDir $tgt
    $t = & $Make $tgt
    $L = $t.L
    if (-not $L.StartsWith($tgt + '\')) { throw "L is not inside the fixture: $L" }
    NewDir $L
    if ($t.Pre) { foreach ($k in $t.Pre.Keys) { NewDir (Split-Path ($src + '\' + $k)); WriteFile ($src + '\' + $k) $t.Pre[$k] } }
    Zip-Make ($src + '\' + $t.Zip)
    Set-Unp $UA $SD
    $id = 0; $fatal = $null; $before = Reports
    try {
        $id = Start-Tc316 $src $L
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 851 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Unpack') { throw ("851 opened '{0}', not the Unpack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        $title = (@([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Static' } | ForEach-Object { [Drv098f]::Txt($_) } | Where-Object { $_ -match 'Unpack' }) -join ' ')
        $combo = Find-Ctl $dlg 210
        if ($combo -eq [IntPtr]::Zero) { throw 'the path combo box 210 was not found' }
        $items = @([Cb316]::Items($combo))
        if ($null -ne $Type) {
            if (-not [Drv098f]::SetText($combo, $Type, 5000)) { throw 'WM_SETTEXT into the entry failed' }
        }
        else {
            if ($items.Count -le $Pick) { throw ("no combo item {0} (items: {1})" -f $Pick, (Join-Vis $items)) }
            [void][Cb316]::Send($combo, 0x014E, $Pick)   # CB_SETCURSEL
        }
        Start-Sleep -Milliseconds 200
        $chosen = [Drv098f]::GetText($combo, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve316 $id @($dlg)
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        if ($stayed -and -not $fatal) { Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](Serve316 $id @() 15) }
        Start-Sleep -Milliseconds 500
        $srcFiles = @(Under $src | Where-Object { $_ -notlike ($t.Zip + '=*') })
        $srcDirs = @(Dirs-Under $src)
        $tgtFiles = @(Under $tgt)
        $c1 = ((@($srcFiles) -join '|') -ceq ((@($t.SrcFiles) | Sort-Object) -join '|'))
        $c2 = ((@($srcDirs) -join '|') -ceq ((@($t.SrcDirs) | Sort-Object) -join '|'))
        $c3 = ((@($tgtFiles) -join '|') -ceq ((@($t.TgtFiles) | Sort-Object) -join '|'))
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and (-not $stayed) -and $c1 -and $c2 -and $c3
        $why = ''
        if (-not $ok) { $why = (" [expected src files {0}; src folders {1}; tgt files {2}]" -f (Join-Vis $t.SrcFiles), (Join-Vis $t.SrcDirs), (Join-Vis $t.TgtFiles)) }
        Row $Case 'RUN' (V $ok) ("UA={0} SD={1}; archive {2}; items: {3}; OK on {4}; dialog stayed: {5}; asked: {6}; src files: {7}; src folders: {8}; tgt files: {9}{10}{11}" -f $UA, $SD, (Vis $t.Zip), (Join-Vis $items), (Vis $chosen), $stayed, (Shown $r), (Join-Vis $srcFiles), (Join-Vis $srcDirs), (Join-Vis $tgtFiles), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $why)
    }
    catch {
        Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace)
        if ($id -and (Test-Alive $id)) { foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc316_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("unpack316_probe (feature 316) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ("Fixture {0}" -f $Root)
    Out ''
    $n19 = ' ' + ('s' * 19)
    Unpack-Row 'space-sd' 0 1 0 $null { param($T) @{ L = ($T + '\L'); Zip = ' ssss.zip'; Pre = @{ 'ssss\keep.k' = 'OLD' }
            SrcFiles = @(' ssss\a.k=K', ' ssss\a.kp=KP', 'ssss\keep.k=OLD'); SrcDirs = @(' ssss', 'ssss') } }
    Unpack-Row 'space-sd-long' 1 1 0 $null { param($T) @{ L = (Long-Path ($T + '\L') 245); Zip = ($n19 + '.zip')
            SrcFiles = @(($n19 + '\a.k=K'), ($n19 + '\a.kp=KP')); SrcDirs = @($n19) } }
    Unpack-Row 'space2-sd' 0 1 0 $null { param($T) @{ L = ($T + '\L'); Zip = '  ss.zip'
            SrcFiles = @('  ss\a.k=K', '  ss\a.kp=KP'); SrcDirs = @('  ss') } }
    Unpack-Row 'typed-space' 0 0 0 ' typed' { param($T) @{ L = ($T + '\L'); Zip = 'a.zip'
            SrcFiles = @(' typed\a.k=K', ' typed\a.kp=KP'); SrcDirs = @(' typed') } }
    Unpack-Row 'ctl-abs-space' 1 1 0 $null { param($T) @{ L = ($T + '\L'); Zip = ' ssss.zip'
            TgtFiles = @('L\ ssss\a.k=K', 'L\ ssss\a.kp=KP') } }
    Unpack-Row 'ctl-typed' 0 0 0 'typed' { param($T) @{ L = ($T + '\L'); Zip = 'a.zip'
            SrcFiles = @('typed\a.k=K', 'typed\a.kp=KP'); SrcDirs = @('typed') } }
    Unpack-Row 'ctl-blank' 0 0 0 '   ' { param($T) @{ L = ($T + '\L'); Zip = 'a.zip'
            SrcFiles = @('a.k=K', 'a.kp=KP') } }
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
