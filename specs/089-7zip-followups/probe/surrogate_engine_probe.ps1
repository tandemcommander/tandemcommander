<#
.SYNOPSIS
    Feature 089 (stretch): a file name with an unpaired UTF-16 surrogate
    through the 7-Zip ENGINE (7za.dll) by the feature 087 driver 7zdrive.exe.

.DESCRIPTION
    Creates <temp>\tc089_surr_<stamp>\src with "Lone<U+D800>surrogate.txt" and
    "plain.txt", runs  7zdrive create / list / extract  and compares the names
    by UTF-16 code units. When a 7z.exe is installed, the archive is extracted
    with it too (an independent reader of what the engine stored).

    This checks the engine and the DRIVER, not the plug-in: 7zdrive.cpp has
    its own conversion code (WideCharToMultiByte(CP_UTF8, 0, ...), which
    replaces an unpaired surrogate by U+FFFD), not the plug-in's splunicode.h.

.NOTES
    Windows PowerShell 5.1. Informational; exit code 0 unless the tools are missing.
#>
param(
    [string]$Driver = 'D:\Projects\tandemcommander\specs\087-7zip-2603-rar\probe\obj\7zdrive.exe',
    [string]$Dll = 'D:\Projects\tandemcommander\build\tandemcommander\Debug_x64\plugins\7zip\7za.dll',
    [string]$SevenZip = (Join-Path $env:ProgramFiles '7-Zip\7z.exe')
)
$ErrorActionPreference = 'Continue'
if (-not (Test-Path -LiteralPath $Driver) -or -not (Test-Path -LiteralPath $Dll)) { Write-Host 'driver or engine missing (build it with specs\087-7zip-2603-rar\probe\build_7zdrive.cmd)'; exit 2 }

$root = Join-Path $env:TEMP ('tc089_surr_' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$src = Join-Path $root 'src'; $out = Join-Path $root 'out'; $out2 = Join-Path $root 'out7z'
New-Item -ItemType Directory -Force -Path $src, $out | Out-Null
$name = 'Lone' + [char]0xD800 + 'surrogate.txt'
[IO.File]::WriteAllText((Join-Path $src $name), 'x')
[IO.File]::WriteAllText((Join-Path $src 'plain.txt'), 'y')
$arc = Join-Path $root 'x.7z'

function Units([string]$s) { return (($s.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ') }
function Names([string]$dir) { if (-not (Test-Path -LiteralPath $dir)) { return @() }; return @([IO.Directory]::GetFileSystemEntries($dir, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object) }

Write-Host "work dir: $root"
& $Driver create $Dll $arc $src | ForEach-Object { Write-Host "  create : $_" }; Write-Host "  create rc=$LASTEXITCODE"
& $Driver list $Dll $arc | ForEach-Object { Write-Host "  list   : $_" }; Write-Host "  list rc=$LASTEXITCODE"
& $Driver extract $Dll $arc $out | ForEach-Object { Write-Host "  extract: $_" }; Write-Host "  extract rc=$LASTEXITCODE"

$s = Names $src; $o = Names $out
Write-Host 'source names (UTF-16 units):'; $s | ForEach-Object { Write-Host ("  {0}" -f (Units $_)) }
Write-Host 'names extracted by 7zdrive:'; $o | ForEach-Object { Write-Host ("  {0}" -f (Units $_)) }
Write-Host ("7zdrive round trip identical: {0}" -f (-not (Compare-Object $s $o) -and $s.Count -eq $o.Count))

if (Test-Path -LiteralPath $SevenZip) {
    & $SevenZip x $arc "-o$out2" -y | Out-Null
    Write-Host ("{0} extract rc={1}" -f $SevenZip, $LASTEXITCODE)
    $o2 = Names $out2
    Write-Host 'names extracted by 7z.exe:'; $o2 | ForEach-Object { Write-Host ("  {0}" -f (Units $_)) }
    Write-Host ("engine stored the lone surrogate (7z.exe round trip identical): {0}" -f (-not (Compare-Object $s $o2) -and $s.Count -eq $o2.Count))
}
else { Write-Host "no $SevenZip - the stored name cannot be read independently" }
exit 0
