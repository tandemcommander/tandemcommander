<#
.SYNOPSIS
    Feature 421 (update notification: level choice, Download & Install, silent automatic install) -
    behaviour probe of a Debug build. Rows follow specs/421-update-notice-levels/spec.md,
    contracts/ui.md and quickstart.md section 2.
    Groups: D Download & Install, P a copy not installed by the installer, L the level choice,
    A the silent automatic install, R regression rows of 420. Every row prints PASS / FAIL / NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Backs up the product's registry key and
    restores it (verified by SHA-256); creates and removes the updates folder
    %LOCALAPPDATA%\Tandem Commander\Updates and a fake uninstall entry under
    HKCU\Software\TC421Probe. The installer is never started: the Debug seam
    TC_UPDATE_PROBE_RUNLOG records what would be started. Uses 420's fixture server.
.PARAMETER Exe   tandemcommander.exe of a Debug build with the feature
.PARAMETER Only  groups to run (default all), e.g. -Only D,A
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Only = @(),
    [string]$Result = ''
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not $Result) { $Result = Join-Path $PSScriptRoot 'notice421_result.txt' }
if ($Only.Count -eq 1 -and $Only[0] -match ',') { $Only = @($Only[0] -split ',') }
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Write-Host 'NOT RUN: a tandemcommander.exe is running (the registry key is shared with it)'; exit 99 }

if (-not ('P421' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class P421
{
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr GetPropW(IntPtr h, string name);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
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
    // any notification window of the process, also one that is not visible
    public static IntPtr AnyNotice(uint pid)
    {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid && GetPropW(h, "TandemCommander.UpdateNotice") != IntPtr.Zero) { found = h; return false; }
            return true; }, IntPtr.Zero);
        return found;
    }
}
'@
}

$Z = [IntPtr]::Zero
$Port = 8421
$Fx = $TempRoot + '\tc421'
$SrvLog = $Fx + '\requests.log'
$RunLog = $Fx + '\runlog.txt'
$OpenLog = $Fx + '\openlog.txt'
$SilentLog = $Fx + '\silentlog.txt'
$PanelDir = $Fx + '\panel'
$Upd = Join-Path $env:LOCALAPPDATA 'Tandem Commander\Updates'
$UcKey = 'HKCU\Software\Tandem Commander\Settings\Update Check'
$ProbeKeyRel = 'Software\TC421Probe\Uninstall'
$Srv420 = (Resolve-Path (Join-Path $PSScriptRoot '..\..\420-auto-update-install\probe\updserver420.py')).Path
$Good = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\setup\output\tandemcommander-0.2.0-x64-setup.exe')).Path
$Older = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\setup\output\tandemcommander-0.1.9-x64-setup.exe')).Path
$Foreign = 'C:\Program Files\Inno Setup 7\ISCC.exe'
$Unsigned = 'C:\Program Files\7-Zip\7z.exe'
$InstallerName = 'tandemcommander-0.2.0-x64-setup.exe'
$IdleBusy = '600000000' # the seam value that stands for "the user is working"

# control ids (src/lang/lang.rh)
$ID_OK = 1; $ID_CANCEL = 2; $ID_INSTALLEXIT = 6296; $ID_SKIP = 6250; $ID_ATSTARTUP = 6249; $ID_HINT = 6248
$ID_LEVELLABEL = 6299; $ID_LEVEL = 6300; $ID_DLI = 6301
$CM_HELP_ABOUT = 2216; $CM_HELP_CHECKVERSION = 2217

function T([string]$Case, [string]$Step, [bool]$Ok, [string]$Facts) { Row $Case $Step (V $Ok) $Facts }
function ND([string]$Case, [string]$Step, [string]$Facts) { Row $Case $Step 'NOT DRIVEN' $Facts }

