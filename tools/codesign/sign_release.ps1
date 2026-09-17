<#
.SYNOPSIS
Tandem Commander release code signing core (feature 050).

.DESCRIPTION
Signs shipped PE artifacts (*.exe, *.dll, *.spl, *.slg) with the certificate
defined in codesign.cfg (Windows certificate store, selected by SHA-1
thumbprint), timestamped by the configured RFC 3161 authority, SHA-256
digests. Idempotent: files already carrying a Valid signature from the
configured certificate are skipped; unsigned files and files signed by any
other certificate are (re-)signed (signtool replaces the primary signature).
Feature 077: files carrying a Valid signature by Microsoft (the
application-local Visual C++ runtime) are exempt - never stripped, never
re-signed, counted as verified - and a runtime-named file WITHOUT a valid
Microsoft signature fails the run before anything is touched.

Contract: specs/050-code-signing/contracts/signing-cli.md, amended by
specs/077-fix-antivirus-findings/contracts/signing-exemption.md
Windows PowerShell 5.1 compatible. ASCII only.

.PARAMETER Root
Sweep mode: sign all signable artifacts under this directory (recursive).

.PARAMETER File
Single-file mode: sign one file (used by the per-target post-build hook).

.PARAMETER Config
Signing profile path. Default: codesign.cfg next to this script.

.PARAMETER VerifyOnly
Report signing state without modifying anything. Exit 0 iff every candidate
is already signed by the configured certificate.
#>
[CmdletBinding(DefaultParameterSetName = 'Sweep')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Sweep')]
    [string]$Root,

    [Parameter(Mandatory = $true, ParameterSetName = 'Single')]
    [string]$File,

    [Parameter(Mandatory = $false)]
    [string]$Config,

    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'

$BatchSize = 15
$MaxAttempts = 3
$RetryDelaySeconds = 5
$PeExtensions = @('.exe', '.dll', '.spl', '.slg')
# Feature 077: the Visual C++ runtime file classes shipped application-locally
# (keep in sync with tools/check_runtime_deps.py DEFAULT_PATTERN and
# specs/077-fix-antivirus-findings/data-model.md section 1).
$RuntimeNamePattern = '^(vcruntime140|vcruntime140_1|vcruntime140_threads|msvcp140(_[a-z0-9_]+)?|concrt140|vccorlib140|vcamp140|vcomp140|mfc140[a-z]*|mfcm140[a-z]*)\.dll$'
$MicrosoftSubjectPattern = 'O=Microsoft Corporation'

function Fail([string]$Message) {
    Write-Host "ERROR: $Message"
    exit 1
}

# ---------------------------------------------------------------------------
# Signing profile (codesign.cfg)
# ---------------------------------------------------------------------------
if (-not $Config) { $Config = Join-Path $PSScriptRoot 'codesign.cfg' }
if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) {
    Fail "signing profile not found: $Config"
}
$cfgMap = @{}
foreach ($line in (Get-Content -LiteralPath $Config)) {
    if ($line -match '^\s*(#|$)') { continue }
    if ($line -match '^\s*([A-Za-z_]+)\s*=\s*(.+?)\s*$') {
        $cfgMap[$Matches[1].ToLower()] = $Matches[2]
    } else {
        Fail "malformed line in ${Config}: $line"
    }
}
$Thumbprint = $cfgMap['thumbprint']
$TimestampUrl = $cfgMap['timestamp_url']
if (-not $Thumbprint -or $Thumbprint -notmatch '^[0-9a-fA-F]{40}$') {
    Fail "codesign.cfg: 'thumbprint' must be exactly 40 hex characters (got: '$Thumbprint')"
}
if (-not $TimestampUrl -or $TimestampUrl -notmatch '^https?://') {
    Fail "codesign.cfg: 'timestamp_url' must be an http(s) URL (got: '$TimestampUrl')"
}
$Thumbprint = $Thumbprint.ToUpperInvariant()

