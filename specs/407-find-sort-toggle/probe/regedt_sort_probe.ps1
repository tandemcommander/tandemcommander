<#
.SYNOPSIS
    Feature 407 probe (finding on the way): the Registry Editor's Find window - a second click on
    the same result column reverses the order, keys stay before values, the header shows the sort
    arrow, a new search forgets the sort, the Data column does not sort.

.DESCRIPTION
    Keys probe407kB / probe407kA and values probe407vA (REG_SZ "x"), probe407vB (REG_SZ of 9
    letters), probe407vC (REG_SZ of 4 letters) under HKCU\Software\TcProbe407; the panel goes
    there, the plug-in's Find window (Ctrl+Shift+J for the session, 391's method) searches for
    "probe407" with Keys, Values and Include subkeys on, Data off. The order is the Name cells of
    the result list (only rows starting with probe407), the arrows the HDF_SORTUP / HDF_SORTDOWN
    bits of the seven header items (Name, Type, Data, Path, Size, Date, Time).
      SEARCH   the found rows (all five)
      NAME-1   click Name: kA, kB, vA, vB, vC; arrow up on Name
      NAME-2   click Name again: kB, kA, vC, vB, vA (keys still first); arrow down
      PATH-1   click Path (one path for all): kA, kB, vA, vB, vC; arrow up on Path (review 1)
      PATH-2   click Path again: vC, vB, vA, kB, kA - the exact reverse (Path never grouped keys)
      SIZE-1   click Size: kA, kB, vA, vC, vB; arrow up on Size only
      SIZE-2   click Size again: kB, kA, vB, vC, vA; arrow down
      DATA     click Data: order and arrows unchanged (the column does not sort)
      AGAIN    Find again: no arrow; then click Size: ascending again
    The Data column is narrowed to 60 px after the first search (it takes the rest of the width, which
    pushes Size out of view). Clicks are posted WM_LBUTTONDOWN / UP to the header control. END: the program exits cleanly.
    MUST run through tools\run_on_hidden_desktop.ps1. The product's registry key is exported,
    restored and verified; the probe key is deleted. Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Drv407r' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv407r
{
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
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift) - the method of features 100-124, 257
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
    // writes 'size' bytes of 'data' into the other process, sends msg (w, the buffer), reads it back
    static byte[] Remote(IntPtr h, uint msg, long w, byte[] data, int size, out long result)
    {
        result = -999;
        uint pid; GetWindowThreadProcessId(h, out pid);
        IntPtr hp = OpenProcess(0x0008 | 0x0010 | 0x0020 | 0x0400, false, pid);
        if (hp == IntPtr.Zero) return null;
        try
        {
            IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, (UIntPtr)(uint)size, 0x3000, 0x04);
            if (mem == IntPtr.Zero) return null;
            try
            {
                var buf = new byte[size];
                Array.Copy(data, buf, Math.Min(data.Length, size));
                IntPtr wr;
                if (!WriteProcessMemory(hp, mem, buf, size, out wr)) return null;
                IntPtr r;
                if (SendMessageTimeoutW(h, msg, (IntPtr)w, mem, 0, 5000, out r) == IntPtr.Zero) return null;
                result = r.ToInt64();
                var outb = new byte[size];
                IntPtr rd;
                if (!ReadProcessMemory(hp, mem, outb, size, out rd)) return null;
                return outb;
            }
            finally { VirtualFreeEx(hp, mem, UIntPtr.Zero, 0x8000); }
        }
        finally { CloseHandle(hp); }
    }
    // the text of a list view cell of another process (LVM_GETITEMTEXTW, x64 LVITEMW)
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
    // the fmt of header item 'index' (HDITEMW x64: mask at 0, fmt at 28), -1 when unreadable
    public static int HdrFmt(IntPtr hdr, int index)
    {
        var hdi = new byte[128];
        BitConverter.GetBytes(0x0004).CopyTo(hdi, 0); // HDI_FORMAT
        long res;
        byte[] o = Remote(hdr, 0x120B, index, hdi, 128, out res); // HDM_GETITEMW
        if (o == null || res == 0) return -1;
        return BitConverter.ToInt32(o, 28);
    }
}
'@
}

