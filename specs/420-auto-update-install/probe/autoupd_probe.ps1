<#
.SYNOPSIS
    Feature 420 (automatic update) - behaviour probe of a Debug build.
    Rows follow specs/420-auto-update-install/spec.md, contracts/*.md and quickstart.md section 2.
    Groups: L levels, V verification, B buttons, X exit, S completion at the next start,
    T test mode, G Configuration > General. Every row prints PASS / FAIL / NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Backs up the product's registry key and
    restores it (verified by SHA-256); creates and removes the updates folder
    %LOCALAPPDATA%\Tandem Commander\Updates and a fake uninstall entry under
    HKCU\Software\TC420Probe. The installer is never started: the Debug seam
    TC_UPDATE_PROBE_RUNLOG records what would be started.
.PARAMETER Exe   tandemcommander.exe of a Debug build with the feature
.PARAMETER Only  groups to run (default all), e.g. -Only L,S
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Only = @(),
    [string]$Result = ''
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not $Result) { $Result = Join-Path $PSScriptRoot 'autoupd_result.txt' }
if ($Only.Count -eq 1 -and $Only[0] -match ',') { $Only = @($Only[0] -split ',') }
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Write-Host 'NOT RUN: a tandemcommander.exe is running (the registry key is shared with it)'; exit 99 }

if (-not ('P420' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class P420
{
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr GetPropW(IntPtr h, string name);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern int GetApplicationRestartSettings(IntPtr process, StringBuilder cmd, ref uint size, out uint flags);
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    // the result of a sent message; long.MinValue when it was not answered in time
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout)
    {
        IntPtr res;
        if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out res) == IntPtr.Zero) return long.MinValue;
        return res.ToInt64();
    }
    public static IntPtr Notice(uint pid)
    {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid && IsWindowVisible(h) && GetPropW(h, "TandemCommander.UpdateNotice") != IntPtr.Zero) { found = h; return false; }
            return true; }, IntPtr.Zero);
        return found;
    }
    // the command line the process registered for a restart (Restart Manager), or null
    public static string RestartCmd(uint pid)
    {
        IntPtr h = OpenProcess(0x0400 | 0x0010, false, pid); // QUERY_INFORMATION | VM_READ
        if (h == IntPtr.Zero) return null;
        try
        {
            var sb = new StringBuilder(2048); uint size = 2048; uint flags;
            int hr = GetApplicationRestartSettings(h, sb, ref size, out flags);
            return hr == 0 ? sb.ToString() : ("<hr 0x" + hr.ToString("X8") + ">");
        }
        finally { CloseHandle(h); }
    }
}
'@
}

$Z = [IntPtr]::Zero
$Port = 8420
$Fx = $TempRoot + '\tc420'
$SrvLog = $Fx + '\requests.log'
$RunLog = $Fx + '\runlog.txt'
$OpenLog = $Fx + '\openlog.txt'
$PanelDir = $Fx + '\panel'
$Upd = Join-Path $env:LOCALAPPDATA 'Tandem Commander\Updates'
$UcKey = 'HKCU\Software\Tandem Commander\Settings\Update Check'
$ProbeKeyRel = 'Software\TC420Probe\Uninstall'
$Good = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\setup\output\tandemcommander-0.2.0-x64-setup.exe')).Path
$Older = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\setup\output\tandemcommander-0.1.9-x64-setup.exe')).Path
$Foreign = 'C:\Program Files\Inno Setup 7\ISCC.exe'
$Unsigned = 'C:\Program Files\7-Zip\7z.exe'
$InstallerName = 'tandemcommander-0.2.0-x64-setup.exe'

function T([string]$Case, [string]$Step, [bool]$Ok, [string]$Facts) { Row $Case $Step (V $Ok) $Facts }
function ND([string]$Case, [string]$Step, [string]$Facts) { Row $Case $Step 'NOT DRIVEN' $Facts }

# ---- fixture server -----------------------------------------------------------------
$script:Srv = $null
function Http-Get([string]$Path) {
    $wc = New-Object Net.WebClient; $wc.Proxy = $null
    try { [void]$wc.DownloadString("http://127.0.0.1:$Port$Path"); return $true } catch { return $false } finally { $wc.Dispose() }
}
function Start-Server {
    Remove-Item -LiteralPath $SrvLog -Force -ErrorAction SilentlyContinue
    $a = @(('"{0}"' -f (Join-Path $PSScriptRoot 'updserver420.py')), '--port', $Port, '--log', ('"{0}"' -f $SrvLog),
        '--good', ('"{0}"' -f $Good), '--older', ('"{0}"' -f $Older), '--foreign', ('"{0}"' -f $Foreign), '--unsigned', ('"{0}"' -f $Unsigned))
    $script:Srv = Start-Process -FilePath python -ArgumentList $a -PassThru -WindowStyle Hidden
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) { if (Http-Get '/latest/rel-good') { return }; Start-Sleep -Milliseconds 200 }
    throw 'the fixture server did not start'
}
function Stop-Server { if ($script:Srv -and -not $script:Srv.HasExited) { [void](Http-Get '/stop'); Start-Sleep -Milliseconds 400; if (-not $script:Srv.HasExited) { Stop-Process -Id $script:Srv.Id -Force } } }
function Reqs([string]$Like) {
    $o = @()
    if (Test-Path -LiteralPath $SrvLog) { foreach ($line in @(Get-Content -LiteralPath $SrvLog)) { if ($line) { $j = $line | ConvertFrom-Json; if ($j.path -like $Like) { $o += $j } } } }
    return , $o
}
function AssetReqs { return (Reqs '/repos/*').Count }

# ---- registry and files ----------------------------------------------------------------
function Uc-Set([string]$Name, $Value, [string]$Type = 'DWord') {
    $t = @{ DWord = 'REG_DWORD'; QWord = 'REG_QWORD'; String = 'REG_SZ' }[$Type]
    & reg.exe add $UcKey /v $Name /t $t /d $Value /f | Out-Null
}
function Uc-Get([string]$Name) {
    $p = Get-ItemProperty -LiteralPath ('Registry::' + $UcKey) -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $p) { return $null }; return $p.$Name
}
function Uc-Del([string]$Name) { & cmd.exe /c "reg delete `"$UcKey`" /v `"$Name`" /f >nul 2>&1" }
function Uc-Snapshot { $k = Get-ItemProperty -LiteralPath ('Registry::' + $UcKey) -ErrorAction SilentlyContinue; if (-not $k) { return '' }; return (@('Check At Startup', 'Last Attempt', 'Last Attempt Answered', 'Last Success', 'Latest Version', 'Latest Published', 'Skipped Version') | ForEach-Object { $_ + '=' + $k.$_ }) -join '; ' }
function Arm {
    $v = Uc-Get 'Install Version'
    if ($null -eq $v) { return $null }
    return [pscustomobject]@{ Version = $v; Source = (Uc-Get 'Install Source'); Test = (Uc-Get 'Install Test'); Launches = (Uc-Get 'Install Launches'); Digest = (Uc-Get 'Install Digest') }
}
function ArmStr($a) { if ($null -eq $a) { return 'no arm' }; return ('arm {0} source {1} test {2} launches {3}' -f $a.Version, $a.Source, $a.Test, $a.Launches) }
function UpdFiles { if (Test-Path -LiteralPath $Upd) { return , @(Get-ChildItem -LiteralPath $Upd -File | ForEach-Object { $_.Name }) }; return , @() }
function FilesStr { $f = UpdFiles; if ($f.Count) { return ($f -join ', ') }; return 'no files' }
function Runs { if (Test-Path -LiteralPath $RunLog) { return , @(Get-Content -LiteralPath $RunLog | Where-Object { $_ }) }; return , @() }
function Reset-State([int]$Level = -1) {
    foreach ($n in @('Last Attempt', 'Last Attempt Answered', 'Last Success', 'Latest Version', 'Latest Published', 'Skipped Version', 'Update Level',
            'Install Version', 'Install Digest', 'Install Source', 'Install Test', 'Install Launches')) { Uc-Del $n }
    Uc-Set 'Check At Startup' 1
    if ($Level -ge 0) { Uc-Set 'Update Level' $Level }
    if (Test-Path -LiteralPath $Upd) { Remove-Item -LiteralPath $Upd -Recurse -Force }
    Remove-Item -LiteralPath $RunLog, $OpenLog -Force -ErrorAction SilentlyContinue
}
function NoCheck { Uc-Set 'Last Attempt' ([DateTime]::UtcNow.ToFileTimeUtc()) 'QWord'; Uc-Set 'Last Attempt Answered' 1 }

# ---- the program ------------------------------------------------------------------------
function Set-Env([string]$Fixture = 'rel-good', [string]$Pretend = '0.1.9', [bool]$Eligible = $true, [bool]$Metered = $false) {
    $env:TC_UPDATECHECK_URL = "http://127.0.0.1:$Port/latest/$Fixture"
    if ($Pretend) { $env:TC_UPDATECHECK_PRETEND_VERSION = $Pretend } else { Remove-Item Env:\TC_UPDATECHECK_PRETEND_VERSION -ErrorAction SilentlyContinue }
    if ($Eligible) { $env:TC_UPDATE_PROBE_UNINSTALL = 'CURRENTUSER:' + $ProbeKeyRel } else { Remove-Item Env:\TC_UPDATE_PROBE_UNINSTALL -ErrorAction SilentlyContinue }
    if ($Metered) { $env:TC_UPDATE_PROBE_METERED = '1' } else { Remove-Item Env:\TC_UPDATE_PROBE_METERED -ErrorAction SilentlyContinue }
    $env:TC_UPDATE_PROBE_RUNLOG = $RunLog
    $env:TC_UPDATECHECK_OPENLOG = $OpenLog
}
function Start-420([string[]]$Extra = @()) {
    $a = @('-t', 'T420', '-l', ('"{0}"' -f $PanelDir), '-r', ('"{0}"' -f $PanelDir)) + $Extra
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq $Z) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq $Z) { throw 'the program did not show its main window' }
    return $p.Id
}
# closes the program normally (WM_CLOSE); returns the seconds until the process ended (-1: killed after 25 s)
function Quit([int]$Id) {
    if (-not (Test-Alive $Id)) { return 0 }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, $Z, $Z)
    while ($sw.Elapsed.TotalSeconds -lt 25 -and (Test-Alive $Id)) { Start-Sleep -Milliseconds 50 }
    if (Test-Alive $Id) { Kill-Mine $Id; return -1 }
    return [math]::Round($sw.Elapsed.TotalSeconds, 2)
}
function Kill-Wait([int]$Id) {
    Kill-Mine $Id
    if ($script:Procs.ContainsKey($Id)) { try { [void]$script:Procs[$Id].WaitForExit(10000) } catch { } }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and (Test-Alive $Id)) { Start-Sleep -Milliseconds 100 }
}
function Wait-Notice([int]$Id, [double]$Seconds = 30) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) { $h = [P420]::Notice([uint32]$Id); if ($h -ne $Z) { Start-Sleep -Milliseconds 300; return [P420]::Notice([uint32]$Id) }; Start-Sleep -Milliseconds 150 }
    return $Z
}
# waits for the notice in a given form (a classic one may be replaced by the downloaded one)
function Wait-Form([int]$Id, [string]$Form, [double]$Seconds = 40) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) { $h = [P420]::Notice([uint32]$Id); if ($h -ne $Z -and (Form $h) -eq $Form) { return $h }; Start-Sleep -Milliseconds 200 }
    return [P420]::Notice([uint32]$Id)
}
function Ctl([IntPtr]$Dlg, [int]$CtlId) { foreach ($k in [Drv098f]::Kids($Dlg)) { if ([Drv098f]::GetDlgCtrlID($k) -eq $CtlId) { return $k } }; return $Z }
function CtlText([IntPtr]$Dlg, [int]$CtlId) { $c = Ctl $Dlg $CtlId; if ($c -eq $Z) { return '<none>' }; return [Drv098f]::Txt($c) }
function Form([IntPtr]$H) {
    if ($H -eq $Z) { return 'none' }
    $ok = CtlText $H 1; $ie = Ctl $H 6296; $cancel = CtlText $H 2
    $ieVis = ($ie -ne $Z -and [Drv098f]::IsWindowVisible($ie))
    if ($ok -eq '&Download') { return 'classic' }
    if ($ok -eq 'Install &Now' -and $ieVis) { return 'offer' }
    if ($ok -eq 'Install &Now' -and $cancel -eq 'OK' -and -not $ieVis) { return 'automatic' }
    return ('other(' + $ok + '|' + $cancel + '|' + $ieVis + ')')
}
function Press([IntPtr]$Dlg, [int]$CtlId) { $c = Ctl $Dlg $CtlId; if ($c -ne $Z) { Click $c } }
function Gone([IntPtr]$H, [double]$Seconds = 5) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if (-not [Drv098f]::IsWindow($H)) { return $true }; Start-Sleep -Milliseconds 100 }; return $false }
function Wait-Arm([double]$Seconds = 40) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { $a = Arm; if ($null -ne $a) { return $a }; Start-Sleep -Milliseconds 200 }; return $null }
function Wait-Run([int]$Count, [double]$Seconds = 15) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if ((Runs).Count -ge $Count) { return $true }; Start-Sleep -Milliseconds 150 }; return $false }
function RunsStr { $r = Runs; if (-not $r.Count) { return 'nothing started' }; return (($r | ForEach-Object { Esc $_ }) -join ' || ') }

$Groups = [ordered]@{}

# L: the levels (FR-001, FR-002, FR-009, FR-010, US1, US3, US6)
$Groups['L'] = {
    Reset-State 0; Set-Env
    $id = Start-420; $h = Wait-Notice $id 20; Start-Sleep -Seconds 2
    T 'L0' 'notify' ((Form $h) -eq 'classic' -and (AssetReqs) -eq 0 -and (UpdFiles).Count -eq 0) ('level 0: notice {0}, asset requests {1}, {2}' -f (Form $h), (AssetReqs), (FilesStr))
    [void](Quit $id)

    Reset-State; Set-Env; $before = AssetReqs
    $id = Start-420; $h = Wait-Form $id 'offer'
    $f = UpdFiles
    T 'L1' 'offer' ((Form $h) -eq 'offer' -and $f.Count -eq 1 -and $f[0] -eq $InstallerName -and $null -eq (Arm) -and (AssetReqs) -gt $before) ('no level stored (default): notice {0}, {1}, {2}, asset requests {3}' -f (Form $h), (FilesStr), (ArmStr (Arm)), ((AssetReqs) - $before))
    $hint = CtlText $h 6248
    T 'L1' 'hint' ($hint -like '*downloaded and verified*when you close*') ('hint: ' + (Esc $hint))
    [void](Quit $id)
    T 'L1' 'exit' ((Runs).Count -eq 0) ('exit with an offered but not armed update: ' + (RunsStr))

    Reset-State 2; Set-Env
    $id = Start-420; $h = Wait-Form $id 'automatic'; $a = Arm
    T 'L2' 'auto' ((Form $h) -eq 'automatic' -and $null -ne $a -and $a.Source -eq 2 -and $a.Test -eq 0 -and $a.Launches -eq 0 -and $a.Version -eq '0.2.0') ('level 2: notice {0}, {1}, {2}' -f (Form $h), (ArmStr $a), (FilesStr))
    $s = Quit $id; $r = Runs; $a = Arm
    $ok = $r.Count -eq 1 -and $r[0] -like 'exit|"*\Tandem Commander\Updates\tandemcommander-0.2.0-x64-setup.exe" /SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS /CURRENTUSER /LOG="*\setup-0.2.0.log"'
    T 'L2' 'exit' ($ok -and $a.Launches -eq 1) ('normal exit after {0} s: {1}; {2}' -f $s, (RunsStr), (ArmStr $a))

    Reset-State 2; Uc-Set 'Check At Startup' 0; Set-Env
    $all = (Reqs '/*').Count
    $id = Start-420; Start-Sleep -Seconds 8; $h = [P420]::Notice([uint32]$id)
    T 'L3' 'off' ($h -eq $Z -and (Reqs '/*').Count -eq $all -and (UpdFiles).Count -eq 0 -and $null -eq (Arm)) ('check off, level 2: notice {0}, requests {1}, {2}, {3}' -f (Form $h), ((Reqs '/*').Count - $all), (FilesStr), (ArmStr (Arm)))
    [void](Quit $id)

    Reset-State 1; Set-Env -Metered $true; $before = AssetReqs
    $id = Start-420; $h = Wait-Notice $id 20; Start-Sleep -Seconds 2
    T 'L4' 'metered' ((Form $h) -eq 'classic' -and (AssetReqs) -eq $before -and (UpdFiles).Count -eq 0) ('metered connection: notice {0}, asset requests {1}, {2}' -f (Form $h), ((AssetReqs) - $before), (FilesStr))
    [void](Quit $id)

    Reset-State 2; Set-Env -Eligible $false; $before = AssetReqs
    $id = Start-420; $h = Wait-Notice $id 20; Start-Sleep -Seconds 2
    T 'L5' 'portable' ((Form $h) -eq 'classic' -and (AssetReqs) -eq $before -and (UpdFiles).Count -eq 0 -and $null -eq (Arm)) ('no matching uninstall entry (the real HKLM entry names Program Files): notice {0}, asset requests {1}, {2}' -f (Form $h), ((AssetReqs) - $before), (FilesStr))
    [void](Quit $id)

    foreach ($fx in @('rel-nodigest', 'rel-huge')) {
        Reset-State 1; Set-Env $fx; $before = AssetReqs
        $id = Start-420; $h = Wait-Notice $id 20; Start-Sleep -Seconds 2
        T 'L6' $fx.Substring(4) ((Form $h) -eq 'classic' -and (AssetReqs) -eq $before -and (UpdFiles).Count -eq 0) ('{0}: notice {1}, asset requests {2}, {3}' -f $fx, (Form $h), ((AssetReqs) - $before), (FilesStr))
        [void](Quit $id)
    }
}

# V: never run a file that is not proven ours (US4, FR-005, FR-008, SC-004)
$Groups['V'] = {
    foreach ($v in @('tampered', 'foreign', 'unsigned', 'older', 'truncated', 'extra', 'foreignrd', 'portrd', 'loop')) {
        Reset-State 2; Set-Env ('rel-' + $v); $before = AssetReqs
        $id = Start-420; $h = Wait-Notice $id 40
        # the classic form appears once the download failed
        $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 20 -and (Form $h) -ne 'classic') { Start-Sleep -Milliseconds 200; $h = [P420]::Notice([uint32]$id) }
        Start-Sleep -Seconds 1
        $n = (AssetReqs) - $before
        $form = Form $h
        [void](Quit $id)
        $ok = $form -eq 'classic' -and (UpdFiles).Count -eq 0 -and $null -eq (Arm) -and (Runs).Count -eq 0 -and $n -ge 1
        if ($v -eq 'loop') { $ok = $ok -and $n -le 4 }
        T 'V1' $v $ok ('{0}: notice {1}, asset requests {2}, {3}, {4}, after the exit: {5}' -f $v, $form, $n, (FilesStr), (ArmStr (Arm)), (RunsStr))
    }
}

# B: the buttons of the downloaded forms (FR-009 - FR-011, FR-015)
$Groups['B'] = {
    Reset-State 1; Set-Env
    $id = Start-420; $h = Wait-Form $id 'offer'
    Press $h 1; [void](Wait-Run 1 10); $r = Runs; $a = Arm
    $ok = $r.Count -eq 1 -and $r[0] -like 'now|"*\tandemcommander-0.2.0-x64-setup.exe" /SP- /SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /CURRENTUSER /LOG="*\setup-0.2.0.log"'
    T 'B1' 'now' ($ok -and $null -ne $a -and $a.Source -eq 1 -and $a.Launches -eq 1 -and (Gone $h 3)) ('Install Now: {0}; {1}; notice closed {2}' -f (RunsStr), (ArmStr $a), (-not [Drv098f]::IsWindow($h)))
    [void](Quit $id)

    Reset-State 1; Set-Env
    $id = Start-420; $h = Wait-Form $id 'offer'
    Press $h 6296; $gone = Gone $h 3; $a = Arm
    T 'B2' 'arm' ($gone -and $null -ne $a -and $a.Source -eq 1 -and $a.Launches -eq 0 -and (Runs).Count -eq 0) ('Install When I Close: notice closed {0}, {1}, {2}' -f $gone, (ArmStr $a), (RunsStr))
    $s = Quit $id; $r = Runs
    T 'B2' 'exit' ($r.Count -eq 1 -and $r[0] -like 'exit|*/VERYSILENT*/NORESTARTAPPLICATIONS /CURRENTUSER*') ('exit after {0} s: {1}' -f $s, (RunsStr))

    Reset-State 1; Set-Env
    $id = Start-420; $h = Wait-Form $id 'offer'
    Press $h 6250; $gone = Gone $h 3
    T 'B3' 'skip' ($gone -and $null -eq (Arm) -and (UpdFiles).Count -eq 0 -and (Uc-Get 'Skipped Version') -eq '0.2.0') ('Skip This Version (offer): closed {0}, {1}, {2}, skipped {3}' -f $gone, (ArmStr (Arm)), (FilesStr), (Uc-Get 'Skipped Version'))
    [void](Quit $id)

    Reset-State 2; Set-Env
    $id = Start-420; $h = Wait-Form $id 'automatic'
    Press $h 2; $gone = Gone $h 3; $a = Arm
    T 'B4' 'ok' ($gone -and $null -ne $a -and $a.Source -eq 2) ('OK (automatic): closed {0}, {1}' -f $gone, (ArmStr $a))
    [void](Quit $id); Reset-State 2; Set-Env
    $id = Start-420; $h = Wait-Form $id 'automatic'
    Press $h 6250; $gone = Gone $h 3
    T 'B4' 'skip' ($gone -and $null -eq (Arm) -and (UpdFiles).Count -eq 0) ('Skip This Version (automatic): closed {0}, {1}, {2}' -f $gone, (ArmStr (Arm)), (FilesStr))
    [void](Quit $id)
    T 'B4' 'exit' ((Runs).Count -eq 0) ('exit after Skip: ' + (RunsStr))
}

