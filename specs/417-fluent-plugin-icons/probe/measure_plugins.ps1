# Measurement before the feature (run on main): do the plug-in icons follow the icon set?
# Starts the program with the Plugins bar shown, in Fluent 2 and Classic, Light and Dark, and compares the
# Plugins bar (the third row of the top rebar: menu, top toolbar, Plugins bar) between the two sets.
# MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Exe, [Parameter(Mandatory = $true)][string]$Repo, [string]$OutFile, [string]$CapDir)
$ErrorActionPreference = 'Stop'
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $Repo 'specs\416-fluent-icon-set\probe\capture416_lib.ps1')
$Root = $TempRoot + '\tcmeasure'
$StartDir = $Root + '\start'
$CfgKey = "$RegKey\Settings\Configuration"
[void][IO.Directory]::CreateDirectory($CapDir)

function Start-At([string]$ExePath) {
    $a = @('-t', 'MEASURE', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $ExePath -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 2500
    return $p.Id
}
function Grab-Bars([int]$Id, [string]$Tag) {
    $main = Get-Main $Id
    [void][Drv098f]::Send($main, 0, 0, 0, 20000)
    $full = [Cap416]::Capture($main, $false)
    $rebar = @(Get-Desc $main 'ReBarWindow32')[0]
    $bars = @(Get-Desc $rebar 'WinLib Universal Window2')
    $out = @()
    for ($i = 0; $i -lt $bars.Count; $i++) {
        $b = [Cap416]::Crop($full, $main, $bars[$i])
        Save-Png $b (Join-Path $CapDir ("{0}_bar{1}.png" -f $Tag, $i))
        $out += $b
    }
    $full.Dispose()
    return , $out
}
$backup = Join-Path $env:TEMP 'tcmeasure_backup.reg'
$existed = Backup-Reg $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("measure_plugins on {0}" -f $Exe)
    $caps = @{}
    foreach ($theme in 0, 1) {
        foreach ($set in 0, 1) {
            & reg.exe add $CfgKey /v 'Theme Mode' /t REG_DWORD /d $theme /f | Out-Null
            & reg.exe add $CfgKey /v 'Toolbar Icon Set' /t REG_DWORD /d $set /f | Out-Null
            & reg.exe add $CfgKey /v 'Show Plugins Bar' /t REG_DWORD /d 1 /f | Out-Null
            $id = Start-At $Exe
            [void](Serve $id 8)
            $tag = "t{0}_set{1}" -f $theme, $set
            $caps[$tag] = Grab-Bars $id $tag
            Out ("{0}: {1} bars: {2}" -f $tag, $caps[$tag].Count, (($caps[$tag] | ForEach-Object { [Cap416]::Stats($_) }) -join ' | '))
            Stop-Tc $id
        }
        $f = $caps["t{0}_set0" -f $theme]; $c = $caps["t{0}_set1" -f $theme]
        for ($i = 0; $i -lt [Math]::Min($f.Count, $c.Count); $i++) {
            Out ("theme {0} bar {1}: Fluent 2 vs Classic differ {2} px" -f $theme, $i, [Cap416]::Diff($f[$i], $c[$i]))
        }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    Out ("registry restored+identical: {0}" -f $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
