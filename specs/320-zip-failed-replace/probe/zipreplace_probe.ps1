<#
.SYNOPSIS
    Feature 320 probe: the ZIP plug-in changes an existing archive through a temporary working file
    'Sal*.tmp' next to it (the default "create temporary backup of zip"). When the temporary file
    cannot take the archive's place, the plug-in says "Cannot replace original archive with temporary
    working file. Archive was not changed." Before 320 it deleted the archive and renamed the
    temporary file over it: a failed delete left the 'Sal*.tmp' behind; a delete that succeeded
    followed by a failed rename left the archive gone (the 319 stream case). After 320: the archive
    byte-for-byte as before, the temporary file removed, the message as before.

.DESCRIPTION
    Fixture per row: <row>\src (the left panel, active) holding 'plain' (f.txt) and 'a.zip' (seed.txt,
    keep.txt; written by the probe). A 'locked' row holds 'a.zip' open in the probe's own process
    (GENERIC_READ, sharing read + write, NOT delete - as an indexer, a viewer or another archiver
    would) for the whole row; the plug-in still opens it (it shares read) but no rename can replace
    it. Rows:
      add-locked  Pack (Alt+F5, 850) 'plain' into 'a.zip' (typed with WM_SETTEXT), "add?" Yes, the
                  ZIP "Add Files to Archive" box OK -> the ZIP message; nothing new, nothing changed
      add-ctl     the same, not locked -> 'a.zip' changed (seed.txt, keep.txt, plain/f.txt), nothing new
      del-locked  the left panel changed into 'a.zip' (862), Select (841) 'seed.txt', Delete (729),
                  Yes -> the ZIP message;
                  nothing new, nothing changed
      del-ctl     the same, not locked -> 'a.zip' changed (keep.txt only), nothing new
    The snapshot lists every file and folder AND every alternate data stream (FindFirstStreamW
    through \\?\, contents hashed through CreateFileW) - a stray 'Sal*.tmp' is a new file.
    Driver of 319's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
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
if (-not ('Cb320' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class Cb320
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct WIN32_FIND_STREAM_DATA { public long StreamSize; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 296)] public string cStreamName; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr FindFirstStreamW(string name, int level, out WIN32_FIND_STREAM_DATA data, int flags);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool FindNextStreamW(IntPtr h, out WIN32_FIND_STREAM_DATA data);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool FindClose(IntPtr h);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);
    // the alternate data streams of 'path' (a \\?\ path), as ':name' without ':$DATA'; the main stream left out
    public static List<string> Streams(string path)
    {
        var l = new List<string>();
        WIN32_FIND_STREAM_DATA d;
        IntPtr h = FindFirstStreamW(path, 0, out d, 0);
        if (h == new IntPtr(-1)) return l;
        try
        {
            do
            {
                string n = d.cStreamName;
                if (n.EndsWith(":$DATA")) n = n.Substring(0, n.Length - 6);
                if (n != ":") l.Add(n);
            } while (FindNextStreamW(h, out d));
        }
        finally { FindClose(h); }
        return l;
    }
    public static byte[] ReadAll(string path)
    {
        using (var h = CreateFileW(path, 0x80000000, 7, IntPtr.Zero, 3, 0, IntPtr.Zero))
        {
            if (h.IsInvalid) throw new IOException("CreateFileW(read) failed: " + Marshal.GetLastWin32Error() + " " + path);
            using (var fs = new FileStream(h, FileAccess.Read)) { var ms = new MemoryStream(); fs.CopyTo(ms); return ms.ToArray(); }
        }
    }
    public static void WriteAll(string path, byte[] bytes)
    {
        using (var h = CreateFileW(path, 0x40000000, 0, IntPtr.Zero, 1, 0, IntPtr.Zero))
        {
            if (h.IsInvalid) throw new IOException("CreateFileW(create new) failed: " + Marshal.GetLastWin32Error() + " " + path);
            using (var fs = new FileStream(h, FileAccess.Write)) { fs.Write(bytes, 0, bytes.Length); }
        }
    }
    // opened for reading, shared for reading and writing but not for deleting (no rename over it)
    public static SafeFileHandle Hold(string path, uint share)
    {
        var h = CreateFileW(path, 0x80000000, share, IntPtr.Zero, 3, 0, IntPtr.Zero);
        if (h.IsInvalid) throw new IOException("CreateFileW(hold) failed: " + Marshal.GetLastWin32Error() + " " + path);
        return h;
    }
}
'@
}
$Root = $TempRoot + '\tc320_zipreplace'
$StartDir = $Root + '\start'
$CnfKey = $RegKey + '\0.1\Configuration\Confirmation'
$PackKey = $RegKey + '\0.1\Packers & Unpackers\Custom Packers'

