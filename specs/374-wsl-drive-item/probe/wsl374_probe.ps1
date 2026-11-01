<#
.SYNOPSIS
    Feature 374 probe: the Change Drive menu (Alt+F1) and the drive bar offer the WSL distributions.

.DESCRIPTION
    Debug build with the probe seams TC_PROBE_DRIVES_DUMP (features 246 / 289 / 374) and
    TC_PROBE_WSL_LXSS (374, specs/374-wsl-drive-item/contracts/probe-seam.md). Rows:
      REAL-MENU   the real WSL registration (this computer: docker-desktop, Ubuntu): the Alt+F1 list
                  holds one "Linux - <name>" item per distribution, sorted, after the cloud storages
                  and before Network
      REAL-BAR    the drive bar holds one drop-down WSL button (type 20) with the tooltip "Linux"
      NO-VM       no distribution runs after the menus and bars were built (none ran before)
      TIME        the WSL part of the list build (median of 5 Alt+F1) < 10 ms, and the whole build
                  with the option on vs off differs by < 10 ms (SC-004)
      SAVED       a configuration without the value is saved with "Change Drive Show WSL" = 1 at exit
      OPT-OFF     value 0: no WSL item, no registry read (WSL on=0 count=0)
      REGRESS     every other item (type, text) is identical with the option on and off (FR-010)
      FAKE-MIX    a fake registration: unusable, not installed, duplicate and wrong-type entries are
                  left out; '&' doubled; order by the file system's name order
      FAKE-ONE    one distribution: the menu item; the bar holds a single button (type 19) whose
                  tooltip is "Linux - <name>"
      FAKE-NONE   no key: no item, no button
      OPEN-MENU   choosing "Linux - Ubuntu" in Alt+F1 opens \\wsl.localhost\Ubuntu in the panel
      FOCUS       with the panel there, the Alt+F1 list checks that item
      OPEN-BAR    the drive bar's drop-down -> Ubuntu opens \\wsl.localhost\Ubuntu in the panel
    The OPEN rows start Ubuntu (as File Explorer would); when it did not run before, the probe stops
    it again at the end (wsl --terminate Ubuntu). docker-desktop is never opened.

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs.
    Backs up and restores HKCU\Software\Tandem Commander (SHA-256 verified); the fake registrations
    live under HKCU\Software\TcProbe374 and are deleted at the end. Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [switch]$NoOpen,
    [string]$KeepDumps   # a folder outside the repository: the dumps are copied there (they name hot paths)
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc374'
$StartDir = $Root + '\start'
$Strict = New-Object Text.UTF8Encoding($false, $true)
$FakeRoot = 'HKCU\Software\TcProbe374'
$FakeRel = 'Software\TcProbe374'
$CfgKey = "$RegKey\Settings\Configuration"
$BS = [string][char]92
$Wsl = $BS + $BS + 'wsl.localhost' + $BS

function Read-Dump([string]$File) {
    $lines = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $File)) { return $lines }
    $b = [IO.File]::ReadAllBytes($File); $s = 0
    for ($i = 0; $i -lt $b.Length - 1; $i++) {
        if ($b[$i] -eq 13 -and $b[$i + 1] -eq 10) {
            $n = $i - $s; $part = New-Object byte[] $n; [Array]::Copy($b, $s, $part, 0, $n)
            [void]$lines.Add($Strict.GetString($part)); $s = $i + 2; $i++
        }
    }
    return $lines
}
# the dump split into builds: each starts at a BUILD line; Bar, Wsl (line), Items (idx,type,text), Time, Focus
function Get-Builds($Lines) {
    $builds = New-Object System.Collections.ArrayList
    $cur = $null
    foreach ($l in $Lines) {
        if ($l.StartsWith('BUILD ')) {
            $cur = [pscustomobject]@{ Bar = [int]($l -replace '^BUILD bar=(\d).*$', '$1'); Wsl = $null; Items = New-Object System.Collections.ArrayList; Time = -1; Focus = -2 }
            [void]$builds.Add($cur); continue
        }
        if ($null -eq $cur) { continue }
        if ($l.StartsWith('WSL ')) { $cur.Wsl = $l }
        elseif ($l -match '^ALL idx=(\d+) type=(\d+) text=(.*)$') {
            $t = $Matches[3]; $k = $t.IndexOf([char]9); if ($k -ge 0) { $t = $t.Substring($k + 1) }
            [void]$cur.Items.Add([pscustomobject]@{ Idx = [int]$Matches[1]; Type = [int]$Matches[2]; Text = $t })
        }
        elseif ($l -match '^TIME bar=\d us=(\d+)$') { $cur.Time = [int]$Matches[1] }
        elseif ($l -match '^FOCUS idx=(-?\d+)$') { $cur.Focus = [int]$Matches[1] }
    }
    return $builds
}
function WslField($B, [string]$Name) { if ($null -eq $B.Wsl) { return $null }; if ($B.Wsl -match (' ' + $Name + '=([0-9A-Fa-f]+)')) { return $Matches[1] }; return $null }
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000); Start-Sleep -Milliseconds 300 }
function Wait-Menu([int]$Id, [double]$Seconds = 15) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        $m = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq 'PopupMenuClass' }) | Select-Object -First 1
        if ($m) { Start-Sleep -Milliseconds 400; return $m }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
