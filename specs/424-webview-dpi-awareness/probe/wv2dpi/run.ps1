param([string]$Out)
$exe = Join-Path $PSScriptRoot 'wv2dpi.exe'
$lines = @()
foreach ($mode in 'system', 'pmv2', 'scoped') {
    $log = Join-Path $PSScriptRoot "out_$mode.txt"
    $p = Start-Process -FilePath $exe -ArgumentList $mode -RedirectStandardOutput $log -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 8
    $lines += "== mode $mode (pid $($p.Id))"
    $kids = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = {0}" -f $p.Id) | Where-Object { $_.Name -eq 'msedgewebview2.exe' })
    foreach ($k in $kids) {
        $sw = @([regex]::Matches([string]$k.CommandLine, '--embedded-browser-webview-dpi-awareness=[^ ]*') | ForEach-Object { $_.Value })
        $lines += "browser $($k.ProcessId): $($sw -join ' ')"
    }
    if (-not $kids.Count) { $lines += 'no browser process' }
    $p.WaitForExit(20000) | Out-Null
    $lines += (Get-Content $log)
}
$lines | Set-Content $Out
$lines
