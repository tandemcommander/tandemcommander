# 084 fixture generator: a 0.1.8-shaped archiver configuration (quickstart 5).
#
# Exports HKCU\Software\Tandem Commander to a .reg backup, deletes the 0.1
# configuration key, starts the given 0.1.8 build on the fresh registry
# (first-run dialogs answered with their default button), closes it with
# WM_CLOSE so it saves its default configuration, exports
#   0.1\Packers & Unpackers   -> <OutDir>\cfg_a_defaults.reg
#   0.1\Version               -> <OutDir>\cfg_version.reg
# and restores the backup, comparing every value of the restored key with the
# backup (key by key, value by value).
#
# Refuses to run while any tandemcommander.exe is running. Prints RESULT: OK /
# FAIL, exit 0 / 1. ASCII, Windows PowerShell 5.1.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$Archive = (Join-Path $env:TEMP 'tc084-fixtures')
)

$ErrorActionPreference = 'Stop'
Add-Type -Namespace TC084F -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, IntPtr title);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
'@
$WM_CLOSE = 0x0010; $BM_CLICK = 0x00F5
$regRoot = 'HKCU\Software\Tandem Commander'
$regCfg = "$regRoot\0.1"
$failures = New-Object System.Collections.ArrayList
$script:proc = $null
$script:backup = $null

function Note([string]$m) { Write-Host ("fixtures: {0}" -f $m) }
function Bad([string]$m) { [void]$failures.Add($m); Write-Host ("fixtures: FAIL - {0}" -f $m) }

function Reg([string[]]$regArgs) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & reg.exe @regArgs 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return @{ Code = $code; Out = ($out -join ' ') }
}

