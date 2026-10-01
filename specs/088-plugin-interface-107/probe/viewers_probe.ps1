<#
.SYNOPSIS
    Feature 088, quickstart "update with viewers open": an installer's close
    request (Windows Restart Manager) against a running build with windows of
    the four viewer plug-ins open, plus the cases that must still decline and
    the normal exit that must still ask.

.DESCRIPTION
    Each scenario runs on a FRESH instance of the given tandemcommander.exe,
    started on a temp folder with four small files:

        a_text.cpp   -> Code Viewer      (class 'CodeView - WinLib Universal Window2')
        b_doc.md     -> Markdown Viewer  (class 'MDView - WinLib Universal Window2')
        c_pic.png    -> PictView         (class 'PICTVIEW - WinLib Universal Window2')
        d_table.csv  -> Database Viewer  (class 'DBVIEWER - WinLib Universal Window2')

    A viewer is opened as a user would with F3: the focus is moved in the
    left panel (WM_KEYDOWN Home / Down posted to the panel's list) and
    CM_VIEW (742) is posted to the main window; the new top-level window's
    title must contain the file name. The installer's request is
    specs/080-restart-manager-upgrade/probe/rm_probe.ps1 -ExePath <exe>,
    run as a child process while this script polls the visible top-level
    windows of the pid every 30 ms and records every window that was not
    there before.

    Scenarios
      P1..P4  one window of each viewer alone      -> rm_probe 0, process ended, nothing shown
      P5      windows of all four viewers           -> the same
      N1a     PictView with its Image Properties dialog open (CMD_IMG_PROP 114)  -> declined
      N1b     Database Viewer with its Go to Record dialog open (CM_GOTO 10010)  -> declined
      N2      the program's Configuration dialog (CM_CONFIGURATION 686)          -> declined
              (a window of a non-viewer plug-in cannot be opened by a posted
              message: plug-in menu commands get their ids only when the menu
              is built, and their hot keys are read with GetKeyState)
      N3      normal exit (WM_CLOSE to the main window) with a viewer open:
              the plug-in's question appears; answered No (IDNO 7); the
              core's older follow-up question (force the plug-in to unload?)
              is answered No as well: the program and the viewer stay
      R1      no viewer open -> rm_probe 0, process ended

    "Nothing shown": no new visible top-level window between the request and
    the end, EXCEPT the core's own wait window (class 'SalamanderSaveBits',
    no buttons, the "saving configuration" notice of the exit path), which
    is recorded and reported, and which R1 shows is there without any viewer.

    SAFETY: only instances started here (from -Exe) are addressed, always by
    pid; rm_probe.ps1 refuses if the Restart Manager lists a process that was
    not started from -Exe. Messages are posted, nothing needs the foreground.
    The registry key HKCU\Software\Tandem Commander is exported before the
    first run and restored and verified at the end, unless -NoRegistryRestore
    is given (then the caller does it).

.PARAMETER Exe
    tandemcommander.exe of the build under test (Debug).
.PARAMETER Only
    Run only the named scenarios, e.g. -Only P1,N3.
.PARAMETER NoRegistryRestore
    Do not back up / restore the registry key (the caller has a backup).

.NOTES
    Windows PowerShell 5.1 compatible. Exit code = number of failed scenarios.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Only,
    [switch]$NoRegistryRestore
)

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'probe_lib.ps1')
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }   # -File passes "P1,N3" as one string

$WaitClass = 'SalamanderSaveBits'
$Files = [ordered]@{ Code = 'a_text.cpp'; Markdown = 'b_doc.md'; PictView = 'c_pic.png'; Database = 'd_table.csv' }
$Suffix = @{ Code = 'Code Viewer'; Markdown = 'Markdown Viewer'; PictView = 'PictView'; Database = 'Database Viewer' }
$script:Fail = 0
$script:Classes = @{}
$script:Results = @()

