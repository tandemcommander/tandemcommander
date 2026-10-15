<#
.SYNOPSIS
    Feature 190 probe: the Registry Editor's Find window searches with a regular expression, in
    hex and for a number - the regexp and hex searches passed an uninitialized number to the
    search thread (a Debug run-time check stopped the search). The number rows are the control
    (and refuted a suspected sign extension of big-endian bytes: plug-ins build with /J).

.DESCRIPTION
    Values are written with RegSetValueExW under HKCU\Software\TcProbe190, the panel goes to that
    key, the plug-in's Find window (Ctrl+Shift+G for the session, the 124 method) searches with
    Keys and Values off, Data on; the names of the found rows are read (LVM_GETITEMTEXTW).
      NUM     the number "255": the DWORD 255 and the big-endian DWORD 255 (00 00 00 FF)
      NUM-MID the number "32768": the big-endian DWORD 00 00 80 00
      NUM-TOP the number "2147483648": the big-endian DWORD 80 00 00 00
      RX      regular expression "beta": the two lists holding it (one of them with one NUL - the
              trim of feature 189)
      HEX     hex "62 00 65 00 74 00 61 00" ("beta" in UTF-16): the same two lists
    END: the program exits cleanly, no window at exit, no bug report.
    MUST run through tools\run_on_hidden_desktop.ps1. The product's registry key is exported,
    restored and verified; the probe key is deleted. Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Drv190' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;
public static class Drv190
{
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)] static extern int RegSetValueExW(SafeRegistryHandle h, string name, int reserved, int type, byte[] data, int size);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, UIntPtr size, uint type, uint protect);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool VirtualFreeEx(IntPtr p, IntPtr a, UIntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool WriteProcessMemory(IntPtr p, IntPtr a, byte[] b, int n, out IntPtr w);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, int n, out IntPtr r);
    // a value with exactly these bytes (RegistryKey.SetValue always adds the terminators)
    public static int SetRaw(string subKey, string name, int type, byte[] data)
    {
        using (RegistryKey k = Registry.CurrentUser.CreateSubKey(subKey))
            return RegSetValueExW(k.Handle, name, 0, type, data, data.Length);
    }
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift) - the method of features 100-124
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
    // the text of a list view cell of another process (LVM_GETITEMTEXTW, x64 LVITEMW), up to its NUL
    public static string LvText(IntPtr lv, int item, int sub)
    {
        uint pid; GetWindowThreadProcessId(lv, out pid);
        IntPtr hp = OpenProcess(0x0008 | 0x0010 | 0x0020 | 0x0400, false, pid);
        if (hp == IntPtr.Zero) return null;
        try
        {
            const int lvSize = 128, cch = 4096;
            IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, (UIntPtr)(uint)(lvSize + cch * 2), 0x3000, 0x04);
            if (mem == IntPtr.Zero) return null;
            try
            {
                var lvi = new byte[lvSize];
                BitConverter.GetBytes(1).CopyTo(lvi, 0);
                BitConverter.GetBytes(item).CopyTo(lvi, 4);
                BitConverter.GetBytes(sub).CopyTo(lvi, 8);
                long textPtr = mem.ToInt64() + lvSize;
                BitConverter.GetBytes(textPtr).CopyTo(lvi, 24);
                BitConverter.GetBytes(cch).CopyTo(lvi, 32);
                IntPtr w;
                if (!WriteProcessMemory(hp, mem, lvi, lvSize, out w)) return null;
                IntPtr r;
                if (SendMessageTimeoutW(lv, 0x1073, (IntPtr)item, mem, 0, 5000, out r) == IntPtr.Zero) return null;
                var buf = new byte[cch * 2];
                IntPtr rd;
                if (!ReadProcessMemory(hp, (IntPtr)textPtr, buf, buf.Length, out rd)) return null;
                string t = Encoding.Unicode.GetString(buf);
                int z = t.IndexOf('\0'); if (z >= 0) t = t.Substring(0, z);
                return t;
            }
            finally { VirtualFreeEx(hp, mem, UIntPtr.Zero, 0x8000); }
        }
        finally { CloseHandle(hp); }
    }
}
'@
}

$Root = $TempRoot + '\tc190'
$StartDir = $Root + '\start'
$ProbeSub = 'Software\TcProbe190'
$ProbeKeyPath = 'reg:\HKEY_CURRENT_USER\Software\TcProbe190'
$script:HotKeyNote = 'not set'

function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function U16([string]$s) { return [Text.Encoding]::Unicode.GetBytes($s) }
# Registry Editor's Find command gets Ctrl+Shift+G for this session (the 118/121/124 method)
function Set-HotKeys {
    $plugins = 'HKCU:\Software\Tandem Commander\0.1\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key' }
    $notes = @()
    foreach ($k in @(Get-ChildItem $plugins)) {
        $dll = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DLL
        if (-not $dll -or $dll -notmatch 'regedt\.spl$') { continue }
        $menu = Join-Path $k.PSPath 'Menu'
        if (-not (Test-Path $menu)) { $notes += 'regedt: no Menu key'; continue }
        $set = 0
        foreach ($mi in @(Get-ChildItem $menu)) {
            if ((Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID -eq 1) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value 0x10347 -Type DWord; $set++ }
        }
        $notes += ("regedt.spl id 1: {0}" -f $set)
    }
    return ($notes -join '; ')
}

