<#
.SYNOPSIS
    Feature 147 probe: the File Comparator and Checksum windows with one of their boxes open when the
    program is closed (normal exit) or an installer asks it to close. Rows K1-K3; built from the 143
    probe (infrastructure) and the 118 probe (comparator and Checksum helpers). MUST run through
    toolsun_on_hidden_desktop.ps1. Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only
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
$Root = $TempRoot + '\tc147'
$WaitClass = 'SalamanderSaveBits'
$FcClass = 'SFC Window Class'
$DmClass = 'Zar.DM.MainWin.WC'
$DmLogClass = 'Zar.DM.LogWin.WC'
$script:HotKeyNote = 'not set'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Start-P([string]$Left, [string]$Right) {
    if (-not $Right) { $Right = $Left }
    $a = @('-t', 'T147', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
        # End-Row counts every window but the main one as stray, so the row's windows are closed
        # first (as 117's End-P does): owned dialogs and boxes, then the plug-in windows themselves
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv118]::GetWindow($_, 4) -ne [IntPtr]::Zero })) { Close-Win $h }
        Start-Sleep -Milliseconds 500
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 10 -and @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass }).Count) { Start-Sleep -Milliseconds 200 }
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
        Other = @($shown | Where-Object { -not $_.StartsWith('[' + $WaitClass + ' ') }); Wait = @($shown | Where-Object { $_.StartsWith('[' + $WaitClass + ' ') }) }
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
function Set-HotKeys {
    $plugins = 'HKCU:\Software\Tandem Commander\Settings\Plugins'
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

# ---- feature 147 -----------------------------------------------------------------------------
# (the File Comparator and Checksum helpers come from the 118 probe)

function Make-Fixture147 {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    foreach ($d in @('fc_same', 'cs_lock')) { NewDir ($Root + '\' + $d) }
    [IO.File]::WriteAllText($LP + $Root + '\fc_same\a.txt', "one`r`ntwo`r`nthree`r`n", (New-Object Text.ASCIIEncoding))
    [IO.File]::WriteAllText($LP + $Root + '\fc_same\b.txt', "one`r`ntwo`r`nthree`r`n", (New-Object Text.ASCIIEncoding))
    $bytes = New-Object byte[] (2 * 1048576); (New-Object Random 147).NextBytes($bytes)
    [IO.File]::WriteAllBytes($LP + $Root + '\cs_lock\locked.bin', $bytes)
    return ("{0}\fc_same (two equal text files), {0}\cs_lock\locked.bin (2 MB, the probe locks its first MB during the rows)" -f $Root)
}

# the File Comparator on the two equal files: its "The files are identical" box
function Prepare-FcBox([int]$Id) {
    $h = Open-Fc $Id
    $sw = [Diagnostics.Stopwatch]::StartNew(); $box = $null
    while ($sw.Elapsed.TotalSeconds -lt 15 -and -not $box) {
        $box = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and (FullText $_) -match 'identical' }) | Select-Object -First 1
        if (-not $box) { Start-Sleep -Milliseconds 200 }
    }
    return @{ Reached = [bool]$box; Text = $(if ($box) { 'comparator box ' + (WinDesc $box) } else { 'no "identical" box' }) }
}
# Checksum Calculate on locked.bin while the probe holds a byte-range lock on its first MB: the
# worker's read fails at once and it shows its read-error box (Retry / Skip / Cancel)
function Prepare-CsReadError([int]$Id) {
    $target = $Root + '\cs_lock\locked.bin'
    $script:LockFs = New-Object IO.FileStream -ArgumentList ($LP + $target), ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
    $script:LockFs.Lock(0, 1048576)
    Select-All $Id
    $known = Get-Tops $Id
    # the read fails at once: the error box may be the first new window (Open-Calc would refuse it)
    [void](Open-ByKey $Id 0x55)   # Ctrl+Shift+U
    $sw = [Diagnostics.Stopwatch]::StartNew(); $box = $null; $c = [IntPtr]::Zero
    while ($sw.Elapsed.TotalSeconds -lt 15 -and (-not $box -or $c -eq [IntPtr]::Zero)) {
        $new = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $known -notcontains $_ })
        $calc = @($new | Where-Object { Is-CalcDlg $_ }) | Select-Object -First 1
        if ($calc) { $c = $calc }
        $box = @($new | Where-Object { -not (Is-CalcDlg $_) -and (FullText $_) -match 'Retry' }) | Select-Object -First 1
        if (-not $box -or $c -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 200 }
    }
    return @{ Reached = [bool]$box; Text = $(if ($box) { 'read-error box ' + (WinDesc $box) + ' over ' + (WinDesc $c) } else { 'no read-error box over ' + (WinDesc $c) }) }
}

