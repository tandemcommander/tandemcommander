<#
.SYNOPSIS
    Feature 286 probe: the Browse dialog of GetTargetDirectory hands back a folder whose UTF-8 path
    does not fit the caller's MAX_PATH buffer - the folder (or a folder shortcut's target) is
    refused ("The path specified is too long."), never cut, never replaced by a code-page form
    and never silently left unfollowed.

.DESCRIPTION
    Route: Configuration > Drives, "If path is inaccessible go to" (field 488), its browse button
    (360) - GetTargetDirectory with the field as the initial folder. The probe selects a folder in
    the browse dialog's tree (the initial folder, or its single child: TVM_EXPAND + TVM_SELECTITEM,
    handle messages only), presses OK and reads the field back.
    Rows:
      fsc-long   a folder shortcut (desktop.ini with the folder-shortcut CLSID + target.lnk) whose
                 target is a folder of 90 CJK letters (> 260 bytes UTF-8, < 260 units), picked as
                 the child of its parent. PASS = refused with "too long", the field unchanged
      fsc-long-init the same folder shortcut given as the initial folder, picked as it is
      fsc-ctl    a folder shortcut whose target fits: PASS = the field holds the target, nothing asked
      pick-long  a folder of 90 CJK letters picked as the child of its parent: PASS = refused
      pick-ctl   a folder of 20 CJK letters (fits): PASS = the field holds it whole, nothing asked
    Driver of 098's library. MUST run through tools\run_on_hidden_desktop.ps1.
    Registry exported, restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    # the browse tree hides hidden folders when Explorer does - %TEMP% (under the hidden AppData)
    # cannot be reached there; give a visible, disposable folder (e.g. the build folder)
    [string]$FixtureBase
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. $Lib
if (-not $FixtureBase) { $FixtureBase = $TempRoot }
$FixtureBase = [IO.Path]::GetFullPath($FixtureBase).TrimEnd('\')
$Root = $FixtureBase + '\tc286_fsc'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$Key01 = 'HKCU:\Software\Tandem Commander\0.1'
$WmUserConfiguration = 0x8000 + 115
$TooLong = 'too long'
$FolderShortcutClsid = '{0AFACED1-E828-11D1-9187-B532F1E9575D}'

# folder shortcuts are written with the wide shell-link interface (WScript.Shell refuses a target
# outside the code page, feature 128)
if (-not ('Lnk286' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
public static class Lnk286
{
    [ComImport, Guid("00021401-0000-0000-C000-000000000046")] class ShellLink { }
    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
    interface IShellLinkW
    {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cch, IntPtr pfd, int fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cch);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cch);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cch);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cch, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, int dwReserved);
        void Resolve(IntPtr hwnd, int fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }
    public static void Create(string lnk, string target)
    {
        var l = (IShellLinkW)new ShellLink();
        l.SetPath(target);
        ((IPersistFile)l).Save(lnk, true);
        Marshal.ReleaseComObject(l);
    }
    public static string Target(string lnk)
    {
        var l = (IShellLinkW)new ShellLink();
        ((IPersistFile)l).Load(lnk, 0);
        var sb = new StringBuilder(1024);
        l.GetPath(sb, sb.Capacity, IntPtr.Zero, 0);
        Marshal.ReleaseComObject(l);
        return sb.ToString();
    }
}
'@
}

