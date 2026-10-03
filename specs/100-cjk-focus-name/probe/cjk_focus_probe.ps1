<#
.SYNOPSIS
    Feature 100 probe: Change Directory to a FILE whose name holds a character
    outside the system code page (measurement, T001), and the stored title of
    every viewer and of the main window for such names (fix, T004).

.DESCRIPTION
    Per case a folder %TEMP%\tc100_cjk\<case> with a.txt, f<X>.txt, z.txt
    (1 / 7 / 3 ASCII lines), m<X>.md, p<X>.png (4x4), c<X>.csv and a folder
    d<X>. X = U+0159 (inside code page 1250, control), U+65E5 and U+4E2D (CJK),
    U+0416 (Cyrillic), U+1F600 (emoji, a surrogate pair). One instance per
    case, started in an empty folder (-l start -r start).

    Measurement rows (T001):
      CD     Change Directory (862): wide WM_SETTEXT of f<X>.txt's full path
             into field 210; the field read back must hold the text exactly.
      LOC    the panel location (the Change Directory field as it opens).
      FOCUS  the focused item's name, read losslessly from the Quick Rename
             dialog (CM_RENAMEFILE 754, a Unicode combo box), then cancelled.
      F3     CM_VIEW (742): the default viewer (Code Viewer for .txt): class,
             IsWindowUnicode, the stored title (InternalGetWindowText) and the
             status bar's line count (7 = the f<X>.txt content was read).
      NAV    the same file focused by Home + k x Down, then FOCUS + F3 again.

    Title rows (T004) - each opens the file by Change Directory to its full
    path (which focuses it) and reads the stored title, polled until it names
    the file (exact or as the code page shows it):
      T-CODE  F3 on f<X>.txt          Code Viewer
      T-INT   Alt+F3 (CM_ALTVIEW 753) internal viewer (alternative viewer *.*)
      T-MD    F3 on m<X>.md           Markdown Viewer
      T-PNG   F3 on p<X>.png          PictView
      T-CSV   F3 on c<X>.csv          Database Viewer
      T-PFS   PictView in full screen (CMD_FULLSCREEN 129: a popup without a title
              bar), next file (CMD_FILE_NEXT 147) from o.png to p<X>.png
      T-DM    DiskMap (Ctrl+Shift+D, modifier state as for FC) on the panel folder
              d<X> (after T-MAIN, which changes into it)
      -Only newrows runs just T-PFS and T-DM (for the build before)
      T-MAIN  Change Directory to the folder d<X>: the main window's stored
              title; EVENT_OBJECT_NAMECHANGE of the main window counted (an
              out-of-context WinEvent hook) for the change itself and for five
              refreshes of the unchanged folder (CM_LEFTREFRESH 724) - a title
              that is not re-set fires no event.
    Verdict with -Expect fixed: PASS = the exact name is in the title (and no
    name-change event for the refreshes). With -Expect before (the build
    before feature 100): PASS = exact for U+0159, the code-page form ('?') for
    the four outside the code page.
      FC      (case fc only) File Comparator: two binary files with U+0159
              names, both selected, the plug-in's hot key Ctrl+Shift+C (the
              modifier state set through AttachThreadInput + SetKeyboardState
              of the probe's own thread, never a real key press), OK in its
              Compare Files dialog; the stored title of the comparator window
              must name both files after the comparison (the worker thread's
              title, worker2.cpp) - names outside the code page cannot reach
              the comparator: its dialog and fcremote.exe are code-page
              windows/programs (recorded in the fix-log).
      END    the disk still holds the case's files, the program exits with 0.

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while another
    tandemcommander.exe runs. HKCU\Software\Tandem Commander exported before
    and restored + SHA-256-verified after. Scratch: %TEMP%\tc100_cjk (removed).

.NOTES
    Windows PowerShell 5.1; pure ASCII (names built from code points).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ }) }   # -File passes "a,b" as one string
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
Add-Type -AssemblyName System.Drawing

