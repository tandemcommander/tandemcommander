<#
.SYNOPSIS
    Feature 121 probe (the small batch): the Find window's Look in field takes a long path whole,
    the message box breaks lines only inside an over-wide word, a copy command reports a clipboard
    that cannot be opened, the "name already used" text is exact in any code page, a failed
    Checksum save is reported, Disk Map's log shows paths exactly, a typed FTP login that does not
    fit is refused (never cut), the Registry Editor's Find window and FTP's Logs window no longer
    block an installer's close request, and closing the program right after fcremote started it
    never asks "plugin has rejected to unload".

.DESCRIPTION
    Rows (names for -Only)                                                     fixed     before
      F1  Find from a panel on a 400-byte accented folder with a ';' in a name:
          the Look in text is the panel path, ';' doubled                       whole     cut at 259 B
      F2  Find Now from F1's Look in finds the one needle file there           1 found   (reported)
      F3  a typed 420-byte accented Look in (WM_SETTEXT), Find Now               1 found   (reported)
      M1  the "equivalent names" notice for a 175-character NFC/NFD name pair:
          every single line break of the box lies inside the name             yes       no (template cut)
      C1  Copy Full Name with the clipboard held by the probe                  error box no window
      C2  Copy Name, the same                                                    error box no window
      C3  Copy Full Path, the same                                               error box no window
          (the box's title is "Copy To Clipboard" without the menu's '&')
      N1  French UI, F5 of a folder onto a FILE of its name: the error text of
          the dialog is the French "name already used" exactly (code page 1250
          lacks a-grave)                                                          exact     best fit
      K1  Checksum Calculate, Save over a list locked by the probe (the write
          fails after the open): a message                                      box       no box
      D1  Disk Map log: the "Ignoring Reparse Point" row names the accented
          junction exactly (read with LVM_GETITEMTEXTW)                          exact     mojibake
      P1  Change Directory to ftp://<101-byte user>@127.0.0.1:1/ - refused      too long  connects
      P3  ... ftp://u:<110 x c-caron = 220 bytes>@127.0.0.1:1/ - NOT refused   no refusal (the same)
          (the plug-in starts connecting; the instance is ended by the probe, no END row)
      P4  F5 target ftp://u:<301-byte password>@127.0.0.1:1/ - refused by the
          core already (its target field takes 259 bytes - run 2): never cut      refused   refused
      P5  F5 target ftp://<101-byte user>@127.0.0.1:1/ - refused by the plug-in  too long  connects
          (run 2: a password over 300 bytes cannot reach the plug-in through Change Directory or
          the F5 target - the core refuses typed paths over 259 bytes; the plug-in's password
          check is defensive)
      K0  item 12: the folder Checksum's Save dialog opens in (UI Automation)   the panel  (reported)
      R1  Registry Editor Find window open (not searching) + the installer's
          close request (rm_probe.ps1 of feature 080)                           agree     decline
      L1  FTP Logs window open + the installer's close request                  agree     decline
      S1  fcremote.exe starts the program with two files, the probe closes the
          program the moment its main window shows, 6 times: no "rejected to
          unload. Force?" box, exit code 0 every time                          0 boxes   (reported)

    Not driven here (reasons in fix-log.md): the folder picker's NetHood resolve (a tree-view
    pick in SHBrowseForFolder - saltests resolve a real folder shortcut end to end), FTP's Welcome
    Message window (needs a server), the wipes and the log/wait-window cuts of FTP (memory and
    display only), the Find window's copy commands (same helper as C1-C3).

    MUST run through tools\run_on_hidden_desktop.ps1 (refuses the Default / Winlogon desktop, the
    098 library refuses too). Refuses while any tandemcommander.exe runs (the probes share
    HKCU\Software\Tandem Commander). The whole key is exported before, restored and SHA-256-
    verified after. Fixtures under %TEMP%\tc121 (removed at the end). Exit code = FAIL rows.

.PARAMETER Exe
    tandemcommander.exe of the build under test (Debug_x64_121 or Debug_x64_pre121).
.PARAMETER Expect
    fixed (the build of feature 121) or before (Debug_x64_pre121, the control).
.PARAMETER Only
    Rows to run, e.g. -Only F1,M1 (prefixes allowed: -Only C).
.PARAMETER RegBaseline
    Prefix of the SHA-256 of the registry export expected before the run (reported, not enforced).
.PARAMETER Rounds
    S1's rounds (default 6).

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$RegBaseline,
    [int]$Rounds = 6
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

if (-not ('Drv121' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv121
{
    [DllImport("user32.dll")] static extern IntPtr GetThreadDesktop(uint threadId);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool GetUserObjectInformationW(IntPtr h, int index, StringBuilder info, int length, out int needed);
    public static string DesktopName()
    {
        var sb = new StringBuilder(256); int needed;
        if (!GetUserObjectInformationW(GetThreadDesktop(GetCurrentThreadId()), 2, sb, sb.Capacity * 2, out needed)) return "";
        return sb.ToString();
    }
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetMenuState(IntPtr m, uint id, uint flags);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool OpenClipboard(IntPtr h);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool CloseClipboard();
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
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift) - the 100/102/104/115/117/118 method
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
    // the text of a list view cell of ANOTHER process (LVM_GETITEMTEXTW with an LVITEMW and a text
    // buffer allocated in that process); null when the process cannot be opened
    public static string LvText(IntPtr lv, int item, int sub)
    {
        uint pid; GetWindowThreadProcessId(lv, out pid);
        IntPtr hp = OpenProcess(0x0008 | 0x0010 | 0x0020 | 0x0400, false, pid); // VM_OPERATION, VM_READ, VM_WRITE, QUERY_INFORMATION
        if (hp == IntPtr.Zero) return null;
        try
        {
            const int lvSize = 128, cch = 4096;
            IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, (UIntPtr)(uint)(lvSize + cch * 2), 0x3000, 0x04);
            if (mem == IntPtr.Zero) return null;
            try
            {
                var lvi = new byte[lvSize];
                BitConverter.GetBytes(1).CopyTo(lvi, 0);       // mask LVIF_TEXT
                BitConverter.GetBytes(item).CopyTo(lvi, 4);    // iItem
                BitConverter.GetBytes(sub).CopyTo(lvi, 8);     // iSubItem
                long textPtr = mem.ToInt64() + lvSize;
                BitConverter.GetBytes(textPtr).CopyTo(lvi, 24); // pszText (x64 layout)
                BitConverter.GetBytes(cch).CopyTo(lvi, 32);     // cchTextMax
                IntPtr w;
                if (!WriteProcessMemory(hp, mem, lvi, lvSize, out w)) return null;
                IntPtr r;
                if (SendMessageTimeoutW(lv, 0x1073, (IntPtr)item, mem, 0, 5000, out r) == IntPtr.Zero) return null; // LVM_GETITEMTEXTW
                int n = (int)r.ToInt64(); if (n < 0) n = 0; if (n > cch - 1) n = cch - 1;
                var buf = new byte[n * 2];
                IntPtr rd;
                if (n > 0 && !ReadProcessMemory(hp, (IntPtr)textPtr, buf, n * 2, out rd)) return null;
                return Encoding.Unicode.GetString(buf);
            }
            finally { VirtualFreeEx(hp, mem, UIntPtr.Zero, 0x8000); }
        }
        finally { CloseHandle(hp); }
    }
    [DllImport("kernel32.dll")] public static extern uint GetACP();
}
'@
}
$deskName = [Drv121]::DesktopName()
if (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon') { Write-Output ("NOT RUN: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$RmProbe = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\080-restart-manager-upgrade\probe\rm_probe.ps1')).Path
$Fcremote = Join-Path (Split-Path $Exe) 'plugins\filecomp\fcremote.exe'

