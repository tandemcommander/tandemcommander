# pwd_engine_probe.ps1 - feature 093 stage S2, evidence A (engine level).
#
# Proves that the two password forms of src/common/salarcpwd.h are the right
# strings: archives are made by the 7-Zip program (7z.exe) and opened through
# the product's own engine (7za.dll, driven by the feature 087 driver
# 7zdrive.exe with the password given as UTF-16 units).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File pwd_engine_probe.ps1 [-Dll <7za.dll>]
#
# ASCII source; every non-ASCII string is built from character codes.
# Exit code: 0 = every row as expected.

param(
    [string]$Dll = '',
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $here '..\..\..')).Path
if ($Dll -eq '') { $Dll = Join-Path $root 'build\tandemcommander\Debug_x64\plugins\7zip\7za.dll' }
$drive = Join-Path $root 'specs\087-7zip-2603-rar\probe\obj\7zdrive.exe'
foreach ($f in @($Dll, $drive, $SevenZip)) { if (-not (Test-Path -LiteralPath $f)) { throw "missing: $f" } }

Add-Type -Namespace P093 -Name Native -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern uint GetACP();
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int MultiByteToWideChar(uint cp, uint flags, byte[] src, int srcLen, [Out] char[] dst, int dstLen);
'@

# the legacy form exactly as salarcpwd.h derives it (the UTF-8 bytes fit the
# old 128-byte buffer here): MultiByteToWideChar(CP_ACP, 0, utf8 bytes)
function Get-Legacy([string]$typed) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($typed)
    $dst = New-Object char[] ($bytes.Length + 1)
    $n = [P093.Native]::MultiByteToWideChar(0, 0, $bytes, $bytes.Length, $dst, $dst.Length)
    return (New-Object string ($dst, 0, $n))
}
function Get-Hex([string]$s) { return (($s.ToCharArray() | ForEach-Object { '{0:X}' -f [int]$_ }) -join ',') }
function Show([string]$s) { return (($s.ToCharArray() | ForEach-Object { if ([int]$_ -lt 128) { [string]$_ } else { 'U+{0:X4}' -f [int]$_ } }) -join ' ') }

$acp = [P093.Native]::GetACP()
$typedR = 'heslo-' + [char]0x0159                                             # "heslo-" + r with caron
$typedC = -join ([char[]](0x043F, 0x0430, 0x0440, 0x043E, 0x043B, 0x044C))   # Cyrillic "parol"
$ascii = 'heslo123'
$legR = Get-Legacy $typedR
$legC = Get-Legacy $typedC

# folders an interrupted earlier run left behind, then this run's own
Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter 'tc093_pwd_engine_*' -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
$work = Join-Path $env:TEMP ('tc093_pwd_engine_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null
$fail = 0
$rows = 0
try {
$src = Join-Path $work 'src'
New-Item -ItemType Directory -Path $src | Out-Null
[IO.File]::WriteAllText((Join-Path $src 'a.txt'), ('feature 093 password probe ' * 200))
[IO.File]::WriteAllText((Join-Path $src 'b.txt'), 'second file')

$archives = @(
    @{ Name = 'typed-r';  Pw = $typedR },
    @{ Name = 'legacy-r'; Pw = $legR },
    @{ Name = 'typed-c';  Pw = $typedC },
    @{ Name = 'legacy-c'; Pw = $legC },
    @{ Name = 'ascii';    Pw = $ascii }
)
$candidates = @(
    @{ Name = 'typed-r';  Pw = $typedR },
    @{ Name = 'legacy-r'; Pw = $legR },
    @{ Name = 'typed-c';  Pw = $typedC },
    @{ Name = 'legacy-c'; Pw = $legC },
    @{ Name = 'ascii';    Pw = $ascii }
)

"feature 093 S2 - engine probe; code page $acp"
"engine: $Dll"
"7-Zip : $((& $SevenZip | Select-Object -Index 1))"
""
"typed-r  = $(Show $typedR)"
"legacy-r = $(Show $legR)      (helper: UTF-8 bytes of typed-r read with code page $acp)"
"typed-c  = $(Show $typedC)"
"legacy-c = $(Show $legC)"
"ascii    = $ascii"
""

foreach ($he in @($false, $true)) {
    $kind = if ($he) { 'headers+content' } else { 'content only' }
    "--- archives made by 7z.exe, encrypted: $kind; opened by 7za.dll ('test' = every item decoded and checked)"
    "{0,-10} | {1}" -f 'archive', (($candidates | ForEach-Object { '{0,-9}' -f $_.Name }) -join ' ')
    foreach ($a in $archives) {
        $file = Join-Path $work ($a.Name + $(if ($he) { '-he' } else { '' }) + '.7z')
        $args7 = @('a', '-bso0', '-bsp0', ('-p' + $a.Pw))
        if ($he) { $args7 += '-mhe=on' }
        $args7 += @($file, (Join-Path $src '*'))
        & $SevenZip @args7 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "7z.exe failed for $($a.Name)" }
        $cells = @()
        foreach ($c in $candidates) {
            & $drive test $Dll $file ('-pu:' + (Get-Hex $c.Pw)) | Out-Null
            $opens = ($LASTEXITCODE -eq 0)
            $expected = ($c.Pw -ceq $a.Pw)
            $rows++
            if ($opens -ne $expected) { $fail++ }
            $cells += '{0,-9}' -f ($(if ($opens) { 'opens' } else { '-' }) + $(if ($opens -ne $expected) { ' !!' } else { '' }))
        }
        "{0,-10} | {1}" -f $a.Name, ($cells -join ' ')
    }
    ""
}

# the reverse direction: an archive the engine writes with the true form is
# opened by the 7-Zip program with the typed text, not with the legacy form
"--- archive made by 7za.dll with typed-r (content+headers), tested by 7z.exe"
$made = Join-Path $work 'made-by-engine.7z'
& $drive create $Dll $made $src ('-pu:' + (Get-Hex $typedR)) -mhe | Out-Null
$rcCreate = $LASTEXITCODE
& $SevenZip t -bso0 -bsp0 -bse0 ('-p' + $typedR) $made | Out-Null
$okTrue = ($LASTEXITCODE -eq 0)
& $SevenZip t -bso0 -bsp0 -bse0 ('-p' + $legR) $made | Out-Null
$okLegacy = ($LASTEXITCODE -eq 0)
"create rc=$rcCreate; 7z t -p<typed-r>: $(if ($okTrue) { 'OK' } else { 'FAILS' }); 7z t -p<legacy-r>: $(if ($okLegacy) { 'OK' } else { 'FAILS' })"
$rows += 2
if ($rcCreate -ne 0 -or -not $okTrue) { $fail++ }
if ($okLegacy) { $fail++ }
""
$expectLegR = 'heslo-' + [char]0x0139 + [char]0x2122
if ($acp -eq 1250) {
    $rows++
    if ($legR -cne $expectLegR) { $fail++; "legacy-r is NOT heslo- U+0139 U+2122 on code page 1250 !!" } else { "legacy-r on code page 1250 = heslo- U+0139 U+2122 (the string measured in fix-log 'Before S2')" }
}
"RESULT: $rows checks, $fail unexpected"
}
finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
exit $(if ($fail -eq 0) { 0 } else { 1 })