# ---- fixture server (420's) ---------------------------------------------------------------
$script:Srv = $null
function Http-Get([string]$Path) {
    $wc = New-Object Net.WebClient; $wc.Proxy = $null
    try { [void]$wc.DownloadString("http://127.0.0.1:$Port$Path"); return $true } catch { return $false } finally { $wc.Dispose() }
}
function Start-Server {
    Remove-Item -LiteralPath $SrvLog -Force -ErrorAction SilentlyContinue
    $a = @(('"{0}"' -f $Srv420), '--port', $Port, '--log', ('"{0}"' -f $SrvLog),
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

# ---- registry and files ----------------------------------------------------------------------
function Uc-Set([string]$Name, $Value, [string]$Type = 'DWord') {
    $t = @{ DWord = 'REG_DWORD'; QWord = 'REG_QWORD'; String = 'REG_SZ' }[$Type]
    & reg.exe add $UcKey /v $Name /t $t /d $Value /f | Out-Null
}
function Uc-Get([string]$Name) {
    $p = Get-ItemProperty -LiteralPath ('Registry::' + $UcKey) -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $p) { return $null }; return $p.$Name
}
function Uc-Del([string]$Name) { & cmd.exe /c "reg delete `"$UcKey`" /v `"$Name`" /f >nul 2>&1" }
function Arm {
    $v = Uc-Get 'Install Version'
    if ($null -eq $v) { return $null }
    return [pscustomobject]@{ Version = $v; Source = (Uc-Get 'Install Source'); Test = (Uc-Get 'Install Test'); Launches = (Uc-Get 'Install Launches'); Confirmed = (Uc-Get 'Install Confirmed') }
}
function ArmStr($a) { if ($null -eq $a) { return 'no arm' }; return ('arm {0} source {1} test {2} launches {3} confirmed {4}' -f $a.Version, $a.Source, $a.Test, $a.Launches, $a.Confirmed) }
function UpdFiles { if (Test-Path -LiteralPath $Upd) { return , @(Get-ChildItem -LiteralPath $Upd -File | ForEach-Object { $_.Name }) }; return , @() }
function FilesStr { $f = UpdFiles; if ($f.Count) { return ($f -join ', ') }; return 'no files' }
function Runs { if (Test-Path -LiteralPath $RunLog) { return , @(Get-Content -LiteralPath $RunLog | Where-Object { $_ }) }; return , @() }
function RunsStr { $r = Runs; if (-not $r.Count) { return 'nothing started' }; return (($r | ForEach-Object { Esc $_ }) -join ' || ') }
function Reset-State([int]$Level = -1) {
    foreach ($n in @('Last Attempt', 'Last Attempt Answered', 'Last Success', 'Latest Version', 'Latest Published', 'Skipped Version', 'Update Level',
            'Install Version', 'Install Digest', 'Install Source', 'Install Test', 'Install Launches', 'Install Confirmed', 'Download Refused')) { Uc-Del $n }
    Uc-Set 'Check At Startup' 1
    if ($Level -ge 0) { Uc-Set 'Update Level' $Level }
    if (Test-Path -LiteralPath $Upd) { Remove-Item -LiteralPath $Upd -Recurse -Force }
    Remove-Item -LiteralPath $RunLog, $OpenLog, $SilentLog -Force -ErrorAction SilentlyContinue
}
function SilentStr { if (Test-Path -LiteralPath $SilentLog) { $l = @(Get-Content -LiteralPath $SilentLog | Where-Object { $_ }); if ($l.Count) { return ('{0} decisions, last: {1}' -f $l.Count, $l[-1]) } }; return 'no decision logged' }
function NoCheck { Uc-Set 'Last Attempt' ([DateTime]::UtcNow.ToFileTimeUtc()) 'QWord'; Uc-Set 'Last Attempt Answered' 1 }
$NowLike = 'now|"*\Tandem Commander\Updates\tandemcommander-0.2.0-x64-setup.exe" /SP- /SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /CURRENTUSER /LOG="*\setup-0.2.0.log"'
$ExitLike = 'exit|"*\Tandem Commander\Updates\tandemcommander-0.2.0-x64-setup.exe" /SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS /CURRENTUSER /LOG="*\setup-0.2.0.log"'

# ---- the program -----------------------------------------------------------------------------
function Set-Env([string]$Fixture = 'rel-good', [string]$Pretend = '0.1.9', [bool]$Eligible = $true, [bool]$Metered = $false,
    [string]$Idle = '0', [bool]$LaunchFail = $false) {
    $env:TC_UPDATECHECK_URL = "http://127.0.0.1:$Port/latest/$Fixture"
    if ($Pretend) { $env:TC_UPDATECHECK_PRETEND_VERSION = $Pretend } else { Remove-Item Env:\TC_UPDATECHECK_PRETEND_VERSION -ErrorAction SilentlyContinue }
    if ($Eligible) { $env:TC_UPDATE_PROBE_UNINSTALL = 'CURRENTUSER:' + $ProbeKeyRel } else { Remove-Item Env:\TC_UPDATE_PROBE_UNINSTALL -ErrorAction SilentlyContinue }
    if ($Metered) { $env:TC_UPDATE_PROBE_METERED = '1' } else { Remove-Item Env:\TC_UPDATE_PROBE_METERED -ErrorAction SilentlyContinue }
    if ($LaunchFail) { $env:TC_UPDATE_PROBE_LAUNCHFAIL = '1' } else { Remove-Item Env:\TC_UPDATE_PROBE_LAUNCHFAIL -ErrorAction SilentlyContinue }
    $env:TC_UPDATE_PROBE_IDLE_MS = $Idle
    $env:TC_UPDATE_PROBE_SILENTLOG = $SilentLog
    $env:TC_UPDATE_PROBE_RUNLOG = $RunLog
    $env:TC_UPDATECHECK_OPENLOG = $OpenLog
}
function Start-421([string[]]$Extra = @()) {
    $a = @('-t', 'T421', '-l', ('"{0}"' -f $PanelDir), '-r', ('"{0}"' -f $PanelDir)) + $Extra
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq $Z) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq $Z) { throw 'the program did not show its main window' }
    return $p.Id
}
function Quit([int]$Id) {
    if (-not (Test-Alive $Id)) { return 0 }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, $Z, $Z)
    while ($sw.Elapsed.TotalSeconds -lt 25 -and (Test-Alive $Id)) { Start-Sleep -Milliseconds 50 }
    if (Test-Alive $Id) { Kill-Mine $Id; return -1 }
    return [math]::Round($sw.Elapsed.TotalSeconds, 2)
}
function Wait-Notice([int]$Id, [double]$Seconds = 30) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) { $h = [P421]::Notice([uint32]$Id); if ($h -ne $Z) { Start-Sleep -Milliseconds 300; return [P421]::Notice([uint32]$Id) }; Start-Sleep -Milliseconds 150 }
    return $Z
}
function Wait-Form([int]$Id, [string]$Form, [double]$Seconds = 40) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) { $h = [P421]::Notice([uint32]$Id); if ($h -ne $Z -and (Form $h) -eq $Form) { return $h }; Start-Sleep -Milliseconds 200 }
    return [P421]::Notice([uint32]$Id)
}
function Ctl([IntPtr]$Dlg, [int]$CtlId) { foreach ($k in [Drv098f]::Kids($Dlg)) { if ([Drv098f]::GetDlgCtrlID($k) -eq $CtlId) { return $k } }; return $Z }
function CtlText([IntPtr]$Dlg, [int]$CtlId) { $c = Ctl $Dlg $CtlId; if ($c -eq $Z) { return '<none>' }; return [Drv098f]::Txt($c) }
function Vis([IntPtr]$Dlg, [int]$CtlId) { $c = Ctl $Dlg $CtlId; return ($c -ne $Z -and [Drv098f]::IsWindowVisible($c)) }
function Ena([IntPtr]$Dlg, [int]$CtlId) { $c = Ctl $Dlg $CtlId; return ($c -ne $Z -and [Drv098f]::IsWindowEnabled($c)) }
# classic / classic-dli (Download & Install shown) / offer / offer-noexit / none
function Form([IntPtr]$H) {
    if ($H -eq $Z) { return 'none' }
    $ok = CtlText $H $ID_OK
    if ($ok -eq '&Download') { if (Vis $H $ID_DLI) { return 'classic-dli' }; return 'classic' }
    if ($ok -eq 'Install &Now') { if (Vis $H $ID_INSTALLEXIT) { return 'offer' }; return 'offer-noexit' }
    return ('other(' + $ok + ')')
}
function DefId([IntPtr]$H) { $r = [P421]::SendR($H, 0x0400, 0, 0, 3000); if ($r -eq [long]::MinValue) { return -1 }; return [int]($r -band 0xFFFF) }
function LevelSel([IntPtr]$H) { $c = Ctl $H $ID_LEVEL; if ($c -eq $Z) { return -2 }; return [int][P421]::SendR($c, 0x0147, 0, 0, 3000) }
function LevelCount([IntPtr]$H) { $c = Ctl $H $ID_LEVEL; if ($c -eq $Z) { return -2 }; return [int][P421]::SendR($c, 0x0146, 0, 0, 3000) }
# chooses a level as the user does: the selection, then CBN_SELCHANGE to the dialog
function Choose-Level([IntPtr]$H, [int]$Level) {
    $c = Ctl $H $ID_LEVEL
    [void][P421]::SendR($c, 0x014E, $Level, 0, 3000)
    $w = ($ID_LEVEL -band 0xFFFF) -bor (1 -shl 16)
    [void][Drv098f]::PostMessageW($H, 0x0111, [IntPtr]$w, $c)
}
function Press([IntPtr]$Dlg, [int]$CtlId) { $c = Ctl $Dlg $CtlId; if ($c -ne $Z) { Click $c } }
function Gone([IntPtr]$H, [double]$Seconds = 5) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if (-not [Drv098f]::IsWindow($H)) { return $true }; Start-Sleep -Milliseconds 100 }; return $false }
function Wait-Run([int]$Count, [double]$Seconds = 15) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if ((Runs).Count -ge $Count) { return $true }; Start-Sleep -Milliseconds 150 }; return $false }
function Wait-Arm([double]$Seconds = 40) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { $a = Arm; if ($null -ne $a) { return $a }; Start-Sleep -Milliseconds 200 }; return $null }
# the visible message boxes of the process (#32770 that is not the notification)
function MsgBoxes([int]$Id) {
    $n = [P421]::AnyNotice([uint32]$Id)
    return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $_ -ne $n -and [Drv098f]::IsWindowVisible($_) })
}
function Wait-MsgBox([int]$Id, [double]$Seconds = 20) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { $m = MsgBoxes $Id; if ($m.Count) { return $m[0] }; Start-Sleep -Milliseconds 150 }; return $Z }
# watches for a notification window during 'Seconds'; TRUE when one ever appeared
function Notice-Seen([int]$Id, [double]$Seconds) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if ([P421]::AnyNotice([uint32]$Id) -ne $Z) { return $true }; Start-Sleep -Milliseconds 100 }; return $false }

