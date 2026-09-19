# 079 probe: prove the in-process crash path by injecting an unhandled fault.
#
# Derived from specs/077-fix-antivirus-findings/probe/crash_inject.ps1. The
# out-of-process helper salmon.exe is gone (feature 079): the application now
# names and writes its text bug report itself and shows a closing message box.
#
# Starts the built tandemcommander.exe, attaches cdb, moves the instruction
# pointer of the thread that owns the main window to an unmapped/non-executable
# address, DETACHES before the fault is dispatched (with a debugger attached the
# filter registered by SetUnhandledExceptionFilter is never called), wakes the
# thread with a WM_NULL so it leaves GetMessage, then:
#   1. waits for the bug report (.TXT) under %LOCALAPPDATA%\Tandem Commander\
#   2. waits for the closing message box (#32770 owned by the process, caption
#      "Tandem Commander <version>"), reads its text (WM_GETTEXT on the static
#      control 0xFFFF) and asserts it names the report's full path
#      (-ExpectNotSaved: asserts the "could not be saved" wording instead)
#   3. dismisses it with WM_COMMAND/IDOK and asserts the exit code is 1
#   4. asserts no salmon.exe process exists (-AllowHelper only reports it; used
#      at the US2 checkpoint while the helper is still launched but idle)
#
#   -Target app     : rip = 0                          (fault in no module)
#   -Target plugin  : rip = image base of a loaded plugin module (header page,
#                     not executable -> access violation inside the plugin's
#                     address range; -PluginModule picks which, default zip.spl)
#
# Prints RESULT: OK / FAIL and exits 0 / 1. Moves the produced report to -Archive
# with the -Tag prefix. Windows PowerShell 5.1 and pwsh 7 compatible, ASCII.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('app', 'plugin')][string]$Target = 'app',
    [string]$PluginModule = 'zip.spl',
    [int]$TimeoutSec = 60,
    [int]$MessageTimeoutSec = 30,
    [int]$SettleSec = 5,
    [string]$Tag = 'run',
    [string]$Archive = (Join-Path $env:TEMP 'tc079-bugreports'),
    [string]$Cdb = 'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe',
    [switch]$ExpectNotSaved,
    [switch]$AllowHelper
)

$ErrorActionPreference = 'Stop'
Add-Type -Namespace TC079 -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
// PowerShell binds $null to "" for string parameters, which would match only windows with an EMPTY
// caption/class - so NULL is passed explicitly as IntPtr.Zero through these overloads
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, IntPtr title);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, IntPtr cls, IntPtr title);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, System.Text.StringBuilder s);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
'@

$WM_NULL = 0; $WM_COMMAND = 0x0111; $WM_GETTEXT = 0x000D; $IDOK = 1

function Cleanup {
    foreach ($n in 'salmon', 'tandemcommander') {
        Get-Process -Name $n -ErrorAction SilentlyContinue | Where-Object { $script:ownPids -contains $_.Id -or $n -eq 'salmon' } | ForEach-Object {
            try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
}
function Fail([string]$m) { Write-Host "RESULT: FAIL - $m"; Cleanup; exit 1 }

# finds the closing message box owned by process $pid: a visible #32770 whose caption starts with "Tandem Commander"
function Find-ClosingMessage([int]$ownerPid) {
    $h = [IntPtr]::Zero
    while ($true) {
        $h = [TC079.User32]::FindWindowEx([IntPtr]::Zero, $h, '#32770', [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero) { return $null }
        $wp = 0
        [void][TC079.User32]::GetWindowThreadProcessId($h, [ref]$wp)
        if ($wp -ne $ownerPid) { continue }
        if (-not [TC079.User32]::IsWindowVisible($h)) { continue }
        $sb = New-Object System.Text.StringBuilder 512
        [void][TC079.User32]::GetWindowText($h, $sb, 512)
        $caption = $sb.ToString()
        if ($caption -like 'Tandem Commander*') {
            $txt = New-Object System.Text.StringBuilder 4096
            $static = [TC079.User32]::GetDlgItem($h, 0xFFFF)
            if ($static -ne [IntPtr]::Zero) { [void][TC079.User32]::SendMessage($static, $WM_GETTEXT, [IntPtr]4096, $txt) }
            return [pscustomobject]@{ Handle = $h; Caption = $caption; Text = $txt.ToString() }
        }
    }
}

$script:ownPids = @()
if (-not (Test-Path -LiteralPath $Exe)) { Fail "exe not found: $Exe" }
if (-not (Test-Path -LiteralPath $Cdb)) { Fail "cdb not found: $Cdb" }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$bugDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Fail 'tandemcommander.exe is already running - stop it first' }
New-Item -ItemType Directory -Force -Path $Archive | Out-Null

# 1. move every existing report aside so the new one is unambiguous
if ((Test-Path -LiteralPath $bugDir) -and (Get-Item -LiteralPath $bugDir).PSIsContainer) {
    Get-ChildItem -LiteralPath $bugDir -File | Where-Object { $_.Extension -match '^\.(txt|dmp|7z)$' } | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $Archive ('old-' + $_.Name)) -Force
        Write-Host ("probe: moved old report aside: {0}" -f $_.Name)
    }
}