# ---------------------------------------------------------------------------
# Candidate collection
# ---------------------------------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'Sweep') {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        Fail "root directory not found: $Root"
    }
    # Sign english.slg files before their sibling language modules: build_langs
    # rebuilds a language module whenever it is older than english.slg, and a
    # plain alphabetical order would stamp czech/dutch before english, making
    # them look stale on every following full build.
    $candidates = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File |
        Where-Object {
            $PeExtensions -contains $_.Extension.ToLower() -and
            $_.FullName -notmatch '\\Intermediate\\'
        } | Sort-Object @{Expression = {if ($_.Name -ieq 'english.slg') { 0 } else { 1 }}}, FullName)
    if ($candidates.Count -eq 0) {
        Fail "no signable artifacts (*.exe, *.dll, *.spl, *.slg) found under: $Root"
    }
    Write-Host ("Signing root : {0}" -f $Root)
} else {
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        Fail "file not found: $File"
    }
    $candidates = @(Get-Item -LiteralPath $File)
}
Write-Host ("Certificate  : {0}" -f $Thumbprint)
Write-Host ("Timestamp    : {0}" -f $TimestampUrl)
Write-Host ("Artifacts    : {0}" -f $candidates.Count)

# ---------------------------------------------------------------------------
# Classification: skip only files Valid AND signed by the configured cert
# ---------------------------------------------------------------------------
function Test-SignedByCurrent([string]$Path) {
    $sig = Get-AuthenticodeSignature -LiteralPath $Path
    if ($sig.Status -ne 'Valid') { return $false }
    if ($sig.SignatureType -eq 'Authenticode') {
        return ($null -ne $sig.SignerCertificate -and
                $sig.SignerCertificate.Thumbprint -eq $Thumbprint)
    }
    # Catalog signature (e.g. an OS-catalog-signed file dropped into the
    # tree): Get-AuthenticodeSignature reports the CATALOG signer, and the
    # catalog stays valid even after we embed our own signature (the
    # Authenticode hash excludes the security directory). Inspect the
    # embedded signer directly so such a file is neither re-signed forever
    # nor reported as a verification failure once it carries our signature.
    try {
        $embedded = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
            [System.Security.Cryptography.X509Certificates.X509Certificate]::CreateFromSignedFile($Path))
        return ($embedded.Thumbprint -eq $Thumbprint)
    } catch {
        return $false
    }
}

# Feature 077: a file with a Valid signature whose signer is Microsoft
# (the application-local Visual C++ runtime) is exempt from signing.
function Get-EmbeddedSignerSubject([string]$Path) {
    try {
        $embedded = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
            [System.Security.Cryptography.X509Certificates.X509Certificate]::CreateFromSignedFile($Path))
        return $embedded.Subject
    } catch {
        return ''
    }
}

function Test-MicrosoftExempt([string]$Path) {
    $sig = Get-AuthenticodeSignature -LiteralPath $Path
    if ($sig.Status -ne 'Valid') { return $false }
    if ($sig.SignatureType -eq 'Authenticode') {
        return ($null -ne $sig.SignerCertificate -and
                $sig.SignerCertificate.Subject -match $MicrosoftSubjectPattern)
    }
    # catalog-signed: judge the embedded signer, as Test-SignedByCurrent does
    return ((Get-EmbeddedSignerSubject $Path) -match $MicrosoftSubjectPattern)
}

function Test-RuntimeName([string]$Name) {
    return ($Name -match $RuntimeNamePattern)
}

$toSign = New-Object System.Collections.ArrayList
$skippedCount = 0
$exemptCount = 0
$runtimeInvalid = New-Object System.Collections.ArrayList
foreach ($cand in $candidates) {
    $msExempt = Test-MicrosoftExempt $cand.FullName
    if ((Test-RuntimeName $cand.Name) -and -not $msExempt) {
        [void]$runtimeInvalid.Add($cand.FullName)
        continue
    }
    if (Test-SignedByCurrent $cand.FullName) {
        $skippedCount++
    } elseif ($msExempt) {
        $exemptCount++
    } else {
        [void]$toSign.Add($cand.FullName)
    }
}

# Rule 1 of the 077 contract: a runtime file that is not validly signed by
# Microsoft must neither ship nor be signed with the project certificate.
if ($runtimeInvalid.Count -gt 0) {
    foreach ($p in $runtimeInvalid) {
        if ($VerifyOnly) { Write-Host "RUNTIME FILE NOT MICROSOFT-SIGNED: $p" }
        else { Write-Host "ERROR: runtime file is not validly signed by Microsoft: $p" }
    }
    if ($VerifyOnly) {
        foreach ($p in $toSign) { Write-Host "NOT SIGNED BY CURRENT CERT: $p" }
    }
    exit 1
}