$Fixed = ($Expect -eq 'fixed')
$Root = $TempRoot + '\tc121'
$StartDir = $Root + '\start'
$WaitClass = 'SalamanderSaveBits'
$DmClass = 'Zar.DM.MainWin.WC'
$DmLogClass = 'Zar.DM.LogWin.WC'
$FcKey = 'HKCU:\Software\Tandem Commander\0.1\Plugins Configuration\File Comparator'
$script:HotKeyNote = 'not set'

# ---- names (pure ASCII source: the characters from their codes) ----------------------------------
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
$CzRun = Chars @(0x010D, 0x0159, 0x017E, 0x00FD, 0x00E1, 0x00ED, 0x00E9, 0x016F, 0x0161, 0x011B)   # 10 accented letters, 2 bytes each
function CzComp([int]$Reps, [string]$Tag) { return ($Tag + ($CzRun * $Reps)) }
$FindDir = $Root + '\find\' + (CzComp 4 'a') + '\' + (CzComp 4 'b') + '\x;y ' + (CzComp 4 'c') + '\' + (CzComp 4 'd') + '\' + (CzComp 3 'e')
$FindDir2 = $Root + '\find2\' + (CzComp 4 'p') + '\' + (CzComp 4 'q') + '\' + (CzComp 4 'r') + '\' + (CzComp 4 's') + '\' + (CzComp 3 't')
$Needle = 'needle121.txt'
$EquivDir = $Root + '\equiv'
$EqBase = ('x' * 170)
$EqNfc = $EqBase + [char]0x00E9 + '.txt'
$EqNfd = $EqBase + 'e' + [char]0x0301 + '.txt'
$ClipDir = $Root + '\clip'
$CsDir = $Root + '\cs'
$DmDir = $Root + '\dm_' + (Chars @(0x010D, 0x0159))
$JName = 'j' + (Chars @(0x0159, 0x00ED, 0x017E))
$CrdSrc = $Root + '\crd\src'
$CrdDst = $Root + '\crd\dst'
$FcDir = $Root + '\fc'
$FrenchAlready = 'ce nom de fichier est d' + [char]0x00E9 + 'j' + [char]0x00E0 + ' utilis' + [char]0x00E9 + '.'   # translations\french\salamand.slt 10145
$FrenchAlreadyDir = 'Ce nom est d' + [char]0x00E9 + 'j' + [char]0x00E0 + ' utilis' + [char]0x00E9 + ' pour un r' + [char]0x00E9 + 'pertoire.'   # 10185

# ---- helpers ----------------------------------------------------------------------------------
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Start-P([string]$Left, [string]$Right) {
    if (-not $Right) { $Right = $StartDir }
    $a = @('-t', 'T121', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
function Close-Boxes([int]$Id, [IntPtr]$Keep = [IntPtr]::Zero) {
    foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $_ -ne $Keep })) { Close-Win $h }
}
function Open-ByKey([int]$Id, [int]$Vk, [double]$Seconds = 10) {
    $known = Get-Tops $Id
    $note = [Drv121]::ModKey((Get-LeftList $Id), $Vk, 3)
    $h = Wait-NewWin $Id $known $Seconds
    if ($h -eq [IntPtr]::Zero) { throw ("Ctrl+Shift+{0} opened no window (key: {1}; hot keys: {2})" -f [char]$Vk, $note, $script:HotKeyNote) }
    return $h
}
function Wait-Class([int]$Id, [string]$Cls, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $h = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq $Cls }) | Select-Object -First 1
        if ($h) { return $h }
        Start-Sleep -Milliseconds 150
    }
    return [IntPtr]::Zero
}
# new top-level windows of the pid (not in $Known) within $Seconds: @{ Hwnd; Desc; Title }
function Collect-New([int]$Id, $Known, [double]$Seconds) {
    $found = New-Object System.Collections.ArrayList; $seen = @{}
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in (Get-Tops $Id)) {
            if ($Known -contains $h -or [Drv098f]::Cls($h) -eq $MainClass) { continue }
            $k = $h.ToInt64()
            if (-not $seen.ContainsKey($k)) { $seen[$k] = 1; Start-Sleep -Milliseconds 400; [void]$found.Add([pscustomobject]@{ Hwnd = $h; Desc = (WinDesc $h); Title = [Drv098f]::Txt($h) }) }
        }
        Start-Sleep -Milliseconds 150
    }
    return $found
}
function Lv-Count([IntPtr]$Lv) { return [Drv121]::SendR($Lv, 0x1004, 0, 0) }   # LVM_GETITEMCOUNT

# gives plug-in commands keys for this session (the 118 method; the whole key is restored after):
# Disk Map Ctrl+Shift+D, Checksum Calculate Ctrl+Shift+U, Registry Editor Find Ctrl+Shift+G,
# FTP Show Logs Ctrl+Shift+L
function Set-HotKeys {
    $plugins = 'HKCU:\Software\Tandem Commander\0.1\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key' }
    $map = @(
        @{ Dll = 'diskmap\.spl$'; Id = 1; Key = 0x10344 },
        @{ Dll = 'checksum\.spl$'; Id = 1; Key = 0x10355 },
        @{ Dll = 'regedt\.spl$'; Id = 1; Key = 0x10347 },
        @{ Dll = 'ftp\.spl$'; Id = 5; Key = 0x1034C })
    $notes = @()
    foreach ($k in @(Get-ChildItem $plugins)) {
        $dll = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DLL
        if (-not $dll) { continue }
        foreach ($m in $map) {
            if ($dll -notmatch $m.Dll) { continue }
            $menu = Join-Path $k.PSPath 'Menu'
            if (-not (Test-Path $menu)) { $notes += ("{0}: no Menu key" -f $dll); continue }
            $set = 0
            foreach ($mi in @(Get-ChildItem $menu)) {
                if ((Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID -eq $m.Id) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value $m.Key -Type DWord; $set++ }
            }
            $notes += ("{0} id {1}: {2}" -f (Split-Path $dll -Leaf), $m.Id, $set)
        }
    }
    return ($notes -join '; ')
}
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
function Set-LoadOnStart([bool]$On) {
    $pk = Get-ChildItem 'HKCU:\Software\Tandem Commander\0.1\Plugins' -ErrorAction SilentlyContinue | Where-Object { $_.GetValue('DLL') -match 'filecomp\.spl$' } | Select-Object -First 1
    if (-not $pk) { return $false }
    if ($On) { Set-ItemProperty -LiteralPath $pk.PSPath -Name 'Load On Start' -Value 1 -Type DWord } else { Remove-ItemProperty -LiteralPath $pk.PSPath -Name 'Load On Start' -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $FcKey) { Set-ItemProperty -LiteralPath $FcKey -Name 'Load On Start' -Value $(if ($On) { 1 } else { 0 }) -Type DWord }
    return $true
}

