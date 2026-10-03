<#
.SYNOPSIS
    Feature 102 probe: the File Comparator compares exactly the files it is given, for names
    in any script, on every route - on the build of this feature (-Expect fixed) and on the
    build before it (-Expect before, Debug_x64_pre102, the control).

.DESCRIPTION
    Fixtures under %TEMP%\tc102_fc (removed at the end). Every case is a folder <case> with
    L\<name> and R\<name> (same name, two files), 13 ASCII lines each; R\<name> differs from
    L\<name> in K separated lines, so the comparator's "N Differences" identifies the pair.
    Decoy cases hold a second pair L\<decoy>, R\<decoy> in the same folders; the changed line
    sets are named {} / {1,3}, decoy {5} / {7,9,11}, so a comparison that reached a decoy
    shows 3 or 4 differences instead of 2.

      cz     Petr<U+016F>.txt                   K=1  inside code page 1250
      cyr    <U+0416 U+0430 U+0431 U+0430>.txt  K=2  Cyrillic
      cjk    <U+65E5 U+672C U+8A9E>.txt         K=3  CJK
      emo    <U+1F4C1>ok.txt                     K=4  a surrogate pair
      lone   lone<U+D800>x.txt                   K=5  a lone surrogate
      same   <U+540C U+3058>.txt                 K=0  identical contents
      long   <150 CJK characters>\L|R\<U+9577>.txt  K=6  (a UTF-8 path of 400+ bytes)
      voila  voil<U+00E0>.txt, decoy voila.txt   K=2  best fit maps U+00E0 to 'a'
      fwab   <U+FF21 U+FF22>.txt, decoy AB.txt   K=2  best fit maps fullwidth to ASCII
      abrev  <U+0102 U+00A9>.txt, decoy <U+00E9>.txt  K=2  cp1250 bytes C3 A9 = UTF-8 of U+00E9
      fri    f<U+65E5>.txt, decoy fa.txt         K=2  '?' would be a wildcard for FindFirstFile

    Routes (each case unless said otherwise; the left panel shows L, the right panel R; the
    file is focused in the left panel by Change Directory to its full path; Ctrl+Shift+C =
    MID_COMPAREFILES compares it with the same name in the other panel):
      ON     "Confirm selection" on: the Compare Files dialog - both path fields read back
             (WM_GETTEXT, UTF-16) - OK
      HIST   ON again in the same instance: the history drop-down (CB_GETLBTEXT, UTF-16)
             holds both full names exactly; the R entry picked from the list fills the field
             exactly; Cancel
      TYPE   (cyr, emo, lone) ON, the second field emptied and the full name posted as
             WM_CHAR per UTF-16 unit to its edit, read back, OK
      NOFILE (cjk) a non-existent CJK name typed into the dialog: the message names it
             exactly and the dialog stays
      BROWSE (cjk) the Browse button of the second field: the full name set into the open
             dialog's file name field, Open; the field then holds it exactly
      OFF    "Confirm selection" off (the plug-in's Configuration blob, first DWORD): no dialog
      REM    fcremote.exe "<L name>" "<R name>" with the program running
      REMW   fcremote.exe -w ... : fcremote waits while the comparator window is open and
             ends with 0 after it is closed
      CZ     (cz, cyr, voila) ON in the Czech UI (Configuration\Language = czech.slg)
      START  (cjk) fcremote.exe -w with the program NOT running: fcremote starts it (the
             plug-in loaded on start: Plugins\<n>\Load On Start = 1 + the plug-in's own value),
             the comparison runs, -w returns 0
      MISM   the OTHER build's fcremote.exe (-OtherFcremote) against this program: a clear
             error from fcremote, no comparator window, no hang
      PATHS  (review) fcremote with an INTERMEDIATE folder ending in a dot (L.\f.txt, R.\f.txt)
             and in a space (L \f.txt), decoys L\f.txt / R\f.txt beside them (rows DOT, SPACE);
             names of about 7,800 and 29,800 units (LONG8K, LONG30K - the second with a short
             right name, two would not fit a command line): the result within 10 s and a
             WM_NULL round trip after a full repaint under 1 s (the header bar froze before)
      END    (review) every window that appears while the program closes is recorded once; a
             box is answered OK/Yes; the close request is repeated at 10 s and 20 s
      INS    two DIFFERENT names a<U+0416>.txt / b<U+65E5>.txt (b = a + one inserted line),
             both selected, ON: the first list item names the right file first and the left
             file second ("Insert line 4 from right file (b..) after line 3 in left file (a..)")
    Every comparison: the comparator window's stored title (InternalGetWindowText) must name
    the file exactly and end with K differences (K=0: the "identical" message); the first item
    of the differences list (UTF-16) must name the file exactly.
    Outcomes: EXACT (the named files, names exact), DECOY (a decoy's count), ERROR (a message
    instead of a result), NOTHING (no window), OTHER.  -Expect before: PASS when the outcome is
    the one the research predicted for the build before (research.md section 2).

    Not drivable, recorded: dropping files onto the dialog or the comparator window
    (WM_DROPFILES needs an HDROP, a global memory handle that must be allocated in the target
    process - a probe in another process cannot create it; no real drag on a hidden desktop).

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while another
    tandemcommander.exe runs. HKCU\Software\Tandem Commander exported before, restored and
    SHA-256-verified after. Pure ASCII (names from code points). Exit code = FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OtherFcremote,
    [string]$OutFile,
    [string[]]$Only,
    [string[]]$CaseOnly
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$Fcremote = Join-Path (Split-Path $Exe) 'plugins\filecomp\fcremote.exe'
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
if ($CaseOnly) { $CaseOnly = @($CaseOnly | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Drv102' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv102
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int InternalGetWindowText(IntPtr h, StringBuilder s, int n);
    public static string Internal(IntPtr h) { var s = new StringBuilder(70000); InternalGetWindowText(h, s, 70000); return s.ToString(); }
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] static extern bool RedrawWindow(IntPtr h, IntPtr r, IntPtr rgn, uint flags);
    public static bool Redraw(IntPtr h) { return RedrawWindow(h, IntPtr.Zero, IntPtr.Zero, 0x0085); } // RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendGetBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    public static void EnumAll(uint pid, System.Collections.ArrayList list)
    {
        EnumWindows(delegate(IntPtr h, IntPtr l) { uint q; GetWindowThreadProcessId(h, out q); if (q == pid) { var c = new StringBuilder(256); GetClassNameW(h, c, 256); list.Add(c.ToString() + (IsWindowVisible(h) ? "(v)" : "") + " '" + Internal(h) + "' tid " + GetWindowThreadProcessId(h, out q)); } return true; }, IntPtr.Zero);
    }
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 5000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    // CB_GETLBTEXT as UTF-16 (the system marshals it for the ComboBox class)
    public static string LbText(IntPtr combo, int index)
    {
        long len = SendR(combo, 0x0149 /*CB_GETLBTEXTLEN*/, index, 0);
        if (len < 0) return null;
        var buf = new char[len + 2]; IntPtr r;
        SendGetBuf(combo, 0x0148 /*CB_GETLBTEXT*/, (IntPtr)index, buf, 0, 5000, out r);
        long n = r.ToInt64(); if (n < 0) return null; if (n > len) n = len;
        return new string(buf, 0, (int)n);
    }
    // modifier keys for a key message: the probe thread shares the target thread's input
    // state (AttachThreadInput) and sets the key-state table - no real key press (feature 100)
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    public static string CtrlShiftKey(IntPtr target, int vk)
    {
        uint pid; uint tid = GetWindowThreadProcessId(target, out pid);
        uint me = GetCurrentThreadId();
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed " + Marshal.GetLastWin32Error();
        var saved = new byte[256]; GetKeyboardState(saved);
        try
        {
            var k = (byte[])saved.Clone();
            k[0x10] = k[0xA0] = 0x80; k[0x11] = k[0xA2] = 0x80;
            if (!SetKeyboardState(k)) return "SetKeyboardState failed";
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

$Fixed = ($Expect -eq 'fixed')
$Root = $TempRoot + '\tc102_fc'
$StartDir = $Root + '\start'
$CmpClass = 'SFC Window Class'
$FcKey = 'HKCU:\Software\Tandem Commander\0.1\Plugins Configuration\File Comparator'
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }
$Lone = [string][char]0xD800   # ConvertFromUtf32 refuses a lone surrogate

# ---- fixtures -------------------------------------------------------------------------
$Odd = @(1, 3, 5, 7, 9, 11)
function Content([int[]]$Changed, [string]$Tag) {
    $l = foreach ($i in 1..13) { if ($Changed -contains $i) { 'CHANGED line {0:D2} in {1}' -f $i, $Tag } else { 'line {0:D2} of the probe text' -f $i } }
    return (($l -join "`r`n") + "`r`n")
}
function Put([string]$Path, [string]$Text) { [IO.File]::WriteAllText($LP + $Path, $Text, (New-Object Text.ASCIIEncoding)) }
$Cases = @(
    @{ Case = 'cz';    Name = 'Petr' + (S 0x016F) + '.txt';         Decoy = $null;             Cls = 'cp';      K = 1 },
    @{ Case = 'cyr';   Name = (S 0x0416, 0x0430, 0x0431, 0x0430) + '.txt'; Decoy = $null;      Cls = 'out';     K = 2 },
    @{ Case = 'cjk';   Name = (S 0x65E5, 0x672C, 0x8A9E) + '.txt';   Decoy = $null;             Cls = 'out';     K = 3 },
    @{ Case = 'emo';   Name = (S 0x1F4C1) + 'ok.txt';                Decoy = $null;             Cls = 'out';     K = 4 },
    @{ Case = 'lone';  Name = 'lone' + $Lone + 'x.txt';              Decoy = $null;             Cls = 'out';     K = 5 },
    @{ Case = 'same';  Name = (S 0x540C, 0x3058) + '.txt';           Decoy = $null;             Cls = 'out';     K = 0 },
    @{ Case = 'long';  Name = (S 0x9577) + '.txt';                   Decoy = $null;             Cls = 'long';    K = 6 },
    @{ Case = 'voila'; Name = 'voil' + (S 0x00E0) + '.txt';          Decoy = 'voila.txt';       Cls = 'bestfit'; K = 2 },
    @{ Case = 'fwab';  Name = (S 0xFF21, 0xFF22) + '.txt';           Decoy = 'AB.txt';          Cls = 'bestfit'; K = 2 },
    @{ Case = 'abrev'; Name = (S 0x0102, 0x00A9) + '.txt';           Decoy = (S 0x00E9) + '.txt'; Cls = 'u8coin'; K = 2 },
    @{ Case = 'fri';   Name = 'f' + (S 0x65E5) + '.txt';             Decoy = 'fa.txt';          Cls = 'out';     K = 2 }
)
$LongCase = $Cases | Where-Object { $_.Case -eq 'long' }
if ($CaseOnly) { $Cases = @($Cases | Where-Object { $CaseOnly -contains $_.Case }) }
$LongDir = -join (1..150 | ForEach-Object { [char](0x4E00 + ($_ * 37) % 2000) })
function CaseDir($c) { if ($c.Case -eq 'long') { return ($Root + '\long\' + $LongDir) } else { return ($Root + '\' + $c.Case) } }
function Make-Fixtures {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    foreach ($c in $Cases) {
        $d = CaseDir $c
        NewDir ($d + '\L'); NewDir ($d + '\R')
        $k = [int]$c.K
        $rset = @(); if ($k -gt 0) { $rset = $Odd[0..($k - 1)] }
        Put ($d + '\L\' + $c.Name) (Content @() 'L-named')
        Put ($d + '\R\' + $c.Name) (Content $rset 'R-named')
        if ($c.Decoy) {
            Put ($d + '\L\' + $c.Decoy) (Content @(5) 'L-decoy')
            Put ($d + '\R\' + $c.Decoy) (Content @(7, 9, 11) 'R-decoy')
        }
    }
}
function Disk-Ok {
    foreach ($c in $Cases) {
        $d = CaseDir $c
        foreach ($s in @('L', 'R')) {
            $n = @($c.Name); if ($c.Decoy) { $n += $c.Decoy }
            foreach ($f in $n) { if (-not [IO.File]::Exists($LP + $d + '\' + $s + '\' + $f)) { return ('missing ' + $c.Case + '\' + $s + '\' + (Esc $f)) } }
        }
    }
    return $null
}

# ---- registry settings (inside the backup / restore of the whole key) -------------------
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
function Set-Confirm([bool]$On) {
    $k = Get-Item -LiteralPath $FcKey -ErrorAction SilentlyContinue
    if (-not $k) { throw 'the File Comparator configuration key does not exist (run the plug-in once)' }
    $blob = [byte[]]$k.GetValue('Configuration')
    if (-not $blob -or $blob.Length -lt 4) { throw 'no Configuration blob' }
    $blob[0] = [byte]$(if ($On) { 1 } else { 0 }); $blob[1] = 0; $blob[2] = 0; $blob[3] = 0
    Set-ItemProperty -LiteralPath $FcKey -Name 'Configuration' -Value $blob -Type Binary
}
function Set-LoadOnStart([bool]$On) {
    $pk = Get-ChildItem 'HKCU:\Software\Tandem Commander\0.1\Plugins' | Where-Object { $_.GetValue('DLL') -match 'filecomp\.spl$' } | Select-Object -First 1
    if (-not $pk) { throw 'the File Comparator plug-in key was not found' }
    if ($On) { Set-ItemProperty -LiteralPath $pk.PSPath -Name 'Load On Start' -Value 1 -Type DWord } else { Remove-ItemProperty -LiteralPath $pk.PSPath -Name 'Load On Start' -ErrorAction SilentlyContinue }
    Set-ItemProperty -LiteralPath $FcKey -Name 'Load On Start' -Value $(if ($On) { 1 } else { 0 }) -Type DWord
}

# ---- program ----------------------------------------------------------------------------
function Start-Fc([string]$L, [string]$R) {
    $a = @('-t', 'T102', '-l', ('"{0}"' -f $L), '-r', ('"{0}"' -f $R), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function RawText([IntPtr]$H) {
    $parts = @([Drv098f]::Txt($H))
    foreach ($c in [Drv098f]::Kids($H)) { $t = [Drv098f]::Txt($c); if ($t -and [Drv098f]::IsWindowVisible($c)) { $parts += $t } }
    return (($parts -join ' | ').Replace("`r", '').Replace("`n", ''))
}
function Short([string]$s, [int]$n = 200) { if ($null -eq $s) { return '<null>' }; if ($s.Length -le $n) { return (Esc $s) }; return ((Esc $s.Substring(0, $n)) + '...') }
function Is-CompareDlg([IntPtr]$H) { return ([Drv098f]::Cls($H) -eq '#32770') -and (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 101 -and [Drv098f]::Cls($_) -eq 'ComboBox' }).Count -gt 0) }
function Field([IntPtr]$Dlg, [int]$Id) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $Id -and [Drv098f]::Cls($_) -eq 'ComboBox' })[0] }
function Field-Edit([IntPtr]$Combo) { return @([Drv098f]::Kids($Combo) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' })[0] }

# the focused item of the left panel by Change Directory to the file's full path
function Focus-File([int]$Id, [string]$Full) {
    $held = Do-ChangeDir $Id $Full
    [void](Serve $Id 10)
    Sync $Id
    return $held
}
# Ctrl+Shift+C on the left panel; returns the new window (dialog / comparator / message) or zero
function Hotkey-Compare([int]$Id) {
    $known = Get-Tops $Id
    $k = [Drv102]::CtrlShiftKey((Get-LeftList $Id), 0x43)
    $w = Wait-NewWin $Id $known 12
    return [pscustomobject]@{ Win = $w; Key = $k; Known = $known }
}

# waits for the comparison result in process $Id: the comparator window with a final title, or
# a message box (answered Yes = close the comparator / OK). Closes the comparator at the end
# unless -KeepOpen. Returns facts.
$FinalRx = ' - (\d+) \S+$'
function Await-Result([int]$Id, $Known, [double]$Seconds = 25, [switch]$KeepOpen) {
    $r = [pscustomobject]@{ Title = $null; Count = -1; Msgs = New-Object System.Collections.ArrayList; Cmp = [IntPtr]::Zero; List0 = $null; ListUnicode = $null; Fatal = $null }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $seen = @{}
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not (Test-Alive $Id)) { break }
        $tops = @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and [Drv098f]::Cls($_) -ne $MainClass })
        $cmp = @($tops | Where-Object { [Drv098f]::Cls($_) -eq $CmpClass }) | Select-Object -First 1
        if ($cmp) { $r.Cmp = $cmp }
        $boxes = @($tops | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and -not (Is-CompareDlg $_) -and [Drv098f]::IsWindowEnabled($_) })
        if ($boxes.Count) {
            $b = $boxes[0]; $key = $b.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; Start-Sleep -Milliseconds 200; continue }
            if ($sw.Elapsed.TotalSeconds - $seen[$key] -lt 0.6) { Start-Sleep -Milliseconds 100; continue }
            $t = RawText $b
            if ($t -match $FatalRx) {
                $r.Fatal = $t
                # a CRT assertion: Retry breaks into the (absent) debugger, so the program writes its
                # bug report with the call stack (printed by the END row)
                $retry = Buttons $b | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 4 } | Select-Object -First 1
                if ($retry -and $t -match 'Assertion') { Click $retry; Start-Sleep -Seconds 10 }
                return $r
            }
            [void]$r.Msgs.Add($t)
            $btn = Buttons $b | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Sort-Object { -[Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($btn) { Click $btn } else { Close-Win $b }
            Start-Sleep -Milliseconds 700
            continue
        }
        if ($r.Cmp -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($r.Cmp)) {
            $t = [Drv102]::Internal($r.Cmp)
            if ($t -match $FinalRx -and $t -notmatch '\(') {
                Start-Sleep -Milliseconds 800
                $t = [Drv102]::Internal($r.Cmp)
                $r.Title = $t
                if ($t -match $FinalRx) { $r.Count = [int]$Matches[1] }
                $combo = @([Drv098f]::Kids($r.Cmp) | Where-Object { [Drv098f]::Cls($_) -eq 'ComboBox' -and [Drv098f]::GetDlgCtrlID($_) -eq 102 }) | Select-Object -First 1
                if ($combo) { $r.List0 = [Drv102]::LbText($combo, 0); $r.ListUnicode = [Drv102]::IsWindowUnicode($combo) }
                break
            }
        }
        elseif ($r.Cmp -ne [IntPtr]::Zero -and $r.Msgs.Count) { break }   # closed by the message's Yes
        if ($r.Cmp -eq [IntPtr]::Zero -and $r.Msgs.Count -and $sw.Elapsed.TotalSeconds -gt 4) { break }
        Start-Sleep -Milliseconds 200
    }
    if (-not $r.Title -and $r.Cmp -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($r.Cmp)) { $r.Title = [Drv102]::Internal($r.Cmp) }
    if (-not $KeepOpen) { Close-Cmp $Id $r.Cmp }
    return $r
}
function Close-Cmp([int]$Id, [IntPtr]$Cmp) {
    if ($Cmp -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($Cmp)) { return }
    [void][Drv098f]::PostMessageW($Cmp, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($Cmp)) { Start-Sleep -Milliseconds 100 }
    [void](Serve $Id 3)
}
# EXACT / DECOY / ERROR / NOTHING / OTHER
function Outcome($c, $r) {
    if ($r.Fatal) { return 'FATAL' }
    if ([int]$c.K -eq 0) {
        if (@($r.Msgs | Where-Object { $_ -match 'identical|identick' }).Count) { return 'EXACT' }
    }
    if ($r.Count -ge 0) {
        $named = $r.Title.IndexOf($c.Name, [StringComparison]::Ordinal) -ge 0
        if ($r.Count -eq [int]$c.K -and $named) { return 'EXACT' }
        if ($c.Decoy -and @(3, 4) -contains $r.Count) { return 'DECOY' }
        return ('OTHER(' + $r.Count + ')')
    }
    if ($r.Msgs.Count) { return 'ERROR' }
    if ($r.Cmp -ne [IntPtr]::Zero) { return 'OTHER' }
    return 'NOTHING'
}
function ListOk($c, $r) {
    if ([int]$c.K -eq 0 -or $r.Count -le 0) { return $true }
    return ($null -ne $r.List0 -and $r.List0.IndexOf($c.Name, [StringComparison]::Ordinal) -ge 0)
}
function Facts($r) {
    $m = 'no message'; if ($r.Msgs.Count) { $m = 'messages: ' + ((@($r.Msgs) | ForEach-Object { Short $_ 160 }) -join ' || ') }
    $l = ''; if ($null -ne $r.List0) { $l = ("; list[0] '{0}' (combo unicode {1})" -f (Short $r.List0 120), $r.ListUnicode) }
    return ("title '{0}'{1}; {2}" -f (Short $r.Title 220), $l, $m)
}
# the outcome the research predicts for the build before feature 102
function Before-Outcome($c, [string]$Route) {
    $cls = $c.Cls
    switch ($Route) {
        'ON' { if ($cls -eq 'long') { return 'NOTHING' }; if ($cls -eq 'cp' -or $cls -eq 'u8coin') { return 'EXACT' }; if ($cls -eq 'bestfit') { return 'DECOY' }; return 'ERROR' }
        'OFF' { if ($cls -eq 'long') { return 'NOTHING' }; return 'EXACT' }
        'REM' { if ($cls -eq 'bestfit' -or $cls -eq 'u8coin') { return 'DECOY' }; return 'ERROR' }
        # the Czech UI: a code-page name is compared, but the code-page template + UTF-8 name
        # shows it garbled in the title (068 F-P5-09 left the narrow fallback)
        'CZ' { if ($cls -eq 'cp') { return ('OTHER(' + $c.K + ')') }; if ($cls -eq 'bestfit') { return 'DECOY' }; return 'ERROR' }
    }
    return '?'
}
function Verdict($c, [string]$Route, [string]$Out, [bool]$List) {
    if ($Fixed) { return (V (($Out -eq 'EXACT') -and $List)) }
    return (V ($Out -eq (Before-Outcome $c $Route)))
}

# ---- routes -----------------------------------------------------------------------------
function Run-Dialog($c, [int]$Id, [string]$Step) {
    $d = CaseDir $c; $f1 = $d + '\L\' + $c.Name; $f2 = $d + '\R\' + $c.Name
    $held = Focus-File $Id $f1
    $h = Hotkey-Compare $Id
    if ($h.Win -eq [IntPtr]::Zero) {
        $o = 'NOTHING'
        Row $c.Case $Step (Verdict $c $Step $o $true) ("outcome {0}: Ctrl+Shift+C ({1}) opened no window; focus by Change Directory held {2}" -f $o, $h.Key, $held)
        return
    }
    if (-not (Is-CompareDlg $h.Win)) {
        $r = Await-Result $Id $h.Known
        $o = Outcome $c $r
        Row $c.Case $Step 'FAIL' ("expected the Compare Files dialog, got {0}; outcome {1}; {2}" -f (WinDesc $h.Win), $o, (Facts $r))
        return
    }
    $dlg = $h.Win
    $t1 = [Drv098f]::GetText((Field $dlg 101), 5000); $t2 = [Drv098f]::GetText((Field $dlg 102), 5000)
    $fieldsExact = ($t1 -ceq $f1) -and ($t2 -ceq $f2)
    $uni = [Drv102]::IsWindowUnicode((Field $dlg 101))
    $known = Get-Tops $Id
    Click-Ok $dlg
    $r = Await-Result $Id $known
    $o = Outcome $c $r
    $lok = ListOk $c $r
    $v = Verdict $c $Step $o $lok
    if ($Fixed -and -not $fieldsExact) { $v = 'FAIL' }
    Row $c.Case $Step $v ("outcome {0}; fields exact {1} (combo unicode {2}; read '{3}' / '{4}'); list exact {5}; {6}" -f $o, $fieldsExact, $uni, (Tail $t1 40), (Tail $t2 40), $lok, (Facts $r))
}
function Run-History($c, [int]$Id) {
    $d = CaseDir $c; $f1 = $d + '\L\' + $c.Name; $f2 = $d + '\R\' + $c.Name
    $h = Hotkey-Compare $Id
    if ($h.Win -eq [IntPtr]::Zero -or -not (Is-CompareDlg $h.Win)) { Row $c.Case 'HIST' 'FAIL' 'the Compare Files dialog did not open'; if ($h.Win -ne [IntPtr]::Zero) { Close-Win $h.Win }; return }
    $dlg = $h.Win
    $cb1 = Field $dlg 101; $cb2 = Field $dlg 102
    $n = [Drv102]::SendR($cb2, 0x0146, 0, 0)   # CB_GETCOUNT
    $items = @(); for ($i = 0; $i -lt $n; $i++) { $items += [Drv102]::LbText($cb2, $i) }
    $has1 = $items -ccontains $f1; $has2 = $items -ccontains $f2
    $idx = [Array]::IndexOf([string[]]$items, $f2)
    $picked = '<not in the list>'
    if ($idx -ge 0) {
        [void][Drv098f]::SetText($cb2, '', 5000)
        [void][Drv102]::SendR($cb2, 0x014E, $idx, 0)   # CB_SETCURSEL fills the edit from the item
        $picked = [Drv098f]::GetText($cb2, 5000)
    }
    $pickOk = $picked -ceq $f2
    Post-Cmd $dlg 2
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 5 -and [Drv098f]::IsWindow($dlg)) { Start-Sleep -Milliseconds 100 }
    [void](Serve $Id 3)
    $ok = $has1 -and $has2 -and $pickOk
    if ($Fixed) { $v = V $ok } else { $v = V (-not $ok) }   # before: every non-ASCII entry is garbled
    Row $c.Case 'HIST' $v ("{0} items; L name in the list {1}, R name {2}; picked entry fills the field exactly {3} ('{4}'); items: {5}" -f $n, $has1, $has2, $pickOk, (Tail $picked 40), ((@($items) | Select-Object -First 4 | ForEach-Object { Tail $_ 30 }) -join ' ; '))
}
function Run-Type($c, [int]$Id) {
    $d = CaseDir $c; $f1 = $d + '\L\' + $c.Name; $f2 = $d + '\R\' + $c.Name
    [void](Focus-File $Id $f1)
    $h = Hotkey-Compare $Id
    if ($h.Win -eq [IntPtr]::Zero -or -not (Is-CompareDlg $h.Win)) { Row $c.Case 'TYPE' 'FAIL' 'the Compare Files dialog did not open'; if ($h.Win -ne [IntPtr]::Zero) { Close-Win $h.Win }; return }
    $dlg = $h.Win; $cb2 = Field $dlg 102; $ed = Field-Edit $cb2
    [void][Drv098f]::SetText($cb2, '', 5000)
    foreach ($ch in $f2.ToCharArray()) { [void][Drv102]::PostMessageW($ed, 0x0102, [IntPtr][int]$ch, [IntPtr]1) }
    $sw = [Diagnostics.Stopwatch]::StartNew(); $t = ''
    while ($sw.Elapsed.TotalSeconds -lt 8) { Start-Sleep -Milliseconds 300; $t2 = [Drv098f]::GetText($cb2, 5000); if ($t2.Length -ge $f2.Length -or $t2 -ceq $t) { $t = $t2; if ($t.Length -ge $f2.Length) { break } }; $t = $t2 }
    $typedOk = $t -ceq $f2
    $known = Get-Tops $Id
    Click-Ok $dlg
    $r = Await-Result $Id $known
    $o = Outcome $c $r
    if ($Fixed) { $v = V ($typedOk -and $o -eq 'EXACT') } else { $v = V ((-not $typedOk) -and $o -ne 'EXACT') }
    Row $c.Case 'TYPE' $v ("typed {0} UTF-16 units as WM_CHAR: field exact {1} ('{2}'); outcome {3}; {4}" -f $f2.Length, $typedOk, (Tail $t 40), $o, (Facts $r))
    $dl = @(Get-Tops $Id | Where-Object { Is-CompareDlg $_ }); foreach ($x in $dl) { Close-Win $x }
}
function Run-NoFile($c, [int]$Id) {
    $d = CaseDir $c; $f1 = $d + '\L\' + $c.Name
    $nx = $d + '\R\' + (S 0x4E0D, 0x5B58, 0x5728) + '.txt'
    [void](Focus-File $Id $f1)
    $h = Hotkey-Compare $Id
    if ($h.Win -eq [IntPtr]::Zero -or -not (Is-CompareDlg $h.Win)) { Row $c.Case 'NOFILE' 'FAIL' 'the Compare Files dialog did not open'; return }
    $dlg = $h.Win
    [void][Drv098f]::SetText((Field $dlg 102), $nx, 5000)
    $known = Get-Tops $Id
    Click-Ok $dlg
    $r = Await-Result $Id $known 10
    $named = @($r.Msgs | Where-Object { $_.IndexOf((Split-Path $nx -Leaf), [StringComparison]::Ordinal) -ge 0 }).Count -gt 0
    $stays = [Drv098f]::IsWindow($dlg)
    if ($stays) { Post-Cmd $dlg 2; Start-Sleep -Milliseconds 600 }
    [void](Serve $Id 3)
    if ($Fixed) { $v = V ($named -and $stays -and $r.Cmp -eq [IntPtr]::Zero) } else { $v = V (-not ($named -and $stays)) }
    Row $c.Case 'NOFILE' $v ("a missing name: message names it exactly {0}; dialog stays {1}; comparator opened {2}; {3}" -f $named, $stays, ($r.Cmp -ne [IntPtr]::Zero), (Facts $r))
}
function Run-Browse($c, [int]$Id) {
    $d = CaseDir $c; $f1 = $d + '\L\' + $c.Name; $f2 = $d + '\R\' + $c.Name
    [void](Focus-File $Id $f1)
    $h = Hotkey-Compare $Id
    if ($h.Win -eq [IntPtr]::Zero -or -not (Is-CompareDlg $h.Win)) { Row $c.Case 'BROWSE' 'FAIL' 'the Compare Files dialog did not open'; return }
    $dlg = $h.Win
    $known = Get-Tops $Id
    $btn = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 105 })[0]
    Click $btn
    $od = Wait-NewWin $Id $known 15
    $res = 'NOT DRIVEN'; $facts = 'no open dialog appeared'
    if ($od -ne [IntPtr]::Zero) {
        Start-Sleep -Milliseconds 1500
        $edits = @([Drv098f]::Kids($od) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) })
        $fn = @($edits | Where-Object { [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148 -or [Drv098f]::GetDlgCtrlID($_) -eq 1148 }) | Select-Object -First 1
        if (-not $fn -and $edits.Count) { $fn = $edits[-1] }
        if ($fn) {
            [void][Drv098f]::SetText($fn, $f2, 5000)
            $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
            if ($ok) { Click $ok } else { Post-Cmd $od 1 }
            $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od)) { Start-Sleep -Milliseconds 100 }
            if ([Drv098f]::IsWindow($od)) { $facts = 'the open dialog did not close: ' + (WinDesc $od); Close-Win $od }
            else {
                $t = [Drv098f]::GetText((Field $dlg 102), 5000)
                $exact = $t -ceq $f2
                if ($Fixed) { $res = V $exact } else { $res = V (-not $exact) }
                $facts = ("open dialog '{0}' (class {1}); the field holds the chosen name exactly {2} ('{3}')" -f (Esc ([Drv098f]::Txt($od))), [Drv098f]::Cls($od), $exact, (Tail $t 40))
            }
        }
        else { $facts = 'no file name field in ' + (WinDesc $od); Close-Win $od }
    }
    Post-Cmd $dlg 2; Start-Sleep -Milliseconds 600; [void](Serve $Id 3)
    Row $c.Case 'BROWSE' $res $facts
}
function Run-Off($c, [int]$Id) {
    $d = CaseDir $c; $f1 = $d + '\L\' + $c.Name
    $held = Focus-File $Id $f1
    $h = Hotkey-Compare $Id
    if ($h.Win -eq [IntPtr]::Zero) { $o = 'NOTHING'; Row $c.Case 'OFF' (Verdict $c 'OFF' $o $true) ("outcome {0}: no window ({1})" -f $o, $h.Key); return }
    if (Is-CompareDlg $h.Win) { Row $c.Case 'OFF' 'FAIL' 'the dialog opened although "Confirm selection" is off'; Close-Win $h.Win; return }
    $r = Await-Result $Id $h.Known
    $o = Outcome $c $r; $lok = ListOk $c $r
    $lv = $lok; if (-not $Fixed) { $lv = $true }
    Row $c.Case 'OFF' (Verdict $c 'OFF' $o $lv) ("outcome {0}; list exact {1}; {2}" -f $o, $lok, (Facts $r))
}
function Run-Remote($c, [int]$Id, [switch]$Wait, [string]$Fc = $Fcremote, [string]$Step = 'REM') {
    $d = CaseDir $c; $f1 = $d + '\L\' + $c.Name; $f2 = $d + '\R\' + $c.Name
    $known = Get-Tops $Id
    $args2 = @(); if ($Wait) { $args2 += '-w' }; $args2 += ('"' + $f1 + '"'); $args2 += ('"' + $f2 + '"')
    $fp = Start-Process -FilePath $Fc -ArgumentList $args2 -PassThru
    [void]$fp.Handle
    $r = Await-Result $Id $known 25 -KeepOpen
    $waiting = -not $fp.HasExited
    $fcWins = New-Object System.Collections.ArrayList
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and -not $fp.HasExited) {   # fcremote's own message boxes
        foreach ($w in @([Drv098f]::Top([uint32]$fp.Id))) { [void]$fcWins.Add((RawText $w)); Close-Win $w }
        Start-Sleep -Milliseconds 200
    }
    Close-Cmp $Id $r.Cmp
    $exited = $fp.WaitForExit(15000)
    if (-not $exited) { foreach ($w in @([Drv098f]::Top([uint32]$fp.Id))) { [void]$fcWins.Add((RawText $w)); Close-Win $w }; $exited = $fp.WaitForExit(5000) }
    if (-not $exited) { Stop-Process -Id $fp.Id -Force }
    $ec = 'none'; if ($exited) { $ec = $fp.ExitCode }
    $o = Outcome $c $r; $lok = ListOk $c $r
    if ($Fixed) {
        $ok = ($o -eq 'EXACT') -and $lok -and $exited -and ($ec -eq 0) -and ($fcWins.Count -eq 0)
        if ($Wait) { $ok = $ok -and $waiting }
        $v = V $ok
    }
    else { $v = V ($o -eq (Before-Outcome $c 'REM')) }
    Row $c.Case $Step $v ("outcome {0}; list exact {1}; fcremote waited while the window was open {2}, exited {3} with {4}; fcremote windows: {5}; {6}" -f $o, $lok, $waiting, $exited, $ec, $(if ($fcWins.Count) { ($fcWins | ForEach-Object { Short $_ 120 }) -join ' || ' } else { 'none' }), (Facts $r))
}
# the OTHER build's fcremote against this program (the plug-in is loaded): a clear error, no hang
function Run-Mismatch($c, [int]$Id) {
    if (-not $OtherFcremote) { Row 'mism' 'MISM' 'NOT DRIVEN' 'no -OtherFcremote given'; return }
    $d = CaseDir $c; $f1 = $d + '\L\' + $c.Name; $f2 = $d + '\R\' + $c.Name
    $known = Get-Tops $Id
    $before = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $fp = Start-Process -FilePath $OtherFcremote -ArgumentList @('-w', ('"' + $f1 + '"'), ('"' + $f2 + '"')) -PassThru
    [void]$fp.Handle
    $msg = @(); $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and -not $fp.HasExited) {
        $w = @([Drv098f]::Top([uint32]$fp.Id) | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })
        if ($w.Count) { Start-Sleep -Milliseconds 500; $msg += (RawText $w[0]); Close-Win $w[0]; break }
        Start-Sleep -Milliseconds 200
    }
    $exited = $fp.WaitForExit(10000); if (-not $exited) { Stop-Process -Id $fp.Id -Force }
    $ec = 'none'; if ($exited) { $ec = $fp.ExitCode }
    $cmp = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq $CmpClass }).Count
    $extra = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id })
    $ex = ''
    foreach ($p in $extra) { $ex += (' ' + $p.Id + ' ' + $p.Path); [void]$Started.Add($p.Id); Stop-Process -Id $p.Id -Force }
    $ok = $exited -and ($msg.Count -eq 1) -and ($cmp -eq 0)
    Row 'mism' 'MISM' (V $ok) ("{0} against this program: fcremote message {1}; exited {2} with {3}; comparator windows {4}; programs fcremote started (ended by the probe):{5}" -f (Split-Path (Split-Path (Split-Path (Split-Path $OtherFcremote))) -Leaf), $(if ($msg.Count) { ($msg | ForEach-Object { Short $_ 160 }) -join ' || ' } else { 'none' }), $exited, $ec, $cmp, $(if ($ex) { $ex } else { ' none' }))
}

