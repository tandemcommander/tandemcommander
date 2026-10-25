<#
.SYNOPSIS
    Feature 189 probe: the Registry Editor's Find window shows text values whose end is not the
    usual one (a REG_MULTI_SZ with one, none or three NULs at the end; a REG_SZ without its NUL; an
    odd byte count) exactly - no trailing space, nothing read past the end of the copy.

.DESCRIPTION
    Values are written with RegSetValueExW (raw bytes) under HKCU\Software\TcProbe189, the panel
    goes to that key, the plug-in's Find window (Ctrl+Shift+G for the session, the 124 method)
    searches "probe189" and every row's cells are read exactly (LVM_GETITEMTEXTW). PASS = the
    value's row has a cell equal to the expected text.
      MSZ-TWO     "alpha\0beta\0\0"   -> "alpha beta"     (the control: proper)
      MSZ-ONE     "alpha\0beta\0"     -> "alpha beta"
      MSZ-NONE    "delta\0epsilon"    -> "delta epsilon"
      MSZ-THREE   "zeta\0\0\0"        -> "zeta"
      SZ-NONE     "gamma" (10 bytes)  -> "gamma"
      SZ-ODD      "eta" + one byte    -> "eta"
    (Windows hands a text back with a NUL added when it was stored without one - MSZ-NONE is
    read as a one-NUL list, SZ-NONE as a proper text; the no-NUL list is checked by saltests.)
      RX          a regular-expression search of the data for "beta" finds MSZ-TWO and MSZ-ONE
    END: the program exits cleanly, no bug report.
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