# the installer's request (rm_probe.ps1 of feature 080), the screen watched meanwhile (118's code)
function Invoke-RmWatched([int]$Id) {
    $before = Get-Tops $Id
    $out = [IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $RmProbe), '-ExePath', ('"{0}"' -f $Exe)) `
        -RedirectStandardOutput $out -PassThru -WindowStyle Hidden
    $null = $p.Handle
    $new = @{}
    while (-not $p.HasExited) {
        foreach ($h in (Get-Tops $Id)) {
            if ($before -notcontains $h -and -not $new.ContainsKey($h.ToInt64())) { $new[$h.ToInt64()] = (WinDesc $h) }
        }
        Start-Sleep -Milliseconds 30
    }
    $p.WaitForExit()
    $text = @(Get-Content -LiteralPath $out)
    Remove-Item -LiteralPath $out -Force
    $line = ($text | Where-Object { $_ -match '^RmShutdown' } | Select-Object -First 1)
    $secs = $null
    if ($line -match 'after ([\d\.,]+) s') { $secs = [double]($Matches[1] -replace ',', '.') }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if ($p.ExitCode -eq 0) { while ($sw.Elapsed.TotalSeconds -lt 10 -and (Test-Alive $Id)) { Start-Sleep -Milliseconds 100 } }
    $alive = Test-Alive $Id
    $shown = @($new.Values)
    return [pscustomobject]@{ Exit = $p.ExitCode; Line = $line; Seconds = $secs; Shown = $shown; Alive = $alive; Before = $before; Output = $text
        Other = @($shown | Where-Object { $_ -notmatch ('^\[' + [regex]::Escape($WaitClass) + ' ') }); Wait = @($shown | Where-Object { $_ -match ('^\[' + [regex]::Escape($WaitClass) + ' ') }) }
}
# the verdict of an RM row: agree (process ended, exit 0, nothing shown but the wait window) or
# decline (rm_probe exit 1 within 1 s, alive, windows kept, nothing new)
function Rm-Verdict([string]$Case, [int]$Id, $R, [bool]$Agree, $Reports) {
    foreach ($s in $R.Shown) { Out ("           shown: " + $s) }
    if ($Agree) {
        $ec = ExitCodeOf $Id
        $rep = @(Take-Reports $Reports)
        $ok = ($R.Exit -eq 0) -and (-not $R.Alive) -and ($R.Other.Count -eq 0) -and ($ec -eq '0x00000000') -and ($rep.Count -eq 0)
        Row $Case 'RM' (V $ok) ("expected agree: rm_probe exit {0}; {1}; process ended {2}, exit code {3}; new windows {4} (+{5} core wait window); new crash reports {6}" -f $R.Exit, $R.Line, (-not $R.Alive), $ec, $R.Other.Count, $R.Wait.Count, $rep.Count)
    }
    else {
        $still = Get-Tops $Id
        $kept = @($R.Before | Where-Object { $still -contains $_ }).Count
        $ok = ($R.Exit -eq 1) -and $R.Alive -and ($R.Shown.Count -eq 0) -and ($null -ne $R.Seconds) -and ($R.Seconds -le 1.0) -and ($kept -eq @($R.Before).Count)
        Row $Case 'RM' (V $ok) ("expected decline: rm_probe exit {0}; {1}; process alive {2}; windows kept {3}/{4}; new windows {5}" -f $R.Exit, $R.Line, $R.Alive, $kept, @($R.Before).Count, $R.Shown.Count)
    }
    if (-not $ok) { $R.Output | ForEach-Object { Out ("           rm> " + $_) } }
}
function End-P([string]$Case, [int]$Id, $Before) {
    if (-not (Test-Alive $Id)) { return }
    Close-Boxes $Id
    Start-Sleep -Milliseconds 300
    End-Row $Case $Id $null $Before
}

# ---- fixture ---------------------------------------------------------------------------------
function Make-Fixture {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    foreach ($d in @($StartDir, $FindDir, $FindDir2, $EquivDir, $ClipDir, $CsDir, $DmDir, ($Root + '\dm_target'), ($CrdSrc + '\dup'), $CrdDst, $FcDir)) { NewDir $d }
    WriteFile ($FindDir + '\' + $Needle) 'needle'
    WriteFile ($FindDir2 + '\' + $Needle) 'needle'
    WriteFile ($Root + '\find\' + $Needle + '.decoy.txt') 'not the needle'
    [IO.File]::WriteAllText($LP + $EquivDir + '\' + $EqNfc, 'nfc')
    [IO.File]::WriteAllText($LP + $EquivDir + '\' + $EqNfd, 'nfd')
    WriteFile ($ClipDir + '\a.txt') 'a'
    $bytes = New-Object byte[] 4096; (New-Object Random 121).NextBytes($bytes)
    [IO.File]::WriteAllBytes($LP + $CsDir + '\one.bin', $bytes)
    WriteFile ($CsDir + '\two.txt') 'two'
    for ($i = 0; $i -lt 5; $i++) { WriteFile ($DmDir + '\f' + $i + '.txt') ('x' * (100 * ($i + 1))) }
    $j = & cmd.exe /c ('mklink /J "{0}\{1}" "{2}\dm_target" 2>&1' -f $DmDir, $JName, $Root)
    WriteFile ($CrdSrc + '\dup\inner.txt') 'inner'
    WriteFile ($CrdDst + '\dup') 'a FILE named like the copied folder'
    [IO.File]::WriteAllText($LP + $FcDir + '\a.txt', "alpha`r`nbeta`r`n", (New-Object Text.ASCIIEncoding))
    [IO.File]::WriteAllText($LP + $FcDir + '\b.txt', "alpha`r`nBETA`r`n", (New-Object Text.ASCIIEncoding))
    $jOk = [IO.Directory]::Exists($LP + $DmDir + '\' + $JName)
    return ("Find folder {0} bytes ({1} units), typed Look in {2} bytes; equivalent pair of {3} units; junction {4} ({5})" -f (U8Len $FindDir), $FindDir.Length, (U8Len $FindDir2), $EqNfc.Length, $jOk, (($j | ForEach-Object { "$_" }) -join ' '))
}

# ---- rows --------------------------------------------------------------------------------------
# F1-F3: the Find window
function Find-Run([IntPtr]$Find, [int]$Id) {
    $named = Find-Ctl $Find 2505
    [void][Drv098f]::SetText($named, $Needle, 5000)
    $lv = @([Drv098f]::Kids($Find) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2510 }) | Select-Object -First 1
    $known = Get-Tops $Id
    Post-Cmd $Find 1   # Find Now
    $count = -1; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        Start-Sleep -Milliseconds 300
        if ($lv) { $count = [int](Lv-Count $lv) }
        if ($count -ge 1 -and $sw.Elapsed.TotalSeconds -gt 2) { break }
    }
    $boxes = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' } | ForEach-Object { WinDesc $_ })
    return @{ Count = $count; Boxes = $boxes }
}
function Row-Find {
    if (-not ((Want 'F1') -or (Want 'F2') -or (Want 'F3'))) { return }
    $before = Reports; $id = 0; $find = [IntPtr]::Zero
    try {
        $id = Start-P $FindDir
        $find = Open-ByCmd $id 741 10
        if ($find -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
        $look = [Drv098f]::GetText((Find-Ctl $find 2501), 5000)
        $want = $FindDir.Replace(';', ';;')
        if (Want 'F1') {
            $whole = ($look -ceq $want)
            if ($Fixed) { $ok = $whole } else { $ok = (-not $whole) -and ((U8Len $look) -le 259) }
            Row 'F1' 'LOOKIN' (V $ok) ("Look in {0} bytes '{1}'; the panel path escaped {2} bytes; equal {3} (expected: {4})" -f (U8Len $look), (Tail $look 60), (U8Len $want), $whole, $(if ($Fixed) { 'whole' } else { 'cut at 259 bytes' }))
        }
        if (Want 'F2') {
            $r = Find-Run $find $id
            $v = $(if ($Fixed) { V ($r.Count -eq 1 -and $r.Boxes.Count -eq 0) } else { 'INFO' })
            Row 'F2' 'FIND' $v ("Find Now from that Look in: {0} found; boxes: {1}" -f $r.Count, $(if ($r.Boxes.Count) { $r.Boxes -join ' || ' } else { 'none' }))
            Close-Boxes $id $find
        }
        if (Want 'F3') {
            [void][Drv098f]::SetText((Find-Ctl $find 2501), $FindDir2, 5000)
            $typed = [Drv098f]::GetText((Find-Ctl $find 2501), 5000)
            $r = Find-Run $find $id
            $v = $(if ($Fixed) { V ($typed -ceq $FindDir2 -and $r.Count -eq 1 -and $r.Boxes.Count -eq 0) } else { 'INFO' })
            Row 'F3' 'FIND' $v ("typed Look in {0} bytes held whole {1}; Find Now: {2} found; boxes: {3}" -f (U8Len $FindDir2), ($typed -ceq $FindDir2), $r.Count, $(if ($r.Boxes.Count) { $r.Boxes -join ' || ' } else { 'none' }))
            Close-Boxes $id $find
        }
    }
    catch { Row 'F' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($find -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($find)) { Close-Win $find; Start-Sleep -Milliseconds 500 }
        if ($id) { End-P 'F' $id $before }
    }
}

# M1: the equivalent-names notice; every SINGLE line break must lie inside the name (the template's
# own paragraph breaks are double)
function Row-Msg {
    if (-not (Want 'M1')) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P $EquivDir
        $box = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 10 -and $box -eq [IntPtr]::Zero) {
            $c = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 2477 $null) }) | Select-Object -First 1
            if ($c) { $box = $c } else { Start-Sleep -Milliseconds 200 }
        }
        if ($box -eq [IntPtr]::Zero) { Row 'M1' 'WRAP' 'NOT DRIVEN' 'the equivalent-names notice did not appear'; return }
        $text = [Drv098f]::GetText((Kid $box 2477 $null), 5000)
        # positions of single line breaks (a run of exactly one LF, CR LF counted as one)
        $norm = $text.Replace("`r`n", "`n")
        $flat = New-Object Text.StringBuilder; $singles = @()
        for ($i = 0; $i -lt $norm.Length; $i++) {
            if ($norm[$i] -eq "`n") {
                $run = 1; while ($i + $run -lt $norm.Length -and $norm[$i + $run] -eq "`n") { $run++ }
                if ($run -eq 1) { $singles += $flat.Length } else { [void]$flat.Append([string]"`n" * $run) }
                $i += $run - 1
                continue
            }
            [void]$flat.Append($norm[$i])
        }
        $f = $flat.ToString()
        $name = $EqNfc; $at = $f.IndexOf($EqNfc, [StringComparison]::Ordinal)
        if ($at -lt 0) { $name = $EqNfd; $at = $f.IndexOf($EqNfd, [StringComparison]::Ordinal) }
        $outside = @($singles | Where-Object { $at -lt 0 -or $_ -le $at -or $_ -ge $at + $name.Length })
        $ok = ($at -ge 0) -and ($outside.Count -eq 0) -and ($singles.Count -ge 1)
        if (-not $Fixed) { $ok = ($outside.Count -ge 1) }
        Row 'M1' 'WRAP' (V $ok) ("notice of {0} characters; name found {1}; single line breaks {2}, outside the name {3} (expected: {4})" -f $text.Length, ($at -ge 0), $singles.Count, $outside.Count, $(if ($Fixed) { 'none outside, at least one inside' } else { 'some outside (the template cut inside words)' }))
        Out ('           text: ' + (Esc ($norm -replace "`n", ' | ')))
        Close-Win $box
    }
    catch { Row 'M1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'M1' $id $before } }
}

