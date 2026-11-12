<#
.SYNOPSIS
    Desktop drive probe (backlog item ikona-na-desktop-vede-kamsi-neznamo-kam, GitHub #31).

.DESCRIPTION
    Debug build with the probe seams TC_PROBE_DRIVES_DUMP (features 246 / 289 / 374), the new
    TC_PROBE_DESKTOP_FILE (core: the Desktop folder named by a UTF-8 file) and the new
    TC_PROBE_FLD_DUMP (Folders plug-in: what Enter did inside fld:; only the item named by the file
    <dump>.pick is acted upon, every other one is recorded and skipped - nothing else is opened or run).
    Rows:
      MENU-DESKTOP  Alt+F1 holds one core Desktop item (type 21), hot key ', text "Desktop", right after Documents
      MENU-PLUGIN   the Folders plug-in's item reads "Shell Folders"; no other item has the hot key '
      BAR-DESKTOP   the drive bar holds a Desktop button (type 21) with the tooltip "Desktop"
      SAVED         a configuration without the value is saved with "Change Drive Show Desktop" = 1
      OPT-OFF       value 0: no Desktop item, no button
      REGRESS       every other item (type, text) is identical with the option on and off
      OPEN-MENU     choosing Desktop in Alt+F1 opens the FOLDERID_Desktop path as a disk path
      OPEN-BAR      the drive bar's Desktop button opens it too
      ERR-NONE      the shell reports no Desktop path (seam: empty file): an error message, the panel stays
      ERR-MISSING   the Desktop folder does not exist (seam: a missing folder in the fixture): an error
                    message, the panel stays (never the existing parent)
      FLD-CPL       inside fld:, Enter on Control Panel: the panel stays in fld:
      FLD-USER      inside fld:, Enter on the user's folder (root): the panel is on %USERPROFILE%
      FLD-DOCS      inside fld:, Enter on Documents (root, or under This PC): the Documents disk path
      FLD-DRIVE     inside fld:, This PC stays in fld:, then Enter on the system drive: its root as a disk path
      FLD-ZIP       inside fld:, a zip archive on the desktop (a shell folder whose path is a file) stays in fld:
                    (NOT DRIVEN when the desktop holds none - the probe never writes there)

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs.
    Backs up and restores HKCU\Software\Tandem Commander (SHA-256 verified). Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Lib = $env:TC_PROBE_LIB
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib

$Root = $TempRoot + '\tcdesk'
$StartDir = $Root + '\start'
$Strict = New-Object Text.UTF8Encoding($false, $true)
$CfgKey = "$RegKey\Settings\Configuration"
$OptName = 'Change Drive Show Desktop'
$TypeDesktop = 21
$DesktopPath = [Environment]::GetFolderPath('Desktop')
$DocsPath = [Environment]::GetFolderPath('MyDocuments')
$Shell = New-Object -ComObject Shell.Application
# the in-folder names the plug-in lists, found by the items' parsing paths (the names follow the Windows language)
function Shell-Name($Folder, [scriptblock]$Match) { foreach ($it in @($Folder.Items())) { if (& $Match $it.Path) { return $it.Name } }; return $null }
$DeskNs = $Shell.Namespace(0)
$NameThisPC = Shell-Name $DeskNs { param($p) $p -like '::{20D04FE0-3AEA-1069-A2D8-08002B30309D}*' }
$NameCpl = Shell-Name $DeskNs { param($p) $p -like '::{26EE0668-A00A-44D7-9371-BEB064C98683}*' -or $p -like '::{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}*' -or $p -like '::{21EC2020-3AEA-1069-A2DD-08002B30309D}*' }
$NameUser = Shell-Name $DeskNs { param($p) $p -ieq $env:USERPROFILE }
$NameDocsRoot = Shell-Name $DeskNs { param($p) $p -ieq $DocsPath }       # Windows 11 lists Documents at the root
$NameDocsPC = Shell-Name $Shell.Namespace(17) { param($p) $p -ieq $DocsPath } # older layouts: under This PC
$NameDriveC = Shell-Name $Shell.Namespace(17) { param($p) $p -ieq ($env:SystemDrive + [char]92) }
# a zip archive on the desktop: a shell folder with a file-system path that is a file (stays in fld:)
$NameZip = Shell-Name $DeskNs { param($p) $p -like '*.zip' -and [IO.File]::Exists($p) }

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
function Get-Builds($Lines) {
    $builds = New-Object System.Collections.ArrayList
    $cur = $null
    foreach ($l in $Lines) {
        if ($l.StartsWith('BUILD ')) {
            $cur = [pscustomobject]@{ Bar = [int]($l -replace '^BUILD bar=(\d).*$', '$1'); Items = New-Object System.Collections.ArrayList }
            [void]$builds.Add($cur); continue
        }
        if ($null -eq $cur) { continue }
        if ($l -match '^ALL idx=(\d+) type=(\d+) text=(.*)$') {
            $full = $Matches[3]; $t = $full; $hk = ''
            $k = $full.IndexOf([char]9); if ($k -ge 0) { $hk = $full.Substring(0, $k); $t = $full.Substring($k + 1) }
            [void]$cur.Items.Add([pscustomobject]@{ Idx = [int]$Matches[1]; Type = [int]$Matches[2]; Text = $t; Hot = $hk })
        }
    }
    return $builds
}
function MenuBuilds($B) { return @($B | Where-Object { $_.Bar -eq 0 }) }
function BarBuilds($B) { return @($B | Where-Object { $_.Bar -eq 1 }) }
function Tips($File) { return @(Read-Dump $File | Where-Object { $_.StartsWith('TIP ') } | ForEach-Object { $_.Substring(6) }) }
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
function Menu-Esc([int]$Id) {
    Post-Cmd (Get-Main $Id) 707   # CM_LCHANGEDRIVE
    $m = Wait-Menu $Id
    if ($m -ne [IntPtr]::Zero) { MenuKey $m 0x1B; Wait-Gone $m }
    Sync $Id
    return ($m -ne [IntPtr]::Zero)
}
function Show-Bar([int]$Id, [string]$Dump) {
    if (@(Read-Dump $Dump | Where-Object { $_.StartsWith('BUILD bar=1 ') }).Count) { return }
    Post-Cmd (Get-Main $Id) 755; Start-Sleep -Milliseconds 1500; Sync $Id   # CM_TOGGLEDRIVEBAR
}
function Set-Opt($Opt) {
    if ($null -eq $Opt) { & cmd.exe /c "reg delete `"$CfgKey`" /v `"$OptName`" /f >nul 2>&1" }
    else { & reg.exe add $CfgKey /v $OptName /t REG_DWORD /d $Opt /f | Out-Null }
}
# the panel path without a trailing backslash (a root keeps it)
function Norm([string]$P) { if ($P.Length -gt 3) { return $P.TrimEnd([char]92) }; return $P }
# a message box of the pid, if one is shown: its text; closed with OK
function Take-Box([int]$Id, [double]$Seconds = 6) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in (Get-Tops $Id)) {
            if ([Drv098f]::Cls($h) -eq '#32770' -and [Drv098f]::IsWindowVisible($h)) {
                Start-Sleep -Milliseconds 300
                $d = WinDesc $h
                Click-Ok $h; Start-Sleep -Milliseconds 500
                if ([Drv098f]::IsWindow($h)) { Close-Win $h }
                return $d
            }
        }
        Start-Sleep -Milliseconds 200
    }
    return $null
}
# Alt+F1, the item at position Pos of the build (ALL lines skip separators, as the keyboard does), Enter
function Menu-Pick([int]$Id, [string]$Dump, [int]$Type) {
    Post-Cmd (Get-Main $Id) 707
    $m = Wait-Menu $Id
    if ($m -eq [IntPtr]::Zero) { return -2 }
    $b = Get-Builds (Read-Dump $Dump); $mb = @(MenuBuilds $b)[-1]
    $pos = -1; $k = 0
    foreach ($it in $mb.Items) { if ($it.Type -eq $Type) { $pos = $k; break }; $k++ }
    if ($pos -lt 0) { MenuKey $m 0x1B; Wait-Gone $m; return -1 }
    MenuKey $m 0x24
    for ($i = 0; $i -lt $pos; $i++) { MenuKey $m 0x28 }
    MenuKey $m 0x0D
    Wait-Gone $m
    return $pos
}
function Run-Instance([string]$Name, $Opt, [int]$Menus = 1, [bool]$Bar = $true) {
    $dump = $Root + '\dump_' + $Name + '.txt'
    Set-Opt $Opt
    $env:TC_PROBE_DRIVES_DUMP = $dump
    $id = 0; $opened = 0
    try {
        $id = Start-Tc $StartDir
        if ($Bar) { Show-Bar $id $dump }
        for ($i = 0; $i -lt $Menus; $i++) { if (Menu-Esc $id) { $opened++ } }
        $fatal = Fatal-Win $id
        if ($fatal) { Row ('RUN-' + $Name) 'RUN' 'FAIL' $fatal }
        Stop-Tc $id; $id = 0
    }
    finally {
        if ($id) { Kill-Mine $id }
        Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
    }
    $b = Get-Builds (Read-Dump $dump)
    Out ("[{0}] menus opened {1}/{2}; builds {3} (menu {4}, bar {5})" -f $Name, $opened, $Menus, $b.Count, @(MenuBuilds $b).Count, @(BarBuilds $b).Count)
    return $b
}

