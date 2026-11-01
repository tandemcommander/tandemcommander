# Feature 366: mutants of the rules in salisotrack.h - each must fail saltests checks. Restores the header.
param([string]$Repo = 'E:\Projects\tandemcommander')
$ErrorActionPreference = 'Stop'
$h = Join-Path $Repo 'src\common\salisotrack.h'
$orig = [IO.File]::ReadAllText($h)
$mutants = @(
    @{ Name = 'form1-bit-ignored'; From = '(attrs & SAL_ISO_XA_FORM2) != 0 && (attrs & SAL_ISO_XA_FORM1) == 0'; To = '(attrs & SAL_ISO_XA_FORM2) != 0' },
    @{ Name = 'header-check-dropped'; From = 'return at >= 0 && at == sectorHeaderSize &&'; To = 'return at >= 0 &&' },
    @{ Name = 'size-rounds-down'; From = 'unsigned long long sectors = dataLength / SAL_ISO_FILE_SECTOR_SIZE + (dataLength % SAL_ISO_FILE_SECTOR_SIZE != 0 ? 1 : 0);'; To = 'unsigned long long sectors = dataLength / SAL_ISO_FILE_SECTOR_SIZE;' },
    @{ Name = 'span-always-2048'; From = 'unsigned long long sectors = size / (unsigned long long)bytesPerSector;'; To = 'unsigned long long sectors = size / SAL_ISO_FILE_SECTOR_SIZE;' },
    @{ Name = 'xa-pad-ignored'; From = 'long long su = 33 + idLen + (idLen % 2 == 0 ? 1 : 0);'; To = 'long long su = 33 + idLen;' }
)
try {
    foreach ($m in $mutants) {
        if (-not $orig.Contains($m.From)) { "$($m.Name): PATTERN NOT FOUND"; continue }
        [IO.File]::WriteAllText($h, $orig.Replace($m.From, $m.To), (New-Object Text.UTF8Encoding($true)))
        $b = & (Join-Path $Repo 'build.cmd') 2>&1 | Select-String 'BUILD SUCCEEDED|BUILD FAILED' | Select-Object -Last 1
        $t = & (Join-Path $Repo 'build\tandemcommander\Debug_x64\saltests\saltests.exe') 2>&1 | Select-String '^saltests: \d+ checks' | Select-Object -Last 1
        "$($m.Name): $b; $t"
    }
}
finally {
    [IO.File]::WriteAllText($h, $orig, (New-Object Text.UTF8Encoding($true)))
}