# X: the exit (FR-012, US2-1, US2-4, US2-5, SC-006)
$Groups['X'] = {
    Reset-State 2; Set-Env
    $a1 = Start-420; $h = Wait-Form $a1 'automatic'
    $a2 = Start-420; Start-Sleep -Seconds 5
    T 'X1' 'second' ((Runs).Count -eq 0) ('a second instance started while the first holds the arm: ' + (RunsStr))
    $s1 = Quit $a1; Start-Sleep -Milliseconds 500
    T 'X1' 'first' ((Runs).Count -eq 0) ('the first instance closed while the second runs (after {0} s): {1}' -f $s1, (RunsStr))
    $s2 = Quit $a2; $r = Runs
    T 'X1' 'last' ($r.Count -eq 1 -and $r[0] -like 'exit|*') ('the last instance closed (after {0} s): {1}' -f $s2, (RunsStr))

    Reset-State 0; Set-Env
    $id = Start-420; [void](Wait-Notice $id 20); Start-Sleep -Seconds 1
    $base = Quit $id
    Reset-State 1; Set-Env 'rel-slow'
    $id = Start-420
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 20 -and (Reqs '/dl/10').Count -eq 0) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Seconds 2
    $dl = (Reqs '/dl/10').Count
    $parts = @(UpdFiles | Where-Object { $_ -like '*.part' }).Count
    $s = Quit $id; Start-Sleep -Milliseconds 300
    T 'X2' 'time' ($dl -ge 1 -and $parts -eq 1 -and $s -ge 0 -and ($s - $base) -lt 2.5) ('exit during a running download: {0} s (without a download {1} s); .part while downloading {2}; files after the exit: {3}' -f $s, $base, $parts, (FilesStr))
}

