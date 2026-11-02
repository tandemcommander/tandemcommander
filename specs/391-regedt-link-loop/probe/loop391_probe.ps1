<#
.SYNOPSIS
    Feature 391 probe: the Registry Editor's Copy (F5) and Find through a registry link (a key made with
    REG_OPTION_CREATE_LINK) that points back into the tree being walked.

.DESCRIPTION
    Fixture (made before each row, removed at the end): HKCU\Software\TcProbeLoop with
      Self\<K>            a = 1;  Self\<K>\Mark  m = 9;  the LINK Self\<K>\L -> Self\<K> (itself)
      Anc\<K>             a = 1;  Anc\<K>\D\Mark m = 9;  the LINK Anc\<K>\D\L -> Anc (above the copied key)
      Cyc\<K>             a = 1;  Cyc\<K>\Mark   m = 9;  the LINK Cyc\<K>\L1 -> Cyc2
      Cyc2                c = 2;                         the LINK Cyc2\L2 -> Cyc\<K> (a cycle of two links)
      Mov\<K>             a = 1;  the LINK Mov\<K>\L -> Jinde (a link elsewhere)
      Jinde               j = 5;  Jinde\Sub s = 6
      Cil                 empty (the copy target)
    <K> = "Klic" with its Czech accents.

      COPYSELF    F5 of Self\<K> into Cil\, OK to the first box: exactly one box, "Can't copy a key to
                  itself." naming Self\<K>\L; Cil\<K> holds a = 1 and Mark (m = 9), no Cil\<K>\L; the
                  source unchanged (before: a chain Cil\<K>\L\L\... dozens of keys deep)
      COPYCANCEL  the same, Cancel to the box: the same state (Mark is processed before L)
      COPYANC     F5 of Anc\<K> into Cil\, OK: one box naming Anc\<K>\D\L; Cil\<K>\D\Mark copied, no
                  Cil\<K>\D\L
      COPYCYCLE   F5 of Cyc\<K> into Cil\, OK: one box naming Cyc\<K>\L1\L2; Cil\<K>\L1 is a plain key
                  holding c = 2 (Cyc2, a link elsewhere, copied as before), no Cil\<K>\L1\L2
      COPYELSE    (control, unchanged) F5 of Mov\<K> into Cil\: no box; Cil\<K>\L a plain key with
                  j = 5 and Sub s = 6
      FINDSELF    Find "Mark" (keys only, subkeys on) in Self: exactly one result (before: Mark found
                  again below every L, L\L, ...)
      FINDANC     Find "Mark" in Anc: exactly one result
      FINDCYCLE   Find "Mark" in Cyc: exactly one result
      FINDELSE    (control, unchanged) Find "Sub" in Mov: one result, below Mov\<K>\L (the link
                  elsewhere is still followed)
    Rows of the review of 391:
      COPYTGT     Tgt\<K> (a = 1) holding the LINK L -> Cil (the target's parent), F5 into Cil\, Cancel:
                  one box naming Tgt\<K>\L\<K> (the walk reached the copy it writes); Cil\<K> a = 1,
                  nothing below Cil\<K>\L\<K> (before: 29 keys, 28 deep, error 87)
      FINDPERF    Find "009" in HKLM\...\CurrentVersion\Perflib (read only): one result, no box - its
                  language keys open as predefined pseudo-handles (the first version: "(6)" box)
      FINDPERFNT  Find "CurrentLanguage" in HKLM\...\CurrentVersion, access-denied (5) boxes answered
                  Skip All (they come before 391 too): one result, no other box
      END         each instance ends with exit code 0, no stray window, no report

    Links are created and removed with REG_OPTION_CREATE_LINK / REG_OPTION_OPEN_LINK + NtDeleteKey,
    each before the fixture tree is removed. The snapshot never follows a link.

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs; the
    product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. In the style of
    specs\297-regedt-delete-link\probe\link297_probe.ps1 (Copy) and
    specs\257-regedt-find-words-hex\probe\find_words_hex_probe.ps1 (Find).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lang = 'english',
    [string]$Repo
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

$RepoRoot = $(if ($Repo) { (Resolve-Path -LiteralPath $Repo).Path } else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path })
. (Join-Path $RepoRoot 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('RegLinkLoop' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class RegLinkLoop
{
    static readonly UIntPtr HKCU = new UIntPtr(0x80000001u);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegCreateKeyExW(UIntPtr h, string sub, int res, string cls, int opt, int sam, IntPtr sa, out UIntPtr r, out int disp);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegOpenKeyExW(UIntPtr h, string sub, int opt, int sam, out UIntPtr r);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegSetValueExW(UIntPtr h, string name, int res, int type, byte[] data, int size);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegQueryValueExW(UIntPtr h, string name, IntPtr res, out int type, byte[] data, ref int size);
    [DllImport("advapi32.dll")] static extern int RegCloseKey(UIntPtr h);
    [DllImport("ntdll.dll")] static extern int NtDeleteKey(UIntPtr h);
    [DllImport("ntdll.dll")] static extern int NtQueryKey(UIntPtr h, int cls, byte[] buf, int len, out int got);
    const int REG_OPTION_CREATE_LINK = 2, REG_OPTION_OPEN_LINK = 8, REG_LINK = 6;
    const int KEY_QUERY_VALUE = 1, KEY_SET_VALUE = 2, KEY_CREATE_LINK = 0x20, DELETE = 0x10000;
    public static int Make(string sub, string target)
    {
        UIntPtr h; int d;
        int e = RegCreateKeyExW(HKCU, sub, 0, null, REG_OPTION_CREATE_LINK, KEY_SET_VALUE | KEY_CREATE_LINK | KEY_QUERY_VALUE, IntPtr.Zero, out h, out d);
        if (e != 0) return e;
        if (d != 1) { RegCloseKey(h); return 183; }
        byte[] b = Encoding.Unicode.GetBytes(target);
        e = RegSetValueExW(h, "SymbolicLinkValue", 0, REG_LINK, b, b.Length);
        RegCloseKey(h);
        return e;
    }
    public static string Target(string sub)
    {
        UIntPtr h;
        if (RegOpenKeyExW(HKCU, sub, REG_OPTION_OPEN_LINK, KEY_QUERY_VALUE, out h) != 0) return null;
        string ret = null;
        byte[] f = new byte[12]; int got;
        if (NtQueryKey(h, 5, f, f.Length, out got) >= 0 && (BitConverter.ToInt32(f, 4) & 2) != 0)
        {
            ret = "(none)";
            int type, size = 0;
            if (RegQueryValueExW(h, "SymbolicLinkValue", IntPtr.Zero, out type, null, ref size) == 0 && type == REG_LINK)
            {
                byte[] b = new byte[size];
                if (RegQueryValueExW(h, "SymbolicLinkValue", IntPtr.Zero, out type, b, ref size) == 0)
                    ret = Encoding.Unicode.GetString(b, 0, size).TrimEnd('\0');
            }
        }
        RegCloseKey(h);
        return ret;
    }
    public static int Delete(string sub)
    {
        if (Target(sub) == null) return 2;
        UIntPtr h;
        int e = RegOpenKeyExW(HKCU, sub, REG_OPTION_OPEN_LINK, DELETE | KEY_QUERY_VALUE, out h);
        if (e != 0) return e;
        int s = NtDeleteKey(h);
        RegCloseKey(h);
        return s;
    }

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
}
'@
}

$Root = $TempRoot + '\tcloop'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
$K = 'Kl' + (Chars @(0x00ED, 0x010D))
$Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$RegName = 'TcProbeLoop'
$RegSub = 'Software\' + $RegName
$RegPs = 'HKCU:\' + $RegSub
$RegFs = 'reg:\HKEY_CURRENT_USER\' + $RegSub
$RegFull = 'HKEY_CURRENT_USER\' + $RegSub
$RegInt = '\REGISTRY\USER\' + $Sid + '\' + $RegSub
$Links = [ordered]@{}
$Links['Self\' + $K + '\L'] = 'Self\' + $K
$Links['Anc\' + $K + '\D\L'] = 'Anc'
$Links['Cyc\' + $K + '\L1'] = 'Cyc2'
$Links['Cyc2\L2'] = 'Cyc\' + $K
$Links['Mov\' + $K + '\L'] = 'Jinde'
$Links['Tgt\' + $K + '\L'] = 'Cil'                     # review of 391: into the copy target's parent

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P {
    $a = @('-t', 'TLOOP', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $proc = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($proc.Id); [void]$proc.Handle; $script:Procs[$proc.Id] = $proc
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $proc.Id) -and (Get-Main $proc.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $proc.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $proc.Id).Path -ine $Exe) { throw "pid $($proc.Id) is not $Exe" }
    try { [void]$proc.WaitForInputIdle(30000) } catch { }
    Sync $proc.Id
    Start-Sleep -Milliseconds 1500
    return $proc.Id
}
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\Settings\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
function Template([int]$Id, [string]$English) {
    if ($Lang -eq 'english') { return $English }
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $RepoRoot ("translations\{0}\regedt.slt" -f $Lang)), $Utf8)) {
        if ($line -match ('^' + $Id + ',\d+,"(.*)"\s*$')) { return $Matches[1].Replace('""', '"').Replace('\n', "`n").Replace('\t', "`t").Replace('\\', '\') }
    }
    throw "id $Id not found in the $Lang translation"
}
function End-P([string]$Case, [int]$Id, $Before) { $fatal = Fatal-Win $Id; End-Row $Case $Id $fatal $Before }
function Box-Text([IntPtr]$H) {
    $st = Kid $H 2477
    if ($st) { return [Drv098f]::GetText($st, 5000).Replace("`r", '') }
    return (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::Cls($_) -ne 'Button' } | ForEach-Object { [Drv098f]::GetText($_, 5000).Replace("`r", '') } | Where-Object { $_ }) -join "`n")
}
function New-Boxes([int]$Id, $Known, [double]$Seconds = 8) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $n = @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' })
        if ($n.Count) { Start-Sleep -Milliseconds 700; return $n }
        Start-Sleep -Milliseconds 150
    }
    return @()
}
function Press([IntPtr]$H, [int[]]$Ids) {
    if ($H -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($H)) { return }
    $b = $null
    foreach ($want in $Ids) { $b = Buttons $H | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1; if ($b) { break } }
    if ($b) { Click $b } else { Close-Win $H }
    Start-Sleep -Milliseconds 600
}
function Close-Boxes([int]$Id) {
    for ($i = 0; $i -lt 6; $i++) {
        $b = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })
        if (-not $b.Count) { return }
        foreach ($h in $b) { Press $h @(2, 7, 1) }
    }
}
function Go([int]$Id, [string]$Path) { [void](Do-ChangeDir $Id $Path); Sync $Id; Start-Sleep -Milliseconds 1200 }