$Groups = [ordered]@{}

# D: Download & Install (US1, FR-005 - FR-009, clarification 1)
$Groups['D'] = {
    Reset-State 0; Set-Env -Fixture 'rel-medium'
    $id = Start-421; $h = Wait-Notice $id 20; Start-Sleep -Seconds 1
    $hint = CtlText $h $ID_HINT
    T 'D1' 'form' ((Form $h) -eq 'classic-dli' -and (CtlText $h $ID_DLI) -eq 'Download && &Install' -and (DefId $h) -eq $ID_DLI -and (AssetReqs) -eq 0) ('level 0: form {0}, button "{1}", default id {2}, asset requests {3}' -f (Form $h), (Esc (CtlText $h $ID_DLI)), (DefId $h), (AssetReqs))
    T 'D1' 'hint' ($hint -like 'Download && Install downloads the installer*Download opens it in your web browser.') ('hint: ' + (Esc $hint))
    T 'D1' 'level' ((LevelSel $h) -eq 0 -and (LevelCount $h) -eq 3 -and (Ena $h $ID_LEVEL) -and (CtlText $h $ID_LEVELLABEL) -eq 'Wh&en a new version is found:') ('level choice: selected {0} of {1}, enabled {2}, label "{3}"' -f (LevelSel $h), (LevelCount $h), (Ena $h $ID_LEVEL), (CtlText $h $ID_LEVELLABEL))
    Press $h $ID_DLI
    $sw = [Diagnostics.Stopwatch]::StartNew(); $seenCancel = $false; $seenPct = ''; $pcts = New-Object System.Collections.Generic.List[int]
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Runs).Count -eq 0 -and [Drv098f]::IsWindow($h)) {
        if ((CtlText $h $ID_DLI) -eq 'Cancel Do&wnload') { $seenCancel = $true; $t = CtlText $h $ID_HINT; if ($t -match '\.\.\. (\d+) %$') { $seenPct = $t; $p = [int]$Matches[1]; if ($pcts.Count -eq 0 -or $pcts[$pcts.Count - 1] -ne $p) { $pcts.Add($p) } } }
        Start-Sleep -Milliseconds 100 }
    $mono = $true; for ($i = 1; $i -lt $pcts.Count; $i++) { if ($pcts[$i] -lt $pcts[$i - 1]) { $mono = $false } }
    T 'D2' 'progress' ($seenCancel -and $seenPct -like 'Downloading and checking the installer of version 0.2.0... * %' -and $pcts.Count -ge 3 -and $mono -and ($pcts | Measure-Object -Maximum).Maximum -ge 50) ('during the download: cancel button {0}, per cent seen {1}, last hint "{2}"' -f $seenCancel, ($pcts -join ','), (Esc $seenPct))
    $got = Wait-Run 1 30; $r = Runs; $a = Arm
    T 'D2' 'install' ($got -and $r.Count -eq 1 -and $r[0] -like $NowLike -and (Gone $h 5) -and $null -ne $a -and $a.Source -eq 1 -and $a.Launches -eq 1) ('after the download: {0}; notice gone {1}; {2}' -f (RunsStr), (-not [Drv098f]::IsWindow($h)), (ArmStr $a))
    T 'D2' 'level' ((Uc-Get 'Update Level') -eq 0) ('the stored level stays ' + (Uc-Get 'Update Level'))
    Kill-Mine $id

    # D3 cancel
    Reset-State 0; Set-Env -Fixture 'rel-slow'
    $id = Start-421; $h = Wait-Notice $id 20; Start-Sleep -Milliseconds 500
    Press $h $ID_DLI; Start-Sleep -Seconds 2
    $partSeen = (UpdFiles) -join ','
    Press $h $ID_DLI; Start-Sleep -Seconds 3
    T 'D3' 'cancel' ((Runs).Count -eq 0 -and (UpdFiles).Count -eq 0 -and (CtlText $h $ID_DLI) -eq 'Download && &Install' -and (CtlText $h $ID_HINT) -like 'Download && Install downloads*' -and $partSeen -like '*.part') ('files during the download "{0}", after cancel: {1}; {2}; button "{3}"' -f $partSeen, (FilesStr), (RunsStr), (Esc (CtlText $h $ID_DLI)))
    # D4 the window closed during the download
    Press $h $ID_DLI; Start-Sleep -Seconds 2
    Press $h $ID_CANCEL; $g = Gone $h 5; Start-Sleep -Seconds 3
    T 'D4' 'later' ($g -and (Runs).Count -eq 0 -and (UpdFiles).Count -eq 0) ('Remind Me Later during the download: gone {0}, {1}, {2}' -f $g, (FilesStr), (RunsStr))
    Kill-Mine $id

    # D5 a download that fails its check
    Reset-State 0; Set-Env -Fixture 'rel-tampered'
    $id = Start-421; $h = Wait-Notice $id 20; Start-Sleep -Milliseconds 500
    Press $h $ID_DLI
    $m = Wait-MsgBox $id 30; $mt = if ($m -ne $Z) { FullText $m } else { '' }
    T 'D5' 'message' ($m -ne $Z -and $mt -like '*could not be downloaded, or it did not pass the check*Use Download*') ('message: ' + (Esc $mt))
    if ($m -ne $Z) { Click-Ok $m }; Start-Sleep -Seconds 1
    T 'D5' 'state' ((Runs).Count -eq 0 -and (CtlText $h $ID_DLI) -eq 'Download && &Install' -and (UpdFiles).Count -eq 0) ('after it: {0}, button "{1}", {2}' -f (RunsStr), (Esc (CtlText $h $ID_DLI)), (FilesStr))
    Kill-Mine $id

    # D6 no checksum published: no Download & Install
    Reset-State 0; Set-Env -Fixture 'rel-nodigest'
    $id = Start-421; $h = Wait-Notice $id 20
    T 'D6' 'nodigest' ((Form $h) -eq 'classic' -and (DefId $h) -eq $ID_OK -and (CtlText $h $ID_HINT) -like 'The download opens in your web browser*') ('form {0}, default {1}, hint "{2}"' -f (Form $h), (DefId $h), (Esc (CtlText $h $ID_HINT)))
    Kill-Mine $id

    # D7 refused before: not offered; test mode ignores the refusal
    Reset-State 0; Uc-Set 'Download Refused' '0.2.0' 'String'; Set-Env
    $id = Start-421; $h = Wait-Notice $id 20
    T 'D7' 'refused' ((Form $h) -eq 'classic') ('refused 0.2.0: form ' + (Form $h))
    Kill-Mine $id
    Reset-State 0; Uc-Set 'Download Refused' '0.2.0' 'String'; Set-Env -Pretend ''
    $id = Start-421 @('--updatetest'); $h = Wait-Notice $id 20
    T 'D7' 'test' ((Form $h) -eq 'classic-dli') ('refused 0.2.0, --updatetest: form ' + (Form $h))
    Kill-Mine $id

    # D8 metered: the click still downloads
    Reset-State 0; Set-Env -Metered $true
    $id = Start-421; $h = Wait-Notice $id 20; $before = AssetReqs
    Press $h $ID_DLI; $got = Wait-Run 1 30
    T 'D8' 'metered' ($got -and (Runs)[0] -like $NowLike -and (AssetReqs) -gt $before) ('metered: {0}, asset requests {1}' -f (RunsStr), ((AssetReqs) - $before))
    Kill-Mine $id

    # D9 a verified installer is there already: no download (offer -> notify -> Download & Install)
    Reset-State 1; Set-Env
    $id = Start-421; $h = Wait-Form $id 'offer'
    Choose-Level $h 0
    $h2 = Wait-Form $id 'classic-dli' 10
    $before = AssetReqs
    T 'D9' 'notify' ((Form $h2) -eq 'classic-dli' -and (Uc-Get 'Update Level') -eq 0 -and (LevelSel $h2) -eq 0) ('offer, level 0 chosen: form {0}, stored {1}, selected {2}' -f (Form $h2), (Uc-Get 'Update Level'), (LevelSel $h2))
    Press $h2 $ID_DLI; $got = Wait-Run 1 10
    T 'D9' 'ready' ($got -and (Runs)[0] -like $NowLike -and (AssetReqs) -eq $before) ('Download & Install with the verified installer: {0}, new asset requests {1}' -f (RunsStr), ((AssetReqs) - $before))
    Kill-Mine $id

    # D10 Skip during the download
    Reset-State 0; Set-Env -Fixture 'rel-slow'
    $id = Start-421; $h = Wait-Notice $id 20; Start-Sleep -Milliseconds 500
    Press $h $ID_DLI; Start-Sleep -Seconds 2
    Press $h $ID_SKIP; $g = Gone $h 5; Start-Sleep -Seconds 3
    T 'D10' 'skip' ($g -and (Runs).Count -eq 0 -and (UpdFiles).Count -eq 0 -and (Uc-Get 'Skipped Version') -eq '0.2.0') ('Skip during the download: gone {0}, {1}, {2}, skipped {3}' -f $g, (FilesStr), (RunsStr), (Uc-Get 'Skipped Version'))
    Kill-Mine $id
}

