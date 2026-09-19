# 079 probe: start-up without the crash-reporting helper.
#
# Two scenarios (spec US1/US3, SC-002/SC-003):
#   -StaleReports   plants three files from "earlier crashes" (.TXT, .DMP, .7Z)
#                   in %LOCALAPPDATA%\Tandem Commander and checks that start-up
#                   shows no prompt about them and leaves them untouched
#   -FreshRegistry  exports HKCU\Software\Tandem Commander to a .reg backup,
#                   deletes the 0.1 configuration subkey, runs, then deletes the
#                   key the run wrote and imports the backup back (verifying a
#                   known value survived the round trip)
# Both: exactly one tandemcommander.exe process and no salmon.exe, no dialog
# (#32770) owned by the process during the settle time except an unrelated
# first-run dialog (logged and answered with its default button), main window
# Responding, orderly exit on WM_CLOSE, and HKCU\...\Bug Reporter not created.
#
# Refuses to run while any tandemcommander.exe is running (never touches a
# process it did not start). Prints RESULT: OK / FAIL, exit 0 / 1. ASCII,
# Windows PowerShell 5.1.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [switch]$StaleReports,
    [switch]$FreshRegistry,
    [int]$SettleSec = 5,
    [string]$Archive = (Join-Path $env:TEMP 'tc079-startup')
)

$ErrorActionPreference = 'Stop'
Add-Type -Namespace TC079S -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
// PowerShell binds $null to "" for string parameters (would match only empty captions): NULL goes in as IntPtr.Zero
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, IntPtr title);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, System.Text.StringBuilder s);
'@
$WM_CLOSE = 0x0010; $WM_GETTEXT = 0x000D; $BM_CLICK = 0x00F5

# a MessageBox ignores a posted WM_COMMAND/IDOK; clicking its first button is what a user does
function Dismiss-Dialog([IntPtr]$h) {
    $btn = [TC079S.User32]::FindWindowEx($h, [IntPtr]::Zero, 'Button', [IntPtr]::Zero)
    if ($btn -ne [IntPtr]::Zero) { [void][TC079S.User32]::PostMessage($btn, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) }
}

$regRoot = 'HKCU\Software\Tandem Commander'
$regCfg = "$regRoot\0.1"
$regBugReporter = "$regRoot\Bug Reporter"
$bugDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$failures = New-Object System.Collections.ArrayList
$script:proc = $null
$script:backup = $null
$script:languageBefore = $null

function Note([string]$m) { Write-Host ("probe: {0}" -f $m) }
function Bad([string]$m) { [void]$failures.Add($m); Write-Host ("probe: FAIL - {0}" -f $m) }

function Dialogs([int]$ownerPid) {
    $list = @()
    $h = [IntPtr]::Zero
    while ($true) {
        $h = [TC079S.User32]::FindWindowEx([IntPtr]::Zero, $h, '#32770', [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero) { break }
        $wp = 0
        [void][TC079S.User32]::GetWindowThreadProcessId($h, [ref]$wp)
        if ($wp -ne $ownerPid -or -not [TC079S.User32]::IsWindowVisible($h)) { continue }
        $sb = New-Object System.Text.StringBuilder 512
        [void][TC079S.User32]::GetWindowText($h, $sb, 512)
        $txt = New-Object System.Text.StringBuilder 2048
        $static = [TC079S.User32]::GetDlgItem($h, 0xFFFF)
        if ($static -ne [IntPtr]::Zero) { [void][TC079S.User32]::SendMessage($static, $WM_GETTEXT, [IntPtr]2048, $txt) }
        $list += [pscustomobject]@{ Handle = $h; Caption = $sb.ToString(); Text = ($txt.ToString() -replace "`r?`n", ' | ') }
    }
    return $list
}

# reg.exe prints its success message on stderr; under $ErrorActionPreference = 'Stop' a
# native command's stderr becomes a terminating error, so every reg call goes through cmd
function Reg([string[]]$regArgs) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & reg.exe @regArgs 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return @{ Code = $code; Out = ($out -join ' ') }
}

