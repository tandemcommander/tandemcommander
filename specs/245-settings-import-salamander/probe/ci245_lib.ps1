<#
.SYNOPSIS
    Feature 245 probe library: product-key backup/restore, fixture sources (old program
    configurations) under HKCU\Software\Tandem Commander Test 245, running the Debug build
    with the import automation seam (TC_CFGIMPORT_AUTORUN, TC_CFGIMPORT_TEST_ROOT) and
    registry snapshots for exact before/after comparisons.

.NOTES
    Never touches HKCU\Software\Altap or HKCU\Software\Open Salamander: the program reads
    only the fixture root (TC_CFGIMPORT_TEST_ROOT replaces the product's root table).
    Dot-source it; Windows PowerShell 5.1.
#>

$ErrorActionPreference = 'Stop'
$script:TCRegPath = 'HKCU\Software\Tandem Commander'
$script:TCPS = 'HKCU:\Software\Tandem Commander'
$script:TCRoot = 'HKCU:\Software\Tandem Commander\Settings'
$script:FixRel = 'Software\Tandem Commander Test 245'
$script:FixPS = 'HKCU:\Software\Tandem Commander Test 245'
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not ('Win245' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Win245
{
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    public static string[] TopWindows(uint pid)
    {
        var r = new List<string>();
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p == pid && IsWindowVisible(h)) {
                var t = new StringBuilder(512); GetWindowTextW(h, t, 512);
                var c = new StringBuilder(256); GetClassNameW(h, c, 256);
                r.Add(c.ToString() + " '" + t.ToString() + "'");
            }
            return true; }, IntPtr.Zero);
        return r.ToArray();
    }
}
'@
}

