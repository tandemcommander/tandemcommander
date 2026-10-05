<#
.SYNOPSIS
    Feature 118 probe: an installer's close request (the Windows Restart Manager sequence of
    specs/080-restart-manager-upgrade/probe/rm_probe.ps1) against a running build with a window of
    the File Comparator, Disk Map, Checksum or Batch Renamer plug-in open, in each state that
    matters. On the build of this feature (-Expect fixed) and on the build before it (-Expect
    before, Debug_x64_pre118, the control: every plug-in window declines there).

.DESCRIPTION
    Every row starts a FRESH instance of -Exe (left and right panel on a fixture folder under
    %TEMP%\tc118), opens the plug-in window the way a user does (the plug-in's hot key on the
    panel, Ctrl+Shift+<key>, given through the input state of the program's thread - the 100/102/
    104/115/117 method), brings it into the state of the row, checks that the state was reached
    (else NOT DRIVEN), then runs rm_probe.ps1 -ExePath <exe> as a child process while this script
    polls the visible top-level windows of the pid every 30 ms and records every window that was
    not there before.

    Expected "agree" (A): rm_probe exit 0, the process ended with exit code 0, no new window except
    the core's wait window (class SalamanderSaveBits, "saving configuration", also in R1), no new
    crash report, and the work state the row names (e.g. the saved list file is intact).
    Expected "decline" (D): rm_probe exit 1 within 1 s, the process alive, every window kept, no
    new window, and the work state still in the window (e.g. the rows of an unsaved list).

    Rows (names for -Only)                                          fixed   before
      F1  File Comparator, comparison finished (two text files)       A       D
      F2  File Comparator, still comparing (title "press ESC")        A       D
      F3  File Comparator, "The files are identical" box open         D       D
      F4  File Comparator, Compare Files dialog open (typed names)    D       D
      M1  Disk Map, scan finished (File > Abort disabled)             A       D
      M2  Disk Map, still scanning (%windir%\WinSxS, Abort enabled)   A       D
      M3  Disk Map, finished, its Log window shown                    A       D
      M4  Disk Map, its About box open                                D       D
      V1  Checksum Verify, finished                                   A       D
      V2  Checksum Verify, still verifying (a sparse file)            A       D
      C1  Checksum Calculate, still calculating                       D       D
      C2  Checksum Calculate, finished, list NOT saved                D       D
      C3  Checksum Calculate, finished, EVERY calculated type saved   A       D
      C4  Checksum Calculate, all saved, then a row removed (Del)     D       D
      C5  Checksum Calculate, 2+ types calculated, ONE saved          D       D
      C6  Checksum Calculate, all saved, then a re-save over one list
          file fails after the file was truncated (a byte-range lock
          held by the probe makes the write fail)                     D       D
      B1  Batch Renamer dialog open (typed mask)                      D       D
      X1  File Comparator + Disk Map + Verify, all finished           A       D
      R1  no plug-in window (080 regression)                          A       A
      N2  the program's Configuration dialog (080/088 regression)     D       D

    The plug-in hot keys are written for the session into the registry key of the program
    (Plugins\<n>\Menu\<m>\HotKey, the 117 method; Calculate has no default key - Ctrl+Shift+U);
    the whole key is exported before and restored and SHA-256-verified after.

    MUST run through tools\run_on_hidden_desktop.ps1 (refuses on the Default desktop). Refuses
    while any tandemcommander.exe runs (the probes share HKCU\Software\Tandem Commander). Only
    instances started here are addressed, always by pid; rm_probe refuses if the Restart Manager
    lists a process not started from -Exe. Exit code = number of FAIL rows.

.PARAMETER Exe
    tandemcommander.exe of the build under test.
.PARAMETER Expect
    fixed (the build of feature 118) or before (Debug_x64_pre118, the control).
.PARAMETER OutFile
    Writes the report lines there as well (ASCII).
.PARAMETER Only
    Rows to run, e.g. -Only F1,C3.
.PARAMETER RegBaseline
    Prefix of the SHA-256 of the registry export expected before the run (reported, not enforced).
.PARAMETER BigMB
    Size of the sparse file verified / calculated in V2 and C1 (default 4096 MB, no disk space used).
.PARAMETER FcLines
    Lines of each text file compared in F2 (shuffled lines of one pool, default 40000).

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
    [int]$BigMB = 4096,
    [int]$FcLines = 40000
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

