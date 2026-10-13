<#
.SYNOPSIS
    Feature 125 probe (GitHub issue #5): what Change Directory does with a UNC path that names a
    server but no share (\\server\), and what the panel does at the root of a share.

.DESCRIPTION
    Rows (names for -Only); every row starts its own instance in English and ends it:

      S1  Change Directory  \\localhost\           S2  \\localhost          S3  \\<COMPUTERNAME>\
      S4  Change Directory  \\                      (no server)
      S5  Change Directory  \\tc125-no-such-host\   (a server that does not exist)
      U1  Change Directory  \\localhost\C$ , then Backspace (the parent of a share's root)
      X1  Change Directory  \\localhost\ and WM_CLOSE 300 ms later (an enumeration may be running)

    Each row reports: the windows that appeared (message boxes are answered OK), the panel's
    location afterwards (the text Change Directory opens with), the names recognized in the left
    panel (capture + text recognition; the crop is kept in -ShotDir), the exit code.

    With -Expect measure (default) every row is INFO - the probe only records. With
    -Expect fixed the rows get verdicts:
      S1-S3  no error window; the panel's location names the server (net:\\<server>) and the
             panel lists the share "TcProbe125" when it exists (see -Share), else INFO
      S4     no crash; a message or a location - recorded
      S5     ends with a message within 60 s, the panel stays where it was
      U1     the location after Backspace is recorded; no error window
      X1     exit code 0, no window at exit, no report

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.PARAMETER Exe      tandemcommander.exe under test
.PARAMETER Share    name of a visible share of this computer to look for (optional)
.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('measure', 'fixed')][string]$Expect = 'measure',
    [string]$OutFile,
    [string[]]$Only,
    [string]$ShotDir,
    [string]$Share
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\124-regedt-key-text\probe\shotocr_lib.ps1')

$Root = $TempRoot + '\tc125'
$StartDir = $Root + '\start'
if (-not $ShotDir) { $ShotDir = $Root + '\shots' }
$Fixed = ($Expect -eq 'fixed')
$Computer = $env:COMPUTERNAME

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P {
    $a = @('-t', 'T125', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    # windows of the start (a first-run notice of a newly found plug-in, ...) are recorded and answered
    $r = Serve $p.Id 8
    if ($r.Messages.Count) { Out ('           at start: ' + (Msgs $r)) }
    return $p.Id
}
function Panel-Text([int]$Id, [string]$Name) {
    $main = Get-Main $Id; $list = Get-LeftList $Id
    $rc = [Shot124]::RelRect($main, $list); $rc[1] -= 48; $rc[3] = [Math]::Min($rc[3] + 48, 420)
    $s = Shot-Read $main $list (Join-Path $ShotDir ($Expect + '_' + $Name + '.png')) 3 $rc
    return ($s.Lines -join ' | ')
}
function V2([bool]$ok) { if (-not $Fixed) { return 'INFO' }; return (V $ok) }

function Row-Path([string]$Case, [string]$Text, [string]$Kind) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-P
        $loc0 = Get-Loc $id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $held = Do-ChangeDir $id $Text
        $r = Serve $id 90
        $secs = $sw.Elapsed.TotalSeconds
        $fatal = $r.Fatal
        Sync $id; Start-Sleep -Milliseconds 2500    # a listing may arrive from a worker
        $loc = Get-Loc $id
        $seen = Panel-Text $id $Case
        $facts = ("typed '{0}' (held {1}); windows: {2}; location before '{3}', after '{4}'; {5:N1} s; panel: {6}" -f $Text, $held, (Msgs $r), (Esc $loc0), (Esc $loc), $secs, (Esc $seen))
        $ok = $true
        if ($Kind -eq 'server') {
            $ok = ($r.Messages.Count -eq 0) -and ($loc -match '^net:\\\\') -and (-not $fatal)
            if ($ok -and $Share) { $ok = ((Ocr-Has @($seen) $Share) -ne 'no'); $facts += ("; share '{0}' listed: {1}" -f $Share, $ok) }
        }
        elseif ($Kind -eq 'nohost') { $ok = ($r.Messages.Count -ge 1) -and (-not $r.TimedOut) -and (-not $fatal) }
        else { $ok = (-not $fatal) }
        Row $Case 'CD' (V2 $ok) $facts
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}
function Row-Up {
    if (-not (Want 'U1')) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-P
        [void](Do-ChangeDir $id '\\localhost\C$')
        $r = Serve $id 60
        Sync $id; Start-Sleep -Milliseconds 1500
        $loc1 = Get-Loc $id
        Key $id 0x08                                   # Backspace: the parent directory
        $r2 = Serve $id 60
        Sync $id; Start-Sleep -Milliseconds 2500
        $loc2 = Get-Loc $id
        $fatal = $r2.Fatal
        Row 'U1' 'UP' (V2 (($r.Messages.Count + $r2.Messages.Count) -eq 0 -and -not $fatal)) ("at '{0}' (windows: {1}; panel text not recorded); Backspace -> '{2}' (windows: {3})" -f (Esc $loc1), (Msgs $r), (Esc $loc2), (Msgs $r2))
    }
    catch { Row 'U1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'U1' $id $fatal $before } }
}
function Row-Exit {
    if (-not (Want 'X1')) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P
        $dlg = Open-ByCmd $id 862
        $ctl = Find-Ctl $dlg 210
        [void][Drv098f]::SetText($ctl, '\\localhost\', 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 300
        Row 'X1' 'CD' 'INFO' 'typed \\localhost\, WM_CLOSE 300 ms later'
    }
    catch { Row 'X1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'X1' $id $null $before } }
}

# ---- rows of the fix (feature 125) ----------------------------------------------------------
$MenuClass = 'PopupMenuClass'
$WaitClass = 'SalamanderSaveBits'
function Set-Seam([string]$Shares, [string]$Delay, [string]$Err) {
    $env:TC_PROBE_UNC_SHARES = $Shares; $env:TC_PROBE_UNC_DELAY = $Delay; $env:TC_PROBE_UNC_ERROR = $Err
}
function Wait-Menu([int]$Id, [double]$Seconds = 60) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        $m = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq $MenuClass }) | Select-Object -First 1
        if ($m) { Start-Sleep -Milliseconds 500; return $m }
        $box = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::Txt($_) -ne 'Change Directory' -and [Drv098f]::Txt($_) -ne '' }) | Select-Object -First 1   # (an untitled dialog is the splash screen)
        if ($box) { return [IntPtr]::Zero }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
