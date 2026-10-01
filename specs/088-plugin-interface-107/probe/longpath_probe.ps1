<#
.SYNOPSIS
    Feature 088, quickstart "long names": next / previous file in PictView
    and in the Database Viewer on a folder whose full path is longer than 300
    characters (the 260-byte buffers of GetNextFileNameForViewer callers).

.DESCRIPTION
    Creates, under %TEMP%, a chain of nested folders with long names (through
    the \\?\ prefix) so that the innermost folder's path exceeds 300
    characters, and in it three pictures (a.png, b.png, c.png) and three
    tables (t1.csv, t2.csv, t3.csv). Starts ONE instance of the given
    tandemcommander.exe with both panels on that folder (-l / -r on the
    command line, left panel active) and then:

      L0  the panel really is in the long folder: the first viewer window's
          title carries the full name of the file, which starts with the
          folder's path, and its length is reported
      L1  PictView on a.png (CM_VIEW 742 posted to the main window)
      L2  CMD_FILE_NEXT (147) posted to the PictView window -> title shows b.png
      L3  CMD_FILE_NEXT again                                -> c.png
      L4  CMD_FILE_PREV (146)                                -> b.png
      L5  Database Viewer on t1.csv
      L6  CM_FILE_NEXT (10037) posted to its window          -> t2.csv
      L7  CM_FILE_NEXT again                                 -> t3.csv
      L8  CM_FILE_PREV (10036)                               -> t2.csv
      L9  the process is alive and no window appeared that the probe did not
          open (a Debug build's run-time check failure, an assertion or a
          crash report would be such a window; each one is printed with its
          class, title and text)

    The Debug build is compiled with run-time checks (/RTC1), so a write past
    a 260-byte stack buffer shows "Run-Time Check Failure #2" or ends the
    process.

    SAFETY: one instance, started here, addressed by pid; messages are
    posted. The registry key HKCU\Software\Tandem Commander is exported
    before the run and restored and verified at the end, unless
    -NoRegistryRestore is given. The folder is deleted at the end.

.PARAMETER Exe
    tandemcommander.exe of the build under test (Debug).
.PARAMETER NoRegistryRestore
    Do not back up / restore the registry key (the caller has a backup).

.NOTES
    Windows PowerShell 5.1 compatible. Exit code = number of failed steps.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [switch]$NoRegistryRestore
)

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'probe_lib.ps1')
$Exe = (Resolve-Path -LiteralPath $Exe).Path

$script:Fail = 0
$script:Results = @()
function Report([string]$Name, [bool]$Ok, [string]$Facts) {
    $v = 'FAIL'; if ($Ok) { $v = 'PASS' } else { $script:Fail++ }
    $line = "{0,-3} {1}  {2}" -f $Name, $v, $Facts
    Write-Host $line
    $script:Results += $line
}

# waits until the window's title contains $Part; returns the title (or the last one seen)
function Wait-Title([IntPtr]$H, [string]$Part, [double]$Seconds = 6) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $t = ''
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not [Drv088]::IsWindow($H)) { return '<window gone>' }
        $t = [Drv088]::Txt($H)
        if ($t -like "*$Part*") { Start-Sleep -Milliseconds 400; return [Drv088]::Txt($H) }
        Start-Sleep -Milliseconds 150
    }
    return $t
}

function Short([string]$Title) {   # the tail of a 300+ character title
    if ($Title.Length -le 70) { return $Title }
    return '...' + $Title.Substring($Title.Length - 67)
}

# windows of the pid that the probe did not open itself
function Get-Unexpected([int]$Id, $Expected) {
    return @(Get-Wins $Id | Where-Object { $Expected -notcontains $_.H -and $_.Class -ne $script:MainClass })
}

