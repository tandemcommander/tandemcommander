<#
.SYNOPSIS
    Feature 319 probe: the Pack dialog (Alt+F5, CM_PACK 850) refuses an archive name whose last part
    holds a ':' ('report:zip', 'rep:x.zip') with "The path specified is invalid." and the dialog
    again. Before 319 the ZIP plug-in created an empty file 'report' / 'rep' and wrote the archive
    into its NTFS alternate data stream ('report:zip.zip'), invisible to Explorer and the panel.

.DESCRIPTION
    Fixture per row: <row>\src (the left panel, active) holding the folder 'plain' (f.txt), and
    <row>\tgt\L (the right panel). "Use the other panel for packing" is off (Packers & Unpackers\Custom
    Packers, 'Use Another Panel' = 0, the default) and the "add to an existing archive" question is on
    (Confirmation\Add To Archive = 1, the default); both written before the start. Home, Down focuses
    'plain'; Alt+F5 (850) opens the Pack dialog; the row picks item 0 or puts a text into the
    archive-name entry (combo box 210) with a wide WM_SETTEXT (not a keyboard), clicks OK and answers
    every box Yes / OK; the Pack dialog shown again is cancelled.
    The snapshot of a row lists every file and folder AND every alternate data stream of them
    (FindFirstStreamW through \\?\; a stream is 'name:stream', its content hashed through CreateFileW).
    PASS = nothing fatal, the dialog closed, the new files / streams under the row exactly the
    expected ones, nothing changed, the archive inspected holds the expected entry, a refusal row
    showed the expected message.
      Refused (nothing created, nothing changed):
      colon-ext        'report:zip'        (the dialog adds '.zip': 'report:zip.zip')
      colon-mid        'rep:x.zip'
      colon-exist      'report:zip' next to an existing plain file 'report': 'report' unchanged,
                       no stream added to it
      colon-stream     'report:zip.zip' where 'report' already holds a stream 'zip.zip' with an
                       archive: refused too (a ':' is never a file name), the stream unchanged
      colon-abs        '<src>\abs:x.zip'   (an absolute name - the same rule)
      colon-slash      'plain/rep:x.zip'   (a '/' separates like '\')
      colon-dir        'sub:x\a.zip'       (a ':' in a folder part - measured, not this rule's: the
                       ZIP plug-in refuses it, nothing created)
      Rows of the review of 319 (run first; refused unless named a control):
      colon-trail-bs   'report:zip\'       (the full name loses the trailing '\')
      colon-utf8       'zpr<a acute>va:zip' (a non-ASCII name)
      ctl-fullwidth    'report<U+FF1A>zip' (the full-width colon is a name character: packed as
                       'report<U+FF1A>zip.zip')
      other-colon-abs  '<tgt>\abs:x.zip'   with "Use the other panel for packing" on
      other-colon-rel  'rep:x.zip'         the same
      colon-space      ' :zip'
      colon-data       'report.zip::$DATA' (before 319: an empty 'report.zip')
      colon-dot        'report.:zip'
      colon-drive-rel  '<drive>:rep:x.zip' (drive-relative with a ':' in the name)
      Packed (controls):
      ctl-plain        item 0: 'plain.zip'
      ctl-drive-abs    '<src>\abs.zip'     (the drive's ':' at the second character)
      ctl-drive-rel    '<drive>:rel.zip'   (a drive-relative name of the panel's drive -> src\rel.zip)
      trail-dot        'report.'           (feature 318 - stays refused)
      ctl-empty        '' : "Empty name has no sense here." (unchanged)
    Not driven: typing with a keyboard (WM_SETTEXT), external archivers.
    Driver of 318's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
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
if (-not ('Cb319' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class Cb319
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
$Root = $TempRoot + '\tc319_pack'
$StartDir = $Root + '\start'
$PackKey = $RegKey + '\0.1\Packers & Unpackers\Custom Packers'
$CnfKey = $RegKey + '\0.1\Configuration\Confirmation'

function Vis([string]$s) { if ($s.Length -gt 60) { $s = '...(' + $s.Length + ') ' + $s.Substring($s.Length - 30) }; $s = $s -replace ' ', '<sp>'; return ("'" + $s + "'") }
function Join-Vis($a) { if (@($a).Count) { return ((@($a) | ForEach-Object { Vis $_ }) -join ', ') } return 'none' }
function Sha([byte[]]$b) { $sha = [Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($sha.ComputeHash($b)) } finally { $sha.Dispose() } }
# every file under $Dir and every alternate data stream of a file or folder under it:
# relative name ('src\report', 'src\report:zip.zip', a folder's stream 'src\d:s') -> SHA-256
function Snap([string]$Dir) {
    $h = @{}
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return $h }
    $base = ($LP + $Dir).Length + 1
    foreach ($f in [IO.Directory]::GetFiles($LP + $Dir, '*', [IO.SearchOption]::AllDirectories)) {
        $h[$f.Substring($base)] = Sha ([Cb319]::ReadAll($f))
        foreach ($s in [Cb319]::Streams($f)) { $h[$f.Substring($base) + $s] = Sha ([Cb319]::ReadAll($f + $s)) }
    }
    foreach ($f in [IO.Directory]::GetDirectories($LP + $Dir, '*', [IO.SearchOption]::AllDirectories)) {
        foreach ($s in [Cb319]::Streams($f)) { $h[$f.Substring($base) + $s] = Sha ([Cb319]::ReadAll($f + $s)) }
    }
    return $h
}
function Zip-Entries([string]$Zip) {
    try {
        $ms = New-Object IO.MemoryStream(, [Cb319]::ReadAll($LP + $Zip))
        $z = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Read)
        try { return @($z.Entries | ForEach-Object { $_.FullName }) } finally { $z.Dispose() }
    }
    catch { return @('<not a readable zip: ' + $_.Exception.Message + '>') }
}
function Start-TcPk([string]$Left, [string]$Right) {
    $a = @('-t', 'T319', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
function ServePk([int]$Id, $Keep = @(), [double]$Seconds = 60) {
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
            if ([Drv098f]::Txt($h) -eq 'Pack' -and (Find-Ctl $h 210) -ne [IntPtr]::Zero) {   # the dialog, not a message box titled Pack
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
    if ($s.Length -gt 200) { $s = $s.Substring(0, 200) + '...' }
    return $s.Trim()
}
function Shown($r) { $m = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || '); if ($m) { return $m } else { return 'nothing' } }

# an archive holding seed.txt, written through CreateFileW (also into a stream 'file:stream')
function Zip-Seed([string]$Zip) {
    $ms = New-Object IO.MemoryStream
    $z = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Create, $true)
    try { $w = New-Object IO.StreamWriter($z.CreateEntry('seed.txt').Open()); $w.Write('S'); $w.Dispose() } finally { $z.Dispose() }
    [Cb319]::WriteAll($LP + $Zip, $ms.ToArray())
}

# one row. $Type: $null = item 0, else the text put into the entry ('<src>' is replaced by the src path).
# $Arc: the archive expected (rel to src) - $null = a refusal: nothing created, $AskRx shown.
# $Seed: an archive (rel to src, made through \\?\ with seed.txt) that exists before - when it is $Arc,
#   the row expects it changed (Add) and holding seed.txt too, not new. $PlainFile: a file (rel to src)
#   that exists before and must stay unchanged.
function Pack-Row([string]$Case, $Type, $Arc, [string]$AskRx, [string]$Seed = '', [string]$PlainFile = '', [int]$Another = 0) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = $d + '\src'
    $L = $d + '\tgt\L'
    NewDir ($src + '\plain'); NewDir $L
    WriteFile ($src + '\plain\f.txt') 'F'
    if ($PlainFile) { WriteFile ($src + '\' + $PlainFile) 'P' }
    if ($Seed) { Zip-Seed ($src + '\' + $Seed) }
    if ($null -ne $Type) {
        $Type = $Type.Replace('<src>', $src).Replace('<tgt>', $L).Replace('<drive>', $src.Substring(0, 1))
        # a rooted name must lie inside the fixture; a relative or drive-relative one resolves in src
        if (($Type -match '^[A-Za-z]:[\\/]' -or $Type.StartsWith('\') -or $Type.StartsWith('/')) -and -not $Type.StartsWith($d + '\')) { throw "typed path is not inside the fixture: $Type" }
    }
    & reg.exe add $PackKey /v 'Use Another Panel' /t REG_DWORD /d $Another /f | Out-Null
    & reg.exe add $CnfKey /v 'Add To Archive' /t REG_DWORD /d 1 /f | Out-Null
    $snap0 = Snap $d
    $id = 0; $fatal = $null; $before = Reports
    try {
        $id = Start-TcPk $src $L
        Key $id 0x24; Key $id 0x28
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 850 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Pack (850) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Pack') { throw ("850 opened '{0}', not the Pack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        $combo = Find-Ctl $dlg 210
        if ($combo -eq [IntPtr]::Zero) { throw 'the archive-name combo box 210 was not found' }
        $items = @([Cb319]::Items($combo))
        if ($null -ne $Type) {
            if (-not [Drv098f]::SetText($combo, $Type, 5000)) { throw 'WM_SETTEXT into the entry failed' }
        }
        else {
            if ($items.Count -lt 1) { throw 'the combo box holds no item' }
            [void][Cb319]::Send($combo, 0x014E, 0)   # CB_SETCURSEL
        }
        Start-Sleep -Milliseconds 200
        $chosen = [Drv098f]::GetText($combo, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = ServePk $id @($dlg) 60
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        if ($stayed -and -not $fatal) { Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](ServePk $id @() 15) }
        Start-Sleep -Milliseconds 500
        $snap1 = Snap $d
        $new = @($snap1.Keys | Where-Object { -not $snap0.ContainsKey($_) } | Sort-Object)
        $changed = @($snap0.Keys | Where-Object { -not $snap1.ContainsKey($_) -or $snap1[$_] -ne $snap0[$_] } | Sort-Object)
        $seeded = $Arc -and ($Seed -ceq $Arc)
        $wantNew = @(); if ($Arc -and -not $seeded) { $wantNew = @('src\' + $Arc) }
        $wantChg = @(); if ($seeded) { $wantChg = @('src\' + $Arc) }
        $c1 = ((@($new) -join '|') -ceq (@($wantNew) -join '|'))
        $c2 = ((@($changed) -join '|') -ceq (@($wantChg) -join '|'))
        $entries = @(); if ($Arc -and $snap1.ContainsKey('src\' + $Arc)) { $entries = @(Zip-Entries ($src + '\' + $Arc)) }
        $c3 = (-not $Arc) -or (@($entries | Where-Object { $_.EndsWith('f.txt') }).Count -gt 0)
        if ($seeded -and -not @($entries | Where-Object { $_ -eq 'seed.txt' }).Count) { $c3 = $false }
        $c4 = (-not $AskRx) -or (@($r.Messages | Where-Object { $_ -match $AskRx }).Count -gt 0)
        $plain = @()
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and (-not $stayed) -and $c1 -and $c2 -and $c3 -and $c4
        $why = ''
        if (-not $ok) { $why = (" [expected new {0}; changed {1}; message '{2}']" -f (Join-Vis $wantNew), (Join-Vis $wantChg), $AskRx) }
        Row $Case 'RUN' (V $ok) ("OK on {0}; dialog stayed: {1}; asked: {2}; new: {3}; changed: {4}; entries: {5}; {6}{7}{8}" -f (Vis $chosen), $stayed, (Shown $r), (Join-Vis $new), (Join-Vis $changed), (Join-Vis $entries), ($plain -join '; '), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $why)
    }
    catch {
        Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace)
        if ($id -and (Test-Alive $id)) { foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc319_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("pack319_probe (feature 319) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; OS {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, [Environment]::OSVersion.VersionString)
    Out ("Fixture {0}" -f $Root)
    Out ''
    $inv = 'path specified is invalid'
    Pack-Row 'colon-trail-bs' 'report:zip\' $null $inv
    Pack-Row 'colon-utf8' ('zpr' + [char]0xE1 + 'va:zip') $null $inv
    Pack-Row 'ctl-fullwidth' ('report' + [char]0xFF1A + 'zip') ('report' + [char]0xFF1A + 'zip.zip') $null
    Pack-Row 'other-colon-abs' '<tgt>\abs:x.zip' $null $inv -Another 1
    Pack-Row 'other-colon-rel' 'rep:x.zip' $null $inv -Another 1
    Pack-Row 'colon-space' ' :zip' $null $inv
    Pack-Row 'colon-data' 'report.zip::$DATA' $null $inv
    Pack-Row 'colon-dot' 'report.:zip' $null $inv
    Pack-Row 'colon-drive-rel' '<drive>:rep:x.zip' $null $inv
    Pack-Row 'colon-ext' 'report:zip' $null $inv
    Pack-Row 'colon-mid' 'rep:x.zip' $null $inv
    Pack-Row 'colon-exist' 'report:zip' $null $inv -PlainFile 'report'
    Pack-Row 'colon-stream' 'report:zip.zip' $null $inv -PlainFile 'report' -Seed 'report:zip.zip'
    Pack-Row 'colon-abs' '<src>\abs:x.zip' $null $inv
    Pack-Row 'colon-slash' 'plain/rep:x.zip' $null $inv
    Pack-Row 'colon-dir' 'sub:x\a.zip' $null $null
    Pack-Row 'ctl-plain' $null 'plain.zip' $null
    Pack-Row 'ctl-drive-abs' '<src>\abs.zip' 'abs.zip' $null
    Pack-Row 'ctl-drive-rel' '<drive>:rel.zip' 'rel.zip' $null
    Pack-Row 'trail-dot' 'report.' $null $inv
    Pack-Row 'ctl-empty' '' $null 'Empty name has no sense'
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