if (-not ('Drv100b' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv100b
{
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int InternalGetWindowText(IntPtr h, StringBuilder s, int n);
    public static string Internal(IntPtr h) { var s = new StringBuilder(4000); InternalGetWindowText(h, s, 4000); return s.ToString(); }
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] static extern IntPtr GetWindowLongPtrW(IntPtr h, int i);
    public static long GetStyle(IntPtr h) { return (long)(uint)GetWindowLongPtrW(h, -16).ToInt64(); }

    // EVENT_OBJECT_NAMECHANGE of one window, out of context (delivered through this thread's queue)
    public delegate void WinEventProc(IntPtr hook, uint ev, IntPtr hwnd, int idObject, int idChild, uint thread, uint time);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr mod, WinEventProc proc, uint pid, uint tid, uint flags);
    [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public int x, y; }
    [DllImport("user32.dll")] static extern bool PeekMessage(out MSG m, IntPtr h, uint a, uint b, uint r);
    [DllImport("user32.dll")] static extern bool TranslateMessage(ref MSG m);
    [DllImport("user32.dll")] static extern IntPtr DispatchMessage(ref MSG m);
    static WinEventProc keep; static IntPtr hook;
    public static IntPtr Target; public static int Count;
    static void Cb(IntPtr h, uint ev, IntPtr hwnd, int idObject, int idChild, uint thread, uint time)
    { if (hwnd == Target && idObject == 0 && idChild == 0) Count++; }
    public static bool HookStart(uint pid) { keep = Cb; hook = SetWinEventHook(0x800C, 0x800C, IntPtr.Zero, keep, pid, 0, 0); return hook != IntPtr.Zero; }
    public static void HookStop() { if (hook != IntPtr.Zero) UnhookWinEvent(hook); hook = IntPtr.Zero; }
    public static void Pump(int ms)
    {
        var sw = Stopwatch.StartNew(); MSG m;
        while (sw.ElapsedMilliseconds < ms) { while (PeekMessage(out m, IntPtr.Zero, 0, 0, 1)) { TranslateMessage(ref m); DispatchMessage(ref m); } Thread.Sleep(10); }
    }

    // modifier keys for a SENT key message: the probe thread shares the target thread's input
    // state (AttachThreadInput) and sets the key-state table - no real key press, no other window
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public static string CtrlShiftKey(IntPtr target, int vk)
    {
        uint pid; uint tid = GetWindowThreadProcessId(target, out pid);
        uint me = GetCurrentThreadId();
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed " + Marshal.GetLastWin32Error();
        var saved = new byte[256]; GetKeyboardState(saved);
        try
        {
            var k = (byte[])saved.Clone();
            k[0x10] = k[0xA0] = 0x80; k[0x11] = k[0xA2] = 0x80; // VK_SHIFT, VK_LSHIFT, VK_CONTROL, VK_LCONTROL
            if (!SetKeyboardState(k)) return "SetKeyboardState failed";
            // posted (the hot key opens a modal dialog), then the key state is kept until the
            // target has retrieved the message
            PostMessageW(target, 0x0100, (IntPtr)vk, (IntPtr)1);
            IntPtr r; SendMessageTimeoutW(target, 0, IntPtr.Zero, IntPtr.Zero, 0, 3000, out r);
            Thread.Sleep(300);
            return "ok";
        }
        finally
        {
            SetKeyboardState(saved);
            PostMessageW(target, 0x0101, (IntPtr)vk, unchecked((IntPtr)0xC0000001));
            AttachThreadInput(me, tid, false);
        }
    }
}
'@
}

# own scratch (the library's tc098_fix names are not used)
$Root = $TempRoot + '\tc100_cjk'
$StartDir = $Root + '\start'
$AcpEnc = [Text.Encoding]::GetEncoding([int][Drv098f]::GetACP())
function Shown([string]$s) { return $AcpEnc.GetString($AcpEnc.GetBytes($s)) }   # what the code page keeps (best fit)
function InCp([string]$s) { return ((Shown $s) -ceq $s) }