# one viewer: open $First, then next, next, previous
function Test-Viewer([int]$Id, [string]$Label, [string[]]$Names, [int]$CmdNext, [int]$CmdPrev, [string[]]$Steps, [ref]$Expected) {
    $w = Open-Viewer $Id $Names[0]
    if (-not $w) { Report $Steps[0] $false "$Label did not open on $($Names[0]) (process alive $(Test-Alive $Id))"; return $null }
    $Expected.Value += $w.H
    $inLong = $w.Title.StartsWith($script:Deep, [StringComparison]::OrdinalIgnoreCase)
    Report $Steps[0] ($inLong -and $w.Title -like "*$Label*") ("{0} opened; class '{1}'; title {2} characters, starts with the long folder: {3}; '{4}'" -f $Label, $w.Class, $w.Title.Length, $inLong, (Short $w.Title))
    $plan = @(@($CmdNext, $Names[1], 'next'), @($CmdNext, $Names[2], 'next'), @($CmdPrev, $Names[1], 'previous'))
    for ($i = 0; $i -lt 3; $i++) {
        $step = $Steps[$i + 1]
        if (-not (Test-Alive $Id)) { Report $step $false 'the process is gone'; continue }
        if (-not [Drv088]::IsWindow($w.H)) { Report $step $false 'the viewer window is gone'; continue }
        Send-WndCommand $Id $w.H $plan[$i][0]
        $want = '\' + $plan[$i][1]
        $t = Wait-Title $w.H $want
        $un = Get-Unexpected $Id $Expected.Value
        foreach ($u in $un) { Write-Host ("       UNEXPECTED WINDOW: " + (Format-Win $u) + ' :: ' + (Get-DialogText $u.H)) }
        $ok = ($t -like "*$want*") -and ($t.StartsWith($script:Deep, [StringComparison]::OrdinalIgnoreCase)) -and (Test-Alive $Id) -and ($un.Count -eq 0)
        Report $step $ok ("{0}: command {1} ({2} file) -> expected {3}; title {4} characters '{5}'; process alive {6}; unexpected windows {7}" -f `
                $Label, $plan[$i][0], $plan[$i][2], $plan[$i][1], $t.Length, (Short $t), (Test-Alive $Id), $un.Count)
    }
    return $w
}

# ---------------------------------------------------------------------------

$backup = Join-Path $env:TEMP 'tc088_longpath_backup.reg'
$existed = $true
if (-not $NoRegistryRestore) { $existed = Backup-TcRegistry $backup }

# the folder: <TEMP>\tc088_long\<5 names of 60 characters>
$root = Join-Path ([IO.Path]::GetFullPath($env:TEMP)) 'tc088_long'
$lp = '\\?\'
if ([IO.Directory]::Exists($lp + $root)) { [IO.Directory]::Delete($lp + $root, $true) }
$script:Deep = $root
foreach ($n in 1..5) { $script:Deep = $script:Deep + '\' + ("level{0}_" -f $n).PadRight(60, [char](96 + $n)) }
[void][IO.Directory]::CreateDirectory($lp + $script:Deep)
$pics = 'a.png', 'b.png', 'c.png'
$tabs = 't1.csv', 't2.csv', 't3.csv'
$colors = 'SteelBlue', 'DarkOrange', 'SeaGreen'
for ($i = 0; $i -lt 3; $i++) {
    New-Png ($lp + $script:Deep + '\' + $pics[$i]) (40 + 8 * $i) 32 $colors[$i]
    New-Csv ($lp + $script:Deep + '\' + $tabs[$i]) ("t" + ($i + 1))
}

$id = 0
try {
    Set-TestConfig
    Write-Host ("Program    : {0}" -f $Exe)
    Write-Host ("Folder     : {0} characters: {1}" -f $script:Deep.Length, $script:Deep)
    Write-Host ("Longest file name: {0} characters" -f ($script:Deep.Length + 1 + 't1.csv'.Length))

    $id = Start-Tc $Exe $script:Deep 'T088L'
    $mainTitle = [Drv088]::Txt((Get-MainWnd $id))
    $start = @(Get-Wins $id)
    $startUnexpected = @($start | Where-Object { $_.Class -ne $script:MainClass })
    foreach ($u in $startUnexpected) { Write-Host ("       AT START: " + (Format-Win $u) + ' :: ' + (Get-DialogText $u.H)) }
    $leaf = Split-Path -Leaf $script:Deep
    # the main window's title names the panel's folder (its last component)
    Report 'L0' (($mainTitle -like "*$leaf*") -and ($startUnexpected.Count -eq 0)) ("started with -l / -r on the long folder; main window title '{0}'; it names the innermost folder: {1}; other windows at start: {2}" -f `
            $mainTitle, ($mainTitle -like "*$leaf*"), $startUnexpected.Count)

    $expected = @()
    $pv = Test-Viewer $id 'PictView' $pics 147 146 @('L1', 'L2', 'L3', 'L4') ([ref]$expected)
    $db = Test-Viewer $id 'Database Viewer' $tabs 10037 10036 @('L5', 'L6', 'L7', 'L8') ([ref]$expected)

    Start-Sleep -Seconds 2
    $alive = Test-Alive $id
    $un = @(); if ($alive) { $un = Get-Unexpected $id $expected }
    foreach ($u in $un) { Write-Host ("       UNEXPECTED WINDOW: " + (Format-Win $u) + ' :: ' + (Get-DialogText $u.H)) }
    $reports = @(Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Tandem Commander') -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Process -Id $PID).StartTime })
    Report 'L9' ($alive -and $un.Count -eq 0 -and $reports.Count -eq 0) ("process alive {0}; unexpected windows (run-time check, assertion, crash) {1}; crash reports written during the run {2}" -f $alive, $un.Count, $reports.Count)
}
catch { Report 'ERR' $false ("NOT DRIVEN: " + $_.Exception.Message) }
finally {
    Stop-AllStarted
    $leftover = @($script:Started | Where-Object { Test-Alive $_ })
    Start-Sleep -Milliseconds 500
    try { [IO.Directory]::Delete($lp + $root, $true) } catch { Write-Host "Folder     : could not delete $root : $($_.Exception.Message)" }
    Write-Host ''
    Write-Host '=== summary ==='
    $script:Results | ForEach-Object { Write-Host $_ }
    Write-Host ("Test processes left running: {0}; folder removed: {1}" -f $leftover.Count, (-not [IO.Directory]::Exists($lp + $root)))
    if (-not $NoRegistryRestore) {
        if (-not (Restore-TcRegistry $backup $existed)) { $script:Fail++ }
    }
    Write-Host ("Failures: {0}" -f $script:Fail)
}
exit $script:Fail