if ($VerifyOnly) {
    Write-Host ("VerifyOnly   : {0} of {1} artifacts signed by the configured certificate, {2} Microsoft-exempt." -f $skippedCount, $candidates.Count, $exemptCount)
    foreach ($p in $toSign) { Write-Host "NOT SIGNED BY CURRENT CERT: $p" }
    if ($toSign.Count -eq 0) { exit 0 } else { exit 1 }
}

if ($toSign.Count -eq 0) {
    Write-Host ("Signed: 0  Skipped: {0}  Exempt (Microsoft): {1}  Failed: 0  (of {2})" -f $skippedCount, $exemptCount, $candidates.Count)
    Write-Host "All artifacts already signed by the configured certificate (or Microsoft-exempt)."
    exit 0
}

# ---------------------------------------------------------------------------
# Pre-flight: certificate present, signtool available (fail before touching
# any file)
# ---------------------------------------------------------------------------
$certHits = @()
foreach ($store in @('Cert:\CurrentUser\My', 'Cert:\LocalMachine\My')) {
    try {
        $certHits += @(Get-ChildItem -Path $store -ErrorAction Stop |
            Where-Object { $_.Thumbprint -eq $Thumbprint })
    } catch { }
}
if ($certHits.Count -eq 0) {
    Fail "certificate with thumbprint $Thumbprint not found in Cert:\CurrentUser\My or Cert:\LocalMachine\My"
}