# 2. start and wait for the main window. For the plugin target the left panel
#    is opened inside a small ZIP archive so that zip.spl stays loaded.
$startArgs = @()
if ($Target -eq 'plugin' -and $PluginModule -ieq 'zip.spl') {
    $zipDir = Join-Path $Archive 'probe-archive'
    New-Item -ItemType Directory -Force -Path $zipDir | Out-Null
    $zipSrc = Join-Path $zipDir 'hello.txt'
    Set-Content -LiteralPath $zipSrc -Value 'tandem commander 079 probe' -Encoding ASCII
    $zipPath = Join-Path $Archive 'probe.zip'
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -LiteralPath $zipSrc -DestinationPath $zipPath
    $startArgs = @('-l', ('"' + $zipPath + '"'))
    Write-Host ("probe: left panel will open inside {0} so that zip.spl stays loaded" -f $zipPath)
}
Write-Host ("probe: starting {0} {1}" -f $Exe, ($startArgs -join ' '))
if ($startArgs.Count -gt 0) {
    $p = Start-Process -FilePath $Exe -ArgumentList $startArgs -WorkingDirectory (Split-Path $Exe) -PassThru
} else {
    $p = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -PassThru
}
$script:ownPids = @($p.Id)
$deadline = (Get-Date).AddSeconds(30)
$ready = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $p.Refresh()
    if ($p.HasExited) { Fail 'process exited before showing its window' }
    if ($p.MainWindowHandle -ne 0) { $ready = $true; break }
}
if (-not $ready) { Fail 'main window did not appear within 30 s' }
Start-Sleep -Seconds $SettleSec
$p.Refresh()
if (-not $p.Responding) { Fail 'main window is not responding before injection' }
$helperBefore = @(Get-Process -Name salmon -ErrorAction SilentlyContinue).Count
Write-Host ("probe: salmon.exe processes while running: {0}" -f $helperBefore)
$hwnd = $p.MainWindowHandle
$ownerPid = 0
$tid = [TC079.User32]::GetWindowThreadProcessId([IntPtr]$hwnd, [ref]$ownerPid)
if ($tid -eq 0 -or $ownerPid -ne $p.Id) { Fail 'could not determine the window-owning thread' }

# 3. pick the target address
$modules = @(Get-Process -Id $p.Id).Modules
$spl = @($modules | Where-Object { $_.ModuleName -match '\.spl$' })
Write-Host ("probe: loaded plugin modules: {0}" -f (($spl | ForEach-Object { $_.ModuleName }) -join ', '))
$targetAddr = [int64]0; $targetName = '(no module: address 0)'; $targetBase = [int64]0; $targetSize = [int64]0
if ($Target -eq 'plugin') {
    $m = $spl | Where-Object { $_.ModuleName -ieq $PluginModule } | Select-Object -First 1
    if (-not $m) { $m = $spl | Select-Object -First 1 }
    if (-not $m) { Fail 'no plugin module is loaded in the process; cannot target a plugin' }
    $targetAddr = [int64]$m.BaseAddress; $targetBase = $targetAddr; $targetSize = [int64]$m.ModuleMemorySize
    $targetName = $m.ModuleName
}
Write-Host ("probe: ui thread {0}; target = {1} (rip=0x{2:X})" -f $tid, $targetName, $targetAddr)