function Backup-TC([string]$File) {
    $script:TCExisted = Test-Path $script:TCPS
    if ($script:TCExisted) { cmd /c "reg export `"$script:TCRegPath`" `"$File`" /y >nul 2>&1"; if ($LASTEXITCODE -ne 0) { throw "reg export failed" } }
    return $script:TCExisted
}

function Restore-TC([string]$File, [bool]$Existed) {
    if (Test-Path $script:TCPS) { Remove-Item -LiteralPath $script:TCPS -Recurse -Force }
    if ($Existed) { cmd /c "reg import `"$File`" >nul 2>&1"; if ($LASTEXITCODE -ne 0) { throw "reg import failed" } }
}

function Remove-Fixtures { if (Test-Path $script:FixPS) { Remove-Item -LiteralPath $script:FixPS -Recurse -Force } }

# a registry key (provider path) -> sorted lines "key|value|kind|data" (data: strings as-is, binary hex)
function Get-RegDump([string]$PSPath) {
    $lines = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $PSPath)) { return @() }
    $keys = @(Get-Item -LiteralPath $PSPath) + @(Get-ChildItem -LiteralPath $PSPath -Recurse)
    $prefix = (Get-Item -LiteralPath $PSPath).Name
    foreach ($k in $keys) {
        $rel = $k.Name.Substring($prefix.Length).TrimStart('\')
        foreach ($n in $k.GetValueNames()) {
            $kind = $k.GetValueKind($n)
            $v = $k.GetValue($n, $null, 'DoNotExpandEnvironmentNames')
            if ($kind -eq 'Binary') { $d = -join ($v | ForEach-Object { $_.ToString('x2') }) }
            elseif ($kind -eq 'MultiString') { $d = ($v -join '|') }
            else { $d = [string]$v }
            $lines.Add("$rel|$n|$kind|$d")
        }
        if ($k.GetValueNames().Count -eq 0) { $lines.Add("$rel|<key>||") }
    }
    return @($lines | Sort-Object)
}

function Get-RegMap([string]$PSPath) {
    $m = @{}
    foreach ($l in (Get-RegDump $PSPath)) {
        $p = $l.Split('|', 4)
        $m["$($p[0])|$($p[1])"] = "$($p[2])|$($p[3])"
    }
    return $m
}

# writes a fixture tree: $Spec is a hashtable "sub\key" -> @{ name = value } (int = DWORD, string = SZ,
# byte[] = BINARY); $Root is a provider path
function Set-RegTree([string]$Root, [hashtable]$Spec) {
    if (-not (Test-Path -LiteralPath $Root)) { New-Item -Path $Root -Force | Out-Null }
    foreach ($sub in $Spec.Keys) {
        $path = if ($sub -eq '') { $Root } else { Join-Path $Root $sub }
        if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
        $vals = $Spec[$sub]
        foreach ($n in $vals.Keys) {
            $v = $vals[$n]
            if ($v -is [int] -or $v -is [long] -or $v -is [uint32]) { New-ItemProperty -LiteralPath $path -Name $n -Value ([int64]$v -band 0xFFFFFFFF) -PropertyType DWord -Force | Out-Null }
            elseif ($v -is [byte[]]) { New-ItemProperty -LiteralPath $path -Name $n -Value $v -PropertyType Binary -Force | Out-Null }
            else { New-ItemProperty -LiteralPath $path -Name $n -Value ([string]$v) -PropertyType String -Force | Out-Null }
        }
    }
}

function HexToBytes([string]$h) {
    $b = New-Object byte[] ($h.Length / 2)
    for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [Convert]::ToByte($h.Substring($i * 2, 2), 16) }
    return , $b
}

# runs the Debug build with the seam; returns @{ Exit; Timeout; Windows; Preview; Result; Error; Fixture }
function Invoke-TC([string]$Exe, [string]$ScriptText, [string]$WorkDir, [string]$Tag, [int]$Seconds = 90, [string]$TestRoot = $script:FixRel) {
    $script = Join-Path $WorkDir "$Tag.ini"
    foreach ($ext in '.preview.txt', '.result.txt', '.error.txt', '.fixture.txt', '.diag.txt') { Remove-Item -LiteralPath ($script + $ext) -ErrorAction SilentlyContinue }
    [IO.File]::WriteAllText($script, $ScriptText, (New-Object System.Text.UnicodeEncoding($false, $true)))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = Split-Path $Exe
    $psi.EnvironmentVariables['TC_CFGIMPORT_AUTORUN'] = $script
    if ($TestRoot) { $psi.EnvironmentVariables['TC_CFGIMPORT_TEST_ROOT'] = $TestRoot }
    $p = [System.Diagnostics.Process]::Start($psi)
    $done = $p.WaitForExit($Seconds * 1000)
    $r = @{ Exit = $null; Timeout = (-not $done); Windows = @() }
    if (-not $done) {
        $r.Windows = [Win245]::TopWindows([uint32]$p.Id)
        try { $p.Kill() } catch {}
        $p.WaitForExit(10000) | Out-Null
    } else { $r.Exit = $p.ExitCode }
    foreach ($pair in @(@('Preview', '.preview.txt'), @('Result', '.result.txt'), @('Error', '.error.txt'), @('Fixture', '.fixture.txt'), @('Diag', '.diag.txt'))) {
        $f = $script + $pair[1]
        $r[$pair[0]] = if (Test-Path -LiteralPath $f) { [IO.File]::ReadAllText($f) } else { $null }
    }
    return $r
}

# a fresh product configuration: delete the root, start once with an empty import (it saves on exit)
function New-TCConfig([string]$Exe, [string]$WorkDir) {
    if (Test-Path $script:TCPS) { Remove-Item -LiteralPath $script:TCPS -Recurse -Force }
    # seeded with the language (no language dialog) and the previous configuration version (the
    # start-up upgrade registers the plug-ins and saves a complete configuration)
    Set-RegTree $script:TCRoot @{ 'Version' = @{ 'Configuration' = 105 }; 'Configuration' = @{ 'Language' = 'english.slg' } }
    $r = Invoke-TC $Exe "[import]`r`ngroups=none`r`nsource=0`r`n" $WorkDir 'newcfg' 90 'Software\Tandem Commander Test 245 Empty'
    if (-not (Test-Path "$script:TCRoot\Configuration")) { throw "fresh configuration not created: $($r | Out-String)" }
    return $r
}

$script:Results = New-Object System.Collections.Generic.List[string]
$script:Fails = 0
function Check([string]$Case, [bool]$Ok, [string]$Facts) {
    $v = if ($Ok) { 'PASS' } else { $script:Fails++; 'FAIL' }
    $line = "$v | $Case | $Facts"
    Write-Host $line
    $script:Results.Add($line)
}