# P: a copy not installed by the installer (US3, FR-010)
$Groups['P'] = {
    foreach ($lv in @(0, 1, 2)) {
        Reset-State $lv; Set-Env -Eligible $false; $before = AssetReqs
        $id = Start-421; $h = Wait-Notice $id 20; Start-Sleep -Seconds 1
        $hint = CtlText $h $ID_HINT
        T ('P' + $lv) 'portable' ((Form $h) -eq 'classic' -and -not (Ena $h $ID_LEVEL) -and (LevelSel $h) -eq $lv -and $hint -like 'This copy of Tandem Commander was not installed by the installer, so it cannot update itself.*' -and (AssetReqs) -eq $before) ('level {0}: form {1}, level choice enabled {2} selected {3}, asset requests {4}, hint "{5}"' -f $lv, (Form $h), (Ena $h $ID_LEVEL), (LevelSel $h), ((AssetReqs) - $before), (Esc $hint))
        Kill-Mine $id
    }
}

# L: the level choice (US2, FR-001 - FR-004)
$Groups['L'] = {
    # L1 classic -> offer: stored, downloaded, the offer form replaces it
    Reset-State 0; Set-Env
    $id = Start-421; $h = Wait-Notice $id 20
    Choose-Level $h 1
    $h2 = Wait-Form $id 'offer' 30
    T 'L1' 'flow' ((Form $h2) -eq 'offer' -and (Uc-Get 'Update Level') -eq 1 -and (UpdFiles) -contains $InstallerName -and (LevelSel $h2) -eq 1 -and $null -eq (Arm)) ('classic, level 1 chosen: form {0}, stored {1}, {2}, selected {3}, {4}' -f (Form $h2), (Uc-Get 'Update Level'), (FilesStr), (LevelSel $h2), (ArmStr (Arm)))
    # L2 offer -> automatic (the user is working): the window closes, the update is planned, nothing starts
    Kill-Mine $id
    Reset-State 1; Set-Env -Idle $IdleBusy
    $id = Start-421; $h = Wait-Form $id 'offer'
    Choose-Level $h 2; $g = Gone $h 5; Start-Sleep -Seconds 8; $a = Arm
    T 'L2' 'auto' ($g -and (Uc-Get 'Update Level') -eq 2 -and $null -ne $a -and $a.Source -eq 2 -and $a.Launches -eq 0 -and (Runs).Count -eq 0 -and [P421]::AnyNotice([uint32]$id) -eq $Z) ('offer, level 2 chosen, user busy: window gone {0}, stored {1}, {2}, {3}' -f $g, (Uc-Get 'Update Level'), (ArmStr $a), (RunsStr))
    $s = Quit $id; $r = Runs
    T 'L2' 'exit' ($r.Count -eq 1 -and $r[0] -like $ExitLike) ('normal exit after {0} s: {1}' -f $s, (RunsStr))
    # L3 classic -> automatic (idle): downloaded, the window closes, the silent install starts
    Reset-State 0; Set-Env -Idle '0'
    $id = Start-421; $h = Wait-Notice $id 20
    Choose-Level $h 2
    $got = Wait-Run 1 40; $r = Runs
    T 'L3' 'auto' ($got -and $r[0] -like $NowLike -and (Gone $h 3) -and (Uc-Get 'Update Level') -eq 2) ('classic, level 2 chosen: {0}; window gone {1}; stored {2}' -f (RunsStr), (-not [Drv098f]::IsWindow($h)), (Uc-Get 'Update Level'))
    Kill-Mine $id
    # L4 the check box disables / enables the level choice; the level is read from the store
    Reset-State 1; Set-Env
    $id = Start-421; $h = Wait-Form $id 'offer'
    $e1 = Ena $h $ID_LEVEL; Press $h $ID_ATSTARTUP; Start-Sleep -Milliseconds 600; $e2 = Ena $h $ID_LEVEL; $c2 = Uc-Get 'Check At Startup'
    Press $h $ID_ATSTARTUP; Start-Sleep -Milliseconds 600; $e3 = Ena $h $ID_LEVEL
    T 'L4' 'checkbox' ($e1 -and -not $e2 -and $c2 -eq 0 -and $e3) ('enabled {0} -> check off {1} (stored {2}) -> on {3}' -f $e1, $e2, $c2, $e3)
    # L5 offer -> offer: nothing changes
    Choose-Level $h 1; Start-Sleep -Seconds 1
    T 'L5' 'same' ([Drv098f]::IsWindow($h) -and (Form $h) -eq 'offer' -and (Uc-Get 'Update Level') -eq 1 -and $null -eq (Arm)) ('the same level: window {0}, form {1}, {2}' -f [Drv098f]::IsWindow($h), (Form $h), (ArmStr (Arm)))
    Kill-Mine $id
}