# 4. inject via cdb, detach, wake the thread
$cmd = ('~~[0x{0:X}] r rip=0x{1:X}; ~~[0x{0:X}] r rip; .detach; q' -f $tid, $targetAddr)
$cdbOut = & $Cdb -p $p.Id -c $cmd 2>&1 | ForEach-Object { $_.ToString() }
$cdbText = ($cdbOut -join "`n")
if ($cdbText -notmatch 'Detached') { Write-Host $cdbText; Fail 'cdb did not report Detached' }
[void][TC079.User32]::PostMessage([IntPtr]$hwnd, $WM_NULL, [IntPtr]::Zero, [IntPtr]::Zero)
Write-Host 'probe: fault injected, debugger detached, WM_NULL posted; waiting for the bug report...'

# 5. wait for the .TXT report (unless the folder was made unwritable on purpose)
$txt = $null
if (-not $ExpectNotSaved) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        if (-not (Test-Path -LiteralPath $bugDir)) { continue }
        $txt = Get-ChildItem -LiteralPath $bugDir -File -Filter '*.TXT' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($txt -and $txt.Length -gt 0) { Start-Sleep -Seconds 1; break }
    }
    if (-not $txt) { Fail ("no bug report (.TXT) under {0} within {1} s" -f $bugDir, $TimeoutSec) }
}

# 5b. examine the report now, while the process still holds the closing message
#     (nothing else touches the folder before the process ends)
$rip = [int64]-1
if ($txt) {
    $report = Get-Content -LiteralPath $txt.FullName -ErrorAction SilentlyContinue
    $excLine = $report | Where-Object { $_ -match '^\s*Exception:' } | Select-Object -First 1
    $addrLine = $report | Where-Object { $_ -match 'execution address = 0x([0-9A-Fa-f]+)' } | Select-Object -First 1
    if ($addrLine -match 'execution address = 0x([0-9A-Fa-f]+)') { $rip = [Convert]::ToInt64($Matches[1], 16) }
    Write-Host ("probe: report   = {0} ({1} bytes)" -f $txt.Name, $txt.Length)
    if ($excLine) { Write-Host ("probe: {0}" -f $excLine.Trim()) }
    if ($addrLine) { Write-Host ("probe: {0}" -f $addrLine.Trim()) }
}