# the values: name, type, bytes
$nul = [string][char]0
$Values = @(
    @{ Name = 'probe190msztwo'; Type = 7; Data = (U16 ('alpha' + $nul + 'beta' + $nul + $nul)) },
    @{ Name = 'probe190mszone'; Type = 7; Data = (U16 ('alpha' + $nul + 'beta' + $nul)) },
    @{ Name = 'probe190other'; Type = 1; Data = (U16 ('gamma' + $nul)) },
    @{ Name = 'probe190dw'; Type = 4; Data = [byte[]]@(0xFF, 0, 0, 0) },
    @{ Name = 'probe190be'; Type = 5; Data = [byte[]]@(0, 0, 0, 0xFF) },
    @{ Name = 'probe190bemid'; Type = 5; Data = [byte[]]@(0, 0, 0x80, 0) },
    @{ Name = 'probe190betop'; Type = 5; Data = [byte[]]@(0x80, 0, 0, 0) }
)
# the searches: row, pattern, hex, regexp, expected names (sorted)
# (the plain searches first: before the fix the first regexp / hex search stopped at a Debug box)
$Searches = @(
    @{ Row = 'NUM'; Pattern = '255'; Hex = 0; Rx = 0; Want = @('probe190be', 'probe190dw') },
    @{ Row = 'NUM-MID'; Pattern = '32768'; Hex = 0; Rx = 0; Want = @('probe190bemid') },
    @{ Row = 'NUM-TOP'; Pattern = '2147483648'; Hex = 0; Rx = 0; Want = @('probe190betop') },
    @{ Row = 'RX'; Pattern = 'beta'; Hex = 0; Rx = 1; Want = @('probe190mszone', 'probe190msztwo') },
    @{ Row = 'HEX'; Pattern = '62 00 65 00 74 00 61 00'; Hex = 1; Rx = 0; Want = @('probe190mszone', 'probe190msztwo') }
)

function Search-Once([IntPtr]$Fw, $S) {
    $pat = Kid $Fw 136; $lv = Kid $Fw 149
    foreach ($cb in @(@(142, 0), @(145, 0), @(146, 1), @(147, $S.Hex), @(150, $S.Rx), @(143, 0), @(144, 0))) {
        $h = Kid $Fw $cb[0]
        if ($h) { [void][Drv098f]::Send($h, 0x00F1, $cb[1], 0, 5000) }   # BM_SETCHECK
    }
    [void][Drv098f]::SetText($pat, $S.Pattern, 5000)
    Click (Kid $Fw 1)
    Start-Sleep -Milliseconds 1500
    $sw = [Diagnostics.Stopwatch]::StartNew(); $n = -1
    while ($sw.Elapsed.TotalSeconds -lt 30) {
        Start-Sleep -Milliseconds 500
        $m = [Drv190]::SendR($lv, 0x1004, 0, 0)
        if ($m -eq $n -and $sw.Elapsed.TotalSeconds -gt 3) { break }
        $n = $m
    }
    $found = @(for ($i = 0; $i -lt $n; $i++) { [Drv190]::LvText($lv, $i, 0) }) | Sort-Object
    $ok = (($found -join ',') -ceq ($S.Want -join ','))
    $boxes = @(Get-Tops $script:CurId | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $_ -ne $Fw } | ForEach-Object { WinDesc $_ })
    Row $S.Row 'FOUND' (V ($ok -and $boxes.Count -eq 0)) ("'{0}' (hex {1}, regexp {2}): found [{3}], expected [{4}]{5}" -f $S.Pattern, $S.Hex, $S.Rx, ($found -join ', '), ($S.Want -join ', '), $(if ($boxes.Count) { '; box: ' + (Tail ($boxes -join ' || ') 300) } else { '' }))
}

function Run-Find {
    $before = Reports; $id = 0
    try {
        $id = Start-Tc $StartDir; $script:CurId = $id
        [void](Do-ChangeDir $id $ProbeKeyPath)
        Sync $id; Start-Sleep -Milliseconds 1500
        $known = Get-Tops $id
        $note = [Drv190]::ModKey((Get-LeftList $id), 0x47, 3)
        $fw = Wait-NewWin $id $known 10
        if ($fw -eq [IntPtr]::Zero) { foreach ($c in $Searches) { Row $c.Row 'FOUND' 'NOT DRIVEN' ("Ctrl+Shift+G opened no window (key: {0}; hot keys: {1})" -f $note, $script:HotKeyNote) }; return }
        Start-Sleep -Milliseconds 800
        if (-not (Kid $fw 136) -or -not (Kid $fw 149)) { foreach ($c in $Searches) { Row $c.Row 'FOUND' 'NOT DRIVEN' ('controls not found in ' + (WinDesc $fw)) }; return }
        foreach ($c in $Searches) { Search-Once $fw $c }
        Close-Win $fw
        Start-Sleep -Milliseconds 800
    }
    catch { Row 'FIND' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'FIND' $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc190_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    foreach ($c in $Values) {
        $e = [Drv190]::SetRaw($ProbeSub, $c.Name, $c.Type, $c.Data)
        if ($e -ne 0) { throw ("RegSetValueExW {0}: {1}" -f $c.Name, $e) }
    }
    Set-Config
    $script:HotKeyNote = Set-HotKeys
    Out ("find_number_probe (feature 190), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; hot keys: {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, $script:HotKeyNote)
    Out ''
    Run-Find
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    & cmd.exe /c "reg delete `"HKCU\$ProbeSub`" /f >nul 2>&1"
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; probe key removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), (-not (Test-Path 'HKCU:\Software\TcProbe190')), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
if ($Expect -eq 'before') { exit 0 }
exit $nf