# C1-C3: copy commands while the probe holds the clipboard open
function Row-Clip([string]$Case, [int]$Cmd, [string]$What) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0; $held = $false
    try {
        $id = Start-P $ClipDir
        Key $id 0x24; Key $id 0x28   # Home (".."), Down (a.txt)
        Start-Sleep -Milliseconds 400
        $held = [Drv121]::OpenClipboard([IntPtr]::Zero)
        $why = $(if ($held) { 'held by the probe' } else { 'the probe could not open it either (error ' + [Runtime.InteropServices.Marshal]::GetLastWin32Error() + ')' })
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) $Cmd
        $new = @(Collect-New $id $known 3)
        $boxes = @($new | Where-Object { [Drv098f]::Cls($_.Hwnd) -eq '#32770' })
        $titled = @($boxes | Where-Object { $_.Title -ceq 'Copy To Clipboard' })
        if ($Fixed) { $v = V ($titled.Count -eq 1 -and $boxes.Count -eq 1) } else { $v = V ($boxes.Count -eq 0) }
        if ($boxes.Count -eq 0 -and -not $held -and $Fixed) { $v = 'NOT DRIVEN' }
        Row $Case 'CLIP' $v ("{0} (command {1}), clipboard {2}: boxes {3}: {4} (expected: {5})" -f $What, $Cmd, $why, $boxes.Count, $(if ($boxes.Count) { ($boxes | ForEach-Object { "'" + $_.Title + "' " + $_.Desc }) -join ' || ' } else { 'none' }), $(if ($Fixed) { "one box titled 'Copy To Clipboard'" } else { 'none (silent)' }))
        foreach ($b in $boxes) { Close-Win $b.Hwnd }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($held) { [void][Drv121]::CloseClipboard() }
        if ($id) { End-P $Case $id $before }
    }
}

