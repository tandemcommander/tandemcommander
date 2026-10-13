<#
.SYNOPSIS
    Feature 130 probe: texts a PLUG-IN composes from a translated template and a UTF-8 file
    name or Windows error text (the follow-up of GitHub issue #7 outside the core).

.DESCRIPTION
    The program runs in the given language (Czech by default). Fixture under %TEMP%\tc130 with
    files named "Prilis zlutoucky kun" with their Czech accents.

      BAD7Z / BADISO / BADTAR
               Change Directory into a file that is no archive: the plug-in's message (it holds
               no name) - control rows for the plug-ins' error helpers
      ZIPTEST / 7ZTEST
               the plug-in's Test Archive (by a hot key given to the menu item for this run) on a
               good archive: "Archive '<path>' is OK." in the language, the path exact (the Czech
               sentence is ASCII - run with -Lang slovak for the accented one)
      CSUM     Checksum > Calculate, Save over an existing file: the overwrite question names
               the file exactly
      DBV / PVW / PEV
               F3 on a .dbf / .png / .exe: the viewer window's title (Database Viewer, PictView,
               PE Viewer) holds the file name exactly
      END      each instance ends with exit code 0, no stray window, no report

    A row passes when the text holds the expected name (and reason) exactly and has none of the
    letters that UTF-8 read through code page 1250 / 1252 gives. Each row also says whether the
    rest of the text has a letter outside ASCII (when it has none, the old build passes too -
    the sentence of that language worked by accident).

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified; the fixture is
    deleted. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lang = 'czech'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Drv130' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv130
{
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendGetBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int InternalGetWindowText(IntPtr h, StringBuilder s, int n);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    public static string LbText(IntPtr combo, int index)
    {
        long len = SendR(combo, 0x0149, index, 0);
        if (len < 0) return null;
        var buf = new char[len + 2]; IntPtr r;
        SendGetBuf(combo, 0x0148, (IntPtr)index, buf, 0, 5000, out r);
        long n = r.ToInt64(); if (n < 0) return null; if (n > len) n = len;
        return new string(buf, 0, (int)n);
    }
    // the title as the window stores it (not through its window procedure)
    public static string Title(IntPtr h) { var s = new StringBuilder(8000); InternalGetWindowText(h, s, 8000); return s.ToString(); }
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift): the probe thread shares the target thread's
    // input state and sets the key-state table - no real key press (the method of 117)
    public static string ModKey(IntPtr target, int vk, int mods)
    {
        uint pid; uint tid = GetWindowThreadProcessId(target, out pid);
        uint me = GetCurrentThreadId();
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed " + Marshal.GetLastWin32Error();
        var saved = new byte[256]; GetKeyboardState(saved);
        try
        {
            var k = (byte[])saved.Clone();
            if ((mods & 2) != 0) { k[0x10] = k[0xA0] = 0x80; }
            if ((mods & 1) != 0) { k[0x11] = k[0xA2] = 0x80; }
            if (!SetKeyboardState(k)) return "SetKeyboardState failed";
            PostMessageW(target, 0x0100, (IntPtr)vk, (IntPtr)1);
            IntPtr r; SendMessageTimeoutW(target, 0, IntPtr.Zero, IntPtr.Zero, 0, 3000, out r);
            Thread.Sleep(300);
            return "ok";
        }
        finally
        {
            SetKeyboardState(saved);
            PostMessageW(target, 0x0101, (IntPtr)vk, unchecked((IntPtr)0xC0000001));
            AttachThreadInput(me, tid, false);
        }
    }
}
'@
}