if (-not ('Drv189' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;
public static class Drv189
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

$Root = $TempRoot + '\tc189'
$StartDir = $Root + '\start'
$ProbeSub = 'Software\TcProbe189'
$ProbeKeyPath = 'reg:\HKEY_CURRENT_USER\Software\TcProbe189'
$script:HotKeyNote = 'not set'

function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function U16([string]$s) { return [Text.Encoding]::Unicode.GetBytes($s) }
# Registry Editor's Find command gets Ctrl+Shift+G for this session (the 118/121/124 method)
function Set-HotKeys {
    $plugins = 'HKCU:\Software\Tandem Commander\Settings\Plugins'
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

# the values: case, value name, type, bytes, expected text
$nul = [string][char]0
$Cases = @(
    @{ Case = 'MSZ-TWO'; Name = 'probe189msztwo'; Type = 7; Data = (U16 ('alpha' + $nul + 'beta' + $nul + $nul)); Want = 'alpha beta' },
    @{ Case = 'MSZ-ONE'; Name = 'probe189mszone'; Type = 7; Data = (U16 ('alpha' + $nul + 'beta' + $nul)); Want = 'alpha beta' },
    @{ Case = 'MSZ-NONE'; Name = 'probe189msznone'; Type = 7; Data = (U16 ('delta' + $nul + 'epsilon')); Want = 'delta epsilon' },
    @{ Case = 'MSZ-THREE'; Name = 'probe189mszthree'; Type = 7; Data = (U16 ('zeta' + $nul + $nul + $nul)); Want = 'zeta' },
    @{ Case = 'SZ-NONE'; Name = 'probe189sznone'; Type = 1; Data = (U16 'gamma'); Want = 'gamma' },
    @{ Case = 'SZ-ODD'; Name = 'probe189szodd'; Type = 1; Data = [byte[]]((U16 'eta') + [byte[]]@(0x41)); Want = 'eta' }
)

function Run-Find {
    $before = Reports; $id = 0
    try {
        $id = Start-Tc $StartDir
        [void](Do-ChangeDir $id $ProbeKeyPath)
        Sync $id; Start-Sleep -Milliseconds 1500
        $known = Get-Tops $id
        $note = [Drv189]::ModKey((Get-LeftList $id), 0x47, 3)
        $fw = Wait-NewWin $id $known 10
        if ($fw -eq [IntPtr]::Zero) { foreach ($c in $Cases) { Row $c.Case 'CELL' 'NOT DRIVEN' ("Ctrl+Shift+G opened no window (key: {0}; hot keys: {1})" -f $note, $script:HotKeyNote) }; return }
        Start-Sleep -Milliseconds 800
        $pat = Kid $fw 136; $look = Kid $fw 137; $lv = Kid $fw 149
        if (-not $pat -or -not $lv) { foreach ($c in $Cases) { Row $c.Case 'CELL' 'NOT DRIVEN' ('controls not found in ' + (WinDesc $fw)) }; return }
        [void][Drv098f]::SetText($pat, 'probe189', 5000)
        $lookText = $(if ($look) { [Drv098f]::GetText($look, 5000) } else { '<none>' })
        Click (Kid $fw 1)
        $sw = [Diagnostics.Stopwatch]::StartNew(); $n = 0
        while ($sw.Elapsed.TotalSeconds -lt 60) {
            Start-Sleep -Milliseconds 500
            $n = [Drv189]::SendR($lv, 0x1004, 0, 0)
            if ($n -ge $Cases.Count -and $sw.Elapsed.TotalSeconds -gt 3) { break }
        }
        Out ("Find: look in '{0}'; rows {1}" -f (Esc $lookText), $n)
        $rows = @{}
        for ($i = 0; $i -lt $n; $i++) {
            $c = @(0..6 | ForEach-Object { [Drv189]::LvText($lv, $i, $_) })
            $rows[[string]$c[0]] = $c
        }
        foreach ($c in $Cases) {
            $cells = $rows[$c.Name]
            if ($null -eq $cells) { Row $c.Case 'CELL' 'FAIL' ("no row named '{0}'" -f $c.Name); continue }
            $hit = @($cells | Where-Object { $_ -ceq $c.Want }).Count -gt 0
            Row $c.Case 'CELL' (V $hit) ("expected a cell '{0}'; cells: [{1}]" -f $c.Want, (($cells | ForEach-Object { Esc $_ }) -join ' ; '))
        }
        # RX: a regular-expression search of the data for "beta" (each string is a line): the
        # one-NUL list lost its last letter to a fixed 4-byte trim (review of 189)
        foreach ($cb in @(@(142, 0), @(145, 0), @(146, 1), @(147, 0), @(150, 1))) {
            $h = Kid $fw $cb[0]
            if ($h) { [void][Drv098f]::Send($h, 0x00F1, $cb[1], 0, 5000) }   # BM_SETCHECK
        }
        [void][Drv098f]::SetText($pat, 'beta', 5000)
        Click (Kid $fw 1)
        Start-Sleep -Milliseconds 1500
        $sw = [Diagnostics.Stopwatch]::StartNew(); $n2 = -1
        while ($sw.Elapsed.TotalSeconds -lt 30) {
            Start-Sleep -Milliseconds 500
            $n2b = [Drv189]::SendR($lv, 0x1004, 0, 0)
            if ($n2b -eq $n2 -and $sw.Elapsed.TotalSeconds -gt 3) { break }
            $n2 = $n2b
        }
        $found = @(for ($i = 0; $i -lt $n2; $i++) { [Drv189]::LvText($lv, $i, 0) }) | Sort-Object
        $want = @('probe189mszone', 'probe189msztwo')
        $okRx = (($found -join ',') -ceq ($want -join ','))
        Row 'RX' 'FOUND' (V $okRx) ("regexp 'beta' in data: found [{0}], expected [{1}]" -f ($found -join ', '), ($want -join ', '))
        Close-Win $fw
        Start-Sleep -Milliseconds 800
    }
    catch { Row 'FIND' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'FIND' $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc189_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    foreach ($c in $Cases) {
        $e = [Drv189]::SetRaw($ProbeSub, $c.Name, $c.Type, $c.Data)
        if ($e -ne 0) { throw ("RegSetValueExW {0}: {1}" -f $c.Name, $e) }
    }
    Set-Config
    $script:HotKeyNote = Set-HotKeys
    Out ("multisz_probe (feature 189), expect: {0}" -f $Expect)
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
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; probe key removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), (-not (Test-Path 'HKCU:\Software\TcProbe189')), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
if ($Expect -eq 'before') { exit 0 }
exit $nf