# S: an armed update the exit did not install is completed at the next start (US2-2, US2-3, FR-013, FR-014, SC-003)
$Groups['S'] = {
    Reset-State 2; Set-Env
    $id = Start-420; [void](Wait-Form $id 'automatic'); $a = Arm
    Kill-Wait $id
    T 'S1' 'killed' ($null -ne $a -and (Runs).Count -eq 0) ('armed, then the program ended without its exit: {0}, {1}' -f (ArmStr $a), (RunsStr))
    for ($n = 1; $n -le 3; $n++) {
        NoCheck
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $id = Start-420; $got = Wait-Run $n 20; $t = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        $r = Runs; $a = Arm
        $ok = $got -and $r.Count -eq $n -and $r[$n - 1] -like 'now|*/SILENT*/CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /CURRENTUSER*' -and $a.Launches -eq $n
        T 'S1' ('start' + $n) $ok ('start {0}: installer after {1} s: {2}; {3}' -f $n, $t, (Esc $r[$n - 1]), (ArmStr $a))
        Kill-Wait $id
    }
    NoCheck
    $id = Start-420; Start-Sleep -Seconds 6
    T 'S1' 'giveup' ((Runs).Count -eq 3 -and $null -eq (Arm) -and (UpdFiles) -contains $InstallerName) ('fourth start after 3 launches: {0} launches logged, {1}, {2}' -f (Runs).Count, (ArmStr (Arm)), (FilesStr))
    [void](Quit $id)

    Reset-State 2; Set-Env
    $id = Start-420; [void](Wait-Form $id 'automatic'); Kill-Wait $id
    NoCheck; Set-Env -Pretend '0.2.0'
    $id = Start-420; Start-Sleep -Seconds 6
    T 'S2' 'reached' ((Runs).Count -eq 0 -and $null -eq (Arm) -and (UpdFiles).Count -eq 0) ('the running version is the armed one: {0}, {1}, {2}' -f (RunsStr), (ArmStr (Arm)), (FilesStr))
    [void](Quit $id)

    Reset-State 2; Set-Env
    $id = Start-420; [void](Wait-Form $id 'automatic'); Kill-Wait $id
    $p = Join-Path $Upd $InstallerName; $b = [IO.File]::ReadAllBytes($p); $b[1000] = $b[1000] -bxor 1; [IO.File]::WriteAllBytes($p, $b)
    NoCheck
    $id = Start-420; Start-Sleep -Seconds 6
    T 'S3' 'tampered' ((Runs).Count -eq 0 -and $null -eq (Arm) -and (UpdFiles).Count -eq 0) ('the armed installer changed on disk: {0}, {1}, {2}' -f (RunsStr), (ArmStr (Arm)), (FilesStr))
    [void](Quit $id)

    Reset-State 2; Set-Env
    $id = Start-420; [void](Wait-Form $id 'automatic'); Kill-Wait $id
    Uc-Set 'Update Level' 1; NoCheck
    $id = Start-420; Start-Sleep -Seconds 6
    T 'S4' 'lowered' ((Runs).Count -eq 0 -and $null -eq (Arm) -and (UpdFiles) -contains $InstallerName) ('automatic arm, level lowered to 1: {0}, {1}, {2}' -f (RunsStr), (ArmStr (Arm)), (FilesStr))
    [void](Quit $id)

    Reset-State 1; Set-Env
    $id = Start-420; $h = Wait-Form $id 'offer'; Press $h 6296; [void](Gone $h 3); Kill-Wait $id
    Uc-Set 'Update Level' 0; NoCheck
    $id = Start-420; [void](Wait-Run 1 20)
    T 'S5' 'user' ((Runs).Count -eq 1 -and (Runs)[0] -like 'now|*') ('armed by a click (Install When I Close), level then 0, program killed: {0}' -f (RunsStr))
    Kill-Wait $id
}