if (-not ('Drv118' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv118
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
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetMenuState(IntPtr m, uint id, uint flags);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool DeviceIoControl(Microsoft.Win32.SafeHandles.SafeFileHandle h, uint code, IntPtr inBuf, uint inSize, IntPtr outBuf, uint outSize, out uint ret, IntPtr ov);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift): the probe thread shares the target thread's
    // input state and sets the key-state table - no real key press (the 100/102/104/115/117 method)
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
    // a sparse file of 'size' bytes: reads as zeros, takes no disk space
    public static bool MakeSparse(string path, long size)
    {
        using (var fs = new System.IO.FileStream(path, System.IO.FileMode.Create, System.IO.FileAccess.ReadWrite))
        {
            uint r;
            bool ok = DeviceIoControl(fs.SafeFileHandle, 0x000900C4 /*FSCTL_SET_SPARSE*/, IntPtr.Zero, 0, IntPtr.Zero, 0, out r, IntPtr.Zero);
            fs.SetLength(size);
            return ok;
        }
    }
}
'@
}
$deskName = [Drv118]::DesktopName()
if (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon') { Write-Output ("REFUSED: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 98 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$RmProbe = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\080-restart-manager-upgrade\probe\rm_probe.ps1')).Path

$Fixed = ($Expect -eq 'fixed')
$Root = $TempRoot + '\tc118'
$WaitClass = 'SalamanderSaveBits'
$FcClass = 'SFC Window Class'
$DmClass = 'Zar.DM.MainWin.WC'
$DmLogClass = 'Zar.DM.LogWin.WC'
$script:HotKeyNote = 'not set'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Start-P([string]$Left, [string]$Right) {
    if (-not $Right) { $Right = $Left }
    $a = @('-t', 'T118', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
    if (-not (Test-Alive $Id)) { return }   # ended by the request: the RM row has checked the exit code and the reports
    if (Test-Alive $Id) {
        # the ordinary exit closes the plug-in windows itself (Release without force); dialogs first
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv118]::GetWindow($_, 4) -ne [IntPtr]::Zero })) { Close-Win $h }
        Start-Sleep -Milliseconds 500
    }
    End-Row $Case $Id $null $Before
}

# the plug-in's hot key on the left panel; returns the first new top-level window (or Zero)
function Open-ByKey([int]$Id, [int]$Vk, [double]$Seconds = 10) {
    $known = Get-Tops $Id
    $note = [Drv118]::ModKey((Get-LeftList $Id), $Vk, 3)
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
function Wait-Enabled([IntPtr]$B, [double]$Seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if ([Drv098f]::IsWindowEnabled($B)) { return $true }; Start-Sleep -Milliseconds 200 }
    return $false
}
function Select-All([int]$Id) { Post-Cmd (Get-Main $Id) 842; Start-Sleep -Milliseconds 800; Sync $Id }
function Lv-Count([IntPtr]$Lv) { return [Drv118]::SendR($Lv, 0x1004, 0, 0) }   # LVM_GETITEMCOUNT
function Lv-Key([IntPtr]$Lv, [int]$Vk) {
    [void][Drv118]::SendR($Lv, 0x0100, $Vk, 1)
    [void][Drv118]::SendR($Lv, 0x0101, $Vk, 0xC0000001)
    Start-Sleep -Milliseconds 300
}

# ---- the installer's request, with the screen watched meanwhile -------------------------------
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
        Other = @($shown | Where-Object { $_ -notlike ("[{0} *" -f $WaitClass) }); Wait = @($shown | Where-Object { $_ -like ("[{0} *" -f $WaitClass) }) }
}

# One row. $Prepare (param $id) brings the instance into the row's state and returns
# @{ Reached = bool; State = text; Work = scriptblock or $null }. Work (param $id, $agreed) checks
# the work state after the request and returns @{ Ok = bool; Text = text }.
function Run-Row([string]$Name, [string]$What, [string]$LeftDir, [bool]$AgreeFixed, [bool]$AgreeBefore, [scriptblock]$Prepare, [string]$RightDir) {
    if (-not (Want $Name)) { return }
    $script:RowWin = [IntPtr]::Zero   # the plug-in window of the row, for its WORK check
    $script:LockFs = $null            # a file the row holds locked (C6), released at the end
    $agree = $(if ($Fixed) { $AgreeFixed } else { $AgreeBefore })
    Out ("--- {0}: {1} (expected: {2})" -f $Name, $What, $(if ($agree) { 'agree' } else { 'decline' }))
    $id = 0; $reports = Reports
    try {
        $id = Start-P $LeftDir $RightDir
        $st = & $Prepare $id
        $fatal = Fatal-Win $id
        if ($fatal) { Row $Name 'STATE' 'FAIL' ('FATAL ' + $fatal); return }
        if (-not $st.Reached) { Row $Name 'STATE' 'NOT DRIVEN' ('state not reached: ' + $st.State); return }
        Row $Name 'STATE' 'PASS' $st.State
        $r = Invoke-RmWatched $id
        foreach ($s in $r.Shown) { Out ("           shown: " + $s) }
        if ($agree) {
            $ec = ExitCodeOf $id
            $rep = @(Take-Reports $reports)
            $ok = ($r.Exit -eq 0) -and (-not $r.Alive) -and ($r.Other.Count -eq 0) -and ($ec -eq '0x00000000') -and ($rep.Count -eq 0)
            Row $Name 'RM' (V $ok) ("rm_probe exit {0}; {1}; process ended {2}, exit code {3}; new windows {4} (+{5} core wait window); new crash reports {6}{7}" -f `
                    $r.Exit, $r.Line, (-not $r.Alive), $ec, $r.Other.Count, $r.Wait.Count, $rep.Count, $(if ($rep.Count) { ' [' + ($rep -join ' ;; ') + ']' } else { '' }))
        }
        else {
            $still = Get-Tops $id
            $kept = @($r.Before | Where-Object { $still -contains $_ }).Count
            $ok = ($r.Exit -eq 1) -and $r.Alive -and ($r.Shown.Count -eq 0) -and ($null -ne $r.Seconds) -and ($r.Seconds -le 1.0) -and ($kept -eq @($r.Before).Count)
            Row $Name 'RM' (V $ok) ("rm_probe exit {0}; {1}; process alive {2}; windows kept {3}/{4}; new windows {5}" -f `
                    $r.Exit, $r.Line, $r.Alive, $kept, @($r.Before).Count, $r.Shown.Count)
        }
        if (-not $ok) { $r.Output | ForEach-Object { Out ("           rm> " + $_) } }
        if ($st.Work) {
            $w = & $st.Work $id ($r.Exit -eq 0)
            Row $Name 'WORK' (V $w.Ok) $w.Text
        }
    }
    catch { Row $Name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($script:LockFs) { try { $script:LockFs.Dispose() } catch { }; $script:LockFs = $null }
        if ($id) { End-P $Name $id $reports }
    }
}