# N1: French UI on this code page; F5 of folder "dup" onto a FILE "dup": the worker's
# "name already used" error text (CFileErrorDlg, control 172)
function Row-French {
    if (-not (Want 'N1')) { return }
    $before = Reports; $id = 0
    $acp = [Drv121]::GetACP()
    $enc = [Text.Encoding]::GetEncoding([int]$acp, (New-Object Text.EncoderExceptionFallback), (New-Object Text.DecoderExceptionFallback))
    $representable = $true; try { [void]$enc.GetBytes($FrenchAlready) } catch { $representable = $false }
    try {
        Set-Lang 'french.slg'
        $id = Start-P $CrdSrc $CrdDst
        Key $id 0x24; Key $id 0x28   # Home (".."), Down ("dup")
        Start-Sleep -Milliseconds 400
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 727   # CM_COPYFILES
        $dlg = Wait-NewWin $id $known 8
        if ($dlg -eq [IntPtr]::Zero) { throw 'F5 opened no dialog' }
        Click-Ok $dlg
        $err = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $err -eq [IntPtr]::Zero) {
            $c = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 172 $null) }) | Select-Object -First 1
            if ($c) { $err = $c } else { Start-Sleep -Milliseconds 200 }
        }
        if ($err -eq [IntPtr]::Zero) { Row 'N1' 'TEXT' 'NOT DRIVEN' ('no error dialog with the error text appeared: ' + (@(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass } | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        Start-Sleep -Milliseconds 400
        $t = [Drv098f]::GetText((Kid $err 172 $null), 5000)
        $exact = ($t -ceq $FrenchAlready) -or ($t -ceq $FrenchAlreadyDir)
        if ($representable) { $v = 'INFO' } elseif ($Fixed) { $v = V $exact } else { $v = V (-not $exact) }
        Row 'N1' 'TEXT' $v ("code page {0} holds the French text: {1}; error text '{2}' exact {3} (expected: {4})" -f $acp, $representable, (Esc $t), $exact, $(if ($representable) { 'no difference on this code page' } elseif ($Fixed) { 'exact' } else { 'best fit / ?' }))
        Close-Win $err   # Cancel
        Start-Sleep -Milliseconds 800
        Close-Boxes $id
    }
    catch { Row 'N1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { End-P 'N1' $id $before }
        Set-Lang 'english.slg'
    }
}

# K1: Checksum Calculate, Save over a list file the probe holds locked (byte range): the open
# truncates, the write fails - the 118 C6 situation; the plug-in now says so
Add-Type -AssemblyName UIAutomationClient -ErrorAction SilentlyContinue
function Uia-Text([IntPtr]$H) {
    try {
        $el = [System.Windows.Automation.AutomationElement]::FromHandle($H)
        $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $t = @(); foreach ($e in $all) { $n = $e.Current.Name; if ($n) { $t += $n } }
        return (Esc (($t | Select-Object -Unique) -join ' | '))
    }
    catch { return ('<uia: ' + $_.Exception.Message + '>') }
}
# answers a Yes/No question of the save dialog with "No" (BM_CLICK on its second button) - 118
# posted WM_CLOSE, which run 2 showed does not close it
function Answer-No([IntPtr]$H) {
    $b = @(Buttons $H)
    if ($b.Count -ge 2) { Click $b[1] } else { [void][Drv098f]::PostMessageW($H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
}
# types text into an edit: select all, then WM_CHAR per character (117's Type-Text)
function Type-Text([IntPtr]$E, [string]$Text) {
    [void][Drv121]::SendR($E, 0x00B1, 0, -1)   # EM_SETSEL all
    [void][Drv121]::SendR($E, 0x0102, 8, 0)    # WM_CHAR backspace: clear the selection
    foreach ($ch in $Text.ToCharArray()) { [void][Drv121]::SendR($E, 0x0102, [int]$ch, 1) }
    Start-Sleep -Milliseconds 300
}
# the save dialog's file type list (118's Type-Combo)
function Type-Combo([IntPtr]$Dlg) {
    $combos = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'ComboBox' })
    $pref = @($combos | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1136 }) + @($combos | Where-Object { [Drv098f]::GetDlgCtrlID($_) -ne 1136 })
    foreach ($c in $pref) {
        if ([Drv121]::SendR($c, 0x0146, 0, 0) -gt 0 -and [Drv098f]::GetText($c, 3000) -match '\*\.') { return $c }
    }
    return $null
}
function Ctl-Dump([IntPtr]$H) {
    $p = @()
    foreach ($k in @([Drv098f]::Kids($H) | Where-Object { @('ComboBox', 'ComboBoxEx32', 'Edit', 'Button') -contains [Drv098f]::Cls($_) })) {
        $p += ("{0}#{1}<{2} vis={3} '{4}'" -f [Drv098f]::Cls($k), [Drv098f]::GetDlgCtrlID($k), [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($k)), [int][Drv098f]::IsWindowVisible($k), (Tail ([Drv098f]::Txt($k)) 30))
    }
    return ("[{0} '{1}'] " -f [Drv098f]::Cls($H), (Tail ([Drv098f]::Txt($H)) 40)) + ($p -join ' ; ')
}
# Save in the Calculate window, type 0, as $Base (full path, no extension); with $Overwrite the
# plug-in's "already exists" question is answered Yes. Returns @{ Status; Type; Boxes; Folder }
# (Folder = the text of the name field as the dialog opened: item 12, the proposed name in the folder)
function Save-Type0([int]$Id, [IntPtr]$Calc, [string]$Base, [bool]$Overwrite, [string]$Proposed = 'cs') {
    $res = @{ Status = ''; Type = ''; Boxes = @(); Folder = ''; Address = '' }
    $known = Get-Tops $Id
    Post-Cmd $Calc 1003   # WM_COMMAND IDC_BUTTON_SAVE (118: a posted BM_CLICK opened nothing on the hidden desktop)
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' -and (Type-Combo $_) }) | Select-Object -First 1
        if ($c) { Start-Sleep -Milliseconds 2000; $od = $c }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) {
        $new = @(Get-Tops $Id | Where-Object { $known -notcontains $_ } | ForEach-Object { Ctl-Dump $_ })
        $res.Status = 'no save dialog; new windows: ' + $(if ($new.Count) { $new -join ' || ' } else { 'none' })
        foreach ($h in @(Get-Tops $Id | Where-Object { $known -notcontains $_ })) { Close-Win $h }
        return $res
    }
    $u = Uia-Text $od
    $m = [regex]::Match($u, '(Adresa|Address): ([^|]*)')
    $res.Address = $(if ($m.Success) { $m.Groups[2].Value.Trim() } else { '<no address element> ' + (Tail $u 200) })
    $types = Type-Combo $od
    [void][Drv121]::SendR($types, 0x014E, 0, 0)   # CB_SETCURSEL 0
    $res.Type = [Drv098f]::GetText($types, 5000)
    $cid = [Drv098f]::GetDlgCtrlID($types); $par = [Drv098f]::GetParent($types)
    foreach ($code in @(9, 1)) { [void][Drv121]::SendR($par, 0x0111, (($code -shl 16) -bor $cid), $types.ToInt64()) }
    Start-Sleep -Milliseconds 1000
    $edits = @([Drv098f]::Kids($od) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) })
    $fn = @($edits | Where-Object { $t = [Drv098f]::GetText($_, 3000); $t -eq $Proposed -or $t.EndsWith('\' + $Proposed) }) | Select-Object -First 1
    if (-not $fn) { $fn = @($edits | Where-Object { [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148 }) | Select-Object -First 1 }
    if (-not $fn) { $fn = @($edits | Where-Object { [Drv098f]::Cls([Drv098f]::GetParent($_)) -eq 'ComboBox' }) | Select-Object -First 1 }
    if (-not $fn) { $d = Ctl-Dump $od; Post-Cmd $od 2; $res.Status = 'no file name field: ' + $d; return $res }
    $res.Folder = ('name field held ' + (Esc ([Drv098f]::GetText($fn, 3000))) + '; edits: ' + (($edits | ForEach-Object { "'" + (Esc ([Drv098f]::GetText($_, 3000))) + "'<" + [Drv098f]::Cls([Drv098f]::GetParent($_)) + '#' + [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) }) -join ', '))
    $dir = [IO.Path]::GetDirectoryName($Base); $leaf = [IO.Path]::GetFileName($Base)
    Type-Text $fn $dir
    Post-Cmd $od 1   # navigate
    Start-Sleep -Milliseconds 2500
    $edits = @([Drv098f]::Kids($od) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) })
    $fn2 = @($edits | Where-Object { [Drv098f]::Cls([Drv098f]::GetParent($_)) -eq 'ComboBox' }) | Select-Object -First 1
    if ($fn2) { $fn = $fn2 }
    Type-Text $fn $leaf
    $res.Folder += ('; typed the folder, then ' + (Esc ([Drv098f]::GetText($fn, 3000))))
    Post-Cmd $od 1   # WM_COMMAND IDOK (118: BM_CLICK on the Vista-style Save button did nothing here)
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
    if ([Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) {
        foreach ($x in @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and $_ -ne $od })) { $res.Boxes += ((WinDesc $x) + ' UIA: ' + (Uia-Text $x)); Answer-No $x }
        Start-Sleep -Milliseconds 800; Post-Cmd $od 2
        $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 5 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
        $res.Status = 'the save dialog stayed open after IDOK (cancelled)'
        return $res
    }
    Start-Sleep -Milliseconds 800
    for ($round = 0; $round -lt 4; $round++) {
        $extra = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and $_ -ne $od -and [Drv098f]::Cls($_) -eq '#32770' })
        if (-not $extra.Count) { break }
        foreach ($x in $extra) {
            $d = WinDesc $x; $res.Boxes += $d
            $yes = Buttons $x | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
            if ($Overwrite -and $d -match 'already exists' -and $yes) { Click $yes } else { Close-Win $x }
        }
        Start-Sleep -Milliseconds 1000
    }
    $res.Status = 'done'
    return $res
}
function Row-Checksum {
    if (-not (Want 'K1')) { return }
    $before = Reports; $id = 0; $lock = $null
    try {
        $id = Start-P $CsDir
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800; Sync $id   # select all
        $calc = Open-ByKey $id 0x55   # Ctrl+Shift+U
        if (-not ((Kid $calc 1001 'SysListView32') -and (Kid $calc 1003 'Button'))) { throw ('not a Calculate window: ' + (WinDesc $calc)) }
        $save = Kid $calc 1003 'Button'
        $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 60 -and -not [Drv098f]::IsWindowEnabled($save)) { Start-Sleep -Milliseconds 200 }
        if (-not [Drv098f]::IsWindowEnabled($save)) { Row 'K1' 'SAVE' 'NOT DRIVEN' 'the calculation did not finish in 60 s'; return }
        $base = $CsDir + '\saved121'
        $first = $null; $tries = @()
        for ($a = 1; $a -le 3; $a++) {
            $first = Save-Type0 $id $calc $base $false
            $tries += ("try {0}: {1}; {2}; {3}" -f $a, $first.Status, $first.Folder, ($first.Boxes -join ' || '))
            if ($first.Type -match '\*(\.[A-Za-z0-9]+)' -and (Test-Path -LiteralPath ($base + $Matches[1]))) { break }
        }
        Out ('           first save: ' + ($tries -join ' ;; '))
        # K0 (item 12): the dialog opens in the panel's folder
        $addr = $first.Address
        $inCs = ($addr -match 'tc121\\cs$' -or $addr -match '\\cs$')
        $v0 = 'INFO'   # item 12 measured and reverted (fix-log "Item 12"): reported on both builds
        if ($addr -like '<no address element>*') { $v0 = 'NOT DRIVEN' }
        Row 'K0' 'FOLDER' $v0 ("Checksum's Save dialog opened in '{0}' (expected: the panel's folder ...\tc121\cs)" -f $addr)
        if ($first.Type -notmatch '\*(\.[A-Za-z0-9]+)') { Row 'K1' 'SAVE' 'NOT DRIVEN' ("no extension in the type text '{0}' ({1})" -f $first.Type, $first.Status); return }
        Out ("           first save: type '{0}', {1}; dialog title '{2}'" -f $first.Type, $first.Status, (Tail $first.Folder 60))
        $target = $base + $Matches[1]
        if (-not (Test-Path -LiteralPath $target)) { Row 'K1' 'SAVE' 'NOT DRIVEN' ('the first save wrote no ' + (Tail $target 40) + '; boxes: ' + ($first.Boxes -join ' || ')); return }
        $lock = New-Object IO.FileStream($target, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $lock.Lock(0, 1048576)
        $r = Save-Type0 $id $calc $base $true
        $after = $lock.Length
        $errBoxes = @($r.Boxes | Where-Object { $_ -notmatch 'already exists' })
        $reported = @($errBoxes | Where-Object { $_ -match 'Error creating file' }).Count
        if ($after -ne 0) { Row 'K1' 'SAVE' 'NOT DRIVEN' ("the re-save did not reach the write (list now {0} bytes); boxes: {1}" -f $after, ($r.Boxes -join ' || ')); return }
        if ($Fixed) { $v = V ($reported -eq 1 -and $errBoxes.Count -eq 1) } else { $v = V ($errBoxes.Count -eq 0) }
        Row 'K1' 'SAVE' $v ("re-save of '{0}' over the locked list: truncated, write refused; boxes after the overwrite question {1}: {2} (expected: {3})" -f $r.Type, $errBoxes.Count, $(if ($errBoxes.Count) { $errBoxes -join ' || ' } else { 'none' }), $(if ($Fixed) { "one 'Error creating file.' + the system's reason" } else { 'none (silent)' }))
    }
    catch { Row 'K1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($lock) { try { $lock.Dispose() } catch { } }
        if ($id) { End-P 'K1' $id $before }
    }
}