$Root = $TempRoot + '\tc130'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# "Prilis zlutoucky kun" with its Czech accents (pure ASCII source)
$Accent = 'P' + (Chars @(0x0159, 0x00ED)) + 'li' + [char]0x0161 + ' ' + [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD + ' k' + (Chars @(0x016F, 0x0148))
$Err32 = (New-Object ComponentModel.Win32Exception 32).Message.TrimEnd(' ', '.', "`r", "`n")   # the text Windows gives for a sharing violation
$NotifyCodes = @(1, 9)   # CBN_SELCHANGE, CBN_SELENDOK

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Start-P([string]$Left) {
    $a = @('-t', 'T130', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
function End-P([string]$Case, [int]$Id, $Before) {
    $fatal = Fatal-Win $Id
    End-Row $Case $Id $fatal $Before
}
function Garbled([string]$t) { return [bool]($t -match ('[' + (Chars @(0x0102, 0x0139, 0x00C4, 0x00C3, 0x00C5, 0x00E2, 0x20AC, 0xFFFD)) + ']')) }
# the verdict of a text: holds every expected piece exactly, nothing garbled
function Judge([string]$Case, [string]$Step, [string]$Text, [string[]]$Pieces, [string]$What) {
    $t = $Text.Replace("`r", '')
    $missing = @($Pieces | Where-Object { -not $t.Contains($_) })
    $rest = $t; foreach ($p in $Pieces) { $rest = $rest.Replace($p, '') }
    $accented = [bool]($rest -match '[^\x00-\x7F]')
    $ok = ($missing.Count -eq 0) -and -not (Garbled $t) -and $t.Length -gt 0
    Row $Case $Step (V $ok) ("{0}: '{1}'; expected pieces missing: {2}; garbled letters: {3}; the rest of the sentence has a letter outside ASCII: {4}" -f $What, (Esc $t), $(if ($missing.Count) { ($missing | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', ' } else { 'none' }), (Garbled $t), $accented)
}
# waits for a message box of the core (its text is the control 2477) that is not in $Known
function Wait-Box([int]$Id, $Known, [double]$Seconds = 20) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' })) {
            $st = Kid $h 2477 $null
            if ($st) { Start-Sleep -Milliseconds 700; return [pscustomobject]@{ Win = $h; Text = [Drv098f]::GetText($st, 5000) } }
        }
        Start-Sleep -Milliseconds 200
    }
    return $null
}
function Press([IntPtr]$Box, [int[]]$Ids) {
    foreach ($w in $Ids) { $b = Buttons $Box | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($b) { Click $b; Start-Sleep -Milliseconds 600; return } }
    Close-Win $Box; Start-Sleep -Milliseconds 600
}
function Drain([int]$Id, [double]$Seconds = 6) {   # closes whatever boxes follow (Cancel, else OK)
    $seen = @(); $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $h = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) }) | Select-Object -First 1
        if (-not $h) { Start-Sleep -Milliseconds 300; continue }
        $seen += (Tail (WinDesc $h) 200)
        Press $h @(2, 7, 1)
    }
    return $seen
}
# gives the menu item $MenuId of the plug-in whose DLL matches $DllRx the hot key $HotKey for this
# run (registry; the whole key is restored afterwards)
function Set-PluginHotKey([string]$DllRx, [int]$MenuId, [int]$HotKey) {
    $plugins = 'HKCU:\Software\Tandem Commander\0.1\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key' }
    foreach ($k in @(Get-ChildItem $plugins)) {
        $dll = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DLL
        if (-not $dll -or $dll -notmatch $DllRx) { continue }
        $menu = Join-Path $k.PSPath 'Menu'
        if (-not (Test-Path $menu)) { return "plug-in $($k.PSChildName): no Menu key" }
        foreach ($mi in @(Get-ChildItem $menu)) {
            $idv = (Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID
            if ($idv -eq $MenuId) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value $HotKey -Type DWord; return "plug-in $($k.PSChildName) ($dll): item $MenuId set" }
        }
        return "plug-in $($k.PSChildName) ($dll): no menu item with ID $MenuId"
    }
    return "no plug-in matching $DllRx is registered"
}

