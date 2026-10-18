param([string]$Drive = 'W:', [int]$Minutes = 25)
$dir = $PSScriptRoot
$log = Join-Path $dir 'idle_monitor.log'
$exe = Join-Path $dir 'measure_idle.exe'
for ($i = 0; $i -le $Minutes; $i++) {
    $t = Get-Date -Format 'HH:mm:ss'
    $l = (& $exe light $Drive) -join ' '
    $m = Get-SmbMapping -LocalPath $Drive -ErrorAction SilentlyContinue
    $c = Get-SmbConnection -ErrorAction SilentlyContinue | Where-Object { $_.ServerName -eq 'localhost' }
    $tmp = Join-Path $dir 'netuse_idle.txt'
    cmd /c "chcp 65001 >nul & net use > `"$tmp`" 2>&1"
    $nu = (Get-Content -LiteralPath $tmp -Encoding UTF8 | Where-Object { $_ -match " $Drive " }) -join ' '
    $nu = ($nu -split '\s+')[0]
    Add-Content -LiteralPath $log -Encoding UTF8 -Value ("{0} min={1} {2} | SmbMapping.Status={3} | SmbConnections(localhost)={4} | net use status='{5}'" -f $t, $i, $l, $m.Status, @($c).Count, $nu)
    if ($i -lt $Minutes) { Start-Sleep -Seconds 60 }
}
Add-Content -LiteralPath $log -Encoding UTF8 -Value 'DONE'