# A: the silent automatic install (US4, FR-011 - FR-013)
$Groups['A'] = {
    # A1 idle: no window at all, the installer starts
    Reset-State 2; Set-Env -Idle '0'
    $id = Start-421
    $sw = [Diagnostics.Stopwatch]::StartNew(); $seen = $false
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Runs).Count -eq 0) { if ([P421]::AnyNotice([uint32]$id) -ne $Z) { $seen = $true }; Start-Sleep -Milliseconds 100 }
    $r = Runs; $a = Arm
    T 'A1' 'silent' (-not $seen -and $r.Count -eq 1 -and $r[0] -like $NowLike -and $null -ne $a -and $a.Launches -eq 1) ('level 2, idle: notification seen {0}; {1}; {2}; {3}' -f $seen, (RunsStr), (ArmStr $a), (SilentStr))
    Start-Sleep -Seconds 7
    T 'A1' 'once' ((Runs).Count -eq 1) ('7 s later: ' + (RunsStr))
    Kill-Mine $id

    # A2 the user works: nothing starts, the exit installs it
    Reset-State 2; Set-Env -Idle $IdleBusy
    $id = Start-421; $a = Wait-Arm 30; $seen = Notice-Seen $id 10
    T 'A2' 'wait' ($null -ne $a -and $a.Source -eq 2 -and $a.Launches -eq 0 -and -not $seen -and (Runs).Count -eq 0) ('user busy: {0}, notification seen {1}, {2}; {3}' -f (ArmStr $a), $seen, (RunsStr), (SilentStr))
    $s = Quit $id; $r = Runs
    T 'A2' 'exit' ($r.Count -eq 1 -and $r[0] -like $ExitLike) ('normal exit after {0} s: {1}' -f $s, (RunsStr))

    # A3 a modal dialog open: nothing starts until it is closed
    Reset-State 2; Set-Env -Fixture 'rel-medium' -Idle '0'
    $id = Start-421; $main = Get-Main $id
    $known = Get-Tops $id; Post-Cmd $main $CM_HELP_ABOUT; $about = Wait-NewWin $id $known 10
    $a = Wait-Arm 30; Start-Sleep -Seconds 8
    $r1 = (Runs).Count
    T 'A3' 'busy' ($about -ne $Z -and $null -ne $a -and $r1 -eq 0) ('About open ({0}): {1}, runs {2}' -f ($about -ne $Z), (ArmStr $a), $r1)
    if ($about -ne $Z) { Close-Win $about }
    $got = Wait-Run 1 15
    T 'A3' 'after' ($got -and (Runs)[0] -like $NowLike) ('About closed: ' + (RunsStr))
    Kill-Mine $id

    # A4 another instance runs: nothing starts; when it ends, this one installs
    Reset-State 2; NoCheck; Set-Env -Idle '0'
    $other = Start-421
    # the start-up check is decided when the start-up is complete (after the main window appears): the
    # first instance must have decided "not due" before the stored attempt is removed for the second one
    Start-Sleep -Seconds 6
    Uc-Del 'Last Attempt'; Uc-Del 'Last Attempt Answered'
    $id = Start-421; $a = Wait-Arm 30; Start-Sleep -Seconds 8
    $r1 = (Runs).Count
    T 'A4' 'other' ($null -ne $a -and $r1 -eq 0) ('second instance running: {0}, runs {1}; {2}' -f (ArmStr $a), $r1, (SilentStr))
    $q = Quit $other
    $got = Wait-Run 1 15
    T 'A4' 'alone' ($got -and (Runs)[0] -like $NowLike) ('the other one closed ({0} s): {1}; {2}' -f $q, (RunsStr), (SilentStr))
    Kill-Mine $id

    # A5 the installer cannot be started: told once, not tried again in the session
    Reset-State 2; Set-Env -Idle '0' -LaunchFail $true
    $id = Start-421; $m = Wait-MsgBox $id 30; $mt = if ($m -ne $Z) { FullText $m } else { '' }
    T 'A5' 'message' ($m -ne $Z -and $mt -like '*could not be started*') ('message: ' + (Esc $mt))
    if ($m -ne $Z) { Click-Ok $m }
    $a = Arm; Start-Sleep -Seconds 12; $m2 = MsgBoxes $id
    T 'A5' 'once' ($m2.Count -eq 0 -and $null -ne $a -and $a.Source -eq 2 -and $a.Launches -eq 1 -and [P421]::AnyNotice([uint32]$id) -eq $Z) ('12 s later: message boxes {0}; {1}' -f $m2.Count, (ArmStr $a))
    Kill-Mine $id

    # A6 a skipped version: never installed on its own; a check the user asks for offers it
    Reset-State 2; Uc-Set 'Skipped Version' '0.2.0' 'String'; Set-Env -Idle '0'
    $id = Start-421; Start-Sleep -Seconds 8
    T 'A6' 'start' ((Runs).Count -eq 0 -and $null -eq (Arm) -and [P421]::AnyNotice([uint32]$id) -eq $Z) ('skipped 0.2.0 at start: {0}, {1}' -f (RunsStr), (ArmStr (Arm)))
    Post-Cmd (Get-Main $id) $CM_HELP_CHECKVERSION
    $h = Wait-Form $id 'offer' 30; Start-Sleep -Seconds 6
    T 'A6' 'asked' ((Form $h) -eq 'offer' -and (Runs).Count -eq 0) ('Help > Check for New Version: form {0}, {1}, {2}' -f (Form $h), (RunsStr), (ArmStr (Arm)))
    Kill-Mine $id

    # A7 a check the user asked for: no idle wait (the user is "working")
    Reset-State 2; NoCheck; Set-Env -Idle $IdleBusy
    $id = Start-421; Start-Sleep -Seconds 2
    Post-Cmd (Get-Main $id) $CM_HELP_CHECKVERSION
    $got = Wait-Run 1 30; Start-Sleep -Milliseconds 500
    T 'A7' 'asked' ($got -and (Runs)[0] -like $NowLike -and [P421]::Notice([uint32]$id) -eq $Z) ('Help > Check for New Version, user busy: {0}; notification left {1}' -f (RunsStr), ([P421]::Notice([uint32]$id) -ne $Z))
    Kill-Mine $id

    # A8 the plan's installer ran since it was planned: offered at the start, never silent
    Reset-State 2; Set-Env -Idle '0'
    $id = Start-421; [void](Wait-Run 1 30); Kill-Mine $id  # the silent install "ran" (run log) and did not install
    $a = Arm
    Uc-Set 'Install Source' 2; Uc-Set 'Install Confirmed' 0 # as the failed launch restores it: automatic, 1 launch, unconfirmed
    Remove-Item -LiteralPath $RunLog -Force -ErrorAction SilentlyContinue
    NoCheck
    $id = Start-421; $h = Wait-Form $id 'offer' 20; Start-Sleep -Seconds 6
    T 'A8' 'offer' ((Form $h) -eq 'offer' -and (Runs).Count -eq 0) ('plan {0} -> start: form {1}, {2}' -f (ArmStr $a), (Form $h), (RunsStr))
    Kill-Mine $id
}

