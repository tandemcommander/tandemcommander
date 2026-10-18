# Creates a remembered (persistent, not connected) entry HKCU\Network\V to an unreachable TEST-NET server.
# Values copied from the entry WNetAddConnection2W(CONNECT_UPDATE_PROFILE) wrote for W:.
param([string]$Remote = '\\192.0.2.1\x')
$k = 'HKCU:\Network\V'
if (Test-Path $k) { throw 'HKCU\Network\V already exists - not touching it' }
$src = Get-Item 'HKCU:\Network\W'
New-Item -Path $k | Out-Null
foreach ($n in $src.GetValueNames()) {
    $v = $src.GetValue($n)
    if ($n -eq 'RemotePath') { $v = $Remote }
    New-ItemProperty -Path $k -Name $n -Value $v -PropertyType $src.GetValueKind($n) | Out-Null
}
Get-ItemProperty $k | Select-Object RemotePath, ProviderName, ConnectionType, DeferFlags
