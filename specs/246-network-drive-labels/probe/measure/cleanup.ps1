# Removes every mapping, remembered connection, MountPoints2 key and share folder this measurement created,
# then verifies the state equals the baseline.
$dir = $PSScriptRoot
$exe = Join-Path $dir 'measure.exe'
foreach ($l in 'W:', 'V:', 'U:', 'T:') { & $exe unmap $l 1 1 }
foreach ($l in 'W', 'V', 'U', 'T') { if (Test-Path "HKCU:\Network\$l") { Remove-Item "HKCU:\Network\$l" -Recurse; "removed HKCU\Network\$l" } }
$mp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2'
$baseline = @('##192.168.0.50#Data', '##192.168.0.50#Obchod', '##localhost#C$',
    '##localhost#C$#Users#pavel#AppData#Local#Temp#tc109#dc#renet#A',
    '##localhost#C$#Users#pavel#AppData#Local#Temp#tc112#dc#own-F3_net')
Get-ChildItem $mp | Where-Object { $_.PSChildName -like '##*' -and $baseline -notcontains $_.PSChildName } | ForEach-Object {
    $n = $_.PSChildName
    if ($n -like '*246-measure*' -or $n -eq '##192.0.2.1#x' -or $n -eq '##localhost#E$') {
        Remove-Item -LiteralPath $_.PSPath -Recurse
        "removed MP2 $n"
    } else { "NOT removing unexpected MP2 key $n" }
}
foreach ($f in 'share', "sh#$([char]0x17E) ar", 'dini', 'gone') {
    $p = Join-Path $dir $f
    if (Test-Path -LiteralPath $p) {
        attrib -r $p
        Get-ChildItem -LiteralPath $p -Force | ForEach-Object { attrib -s -h -r $_.FullName }
        Remove-Item -LiteralPath $p -Recurse -Force
        "removed folder $f"
    }
}
'--- verification ---'
$now = @(Get-ChildItem $mp | Where-Object { $_.PSChildName -like '##*' } | ForEach-Object { $_.PSChildName })
"MP2 ## keys equal baseline: $((Compare-Object $baseline $now) -eq $null)"
"HKCU\Network exists: $(Test-Path HKCU:\Network); subkeys: $((Get-ChildItem HKCU:\Network).Count)"
"GetLogicalDrives: $([Environment]::GetLogicalDrives() -join ',')"
"SmbMapping count: $(@(Get-SmbMapping -ErrorAction SilentlyContinue).Count)"
& $exe enum
cmd /c "chcp 65001 >nul & net use"
