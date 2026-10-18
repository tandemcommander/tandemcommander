param([string]$Tag = '')
$ErrorActionPreference = 'Continue'
$dir = $PSScriptRoot
$log = Join-Path $dir 'snap.log'
function W($s) { Add-Content -LiteralPath $log -Value $s -Encoding UTF8; Write-Output $s }
W "=== snapshot $Tag $(Get-Date -Format o)"
$mp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2'
Get-ChildItem $mp | Where-Object { $_.PSChildName -like '##*' } | ForEach-Object {
    $k = $_
    $vals = @()
    foreach ($n in $k.GetValueNames()) {
        $v = $k.GetValue($n)
        $kind = $k.GetValueKind($n)
        $vals += "$n=[$kind]'$v'"
    }
    $sub = ($k.GetSubKeyNames() -join ',')
    W ("MP2 key '{0}' values: {1} subkeys: {2}" -f $k.PSChildName, ($vals -join '; '), $sub)
}
if (Test-Path HKCU:\Network) {
    Get-ChildItem HKCU:\Network | ForEach-Object {
        $k = $_
        $vals = @()
        foreach ($n in $k.GetValueNames()) { $vals += "$n=[$($k.GetValueKind($n))]'$($k.GetValue($n))'" }
        W ("HKCU\Network\{0}: {1}" -f $k.PSChildName, ($vals -join '; '))
    }
    W "HKCU\Network exists, subkeys=$((Get-ChildItem HKCU:\Network).Count)"
} else { W 'HKCU\Network missing' }
$t = Measure-Command { $m = Get-SmbMapping -ErrorAction SilentlyContinue }
foreach ($x in $m) { W ("SmbMapping {0} {1} Status={2} [{3:N0} ms]" -f $x.LocalPath, $x.RemotePath, $x.Status, $t.TotalMilliseconds) }
if (-not $m) { W "SmbMapping: none [$([int]$t.TotalMilliseconds) ms]" }
$t = Measure-Command { $c = Get-CimInstance Win32_NetworkConnection -ErrorAction SilentlyContinue }
foreach ($x in $c) { W ("Win32_NetworkConnection {0} {1} ConnectionState={2} Status={3} Persistent={4} [{5:N0} ms]" -f $x.LocalName, $x.RemoteName, $x.ConnectionState, $x.Status, $x.Persistent, $t.TotalMilliseconds) }
$tmp = Join-Path $dir 'netuse.txt'
$t = Measure-Command { cmd /c "chcp 65001 >nul & net use > `"$tmp`" 2>&1" }
W "net use [$([int]$t.TotalMilliseconds) ms]:"
Get-Content -LiteralPath $tmp -Encoding UTF8 | Where-Object { $_ -match '\\\\' -or $_ -match '^\S+\s+[A-Z]:' } | ForEach-Object { W "  $_" }