function Cjk([int]$n, [int]$base = 0x4E00) { return (-join (1..$n | ForEach-Object { [char]($base + $_) })) }
function U8([string]$s) { return $Utf8.GetByteCount($s) }
# a folder shortcut $Dir -> $Target, as the shell makes them (NetHood entries, "Add a network location")
function New-FolderShortcut([string]$Dir, [string]$Target) {
    if (-not ($Dir.StartsWith($Root + '\'))) { throw "fixture path outside the root: $Dir" }
    NewDir $Dir
    $ini = $Dir + '\desktop.ini'
    [IO.File]::WriteAllText($ini, "[.ShellClassInfo]`r`nCLSID2=$FolderShortcutClsid`r`nFlags=2`r`n", (New-Object Text.ASCIIEncoding))
    [Lnk286]::Create($Dir + '\target.lnk', $Target)
    [IO.File]::SetAttributes($ini, [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System)
    [IO.File]::SetAttributes($Dir, [IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::Directory)
    $back = [Lnk286]::Target($Dir + '\target.lnk')
    if ($back -cne $Target) { throw ("target.lnk reads back another target: {0}" -f (Tail $back 40)) }
}
function Open-Config([int]$Id, [int]$Mode, [long]$Param) {
    $known = Get-Tops $Id
    [void][Drv098f]::PostMessageW((Get-Main $Id), $WmUserConfiguration, [IntPtr]$Mode, [IntPtr]$Param)
    return (Wait-NewWin $Id $known 15)
}
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    $held = [Drv098f]::GetText($f, 5000)
    if ($held -cne $Text) { throw ("field $CtlId did not take the text ({0} of {1} units)" -f $held.Length, $Text.Length) }
}
function Get-Field([IntPtr]$Dlg, [int]$CtlId) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { return '<no field>' }
    return [Drv098f]::GetText($f, 5000)
}
# answers every window except $Keep: OK / Yes ('ok') or Cancel ('cancel'); until idle
function Serve286([int]$Id, $Keep = @(), [string]$Policy = 'ok', [double]$Seconds = 30) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and $Keep -notcontains $_ })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            [void]$r.Messages.Add($d)
            $pick = $null
            if ($Policy -eq 'ok') { $btn = Buttons $h; foreach ($want in @(6, 1)) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } } }
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function Short([string]$s) {
    $s = $s -replace '\[Button id=\d+\] [^|]*(\||$)', ''
    $s = $s -replace '\[Static id=-?\d+\] ', ''
    if ($s.Length -gt 200) { $s = $s.Substring(0, 200) + '...' }
    return $s.Trim()
}
function Shown($r) { $m = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || '); if ($m) { return $m } else { return 'nothing' } }
function Tv([IntPtr]$Tree, [int]$Msg, [long]$W, [long]$L) {
    $res = [IntPtr]::Zero
    [void][Drv098f]::SendMessageTimeoutW($Tree, [uint32]$Msg, [IntPtr]$W, [IntPtr]$L, 0, 5000, [ref]$res)
    return $res.ToInt64()
}

function Run-Row([string]$Case, [scriptblock]$Body) {
    $before = Reports; $script:RowId = 0; $script:RowFatal = $null
    try { & $Body }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($script:RowId) { End-Row $Case $script:RowId $script:RowFatal $before } }
}

# the browse button of Configuration > Drives with $Init in the field; $Child = select the single
# child of the initial folder; returns what was shown, the field after, the OK state
function Browse-Row([string]$Case, [string]$Init, [switch]$Child, [string]$Expect, [switch]$Refuse) {
    Run-Row $Case {
        $id = Start-Tc $StartDir; $script:RowId = $id
        $dlg = Open-Config $id 6 0
        if ($dlg -eq [IntPtr]::Zero) { throw 'Configuration (mode 6) opened no window' }
        Set-Field $dlg 488 $Init
        $b = Find-Btn $dlg 360
        if (-not $b) { throw 'the browse button (360) was not found' }
        $known = Get-Tops $id
        Click $b
        $bro = Wait-NewWin $id $known 10
        if ($bro -eq [IntPtr]::Zero) { Close-Win $dlg; Row $Case 'RUN' 'NOT DRIVEN' 'the browse button opened no window'; return }
        Start-Sleep -Milliseconds 1500
        $tree = @([Drv098f]::Kids($bro) | Where-Object { [Drv098f]::Cls($_) -eq 'SysTreeView32' }) | Select-Object -First 1
        if (-not $tree) { $d = WinDesc $bro; Close-Win $bro; Start-Sleep -Milliseconds 400; Close-Win $dlg; Row $Case 'RUN' 'NOT DRIVEN' ('no tree in the browse window: ' + $d); return }
        $sel = Tv $tree 0x110A 9 0                                  # TVM_GETNEXTITEM, TVGN_CARET
        $how = 'the initial folder'
        if ($Child) {
            [void](Tv $tree 0x1102 2 $sel)                          # TVM_EXPAND, TVE_EXPAND
            Start-Sleep -Milliseconds 1200
            $kid = Tv $tree 0x110A 4 $sel                           # TVGN_CHILD
            if ($kid -eq 0) { Close-Win $bro; Start-Sleep -Milliseconds 400; Close-Win $dlg; Row $Case 'RUN' 'NOT DRIVEN' 'the initial folder shows no child in the tree'; return }
            [void](Tv $tree 0x110B 9 $kid)                          # TVM_SELECTITEM, TVGN_CARET
            Start-Sleep -Milliseconds 1000
            $how = 'its child'
        }
        $okBtn = Buttons $bro | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
        $okOn = $okBtn -and [Drv098f]::IsWindowEnabled($okBtn)
        if (-not $okOn) { Close-Win $bro; Start-Sleep -Milliseconds 400; Close-Win $dlg; [void](Serve286 $id @() 'cancel' 10); Row $Case 'RUN' 'FAIL' ("OK of the browse window is disabled for {0} - the folder cannot be picked at all" -f $how); return }
        Click $okBtn
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 5 -and [Drv098f]::IsWindow($bro)) { Start-Sleep -Milliseconds 100 }
        $r = Serve286 $id @($dlg) 'ok'
        $script:RowFatal = $r.Fatal; if (-not $script:RowFatal) { $script:RowFatal = Fatal-Win $id }
        $s = Shown $r
        $now = Get-Field $dlg 488
        Close-Win $dlg; Start-Sleep -Milliseconds 400; [void](Serve286 $id @() 'cancel' 10)
        if ($Refuse) { $verdict = ($s -match $TooLong) -and (@($r.Messages).Count -eq 1) -and ($now -ceq $Init) }
        else { $verdict = ($s -eq 'nothing') -and ($now -ceq $Expect) }
        $ok = (-not $script:RowFatal) -and (-not $r.TimedOut) -and $verdict
        Row $Case 'RUN' (V $ok) ("picked {0}; asked: {1}; field after: {2} units / {3} bytes, same as the initial folder: {4}, same as expected: {5}, tail '{6}'{7}" -f $how, $s, $now.Length, (U8 $now), ($now -ceq $Init), ($now -ceq $Expect), (Tail $now 24), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }))
    }
}