function Vis([string]$s) { if ($s.Length -gt 60) { $s = '...(' + $s.Length + ') ' + $s.Substring($s.Length - 30) }; $s = $s -replace ' ', '<sp>'; return ("'" + $s + "'") }
function Join-Vis($a) { if (@($a).Count) { return ((@($a) | ForEach-Object { Vis $_ }) -join ', ') } return 'none' }
function Sha([byte[]]$b) { $sha = [Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($sha.ComputeHash($b)) } finally { $sha.Dispose() } }
# every file under $Dir and every alternate data stream of a file or folder under it -> SHA-256
function Snap([string]$Dir) {
    $h = @{}
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return $h }
    $base = ($LP + $Dir).Length + 1
    foreach ($f in [IO.Directory]::GetFiles($LP + $Dir, '*', [IO.SearchOption]::AllDirectories)) {
        $h[$f.Substring($base)] = Sha ([Cb320]::ReadAll($f))
        foreach ($s in [Cb320]::Streams($f)) { $h[$f.Substring($base) + $s] = Sha ([Cb320]::ReadAll($f + $s)) }
    }
    foreach ($f in [IO.Directory]::GetDirectories($LP + $Dir, '*', [IO.SearchOption]::AllDirectories)) {
        foreach ($s in [Cb320]::Streams($f)) { $h[$f.Substring($base) + $s] = Sha ([Cb320]::ReadAll($f + $s)) }
    }
    return $h
}
function Zip-Entries([string]$Zip) {
    try {
        $ms = New-Object IO.MemoryStream(, [Cb320]::ReadAll($LP + $Zip))
        $z = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Read)
        try { return @($z.Entries | ForEach-Object { $_.FullName } | Sort-Object) } finally { $z.Dispose() }
    }
    catch { return @('<not a readable zip: ' + $_.Exception.Message + '>') }
}
# an archive holding seed.txt and keep.txt, written through CreateFileW
function Zip-Seed([string]$Zip) {
    $ms = New-Object IO.MemoryStream
    $z = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($n in @('seed.txt', 'keep.txt')) { $w = New-Object IO.StreamWriter($z.CreateEntry($n).Open()); $w.Write($n); $w.Dispose() }
    }
    finally { $z.Dispose() }
    [Cb320]::WriteAll($LP + $Zip, $ms.ToArray())
}
function Start-TcZr([string]$Left, [string]$Right) {
    $a = @('-t', 'T320', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
# answers every window except $Keep: any box Yes / OK; the Pack dialog shown again is cancelled; until idle
function ServeZr([int]$Id, $Keep = @(), [double]$Seconds = 60) {
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
            if ([Drv098f]::Txt($h) -eq 'Pack' -and (Find-Ctl $h 210) -ne [IntPtr]::Zero) {
                [void]$r.Messages.Add('the Pack dialog again'); Close-Win $h; Start-Sleep -Milliseconds 500; continue
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
    if ($s.Length -gt 220) { $s = $s.Substring(0, 220) + '...' }
    return $s.Trim()
}
function Shown($r) { $m = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || '); if ($m) { return $m } else { return 'nothing' } }

$ReplaceRx = 'Cannot replace original archive'
# one row. $Op: 'add' (Pack 'plain' into a.zip) or 'del' (F8 on seed.txt inside a.zip).
# $Share: 0 = not held; else the archive is held open (read) with this sharing for the whole row
#   (3 = read + write, no delete: nothing can replace it; 7 = + delete).
# $WantEntries: the entries the archive must hold afterwards when it changed; $null: unchanged + the
#   replace message; 'unchanged': nothing new and nothing changed, a message or not.
# $Arc: the archive (rel to src); $PlainFile: a plain file (rel to src) made first (a stream's host).
function Zr-Row([string]$Case, [string]$Op, [int]$Share, $WantEntries, [string]$Arc = 'a.zip', [string]$PlainFile = '') {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = $d + '\src'
    $R = $d + '\tgt\R'
    NewDir ($src + '\plain'); NewDir $R
    WriteFile ($src + '\plain\f.txt') 'F'
    if ($PlainFile) { WriteFile ($src + '\' + $PlainFile) 'P' }
    Zip-Seed ($src + '\' + $Arc)
    & reg.exe add $PackKey /v 'Use Another Panel' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add $CnfKey /v 'Add To Archive' /t REG_DWORD /d 1 /f | Out-Null
    $snap0 = Snap $d
    $hold = $null
    $id = 0; $fatal = $null; $before = Reports
    try {
        if ($Share) { $hold = [Cb320]::Hold($LP + $src + '\' + $Arc, [uint32]$Share) }
        if ($Op -eq 'add') {
            $id = Start-TcZr $src $R
            Key $id 0x24; Key $id 0x28        # Home, Down: 'plain' (after '..'; folders first)
            Start-Sleep -Milliseconds 500
            $dlg = Open-ByCmd $id 850 15
            if ($dlg -eq [IntPtr]::Zero) { throw 'Pack (850) opened no window' }
            if ([Drv098f]::Txt($dlg) -ne 'Pack') { throw ("850 opened '{0}', not the Pack dialog" -f [Drv098f]::Txt($dlg)) }
            Start-Sleep -Milliseconds 400
            $combo = Find-Ctl $dlg 210
            if ($combo -eq [IntPtr]::Zero) { throw 'the archive-name combo box 210 was not found' }
            if (-not [Drv098f]::SetText($combo, $Arc, 5000)) { throw 'WM_SETTEXT into the entry failed' }
            Start-Sleep -Milliseconds 200
            Click-Ok $dlg
            Start-Sleep -Milliseconds 800
            $r = ServeZr $id @($dlg) 60
            $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
            if ($stayed) { Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](ServeZr $id @() 15) }
        }
        else {
            $id = Start-TcZr $src $R
            [void](Do-ChangeDir $id ($src + '\' + $Arc)); [void](ServeZr $id @() 30)
            $loc = Get-Loc $id
            $sel = Open-ByCmd $id 841 10      # Select
            if ($sel -eq [IntPtr]::Zero) { throw 'Select (841) opened no window' }
            [void][Drv098f]::SetText((Find-Ctl $sel 101), 'seed.txt', 5000); Click-Ok $sel
            Start-Sleep -Milliseconds 800
            Post-Cmd (Get-Main $id) 729       # Delete (F8) - "delete?" answered Yes by ServeZr
            Start-Sleep -Milliseconds 800
            $r = ServeZr $id @() 60
            $stayed = $false
        }
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        if ($hold) { $hold.Dispose(); $hold = $null }
        Start-Sleep -Milliseconds 500
        $snap1 = Snap $d
        $new = @($snap1.Keys | Where-Object { -not $snap0.ContainsKey($_) } | Sort-Object)
        $changed = @($snap0.Keys | Where-Object { -not $snap1.ContainsKey($_) -or $snap1[$_] -ne $snap0[$_] } | Sort-Object)
        $entries = @(); if ($snap1.ContainsKey('src\' + $Arc)) { $entries = @(Zip-Entries ($src + '\' + $Arc)) }
        $asked = (@($r.Messages | Where-Object { $_ -match $ReplaceRx }).Count -gt 0)
        if ('unchanged' -ceq $WantEntries) {
            $ok = ($new.Count -eq 0) -and ($changed.Count -eq 0)
            $want = 'nothing new, nothing changed'
        }
        elseif ($null -eq $WantEntries) {
            $ok = ($new.Count -eq 0) -and ($changed.Count -eq 0) -and $asked
            $want = 'nothing new, nothing changed, the replace message'
        }
        else {
            $ok = ($new.Count -eq 0) -and ((@($changed) -join '|') -ceq ('src\' + $Arc)) -and ((@($entries) -join '|') -ceq (@($WantEntries) -join '|')) -and -not $asked
            $want = ('nothing new, {1} changed holding {0}, no replace message' -f (Join-Vis $WantEntries), $Arc)
        }
        $ok = $ok -and (-not $fatal) -and (-not $r.TimedOut) -and (-not $stayed)
        $why = ''; if (-not $ok) { $why = " [expected: $want]" }
        $at = ''; if ($Op -eq 'del') { $at = ('panel at {0}; ' -f (Vis ([string]$loc))) }
        Row $Case 'RUN' (V $ok) ("{0}held with sharing: {1}; shown: {2}; new: {3}; changed: {4}; entries: {5}{6}{7}" -f $at, $Share, (Shown $r), (Join-Vis $new), (Join-Vis $changed), (Join-Vis $entries), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $why)
    }
    catch {
        Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace)
        if ($id -and (Test-Alive $id)) { foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally {
        if ($hold) { $hold.Dispose() }
        if ($id) { End-Row $Case $id $fatal $before }
    }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc320_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("zipreplace_probe (feature 320) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; OS {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, [Environment]::OSVersion.VersionString)
    Out ("Fixture {0}" -f $Root)
    Out ''
    Zr-Row 'add-locked' 'add' 3 $null
    Zr-Row 'add-ctl' 'add' 0 @('keep.txt', 'plain/', 'plain/f.txt', 'seed.txt')
    Zr-Row 'add-sharedel' 'add' 7 @('keep.txt', 'plain/', 'plain/f.txt', 'seed.txt')
    Zr-Row 'del-locked' 'del' 3 $null
    Zr-Row 'del-ctl' 'del' 0 @('keep.txt')
    Zr-Row 'del-sharedel' 'del' 7 @('keep.txt')
    # an archive inside a stream ('report:zip.zip') is not reachable: Change Directory refuses the path
    # (error 123), Pack refuses the name (319) - measured at 4252bcb6; covered by saltests (320)
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
