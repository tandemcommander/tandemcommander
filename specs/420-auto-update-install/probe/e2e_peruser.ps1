<#
.SYNOPSIS
    Feature 420 - end-to-end run with the REAL published installer over a per-user test
    installation (quickstart.md section 3). Runs on the hidden desktop.
    1. installs the published 0.1.9 per user (/CURRENTUSER, no elevation) - refuses when a
       per-user installation already exists;
    2. copies the Debug build of this feature over it (an "installed" copy of the feature);
    3. E1: level "install automatically", started with --updatetest: real check on GitHub, real
       download of the published 0.2.0 installer, real verification, armed; closed normally ->
       the real installer runs at exit; the installed tandemcommander.exe must then equal the
       published 0.2.0 one;
    4. E2: the Debug build copied over again; armed, the program killed (no exit); started again
       with --updatetest -> the update is completed at that start: the real installer closes the
       program through the Restart Manager and installs 0.2.0 (TC_UPDATE_PROBE_NORESTART keeps the
       restart off the visible desktop);
    5. uninstalls the per-user installation; restores the registry; removes the updates folder.
.PARAMETER Exe   tandemcommander.exe of the Debug build (its folder is copied)
.PARAMETER Fixture  the release record and the installer come from the loopback fixture server
    (updserver420.py, the published signed 0.2.0 installer) instead of GitHub
#>
param([Parameter(Mandatory = $true)][string]$Exe, [string]$Result = '', [switch]$Fixture)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not $Result) { $Result = Join-Path $PSScriptRoot 'e2e_result.txt' }
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Write-Host 'NOT RUN: a tandemcommander.exe is running'; exit 99 }

$Z = [IntPtr]::Zero
$Old = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\setup\output\tandemcommander-0.1.9-x64-setup.exe')).Path
$Official = 'C:\Program Files\Tandem Commander\tandemcommander.exe'   # the installed published 0.2.0
$UninstKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{35C0B0DC-DB73-429C-AAA8-FBC41C937F66}_is1'
$Dir = Join-Path $env:LOCALAPPDATA 'Programs\Tandem Commander'
$Upd = Join-Path $env:LOCALAPPDATA 'Tandem Commander\Updates'
$UcKey = 'HKCU\Software\Tandem Commander\Settings\Update Check'
$Fx = $TempRoot + '\tc420e2e'
$PanelDir = $Fx + '\panel'
function T([string]$Case, [string]$Step, [bool]$Ok, [string]$Facts) { Row $Case $Step (V $Ok) $Facts }
function Hash([string]$p) { if (Test-Path -LiteralPath $p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash }; return '<none>' }
function Uc-Set([string]$Name, $Value, [string]$Type = 'REG_DWORD') { & cmd.exe /c "reg add `"$UcKey`" /v `"$Name`" /t $Type /d $Value /f >nul 2>&1" }
function Uc-Del([string]$Name) { & cmd.exe /c "reg delete `"$UcKey`" /v `"$Name`" /f >nul 2>&1" }
function Uc-Get([string]$Name) { $p = Get-ItemProperty -LiteralPath ('Registry::' + $UcKey) -Name $Name -ErrorAction SilentlyContinue; if ($null -eq $p) { return $null }; return $p.$Name }
function ArmStr { $v = Uc-Get 'Install Version'; if ($null -eq $v) { return 'no arm' }; return ('arm {0} source {1} test {2} launches {3}' -f $v, (Uc-Get 'Install Source'), (Uc-Get 'Install Test'), (Uc-Get 'Install Launches')) }
function Reset-Uc {
    foreach ($n in @('Last Attempt', 'Last Attempt Answered', 'Install Version', 'Install Digest', 'Install Source', 'Install Test', 'Install Launches')) { Uc-Del $n }
    Uc-Set 'Check At Startup' 1; Uc-Set 'Update Level' 2
}
$script:LoaderIds = @{}
function Setups {
    $s = @(Get-Process | Where-Object { $_.ProcessName -like 'tandemcommander-*-setup*' -or $_.ProcessName -like 'setup*.tmp' -or $_.ProcessName -like 'is-*' })
    # the installer loaders started from the updates folder (each start of the installer is one)
    foreach ($p in $s) { try { if ($p.Path -and $p.Path.StartsWith($Upd, [StringComparison]::OrdinalIgnoreCase)) { $script:LoaderIds[$p.Id] = $true } } catch { } }
    return $s
}
function Wait-Setups([double]$Seconds = 300) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    # the installer starts a moment after the program ended
    while ($sw.Elapsed.TotalSeconds -lt 15 -and (Setups).Count -eq 0) { Start-Sleep -Milliseconds 200 }
    $seen = (Setups).Count -gt 0
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Setups).Count -gt 0) { Start-Sleep -Milliseconds 300 }
    return [pscustomobject]@{ Seen = $seen; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1); Left = (Setups).Count }
}
function Overlay {
    # the Debug build tree (without intermediate files) over the installed files
    & robocopy.exe (Split-Path $Exe) $Dir /E /NFL /NDL /NJH /NJS /NP /XD Intermediate saltests /XF *.pdb *.ilk *.lib *.exp | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
}
function Start-Inst([string[]]$Extra = @()) {
    $exeI = Join-Path $Dir 'tandemcommander.exe'
    $a = @('-t', 'E420', '-l', ('"{0}"' -f $PanelDir), '-r', ('"{0}"' -f $PanelDir)) + $Extra
    $p = Start-Process -FilePath $exeI -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq $Z) { Start-Sleep -Milliseconds 100 }
    return $p.Id
}
function Wait-Arm([double]$Seconds = 180) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $Seconds) { if ($null -ne (Uc-Get 'Install Version')) { return $true }; Start-Sleep -Milliseconds 300 }; return $false }