# 6. wait for the closing message box, read it, dismiss it
$deadline = (Get-Date).AddSeconds($MessageTimeoutSec)
$box = $null
while ((Get-Date) -lt $deadline) {
    $box = Find-ClosingMessage $p.Id
    if ($box) { break }
    $p.Refresh()
    if ($p.HasExited) { Fail ('process exited (code {0}) without showing the closing message' -f $p.ExitCode) }
    Start-Sleep -Milliseconds 500
}
if (-not $box) {
    # diagnostics: every top-level window the process owns, any class
    $h = [IntPtr]::Zero
    while ($true) {
        $h = [TC079.User32]::FindWindowEx([IntPtr]::Zero, $h, [IntPtr]::Zero, [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero) { break }
        $wp = 0
        [void][TC079.User32]::GetWindowThreadProcessId($h, [ref]$wp)
        if ($wp -ne $p.Id) { continue }
        $sb = New-Object System.Text.StringBuilder 512
        [void][TC079.User32]::GetWindowText($h, $sb, 512)
        $cls = New-Object System.Text.StringBuilder 256
        [void][TC079.User32]::GetClassName($h, $cls, 256)
        Write-Host ("probe: window 0x{0:X} class='{1}' visible={2} caption='{3}'" -f [int64]$h, $cls.ToString(), [TC079.User32]::IsWindowVisible($h), $sb.ToString())
    }
    $p.Refresh()
    Write-Host ("probe: process alive={0} responding={1} threads={2}" -f (-not $p.HasExited), $p.Responding, $p.Threads.Count)
    Fail ("no closing message box within {0} s" -f $MessageTimeoutSec)
}
Write-Host ("probe: message caption = '{0}'" -f $box.Caption)
Write-Host ("probe: message text    = '{0}'" -f ($box.Text -replace "`r?`n", ' | '))
$textOk = $false
if ($ExpectNotSaved) {
    # language-neutral: the "could not be saved" message names the intended path under the
    # (blocked) report folder, and no report file can exist there
    $textOk = ($box.Text.ToLowerInvariant().Contains(($bugDir + '\TC').ToLowerInvariant())) -and
              -not (Test-Path -LiteralPath (Join-Path $bugDir 'x') -ErrorAction SilentlyContinue)
} else {
    $textOk = ($box.Text.ToLowerInvariant().Contains($txt.FullName.ToLowerInvariant()))
}
if (-not $textOk) { Fail 'message text does not name the expected report path / wording' }
# a MessageBox ignores a posted WM_COMMAND/IDOK; clicking its OK button (BM_CLICK) is what a user does
$btn = [TC079.User32]::FindWindowEx($box.Handle, [IntPtr]::Zero, 'Button', [IntPtr]::Zero)
if ($btn -ne [IntPtr]::Zero) { [void][TC079.User32]::PostMessage($btn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) } # BM_CLICK
$dismissWatch = [System.Diagnostics.Stopwatch]::StartNew()
$dismissed = $false
$attempt = 'BM_CLICK'
while ($dismissWatch.ElapsedMilliseconds -lt 6000) {
    Start-Sleep -Milliseconds 200
    $p.Refresh()
    if ($p.HasExited -or -not (Find-ClosingMessage $p.Id)) { $dismissed = $true; break }
    if ($dismissWatch.ElapsedMilliseconds -gt 2000 -and $attempt -eq 'BM_CLICK') {
        # fallback 1: posted IDOK
        [void][TC079.User32]::PostMessage($box.Handle, $WM_COMMAND, [IntPtr]$IDOK, [IntPtr]::Zero)
        $attempt = 'WM_COMMAND/IDOK'
    } elseif ($dismissWatch.ElapsedMilliseconds -gt 4000 -and $attempt -eq 'WM_COMMAND/IDOK') {
        # fallback 2: close box (MB_OK boxes treat WM_CLOSE as OK)
        [void][TC079.User32]::PostMessage($box.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) # WM_CLOSE
        $attempt = 'WM_CLOSE'
    }
}
Write-Host ("probe: message dismissed = {0} after {1} ms (last attempt {2})" -f $dismissed, $dismissWatch.ElapsedMilliseconds, $attempt)
$exited = $p.WaitForExit(15000)
$p.Refresh()
if (-not $exited) { Fail 'process did not exit within 15 s after the message was dismissed' }
$exitCode = $p.ExitCode
Write-Host ("probe: exit code = {0}" -f $exitCode)

# 7. helper check (the report was examined in 5b)
$helperAfter = @(Get-Process -Name salmon -ErrorAction SilentlyContinue).Count
Write-Host ("probe: salmon.exe processes: {0}" -f $helperAfter)

$ok = ($exitCode -eq 1)
if (-not $ExpectNotSaved) {
    if ($Target -eq 'app') { $ok = $ok -and ($rip -eq 0) }
    else {
        $inRange = ($rip -ge $targetBase -and $rip -lt ($targetBase + $targetSize))
        Write-Host ("probe: faulting address inside {0} [0x{1:X}..0x{2:X}): {3}" -f $targetName, $targetBase, ($targetBase + $targetSize), $inRange)
        $ok = $ok -and $inRange
    }
}
if (-not $AllowHelper -and ($helperBefore -ne 0 -or $helperAfter -ne 0)) { $ok = $false; Write-Host 'probe: a salmon.exe process was present' }

# 8. archive the report, clean up
if ((Test-Path -LiteralPath $bugDir) -and (Get-Item -LiteralPath $bugDir).PSIsContainer) {
    Get-ChildItem -LiteralPath $bugDir -File -Filter '*.TXT' | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $Archive ($Tag + '-' + $_.Name)) -Force
    }
}
Cleanup
if ($ok) { Write-Host 'RESULT: OK'; exit 0 } else { Write-Host 'RESULT: FAIL - see the lines above'; exit 1 }
