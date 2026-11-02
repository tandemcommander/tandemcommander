<#
.SYNOPSIS
    Probe: the ZIP plug-in changes an archive reached through a symbolic link (backlog item
    zip-cannot-update-an-archive-reached-through-a-symbolic-link). With the default "create temporary
    backup of zip" the plug-in writes a temporary working file 'Sal*.tmp' and puts it in the archive's
    place with one ReplaceFileW step (feature 320). When the archive's name is a file symbolic link,
    ReplaceFileW fails (1464) and the user sees "Cannot replace original archive with temporary working
    file. Archive was not changed." Expected after the fix: the real archive changed, the link still the
    same link, nothing new anywhere.

.DESCRIPTION
    Fixture per row under %TEMP%\tc_zipsymlink\<row> (the left panel, active, is P):
      plain       P = src; src\a.zip a plain archive (the control)
      symlink     P = src; real\a.zip the archive; src\a.zip a file symbolic link to it (absolute target)
      relsymlink  as symlink, the link's target relative ('..\real\a.zip')
      junction    P = src\j, a directory junction to realdir; realdir holds 'plain' and a.zip
    'plain\f.txt' is in P. The archive holds seed.txt and keep.txt (written by the probe).
    Rows: add-<layout> Pack (850) 'plain' into 'a.zip' (typed), "add?" Yes, the ZIP box OK;
          del-<layout> the panel changed into P\a.zip (862), Select (841) 'seed.txt', Delete (729), Yes;
          add-symlink-locked: the real archive held open (read, sharing read + write, no delete) for the
          row -> the ZIP replace message, nothing changed, the link still the link.
    The snapshot lists every file (SHA-256 of its content and of every alternate data stream) and every
    reparse point (a link or a junction: recorded as '<reparse> <final path>', never followed) - a link
    that became a plain file, a stray 'Sal*.tmp' or a changed real archive is seen.
    Driver of 320's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
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
if (-not ('CbSym' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
public static class CbSym
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct WIN32_FIND_STREAM_DATA { public long StreamSize; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 296)] public string cStreamName; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr FindFirstStreamW(string name, int level, out WIN32_FIND_STREAM_DATA data, int flags);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool FindNextStreamW(IntPtr h, out WIN32_FIND_STREAM_DATA data);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool FindClose(IntPtr h);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern uint GetFinalPathNameByHandleW(SafeFileHandle h, StringBuilder buf, uint size, uint flags);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern uint GetFileAttributesW(string name);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern byte CreateSymbolicLinkW(string link, string target, uint flags);
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
    public static SafeFileHandle Hold(string path, uint share)
    {
        var h = CreateFileW(path, 0x80000000, share, IntPtr.Zero, 3, 0, IntPtr.Zero);
        if (h.IsInvalid) throw new IOException("CreateFileW(hold) failed: " + Marshal.GetLastWin32Error() + " " + path);
        return h;
    }
    public static uint Attr(string path) { return GetFileAttributesW(path); }
    // the path the file system resolves 'path' to (links followed), or "<unresolved N>"
    public static string Final(string path)
    {
        using (var h = CreateFileW(path, 0, 7, IntPtr.Zero, 3, 0x02000000, IntPtr.Zero))
        {
            if (h.IsInvalid) return "<unresolved " + Marshal.GetLastWin32Error() + ">";
            var sb = new StringBuilder(1024);
            uint n = GetFinalPathNameByHandleW(h, sb, 1024, 0);
            if (n == 0 || n >= 1024) return "<unresolved " + Marshal.GetLastWin32Error() + ">";
            return sb.ToString();
        }
    }
    // a file symbolic link (unprivileged with Developer Mode)
    public static void FileLink(string link, string target)
    {
        if (CreateSymbolicLinkW(link, target, 2) == 0)
            throw new IOException("CreateSymbolicLinkW failed: " + Marshal.GetLastWin32Error() + " " + link + " -> " + target);
    }
}
'@
}
$Root = $TempRoot + '\tc_zipsymlink'
$StartDir = $Root + '\start'
$CnfKey = $RegKey + '\Settings\Configuration\Confirmation'
$PackKey = $RegKey + '\Settings\Packers & Unpackers\Custom Packers'
$ReparseAttr = 0x400