# R: regression rows of 420 that still apply
$Groups['R'] = {
    Reset-State 1; Set-Env
    $id = Start-421; $h = Wait-Form $id 'offer'
    T 'R1' 'offer' ((Form $h) -eq 'offer' -and (DefId $h) -eq $ID_OK -and -not (Vis $h $ID_DLI) -and (CtlText $h $ID_HINT) -like 'The new version has been downloaded and verified. Install Now*') ('form {0}, default {1}, Download & Install visible {2}' -f (Form $h), (DefId $h), (Vis $h $ID_DLI))
    Press $h $ID_INSTALLEXIT; $g = Gone $h 5; $a = Arm
    T 'R1' 'when-close' ($g -and $null -ne $a -and $a.Source -eq 1) ('Install When I Close: gone {0}, {1}' -f $g, (ArmStr $a))
    $s = Quit $id; $r = Runs
    T 'R1' 'exit' ($r.Count -eq 1 -and $r[0] -like $ExitLike) ('exit after {0} s: {1}' -f $s, (RunsStr))
    Reset-State 1; Set-Env
    $id = Start-421; $h = Wait-Form $id 'offer'
    Press $h $ID_OK; $got = Wait-Run 1 10
    T 'R2' 'now' ($got -and (Runs)[0] -like $NowLike -and (Gone $h 5)) ('Install Now: ' + (RunsStr))
    Kill-Mine $id
    Reset-State 0; Set-Env
    $id = Start-421; $h = Wait-Notice $id 20
    Press $h $ID_OK; Start-Sleep -Seconds 2
    $ol = if (Test-Path -LiteralPath $OpenLog) { (Get-Content -LiteralPath $OpenLog) -join ' ' } else { '' }
    T 'R3' 'browser' ($ol -like '*releases/download/v0.2.0/tandemcommander-0.2.0-x64-setup.exe*' -and (Runs).Count -eq 0) ('Download (browser): opened "{0}", {1}' -f (Esc $ol), (RunsStr))
    Kill-Mine $id
}