# --- fld: helpers (seam TC_PROBE_FLD_DUMP of the Folders plug-in) ----------------
function Fld-Lines([string]$File) { return @(Read-Dump $File | Where-Object { $_.StartsWith('LIST ') -or $_.StartsWith('EXEC ') }) }
function Fld-Exec([string]$L) {
    if ($L -match '^EXEC dir=(\d) name=(.*) attrs=([0-9A-F]+) path=(.*) action=(\S+)$') {
        return [pscustomobject]@{ Dir = [int]$Matches[1]; Name = $Matches[2]; Attrs = $Matches[3]; Path = $Matches[4]; Action = $Matches[5] }
    }
    return $null
}
# from a disk path to the root of fld: (a new file system); $true when the plug-in listed it
function Fld-Root([int]$Id, [string]$Dump) {
    [void](Do-ChangeDir $Id $StartDir); Start-Sleep -Milliseconds 500
    $before = @(Fld-Lines $Dump).Count
    [void](Do-ChangeDir $Id 'fld:'); Start-Sleep -Milliseconds 1500; Sync $Id
    $new = @(Fld-Lines $Dump | Select-Object -Skip $before | Where-Object { $_.StartsWith('LIST ') })
    return ($new.Count -gt 0)
}
# walks the focus down the current fld: listing, Enter on each position, until the plug-in acts on the
# picked item (<dump>.pick = $Pick: all other items are recorded and skipped); returns its EXEC
function Fld-Enter([int]$Id, [string]$Dump, [string]$Pick) {
    [IO.File]::WriteAllText($Dump + '.pick', $Pick, (New-Object Text.UTF8Encoding($false)))
    $lists = @(Fld-Lines $Dump | Where-Object { $_.StartsWith('LIST ') })
    $max = 60
    if ($lists.Count -and $lists[-1] -match 'count=(\d+)') { $max = [int]$Matches[1] + 2 }
    $res = $null
    for ($k = 0; $k -lt $max -and $null -eq $res; $k++) {
        $before = @(Fld-Lines $Dump).Count
        Key $Id 0x24
        for ($i = 0; $i -lt $k; $i++) { Key $Id 0x28 }
        Key $Id 0x0D
        Start-Sleep -Milliseconds 400; Sync $Id
        foreach ($l in @(Fld-Lines $Dump | Select-Object -Skip $before | Where-Object { $_.StartsWith('EXEC ') })) {
            $e = Fld-Exec $l
            if ($null -ne $e -and $e.Action -ne 'skipped') { $res = $e }
        }
    }
    return $res
}