function Vis([string]$s) { if ($s.Length -gt 60) { $s = '...(' + $s.Length + ') ' + $s.Substring($s.Length - 30) }; $s = $s -replace ' ', '<sp>'; return ("'" + $s + "'") }
function Join-Vis($a) { if (@($a).Count) { return ((@($a) | ForEach-Object { Vis $_ }) -join ', ') } return 'none' }
function Sha([byte[]]$b) { $sha = [Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($sha.ComputeHash($b)) } finally { $sha.Dispose() } }
# every entry under $Dir: a file -> SHA-256 (+ its streams); a reparse point (file or folder) ->
# '<reparse> <final path>', not followed
function Snap-Into($h, [string]$Dir, [int]$Base) {
    foreach ($e in [IO.Directory]::GetFileSystemEntries($LP + $Dir)) {
        $rel = $e.Substring($Base)
        $a = [CbSym]::Attr($e)
        if ($a -band $ReparseAttr) { $h[$rel] = '<reparse> ' + [CbSym]::Final($e); continue }
        if ($a -band 0x10) {
            foreach ($s in [CbSym]::Streams($e)) { $h[$rel + $s] = Sha ([CbSym]::ReadAll($e + $s)) }
            Snap-Into $h ($e.Substring($LP.Length)) $Base
            continue
        }
        $h[$rel] = Sha ([CbSym]::ReadAll($e))
        foreach ($s in [CbSym]::Streams($e)) { $h[$rel + $s] = Sha ([CbSym]::ReadAll($e + $s)) }
    }
}
function Snap([string]$Dir) {
    $h = @{}
    if ([IO.Directory]::Exists($LP + $Dir)) { Snap-Into $h $Dir (($LP + $Dir).Length + 1) }
    return $h
}
function Zip-Entries([string]$Zip) {
    try {
        $ms = New-Object IO.MemoryStream(, [CbSym]::ReadAll($LP + $Zip))
        $z = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Read)
        try { return @($z.Entries | ForEach-Object { $_.FullName } | Sort-Object) } finally { $z.Dispose() }
    }
    catch { return @('<not a readable zip: ' + $_.Exception.Message + '>') }
}
function Zip-Seed([string]$Zip) {
    $ms = New-Object IO.MemoryStream
    $z = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($n in @('seed.txt', 'keep.txt')) { $w = New-Object IO.StreamWriter($z.CreateEntry($n).Open()); $w.Write($n); $w.Dispose() }
    }
    finally { $z.Dispose() }
    [CbSym]::WriteAll($LP + $Zip, $ms.ToArray())
}
function Start-TcZs([string]$Left, [string]$Right) {
    $a = @('-t', 'TSYM', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
function ServeZs([int]$Id, $Keep = @(), [double]$Seconds = 60) {
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
# one row. $Op 'add' | 'del'; $Layout 'plain' | 'symlink' | 'relsymlink' | 'junction';
# $Share 0 = not held, else the real archive held open (read) with this sharing for the whole row;
# $WantEntries: the entries the real archive must hold afterwards; $null: nothing changed + the replace message
function Zs-Row([string]$Case, [string]$Op, [string]$Layout, [int]$Share, $WantEntries) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = $d + '\src'
    $R = $d + '\tgt\R'
    NewDir $src; NewDir $R
    switch ($Layout) {
        'plain' { $P = $src; $real = $src + '\a.zip'; $realRel = 'src\a.zip' }
        'junction' {
            NewDir ($d + '\realdir')
            & cmd.exe /c mklink /J ($src + '\j') ($d + '\realdir') | Out-Null
            if (-not (([CbSym]::Attr($LP + $src + '\j')) -band $ReparseAttr)) { throw 'the junction was not made' }
            $P = $src + '\j'; $real = $d + '\realdir\a.zip'; $realRel = 'realdir\a.zip'
        }
        default {
            NewDir ($d + '\real')
            $P = $src; $real = $d + '\real\a.zip'; $realRel = 'real\a.zip'
        }
    }
    NewDir ($P + '\plain')
    WriteFile ($P + '\plain\f.txt') 'F'
    Zip-Seed $real
    if ($Layout -eq 'symlink') { [CbSym]::FileLink($src + '\a.zip', $real) }
    if ($Layout -eq 'relsymlink') { [CbSym]::FileLink($src + '\a.zip', '..\real\a.zip') }
    $linkFinal0 = ''
    if ($Layout -like '*symlink') {
        $linkFinal0 = [CbSym]::Final($LP + $src + '\a.zip')
        if ($linkFinal0 -notlike ('*\' + $Case + '\real\a.zip')) { throw ('the link resolves to ' + $linkFinal0) }
    }
    & reg.exe add $PackKey /v 'Use Another Panel' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add $CnfKey /v 'Add To Archive' /t REG_DWORD /d 1 /f | Out-Null
    $snap0 = Snap $d
    $hold = $null
    $id = 0; $fatal = $null; $before = Reports
    try {
        if ($Share) { $hold = [CbSym]::Hold($LP + $real, [uint32]$Share) }
        $id = Start-TcZs $P $R
        if ($Op -eq 'add') {
            Key $id 0x24; Key $id 0x28        # Home, Down: 'plain' (after '..'; folders first)
            Start-Sleep -Milliseconds 500
            $dlg = Open-ByCmd $id 850 15
            if ($dlg -eq [IntPtr]::Zero) { throw 'Pack (850) opened no window' }
            if ([Drv098f]::Txt($dlg) -ne 'Pack') { throw ("850 opened '{0}', not the Pack dialog" -f [Drv098f]::Txt($dlg)) }
            Start-Sleep -Milliseconds 400
            $combo = Find-Ctl $dlg 210
            if ($combo -eq [IntPtr]::Zero) { throw 'the archive-name combo box 210 was not found' }
            if (-not [Drv098f]::SetText($combo, 'a.zip', 5000)) { throw 'WM_SETTEXT into the entry failed' }
            Start-Sleep -Milliseconds 200
            Click-Ok $dlg
            Start-Sleep -Milliseconds 800
            $r = ServeZs $id @($dlg) 60
            $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
            if ($stayed) { Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](ServeZs $id @() 15) }
        }
        else {
            [void](Do-ChangeDir $id ($P + '\a.zip')); [void](ServeZs $id @() 30)
            $loc = Get-Loc $id
            $sel = Open-ByCmd $id 841 10      # Select
            if ($sel -eq [IntPtr]::Zero) { throw 'Select (841) opened no window' }
            [void][Drv098f]::SetText((Find-Ctl $sel 101), 'seed.txt', 5000); Click-Ok $sel
            Start-Sleep -Milliseconds 800
            Post-Cmd (Get-Main $id) 729       # Delete (F8) - "delete?" answered Yes by ServeZs
            Start-Sleep -Milliseconds 800
            $r = ServeZs $id @() 60
            $stayed = $false
        }
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        if ($hold) { $hold.Dispose(); $hold = $null }
        Start-Sleep -Milliseconds 500
        $snap1 = Snap $d
        $new = @($snap1.Keys | Where-Object { -not $snap0.ContainsKey($_) } | Sort-Object)
        $changed = @($snap0.Keys | Where-Object { -not $snap1.ContainsKey($_) -or $snap1[$_] -ne $snap0[$_] } | Sort-Object)
        $entries = @(Zip-Entries $real)
        $asked = (@($r.Messages | Where-Object { $_ -match $ReplaceRx }).Count -gt 0)
        $link = ''
        if ($Layout -like '*symlink') {
            $isLink = [bool](([CbSym]::Attr($LP + $src + '\a.zip')) -band $ReparseAttr)
            $linkFinal1 = [CbSym]::Final($LP + $src + '\a.zip')
            $link = ('; src\a.zip still the link to real\a.zip: {0}' -f ($isLink -and $linkFinal1 -ceq $linkFinal0))
        }
        if ($null -eq $WantEntries) {
            $ok = ($new.Count -eq 0) -and ($changed.Count -eq 0) -and $asked
            $want = 'nothing new, nothing changed, the replace message'
        }
        else {
            $ok = ($new.Count -eq 0) -and ((@($changed) -join '|') -ceq $realRel) -and ((@($entries) -join '|') -ceq (@($WantEntries) -join '|')) -and -not $asked
            $want = ('nothing new, only {1} changed holding {0}, no replace message' -f (Join-Vis $WantEntries), $realRel)
        }
        if ($link -like '*: False') { $ok = $false }
        $ok = $ok -and (-not $fatal) -and (-not $r.TimedOut) -and (-not $stayed)
        $why = ''; if (-not $ok) { $why = " [expected: $want]" }
        $at = ''; if ($Op -eq 'del') { $at = ('panel at {0}; ' -f (Vis ([string]$loc))) }
        Row $Case 'RUN' (V $ok) ("{0}held: {1}; shown: {2}; new: {3}; changed: {4}; real archive entries: {5}{6}{7}{8}" -f $at, $Share, (Shown $r), (Join-Vis $new), (Join-Vis $changed), (Join-Vis $entries), $link, $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $why)
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
$backup = Join-Path $env:TEMP 'tczipsym_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("zipsymlink_probe {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; OS {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, [Environment]::OSVersion.VersionString)
    Out ("Fixture {0}" -f $Root)
    Out ''
    $added = @('keep.txt', 'plain/', 'plain/f.txt', 'seed.txt')
    Zs-Row 'add-plain' 'add' 'plain' 0 $added
    Zs-Row 'add-symlink' 'add' 'symlink' 0 $added
    Zs-Row 'add-relsymlink' 'add' 'relsymlink' 0 $added
    Zs-Row 'add-junction' 'add' 'junction' 0 $added
    Zs-Row 'add-symlink-locked' 'add' 'symlink' 3 $null
    Zs-Row 'del-plain' 'del' 'plain' 0 @('keep.txt')
    Zs-Row 'del-symlink' 'del' 'symlink' 0 @('keep.txt')
    Zs-Row 'del-relsymlink' 'del' 'relsymlink' 0 @('keep.txt')
    Zs-Row 'del-junction' 'del' 'junction' 0 @('keep.txt')
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    # links and junctions first (a recursive delete must never follow one)
    try {
        if ([IO.Directory]::Exists($LP + $Root)) {
            foreach ($j in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -Attributes ReparsePoint -ErrorAction SilentlyContinue)) {
                if ($j.PSIsContainer) { [IO.Directory]::Delete($j.FullName, $false) } else { [IO.File]::Delete($j.FullName) }
            }
            [IO.Directory]::Delete($LP + $Root, $true)
        }
    }
    catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
