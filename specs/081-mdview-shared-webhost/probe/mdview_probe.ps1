<#
.SYNOPSIS
    Runtime probe for feature 081 (mdview on the shared WebView2 host). Drives
    ONE instance of a given tandemcommander.exe by POSTED MESSAGES only - no
    SendInput, no foreground games, nothing that could reach another instance
    the user may have open.

.DESCRIPTION
    Scenarios (-Scenario):
      smoke        open the control fixture; zoom in/out/reset, View Source
                   toggle, scheme cycling; assert the title tracks each one and
                   exactly one engine tree belongs to us
      hostile      open every hostile fixture in turn; assert one viewer window
                   each, no extra dialog, no growth of the engine tree
      keeper-warm  cold open, close, wait, assert the tree survived; measure a
                   warm open against a back-to-back open (feature 065 SC-002)
      keeper-crash kill the engine tree with no viewer open; assert the next
                   view works and the one after it is warm again
      cold-close   open and close within ~100 ms, ten times; assert the process
                   survives and a normal open still works afterwards
      cross-warm   open a .cpp first (the Code Viewer warms the tree), then a
                   .md; assert the Markdown view attaches warm
      all          every scenario above, in that order

    Every scenario prints measured values and PASS/FAIL; the script exits
    non-zero if any scenario failed.

