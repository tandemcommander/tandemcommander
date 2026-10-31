<#
.SYNOPSIS
    Feature 346 probe: Shift+F6 opens the in-place rename (Quick Rename edit) over the focused
    item's name in a disk panel; Files > Rename in Place does the same; Enter renames, Esc cancels.

.DESCRIPTION
    Fixture %TEMP%\tc346\R holds the folder Dir1, the files a.txt and "voila e.txt" with accents
    (U+00E0, U+00E9) and the archive arch.zip (inner.txt). Left panel order: .., Dir1, a.txt,
    arch.zip, the accented file.

    Keys with Shift / Ctrl: the probe attaches its thread to the program's input queue, sets the
    modifiers in the shared key state and SENDS WM_KEYDOWN + WM_KEYUP to the panel list (the
    technique of specs/312-tabs-browser-keys/probe/tabs312_probe.ps1). Enter and Esc in the edit are
    the WM_CHAR the edit handles. No SendInput: no real keyboard.

    The in-place editor is the visible child "Edit" of the panel list (SalamanderItemsBox).
    Which item it edits: its text. Focus after a rename: Shift+F6 again shows the new name.

    Rows (one program start):
      S6-UPDIR   Shift+F6 on ".." opens nothing
      S6-FILE    Shift+F6 on a.txt: the edit over the name, text "a.txt", selection 0..1
      S6-ESC     Esc closes it; nothing renamed
      S6-ENTER   new text a2.txt + Enter: the file renamed on disk, the edit gone
      S6-FOCUS   Shift+F6 again edits "a2.txt" (focus stayed on the renamed item); Esc
      S6-DIR     Shift+F6 on Dir1: whole name selected (0..4); Esc
      S6-UTF8    Shift+F6 on the accented file: exact UTF-16 text, selection before the dot;
                 renamed to another accented name with Enter: exact name on disk
      CS6        Ctrl+Shift+F6 sent to the panel opens no edit (Restore Selection stays the
                 accelerator's)
      KEEPS      F6 alone, Alt+Shift+F6 open no edit
      MENU       the menu command (CM_QUICKRENAMEINPLACE) opens the edit on the focused item; Esc
      F2         CM_RENAMEFILE (F2) still opens the Rename dialog; Cancel
      ARCHIVE    inside arch.zip: Shift+F6 and the menu command open no edit
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib

if (-not ('Tc346' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class Tc346
{
    [StructLayout(LayoutKind.Sequential)] public struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public int x, y; }
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] public static extern bool GetKeyboardState(byte[] s);
    [DllImport("user32.dll")] public static extern bool SetKeyboardState(byte[] s);
    [DllImport("user32.dll")] public static extern bool PeekMessageW(out MSG m, IntPtr h, uint a, uint b, uint remove);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();

    // WM_KEYDOWN + WM_KEYUP sent to 'h' while the shared key state says Ctrl / Shift / Alt are down
    public static string KeyMods(IntPtr h, int vk, bool ctrl, bool shift, bool alt, uint timeout)
    {
        uint pid; uint tid = GetWindowThreadProcessId(h, out pid); uint me = GetCurrentThreadId();
        MSG m; PeekMessageW(out m, IntPtr.Zero, 0, 0, 0);
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed";
        string err = "";
        try
        {
            var old = new byte[256];
            GetKeyboardState(old);
            var st = (byte[])old.Clone();
            foreach (int k in new int[] { 0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5 }) st[k] = 0;
            var clean = (byte[])st.Clone();
            if (ctrl) { st[0x11] = 0x80; st[0xA2] = 0x80; }
            if (shift) { st[0x10] = 0x80; st[0xA0] = 0x80; }
            if (alt) { st[0x12] = 0x80; st[0xA4] = 0x80; }
            if (!SetKeyboardState(st)) err = "SetKeyboardState failed";
            else
            {
                IntPtr res;
                uint down = alt ? 0x0104u : 0x0100u, up = alt ? 0x0105u : 0x0101u;
                long lp = alt ? 0x20000001L : 1L;
                if (SendMessageTimeoutW(h, down, (IntPtr)vk, (IntPtr)lp, 0, timeout, out res) == IntPtr.Zero) err = "WM_KEYDOWN timed out";
                SendMessageTimeoutW(h, up, (IntPtr)vk, (IntPtr)unchecked((int)0xC0000001 | (int)(lp & 0x20000000L)), 0, timeout, out res);
            }
            SetKeyboardState(clean);
        }
        finally { AttachThreadInput(me, tid, false); }
        return err;
    }
    public static long Result(IntPtr h, uint msg, long w, long l, uint timeout)
    {
        IntPtr res;
        if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, timeout, out res) == IntPtr.Zero) return -1;
        return res.ToInt64();
    }
}
'@
}