# diagnostics for a program that does not end: every window of the process (also hidden) and
# its thread count
function Proc-Diag([int]$Id) {
    $all = New-Object System.Collections.ArrayList
    [void][Drv102]::EnumAll([uint32]$Id, $all)
    $th = 0; try { $th = (Get-Process -Id $Id).Threads.Count } catch { }
    return ("threads {0}; windows: {1}" -f $th, (($all | Select-Object -First 25) -join ' ; '))
}
# the END row of the 098 library, with diagnostics when the program does not end
function End-Row102([string]$Case, [int]$Id, $Before) {
    $alive = Test-Alive $Id
    $resp = $false; if ($alive) { $resp = [Drv098f]::Send((Get-Main $Id), 0, 0, 0, 10000) }
    $extra = @(); if ($alive) { $extra = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass } | ForEach-Object { WinDesc $_ }) }
    $ec = '-'; $diag = ''
    $closes = 0
    if ($alive) {
        # review: one close request and a 30-second rule cannot tell a dropped request or an
        # unanswered box (e.g. "File Comparator plugin has rejected to unload. Force?") from a
        # hang - every window that appears while closing is recorded once (any class), a box is
        # answered OK/Yes after half a second, the close request is repeated at 10 s and 20 s
        $seenAt = @{}
        [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); $closes = 1
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
            foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and [Drv098f]::Cls($_) -ne 'SalamanderSaveBits' })) {   # SalamanderSaveBits = the program's wait window (CWaitWindow) while it closes
                $key = $h.ToInt64()
                if (-not $seenAt.ContainsKey($key)) { $seenAt[$key] = $sw.Elapsed.TotalSeconds; $extra += ("at exit ({0:N1} s): {1}" -f $sw.Elapsed.TotalSeconds, (WinDesc $h)); continue }
                if ([Drv098f]::Cls($h) -eq '#32770' -and $sw.Elapsed.TotalSeconds - $seenAt[$key] -gt 0.5) {
                    $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b }
                }
            }
            if (($closes -eq 1 -and $sw.Elapsed.TotalSeconds -gt 10) -or ($closes -eq 2 -and $sw.Elapsed.TotalSeconds -gt 20)) {
                $m = Get-Main $Id
                if ($m -ne [IntPtr]::Zero) { [void][Drv098f]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
                $closes++
            }
            Start-Sleep -Milliseconds 200
        }
        if (Test-Alive $Id) { $diag = Proc-Diag $Id; Kill-Mine $Id; $ec = ('did not exit in 30 s after {0} close requests - ended by the probe' -f $closes) } else { $ec = ExitCodeOf $Id }
    }
    else { $ec = 'already ended ' + (ExitCodeOf $Id) }
    Start-Sleep -Milliseconds 400
    foreach ($n in @((Reports) | Where-Object { $Before -notcontains $_ })) {   # the whole report, for the record
        Out ('  REPORT ' + $n)
        try { Get-Content -LiteralPath (Join-Path $ReportDir $n) -TotalCount 160 | ForEach-Object { Out ('    ' + (Esc $_)) } } catch { }
    }
    $rep = Take-Reports $Before
    $notes = @($extra | Where-Object { $_ -match 'monitored handles remained opened' })
    $extra = @($extra | Where-Object { $_ -notmatch 'monitored handles remained opened' })
    $ok = $resp -and ($extra.Count -eq 0) -and ($rep.Count -eq 0) -and ($ec -eq '0x00000000')
    Row $Case 'END' (V $ok) ("exit {0}; close requests {7}; WM_NULL {1}; stray {2}; new reports {3}{4}{5}{6}" -f $ec, $resp, $(if ($extra.Count) { '' + $extra.Count + ' (' + ($extra -join ' || ') + ')' } else { '0' }), $rep.Count, $(if ($rep.Count) { ' [' + ($rep -join ' ;; ') + ']' } else { '' }), $(if ($notes.Count) { '; Debug note: monitored handles' } else { '' }), $(if ($diag) { '; STILL RUNNING: ' + $diag } else { '' }), $closes)
}
function In-Instance($c, [scriptblock]$Body) {
    $d = CaseDir $c
    $id = 0; $before = Reports
    try {
        $id = Start-Fc ($d + '\L') ($d + '\R')
        & $Body $id
    }
    catch { Row $c.Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row102 $c.Case $id $before } }
}