# T: test mode --updatetest (US5, FR-016 - FR-018, SC-005)
$Groups['T'] = {
    Reset-State 1; Set-Env -Pretend ''
    NoCheck; Uc-Set 'Skipped Version' '0.2.0' 'String'; Uc-Set 'Check At Startup' 0
    $snap = Uc-Snapshot
    $id = Start-420 @('--updatetest'); $h = Wait-Form $id 'offer'
    $rel = CtlText $h 6246
    T 'T1' 'offer' ((Form $h) -eq 'offer' -and (UpdFiles) -contains $InstallerName) ('installed 0.2.0 = published 0.2.0, option off, interval not due, 0.2.0 skipped: notice {0}, {1}' -f (Form $h), (FilesStr))
    T 'T1' 'line' ($rel -like '*test mode*') ('the released line: ' + (Esc $rel))
    $rc = [P420]::RestartCmd([uint32]$id)
    T 'T2' 'restart' ($null -ne $rc -and $rc -notmatch 'updatetest' -and $rc -match 'T420') ('registered restart command line: ' + (Esc $rc))
    [void](Quit $id)
    $snap2 = Uc-Snapshot
    T 'T1' 'state' ($snap -eq $snap2) ('123 state before {0} / after {1}' -f $snap, $snap2)

    Reset-State 2; Set-Env -Pretend ''
    $id = Start-420 @('--updatetest'); [void](Wait-Form $id 'automatic'); $a = Arm
    T 'T3' 'arm' ($null -ne $a -and $a.Test -eq 1 -and $a.Source -eq 2) ('test mode, level 2: ' + (ArmStr $a))
    Kill-Wait $id
    NoCheck
    $id = Start-420 @('--updatetest'); $got = Wait-Run 1 20; $a = Arm
    T 'T3' 'complete' ($got -and (Runs)[0] -like 'now|*' -and $a.Launches -eq 1) ('killed, started again with --updatetest: {0}; {1}' -f (RunsStr), (ArmStr $a))
    Kill-Wait $id
    $id = Start-420 @('--updatetest'); Start-Sleep -Seconds 6; $a = Arm
    T 'T3' 'launched' ((Runs).Count -eq 1) ('a launched test arm at the next test start counts as done: {0}; then {1}' -f (RunsStr), (ArmStr $a))
    [void](Quit $id)

    Reset-State 2; Set-Env -Pretend ''
    $id = Start-420 @('--updatetest'); [void](Wait-Form $id 'automatic'); Kill-Wait $id
    NoCheck
    $id = Start-420; Start-Sleep -Seconds 6
    T 'T4' 'normal' ((Runs).Count -eq 0 -and $null -eq (Arm) -and (UpdFiles).Count -eq 0) ('a test arm at a start without the switch: {0}, {1}, {2}' -f (RunsStr), (ArmStr (Arm)), (FilesStr))
    [void](Quit $id)

    Reset-State 2; Set-Env -Pretend ''
    $id = Start-420 @('--updatetest'); [void](Wait-Form $id 'automatic')
    $s = Quit $id; $r = Runs
    T 'T5' 'exit' ($r.Count -eq 1 -and $r[0] -like 'exit|*') ('test mode, level 2, normal exit after {0} s: {1}' -f $s, (RunsStr))
}