.NOTES
    Windows PowerShell 5.1 compatible. Derived from
    specs/080-restart-manager-upgrade/probe/tc_drive.ps1.

    Debug builds of this product pop a "Heap Message" dialog saying
    "Detected memory leaks!" when they exit - that is the pre-existing leak
    recorded in feature 078, NOT something this feature introduced (see
    fix-log.md T002b). The probe dismisses it and never counts it as a failure.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Fixtures = "$env:TEMP\md081",
    [ValidateSet('smoke', 'hostile', 'keeper-warm', 'keeper-crash', 'cold-close', 'cross-warm', 'all')]
    [string]$Scenario = 'all',
    [string]$TitlePrefix = 'T081'
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Mdp
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(1024); GetWindowTextW(h, s, 1024); return s.ToString(); }

    public static List<IntPtr> Top(uint pid)
    {
        var l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { uint q; GetWindowThreadProcessId(h, out q); if (q == pid) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static List<IntPtr> Kids(IntPtr parent)
    {
        var l = new List<IntPtr>();
        EnumChildWindows(parent, delegate(IntPtr h, IntPtr p) { l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
}
'@

# --- window classes and command ids -----------------------------------------
$MainClass   = 'TandemCommanderMainWindowVer01'
$ViewerClass = 'MDView - WinLib Universal Window2'   # mdview's own viewer frame
$CodeViewCls = 'CodeView'                            # matched with -like, see Get-AnyViewer

$CM_VIEW        = 742   # main window: view the file under the cursor (F3)
$CM_ZOOMIN      = 109   # viewer window (src/plugins/mdview/mdview.h)
$CM_ZOOMRESET   = 111
$CM_OPENTEXT    = 101   # View Source toggle
$CM_SCHEME_NEXT = 210
$CM_SCHEME_PREV = 211

$script:Results = @()

function Add-Result([string]$name, [bool]$ok, [string]$detail) {
    $script:Results += [pscustomobject]@{ Scenario = $name; Ok = $ok; Detail = $detail }
    $tag = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Host ("  [{0}] {1}: {2}" -f $tag, $name, $detail)
}

# --- process / window helpers ------------------------------------------------

function Get-Main([int]$TargetPid) {
    foreach ($h in [Mdp]::Top([uint32]$TargetPid)) { if ([Mdp]::Cls($h) -eq $MainClass) { return $h } }
    return [IntPtr]::Zero
}

function Get-Viewers([int]$TargetPid) {
    $out = @()
    foreach ($h in [Mdp]::Top([uint32]$TargetPid)) {
        if ([Mdp]::IsWindowVisible($h) -and [Mdp]::Txt($h) -like '*Markdown Viewer*') { $out += $h }
    }
    return @($out)
}

function Get-AnyViewer([int]$TargetPid) {
    # any plug-in viewer window: mdview's or the Code Viewer's
    $out = @()
    foreach ($h in [Mdp]::Top([uint32]$TargetPid)) {
        if (-not [Mdp]::IsWindowVisible($h)) { continue }
        if ([Mdp]::Cls($h) -eq $MainClass) { continue }
        if ([Mdp]::Cls($h) -eq '#32770') { continue }   # a dialog, not a viewer
        $out += $h
    }
    return @($out)
}

function Get-Dialogs([int]$TargetPid) {
    $out = @()
    foreach ($h in [Mdp]::Top([uint32]$TargetPid)) {
        if ([Mdp]::IsWindowVisible($h) -and [Mdp]::Cls($h) -eq '#32770') { $out += $h }
    }
    return @($out)
}

# every msedgewebview2.exe whose parent chain reaches our pid (other apps on the
# machine run their own trees; they must never be counted or killed)
function Get-EngineProcs([int]$TargetPid) {
    $all = @(Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" -ErrorAction SilentlyContinue)
    if ($all.Count -eq 0) { return @() }
    $ours = @($all | Where-Object { $_.ParentProcessId -eq $TargetPid })
    $ourIds = @($ours | ForEach-Object { $_.ProcessId })
    # the broker's own children (renderer, GPU, crashpad)
    for ($i = 0; $i -lt 4; $i++) {
        $more = @($all | Where-Object { $ourIds -contains $_.ParentProcessId -and $ourIds -notcontains $_.ProcessId })
        if ($more.Count -eq 0) { break }
        $ours += $more
        $ourIds = @($ours | ForEach-Object { $_.ProcessId })
    }
    return @($ours)
}

function Post([IntPtr]$h, [int]$id) {
    [void][Mdp]::PostMessageW($h, 0x0111, [IntPtr]$id, [IntPtr]::Zero)   # WM_COMMAND
}

function Dismiss-Dialogs([int]$TargetPid) {
    foreach ($h in Get-Dialogs $TargetPid) {
        $b = [Mdp]::GetDlgItem($h, 2)   # IDOK
        if ($b -ne [IntPtr]::Zero) { [void][Mdp]::PostMessageW($b, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
    }
}

function Start-App([string]$leftRight) {
    $a = @('-t', $TitlePrefix, '-l', ('"{0}"' -f $leftRight), '-r', ('"{0}"' -f $leftRight))
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 150 }
    Start-Sleep -Seconds 3     # let plug-ins, panels and icon readers settle
    return $p.Id
}

function Stop-App([int]$TargetPid) {
    $m = Get-Main $TargetPid
    if ($m -ne [IntPtr]::Zero) { [void][Mdp]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }  # WM_CLOSE
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 400
        if (-not (Get-Process -Id $TargetPid -ErrorAction SilentlyContinue)) { return }
        Dismiss-Dialogs $TargetPid    # the pre-existing Debug leak report
    }
    Stop-Process -Id $TargetPid -Force -ErrorAction SilentlyContinue
}

# Puts the panel cursor on a named file and views it. The panel that F3 acts on
# is the ACTIVE one, which is why Start-App points both panels at the fixtures.
function Open-File([int]$TargetPid, [string]$fileName, [int]$timeoutSec = 25) {
    $m = Get-Main $TargetPid
    $lists = @([Mdp]::Kids($m) | Where-Object { [Mdp]::Cls($_) -eq 'SalamanderItemsBox' -and [Mdp]::IsWindowVisible($_) })
    if ($lists.Count -eq 0) { throw 'panel list window not found' }

    # Quick Search by typed name is fragile through posted messages; walk the
    # list instead. The order is: [..], directories, then files by name.
    $names = @(Get-ChildItem -LiteralPath $Fixtures -Directory | Sort-Object Name | ForEach-Object { $_.Name }) +
             @(Get-ChildItem -LiteralPath $Fixtures -File | Sort-Object Name | ForEach-Object { $_.Name })
    $idx = [array]::IndexOf($names, $fileName)
    if ($idx -lt 0) { throw "fixture '$fileName' not found in $Fixtures" }

    foreach ($l in $lists) {
        [void][Mdp]::PostMessageW($l, 0x0100, [IntPtr]0x24, [IntPtr]1)          # VK_HOME
        [void][Mdp]::PostMessageW($l, 0x0101, [IntPtr]0x24, [IntPtr]0xC0000001)
    }
    Start-Sleep -Milliseconds 300
    # VK_HOME lands on [..]; one Down per entry then reaches the file
    for ($i = 0; $i -le $idx; $i++) {
        foreach ($l in $lists) {
            [void][Mdp]::PostMessageW($l, 0x0100, [IntPtr]0x28, [IntPtr]1)      # VK_DOWN
            [void][Mdp]::PostMessageW($l, 0x0101, [IntPtr]0x28, [IntPtr]0xC0000001)
        }
        Start-Sleep -Milliseconds 25
    }
    Start-Sleep -Milliseconds 400

    $before = @(Get-AnyViewer $TargetPid).Count
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Post (Get-Main $TargetPid) $CM_VIEW
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        Start-Sleep -Milliseconds 80
        $now = @(Get-AnyViewer $TargetPid)
        if ($now.Count -gt $before) { return [pscustomobject]@{ Handle = $now[0]; Ms = [int]$sw.Elapsed.TotalMilliseconds } }
    }
    return [pscustomobject]@{ Handle = [IntPtr]::Zero; Ms = -1 }
}

function Close-Viewers([int]$TargetPid) {
    foreach ($h in Get-AnyViewer $TargetPid) {
        [void][Mdp]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)   # WM_CLOSE
    }
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Milliseconds 300
        if (@(Get-AnyViewer $TargetPid).Count -eq 0) { return $true }
    }
    return $false
}

# ============================================================================
# scenarios
# ============================================================================

function Test-Smoke {
    Write-Host "`n--- smoke: open the control fixture and exercise every command ---"
    $procId = Start-App $Fixtures
    try {
        $o = Open-File $procId '10-legit-control.md'
        if ($o.Handle -eq [IntPtr]::Zero) { Add-Result 'smoke/open' $false 'no viewer window appeared'; return }
        $title = [Mdp]::Txt($o.Handle)
        Add-Result 'smoke/open' ($title -like '*10-legit-control.md*Markdown Viewer*') "$([int]$o.Ms) ms, title '$title'"

        $eng = @(Get-EngineProcs $procId).Count
        Add-Result 'smoke/engine' ($eng -ge 1) "$eng engine process(es) belong to our pid"

        Post $o.Handle $CM_ZOOMIN;    Start-Sleep -Milliseconds 800
        $t1 = [Mdp]::Txt($o.Handle)
        Post $o.Handle $CM_ZOOMIN;    Start-Sleep -Milliseconds 800
        $t2 = [Mdp]::Txt($o.Handle)
        Post $o.Handle $CM_ZOOMRESET; Start-Sleep -Milliseconds 800
        $t3 = [Mdp]::Txt($o.Handle)
        Add-Result 'smoke/zoom' (($t1 -like '*(110%)*') -and ($t2 -like '*(120%)*') -and ($t3 -like '*(100%)*')) `
            "110% -> 120% -> reset 100% (titles: '$($t1 -replace '.*Viewer','')','$($t2 -replace '.*Viewer','')','$($t3 -replace '.*Viewer','')')"

        Post $o.Handle $CM_OPENTEXT; Start-Sleep -Milliseconds 900
        $s1 = [Mdp]::Txt($o.Handle)
        Post $o.Handle $CM_OPENTEXT; Start-Sleep -Milliseconds 900
        $s2 = [Mdp]::Txt($o.Handle)
        # .Contains, never -like: in a -like pattern '[Source]' is a character
        # class, so '*[Source]*' matches almost any string and the check would
        # be meaningless (it cost one run to notice).
        Add-Result 'smoke/source' ($s1.Contains('[Source]') -and -not $s2.Contains('[Source]')) `
            "after first toggle: '$($s1 -replace '.*Markdown Viewer','')', after second: '$($s2 -replace '.*Markdown Viewer','')'"

        Post $o.Handle $CM_SCHEME_NEXT; Start-Sleep -Milliseconds 1200
        Post $o.Handle $CM_SCHEME_PREV; Start-Sleep -Milliseconds 1200
        $alive = @(Get-AnyViewer $procId).Count -eq 1
        $dlg = @(Get-Dialogs $procId).Count
        Add-Result 'smoke/scheme' ($alive -and $dlg -eq 0) "viewer alive after scheme cycling, $dlg dialog(s)"
    }
    finally { Stop-App $procId }
}

function Test-Hostile {
    Write-Host "`n--- hostile: every hostile fixture opens, alone, with no dialog ---"
    $procId = Start-App $Fixtures
    try {
        $files = @(Get-ChildItem -LiteralPath $Fixtures -File -Filter '0*.md' | Sort-Object Name | ForEach-Object { $_.Name })
        $baseEngine = 0
        foreach ($f in $files) {
            $o = Open-File $procId $f
            if ($o.Handle -eq [IntPtr]::Zero) { Add-Result "hostile/$f" $false 'no viewer window appeared'; continue }
            Start-Sleep -Seconds 2      # give a hostile page time to misbehave
            $viewers = @(Get-AnyViewer $procId).Count
            $dialogs = @(Get-Dialogs $procId).Count
            $eng = @(Get-EngineProcs $procId).Count
            if ($baseEngine -eq 0) { $baseEngine = $eng }
            $title = [Mdp]::Txt($o.Handle)
            $ok = ($viewers -eq 1) -and ($dialogs -eq 0) -and ($eng -le $baseEngine + 1) -and ($title -like "*$f*")
            Add-Result "hostile/$f" $ok "$viewers viewer(s), $dialogs dialog(s), $eng engine proc(s), title ok=$($title -like "*$f*")"
            [void](Close-Viewers $procId)
        }
    }
    finally { Stop-App $procId }
}

function Test-KeeperWarm {
    Write-Host "`n--- keeper-warm: the tree survives a closed viewer; the next open is warm ---"
    $procId = Start-App $Fixtures
    try {
        $cold = Open-File $procId '10-legit-control.md'
        if ($cold.Handle -eq [IntPtr]::Zero) { Add-Result 'keeper/cold' $false 'no viewer'; return }
        Add-Result 'keeper/cold' $true "cold open $([int]$cold.Ms) ms"
        [void](Close-Viewers $procId)

        Start-Sleep -Seconds 65     # well past the browser tree's grace period
        $eng = @(Get-EngineProcs $procId).Count
        Add-Result 'keeper/alive-after-65s' ($eng -ge 1) "$eng engine process(es) still ours (keeper armed)"

        $warm = Open-File $procId '10b-linked.md'
        if ($warm.Handle -eq [IntPtr]::Zero) { Add-Result 'keeper/warm' $false 'no viewer'; return }
        [void](Close-Viewers $procId)
        $b2b = Open-File $procId '10-legit-control.md'
        [void](Close-Viewers $procId)

        $ok = ($b2b.Ms -gt 0) -and ($warm.Ms -le [Math]::Max(2 * $b2b.Ms, 1500))
        Add-Result 'keeper/warm' $ok "warm open $([int]$warm.Ms) ms vs back-to-back $([int]$b2b.Ms) ms (065 SC-002: within 2x)"
    }
    finally { Stop-App $procId }
}

function Test-KeeperCrash {
    Write-Host "`n--- keeper-crash: the tree dies, the next view still works and re-arms ---"
    $procId = Start-App $Fixtures
    try {
        $o = Open-File $procId '10-legit-control.md'
        if ($o.Handle -eq [IntPtr]::Zero) { Add-Result 'crash/setup' $false 'no viewer'; return }
        [void](Close-Viewers $procId)
        Start-Sleep -Seconds 3

        $procs = Get-EngineProcs $procId
        foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 3
        Add-Result 'crash/killed' (@(Get-EngineProcs $procId).Count -eq 0) "$($procs.Count) engine process(es) killed"

        $after = Open-File $procId '10-legit-control.md'
        Add-Result 'crash/view-after' ($after.Handle -ne [IntPtr]::Zero) "view after the crash: $([int]$after.Ms) ms"
        [void](Close-Viewers $procId)
        Start-Sleep -Seconds 2
        $again = Open-File $procId '10b-linked.md'
        [void](Close-Viewers $procId)
        Add-Result 'crash/rearm' ($again.Handle -ne [IntPtr]::Zero) "view after re-arm: $([int]$again.Ms) ms"
    }
    finally { Stop-App $procId }
}

function Test-ColdClose {
    Write-Host "`n--- cold-close: close the window while the engine is still starting, 10x ---"
    $procId = Start-App $Fixtures
    try {
        $survived = $true
        for ($i = 1; $i -le 10; $i++) {
            $m = Get-Main $procId
            Post $m $CM_VIEW
            Start-Sleep -Milliseconds 100      # inside the cold-start window
            foreach ($h in Get-AnyViewer $procId) {
                [void][Mdp]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            }
            Start-Sleep -Milliseconds 500
            if (-not (Get-Process -Id $procId -ErrorAction SilentlyContinue)) { $survived = $false; break }
        }
        Add-Result 'cold-close/survives' $survived '10 open-and-close-immediately cycles'
        if ($survived) {
            [void](Close-Viewers $procId)
            $o = Open-File $procId '10-legit-control.md'
            Add-Result 'cold-close/still-works' ($o.Handle -ne [IntPtr]::Zero) "a normal open afterwards: $([int]$o.Ms) ms"
            [void](Close-Viewers $procId)
        }
    }
    finally { if (Get-Process -Id $procId -ErrorAction SilentlyContinue) { Stop-App $procId } }
}

function Test-CrossWarm {
    Write-Host "`n--- cross-warm: the Code Viewer warms the tree for the Markdown Viewer ---"
    $procId = Start-App $Fixtures
    try {
        $cpp = Open-File $procId 'hello.cpp' 40
        if ($cpp.Handle -eq [IntPtr]::Zero) {
            Add-Result 'cross-warm/codeview' $false 'the Code Viewer did not open hello.cpp (is codeview enabled?)'
            return
        }
        Add-Result 'cross-warm/codeview' $true "Code Viewer opened in $([int]$cpp.Ms) ms ('$([Mdp]::Txt($cpp.Handle))')"
        [void](Close-Viewers $procId)
        Start-Sleep -Seconds 3

        $md = Open-File $procId '10-legit-control.md'
        if ($md.Handle -eq [IntPtr]::Zero) { Add-Result 'cross-warm/mdview' $false 'no Markdown viewer'; return }
        [void](Close-Viewers $procId)
        $b2b = Open-File $procId '10b-linked.md'
        [void](Close-Viewers $procId)

        $ok = ($b2b.Ms -gt 0) -and ($md.Ms -le [Math]::Max(2 * $b2b.Ms, 1500))
        Add-Result 'cross-warm/mdview' $ok "first Markdown view $([int]$md.Ms) ms vs back-to-back $([int]$b2b.Ms) ms"
    }
    finally { Stop-App $procId }
}

# ============================================================================

if (-not (Test-Path $Exe)) { throw "executable not found: $Exe" }
if (-not (Test-Path $Fixtures)) { throw "fixture folder not found: $Fixtures" }

Write-Host "mdview probe (feature 081)"
Write-Host "  exe      : $Exe"
Write-Host "  fixtures : $Fixtures"
Write-Host "  scenario : $Scenario"

switch ($Scenario) {
    'smoke'        { Test-Smoke }
    'hostile'      { Test-Hostile }
    'keeper-warm'  { Test-KeeperWarm }
    'keeper-crash' { Test-KeeperCrash }
    'cold-close'   { Test-ColdClose }
    'cross-warm'   { Test-CrossWarm }
    'all'          { Test-Smoke; Test-Hostile; Test-KeeperWarm; Test-KeeperCrash; Test-ColdClose; Test-CrossWarm }
}

$failed = @($script:Results | Where-Object { -not $_.Ok })
Write-Host "`n============================================================"
Write-Host ("  {0} checks, {1} failed" -f $script:Results.Count, $failed.Count)
foreach ($f in $failed) { Write-Host ("  FAILED: {0} - {1}" -f $f.Scenario, $f.Detail) }
Write-Host "============================================================"
if ($failed.Count -gt 0) { exit 1 }
exit 0
