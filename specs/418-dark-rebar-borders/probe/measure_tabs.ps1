# Measurement (step 3): the rows from the top of the rebar to the left panel's directory line, Default vs Dark.
# MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Exe, [Parameter(Mandatory = $true)][string]$Repo, [string]$OutFile, [string]$CapDir)
$ErrorActionPreference = 'Stop'
if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $Repo 'specs\416-fluent-icon-set\probe\capture416_lib.ps1')
$Root = $TempRoot + '\tcmtabs'
$StartDir = $Root + '\start'
$CfgKey = "$RegKey\Settings\Configuration"
[void][IO.Directory]::CreateDirectory($CapDir)
function Start-At([string]$ExePath) {
    $a = @('-t', 'MTABS', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $ExePath -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 2500
    return $p.Id
}
function Rel([IntPtr]$main, [IntPtr]$h) {
    $r = New-Object Cap416+RECT; [void][Cap416]::GetWindowRect($h, [ref]$r)
    $o = New-Object Cap416+POINT; [void][Cap416]::ClientToScreen($main, [ref]$o)
    return @(($r.left - $o.x), ($r.top - $o.y), ($r.right - $o.x), ($r.bottom - $o.y))
}
function Runs([Drawing.Bitmap]$b, [int]$x, [int]$y0, [int]$y1) {
    $out = @(); $prev = $null; $start = $y0
    for ($y = $y0; $y -le $y1; $y++) {
        $c = $b.GetPixel($x, $y).ToArgb() -band 0xFFFFFF
        if ($c -ne $prev) { if ($null -ne $prev) { $out += ('{0}-{1}:{2:X6}' -f $start, ($y - 1), $prev) }; $prev = $c; $start = $y }
    }
    $out += ('{0}-{1}:{2:X6}' -f $start, $y1, $prev)
    return ($out -join ' ')
}
$backup = Join-Path $env:TEMP 'tcmtabs_backup.reg'
$existed = Backup-Reg $backup
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("measure_tabs on {0}" -f $Exe)
    foreach ($theme in 0, 1) {
        & reg.exe add $CfgKey /v 'Theme Mode' /t REG_DWORD /d $theme /f | Out-Null
        $id = Start-At $Exe
        [void](Serve $id 8)
        $main = Get-Main $id
        [void][Drv098f]::Send($main, 0, 0, 0, 20000)
        $full = [Cap416]::Capture($main, $false)
        Save-Png $full (Join-Path $CapDir ("theme{0}_full.png" -f $theme))
        $rebar = @(Get-Desc $main 'ReBarWindow32')[0]
        $tabs = @([Cap416]::Kids($main) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::GetDlgCtrlID($_) -eq 958 } | Sort-Object { (Rel $main $_)[0] })
        $dirs = @([Cap416]::Kids($main) | Where-Object { [Cap416]::IsWindowVisible($_) -and [Cap416]::GetDlgCtrlID($_) -eq 952 } | Sort-Object { (Rel $main $_)[0] })
        $rr = Rel $main $rebar; $tr = Rel $main $tabs[0]; $dr = Rel $main $dirs[0]
        Out ("theme {0}: rebar {1}; tab strip {2}; directory line {3} (client coordinates l,t,r,b)" -f $theme, ($rr -join ','), ($tr -join ','), ($dr -join ','))
        $y0 = [Math]::Max(0, $rr[1] - 2); $y1 = $dr[3] + 2
        Out ("  x={0} (active tab): {1}" -f ($tr[0] + 40), (Runs $full ($tr[0] + 40) $y0 $y1))
        Out ("  x={0} (empty strip): {1}" -f ($tr[2] - 40), (Runs $full ($tr[2] - 40) $y0 $y1))
        $full.Dispose()
        Stop-Tc $id
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
