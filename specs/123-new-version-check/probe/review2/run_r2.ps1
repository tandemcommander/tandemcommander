# Review 2: runs the timing scenarios of r2_http.exe (servers must be running: updserver.py on 8341,
# rawsrv.py on 8342). Output: r2_results.txt
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot
$out = Join-Path $PSScriptRoot 'r2_results.txt'
Remove-Item $out -ErrorAction SilentlyContinue
function Run($a) {
    $r = & .\r2_http.exe @a 2>&1
    $r | Out-File -Append -Encoding utf8 $out
}
Run @('127.0.0.1', '8341', '/latest/hang', '0')
Run @('127.0.0.1', '8341', '/latest/slow', '0')
Run @('127.0.0.1', '8342', '/hdrdrip', '0')
Run @('127.0.0.1', '8342', '/bodydrip', '0')
Run @('127.0.0.1', '8342', '/noread', '0')
foreach ($p in '/nocl', '/nocl-cut', '/chunkcut', '/chunkcut2', '/clhuge', '/clshort', '/clzero', '/100') {
    Run @('127.0.0.1', '8342', $p, '0')
}
Run @('127.0.0.1', '8399', '/closedport', '0')
Run @('10.255.255.1', '443', '/blackhole', '1')
Run @('10.255.255.1', '80', '/blackhole-plain', '0')
Run @('tc-review2-nonexistent.invalid', '443', '/dns', '1')
# cancels
Run @('127.0.0.1', '8341', '/latest/hang', '0', '1000')
Run @('127.0.0.1', '8342', '/bodydrip', '0', '2000')
Run @('127.0.0.1', '8342', '/hdrdrip', '0', '2000')
Run @('10.255.255.1', '443', '/blackhole', '1', '1000')
Run @('tc-review2-nonexistent.invalid', '443', '/dns', '1', '5')
'ALL DONE' | Out-File -Append -Encoding utf8 $out
