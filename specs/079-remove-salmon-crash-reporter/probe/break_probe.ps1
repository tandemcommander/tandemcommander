# 079 probe: Task List "Break" of a running instance (spec US2 scenario 6).
#
# The developer tool tools\salbreak (built from tools\salbreak\salbreak.vcxproj,
# Release|Win32) registers the global hotkey Ctrl+Alt+Shift+F12 and fires
# TASKLIST_TODO_BREAK at every running instance through the shared process
# list - the same path the Task List dialog's Break button uses. The target
# instance raises the break exception on its task-list control thread, so the
# crash path must end in the text report, the closing message (from the
# bug-report thread) and exit code 1 even though the main thread was idle.
#
# Prints RESULT: OK / FAIL, exit 0 / 1. Stops only the processes it started.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$SalBreak = (Join-Path (Split-Path $PSScriptRoot -Parent) '..\..\tools\salbreak\Release\salbreak.exe'),
    [int]$TimeoutSec = 60,
    [string]$Tag = 'break',
    [string]$Archive = (Join-Path $env:TEMP 'tc079-bugreports')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Namespace TC079B -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, IntPtr title);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, System.Text.StringBuilder s);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
'@
$WM_GETTEXT = 0x000D; $BM_CLICK = 0x00F5

$script:started = @()
function Cleanup { foreach ($q in $script:started) { try { if (-not $q.HasExited) { Stop-Process -Id $q.Id -Force -ErrorAction SilentlyContinue } } catch { } } }
function Fail([string]$m) { Write-Host "RESULT: FAIL - $m"; Cleanup; exit 1 }

function Find-ClosingMessage([int]$ownerPid) {
    $h = [IntPtr]::Zero
    while ($true) {
        $h = [TC079B.User32]::FindWindowEx([IntPtr]::Zero, $h, '#32770', [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero) { return $null }
        $wp = 0
        [void][TC079B.User32]::GetWindowThreadProcessId($h, [ref]$wp)
        if ($wp -ne $ownerPid -or -not [TC079B.User32]::IsWindowVisible($h)) { continue }
        $sb = New-Object System.Text.StringBuilder 512
        [void][TC079B.User32]::GetWindowText($h, $sb, 512)
        if ($sb.ToString() -like 'Tandem Commander*') {
            $txt = New-Object System.Text.StringBuilder 4096
            $static = [TC079B.User32]::GetDlgItem($h, 0xFFFF)
            if ($static -ne [IntPtr]::Zero) { [void][TC079B.User32]::SendMessage($static, $WM_GETTEXT, [IntPtr]4096, $txt) }
            return [pscustomobject]@{ Handle = $h; Caption = $sb.ToString(); Text = $txt.ToString() }
        }
    }
}

if (-not (Test-Path -LiteralPath $Exe)) { Fail "exe not found: $Exe" }
$SalBreak = [System.IO.Path]::GetFullPath($SalBreak)
if (-not (Test-Path -LiteralPath $SalBreak)) { Fail "salbreak.exe not found: $SalBreak (build tools\salbreak\salbreak.vcxproj Release|Win32)" }
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Fail 'tandemcommander.exe is already running - stop it first' }
if (Get-Process -Name salbreak -ErrorAction SilentlyContinue) { Fail 'salbreak.exe is already running - stop it first' }
$bugDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
New-Item -ItemType Directory -Force -Path $Archive | Out-Null
if ((Test-Path -LiteralPath $bugDir) -and (Get-Item -LiteralPath $bugDir).PSIsContainer) {
    Get-ChildItem -LiteralPath $bugDir -File | Where-Object { $_.Extension -match '^\.(txt|dmp|7z)$' } | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $Archive ('old-' + $_.Name)) -Force
    }
}

# 1. start the instance and the break tool
$p = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -PassThru
$script:started += $p
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500; $p.Refresh(); if ($p.HasExited) { Fail 'instance exited early' }; if ($p.MainWindowHandle -ne 0) { break } }
if ($p.MainWindowHandle -eq 0) { Fail 'main window did not appear' }
Start-Sleep -Seconds 4
$b = Start-Process -FilePath $SalBreak -PassThru
$script:started += $b
Start-Sleep -Seconds 2
Write-Host ("probe: instance pid {0}, salbreak pid {1}; sending Ctrl+Alt+Shift+F12" -f $p.Id, $b.Id)

# 2. fire the global hotkey (RegisterHotKey receives synthesized input)
[System.Windows.Forms.SendKeys]::SendWait('^%+{F12}')

# 3. expect the crash path: report, closing message, exit code 1
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$box = $null
while ((Get-Date) -lt $deadline) {
    $box = Find-ClosingMessage $p.Id
    if ($box) { break }
    $p.Refresh()
    if ($p.HasExited) { Fail ('instance exited (code {0}) without the closing message' -f $p.ExitCode) }
    Start-Sleep -Milliseconds 500
}
if (-not $box) { Fail 'no closing message after the break' }
Write-Host ("probe: message caption = '{0}'" -f $box.Caption)
Write-Host ("probe: message text    = '{0}'" -f ($box.Text -replace "`r?`n", ' | '))
$txt = Get-ChildItem -LiteralPath $bugDir -File -Filter '*.TXT' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $txt) { Fail 'no report file' }
$report = Get-Content -LiteralPath $txt.FullName
$excLine = $report | Where-Object { $_ -match '^\s*Exception:' } | Select-Object -First 1
Write-Host ("probe: report = {0} ({1} bytes); {2}" -f $txt.Name, $txt.Length, $(if ($excLine) { $excLine.Trim() } else { '(no Exception line)' }))
$pathOk = $box.Text.ToLowerInvariant().Contains($txt.FullName.ToLowerInvariant())
$btn = [TC079B.User32]::FindWindowEx($box.Handle, [IntPtr]::Zero, 'Button', [IntPtr]::Zero)
if ($btn -ne [IntPtr]::Zero) { [void][TC079B.User32]::PostMessage($btn, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) }
$exited = $p.WaitForExit(15000)
$p.Refresh()
Write-Host ("probe: exited = {0}, exit code = {1}" -f $exited, $(if ($exited) { $p.ExitCode } else { 'n/a' }))
Get-ChildItem -LiteralPath $bugDir -File -Filter '*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { Move-Item -LiteralPath $_.FullName -Destination (Join-Path $Archive ($Tag + '-' + $_.Name)) -Force }
Cleanup
if ($pathOk -and $exited -and $p.ExitCode -eq 1) { Write-Host 'RESULT: OK'; exit 0 }
Write-Host 'RESULT: FAIL - see the lines above'; exit 1
