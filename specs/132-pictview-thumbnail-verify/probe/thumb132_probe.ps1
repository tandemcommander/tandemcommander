<#
.SYNOPSIS
    Feature 132: PictView's Update Thumbnail never replaces a picture by a file that lost something.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). Every row is its own folder with
    one JPEG file (made beforehand by exifdll_measure.py - pass its work folder as -Cases), its own
    start of the program, the plug-in's command Update Thumbnail (a hot key given to its menu item
    for this run), Yes to every question, Skip / OK to every error. The verdict is taken from the
    FILE afterwards:
      unchanged - byte for byte the original;
      updated   - another file that ends with all the original's bytes from its picture data on
                  and still holds the marks the case planted (XMP block, Exif tag, data behind
                  the picture);
      LOSS      - anything else.
    -KeepDir <folder> keeps every row's original and resulting file (check_outputs.py reads them).
    -Expect fixed  : the build with feature 132 - the row's expected outcome must be met;
    -Expect before : a build without it (0.1.9) - the outcome is recorded, LOSS is FAIL;
    -Expect oldlib : the new plug-in with the EXIF.DLL of 0.1.9 put beside it (the runner swaps
                     the file) - what the old library spoils must be refused by the plug-in.
    The product's registry key is exported, restored and compared; the fixture is deleted.
    Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$Cases,
    [ValidateSet('fixed', 'before', 'oldlib')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string]$KeepDir,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$Cases = (Resolve-Path -LiteralPath $Cases).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Drv132' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
public static class Drv132
{
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
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
    public static int IndexOf(byte[] hay, byte[] needle, int from)
    {
        for (int i = from; i + needle.Length <= hay.Length; i++)
        {
            int j = 0; while (j < needle.Length && hay[i + j] == needle[j]) j++;
            if (j == needle.Length) return i;
        }
        return -1;
    }
    public static bool EndsWith(byte[] hay, byte[] src, int srcFrom)
    {
        int n = src.Length - srcFrom; if (n > hay.Length) return false;
        for (int i = 0; i < n; i++) if (hay[hay.Length - n + i] != src[srcFrom + i]) return false;
        return true;
    }
    public static bool Same(byte[] a, byte[] b)
    {
        if (a.Length != b.Length) return false;
        for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false;
        return true;
    }
}
'@
}

$Root = $TempRoot + '\tc132'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# "Zlutoucky kun" with its Czech accents (pure ASCII source)
$Accent = [char]0x017D + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD + ' k' + (Chars @(0x016F, 0x0148))
$Ascii = [Text.Encoding]::ASCII

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left) {
    $a = @('-t', 'T132', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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

# answers every dialog of the process until none shows for $Quiet seconds: Yes, else OK, else
# Skip; a dialog with none of these (the progress dialog) is left alone. Returns their texts.
function Answer-All([int]$Id, [double]$Seconds = 60, [double]$Quiet = 5) {
    $texts = @(); $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and $last.Elapsed.TotalSeconds -lt $Quiet -and (Test-Alive $Id)) {
        $acted = $false
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) })) {
            $bs = Buttons $h
            $b = $null
            foreach ($rx in @('^&?Yes$', '^&?OK$', '^&?Skip$')) {
                $b = $bs | Where-Object { [Drv098f]::Txt($_) -match $rx } | Select-Object -First 1
                if ($b) { break }
            }
            if (-not $b) { continue }
            Start-Sleep -Milliseconds 500
            $texts += ((WinDesc $h) + ' -> ' + [Drv098f]::Txt($b))
            Click $b; $acted = $true
            Start-Sleep -Milliseconds 900
            break
        }
        if ($acted) { $last.Restart() } else { Start-Sleep -Milliseconds 250 }
    }
    return $texts
}

# what happened to the file
function Classify([byte[]]$Orig, [string]$File, [string[]]$Marks) {
    if (-not [IO.File]::Exists($LP + $File)) { return [pscustomobject]@{ Kind = 'LOSS'; Why = 'the file is gone' } }
    $now = [IO.File]::ReadAllBytes($LP + $File)
    if ([Drv132]::Same($Orig, $now)) { return [pscustomobject]@{ Kind = 'unchanged'; Why = ('{0} bytes' -f $now.Length) } }
    $sos = [Drv132]::IndexOf($Orig, [byte[]](0xFF, 0xDA), 0)
    $why = @()
    if ($sos -lt 0 -or -not [Drv132]::EndsWith($now, $Orig, $sos)) { $why += 'the picture data (or what follows them) are not the original ones' }
    foreach ($m in $Marks) { if ([Drv132]::IndexOf($Orig, $Ascii.GetBytes($m), 0) -ge 0 -and [Drv132]::IndexOf($now, $Ascii.GetBytes($m), 0) -lt 0) { $why += ("'" + $m + "' is gone") } }
    $kind = $(if ($why.Count) { 'LOSS' } else { 'updated' })
    return [pscustomobject]@{ Kind = $kind; Why = ('{0} -> {1} bytes{2}' -f $Orig.Length, $now.Length, $(if ($why.Count) { ': ' + ($why -join '; ') } else { '' })) }
}