$Cases = [ordered]@{}
$TgtLong = $Root + '\tgt\' + (Cjk 90)
$TgtShort = $Root + '\tgt\short'
$Cases['fsc-long'] = { Browse-Row 'fsc-long' ($Root + '\fl') -Child -Refuse }
$Cases['fsc-long-init'] = { Browse-Row 'fsc-long-init' ($Root + '\fl\fsc') -Refuse }
$Cases['fsc-ctl'] = { Browse-Row 'fsc-ctl' ($Root + '\fc') -Child -Expect $TgtShort }
$Cases['pick-long'] = { Browse-Row 'pick-long' ($Root + '\pl') -Child -Refuse }
$Cases['pick-ctl'] = { Browse-Row 'pick-ctl' ($Root + '\pc') -Child -Expect ($Root + '\pc\' + (Cjk 20)) }

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc286_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) {
        Get-ChildItem -LiteralPath $Root -Recurse -Force -Directory | ForEach-Object { $_.Attributes = 'Directory' }
        [IO.Directory]::Delete($LP + $Root, $true)
    }
    NewDir $StartDir; NewDir $OutDir
    NewDir $TgtLong; NewDir $TgtShort
    New-FolderShortcut ($Root + '\fl\fsc') $TgtLong
    New-FolderShortcut ($Root + '\fc\fsc') $TgtShort
    # a plain sibling (sorted after the shortcut): the tree expands only a parent that "has a subfolder"
    # and a folder shortcut alone does not make it one
    NewDir ($Root + '\fl\zz'); NewDir ($Root + '\fc\zz')
    NewDir ($Root + '\pl\' + (Cjk 90))
    NewDir ($Root + '\pc\' + (Cjk 20))
    Set-Config
    Out ("fsc286_probe (feature 286) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ("Fixture : long target {0} units / {1} bytes; short target {2}" -f $TgtLong.Length, (U8 $TgtLong), $TgtShort)
    Out ''
    foreach ($k in @($Cases.Keys)) {
        if (Want $k) {
            # every row starts from the user's configuration (a row's exit writes it back)
            & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
            if ($existed) { & cmd.exe /c "reg import `"$backup`" >nul 2>&1" }
            Set-Config
            & $Cases[$k]
        }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try {
        if ([IO.Directory]::Exists($LP + $Root)) {
            Get-ChildItem -LiteralPath $Root -Recurse -Force -Directory | ForEach-Object { $_.Attributes = 'Directory' }
            [IO.Directory]::Delete($LP + $Root, $true)
        }
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
