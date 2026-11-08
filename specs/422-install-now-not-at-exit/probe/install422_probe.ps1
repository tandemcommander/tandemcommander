<#
.SYNOPSIS
    Feature 422 (updates install right away with a restart, never at exit) - behaviour probe of a
    Debug build, derived from 421's probe (specs/421-update-notice-levels/probe/notice421_probe.ps1).
    Rows follow specs/422-install-now-not-at-exit/spec.md.
    Groups: D Download & Install (421), P a copy not installed by the installer (421), L the level
    choice, A the automatic install right away and the checks the user starts, T the maintainer's
    lock-out trap, F what the user would lose holds it, R regression, X no install at any exit.
    Every row prints PASS / FAIL / NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Backs up the product's registry key and
    restores it (verified by SHA-256); creates and removes the updates folder
    %LOCALAPPDATA%\Tandem Commander\Updates and a fake uninstall entry under
    HKCU\Software\TC422Probe. The installer is never started: the Debug seam
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
if (-not $Result) { $Result = Join-Path $PSScriptRoot 'install422_result.txt' }
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
$Port = 8422
$Fx = $TempRoot + '\tc422'
$SrvLog = $Fx + '\requests.log'
$RunLog = $Fx + '\runlog.txt'
$OpenLog = $Fx + '\openlog.txt'
$SilentLog = $Fx + '\silentlog.txt'
$PanelDir = $Fx + '\panel'
$Upd = Join-Path $env:LOCALAPPDATA 'Tandem Commander\Updates'
$UcKey = 'HKCU\Software\Tandem Commander\Settings\Update Check'
$ProbeKeyRel = 'Software\TC422Probe\Uninstall'
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
function Start-421([string[]]$Extra = @(), [string]$Right = '') {
    if (-not $Right) { $Right = $PanelDir }
    $a = @('-t', 'T421', '-l', ('"{0}"' -f $PanelDir), '-r', ('"{0}"' -f $Right)) + $Extra
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
    if ($ok -eq 'Install &Now') { return 'offer' } # feature 422: no Install When I Close any more
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

# every Quit of this probe checks the exit: feature 422 - the exit never starts an installer (FR-003)
$script:ExitRuns = 0
function QuitChecked([int]$Id) {
    $before = @(Runs).Count
    $s = Quit $Id
    $new = @(Runs | Select-Object -Skip $before)
    if (@($new | Where-Object { $_ -like 'exit|*' }).Count -gt 0) { $script:ExitRuns++ }
    return [pscustomobject]@{ Seconds = $s; NewRuns = $new.Count }
}
# the program killed - what an installer's close does when the user then cancels the installer
function KillAsInstaller([int]$Id) { Kill-Mine $Id; if ($script:Procs.ContainsKey($Id)) { try { [void]$script:Procs[$Id].WaitForExit(10000) } catch { } } }
# a new start whose start-up check is due (Last Attempt removed) or not (NoCheck)
function Restart-421([bool]$CheckDue) {
    if ($CheckDue) { Uc-Del 'Last Attempt'; Uc-Del 'Last Attempt Answered' } else { NoCheck }
    return (Start-421)
}

# L: the level choice in the notification (421 US2; 422 FR-009: a choice in the window never installs)
$Groups['L'] = {
    # L1 classic -> offer: stored, downloaded, the offer form replaces it
    Reset-State 0; Set-Env
    $id = Start-421; $h = Wait-Notice $id 20
    Choose-Level $h 1
    $h2 = Wait-Form $id 'offer' 30
    T 'L1' 'flow' ((Form $h2) -eq 'offer' -and (Uc-Get 'Update Level') -eq 1 -and (UpdFiles) -contains $InstallerName -and (LevelSel $h2) -eq 1 -and $null -eq (Arm)) ('classic, level 1 chosen: form {0}, stored {1}, {2}, selected {3}, {4}' -f (Form $h2), (Uc-Get 'Update Level'), (FilesStr), (LevelSel $h2), (ArmStr (Arm)))
    Kill-Mine $id
    # L2 offer -> automatic: stored; the offer stays (the user decides here), nothing starts, nothing at exit
    Reset-State 1; Set-Env
    $id = Start-421; $h = Wait-Form $id 'offer'
    Choose-Level $h 2; Start-Sleep -Seconds 6
    T 'L2' 'auto' ([Drv098f]::IsWindow($h) -and (Form $h) -eq 'offer' -and (Uc-Get 'Update Level') -eq 2 -and $null -eq (Arm) -and (Runs).Count -eq 0) ('offer, level 2 chosen: window {0}, form {1}, stored {2}, {3}, {4}' -f [Drv098f]::IsWindow($h), (Form $h), (Uc-Get 'Update Level'), (ArmStr (Arm)), (RunsStr))
    $q = QuitChecked $id
    T 'L2' 'exit' ($q.NewRuns -eq 0) ('normal exit after {0} s: {1}' -f $q.Seconds, (RunsStr))
    # L3 classic -> automatic: downloaded, then the OFFER replaces the window (a choice in the window)
    Reset-State 0; Set-Env
    $id = Start-421; $h = Wait-Notice $id 20
    Choose-Level $h 2
    $h2 = Wait-Form $id 'offer' 30; Start-Sleep -Seconds 6
    T 'L3' 'auto' ((Form $h2) -eq 'offer' -and (Runs).Count -eq 0 -and (Uc-Get 'Update Level') -eq 2) ('classic, level 2 chosen: form {0}, {1}, stored {2}' -f (Form $h2), (RunsStr), (Uc-Get 'Update Level'))
    Kill-Mine $id
    # L4 the check box disables / enables the level choice
    Reset-State 1; Set-Env
    $id = Start-421; $h = Wait-Form $id 'offer'
    $e1 = Ena $h $ID_LEVEL; Press $h $ID_ATSTARTUP; Start-Sleep -Milliseconds 600; $e2 = Ena $h $ID_LEVEL; $c2 = Uc-Get 'Check At Startup'
    Press $h $ID_ATSTARTUP; Start-Sleep -Milliseconds 600; $e3 = Ena $h $ID_LEVEL
    T 'L4' 'checkbox' ($e1 -and -not $e2 -and $c2 -eq 0 -and $e3) ('enabled {0} -> check off {1} (stored {2}) -> on {3}' -f $e1, $e2, $c2, $e3)
    # L5 the offer form: Install Now, Remind Me Later, Skip - no Install When I Close (FR-004)
    $ie = Ctl $h 6296
    T 'L5' 'buttons' ((Form $h) -eq 'offer' -and $ie -eq $Z -and (Vis $h $ID_CANCEL) -and (Vis $h $ID_SKIP) -and (DefId $h) -eq $ID_OK) ('form {0}, a control 6296 {1}, default {2}' -f (Form $h), ($ie -ne $Z), (DefId $h))
    Kill-Mine $id
    # L6 the level lowered on the General page while the silent install waits (a modal dialog holds it): offered
    Reset-State 2; Set-Env -Fixture 'rel-medium'
    $id = Start-421; $main = Get-Main $id
    $known = Get-Tops $id; Post-Cmd $main $CM_HELP_ABOUT; $about = Wait-NewWin $id $known 10
    $a = Wait-Arm 30; Start-Sleep -Seconds 2
    Uc-Set 'Update Level' 1
    foreach ($n in @('Install Version', 'Install Digest', 'Install Source', 'Install Test', 'Install Launches', 'Install Confirmed')) { Uc-Del $n }
    if ($about -ne $Z) { Close-Win $about }
    $h = Wait-Form $id 'offer' 20
    T 'L6' 'lowered' ($about -ne $Z -and $null -ne $a -and $a.Source -eq 2 -and (Form $h) -eq 'offer' -and (Runs).Count -eq 0) ('planned {0}; level 1 stored meanwhile: form {1}, {2}; {3}' -f (ArmStr $a), (Form $h), (RunsStr), (SilentStr))
    Kill-Mine $id
    # L7 steps through the closed list do not act one by one
    Reset-State 1; Set-Env
    $id = Start-421; $h = Wait-Form $id 'offer'
    Choose-Level $h 0; Start-Sleep -Milliseconds 300; Choose-Level $h 1; Start-Sleep -Seconds 3
    T 'L7' 'steps' ([Drv098f]::IsWindow($h) -and (Form $h) -like 'offer*' -and (Uc-Get 'Update Level') -eq 1) ('0 then 1 within 0.3 s: window {0}, form {1}, stored {2}' -f [Drv098f]::IsWindow($h), (Form $h), (Uc-Get 'Update Level'))
    Choose-Level $h 0; Start-Sleep -Milliseconds 400; $early = (Uc-Get 'Update Level')
    $h2 = Wait-Form $id 'classic-dli' 10
    T 'L7' 'settle' ($early -eq 1 -and (Form $h2) -eq 'classic-dli' -and (Uc-Get 'Update Level') -eq 0) ('one step to 0: stored after 0.4 s {0}, then form {1}, stored {2}' -f $early, (Form $h2), (Uc-Get 'Update Level'))
    Kill-Mine $id
}

# A: the automatic install right away (422 US1, FR-001/002) and the checks the user starts (FR-009)
$Groups['A'] = {
    # A1 right away after the background check, whatever the user does (no idle wait): no window
    Reset-State 2; Set-Env
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $id = Start-421
    $seen = $false
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Runs).Count -eq 0) { if ([P421]::AnyNotice([uint32]$id) -ne $Z) { $seen = $true }; Start-Sleep -Milliseconds 100 }
    $t = [math]::Round($sw.Elapsed.TotalSeconds, 1); $r = Runs; $a = Arm
    T 'A1' 'right-away' (-not $seen -and $r.Count -eq 1 -and $r[0] -like $NowLike -and $t -le 15 -and $null -ne $a -and $a.Launches -eq 1) ('level 2: installer started {0} s after the start, notification seen {1}; {2}; {3}; {4}' -f $t, $seen, (RunsStr), (ArmStr $a), (SilentStr))
    Start-Sleep -Seconds 7
    T 'A1' 'once' ((Runs).Count -eq 1) ('7 s later: ' + (RunsStr))
    Kill-Mine $id

    # A2 something to lose (typed command-line text) and the program closed first: NOT at the exit; the
    # next start installs it (start-up completion, FR-006)
    Reset-State 2; Set-Env -Fixture 'rel-medium'
    $id = Start-421; $main = Get-Main $id
    $edits = @([Drv098f]::Kids($main) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::Cls([Drv098f]::GetParent($_)) -eq 'ComboBox' })
    if ($edits.Count -ge 1) { [void][Drv098f]::SetText($edits[0], 'echo probe422', 5000) }
    $a = Wait-Arm 30; Start-Sleep -Seconds 6
    T 'A2' 'wait' ($edits.Count -ge 1 -and $null -ne $a -and $a.Source -eq 2 -and $a.Launches -eq 0 -and (Runs).Count -eq 0) ('command line text: {0}, {1}; {2}' -f (ArmStr $a), (RunsStr), (SilentStr))
    $q = QuitChecked $id
    T 'A2' 'exit' ($q.NewRuns -eq 0) ('normal exit while it waits ({0} s): {1}; {2}' -f $q.Seconds, (RunsStr), (ArmStr (Arm)))
    $a0 = Arm
    $id = Restart-421 $false; $got = Wait-Run 1 20
    T 'A2' 'next-start' ($null -ne $a0 -and $a0.Launches -eq 0 -and $got -and (Runs)[0] -like $NowLike) ('plan {0} -> next start: {1}' -f (ArmStr $a0), (RunsStr))
    Kill-Mine $id

    # A3 a modal dialog open: nothing starts until it is closed
    Reset-State 2; Set-Env -Fixture 'rel-medium'
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
    Reset-State 2; NoCheck; Set-Env
    $other = Start-421
    Start-Sleep -Seconds 6
    Uc-Del 'Last Attempt'; Uc-Del 'Last Attempt Answered'
    $id = Start-421; $a = Wait-Arm 30; Start-Sleep -Seconds 8
    $r1 = (Runs).Count
    T 'A4' 'other' ($null -ne $a -and $r1 -eq 0) ('second instance running: {0}, runs {1}; {2}' -f (ArmStr $a), $r1, (SilentStr))
    $q = QuitChecked $other
    $got = Wait-Run 1 15
    T 'A4' 'alone' ($q.NewRuns -eq 0 -and $got -and (Runs)[0] -like $NowLike) ('the other one closed (no run at its exit: {0}): {1}' -f ($q.NewRuns -eq 0), (RunsStr))
    Kill-Mine $id

    # A5 the installer cannot be started: told once, not tried again in the session
    Reset-State 2; Set-Env -LaunchFail $true
    $id = Start-421; $m = Wait-MsgBox $id 30; $mt = if ($m -ne $Z) { FullText $m } else { '' }
    T 'A5' 'message' ($m -ne $Z -and $mt -like '*could not be started*') ('message: ' + (Esc $mt))
    if ($m -ne $Z) { Click-Ok $m }
    $a = Arm; Start-Sleep -Seconds 12; $m2 = MsgBoxes $id
    T 'A5' 'once' ($m2.Count -eq 0 -and $null -ne $a -and $a.Launches -eq 1) ('12 s later: message boxes {0}; {1}' -f $m2.Count, (ArmStr $a))
    Kill-Mine $id

    # A6 a skipped version: never installed on its own; a check the user asks for offers it
    Reset-State 2; Uc-Set 'Skipped Version' '0.2.0' 'String'; Set-Env
    $id = Start-421; Start-Sleep -Seconds 8
    T 'A6' 'start' ((Runs).Count -eq 0 -and $null -eq (Arm) -and [P421]::AnyNotice([uint32]$id) -eq $Z) ('skipped 0.2.0 at start: {0}, {1}' -f (RunsStr), (ArmStr (Arm)))
    Post-Cmd (Get-Main $id) $CM_HELP_CHECKVERSION
    $h = Wait-Form $id 'offer' 30; Start-Sleep -Seconds 6
    T 'A6' 'asked' ((Form $h) -eq 'offer' -and (Runs).Count -eq 0) ('Help > Check for New Version: form {0}, {1}, {2}' -f (Form $h), (RunsStr), (ArmStr (Arm)))
    Kill-Mine $id

    # A7 (FR-009) Help > Check for New Version at the automatic level: the notification, never an install
    Reset-State 2; NoCheck; Set-Env
    $id = Start-421; Start-Sleep -Seconds 2
    Post-Cmd (Get-Main $id) $CM_HELP_CHECKVERSION
    $h = Wait-Form $id 'offer' 30; Start-Sleep -Seconds 8
    T 'A7' 'help-check' ((Form $h) -eq 'offer' -and (Runs).Count -eq 0 -and $null -eq (Arm)) ('level 2, Help > Check: form {0}, {1}, {2}; {3}' -f (Form $h), (RunsStr), (ArmStr (Arm)), (SilentStr))
    Press $h $ID_OK; $got = Wait-Run 1 10
    T 'A7' 'install-now' ($got -and (Runs)[0] -like $NowLike) ('Install Now in it: ' + (RunsStr))
    Kill-Mine $id

    # A8 (FR-009) a silent install already waiting (a modal dialog holds it) and the user asks for the check: offered
    Reset-State 2; Set-Env -Fixture 'rel-medium'
    $id = Start-421; $main = Get-Main $id
    $known = Get-Tops $id; Post-Cmd $main $CM_HELP_ABOUT; $about = Wait-NewWin $id $known 10
    $a = Wait-Arm 30; Start-Sleep -Seconds 2
    if ($about -ne $Z) { Post-Cmd $about $CM_HELP_CHECKVERSION; Start-Sleep -Seconds 3; Close-Win $about } # the About box's "Check now"
    $h = Wait-Form $id 'offer' 20; Start-Sleep -Seconds 8
    T 'A8' 'about-check' ($about -ne $Z -and $null -ne $a -and (Form $h) -eq 'offer' -and (Runs).Count -eq 0) ('waiting {0}; About > Check now, About closed: form {1}, {2}; {3}' -f (ArmStr $a), (Form $h), (RunsStr), (SilentStr))
    Kill-Mine $id

    # A9 the installer ended without installing while the program runs: OK only (no "install it when you
    # close?"), the plan is only offered, the offer comes back; the next start with a check offers it
    Reset-State 2; Set-Env
    $id = Start-421; $got = Wait-Run 1 30
    [void][Drv098f]::PostMessageW((Get-Main $id), (0x8000 + 424), [IntPtr]1223, $Z) # WM_USER_UPDATEINSTALL_DONE [exit code]
    $m = Wait-MsgBox $id 10; $mt = if ($m -ne $Z) { FullText $m } else { '' }
    $yesNo = ($mt -like '*id=6]*' -or $mt -like '*id=7]*')
    if ($m -ne $Z) { Click-Ok $m }
    $h = Wait-Form $id 'offer' 10; $a = Arm
    T 'A9' 'failed' ($got -and $m -ne $Z -and -not $yesNo -and $mt -notlike '*when you close*' -and $null -ne $a -and $a.Source -eq 3 -and $a.Launches -eq 1 -and (Form $h) -eq 'offer') ('installer ended (1223): "{0}" -> {1}, form {2}' -f (Tail $mt 90), (ArmStr $a), (Form $h))
    $q = QuitChecked $id
    T 'A9' 'exit' ($q.NewRuns -eq 0) ('exit: ' + (RunsStr))
    Remove-Item -LiteralPath $RunLog -Force -ErrorAction SilentlyContinue
    $id = Restart-421 $true; $h = Wait-Form $id 'offer' 30; Start-Sleep -Seconds 8
    T 'A9' 'next' ((Form $h) -eq 'offer' -and (Runs).Count -eq 0 -and (Arm).Source -eq 3) ('the next start with a check: form {0}, {1}, {2}' -f (Form $h), (RunsStr), (ArmStr (Arm)))
    Kill-Mine $id

    # A10 (421 review 2 S-A) a check the user asked for: Download & Install, then Cancel Download - "not now"
    Reset-State 2; NoCheck; Set-Env -Fixture 'rel-medium'
    $id = Start-421; Start-Sleep -Seconds 2
    Post-Cmd (Get-Main $id) $CM_HELP_CHECKVERSION
    $h = Wait-Notice $id 30; $f0 = Form $h
    Press $h $ID_DLI; Start-Sleep -Milliseconds 400; $b1 = CtlText $h $ID_DLI
    Press $h $ID_DLI; Start-Sleep -Milliseconds 400; $b2 = CtlText $h $ID_DLI
    $got = Wait-Run 1 20; $h2 = [P421]::Notice([uint32]$id)
    T 'A10' 'cancel' (-not $got -and $f0 -eq 'classic-dli' -and $b1 -eq 'Cancel Do&wnload' -and $b2 -eq 'Download && &Install' -and (Form $h2) -eq 'offer') ('form {0}, "{1}", "{2}"; 20 s later: {3}, form {4}' -f $f0, (Esc $b1), (Esc $b2), (RunsStr), (Form $h2))
    Kill-Mine $id
}