function Dialogs([int]$ownerPid) {
    $list = @()
    $h = [IntPtr]::Zero
    while ($true) {
        $h = [TC084F.User32]::FindWindowEx([IntPtr]::Zero, $h, '#32770', [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero) { break }
        $wp = 0
        [void][TC084F.User32]::GetWindowThreadProcessId($h, [ref]$wp)
        if ($wp -ne $ownerPid -or -not [TC084F.User32]::IsWindowVisible($h)) { continue }
        $sb = New-Object System.Text.StringBuilder 512
        [void][TC084F.User32]::GetWindowText($h, $sb, 512)
        $list += [pscustomobject]@{ Handle = $h; Caption = $sb.ToString() }
    }
    return $list
}

function Dismiss([IntPtr]$h) {
    $btn = [TC084F.User32]::FindWindowEx($h, [IntPtr]::Zero, 'Button', [IntPtr]::Zero)
    if ($btn -ne [IntPtr]::Zero) { [void][TC084F.User32]::PostMessage($btn, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) }
}

# value map of a .reg export: "section :: name" -> data (continuation lines joined)
function Read-Reg([string]$file) {
    $map = @{}
    $section = ''
    $pending = $null
    foreach ($line in (Get-Content -LiteralPath $file -Encoding Unicode)) {
        if ($null -ne $pending) { $pending += $line.TrimStart(); if ($pending.EndsWith('\')) { $pending = $pending.TrimEnd('\'); continue }; $line = $pending; $pending = $null }
        elseif ($line.EndsWith('\')) { $pending = $line.TrimEnd('\'); continue }
        if ($line -match '^\[(.+)\]$') { $section = $Matches[1]; $map["$section ::"] = '<key>'; continue }
        if ($line -match '^(@|".*?")=(.*)$') { $map["$section :: $($Matches[1])"] = $Matches[2] }
    }
    return $map
}

function Restore-Registry {
    if (-not $script:backup) { return }
    Note ("restoring registry from {0}" -f $script:backup)
    [void](Reg @('delete', $regRoot, '/f'))
    $r = Reg @('import', $script:backup)
    if ($r.Code -ne 0) { Bad ("reg import failed: {0} - backup kept at {1}" -f $r.Out, $script:backup); return }
    $check = Join-Path $Archive 'restored-check.reg'
    [void](Reg @('export', $regRoot, $check, '/y'))
    $a = Read-Reg $script:backup
    $b = Read-Reg $check
    $diff = 0
    foreach ($k in (@($a.Keys) + @($b.Keys) | Sort-Object -Unique)) { if ($a[$k] -ne $b[$k]) { $diff++; Write-Host ("  DIFF {0}" -f $k) } }
    if ($diff -eq 0) { Note ("registry restored and verified: {0} keys/values identical" -f $a.Count) }
    else { Bad ("restored registry differs from the backup in {0} entries - backup kept at {1}" -f $diff, $script:backup) }
}

function Finish {
    if ($script:proc -and -not $script:proc.HasExited) {
        try { Stop-Process -Id $script:proc.Id -Force -ErrorAction SilentlyContinue } catch { }
        Start-Sleep -Seconds 1
    }
    Restore-Registry
    if ($failures.Count -eq 0) { Write-Host 'RESULT: OK'; exit 0 }
    Write-Host ("RESULT: FAIL - {0} problem(s)" -f $failures.Count); exit 1
}

if (-not (Test-Path -LiteralPath $Exe)) { Bad "exe not found: $Exe"; Finish }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Bad 'tandemcommander.exe is already running - stop it first'; Finish }
New-Item -ItemType Directory -Force -Path $Archive, $OutDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

$script:backup = Join-Path $Archive ("tc-backup-{0}.reg" -f $stamp)
$r = Reg @('export', $regRoot, $script:backup, '/y')
if ($r.Code -ne 0 -or (Get-Item -LiteralPath $script:backup).Length -lt 1024) { $script:backup = $null; Bad ("backup failed: {0}" -f $r.Out); Finish }
Note ("registry backed up to {0} ({1} bytes)" -f $script:backup, (Get-Item -LiteralPath $script:backup).Length)
[void](Reg @('delete', $regCfg, '/f'))
if (Test-Path "Registry::$regCfg") { Bad 'could not delete the 0.1 key'; Finish }

$script:proc = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -PassThru
$p = $script:proc
$deadline = (Get-Date).AddSeconds(30)
$seen = @{}
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
    foreach ($d in (Dialogs $p.Id)) { if (-not $seen.ContainsKey($d.Caption)) { $seen[$d.Caption] = 1; Note ("first-run dialog '{0}' - default button" -f $d.Caption); Dismiss $d.Handle } }
    $p.Refresh()
    if ($p.HasExited) { Bad ('exited early (code {0})' -f $p.ExitCode); Finish }
    if ($p.MainWindowHandle -ne 0) { break }
}
if ($p.MainWindowHandle -eq 0) { Bad 'main window did not appear'; Finish }
Start-Sleep -Seconds 3
[void][TC084F.User32]::PostMessage([IntPtr]$p.MainWindowHandle, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
$exitDeadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $exitDeadline -and -not $p.HasExited) {
    foreach ($d in (Dialogs $p.Id)) { if (-not $seen.ContainsKey("exit:" + $d.Caption)) { $seen["exit:" + $d.Caption] = 1; Note ("exit dialog '{0}' - default button" -f $d.Caption); Dismiss $d.Handle } }
    Start-Sleep -Milliseconds 250
    $p.Refresh()
}
if (-not $p.HasExited) { Bad 'did not exit within 20 s'; Finish }
Note ("exited with code {0}" -f $p.ExitCode)

$pu = Join-Path $OutDir 'cfg_a_defaults.reg'
$r = Reg @('export', "$regCfg\Packers & Unpackers", $pu, '/y')
if ($r.Code -ne 0) { Bad ("export of Packers & Unpackers failed: {0}" -f $r.Out) } else { Note ("wrote {0}" -f $pu) }
$ver = Join-Path $OutDir 'cfg_version.reg'
$r = Reg @('export', "$regCfg\Version", $ver, '/y')
if ($r.Code -ne 0) { Note ("no Version key exported: {0}" -f $r.Out) } else { Note ("wrote {0}" -f $ver) }
Finish