# the lines of the menu, top to bottom (capture of the menu window, text recognition at one size)
function Menu-Lines([IntPtr]$Menu, [string]$Name) {
    $png = Join-Path $ShotDir ($Expect + '_' + $Name + '.png')
    [void][Shot124]::Capture($Menu, $png + '.full.png')
    $rc = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($Menu, [ref]$rc)
    [Shot124]::Crop($png + '.full.png', $png, 0, 0, ($rc.Right - $rc.Left), ($rc.Bottom - $rc.Top), 3)
    Remove-Item -LiteralPath ($png + '.full.png') -Force
    return @(Ocr-File $png)
}
function Menu-Key([IntPtr]$Menu, [int]$Vk) {
    [void][Drv098f]::PostMessageW($Menu, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($Menu, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)
    Start-Sleep -Milliseconds 250
}
function Type-Path([int]$Id, [string]$Text) {
    $dlg = Open-ByCmd $Id 862
    if ($dlg -eq [IntPtr]::Zero) { throw 'Change Directory (862) opened no window' }
    $ctl = Find-Ctl $dlg 210
    [void][Drv098f]::SetText($ctl, $Text, 5000)
    Click-Ok $dlg
}
# index of the first recognized line that holds the word (-1 = none)
function Line-Of([string[]]$Lines, [string]$Word) {
    for ($i = 0; $i -lt $Lines.Count; $i++) { if ((Ocr-Has @($Lines[$i]) $Word) -ne 'no') { return $i } }
    return -1
}

# L1: the list (seam): folder shares only, visible first, hidden after them; Esc closes it
function Row-List {
    if (-not (Want 'L1')) { return }
    $before = Reports; $id = 0; $fatal = $null
    $czech = 'Sd' + [char]0x00ED + 'len' + [char]0x00E9
    try {
        Set-Seam ('NETLOGON|IPC$*2147483651|C$*2147483648|apps|HP LaserJet*1|ADMIN$*2147483648|Home|archiv$|DATA|' + $czech + '|R&D') '' ''
        $id = Start-P
        $loc0 = Get-Loc $id
        Type-Path $id '\\tcprobe125\'
        $menu = Wait-Menu $id 30
        if ($menu -eq [IntPtr]::Zero) { Row 'L1' 'MENU' 'FAIL' ('no menu; windows: ' + ((Get-Tops $id | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        $lines = Menu-Lines $menu 'L1_menu'
        $want = @('apps', 'DATA', 'Home', 'NETLOGON', 'R&D', $czech, 'ADMIN$', 'archiv$', 'C$')
        Row 'L1' 'LOOK' 'INFO' ("the menu as recognized (short names with '$' are read badly - see the crop L1_menu.png): {0}" -f (Esc ($lines -join ' | ')))
        Menu-Key $menu 0x1B                                 # Esc
        $r = Serve $id 20
        $fatal = $r.Fatal
        $loc = Get-Loc $id
        $boxes = @($r.Messages | Where-Object { $_ -ne 'Change Directory dialog opened' })
        Row 'L1' 'ESC' (V ($boxes.Count -eq 0 -and $loc -ceq $loc0 -and ($r.Messages -contains 'Change Directory dialog opened'))) ("after Esc: windows: {0}; location '{1}' (before '{2}')" -f (Msgs $r), (Esc $loc), (Esc $loc0))
    }
    catch { Row 'L1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' '' ''; if ($id) { End-Row 'L1' $id $fatal $before } }
}

# L2: the content and the order of the list, exactly: the k-th item is chosen (k times Down, Enter)
# and the path the program then tries is read from its error box (the server does not exist)
function Row-Items {
    if (-not (Want 'L2')) { return }
    $before = Reports; $id = 0; $fatal = $null
    $czech = 'Sd' + [char]0x00ED + 'len' + [char]0x00E9
    $want = @('apps', 'DATA', 'Home', 'NETLOGON', 'R&D', $czech, 'ADMIN$', 'archiv$', 'C$')
    try {
        Set-Seam ('NETLOGON|IPC$*2147483651|C$*2147483648|apps|HP LaserJet*1|ADMIN$*2147483648|Home|archiv$|DATA|' + $czech + '|R&D') '' ''
        $id = Start-P
        $got = @()
        for ($k = 1; $k -le $want.Count + 1; $k++) {
            Type-Path $id '\\tcprobe125\'
            $menu = Wait-Menu $id 30
            if ($menu -eq [IntPtr]::Zero) { $got += '<no menu>'; break }
            for ($d = 0; $d -lt $k; $d++) { Menu-Key $menu 0x28 }
            Menu-Key $menu 0x0D
            # the server does not exist: an error box comes (answered OK), then Change Directory opens
            # again holding the path that was tried - the chosen share, exactly
            $sw = [Diagnostics.Stopwatch]::StartNew(); $tried = $null
            while ($sw.Elapsed.TotalSeconds -lt 90 -and $null -eq $tried) {
                foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) {
                    $d = WinDesc $h
                    if ($d -match $FatalRx) { $fatal = $d; $tried = '<fatal>'; break }
                    if ([Drv098f]::Txt($h) -eq 'Change Directory') {
                        $ctl = Find-Ctl $h 210
                        $tried = [Drv098f]::GetText($ctl, 5000)
                        Close-Win $h
                    }
                    else { Start-Sleep -Milliseconds 300; Click-Ok $h }
                    Start-Sleep -Milliseconds 400
                    break
                }
                Start-Sleep -Milliseconds 150
            }
            if ($fatal) { break }
            if ($tried -and $tried.StartsWith('\\tcprobe125\')) { $got += $tried.Substring(13) } else { $got += ('<' + $tried + '>') }
            Start-Sleep -Milliseconds 500
        }
        $firstN = @($got | Select-Object -First $want.Count)
        $same = ($firstN.Count -eq $want.Count); for ($i = 0; $same -and $i -lt $want.Count; $i++) { if ($firstN[$i] -cne $want[$i]) { $same = $false } }
        $wrap = $got[$want.Count]
        Row 'L2' 'ITEMS' (V ($same -and $wrap -ceq $want[0])) ("item k of the list, k = 1..{0}: {1}; expected: {2}; item {3} (one more Down wraps to the first): {4}" -f $want.Count, (($firstN | ForEach-Object { Esc $_ }) -join ' , '), (($want | ForEach-Object { Esc $_ }) -join ' , '), ($want.Count + 1), (Esc $wrap))
    }
    catch { Row 'L2' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' '' ''; if ($id) { End-Row 'L2' $id $fatal $before } }
}

# P1 (seam list) / R1 (the real server list of this computer): pick C$ on \\localhost
function Row-Pick([string]$Case, [bool]$Seam) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        if ($Seam) { Set-Seam 'C$*2147483648|ADMIN$*2147483648|IPC$*2147483651' '' '' } else { Set-Seam '' '' '' }
        $id = Start-P
        Type-Path $id '\\localhost\'
        $menu = Wait-Menu $id 60
        if ($menu -eq [IntPtr]::Zero) { Row $Case 'MENU' 'FAIL' ('no menu; windows: ' + ((Get-Tops $id | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        $lines = Menu-Lines $menu ($Case + '_menu')
        Row $Case 'LOOK' 'INFO' ("the menu as recognized (see the crop): {0}" -f (Esc ($lines -join ' | ')))
        Menu-Key $menu 0x28; Menu-Key $menu 0x28; Menu-Key $menu 0x0D     # Down, Down, Enter: the second item
        $r = Serve $id 60
        $fatal = $r.Fatal
        Sync $id; Start-Sleep -Milliseconds 1500
        $loc = Get-Loc $id
        Row $Case 'PICK' (V ($r.Messages.Count -eq 0 -and $loc -ieq '\\localhost\C$')) ("after Down, Down, Enter: windows: {0}; location '{1}' (expected \\localhost\C`$)" -f (Msgs $r), (Esc $loc))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' '' ''; if ($id) { End-Row $Case $id $fatal $before } }
}

# E1 (seam error 53) / E2 (a host that does not exist, the real network) / N1 (only non-folder shares)
function Row-Error([string]$Case, [string]$Text, [string]$Shares, [string]$Err, [string]$Expected) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        Set-Seam $Shares '' $Err
        $id = Start-P
        $loc0 = Get-Loc $id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Type-Path $id $Text
        $r = Serve $id 120
        $secs = $sw.Elapsed.TotalSeconds
        $fatal = $r.Fatal
        $loc = Get-Loc $id
        $box = @($r.Messages | Where-Object { $_ -ne 'Change Directory dialog opened' })
        $ok = ($box.Count -eq 1) -and ($box[0] -match [regex]::Escape($Expected)) -and ($box[0] -match [regex]::Escape($Text)) -and ($loc -ceq $loc0) -and (-not $r.TimedOut)
        Row $Case 'BOX' (V $ok) ("typed '{0}': windows: {1}; expected one box with '{2}'; {3:N1} s; location '{4}'" -f $Text, (Msgs $r), $Expected, $secs, (Esc $loc))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' '' ''; if ($id) { End-Row $Case $id $fatal $before } }
}

# A1: the path comes from the command line (-l \\localhost\) with a slow answer (seam, 3 s): the
# program starts, the list is offered, the pick is opened
function Row-CmdLine {
    if (-not (Want 'A1')) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        Set-Seam 'C$*2147483648|ADMIN$*2147483648' '3000' ''
        $a = @('-t', 'T125', '-l', '"\\localhost\\"', '-r', ('"{0}"' -f $StartDir), '-p', '1')
        $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $menu = Wait-Menu $id 60
        if ($menu -eq [IntPtr]::Zero) { Row 'A1' 'MENU' 'FAIL' ('no menu at start; windows: ' + ((Get-Tops $id | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        Menu-Key $menu 0x28; Menu-Key $menu 0x28; Menu-Key $menu 0x0D
        $r = Serve $id 60
        $fatal = $r.Fatal
        Sync $id; Start-Sleep -Milliseconds 2000
        $loc = Get-Loc $id
        Row 'A1' 'START' (V ($r.Messages.Count -eq 0 -and $loc -ieq '\\localhost\C$')) ("started with -l \\localhost\ ; the list came; Down, Down, Enter: windows: {0}; location '{1}' (expected \\localhost\C`$)" -f (Msgs $r), (Esc $loc))
    }
    catch { Row 'A1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' '' ''; if ($id) { End-Row 'A1' $id $fatal $before } }
}

# W2: Esc in the wait window - a real key (the program reads the keyboard state), so only on
# the visible desktop and only while the program's own window is the active one; then the
# program is closed at once, the abandoned request still running (seam delay 8 s)
if (-not ('Key125' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Key125
{
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    public static uint ForegroundPid() { uint pid; GetWindowThreadProcessId(GetForegroundWindow(), out pid); return pid; }
    // makes the window the active one: the right to do so is borrowed from the thread that has it now
    public static void Activate(IntPtr h)
    {
        uint pid; uint fg = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
        uint me = GetCurrentThreadId();
        bool attached = fg != 0 && fg != me && AttachThreadInput(me, fg, true);
        BringWindowToTop(h); SetForegroundWindow(h);
        if (attached) AttachThreadInput(me, fg, false);
    }
    public static void Press(byte vk) { keybd_event(vk, 0, 0, UIntPtr.Zero); System.Threading.Thread.Sleep(60); keybd_event(vk, 0, 2, UIntPtr.Zero); }
}
"@
}
function Row-WaitEsc {
    if (-not (Want 'W2')) { return }
    if ($env:TC_PROBE_ALLOW_VISIBLE_DESKTOP -ne '1') { Row 'W2' 'ESC' 'NOT DRIVEN' 'a real Esc key needs the visible desktop'; return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        Set-Seam 'DATA|apps' '8000' ''
        $id = Start-P
        $loc0 = Get-Loc $id
        [Key125]::Activate((Get-Main $id)); Start-Sleep -Milliseconds 400
        Type-Path $id '\\tcprobe125\'
        $sw = [Diagnostics.Stopwatch]::StartNew(); $w = $null
        while ($sw.Elapsed.TotalSeconds -lt 5 -and -not $w) {
            $w = @([Drv098f]::Top([uint32]$id) | Where-Object { [Drv098f]::Cls($_) -eq $WaitClass }) | Select-Object -First 1
            if (-not $w) { Start-Sleep -Milliseconds 100 }
        }
        if (-not $w) { Row 'W2' 'ESC' 'FAIL' 'no wait window within 5 s'; return }
        if ([Key125]::ForegroundPid() -ne [uint32]$id) { [Key125]::Activate((Get-Main $id)); Start-Sleep -Milliseconds 400 }
        if ([Key125]::ForegroundPid() -ne [uint32]$id) {
            Row 'W2' 'ESC' 'NOT DRIVEN' 'the program under test is not the active window - the key is not pressed into another program'
            $menu = Wait-Menu $id 30; if ($menu -ne [IntPtr]::Zero) { Menu-Key $menu 0x1B }
            $r = Serve $id 20; $fatal = $r.Fatal
            return
        }
        Start-Sleep -Milliseconds 300
        $pressedAt = $sw.Elapsed.TotalSeconds
        [Key125]::Press(0x1B)
        $gone = -1
        while ($sw.Elapsed.TotalSeconds -lt ($pressedAt + 4)) {
            if (@([Drv098f]::Top([uint32]$id) | Where-Object { [Drv098f]::Cls($_) -eq $WaitClass }).Count -eq 0) { $gone = $sw.Elapsed.TotalSeconds - $pressedAt; break }
            Start-Sleep -Milliseconds 50
        }
        Start-Sleep -Milliseconds 700
        $menus = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq $MenuClass }).Count
        $dlgs = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::Txt($_) -eq 'Change Directory' })
        $loc = Get-Loc $id
        Row 'W2' 'ESC' (V ($gone -ge 0 -and $gone -lt 2 -and $menus -eq 0 -and $dlgs.Count -eq 1 -and $loc -ceq $loc0)) ("Esc {0:N1} s after the wait window: the wait window closed after {1:N2} s (the answer would come after 8 s); share list shown: {2}; Change Directory dialog back: {3}; location '{4}' (before '{5}')" -f $pressedAt, $gone, $menus, $dlgs.Count, (Esc $loc), (Esc $loc0))
        foreach ($d in $dlgs) { Close-Win $d }
        Start-Sleep -Milliseconds 400
        # the request is still out (about 6 s left): close the program now
        $atClose = $sw.Elapsed.TotalSeconds
        [void][Drv098f]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $p = $script:Procs[$id]; $ended = $p.WaitForExit(6000)
        Row 'W2' 'EXIT' (V ($ended -and $p.ExitCode -eq 0 -and ($sw.Elapsed.TotalSeconds -lt 8.4))) ("closed {0:N1} s after the start of the request (answer due at 8.4 s): ended {1}, exit code {2}, {3:N1} s after the close" -f $atClose, $ended, $(if ($ended) { $p.ExitCode } else { 'n/a' }), ($sw.Elapsed.TotalSeconds - $atClose))
        if ($ended) { $id = 0 }                                  # (ended by this row: no END row)
    }
    catch { Row 'W2' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' '' ''; if ($id) { End-Row 'W2' $id $fatal $before } }
}

# W1: a slow server (seam delay 6 s): the wait window appears, then the menu
function Row-Wait {
    if (-not (Want 'W1')) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        Set-Seam 'DATA|apps' '6000' ''
        $id = Start-P
        Type-Path $id '\\tcprobe125\'
        $sw = [Diagnostics.Stopwatch]::StartNew(); $waitAt = -1; $waitText = ''
        while ($sw.Elapsed.TotalSeconds -lt 5) {
            $w = @([Drv098f]::Top([uint32]$id) | Where-Object { [Drv098f]::Cls($_) -eq $WaitClass }) | Select-Object -First 1
            if ($w) { $waitAt = $sw.Elapsed.TotalSeconds; $waitText = (Shot-Read $w $w (Join-Path $ShotDir ($Expect + '_W1_wait.png')) 3 @(0, 0, 900, 200)).Lines -join ' | '; break }
            Start-Sleep -Milliseconds 100
        }
        $menu = Wait-Menu $id 30
        $menuAt = $sw.Elapsed.TotalSeconds
        $waitGone = (@([Drv098f]::Top([uint32]$id) | Where-Object { [Drv098f]::Cls($_) -eq $WaitClass }).Count -eq 0)
        Row 'W1' 'WAIT' (V ($waitAt -ge 0 -and $waitAt -lt 3 -and $menu -ne [IntPtr]::Zero -and $waitGone -and ((Ocr-Has @($waitText) 'tcprobe125') -ne 'no'))) ("wait window at {0:N1} s: '{1}'; menu at {2:N1} s: {3}; wait window gone then: {4}" -f $waitAt, (Esc $waitText), $menuAt, ($menu -ne [IntPtr]::Zero), $waitGone)
        Row 'W1' 'ESC' 'NOT DRIVEN' 'Esc / Close in the wait window read the real keyboard and mouse position (GetAsyncKeyState, GetMessagePos) - a step for a person'
        if ($menu -ne [IntPtr]::Zero) { Menu-Key $menu 0x1B }
        $r = Serve $id 20; $fatal = $r.Fatal
    }
    catch { Row 'W1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' '' ''; if ($id) { End-Row 'W1' $id $fatal $before } }
}

# C1: WM_CLOSE to the main window while the menu is open; C2: while the server is being read
function Row-Close([string]$Case, [string]$Delay) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        Set-Seam 'DATA|apps' $Delay ''
        $id = Start-P
        Type-Path $id '\\tcprobe125\'
        if ($Delay) { Start-Sleep -Milliseconds 1500; $state = 'the server is being read (seam delay ' + $Delay + ' ms)' }
        else { $menu = Wait-Menu $id 30; $state = 'menu open: ' + ($menu -ne [IntPtr]::Zero) }
        [void][Drv098f]::PostMessageW((Get-Main $id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw = [Diagnostics.Stopwatch]::StartNew(); $seen = @{}
        while ($sw.Elapsed.TotalSeconds -lt 40 -and (Test-Alive $id)) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) {
                $k = $h.ToInt64(); if ($seen.ContainsKey($k)) { continue }
                $seen[$k] = (WinDesc $h)
                if ([Drv098f]::Cls($h) -eq $MenuClass) { Start-Sleep -Milliseconds 600; if ([Drv098f]::IsWindow($h)) { Menu-Key $h 0x1B } }
                elseif ([Drv098f]::Cls($h) -eq '#32770') { Start-Sleep -Milliseconds 600; Close-Win $h }
            }
            Start-Sleep -Milliseconds 150
        }
        $alive = Test-Alive $id
        $ec = $(if ($alive) { 'still running after 40 s' } else { ExitCodeOf $id })
        $rep = @(Take-Reports $before)
        # the program may close (exit 0) or stay because a window was open - both are sound; a crash,
        # a hang (no answer to WM_NULL) or a report is not
        $resp = $true; if ($alive) { $resp = [Drv098f]::Send((Get-Main $id), 0, 0, 0, 10000) }
        Row $Case 'CLOSE' (V ($rep.Count -eq 0 -and $resp -and ($alive -or $ec -eq '0x00000000'))) ("{0}; WM_CLOSE to the main window; windows seen meanwhile: {1}; program: {2}; answers: {3}; reports {4}" -f $state, $(if ($seen.Count) { ($seen.Values -join ' || ') } else { 'none' }), $ec, $resp, $rep.Count)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { Set-Seam '' '' ''; if ($id -and (Test-Alive $id)) { End-Row $Case $id $null $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc125_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    [void][IO.Directory]::CreateDirectory($ShotDir)
    Set-Config
    Out ("unc_probe (feature 125, issue #5), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; computer {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), $Computer, $existed, $regHash)
    Out ("Plug-in : plugins\nethood\nethood.spl present next to the program: {0}; share looked for: {1}" -f (Test-Path -LiteralPath (Join-Path (Split-Path $Exe) 'plugins\nethood\nethood.spl')), $(if ($Share) { $Share } else { '(none)' }))
    Out ''
    if ($Fixed) {
        Row-List
        Row-Items
        Row-Pick 'P1' $true
        Row-Pick 'R1' $false
        Row-Error 'E1' '\\tcprobe125\' '' '53' '(53)'
        Row-Error 'E2' '\\tc125-no-such-host\' '' '' 'Error:'
        Row-Error 'N1' '\\tcprobe125\' 'IPC$*2147483651|HP LaserJet*1' '' 'A share name is missing'
        Row-Error 'S4' '\\' '' '' 'A server name is missing'
        Row-Wait
        Row-WaitEsc
        Row-CmdLine
        Row-Close 'C1' ''
        Row-Close 'C2' '8000'
        Row-Up
    }
    else {
        Row-Path 'S1' '\\localhost\' 'server'
        Row-Path 'S2' '\\localhost' 'server'
        Row-Path 'S3' ('\\' + $Computer + '\') 'server'
        Row-Path 'S4' '\\' 'root'
        Row-Path 'S5' '\\tc125-no-such-host\' 'nohost'
        Row-Up
        Row-Exit
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $StartDir)) { [IO.Directory]::Delete($LP + $StartDir, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    $ni = @($script:Rows | Where-Object { $_.Verdict -eq 'INFO' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}, INFO {3}. Left running: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $ni, $leftover.Count, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
