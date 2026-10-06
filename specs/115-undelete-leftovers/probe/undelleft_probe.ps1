<#
.SYNOPSIS
    Feature 115 probe: the leftovers of 114 in the Undelete plug-in - Restore Encrypted Files
    walks any depth and never restores a folder's files into another folder; {All Deleted Files}
    loses its true duplicates and keeps different small files of one name; names that are one
    name for Windows (C-caron.txt / c-caron.txt) are numbered; F3 on a deleted file with a long
    name shows that file. On the build of this feature (-Expect fixed) and on the build before it
    (-Expect before, Debug_x64_pre115, the control).

.DESCRIPTION
    Fixtures under %TEMP%\tc115_un (removed at the end): make_images115.py writes two disk
    images (ordinary files - no volume is opened, no admin needed), 114's long-name image and
    expected115.json; the Restore Encrypted Files rows use ordinary folders (plain files, NO
    .bak backups - nothing is handed to the EFS import, no EFS key or certificate is used or
    created; the probe refuses when the fixture root is encrypted and checks afterwards that the
    number of EFS certificates of the user did not change and no restored file is encrypted).

    Rows (names for -Only):
      fat       fatdup115.ima, {All Deleted Files} restored with F5 into an empty folder:
                dupe   one dupe.txt (one file read twice through two deleted directory entries
                       of one cluster; the build before: "dupe (1).txt" + "dupe (2).txt")
                tiny   "same (1).txt" + "same (2).txt", two different 12-byte files (the build
                       before: ONE - its memcmp of 12 bytes of DATA_POINTERS removed the other)
                caron  "<C-caron> (k).txt" + "<c-caron> (k).txt" (numbered in the listing; the
                       build before: one of them, after an overwrite prompt answered Skip)
                PROMPTS (overwrite prompts: none / at least one), EXTRA, END
      exfat     exfatnum115.ima: caron (numbered by the restore list) and the ASCII control
                a.txt / A.txt (numbered by both builds)
      view      F3 on a deleted file of 114's long-name image (334-byte CJK name): BOTH builds -
                the core's disk cache refuses a temporary name of MAX_PATH+ bytes ("The resulting
                filename is too long", cache.cpp CCacheDirData::GetName) before the plug-in copies
                anything; no fatal window, no file (GUI run 1 corrected the expectation: the
                plug-in's cut of that name was unreachable)
      enc-deep  Restore Encrypted Files from Backup on a folder 15 levels deep (UTF-8 names,
                ~650 bytes): every file restored in its own folder, no message (the build
                before: GetDirSize recursed into the same folder at 259 bytes - a crash)
      enc-long  the source panel in a folder of 260+ bytes: x.txt and sub\y.txt restored (the
                build before read the panel path into MAX_PATH bytes unchecked: "" - relative
                names, an error and an empty "sub")
      enc-loop  a folder holding a directory junction to itself: its files restored, the
                junction reported once (Skip), nothing restored twice (the build before: a
                crash)
    The Restore Encrypted Files command has no key: the probe gives it Ctrl+Shift+U for the
    session (registry, the plug-in's menu item 2, "dirty" so the plug-in keeps it; restored with
    the whole key afterwards). When that does not open the Restore dialog the enc rows are
    NOT DRIVEN (person step: Plugins > Undelete > Restore Encrypted Files from Backup).
    -Expect before: a row PASSes when the build before shows the defect where predicted.
    NOT DRIVEN (recorded): real EFS backups (.bak with the ROBS signature) - they need an
    EFS-encrypted file and so a user EFS certificate, which this machine does not have and the
    probe must not create; NTFS; the cut-.bak deletion and the target-path refusal of the main
    restore (need EFS files on an NTFS volume opened raw - admin).

    MUST run through tools\run_on_hidden_desktop.ps1 (refuses on the Default desktop). Refuses
    while any tandemcommander.exe runs. HKCU\Software\Tandem Commander exported before,
    restored and SHA-256-verified after. Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }
