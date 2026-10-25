<#
.SYNOPSIS
    Feature 267 probe: PictView's Exif dialog and Exif auto-rotation with the built-in (WIC)
    engine.

.DESCRIPTION
    Fixtures under %TEMP%\tc267\p (removed at the end, explicit root only), made by Pillow
    (probe\mkfix267.py): JPEG files of four solid quadrants with an Exif Orientation 1..8 and
    controls. Each row opens one file in PictView (F3 from the panel), then:

      ROT   the viewer's title gives the size shown, and a Save As of the shown image (PNG, no
            rotation in the dialog) is read back by probe\quad267.py: its quadrant colours must be
            those of the file turned by its orientation (Pillow's exif_transpose), or the file as
            stored where the row says so;
      EXIF  CMD_IMG_EXIF (115) is posted to the viewer: for a file with an Exif block the Exif
            dialog must open and its list (2121) must hold the tags, among them "Orientation";
            for a file without Exif no dialog may open.

    Rows (names for -Only):
      o1 .. o8        Orientation 1..8 with PixelX/YDimension 64 x 48: turned as the tag says
      o6-nodims       Orientation 6 without PixelX/YDimension: turned
      o6-moddims      Orientation 6, PixelX/YDimension 640 x 480 (the recorded size is not
                      consulted - 267): turned
      noexif, xmp     no Exif block (none / XMP only): shown as stored, no Exif dialog
      uni             o6.jpg under a name with Czech and Japanese letters: turned, dialog with tags
      off             o6.jpg with the AutoRotate setting off: shown as stored, dialog with tags
      tif6            a TIFF with Orientation 6 (not a JPEG - 267 leaves it alone): no Exif
                      dialog; the size shown is recorded (INFO) and compared between builds
      keep-*          two windows: B shows z.jpg, A renames x.jpg onto it (Yes); B reopens z.jpg keeping
                      the user's mirror and must show x's content turned by its own tag (review 1,
                      S1): keep-ctl (z without Exif), keep-o6, keep-o2, keep-o5, keep-user6 (o6
                      mirrored left-right by the user in B before the rename)
      real-*          with -RealRoot <folder of the public collection ianare/exif-samples>: real
                      camera files copied into the fixture; the title size must be the size of
                      the file turned by its tag (Pillow), the Exif dialog must open exactly for
                      the files with an Exif block

    The setting AutoRotate is seeded (1; 0 for the row 'off') under HKCU\Software\Tandem
    Commander (exported before, restored and SHA-256-verified after). MUST run through
    tools\run_on_hidden_desktop.ps1. Refuses while another tandemcommander.exe runs. Exit code =
    number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [string]$RepoRoot,
    [string]$RealRoot
)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Join-Path $PSScriptRoot '..\..\..' }   # $PSScriptRoot is empty in a parameter default (5.1)
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) -or (@($Only | Where-Object { $n -like $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $RepoRoot 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Drv267' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Drv267
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr addr, UIntPtr size, uint type, uint protect);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool VirtualFreeEx(IntPtr p, IntPtr addr, UIntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool ReadProcessMemory(IntPtr p, IntPtr addr, byte[] buf, UIntPtr size, out UIntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool WriteProcessMemory(IntPtr p, IntPtr addr, byte[] buf, UIntPtr size, out UIntPtr done);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendGetBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    public static string LbText(IntPtr combo, int index)
    {
        long len = SendR(combo, 0x0149, index, 0);
        if (len < 0) return null;
        var buf = new char[len + 2]; IntPtr r;
        SendGetBuf(combo, 0x0148, (IntPtr)index, buf, 0, 5000, out r);
        long n = r.ToInt64(); if (n < 0) return null; if (n > len) n = len;
        return new string(buf, 0, (int)n);
    }
    // the texts of column 'sub' of a list view of another (64-bit) process: LVM_GETITEMTEXTW with an
    // LVITEMW in that process's memory
    public static string[] LvTexts(IntPtr lv, int sub)
    {
        var res = new List<string>();
        long n = SendR(lv, 0x1004 /*LVM_GETITEMCOUNT*/, 0, 0);
        if (n <= 0) return res.ToArray();
        uint pid; GetWindowThreadProcessId(lv, out pid);
        IntPtr hp = OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid);
        if (hp == IntPtr.Zero) return null;
        IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, (UIntPtr)4096, 0x3000, 0x04);
        if (mem == IntPtr.Zero) { CloseHandle(hp); return null; }
        try
        {
            for (int i = 0; i < n && i < 500; i++)
            {
                var item = new byte[88]; // LVITEMW, x64
                BitConverter.GetBytes(0x0001 /*LVIF_TEXT*/).CopyTo(item, 0);
                BitConverter.GetBytes(i).CopyTo(item, 4);
                BitConverter.GetBytes(sub).CopyTo(item, 8);
                BitConverter.GetBytes(mem.ToInt64() + 512).CopyTo(item, 24); // pszText
                BitConverter.GetBytes(1000).CopyTo(item, 32);                // cchTextMax
                UIntPtr done;
                if (!WriteProcessMemory(hp, mem, item, (UIntPtr)item.Length, out done)) return null;
                long len = SendR(lv, 0x1073 /*LVM_GETITEMTEXTW*/, i, mem.ToInt64());
                if (len < 0) { res.Add("<timeout>"); continue; }
                var b = new byte[2000];
                if (!ReadProcessMemory(hp, (IntPtr)(mem.ToInt64() + 512), b, (UIntPtr)2000, out done)) return null;
                var chars = new char[1000]; Buffer.BlockCopy(b, 0, chars, 0, 2000);
                int z = Array.IndexOf(chars, '\0'); if (z < 0) z = chars.Length;
                res.Add(new string(chars, 0, z));
            }
            return res.ToArray();
        }
        finally { VirtualFreeEx(hp, mem, UIntPtr.Zero, 0x8000); CloseHandle(hp); }
    }
}
'@
}