# every link key below the fixture (found without following any link)
function Find-Links([string]$Rel) {
    $out = @()
    $item = Get-Item -LiteralPath ($RegPs + $(if ($Rel) { '\' + $Rel } else { '' })) -ErrorAction SilentlyContinue
    if (-not $item) { return @() }
    foreach ($n in @($item.GetSubKeyNames())) {
        $r = $(if ($Rel) { $Rel + '\' + $n } else { $n })
        if ($null -ne [RegLinkLoop]::Target($RegSub + '\' + $r)) { $out += $r } else { $out += @(Find-Links $r) }
    }
    return $out
}
function Remove-Fixture {
    if (-not (Test-Path -LiteralPath $RegPs)) { return }
    if ($null -ne [RegLinkLoop]::Target($RegSub)) { throw 'the fixture key itself is a link' }
    foreach ($l in @(Find-Links '')) {
        $e = [RegLinkLoop]::Delete($RegSub + '\' + $l)
        if ($e -ne 0) { throw ('cannot remove the link ' + $l + ': ' + $e) }
    }
    if (@(Find-Links '').Count) { throw 'links left in the fixture' }
    Remove-Item -LiteralPath $RegPs -Recurse -Force -ErrorAction SilentlyContinue
}
function New-Key([string]$Rel) { [void](New-Item -Path ($RegPs + '\' + $Rel) -Force) }
function Set-Val([string]$Rel, [string]$Name, [string]$Value) { [void](New-ItemProperty -LiteralPath ($RegPs + '\' + $Rel) -Name $Name -Value $Value -PropertyType String -Force) }
function Make-Fixture {
    NewDir $StartDir
    Remove-Fixture
    New-Key ('Self\' + $K + '\Mark'); Set-Val ('Self\' + $K) 'a' '1'; Set-Val ('Self\' + $K + '\Mark') 'm' '9'
    New-Key ('Anc\' + $K + '\D\Mark'); Set-Val ('Anc\' + $K) 'a' '1'; Set-Val ('Anc\' + $K + '\D\Mark') 'm' '9'
    New-Key ('Cyc\' + $K + '\Mark'); Set-Val ('Cyc\' + $K) 'a' '1'; Set-Val ('Cyc\' + $K + '\Mark') 'm' '9'
    New-Key 'Cyc2'; Set-Val 'Cyc2' 'c' '2'
    New-Key ('Mov\' + $K); Set-Val ('Mov\' + $K) 'a' '1'
    New-Key 'Jinde\Sub'; Set-Val 'Jinde' 'j' '5'; Set-Val 'Jinde\Sub' 's' '6'
    New-Key 'Cil'
    New-Key ('Tgt\' + $K); Set-Val ('Tgt\' + $K) 'a' '1'
    foreach ($l in $Links.Keys) {
        $e = [RegLinkLoop]::Make($RegSub + '\' + $l, $RegInt + '\' + $Links[$l])
        if ($e -ne 0) { throw ('cannot create the link ' + $l + ': ' + $e) }
    }
}
# every key under the fixture key, never following a link: 'rel|n=v;...' or 'rel|-> target'
function Snap-Keys([string]$Rel) {
    $out = @()
    $t = [RegLinkLoop]::Target($RegSub + '\' + $Rel)
    if ($null -ne $t) {
        if ($t.StartsWith($RegInt + '\', [StringComparison]::OrdinalIgnoreCase)) { $t = $t.Substring($RegInt.Length + 1) }
        return @(('{0}|-> {1}' -f $Rel, $t))
    }
    $item = $null
    try { $item = Get-Item -LiteralPath ($RegPs + '\' + $Rel) -ErrorAction SilentlyContinue } catch { }
    if (-not $item) { return @(('{0}|(no access)' -f $Rel)) }
    $vals = @($item.GetValueNames() | Sort-Object | ForEach-Object { $_ + '=' + $item.GetValue($_) }) -join ';'
    $out += ('{0}|{1}' -f $Rel, $vals)
    foreach ($n in @($item.GetSubKeyNames())) { $out += @(Snap-Keys ($Rel + '\' + $n)) }
    return $out
}
function Snapshot {
    if (-not (Test-Path -LiteralPath $RegPs)) { return @('(missing)') }
    $item = Get-Item -LiteralPath $RegPs
    $out = @()
    foreach ($n in @($item.GetSubKeyNames())) { $out += @(Snap-Keys $n) }
    return @($out | Sort-Object)
}
function Sub-Snap($Snap, [string]$Top) { return @($Snap | Where-Object { $_.StartsWith($Top + '|') -or $_.StartsWith($Top + '\') }) }
function Has-Line($Snap, [string]$Line) { return @($Snap | Where-Object { $_ -ceq $Line }).Count -eq 1 }
function Has-Key($Snap, [string]$Rel) { return @($Snap | Where-Object { $_.StartsWith($Rel + '|') }).Count -gt 0 }
function U8-Back([string]$s) { if ($null -eq $s) { return '' }; return $Utf8.GetString([Text.Encoding]::Default.GetBytes($s)) }
# how deep the copy wrote below Cil\<K>: the longest key path's element count
function Depth($Snap) {
    $m = 0
    foreach ($l in @(Sub-Snap $Snap ('Cil\' + $K))) { $n = ($l.Split('|')[0] -split '\\').Count - 2; if ($n -gt $m) { $m = $n } }
    return $m
}

function Run-Copy([string]$From, [string]$Target, [int[]]$Answer) {
    $res = @{ Boxes = @(); Pre = $null }
    $id = Start-P
    $res.Id = $id
    Go $id $From
    foreach ($vk in @(0x24, 0x28)) { Key $id $vk }        # "..", then <K> (the only key)
    $known2 = Get-Tops $id
    Post-Cmd (Get-Main $id) 727
    $dlg = Wait-NewWin $id $known2 10
    if ($dlg -eq [IntPtr]::Zero) { throw 'the command opened no dialog' }
    $edit = @([Drv098f]::Kids($dlg) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) }) | Select-Object -First 1
    if (-not $edit) { throw ('no edit field in the dialog: ' + (WinDesc $dlg)) }
    $res.Pre = [Drv098f]::GetText($edit, 5000)
    [void][Drv098f]::SetText($edit, $Target, 5000)
    $known2 = Get-Tops $id
    Click-Ok $dlg
    for ($i = 0; $i -lt 6; $i++) {
        $boxes = New-Boxes $id $known2 $(if ($i -eq 0) { 20 } else { 6 })
        if (-not $boxes.Count) { break }
        $h = $boxes[0]
        $res.Boxes += @{ Desc = (WinDesc $h); Text = (Box-Text $h) }
        Press $h $(if ($Answer) { $Answer } else { @(2) })
        $known2 = @($known2) + $h
    }
    Sync $id
    Start-Sleep -Milliseconds 1500
    Close-Boxes $id
    return $res
}
function Row-Copy([string]$Case, [string]$From, [int[]]$Answer, [scriptblock]$Judge) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        Make-Fixture
        $snap0 = Snapshot
        $r = Run-Copy ($RegFs + '\' + $From) ('\' + $RegFull + '\Cil\') $Answer
        $id = $r.Id
        $snap1 = Snapshot
        $r.Snap0 = $snap0
        $r.Snap1 = $snap1
        $r.SrcKept = (((Sub-Snap $snap0 $From) -join "`n") -ceq ((Sub-Snap $snap1 $From) -join "`n"))
        $r.Depth = Depth $snap1
        $cil = @(Sub-Snap $snap1 ('Cil\' + $K))
        $r.State = ('{0} keys below Cil, depth {1}: {2}' -f $cil.Count, $r.Depth, ((@($cil | Select-Object -First 8) | ForEach-Object { Esc $_ }) -join ' , '))
        & $Judge $r
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Close-Boxes $id; End-P $Case $id $before } }
}
function Box-Facts($r) {
    if (-not $r.Boxes.Count) { return 'boxes: none' }
    return ('boxes: ' + (($r.Boxes | ForEach-Object { "{0}; text '{1}'" -f $_.Desc, (Tail (Esc $_.Text) 240) }) -join ' || '))
}
$Itself = (Template 1065 "Name:`t%ls`n`nError:`tCan't copy a key to itself.").Split("`n")[-1]
$Itself = $Itself.Substring($Itself.IndexOf("`t") + 1).Trim()
function One-Itself($r, [string]$Rel) {
    if ($r.Boxes.Count -ne 1) { return $false }
    $t = $r.Boxes[0].Text; $u = U8-Back $t
    return ($t.Contains($Itself) -or $u.Contains($Itself)) -and ($u.Contains($RegFull + '\' + $Rel + "`n") -or $t.Contains($RegFull + '\' + $Rel + "`n"))
}

# ---- Find ----
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
$Finds = @(
    @{ Row = 'FINDSELF'; In = 'Self'; Pattern = 'Mark'; Want = @('Mark|' + $RegFull + '\Self\' + $K) },
    @{ Row = 'FINDANC'; In = 'Anc'; Pattern = 'Mark'; Want = @('Mark|' + $RegFull + '\Anc\' + $K + '\D') },
    @{ Row = 'FINDCYCLE'; In = 'Cyc'; Pattern = 'Mark'; Want = @('Mark|' + $RegFull + '\Cyc\' + $K) },
    @{ Row = 'FINDELSE'; In = 'Mov'; Pattern = 'Sub'; Want = @('Sub|' + $RegFull + '\Mov\' + $K + '\L') },
    # review of 391: Perflib\009, \CurrentLanguage open as performance pseudo-handles (no identity)
    @{ Row = 'FINDPERF'; Look = 'reg:\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib'; Pattern = '009'; Want = @('009|HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib') },
    @{ Row = 'FINDPERFNT'; Look = 'reg:\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; Pattern = 'CurrentLanguage'; Answer = 174; Allow = '(5)'; Want = @('CurrentLanguage|HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib') }
)
function Search-Once([int]$Id, [IntPtr]$Fw, $S) {
    $pat = Kid $Fw 136; $lv = Kid $Fw 149; $look = Kid $Fw 137
    foreach ($cb in @(@(140, 1), @(142, 1), @(145, 0), @(146, 0), @(147, 0), @(150, 0), @(143, 0), @(144, 1))) {
        $h = Kid $Fw $cb[0]
        if ($h) { [void][Drv098f]::Send($h, 0x00F1, $cb[1], 0, 5000) }   # BM_SETCHECK
    }
    [void][Drv098f]::SetText($pat, $S.Pattern, 5000)
    if ($S.Look) { [void][Drv098f]::SetText($look, $S.Look, 5000); $S.In = $S.Look } else { [void][Drv098f]::SetText($look, ($RegFs + '\' + $S.In), 5000) }
    $known = @(Get-Tops $Id)
    Click (Kid $Fw 1)
    Start-Sleep -Milliseconds 1500
    $sw = [Diagnostics.Stopwatch]::StartNew(); $n = -1; $boxes = @()
    while ($sw.Elapsed.TotalSeconds -lt 60) {
        Start-Sleep -Milliseconds 500
        foreach ($b in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $_ -ne $Fw -and $known -notcontains $_ })) {
            $boxes += (WinDesc $b); Press $b $(if ($S.Answer) { @($S.Answer, 2) } else { @(2) }); $known += $b
        }
        $m = [RegLinkLoop]::SendR($lv, 0x1004, 0, 0)
        if ($m -eq $n -and $sw.Elapsed.TotalSeconds -gt 4) { break }
        $n = $m
    }
    $found = @(for ($i = 0; $i -lt $n; $i++) { $p = ''; foreach ($sc in 1..3) { $t = [RegLinkLoop]::LvText($lv, $i, $sc); if ($t -and $t.Contains('\')) { $p = $t; break } }; ([RegLinkLoop]::LvText($lv, $i, 0)) + '|' + $p })
    $foundU = @($found | ForEach-Object { $_ })
    $ok = ($n -eq $S.Want.Count) -and ((($foundU | Sort-Object) -join ',') -ceq (($S.Want | Sort-Object) -join ',')) -and @($boxes | Where-Object { -not ($S.Allow -and $_.Contains($S.Allow)) }).Count -eq 0
    $deep = 0; foreach ($f in $foundU) { $c = ([regex]::Matches($f, '\\L')).Count; if ($c -gt $deep) { $deep = $c } }
    Row $S.Row 'FOUND' (V $ok) ("'{0}' in {1}: {2} result(s), deepest path with {3} link step(s); first: [{4}]; expected [{5}]{6}" -f $S.Pattern, $S.In, $n, $deep, ((@($foundU | Select-Object -First 3) | ForEach-Object { Esc $_ }) -join ' ; '), (($S.Want | ForEach-Object { Esc $_ }) -join ' ; '), $(if ($boxes.Count) { '; boxes: ' + (Tail ($boxes -join ' || ') 300) } else { '' }))
}
function Run-Find {
    if (-not (@($Finds | Where-Object { Want $_.Row }).Count)) { return }
    $before = Reports; $id = 0
    try {
        Make-Fixture
        $id = Start-P
        Go $id $RegFs
        $known = Get-Tops $id
        $note = [RegLinkLoop]::ModKey((Get-LeftList $id), 0x4A, 3)
        $fw = Wait-NewWin $id $known 10
        if ($fw -eq [IntPtr]::Zero) { foreach ($c in $Finds) { Row $c.Row 'FOUND' 'NOT DRIVEN' ("Ctrl+Shift+J opened no window (key: {0}; hot keys: {1})" -f $note, $script:HotKeyNote) }; return }
        Start-Sleep -Milliseconds 800
        if (-not (Kid $fw 136) -or -not (Kid $fw 149) -or -not (Kid $fw 137)) { foreach ($c in $Finds) { Row $c.Row 'FOUND' 'NOT DRIVEN' ('controls not found in ' + (WinDesc $fw)) }; return }
        Out ("Find window look-in at open: '{0}'" -f (Esc ([Drv098f]::GetText((Kid $fw 137), 5000))))
        foreach ($c in $Finds) { if (Want $c.Row) { Search-Once $id $fw $c } }
        $s1 = Snapshot
        Close-Win $fw
        Start-Sleep -Milliseconds 800
    }
    catch { Row 'FIND' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Close-Boxes $id; End-P 'FIND' $id $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc391_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    $script:HotKeyNote = Set-HotKeys
    Out ("loop391_probe (feature 391), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}; hot keys: {5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash, $script:HotKeyNote)
    Out ("Fixture : {0}" -f ((Snapshot | ForEach-Object { Esc $_ }) -join ' , '))
    Out ''

    $OkAns = @(1, 2)
    Row-Copy 'COPYSELF' 'Self' $OkAns {
        param($r)
        $s = $r.Snap1
        Row 'COPYSELF' 'BOX' (V (One-Itself $r ('Self\' + $K + '\L'))) ("exactly one box, can't-copy-to-itself naming Self\<K>\L; {0}" -f (Box-Facts $r))
        $ok = (Has-Line $s ('Cil\' + $K + '|a=1')) -and (Has-Line $s ('Cil\' + $K + '\Mark|m=9')) -and -not (Has-Key $s ('Cil\' + $K + '\L')) -and $r.SrcKept
        Row 'COPYSELF' 'STATE' (V $ok) ("Cil\<K> with a = 1 and Mark, no L, source unchanged ({0}): {1}; {2}" -f $r.SrcKept, $ok, $r.State)
    }
    Row-Copy 'COPYCANCEL' 'Self' @(2) {
        param($r)
        $s = $r.Snap1
        Row 'COPYCANCEL' 'BOX' (V (One-Itself $r ('Self\' + $K + '\L'))) ("exactly one box naming Self\<K>\L; {0}" -f (Box-Facts $r))
        $ok = (Has-Line $s ('Cil\' + $K + '|a=1')) -and (Has-Line $s ('Cil\' + $K + '\Mark|m=9')) -and -not (Has-Key $s ('Cil\' + $K + '\L')) -and $r.SrcKept
        Row 'COPYCANCEL' 'STATE' (V $ok) ("Cil\<K> with a = 1 and Mark, no L, source unchanged ({0}): {1}; {2}" -f $r.SrcKept, $ok, $r.State)
    }
    Row-Copy 'COPYANC' 'Anc' $OkAns {
        param($r)
        $s = $r.Snap1
        Row 'COPYANC' 'BOX' (V (One-Itself $r ('Anc\' + $K + '\D\L'))) ("exactly one box naming Anc\<K>\D\L; {0}" -f (Box-Facts $r))
        $ok = (Has-Line $s ('Cil\' + $K + '|a=1')) -and (Has-Line $s ('Cil\' + $K + '\D\Mark|m=9')) -and -not (Has-Key $s ('Cil\' + $K + '\D\L')) -and $r.SrcKept
        Row 'COPYANC' 'STATE' (V $ok) ("Cil\<K>\D\Mark copied, no D\L, source unchanged ({0}): {1}; {2}" -f $r.SrcKept, $ok, $r.State)
    }
    Row-Copy 'COPYCYCLE' 'Cyc' $OkAns {
        param($r)
        $s = $r.Snap1
        Row 'COPYCYCLE' 'BOX' (V (One-Itself $r ('Cyc\' + $K + '\L1\L2'))) ("exactly one box naming Cyc\<K>\L1\L2; {0}" -f (Box-Facts $r))
        $ok = (Has-Line $s ('Cil\' + $K + '|a=1')) -and (Has-Line $s ('Cil\' + $K + '\Mark|m=9')) -and (Has-Line $s ('Cil\' + $K + '\L1|c=2')) -and -not (Has-Key $s ('Cil\' + $K + '\L1\L2')) -and $r.SrcKept
        Row 'COPYCYCLE' 'STATE' (V $ok) ("Cil\<K>\L1 plain with c = 2, no L1\L2, source unchanged ({0}): {1}; {2}" -f $r.SrcKept, $ok, $r.State)
    }
    Row-Copy 'COPYELSE' 'Mov' $null {
        param($r)
        $s = $r.Snap1
        $ok = (Has-Line $s ('Cil\' + $K + '|a=1')) -and (Has-Line $s ('Cil\' + $K + '\L|j=5')) -and (Has-Line $s ('Cil\' + $K + '\L\Sub|s=6')) -and $r.SrcKept -and $r.Boxes.Count -eq 0
        Row 'COPYELSE' 'STATE' (V $ok) ("copied as before (the link's target as a plain key), no box: {0}; {1}; {2}" -f $ok, (Box-Facts $r), $r.State)
    }
    # review of 391: the link leads into the target's parent, so the walk reaches the copy it writes
    Row-Copy 'COPYTGT' 'Tgt' @(2) {
        param($r)
        $s = $r.Snap1
        Row 'COPYTGT' 'BOX' (V (One-Itself $r ('Tgt\' + $K + '\L\' + $K))) ("exactly one box naming Tgt\<K>\L\<K> (the copy reached through the link); {0}" -f (Box-Facts $r))
        $ok = (Has-Line $s ('Cil\' + $K + '|a=1')) -and -not (Has-Key $s ('Cil\' + $K + '\L\' + $K)) -and $r.SrcKept -and $r.Depth -le 2
        Row 'COPYTGT' 'STATE' (V $ok) ("Cil\<K> with a = 1, nothing below Cil\<K>\L\<K>, depth {0}, source unchanged ({1}): {2}; {3}" -f $r.Depth, $r.SrcKept, $ok, $r.State)
    }
    Run-Find
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($sp in @($Started)) { if (Test-Alive $sp) { Stop-Process -Id $sp -Force } }
    Start-Sleep -Milliseconds 600
    try { Remove-Fixture } catch { Out ('CLEANUP ERROR: ' + $_.Exception.Message) }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture keys removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not (Test-Path -LiteralPath $RegPs)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