function Report([string]$Name, [bool]$Ok, [string]$Facts) {
    $v = 'FAIL'; if ($Ok) { $v = 'PASS' } else { $script:Fail++ }
    $line = "{0,-4} {1}  {2}" -f $Name, $v, $Facts
    Write-Host $line
    $script:Results += $line
}

function Want([string]$Name) { return (-not $Only) -or ($Only -contains $Name) }

# opens the viewers named in $Kinds; returns a hashtable kind -> window, or throws
function Open-Kinds([int]$Id, [string[]]$Kinds) {
    $r = @{}
    foreach ($k in $Kinds) {
        $w = Open-Viewer $Id $Files[$k]
        if (-not $w) { throw "could not open the $k viewer on $($Files[$k])" }
        if ($w.Title -notlike "*$($Suffix[$k])*") { throw "$($Files[$k]) opened in an unexpected window: $(Format-Win $w)" }
        $script:Classes[$k] = $w.Class
        Write-Host ("       opened {0}" -f (Format-Win $w))
        $r[$k] = $w
    }
    return $r
}

function Split-Shown($Shown) {
    $wait = @($Shown | Where-Object { $_ -like "*class='$WaitClass'*" })
    $other = @($Shown | Where-Object { $_ -notlike "*class='$WaitClass'*" })
    return $wait, $other
}

# positive case: agreed, ended, nothing but the wait window shown
function Test-Positive([string]$Name, [string[]]$Kinds) {
    if (-not (Want $Name)) { return }
    Write-Host ("--- {0}: {1}" -f $Name, $(if ($Kinds.Count) { $Kinds -join ' + ' } else { 'no viewer' }))
    $id = 0
    try {
        $id = Start-Tc $Exe $script:Dir "T088$Name"
        if ($Kinds.Count) { [void](Open-Kinds $id $Kinds) }
        $n = @(Get-Wins $id).Count
        $r = Invoke-RmWatched $Exe $id
        $wait, $other = Split-Shown $r.Shown
        foreach ($s in $other) { Write-Host "       SHOWN: $s" }
        foreach ($s in $r.Left) { Write-Host ("       LEFT : " + (Format-Win $s)) }
        $ok = ($r.Exit -eq 0) -and (-not $r.Alive) -and ($other.Count -eq 0)
        Report $Name $ok ("rm_probe exit {0}; {1}; windows before {2}; process alive {3}; windows left {4}; new windows {5} (+{6} core wait window)" -f `
                $r.Exit, $r.Line, $n, $r.Alive, @($r.Left).Count, $other.Count, $wait.Count)
        if (-not $ok) { $r.Output | ForEach-Object { Write-Host "       rm> $_" } }
    }
    catch { Report $Name $false ("NOT DRIVEN: " + $_.Exception.Message) }
    finally { if ($id) { Stop-Tc $id } }
}

# negative case: $Prepare opens the obstacle and returns its description
function Test-Negative([string]$Name, [string]$What, [scriptblock]$Prepare) {
    if (-not (Want $Name)) { return }
    Write-Host ("--- {0}: {1}" -f $Name, $What)
    $id = 0
    try {
        $id = Start-Tc $Exe $script:Dir "T088$Name"
        $obstacle = & $Prepare $id
        $before = @(Get-Wins $id | ForEach-Object { $_.H })
        $r = Invoke-RmWatched $Exe $id
        $wait, $other = Split-Shown $r.Shown
        foreach ($s in $r.Shown) { Write-Host "       SHOWN: $s" }
        $still = @(Get-Wins $id | ForEach-Object { $_.H })
        $kept = @($before | Where-Object { $still -contains $_ }).Count
        $ok = ($r.Exit -eq 1) -and $r.Alive -and ($r.Shown.Count -eq 0) -and ($r.Seconds -le 1.0) -and ($kept -eq $before.Count)
        Report $Name $ok ("obstacle: {0}; rm_probe exit {1}; {2}; process alive {3}; windows kept {4}/{5}; new windows {6}" -f `
                $obstacle, $r.Exit, $r.Line, $r.Alive, $kept, $before.Count, $r.Shown.Count)
        if (-not $ok) { $r.Output | ForEach-Object { Write-Host "       rm> $_" } }
    }
    catch { Report $Name $false ("NOT DRIVEN: " + $_.Exception.Message) }
    finally { if ($id) { Stop-Tc $id } }
}