if (Test-Path -LiteralPath $UninstKey) { Write-Host 'NOT RUN: a per-user installation exists already'; exit 98 }
if (Test-Path -LiteralPath $Dir) { Write-Host "NOT RUN: $Dir exists"; exit 98 }
if ((Test-Path -LiteralPath $Upd) -and @(Get-ChildItem -LiteralPath $Upd -Force).Count) { Write-Host "NOT RUN: $Upd is not empty"; exit 98 }
$updParentExisted = Test-Path -LiteralPath (Split-Path $Upd)
$regFile = Join-Path $TempRoot 'tc420e2e_backup.reg'
$existed = Backup-Reg $regFile
Out ('Feature 420 end-to-end, {0}; official 0.2.0 exe {1} SHA-256 {2}' -f (Get-Date -Format s), $Official, (Hash $Official))
$restored = $false
try {
    [void][IO.Directory]::CreateDirectory($PanelDir)
    foreach ($n in @('TC_UPDATECHECK_URL', 'TC_UPDATECHECK_PRETEND_VERSION', 'TC_UPDATE_PROBE_UNINSTALL', 'TC_UPDATE_PROBE_RUNLOG', 'TC_UPDATE_PROBE_METERED', 'TC_UPDATE_PROBE_NORESTART')) { Remove-Item ('Env:\' + $n) -ErrorAction SilentlyContinue }

    if ($Fixture) {
        $good = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\setup\output\tandemcommander-0.2.0-x64-setup.exe')).Path
        $script:Srv = Start-Process -FilePath python -ArgumentList @(('"{0}"' -f (Join-Path $PSScriptRoot 'updserver420.py')), '--port', 8421, '--log', ('"{0}\requests.log"' -f $Fx),
            '--good', ('"{0}"' -f $good), '--older', ('"{0}"' -f $Old),
            '--foreign', '"C:\Program Files\Inno Setup 7\ISCC.exe"', '--unsigned', '"C:\Program Files\7-Zip\7z.exe"') -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 2
        $env:TC_UPDATECHECK_URL = 'http://127.0.0.1:8421/latest/rel-good'
        Out 'source: the loopback fixture server (the published signed 0.2.0 installer)'
    }
    else { Out 'source: GitHub' }
    # 1. the published 0.1.9, per user
    $p = Start-Process -FilePath $Old -ArgumentList @('/SP-', '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', ('/LOG="{0}\install019.log"' -f $Fx)) -PassThru
    [void]$p.WaitForExit(300000)
    $loc = (Get-ItemProperty -LiteralPath $UninstKey -ErrorAction SilentlyContinue).InstallLocation
    T 'E0' 'install' ($p.ExitCode -eq 0 -and $loc -eq ($Dir + '\')) ('published 0.1.9 installed per user: exit {0}, InstallLocation {1}' -f $p.ExitCode, $loc)
    if ($loc -ne ($Dir + '\')) { throw 'the per-user installation is not where expected' }

    # E1: automatic level, test mode, real GitHub, install at exit
    Overlay
    T 'E1' 'overlay' ((Hash (Join-Path $Dir 'tandemcommander.exe')) -eq (Hash $Exe)) 'the Debug build of the feature copied over the installation'
    Reset-Uc
    $id = Start-Inst @('--updatetest')
    $armed = Wait-Arm 180
    T 'E1' 'armed' $armed ('real check + real download + verification: {0}; files {1}' -f (ArmStr), ((Get-ChildItem -LiteralPath $Upd -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join ', '))
    Start-Sleep -Seconds 2
    [void][Drv098f]::PostMessageW((Get-Main $id), 0x0010, $Z, $Z)
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $id)) { Start-Sleep -Milliseconds 100 }
    $w = Wait-Setups 300
    $h = Hash (Join-Path $Dir 'tandemcommander.exe'); $hOff = Hash $Official
    $log = Join-Path $Upd 'setup-0.2.0.log'
    $logTail = if (Test-Path -LiteralPath $log) { ((Get-Content -LiteralPath $log -Tail 3) -join ' / ') } else { '<no log>' }
    T 'E1' 'installed' ($w.Seen -and $w.Left -eq 0 -and $h -eq $hOff) ('installer seen {0}, finished after {1} s; installed exe {2} (published 0.2.0 {3}); {4}; log: {5}' -f $w.Seen, $w.Seconds, $h, $hOff, (ArmStr), (Esc $logTail))

    # E2: armed, no normal exit, completed at the next start
    Overlay
    Reset-Uc
    $id = Start-Inst @('--updatetest')
    $armed = Wait-Arm 180
    Kill-Mine $id; [void]$script:Procs[$id].WaitForExit(10000)
    T 'E2' 'killed' ($armed -and (Setups).Count -eq 0 -and (Hash (Join-Path $Dir 'tandemcommander.exe')) -eq (Hash $Exe)) ('armed, then killed without its exit: {0}; nothing installed yet' -f (ArmStr))
    $env:TC_UPDATE_PROBE_NORESTART = '1'
    Uc-Set 'Last Attempt' ([DateTime]::UtcNow.ToFileTimeUtc()) 'REG_QWORD'; Uc-Set 'Last Attempt Answered' 1
    $script:LoaderIds = @{}
    $id = Start-Inst @('--updatetest')
    $w = Wait-Setups 300
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $id)) { Start-Sleep -Milliseconds 200 }
    $alive = Test-Alive $id
    Start-Sleep -Seconds 3; [void](Setups) # an installer started by the exit of the closed program would appear now
    $h = Hash (Join-Path $Dir 'tandemcommander.exe')
    $launches = Uc-Get 'Install Launches'
    T 'E2' 'completed' ($w.Seen -and $w.Left -eq 0 -and -not $alive -and $h -eq $hOff) ('next start: installer seen {0}, finished after {1} s; the program closed by it: {2}; installed exe {3} (published {4}); {5}' -f $w.Seen, $w.Seconds, (-not $alive), $h, $hOff, (ArmStr))
    T 'E2' 'once' ($script:LoaderIds.Count -eq 1 -and $launches -eq 1) ('installer starts seen: {0}; launches recorded: {1} (the exit caused by the installer must not start another one)' -f $script:LoaderIds.Count, $launches)
    Remove-Item Env:\TC_UPDATE_PROBE_NORESTART -ErrorAction SilentlyContinue
}
catch { Row 'E' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.InvocationInfo.ScriptLineNumber) }
finally {
    foreach ($i in @($Started)) { if (Test-Alive $i) { Kill-Mine $i } }
    if ($script:Srv -and -not $script:Srv.HasExited) { Stop-Process -Id $script:Srv.Id -Force }
    Remove-Item Env:\TC_UPDATECHECK_URL -ErrorAction SilentlyContinue
    foreach ($s in (Setups)) { try { $s.WaitForExit(120000) | Out-Null } catch { } }
    $unins = Join-Path $Dir 'unins000.exe'
    if (Test-Path -LiteralPath $unins) {
        $u = Start-Process -FilePath $unins -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -PassThru
        [void]$u.WaitForExit(120000)
        # the uninstaller continues from a copy of itself in %TEMP% (_iu*.tmp)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 120 -and @(Get-Process | Where-Object { $_.ProcessName -like '_iu*' }).Count -gt 0) { Start-Sleep -Milliseconds 300 }
        Start-Sleep -Seconds 2
    }
    if (Test-Path -LiteralPath $Dir) { Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue }
    Out ('uninstalled: entry gone {0}, folder gone {1}' -f (-not (Test-Path -LiteralPath $UninstKey)), (-not (Test-Path -LiteralPath $Dir)))
    if (Test-Path -LiteralPath $Upd) { Remove-Item -LiteralPath $Upd -Recurse -Force }
    if (-not $updParentExisted -and (Test-Path -LiteralPath (Split-Path $Upd))) { Remove-Item -LiteralPath (Split-Path $Upd) -Recurse -Force }
    $restored = Restore-Reg $regFile $existed
}
$pass = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
$fail = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
Out ('TOTAL: {0} PASS, {1} FAIL; registry restored: {2}' -f $pass, $fail, $restored)
$script:Lines | Set-Content -LiteralPath $Result -Encoding UTF8
exit $fail