if (-not ('Drv115' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv115
{
    [DllImport("user32.dll")] public static extern IntPtr GetThreadDesktop(uint threadId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool GetUserObjectInformationW(IntPtr h, int index, StringBuilder info, int length, out int needed);
    public static string DesktopName()
    {
        var sb = new StringBuilder(256); int needed;
        if (!GetUserObjectInformationW(GetThreadDesktop(GetCurrentThreadId()), 2, sb, sb.Capacity * 2, out needed)) return "";
        return sb.ToString();
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool GetVolumeInformationW(string root, StringBuilder name, int nameSize, out uint serial, out uint maxComp, out uint flags, StringBuilder fs, int fsSize);
    public static uint VolumeFlags(string root)
    {
        var n = new StringBuilder(261); var f = new StringBuilder(261); uint s, m, fl;
        if (!GetVolumeInformationW(root, n, 261, out s, out m, out fl, f, 261)) return 0xFFFFFFFF;
        return fl;
    }
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift): the probe thread shares the target thread's
    // input state and sets the key-state table - no real key press (the 100/102/104 method)
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
$deskName = [Drv115]::DesktopName()
if (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon') { Write-Output ("REFUSED: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 98 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Fixed = ($Expect -eq 'fixed')
$Root = $TempRoot + '\tc115_un'
$StartDir = $Root + '\start'
$ImgDir = $Root + '\img'
$EncRoot = $Root + '\enc'
$AllDeleted = '{All Deleted Files}'
$EfsEku = '1.3.6.1.4.1.311.10.3.4'
$script:HotKeyNote = 'not set'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Start-P([string]$Left, [string]$Right) {
    $a = @('-t', 'T115', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
function End-P([string]$Case, [int]$Id, $Before) {
    if (Test-Alive $Id) {
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
        Start-Sleep -Milliseconds 800
    }
    End-Row $Case $Id $null $Before
}
function Units([object[]]$u) { return -join ($u | ForEach-Object { [char][int]$_ }) }
# name -> content of the files of a folder, names compared exactly (ordinal)
function Folder-Map([string]$dir) {
    $m = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    if (-not [IO.Directory]::Exists($LP + $dir)) { return , $m }
    foreach ($e in [IO.Directory]::GetFiles($LP + $dir)) {
        $n = $e.Substring($e.LastIndexOf('\') + 1)
        $m[$n] = [IO.File]::ReadAllText($e, (New-Object Text.ASCIIEncoding))
    }
    return , $m
}
# every file below a folder: relative path -> content
function Tree-Map([string]$dir) {
    $m = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    if (-not [IO.Directory]::Exists($LP + $dir)) { return , $m }
    $base = ($LP + $dir).Length + 1
    foreach ($e in [IO.Directory]::GetFiles($LP + $dir, '*', [IO.SearchOption]::AllDirectories)) {
        $m[$e.Substring($base)] = [IO.File]::ReadAllText($e, (New-Object Text.ASCIIEncoding))
    }
    return , $m
}
function Efs-Certs { return @(Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.EnhancedKeyUsageList.ObjectId -contains $EfsEku }).Count }

# ---- {All Deleted Files} of an image ---------------------------------------------------------
function Open-Deleted([int]$Id, [string]$Image) {
    $target = 'del:' + $Image + '\' + $AllDeleted
    [void](Do-ChangeDir $Id $target)
    $r = Serve $Id 60 @(1, 6)
    if ($r.Fatal) { return @{ Ok = $false; Facts = ('FATAL ' + $r.Fatal) } }
    Sync $Id
    $loc = Get-Loc $Id
    return @{ Ok = ($loc -like ('*' + $AllDeleted)); Facts = ('panel: ' + (Tail $loc 60) + '; windows: ' + (Msgs $r)) }
}
# select all, F5 into the other panel; every box answered Skip / Yes / OK; overwrite prompts counted
function Restore-All([int]$Id) {
    $res = [pscustomobject]@{ Boxes = New-Object System.Collections.ArrayList; Overwrite = 0; Fatal = $null }
    Post-Cmd (Get-Main $Id) 842; Start-Sleep -Milliseconds 1500; Sync $Id
    $dlg = Open-ByCmd $Id 727 15
    if ($dlg -eq [IntPtr]::Zero) { $res.Fatal = 'Copy (727) opened no window'; return $res }
    $d0 = WinDesc $dlg
    if ($d0 -match $FatalRx) { $res.Fatal = $d0; return $res }
    Click-Ok $dlg
    $s = Serve-Op $Id 120
    $res.Fatal = $s.Fatal; $res.Boxes = $s.Boxes
    $res.Overwrite = @($s.Boxes | Where-Object { $_ -match 'exist|overwrit' }).Count
    return $res
}
# serves an operation until idle: a fatal window ends it; every other box is answered Skip (173),
# Yes (6) or OK (1)
function Serve-Op([int]$Id, [double]$Seconds) {
    $res = [pscustomobject]@{ Boxes = New-Object System.Collections.ArrayList; Raw = New-Object System.Collections.ArrayList; Fatal = $null }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not (Test-Alive $Id)) { $res.Fatal = 'the program ended (exit ' + (ExitCodeOf $Id) + ')'; break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.5 -and [Drv098f]::IsWindowEnabled((Get-Main $Id))) { break }
            Start-Sleep -Milliseconds 150; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $res.Fatal = $d; return $res }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) { continue }   # progress
            [void]$res.Boxes.Add($d)
            # GUI run 1: WinDesc keeps 300 + 300 characters of a long box - the full texts too
            [void]$res.Raw.Add(((@([Drv098f]::Kids($h) | ForEach-Object { [Drv098f]::Txt($_) }) -join ' | ')))
            $pick = $null
            foreach ($w in @(173, 6, 1)) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($pick) { break } }
            if ($pick) { Click $pick } else { Close-Win $h }
            $seen.Remove($key); Start-Sleep -Milliseconds 600
        }
        Start-Sleep -Milliseconds 150
    }
    return $res
}

# the files of a group in a restored folder (names equal to a member's plain or numbered name,
# case ignored) and the verdict for 'mode'
function Group-Check($G, [string]$Mode, $Map) {
    $mem = @($G.members | ForEach-Object { [pscustomobject]@{ Stem = (Units $_.stem_units); Ext = $_.ext; Content = $_.content } })
    $cands = @()
    foreach ($m in $mem) { $cands += ($m.Stem + $m.Ext); for ($k = 1; $k -le 9; $k++) { $cands += ($m.Stem + ' (' + $k + ')' + $m.Ext) } }
    $files = @($Map.Keys | Where-Object { $f = $_; @($cands | Where-Object { [string]::Equals($_, $f, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0 } | Sort-Object)
    $facts = ("{0} file(s): {1}" -f $files.Count, (($files | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', '))
    $ok = $false
    switch ($Mode) {
        'one' {
            $m = $mem[0]; $n = $m.Stem + $m.Ext
            $ok = ($files.Count -eq 1) -and ($files[0] -ceq $n) -and ($Map[$files[0]] -ceq $m.Content)
        }
        'twice' {
            $m = $mem[0]
            $ok = ($files.Count -eq 2) -and (@($files | Where-Object { ($_ -ceq ($m.Stem + ' (1)' + $m.Ext) -or $_ -ceq ($m.Stem + ' (2)' + $m.Ext)) -and $Map[$_] -ceq $m.Content }).Count -eq 2)
        }
        'anyone' {
            $ok = ($files.Count -eq 1) -and (@($mem | Where-Object { $files[0] -ceq ($_.Stem + $_.Ext) -and $Map[$files[0]] -ceq $_.Content }).Count -eq 1)
        }
        'numbered' {
            $used = @{}; $ks = @{}; $good = ($files.Count -eq $mem.Count)
            foreach ($f in $files) {
                $hit = $false
                for ($i = 0; $i -lt $mem.Count; $i++) {
                    if ($used.ContainsKey($i)) { continue }
                    $m = $mem[$i]
                    for ($k = 1; $k -le $mem.Count; $k++) {
                        if (($f -ceq ($m.Stem + ' (' + $k + ')' + $m.Ext)) -and -not $ks.ContainsKey($k) -and ($Map[$f] -ceq $m.Content)) { $used[$i] = $true; $ks[$k] = $true; $hit = $true; break }
                    }
                    if ($hit) { break }
                }
                if (-not $hit) { $good = $false }
            }
            $ok = $good
        }
    }
    return [pscustomobject]@{ Ok = $ok; Facts = $facts; Files = $files }
}

function Run-Image([string]$Case, [string]$ImageFile, $Groups) {
    $out = $Root + '\out_' + $Case; NewDir $out
    $id = 0; $before = Reports
    try {
        $id = Start-P $StartDir $out
        $o = Open-Deleted $id ($ImgDir + '\' + $ImageFile)
        Row $Case 'OPEN' (V $o.Ok) $o.Facts
        if (-not $o.Ok) { return }
        $r = Restore-All $id
        if ($r.Fatal) { Row $Case 'COPY' $(if ($Fixed) { 'FAIL' } else { 'INFO' }) ('FATAL ' + $r.Fatal); return }
        $map = Folder-Map $out
        $mine = @{}
        foreach ($g in $Groups) {
            $mode = $(if ($Fixed) { $g.fixed } else { $g.before })
            $c = Group-Check $g $mode $map
            foreach ($f in $c.Files) { $mine[$f] = $true }
            Row $Case $g.tag (V $c.Ok) ("{0} - expected '{1}' ({2})" -f $c.Facts, $mode, $g.why)
        }
        $extra = @($map.Keys | Where-Object { -not $mine.ContainsKey($_) } | Sort-Object)
        Row $Case 'EXTRA' (V ($extra.Count -eq 0)) ("{0} file(s) of no group: {1}" -f $extra.Count, (($extra | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', '))
        $wantPrompt = @($Groups | Where-Object { $_.before -eq 'anyone' -and $_.tag -eq 'caron' }).Count -gt 0
        if ($Fixed) { $v = V ($r.Overwrite -eq 0) } else { $v = V ((-not $wantPrompt) -or $r.Overwrite -ge 1) }
        Row $Case 'PROMPTS' $v ("overwrite prompts {0}; boxes {1}: {2}" -f $r.Overwrite, $r.Boxes.Count, $(if ($r.Boxes.Count) { (($r.Boxes | ForEach-Object { Tail $_ 110 }) -join ' || ') } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# F3 on a deleted file with a 334-byte name: the disk-cache copy under its full name
function Run-View($Exp) {
    $Case = 'view'
    $id = 0; $before = Reports
    $t0 = Get-Date
    try {
        $id = Start-P $StartDir $StartDir
        $o = Open-Deleted $id ($ImgDir + '\exfatdup114.ima')
        Row $Case 'OPEN' (V $o.Ok) $o.Facts
        if (-not $o.Ok) { return }
        $name = Units $Exp.name_units
        Key $id 0x24; Key $id 0x28; Sync $id   # Home, Down: the first file
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 742            # View (F3)
        $s = Serve-Op $id 25
        $copies = @()
        foreach ($d in @(Get-ChildItem -LiteralPath $TempRoot -Directory -Filter 'SAL*.tmp' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $t0.AddSeconds(-5) })) {
            foreach ($f in [IO.Directory]::GetFiles($LP + $d.FullName)) {
                $n = $f.Substring($f.LastIndexOf('\') + 1)
                $copies += [pscustomobject]@{ Dir = $d.Name; Name = $n; Content = [IO.File]::ReadAllText($f, (New-Object Text.ASCIIEncoding)) }
            }
        }
        $full = @($copies | Where-Object { $_.Name -ceq $name -and @($Exp.contents) -contains $_.Content })
        $viewer = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and [Drv098f]::Cls($_) -ne '#32770' -and $known -notcontains $_ })
        $facts = ("{0}-byte name: disk-cache files {1} ({2}); under the full name with its content {3}; viewer windows {4}; fatal {5}; boxes {6}: {7}" -f $Exp.name_bytes, $copies.Count, (($copies | ForEach-Object { $_.Dir + '\' + (Tail $_.Name 20) + ' [' + $_.Name.Length + ' units]' }) -join ', '), $full.Count, $viewer.Count, $(if ($s.Fatal) { $s.Fatal } else { 'none' }), $s.Boxes.Count, $(if ($s.Boxes.Count) { (($s.Boxes | ForEach-Object { Tail $_ 90 }) -join ' || ') } else { '-' }))
        # GUI run 1 (corrected expectation): the core's disk cache refuses a temporary name of MAX_PATH
        # bytes or more (cache.cpp CCacheDirData::GetName, DCGNE_TOOLONGNAME) BEFORE the plug-in copies
        # anything - so the plug-in's cut of that name could never happen; both builds: one message
        # ("The resulting filename is too long"), no fatal window, no file
        $tooLong = @($s.Boxes | Where-Object { $_ -match 'too long' }).Count
        $v = V ($full.Count -eq 0 -and $s.Boxes.Count -eq 1 -and $tooLong -eq 1 -and -not $s.Fatal)
        Row $Case 'VIEW' $v $facts
        foreach ($w in $viewer) { [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
        Start-Sleep -Milliseconds 1000
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- Restore Encrypted Files from Backup -----------------------------------------------------
# gives the plug-in's menu item 2 (Restore Encrypted Files) Ctrl+Shift+U for this session: the item
# loaded from the registry keeps a "dirty" key (HOTKEY_DIRTY 0x10000) when the plug-in reconnects
function Set-RestoreHotKey {
    $plugins = 'HKCU:\Software\Tandem Commander\0.1\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key' }
    foreach ($k in @(Get-ChildItem $plugins)) {
        $dll = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DLL
        if (-not $dll -or $dll -notmatch 'undelete\.spl$') { continue }
        $menu = Join-Path $k.PSPath 'Menu'
        if (-not (Test-Path $menu)) { return "plug-in $($k.PSChildName): no Menu key" }
        $set = 0
        foreach ($mi in @(Get-ChildItem $menu)) {
            $idv = (Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID
            if ($idv -eq 1) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value 0x10000 -Type DWord; $set++ }
            if ($idv -eq 2) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value 0x10355 -Type DWord; $set++ }
        }
        return "plug-in $($k.PSChildName) ($dll): $set menu item(s) set"
    }
    return 'Undelete not registered'
}
function Open-Restore([int]$Id) {
    $known = Get-Tops $Id
    $k = [Drv115]::ModKey((Get-LeftList $Id), 0x55, 3)   # Ctrl+Shift+U
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        foreach ($h in @(Get-Tops $Id | Where-Object { $known -notcontains $_ })) {
            if (Kid $h 1501 'Edit') { Start-Sleep -Milliseconds 800; return @{ Dlg = $h; Note = $k } }
            $d = WinDesc $h
            if ($d -match $FatalRx) { return @{ Dlg = [IntPtr]::Zero; Note = ('FATAL ' + $d) } }
        }
        Start-Sleep -Milliseconds 200
    }
    $new = @(Get-Tops $Id | Where-Object { $known -notcontains $_ } | ForEach-Object { WinDesc $_ })
    foreach ($h in @(Get-Tops $Id | Where-Object { $known -notcontains $_ })) { Close-Win $h }
    return @{ Dlg = [IntPtr]::Zero; Note = ('key ' + $k + '; new windows: ' + $(if ($new.Count) { $new -join ' || ' } else { 'none' })) }
}
# selects all in the left panel, runs Restore Encrypted Files into 'Target', serves it
function Run-Restore([int]$Id, [string]$Target) {
    Post-Cmd (Get-Main $Id) 842; Start-Sleep -Milliseconds 1500; Sync $Id
    $o = Open-Restore $Id
    if ($o.Dlg -eq [IntPtr]::Zero) { return [pscustomobject]@{ Opened = $false; Note = $o.Note; Boxes = @(); Raw = @(); Fatal = $(if ($o.Note -like 'FATAL*') { $o.Note } else { $null }) } }
    [void][Drv098f]::SetText((Kid $o.Dlg 1501 'Edit'), $Target, 5000)
    Click-Ok $o.Dlg
    $s = Serve-Op $Id 180
    return [pscustomobject]@{ Opened = $true; Note = $o.Note; Boxes = $s.Boxes; Raw = $s.Raw; Fatal = $s.Fatal }
}
function Make-Name([int]$Level) {   # a folder name of 42 bytes of UTF-8 (C-caron, z-caron, u-ring)
    return ([string][char]0x010C + 'ast ' + $Level.ToString('00') + ' ' + ([string][char]0x017E * 12) + ([string][char]0x016F * 4))
}
# the encrypted-route rows; returns the rows' facts
function Run-Enc([string]$Case, [string]$Left, [string]$SourceDir, [string]$Out, $Expected, [string]$Note, [string]$ExpectedBox) {
    $id = 0; $before = Reports
    try {
        $id = Start-P $Left $Out
        if ($SourceDir -ne $Left) { [void](Do-ChangeDir $id $SourceDir); [void](Serve $id 10); Sync $id }
        $r = Run-Restore $id $Out
        if (-not $r.Opened -and -not $r.Fatal) { Row $Case 'RESTORE' 'NOT DRIVEN' ('the Restore dialog did not open (' + $script:HotKeyNote + '; ' + $r.Note + ') - person step: Plugins > Undelete > Restore Encrypted Files from Backup'); return }
        $tree = Tree-Map $Out
        $miss = @(); $bad = @()
        foreach ($k in $Expected.Keys) { if (-not $tree.ContainsKey($k)) { $miss += $k } elseif ($tree[$k] -cne $Expected[$k]) { $bad += $k } }
        $extra = @($tree.Keys | Where-Object { -not $Expected.ContainsKey($_) })
        $enc = @(); if ([IO.Directory]::Exists($LP + $Out)) { $enc = @([IO.Directory]::GetFiles($LP + $Out, '*', [IO.SearchOption]::AllDirectories) | Where-Object { ([IO.File]::GetAttributes($_) -band [IO.FileAttributes]::Encrypted) -ne 0 }) }
        $boxes = @($r.Boxes)
        $raw = @($r.Raw)
        $boxOk = $(if ($ExpectedBox) { $raw.Count -eq 1 -and $raw[0] -match $ExpectedBox } else { $boxes.Count -eq 0 })
        $facts = ("{0}; expected files {1}: missing {2}, content differs {3}, extra {4}{5}; encrypted {6}; fatal {7}; boxes {8}: {9}" -f $Note, $Expected.Count, $miss.Count, $bad.Count, $extra.Count, $(if ($extra.Count) { ' [' + (($extra | Select-Object -First 4 | ForEach-Object { Tail $_ 60 }) -join ', ') + ']' } else { '' }), $enc.Count, $(if ($r.Fatal) { $r.Fatal } else { 'none' }), $boxes.Count, $(if ($raw.Count) { (($raw | ForEach-Object { Tail $_ 200 }) -join ' || ') } else { '-' }))
        if ($Fixed) { $v = V ((-not $r.Fatal) -and $miss.Count -eq 0 -and $bad.Count -eq 0 -and $extra.Count -eq 0 -and $enc.Count -eq 0 -and $boxOk) }
        else { $v = V ([bool]$r.Fatal -or $miss.Count -gt 0 -or $extra.Count -gt 0) }
        Row $Case 'RESTORE' $v $facts
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

function Run-EncRows {
    $flags = [Drv115]::VolumeFlags(([IO.Path]::GetPathRoot($TempRoot)))
    if ($flags -eq 0xFFFFFFFF -or ($flags -band 0x20000) -eq 0) {
        foreach ($c in @('enc-deep', 'enc-long', 'enc-loop')) { if (Want $c) { Row $c 'RESTORE' 'NOT DRIVEN' ('the volume of %TEMP% does not report FILE_SUPPORTS_ENCRYPTION (flags 0x{0:X8}) - the command refuses' -f $flags) } }
        return
    }
    NewDir $EncRoot
    if (([IO.File]::GetAttributes($LP + $EncRoot) -band [IO.FileAttributes]::Encrypted) -ne 0) {
        Row 'enc' 'SAFETY' 'FAIL' 'the fixture folder is encrypted (EFS) - the encrypted rows are not run'
        return
    }
    $certs0 = Efs-Certs

    if (Want 'enc-deep') {
        $left = $EncRoot + '\a'; $out = $EncRoot + '\outa'; NewDir $left; NewDir $out
        $exp = @{}
        $p = $left + '\deep'; $rel = 'deep'; NewDir $p
        WriteFile ($p + '\top.txt') 'TC115 enc top'; $exp[$rel + '\top.txt'] = 'TC115 enc top'
        for ($i = 1; $i -le 15; $i++) {
            $n = Make-Name $i; $p = $p + '\' + $n; $rel = $rel + '\' + $n; NewDir $p
            $c = 'TC115 enc level ' + $i; WriteFile ($p + '\soubor ' + $i + '.txt') $c; $exp[$rel + '\soubor ' + $i + '.txt'] = $c
        }
        $note = ("source tree 16 levels, deepest file {0} bytes of UTF-8 (MAX_PATH 260, 2 x MAX_PATH 520)" -f (U8Len ($p + '\soubor 15.txt')))
        Run-Enc 'enc-deep' $left $left $out $exp $note $null
    }
    if (Want 'enc-long') {
        $left = $EncRoot + '\l'; $out = $EncRoot + '\outl'; NewDir $left; NewDir $out
        $p = $left; while ((U8Len $p) -lt 300) { $p = $p + '\' + (Make-Name 99) }
        NewDir ($p + '\sub')
        WriteFile ($p + '\x.txt') 'TC115 long x'; WriteFile ($p + '\sub\y.txt') 'TC115 long y'
        $exp = @{ 'x.txt' = 'TC115 long x'; 'sub\y.txt' = 'TC115 long y' }
        $note = ("source panel {0} bytes of UTF-8" -f (U8Len $p))
        Run-Enc 'enc-long' $left $p $out $exp $note $null
    }
    if (Want 'enc-loop') {
        $left = $EncRoot + '\p'; $out = $EncRoot + '\outp'; $loop = $left + '\loop'; NewDir $loop; NewDir ($loop + '\b'); NewDir $out
        WriteFile ($loop + '\a.txt') 'TC115 loop a'; WriteFile ($loop + '\b\c.txt') 'TC115 loop c'
        $mk = & cmd.exe /c ('mklink /J "' + $loop + '\back" "' + $loop + '"') 2>&1
        if (-not [IO.Directory]::Exists($loop + '\back')) { Row 'enc-loop' 'RESTORE' 'NOT DRIVEN' ('the junction could not be made: ' + $mk) }
        else {
            $exp = @{ 'loop\a.txt' = 'TC115 loop a'; 'loop\b\c.txt' = 'TC115 loop c' }
            # GUI run 1: the box's name field is drawn by the core (no window text) - the error code identifies it
            Run-Enc 'enc-loop' $left $left $out $exp 'loop\back = a directory junction to loop' '\(1921\)'
        }
        & cmd.exe /c ('rmdir "' + $loop + '\back"') 2>&1 | Out-Null   # the link only, never what it points to
    }
    $certs1 = Efs-Certs
    Row 'enc' 'EFS' (V ($certs1 -eq $certs0)) ("EFS certificates of the user before {0}, after {1} (no .bak backup in the fixtures: nothing reaches the EFS import)" -f $certs0, $certs1)
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc115_un_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $ImgDir
    $gen = & $Python (Join-Path $PSScriptRoot 'make_images115.py') $ImgDir 2>&1
    $exp = Get-Content -LiteralPath ($ImgDir + '\expected115.json') -Raw | ConvertFrom-Json
    Set-Config
    $script:HotKeyNote = Set-RestoreHotKey
    Out ("undelleft_probe (feature 115), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; images made for OEM {2}; desktop '{3}'; registry key existed {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $exp.oemcp, $deskName, $existed)
    Out ("Images  : {0}" -f (($gen | ForEach-Object { '' + $_ }) -join ' '))
    Out ("Hot key : {0}" -f $script:HotKeyNote)
    Out ''
    if (Want 'fat') { Run-Image 'fat' 'fatdup115.ima' $exp.fat }
    if (Want 'exfat') { Run-Image 'exfat' 'exfatnum115.ima' $exp.exfat }
    if (Want 'view') { Run-View $exp.view }
    if ((Want 'enc-deep') -or (Want 'enc-long') -or (Want 'enc-loop')) { Run-EncRows }
    if (-not $Only) {
        foreach ($nd in @('real EFS backups (.bak with the ROBS signature): they need an EFS-encrypted file, so a user EFS certificate - none exists on this machine and the probe must not create one',
                          'NTFS images and EFS-encrypted deleted files (the cut .bak deletion, the bounded UndeleteGetResolvedRootPath): need admin rights / a raw volume')) { Row 'nd' 'ROUTE' 'NOT DRIVEN' $nd }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try {
        foreach ($j in @(($EncRoot + '\p\loop\back'))) { if ([IO.Directory]::Exists($j)) { & cmd.exe /c ('rmdir "' + $j + '"') 2>&1 | Out-Null } }
        if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
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