function Start-Tc100([string]$Left) {
    $a = @('-t', 'T100', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }

# the focused item's name, read from the rename editor (dialog or inline edit); cancelled again
function Read-Focus([int]$Id) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 754
    $dlg = [IntPtr]::Zero; $edit = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 6 -and $dlg -eq [IntPtr]::Zero -and $edit -eq [IntPtr]::Zero) {
        foreach ($h in (Get-Tops $Id)) { if ($known -notcontains $h -and [Drv098f]::Cls($h) -eq '#32770') { $dlg = $h } }
        if ($dlg -eq [IntPtr]::Zero) {
            $e = @([Drv098f]::Kids((Get-LeftList $Id)) | Where-Object { [Drv098f]::Cls($_) -ieq 'Edit' -and [Drv098f]::IsWindowVisible($_) })
            if ($e.Count) { $edit = $e[0] }
        }
        Start-Sleep -Milliseconds 100
    }
    if ($dlg -ne [IntPtr]::Zero) {
        Start-Sleep -Milliseconds 300
        $ed = @([Drv098f]::Kids($dlg) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
        if (-not $ed) { $t = 'dialog without an edit: ' + (WinDesc $dlg); Close-Win $dlg; return [pscustomobject]@{ Name = $null; How = $t } }
        $name = [Drv098f]::GetText($ed, 5000)
        $how = ("rename dialog '{0}', {1} unicode={2}" -f [Drv098f]::Txt($dlg), [Drv098f]::Cls($ed), [Drv100b]::IsWindowUnicode($ed))
        Post-Cmd $dlg 2
        $sw.Restart(); while ($sw.Elapsed.TotalSeconds -lt 4 -and [Drv098f]::IsWindow($dlg)) { Start-Sleep -Milliseconds 100 }
        if ([Drv098f]::IsWindow($dlg)) { Close-Win $dlg }
        Sync $Id
        return [pscustomobject]@{ Name = $name; How = $how }
    }
    if ($edit -ne [IntPtr]::Zero) {
        $name = [Drv098f]::GetText($edit, 5000)
        $how = ("inline edit unicode={0}" -f [Drv100b]::IsWindowUnicode($edit))
        [void][Drv098f]::PostMessageW($edit, 0x0100, [IntPtr]0x1B, [IntPtr]1)
        [void][Drv098f]::PostMessageW($edit, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001)
        $sw.Restart(); while ($sw.Elapsed.TotalSeconds -lt 3 -and [Drv098f]::IsWindow($edit) -and [Drv098f]::IsWindowVisible($edit)) { Start-Sleep -Milliseconds 100 }
        Sync $Id
        return [pscustomobject]@{ Name = $name; How = $how }
    }
    return [pscustomobject]@{ Name = $null; How = 'no rename editor appeared' }
}