function Make-Png([string]$File) {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object Drawing.Bitmap 40, 30
    try { $g = [Drawing.Graphics]::FromImage($bmp); $g.Clear([Drawing.Color]::Teal); $g.Dispose(); $bmp.Save($File, [Drawing.Imaging.ImageFormat]::Png) } finally { $bmp.Dispose() }
}
# a minimal dBASE III table: one field C(10), one record
function Make-Dbf([string]$File) {
    $ms = New-Object IO.MemoryStream
    $h = New-Object byte[] 32
    $h[0] = 3; $h[1] = 126; $h[2] = 10; $h[3] = 13; $h[4] = 1; $h[8] = 65; $h[10] = 11
    $ms.Write($h, 0, 32)
    $f = New-Object byte[] 32
    [Text.Encoding]::ASCII.GetBytes('NAME').CopyTo($f, 0); $f[11] = [byte][char]'C'; $f[16] = 10
    $ms.Write($f, 0, 32); $ms.WriteByte(13)
    $rec = [Text.Encoding]::ASCII.GetBytes(' ' + 'alpha'.PadRight(10)); $ms.Write($rec, 0, $rec.Length); $ms.WriteByte(26)
    [IO.File]::WriteAllBytes($File, $ms.ToArray())
}
function Make-Fixture {
    NewDir $StartDir
    foreach ($d in @('o7z', 'oiso', 'otar', 'ztest', 'stest', 'csum', 'dbv', 'pvw', 'pev')) { NewDir ($Root + '\' + $d) }
    $junk = New-Object byte[] 4096; (New-Object Random 130).NextBytes($junk)
    [IO.File]::WriteAllBytes(($Root + '\o7z\' + $Accent + '.7z'), $junk)
    [IO.File]::WriteAllBytes(($Root + '\oiso\' + $Accent + '.iso'), $junk)
    [IO.File]::WriteAllBytes(($Root + '\otar\' + $Accent + '.tar'), $junk)
    # two real ZIP archives (one to hold open, one to test)
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    foreach ($z in @(($Root + '\ztest\' + $Accent + '.zip'))) {
        $a = [IO.Compression.ZipFile]::Open($z, 'Create')
        try { $e = $a.CreateEntry('inside.txt'); $w = New-Object IO.StreamWriter($e.Open()); $w.Write('hello'); $w.Dispose() } finally { $a.Dispose() }
    }
    # a real 7z archive, made by the system's tar (bsdtar) under an ASCII name
    $script:SevenNote = ''
    try {
        [IO.File]::WriteAllText(($Root + '\stest\inside.txt'), 'hello')
        $tar = Join-Path $env:WINDIR 'System32\tar.exe'
        & cmd.exe /c ('"' + $tar + '" -a -cf "' + $Root + '\stest\a.7z" -C "' + $Root + '\stest" inside.txt >nul 2>&1')
        [IO.File]::Delete($Root + '\stest\inside.txt')
        if ([IO.File]::Exists($Root + '\stest\a.7z')) { [IO.File]::Move(($Root + '\stest\a.7z'), ($Root + '\stest\' + $Accent + '.7z')) } else { $script:SevenNote = 'tar.exe made no .7z' }
    }
    catch { $script:SevenNote = 'tar.exe: ' + $_.Exception.Message }
    [IO.File]::WriteAllText(($Root + '\csum\data.txt'), 'x')
    [IO.File]::WriteAllText(($Root + '\csum\' + $Accent + '.sha256'), 'old')
    Make-Dbf ($Root + '\dbv\' + $Accent + '.dbf')
    Make-Png ($Root + '\pvw\' + $Accent + '.png')
    [IO.File]::Copy((Join-Path $env:WINDIR 'System32\whoami.exe'), ($Root + '\pev\' + $Accent + '.exe'), $true)
    return ("9 folders under {0}, names '{1}.*'" -f $Root, (Esc $Accent))
}

# OPENxx: the archive is held open without sharing; Change Directory into it
function Row-Open([string]$Case, [string]$Dir, [string]$Ext, [bool]$NameInText, [bool]$Hold = $false) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0; $lock = $null
    $file = $Root + '\' + $Dir + '\' + $Accent + '.' + $Ext
    try {
        if ($Hold) { $lock = [IO.File]::Open($file, 'Open', 'ReadWrite', 'None') }
        $id = Start-P ($Root + '\' + $Dir)
        $known = Get-Tops $id
        [void](Do-ChangeDir $id $file)
        $box = Wait-Box $id $known 20
        if (-not $box) { Row $Case 'TEXT' 'FAIL' ('no message box after Change Directory to the held archive; windows: ' + ((@(Get-Tops $id | Where-Object { $known -notcontains $_ }) | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        $pieces = @(); if ($NameInText) { $pieces += ($Accent + '.' + $Ext) }; if ($Hold) { $pieces += $Err32 }
        Judge $Case 'TEXT' $box.Text $pieces ("message of the plug-in for the archive it cannot open (caption '{0}')" -f (Esc ([Drv098f]::Txt($box.Win))))
        Press $box.Win @(2, 1)
        $more = Drain $id 4
        if ($more.Count) { Out ("    {0}: boxes after it: {1}" -f $Case, ($more -join ' || ')) }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($lock) { $lock.Dispose() }
        if ($id) { End-P $Case $id $before }
    }
}

# ZIPTEST / 7ZTEST: the plug-in's Test Archive on the focused archive (hot key set for this run)
function Row-Test([string]$Case, [string]$Dir, [string]$Ext, [int]$Vk, [string]$Note) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $file = $Root + '\' + $Dir + '\' + $Accent + '.' + $Ext
    try {
        if (-not [IO.File]::Exists($file)) { Row $Case 'TEXT' 'NOT DRIVEN' ('the fixture has no ' + $Ext + ' archive: ' + $script:SevenNote); return }
        $id = Start-P ($Root + '\' + $Dir)
        Key $id 0x24; Key $id 0x28                                  # "..", the archive
        $known = Get-Tops $id
        $k = [Drv130]::ModKey((Get-LeftList $id), $Vk, 3)           # Ctrl+Shift+<key> = Test Archive
        $box = Wait-Box $id $known 25
        if (-not $box) { Row $Case 'TEXT' 'NOT DRIVEN' ("no box after the hot key ({0}; key {1}); windows: {2} - person step: the plug-in's Test Archive on an archive with an accented name" -f $Note, $k, ((@(Get-Tops $id | Where-Object { $known -notcontains $_ }) | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        Judge $Case 'TEXT' $box.Text @($file) ("result of Test Archive (caption '{0}')" -f (Esc ([Drv098f]::Txt($box.Win))))
        Press $box.Win @(1, 2)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- Checksum: Calculate, Save over an existing file --------------------------------------
function Combo-Items([IntPtr]$C) {
    if (-not $C) { return @() }
    $n = [Drv130]::SendR($C, 0x0146, 0, 0); $l = @()
    for ($i = 0; $i -lt $n; $i++) { $l += [Drv130]::LbText($C, $i) }
    return $l
}
function Pick([IntPtr]$C, [string]$Rx) {
    $items = @(Combo-Items $C)
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($items[$i] -match $Rx) {
            [void][Drv130]::SendR($C, 0x014E, $i, 0)
            $cid = [Drv098f]::GetDlgCtrlID($C); $par = [Drv098f]::GetParent($C)
            foreach ($code in $NotifyCodes) { [void][Drv130]::SendR($par, 0x0111, (($code -shl 16) -bor $cid), $C.ToInt64()) }
            Start-Sleep -Milliseconds 300
            return $true
        }
    }
    return $false
}
function Find-NameEdit([IntPtr]$Dlg) {
    $e = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -ne 41477 })
    $f = @($e | Where-Object { [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148 -or [Drv098f]::GetDlgCtrlID($_) -eq 1148 }) | Select-Object -First 1
    if ($f) { return $f }
    return @($e | Where-Object { [Drv098f]::Cls([Drv098f]::GetParent($_)) -eq 'ComboBox' }) | Select-Object -First 1
}
function Type-Text([IntPtr]$E, [string]$Text) {
    [void][Drv130]::SendR($E, 0x00B1, 0, -1)
    [void][Drv130]::SendR($E, 0x0102, 8, 0)
    foreach ($ch in $Text.ToCharArray()) { [void][Drv130]::SendR($E, 0x0102, [int]$ch, 1) }
    Start-Sleep -Milliseconds 300
}
function Row-Csum {
    if (-not (Want 'CSUM')) { return }
    $before = Reports; $id = 0
    $dir = $Root + '\csum'
    try {
        $id = Start-P $dir
        Key $id 0x24; Key $id 0x28; Key $id 0x28                    # "..", the .sha256, data.txt ... select all instead:
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 1200; Sync $id
        $known = Get-Tops $id
        $k = [Drv130]::ModKey((Get-LeftList $id), 0x55, 3)          # Ctrl+Shift+U = Calculate (set for this run)
        $calc = [IntPtr]::Zero
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $calc -eq [IntPtr]::Zero) {
            foreach ($h in @(Get-Tops $id | Where-Object { $known -notcontains $_ })) { if (Kid $h 1003 'Button') { $calc = $h } }
            Start-Sleep -Milliseconds 200
        }
        if ($calc -eq [IntPtr]::Zero) { Row 'CSUM' 'TEXT' 'NOT DRIVEN' ("the Calculate dialog did not open ({0}; key {1}) - person step: Plugins > Checksum > Calculate, Save over an existing file with an accented name" -f $script:CsumKeyNote, $k); return }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and -not [Drv098f]::IsWindowEnabled((Kid $calc 1003 'Button'))) { Start-Sleep -Milliseconds 200 }
        $known2 = Get-Tops $id
        Click (Kid $calc 1003 'Button')
        $od = [IntPtr]::Zero
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and $od -eq [IntPtr]::Zero) {
            $dlg = @(Get-Tops $id | Where-Object { $known2 -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
            if ($dlg -and (Find-NameEdit $dlg)) { Start-Sleep -Milliseconds 1200; $od = $dlg }
            Start-Sleep -Milliseconds 300
        }
        if ($od -eq [IntPtr]::Zero) { Row 'CSUM' 'TEXT' 'NOT DRIVEN' 'no save dialog with a file name field after 60 s'; return }
        foreach ($cb in @([Drv098f]::Kids($od) | Where-Object { [Drv098f]::Cls($_) -eq 'ComboBox' })) { if (@(Combo-Items $cb | Where-Object { $_ -match '\*\.sha256' }).Count) { [void](Pick $cb '\*\.sha256'); break } }
        $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
        Type-Text (Find-NameEdit $od) $dir
        if ($ok) { Click $ok } else { Post-Cmd $od 1 }
        Start-Sleep -Milliseconds 2500
        $fn = Find-NameEdit $od
        if (-not $fn) { Row 'CSUM' 'TEXT' 'NOT DRIVEN' 'no file name field after navigating'; Post-Cmd $od 2; return }
        $known3 = Get-Tops $id
        Type-Text $fn $Accent
        if ($ok) { Click $ok } else { Post-Cmd $od 1 }
        # the question is the plug-in's (a core message box); a box of the common dialog itself is
        # reported and answered Yes
        $box = $null; $other = @()
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 20 -and -not $box) {
            foreach ($h in @(Get-Tops $id | Where-Object { $known3 -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) })) {
                $st = Kid $h 2477 $null
                if ($st) { Start-Sleep -Milliseconds 700; $box = [pscustomobject]@{ Win = $h; Text = [Drv098f]::GetText($st, 5000) }; break }
                $other += (Tail (WinDesc $h) 160)
                $yes = Buttons $h | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 -or [Drv098f]::Txt($_) -match '^&?(Ano|Yes)$' } | Select-Object -First 1
                if ($yes) { Click $yes; Start-Sleep -Milliseconds 800 }
            }
            Start-Sleep -Milliseconds 300
        }
        if (-not $box) { Row 'CSUM' 'TEXT' 'NOT DRIVEN' ('no overwrite question of the plug-in; other boxes: ' + ($other -join ' || ')); [void](Drain $id 4); return }
        Judge 'CSUM' 'TEXT' $box.Text @(($dir + '\' + $Accent + '.sha256')) ("overwrite question (caption '{0}')" -f (Esc ([Drv098f]::Txt($box.Win))))
        Press $box.Win @(2, 7)                                       # Cancel: nothing is written
        Start-Sleep -Milliseconds 800
        [void](Drain $id 4)
        $kept = [IO.File]::ReadAllText($dir + '\' + $Accent + '.sha256')
        Row 'CSUM' 'STATE' (V ($kept -ceq 'old')) ("the existing file after Cancel holds '{0}' (expected 'old')" -f (Esc $kept))
        foreach ($h in @(Get-Tops $id | Where-Object { $known -notcontains $_ })) { Post-Cmd $h 2; Start-Sleep -Milliseconds 400 }
    }
    catch { Row 'CSUM' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'CSUM' $id $before } }
}

# DBV / PVW / PEV: F3 on the only file of a folder - the viewer window's title
function Row-Title([string]$Case, [string]$Dir, [string]$Ext, [string]$ViewerRx) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P ($Root + '\' + $Dir)
        Key $id 0x24; Key $id 0x28
        $w = Open-ByCmd $id 742 20                                   # CM_VIEW
        if ($w -eq [IntPtr]::Zero) { Row $Case 'TITLE' 'FAIL' 'F3 opened no window'; return }
        Start-Sleep -Milliseconds 2500
        $cls = [Drv098f]::Cls($w); $title = [Drv130]::Title($w)
        if ($cls -eq '#32770') { Row $Case 'TITLE' 'FAIL' ('a box instead of a viewer: ' + (WinDesc $w)); Press $w @(2, 1); return }
        if ($title -notmatch $ViewerRx) { Row $Case 'TITLE' 'NOT DRIVEN' ("another viewer opened the file (class {0}, title '{1}') - the configuration's viewer for *.{2} is not this plug-in" -f $cls, (Esc $title), $Ext) }
        else { Judge $Case 'TITLE' $title @(($Accent + '.' + $Ext)) ("title of the viewer window (class {0})" -f $cls) }
        [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 1200
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc130_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    $fx = Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    $script:ZipKeyNote = Set-PluginHotKey 'zip\.spl$' 3 0x1034A
    $script:CsumKeyNote = Set-PluginHotKey 'checksum\.spl$' 1 0x10355
    $script:SevenKeyNote = Set-PluginHotKey '7zip\.spl$' 1 0x1034B
    Out ("plugmix_probe (feature 130), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Fixture : {0}; Windows text for error 32: '{1}'" -f $fx, (Esc $Err32))
    Out ("Hot keys: ZIP - {0}; Checksum - {1}; 7-Zip - {2}" -f $script:ZipKeyNote, $script:CsumKeyNote, $script:SevenKeyNote)
    Out ''
    Row-Open 'BAD7Z' 'o7z' '7z' $false
    Row-Open 'BADISO' 'oiso' 'iso' $false
    Row-Open 'BADTAR' 'otar' 'tar' $false
    Row-Test 'ZIPTEST' 'ztest' 'zip' 0x4A $script:ZipKeyNote
    Row-Test '7ZTEST' 'stest' '7z' 0x4B $script:SevenKeyNote
    Row-Csum
    Row-Title 'DBV' 'dbv' 'dbf' '.'
    Row-Title 'PVW' 'pvw' 'png' 'PictView'
    Row-Title 'PEV' 'pev' 'exe' '.'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } }
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