# D1: Disk Map of a folder with an accented junction; its log names the junction
function Row-DiskMap {
    if (-not (Want 'D1')) { return }
    $before = Reports; $id = 0
    try {
        if (-not [IO.Directory]::Exists($LP + $DmDir + '\' + $JName)) { Row 'D1' 'LOG' 'NOT DRIVEN' 'the junction could not be created (mklink /J)'; return }
        $id = Start-P $DmDir
        $h = Open-ByKey $id 0x44   # Ctrl+Shift+D
        if ([Drv098f]::Cls($h) -ne $DmClass) { $h2 = Wait-Class $id $DmClass 10; if ($h2 -ne [IntPtr]::Zero) { $h = $h2 } }
        if ([Drv098f]::Cls($h) -ne $DmClass) { throw ('not a Disk Map window: ' + (WinDesc $h)) }
        Start-Sleep -Seconds 3
        Post-Cmd $h 124   # IDM_VIEW_LOG
        $l = Wait-Class $id $DmLogClass 8
        if ($l -eq [IntPtr]::Zero) { Row 'D1' 'LOG' 'NOT DRIVEN' 'the log window did not appear'; return }
        $lv = Kid $l 0 'SysListView32'
        if (-not $lv) { $lv = @([Drv098f]::Kids($l) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' }) | Select-Object -First 1 }
        if (-not $lv) { throw 'no list view in the log window' }
        $n = [int](Lv-Count $lv)
        $rows = @()
        for ($i = 0; $i -lt $n -and $i -lt 50; $i++) { $rows += [pscustomobject]@{ Text = [Drv121]::LvText($lv, $i, 1); Path = [Drv121]::LvText($lv, $i, 2) } }
        $want = $DmDir + '\' + $JName
        $hit = @($rows | Where-Object { $_.Path -and ($_.Path.TrimEnd('\') -ceq $want -or $_.Path.TrimEnd('\').EndsWith('\' + $JName, [StringComparison]::Ordinal)) })
        $jRows = @($rows | Where-Object { $_.Path -and $_.Path -match '\\j[^\\]*\\?$' })
        if ($Fixed) { $v = V ($hit.Count -ge 1) } else { $v = V ($hit.Count -eq 0 -and $jRows.Count -ge 1) }
        if ($n -eq 0) { $v = 'NOT DRIVEN' }
        Row 'D1' 'LOG' $v ("log rows {0}; rows naming the junction exactly {1}; junction-like rows: {2} (expected: {3})" -f $n, $hit.Count, $(if ($jRows.Count) { ($jRows | ForEach-Object { "'" + (Esc $_.Text) + "' / '" + (Tail $_.Path 50) + "'" }) -join ' || ' } else { 'none' }), $(if ($Fixed) { 'exact' } else { 'garbled' }))
    }
    catch { Row 'D1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id -and (Test-Alive $id)) {
            foreach ($h in @(Get-Tops $id | Where-Object { @($DmLogClass, $DmClass) -contains [Drv098f]::Cls($_) })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 700 }
        }
        if ($id) { End-P 'D1' $id $before }
    }
}

# P1-P3: a typed FTP login that does not fit is refused (IDS_TOOLONGPATH of the FTP plug-in)
function Row-FtpLogin([string]$Case, [string]$Url, [bool]$WantRefused, [string]$What) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P $StartDir
        $known = Get-Tops $id
        $held = Do-ChangeDir $id $Url
        $new = @(Collect-New $id $known 12)
        $texts = @($new | ForEach-Object { $_.Desc })
        Stop-FtpConnect $id
        $refused = @($texts | Where-Object { $_ -match 'too long path' }).Count
        $coreRefused = @($texts | Where-Object { $_ -match 'path specified is too long' }).Count
        foreach ($w in $new) { if ([Drv098f]::IsWindow($w.Hwnd)) { Close-Win $w.Hwnd } }
        Start-Sleep -Milliseconds 500; Close-Boxes $id
        if ($WantRefused) { if ($Fixed) { $ok = ($refused -eq 1) } else { $ok = ($refused -eq 0) } } else { $ok = ($refused -eq 0 -and $coreRefused -eq 0) }
        $v = V $ok; if (-not $held) { $v = 'NOT DRIVEN' }
        Row $Case 'FTP' $v ("{0} ({1} bytes typed, field held it {2}): the plug-in's 'too long' boxes {3}, the core's {4}; windows: {5}" -f $What, (U8Len $Url), $held, $refused, $coreRefused, $(if ($texts.Count) { ($texts | ForEach-Object { Tail $_ 140 }) -join ' || ' } else { 'none' }))
        if (-not $WantRefused -and @($texts | Where-Object { $_ -match 'SalamanderFTPClient' }).Count) {
            Kill-Mine $id; Out ("           {0}: the plug-in started connecting (its wait window) - instance ended by the probe, no END row" -f $Case); $id = 0
        }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# Esc to the FTP plug-in's wait windows until none is left (20 s), then every box closed
function Stop-FtpConnect([int]$Id) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 20) {
        $w = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -like 'SalamanderFTPClient*' -or [Drv098f]::Cls($_) -eq 'SalamanderSaveBits' })
        $b = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })
        if (-not $w.Count -and -not $b.Count) { break }
        foreach ($h in $w) { [void][Drv098f]::PostMessageW($h, 0x0100, [IntPtr]0x1B, [IntPtr]1); [void][Drv098f]::PostMessageW($h, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001) }
        $m = Get-Main $Id; if ($m -ne [IntPtr]::Zero) { [void][Drv098f]::PostMessageW($m, 0x0100, [IntPtr]0x1B, [IntPtr]1); [void][Drv098f]::PostMessageW($m, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001) }
        foreach ($h in $b) { Close-Win $h }
        Start-Sleep -Milliseconds 500
    }
}
# P4 / P5: the upload target typed into the Copy dialog (F5 of a.txt) - the plug-in's
# CopyOrMoveFromDiskToFS (fs5.cpp) sees up to 2 x MAX_PATH bytes
function Row-FtpUpload([string]$Case, [string]$Url, [bool]$WantRefused, [string]$What) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P $ClipDir
        Key $id 0x24; Key $id 0x28   # Home (".."), Down (a.txt)
        Start-Sleep -Milliseconds 400
        $dlg = Open-ByCmd $id 727
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'FTP' 'NOT DRIVEN' 'F5 opened no window'; return }
        $path = Find-Ctl $dlg 210
        if ($path -eq [IntPtr]::Zero) { Close-Win $dlg; Row $Case 'FTP' 'NOT DRIVEN' ('no target field in ' + (WinDesc $dlg)); return }
        [void][Drv098f]::SetText($path, $Url, 5000)
        $held = ([Drv098f]::GetText($path, 5000) -ceq $Url)
        $known = Get-Tops $id
        Click-Ok $dlg
        $new = @(Collect-New $id $known 12)
        $texts = @($new | ForEach-Object { $_.Desc })
        $refused = @($texts | Where-Object { $_ -match 'too long path' }).Count
        $coreRefused = @($texts | Where-Object { $_ -match 'path specified is too long' }).Count
        foreach ($w in $new) { if ([Drv098f]::IsWindow($w.Hwnd)) { Close-Win $w.Hwnd } }
        Stop-FtpConnect $id
        if ($coreRefused -eq 1 -and $refused -eq 0) { $ok = $true }   # the core refuses first (097): never cut, the plug-in is not reached - both builds
        elseif ($WantRefused) { if ($Fixed) { $ok = ($refused -eq 1) } else { $ok = ($refused -eq 0) } } else { $ok = ($refused -eq 0) }
        $v = V $ok; if (-not $held) { $v = 'NOT DRIVEN' }
        Row $Case 'FTP' $v ("{0} ({1} bytes typed as the F5 target, field held it {2}): the plug-in's 'too long' boxes {3}, the core's {4}; windows: {5}" -f $What, (U8Len $Url), $held, $refused, $coreRefused, $(if ($texts.Count) { ($texts | ForEach-Object { Tail $_ 140 }) -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# R1 / L1: a plug-in window open, then the installer's close request
function Row-Rm([string]$Case, [int]$Vk, [string]$What) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P $StartDir
        try { $w = Open-ByKey $id $Vk }
        catch { Row $Case 'STATE' 'NOT DRIVEN' $_.Exception.Message; return }
        Start-Sleep -Milliseconds 1200
        $extra = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and $_ -ne $w })
        if ($extra.Count) { Row $Case 'STATE' 'NOT DRIVEN' ('more windows than the one of the row: ' + (($extra | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        Row $Case 'STATE' 'PASS' ("{0}: {1}" -f $What, (WinDesc $w))
        $r = Invoke-RmWatched $id
        Rm-Verdict $Case $id $r $Fixed $before
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# S1: fcremote starts the program, the probe closes it the moment the main window shows
function Row-Fcremote {
    if (-not (Want 'S1')) { return }
    if (-not (Test-Path -LiteralPath $Fcremote)) { Row 'S1' 'START' 'NOT DRIVEN' ('no ' + $Fcremote); return }
    if (-not (Set-LoadOnStart $true)) { Row 'S1' 'START' 'NOT DRIVEN' 'the File Comparator plug-in key was not found'; return }
    $boxesTotal = 0; $bad = 0; $notes = @()
    try {
        for ($round = 1; $round -le $Rounds; $round++) {
            $before = Reports
            $fp = Start-Process -FilePath $Fcremote -ArgumentList @(('"' + $FcDir + '\a.txt"'), ('"' + $FcDir + '\b.txt"')) -PassThru
            [void]$fp.Handle
            $sw = [Diagnostics.Stopwatch]::StartNew(); $tp = $null; $main = [IntPtr]::Zero
            while ($sw.Elapsed.TotalSeconds -lt 40 -and $main -eq [IntPtr]::Zero) {
                if (-not $tp) { $tp = Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $Exe } | Select-Object -First 1 }
                if ($tp) { $main = Get-Main $tp.Id }
                if ($main -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 20 }
            }
            if (-not $tp -or $main -eq [IntPtr]::Zero) { $notes += ("round {0}: fcremote did not start the program" -f $round); $bad++; if (-not $fp.HasExited) { Stop-Process -Id $fp.Id -Force }; continue }
            [void]$Started.Add($tp.Id); $script:Procs[$tp.Id] = $tp; [void]$tp.Handle
            $closeAt = $sw.Elapsed.TotalSeconds
            [void][Drv098f]::PostMessageW($main, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            $seen = @{}; $boxes = @(); $again = $false; $sw2 = [Diagnostics.Stopwatch]::StartNew()
            while ($sw2.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $tp.Id)) {
                foreach ($h in @(Get-Tops $tp.Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) {
                    $k = $h.ToInt64()
                    if (-not $seen.ContainsKey($k)) { $seen[$k] = $sw2.Elapsed.TotalSeconds; $boxes += (WinDesc $h); continue }
                    if ($sw2.Elapsed.TotalSeconds - $seen[$k] -gt 0.5) { $b = Buttons $h | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
                }
                $m = Get-Main $tp.Id
                if (-not $again -and $sw2.Elapsed.TotalSeconds -gt 8 -and $m -ne [IntPtr]::Zero -and $seen.Count -eq 0) { $again = $true; [void][Drv098f]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); $notes += ("round {0}: a second close request at 8 s" -f $round) }
                Start-Sleep -Milliseconds 100
            }
            $ec = $(if (Test-Alive $tp.Id) { Kill-Mine $tp.Id; 'killed' } else { ExitCodeOf $tp.Id })
            $exitedFc = $fp.WaitForExit(15000); if (-not $exitedFc) { Stop-Process -Id $fp.Id -Force }
            $rep = @(Take-Reports $before)
            $rej = @($boxes | Where-Object { $_ -match 'rejected to unload' }).Count
            $boxesTotal += $rej
            if ($ec -ne '0x00000000' -or $rep.Count -or $boxes.Count) { $bad++ }
            $notes += ("round {0}: main window at {1:N2} s, closed at once; boxes {2}{3}; exit {4}; fcremote exited {5}; reports {6}" -f $round, $closeAt, $boxes.Count, $(if ($boxes.Count) { ' (' + ($boxes -join ' || ') + ')' } else { '' }), $ec, $exitedFc, $rep.Count)
            Start-Sleep -Milliseconds 500
        }
    }
    finally { [void](Set-LoadOnStart $false) }
    foreach ($n in $notes) { Out ('           ' + $n) }
    $v = $(if ($Fixed) { V ($bad -eq 0) } else { 'INFO' })
    Row 'S1' 'START' $v ("{0} rounds: 'rejected to unload' boxes {1}, rounds with any box / bad exit / report {2} (expected: {3})" -f $Rounds, $boxesTotal, $bad, $(if ($Fixed) { 'none' } else { 'reported (the race is timing-dependent)' }))
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc121_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    $fx = Make-Fixture
    Set-Config
    $script:HotKeyNote = Set-HotKeys
    Out ("batch121_probe (feature 121), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}{5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $deskName, [Drv121]::GetACP(), $existed, $regHash, $(if ($RegBaseline) { '; baseline ' + $RegBaseline + ' matches: ' + $regHash.StartsWith($RegBaseline.ToUpper()) } else { '' }))
    Out ("Fixture : {0}" -f $fx)
    Out ("Hot keys: {0}" -f $script:HotKeyNote)
    Out ''

    Row-Find
    Row-Msg
    Row-Clip 'C1' 709 'Copy Full Name'
    Row-Clip 'C2' 710 'Copy Name'
    Row-Clip 'C3' 711 'Copy Full Path'
    Row-French
    Row-Checksum
    Row-DiskMap
    Row-FtpLogin 'P1' ('ftp://' + ('u' * 101) + '@127.0.0.1:1/') $true 'user name of 101 bytes'
    Row-FtpLogin 'P3' ('ftp://u:' + ([string][char]0x010D * 110) + '@127.0.0.1:1/') $false 'password of 110 c-caron = 220 bytes (fits; the whole path stays under the core limit of 259 bytes)'
    Row-FtpUpload 'P4' ('ftp://u:' + ('p' * 301) + '@127.0.0.1:1/') $true 'password of 301 bytes'
    Row-FtpUpload 'P5' ('ftp://' + ('u' * 101) + '@127.0.0.1:1/') $true 'user name of 101 bytes'
    Row-Rm 'R1' 0x47 'Registry Editor Find window (not searching)'
    Row-Rm 'L1' 0x4C 'FTP Logs window'
    Row-Fcremote
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    foreach ($p in @(Get-Process fcremote -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $Fcremote })) { Stop-Process -Id $p.Id -Force }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try {
        if ([IO.Directory]::Exists($LP + $DmDir + '\' + $JName)) { [IO.Directory]::Delete($LP + $DmDir + '\' + $JName) }   # the junction itself, never its target's content
        if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    }
    catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    $ni = @($script:Rows | Where-Object { $_.Verdict -eq 'INFO' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}, INFO {3}. Left running: {4}; fixture removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, $ni, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