# K row: the program's normal exit with the row's box open - expected a clean exit (exit code 0, no
# crash report, no fatal window, no "plug-in has rejected to unload" question) within 25 s
function Exit-Box-Row([string]$Name, [string]$What, [string]$Left, [scriptblock]$Prepare) {
    if (-not (Want $Name)) { return }
    Out ("--- {0}: {1} (expected: the program ends cleanly)" -f $Name, $What)
    $id = 0; $reports = Reports
    $script:LockFs = $null
    try {
        $id = Start-P $Left $Left
        $st = & $Prepare $id
        $fatal = Fatal-Win $id
        if ($fatal) { Row $Name 'STATE' 'FAIL' ('FATAL ' + $fatal); return }
        if (-not $st.Reached) { Row $Name 'STATE' 'NOT DRIVEN' ('state not reached: ' + $st.Text); return }
        Row $Name 'STATE' 'PASS' $st.Text
        $before = Get-Tops $id
        $seen = @{}; $fatalSeen = $null; $forceAsked = $false
        [void][Drv098f]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 25 -and (Test-Alive $id)) {
            foreach ($w in @(Get-Tops $id)) {
                if ($before -contains $w) { continue }
                $k = $w.ToInt64()
                if (-not $seen.ContainsKey($k)) {
                    $d = WinDesc $w; $seen[$k] = ('{0:N1} s {1}' -f $sw.Elapsed.TotalSeconds, $d)
                    if ($d -match $FatalRx) { $fatalSeen = $d }
                    if ($d -match 'rejected to unload') { $forceAsked = $true; $y = Buttons $w | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1; if ($y) { Click $y } }
                }
            }
            if ($fatalSeen) { break }
            Start-Sleep -Milliseconds 100
        }
        $alive = Test-Alive $id; $secs = $sw.Elapsed.TotalSeconds
        if ($alive) { Kill-Mine $id; $ec = 'still running after 25 s - ended by the probe' } else { $ec = ExitCodeOf $id }
        Start-Sleep -Milliseconds 600
        $rep = @(Take-Reports $reports)
        foreach ($s in @($seen.Values)) { Out ('           shown: ' + $s) }
        $ok = (-not $alive) -and ($ec -eq '0x00000000') -and ($rep.Count -eq 0) -and (-not $fatalSeen) -and (-not $forceAsked)
        Row $Name 'EXIT' (V $ok) ("{0}; after {1:N1} s; crash reports {2}{3}; fatal window {4}; the core's force question {5}" -f $ec, $secs, $rep.Count,
                $(if ($rep.Count) { ' [' + ($rep -join ' ;; ') + ']' } else { '' }), [bool]$fatalSeen, $(if ($forceAsked) { 'asked' } else { 'not asked' }))
        $id = 0
    }
    catch { Row $Name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($script:LockFs) { try { $script:LockFs.Dispose() } catch { }; $script:LockFs = $null }
        if ($id) { End-P $Name $id $reports }
    }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc147_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    $fx = Make-Fixture147
    Set-Config
    $script:HotKeyNote = Set-HotKeys
    Out ("plugin_close_box_probe (feature 147), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; registry key existed {2}; export SHA-256 {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $deskName, $existed, $regHash)
    Out ("Fixture : {0}" -f $fx)
    Out ("Hot keys: {0}" -f $script:HotKeyNote)
    Out ''
    Exit-Box-Row 'K1' "File Comparator, 'The files are identical' box open" ($Root + '\fc_same') { param($id) Prepare-FcBox $id }
    Exit-Box-Row 'K2' 'Checksum Calculate, its read-error box open' ($Root + '\cs_lock') { param($id) Prepare-CsReadError $id }
    Run-Row 'K3' 'installer: Checksum Calculate, its read-error box open' ($Root + '\cs_lock') $false $false {
        param($id)
        $st = Prepare-CsReadError $id
        return @{ Reached = $st.Reached; State = $st.Text; Work = $null }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    if ($script:LockFs) { try { $script:LockFs.Dispose() } catch { } }
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