# ---- the plug-in windows ------------------------------------------------------------------------
# File Comparator on the two selected files of the left panel; with $KeepDialog the Compare Files
# dialog (when the configuration shows it) is left open and returned
function Open-Fc([int]$Id, [bool]$KeepDialog = $false) {
    Select-All $Id
    $h = Open-ByKey $Id 0x43   # Ctrl+Shift+C
    if ([Drv098f]::Cls($h) -eq '#32770' -and (Kid $h 1 'Button')) {
        if ($KeepDialog) { return $h }
        Click-Ok $h
        $h = Wait-Class $Id $FcClass 15
        if ($h -eq [IntPtr]::Zero) { throw 'the comparator window did not appear after OK' }
    }
    elseif ($KeepDialog) { throw ('Ctrl+Shift+C opened no Compare Files dialog (the configuration skips it): ' + (WinDesc $h)) }
    if ([Drv098f]::Cls($h) -ne $FcClass) { $h2 = Wait-Class $Id $FcClass 10; if ($h2 -ne [IntPtr]::Zero) { $h = $h2 } }
    if ([Drv098f]::Cls($h) -ne $FcClass) { throw ('not a comparator window: ' + (WinDesc $h)) }
    return $h
}
function Fc-Finished([int]$Id, [IntPtr]$H, [double]$Seconds = 30) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $t = [Drv098f]::Txt($H)
        if ($t -notmatch 'Computing Differences' -and [Drv098f]::IsWindowEnabled($H)) { Start-Sleep -Milliseconds 500; return $true }
        Start-Sleep -Milliseconds 200
    }
    return $false
}
function Open-DiskMap([int]$Id) {
    $h = Open-ByKey $Id 0x44   # Ctrl+Shift+D
    if ([Drv098f]::Cls($h) -ne $DmClass) { $h2 = Wait-Class $Id $DmClass 10; if ($h2 -ne [IntPtr]::Zero) { $h = $h2 } }
    if ([Drv098f]::Cls($h) -ne $DmClass) { throw ('not a Disk Map window: ' + (WinDesc $h)) }
    return $h
}
# TRUE while the map scans: its File > Abort item is enabled (the window updates the item states on
# WM_INITMENU, which is sent here first); $null when the menu cannot be read
function Dm-Scanning([IntPtr]$H) {
    $m = [Drv118]::GetMenu($H)
    if ($m -eq [IntPtr]::Zero) { return $null }
    [void][Drv118]::SendR($H, 0x0116, $m.ToInt64(), 0)   # WM_INITMENU
    $st = [Drv118]::GetMenuState($m, 113, 0)             # IDM_FILE_ABORT, MF_BYCOMMAND
    if ($st -eq -1) { return $null }
    return (($st -band 3) -eq 0)                         # neither MF_GRAYED nor MF_DISABLED
}
function Is-VerifyDlg([IntPtr]$H) { return [bool]((Kid $H 1001 'SysListView32') -and (Kid $H 2002 $null)) }
function Is-CalcDlg([IntPtr]$H) { return [bool]((Kid $H 1001 'SysListView32') -and (Kid $H 1003 'Button')) }
# Verify of the list file $List (the focused item after Change Directory to it)
function Open-Verify([int]$Id, [string]$List) {
    [void](Do-ChangeDir $Id $List); Start-Sleep -Milliseconds 500; Sync $Id
    $h = Open-ByKey $Id 0x56   # Ctrl+Shift+V
    if (-not (Is-VerifyDlg $h)) { throw ('not a Verify window: ' + (WinDesc $h)) }
    return $h
}
function Verify-Done([IntPtr]$H) { $l = Kid $H 2002 $null; return [bool]($l -and [Drv098f]::IsWindowVisible($l)) }
function Open-Calc([int]$Id) {
    $h = Open-ByKey $Id 0x55   # Ctrl+Shift+U (set for the session, see Set-HotKeys)
    if (-not (Is-CalcDlg $h)) { throw ('not a Calculate window: ' + (WinDesc $h)) }
    return $h
}
# Save in the Calculate window: the type at index $TypeIndex of the save dialog's type list (it
# offers exactly the calculated types), named $Base (no extension - the plug-in adds the type's);
# with $Overwrite the plug-in's "already exists - overwrite?" question is answered Yes. The 117
# method. Returns @{ Status; Count = types offered; Type = the picked item's text }.
function Save-ListIdx([int]$Id, [IntPtr]$Calc, [int]$TypeIndex, [string]$Base, [bool]$Overwrite = $false) {
    $res = @{ Status = ''; Count = 0; Type = '' }
    $known = Get-Tops $Id
    Click (Kid $Calc 1003 'Button')
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 1136 'ComboBox') }) | Select-Object -First 1
        if ($c) { Start-Sleep -Milliseconds 1200; $od = $c }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) { $res.Status = 'no save dialog'; return $res }
    $types = Kid $od 1136 'ComboBox'
    $res.Count = [int][Drv118]::SendR($types, 0x0146, 0, 0)   # CB_GETCOUNT
    if ($TypeIndex -ge $res.Count) { Post-Cmd $od 2; $res.Status = "type index $TypeIndex not offered ($($res.Count) types)"; return $res }
    [void][Drv118]::SendR($types, 0x014E, $TypeIndex, 0)      # CB_SETCURSEL
    $res.Type = [Drv098f]::GetText($types, 5000)               # the selected item's text
    $cid = [Drv098f]::GetDlgCtrlID($types); $par = [Drv098f]::GetParent($types)
    foreach ($code in @(9, 1)) { [void][Drv118]::SendR($par, 0x0111, (($code -shl 16) -bor $cid), $types.ToInt64()) }   # CBN_SELENDOK, CBN_SELCHANGE
    Start-Sleep -Milliseconds 300
    $fn = @([Drv098f]::Kids($od) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148 }) | Select-Object -First 1
    if (-not $fn) { Post-Cmd $od 2; $res.Status = 'no file name field'; return $res }
    [void][Drv098f]::SetText($fn, $Base, 5000)
    $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
    if ($ok) { Click $ok } else { Post-Cmd $od 1 }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 800
    $boxes = @()
    for ($round = 0; $round -lt 3; $round++) {
        $extra = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and $_ -ne $od -and [Drv098f]::Cls($_) -eq '#32770' })
        if (-not $extra.Count) { break }
        foreach ($x in $extra) {
            $d = WinDesc $x; $boxes += (Tail $d 120)
            $yes = Buttons $x | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
            if ($Overwrite -and $d -match 'already exists' -and $yes) { Click $yes } else { Close-Win $x }
        }
        Start-Sleep -Milliseconds 1000
    }
    $res.Status = $(if ($boxes.Count) { 'boxes: ' + ($boxes -join ' || ') } else { 'ok' })
    return $res
}
# saves every type the save dialog offers, each as $Base.<its extension>;
# returns @{ Count; Files; Types (the dialog's item texts, e.g. "... (*.md5)"); Status }
function Save-AllTypes([int]$Id, [IntPtr]$Calc, [string]$Base) {
    $first = Save-ListIdx $Id $Calc 0 $Base
    $st = @("0:'" + $first.Type + "' " + $first.Status)
    $typesSeen = @($first.Type)
    for ($i = 1; $i -lt $first.Count; $i++) { $r = Save-ListIdx $Id $Calc $i $Base; $st += ("{0}:'{1}' {2}" -f $i, $r.Type, $r.Status); $typesSeen += $r.Type }
    $files = @(Get-ChildItem -LiteralPath (Split-Path $Base -Parent) -Filter ((Split-Path $Base -Leaf) + '.*') | ForEach-Object { $_.FullName })
    return @{ Count = $first.Count; Files = $files; Types = $typesSeen; Status = ($st -join '; ') }
}
function Calc-Rows([IntPtr]$Calc) { return (Lv-Count (Kid $Calc 1001 'SysListView32')) }
# the WORK check of a row whose Calculate window must still be open with $Want rows
function Calc-Kept([int]$Want) {
    $h = $script:RowWin
    $n = $(if ([Drv098f]::IsWindow($h) -and [Drv098f]::IsWindowVisible($h)) { Calc-Rows $h } else { -1 })
    return @{ Ok = ($n -eq $Want); Text = "the Calculate window is still open with its rows: $n of $Want" }
}
function Calc-Finished([int]$Id) {
    $c = Open-Calc $Id
    $save = Kid $c 1003 'Button'
    if (-not (Wait-Enabled $save 60)) { throw 'the calculation did not finish in 60 s (Save stayed disabled)' }
    Start-Sleep -Milliseconds 500
    return $c
}