# T: the maintainer's lock-out trap (422 US4, FR-007) - an install started on its own, the installer closed
# the program, the user cancelled it and starts the program again: nothing starts on its own, ever
$Groups['T'] = {
    # T1 the automatic install right away after the background check
    Reset-State 2; Set-Env
    $id = Start-421; $got = Wait-Run 1 30
    KillAsInstaller $id
    $a0 = Arm
    Remove-Item -LiteralPath $RunLog -Force -ErrorAction SilentlyContinue
    $rows = @()
    foreach ($due in @($true, $false, $true)) {
        $id = Restart-421 $due; $h = Wait-Form $id 'offer' 25; Start-Sleep -Seconds 6
        $rows += ('{0}: form {1}, runs {2}' -f $(if ($due) { 'check' } else { 'no check' }), (Form $h), (Runs).Count)
        $ok = (Runs).Count -eq 0
        KillAsInstaller $id
        if (-not $ok) { break }
    }
    T 'T1' 'silent' ($got -and $null -ne $a0 -and $a0.Launches -eq 1 -and (Runs).Count -eq 0 -and @($rows | Where-Object { $_ -like '*runs 0' }).Count -eq 3 -and @($rows | Where-Object { $_ -like 'check: form offer, runs 0' }).Count -eq 2) ('launched, killed as by the installer ({0}); three starts: {1}; {2}' -f (ArmStr $a0), ($rows -join ' | '), (ArmStr (Arm)))
    # T2 the start-up completion: a plan never launched (closed while held), the next start installs it,
    # the installer closes the program and is cancelled - the following starts never start it again
    Reset-State 2; Set-Env -Fixture 'rel-medium'
    $id = Start-421; $main = Get-Main $id
    $known = Get-Tops $id; Post-Cmd $main $CM_HELP_ABOUT; $about = Wait-NewWin $id $known 10
    $a = Wait-Arm 30; Start-Sleep -Seconds 2
    KillAsInstaller $id
    Remove-Item -LiteralPath $RunLog -Force -ErrorAction SilentlyContinue
    $id = Restart-421 $false; $got = Wait-Run 1 20
    $first = RunsStr
    KillAsInstaller $id
    $a1 = Arm
    Remove-Item -LiteralPath $RunLog -Force -ErrorAction SilentlyContinue
    $rows = @()
    foreach ($due in @($false, $true, $false)) {
        $id = Restart-421 $due; $h = Wait-Form $id 'offer' 25; Start-Sleep -Seconds 6
        $rows += ('{0}: form {1}, runs {2}' -f $(if ($due) { 'check' } else { 'no check' }), (Form $h), (Runs).Count)
        $ok = (Runs).Count -eq 0
        KillAsInstaller $id
        if (-not $ok) { break }
    }
    T 'T2' 'completion' ($null -ne $a -and $got -and $first -like 'now|*' -and $a1.Launches -eq 1 -and (Runs).Count -eq 0 -and @($rows | Where-Object { $_ -like '*runs 0' }).Count -eq 3) ('plan {0}; the start completed it: {1}; killed ({2}); three starts: {3}' -f (ArmStr $a), (Esc $first), (ArmStr $a1), ($rows -join ' | '))
    # T3 negative control: the same plan made never-launched again (the count reset by hand) IS completed -
    # the protection is the launch count, not chance
    Uc-Set 'Install Launches' 0; Uc-Set 'Install Confirmed' 0; Uc-Set 'Install Source' 2
    Remove-Item -LiteralPath $RunLog -Force -ErrorAction SilentlyContinue
    $id = Restart-421 $false; $got = Wait-Run 1 20
    T 'T3' 'control' ($got -and (Runs)[0] -like $NowLike) ('count reset to 0: ' + (RunsStr))
    Kill-Mine $id
    # T4 (review M1, the reviewer's row Z1) a click on nothing planned: level 2, Help > Check, Install Now,
    # the installer ends without installing while the program runs (declined UAC) - the next start with a
    # check must not start it on its own
    Reset-State 2; NoCheck; Set-Env
    $id = Start-421; Start-Sleep -Seconds 2
    Post-Cmd (Get-Main $id) $CM_HELP_CHECKVERSION
    $h = Wait-Form $id 'offer' 30
    Press $h $ID_OK; $got = Wait-Run 1 10
    [void][Drv098f]::PostMessageW((Get-Main $id), (0x8000 + 424), [IntPtr]1223, $Z)
    $m = Wait-MsgBox $id 10; if ($m -ne $Z) { Click-Ok $m }
    Start-Sleep -Seconds 1; $a = Arm
    $q = QuitChecked $id
    Remove-Item -LiteralPath $RunLog -Force -ErrorAction SilentlyContinue
    $id = Restart-421 $true; $h2 = Wait-Form $id 'offer' 25; Start-Sleep -Seconds 6
    T 'T4' 'click' ($got -and $m -ne $Z -and $null -ne $a -and $a.Source -eq 3 -and $a.Launches -eq 1 -and $q.NewRuns -eq 0 -and (Runs).Count -eq 0 -and (Form $h2) -eq 'offer') ('Install Now failed while running: {0}; next start with a check: form {1}, {2}' -f (ArmStr $a), (Form $h2), (RunsStr))
    Kill-Mine $id
}