$Root = $TempRoot + '\tc267\p'
$StartDir = $Root + '\start'
$Fix = $Root + '\fix'
$Out = $Root + '\out'
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }
$UniName = 'Kon' + [char]0x00ED + [char]0x010D + 'ek ' + (S 0x65E5, 0x672C) + ' o6.jpg'
$Py = 'python'
$Quad = Join-Path $PSScriptRoot 'quad267.py'
$PvKey = $RegKey + '\Settings\Plugins Configuration\PictView'

function Exists([string]$p) { return [IO.File]::Exists($LP + $p) }
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left) {
    $a = @('-t', 'T267', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
# 111's / 120's helpers (pv120_probe.ps1), copied
function Answer([int]$Id, [double]$Seconds = 25, [int[]]$WantIds = @(6, 2, 1), $Ignore = @()) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not (Test-Alive $Id)) { break }
        $boxes = @(Get-Tops $Id | Where-Object { @('#32770', 'OperationStatusWindow') -contains [Drv098f]::Cls($_) -and $Ignore -notcontains $_ -and [Drv098f]::IsWindowEnabled($_) })
        if (-not $boxes.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 150; continue
        }
        $idleSince = $null
        foreach ($b in $boxes) {
            $key = $b.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - $seen[$key] -lt 0.7) { continue }
            $seen.Remove($key)
            $d = WinDesc $b
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if ([Drv098f]::Cls($b) -eq 'OperationStatusWindow') {
                [void]$r.Messages.Add('[shell operation window] ' + (Esc ([Drv098f]::Txt($b))))
                [void][Drv098f]::PostMessageW($b, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
                Start-Sleep -Milliseconds 800; continue
            }
            [void]$r.Messages.Add($d)
            $btn = $null
            foreach ($w in $WantIds) { $btn = Buttons $b | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($btn) { break } }
            if ($btn) { Click $btn } else { Close-Win $b }
            Start-Sleep -Milliseconds 600
        }
    }
    return $r
}
function Msgs2($r) { if ($r.Messages.Count) { return ($r.Messages -join ' || ') } else { return 'no box' } }
function End-P([string]$Case, [int]$Id, $Before) {
    foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    Start-Sleep -Milliseconds 800
    [void](Answer $Id 6 @(6, 1))
    End-Row $Case $Id $null $Before
}
function Focus-File([int]$Id, [string]$Full) { [void](Do-ChangeDir $Id $Full); [void](Serve $Id 8); Sync $Id }
function Open-Viewer([int]$Id, [double]$Seconds = 30) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 742
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -ne '#32770' }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 3000; return $w }   # 267: the time for an automatic turn
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}
function Close-Viewer([int]$Id, [IntPtr]$Wv) {
    if ($Wv -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($Wv)) { return }
    [void][Drv098f]::PostMessageW($Wv, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($Wv)) { Start-Sleep -Milliseconds 100 }
    [void](Answer $Id 3 @(6, 1))
}
function Title([IntPtr]$Wv) { return [Drv098f]::Txt($Wv) }
function Dims([string]$t) { if ($t -match '\((\d+) x (\d+) x ') { return ('{0}x{1}' -f $Matches[1], $Matches[2]) }; return '?' }
function Combo-Items([IntPtr]$C) {
    if (-not $C) { return @() }
    $n = [Drv267]::SendR($C, 0x0146, 0, 0); $l = @()
    for ($i = 0; $i -lt $n; $i++) { $l += [Drv267]::LbText($C, $i) }
    return $l
}
function Pick([IntPtr]$C, [string]$Rx, [switch]$Notify) {
    if (-not $C) { return $false }
    $items = @(Combo-Items $C)
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($items[$i] -match $Rx) {
            [void][Drv267]::SendR($C, 0x014E, $i, 0)
            if ($Notify) {
                $cid = [Drv098f]::GetDlgCtrlID($C); $par = [Drv098f]::GetParent($C)
                foreach ($code in @(9, 1)) { [void][Drv267]::SendR($par, 0x0111, (($code -shl 16) -bor $cid), $C.ToInt64()) }
            }
            Start-Sleep -Milliseconds 300
            return $true
        }
    }
    return $false
}
function Save-As([int]$Id, [IntPtr]$Wv, [string]$Full, $O) {
    $r = [pscustomobject]@{ Ok = $false; Note = ''; Pre = @() }
    $known = Get-Tops $Id
    Post-Cmd $Wv 124
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($c) {
            Start-Sleep -Milliseconds 1200
            if ((Kid $c 1136 'ComboBox')) { $od = $c; break }
            $r.Pre += (WinDesc $c)
            $y = Buttons $c | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($y) { Click $y } else { Close-Win $c }
            $known = @($known) + @($c); Start-Sleep -Milliseconds 800; continue
        }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) { $r.Note = 'no save dialog; before it: ' + ($r.Pre -join ' || '); return $r }
    $types = Kid $od 1136 'ComboBox'
    if ($O.Type -and -not (Pick $types $O.Type -Notify)) { $r.Note = "type '$($O.Type)' not offered"; Post-Cmd $od 2; return $r }
    Start-Sleep -Milliseconds 300
    if ($O.Rot) { [void](Pick (Kid $od 2304 'ComboBox') $O.Rot) }
    $fn = @([Drv098f]::Kids($od) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148 }) | Select-Object -First 1
    if (-not $fn) { $r.Note = 'no file name field'; Post-Cmd $od 2; return $r }
    [void][Drv098f]::SetText($fn, $Full, 5000)
    $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
    if ($ok) { Click $ok } else { Post-Cmd $od 1 }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
    $r.Ok = $true
    return $r
}
function Cancel-Dialogs([int]$Id) { foreach ($x in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 1136 'ComboBox') })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 600 } }
# a Save As of what the viewer shows into a new PNG: "WxH <quadrants>" (quad267.py)
function Shown-Quads([int]$Id, [IntPtr]$Wv, [string]$Full) {
    $s = Save-As $Id $Wv $Full @{ Type = 'Portable Network'; Rot = 'None' }
    $ans = Answer $Id 25 @(6, 2, 1) @($Wv)
    Cancel-Dialogs $Id
    if (-not (Exists $Full)) { return ('<no file; ' + $s.Note + '; ' + (Msgs2 $ans) + '>') }
    return ((& $Py $Quad 'shown' ($LP + $Full) 2>&1) -join '')
}
function Want-Quads([string]$Mode, [string]$Full) { return ((& $Py $Quad $Mode ($LP + $Full) 2>&1) -join '') }
# CMD_IMG_EXIF in viewer $Wv: the Exif dialog's list texts (column 0), or $null when no dialog opened
function Exif-Dialog([int]$Id, [IntPtr]$Wv) {
    $known = Get-Tops $Id
    Post-Cmd $Wv 115
    $dlg = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 6 -and $dlg -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($c) { $dlg = $c } else { Start-Sleep -Milliseconds 200 }
    }
    if ($dlg -eq [IntPtr]::Zero) { return $null }
    Start-Sleep -Milliseconds 1000
    $lv = Kid $dlg 2121 'SysListView32'
    if (-not $lv) { $r = @('<a box, not the Exif dialog: ' + (WinDesc $dlg) + '>') }
    else { $r = @([Drv267]::LvTexts($lv, 0)) }
    Post-Cmd $dlg 2
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 5 -and [Drv098f]::IsWindow($dlg)) { Start-Sleep -Milliseconds 100 }
    return , $r
}
function Make-Fixtures {
    NewDir $Fix
    $o = & $Py (Join-Path $PSScriptRoot 'mkfix267.py') $Fix 2>&1
    if ("$o" -notmatch 'ok') { throw ('fixtures: ' + "$o") }
}
function Fx([string]$name, [string]$dir, [string]$as) { if (-not $as) { $as = $name }; NewDir $dir; [IO.File]::Copy($LP + $Fix + '\' + $name, $LP + $dir + '\' + $as, $true); return ($dir + '\' + $as) }
function Set-AutoRotate([int]$v) { & reg.exe add $PvKey /v 'AutoRotate' /t REG_DWORD /d $v /f | Out-Null }

# $Case: row name; $Fixture: the file; $As: its name in the row's folder; $Turned: shown turned by
# the tag ($true) or as stored; $HasExif: the Exif dialog must open with the tags; $AutoRotate: the setting
function Run-Row([string]$Case, [string]$Fixture, [string]$As, [bool]$Turned, [bool]$HasExif, [int]$AutoRotate = 1) {
    if (-not (Want $Case)) { return }
    if ($Case -notmatch '^[a-z0-9-]+$') { throw "bad case name $Case" }
    $d = $Root + '\' + $Case
    $src = Fx $Fixture $d $As
    if (-not $src.StartsWith($Root + '\')) { throw "fixture outside the root: $src" }
    $want = Want-Quads $(if ($Turned) { 'want' } else { 'shown' }) $src
    Set-AutoRotate $AutoRotate
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        $t = Title $w
        $texts = Exif-Dialog $id $w
        $shown = Shown-Quads $id $w ($Out + '\' + $Case + '.png')
        $okRot = ($shown -eq $want) -and ((Dims $t) -eq ($want -split ' ')[0])
        # a non-JPEG: what the engine shows is its own business (Pillow turns a TIFF on load) - only
        # recorded, to be compared between builds
        $verdict = if ($Fixture -like '*.tif') { 'INFO' } else { V $okRot }
        Row $Case 'ROT' $verdict ("{0}, AutoRotate {1}: title size {2}; shown {3} (want {4}{5})" -f (Esc $As), $AutoRotate, (Dims $t), $shown, $want, $(if ($Turned) { ', turned by the tag' } else { ', as stored' }))
        if ($HasExif) {
            $n = if ($null -eq $texts) { -1 } else { $texts.Count }
            $okExif = ($null -ne $texts) -and ($n -gt 0) -and (@($texts | Where-Object { $_ -match '^Orientation' }).Count -gt 0)
            Row $Case 'EXIF' (V $okExif) ("Exif command: {0}" -f $(if ($null -eq $texts) { 'no dialog opened' } else { "dialog, {0} tags: {1}" -f $n, (Esc ((@($texts) | Select-Object -First 8) -join ', ')) }))
        }
        else {
            Row $Case 'EXIF' (V ($null -eq $texts)) ("Exif command on a file without Exif: {0}" -f $(if ($null -eq $texts) { 'no dialog (right)' } else { 'a dialog opened: ' + (Esc (@($texts) -join ', ')) }))
        }
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# a real camera file (-RealRoot): the title size against the file turned by its tag, the Exif dialog
function Run-Real([string]$Case, [string]$Rel, [bool]$HasExif) {
    if (-not (Want $Case)) { return }
    if (-not $RealRoot) { Row $Case 'REAL' 'NOT DRIVEN' 'no -RealRoot given (the public collection ianare/exif-samples)'; return }
    $from = Join-Path $RealRoot $Rel
    if (-not (Test-Path -LiteralPath $from)) { Row $Case 'REAL' 'NOT DRIVEN' ('not in -RealRoot: ' + $Rel); return }
    $d = $Root + '\' + $Case
    NewDir $d
    $src = $d + '\' + [IO.Path]::GetFileName($from)
    [IO.File]::Copy($from, $LP + $src, $true)
    $want = (Want-Quads 'want' $src) -split ' ' | Select-Object -First 1
    Set-AutoRotate 1
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $src
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row $Case 'OPEN' 'FAIL' 'no viewer'; return }
        $t = Title $w
        $texts = Exif-Dialog $id $w
        Row $Case 'ROT' (V ((Dims $t) -eq $want)) ("{0}: title size {1} (want {2}, the file turned by its tag)" -f $Rel, (Dims $t), $want)
        $okExif = if ($HasExif) { ($null -ne $texts) -and $texts.Count -gt 0 } else { $null -eq $texts }
        Row $Case 'EXIF' (V $okExif) ("Exif command (the file has {0}): {1}" -f $(if ($HasExif) { 'an Exif block' } else { 'no Exif block' }), $(if ($null -eq $texts) { 'no dialog' } else { 'dialog, {0} tags' -f $texts.Count }))
        Close-Viewer $id $w
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# 120's Rename-Shown (pv120_probe.ps1), copied: CMD_IMG_RENAME in viewer $Wv, the field 2172 set to
# $NewName, OK; the boxes after it answered with $WantIds
function Rename-Shown([int]$Id, [IntPtr]$Wv, [string]$NewName, [int[]]$WantIds = @(6, 2, 1), $Ignore = @()) {
    $known = Get-Tops $Id
    Post-Cmd $Wv 185
    $dlg = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 10 -and $dlg -eq [IntPtr]::Zero) {
        $dlg = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 2172 'Edit') }) | Select-Object -First 1
        if (-not $dlg) { $dlg = [IntPtr]::Zero; Start-Sleep -Milliseconds 200 }
    }
    if ($dlg -eq [IntPtr]::Zero) { return 'no rename dialog' }
    Start-Sleep -Milliseconds 500
    [void][Drv098f]::SetText((Kid $dlg 2172 'Edit'), $NewName, 5000)
    Click-Ok $dlg
    Start-Sleep -Milliseconds 800
    $ans = Answer $Id 15 $WantIds (@($Ignore) + @($Wv))
    foreach ($x in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 2172 'Edit') })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 500 }
    return (Msgs2 $ans)
}
# "WxH ABCD" mirrored left-right: "WxH BADC"
function Mirror-Quads([string]$q) { $p = $q -split ' '; if ($p.Count -lt 2 -or $p[1].Length -ne 4) { return $q }; $c = $p[1]; return ('{0} {1}{2}{3}{4}' -f $p[0], $c[1], $c[0], $c[3], $c[2]) }
# review 1 of 267 (S1): window B shows z.jpg (turned by its tag; with -UserMirror the user mirrored it
# left-right too), window A renames x.jpg onto z.jpg (Yes). B reopens z.jpg keeping the USER's mirror
# (ReopenKeepingView(TRUE)) and must show x's content turned by its own tag (and mirrored by the user).
# Before the fix the mirror the auto-rotation had set was kept as the user's and the new turn toggled
# it off / turned the other way.
function Run-Keep([string]$Case, [string]$XFix, [string]$ZFix, [switch]$UserMirror) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $x = Fx $XFix $d 'x.jpg'; $z = Fx $ZFix $d 'z.jpg'
    if (-not $x.StartsWith($Root + '\') -or -not $z.StartsWith($Root + '\')) { throw "fixture outside the root" }
    $wantX = Want-Quads 'want' $x
    $wantZ = Want-Quads 'want' $z
    if ($UserMirror) { $wantX = Mirror-Quads $wantX; $wantZ = Mirror-Quads $wantZ }
    Set-AutoRotate 1
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id $x; $a = Open-Viewer $id
        Focus-File $id $z; $b = Open-Viewer $id
        if ($a -eq [IntPtr]::Zero -or $b -eq [IntPtr]::Zero -or $a -eq $b) { Row $Case 'OPEN' 'FAIL' 'two viewer windows did not open'; return }
        if ($UserMirror) { Post-Cmd $b 120; Start-Sleep -Milliseconds 800 }   # CMD_MIRROR_HOR by the user
        $b0 = Shown-Quads $id $b ($Out + '\' + $Case + '-b0.png')
        Row $Case 'B-BEFORE' (V ($b0 -eq $wantZ)) ("B shows z.jpg ({0}{1}) before: {2} (want {3})" -f $ZFix, $(if ($UserMirror) { ', mirrored by the user' } else { '' }), $b0, $wantZ)
        $boxes = Rename-Shown $id $a 'z.jpg' @(6, 2, 1) @($b)
        Start-Sleep -Milliseconds 4000
        $tb = Title $b
        $b1 = Shown-Quads $id $b ($Out + '\' + $Case + '-b1.png')
        Row $Case 'B-AFTER' (V ($b1 -eq $wantX)) ("A renamed x.jpg ({0}) onto z.jpg; B title size {1}, shows {2} (want {3}); boxes: {4}; x exists {5}" -f $XFix, (Dims $tb), $b1, $wantX, $boxes, (Exists $x))
        foreach ($w in @($b, $a)) { Close-Viewer $id $w }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- main ------------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc267_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Out
    Make-Fixtures
    Set-Config
    Out ("pv267_probe (feature 267)")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; desktop '{2}'; registry key existed {3}; backup SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), [DeskLib098]::Name(), $existed, $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '-' }))
    Out ''
    for ($o = 1; $o -le 8; $o++) { Run-Row ('o' + $o) ('o' + $o + '.jpg') ('o' + $o + '.jpg') $true $true }
    Run-Row 'o6-nodims' 'o6-nodims.jpg' 'o6-nodims.jpg' $true $true
    Run-Row 'o6-moddims' 'o6-moddims.jpg' 'o6-moddims.jpg' $true $true
    Run-Row 'noexif' 'noexif.jpg' 'noexif.jpg' $false $false
    Run-Row 'xmp' 'xmp.jpg' 'xmp.jpg' $false $false
    Run-Row 'uni' 'o6.jpg' $UniName $true $true
    Run-Row 'off' 'o6.jpg' 'o6.jpg' $false $true 0
    Run-Row 'tif6' 'o6.tif' 'o6.tif' $false $false
    Run-Keep 'keep-ctl' 'o2.jpg' 'noexif.jpg'
    Run-Keep 'keep-o6' 'o6.jpg' 'o6.jpg'
    Run-Keep 'keep-o2' 'o2.jpg' 'o2.jpg'
    Run-Keep 'keep-o5' 'o5.jpg' 'o5.jpg'
    Run-Keep 'keep-user6' 'o6.jpg' 'o6.jpg' -UserMirror
    Run-Real 'real-land6' 'jpg\orientation\landscape_6.jpg' $true
    Run-Real 'real-land5' 'jpg\orientation\landscape_5.jpg' $true
    Run-Real 'real-port8' 'jpg\orientation\portrait_8.jpg' $true
    Run-Real 'real-canon6' 'jpg\hdr\canon_hdr_YES.jpg' $true
    Run-Real 'real-nokia6' 'jpg\mobile\HMD_Nokia_8.3_5G_hdr.jpg' $true
    Run-Real 'real-kodak1' 'jpg\Kodak_CX7530.jpg' $true
    Run-Real 'real-noexif' 'jpg\exif-org\olympus-d320l.jpg' $false
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try {
        if ([IO.Directory]::Exists($LP + $Root)) {
            foreach ($f in @([IO.Directory]::GetFiles($LP + $Root, '*', 'AllDirectories'))) { [IO.File]::SetAttributes($f, 'Normal') }
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