function Find-SignTool {
    $kitsBin = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    if (Test-Path -LiteralPath $kitsBin) {
        $dirs = @(Get-ChildItem -LiteralPath $kitsBin -Directory |
            Where-Object { $_.Name -match '^10\.[0-9.]+$' } |
            Sort-Object { [version]$_.Name } -Descending)
        foreach ($dir in $dirs) {
            $candidate = Join-Path $dir.FullName 'x64\signtool.exe'
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    $cmd = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$SignTool = Find-SignTool
if (-not $SignTool) {
    Fail "signtool.exe not found (Windows 10/11 SDK is a build prerequisite)"
}
Write-Host ("signtool     : {0}" -f $SignTool)
Write-Host ("To sign      : {0} (skipping {1} already signed)" -f $toSign.Count, $skippedCount)

# ---------------------------------------------------------------------------
# Self-heal: strip stale/broken certificate tables before signing
# ---------------------------------------------------------------------------
# A tool that rewrites an already-signed PE in place (e.g. the translator
# patching a language module seeded from a signed english.slg) leaves a
# malformed certificate table behind; signtool then refuses BOTH sign and
# remove (0x800700C1 / 0x57). Every file classified for signing gets any
# existing certificate table dropped first - for files with a healthy foreign
# signature this equals signtool's own replace behavior, for corrupt ones it
# is the only way to make them signable again. No-op for unsigned files.

function Remove-PeSignature([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64) { return }
    $peOff = [System.BitConverter]::ToInt32($bytes, 60)
    if ($peOff -le 0 -or $peOff + 176 -gt $bytes.Length) { return }
    $magic = [System.BitConverter]::ToUInt16($bytes, $peOff + 24)
    $ddBase = if ($magic -eq 0x20B) { $peOff + 24 + 112 } else { $peOff + 24 + 96 }
    $entry = $ddBase + 4 * 8   # IMAGE_DIRECTORY_ENTRY_SECURITY
    if ($entry + 8 -gt $bytes.Length) { return }
    $certOff = [System.BitConverter]::ToInt32($bytes, $entry)
    $certSize = [System.BitConverter]::ToInt32($bytes, $entry + 4)
    if ($certOff -le 0 -or $certSize -le 0) { return }
    # Truncating the certificate table off the end is only safe when the
    # directory entry really points at one: a stale entry (left behind by a
    # tool that rewrote the file) can point into live data. Require a
    # plausible WIN_CERTIFICATE header (dwLength == directory size, known
    # wRevision) AND that no section's raw data lies beyond the cut;
    # otherwise only clear the directory entry and leave the bytes alone.
    $newLen = $bytes.Length
    $plausible = $false
    if (($certOff + 8) -le $bytes.Length -and ($certOff + $certSize) -eq $bytes.Length) {
        $dwLength = [System.BitConverter]::ToInt32($bytes, $certOff)
        $wRevision = [System.BitConverter]::ToUInt16($bytes, $certOff + 4)
        $plausible = ($dwLength -eq $certSize -and ($wRevision -eq 0x0200 -or $wRevision -eq 0x0100))
    }
    if ($plausible) {
        $numSec = [System.BitConverter]::ToUInt16($bytes, $peOff + 6)
        $optSize = [System.BitConverter]::ToUInt16($bytes, $peOff + 20)
        $secBase = $peOff + 24 + $optSize
        for ($i = 0; $i -lt $numSec; $i++) {
            $rawSize = [System.BitConverter]::ToInt32($bytes, $secBase + $i * 40 + 16)
            $rawPtr = [System.BitConverter]::ToInt32($bytes, $secBase + $i * 40 + 20)
            if (($rawPtr + $rawSize) -gt $certOff) { $plausible = $false; break }
        }
    }
    if ($plausible) { $newLen = $certOff }
    for ($i = 0; $i -lt 8; $i++) { $bytes[$entry + $i] = 0 }
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    try { $fs.Write($bytes, 0, $newLen) } finally { $fs.Close() }
}

foreach ($path in $toSign) {
    try {
        Remove-PeSignature $path
    } catch {
        Write-Host ("  warning: could not strip old signature from {0}: {1}" -f $path, $_.Exception.Message)
    }
}

# ---------------------------------------------------------------------------
# Signing: batches with retry, per-file fallback isolation
# ---------------------------------------------------------------------------
$script:LastSignOutput = ''

function Invoke-SignTool([string[]]$Paths) {
    $sigArgs = @('sign', '/sha1', $Thumbprint, '/tr', $TimestampUrl,
                 '/td', 'sha256', '/fd', 'sha256', '/v') + $Paths
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $SignTool @sigArgs 2>&1 | ForEach-Object { $_.ToString() }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    $script:LastSignOutput = ($output -join [Environment]::NewLine)
    return ($LASTEXITCODE -eq 0)
}

function Invoke-WithRetry([string[]]$Paths, [string]$Label) {
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if ($attempt -gt 1) {
            Write-Host ("  retry {0}/{1} for {2} in {3} s..." -f $attempt, $MaxAttempts, $Label, $RetryDelaySeconds)
            Start-Sleep -Seconds $RetryDelaySeconds
        }
        if (Invoke-SignTool $Paths) { return $true }
    }
    return $false
}

$toSignArr = $toSign.ToArray()
$failedFiles = New-Object System.Collections.ArrayList
$signedCount = 0
$batchTotal = [Math]::Ceiling($toSignArr.Count / $BatchSize)
$batchIndex = 0

for ($i = 0; $i -lt $toSignArr.Count; $i += $BatchSize) {
    $batchIndex++
    $last = [Math]::Min($i + $BatchSize, $toSignArr.Count) - 1
    $batch = @($toSignArr[$i..$last])
    Write-Host ("Batch {0}/{1}: signing {2} file(s)..." -f $batchIndex, $batchTotal, $batch.Count)
    if (Invoke-WithRetry $batch ("batch {0}" -f $batchIndex)) {
        $signedCount += $batch.Count
    } else {
        Write-Host ("  batch {0} failed after {1} attempts; isolating per file..." -f $batchIndex, $MaxAttempts)
        foreach ($path in $batch) {
            if (Invoke-WithRetry @($path) (Split-Path $path -Leaf)) {
                $signedCount++
            } else {
                [void]$failedFiles.Add($path)
                Write-Host ("  FAILED to sign: {0}" -f $path)
                Write-Host $script:LastSignOutput
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Final verification pass over the full candidate set
# ---------------------------------------------------------------------------
$verifiedCount = 0
$notVerified = New-Object System.Collections.ArrayList
foreach ($cand in $candidates) {
    $msExempt = Test-MicrosoftExempt $cand.FullName
    if ((Test-RuntimeName $cand.Name) -and -not $msExempt) {
        [void]$notVerified.Add($cand.FullName)
    } elseif ((Test-SignedByCurrent $cand.FullName) -or $msExempt) {
        $verifiedCount++
    } else {
        [void]$notVerified.Add($cand.FullName)
    }
}

Write-Host ""
Write-Host ("Signed: {0}  Skipped: {1}  Exempt (Microsoft): {2}  Failed: {3}  (of {4})" -f $signedCount, $skippedCount, $exemptCount, $notVerified.Count, $candidates.Count)
Write-Host ("Verified     : {0} of {1}" -f $verifiedCount, $candidates.Count)
foreach ($p in $notVerified) { Write-Host "FAILED: $p" }

if ($notVerified.Count -eq 0) { exit 0 } else { exit 1 }