# F: something the user would lose holds the automatic install - typed command-line text, then a file
# operation waiting on its question; when both are gone it starts
$Groups['F'] = {
    Reset-State 2; Set-Env -Fixture 'rel-medium'
    $right = $Fx + '\right'
    [void][IO.Directory]::CreateDirectory($right)
    # the file in both panels: copied from whichever is active, the target exists in the other
    Set-Content -LiteralPath ($right + '\a422.txt') -Value 'kept' -Encoding ASCII
    Set-Content -LiteralPath ($PanelDir + '\a422.txt') -Value 'kept' -Encoding ASCII
    # a second instance holds the install (A4) while the copy is set up; then it is closed and only the copy
    # holds it
    NoCheck
    $other = Start-421
    Start-Sleep -Seconds 6
    Uc-Del 'Last Attempt'; Uc-Del 'Last Attempt Answered'
    $id = Start-421 @() $right; Start-Sleep -Seconds 2
    $main = Get-Main $id
    $lists = @([Drv098f]::Kids($main) | Where-Object { [Drv098f]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv098f]::IsWindowVisible($_) })
    foreach ($l in $lists) { foreach ($vk in @(0x24, 0x28)) { [void][Drv098f]::Send($l, 0x0100, $vk, 1, 30000); [void][Drv098f]::Send($l, 0x0101, $vk, 0xC0000001, 30000) } }
    $copyDlg = Open-ByCmd $id 727 # CM_COPYFILES
    if ($copyDlg -eq $Z) { Out ('F after CM_COPYFILES: lists ' + $lists.Count + ', windows ' + ((@(Get-Tops $id) | ForEach-Object { WinDesc $_ }) -join ' || ') + '; main enabled ' + [Drv098f]::IsWindowEnabled($main)) }
    $known = @(Get-Tops $id)
    if ($copyDlg -ne $Z) { Click-Ok $copyDlg }
    $q = Wait-NewWin $id $known 10
    Out ('F copy dialog: ' + $(if ($copyDlg -ne $Z) { WinDesc $copyDlg } else { 'none' }) + '; question: ' + $(if ($q -ne $Z) { WinDesc $q } else { 'none' }) + '; runs so far ' + (Runs).Count)
    $a = Wait-Arm 30; Start-Sleep -Seconds 2
    $qo = QuitChecked $other
    Start-Sleep -Seconds 8
    T 'F2' 'fileop' ($copyDlg -ne $Z -and $q -ne $Z -and $null -ne $a -and (Runs).Count -eq 0 -and (SilentStr) -like '*file*') ('copy waiting on its question: {0}, {1}; {2}' -f (ArmStr $a), (RunsStr), (SilentStr))
    if ($q -ne $Z) { Press $q 173 } # Skip
    $got = Wait-Run 1 20
    $t = ((Get-Content -LiteralPath ($PanelDir + '\a422.txt')) -join '') + '/' + ((Get-Content -LiteralPath ($right + '\a422.txt')) -join '')
    T 'F3' 'after' ($got -and (Runs)[0] -like $NowLike -and $t -eq 'kept/kept') ('the copy ended: {0}; the target kept "{1}"' -f (RunsStr), $t)
    Kill-Mine $id
    Remove-Item -LiteralPath ($PanelDir + '\a422.txt'), ($right + '\a422.txt') -Force -ErrorAction SilentlyContinue
}

