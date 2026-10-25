<#
.SYNOPSIS
    Feature 124 probe (GitHub issue #3): the Registry Editor plug-in's text for a key ("KEY",
    Czech "KLIC" with accents) in the panel's Size column, in the information line and in the
    plug-in's Find window, in every shipped language.

.DESCRIPTION
    For every language (-Langs, default: english + the enabled languages of
    translations\languages.cfg) the program is started in that language, the left panel is put
    into the Detailed view and changed to reg:\HKEY_CURRENT_USER\Software\TcProbe124 (a key the
    probe creates and removes: one subkey, one value), the subkey is focused and:

      <lang> COL    the left panel (owner-drawn) is captured and read by the text recognition:
                    it holds the translation of "KEY" (Size column) - and the column names
      <lang> INFO   the information line under the panel, the same way
      <lang> DEFAULT the information line with the "(Default)" value focused: its translated name
      <lang> LONG    ... with a 320-byte accented text value focused (cut with "..." by the plug-in)
      <lang> DATA    ... with an accented text value focused: the text
      <lang> SEL    the information line with the subkey selected: it ends with the last word of
                    the translated "1 selected key" (template 1152 expanded for one)
      <lang> SEL3   the two values selected as well: the size prefix and "values and keys" (1153)
      <lang> FIND   the plug-in's Find window (hot key set for the session) finds the subkey;
                    its Size cell is read with LVM_GETITEMTEXTW: exactly the translation
      <lang> END    the program ended by WM_CLOSE with exit code 0, no stray window, no report

    Expected texts come from translations\<lang>\regedt.slt (ids 1004-1007), English from
    lang.rc2. COL/INFO/SEL verdicts: PASS when the recognized text holds the expected word
    exactly, or with the diacritics folded (the recognizer is the user's language; it does not
    know every letter of every other language) - the crops are saved to -ShotDir for a look.
    With -Expect before the same rows are reported as INFO/PASS/FAIL the same way (a control: the
    rows that the fix is for must FAIL there).

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while any tandemcommander.exe runs
    (the probes share HKCU\Software\Tandem Commander). The whole key is exported before, restored
    and SHA-256-verified after. Exit code = FAIL rows.

.PARAMETER Exe      tandemcommander.exe of the build under test
.PARAMETER Expect   fixed or before (only changes the header; verdicts are computed the same way)
.PARAMETER Langs    language folder names, e.g. -Langs czech,german
.PARAMETER ShotDir  where the crops go (default: %TEMP%\tc124\shots)

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Langs,
    [string]$ShotDir,
    [int]$ModeCmd = 2972
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot 'shotocr_lib.ps1')

