<#
.SYNOPSIS
    Feature 405 probe: a click on a panel tab whose switch shows a modal box (the FTP "keep the
    connection?" question of GitHub issue #22; here the error box of a tab whose folder was deleted)
    must not leave the tab strip waiting for a drag.

.DESCRIPTION
    One program start: left tabs A X1 X2 X3 B (A active), right R; X1..X3 are deleted after the
    start, so switching to one shows an error box inside the strip's WM_LBUTTONDOWN (SwitchToTab ->
    ChangeDir) and then falls back to another folder.

    The left button's state is what the program reads with GetKeyState: this probe attaches its
    thread to the program's GUI thread (AttachThreadInput) and sets VK_LBUTTON with
    SetKeyboardState - "pressed" before the posted WM_LBUTTONDOWN, "released" while the box is up
    (the user lets the button go over the box and answers it). Posted messages never change that
    state themselves.

      RELEASED  pressed on X1, released while the box is up, box answered; then the strip's capture
                (GetGUIThreadInfo) and a posted WM_MOUSEMOVE with MK_LBUTTON to tab B's place and a
                WM_LBUTTONUP - what the captured strip receives when the user next presses elsewhere
                and moves. Must: no capture, no tab moved.
      NOBUTTON  the same on X2, then a WM_MOUSEMOVE without a button (the issue's insert mark
                following the mouse) and a click at tab B's place. Must: no capture after the box,
                no tab moved (B becomes active - a normal click).
      HELD      control: pressed on X3 and held through the box, then moved onto A's place and
                released. A drag held from the press to the release still moves the tab (X3 first).
    NOT DRIVEN: the real FTP prompt with a real mouse (no input desktop here).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label = 'after',
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Tc405' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class Tc405
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] struct GUITHREADINFO
    {
        public int cbSize, flags;
        public IntPtr hwndActive, hwndFocus, hwndCapture, hwndMenuOwner, hwndMoveSize, hwndCaret;
        public RECT rcCaret;
    }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] s);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] s);
    [DllImport("user32.dll")] static extern short GetKeyState(int vk);
    [DllImport("user32.dll")] static extern bool GetGUIThreadInfo(uint tid, ref GUITHREADINFO gi);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();

    static uint me, target;

    public static IntPtr[] Strips(IntPtr main)
    {
        var list = new List<IntPtr>();
        EnumChildWindows(main, (h, l) => { if (GetDlgCtrlID(h) == 958 && IsWindowVisible(h)) list.Add(h); return true; }, IntPtr.Zero);
        list.Sort((a, b) => { RECT ra, rb; GetWindowRect(a, out ra); GetWindowRect(b, out rb); return ra.left.CompareTo(rb.left); });
        return list.ToArray();
    }
    public static int[] ClientSize(IntPtr h) { RECT r; GetClientRect(h, out r); return new int[] { r.right, r.bottom }; }
    public static void Post(IntPtr h, uint msg, int wp, int x, int y) { PostMessageW(h, msg, (IntPtr)wp, (IntPtr)(((y & 0xFFFF) << 16) | (x & 0xFFFF))); }

    // shares this thread's input state with the program's GUI thread (the window's thread)
    public static bool Attach(IntPtr main)
    {
        uint pid; target = GetWindowThreadProcessId(main, out pid); me = GetCurrentThreadId();
        return target != 0 && AttachThreadInput(me, target, true);
    }
    public static void Detach() { if (target != 0) { SetLButton(false); AttachThreadInput(me, target, false); target = 0; } }
    // sets VK_LBUTTON in the shared key state; returns what GetKeyState reads back ("" = not attached on this thread)
    public static string SetLButton(bool down)
    {
        if (target == 0 || GetCurrentThreadId() != me) return "not attached on this thread";
        var s = new byte[256]; GetKeyboardState(s);
        s[1] = (byte)(down ? 0x80 : 0);
        SetKeyboardState(s);
        return (GetKeyState(1) & 0x8000) != 0 ? "down" : "up";
    }
    public static IntPtr CaptureOf(IntPtr main)
    {
        uint pid; uint tid = GetWindowThreadProcessId(main, out pid);
        var gi = new GUITHREADINFO(); gi.cbSize = Marshal.SizeOf(typeof(GUITHREADINFO));
        if (!GetGUIThreadInfo(tid, ref gi)) return (IntPtr)(-1);
        return gi.hwndCapture;
    }
}
'@
}

$Root = $TempRoot + '\tc405'
$StartDir = $Root + '\start'
$CfgReg = $RegKey + '\Settings\Configuration'
$KeyL = 'HKCU:\Software\Tandem Commander\Settings\Left Panel'
$KeyR = 'HKCU:\Software\Tandem Commander\Settings\Right Panel'
$CM_SAVECONFIG = 687
$WM_MOUSEMOVE = 0x0200; $WM_LBUTTONDOWN = 0x0201; $WM_LBUTTONUP = 0x0202
$MK_LBUTTON = 1