# opens a viewer with command $Cmd on the focused item; polls its stored title until it names
# $Name exactly or in the code page's form; closes it. Returns the facts.
function Open-Viewer([int]$Id, [int]$Cmd, [string]$Name, [string]$Dir, [string[]]$Files) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) $Cmd
    $w = Wait-NewWin $Id $known 20
    $r = [pscustomobject]@{ Title = $null; Exact = $false; Lossy = $false; Facts = '' }
    if ($w -eq [IntPtr]::Zero) { $r.Facts = 'no window opened'; return $r }
    $cls = [Drv098f]::Cls($w)
    if ($cls -eq '#32770') { $r.Facts = 'MESSAGE ' + (WinDesc $w); Close-Win $w; return $r }
    $shown = Shown $Name
    $sw = [Diagnostics.Stopwatch]::StartNew(); $t = ''
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $t = [Drv100b]::Internal($w)
        if ($t.IndexOf($Name, [StringComparison]::Ordinal) -ge 0) { $r.Exact = $true; break }
        if ($shown -cne $Name -and $t.IndexOf($shown, [StringComparison]::Ordinal) -ge 0) { $r.Lossy = $true; break }
        Start-Sleep -Milliseconds 200
    }
    Start-Sleep -Milliseconds 300
    $t = [Drv100b]::Internal($w)   # the final title (a viewer may append e.g. the image size)
    $r.Exact = $t.IndexOf($Name, [StringComparison]::Ordinal) -ge 0
    $r.Lossy = (-not $r.Exact) -and $shown -cne $Name -and $t.IndexOf($shown, [StringComparison]::Ordinal) -ge 0
    $r.Title = $t
    $status = ''
    if ($Files) { $status = (@([Drv098f]::Kids($w) | Where-Object { [Drv098f]::Cls($_) -eq 'Static' } | ForEach-Object { [Drv098f]::Txt($_) } | Where-Object { $_ }) -join ' / ') }
    $r.Facts = ("class '{0}' unicode={1}; stored title '{2}'{3}" -f $cls, [Drv100b]::IsWindowUnicode($w), (Esc $t), $(if ($status) { "; status bar '" + (Esc $status) + "'" } else { '' }))
    [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw.Restart(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($w)) { Start-Sleep -Milliseconds 100 }
    Serve $Id 5 | Out-Null
    Sync $Id
    return $r
}
function TitleVerdict([string]$X, $r) {
    if ($Expect -eq 'fixed' -or (InCp $X)) { return (V $r.Exact) }
    return (V $r.Lossy)
}
function Title-Row([string]$Case, [string]$Step, [string]$X, [int]$Id, [string]$Dir, [string]$File, [int]$Cmd, [string[]]$Files) {
    $held = Do-ChangeDir $Id ($Dir + '\' + $File)
    $s = Serve $Id 10
    $fo = Read-Focus $Id
    if ($fo.Name -cne $File) { Row $Case $Step 'FAIL' ("focus not on {0} (rename editor read {1}; field held {2}; {3})" -f (Esc $File), (Esc $fo.Name), $held, (Msgs $s)); return }
    $r = Open-Viewer $Id $Cmd $File $Dir $Files
    Row $Case $Step (TitleVerdict $X $r) ("{0}: exact {1}, code-page form {2}; {3}" -f (Esc $File), $r.Exact, $r.Lossy, $r.Facts)
}

# polls the stored title of $W until it holds $Name (exact or in the code page's form)
function Poll-Title([IntPtr]$W, [string]$Name, [double]$Seconds = 15) {
    $shown = Shown $Name
    $sw = [Diagnostics.Stopwatch]::StartNew(); $t = ''
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $t = [Drv100b]::Internal($W)
        if ($t.IndexOf($Name, [StringComparison]::Ordinal) -ge 0) { break }
        if ($shown -cne $Name -and $t.IndexOf($shown, [StringComparison]::Ordinal) -ge 0) { break }
        Start-Sleep -Milliseconds 200
    }
    Start-Sleep -Milliseconds 300
    $t = [Drv100b]::Internal($W)
    $exact = $t.IndexOf($Name, [StringComparison]::Ordinal) -ge 0
    $lossy = (-not $exact) -and $shown -cne $Name -and $t.IndexOf($shown, [StringComparison]::Ordinal) -ge 0
    return [pscustomobject]@{ Title = $t; Exact = $exact; Lossy = $lossy }
}

# T-PFS: PictView in full screen (a popup without a title bar), next file: o.png -> p<X>.png
function Run-PicFull([string]$Case, [string]$X, [int]$Id, [string]$Dir, [string]$Png) {
    [void](Do-ChangeDir $Id ($Dir + '\o.png')); [void](Serve $Id 10)
    $fo = Read-Focus $Id
    if ($fo.Name -cne 'o.png') { Row $Case 'T-PFS' 'FAIL' ("focus not on o.png ({0})" -f (Esc $fo.Name)); return }
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 742
    $w = Wait-NewWin $Id $known 20
    if ($w -eq [IntPtr]::Zero -or [Drv098f]::Cls($w) -eq '#32770') { Row $Case 'T-PFS' 'FAIL' 'PictView did not open o.png'; if ($w -ne [IntPtr]::Zero) { Close-Win $w }; return }
    $t0 = Poll-Title $w 'o.png'
    Post-Cmd $w 129   # CMD_FULLSCREEN
    Start-Sleep -Milliseconds 1200
    $style = [Drv100b]::GetStyle($w)
    Post-Cmd $w 147   # CMD_FILE_NEXT
    $r = Poll-Title $w $Png
    $style2 = [Drv100b]::GetStyle($w)
    Post-Cmd $w 129   # leave full screen
    Start-Sleep -Milliseconds 800
    [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($w)) { Start-Sleep -Milliseconds 100 }
    [void](Serve $Id 5); Sync $Id
    $full = (($style -band 0x00C00000) -ne 0x00C00000) -and (($style -band 0x80000000) -ne 0)
    $seen = 'title held o.png'; if (-not $t0.Exact) { $seen = 'o.png not seen: ' + (Esc $t0.Title) }
    Row $Case 'T-PFS' (TitleVerdict $X $r) ("{0} after o.png ({1}) in full screen: exact {2}, code-page form {3}; style 0x{4:X8} (WS_POPUP without WS_CAPTION: {5}), at the title read 0x{6:X8}; stored title '{7}'" -f (Esc $Png), $seen, $r.Exact, $r.Lossy, $style, $full, $style2, (Esc $r.Title))
}