# ---- main -------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc102_fc_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    Make-Fixtures
    Set-Config
    Set-Lang 'english.slg'
    Out ("filecomp_probe (feature 102), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("fcremote: {0}; other build's fcremote: {1}" -f $Fcremote, $(if ($OtherFcremote) { $OtherFcremote } else { '-' }))
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ("Long case: {0} UTF-16 units, {1} UTF-8 bytes to the R file" -f ((CaseDir $LongCase) + '\R\' + $LongCase.Name).Length, (U8Len ((CaseDir $LongCase) + '\R\' + $LongCase.Name)))
    Out ''
    Set-LoadOnStart $false
    Set-Confirm $true
    foreach ($c in $Cases) {
        if (-not ((Want 'on') -or (Want 'rem') -or (Want 'hist') -or (Want 'type') -or (Want 'nofile') -or (Want 'browse') -or (Want 'mism'))) { break }
        In-Instance $c {
            param($id)
            if (Want 'on') { Run-Dialog $c $id 'ON' }
            if ((Want 'hist') -and ($Fixed -or $c.Cls -ne 'long')) { Run-History $c $id }
            if ((Want 'type') -and @('cyr', 'emo', 'lone') -contains $c.Case) { Run-Type $c $id }
            if ((Want 'nofile') -and $c.Case -eq 'cjk') { Run-NoFile $c $id }
            if ((Want 'browse') -and $c.Case -eq 'cjk') { Run-Browse $c $id }
            if (Want 'rem') { Run-Remote $c $id }
            if ((Want 'rem') -and @('cz', 'cjk', 'lone') -contains $c.Case) { Run-Remote $c $id -Wait -Step 'REMW' }
            if ((Want 'mism') -and $c.Case -eq 'cyr') { Run-Mismatch $c $id }
        }
    }
    # the history the instances saved (registry, read as UTF-16)
    if (Want 'hist') {
        $k = Get-Item -LiteralPath $FcKey
        $hist = @($k.GetValueNames() | Where-Object { $_ -like 'History *' } | ForEach-Object { [string]$k.GetValue($_) })
        $want = @(); foreach ($c in $Cases | Where-Object { @('cyr', 'emo', 'lone', 'voila', 'fri') -contains $_.Case }) { $want += ((CaseDir $c) + '\L\' + $c.Name) }
        $found = @($want | Where-Object { $hist -ccontains $_ }).Count
        $garbled = @($hist | Where-Object { $_ -match '\?' }).Count
        if ($Fixed) { $v = V ($found -eq $want.Count -and $garbled -eq 0) } else { $v = 'INFO' }
        Row 'reg' 'HISTREG' $v ("{0} History values; of {1} expected L names (Cyrillic, emoji, lone surrogate, voila, f<U+65E5>) stored exactly: {2}; values with '?': {3}" -f $hist.Count, $want.Count, $found, $garbled)
    }
    # PATHS (review): fcremote with an INTERMEDIATE folder ending in a dot / a space (decoys:
    # the same folder names without it - GetFullPathNameW would drop the dot and compare them),
    # and names of 8,000 and 30,000 units (the header bar drew them with DT_PATH_ELLIPSIS,
    # whose cost grows with the square of the length: the window froze)
    if (Want 'paths') {
        Set-LoadOnStart $true
        $pr = $Root + '\paths'
        foreach ($t in @(@('DOT', '.'), @('SPACE', ' '))) {
            $base = $pr + '\' + $t[0]
            foreach ($sd in @('L', 'R')) { NewDir ($base + '\' + $sd + $t[1]); NewDir ($base + '\' + $sd) }
            Put ($base + '\L' + $t[1] + '\f.txt') (Content @() 'L-named')
            Put ($base + '\R' + $t[1] + '\f.txt') (Content @(1, 3) 'R-named')
            Put ($base + '\L\f.txt') (Content @(5) 'L-decoy')
            Put ($base + '\R\f.txt') (Content @(7, 9, 11) 'R-decoy')
        }
        # 8,000 units: both names; 30,000 units: the left name (two would not fit a command line)
        $chain = { param([int]$Units, [string]$Base) $p = $Base; $i = 0; while ($p.Length -lt $Units - 220) { $i++; $p += '\' + ('q' * [Math]::Min(200, $Units - 220 - $p.Length)) }; return $p }
        $l8 = & $chain 8000 ($pr + '\K8'); $r8 = $l8 + '\R'; $l8 = $l8 + '\L'
        $l30 = (& $chain 30000 ($pr + '\K30')) + '\L'; $r30 = $pr + '\K30R'
        foreach ($dd in @($l8, $r8, $l30, $r30)) { NewDir $dd }
        Put ($l8 + '\f.txt') (Content @() 'L-named'); Put ($r8 + '\f.txt') (Content @(1) 'R-named')
        Put ($l30 + '\f.txt') (Content @() 'L-named'); Put ($r30 + '\f.txt') (Content @(1) 'R-named')
        $pathRows = @(   # not $rows: PowerShell names are case-insensitive, $Rows is the report
            @{ Step = 'DOT'; F1 = $pr + '\DOT\L.\f.txt'; F2 = $pr + '\DOT\R.\f.txt'; K = 2; Long = $false },
            @{ Step = 'SPACE'; F1 = $pr + '\SPACE\L \f.txt'; F2 = $pr + '\SPACE\R \f.txt'; K = 2; Long = $false },
            @{ Step = 'LONG8K'; F1 = $l8 + '\f.txt'; F2 = $r8 + '\f.txt'; K = 1; Long = $true },
            @{ Step = 'LONG30K'; F1 = $l30 + '\f.txt'; F2 = $r30 + '\f.txt'; K = 1; Long = $true })
        $id = 0; $before = Reports
        try {
            $id = Start-Fc $StartDir $StartDir
            foreach ($row in $pathRows) {
                $c = @{ Case = 'paths'; Name = 'f.txt'; Decoy = 'f.txt'; Cls = 'trail'; K = $row.K }
                $known = Get-Tops $id
                $sw = [Diagnostics.Stopwatch]::StartNew()
                # CreateProcess directly (no ShellExecute): the command line of the 30,000-unit row is ~30,100 units
                $psi = New-Object Diagnostics.ProcessStartInfo $Fcremote, ('"' + $row.F1 + '" "' + $row.F2 + '"')
                $psi.UseShellExecute = $false
                $fp = [Diagnostics.Process]::Start($psi)
                $r = Await-Result $id $known 40 -KeepOpen
                $secs = $sw.Elapsed.TotalSeconds
                $maxMs = -1
                if ($r.Cmp -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($r.Cmp)) {
                    for ($k = 0; $k -lt 3; $k++) {   # a repaint of the whole window, then a message round trip
                        [void][Drv102]::Redraw($r.Cmp)
                        Start-Sleep -Milliseconds 300
                        $t0 = [Diagnostics.Stopwatch]::StartNew(); $okNull = [Drv098f]::Send($r.Cmp, 0, 0, 0, 60000); $ms = $t0.ElapsedMilliseconds
                        if (-not $okNull) { $ms = 60000 }
                        if ($ms -gt $maxMs) { $maxMs = $ms }
                    }
                }
                Close-Cmp $id $r.Cmp
                [void]$fp.WaitForExit(10000)
                $o = Outcome $c $r
                if ($row.Long) {
                    $named = $r.Title -and $r.Title.IndexOf('f.txt', [StringComparison]::Ordinal) -ge 0
                    if ($Fixed) { $v = V (($o -eq 'EXACT') -and $secs -lt 10 -and $maxMs -ge 0 -and $maxMs -lt 1000) } else { $v = 'INFO' }
                }
                elseif ($Fixed) { $v = V ($o -eq 'EXACT') }
                else { $v = V ($o -eq 'EXACT') }   # 0.1.8 opened these ASCII names as typed
                Row 'paths' $row.Step $v ("{0} / {1} units; outcome {2}; result after {3:N1} s; slowest WM_NULL round trip after a repaint {4} ms; {5}" -f $row.F1.Length, $row.F2.Length, $o, $secs, $maxMs, (Facts $r))
            }
        }
        catch { Row 'paths' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { End-Row102 'paths' $id $before }; Set-LoadOnStart $false }
    }
    # INS: an inserted line between two DIFFERENT names (both selected in one panel); the list
    # item says "Insert line 4 from right file (<right name>) after line 3 in left file (<left>)"
    # - the names were passed the other way round before feature 102 (English UI)
    if (Want 'ins') {
        $c = @{ Case = 'ins'; Name = 'b' + (S 0x65E5) + '.txt'; Decoy = $null; Cls = 'out'; K = 1 }
        $d = $Root + '\ins'; NewDir $d
        $nL = 'a' + (S 0x0416) + '.txt'; $nR = $c.Name
        Put ($d + '\' + $nL) (Content @() 'base')
        $ins = (Content @() 'base') -split "`r`n"; $ins = @($ins[0..2] + @('INSERTED line') + $ins[3..($ins.Count - 1)])
        Put ($d + '\' + $nR) ($ins -join "`r`n")
        $id = 0; $before = Reports
        try {
            $id = Start-Fc $d $StartDir
            Post-Cmd (Get-Main $id) 842   # select all (the two files)
            Start-Sleep -Milliseconds 500; Sync $id
            $h = Hotkey-Compare $id
            if ($h.Win -eq [IntPtr]::Zero -or -not (Is-CompareDlg $h.Win)) { Row 'ins' 'INS' 'FAIL' 'the Compare Files dialog did not open' }
            else {
                $t1 = [Drv098f]::GetText((Field $h.Win 101), 5000); $t2 = [Drv098f]::GetText((Field $h.Win 102), 5000)
                $known = Get-Tops $id
                Click-Ok $h.Win
                $r = Await-Result $id $known
                $left = Split-Path $t1 -Leaf; $right = Split-Path $t2 -Leaf
                $okNames = $null -ne $r.List0 -and $r.List0 -match 'from right file \((.*)\) after line \d+ in left file \((.*)\)$' -and $Matches[1] -ceq $right -and $Matches[2] -ceq $left
                if ($Fixed) { $v = V ($okNames -and $r.Count -eq 1) } else { $v = V (-not $okNames) }
                Row 'ins' 'INS' $v ("fields '{0}' / '{1}'; list[0] names the right file first and the left file second exactly: {2}; {3}" -f (Esc $left), (Esc $right), $okNames, (Facts $r))
            }
        }
        catch { Row 'ins' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { End-Row102 'ins' $id $before } }
    }
    if (Want 'off') {
        Set-Confirm $false
        foreach ($c in $Cases) { In-Instance $c { param($id) Run-Off $c $id } }
        Set-Confirm $true
    }
    if (Want 'cz') {
        Set-Lang 'czech.slg'
        foreach ($c in $Cases | Where-Object { @('cz', 'cyr', 'voila') -contains $_.Case }) {
            In-Instance $c { param($id) Run-Dialog $c $id 'CZ'; if (Want 'rem') { Run-Remote $c $id -Step 'CZREM' } }
        }
        Set-Lang 'english.slg'
    }
    if (Want 'start') {
        $c = $Cases | Where-Object { $_.Case -eq 'cjk' }
        Set-LoadOnStart $true
        $before = Reports
        $d = CaseDir $c; $f1 = $d + '\L\' + $c.Name; $f2 = $d + '\R\' + $c.Name
        $fp = Start-Process -FilePath $Fcremote -ArgumentList @('-w', ('"' + $f1 + '"'), ('"' + $f2 + '"')) -PassThru
        [void]$fp.Handle
        $sw = [Diagnostics.Stopwatch]::StartNew(); $tp = $null
        while ($sw.Elapsed.TotalSeconds -lt 40 -and -not $tp) { $tp = Get-Process tandemcommander -ErrorAction SilentlyContinue | Select-Object -First 1; Start-Sleep -Milliseconds 200 }
        if (-not $tp) { Row 'start' 'START' 'FAIL' 'fcremote did not start the program'; $fcw = @([Drv098f]::Top([uint32]$fp.Id) | ForEach-Object { RawText $_ }); Out ('  fcremote windows: ' + (($fcw | ForEach-Object { Short $_ }) -join ' || ')); if (-not $fp.HasExited) { Stop-Process -Id $fp.Id -Force } }
        else {
            [void]$Started.Add($tp.Id); $script:Procs[$tp.Id] = $tp; [void]$tp.Handle
            $r = Await-Result $tp.Id @() 40 -KeepOpen
            $waiting = -not $fp.HasExited
            Close-Cmp $tp.Id $r.Cmp
            $exited = $fp.WaitForExit(15000); if (-not $exited) { Stop-Process -Id $fp.Id -Force }
            $ec = 'none'; if ($exited) { $ec = $fp.ExitCode }
            $o = Outcome $c $r
            if ($Fixed) { $v = V (($o -eq 'EXACT') -and $waiting -and $exited -and $ec -eq 0 -and ($tp.Path -ieq $Exe)) } else { $v = V ($o -eq 'ERROR') }
            Row 'start' 'START' $v ("program started by fcremote: {0}; outcome {1}; fcremote waited {2}, exited {3} with {4}; {5}" -f $tp.Path, $o, $waiting, $exited, $ec, (Facts $r))
            End-Row102 'start' $tp.Id $before
        }
        Set-LoadOnStart $false
    }
    $miss = Disk-Ok
    Row 'disk' 'DISK' (V (-not $miss)) $(if ($miss) { $miss } else { 'every fixture file is still on disk' })
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    foreach ($p in @(Get-Process fcremote -ErrorAction SilentlyContinue)) { Stop-Process -Id $p.Id -Force }
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