# one case: $Fixed / $OldLib = the outcome the row must have in those modes
function Row-Thumb([string]$Case, [string]$Source, [string]$Dir, [string]$Fixed, [string]$OldLib, [string]$Note) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $src = Join-Path $Cases ($Source + '.jpg')
    $folder = $Root + '\' + $Dir
    $file = $folder + '\photo.jpg'
    try {
        if (-not [IO.File]::Exists($src)) { Row $Case 'FILE' 'NOT DRIVEN' ('no case file ' + $src + ' (run exifdll_measure.py first)'); return }
        NewDir $folder
        $orig = [IO.File]::ReadAllBytes($src)
        [IO.File]::WriteAllBytes($LP + $file, $orig)
        $id = Start-P $folder
        Key $id 0x24; Key $id 0x28                                  # "..", the file
        $k = [Drv132]::ModKey((Get-LeftList $id), 0x4A, 3)          # Ctrl+Shift+J = Update Thumbnail
        $texts = Answer-All $id 60 5
        $c = Classify $orig $file @('TC132-XMP-MARK', 'TandemTest', 'TC132-TRAILER-')
        if ($KeepDir -and [IO.File]::Exists($LP + $file)) { [void][IO.Directory]::CreateDirectory($KeepDir); [IO.File]::Copy($LP + $file, (Join-Path $KeepDir ($Case + '.after.jpg')), $true); [IO.File]::Copy($src, (Join-Path $KeepDir ($Case + '.orig.jpg')), $true) }
        $left = @([IO.Directory]::GetFiles($LP + $folder) | ForEach-Object { [IO.Path]::GetFileName($_) })
        $refusal = [bool](@($texts | Where-Object { $_ -match 'Unable to create a file with the new thumbnail' }).Count)
        $want = $(switch ($Expect) { 'fixed' { $Fixed } 'oldlib' { $OldLib } default { '' } })
        $ok = $c.Kind -ne 'LOSS' -and $left.Count -eq 1
        if ($want) { $ok = $ok -and $c.Kind -eq $want }
        if ($want -eq 'unchanged') { $ok = $ok -and $refusal }     # a refusal is said, not silent
        if (-not $texts.Count) { Row $Case 'FILE' 'NOT DRIVEN' ("no dialog after the hot key ({0}; key {1}) - the command did not run; file {2}" -f $script:KeyNote, $k, $c.Kind); return }
        Row $Case 'FILE' (V $ok) ("{0}: {1} ({2}); expected here: {3}; the refusal message shown: {4}; files in the folder: {5}; dialogs: {6}" -f $Note, $c.Kind, $c.Why, $(if ($want) { $want } else { 'recorded' }), $refusal, (($left | ForEach-Object { Esc $_ }) -join ', '), (($texts | ForEach-Object { Tail $_ 230 }) -join ' || '))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc132_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    Set-Config
    $script:KeyNote = Set-PluginHotKey 'pictview\.spl$' 188 0x1034A
    Out ("thumb132_probe (feature 132), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("EXIF.DLL: {0}" -f (Get-FileHash -LiteralPath (Join-Path (Split-Path $Exe) 'plugins\pictview\exif.dll')).Hash)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Hot key : {0}; case files from {1}" -f $script:KeyNote, $Cases)
    Out ''
    Row-Thumb 'CTRL' 'CTRL_PLAIN' 'ctrl' 'updated' 'unchanged' 'a plain JPEG file (the library of 0.1.9 gives it an Exif block it did not have - refused since 135)'
    Row-Thumb 'EXIF' 'CTRL_EXIF' 'exif' 'updated' '' 'a JPEG file with two Exif tags (the library of 0.1.9 happens to keep every byte of so small a block - recorded)'
    Row-Thumb 'ACCENT' 'CTRL_PLAIN' $Accent 'updated' 'unchanged' 'a plain JPEG file in a folder with accented letters (owed by 131)'
    Row-Thumb 'XMP' 'EXIF_THEN_XMP' 'xmp' 'updated' 'unchanged' 'Exif and an XMP block (the usual file of a phone or of Lightroom)'
    Row-Thumb 'XMPONLY' 'XMP_ONLY' 'xmponly' 'updated' 'unchanged' 'an XMP block and no Exif'
    Row-Thumb 'FILL8' 'FILL_8' 'fill8' 'unchanged' 'unchanged' 'eight fill bytes before a table (allowed by the standard, more than the library reads)'
    Row-Thumb 'BIGEXIF' 'EXIF_BIG' 'bigexif' '' '' 'an Exif block near 64 KB'
    Row-Thumb 'TRAILER' 'TRAILER_FF00' 'trailer' 'updated' 'unchanged' 'data behind the picture that end with FF 00'
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