$Root = $TempRoot + '\tc407r'
$StartDir = $Root + '\start'
$ProbeSub = 'Software\TcProbe407'
$ProbeKeyPath = 'reg:\HKEY_CURRENT_USER\Software\TcProbe407'
$script:HotKeyNote = 'not set'

function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
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
            if ((Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID -eq 1) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value 0x1034A -Type DWord; $set++ }
        }
        $notes += ("regedt.spl id 1: {0}" -f $set)
    }
    return ($notes -join '; ')
}
function Order([IntPtr]$Lv) {
    $n = [int][Drv407r]::SendR($Lv, 0x1004, 0, 0)
    return ((@(for ($i = 0; $i -lt $n; $i++) { [Drv407r]::LvText($Lv, $i, 0) }) | Where-Object { $_ -like 'probe407*' } | ForEach-Object { $_.Substring(8) }) -join ',')
}
function Arrows([IntPtr]$Lv) {
    $h = @([Drv098f]::Kids($Lv) | Where-Object { [Drv098f]::Cls($_) -eq 'SysHeader32' }) | Select-Object -First 1
    return (-join (0..6 | ForEach-Object {
        $f = [Drv407r]::HdrFmt($h, $_)
        if ($f -lt 0) { '?' } elseif ($f -band 0x0400) { '^' } elseif ($f -band 0x0200) { 'v' } else { '-' }
    }))
}
function Click-Col([IntPtr]$Lv, [int]$Col) {
    $h = @([Drv098f]::Kids($Lv) | Where-Object { [Drv098f]::Cls($_) -eq 'SysHeader32' }) | Select-Object -First 1
    $x = 0
    for ($i = 0; $i -lt $Col; $i++) { $x += [int][Drv407r]::SendR($Lv, 0x101D, $i, 0) }   # LVM_GETCOLUMNWIDTH
    $x += [int]([int][Drv407r]::SendR($Lv, 0x101D, $Col, 0) / 2)
    Post-Click $h $x 6
    Start-Sleep -Milliseconds 700
    [void][Drv407r]::SendR($Lv, 0, 0, 0)
}
function Search([IntPtr]$Fw) {
    $pat = Kid $Fw 136; $lv = Kid $Fw 149
    foreach ($cb in @(@(140, 1), @(142, 1), @(145, 1), @(146, 0), @(147, 0), @(150, 0), @(143, 0), @(144, 0))) {
        $h = Kid $Fw $cb[0]
        if ($h) { [void][Drv098f]::Send($h, 0x00F1, $cb[1], 0, 5000) }   # BM_SETCHECK
    }
    [void][Drv098f]::SetText($pat, 'probe407', 5000)
    Click (Kid $Fw 1)
    Start-Sleep -Milliseconds 1500
    $sw = [Diagnostics.Stopwatch]::StartNew(); $n = -1
    while ($sw.Elapsed.TotalSeconds -lt 30) {
        Start-Sleep -Milliseconds 500
        $m = [Drv407r]::SendR($lv, 0x1004, 0, 0)
        if ($m -eq $n -and $sw.Elapsed.TotalSeconds -gt 3) { break }
        $n = $m
    }
}
function Step([string]$RowName, [IntPtr]$Lv, [scriptblock]$Do, [string]$WantOrder, [string]$WantArrows) {
    & $Do
    $o = Order $Lv; $a = Arrows $Lv
    $ok = ((-not $WantOrder) -or ($o -ceq $WantOrder)) -and ($a -ceq $WantArrows)
    Row $RowName 'RUN' (V $ok) ("{0} [{1}]{2}" -f $o, $a, $(if ($ok) { '' } else { (' <- expected {0} [{1}]' -f $WantOrder, $WantArrows) }))
}