# G: Configuration > General (FR-001, US3)
$CfgKey = 'HKCU\Software\Tandem Commander\Settings\Configuration'
function Cfg-General { & cmd.exe /c "reg add `"$CfgKey`" /v `"Last Focused Page`" /t REG_DWORD /d 0 /f >nul 2>&1" }
$Groups['G'] = {
    Reset-State; Set-Env; NoCheck; Cfg-General
    $id = Start-420; Start-Sleep -Seconds 2
    $cfg = Open-ByCmd $id 686 10
    $combo = Ctl $cfg 6298; $box = Ctl $cfg 6255; $label = Ctl $cfg 6297
    if ($combo -eq $Z) { T 'G1' 'combo' $false 'no list 6298 in the Configuration dialog'; Close-Win $cfg; [void](Quit $id); return }
    $sel = [P420]::SendR($combo, 0x0147, 0, 0, 3000)  # CB_GETCURSEL
    $cnt = [P420]::SendR($combo, 0x0146, 0, 0, 3000)  # CB_GETCOUNT
    T 'G1' 'default' ($sel -eq 1 -and $cnt -eq 3 -and [Drv098f]::IsWindowEnabled($combo)) ('no stored level: selected {0} of {1}, enabled {2}, label {3}' -f $sel, $cnt, [Drv098f]::IsWindowEnabled($combo), (Esc ([Drv098f]::Txt($label))))
    [void][P420]::SendR($combo, 0x014E, 2, 0, 3000)   # CB_SETCURSEL 2
    $ok = Buttons $cfg | Where-Object { [Drv098f]::Txt($_) -eq 'OK' -and [Drv098f]::GetParent($_) -eq $cfg } | Select-Object -First 1
    Click $ok; [void](Gone $cfg 5); Start-Sleep -Milliseconds 500
    T 'G1' 'store' ((Uc-Get 'Update Level') -eq 2) ('after choosing the third item and OK: Update Level = ' + (Uc-Get 'Update Level'))
    $cfg = Open-ByCmd $id 686 10; $combo = Ctl $cfg 6298; $box = Ctl $cfg 6255
    $sel = [P420]::SendR($combo, 0x0147, 0, 0, 3000)
    Click $box; Start-Sleep -Milliseconds 400
    $en = [Drv098f]::IsWindowEnabled($combo)
    T 'G2' 'disable' ($sel -eq 2 -and -not $en) ('reopened: selected {0}; after clearing the check box the list is enabled: {1}' -f $sel, $en)
    Click $box; Start-Sleep -Milliseconds 300
    Close-Win $cfg; [void](Gone $cfg 5)
    [void](Quit $id)

    # an automatic arm is dropped when the page lowers the level
    Reset-State 2; Set-Env; Cfg-General
    $id = Start-420; $h = Wait-Form $id 'automatic'; Press $h 2; [void](Gone $h 3)
    $cfg = Open-ByCmd $id 686 10; $combo = Ctl $cfg 6298
    [void][P420]::SendR($combo, 0x014E, 1, 0, 3000)
    $ok = Buttons $cfg | Where-Object { [Drv098f]::Txt($_) -eq 'OK' -and [Drv098f]::GetParent($_) -eq $cfg } | Select-Object -First 1
    Click $ok; [void](Gone $cfg 5); Start-Sleep -Milliseconds 500
    T 'G3' 'drop' ((Uc-Get 'Update Level') -eq 1 -and $null -eq (Arm)) ('level lowered on the page: Update Level {0}, {1}' -f (Uc-Get 'Update Level'), (ArmStr (Arm)))
    [void](Quit $id)
    T 'G3' 'exit' ((Runs).Count -eq 0) ('exit after lowering: ' + (RunsStr))
}

# Dbg: diagnostics (run only when named: -Only Dbg) - the windows of the program every half second
$Groups['Dbg'] = {
    Reset-State 2; Set-Env 'rel-tampered'
    $id = Start-420
    for ($i = 0; $i -lt 30; $i++) {
        $tops = @(Get-Tops $id | ForEach-Object { '{0:X} {1} vis={2} notice={3} kids={4} "{5}"' -f $_.ToInt64(), [Drv098f]::Cls($_), [Drv098f]::IsWindowVisible($_), ([P420]::Notice([uint32]$id) -eq $_), @([Drv098f]::Kids($_)).Count, (Esc ([Drv098f]::Txt($_))) })
        Out ('t={0,4:N1} {1}' -f ($i / 2), ($tops -join ' | '))
        Start-Sleep -Milliseconds 500
    }
    Out ('files: ' + (FilesStr) + '; ' + (ArmStr (Arm)) + '; requests: ' + ((Reqs '/*' | ForEach-Object { $_.path }) -join ' '))
    Kill-Wait $id
    Reset-State 2; Set-Env
    $id = Start-420; [void](Wait-Form $id 'automatic'); Kill-Wait $id
    Start-Sleep -Milliseconds 700
    $p = Join-Path $Upd $InstallerName; $b = [IO.File]::ReadAllBytes($p); $b[1000] = $b[1000] -bxor 1; [IO.File]::WriteAllBytes($p, $b)
    Out ('S3 before start: ' + (ArmStr (Arm)) + '; ' + (FilesStr) + '; processes: ' + ((Get-Process tandemcommander -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }) -join ','))
    NoCheck
    $id = Start-420
    for ($i = 0; $i -lt 12; $i++) { Out ('S3 t={0}: {1}; {2}; runs {3}' -f ($i / 2), (ArmStr (Arm)), (FilesStr), (Runs).Count); Start-Sleep -Milliseconds 500 }
    Kill-Wait $id
}