# gives the plug-in commands their keys for this session (registry, "dirty" so the plug-ins keep
# them; the whole key is restored afterwards): File Comparator Ctrl+Shift+C, Disk Map Ctrl+Shift+D,
# Batch Renamer Ctrl+Shift+R, Checksum Calculate Ctrl+Shift+U and Verify Ctrl+Shift+V
function Set-HotKeys {
    $plugins = 'HKCU:\Software\Tandem Commander\0.1\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key (defaults; Calculate has no key)' }
    $map = @(
        @{ Dll = 'filecomp\.spl$'; Id = 1; Key = 0x10343 },
        @{ Dll = 'diskmap\.spl$'; Id = 1; Key = 0x10344 },
        @{ Dll = 'renamer\.spl$'; Id = 1; Key = 0x10352 },
        @{ Dll = 'checksum\.spl$'; Id = 1; Key = 0x10355 },
        @{ Dll = 'checksum\.spl$'; Id = 2; Key = 0x10356 })
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

# ---- fixture ---------------------------------------------------------------------------------
function Write-Lines([string]$Path, [string[]]$Lines) { [IO.File]::WriteAllText($LP + $Path, (($Lines -join "`r`n") + "`r`n"), (New-Object Text.ASCIIEncoding)) }
function Md5Of([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash.ToLower() }
function Make-Fixture {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    foreach ($d in @('fc_diff', 'fc_same', 'fc_big', 'dm_small', 'dm_small\sub', 'cs_ok', 'cs_big', 'cs_c2', 'cs_c3', 'cs_c4', 'cs_c5', 'cs_c6', 'rn')) { NewDir ($Root + '\' + $d) }
    Write-Lines ($Root + '\fc_diff\a.txt') @('alpha', 'beta', 'gamma', 'delta')
    Write-Lines ($Root + '\fc_diff\b.txt') @('alpha', 'BETA', 'gamma', 'epsilon')
    Write-Lines ($Root + '\fc_same\a.txt') @('one', 'two', 'three')
    Write-Lines ($Root + '\fc_same\b.txt') @('one', 'two', 'three')
    # two long files of the same lines in different random orders: no line is unique to one file,
    # so the comparison cannot shortcut and runs for a long time (cancellable at any moment)
    $rnd = New-Object Random 118
    $pool = @(for ($i = 0; $i -lt 2000; $i++) { 'line {0} {1}' -f $i, ('x' * ($i % 37)) })
    foreach ($f in @('a.txt', 'b.txt')) {
        $sb = New-Object Text.StringBuilder
        for ($i = 0; $i -lt $FcLines; $i++) { [void]$sb.Append($pool[$rnd.Next($pool.Count)]).Append("`r`n") }
        [IO.File]::WriteAllText($LP + $Root + '\fc_big\' + $f, $sb.ToString(), (New-Object Text.ASCIIEncoding))
    }
    for ($i = 0; $i -lt 20; $i++) { WriteFile ($Root + '\dm_small\f' + $i + '.txt') ('x' * (100 * ($i + 1))) }
    WriteFile ($Root + '\dm_small\sub\inner.txt') 'inner'
    $bytes = New-Object byte[] 65536; $rnd.NextBytes($bytes); [IO.File]::WriteAllBytes($LP + $Root + '\cs_ok\x.bin', $bytes)
    [IO.File]::WriteAllText($LP + $Root + '\cs_ok\x.md5', ((Md5Of ($Root + '\cs_ok\x.bin')) + "  x.bin`n"), (New-Object Text.ASCIIEncoding))
    $sparse = [Drv118]::MakeSparse($Root + '\cs_big\big.bin', [long]$BigMB * 1MB)
    [IO.File]::WriteAllText($LP + $Root + '\cs_big\big.md5', ('0' * 32 + "  big.bin`n"), (New-Object Text.ASCIIEncoding))
    foreach ($d in @('cs_c2', 'cs_c3', 'cs_c4', 'cs_c5', 'cs_c6')) {   # one folder per row: a row's saved lists never enter another row's selection
        [IO.File]::WriteAllBytes($LP + $Root + '\' + $d + '\one.bin', $bytes)
        WriteFile ($Root + '\' + $d + '\two.txt') 'two'
    }
    WriteFile ($Root + '\rn\a.txt') 'a'
    WriteFile ($Root + '\rn\b.txt') 'b'
    return ("big text files {0} lines each; sparse file {1} MB (sparse flag {2})" -f $FcLines, $BigMB, $sparse)
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc118_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    $fx = Make-Fixture
    Set-Config
    $script:HotKeyNote = Set-HotKeys
    Out ("update_close_probe (feature 118), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; registry key existed {2}; export SHA-256 {3}{4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $deskName, $existed, $regHash, $(if ($RegBaseline) { '; baseline ' + $RegBaseline + ' matches: ' + $regHash.StartsWith($RegBaseline.ToUpper()) } else { '' }))
    Out ("Fixture : {0}" -f $fx)
    Out ("Hot keys: {0}" -f $script:HotKeyNote)
    Out ''

    Run-Row 'F1' 'File Comparator, comparison finished' ($Root + '\fc_diff') $true $false {
        param($id)
        $h = Open-Fc $id
        $done = Fc-Finished $id $h
        $box = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })
        return @{ Reached = ($done -and $box.Count -eq 0); State = ("comparator '{0}', finished {1}, boxes {2}" -f (Tail ([Drv098f]::Txt($h)) 90), $done, $box.Count); Work = $null }
    }
    Run-Row 'F2' 'File Comparator, still comparing' ($Root + '\fc_big') $true $false {
        param($id)
        $h = Open-Fc $id
        Start-Sleep -Milliseconds 700
        $t = [Drv098f]::Txt($h)
        return @{ Reached = ($t -match 'press ESC'); State = ("comparator '{0}'" -f (Tail $t 110)); Work = $null }
    }
    Run-Row 'F3' "File Comparator, 'The files are identical' box" ($Root + '\fc_same') $false $false {
        param($id)
        $h = Open-Fc $id
        $sw = [Diagnostics.Stopwatch]::StartNew(); $box = [IntPtr]::Zero
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $box -eq [IntPtr]::Zero) {
            $box = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (FullText $_) -match 'identical' }) | Select-Object -First 1
            if (-not $box) { $box = [IntPtr]::Zero }
            Start-Sleep -Milliseconds 200
        }
        return @{ Reached = ($box -ne [IntPtr]::Zero); State = $(if ($box -ne [IntPtr]::Zero) { 'box ' + (WinDesc $box) } else { 'no box' }); Work = $null }
    }
    Run-Row 'F4' 'File Comparator, Compare Files dialog open' ($Root + '\fc_diff') $false $false {
        param($id)
        try { $d = Open-Fc $id $true }
        catch { return @{ Reached = $false; State = $_.Exception.Message; Work = $null } }
        return @{ Reached = $true; State = ('dialog ' + (WinDesc $d)); Work = {
                param($id, $agreed)
                $still = [bool](@(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (Kid $_ 1 'Button') }).Count)
                return @{ Ok = $still; Text = "Compare Files dialog still open: $still" } } }
    }
    Run-Row 'M1' 'Disk Map, scan finished' ($Root + '\dm_small') $true $false {
        param($id)
        $h = Open-DiskMap $id
        $sw = [Diagnostics.Stopwatch]::StartNew(); $scan = $true
        while ($sw.Elapsed.TotalSeconds -lt 20) { $scan = Dm-Scanning $h; if ($scan -eq $false) { break }; Start-Sleep -Milliseconds 300 }
        return @{ Reached = ($scan -eq $false); State = ("map '{0}' of a folder of 21 files, scanning {1} (File > Abort enabled) after {2:N1} s" -f (Tail ([Drv098f]::Txt($h)) 90), $scan, $sw.Elapsed.TotalSeconds); Work = $null }
    }
    Run-Row 'M2' 'Disk Map, still scanning' ($env:windir + '\WinSxS') $true $false {
        param($id)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $h = Open-DiskMap $id
        Start-Sleep -Milliseconds 800
        $scan = Dm-Scanning $h
        return @{ Reached = ($scan -eq $true); State = ("map '{0}', scanning {1} (File > Abort enabled), {2:N1} s after the key" -f (Tail ([Drv098f]::Txt($h)) 90), $scan, $sw.Elapsed.TotalSeconds); Work = $null }
    } ($Root + '\dm_small')
    Run-Row 'M3' 'Disk Map, finished, Log window shown' ($Root + '\dm_small') $true $false {
        param($id)
        $h = Open-DiskMap $id
        Start-Sleep -Seconds 3
        Post-Cmd $h 124   # IDM_VIEW_LOG
        $l = Wait-Class $id $DmLogClass 8
        return @{ Reached = ($l -ne [IntPtr]::Zero); State = $(if ($l -ne [IntPtr]::Zero) { 'log ' + (WinDesc $l) } else { 'the log window did not appear' }); Work = $null }
    }
    Run-Row 'M4' 'Disk Map, About box open' ($Root + '\dm_small') $false $false {
        param($id)
        $h = Open-DiskMap $id
        Start-Sleep -Seconds 2
        $known = Get-Tops $id
        Post-Cmd $h 131   # IDM_HELP_ABOUT
        $b = Wait-NewWin $id $known 8
        return @{ Reached = ($b -ne [IntPtr]::Zero); State = $(if ($b -ne [IntPtr]::Zero) { 'box ' + (WinDesc $b) } else { 'no About box' }); Work = $null }
    }
    Run-Row 'V1' 'Checksum Verify, finished' ($Root + '\cs_ok') $true $false {
        param($id)
        $h = Open-Verify $id ($Root + '\cs_ok\x.md5')
        $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 20 -and -not (Verify-Done $h)) { Start-Sleep -Milliseconds 200 }
        $done = Verify-Done $h
        return @{ Reached = $done; State = ("verify window, result '{0}'" -f $(if ($done) { [Drv098f]::Txt((Kid $h 2002 $null)) } else { '(not finished)' })); Work = $null }
    }
    Run-Row 'V2' 'Checksum Verify, still verifying' ($Root + '\cs_big') $true $false {
        param($id)
        $h = Open-Verify $id ($Root + '\cs_big\big.md5')
        Start-Sleep -Milliseconds 700
        $done = Verify-Done $h
        return @{ Reached = (-not $done); State = ("verify window of a {0} MB file, finished {1}" -f $BigMB, $done); Work = $null }
    }
    Run-Row 'C1' 'Checksum Calculate, still calculating' ($Root + '\cs_big') $false $false {
        param($id)
        [void](Do-ChangeDir $id ($Root + '\cs_big\big.bin')); Start-Sleep -Milliseconds 500; Sync $id
        $c = Open-Calc $id; $script:RowWin = $c
        Start-Sleep -Milliseconds 1200
        $saveOn = [Drv098f]::IsWindowEnabled((Kid $c 1003 'Button'))
        return @{ Reached = (-not $saveOn); State = ("calculate window of a {0} MB file, Save enabled {1}" -f $BigMB, $saveOn); Work = {
                param($id, $agreed)
                $h = $script:RowWin
                $open = [Drv098f]::IsWindow($h) -and [Drv098f]::IsWindowVisible($h)
                return @{ Ok = $open; Text = "the Calculate window is still open: $open" } } }
    }
    Run-Row 'C2' 'Checksum Calculate, finished, list not saved' ($Root + '\cs_c2') $false $false {
        param($id)
        Select-All $id
        $c = Calc-Finished $id; $script:RowWin = $c
        $n = Calc-Rows $c
        return @{ Reached = ($n -eq 2); State = ("calculate window, rows {0}, Save enabled, nothing saved" -f $n); Work = { param($id, $agreed); return (Calc-Kept 2) } }
    }
    Run-Row 'C3' 'Checksum Calculate, finished, every calculated type saved' ($Root + '\cs_c3') $true $false {
        param($id)
        Select-All $id
        $c = Calc-Finished $id; $script:RowWin = $c
        $sv = Save-AllTypes $id $c ($Root + '\cs_c3\saved118')
        $script:C3Files = $sv.Files
        return @{ Reached = ($sv.Count -ge 1 -and $sv.Files.Count -eq $sv.Count); State = ("{0} type(s) offered, {1} list file(s) written; {2}" -f $sv.Count, $sv.Files.Count, $sv.Status); Work = {
                param($id, $agreed)
                $bad = @($script:C3Files | Where-Object { @([IO.File]::ReadAllLines($LP + $_) | Where-Object { $_ -match '^[0-9a-f]{32,128}  |  [0-9a-f]{8}$' }).Count -ne 2 })
                return @{ Ok = ($script:C3Files.Count -ge 1 -and $bad.Count -eq 0); Text = ("the saved lists are intact: {0} file(s), {1} without 2 checksum lines" -f $script:C3Files.Count, $bad.Count) } } }
    }
    Run-Row 'C4' 'Checksum Calculate, every type saved, then a row removed' ($Root + '\cs_c4') $false $false {
        param($id)
        Select-All $id
        $c = Calc-Finished $id; $script:RowWin = $c
        $sv = Save-AllTypes $id $c ($Root + '\cs_c4\saved118')
        $lv = Kid $c 1001 'SysListView32'
        Lv-Key $lv 0x24   # VK_HOME: focus and select the first row (the selection mark the Del key uses)
        Lv-Key $lv 0x2E   # VK_DELETE
        $n = Calc-Rows $c
        return @{ Reached = ($n -eq 1 -and $sv.Count -ge 1 -and $sv.Files.Count -eq $sv.Count); State = ("{0} type(s) saved ({1}); rows after Del {2} of 2" -f $sv.Count, $sv.Status, $n); Work = { param($id, $agreed); return (Calc-Kept 1) } }
    }
    Run-Row 'C5' 'Checksum Calculate, several types calculated, only one saved' ($Root + '\cs_c5') $false $false {
        param($id)
        Select-All $id
        $c = Calc-Finished $id; $script:RowWin = $c
        $r = Save-ListIdx $id $c 0 ($Root + '\cs_c5\saved118')
        $files = @(Get-ChildItem -LiteralPath ($Root + '\cs_c5') -Filter 'saved118.*')
        if ($r.Count -lt 2) { return @{ Reached = $false; State = ("only {0} hash type calculated (the configuration) - nothing left unsaved to test" -f $r.Count); Work = $null } }
        return @{ Reached = ($files.Count -eq 1); State = ("{0} types calculated, saved '{1}' only ({2}); list files {3}" -f $r.Count, $r.Type, $r.Status, $files.Count); Work = { param($id, $agreed); return (Calc-Kept 2) } }
    }
    Run-Row 'C6' 'Checksum Calculate, every type saved, then a failed re-save over one list' ($Root + '\cs_c6') $false $false {
        param($id)
        Select-All $id
        $c = Calc-Finished $id; $script:RowWin = $c
        $base = $Root + '\cs_c6\saved118'
        $sv = Save-AllTypes $id $c $base
        if ($sv.Count -lt 1 -or $sv.Files.Count -ne $sv.Count) { return @{ Reached = $false; State = ('the first saves failed: ' + $sv.Status); Work = $null } }
        # the list of type 0: its extension is in the save dialog's item text ("... (*.md5)")
        if ($sv.Types[0] -notmatch '\*(\.[A-Za-z0-9]+)') { return @{ Reached = $false; State = ("no extension in the type text '{0}'" -f $sv.Types[0]); Work = $null } }
        $target = $base + $Matches[1]
        if (-not (Test-Path -LiteralPath $target)) { return @{ Reached = $false; State = ("the list of type 0 is not {0}" -f (Tail $target 40)); Work = $null } }
        $before = (Get-Item -LiteralPath $target).Length
        # a byte-range lock over the whole list: the plug-in can open it ("wb" truncates) but not write
        $script:LockFs = New-Object IO.FileStream($target, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $script:LockFs.Lock(0, 1048576)
        $r = Save-ListIdx $id $c 0 $base $true
        $after = $script:LockFs.Length
        $how = $(if ($after -eq 0) { 'opened and truncated, the write failed' } elseif ($after -eq $before) { 'not truncated (the open failed, or the lock did not stop the write)' } else { "size $after" })
        return @{ Reached = ($after -eq 0); State = ("re-save of '{0}' over {1} ({2} bytes): {3}; now {4} bytes - {5}" -f $r.Type, (Tail $target 40), $before, $r.Status, $after, $how); Work = { param($id, $agreed); return (Calc-Kept 2) } }
    }
    Run-Row 'B1' 'Batch Renamer dialog open' ($Root + '\rn') $false $false {
        param($id)
        Select-All $id
        $h = Open-ByKey $id 0x52   # Ctrl+Shift+R
        Start-Sleep -Milliseconds 1000
        $script:RowWin = $h
        return @{ Reached = [Drv098f]::IsWindow($h); State = ('renamer ' + (WinDesc $h)); Work = {
                param($id, $agreed)
                $h2 = $script:RowWin
                $open = [Drv098f]::IsWindow($h2) -and [Drv098f]::IsWindowVisible($h2) -and [Drv098f]::IsWindowEnabled($h2)
                return @{ Ok = $open; Text = ("the Batch Renamer window is still open: {0} ('{1}')" -f $open, (Tail ([Drv098f]::Txt($h2)) 60)) } } }
    }
    Run-Row 'X1' 'File Comparator + Disk Map + Verify, all finished' ($Root + '\fc_diff') $true $false {
        param($id)
        $f = Open-Fc $id
        $fd = Fc-Finished $id $f
        $m = Open-DiskMap $id
        Start-Sleep -Seconds 3
        $v = Open-Verify $id ($Root + '\cs_ok\x.md5')
        $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 20 -and -not (Verify-Done $v)) { Start-Sleep -Milliseconds 200 }
        $vd = Verify-Done $v
        $box = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and -not (Is-VerifyDlg $_) })
        return @{ Reached = ($fd -and $vd -and $box.Count -eq 0); State = ("comparator finished {0}, map open, verify finished {1}, other boxes {2}" -f $fd, $vd, $box.Count); Work = $null }
    }
    Run-Row 'R1' 'no plug-in window' ($Root + '\dm_small') $true $true {
        param($id)
        return @{ Reached = $true; State = 'main window only'; Work = $null }
    }
    Run-Row 'N2' "the program's Configuration dialog" ($Root + '\dm_small') $false $false {
        param($id)
        $d = Open-ByCmd $id 686 8   # CM_CONFIGURATION
        return @{ Reached = ($d -ne [IntPtr]::Zero); State = $(if ($d -ne [IntPtr]::Zero) { 'dialog ' + (WinDesc $d) } else { 'no dialog' }); Work = $null }
    }
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