function Run-Find {
    $before = Reports; $id = 0
    try {
        $id = Start-Tc $StartDir; $script:CurId = $id
        [void](Do-ChangeDir $id $ProbeKeyPath)
        Sync $id; Start-Sleep -Milliseconds 1500
        $known = Get-Tops $id
        $note = [Drv407r]::ModKey((Get-LeftList $id), 0x4A, 3)
        $fw = Wait-NewWin $id $known 10
        if ($fw -eq [IntPtr]::Zero) { Row 'SEARCH' 'RUN' 'NOT DRIVEN' ("Ctrl+Shift+J opened no window (key: {0}; hot keys: {1})" -f $note, $script:HotKeyNote); return }
        Start-Sleep -Milliseconds 800
        $lv = Kid $fw 149
        if (-not (Kid $fw 136) -or -not $lv) { Row 'SEARCH' 'RUN' 'NOT DRIVEN' ('controls not found in ' + (WinDesc $fw)); return }
        Step 'SEARCH' $lv { Search $fw } '' '-------'
        # the Data column takes the rest of the width: narrow it so that every header item is visible
        [void][Drv407r]::SendR($lv, 0x101E, 2, 60)   # LVM_SETCOLUMNWIDTH
        Start-Sleep -Milliseconds 300
        $found = (Order $lv) -split ',' | Sort-Object
        if (($found -join ',') -cne 'kA,kB,vA,vB,vC') { Row 'SEARCH' 'FOUND' 'FAIL' ('found ' + ($found -join ',')); return }
        Step 'NAME-1' $lv { Click-Col $lv 0 } 'kA,kB,vA,vB,vC' '^------'
        Step 'NAME-2' $lv { Click-Col $lv 0 } 'kB,kA,vC,vB,vA' 'v------'
        # Path does not group keys (upstream): one path for all, ties by name (keys first), the
        # descending order is the exact reverse - values before keys (review 1)
        Step 'PATH-1' $lv { Click-Col $lv 3 } 'kA,kB,vA,vB,vC' '---^---'
        Step 'PATH-2' $lv { Click-Col $lv 3 } 'vC,vB,vA,kB,kA' '---v---'
        Step 'SIZE-1' $lv { Click-Col $lv 4 } 'kA,kB,vA,vC,vB' '----^--'
        Step 'SIZE-2' $lv { Click-Col $lv 4 } 'kB,kA,vB,vC,vA' '----v--'
        Step 'DATA' $lv { Click-Col $lv 2 } 'kB,kA,vB,vC,vA' '----v--'
        Step 'AGAIN' $lv { Search $fw } '' '-------'
        Step 'AGAIN-SIZE' $lv { Click-Col $lv 4 } 'kA,kB,vA,vC,vB' '----^--'
        $script:Fatal = Fatal-Win $id
        Close-Win $fw
        Start-Sleep -Milliseconds 800
    }
    catch { Row 'FIND' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'FIND' $id $script:Fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc407r_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0; $script:Fatal = $null
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    & cmd.exe /c "reg delete `"HKCU\$ProbeSub`" /f >nul 2>&1"
    [void](New-Item -Path "HKCU:\$ProbeSub\probe407kB" -Force)
    [void](New-Item -Path "HKCU:\$ProbeSub\probe407kA" -Force)
    Set-ItemProperty -Path "HKCU:\$ProbeSub" -Name 'probe407vA' -Value 'x' -Type String
    Set-ItemProperty -Path "HKCU:\$ProbeSub" -Name 'probe407vB' -Value 'xxxxxxxxx' -Type String
    Set-ItemProperty -Path "HKCU:\$ProbeSub" -Name 'probe407vC' -Value 'xxxx' -Type String
    Set-Config
    $script:HotKeyNote = Set-HotKeys
    Out ("regedt_sort_probe (feature 407) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; hot keys: {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $script:HotKeyNote)
    Out 'Rows: names without the probe407 prefix; arrows per column Name,Type,Data,Path,Size,Date,Time: ^ up, v down, - none'
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
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; probe key removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), (-not (Test-Path 'HKCU:\Software\TcProbe407')), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