function MenuKey([IntPtr]$M, [int]$Vk) {
    [void][Drv098f]::PostMessageW($M, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($M, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)
    Start-Sleep -Milliseconds 150
}
function Wait-Gone([IntPtr]$M) { $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($M)) { Start-Sleep -Milliseconds 100 } }
function Menu-Esc([int]$Id) {   # Alt+F1 opened and closed: one menu build
    Post-Cmd (Get-Main $Id) 707   # CM_LCHANGEDRIVE
    $m = Wait-Menu $Id
    if ($m -ne [IntPtr]::Zero) { MenuKey $m 0x1B; Wait-Gone $m }
    Sync $Id
    return ($m -ne [IntPtr]::Zero)
}
# the drive bar: shown unless it is already (the configuration may show it - then CM_TOGGLEDRIVEBAR would hide it)
function Show-Bar([int]$Id, [string]$Dump) {
    if (@(Read-Dump $Dump | Where-Object { $_.StartsWith('BUILD bar=1 ') }).Count) { return }
    Post-Cmd (Get-Main $Id) 755; Start-Sleep -Milliseconds 1500; Sync $Id   # CM_TOGGLEDRIVEBAR
}
function Running-Distros {
    $old = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::Unicode
        $o = @(& wsl.exe --list --running --quiet 2>$null)
    }
    finally { [Console]::OutputEncoding = $old }
    return @($o | ForEach-Object { ($_ -replace [char]0, '').Trim() } | Where-Object { $_ -ne '' })
}
function Fake-Distro([string]$Set, [string]$Guid, $Name, $State, [string]$NameType = 'REG_SZ') {
    $k = "$FakeRoot\$Set\$Guid"
    & reg.exe add $k /f | Out-Null
    if ($null -ne $Name) { & reg.exe add $k /v 'DistributionName' /t $NameType /d $Name /f | Out-Null }
    if ($null -ne $State) { & reg.exe add $k /v 'State' /t REG_DWORD /d $State /f | Out-Null }
}
function Is-Ubuntu([string]$L) { return ($L.TrimEnd([char]92) -ceq ($Wsl + 'Ubuntu')) }
function Median($xs) { $a = @($xs | Sort-Object); if (-not $a.Count) { return -1 }; return $a[[int][Math]::Floor(($a.Count - 1) / 2)] }
# runs one instance: $Lxss = $null (the real key) or a fake subkey; $Opt = $null (value deleted), 0 or 1
function Run-Instance([string]$Name, $Lxss, $Opt, [int]$Menus = 1, [bool]$Bar = $true) {
    $dump = $Root + '\dump_' + $Name + '.txt'
    if ($null -eq $Opt) { & cmd.exe /c "reg delete `"$CfgKey`" /v `"Change Drive Show WSL`" /f >nul 2>&1" }
    else { & reg.exe add $CfgKey /v 'Change Drive Show WSL' /t REG_DWORD /d $Opt /f | Out-Null }
    $env:TC_PROBE_DRIVES_DUMP = $dump
    if ($null -ne $Lxss) { $env:TC_PROBE_WSL_LXSS = $Lxss } else { Remove-Item Env:\TC_PROBE_WSL_LXSS -ErrorAction SilentlyContinue }
    $id = 0; $opened = 0
    try {
        $id = Start-Tc $StartDir
        # the bar first: each Alt+F1 then dumps the bar's tooltips (RebuildDriveBarsIfNeeded, 246)
        if ($Bar) { Show-Bar $id $dump }
        for ($i = 0; $i -lt $Menus; $i++) { if (Menu-Esc $id) { $opened++ } }
        $fatal = Fatal-Win $id
        if ($fatal) { Row ('RUN-' + $Name) 'RUN' 'FAIL' $fatal }
        Stop-Tc $id; $id = 0
    }
    finally {
        if ($id) { Kill-Mine $id }
        Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
        Remove-Item Env:\TC_PROBE_WSL_LXSS -ErrorAction SilentlyContinue
    }
    $b = Get-Builds (Read-Dump $dump)
    Out ("[{0}] menus opened {1}/{2}; builds {3} (menu {4}, bar {5})" -f $Name, $opened, $Menus, $b.Count, @($b | Where-Object { $_.Bar -eq 0 }).Count, @($b | Where-Object { $_.Bar -eq 1 }).Count)
    return $b
}
function MenuBuilds($B) { return @($B | Where-Object { $_.Bar -eq 0 }) }
function BarBuilds($B) { return @($B | Where-Object { $_.Bar -eq 1 }) }
function TypeTexts($Build, [int[]]$Types) { return @($Build.Items | Where-Object { $Types -contains $_.Type } | ForEach-Object { $_.Text }) }
function Tips($File) { return @(Read-Dump $File | Where-Object { $_.StartsWith('TIP ') } | ForEach-Object { $_.Substring(6) }) }

$backup = Join-Path $env:TEMP 'tc374_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
$runningBefore = @()
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    & cmd.exe /c "reg delete `"$FakeRoot`" /f >nul 2>&1"
    # fake registrations
    Fake-Distro 'Mix' '{a}' 'Zeta' 1
    Fake-Distro 'Mix' '{b}' 'alpha' $null          # no State: taken as installed
    Fake-Distro 'Mix' '{c}' ('Bad' + $BS + 'Name') 1  # unusable
    Fake-Distro 'Mix' '{d}' 'Removing' 4           # being uninstalled
    Fake-Distro 'Mix' '{e}' 'ALPHA' 1              # a case-insensitive duplicate of alpha
    Fake-Distro 'Mix' '{f}' 'R&D' 1
    Fake-Distro 'Mix' '{g}' 'Typed' 1 'REG_EXPAND_SZ'  # wrong value type
    Fake-Distro 'Mix' '{h}' $null 1                # no name
    Fake-Distro 'One' '{a}' 'Solo' 1
    $runningBefore = @(Running-Distros)

    Out ("wsl374 (feature 374) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; running distributions before: '{2}'" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, ($runningBefore -join ','))
    $realNames = @(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue | ForEach-Object { (Get-ItemProperty $_.PSPath).DistributionName } | Where-Object { $_ })
    Out ("Real registration: {0}" -f ($realNames -join ', '))
    Out ''

    # --- the real registration, option absent (default on) -------------------------------------
    $on = Run-Instance 'on' $null $null 5 $true
    $saved = (Get-ItemProperty "Registry::$CfgKey" -ErrorAction SilentlyContinue).'Change Drive Show WSL'
    $mb = @(MenuBuilds $on)
    $expect = @($realNames | Sort-Object { $_.ToUpperInvariant() } | ForEach-Object { 'Linux - ' + $_.Replace('&', '&&') })
    if ($mb.Count) {
        $m0 = $mb[0]
        $wslTexts = TypeTexts $m0 @(19)
        $cloudMax = @($m0.Items | Where-Object { $_.Type -ge 8 -and $_.Type -le 12 } | ForEach-Object { $_.Idx }) | Measure-Object -Maximum
        $netMin = @($m0.Items | Where-Object { $_.Type -eq 13 } | ForEach-Object { $_.Idx }) | Measure-Object -Minimum
        $wslIdx = @($m0.Items | Where-Object { $_.Type -eq 19 } | ForEach-Object { $_.Idx })
        $placeOk = $wslIdx.Count -gt 0 -and ($cloudMax.Count -eq 0 -or $wslIdx[0] -gt $cloudMax.Maximum) -and ($netMin.Count -eq 0 -or $wslIdx[-1] -lt $netMin.Minimum)
        $ok = (($wslTexts -join '|') -ceq ($expect -join '|')) -and $placeOk -and ((WslField $m0 'count') -eq [string]$expect.Count) -and (@(TypeTexts $m0 @(20)).Count -eq 0)
        Row 'REAL-MENU' 'RUN' (V $ok) ("items '{0}' (expected '{1}'); after cloud / before Network {2}; {3}" -f ($wslTexts -join ' | '), ($expect -join ' | '), $placeOk, $m0.Wsl)
    }
    else { Row 'REAL-MENU' 'RUN' 'FAIL' 'no menu build' }
    $bb = @(BarBuilds $on)
    $tips = Tips ($Root + '\dump_on.txt')
    if ($bb.Count) {
        $b0 = $bb[-1]
        $t20 = TypeTexts $b0 @(20); $t19 = TypeTexts $b0 @(19)
        $ok = $expect.Count -gt 1 -and $t20.Count -eq 1 -and $t19.Count -eq 0 -and ($tips -ccontains 'Linux')
        Row 'REAL-BAR' 'RUN' (V $ok) ("drop-down buttons {0} ('{1}'), single buttons {2}; tooltip 'Linux' {3}" -f $t20.Count, ($t20 -join '|'), $t19.Count, ($tips -ccontains 'Linux'))
    }
    else { Row 'REAL-BAR' 'RUN' 'FAIL' 'no drive bar build' }
    Row 'SAVED' 'RUN' (V ($saved -eq 1)) ("value after the exit of a run without it: '{0}'" -f $saved)

    # --- option off ----------------------------------------------------------------------------
    $off = Run-Instance 'off' $null 0 5 $true
    $mbOff = @(MenuBuilds $off)
    $anyWsl = @($off | ForEach-Object { TypeTexts $_ @(19, 20) }).Count
    $wslLinesOff = @($off | Where-Object { $null -eq $_.Wsl -or $_.Wsl -notmatch '^WSL on=0 count=0 ' }).Count   # every build must say so
    Row 'OPT-OFF' 'RUN' (V ($mbOff.Count -gt 0 -and $anyWsl -eq 0 -and $wslLinesOff -eq 0)) ("WSL items {0}; builds not 'on=0 count=0' {1}; e.g. {2}" -f $anyWsl, $wslLinesOff, $(if ($mbOff.Count) { $mbOff[0].Wsl } else { '-' }))
    if ($mb.Count -and $mbOff.Count) {
        $a = @($mb[0].Items | Where-Object { $_.Type -ne 19 -and $_.Type -ne 20 } | ForEach-Object { '' + $_.Type + ':' + $_.Text })
        $c = @($mbOff[0].Items | ForEach-Object { '' + $_.Type + ':' + $_.Text })
        Row 'REGRESS' 'RUN' (V (($a -join '|') -ceq ($c -join '|'))) ("{0} other items with the option on, {1} off; identical {2}" -f $a.Count, $c.Count, (($a -join '|') -ceq ($c -join '|')))
    }
    else { Row 'REGRESS' 'RUN' 'FAIL' 'missing builds' }
    $wslUs = @($mb | ForEach-Object { [int](WslField $_ 'us') })
    $tOn = Median @($mb | ForEach-Object { $_.Time }); $tOff = Median @($mbOff | ForEach-Object { $_.Time })
    $wMed = Median $wslUs
    $allWsl = $mb.Count -gt 0 -and @($mb | Where-Object { $null -eq $_.Wsl }).Count -eq 0
    Row 'TIME' 'RUN' (V ($allWsl -and $wMed -ge 0 -and $wMed -lt 10000 -and ($tOn - $tOff) -lt 10000)) ("WSL part us {0} (median {1}); build us on {2} / off {3} (medians {4} / {5})" -f ($wslUs -join ','), $wMed, (@($mb | ForEach-Object { $_.Time }) -join ','), (@($mbOff | ForEach-Object { $_.Time }) -join ','), $tOn, $tOff)

    # --- fake registrations ---------------------------------------------------------------------
    $mix = Run-Instance 'mix' "$FakeRel\Mix" 1 1 $false
    $mm = @(MenuBuilds $mix)
    $mixTexts = if ($mm.Count) { TypeTexts $mm[0] @(19) } else { @() }
    $mixExpect = @('Linux - alpha', 'Linux - R&&D', 'Linux - Zeta')
    Row 'FAKE-MIX' 'RUN' (V (($mixTexts -join '|') -ceq ($mixExpect -join '|'))) ("items '{0}' (expected '{1}')" -f ($mixTexts -join ' | '), ($mixExpect -join ' | '))
    $one = Run-Instance 'one' "$FakeRel\One" 1 1 $true
    $om = @(MenuBuilds $one); $ob = @(BarBuilds $one); $otips = Tips ($Root + '\dump_one.txt')
    $omT = if ($om.Count) { TypeTexts $om[0] @(19) } else { @() }
    $obT19 = if ($ob.Count) { TypeTexts $ob[-1] @(19) } else { @() }
    $obT20 = if ($ob.Count) { TypeTexts $ob[-1] @(20) } else { @() }
    $ok = ($omT -join '|') -ceq 'Linux - Solo' -and ($obT19 -join '|') -ceq 'Linux - Solo' -and $obT20.Count -eq 0 -and ($otips -ccontains 'Linux - Solo')
    Row 'FAKE-ONE' 'RUN' (V $ok) ("menu '{0}'; bar single '{1}', drop-down {2}; tooltip 'Linux - Solo' {3}" -f ($omT -join '|'), ($obT19 -join '|'), $obT20.Count, ($otips -ccontains 'Linux - Solo'))
    $none = Run-Instance 'none' "$FakeRel\Missing" 1 1 $true
    $nAny = @($none | ForEach-Object { TypeTexts $_ @(19, 20) }).Count
    $nLines = @($none | Where-Object { $_.Wsl -match '^WSL on=1 count=0 ' }).Count
    Row 'FAKE-NONE' 'RUN' (V ($nAny -eq 0 -and $nLines -eq $none.Count -and $none.Count -gt 0)) ("WSL items {0}; builds 'on=1 count=0' {1}/{2}" -f $nAny, $nLines, $none.Count)

    $runningAfter = @(Running-Distros)
    $newRun = @($runningAfter | Where-Object { $runningBefore -notcontains $_ })
    Row 'NO-VM' 'RUN' (V ($newRun.Count -eq 0)) ("running before '{0}', after the builds '{1}'" -f ($runningBefore -join ','), ($runningAfter -join ','))

    # --- opening (starts Ubuntu) ---------------------------------------------------------------
    if ($NoOpen -or ($realNames -notcontains 'Ubuntu')) {
        Row 'OPEN-MENU' 'RUN' 'NOT DRIVEN' 'skipped (-NoOpen or no Ubuntu registered)'
        Row 'FOCUS' 'RUN' 'NOT DRIVEN' 'skipped'
        Row 'OPEN-BAR' 'RUN' 'NOT DRIVEN' 'skipped'
    }
    else {
        $dump = $Root + '\dump_open.txt'
        & reg.exe add $CfgKey /v 'Change Drive Show WSL' /t REG_DWORD /d 1 /f | Out-Null
        $env:TC_PROBE_DRIVES_DUMP = $dump
        $id = 0
        try {
            $id = Start-Tc $StartDir
            # Alt+F1, Home, Down x k, Enter on "Linux - Ubuntu"
            Post-Cmd (Get-Main $id) 707
            $m = Wait-Menu $id
            $b = Get-Builds (Read-Dump $dump); $mb1 = @(MenuBuilds $b)[-1]
            $pos = -1; $k = 0
            foreach ($it in $mb1.Items) { if ($it.Type -eq 19 -and $it.Text -ceq 'Linux - Ubuntu') { $pos = $k; break }; $k++ }
            if ($m -ne [IntPtr]::Zero -and $pos -ge 0) {
                MenuKey $m 0x24
                for ($i = 0; $i -lt $pos; $i++) { MenuKey $m 0x28 }
                MenuKey $m 0x0D
                Wait-Gone $m
            }
            elseif ($m -ne [IntPtr]::Zero) { MenuKey $m 0x1B }
            $loc = ''; $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Milliseconds 1500; $loc = Get-Loc $id; if (Is-Ubuntu $loc) { break } }
            Row 'OPEN-MENU' 'RUN' (V (Is-Ubuntu $loc)) ("item position {0}; panel '{1}' after {2:N1} s" -f $pos, (Esc $loc), $sw.Elapsed.TotalSeconds)
            # FOCUS: Alt+F1 again
            [void](Menu-Esc $id)
            $b = Get-Builds (Read-Dump $dump); $mb2 = @(MenuBuilds $b)[-1]
            $ub = @($mb2.Items | Where-Object { $_.Type -eq 19 -and $_.Text -ceq 'Linux - Ubuntu' } | ForEach-Object { $_.Idx })
            Row 'FOCUS' 'RUN' (V ($ub.Count -eq 1 -and $mb2.Focus -eq $ub[0])) ("checked idx {0}, 'Linux - Ubuntu' idx {1}" -f $mb2.Focus, ($ub -join ','))
            # back to the start folder, then the drive bar's drop-down
            [void](Do-ChangeDir $id $StartDir)
            Start-Sleep -Milliseconds 800
            $locStart = Get-Loc $id
            Show-Bar $id $dump
            $b = Get-Builds (Read-Dump $dump); $bb1 = @(BarBuilds $b)[-1]
            $btn = @($bb1.Items | Where-Object { $_.Type -eq 20 } | ForEach-Object { $_.Idx })
            $loc2 = '<not run>'
            if ($btn.Count -eq 1) {
                Post-Cmd (Get-Main $id) (3500 + $btn[0])   # CM_DRIVEBAR_MIN + index: CDriveBar::Execute
                $dm = Wait-Menu $id
                if ($dm -ne [IntPtr]::Zero) {
                    $sorted = @($realNames | Sort-Object { $_.ToUpperInvariant() })
                    $up = [Array]::IndexOf($sorted, 'Ubuntu')
                    MenuKey $dm 0x24
                    for ($i = 0; $i -lt $up; $i++) { MenuKey $dm 0x28 }
                    MenuKey $dm 0x0D
                    Wait-Gone $dm
                }
                $sw = [Diagnostics.Stopwatch]::StartNew()
                while ($sw.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Milliseconds 1500; $loc2 = Get-Loc $id; if (Is-Ubuntu $loc2) { break } }
            }
            Row 'OPEN-BAR' 'RUN' (V ($btn.Count -eq 1 -and $locStart.TrimEnd([char]92) -ceq $StartDir -and (Is-Ubuntu $loc2))) ("drop-down button idx {0}; panel before '{1}', after '{2}'" -f ($btn -join ','), (Esc $locStart), (Esc $loc2))
            $fatal = Fatal-Win $id
            if ($fatal) { Row 'RUN-open' 'RUN' 'FAIL' $fatal }
            Stop-Tc $id; $id = 0
        }
        finally {
            if ($id) { Kill-Mine $id }
            Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
        }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace); Row 'PROBE' 'ERROR' 'FAIL' $_.Exception.Message }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
    Remove-Item Env:\TC_PROBE_WSL_LXSS -ErrorAction SilentlyContinue
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    & cmd.exe /c "reg delete `"$FakeRoot`" /f >nul 2>&1"
    if ($runningBefore -notcontains 'Ubuntu') {
        $nowRunning = @(Running-Distros)
        if ($nowRunning -contains 'Ubuntu') { & wsl.exe --terminate Ubuntu | Out-Null; Out 'Ubuntu did not run before: terminated again' }
    }
    if ($KeepDumps) { [void][IO.Directory]::CreateDirectory($KeepDumps); Get-ChildItem -LiteralPath $Root -Filter 'dump_*.txt' -ErrorAction SilentlyContinue | Copy-Item -Destination $KeepDumps -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; fake key removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), (-not (Test-Path 'HKCU:\Software\TcProbe374')), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