$backup = Join-Path $env:TEMP 'tcdesk_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    # every plug-in is loaded (and connected) once at the start: the stored drive-menu texts are fresh
    & reg.exe add $CfgKey /v 'Plugins.ver Version (x64)' /t REG_DWORD /d 0 /f | Out-Null

    Out ("desktop probe (GitHub #31) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ("Desktop : '{0}'; Documents '{1}'; shell names: This PC '{2}', Documents '{3}' / '{4}', Control Panel '{5}', user '{6}', C: '{7}', zip '{8}'" -f (Esc $DesktopPath), (Esc $DocsPath), (Esc $NameThisPC), (Esc $NameDocsRoot), (Esc $NameDocsPC), (Esc $NameCpl), (Esc $NameUser), (Esc $NameDriveC), (Esc $NameZip))
    Out ''

    # --- the items, option absent (default on) ----------------------------------------------------
    $on = Run-Instance 'on' $null 2 $true
    $saved = (Get-ItemProperty "Registry::$CfgKey" -ErrorAction SilentlyContinue).$OptName
    $mb = @(MenuBuilds $on)
    if ($mb.Count) {
        $m0 = $mb[0]
        $desk = @($m0.Items | Where-Object { $_.Type -eq $TypeDesktop })
        $docs = @($m0.Items | Where-Object { $_.Type -eq 7 })
        $after = $desk.Count -eq 1 -and $docs.Count -eq 1 -and $desk[0].Idx -eq ($docs[0].Idx + 1)
        $ok = $desk.Count -eq 1 -and $desk[0].Text -ceq 'Desktop' -and $desk[0].Hot -ceq "'" -and $after
        $dd = if ($desk.Count) { "'" + $desk[0].Hot + "' / '" + $desk[0].Text + "' idx " + $desk[0].Idx } else { 'none' }
        $dc = if ($docs.Count) { 'Documents idx ' + $docs[0].Idx } else { 'no Documents' }
        Row 'MENU-DESKTOP' 'RUN' (V $ok) ("Desktop items {0}: {1}; {2}; right after Documents {3}" -f $desk.Count, $dd, $dc, $after)
        $fld = @($m0.Items | Where-Object { $_.Type -eq 17 -and ($_.Text -ceq 'Shell Folders' -or $_.Text -ceq 'Desktop') })
        $quote = @($m0.Items | Where-Object { $_.Hot -ceq "'" -and $_.Type -ne $TypeDesktop })
        $plugTexts = @($m0.Items | Where-Object { $_.Type -eq 17 } | ForEach-Object { "'" + $_.Hot + "' " + $_.Text })
        $ok = $fld.Count -eq 1 -and $fld[0].Text -ceq 'Shell Folders' -and $quote.Count -eq 0
        Row 'MENU-PLUGIN' 'RUN' (V $ok) ("plug-in items: {0}; others with the hot key ': {1}" -f ($plugTexts -join ' | '), $quote.Count)
    }
    else { Row 'MENU-DESKTOP' 'RUN' 'FAIL' 'no menu build'; Row 'MENU-PLUGIN' 'RUN' 'FAIL' 'no menu build' }
    $bb = @(BarBuilds $on)
    $tips = Tips ($Root + '\dump_on.txt')
    if ($bb.Count) {
        $btn = @($bb[-1].Items | Where-Object { $_.Type -eq $TypeDesktop })
        Row 'BAR-DESKTOP' 'RUN' (V ($btn.Count -eq 1 -and ($tips -ccontains 'Desktop'))) ("Desktop buttons {0}; tooltip 'Desktop' {1}" -f $btn.Count, ($tips -ccontains 'Desktop'))
    }
    else { Row 'BAR-DESKTOP' 'RUN' 'FAIL' 'no drive bar build' }
    Row 'SAVED' 'RUN' (V ($saved -eq 1)) ("value after the exit of a run without it: '{0}'" -f $saved)

    # --- option off ----------------------------------------------------------------------------
    $off = Run-Instance 'off' 0 2 $true
    $mbOff = @(MenuBuilds $off)
    $any = @($off | ForEach-Object { $_.Items } | Where-Object { $_.Type -eq $TypeDesktop }).Count
    Row 'OPT-OFF' 'RUN' (V ($mbOff.Count -gt 0 -and @(BarBuilds $off).Count -gt 0 -and $any -eq 0)) ("Desktop items or buttons with the option off: {0}" -f $any)
    if ($mb.Count -and $mbOff.Count) {
        $a = @($mb[0].Items | Where-Object { $_.Type -ne $TypeDesktop } | ForEach-Object { '' + $_.Type + ':' + $_.Hot + ':' + $_.Text })
        $c = @($mbOff[0].Items | ForEach-Object { '' + $_.Type + ':' + $_.Hot + ':' + $_.Text })
        Row 'REGRESS' 'RUN' (V (($a -join '|') -ceq ($c -join '|'))) ("{0} other items with the option on, {1} off; identical {2}" -f $a.Count, $c.Count, (($a -join '|') -ceq ($c -join '|')))
    }
    else { Row 'REGRESS' 'RUN' 'FAIL' 'missing builds' }

    # --- opening -------------------------------------------------------------------------------
    Set-Opt 1
    $dump = $Root + '\dump_open.txt'
    $env:TC_PROBE_DRIVES_DUMP = $dump
    $id = 0
    try {
        $id = Start-Tc $StartDir
        $pos = Menu-Pick $id $dump $TypeDesktop
        Start-Sleep -Milliseconds 800
        $box = Take-Box $id 2
        $loc = Get-Loc $id
        Row 'OPEN-MENU' 'RUN' (V ($pos -ge 0 -and $null -eq $box -and (Norm $loc) -ceq (Norm $DesktopPath))) ("item position {0}; panel '{1}' (expected '{2}'); message {3}" -f $pos, (Esc $loc), (Esc $DesktopPath), $(if ($box) { $box } else { 'none' }))
        [void](Do-ChangeDir $id $StartDir); Start-Sleep -Milliseconds 600
        $locStart = Get-Loc $id
        Show-Bar $id $dump
        $b = Get-Builds (Read-Dump $dump); $bb1 = @(BarBuilds $b)
        $btn = @(); if ($bb1.Count) { $btn = @($bb1[-1].Items | Where-Object { $_.Type -eq $TypeDesktop } | ForEach-Object { $_.Idx }) }
        $loc2 = '<not run>'
        if ($btn.Count -eq 1) {
            Post-Cmd (Get-Main $id) (3500 + $btn[0])   # CM_DRIVEBAR_MIN + index: CDriveBar::Execute
            Start-Sleep -Milliseconds 1200; Sync $id
            $loc2 = Get-Loc $id
        }
        Row 'OPEN-BAR' 'RUN' (V ($btn.Count -eq 1 -and (Norm $locStart) -ceq $StartDir -and (Norm $loc2) -ceq (Norm $DesktopPath))) ("button idx {0}; panel before '{1}', after '{2}'" -f ($btn -join ','), (Esc $locStart), (Esc $loc2))
        $fatal = Fatal-Win $id
        if ($fatal) { Row 'RUN-open' 'RUN' 'FAIL' $fatal }
        Stop-Tc $id; $id = 0
    }
    finally {
        if ($id) { Kill-Mine $id }
        Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
    }

    # --- errors (seam TC_PROBE_DESKTOP_FILE) -------------------------------------------------------
    foreach ($case in @(@('ERR-NONE', ''), @('ERR-MISSING', ($Root + '\gone\Desktop')))) {
        $seam = $Root + '\desktop_' + $case[0] + '.txt'
        [IO.File]::WriteAllText($seam, $case[1], (New-Object Text.UTF8Encoding($false)))
        NewDir ($Root + '\gone')   # the parent exists: a shortened path would land there
        $dump = $Root + '\dump_' + $case[0] + '.txt'
        $env:TC_PROBE_DRIVES_DUMP = $dump
        $env:TC_PROBE_DESKTOP_FILE = $seam
        $id = 0
        try {
            $id = Start-Tc $StartDir
            $pos = Menu-Pick $id $dump $TypeDesktop
            $box = Take-Box $id 6
            $loc = Get-Loc $id
            $ok = $pos -ge 0 -and $null -ne $box -and (Norm $loc) -ceq $StartDir
            Row $case[0] 'RUN' (V $ok) ("seam '{0}'; item position {1}; message {2}; panel '{3}'" -f (Esc $case[1]), $pos, $(if ($box) { $box } else { 'none' }), (Esc $loc))
            $fatal = Fatal-Win $id
            if ($fatal) { Row ('RUN-' + $case[0]) 'RUN' 'FAIL' $fatal }
            Stop-Tc $id; $id = 0
        }
        finally {
            if ($id) { Kill-Mine $id }
            Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
            Remove-Item Env:\TC_PROBE_DESKTOP_FILE -ErrorAction SilentlyContinue
        }
    }

    # --- inside fld: (seam TC_PROBE_FLD_DUMP) -------------------------------------
    $fdump = $Root + '\dump_fld.txt'
    $env:TC_PROBE_FLD_DUMP = $fdump
    [IO.File]::WriteAllText($fdump + '.pick', '<none>', (New-Object Text.UTF8Encoding($false)))
    $id = 0
    try {
        $id = Start-Tc $StartDir
        if (-not (Fld-Root $id $fdump)) {
            foreach ($r in @('FLD-CPL', 'FLD-USER', 'FLD-DOCS', 'FLD-DRIVE', 'FLD-ZIP')) { Row $r 'RUN' 'NOT DRIVEN' 'no LIST line: the plug-in has no seam (Enter is never pressed without it)' }
        }
        else {
            # Control Panel (root): stays in fld:
            $e = Fld-Enter $id $fdump $NameCpl
            Start-Sleep -Milliseconds 1500
            $loc = Get-Loc $id
            $ok = $null -ne $e -and $e.Action -ceq 'fld' -and $loc -ceq 'fld:'
            Row 'FLD-CPL' 'RUN' (V $ok) ("EXEC {0}; panel '{1}'" -f $(if ($e) { "action=$($e.Action) attrs=$($e.Attrs) path=$(Esc $e.Path)" } else { 'none' }), (Esc $loc))
            # the user's folder (root): its disk path
            [void](Fld-Root $id $fdump)
            $e = Fld-Enter $id $fdump $NameUser
            Start-Sleep -Milliseconds 1500
            $loc = Get-Loc $id
            $ok = $null -ne $e -and $e.Action -ceq 'disk' -and (Norm $loc) -ceq (Norm $env:USERPROFILE)
            Row 'FLD-USER' 'RUN' (V $ok) ("EXEC {0}; panel '{1}' (expected '{2}')" -f $(if ($e) { "action=$($e.Action) attrs=$($e.Attrs) path=$(Esc $e.Path)" } else { 'none' }), (Esc $loc), (Esc $env:USERPROFILE))
            # Documents: at the root (Windows 11) or under This PC
            [void](Fld-Root $id $fdump)
            $e1 = $null
            if ($NameDocsRoot) { $e = Fld-Enter $id $fdump $NameDocsRoot }
            else {
                $e1 = Fld-Enter $id $fdump $NameThisPC
                Start-Sleep -Milliseconds 1500; Sync $id
                $e = $null
                if ($null -ne $e1 -and $e1.Action -ceq 'fld') { $e = Fld-Enter $id $fdump $NameDocsPC }
            }
            Start-Sleep -Milliseconds 1500
            $loc = Get-Loc $id
            $ok = $null -ne $e -and $e.Action -ceq 'disk' -and (Norm $loc) -ceq (Norm $DocsPath)
            Row 'FLD-DOCS' 'RUN' (V $ok) ("{0}Documents: {1}; panel '{2}' (expected '{3}')" -f $(if ($e1) { "This PC: action=$($e1.Action); " } else { 'at the root; ' }), $(if ($e) { "action=$($e.Action) attrs=$($e.Attrs) path=$(Esc $e.Path)" } else { 'none' }), (Esc $loc), (Esc $DocsPath))
            # This PC (virtual, stays) -> the system drive (disk)
            [void](Fld-Root $id $fdump)
            $e1 = Fld-Enter $id $fdump $NameThisPC
            Start-Sleep -Milliseconds 1500; Sync $id
            $loc1 = Get-Loc $id
            $e = $null
            if ($null -ne $e1 -and $e1.Action -ceq 'fld' -and $loc1 -ceq 'fld:') { $e = Fld-Enter $id $fdump $NameDriveC }
            Start-Sleep -Milliseconds 1500
            $loc = Get-Loc $id
            $exp = $env:SystemDrive + [string][char]92
            $ok = $null -ne $e1 -and $e1.Action -ceq 'fld' -and $loc1 -ceq 'fld:' -and $null -ne $e -and $e.Action -ceq 'disk' -and $loc -ceq $exp
            Row 'FLD-DRIVE' 'RUN' (V $ok) ("This PC: {0}, panel '{1}'; {2}: {3}; panel '{4}' (expected '{5}')" -f $(if ($e1) { "action=$($e1.Action)" } else { 'none' }), (Esc $loc1), (Esc $NameDriveC), $(if ($e) { "action=$($e.Action) path=$(Esc $e.Path)" } else { 'none' }), (Esc $loc), (Esc $exp))
            # a zip archive (a shell folder whose path is a file): stays in fld:
            if ($NameZip) {
                [void](Fld-Root $id $fdump)
                $e = Fld-Enter $id $fdump $NameZip
                Start-Sleep -Milliseconds 1500
                $loc = Get-Loc $id
                $ok = $null -ne $e -and $e.Action -ceq 'fld' -and $loc -ceq 'fld:'
                Row 'FLD-ZIP' 'RUN' (V $ok) ("'{0}': {1}; panel '{2}'" -f (Esc $NameZip), $(if ($e) { "action=$($e.Action) attrs=$($e.Attrs) path=$(Esc $e.Path)" } else { 'none' }), (Esc $loc))
            }
            else { Row 'FLD-ZIP' 'RUN' 'NOT DRIVEN' 'no zip archive on the desktop (the probe never writes there)' }
        }
        $fatal = Fatal-Win $id
        if ($fatal) { Row 'RUN-fld' 'RUN' 'FAIL' $fatal }
        Stop-Tc $id; $id = 0
    }
    finally {
        if ($id) { Kill-Mine $id }
        Remove-Item Env:\TC_PROBE_FLD_DUMP -ErrorAction SilentlyContinue
    }
    $skipped = @(Fld-Lines $fdump | Where-Object { $_.StartsWith('EXEC ') -and $_.EndsWith('action=skipped') }).Count
    $acted = @(Fld-Lines $fdump | Where-Object { $_.StartsWith('EXEC ') -and -not $_.EndsWith('action=skipped') } | ForEach-Object { $x = Fld-Exec $_; if ($x) { $x.Name + '=' + $x.Action } })
    Out ("fld: items skipped {0}; acted upon: {1}" -f $skipped, ($acted -join ', '))
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace); Row 'PROBE' 'ERROR' 'FAIL' $_.Exception.Message }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    foreach ($v in @('TC_PROBE_DRIVES_DUMP', 'TC_PROBE_DESKTOP_FILE', 'TC_PROBE_FLD_DUMP')) { Remove-Item ('Env:\' + $v) -ErrorAction SilentlyContinue }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
