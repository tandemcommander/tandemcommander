# Feature 367: mutants of the rules in salisotrack.h - each must fail saltests checks. Restores the header.
param([string]$Repo = 'E:\Projects\tandemcommander', [string[]]$Only)
$ErrorActionPreference = 'Stop'
$h = Join-Path $Repo 'src\common\salisotrack.h'
$orig = [IO.File]::ReadAllText($h)
$mutants = @(
    @{ Name = 'form1-as-unknown'; From = '? SAL_ISO_SECTOR_FORM2 : SAL_ISO_SECTOR_FORM1;'; To = '? SAL_ISO_SECTOR_FORM2 : SAL_ISO_SECTOR_UNKNOWN;' },
    @{ Name = 'stream-trigger-dropped'; From = 'if (startsInStream || firstSectorForm2)'; To = 'if (firstSectorForm2)' },
    @{ Name = 'xa-trigger-dropped'; From = 'return xaKnown && (xaAttrs & SAL_ISO_XA_FORM2) != 0 && (xaAttrs & SAL_ISO_XA_DIRECTORY) == 0;'; To = 'return false;' },
    @{ Name = 'unknown-counts-whole'; From = '(form == SAL_ISO_SECTOR_FORM1 && (!last'; To = '(form != SAL_ISO_SECTOR_FORM2 && (!last' },
    @{ Name = 'run-never-stops'; From = 'if (!s.Stopped && whole)'; To = 'if (whole)' },
    @{ Name = 'partial-last-whole'; From = '(!last || s.LastLen == SAL_ISO_FILE_SECTOR_SIZE)'; To = '(true)' },
    @{ Name = 'size-last-full'; From = '+ (others - 1) * SAL_ISO_FILE_SECTOR_SIZE + s.LastLen;'; To = '+ others * SAL_ISO_FILE_SECTOR_SIZE;' },
    @{ Name = 'mixed-as-form2'; From = 'return s.Form2 == s.Sectors ? SAL_ISO_SCAN_FORM2 : SAL_ISO_SCAN_MIXED;'; To = 'return SAL_ISO_SCAN_FORM2;' },
    # review 1: a Form 1 subheader trusted without its EDC / empty rest
    @{ Name = 'form1-always-whole'; From = 'if (raw == nullptr || pay < 0 || len < pay + SAL_ISO_FORM2_PAYLOAD)' + "`r`n" + '        return false;'; To = 'if (raw == nullptr || pay < 0 || len < pay + SAL_ISO_FORM2_PAYLOAD)' + "`r`n" + '        return false;' + "`r`n" + '    return true;' },
    @{ Name = 'edc-ignored'; From = 'if (SalIsoCdEdc(raw + edcFrom, edcAt - edcFrom) == stored)'; To = 'if (false)' },
    @{ Name = 'empty-rest-ignored'; From = '        if (raw[i] != 0)' + "`r`n" + '            return false;'; To = '        if (raw[i] != 0 || true)' + "`r`n" + '            return false;' }
)
if ($Only) {
    $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $mutants = @($mutants | Where-Object { $Only -contains $_.Name })
}
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