# ---- run --------------------------------------------------------------------------------------
if ((Test-Path -LiteralPath $Upd) -and @(Get-ChildItem -LiteralPath $Upd -Force).Count -gt 0) { Write-Host "NOT RUN: $Upd is not empty"; exit 98 }
$updParentExisted = Test-Path -LiteralPath (Split-Path $Upd)
$regFile = Join-Path $TempRoot 'tc421_backup.reg'
$existed = Backup-Reg $regFile
Out ('Feature 421 probe, {0}, exe {1}, registry backup {2}' -f (Get-Date -Format s), $Exe, $regFile)
$restoredOk = $false
try {
    [void][IO.Directory]::CreateDirectory($PanelDir)
    & reg.exe add ('HKCU\' + $ProbeKeyRel) /v InstallLocation /t REG_SZ /d ((Split-Path $Exe) + '\') /f | Out-Null
    Start-Server
    foreach ($g in $Groups.Keys) {
        if ($Only.Count -and -not ($Only | Where-Object { $g -like $_ })) { continue }
        Out ('--- group ' + $g)
        try { & $Groups[$g] }
        catch { Row $g 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.InvocationInfo.ScriptLineNumber) }
        foreach ($i in @($Started)) { if (Test-Alive $i) { Kill-Mine $i } }
        Start-Sleep -Milliseconds 500
    }
}
finally {
    foreach ($i in @($Started)) { if (Test-Alive $i) { Kill-Mine $i } }
    Stop-Server
    & cmd.exe /c "reg delete HKCU\Software\TC421Probe /f >nul 2>&1"
    if (Test-Path -LiteralPath $Upd) { Remove-Item -LiteralPath $Upd -Recurse -Force }
    if (-not $updParentExisted -and (Test-Path -LiteralPath (Split-Path $Upd))) { Remove-Item -LiteralPath (Split-Path $Upd) -Recurse -Force }
    $restoredOk = Restore-Reg $regFile $existed
    foreach ($n in @('TC_UPDATECHECK_URL', 'TC_UPDATECHECK_PRETEND_VERSION', 'TC_UPDATE_PROBE_UNINSTALL', 'TC_UPDATE_PROBE_METERED', 'TC_UPDATE_PROBE_RUNLOG', 'TC_UPDATECHECK_OPENLOG', 'TC_UPDATE_PROBE_LAUNCHFAIL', 'TC_UPDATE_PROBE_IDLE_MS')) { Remove-Item ('Env:\' + $n) -ErrorAction SilentlyContinue }
}
$pass = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
$fail = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
$nd = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
Out ('TOTAL: {0} PASS, {1} FAIL, {2} NOT DRIVEN; registry restored: {3}' -f $pass, $fail, $nd, $restoredOk)
$script:Lines | Set-Content -LiteralPath $Result -Encoding UTF8
exit $fail