# R: regression rows that still apply
$Groups['R'] = {
    Reset-State 1; Set-Env
    $id = Start-421; $h = Wait-Form $id 'offer'
    Press $h $ID_OK; $got = Wait-Run 1 10
    T 'R1' 'now' ($got -and (Runs)[0] -like $NowLike -and (Gone $h 5)) ('Install Now: ' + (RunsStr))
    Kill-Mine $id
    # a click's plan left by an older build (Install When I Close of 420/421), never launched: the next
    # start completes it - not the exit
    Reset-State 1; Set-Env
    $id = Start-421; [void](Wait-Form $id 'offer'); $q = QuitChecked $id
    Uc-Set 'Install Version' '0.2.0' 'String'; Uc-Set 'Install Digest' '3c56de193de8260f5e15dbc851e250271fc1dffdb882bd30f7da2ece1cd2e2b2' 'String'
    Uc-Set 'Install Source' 1; Uc-Set 'Install Test' 0; Uc-Set 'Install Launches' 0; Uc-Set 'Install Confirmed' 0
    $id = Restart-421 $false; $got = Wait-Run 1 20
    T 'R2' 'old-plan' ($q.NewRuns -eq 0 -and $got -and (Runs)[0] -like $NowLike) ('exit of an offer: no run {0}; an old click plan at the next start: {1}' -f ($q.NewRuns -eq 0), (RunsStr))
    Kill-Mine $id
    Reset-State 0; Set-Env
    $id = Start-421; $h = Wait-Notice $id 20
    Press $h $ID_OK; Start-Sleep -Seconds 2
    $ol = if (Test-Path -LiteralPath $OpenLog) { (Get-Content -LiteralPath $OpenLog) -join ' ' } else { '' }
    T 'R3' 'browser' ($ol -like '*releases/download/v0.2.0/tandemcommander-0.2.0-x64-setup.exe*' -and (Runs).Count -eq 0) ('Download (browser): opened "{0}", {1}' -f (Esc $ol), (RunsStr))
    Kill-Mine $id
}

# X: across all groups - a normal exit never started an installer (FR-003, SC-002)
$Groups['X'] = {
    T 'X1' 'no-exit-install' ($script:ExitRuns -eq 0) ('exits that started an installer: ' + $script:ExitRuns)
}

# ---- run --------------------------------------------------------------------------------------
if ((Test-Path -LiteralPath $Upd) -and @(Get-ChildItem -LiteralPath $Upd -Force).Count -gt 0) { Write-Host "NOT RUN: $Upd is not empty"; exit 98 }
$updParentExisted = Test-Path -LiteralPath (Split-Path $Upd)
$regFile = Join-Path $TempRoot 'tc422_backup.reg'
$existed = Backup-Reg $regFile
Out ('Feature 422 probe, {0}, exe {1}, registry backup {2}' -f (Get-Date -Format s), $Exe, $regFile)
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
    & cmd.exe /c "reg delete HKCU\Software\TC422Probe /f >nul 2>&1"
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