function Restore-Registry {
    if (-not $script:backup) { return }
    Note ("restoring registry from {0}" -f $script:backup)
    [void](Reg @('delete', $regCfg, '/f'))
    $r = Reg @('import', $script:backup)
    if ($r.Code -ne 0) { Bad ("reg import failed: {0}" -f $r.Out); return }
    $after = (Get-ItemProperty -Path "HKCU:\Software\Tandem Commander\0.1\Configuration" -Name Language -ErrorAction SilentlyContinue).Language
    if ($after -eq $script:languageBefore) { Note ("registry restored: OK (Configuration\Language = '{0}')" -f $after) }
    else { Bad ("registry restore mismatch: Language before '{0}', after '{1}'" -f $script:languageBefore, $after) }
    $script:backup = $null
}

function Finish {
    if ($script:proc -and -not $script:proc.HasExited) {
        Note 'stopping the process the probe started'
        try { Stop-Process -Id $script:proc.Id -Force -ErrorAction SilentlyContinue } catch { }
        Start-Sleep -Seconds 1
    }
    Restore-Registry
    if ($failures.Count -eq 0) { Write-Host 'RESULT: OK'; exit 0 }
    Write-Host ("RESULT: FAIL - {0} problem(s)" -f $failures.Count); exit 1
}

if (-not (Test-Path -LiteralPath $Exe)) { Bad "exe not found: $Exe"; Finish }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not ($StaleReports -or $FreshRegistry)) { Bad 'choose -StaleReports and/or -FreshRegistry'; Finish }
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Bad 'tandemcommander.exe is already running - stop it first'; Finish }
New-Item -ItemType Directory -Force -Path $Archive | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# --- scenario preparation --------------------------------------------------
$planted = @()
if ($StaleReports) {
    New-Item -ItemType Directory -Force -Path $bugDir | Out-Null
    foreach ($n in 'TC018X64-20260101-000000.TXT', 'OLD-DUMP.DMP', 'OLD-REPORT.7Z') {
        $f = Join-Path $bugDir $n
        Set-Content -LiteralPath $f -Value ("stale report planted by the 079 probe " + $n) -Encoding ASCII
        $planted += Get-Item -LiteralPath $f | Select-Object Name, Length, LastWriteTimeUtc, FullName
    }
    Note ("planted {0} stale report files in {1}" -f $planted.Count, $bugDir)
}
$bugReporterKeyBefore = Test-Path "Registry::$regBugReporter"
Note ("Bug Reporter key exists before start: {0}" -f $bugReporterKeyBefore)

if ($FreshRegistry) {
    $script:languageBefore = (Get-ItemProperty -Path "HKCU:\Software\Tandem Commander\0.1\Configuration" -Name Language -ErrorAction SilentlyContinue).Language
    $script:backup = Join-Path $Archive ("tc-backup-{0}.reg" -f $stamp)
    $r = Reg @('export', $regRoot, $script:backup, '/y')
    if ($r.Code -ne 0 -or -not (Test-Path -LiteralPath $script:backup) -or (Get-Item -LiteralPath $script:backup).Length -lt 1024) {
        $script:backup = $null
        Bad ("registry backup failed or too small: {0}" -f $r.Out); Finish
    }
    Note ("registry backed up to {0} ({1} bytes; Configuration\Language = '{2}')" -f $script:backup, (Get-Item -LiteralPath $script:backup).Length, $script:languageBefore)
    [void](Reg @('delete', $regCfg, '/f'))
    if (Test-Path "Registry::$regCfg") { Bad 'could not delete the 0.1 configuration key'; Finish }
    Note 'configuration key 0.1 deleted (fresh registry)'
}

# --- start ------------------------------------------------------------------
Note ("starting {0}" -f $Exe)
$t0 = Get-Date
$script:proc = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -PassThru
$p = $script:proc
$deadline = (Get-Date).AddSeconds(30)
$seen = @{}
$ready = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
    # dialogs may appear before the main window (first-run language chooser); answer and log them
    foreach ($d in (Dialogs $p.Id)) {
        if (-not $seen.ContainsKey($d.Caption)) {
            $seen[$d.Caption] = 1
            Note ("dialog before main window: '{0}' - answering with its default button" -f $d.Caption)
            if ($d.Caption -match 'Bug Report|Reporter') { Bad ("crash-reporter dialog at start-up: '{0}'" -f $d.Caption) }
            Dismiss-Dialog $d.Handle
        }
    }
    $p.Refresh()
    if ($p.HasExited) { Bad ('process exited before showing its window (code {0})' -f $p.ExitCode); Finish }
    if ($p.MainWindowHandle -ne 0) { $ready = $true; break }
}
if (-not $ready) { Bad 'main window did not appear within 30 s'; Finish }
Note ("main window after {0:N1} s" -f ((Get-Date) - $t0).TotalSeconds)