# ---- run ------------------------------------------------------------------------------------
if ((Test-Path -LiteralPath $Upd) -and @(Get-ChildItem -LiteralPath $Upd -Force).Count -gt 0) { Write-Host "NOT RUN: $Upd is not empty"; exit 98 }
$updParentExisted = Test-Path -LiteralPath (Split-Path $Upd)
$regFile = Join-Path $TempRoot 'tc420_backup.reg'
$existed = Backup-Reg $regFile
Out ('Feature 420 probe, {0}, exe {1}, registry backup {2}' -f (Get-Date -Format s), $Exe, $regFile)
$restoredOk = $false
try {
    [void][IO.Directory]::CreateDirectory($PanelDir)
    & reg.exe add ('HKCU\' + $ProbeKeyRel) /v InstallLocation /t REG_SZ /d ((Split-Path $Exe) + '\') /f | Out-Null
    Start-Server
    foreach ($g in $Groups.Keys) {
        if ($Only.Count -and -not ($Only | Where-Object { $g -like $_ })) { continue }
        if ($g -eq 'Dbg' -and -not ($Only -contains 'Dbg')) { continue }
        Out ('--- group ' + $g)
        try { & $Groups[$g] }
        catch { Row $g 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.InvocationInfo.ScriptLineNumber) }
        foreach ($i in @($Started)) { if (Test-Alive $i) { Kill-Mine $i } }
    }
}
finally {
    foreach ($i in @($Started)) { if (Test-Alive $i) { Kill-Mine $i } }
    Stop-Server
    & cmd.exe /c "reg delete HKCU\Software\TC420Probe /f >nul 2>&1"
    if (Test-Path -LiteralPath $Upd) { Remove-Item -LiteralPath $Upd -Recurse -Force }
    if (-not $updParentExisted -and (Test-Path -LiteralPath (Split-Path $Upd))) { Remove-Item -LiteralPath (Split-Path $Upd) -Recurse -Force }
    $restoredOk = Restore-Reg $regFile $existed
    foreach ($n in @('TC_UPDATECHECK_URL', 'TC_UPDATECHECK_PRETEND_VERSION', 'TC_UPDATE_PROBE_UNINSTALL', 'TC_UPDATE_PROBE_METERED', 'TC_UPDATE_PROBE_RUNLOG', 'TC_UPDATECHECK_OPENLOG')) { Remove-Item ('Env:\' + $n) -ErrorAction SilentlyContinue }
}
$pass = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
$fail = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
$nd = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
Out ('TOTAL: {0} PASS, {1} FAIL, {2} NOT DRIVEN; registry restored: {3}' -f $pass, $fail, $nd, $restoredOk)
$script:Lines | Set-Content -LiteralPath $Result -Encoding UTF8
exit $fail