function Prep-Registry($LeftTabs, [int]$LeftActive, $RightTabs, [int]$RightActive) {
    & cmd.exe /c "reg query `"$CfgReg`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    Set-Config
    & reg.exe add $CfgReg /v 'Panel Tabs' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add $CfgReg /v 'Theme Mode' /t REG_DWORD /d 0 /f | Out-Null
    foreach ($side in @(@('Left Panel', $LeftTabs, $LeftActive), @('Right Panel', $RightTabs, $RightActive))) {
        $p = $side[0]; $tabs = @($side[1]); $act = $side[2]
        & cmd.exe /c "reg delete `"$RegKey\Settings\$p\Tabs`" /f >nul 2>&1"
        for ($i = 0; $i -lt $tabs.Count; $i++) {
            $k = "$RegKey\Settings\$p\Tabs\$i"
            & reg.exe add $k /v 'Path' /t REG_SZ /d $tabs[$i] /f | Out-Null
            & reg.exe add $k /v 'View Type' /t REG_DWORD /d 2 /f | Out-Null
            & reg.exe add $k /v 'Sort Type' /t REG_DWORD /d 0 /f | Out-Null
            & reg.exe add $k /v 'Reverse Sort' /t REG_DWORD /d 0 /f | Out-Null
            & reg.exe add $k /v 'Enable Filter' /t REG_DWORD /d 0 /f | Out-Null
            & reg.exe add $k /v 'Filter' /t REG_SZ /d '*.*' /f | Out-Null
        }
        & reg.exe add "$RegKey\Settings\$p" /v 'Active Tab' /t REG_DWORD /d $act /f | Out-Null
    }
    return $true
}
function Start-Run([string]$Left, [string]$Right) {
    $a = @('-t', 'T405', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2000
    [void](Serve $p.Id 10)
    return $p.Id
}
function Strip([int]$Id) {
    $s = @([Tc405]::Strips((Get-Main $Id)))
    if ($s.Count -lt 1) { throw 'no tab strip (child id 958) found' }
    return $s[0]
}
function Snap([int]$Id) {
    Post-Cmd (Get-Main $Id) $CM_SAVECONFIG
    Start-Sleep -Milliseconds 400
    [void](Serve $Id 15)
    $res = @{}
    foreach ($side in @(@('L', $KeyL), @('R', $KeyR))) {
        $tabs = @()
        if (Test-Path -LiteralPath "$($side[1])\Tabs") {
            foreach ($k in @(Get-ChildItem -LiteralPath "$($side[1])\Tabs" | Sort-Object { [int]$_.PSChildName })) { $tabs += [string](Get-ItemProperty -LiteralPath $k.PSPath).Path }
        }
        $res[$side[0]] = [pscustomobject]@{ Tabs = $tabs; Active = [int](Get-ItemProperty -LiteralPath $side[1]).'Active Tab' }
    }
    return [pscustomobject]$res
}
function Leaf([string]$p) { if (-not $p) { return '' }; $t = $p.TrimEnd('\'); $i = $t.LastIndexOf('\'); if ($i -ge 0) { return $t.Substring($i + 1) }; return $t }
function Leaves($side) { return @($side.Tabs | ForEach-Object { Leaf $_ }) }
function Desc($s) { return ("left [{0}] active {1}; right [{2}]" -f ((Leaves $s.L) -join ' '), $s.L.Active, ((Leaves $s.R) -join ' ')) }
# the strip geometry (feature 404: TabsLeft 8, tab width capped at 20 average chars + padding)
function Geo([IntPtr]$Hs, [int]$Count) {
    $sz = [Tc405]::ClientSize($Hs); $W = $sz[0]; $H = $sz[1]
    $fm = [Tc404Font]::Metrics(); $avg = $fm[1]
    $left = 8; $maxW = 20 * $avg + 2 * 10 + 8 + 16 + 6
    $tw = [Math]::Floor(($W - $left - $H - 2) / $Count); if ($tw -gt $maxW) { $tw = $maxW }
    return [pscustomobject]@{ W = $W; H = $H; Left = $left; TabW = $tw; MidY = [int]((3 + $H) / 2) }
}
function TabCx($g, [int]$i) { return [int]($g.Left + $i * $g.TabW + $g.TabW / 2) }
function CapDesc([int]$Id, [IntPtr]$Hs) {
    $c = [Tc405]::CaptureOf((Get-Main $Id))
    if ($c -eq [IntPtr]::Zero) { return [pscustomobject]@{ Strip = $false; Text = 'no capture' } }
    if ($c -eq $Hs) { return [pscustomobject]@{ Strip = $true; Text = 'the strip holds the capture' } }
    return [pscustomobject]@{ Strip = $false; Text = ("capture {0}" -f $c) }
}

if (-not ('Tc404Font' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Tc404Font
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct LOGFONTW
    {
        public int lfHeight, lfWidth, lfEscapement, lfOrientation, lfWeight;
        public byte lfItalic, lfUnderline, lfStrikeOut, lfCharSet, lfOutPrecision, lfClipPrecision, lfQuality, lfPitchAndFamily;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string lfFaceName;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct TEXTMETRICW
    {
        public int tmHeight, tmAscent, tmDescent, tmInternalLeading, tmExternalLeading, tmAveCharWidth, tmMaxCharWidth,
            tmWeight, tmOverhang, tmDigitizedAspectX, tmDigitizedAspectY;
        public char tmFirstChar, tmLastChar, tmDefaultChar, tmBreakChar;
        public byte tmItalic, tmUnderlined, tmStruckOut, tmPitchAndFamily, tmCharSet;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool SystemParametersInfoW(uint a, uint b, ref LOGFONTW lf, uint c);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateFontIndirectW(ref LOGFONTW lf);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern bool GetTextMetricsW(IntPtr dc, out TEXTMETRICW tm);
    public static int[] Metrics()
    {
        LOGFONTW lf = new LOGFONTW();
        SystemParametersInfoW(0x1F, (uint)Marshal.SizeOf(typeof(LOGFONTW)), ref lf, 0);
        IntPtr f = CreateFontIndirectW(ref lf); IntPtr dc = GetDC(IntPtr.Zero); IntPtr old = SelectObject(dc, f);
        TEXTMETRICW tm; GetTextMetricsW(dc, out tm);
        SelectObject(dc, old); ReleaseDC(IntPtr.Zero, dc); DeleteObject(f);
        return new int[] { tm.tmHeight, tm.tmAveCharWidth };
    }
}
'@
}

# a press on tab $Index whose switch shows a box; $Release = the button goes up while the box is up.
# Returns the box text, the key states read back and the capture after the box.
function Press-Through-Box([int]$Id, [IntPtr]$Hs, $g, [int]$Index, [bool]$Release) {
    $k1 = [Tc405]::SetLButton($true)
    $known = Get-Tops $Id
    [Tc405]::Post($Hs, $WM_LBUTTONDOWN, $MK_LBUTTON, (TabCx $g $Index), $g.MidY)
    $box = Wait-NewWin $Id $known 8
    $k2 = 'kept down'
    if ($Release) { $k2 = [Tc405]::SetLButton($false) }
    $boxText = if ($box -ne [IntPtr]::Zero) { WinDesc $box } else { 'NO BOX' }
    $r = Serve $Id 15
    Start-Sleep -Milliseconds 300
    $cap = CapDesc $Id $Hs
    return [pscustomobject]@{ Box = ($box -ne [IntPtr]::Zero); Text = ("box {0}; key at press {1}, in the box {2}; after the box: {3}; windows: {4}" -f $boxText, $k1, $k2, $cap.Text, (Msgs $r)); Captured = $cap.Strip }
}

function Run-Switch {
    $S = $Root + '\switch'
    if (-not (Prep-Registry @("$S\A", "$S\X1", "$S\X2", "$S\X3", "$S\B") 0 @("$S\R") 0)) { Row 'SWITCH' 'SETUP' 'NOT DRIVEN' 'no stored configuration'; return }
    $id = 0
    try {
        $id = Start-Run "$S\A" "$S\R"
        foreach ($n in @('X1', 'X2', 'X3')) { [IO.Directory]::Delete($LP + "$S\$n", $true) }   # inside the fixture
        $Hs = Strip $id
        $g = Geo $Hs 5
        $s = Snap $id
        Row 'SWITCH' 'START' (V (((Leaves $s.L) -join ' ') -eq 'A X1 X2 X3 B' -and $s.L.Active -eq 0)) ("{0}; strip {1}x{2}, tab width {3}" -f (Desc $s), $g.W, $g.H, $g.TabW)
        $att = [Tc405]::Attach((Get-Main $id))
        Row 'SWITCH' 'SEAM' (V $att) ("AttachThreadInput to the program's GUI thread: {0}" -f $att)
        if (-not $att) { return }

        # RELEASED: the issue - the button goes up over the box, the next press-and-move elsewhere reaches the strip
        $p = Press-Through-Box $id $Hs $g 1 $true
        [Tc405]::Post($Hs, $WM_MOUSEMOVE, $MK_LBUTTON, (TabCx $g 4), $g.MidY + 40); Start-Sleep -Milliseconds 30
        for ($i = 1; $i -le 8; $i++) { [Tc405]::Post($Hs, $WM_MOUSEMOVE, $MK_LBUTTON, [int]((TabCx $g 1) + ((TabCx $g 4) + 10 - (TabCx $g 1)) * $i / 8), $g.MidY); Start-Sleep -Milliseconds 30 }
        [Tc405]::Post($Hs, $WM_LBUTTONUP, 0, (TabCx $g 4) + 10, $g.MidY)
        Start-Sleep -Milliseconds 700
        $s = Snap $id
        $L = Leaves $s.L
        $kept = ($L.Count -eq 5 -and $L[0] -eq 'A' -and $L[2] -eq 'X2' -and $L[3] -eq 'X3' -and $L[4] -eq 'B')
        Row 'SWITCH' 'RELEASED' (V ($p.Box -and -not $p.Captured -and $kept)) ($p.Text + '; then a move with the button to B and a release: ' + (Desc $s))

        # NOBUTTON: the issue's symptom - the mouse moves with no button, then a click
        $s0 = Snap $id
        $ix = [Array]::IndexOf([string[]](Leaves $s0.L), 'X2'); if ($ix -lt 0) { throw 'X2 not found' }
        $p = Press-Through-Box $id $Hs $g $ix $true
        for ($i = 1; $i -le 8; $i++) { [Tc405]::Post($Hs, $WM_MOUSEMOVE, 0, [int]((TabCx $g $ix) + ((TabCx $g 4) - (TabCx $g $ix)) * $i / 8), $g.MidY); Start-Sleep -Milliseconds 30 }
        $cap2 = CapDesc $id $Hs
        [Tc405]::Post($Hs, $WM_LBUTTONDOWN, $MK_LBUTTON, (TabCx $g 4), $g.MidY); Start-Sleep -Milliseconds 300
        [void](Serve $id 5)
        [Tc405]::Post($Hs, $WM_LBUTTONUP, 0, (TabCx $g 4), $g.MidY)
        Start-Sleep -Milliseconds 700
        $s = Snap $id
        $L = Leaves $s.L
        $o0 = @(Leaves $s0.L); $kept = ($L.Count -eq $o0.Count)   # every tab but the switched one (its location fell back) in its place
        for ($i = 0; $i -lt $o0.Count -and $kept; $i++) { if ($i -ne $ix -and $L[$i] -ne $o0[$i]) { $kept = $false } }
        Row 'SWITCH' 'NOBUTTON' (V ($p.Box -and -not $p.Captured -and -not $cap2.Strip -and $kept)) ($p.Text + ('; after a move without a button: {0}; then a click on B: ' -f $cap2.Text) + (Desc $s))

        # HELD (control): the button held from the press through the box to the release still drags
        $ix = [Array]::IndexOf([string[]](Leaves (Snap $id).L), 'X3'); if ($ix -lt 0) { throw 'X3 not found' }
        $p = Press-Through-Box $id $Hs $g $ix $false
        for ($i = 1; $i -le 10; $i++) { [Tc405]::Post($Hs, $WM_MOUSEMOVE, $MK_LBUTTON, [int]((TabCx $g $ix) + ((TabCx $g 0) - 10 - (TabCx $g $ix)) * $i / 10), $g.MidY); Start-Sleep -Milliseconds 30 }
        [void][Tc405]::SetLButton($false)
        [Tc405]::Post($Hs, $WM_LBUTTONUP, 0, (TabCx $g 0) - 10, $g.MidY)
        Start-Sleep -Milliseconds 700
        $s = Snap $id
        $L = Leaves $s.L
        $moved = ($L.Count -eq 5 -and $ix -gt 1 -and $s.L.Active -lt $ix)   # the dragged tab (active) left of its old place (the strip clamps at its left end: slot 0 or 1)
        Row 'SWITCH' 'HELD' (V ($p.Box -and $p.Captured -and $moved)) ($p.Text + ("; then held from index {0} onto A and released: " -f $ix) + (Desc $s))
        Row 'SWITCH' 'REAL-FTP' 'NOT DRIVEN' 'the real FTP leave question with a real mouse needs an input desktop and a server (release checklist)'
    }
    catch { Row 'SWITCH' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        try { [Tc405]::Detach() } catch { }
        if ($id -and (Test-Alive $id)) { $f = Fatal-Win $id; if ($f) { Row 'RUN' 'FATAL' 'FAIL' $f }; Kill-Mine $id }
    }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc405_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    foreach ($n in @('A', 'X1', 'X2', 'X3', 'B', 'R')) { NewDir ($Root + '\switch\' + $n) }
    Out ("tabs405_probe (feature 405) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; fixture {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, (Esc $Root))
    Out ''
    Run-Switch
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
