<#
.SYNOPSIS
    Feature 093, baseline measurement: which text fields of the PRODUCT lose
    characters outside the system code page, and by which channel.

.DESCRIPTION
    Starts tandemcommander.exe (-Exe) on a fixture folder and, per surface,
    opens the dialog by its command id, finds the text control by its control
    id and records per control:

      A  IsWindowUnicode + window class of the dialog, the control and (combo)
         the inner edit
      B  prefill: what the field shows on opening (SendMessageW WM_GETTEXT)
      C  programmatic set: SendMessageW(WM_SETTEXT, test text), read back wide
      D  typing: field cleared, PostMessageW(WM_CHAR) per UTF-16 unit of the
         test text (to the inner edit of a combo), read back wide - this goes
         through the dialog's real message loop
      E  outcome where cheap (Create Directory: the directory on disk;
         Change Directory: where the panel is afterwards)

    Test text: a, U+0159 (in code page 1250), U+0416, U+65E5, U+D83D U+DCC1.

    Surfaces (names for -Only):
      createdir changedir pack unpack select filter find hotpaths usermenu
      config cmdline about msgbox
      convert filelist driveinfo changeicon compareargs editlb drive
    (the second line was added for stage S1: five more modal dialogs, the
    in-place editor of an edit list box, and 'drive' = a regression drive of
    the Find window - search, menu bar by Alt+letter - and of the main menu)

    One line per control and channel:
      surface | control | channel | classes dlg/ctl/inner | unicode dlg/ctl/inner | exp=<hex> | act=<hex> | verdict
    Verdicts: PASS (text equal), LOSSY (text differs), INFO (channel A, no
    text compared), NOT DRIVEN (with the reason), FAIL (a regression-drive
    step of the 'drive' surface did not give the expected result).

    SAFETY: only the processes started here are addressed, by pid; messages go
    only to windows of those pids; no SendInput. HKCU\Software\Tandem Commander
    is exported before the first start and restored and verified (SHA-256 of a
    second export) at the end. Values changed for the run: UI language
    (English) and the exit confirmation. The fixture %TEMP%\tc093_dlg is
    removed.

.PARAMETER Exe
    tandemcommander.exe to measure.
.PARAMETER Only
    Run only the named surfaces.
.PARAMETER Label
    Free text printed in the first line (which build this is).
.PARAMETER OutFile
    Also write every printed line to this file (UTF-8, the content is ASCII).

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII (strings are built from
    character codes, foreign text is printed as hex / \uXXXX).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Only,
    [string]$Label,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }

if (-not ('Drv093' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Drv093
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendTextTimeout(IntPtr h, uint msg, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendGetText(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll")] public static extern uint GetACP();

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(4096); GetWindowTextW(h, s, 4096); return s.ToString(); }
    public static uint PidOf(IntPtr h) { uint q; GetWindowThreadProcessId(h, out q); return q; }

    public static List<IntPtr> Top(uint pid)
    {
        var l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { uint q; GetWindowThreadProcessId(h, out q); if (q == pid && IsWindowVisible(h)) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static List<IntPtr> Kids(IntPtr parent)   // all descendants
    {
        var l = new List<IntPtr>();
        EnumChildWindows(parent, delegate(IntPtr h, IntPtr p) { l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static bool Send(IntPtr h, uint msg, long w, long l, uint timeout)
    {
        IntPtr res;
        return SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, timeout, out res) != IntPtr.Zero;
    }
    public static bool SetText(IntPtr h, string s, uint timeout)
    {
        IntPtr res;
        return SendTextTimeout(h, 0x000C, IntPtr.Zero, s, 0, timeout, out res) != IntPtr.Zero;
    }
    // items of a combo box list (CB_GETCOUNT / CB_GETLBTEXT, marshalled by USER32)
    public static List<string> ComboItems(IntPtr h, uint timeout)
    {
        var l = new List<string>(); IntPtr res;
        if (SendMessageTimeoutW(h, 0x0146, IntPtr.Zero, IntPtr.Zero, 0, timeout, out res) == IntPtr.Zero) return l;
        int n = (int)res.ToInt64();
        for (int i = 0; i < n && i < 40; i++)
        {
            var buf = new char[8192];
            if (SendGetText(h, 0x0148, (IntPtr)i, buf, 0, timeout, out res) == IntPtr.Zero) break;
            int len = (int)res.ToInt64(); if (len < 0) len = 0; if (len > buf.Length) len = buf.Length;
            l.Add(new string(buf, 0, len));
        }
        return l;
    }
    // WM_GETTEXT, wide, by the returned length (code units as they are, no
    // stop at anything but the count the window reports)
    public static string GetText(IntPtr h, uint timeout)
    {
        IntPtr res; var buf = new char[8192];
        SendGetText(h, 0x000D, (IntPtr)buf.Length, buf, 0, timeout, out res);
        int n = (int)res.ToInt64();
        if (n < 0) n = 0; if (n > buf.Length) n = buf.Length;
        return new string(buf, 0, n);
    }
}
'@
}

$MainClass = 'TandemCommanderMainWindowVer01'
$RegKey = 'HKCU\Software\Tandem Commander'
$Started = New-Object System.Collections.ArrayList
$script:Procs = @{}
$script:ExitCodes = New-Object System.Collections.ArrayList
$script:Lines = New-Object System.Collections.ArrayList
$script:Lossy = 0; $script:Pass = 0; $script:NotDriven = 0; $script:Fail = 0
$script:Unexpected = @()

function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
$TestText = S 0x61, 0x159, 0x416, 0x65E5, 0xD83D, 0xDCC1
$NameCyr = (S 0x416, 0x2D, 0x43F, 0x440, 0x43E, 0x435, 0x43A, 0x442)   # Zh-proekt
$NameCjk = (S 0x65E5, 0x672C)                                          # nihon
$NameEmo = (S 0xD83D, 0xDCC1)                                          # folder emoji

function Hex([string]$s) {
    if ($null -eq $s) { return '<null>' }
    if ($s.Length -eq 0) { return '<empty>' }
    return (($s.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ')
}
function Esc([string]$s) {   # ASCII-safe rendering
    if ($null -eq $s) { return '<null>' }
    $sb = New-Object Text.StringBuilder
    foreach ($c in $s.ToCharArray()) { if ([int]$c -ge 32 -and [int]$c -lt 127) { [void]$sb.Append($c) } else { [void]$sb.AppendFormat('\u{0:X4}', [int]$c) } }
    return $sb.ToString()
}
function Out([string]$line) { Write-Host $line; [void]$script:Lines.Add($line) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }

# ---- registry ---------------------------------------------------------------
function Backup-TcRegistry([string]$File) {
    & cmd.exe /c "reg query `"$RegKey`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    & cmd.exe /c "reg export `"$RegKey`" `"$File`" /y >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'reg export failed' }
    return $true
}
function Restore-TcRegistry([string]$File, [bool]$Existed) {
    & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
    if (-not $Existed) { Out 'Registry: the key did not exist before - deleted'; return $true }
    & cmd.exe /c "reg import `"$File`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Out "Registry: IMPORT FAILED - restore by hand from $File"; return $false }
    $check = "$File.check"
    & cmd.exe /c "reg export `"$RegKey`" `"$check`" /y >nul 2>&1"
    $ha = (Get-FileHash -LiteralPath $File).Hash; $hb = (Get-FileHash -LiteralPath $check).Hash
    Out ("Registry: restored; identical={0}; SHA-256 before {1} / after {2}" -f ($ha -eq $hb), $ha, $hb)
    Remove-Item -LiteralPath $check -Force
    return ($ha -eq $hb)
}

# ---- process and windows ----------------------------------------------------
function Test-Alive([int]$Id) { return [bool](Get-Process -Id $Id -ErrorAction SilentlyContinue) }
function Get-Tops([int]$Id) { return @([Drv093]::Top([uint32]$Id)) }
function Get-Main([int]$Id) {
    foreach ($h in [Drv093]::Top([uint32]$Id)) { if ([Drv093]::Cls($h) -eq $MainClass) { return $h } }
    return [IntPtr]::Zero
}
function Assert-Mine([int]$Id, [IntPtr]$H) { if ([Drv093]::PidOf($H) -ne [uint32]$Id) { throw 'window does not belong to the test process' } }
function Sync([int]$Id) {
    $m = Get-Main $Id
    if ($m -eq [IntPtr]::Zero) { throw 'no main window' }
    [void][Drv093]::Send($m, 0, 0, 0, 20000)
}
function Get-DialogText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv093]::Kids($H)) {
        $t = [Drv093]::Txt($c)
        if ($t -and [Drv093]::IsWindowVisible($c)) { $parts += ("[{0} id={1}] {2}" -f [Drv093]::Cls($c), [Drv093]::GetDlgCtrlID($c), (Esc ($t -replace '\s+', ' '))) }
    }
    $r = ($parts -join ' | ')
    if ($r.Length -gt 400) { $r = $r.Substring(0, 400) + '...' }
    return $r
}
function Post-Cmd([IntPtr]$H, [int]$C) { [void][Drv093]::PostMessageW($H, 0x0111, [IntPtr]$C, [IntPtr]::Zero) }

# closes a window of the pid: Cancel command first, then WM_CLOSE
function Close-Win([int]$Id, [IntPtr]$H) {
    if (-not [Drv093]::IsWindow($H)) { return }
    Assert-Mine $Id $H
    Post-Cmd $H 2                                        # IDCANCEL
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv093]::IsWindow($H) -and [Drv093]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
    if ([Drv093]::IsWindow($H) -and [Drv093]::IsWindowVisible($H)) {
        [void][Drv093]::PostMessageW($H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        $sw.Restart()
        while ($sw.Elapsed.TotalSeconds -lt 3 -and [Drv093]::IsWindow($H) -and [Drv093]::IsWindowVisible($H)) { Start-Sleep -Milliseconds 50 }
    }
}
# closes every top-level window of the pid except the main one; records them
function Clear-Wins([int]$Id, [string]$Where, [bool]$Record = $true) {
    for ($round = 0; $round -lt 4; $round++) {
        $extra = @(Get-Tops $Id | Where-Object { [Drv093]::Cls($_) -ne $MainClass })
        if (-not $extra.Count) { return }
        foreach ($h in $extra) {
            if ($Record) {
                $d = ("{0}: window class={1} title='{2}': {3}" -f $Where, [Drv093]::Cls($h), (Esc ([Drv093]::Txt($h))), (Get-DialogText $h))
                Out "   UNEXPECTED $d"; $script:Unexpected += $d
            }
            Close-Win $Id $h
        }
    }
}
function Wait-NewWin([int]$Id, $Known, [double]$Seconds = 8) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in (Get-Tops $Id)) { if ($Known -notcontains $h) { Start-Sleep -Milliseconds 400; return $h } }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
# posts a command to the main window and returns the new top-level window (or Zero)
function Open-ByCmd([int]$Id, [int]$C, [double]$Seconds = 8) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) $C
    return (Wait-NewWin $Id $known $Seconds)
}

function Start-Tc([string]$Dir) {
    $a = @('-t', 'T093', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Dir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id)
    [void]$p.Handle                      # keeps the exit code readable after the process has ended
    $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 3000
    Sync $p.Id
    Clear-Wins $p.Id 'start'
    return $p.Id
}
function Stop-Tc([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    if ($Started -notcontains $Id) { throw "pid $Id was not started by this probe" }
    Clear-Wins $Id 'stop' $false
    $m = Get-Main $Id
    if ($m -ne [IntPtr]::Zero) { [void][Drv093]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
        foreach ($h in (Get-Tops $Id)) {
            if ([Drv093]::Cls($h) -eq '#32770') {
                $yes = [Drv093]::Kids($h) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
                if ($yes) { [void][Drv093]::PostMessageW($yes, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
                else { [void][Drv093]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
            }
        }
        Start-Sleep -Milliseconds 200
    }
    if (Test-Alive $Id) { Out "   (pid $Id did not exit in 30 s - ended by pid)"; [void]$script:ExitCodes.Add('killed'); Stop-Process -Id $Id -Force; Start-Sleep -Milliseconds 500 }
    elseif ($script:Procs.ContainsKey($Id)) {
        $pr = $script:Procs[$Id]; $script:Procs.Remove($Id)
        try { [void]$pr.WaitForExit(5000); $ec = $pr.ExitCode } catch { $ec = 'unknown' }
        [void]$script:ExitCodes.Add("$ec")
        Out ("   process exit code: {0}" -f $ec)
    }
}

function Get-LeftList([int]$Id) {
    $m = Get-Main $Id
    $lists = @([Drv093]::Kids($m) | Where-Object { [Drv093]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv093]::IsWindowVisible($_) })
    if ($lists.Count -lt 1) { throw 'panel list window not found' }
    return $lists[0]
}
function Key([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv093]::Send($l, 0x0100, $Vk, 1, 20000)
    [void][Drv093]::Send($l, 0x0101, $Vk, 0xC0000001, 20000)
}
function Title([int]$Id) { return [Drv093]::Txt((Get-Main $Id)) }

# ---- measurement ------------------------------------------------------------

# descendant of $Dlg with control id $CtlId (visible ones preferred)
function Find-Ctl([IntPtr]$Dlg, [int]$CtlId) {
    $c = @([Drv093]::Kids($Dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq $CtlId -and @('ComboBox', 'Edit') -contains [Drv093]::Cls($_) })
    $v = @($c | Where-Object { [Drv093]::IsWindowVisible($_) })
    if ($v.Count) { return $v[0] }
    if ($c.Count) { return $c[0] }
    return [IntPtr]::Zero
}
function Inner-Edit([IntPtr]$Ctl) {
    if ([Drv093]::Cls($Ctl) -ne 'ComboBox') { return [IntPtr]::Zero }
    $e = @([Drv093]::Kids($Ctl) | Where-Object { [Drv093]::Cls($_) -eq 'Edit' })
    if ($e.Count) { return $e[0] }
    return [IntPtr]::Zero
}
function Describe([IntPtr]$Dlg, [IntPtr]$Ctl) {
    $in = Inner-Edit $Ctl
    $par = [Drv093]::GetParent($Ctl)
    $cls = '{0}/{1}/{2}' -f [Drv093]::Cls($Dlg), [Drv093]::Cls($Ctl), $(if ($in -ne [IntPtr]::Zero) { [Drv093]::Cls($in) } else { '-' })
    $uni = 'dlg={0} ctl={1} inner={2}' -f [Drv093]::IsWindowUnicode($Dlg), [Drv093]::IsWindowUnicode($Ctl), $(if ($in -ne [IntPtr]::Zero) { [Drv093]::IsWindowUnicode($in) } else { '-' })
    if ($par -ne $Dlg -and $par -ne [IntPtr]::Zero) { $cls += (' (parent {0})' -f [Drv093]::Cls($par)); $uni += (' parent={0}' -f [Drv093]::IsWindowUnicode($par)) }
    return @($cls, $uni)
}
function Row([string]$Surface, [string]$Ctl, [string]$Ch, [string]$Cls, [string]$Uni, [string]$Exp, [string]$Act, [string]$Verdict, [string]$Note) {
    $line = "{0,-10}| {1,-26}| {2} | {3} | {4} | exp={5} | act={6} | {7}" -f $Surface, $Ctl, $Ch, $Cls, $Uni, $Exp, $Act, $Verdict
    if ($Note) { $line += " | $Note" }
    Out $line
    if ($Verdict -eq 'PASS') { $script:Pass++ } elseif ($Verdict -eq 'LOSSY') { $script:Lossy++ } elseif ($Verdict -like 'NOT DRIVEN*') { $script:NotDriven++ } elseif ($Verdict -eq 'FAIL') { $script:Fail++ }
}
function Ctl([int]$CtlId, [string]$Name, [string]$Prefill, [string]$Mode = 'exact') { return [pscustomobject]@{ Id = $CtlId; Name = $Name; Prefill = $Prefill; Mode = $Mode } }
function NotDriven([string]$Surface, [string]$Why) { Row $Surface '-' '-' '-' '-' '-' '-' 'NOT DRIVEN' $Why }

# reads the text until it has stopped changing (posted WM_CHARs are served by
# the target's own loop; a sent message would overtake them)
function Read-Settled([IntPtr]$Dlg, [IntPtr]$H, [int]$WantLen) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $prev = $null; $same = 0
    while ($sw.Elapsed.TotalSeconds -lt 4) {
        [void][Drv093]::Send($Dlg, 0, 0, 0, 5000)          # WM_NULL round trip
        $t = [Drv093]::GetText($H, 5000)
        if ($t -ceq $prev) { $same++ } else { $same = 0 }
        if ($same -ge 3 -and ($t.Length -ge $WantLen -or $sw.Elapsed.TotalMilliseconds -gt 1200)) { return $t }
        $prev = $t
        Start-Sleep -Milliseconds 100
    }
    return $prev
}

# channels A, B (when $Prefill is given), C, D for one control
# $PrefillMode: 'exact' = the field must equal $Prefill; 'contains' = it must contain it
# $Hwnd: the control itself when it cannot be found by its id (the in-place editor of a list)
function Measure-Ctl([string]$Surface, [IntPtr]$Dlg, [int]$CtlId, [string]$CtlName, [string]$Prefill, [string]$PrefillMode = 'exact', [bool]$DoSetType = $true, [IntPtr]$Hwnd = [IntPtr]::Zero) {
    if ($Hwnd -ne [IntPtr]::Zero) { $ctl = $Hwnd } else { $ctl = Find-Ctl $Dlg $CtlId }
    $label = "$CtlName id=$CtlId"
    if ($ctl -eq [IntPtr]::Zero) { Row $Surface $label '-' '-' '-' '-' '-' 'NOT DRIVEN' 'no ComboBox/Edit with this id in the window'; return }
    $d = Describe $Dlg $ctl
    $inner = Inner-Edit $ctl
    $note = ''
    if (-not [Drv093]::IsWindowEnabled($ctl)) { $note = 'control disabled' }
    if (-not [Drv093]::IsWindowVisible($ctl)) { $note = ($note + ' control not visible').Trim() }
    Row $Surface $label 'A' $d[0] $d[1] '-' '-' 'INFO' $note

    if ($Prefill) {
        $act = [Drv093]::GetText($ctl, 5000)
        $n = "shown: " + (Esc $act)
        if ($PrefillMode -eq 'exact') { $ok = ($act -ceq $Prefill) }
        elseif ($PrefillMode -eq 'list') {
            # the path may be offered in the combo's list instead of the edit (depends on the configuration)
            $items = @([Drv093]::ComboItems($ctl, 5000))
            $ok = ($act.IndexOf($Prefill, [StringComparison]::Ordinal) -ge 0) -or (@($items | Where-Object { $_.IndexOf($Prefill, [StringComparison]::Ordinal) -ge 0 }).Count -gt 0)
            $n += ("; list items ({0}): {1}" -f $items.Count, (($items | Select-Object -First 4 | ForEach-Object { Esc $_ }) -join ' ; '))
            $act = $act + '|' + (($items | Select-Object -First 2) -join '|')
        }
        else { $ok = ($act.IndexOf($Prefill, [StringComparison]::Ordinal) -ge 0) }
        Row $Surface $label 'B' $d[0] $d[1] ("({0}) {1}" -f $PrefillMode, (Hex $Prefill)) (Hex $act) $(if ($ok) { 'PASS' } else { 'LOSSY' }) $n
    }
    if (-not $DoSetType) { return }

    # C: programmatic set
    if (-not [Drv093]::SetText($ctl, $TestText, 5000)) { Row $Surface $label 'C' $d[0] $d[1] (Hex $TestText) '-' 'NOT DRIVEN' 'WM_SETTEXT timed out' }
    else {
        $act = [Drv093]::GetText($ctl, 5000)
        $n = ''
        if ($inner -ne [IntPtr]::Zero) { $ia = [Drv093]::GetText($inner, 5000); if ($ia -cne $act) { $n = 'inner edit reads ' + (Hex $ia) } }
        Row $Surface $label 'C' $d[0] $d[1] (Hex $TestText) (Hex $act) $(if ($act -ceq $TestText) { 'PASS' } else { 'LOSSY' }) $n
    }

    # D: typing through the window's own message loop
    $target = $ctl; if ($inner -ne [IntPtr]::Zero) { $target = $inner }
    [void][Drv093]::SetText($ctl, '', 5000)
    $left = [Drv093]::GetText($ctl, 5000)
    foreach ($u in $TestText.ToCharArray()) { [void][Drv093]::PostMessageW($target, 0x0102, [IntPtr][int]$u, [IntPtr]1) }
    $act = Read-Settled $Dlg $ctl $TestText.Length
    $n = ''; if ($left.Length) { $n = 'field not empty before typing: ' + (Hex $left) }
    # the flags again: an attached subclass may have changed them meanwhile
    $d2 = Describe $Dlg $ctl
    if ($d2[1] -ne $d[1]) { $n = ($n + ' flags after typing: ' + $d2[1]).Trim() }
    Row $Surface $label 'D' $d[0] $d[1] (Hex $TestText) (Hex $act) $(if ($act -ceq $TestText) { 'PASS' } else { 'LOSSY' }) $n
}

# opens a dialog by a main-window command, measures the listed controls, cancels
# $Ctls: array of Ctl objects
function Surface-Dialog([int]$Id, [string]$Surface, [int]$C, $Ctls, [scriptblock]$Before, [scriptblock]$AfterOpen) {
    try {
        if ($Before) { & $Before }
        $dlg = Open-ByCmd $Id $C
        if ($dlg -eq [IntPtr]::Zero) { NotDriven $Surface "command $C opened no window"; return }
        Out ("   {0}: window class={1} title='{2}'" -f $Surface, [Drv093]::Cls($dlg), (Esc ([Drv093]::Txt($dlg))))
        if ($AfterOpen) { & $AfterOpen $dlg }
        foreach ($item in @($Ctls)) { Measure-Ctl $Surface $dlg $item.Id $item.Name $item.Prefill $item.Mode }
        Close-Win $Id $dlg
        Start-Sleep -Milliseconds 300
        Clear-Wins $Id $Surface
        Sync $Id
    }
    catch { NotDriven $Surface $_.Exception.Message; try { Clear-Wins $Id $Surface } catch { } }
}

# OK: BM_CLICK on the IDOK button; when the dialog stays, WM_COMMAND IDOK
function Click-Ok([IntPtr]$Dlg) {
    $ok = [Drv093]::Kids($Dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 1 -and [Drv093]::Cls($_) -eq 'Button' } | Select-Object -First 1
    $how = 'BM_CLICK'
    if ($ok) { [void][Drv093]::PostMessageW($ok, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 2 -and [Drv093]::IsWindow($Dlg) -and [Drv093]::IsWindowEnabled($Dlg)) { Start-Sleep -Milliseconds 50 }
    if ([Drv093]::IsWindow($Dlg) -and [Drv093]::IsWindowEnabled($Dlg)) { Post-Cmd $Dlg 1; $how = 'WM_COMMAND IDOK (BM_CLICK had no effect)' }
    return $how
}

# Create Directory with $Name through the F7 dialog; returns a note
function Do-CreateDir([int]$Id, [string]$Name) {
    $dlg = Open-ByCmd $Id 730
    if ($dlg -eq [IntPtr]::Zero) { return 'no dialog' }
    $ctl = Find-Ctl $dlg 210
    if ($ctl -eq [IntPtr]::Zero) { Close-Win $Id $dlg; return 'no IDE_PATH' }
    [void][Drv093]::SetText($ctl, $Name, 5000)
    $how = Click-Ok $dlg
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 5 -and [Drv093]::IsWindow($dlg)) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 500
    return $how
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc093_dlg_backup.reg'
$root = Join-Path $env:TEMP 'tc093_dlg'
$existed = Backup-TcRegistry $backup
$regOk = $false
try {
    Out ("=== dialogs_probe: {0}  (built {1:yyyy-MM-dd HH:mm:ss}){2} ===" -f $Exe, (Get-Item -LiteralPath $Exe).LastWriteTime, $(if ($Label) { "  [$Label]" } else { '' }))
    Out ("System code page {0}. Test text: {1}" -f [Drv093]::GetACP(), (Hex $TestText))

    # ---- manifest (static) ----
    $bytes = [IO.File]::ReadAllBytes($Exe)
    $latin = [Text.Encoding]::GetEncoding(28591).GetString($bytes)
    $ix = $latin.IndexOf('Microsoft.Windows.Common-Controls')
    if ($ix -ge 0) {
        $seg = $latin.Substring($ix, [Math]::Min(200, $latin.Length - $ix)) -replace '\s+', ' '
        $ver = ''; if ($seg -match 'version\s*=\s*["'']([\d\.]+)["'']') { $ver = $Matches[1] }
        Out ("Manifest: embedded dependency on Microsoft.Windows.Common-Controls, version '{0}'" -f $ver)
    }
    else { Out 'Manifest: NO reference to Microsoft.Windows.Common-Controls in the .exe' }

    # ---- fixture ----
    if ([IO.Directory]::Exists($root)) { [IO.Directory]::Delete($root, $true) }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $dirs = @{}
    foreach ($n in @(@('cyr', $NameCyr), @('cjk', $NameCjk), @('emo', $NameEmo))) {
        $d = Join-Path $root $n[1]
        [void][IO.Directory]::CreateDirectory($d)
        # the one file of the folder is a small real ZIP archive (Pack takes it as a file, Unpack as an archive)
        $zs = [IO.File]::Create((Join-Path $d ($TestText + '.zip')))
        $za = New-Object IO.Compression.ZipArchive($zs, [IO.Compression.ZipArchiveMode]::Create)
        $e = $za.CreateEntry('hello.txt'); $w = New-Object IO.StreamWriter($e.Open()); $w.Write('feature 093 probe'); $w.Dispose()
        $za.Dispose(); $zs.Dispose()
        $dirs[$n[0]] = $d
    }
    Out ("Fixture: {0}\{{{1} | {2} | {3}}}\<test text>.zip" -f (Esc $root), (Hex $NameCyr), (Hex $NameCjk), (Hex $NameEmo))

    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) {
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
        # seeded for the Configuration pages (removed again by the registry restore):
        # hot path slot 30 and user-menu item 1 hold text outside the code page
        $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Tandem Commander\0.1\Hot Paths\30')
        $k.SetValue('Name', $TestText, 'String'); $k.SetValue('Path', $dirs['cjk'], 'String'); $k.SetValue('Visible', 1, 'DWord'); $k.Close()
        $um = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Tandem Commander\0.1\User Menu\1')
        if ($um) { $um.Close(); $script:SeededUM = $false }
        else {
            $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Tandem Commander\0.1\User Menu\1')
            $k.SetValue('Item Name', 'tc093', 'String'); $k.SetValue('Command', ($dirs['cjk'] + '\x.exe'), 'String')
            $k.SetValue('Arguments', $TestText, 'String'); $k.SetValue('Initial Directory', $dirs['cjk'], 'String')
            $k.SetValue('Execute Through Shell', 1, 'DWord'); $k.SetValue('Close Shell Window', 1, 'DWord'); $k.Close()
            # item 2: its arguments make the program ask for the two names to compare
            # (the "Show Names To Compare" confirmation is switched on for the run)
            $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Tandem Commander\0.1\User Menu\2')
            $k.SetValue('Item Name', 'tc093cmp', 'String'); $k.SetValue('Command', ($dirs['cjk'] + '\x.exe'), 'String')
            $k.SetValue('Arguments', '$(FileToCompareLeft) $(FileToCompareRight)', 'String'); $k.SetValue('Initial Directory', '', 'String')
            $k.SetValue('Execute Through Shell', 1, 'DWord'); $k.SetValue('Close Shell Window', 1, 'DWord'); $k.Close()
            & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Show Names To Compare' /t REG_DWORD /d 1 /f | Out-Null
            $script:SeededUM = $true
        }
        Out ("Seeded in the registry: Hot Paths\30 Name=<test text> Path=<cjk folder>; User Menu\1 (seeded={0}) Command=<cjk folder>\x.exe Arguments=<test text> Initial Directory=<cjk folder>" -f $script:SeededUM)
    }

    $first = $true
    foreach ($tag in @('cyr', 'cjk', 'emo')) {
        $dir = $dirs[$tag]
        $full = $first            # the first instance drives every surface; the others the path dialogs (another prefill)
        Out ''
        Out ("--- instance in the '{0}' folder ({1}); {2} ---" -f $tag, (Hex (Split-Path -Leaf $dir)), $(if ($full) { 'all surfaces, all channels' } else { 'Create Directory, Change Directory, Pack, Unpack, Find only' }))
        $id = 0
        try {
            $id = Start-Tc $dir
            Out ("   main window title: '{0}'" -f (Esc (Title $id)))
            if ($first) {
                $mods = @((Get-Process -Id $id).Modules | Where-Object { $_.ModuleName -ieq 'comctl32.dll' } | ForEach-Object { $_.FileName })
                Out ("Loaded comctl32.dll: {0}" -f ($mods -join ' ; '))
                $m = Get-Main $id
                Out ("Main window: IsWindowUnicode={0}" -f [Drv093]::IsWindowUnicode($m))
            }
            $S = "[$tag]"

            # (1) Create Directory - the control case (a Unicode dialog since feature 015).
            # Channel E also proves which folder the panel is in.
            if (Want 'createdir') {
                $sf = 'createdir' + $S
                try {
                    $dlg = Open-ByCmd $id 730
                    if ($dlg -eq [IntPtr]::Zero) { NotDriven $sf 'command 730 opened no window' }
                    else {
                        Out ("   {0}: window class={1} title='{2}'" -f $sf, [Drv093]::Cls($dlg), (Esc ([Drv093]::Txt($dlg))))
                        Measure-Ctl $sf $dlg 210 'IDE_PATH' $null 'exact' $full
                        $ctl = Find-Ctl $dlg 210
                        [void][Drv093]::SetText($ctl, $TestText, 5000)
                        $how = Click-Ok $dlg
                        $sw = [Diagnostics.Stopwatch]::StartNew()
                        while ($sw.Elapsed.TotalSeconds -lt 5 -and [Drv093]::IsWindow($dlg)) { Start-Sleep -Milliseconds 100 }
                        Start-Sleep -Milliseconds 700
                        $made = @([IO.Directory]::GetDirectories($dir) | ForEach-Object { [IO.Path]::GetFileName($_) })
                        $ok = ($made -ccontains $TestText)
                        Row $sf 'IDE_PATH id=210' 'E' '-' '-' (Hex $TestText) (($made | ForEach-Object { Hex $_ }) -join ' ; ') $(if ($ok) { 'PASS' } else { 'LOSSY' }) ("directories now in the panel's folder; OK by $how")
                        Clear-Wins $id $sf
                    }
                }
                catch { NotDriven $sf $_.Exception.Message; try { Clear-Wins $id $sf } catch { } }
            }

            # (2) Change Directory
            if (Want 'changedir') {
                Surface-Dialog $id ('changedir' + $S) 862 @((Ctl 210 'IDE_PATH' $dir 'exact')) $null
            }

            # (3) Pack, (4) Unpack: focus on the one file (End = last item)
            if (Want 'pack') {
                Surface-Dialog $id ('pack' + $S) 850 @((Ctl 210 'IDE_PATH' $TestText.Substring(1) 'contains')) { Key $id 0x23 }   # the suggested archive name comes from the file name
            }
            if (Want 'unpack') {
                Surface-Dialog $id ('unpack' + $S) 851 @((Ctl 210 'IDE_PATH' (Split-Path -Leaf $dir) 'list'), (Ctl 521 'IDE_MASK' $null 'exact')) { Key $id 0x23 }
            }

            # (6) Find Files: own thread, own message loop
            if (Want 'find') {
                Surface-Dialog $id ('find' + $S) 741 @((Ctl 2505 'IDC_FIND_NAMED' $null 'exact'), (Ctl 2501 'IDC_FIND_LOOKIN' $dir 'exact'), (Ctl 2504 'IDC_FIND_CONTAINING' $null 'exact')) $null
            }

            if ($full) {
                # (5) Select, panel filter
                if (Want 'select') { Surface-Dialog $id 'select' 841 @((Ctl 101 'IDE_FILEMASK' $null 'exact')) $null }
                if (Want 'filter') { Surface-Dialog $id 'filter' 779 @((Ctl 409 'IDE_FILTER' $null 'exact')) $null }

                # (7) Configuration
                if (Want 'config') {
                    $sf = 'config'
                    try {
                        $dlg = Open-ByCmd $id 686
                        if ($dlg -eq [IntPtr]::Zero) { NotDriven $sf 'command 686 opened no window' }
                        else {
                            $pages = @([Drv093]::Kids($dlg) | Where-Object { [Drv093]::Cls($_) -eq '#32770' -and [Drv093]::IsWindowVisible($_) })
                            $ptitle = ($pages | ForEach-Object { Esc ([Drv093]::Txt($_)) }) -join ' ; '
                            $tv = @([Drv093]::Kids($dlg) | Where-Object { [Drv093]::Cls($_) -eq 'SysTreeView32' }) | Select-Object -First 1
                            Out ("   config: holder class={0} title='{1}' unicode={2}; visible page(s): '{3}' unicode={4}; tree view unicode={5}" -f [Drv093]::Cls($dlg), (Esc ([Drv093]::Txt($dlg))), [Drv093]::IsWindowUnicode($dlg), $ptitle, (($pages | ForEach-Object { [Drv093]::IsWindowUnicode($_) }) -join ','), $(if ($tv) { [Drv093]::IsWindowUnicode($tv) } else { '-' }))
                            $edits = @([Drv093]::Kids($dlg) | Where-Object { [Drv093]::Cls($_) -eq 'Edit' -and [Drv093]::IsWindowVisible($_) -and [Drv093]::Cls([Drv093]::GetParent($_)) -eq '#32770' })
                            if (-not $edits.Count) { Row $sf '-' 'A' '-' '-' '-' '-' 'INFO' 'the first page has no visible edit field' }
                            foreach ($e in ($edits | Select-Object -First 2)) { Measure-Ctl $sf $dlg ([Drv093]::GetDlgCtrlID($e)) 'first-page edit' $null }
                            Close-Win $id $dlg; Start-Sleep -Milliseconds 300; Clear-Wins $id $sf
                        }
                    }
                    catch { NotDriven $sf $_.Exception.Message; try { Clear-Wins $id $sf } catch { } }
                }

                if (Want 'hotpaths') {
                    # the last row of the list (slot 30, seeded) is selected with the End key
                    Surface-Dialog $id 'hotpaths' 925 @((Ctl 373 'IDC_HOTPATH_PATH' $dirs['cjk'] 'exact'), (Ctl 376 'IDC_HOTPATH_NAME' $TestText 'exact')) $null {
                        param($dlg)
                        $lv = @([Drv093]::Kids($dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 371 }) | Select-Object -First 1
                        if ($lv) {
                            [void][Drv093]::Send($lv, 0x0100, 0x23, 1, 5000); [void][Drv093]::Send($lv, 0x0101, 0x23, 0xC0000001, 5000)
                            Out ("   hotpaths: list class={0} unicode={1}; page unicode={2}; End key sent to the list" -f [Drv093]::Cls($lv), [Drv093]::IsWindowUnicode($lv), [Drv093]::IsWindowUnicode([Drv093]::GetParent($lv)))
                        }
                        else { Out '   hotpaths: list id 371 not found' }
                        Start-Sleep -Milliseconds 400
                    }
                }
                if (Want 'usermenu') {
                    $pc = $null; $pa = $null; $pi = $null
                    if ($script:SeededUM) { $pc = $dirs['cjk'] + '\x.exe'; $pa = $TestText; $pi = $dirs['cjk'] }
                    Surface-Dialog $id 'usermenu' 926 @((Ctl 352 'IDE_COMMAND' $pc 'exact'), (Ctl 359 'IDE_ARGUMENTS' $pa 'exact'), (Ctl 357 'IDE_INITDIR' $pi 'exact')) $null {
                        param($dlg)
                        $lb = @([Drv093]::Kids($dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 351 }) | Select-Object -First 1
                        if ($lb) {
                            [void][Drv093]::Send($lb, 0x0100, 0x24, 1, 5000); [void][Drv093]::Send($lb, 0x0101, 0x24, 0xC0000001, 5000)
                            Out ("   usermenu: list class={0} unicode={1}; page unicode={2}; Home key sent to the list" -f [Drv093]::Cls($lb), [Drv093]::IsWindowUnicode($lb), [Drv093]::IsWindowUnicode([Drv093]::GetParent($lb)))
                        }
                        else { Out '   usermenu: list id 351 not found' }
                        Start-Sleep -Milliseconds 400
                    }
                }

                # ---- stage S1: five more modal dialogs (focus on the one file first) ----
                if (Want 'convert') { Surface-Dialog $id 'convert' 814 @((Ctl 101 'IDE_FILEMASK' $null 'exact')) { Key $id 0x23 } }
                if (Want 'filelist') { Surface-Dialog $id 'filelist' 811 @((Ctl 2382 'IDC_FL_LINE' $null 'exact'), (Ctl 2384 'IDC_FL_FILENAME' $null 'exact')) { Key $id 0x23 } }
                # the volume label: the field is only read and set here, the dialog is cancelled (the label is written on OK only)
                if (Want 'driveinfo') { Surface-Dialog $id 'driveinfo' 752 @((Ctl 552 'IDE_VOLNAME' $null 'exact')) $null }
                if (Want 'compareargs') {
                    # user-menu item 2 (seeded) asks for the two names; cancelled, so nothing is started
                    if (-not $script:SeededUM) { NotDriven 'compareargs' 'the user menu of this configuration is not empty - no item was seeded' }
                    else { Surface-Dialog $id 'compareargs' 3001 @((Ctl 2803 'IDE_UMC_NAME1' $null 'exact'), (Ctl 2804 'IDE_UMC_NAME2' $null 'exact')) { Key $id 0x23 } }
                }
                if (Want 'changeicon') {
                    $sf = 'changeicon'
                    try {
                        $cfg = Open-ByCmd $id 926
                        if ($cfg -eq [IntPtr]::Zero) { NotDriven $sf 'command 926 opened no window' }
                        else {
                            $lb = @([Drv093]::Kids($cfg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 351 }) | Select-Object -First 1
                            if (-not $lb) { NotDriven $sf 'list id 351 not found' }
                            else {
                                [void][Drv093]::Send($lb, 0x0100, 0x24, 1, 5000); [void][Drv093]::Send($lb, 0x0101, 0x24, 0xC0000001, 5000)
                                Start-Sleep -Milliseconds 300
                                $known = Get-Tops $id
                                Post-Cmd ([Drv093]::GetParent($lb)) 365             # IDB_UM_CHANGEICON
                                $dlg = Wait-NewWin $id $known 8
                                if ($dlg -ne [IntPtr]::Zero -and (Find-Ctl $dlg 661) -eq [IntPtr]::Zero) {
                                    # a message first (the seeded command names a file that does not exist): close it, the dialog follows
                                    Out ("   {0}: first window class={1} title='{2}': {3}" -f $sf, [Drv093]::Cls($dlg), (Esc ([Drv093]::Txt($dlg))), (Get-DialogText $dlg))
                                    $known = Get-Tops $id
                                    Close-Win $id $dlg
                                    $dlg = Wait-NewWin $id $known 8
                                }
                                if ($dlg -eq [IntPtr]::Zero) { NotDriven $sf 'IDB_UM_CHANGEICON opened no window' }
                                else {
                                    Out ("   {0}: window class={1} title='{2}'" -f $sf, [Drv093]::Cls($dlg), (Esc ([Drv093]::Txt($dlg))))
                                    Measure-Ctl $sf $dlg 661 'IDE_CHI_FILENAME' $null
                                    Close-Win $id $dlg
                                    Start-Sleep -Milliseconds 300
                                }
                            }
                            foreach ($h in @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -ne $MainClass -and $_ -ne $cfg })) { Close-Win $id $h }
                            Close-Win $id $cfg; Start-Sleep -Milliseconds 300; Clear-Wins $id $sf
                        }
                    }
                    catch { NotDriven $sf $_.Exception.Message; try { Clear-Wins $id $sf } catch { } }
                }

                # ---- stage S1: the in-place editor of an edit list box (the User Menu page's list) ----
                if (Want 'editlb') {
                    $sf = 'editlb'
                    try {
                        $cfg = Open-ByCmd $id 926
                        if ($cfg -eq [IntPtr]::Zero) { NotDriven $sf 'command 926 opened no window' }
                        else {
                            $lb = @([Drv093]::Kids($cfg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 351 }) | Select-Object -First 1
                            if (-not $lb) { NotDriven $sf 'list id 351 not found' }
                            else {
                                # (1) F2 on the first item
                                [void][Drv093]::Send($lb, 0x0100, 0x24, 1, 5000); [void][Drv093]::Send($lb, 0x0101, 0x24, 0xC0000001, 5000)
                                [void][Drv093]::Send($lb, 0x0100, 0x71, 1, 5000)
                                Start-Sleep -Milliseconds 400
                                $ed = @([Drv093]::Kids($lb) | Where-Object { [Drv093]::Cls($_) -eq 'Edit' }) | Select-Object -First 1
                                if (-not $ed) { NotDriven $sf 'F2 on the list created no Edit child' }
                                else {
                                    $pf = $null; if ($script:SeededUM) { $pf = 'tc093' }
                                    Measure-Ctl $sf $cfg 0 'in-place editor (F2)' $pf 'exact' $true $ed
                                    [void][Drv093]::Send($ed, 0x0100, 0x1B, 1, 5000)          # Esc: the change is discarded
                                    Start-Sleep -Milliseconds 300
                                }
                                # (2) a character typed into the list starts the editing with that character;
                                # the first unit goes to the list, the others to the editor it creates
                                $seq = (S 0x416, 0x61, 0x159, 0x65E5, 0xD83D, 0xDCC1)
                                [void][Drv093]::PostMessageW($lb, 0x0102, [IntPtr][int]$seq[0], [IntPtr]1)
                                $ed = $null
                                $sw = [Diagnostics.Stopwatch]::StartNew()
                                while ($sw.Elapsed.TotalSeconds -lt 3 -and -not $ed) {
                                    Start-Sleep -Milliseconds 100
                                    $ed = @([Drv093]::Kids($lb) | Where-Object { [Drv093]::Cls($_) -eq 'Edit' }) | Select-Object -First 1
                                }
                                if (-not $ed) { Row $sf 'in-place editor (typed)' 'D' '-' '-' (Hex $seq) '-' 'NOT DRIVEN' 'a character posted to the list created no Edit child' }
                                else {
                                    $d = Describe $cfg $ed
                                    foreach ($u in $seq.Substring(1).ToCharArray()) { [void][Drv093]::PostMessageW($ed, 0x0102, [IntPtr][int]$u, [IntPtr]1) }
                                    $act = Read-Settled $cfg $ed $seq.Length
                                    Row $sf 'in-place editor (typed)' 'D' $d[0] $d[1] (Hex $seq) (Hex $act) $(if ($act -ceq $seq) { 'PASS' } else { 'LOSSY' }) 'first unit posted to the list (starts the editing), the others to the editor'
                                    [void][Drv093]::Send($ed, 0x0100, 0x1B, 1, 5000)
                                    Start-Sleep -Milliseconds 300
                                }
                            }
                            Close-Win $id $cfg; Start-Sleep -Milliseconds 300; Clear-Wins $id $sf
                        }
                    }
                    catch { NotDriven $sf $_.Exception.Message; try { Clear-Wins $id $sf } catch { } }
                }

                # ---- stage S1: regression drive (verdicts PASS / FAIL) ----
                if (Want 'drive') {
                    $sf = 'drive'
                    try {
                        $dlg = Open-ByCmd $id 741
                        if ($dlg -eq [IntPtr]::Zero) { NotDriven $sf 'command 741 opened no window' }
                        else {
                            # (1) an ASCII mask typed into Named, Find Now, the number of found items
                            $named = Find-Ctl $dlg 2505; $in = Inner-Edit $named
                            [void][Drv093]::SetText($named, '', 5000)
                            foreach ($u in '*.zip'.ToCharArray()) { [void][Drv093]::PostMessageW($in, 0x0102, [IntPtr][int]$u, [IntPtr]1) }
                            $mask = Read-Settled $dlg $named 5
                            $look = [Drv093]::GetText((Find-Ctl $dlg 2501), 5000)
                            $lv = @([Drv093]::Kids($dlg) | Where-Object { [Drv093]::GetDlgCtrlID($_) -eq 2510 }) | Select-Object -First 1
                            $known = Get-Tops $id
                            Post-Cmd $dlg 1                                   # Find Now (BM_CLICK does nothing in a window that is not the active one)
                            $count = -1; $msg = ''
                            $sw = [Diagnostics.Stopwatch]::StartNew()
                            while ($sw.Elapsed.TotalSeconds -lt 8) {
                                Start-Sleep -Milliseconds 300
                                $extra = @(Get-Tops $id | Where-Object { $known -notcontains $_ })
                                if ($extra.Count) { foreach ($h in $extra) { $msg += (' window shown: ' + (Get-DialogText $h) + ';'); Close-Win $id $h }; break }
                                $res = [IntPtr]::Zero
                                if ($lv -and [Drv093]::SendMessageTimeoutW($lv, 0x1004, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res) -ne [IntPtr]::Zero) { $count = [int]$res.ToInt64() }
                                if ($count -ge 1 -and $sw.Elapsed.TotalSeconds -gt 1.5) { break }
                            }
                            Row $sf 'Find Now, mask *.zip' 'E' '-' '-' 'items=1' ("items={0}" -f $count) $(if ($count -eq 1) { 'PASS' } else { 'FAIL' }) ("Named held '{0}', Look in held {1};{2}" -f (Esc $mask), (Hex $look), $msg)
                            Start-Sleep -Milliseconds 500

                            # (2) the Find window's menu bar: Alt+F (WM_SYSCHAR) opens a menu, Esc closes it
                            $pop = { @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -eq 'PopupMenuClass' }) }
                            [void][Drv093]::PostMessageW($in, 0x0106, [IntPtr]0x66, [IntPtr]0x20000001)
                            Start-Sleep -Milliseconds 800
                            $m = & $pop
                            Row $sf 'Find menu by Alt+F' 'E' '-' '-' 'menu windows=1' ("menu windows={0}" -f $m.Count) $(if ($m.Count -eq 1) { 'PASS' } else { 'FAIL' }) 'WM_SYSCHAR 0066 posted to the Named field'
                            if ($m.Count) {
                                [void][Drv093]::PostMessageW($m[0], 0x0100, [IntPtr]0x1B, [IntPtr]1); [void][Drv093]::PostMessageW($m[0], 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001)
                                Start-Sleep -Milliseconds 600
                                $m2 = & $pop
                                Row $sf 'Find menu closed by Esc' 'E' '-' '-' 'menu windows=0' ("menu windows={0}" -f $m2.Count) $(if ($m2.Count -eq 0 -and [Drv093]::IsWindow($dlg)) { 'PASS' } else { 'FAIL' }) ("Find window still open: {0}" -f [Drv093]::IsWindow($dlg))
                                # the menu bar keeps its loop after the popup has closed: one more Esc leaves it
                                [void][Drv093]::PostMessageW($dlg, 0x0100, [IntPtr]0x1B, [IntPtr]1); [void][Drv093]::PostMessageW($dlg, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001)
                                Start-Sleep -Milliseconds 500
                            }
                            # (3) Alt + a letter that is no mnemonic of the menu (U+0159) opens nothing
                            if ([Drv093]::IsWindow($dlg)) {
                                $in = Inner-Edit (Find-Ctl $dlg 2505)
                                [void][Drv093]::PostMessageW($in, 0x0106, [IntPtr]0x159, [IntPtr]0x20000001)
                                Start-Sleep -Milliseconds 700
                                $m = & $pop
                                Row $sf 'Find menu by Alt+U+0159' 'E' '-' '-' 'menu windows=0' ("menu windows={0}" -f $m.Count) $(if ($m.Count -eq 0) { 'PASS' } else { 'FAIL' }) 'WM_SYSCHAR 0159: not a mnemonic of the English menu (its low byte is that of Y)'
                                foreach ($h in $m) { [void][Drv093]::PostMessageW($h, 0x0100, [IntPtr]0x1B, [IntPtr]1); Start-Sleep -Milliseconds 300 }
                            }
                            else { Row $sf 'Find menu by Alt+U+0159' 'E' '-' '-' '-' '-' 'NOT DRIVEN' 'the Find window closed on the second Esc' }
                            Close-Win $id $dlg; Start-Sleep -Milliseconds 500; Clear-Wins $id $sf $false
                        }
                        # (4) the main window's menu by Alt+F - handled only while the main window is the active one
                        # (the caption state is set by a sent WM_NCACTIVATE and taken back afterwards; no foreground change)
                        $mw = Get-Main $id
                        [void][Drv093]::Send($mw, 0x0086, 1, 0, 5000)
                        [void][Drv093]::PostMessageW($mw, 0x0106, [IntPtr]0x66, [IntPtr]0x20000001)
                        Start-Sleep -Milliseconds 800
                        $m = @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -eq 'PopupMenuClass' })
                        if ($m.Count -eq 1) {
                            Row $sf 'main menu by Alt+F' 'E' '-' '-' 'menu windows=1' 'menu windows=1' 'PASS' 'WM_SYSCHAR 0066 posted to the main window'
                            [void][Drv093]::PostMessageW($m[0], 0x0100, [IntPtr]0x1B, [IntPtr]1); [void][Drv093]::PostMessageW($m[0], 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001)
                            Start-Sleep -Milliseconds 500
                            [void][Drv093]::PostMessageW($mw, 0x0100, [IntPtr]0x1B, [IntPtr]1); [void][Drv093]::PostMessageW($mw, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001)
                            Start-Sleep -Milliseconds 500
                            $m = @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -eq 'PopupMenuClass' })
                            Row $sf 'main menu closed by Esc' 'E' '-' '-' 'menu windows=0' ("menu windows={0}" -f $m.Count) $(if ($m.Count -eq 0) { 'PASS' } else { 'FAIL' }) ''
                        }
                        else { Row $sf 'main menu by Alt+F' 'E' '-' '-' 'menu windows=1' ("menu windows={0}" -f $m.Count) 'NOT DRIVEN' 'no menu: the main window handles Alt+letter only while it is the active window' }
                        [void][Drv093]::Send($mw, 0x0086, 0, 0, 5000)
                        Sync $id
                    }
                    catch { NotDriven $sf $_.Exception.Message; try { Clear-Wins $id $sf $false } catch { } }
                }

                # (8) the command line: a ComboBox child of the main window, id 955
                if (Want 'cmdline') {
                    $sf = 'cmdline'
                    try {
                        $m = Get-Main $id
                        $cb = Find-Ctl $m 955
                        if ($cb -eq [IntPtr]::Zero) { Post-Cmd $m 745; Start-Sleep -Milliseconds 700; $cb = Find-Ctl $m 955 }   # CM_EDITLINE shows it
                        if ($cb -eq [IntPtr]::Zero) { NotDriven $sf 'no ComboBox id 955 under the main window' }
                        else { Measure-Ctl $sf $m 955 'IDC_EDITWINDOW' $null; [void][Drv093]::SetText($cb, '', 5000) }
                    }
                    catch { NotDriven $sf $_.Exception.Message }
                }

                # (9) label-only samples: About, and a message box (Change Directory to a path that does not exist)
                if (Want 'about') {
                    $sf = 'about'
                    try {
                        $dlg = Open-ByCmd $id 2216
                        if ($dlg -eq [IntPtr]::Zero) { NotDriven $sf 'command 2216 opened no window' }
                        else {
                            $st = @([Drv093]::Kids($dlg) | Where-Object { [Drv093]::Cls($_) -eq 'Static' }) | Select-Object -First 1
                            Row $sf 'dialog' 'A' ('{0}/{1}/-' -f [Drv093]::Cls($dlg), $(if ($st) { [Drv093]::Cls($st) } else { '-' })) ('dlg={0} ctl={1} inner=-' -f [Drv093]::IsWindowUnicode($dlg), $(if ($st) { [Drv093]::IsWindowUnicode($st) } else { '-' })) '-' '-' 'INFO' ("title '" + (Esc ([Drv093]::Txt($dlg))) + "'; ctl = first Static")
                            Close-Win $id $dlg; Start-Sleep -Milliseconds 300; Clear-Wins $id $sf
                        }
                    }
                    catch { NotDriven $sf $_.Exception.Message; try { Clear-Wins $id $sf } catch { } }
                }
                if (Want 'msgbox') {
                    $sf = 'msgbox'
                    try {
                        $dlg = Open-ByCmd $id 862
                        if ($dlg -eq [IntPtr]::Zero) { NotDriven $sf 'Change Directory did not open' }
                        else {
                            $ctl = Find-Ctl $dlg 210
                            [void][Drv093]::SetText($ctl, (Join-Path $root 'no_such_folder_093\x'), 5000)
                            $known = Get-Tops $id
                            [void](Click-Ok $dlg)
                            $box = Wait-NewWin $id $known 5
                            if ($box -eq [IntPtr]::Zero) { NotDriven $sf ('no message window appeared; title now: ' + (Esc (Title $id))) }
                            else {
                                $st = @([Drv093]::Kids($box) | Where-Object { [Drv093]::Cls($_) -eq 'Static' }) | Select-Object -First 1
                                $bt = @([Drv093]::Kids($box) | Where-Object { [Drv093]::Cls($_) -eq 'Button' }) | Select-Object -First 1
                                Row $sf 'dialog' 'A' ('{0}/{1}/{2}' -f [Drv093]::Cls($box), $(if ($st) { [Drv093]::Cls($st) } else { '-' }), $(if ($bt) { [Drv093]::Cls($bt) } else { '-' })) ('dlg={0} ctl={1} inner={2}' -f [Drv093]::IsWindowUnicode($box), $(if ($st) { [Drv093]::IsWindowUnicode($st) } else { '-' }), $(if ($bt) { [Drv093]::IsWindowUnicode($bt) } else { '-' })) '-' '-' 'INFO' ("ctl = first Static, inner = first Button; text: " + (Get-DialogText $box))
                                Close-Win $id $box
                            }
                            Start-Sleep -Milliseconds 500
                            Clear-Wins $id $sf $false
                        }
                    }
                    catch { NotDriven $sf $_.Exception.Message; try { Clear-Wins $id $sf $false } catch { } }
                }

                # (2) E: Change Directory to the CJK folder, then a marker directory shows where the panel is
                if (Want 'changedir') {
                    $sf = 'changedir[E]'
                    try {
                        $dlg = Open-ByCmd $id 862
                        if ($dlg -eq [IntPtr]::Zero) { NotDriven $sf 'command 862 opened no window' }
                        else {
                            $ctl = Find-Ctl $dlg 210
                            $target = $dirs['cjk']
                            [void][Drv093]::SetText($ctl, $target, 5000)
                            $held = [Drv093]::GetText($ctl, 5000)
                            $known = Get-Tops $id
                            $how = Click-Ok $dlg
                            $sw = [Diagnostics.Stopwatch]::StartNew()
                            while ($sw.Elapsed.TotalSeconds -lt 4 -and [Drv093]::IsWindow($dlg) -and -not @(Get-Tops $id | Where-Object { $known -notcontains $_ }).Count) { Start-Sleep -Milliseconds 100 }
                            Start-Sleep -Milliseconds 800
                            $msg = ''
                            foreach ($h in @(Get-Tops $id | Where-Object { [Drv093]::Cls($_) -ne $MainClass })) {
                                if ($h -ne $dlg) { $msg += (" message shown: [dlg unicode={0}] {1};" -f [Drv093]::IsWindowUnicode($h), (Get-DialogText $h)) }
                            }
                            Clear-Wins $id $sf $false
                            Sync $id
                            $title = Title $id
                            [void](Do-CreateDir $id 'marker_093')
                            Clear-Wins $id $sf $false
                            $where = @($dirs.GetEnumerator() | Where-Object { [IO.Directory]::Exists((Join-Path $_.Value 'marker_093')) } | ForEach-Object { $_.Key })
                            $ok = ($where.Count -eq 1 -and $where[0] -eq 'cjk')
                            Row $sf 'IDE_PATH id=210' 'E' '-' '-' (Hex $target) (Hex $held) $(if ($ok) { 'PASS' } else { 'LOSSY' }) ("act = what the field held before OK; OK by $how; marker directory created by F7 afterwards landed in: [{0}]; main title: '{1}';{2}" -f ($where -join ','), (Esc $title), $msg)
                        }
                    }
                    catch { NotDriven $sf $_.Exception.Message; try { Clear-Wins $id $sf $false } catch { } }
                }
            }
        }
        catch { Out ("   instance '{0}': {1}" -f $tag, $_.Exception.Message) }
        finally { if ($id) { Stop-Tc $id } }
        $first = $false
    }
}
finally {
    foreach ($s in @($Started)) { try { Stop-Tc $s } catch { Out "  (stop $s : $($_.Exception.Message))" } }
    $left = @($Started | Where-Object { Test-Alive $_ }).Count
    for ($k = 0; $k -lt 10 -and [IO.Directory]::Exists($root); $k++) {
        try { [IO.Directory]::Delete($root, $true) } catch { Start-Sleep -Milliseconds 500 }
    }
    $regOk = Restore-TcRegistry $backup $existed
    Out ''
    Out ("Rows: PASS {0}, LOSSY {1}, NOT DRIVEN {2}, FAIL {3}; unexpected windows: {4}" -f $script:Pass, $script:Lossy, $script:NotDriven, $script:Fail, $script:Unexpected.Count)
    Out ("Test processes left: {0}; fixture folder left: {1}; registry restored identical: {2}; process exit codes: {3}" -f $left, [IO.Directory]::Exists($root), $regOk, ($script:ExitCodes -join ','))
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines.ToArray([string]), (New-Object Text.UTF8Encoding($false))) }
}
if ($regOk) { exit 0 } else { exit 1 }
