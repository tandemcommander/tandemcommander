<#
.SYNOPSIS
    Feature 170 probe: the program installed in a folder whose name is outside the system code
    page (e.g. a per-user install under a profile named in another script) - do the plug-ins and
    the language modules load?

.DESCRIPTION
    Copies the build tree (-Build, without Intermediate / saltests) to %TEMP%\tc170\<folder>
    and starts that copy. Rows:
      <case> START  the main window appears; its title
      <case> LANG   the language from -Lang is loaded (a Czech word in the File menu's place: the
                    title of the Change Directory dialog, command 862)
      <case> PLUGIN a plug-in's file system opens: Change Directory to reg:\HKEY_CURRENT_USER (the
                    Registry Editor) - the panel's path afterwards
      <case> VIEWER F3 on a .md file opens the Markdown Viewer plug-in (its window class)
    Cases: ASCII (control, a plain folder name), CYR (a Cyrillic letter, outside code page 1250),
    CJK (a Chinese letter).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lang = 'czech',
    [string]$ShotDir
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\124-regedt-key-text\probe\shotocr_lib.ps1')
$Root = $TempRoot + '\tc170'
$StartDir = $Root + '\start'
$SrcTree = Split-Path -Parent $Exe

function Copy-Tree([string]$Dst) {
    foreach ($e in [IO.Directory]::GetFileSystemEntries($SrcTree)) {
        $n = [IO.Path]::GetFileName($e)
        if (@('Intermediate', 'saltests') -contains $n -or $n -like '*.pdb' -or $n -like '*.ilk') { continue }
        if ([IO.Directory]::Exists($e)) {
            & robocopy.exe $e ($Dst + '\' + $n) /E /NFL /NDL /NJH /NJS /NP /XD Intermediate /XF *.pdb *.ilk | Out-Null
        }
        else { [IO.File]::Copy($e, $LP + $Dst + '\' + $n, $true) }
    }
}

function Run-Case([string]$Case, [string]$Folder) {
    if (-not (Want $Case)) { return }
    $dst = $Root + '\' + $Folder
    NewDir $dst
    Copy-Tree $dst
    $exe = $dst + '\tandemcommander.exe'
    $d = $Root + '\' + $Case + '_files'; NewDir $d
    [IO.File]::WriteAllText($LP + $d + '\b_doc.md', "# Feature 170`r`n")
    $id = 0; $before = Reports
    try {
        # first a start of our own: what the copy shows (a message box, nothing) in 20 s
        $p = Start-Process -FilePath $exe -ArgumentList @('-t', 'T170', '-l', ('"{0}"' -f $d), '-r', ('"{0}"' -f $StartDir)) -PassThru
        [void]$Started.Add($p.Id); $script:Procs[$p.Id] = $p
        $seen = @(); $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 20 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) {
            foreach ($h in (Get-Tops $p.Id)) { $w = WinDesc $h; if ($seen -notcontains $w) { $seen += $w } }
            Start-Sleep -Milliseconds 300
        }
        $hasMain = (Get-Main $p.Id) -ne [IntPtr]::Zero
        $alive = Test-Alive $p.Id
        if (-not $hasMain) {
            Row $Case 'START' 'FAIL' ("installed in '{0}': no main window in 20 s; process alive {1}, exit {2}; windows shown: {3}" -f (Esc $dst), $alive, $(if ($alive) { '-' } else { ExitCodeOf $p.Id }), $(if ($seen.Count) { $seen -join ' || ' } else { 'none' }))
            if ($alive) { Stop-Process -Id $p.Id -Force }
            return
        }
        $id = $p.Id
        [void][Drv098f]::Send((Get-Main $id), 0, 0, 0, 20000); Start-Sleep -Milliseconds 1500
        Row $Case 'START' 'PASS' ("installed in '{0}'; title '{1}'" -f (Esc $dst), (Esc ([Drv098f]::Txt((Get-Main $id)))))
        if ($ShotDir) {   # a picture of the main window (the toolbar icons come from toolbars\*.svg)
            $png = Join-Path $ShotDir ($Case + '_main.png')
            Row $Case 'PICTURE' 'INFO' ("main window captured {0}: {1}" -f [Shot124]::Capture((Get-Main $id), $png), $png)
        }
        $r0 = Serve $id 10
        # the language: the caption of the Change Directory dialog
        $cd = Open-ByCmd $id 862 10
        $cap = $(if ($cd -ne [IntPtr]::Zero) { [Drv098f]::Txt($cd) } else { '' })
        if ($cd -ne [IntPtr]::Zero) { Close-Win $cd }
        $isCzech = $cap -ne '' -and $cap -ne 'Change Directory'
        Row $Case 'LANG' (V $isCzech) ("Change Directory dialog caption '{0}' (English 'Change Directory' = the {1} module was not loaded); windows at start: {2}" -f (Esc $cap), $Lang, (Msgs $r0))
        # a plug-in file system
        [void](Do-ChangeDir $id 'reg:\HKEY_CURRENT_USER')
        $r = Serve $id 15 @(1)
        $title = [Drv098f]::Txt((Get-Main $id))
        $inReg = $title -match 'HKEY_CURRENT_USER'
        Row $Case 'PLUGIN' (V $inReg) ("after Change Directory to reg:\HKEY_CURRENT_USER the title is '{0}'; windows: {1}" -f (Esc $title), (Msgs $r))
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc170_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d ($Lang + '.slg') /f | Out-Null
    Out ("install_path_probe (feature 170), expect: {0}, language {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    Run-Case 'ASCII' 'TandemPlain'
    Run-Case 'CZ' ('Tandem ' + [string][char]0x010C + 'e' + [string][char]0x0161 + 'tina')   # inside code page 1250
    Run-Case 'CYR' ('Tandem ' + [string][char]0x0416 + [string][char]0x0443 + 'k')
    Run-Case 'CJK' ('Tandem ' + [string][char]0x4E2D + [string][char]0x6587)
    # FRESH: the first start after an update - plugins.ver is processed (SearchForAddedSPLs,
    # RemoveNoLongerExistingPlugins): every registered plug-in must stay registered
    if (Want 'FRESH') {
        $plugKey = 'HKCU:\Software\Tandem Commander\0.1\Plugins'
        $n0 = @(Get-ChildItem $plugKey -ErrorAction SilentlyContinue).Count
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Plugins.ver Version (x64)' /t REG_DWORD /d 0 /f | Out-Null
        Run-Case 'FRESH' ('Tandem ' + [string][char]0x0416 + 'f')
        $n1 = @(Get-ChildItem $plugKey -ErrorAction SilentlyContinue).Count
        $ver = (Get-ItemProperty 'HKCU:\Software\Tandem Commander\0.1\Configuration' -Name 'Plugins.ver Version (x64)' -ErrorAction SilentlyContinue).'Plugins.ver Version (x64)'
        Row 'FRESH' 'PLUGINS' (V ($n1 -eq $n0 -and $n0 -gt 0 -and $ver -gt 0)) ("registered plug-ins before {0}, after the first start {1}; plugins.ver version stored {2} (0 = not processed)" -f $n0, $n1, $ver)
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 800
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
if ($Expect -eq 'before') { exit 0 }
exit $nf