# T-DM: DiskMap (Ctrl+Shift+D) on the panel folder d<X>
function Run-DiskMap([string]$Case, [string]$X, [int]$Id, [string]$Dx) {
    $known = Get-Tops $Id
    $k = [Drv100b]::CtrlShiftKey((Get-LeftList $Id), 0x44)
    $w = Wait-NewWin $Id $known 15
    if ($w -eq [IntPtr]::Zero) { Row $Case 'T-DM' 'FAIL' ("Ctrl+Shift+D ({0}) opened no window" -f $k); return }
    if ([Drv098f]::Cls($w) -eq '#32770') { Row $Case 'T-DM' 'FAIL' ('MESSAGE ' + (WinDesc $w)); Close-Win $w; return }
    $r = Poll-Title $w ('\' + $Dx)
    $cls = [Drv098f]::Cls($w)
    [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($w)) { Start-Sleep -Milliseconds 100 }
    [void](Serve $Id 5); Sync $Id
    Row $Case 'T-DM' (TitleVerdict $X $r) ("{0}: exact {1}, code-page form {2}; class '{3}'; stored title '{4}'" -f (Esc $Dx), $r.Exact, $r.Lossy, $cls, (Esc $r.Title))
}

function Run-Case([string]$Case, [string]$X) {
    $dir = $Root + '\' + $Case
    NewDir $dir
    $fx = 'f' + $X + '.txt'
    $files = @('a.txt', $fx, 'z.txt')
    $nLines = @{ 'a.txt' = 1; 'z.txt' = 3 }; $nLines[$fx] = 7
    foreach ($f in $files) { [IO.File]::WriteAllText($LP + $dir + '\' + $f, ((1..$nLines[$f] | ForEach-Object { 'CONTENT-' + $Case + '-' + (Esc $f) + '-line' + $_ }) -join "`r`n"), (New-Object Text.ASCIIEncoding)) }
    $md = 'm' + $X + '.md'; $png = 'p' + $X + '.png'; $csv = 'c' + $X + '.csv'; $dx = 'd' + $X
    [IO.File]::WriteAllText($LP + $dir + '\' + $md, "# Probe 100`r`n`r`nText.`r`n", (New-Object Text.ASCIIEncoding))
    [IO.File]::WriteAllText($LP + $dir + '\' + $csv, "a,b`r`n1,2`r`n", (New-Object Text.ASCIIEncoding))
    $bmp = New-Object System.Drawing.Bitmap 4, 4
    try { $bmp.SetPixel(1, 1, [System.Drawing.Color]::Red); $ms = New-Object IO.MemoryStream; $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); [IO.File]::WriteAllBytes($LP + $dir + '\' + $png, $ms.ToArray()); [IO.File]::WriteAllBytes($LP + $dir + '\o.png', $ms.ToArray()) } finally { $bmp.Dispose() }
    NewDir ($dir + '\' + $dx)
    $all = @($files + @($md, $png, $csv, 'o.png') | Sort-Object)
    $id = 0; $fatal = $null; $before = Reports
    try {
        $id = Start-Tc100 $StartDir
        if (Want 'measure') {
            $full = $dir + '\' + $fx
            $held = Do-ChangeDir $id $full
            $r = Serve $id 20
            $fatal = $r.Fatal
            Row $Case 'CD' (V $held) ("field held the typed text exactly: {0}; typed {1}; windows after OK: {2}" -f $held, (Esc $full), (Msgs $r))
            $loc = Get-Loc $id
            Row $Case 'LOC' (V ($loc.TrimEnd('\') -ceq $dir)) ("panel location {0}" -f (Esc $loc))
            $fo = Read-Focus $id
            Row $Case 'FOCUS' (V ($fo.Name -ceq $fx)) ("focused name {0} via {1}" -f (Esc $fo.Name), $fo.How)
            $v = Open-Viewer $id 742 $fx $dir $files
            Row $Case 'F3' (TitleVerdict $X $v) ("exact {0}, code-page form {1}; {2}" -f $v.Exact, $v.Lossy, $v.Facts)
            $k = -1
            for ($i = 0; $i -le 9; $i++) {
                Key $id 0x24; for ($j = 0; $j -lt $i; $j++) { Key $id 0x28 }
                Sync $id
                $f2 = Read-Focus $id
                if ($f2.Name -ceq $fx) { $k = $i; break }
            }
            Row $Case 'NAV' (V ($k -ge 0)) ("focused by Home + {0} x Down" -f $k)
            if ($k -ge 0) { $v = Open-Viewer $id 742 $fx $dir $files; Row $Case 'NAVF3' (TitleVerdict $X $v) ("exact {0}, code-page form {1}; {2}" -f $v.Exact, $v.Lossy, $v.Facts) }
        }
        if (Want 'titles') {
            Title-Row $Case 'T-INT' $X $id $dir $fx 753 $null
            Title-Row $Case 'T-MD' $X $id $dir $md 742 $null
            Title-Row $Case 'T-PNG' $X $id $dir $png 742 $null
            Title-Row $Case 'T-CSV' $X $id $dir $csv 742 $null
        }
        if ((Want 'titles') -or (Want 'newrows')) { Run-PicFull $Case $X $id $dir $png }
        if (Want 'titles') {
            # the main window title: the change itself, then five refreshes of the unchanged folder
            $main = Get-Main $id
            [Drv100b]::Target = $main
            if (-not [Drv100b]::HookStart([uint32]$id)) { throw 'SetWinEventHook failed' }
            try {
                [Drv100b]::Pump(300); [Drv100b]::Count = 0
                $held = Do-ChangeDir $id ($dir + '\' + $dx)
                [void](Serve $id 10)
                [Drv100b]::Pump(1500); $nChange = [Drv100b]::Count
                $t = [Drv100b]::Internal($main)
                [Drv100b]::Count = 0
                for ($i = 0; $i -lt 5; $i++) { [void][Drv098f]::Send($main, 0x0111, 724, 0, 20000); Start-Sleep -Milliseconds 300 }
                Sync $id
                [Drv100b]::Pump(1500); $nRefresh = [Drv100b]::Count
                $t2 = [Drv100b]::Internal($main)
            }
            finally { [Drv100b]::HookStop() }
            $exact = $t.IndexOf($dx, [StringComparison]::Ordinal) -ge 0
            $lossy = (-not $exact) -and (Shown $dx) -cne $dx -and $t.IndexOf((Shown $dx), [StringComparison]::Ordinal) -ge 0
            $r = [pscustomobject]@{ Exact = $exact; Lossy = $lossy }
            $verdict = TitleVerdict $X $r
            if ($Expect -eq 'fixed' -and $nRefresh -ne 0) { $verdict = 'FAIL' }
            Row $Case 'T-MAIN' $verdict ("{0}: exact {1}, code-page form {2}; stored title '{3}'; name-change events: Change Directory {4}, 5 refreshes {5}; title after the refreshes unchanged {6}" -f (Esc $dx), $exact, $lossy, (Esc $t), $nChange, $nRefresh, ($t2 -ceq $t))
        }
        elseif (Want 'newrows') { [void](Do-ChangeDir $id ($dir + '\' + $dx)); [void](Serve $id 10) }
        if ((Want 'titles') -or (Want 'newrows')) { Run-DiskMap $Case $X $id $dx }
        $disk = @([IO.Directory]::GetFiles($LP + $dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
        Row $Case 'DISK' (V (($disk -join '|') -ceq ($all -join '|'))) ("files on disk: {0}" -f (($disk | ForEach-Object { Esc $_ }) -join ', '))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# File Comparator: two binary files with U+0159 names, Ctrl+Shift+C, OK; the comparator's title
function Run-Fc([string]$Case) {
    $dir = $Root + '\' + $Case
    NewDir $dir
    $n1 = 'b1' + [char]0x0159 + '.bin'; $n2 = 'b2' + [char]0x0159 + '.bin'
    $b1 = New-Object byte[] 64; $b2 = New-Object byte[] 64
    for ($i = 0; $i -lt 64; $i++) { $b1[$i] = [byte]($i % 7); $b2[$i] = [byte]($i % 7) }
    $b2[10] = 0xFF; $b2[40] = 0xFE
    [IO.File]::WriteAllBytes($LP + $dir + '\' + $n1, $b1); [IO.File]::WriteAllBytes($LP + $dir + '\' + $n2, $b2)
    $id = 0; $fatal = $null; $before = Reports
    try {
        $id = Start-Tc100 $dir
        Post-Cmd (Get-Main $id) 842   # select all (the two files)
        Start-Sleep -Milliseconds 500; Sync $id
        $known = Get-Tops $id
        $k = [Drv100b]::CtrlShiftKey((Get-LeftList $id), 0x43)
        $dlg = Wait-NewWin $id $known 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'FC' 'NOT DRIVEN' ("Ctrl+Shift+C ({0}) opened no window" -f $k); return }
        $dd = WinDesc $dlg
        $known2 = Get-Tops $id
        Click-Ok $dlg
        $w = Wait-NewWin $id $known2 15
        $msgs = @()
        for ($m = 0; $m -lt 3 -and $w -ne [IntPtr]::Zero -and [Drv098f]::Cls($w) -eq '#32770'; $m++) {
            $msgs += (WinDesc $w); $known2 = Get-Tops $id
            $b = Buttons $w | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($b) { Click $b } else { Close-Win $w }
            $w = Wait-NewWin $id $known2 15
        }
        if ($w -eq [IntPtr]::Zero) { Row $Case 'FC' 'FAIL' ("no comparator window after OK in {0}; messages {1}" -f $dd, ($msgs -join ' || ')); return }
        if ($msgs.Count) { $dd += ('; messages answered: ' + ($msgs -join ' || ')) }
        $sw = [Diagnostics.Stopwatch]::StartNew(); $t = ''
        while ($sw.Elapsed.TotalSeconds -lt 20) {
            $t = [Drv100b]::Internal($w)
            if ($t.IndexOf($n1, [StringComparison]::Ordinal) -ge 0 -and $t.IndexOf($n2, [StringComparison]::Ordinal) -ge 0 -and $t -match '\d') { Start-Sleep -Milliseconds 1500; $t = [Drv100b]::Internal($w); break }
            Start-Sleep -Milliseconds 200
        }
        $ok = $t.IndexOf($n1, [StringComparison]::Ordinal) -ge 0 -and $t.IndexOf($n2, [StringComparison]::Ordinal) -ge 0
        $resp = [Drv098f]::Send($w, 0, 0, 0, 5000)
        Row $Case 'FC' (V ($ok -and $resp)) ("dialog {0}; comparator class '{1}' unicode={2}; stored title '{3}'; responsive {4}" -f $dd, [Drv098f]::Cls($w), [Drv100b]::IsWindowUnicode($w), (Esc $t), $resp)
        [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw.Restart(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($w)) { Start-Sleep -Milliseconds 100 }
        [void](Serve $id 5)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- main --------------------------------------------------------------------
$others = @(Get-Process -Name 'tandemcommander' -ErrorAction SilentlyContinue)
if ($others.Count) { Out ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }
$backup = Join-Path $env:TEMP 'tc100_cjk_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cjk_focus_probe (feature 100), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ''
    foreach ($c in @(@('c0r', 0x0159), @('c1ri', 0x65E5), @('c2zh', 0x4E2D), @('c3cyr', 0x0416), @('c4emo', 0x1F600))) {
        if ((Want 'measure') -or (Want 'titles') -or (Want 'newrows')) { Run-Case $c[0] ([char]::ConvertFromUtf32($c[1])) }
    }
    if (Want 'fc') { Run-Fc 'fc' }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
