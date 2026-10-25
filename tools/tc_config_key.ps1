<#
.SYNOPSIS
    The registry keys of Tandem Commander's configuration, defined once for probes and tools
    (feature 343). Dot-source it: . (Join-Path <repo> 'tools\tc_config_key.ps1')

.DESCRIPTION
    Since feature 343 the configuration root is version-free: HKCU\Software\Tandem Commander\Settings.
    Versions 0.1.0 - 0.1.10 used HKCU\Software\Tandem Commander\0.1; the program copies it once into
    Settings at its first start and keeps it unchanged as a backup.

    A probe that protects the user's configuration backs up and restores the parent key
    ($TcParentKeyReg), which holds both roots and their sibling keys (backup, corrupted, migrating).

    Until a 0.2.0-or-later build has kept a configuration on a machine, only 0.1 holds one. A probe
    that tweaks the configuration before the program starts must then copy 0.1 to Settings after its
    backup (what the program does at its first start) - Copy-TcLegacyToSettings. The shared library
    specs\098-long-path-overruns\probe\fix_probe_lib.ps1 does it in Backup-Reg; older stand-alone
    probes with their own backup do not.
#>

$TcParentKeyName = 'Software\Tandem Commander'
$TcConfigKeyName = $TcParentKeyName + '\Settings'
$TcLegacyKeyName = $TcParentKeyName + '\0.1'

# reg.exe form (HKCU\...)
$TcParentKeyReg = 'HKCU\' + $TcParentKeyName
$TcConfigKeyReg = 'HKCU\' + $TcConfigKeyName
$TcLegacyKeyReg = 'HKCU\' + $TcLegacyKeyName

# PowerShell registry provider form (HKCU:\...)
$TcParentKeyPs = 'HKCU:\' + $TcParentKeyName
$TcConfigKeyPs = 'HKCU:\' + $TcConfigKeyName
$TcLegacyKeyPs = 'HKCU:\' + $TcLegacyKeyName

# .reg file form ([HKEY_CURRENT_USER\...])
$TcConfigKeyRegFile = 'HKEY_CURRENT_USER\' + $TcConfigKeyName
$TcLegacyKeyRegFile = 'HKEY_CURRENT_USER\' + $TcLegacyKeyName

# sibling keys of a root: <root>.backup.63A7CD13 (crash-time backup), <root>.corrupted.63A7CD13
# (a damaged root moved aside), Settings.migrating.63A7CD13 (the migration's side key)
$TcKeySuffix = '.63A7CD13'

# copies 0.1 to Settings when only 0.1 holds a configuration (call it after backing up the parent key)
function Copy-TcLegacyToSettings {
    & cmd.exe /c "reg query `"$TcConfigKeyReg\Configuration`" >nul 2>&1 || (reg query `"$TcLegacyKeyReg\Configuration`" >nul 2>&1 && reg copy `"$TcLegacyKeyReg`" `"$TcConfigKeyReg`" /s /f >nul 2>&1)"
}