# --- settle: watch for dialogs, responsiveness, processes -------------------
$versionCaptionSeen = $false
$settleEnd = (Get-Date).AddSeconds($SettleSec)
while ((Get-Date) -lt $settleEnd) {
    foreach ($d in (Dialogs $p.Id)) {
        if (-not $seen.ContainsKey($d.Caption)) {
            $seen[$d.Caption] = 1
            Note ("dialog during settle: '{0}' text: '{1}'" -f $d.Caption, $d.Text)
            if ($d.Caption -match 'Bug Report|Reporter' -or $d.Caption -match '^Tandem Commander \d') { Bad ("unexpected dialog: '{0}'" -f $d.Caption) }
            else { [void][TC079S.User32]::PostMessage($d.Handle, $WM_COMMAND, [IntPtr]$IDOK, [IntPtr]::Zero) }
        }
    }
    Start-Sleep -Milliseconds 250
}
$p.Refresh()
if ($p.HasExited) { Bad ('process exited during settle (code {0})' -f $p.ExitCode); Finish }
Note ("dialogs seen: {0}" -f $(if ($seen.Count) { ($seen.Keys -join '; ') } else { 'none' }))
if ($p.Responding) { Note 'main window responding: True' } else { Bad 'main window not responding after settle' }
$tcCount = @(Get-Process -Name tandemcommander -ErrorAction SilentlyContinue).Count
$helperCount = @(Get-Process -Name salmon -ErrorAction SilentlyContinue).Count
Note ("processes: tandemcommander={0} salmon={1}" -f $tcCount, $helperCount)
if ($tcCount -ne 1) { Bad ("expected exactly one tandemcommander.exe, found {0}" -f $tcCount) }
if ($helperCount -ne 0) { Bad ("salmon.exe is running ({0})" -f $helperCount) }
$bugReporterKeyAfter = Test-Path "Registry::$regBugReporter"
Note ("Bug Reporter key exists after start: {0}" -f $bugReporterKeyAfter)
if ($bugReporterKeyAfter -and -not $bugReporterKeyBefore) { Bad 'the Bug Reporter registry key was created by this start' }

# --- exit -------------------------------------------------------------------
[void][TC079S.User32]::PostMessage([IntPtr]$p.MainWindowHandle, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
$exitDeadline = (Get-Date).AddSeconds(15)
while ((Get-Date) -lt $exitDeadline -and -not $p.HasExited) {
    foreach ($d in (Dialogs $p.Id)) {
        if (-not $seen.ContainsKey($d.Caption)) {
            $seen[$d.Caption] = 1
            Note ("dialog at exit: '{0}' text: '{1}' - clicking its button" -f $d.Caption, $d.Text)
            Dismiss-Dialog $d.Handle
        }
    }
    Start-Sleep -Milliseconds 250
    $p.Refresh()
}
if ($p.HasExited) { Note ("exited on WM_CLOSE with code {0}" -f $p.ExitCode) } else { Bad 'did not exit within 15 s of WM_CLOSE' }

# --- scenario checks --------------------------------------------------------
if ($StaleReports) {
    foreach ($f in $planted) {
        $now = Get-Item -LiteralPath $f.FullName -ErrorAction SilentlyContinue
        if (-not $now) { Bad ("planted file vanished: {0}" -f $f.Name); continue }
        if ($now.Length -ne $f.Length -or $now.LastWriteTimeUtc -ne $f.LastWriteTimeUtc) { Bad ("planted file changed: {0}" -f $f.Name) }
        else { Note ("planted file untouched: {0} ({1} bytes)" -f $f.Name, $now.Length) }
    }
    # remove the planted files again
    foreach ($f in $planted) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
}
Finish
