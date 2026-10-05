<#
.SYNOPSIS
    Feature 117 probe: the Checksum plug-in's Verify reads a list in the encoding it was written
    in (UTF-8 with or without a mark, UTF-16 LE / BE with or without a mark, the code page),
    resolves "./" and "..", never matches a wildcard or a look-alike, and its own Calculate >
    Save writes lists that GNU coreutils and 7-Zip read back. On the build of this feature
    (-Expect fixed) and on the build before it (-Expect before, Debug_x64_pre117, the control).

.DESCRIPTION
    Fixtures under %TEMP%\tc117_cs (removed at the end), made by make_lists117.py: data\ holds
    files named in Czech, Cyrillic, CJK, with a lone surrogate, the look-alike pair voila-grave /
    voila (different content - a wrong match shows as CORRUPT), abc.txt (what "???.txt" would
    match as a wildcard), sub\r-caron.txt, and 13 lists; rt\ holds 7 files for the round trip.
    expected117.json carries the verdict of every list row for both builds.

    Rows (names for -Only):
      <list file name>  one per list (utf8.sha256 ... wild.sha256): Verify through the plug-in's
                key Ctrl+Shift+V on the focused list; every row's verdict (the list view's icon:
                OK / CORRUPT / MISSING; a status text without an icon = SKIPPED after an error box
                answered Skip) and, on -Expect fixed, the name shown. A list the build refuses
                ("not a checksum file") = BADFILE. Fixed: no box at all.
      rt        Calculate (select all in rt\, the plug-in's menu item 1 given Ctrl+Shift+U for the
                session) > Save as .sha256 and as .sfv: the bytes (fixed: no mark, LF, no comment
                for .sha256; CRLF + ';' header for .sfv; before: CRLF + header for both), Verify of
                both (all OK on both builds), "sha256sum -c" of Git for Windows and "7z t -thash"
                (fixed: both read it; before: both fail). A tool that is not installed = NOT DRIVEN.
    The code-page lists (cp1250_setcontent, opensal.sfv, oem852.md5) assume ACP 1250 / OEM 852
    (this machine); on another code page they are NOT DRIVEN.

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
if (-not ('Drv117' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv117
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
    [DllImport("kernel32.dll")] public static extern uint GetOEMCP();
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendGetBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr addr, UIntPtr size, uint type, uint protect);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool VirtualFreeEx(IntPtr p, IntPtr addr, UIntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool WriteProcessMemory(IntPtr p, IntPtr addr, byte[] buf, UIntPtr size, out UIntPtr done);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool ReadProcessMemory(IntPtr p, IntPtr addr, byte[] buf, UIntPtr size, out UIntPtr done);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    public static string LbText(IntPtr combo, int index)
    {
        long len = SendR(combo, 0x0149 /*CB_GETLBTEXTLEN*/, index, 0);
        if (len < 0) return null;
        var buf = new char[len + 2]; IntPtr r;
        SendGetBuf(combo, 0x0148 /*CB_GETLBTEXT*/, (IntPtr)index, buf, 0, 5000, out r);
        long n = r.ToInt64(); if (n < 0) return null; if (n > len) n = len;
        return new string(buf, 0, (int)n);
    }
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift): the probe thread shares the target thread's
    // input state and sets the key-state table - no real key press (the 100/102/104/115 method)
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
    // one cell of a list view in another (64-bit) process: LVM_GETITEMW with an LVITEMW and a
    // text buffer allocated in the target; the text is read from the pointer the owner left in
    // the structure (an owner-data list may point it at its own buffer). Lone surrogates kept.
    public static string LvItem(IntPtr lv, int item, int sub, out int image)
    {
        image = -1;
        uint pid; GetWindowThreadProcessId(lv, out pid);
        IntPtr hp = OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid);
        if (hp == IntPtr.Zero) return null;
        IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, (UIntPtr)8192, 0x3000, 0x04);
        if (mem == IntPtr.Zero) { CloseHandle(hp); return null; }
        try
        {
            UIntPtr n;
            WriteProcessMemory(hp, mem, new byte[8192], (UIntPtr)8192, out n);
            var it = new byte[88];
            BitConverter.GetBytes((uint)(sub == 0 ? 3 : 1)).CopyTo(it, 0);   // LVIF_TEXT | LVIF_IMAGE
            BitConverter.GetBytes(item).CopyTo(it, 4);
            BitConverter.GetBytes(sub).CopyTo(it, 8);
            BitConverter.GetBytes(mem.ToInt64() + 1024).CopyTo(it, 24);       // pszText
            BitConverter.GetBytes(2048).CopyTo(it, 32);                        // cchTextMax
            WriteProcessMemory(hp, mem, it, (UIntPtr)88, out n);
            IntPtr r;
            if (SendMessageTimeoutW(lv, 0x104B /*LVM_GETITEMW*/, IntPtr.Zero, mem, 0, 10000, out r) == IntPtr.Zero) return null;
            ReadProcessMemory(hp, mem, it, (UIntPtr)88, out n);
            image = BitConverter.ToInt32(it, 36);
            IntPtr textPtr = (IntPtr)BitConverter.ToInt64(it, 24);
            var tb = new byte[4096];
            if (!ReadProcessMemory(hp, textPtr, tb, (UIntPtr)4096, out n)) return null;
            var chars = new char[2048];
            Buffer.BlockCopy(tb, 0, chars, 0, 4096);
            int z = Array.IndexOf(chars, '\0'); if (z < 0) z = chars.Length;
            return new string(chars, 0, z);
        }
        finally { VirtualFreeEx(hp, mem, UIntPtr.Zero, 0x8000); CloseHandle(hp); }
    }
}
'@
}
$deskName = [Drv117]::DesktopName()
if (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon') { Write-Output ("REFUSED: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 98 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Fixed = ($Expect -eq 'fixed')
$Root = $TempRoot + '\tc117_cs'
$DataDir = $Root + '\data'
$RtDir = $Root + '\rt'
$NotifyCodes = @(9, 1)   # CBN_SELENDOK, CBN_SELCHANGE
$script:HotKeyNote = 'not set'
$CodePageLists = @('cp1250_setcontent.sha256', 'opensal.sfv', 'oem852.md5')

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Start-P([string]$Left, [string]$Right) {
    $a = @('-t', 'T117', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
function Combo-Items([IntPtr]$C) {
    if (-not $C) { return @() }
    $n = [Drv117]::SendR($C, 0x0146, 0, 0); $l = @()
    for ($i = 0; $i -lt $n; $i++) { $l += [Drv117]::LbText($C, $i) }
    return $l
}
function Pick([IntPtr]$C, [string]$Rx) {
    if (-not $C) { return $false }
    $items = @(Combo-Items $C)
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($items[$i] -match $Rx) {
            [void][Drv117]::SendR($C, 0x014E, $i, 0)
            $cid = [Drv098f]::GetDlgCtrlID($C); $par = [Drv098f]::GetParent($C)
            foreach ($code in $NotifyCodes) { [void][Drv117]::SendR($par, 0x0111, (($code -shl 16) -bor $cid), $C.ToInt64()) }
            Start-Sleep -Milliseconds 300
            return $true
        }
    }
    return $false
}
# answers a box: Skip (173), else OK (1), Yes (6), else Cancel - never Retry
function Answer-Box([IntPtr]$H) {
    $btn = Buttons $H
    $pick = $null
    foreach ($w in @(173, 1, 6, 2)) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($pick) { break } }
    if ($pick) { Click $pick } else { Close-Win $H }
}
function Is-VerifyDlg([IntPtr]$H) { return [bool]((Kid $H 1001 'SysListView32') -and (Kid $H 2002 $null)) }
function Verdict([int]$Image, [string]$Status) {
    switch ($Image) { 3 { return 'OK' } 2 { return 'CORRUPT' } 1 { return 'MISSING' } }
    if ($Status) { return 'SKIPPED' }
    return 'NONE'
}

# focuses the list file in the left panel, Ctrl+Shift+V, serves boxes, reads the result
function Verify-List([int]$Id, [string]$Full) {
    $res = [pscustomobject]@{ Opened = $false; Done = $false; Boxes = New-Object System.Collections.ArrayList; Rows = @(); Label = ''; Fatal = $null; Note = '' }
    [void](Do-ChangeDir $Id $Full); Start-Sleep -Milliseconds 500; Sync $Id
    $known = Get-Tops $Id
    $res.Note = [Drv117]::ModKey((Get-LeftList $Id), 0x56, 3)   # Ctrl+Shift+V
    $dlg = [IntPtr]::Zero; $seen = @{}; $goneSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 90) {
        if (-not (Test-Alive $Id)) { $res.Fatal = 'the program ended (exit ' + (ExitCodeOf $Id) + ')'; break }
        foreach ($h in @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -ne $MainClass })) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            if (Is-VerifyDlg $h) { if ($dlg -eq [IntPtr]::Zero) { $dlg = $h; $res.Opened = $true }; continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $res.Fatal = $d; return $res }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            [void]$res.Boxes.Add($d); Answer-Box $h; $seen.Remove($key); Start-Sleep -Milliseconds 500
        }
        if ($dlg -ne [IntPtr]::Zero) {
            if (-not [Drv098f]::IsWindow($dlg) -or -not [Drv098f]::IsWindowVisible($dlg)) {
                if ($null -eq $goneSince) { $goneSince = $sw.Elapsed.TotalSeconds }
                if ($sw.Elapsed.TotalSeconds - $goneSince -gt 1.5) { break }   # closed itself (a refused list)
            }
            else {
                $lbl = Kid $dlg 2002 $null
                if ($lbl -and [Drv098f]::IsWindowVisible($lbl)) { $res.Done = $true; Start-Sleep -Milliseconds 400; break }
            }
        }
        elseif ($sw.Elapsed.TotalSeconds -gt 20) { break }
        Start-Sleep -Milliseconds 150
    }
    if ($res.Done) {
        $res.Label = [Drv098f]::Txt((Kid $dlg 2002 $null))
        $lv = Kid $dlg 1001 'SysListView32'
        $n = [Drv117]::SendR($lv, 0x1004, 0, 0)
        $rows = @()
        for ($i = 0; $i -lt $n; $i++) {
            $img = -1; $junk = -1
            $name = [Drv117]::LvItem($lv, $i, 0, [ref]$img)
            $status = [Drv117]::LvItem($lv, $i, 2, [ref]$junk)
            $rows += [pscustomobject]@{ Name = $name; Image = $img; Status = $status; Verdict = (Verdict $img $status) }
        }
        $res.Rows = $rows
        $close = Kid $dlg 1004 'Button'
        if ($close) { Click $close } else { [void][Drv098f]::PostMessageW($dlg, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
        $sw2 = [Diagnostics.Stopwatch]::StartNew(); while ($sw2.Elapsed.TotalSeconds -lt 5 -and [Drv098f]::IsWindow($dlg)) { Start-Sleep -Milliseconds 100 }
    }
    foreach ($h in @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h }
    return $res
}
function Show([string]$s) { if ($null -eq $s) { return '<null>' }; return (Esc $s) }

function Run-List([int]$Id, $L) {
    $case = $L.file
    if (($CodePageLists -contains $L.file) -and ($Exp.acp -ne 1250 -or $Exp.oemcp -ne 852)) { Row $case 'LIST' 'NOT DRIVEN' ("the fixture is written for ACP 1250 / OEM 852; this machine: {0} / {1}" -f $Exp.acp, $Exp.oemcp); return }
    $r = Verify-List $Id ($DataDir + '\' + $L.file)
    $boxes = $(if ($r.Boxes.Count) { (($r.Boxes | ForEach-Object { Tail $_ 110 }) -join ' || ') } else { 'none' })
    if ($r.Fatal) { Row $case 'LIST' 'FAIL' ('FATAL ' + $r.Fatal); return }
    $badfile = (-not $r.Done) -and $r.Opened
    $facts = ("{0}; opened {1}, done {2}, rows {3}; result '{4}'; boxes {5}: {6}" -f $L.what, $r.Opened, $r.Done, @($r.Rows).Count, (Show $r.Label), $r.Boxes.Count, $boxes)
    if (-not $Fixed -and $L.before_list -eq 'BADFILE') {
        Row $case 'LIST' (V ($badfile -and $r.Boxes.Count -ge 1)) ('expected: refused (not a checksum file); ' + $facts)
        return
    }
    $listOk = $r.Done -and (@($r.Rows).Count -eq @($L.rows).Count)
    if ($Fixed) { $listOk = $listOk -and $r.Boxes.Count -eq 0 }
    else { $wantBox = @($L.rows | Where-Object { $_.before -eq 'SKIPPED' }).Count -gt 0; $listOk = $listOk -and (($r.Boxes.Count -ge 1) -eq $wantBox) }
    Row $case 'LIST' (V $listOk) $facts
    for ($i = 0; $i -lt @($L.rows).Count; $i++) {
        $e = $L.rows[$i]
        $want = $(if ($Fixed) { $e.after } else { $e.before })
        if ($i -ge @($r.Rows).Count) { Row $case ('#' + $i) 'FAIL' ("no row; expected {0} '{1}'" -f $want, (Show $e.name)); continue }
        $g = $r.Rows[$i]
        $ok = ($g.Verdict -eq $want)
        if ($Fixed) { $ok = $ok -and ($g.Name -ceq $e.name) }
        Row $case ('#' + $i) (V $ok) ("{0} (icon {1}, status '{2}') expected {3}; name '{4}'{5}{6}" -f $g.Verdict, $g.Image, (Show $g.Status), $want, (Show $g.Name), $(if ($g.Name -cne $e.name) { " (list: '" + (Show $e.name) + "')" } else { '' }), $(if ($e.why) { ' - ' + $e.why } else { '' }))
    }
}

# ---- the round trip ---------------------------------------------------------------------------
# gives the plug-in's Calculate (menu item ID 1) Ctrl+Shift+U and Verify (ID 2) Ctrl+Shift+V for this
# session (registry, "dirty" so the plug-in keeps them; the whole key is restored afterwards)
function Set-CsumHotKeys {
    $plugins = 'HKCU:\Software\Tandem Commander\0.1\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key' }
    foreach ($k in @(Get-ChildItem $plugins)) {
        $dll = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DLL
        if (-not $dll -or $dll -notmatch 'checksum\.spl$') { continue }
        $menu = Join-Path $k.PSPath 'Menu'
        if (-not (Test-Path $menu)) { return "plug-in $($k.PSChildName): no Menu key" }
        $set = 0
        foreach ($mi in @(Get-ChildItem $menu)) {
            $idv = (Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID
            if ($idv -eq 1) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value 0x10355 -Type DWord; $set++ }
            if ($idv -eq 2) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value 0x10356 -Type DWord; $set++ }
        }
        return "plug-in $($k.PSChildName) ($dll): $set menu item(s) set"
    }
    return 'Checksum not registered (the built-in Ctrl+Shift+V stays; Calculate has no key)'
}
function Wait-Enabled([IntPtr]$B, [double]$Seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if ([Drv098f]::IsWindowEnabled($B)) { return $true }; Start-Sleep -Milliseconds 200 }
    return $false
}
# Save in the Calculate dialog: the type picked by $TypeRx, the name typed without extension
function Save-List([int]$Id, [IntPtr]$Calc, [string]$TypeRx, [string]$Base) {
    $known = Get-Tops $Id
    Click (Kid $Calc 1003 'Button')
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 1136 'ComboBox') }) | Select-Object -First 1
        if ($c) { Start-Sleep -Milliseconds 1200; $od = $c }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) { return 'no save dialog' }
    $types = Kid $od 1136 'ComboBox'
    if (-not (Pick $types $TypeRx)) { $t = (Combo-Items $types) -join ' / '; Post-Cmd $od 2; return "type $TypeRx not offered: $t" }
    $fn = @([Drv098f]::Kids($od) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148 }) | Select-Object -First 1
    if (-not $fn) { Post-Cmd $od 2; return 'no file name field' }
    [void][Drv098f]::SetText($fn, $Base, 5000)
    $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
    if ($ok) { Click $ok } else { Post-Cmd $od 1 }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 800
    $extra = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and $_ -ne $od -and [Drv098f]::Cls($_) -eq '#32770' })
    foreach ($x in $extra) { $d = WinDesc $x; Answer-Box $x; return ('box after Save: ' + (Tail $d 120)) }
    return 'ok'
}
function Bytes-Facts([string]$File) {
    $b = [IO.File]::ReadAllBytes($LP + $File)
    $cr = @($b | Where-Object { $_ -eq 13 }).Count; $lf = @($b | Where-Object { $_ -eq 10 }).Count
    $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
    $text = (New-Object Text.UTF8Encoding($false, $true)).GetString($b)
    $hdr = $text.StartsWith(';') -or $text.StartsWith('#')
    return [pscustomobject]@{ Len = $b.Length; CR = $cr; LF = $lf; Bom = $bom; Header = $hdr; Text = $text }
}
function Run-RoundTrip {
    $Case = 'rt'
    $id = 0; $before = Reports
    try {
        $id = Start-P $RtDir $RtDir
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 1500; Sync $id   # select all
        $known = Get-Tops $id
        $k = [Drv117]::ModKey((Get-LeftList $id), 0x55, 3)                     # Ctrl+Shift+U = Calculate
        $calc = [IntPtr]::Zero
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $calc -eq [IntPtr]::Zero) {
            foreach ($h in @(Get-Tops $id | Where-Object { $known -notcontains $_ })) { if (Kid $h 1003 'Button') { $calc = $h } }
            Start-Sleep -Milliseconds 200
        }
        if ($calc -eq [IntPtr]::Zero) { Row $Case 'CALC' 'NOT DRIVEN' ('the Calculate dialog did not open (' + $script:HotKeyNote + '; key ' + $k + ') - person step: Plugins > Checksum > Calculate, Save as .sha256 and .sfv'); return }
        Start-Sleep -Milliseconds 1000
        $en = Wait-Enabled (Kid $calc 1003 'Button') 60
        $saves = @{}
        foreach ($t in @(@{ Ext = 'sha256'; Rx = '\*\.sha256' }, @{ Ext = 'sfv'; Rx = '\*\.sfv' })) {
            $s = Save-List $id $calc $t.Rx ($RtDir + '\roundtrip117')
            $f = $RtDir + '\roundtrip117.' + $t.Ext
            $saves[$t.Ext] = [IO.File]::Exists($LP + $f)
            if (-not $saves[$t.Ext]) { Row $Case ('SAVE-' + $t.Ext) 'FAIL' ("save: {0}; the file {1} does not exist (Save enabled {2})" -f $s, (Tail $f 50), $en); continue }
            $bf = Bytes-Facts $f
            $lines = @($bf.Text -split "`r?`n" | Where-Object { $_ -ne '' })
            if ($t.Ext -eq 'sha256') {
                $want = $(if ($Fixed) { (-not $bf.Bom) -and $bf.CR -eq 0 -and -not $bf.Header } else { $bf.CR -gt 0 -and $bf.Header })
                $shape = @($lines | Where-Object { $_ -match '^[0-9a-f]{64}  \S' }).Count
            }
            else {
                $want = (-not $bf.Bom) -and $bf.CR -eq $bf.LF -and $bf.Header
                $shape = @($lines | Where-Object { $_ -match '  [0-9a-f]{8}$' }).Count
            }
            Row $Case ('SAVE-' + $t.Ext) (V ($want -and $shape -eq 7)) ("save: {0}; {1} bytes, mark {2}, CR {3}, LF {4}, comment header {5}, checksum lines {6} of 7" -f $s, $bf.Len, $bf.Bom, $bf.CR, $bf.LF, $bf.Header, $shape)
        }
        $close = Kid $calc 1004 'Button'; if ($close) { Click $close } else { [void][Drv098f]::PostMessageW($calc, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
        Start-Sleep -Milliseconds 1000
        foreach ($ext in @('sha256', 'sfv')) {
            if (-not $saves[$ext]) { continue }
            $r = Verify-List $id ($RtDir + '\roundtrip117.' + $ext)
            $okc = @($r.Rows | Where-Object { $_.Verdict -eq 'OK' }).Count
            Row $Case ('VERIFY-' + $ext) (V ($r.Done -and @($r.Rows).Count -eq 7 -and $okc -eq 7 -and $r.Boxes.Count -eq 0)) ("rows {0}, OK {1}; result '{2}'; boxes {3}; names: {4}" -f @($r.Rows).Count, $okc, (Show $r.Label), $r.Boxes.Count, ((@($r.Rows) | ForEach-Object { Show $_.Name }) -join ', '))
        }
        if ($saves['sha256']) {
            $gnu = $null
            foreach ($c in @((Join-Path $env:ProgramFiles 'Git\usr\bin\sha256sum.exe'))) { if (Test-Path -LiteralPath $c) { $gnu = $c } }
            if ($gnu) {
                Push-Location -LiteralPath $RtDir
                try { $o = & $gnu -c 'roundtrip117.sha256' 2>&1 | ForEach-Object { '' + $_ }; $ec = $LASTEXITCODE } finally { Pop-Location }
                $okl = @($o | Where-Object { $_ -match ': OK$' }).Count
                $v = $(if ($Fixed) { V ($ec -eq 0 -and $okl -eq 7) } else { V ($ec -ne 0) })
                Row $Case 'GNU' $v ("{0} -c: exit {1}, OK lines {2}; {3}" -f $gnu, $ec, $okl, (Tail (($o | Select-Object -Last 2) -join ' | ') 160))
            }
            else { Row $Case 'GNU' 'NOT DRIVEN' 'Git for Windows sha256sum.exe not found' }
            $z = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
            if (Test-Path -LiteralPath $z) {
                $o = & $z t -thash ($RtDir + '\roundtrip117.sha256') 2>&1 | ForEach-Object { '' + $_ }
                $okz = [bool]($o | Where-Object { $_ -match 'Everything is Ok' })
                $v = $(if ($Fixed) { V $okz } else { V (-not $okz) })
                Row $Case '7ZIP' $v ("7z t -thash: Everything is Ok {0}; {1}" -f $okz, (Tail ((@($o | Where-Object { $_ -match 'ERROR|Ok|Files' }) | Select-Object -First 3) -join ' | ') 160))
            }
            else { Row $Case '7ZIP' 'NOT DRIVEN' '7-Zip not installed' }
        }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc117_cs_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $Root
    $gen = & $Python (Join-Path $PSScriptRoot 'make_lists117.py') $Root 2>&1
    $Exp = Get-Content -LiteralPath ($Root + '\expected117.json') -Raw | ConvertFrom-Json
    Set-Config
    $script:HotKeyNote = Set-CsumHotKeys
    Out ("csumlist_probe (feature 117), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; OEM {2}; desktop '{3}'; registry key existed {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), [Drv117]::GetOEMCP(), $deskName, $existed)
    Out ("Fixture : {0}" -f (($gen | ForEach-Object { '' + $_ }) -join ' '))
    Out ("Hot keys: {0}" -f $script:HotKeyNote)
    Out ''
    $todo = @($Exp.lists | Where-Object { (Want $_.file) -or (Want 'lists') })
    if ($todo.Count) {
        $id = 0; $before = Reports
        try {
            $id = Start-P $DataDir $RtDir
            foreach ($L in $todo) { Run-List $id $L }
        }
        catch { Row 'lists' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { End-P 'lists' $id $before } }
    }
    if (Want 'rt') { Run-RoundTrip }
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