if (-not ('Drv124' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv124
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
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift) - the method of features 100-121
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
    static string Remote(IntPtr win, uint msg, long wParam, int structSize, int textPtrOffset, int cchOffset, Action<byte[]> fill)
    {
        uint pid; GetWindowThreadProcessId(win, out pid);
        IntPtr hp = OpenProcess(0x0008 | 0x0010 | 0x0020 | 0x0400, false, pid);
        if (hp == IntPtr.Zero) return null;
        try
        {
            const int cch = 4096;
            IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, (UIntPtr)(uint)(structSize + cch * 2), 0x3000, 0x04);
            if (mem == IntPtr.Zero) return null;
            try
            {
                var s = new byte[structSize];
                fill(s);
                long textPtr = mem.ToInt64() + structSize;
                BitConverter.GetBytes(textPtr).CopyTo(s, textPtrOffset);
                BitConverter.GetBytes(cch).CopyTo(s, cchOffset);
                IntPtr w;
                if (!WriteProcessMemory(hp, mem, s, structSize, out w)) return null;
                IntPtr r;
                if (SendMessageTimeoutW(win, msg, (IntPtr)wParam, mem, 0, 5000, out r) == IntPtr.Zero) return null;
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
    // the text of a list view cell of another process (LVM_GETITEMTEXTW, x64 LVITEMW)
    public static string LvText(IntPtr lv, int item, int sub)
    {
        return Remote(lv, 0x1073, item, 128, 24, 32, delegate(byte[] s) {
            BitConverter.GetBytes(1).CopyTo(s, 0); BitConverter.GetBytes(item).CopyTo(s, 4); BitConverter.GetBytes(sub).CopyTo(s, 8); });
    }
    // the header text of a list view column of another process (LVM_GETCOLUMNW, x64 LVCOLUMNW)
    public static string LvColumn(IntPtr lv, int col)
    {
        return Remote(lv, 0x105F, col, 64, 16, 24, delegate(byte[] s) { BitConverter.GetBytes(4).CopyTo(s, 0); });   // LVCF_TEXT
    }
}
'@
}

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$Root = $TempRoot + '\tc124'
$StartDir = $Root + '\start'
if (-not $ShotDir) { $ShotDir = $Root + '\shots' }
$ProbeKeyReg = 'HKCU\Software\TcProbe124'
$ProbeKeyPath = 'reg:\HKEY_CURRENT_USER\Software\TcProbe124'
$SubKey = 'probekey124'
$script:HotKeyNote = 'not set'
# value data (pure ASCII source): "zlutoucky kun" with its Czech accents; the long one repeats the first word
$DataWord = 'p' + [char]0x0159 + [char]0x00ED + 'li' + [char]0x0161 + ' ' + [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD
$DataText = $DataWord + ' k' + [char]0x016F + [char]0x0148

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left) {
    $a = @('-t', 'T124', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\Settings\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
# Registry Editor's Find command gets Ctrl+Shift+G for this session (the 118/121 method)
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
# the expected texts of a language: ids 1004 Type/Date, 1005 Data/Time, 1006 Size, 1007 KEY
function Get-Expected([string]$Lang) {
    $e = @{}
    if ($Lang -eq 'english') { $e[1003] = '(Default)'; $e[1004] = 'Type/Date'; $e[1005] = 'Data/Time'; $e[1006] = 'Size'; $e[1007] = 'KEY'; $e[1152] = '{!}%d selected key{|1|s}'; $e[1153] = '{!}%d selected value{|1|s} and %d selected key{|1|s}'; return $e }
    $slt = Join-Path $RepoRoot ("translations\{0}\regedt.slt" -f $Lang)
    foreach ($line in [IO.File]::ReadAllLines($slt, $Utf8)) {
        if ($line -match '^(100[3-7]|115[1-4]),\d+,"(.*)"\s*$') { $e[[int]$Matches[1]] = $Matches[2] }
    }
    if ($e.Count -ne 9) { throw "ids 1004-1007 / 1151-1154 not found in $slt" }
    return $e
}
function Enabled-Langs {
    $cfg = [IO.File]::ReadAllLines((Join-Path $RepoRoot 'translations\languages.cfg'), $Utf8)
    $res = @('english'); $cur = $null
    foreach ($l in $cfg) {
        if ($l -match '^\s*\[(.+)\]\s*$') { $cur = $Matches[1].Trim() }
        elseif ($cur -and $l -match '^\s*enabled\s*=\s*on\s*$') { $res += $cur }
    }
    return $res
}
# the information line of the left panel: the universal-window child that begins at the bottom of the list
function Find-InfoLine([int]$Id) {
    $list = Get-LeftList $Id
    $panel = [Drv098f]::GetParent($list)
    $lr = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($list, [ref]$lr)
    $line = [IntPtr]::Zero; $best = 1e9
    foreach ($h in @([Drv098f]::Kids($panel) | Where-Object { [Drv098f]::Cls($_) -eq $LineClass -and [Drv098f]::GetParent($_) -eq $panel -and [Drv098f]::IsWindowVisible($_) })) {
        $wr = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($h, [ref]$wr)
        if ($wr.Top -ge $lr.Bottom - 1 -and $wr.Top -lt $best) { $best = $wr.Top; $line = $h }
    }
    return $line
}
# a plural template of the program ("{!}%d selected key{|1|s}") for the value 1: every {a|n|b|m|c}
# group gives its first text whose limit is >= 1 (an "N:" index prefix is dropped)
function Expand-One([string]$T) {
    $t = $T -replace '^\{!\}', ''
    $t = [regex]::Replace($t, '\{([^{}]*)\}', {
            param($m)
            $body = $m.Groups[1].Value -replace '^\d+:', ''
            $parts = $body -split '\|'
            for ($i = 0; $i + 1 -lt $parts.Count; $i += 2) { if ([int]$parts[$i + 1] -ge 1) { return $parts[$i] } }
            return $parts[$parts.Count - 1]
        })
    return $t
}
function Last-Word([string]$s) { return @($s.Trim() -split '\s+')[-1] }
function Verdict-Ocr([string]$Has) { if ($Has -eq 'no') { return 'FAIL' } else { return 'PASS' } }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }

function Row-Lang([string]$Lang) {
    $exp = Get-Expected $Lang
    $key = $exp[1007]
    $before = Reports; $id = 0
    try {
        Set-Lang ($Lang + '.slg')
        $id = Start-P $StartDir
        $main = Get-Main $id
        [void](Do-ChangeDir $id $ProbeKeyPath)
        Sync $id; Start-Sleep -Milliseconds 1500
        Post-Cmd $main $ModeCmd; Sync $id; Start-Sleep -Milliseconds 800   # the Detailed view
        $boxes = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
        if ($boxes.Count) { Row $Lang 'COL' 'FAIL' ('a window after the path change: ' + (($boxes | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        Key $id 0x24; Key $id 0x28                                        # Home, Down: the subkey (after "..")
        Sync $id; Start-Sleep -Milliseconds 600

        $list = Get-LeftList $id
        $lrc = [Shot124]::RelRect($main, $list); $lrc[1] -= 24; $lrc[3] = 130     # the header line above the list and the first rows
        $col = Shot-Read $main $list (Join-Path $ShotDir ("{0}_{1}_panel.png" -f $Expect, $Lang)) 3 $lrc
        $hasKey = Ocr-Has $col.Lines $key
        $hdr = @(1004, 1005, 1006 | ForEach-Object { '' + $_ + ' ' + (Ocr-Has $col.Lines $exp[$_]) })
        Row $Lang 'COL' (Verdict-Ocr $hasKey) ("expected '{0}': {1}; column names: {2}; recognized: {3}" -f (Esc $key), $hasKey, ($hdr -join ', '), (Esc ($col.Lines -join ' | ')))

        $info = Find-InfoLine $id
        if ($info -eq [IntPtr]::Zero) { Row $Lang 'INFO' 'FAIL' 'information line window not found' }
        else {
            $il = Shot-Read $main $info (Join-Path $ShotDir ("{0}_{1}_info.png" -f $Expect, $Lang)) 3
            $hasI = Ocr-Has $il.Lines ($SubKey + ': ' + $key)
            Row $Lang 'INFO' (Verdict-Ocr $hasI) ("expected '{0}: {1}': {2}; recognized: {3}" -f $SubKey, (Esc $key), $hasI, (Esc ($il.Lines -join ' | ')))
            # the values: "(Default)" (a name the plug-in makes up from its language module), a long
            # accented text (cut with "..."), an accented text
            Key $id 0x28; Sync $id; Start-Sleep -Milliseconds 400
            $dv = Shot-Read $main $info (Join-Path $ShotDir ("{0}_{1}_default.png" -f $Expect, $Lang)) 3
            $hasD = Ocr-Has $dv.Lines $exp[1003]
            Row $Lang 'DEFAULT' (Verdict-Ocr $hasD) ("expected '{0}': {1}; recognized: {2}" -f (Esc $exp[1003]), $hasD, (Esc ($dv.Lines -join ' | ')))
            Key $id 0x28; Sync $id; Start-Sleep -Milliseconds 400
            $dt = Shot-Read $main $info (Join-Path $ShotDir ("{0}_{1}_data.png" -f $Expect, $Lang)) 3
            $hasT = Ocr-Has $dt.Lines $DataText
            Row $Lang 'DATA' (Verdict-Ocr $hasT) ("expected '{0}': {1}; recognized: {2}" -f (Esc $DataText), $hasT, (Esc ($dt.Lines -join ' | ')))
            # the long text lives in the subkey (in the first key its wide Data column would push
            # the Size column out of the panel)
            [void](Do-ChangeDir $id ($ProbeKeyPath + '\' + $SubKey)); Sync $id; Start-Sleep -Milliseconds 1200
            Key $id 0x24; Key $id 0x28; Key $id 0x28; Sync $id; Start-Sleep -Milliseconds 400
            $info2 = Find-InfoLine $id
            $lg = Shot-Read $main $info2 (Join-Path $ShotDir ("{0}_{1}_long.png" -f $Expect, $Lang)) 3
            $hasL = Ocr-Has $lg.Lines ($DataWord + ' ' + $DataWord)
            Row $Lang 'LONG' (Verdict-Ocr $hasL) ("a text of 320 UTF-8 bytes, expected to hold '{0} {0}': {1}; recognized: {2}" -f (Esc $DataWord), $hasL, (Esc ($lg.Lines -join ' | ')))
            [void](Do-ChangeDir $id $ProbeKeyPath); Sync $id; Start-Sleep -Milliseconds 1200
            $info = Find-InfoLine $id
            Key $id 0x24; Key $id 0x28; Sync $id; Start-Sleep -Milliseconds 400
            Key $id 0x2D; Sync $id; Start-Sleep -Milliseconds 500        # Insert: select the subkey
            $sl = Shot-Read $main $info (Join-Path $ShotDir ("{0}_{1}_sel.png" -f $Expect, $Lang)) 3
            $selWord = Last-Word (Expand-One $exp[1152])
            $hasS = Ocr-Has $sl.Lines $selWord
            Row $Lang 'SEL' (Verdict-Ocr $hasS) ("one key selected, expected to end with '{0}': {1}; recognized: {2}" -f (Esc $selWord), $hasS, (Esc ($sl.Lines -join ' | ')))
            Key $id 0x2D; Key $id 0x2D; Sync $id; Start-Sleep -Milliseconds 500   # the two values as well: size prefix + "values and keys"
            $s3 = Shot-Read $main $info (Join-Path $ShotDir ("{0}_{1}_sel3.png" -f $Expect, $Lang)) 3
            $w3 = Last-Word (Expand-One $exp[1153])
            $has3 = Ocr-Has $s3.Lines $w3
            Row $Lang 'SEL3' (Verdict-Ocr $has3) ("two values and one key selected, expected to end with '{0}': {1}; recognized: {2}" -f (Esc $w3), $has3, (Esc ($s3.Lines -join ' | ')))
        }

        # the plug-in's Find window
        $known = Get-Tops $id
        $note = [Drv124]::ModKey((Get-LeftList $id), 0x47, 3)
        $fw = Wait-NewWin $id $known 10
        if ($fw -eq [IntPtr]::Zero) { Row $Lang 'FIND' 'NOT DRIVEN' ("Ctrl+Shift+G opened no window (key: {0}; hot keys: {1})" -f $note, $script:HotKeyNote) }
        else {
            Start-Sleep -Milliseconds 800
            $pat = Kid $fw 136; $look = Kid $fw 137; $lv = Kid $fw 149
            if (-not $pat -or -not $lv) { Row $Lang 'FIND' 'NOT DRIVEN' ('controls not found in ' + (WinDesc $fw)) }
            else {
                [void][Drv098f]::SetText($pat, $SubKey, 5000)
                $lookText = $(if ($look) { [Drv098f]::GetText($look, 5000) } else { '<none>' })
                $ok = Kid $fw 1; Click $ok
                $sw = [Diagnostics.Stopwatch]::StartNew(); $n = 0
                while ($sw.Elapsed.TotalSeconds -lt 60) {
                    Start-Sleep -Milliseconds 500
                    $n = [Drv124]::SendR($lv, 0x1004, 0, 0)
                    if ($n -gt 0 -and $sw.Elapsed.TotalSeconds -gt 3) { break }
                }
                $cols = @(0..6 | ForEach-Object { [Drv124]::LvColumn($lv, $_) })
                $cells = @(); $sizeCell = $null
                for ($i = 0; $i -lt [Math]::Min($n, 3); $i++) {
                    $c = @(0..6 | ForEach-Object { [Drv124]::LvText($lv, $i, $_) })
                    $cells += ('[' + (($c | ForEach-Object { Esc $_ }) -join ' ; ') + ']')
                    if ($c[0] -ceq $SubKey -and $null -eq $sizeCell) { $sizeCell = $c[4] }
                }
                $v = $(if ($null -eq $sizeCell) { 'NOT DRIVEN' } elseif ($sizeCell -ceq $key) { 'PASS' } else { 'FAIL' })
                Row $Lang 'FIND' $v ("look in '{0}'; rows {1}; Size cell of '{2}': '{3}' (expected '{4}'); columns: {5}; cells: {6}" -f (Esc $lookText), $n, $SubKey, (Esc $sizeCell), (Esc $key), (($cols | ForEach-Object { Esc $_ }) -join ' ; '), ($cells -join ' '))
            }
            if ((Kid $fw 1)) { $t = [Drv098f]::GetText((Kid $fw 1), 3000) }
            Close-Win $fw
            Start-Sleep -Milliseconds 800
        }
    }
    catch { Row $Lang 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) {
            $fatal = Fatal-Win $id
            Stop-Tc $id
            $ec = ExitCodeOf $id
            $rep = @(Take-Reports $before)
            Row $Lang 'END' (V ((-not $fatal) -and $ec -eq '0x00000000' -and $rep.Count -eq 0)) ("exit {0}; new reports {1}{2}" -f $ec, $rep.Count, $(if ($fatal) { '; FATAL: ' + $fatal } else { '' }))
        }
    }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc124_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    [void][IO.Directory]::CreateDirectory($ShotDir)
    & reg.exe add "$ProbeKeyReg\$SubKey" /f | Out-Null
    $pk = 'HKCU:\Software\TcProbe124'
    Set-ItemProperty -LiteralPath $pk -Name 'probeval124' -Value $DataText -Type String
    Set-ItemProperty -LiteralPath ($pk + '\' + $SubKey) -Name 'probelong124' -Value ((($DataWord + ' ') * 20).Trim()) -Type String
    Set-Config
    $script:HotKeyNote = Set-HotKeys
    if (-not $Langs) { $Langs = Enabled-Langs } else { $Langs = @($Langs | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    Out ("regkey_probe (feature 124, issue #3), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; recognizer languages: {3}; registry key existed {4}; export SHA-256 {5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), ((Ocr-Languages) -join ','), $existed, $regHash)
    Out ("Hot keys: {0}; languages: {1}; crops: {2}" -f $script:HotKeyNote, ($Langs -join ','), $ShotDir)
    Out ''
    foreach ($l in $Langs) { Row-Lang $l }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    & cmd.exe /c "reg delete `"$ProbeKeyReg`" /f >nul 2>&1"
    try { if ([IO.Directory]::Exists($LP + $StartDir)) { [IO.Directory]::Delete($LP + $StartDir, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    $ni = @($script:Rows | Where-Object { $_.Verdict -eq 'INFO' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}, INFO {3}. Left running: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $ni, $leftover.Count, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