$Root = $TempRoot + '\tc346'
$R = $Root + '\R'
$StartDir = $Root + '\start'
$Agrave = [string][char]0x00E0; $Eacute = [string][char]0x00E9; $Uuml = [string][char]0x00FC
$Accented = 'voil' + $Agrave + ' ' + $Eacute + '.txt'
$Accented2 = 'voil' + $Agrave + ' ' + $Uuml + '.txt'

# commands (src/resource.rh2)
$CM_RENAMEFILE = 754; $CM_QUICKRENAMEINPLACE = 2954
$VK_F6 = 0x75; $VK_HOME = 0x24; $VK_DOWN = 0x28; $VK_RETURN = 0x0D

function List([int]$Id) { return (Get-LeftList $Id) }
function KeyM([int]$Id, [int]$Vk, [bool]$Ctrl, [bool]$Shift, [bool]$Alt = $false) {
    $e = [Tc346]::KeyMods((List $Id), $Vk, $Ctrl, $Shift, $Alt, 30000)
    if ($e) { throw "key not driven: $e" }
    Start-Sleep -Milliseconds 300
    [void](Serve $Id 10)
}
function FocusItem([int]$Id, [int]$Downs) {
    Key $Id $VK_HOME
    for ($i = 0; $i -lt $Downs; $i++) { Key $Id $VK_DOWN }
}
# the in-place editor: a visible Edit child of the panel list, or Zero
function RenEdit([int]$Id) {
    $e = @([Drv098f]::Kids((List $Id)) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
    if ($e) { return $e }; return [IntPtr]::Zero
}
function Sel([IntPtr]$E) {
    $gs = [Tc346]::Result($E, 0x00B0, 0, 0, 5000)   # EM_GETSEL: LOWORD start, HIWORD end
    if ($gs -lt 0) { return 'timeout' }
    return ('{0}..{1}' -f ($gs -band 0xFFFF), (($gs -shr 16) -band 0xFFFF))
}
function EdChar([IntPtr]$E, [int]$Ch) {
    [void][Drv098f]::Send($E, 0x0102, $Ch, 1, 30000)   # WM_CHAR (Enter 13 / Esc 27)
    Start-Sleep -Milliseconds 400
}
function EdDesc([IntPtr]$E) {
    if ($E -eq [IntPtr]::Zero) { return 'no edit' }
    return ("edit '{0}' sel {1}" -f (Esc ([Drv098f]::GetText($E, 5000))), (Sel $E))
}
function Exists([string]$n) { return [IO.File]::Exists($LP + $R + '\' + $n) }
function End-Run([int]$Id) {
    if ($Id -and (Test-Alive $Id)) {
        $f = Fatal-Win $Id
        if ($f) { Row 'RUN' 'FATAL' 'FAIL' $f }
        Kill-Mine $Id
    }
}

function Run-Disk {
    $id = 0
    try {
        $id = Start-Tc $R
        Row 'DISK' 'START' (V ((Get-Main $id) -ne [IntPtr]::Zero)) ("left panel in {0}" -f (Esc $R))

        FocusItem $id 0
        KeyM $id $VK_F6 $false $true
        $e = RenEdit $id
        Row 'DISK' 'S6-UPDIR' (V ($e -eq [IntPtr]::Zero)) ("Shift+F6 on '..': " + (EdDesc $e))
        if ($e -ne [IntPtr]::Zero) { EdChar $e 27 }

        FocusItem $id 2
        KeyM $id $VK_F6 $false $true
        $e = RenEdit $id
        $d = EdDesc $e
        Row 'DISK' 'S6-FILE' (V ($e -ne [IntPtr]::Zero -and ([Drv098f]::GetText($e, 5000)) -ceq 'a.txt' -and (Sel $e) -eq '0..1')) ("Shift+F6 on a.txt: " + $d)
        if ($e -ne [IntPtr]::Zero) {
            [void][Drv098f]::SetText($e, 'zz.txt', 5000)
            EdChar $e 27
            $e2 = RenEdit $id
            Row 'DISK' 'S6-ESC' (V ($e2 -eq [IntPtr]::Zero -and (Exists 'a.txt') -and -not (Exists 'zz.txt'))) ("typed zz.txt, Esc: {0}; a.txt {1}, zz.txt {2}" -f (EdDesc $e2), (Exists 'a.txt'), (Exists 'zz.txt'))

            KeyM $id $VK_F6 $false $true
            $e = RenEdit $id
            [void][Drv098f]::SetText($e, 'a2.txt', 5000)
            EdChar $e 13
            [void](Serve $id 10)
            Start-Sleep -Milliseconds 800
            $e2 = RenEdit $id
            Row 'DISK' 'S6-ENTER' (V ($e2 -eq [IntPtr]::Zero -and (Exists 'a2.txt') -and -not (Exists 'a.txt'))) ("typed a2.txt, Enter: {0}; a2.txt {1}, a.txt {2}" -f (EdDesc $e2), (Exists 'a2.txt'), (Exists 'a.txt'))

            KeyM $id $VK_F6 $false $true
            $e = RenEdit $id
            $d = EdDesc $e
            Row 'DISK' 'S6-FOCUS' (V ($e -ne [IntPtr]::Zero -and ([Drv098f]::GetText($e, 5000)) -ceq 'a2.txt')) ("Shift+F6 again after the rename: " + $d)
            if ($e -ne [IntPtr]::Zero) { EdChar $e 27 }
        }
        else {
            Row 'DISK' 'S6-ESC' 'FAIL' 'no edit to cancel'
            Row 'DISK' 'S6-ENTER' 'FAIL' 'no edit to confirm'
            Row 'DISK' 'S6-FOCUS' 'FAIL' 'no edit'
        }

        FocusItem $id 1
        KeyM $id $VK_F6 $false $true
        $e = RenEdit $id
        $d = EdDesc $e
        Row 'DISK' 'S6-DIR' (V ($e -ne [IntPtr]::Zero -and ([Drv098f]::GetText($e, 5000)) -ceq 'Dir1' -and (Sel $e) -eq '0..4')) ("Shift+F6 on Dir1: " + $d)
        if ($e -ne [IntPtr]::Zero) { EdChar $e 27 }

        FocusItem $id 4
        KeyM $id $VK_F6 $false $true
        $e = RenEdit $id
        $d = EdDesc $e
        $ok = $e -ne [IntPtr]::Zero -and ([Drv098f]::GetText($e, 5000)) -ceq $Accented -and (Sel $e) -eq '0..7'
        if ($e -ne [IntPtr]::Zero) {
            [void][Drv098f]::SetText($e, $Accented2, 5000)
            EdChar $e 13
            [void](Serve $id 10)
            Start-Sleep -Milliseconds 800
        }
        $ok = $ok -and (Exists $Accented2) -and -not (Exists $Accented) -and (RenEdit $id) -eq [IntPtr]::Zero
        Row 'DISK' 'S6-UTF8' (V $ok) ("Shift+F6 on the accented file: {0}; renamed to the other accented name: {1}, old {2}" -f $d, (Exists $Accented2), (Exists $Accented))

        # Ctrl+Shift+F6 reaches the panel only when sent (the accelerator Restore Selection takes it
        # in the message loop); sent, it can open a window of its own - short timeout, then the
        # windows are recorded and cancelled
        FocusItem $id 2
        $known = Get-Tops $id
        $ke = [Tc346]::KeyMods((List $id), $VK_F6, $true, $true, $false, 3000)
        $w = Wait-NewWin $id $known 3
        $wd = 'no window'
        if ($w -ne [IntPtr]::Zero) { $wd = WinDesc $w }
        $srv = Serve $id 10 @(2)
        $e = RenEdit $id
        Row 'DISK' 'CS6' (V ($e -eq [IntPtr]::Zero)) ("Ctrl+Shift+F6 sent to the panel: {0}; key: '{1}'; window: {2}; served: {3}" -f (EdDesc $e), $ke, $wd, (Msgs $srv))
        if ($e -ne [IntPtr]::Zero) { EdChar $e 27 }

        $srv = ''
        KeyM $id $VK_F6 $false $false
        $srv = Serve $id 3 @(2)
        $e = RenEdit $id
        $d1 = EdDesc $e; if ($e -ne [IntPtr]::Zero) { EdChar $e 27 }
        KeyM $id $VK_F6 $false $true $true
        $e = RenEdit $id
        $d2 = EdDesc $e; if ($e -ne [IntPtr]::Zero) { EdChar $e 27 }
        Row 'DISK' 'KEEPS' (V ($d1 -eq 'no edit' -and $d2 -eq 'no edit')) ("F6 sent to the panel: {0}; Alt+Shift+F6: {1}" -f $d1, $d2)

        FocusItem $id 2
        Post-Cmd (Get-Main $id) $CM_QUICKRENAMEINPLACE
        [void](Serve $id 5)
        $e = RenEdit $id
        $d = EdDesc $e
        Row 'DISK' 'MENU' (V ($e -ne [IntPtr]::Zero -and ([Drv098f]::GetText($e, 5000)) -ceq 'a2.txt')) ("the menu command on a2.txt: " + $d)
        if ($e -ne [IntPtr]::Zero) { EdChar $e 27 }

        FocusItem $id 2
        $dlg = Open-ByCmd $id $CM_RENAMEFILE
        $dd = '<no window>'
        if ($dlg -ne [IntPtr]::Zero) { $dd = WinDesc $dlg; Close-Win $dlg; Start-Sleep -Milliseconds 400 }
        $names = (@([IO.Directory]::GetFileSystemEntries($LP + $R) | ForEach-Object { [IO.Path]::GetFileName($_) }) -join ', ')
        $okF2 = ($dlg -ne [IntPtr]::Zero) -and ($dd -match 'a2\.txt') -and (Exists 'a2.txt')
        Row 'DISK' 'F2' (V $okF2) ("CM_RENAMEFILE (F2): {0}; after Cancel the folder holds: {1}" -f $dd, (Esc $names))

        FocusItem $id 3
        Key $id $VK_RETURN
        [void](Serve $id 10)
        Start-Sleep -Milliseconds 800
        $loc = Get-Loc $id
        FocusItem $id 1
        KeyM $id $VK_F6 $false $true
        $e = RenEdit $id
        $d1 = EdDesc $e; if ($e -ne [IntPtr]::Zero) { EdChar $e 27 }
        Post-Cmd (Get-Main $id) $CM_QUICKRENAMEINPLACE
        [void](Serve $id 5)
        $e = RenEdit $id
        $d2 = EdDesc $e; if ($e -ne [IntPtr]::Zero) { EdChar $e 27 }
        Row 'DISK' 'ARCHIVE' (V ($loc -match 'arch\.zip' -and $d1 -eq 'no edit' -and $d2 -eq 'no edit')) ("panel in '{0}': Shift+F6 on inner.txt: {1}; menu command: {2}" -f (Esc $loc), $d1, $d2)
    }
    catch { Row 'DISK' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { End-Run $id }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc346_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    NewDir ($R + '\Dir1')
    NewDir ($Root + '\zsrc')
    [IO.File]::WriteAllText($LP + $R + '\a.txt', 'A')
    [IO.File]::WriteAllText($LP + $R + '\' + $Accented, 'V')
    [IO.File]::WriteAllText($LP + $Root + '\zsrc\inner.txt', 'I')
    Compress-Archive -LiteralPath ($Root + '\zsrc\inner.txt') -DestinationPath ($R + '\arch.zip')
    Set-Config
    Out ("rip346_probe (feature 346) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; fixture {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, (Esc $R))
    Out ''
    Run-Disk
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