# ---------------------------------------------------------------------------

$backup = Join-Path $env:TEMP 'tc088_viewers_backup.reg'
$existed = $true
if (-not $NoRegistryRestore) { $existed = Backup-TcRegistry $backup }

$script:Dir = Join-Path $env:TEMP 'tc088_viewers'
if (Test-Path -LiteralPath $script:Dir) { Remove-Item -LiteralPath $script:Dir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $script:Dir | Out-Null
[IO.File]::WriteAllText((Join-Path $script:Dir $Files.Code), "// feature 088 probe`r`nint main() { return 0; }`r`n")
[IO.File]::WriteAllText((Join-Path $script:Dir $Files.Markdown), "# Feature 088`r`n`r`nA *small* document.`r`n")
New-Png (Join-Path $script:Dir $Files.PictView)
New-Csv (Join-Path $script:Dir $Files.Database)

try {
    Set-TestConfig
    Write-Host ("Program    : {0}" -f $Exe)
    Write-Host ("Folder     : {0}" -f $script:Dir)

    Test-Positive 'P1' @('Code')
    Test-Positive 'P2' @('Markdown')
    Test-Positive 'P3' @('PictView')
    Test-Positive 'P4' @('Database')
    Test-Positive 'P5' @('Code', 'Markdown', 'PictView', 'Database')

    Test-Negative 'N1a' 'PictView with its Image Properties dialog' {
        param($id)
        $v = (Open-Kinds $id @('PictView')).PictView
        $d = Open-ViewerDialog $id $v.H 114          # CMD_IMG_PROP
        if (-not $d) { throw 'the Image Properties dialog did not appear' }
        Write-Host ("       dialog {0}" -f (Format-Win $d))
        return ("'{0}' ({1}) owned by the PictView window" -f $d.Title, $d.Class)
    }
    Test-Negative 'N1b' 'Database Viewer with its Go to Record dialog' {
        param($id)
        $v = (Open-Kinds $id @('Database')).Database
        $d = Open-ViewerDialog $id $v.H 10010        # CM_GOTO
        if (-not $d) { throw 'the Go to Record dialog did not appear' }
        Write-Host ("       dialog {0}" -f (Format-Win $d))
        return ("'{0}' ({1}) owned by the Database Viewer window" -f $d.Title, $d.Class)
    }
    Test-Negative 'N2' "the program's Configuration dialog (no viewer)" {
        param($id)
        $known = @(Get-Wins $id | ForEach-Object { $_.H })
        Send-MainCommand $id 686                     # CM_CONFIGURATION
        $d = Wait-NewWin $id $known 5
        if (-not $d) { throw 'the Configuration dialog did not appear' }
        Write-Host ("       dialog {0}" -f (Format-Win $d))
        return ("'{0}' ({1})" -f $d.Title, $d.Class)
    }

    if (Want 'N3') {
        Write-Host '--- N3: normal exit (WM_CLOSE) with a Code Viewer window open'
        $id = 0
        try {
            $id = Start-Tc $Exe $script:Dir 'T088N3'
            $v = (Open-Kinds $id @('Code')).Code
            $known = @(Get-Wins $id | ForEach-Object { $_.H })
            Invoke-Drive @('-Action', 'close', '-ProcessId', $id) | Out-Null   # tc_drive: WM_CLOSE to the main window
            $q = $null
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 10 -and -not $q) {
                $q = Get-Wins $id | Where-Object { $known -notcontains $_.H -and $_.Class -eq '#32770' } | Select-Object -First 1
                Start-Sleep -Milliseconds 150
            }
            if (-not $q) {
                $now = (Get-Wins $id | ForEach-Object { Format-Win $_ }) -join ' ;; '
                Report 'N3' $false ("no question appeared within 10 s; process alive {0}; windows: {1}" -f (Test-Alive $id), $now)
            }
            else {
                $text = Get-DialogText $q.H
                Write-Host ("       question {0}" -f (Format-Win $q))
                Write-Host ("       text     {0}" -f $text)
                $hasNo = [Drv088]::Kids($q.H) | Where-Object { [Drv088]::GetDlgCtrlID($_) -eq 7 }
                if (-not $hasNo) { throw "the question has no button with id 7 (IDNO): $text" }
                Invoke-Drive @('-Action', 'click', '-ProcessId', $id, '-Title', $q.Title, '-Id', 7) | Out-Null   # IDNO
                # The core then asks its own, older question ("<plug-in> plugin has
                # rejected to unload. Do you want to force it to unload?", title
                # 'Question', IDS_PLUGINFORCEUNLOAD - present in 0.1.7 as well).
                # It is recorded and answered No too.
                $follow = @()
                $sw = [Diagnostics.Stopwatch]::StartNew()
                while ($sw.Elapsed.TotalSeconds -lt 4) {
                    $f = Get-Wins $id | Where-Object { $known -notcontains $_.H -and $_.H -ne $q.H -and $_.Class -eq '#32770' } | Select-Object -First 1
                    if ($f) {
                        $ft = Get-DialogText $f.H
                        Write-Host ("       follow-up {0}" -f (Format-Win $f))
                        Write-Host ("       text      {0}" -f $ft)
                        $follow += ("'{0}': {1}" -f $f.Title, $ft)
                        $known += $f.H
                        Invoke-Drive @('-Action', 'click', '-ProcessId', $id, '-Title', $f.Title, '-Id', 7) | Out-Null   # IDNO
                        $sw.Restart()
                    }
                    Start-Sleep -Milliseconds 200
                }
                $alive = Test-Alive $id
                $wins = @(Get-Wins $id)
                $viewerThere = [bool]($wins | Where-Object { $_.H -eq $v.H })
                $mainThere = [bool]($wins | Where-Object { $_.Class -eq $script:MainClass })
                $mainEnabled = [bool]($wins | Where-Object { $_.Class -eq $script:MainClass -and $_.Enabled })
                $extra = @($wins | Where-Object { $_.H -ne $v.H -and $_.Class -ne $script:MainClass })
                foreach ($e in $extra) { Write-Host ("       STILL SHOWN: " + (Format-Win $e) + ' :: ' + (Get-DialogText $e.H)) }
                $ok = $alive -and $viewerThere -and $mainThere -and $mainEnabled -and ($extra.Count -eq 0)
                Report 'N3' $ok ("question '{0}': {1} -> No; follow-up questions {7} [{8}] -> No; process alive {2}; viewer window still there {3}; main window there {4}, enabled {5}; other windows {6}" -f `
                        $q.Title, $text, $alive, $viewerThere, $mainThere, $mainEnabled, $extra.Count, $follow.Count, ($follow -join ' ;; '))
            }
        }
        catch { Report 'N3' $false ("NOT DRIVEN: " + $_.Exception.Message) }
        finally { if ($id) { Stop-Tc $id } }
    }

    Test-Positive 'R1' @()
}
finally {
    Stop-AllStarted
    $leftover = @($script:Started | Where-Object { Test-Alive $_ })
    Write-Host ''
    Write-Host '=== summary ==='
    $script:Results | ForEach-Object { Write-Host $_ }
    Write-Host ("Window classes: " + (($script:Classes.GetEnumerator() | Sort-Object Name | ForEach-Object { "{0} = '{1}'" -f $_.Name, $_.Value }) -join '; '))
    Write-Host ("Test processes left running: {0}" -f $leftover.Count)
    Remove-Item -LiteralPath $script:Dir -Recurse -Force -ErrorAction SilentlyContinue
    if (-not $NoRegistryRestore) {
        if (-not (Restore-TcRegistry $backup $existed)) { $script:Fail++ }
    }
    Write-Host ("Failures: {0}" -f $script:Fail)
}
exit $script:Fail
