<#
.SYNOPSIS
    Feature 134: texts of the FTP client that hold a name - messages, the Copy dialog, the
    operation window, the log - read in the program against the probe's own FTP server.

.DESCRIPTION
    Runs on the hidden desktop (tools\run_on_hidden_desktop.ps1). Starts ftp134_server.py on
    127.0.0.1 (Python needed), drives the plug-in by a typed address (anonymous login) and reads
    what the windows hold. Every row is its own start of the program.

    Rows:
      MKDU8 / MKDCP / MKDASCII  Create Directory refused with "550 <name>: File exists." - the
                                name in the reply as UTF-8, in code page 1250, or no name
      CWDERR    Change Directory to a directory that does not exist
      COPY      F5 on a file with an accented name: the Copy dialog's subject, then the
                operation window's title and the cells of its two lists (a slow file)
      DELETE    F8 on a file with an accented name: the question, then the server's refusal
      LOG       the Logs window after entering a directory with an accented name
    Rows of feature 136 (texts 134 changed and did not run):
      BMK       Connect to FTP Server: a bookmark with an accented name - the check box of New,
                the label of Rename, the question of Remove
      PWD       an accented user name and no password: the prompt's "Connecting to ... as ..."
      LOGINU8 / LOGINCP  a refused password: the server's words (UTF-8 / code page 1250) in
                the login error dialog
      SAVELOG   the list of logs; Save log through the file dialog - the file read back
    A text passes when it holds every expected piece exactly and no mojibake letter.
    -Lang czech|english|...; -Expect fixed: FAIL rows count; -Expect before: recorded, the
    verdict column still says what a reader would see (FAIL = garbled).
    The server's log of received bytes is copied to -ServerLog (compared before / after).
    The product's registry key is exported, restored and compared. Exit code = FAIL rows
    (0 with -Expect before).

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string]$ServerLog,
    [string[]]$Only,
    [string]$Lang = 'czech',
    [int]$Port = 2134
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\127-mixed-template-texts\probe\lvtext_lib.ps1')

if (-not ('Drv134' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv134
{
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int InternalGetWindowText(IntPtr h, StringBuilder s, int n);
    public static string Title(IntPtr h) { var s = new StringBuilder(8000); InternalGetWindowText(h, s, 8000); return s.ToString(); }
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendGetBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 15000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    // the text of a combo box item, wide (CB_GETLBTEXTLEN / CB_GETLBTEXT)
    public static string ComboText(IntPtr combo, int index)
    {
        long len = SendR(combo, 0x0149, index, 0);
        if (len < 0) return null;
        var buf = new char[len + 2]; IntPtr r;
        SendGetBuf(combo, 0x0148, (IntPtr)index, buf, 0, 5000, out r);
        long n = r.ToInt64(); if (n < 0) return null; if (n > len) n = len;
        return new string(buf, 0, (int)n);
    }
    public static string ModKey(IntPtr target, int vk, int mods)
    {
        uint pid; uint tid = GetWindowThreadProcessId(target, out pid);
        uint me = GetCurrentThreadId();
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed " + Marshal.GetLastWin32Error();
        var saved = new byte[256]; GetKeyboardState(saved);
        try
        {
            var k = (byte[])saved.Clone();
            if ((mods & 2) != 0) { k[0x10] = k[0xA0] = 0x80; }
            if ((mods & 1) != 0) { k[0x11] = k[0xA2] = 0x80; }
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

$Root = $TempRoot + '\tc134'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# the server's names (pure ASCII source): "Zlutoucky kun", "prilis zlutoucky.txt", "slow zlutoucky kun.bin"
$Zl = [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD
$Kun = 'k' + (Chars @(0x016F, 0x0148))
$AccDir = [char]0x017D + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD + ' ' + $Kun
$AccFile = 'p' + (Chars @(0x0159, 0x00ED)) + 'li' + [char]0x0161 + ' ' + $Zl + '.txt'
$SlowFile = 'slow ' + $Zl + ' ' + $Kun + '.bin'
$NewDir = 'Nov' + [char]0x00FD + ' adres' + (Chars @(0x00E1, 0x0159))     # "Novy adresar"
$Addr = 'ftp://127.0.0.1:' + $Port
$Server = $null

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
function Start-P {
    $a = @('-t', 'T134', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Garbled([string]$t) { return [bool]($t -match ('[' + (Chars @(0x0102, 0x0139, 0x00C4, 0x00C3, 0x00C5, 0x00E2, 0x20AC, 0xFFFD, 0x013E, 0x0165)) + '][' + (Chars @(0x0102, 0x00BE, 0x00A5, 0x00A1, 0x00AF, 0x2122, 0x0099, 0x017D, 0x017E, 0x2030, 0x2021, 0x00AD, 0x00BD, 0x00A7, 0x0164, 0x02C7, 0x00B8, 0x2039)) + ']|' + [char]0xFFFD)) }
# the verdict of one text: holds every piece exactly, no mojibake pair
function Judge([string]$Case, [string]$Step, [string]$Text, [string[]]$Pieces, [string]$What) {
    $t = ('' + $Text).Replace("`r", '')
    $missing = @($Pieces | Where-Object { -not $t.Contains($_) })
    $ok = ($missing.Count -eq 0) -and -not (Garbled $t) -and $t.Length -gt 0
    $shown = Esc $t; if ($shown.Length -gt 700) { $shown = $shown.Substring(0, 700) + '...' }
    Row $Case $Step (V $ok) ("{0}: '{1}'; pieces missing: {2}; mojibake: {3}" -f $What, $shown, $(if ($missing.Count) { ($missing | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', ' } else { 'none' }), (Garbled $t))
}
function Dialogs([int]$Id) { return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) -and [Drv098f]::IsWindowVisible($_) }) }
function StaticText([IntPtr]$Dlg) {   # all static texts of a dialog, as the controls hold them
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Static' -and [Drv098f]::IsWindowVisible($_) } | ForEach-Object { [Drv098f]::GetText($_, 5000) } | Where-Object { $_ }) -join ' | ')
}
function BtnById([IntPtr]$Dlg, [int[]]$Ids) { foreach ($w in $Ids) { $b = Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($b) { return $b } }; return $null }
# waits for a new dialog (not in $Known) with buttons other than a lone Cancel
function Wait-Dlg([int]$Id, $Known, [double]$Seconds = 25) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        foreach ($h in (Dialogs $Id)) {
            if ($Known -contains $h) { continue }
            $ids = @(Buttons $h | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if ($ids.Count -eq 0 -or ($ids.Count -eq 1 -and $ids[0] -eq 2)) { continue }
            Start-Sleep -Milliseconds 700
            return $h
        }
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}
function Drain([int]$Id, [double]$Seconds = 5, [int[]]$Ids = @(2, 7, 1)) {   # closes whatever dialogs follow (default: Cancel, No, OK)
    $seen = @(); $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $h = Dialogs $Id | Select-Object -First 1
        if (-not $h) { Start-Sleep -Milliseconds 300; continue }
        $seen += (Tail (WinDesc $h) 160)
        $b = BtnById $h $Ids
        if ($b) { Click $b } else { Close-Win $h }
        Start-Sleep -Milliseconds 600
    }
    return $seen
}
# the server's welcome message: a window with one button (id 1) and a text control
function Close-Welcome([int]$Id) {
    Start-Sleep -Milliseconds 800
    foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowVisible($_) })) {
        $ids = @(Buttons $h | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
        if ($ids.Count -eq 1 -and $ids[0] -eq 1 -and @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2477 }).Count -eq 0) { Click (Buttons $h)[0]; Start-Sleep -Milliseconds 500 }
    }
}
function Connect([int]$Id, [string]$RemoteDir) {
    $known = Dialogs $Id
    [void](Do-ChangeDir $Id ($Addr + $RemoteDir))
    $sw = [Diagnostics.Stopwatch]::StartNew(); $loc = ''
    while ($sw.Elapsed.TotalSeconds -lt 30) {
        Start-Sleep -Milliseconds 700
        if (@(Dialogs $Id | Where-Object { $known -notcontains $_ }).Count) { break }   # an error box
        Sync $Id
        $loc = Get-Loc $Id
        if ($loc -like 'ftp:*') { break }
    }
    Close-Welcome $Id
    return $loc
}
function Set-PluginHotKey([string]$DllRx, [int]$MenuId, [int]$HotKey) {
    $plugins = 'HKCU:\Software\Tandem Commander\0.1\Plugins'
    if (-not (Test-Path $plugins)) { return 'no Plugins key' }
    foreach ($k in @(Get-ChildItem $plugins)) {
        $dll = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DLL
        if (-not $dll -or $dll -notmatch $DllRx) { continue }
        $menu = Join-Path $k.PSPath 'Menu'
        if (-not (Test-Path $menu)) { return "plug-in $($k.PSChildName): no Menu key" }
        foreach ($mi in @(Get-ChildItem $menu)) {
            $idv = (Get-ItemProperty $mi.PSPath -ErrorAction SilentlyContinue).ID
            if ($idv -eq $MenuId) { Set-ItemProperty -LiteralPath $mi.PSPath -Name 'HotKey' -Value $HotKey -Type DWord; return "plug-in $($k.PSChildName) ($dll): item $MenuId set" }
        }
        return "plug-in $($k.PSChildName) ($dll): no menu item with ID $MenuId"
    }
    return "no plug-in matching $DllRx is registered"
}

# ends the operation of an operation window so that nothing is left in the queue: Skip the
# waiting item (773), Stop the connection (766), close the window, Yes to "cancel?"
function End-Operation([int]$Id, [IntPtr]$Op) {
    foreach ($bid in @(773, 766)) {
        $b = @([Drv098f]::Kids($Op) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $bid -and [Drv098f]::IsWindowEnabled($_) }) | Select-Object -First 1
        if ($b) { Click $b; Start-Sleep -Milliseconds 900 }
    }
    [void](Drain $Id 3 @(6, 1, 2))
    if ([Drv098f]::IsWindow($Op)) { [void][Drv098f]::PostMessageW($Op, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    Start-Sleep -Milliseconds 800
    [void](Drain $Id 4 @(6, 1, 2))
}

# the refused delete stays in the queue as an item with an error; at exit the plug-in asks
# "the queue still holds unfinished operations - cancel them?" (answered Yes by End-Row). That
# one question is expected for the DELETE row and is not a stray window.
function Allow-QueueQuestion {
    $last = $script:Rows[$script:Rows.Count - 1]
    $line = '' + $script:Lines[$script:Lines.Count - 1]
    if ($last.Verdict -eq 'FAIL' -and $line -match 'exit 0x00000000' -and $line -match 'stray 1 \(at exit: \[#32770 ''FTP [^'']*''\] \[Static id=2477\]' -and $line -match 'new reports 0') {
        $last.Verdict = 'PASS'
        $script:Lines[$script:Lines.Count - 1] = $line.Replace(' FAIL ', ' PASS ') + ' [the queue question at exit is expected here]'
    }
}

# MKD rows: Create Directory with an accented name in a directory whose refusals have a set encoding
function Row-Mkd([string]$Case, [string]$Dir, [bool]$NameInReply) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P
        $loc = Connect $id ('/' + $Dir + '/')
        $known = Dialogs $id
        Post-Cmd (Get-Main $id) 730
        $dlg = Wait-Dlg $id $known 15
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'TEXT' 'NOT DRIVEN' ('no Create Directory dialog; panel at ' + (Tail $loc 60)); return }
        $edit = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
        [void][Drv098f]::SetText($edit, $NewDir, 5000)
        Click-Ok $dlg
        $box = Wait-Dlg $id ($known + $dlg) 25
        if ($box -eq [IntPtr]::Zero) { Row $Case 'TEXT' 'FAIL' ('no message after the refused MKD; panel at ' + (Tail $loc 60)); return }
        $pieces = @($NewDir); if ($NameInReply) { $pieces += ($NewDir + ': File exists.') } else { $pieces += 'Requested action not taken.' }
        Judge $Case 'TEXT' (StaticText $box) $pieces ("message for a refused Create Directory (caption '{0}')" -f (Esc ([Drv098f]::Txt($box))))
        [void](Drain $id 4)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

function Row-CwdErr {
    if (-not (Want 'CWDERR')) { return }
    $before = Reports; $id = 0
    $missing = 'Neexistuj' + [char]0x00ED + 'c' + [char]0x00ED     # "Neexistujici"
    try {
        $id = Start-P
        [void](Connect $id '/plain/')
        $known = Dialogs $id
        [void](Do-ChangeDir $id ($Addr + '/' + $missing + '/'))
        $box = Wait-Dlg $id $known 25
        if ($box -eq [IntPtr]::Zero) { Row 'CWDERR' 'TEXT' 'NOT DRIVEN' ('no message; panel at ' + (Tail (Get-Loc $id) 60)); return }
        Judge 'CWDERR' 'TEXT' (StaticText $box) @($missing) ("message for a directory that does not exist (caption '{0}')" -f (Esc ([Drv098f]::Txt($box))))
        [void](Drain $id 4)
    }
    catch { Row 'CWDERR' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row 'CWDERR' $id $fatal $before } }
}

# COPY: the Copy dialog, then the operation window while the slow file is transferred
function Row-Copy {
    if (-not (Want 'COPY')) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P
        $loc = Connect $id ('/' + $AccDir + '/')
        Key $id 0x24; Key $id 0x28                       # "..", then the first file: "slow ..."
        $known = Dialogs $id
        $knownTops = Get-Tops $id
        Post-Cmd (Get-Main $id) 727
        $dlg = Wait-Dlg $id $known 15
        if ($dlg -eq [IntPtr]::Zero) { Row 'COPY' 'DIALOG' 'NOT DRIVEN' ('no Copy dialog; panel at ' + (Tail $loc 60)); return }
        Judge 'COPY' 'DIALOG' (StaticText $dlg) @($SlowFile) ("subject of the Copy dialog (caption '{0}')" -f (Esc ([Drv098f]::Txt($dlg))))
        Click-Ok $dlg
        # the operation window: a new top-level window with list views
        $op = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 20 -and $op -eq [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 400
            foreach ($h in @(Get-Tops $id | Where-Object { $knownTops -notcontains $_ -and $_ -ne $dlg })) {
                if (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' }).Count) { $op = $h; break }
            }
        }
        if ($op -eq [IntPtr]::Zero) { Row 'COPY' 'WINDOW' 'NOT DRIVEN' ('no operation window; windows: ' + ((@(Get-Tops $id | Where-Object { $knownTops -notcontains $_ }) | ForEach-Object { Tail (WinDesc $_) 120 }) -join ' || ')); return }
        Start-Sleep -Milliseconds 3500
        Judge 'COPY' 'TITLE' ([Drv134]::Title($op)) @($SlowFile) 'title of the operation window'
        $n = 0
        foreach ($lv in @([Drv098f]::Kids($op) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' })) {
            $n++
            $cells = @()
            $cnt = [LvText127]::Count($lv)
            for ($i = 0; $i -lt [Math]::Min($cnt, 3); $i++) { for ($c = 0; $c -lt 6; $c++) { $t = [LvText127]::Cell($lv, $i, $c); if ($t) { $cells += $t } } }
            $withName = @($cells | Where-Object { $_.Contains($Zl) -or (Garbled $_) })
            if (-not $cells.Count) { Row 'COPY' ('LIST' + $n) 'NOT DRIVEN' ('the list has no text (' + $cnt + ' items)'); continue }
            Judge 'COPY' ('LIST' + $n) ($cells -join ' | ') $(if ($withName.Count) { @($Zl) } else { @() }) ("cells of list {0} of the operation window ({1} items)" -f $n, $cnt)
        }
        End-Operation $id $op
    }
    catch { Row 'COPY' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row 'COPY' $id $fatal $before } }
}

function Row-Delete {
    if (-not (Want 'DELETE')) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P
        $loc = Connect $id '/'
        Key $id 0x23; Key $id 0x26                       # End, Up: the file with the accented name
        $known = Dialogs $id
        Post-Cmd (Get-Main $id) 729
        $dlg = Wait-Dlg $id $known 15
        if ($dlg -eq [IntPtr]::Zero) { Row 'DELETE' 'QUESTION' 'NOT DRIVEN' ('no question; panel at ' + (Tail $loc 60)); return }
        $q = StaticText $dlg
        $name = $(if ($q.Contains('readme.txt')) { 'readme.txt' } else { $AccFile })
        Judge 'DELETE' 'QUESTION' $q @($name) ("the Delete question (caption '{0}')" -f (Esc ([Drv098f]::Txt($dlg))))
        $b = BtnById $dlg @(1, 6); if ($b) { Click $b } else { Close-Win $dlg }
        Start-Sleep -Milliseconds 4000
        $texts = @()
        foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::IsWindowVisible($_) -and $_ -ne (Get-Main $id) })) {
            $t = (StaticText $h); if ($t) { $texts += $t }
            foreach ($lv in @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' })) {
                $cnt = [LvText127]::Count($lv)
                for ($i = 0; $i -lt [Math]::Min($cnt, 3); $i++) { for ($c = 0; $c -lt 6; $c++) { $x = [LvText127]::Cell($lv, $i, $c); if ($x) { $texts += $x } } }
            }
        }
        Judge 'DELETE' 'AFTER' ($texts -join ' | ') @() 'texts of the windows after the refused delete (operation window or error dialog)'
        foreach ($h in @(Get-Tops $id | Where-Object { $_ -ne (Get-Main $id) -and @([Drv098f]::Kids($_) | Where-Object { [Drv098f]::Cls($_) -eq 'SysListView32' }).Count })) { End-Operation $id $h }
    }
    catch { Row 'DELETE' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row 'DELETE' $id $fatal $before; Allow-QueueQuestion } }
}

# ---- feature 136 ------------------------------------------------------------------------
function Ctl([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function CtlText([IntPtr]$Dlg, [int]$CtlId) { $c = Ctl $Dlg $CtlId; if ($c) { return [Drv098f]::GetText($c, 8000) }; return $null }
$BmkName = [char]0x017D + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD + ' ' + $Kun     # "Zlutoucky kun"
$UserName = 'ji' + (Chars @(0x0159, 0x00ED))                                                             # "jiri"
$Refused = 'P' + [char]0x0159 + 'ihl' + [char]0x00E1 + [char]0x0161 + 'en' + [char]0x00ED + ' odm' + [char]0x00ED + 'tnuto: ' + [char]0x0161 + 'patn' + [char]0x00E9 + ' heslo.'

# BMK: the Connect dialog (hot key on the plug-in's first menu command), no server involved
function Row-Bmk {
    if (-not (Want 'BMK')) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P
        $known = Dialogs $id
        $k = [Drv134]::ModKey((Get-LeftList $id), 0x4B, 3)          # Ctrl+Shift+K = Connect to FTP Server
        $dlg = Wait-Dlg $id $known 15
        if ($dlg -eq [IntPtr]::Zero -or -not (Ctl $dlg 561)) { Row 'BMK' 'DIALOG' 'NOT DRIVEN' ("no Connect dialog after the hot key ({0}; key {1})" -f $script:ConnKeyNote, $k); return }
        # New: the first bookmark
        Click (Ctl $dlg 572)
        $new = Wait-Dlg $id ($known + $dlg) 10
        if ($new -eq [IntPtr]::Zero -or -not (Ctl $new 602)) { Row 'BMK' 'NEW' 'NOT DRIVEN' 'the New dialog did not open'; return }
        [void][Drv098f]::SetText((Ctl $new 602), $BmkName, 5000)
        Click-Ok $new
        Start-Sleep -Milliseconds 900
        # New again: the check box names the focused bookmark
        Click (Ctl $dlg 572)
        $new = Wait-Dlg $id ($known + $dlg) 10
        if ($new -eq [IntPtr]::Zero) { Row 'BMK' 'NEWCHK' 'NOT DRIVEN' 'the second New dialog did not open' }
        else { Judge 'BMK' 'NEWCHK' (CtlText $new 611) @($BmkName) 'check box of the New dialog'; Close-Win $new; Start-Sleep -Milliseconds 600 }
        # Rename: the label
        Click (Ctl $dlg 573)
        $ren = Wait-Dlg $id ($known + $dlg) 10
        if ($ren -eq [IntPtr]::Zero) { Row 'BMK' 'RENAME' 'NOT DRIVEN' 'the Rename dialog did not open' }
        else { Judge 'BMK' 'RENAME' (CtlText $ren 601) @($BmkName) 'label of the Rename dialog'; Close-Win $ren; Start-Sleep -Milliseconds 600 }
        # Remove: the question, answered No
        Click (Ctl $dlg 574)
        $box = Wait-Dlg $id ($known + $dlg) 10
        if ($box -eq [IntPtr]::Zero) { Row 'BMK' 'REMOVE' 'NOT DRIVEN' 'no question after Remove' }
        else { Judge 'BMK' 'REMOVE' (StaticText $box) @($BmkName) 'question of Remove'; $b = BtnById $box @(7, 2); if ($b) { Click $b } else { Close-Win $box }; Start-Sleep -Milliseconds 600 }
        $c = Ctl $dlg 575; if ($c) { Click $c } else { Close-Win $dlg }
        Start-Sleep -Milliseconds 800
        [void](Drain $id 3)
    }
    catch { Row 'BMK' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row 'BMK' $id $fatal $before } }
}

# PWD / LOGIN: an address with a user name; the first dialog that holds control $CtlId
function Row-Login([string]$Case, [string]$UserPart, [int]$CtlId, [string[]]$Pieces, [string]$What) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P
        $known = Dialogs $id
        [void](Do-ChangeDir $id ('ftp://' + $UserPart + '@127.0.0.1:' + $Port + '/'))
        $found = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew(); $seen = @()
        while ($sw.Elapsed.TotalSeconds -lt 40 -and $found -eq [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 400
            foreach ($h in @(Dialogs $id | Where-Object { $known -notcontains $_ })) {
                if (Ctl $h $CtlId) { $found = $h; break }
                $d = Tail (WinDesc $h) 120; if ($seen -notcontains $d) { $seen += $d }
            }
        }
        if ($found -eq [IntPtr]::Zero) { Row $Case 'TEXT' 'NOT DRIVEN' ("no dialog with control {0} in 40 s; seen: {1}" -f $CtlId, ($seen -join ' || ')); [void](Drain $id 4); return }
        Start-Sleep -Milliseconds 600
        Judge $Case 'TEXT' (CtlText $found $CtlId) $Pieces ("{0} (dialog '{1}')" -f $What, (Esc ([Drv098f]::Txt($found))))
        $b = BtnById $found @(2); if ($b) { Click $b } else { Close-Win $found }
        Start-Sleep -Milliseconds 800
        [void](Drain $id 5)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

# SAVELOG: the list of logs, Save log through the file dialog, the file read back
function Row-SaveLog {
    if (-not (Want 'SAVELOG')) { return }
    $before = Reports; $id = 0
    $target = $Root + '\saved log.txt'
    try {
        $id = Start-P
        $loc = Connect $id ('/' + $AccDir + '/')
        $knownTops = Get-Tops $id
        $k = [Drv134]::ModKey((Get-LeftList $id), 0x4A, 3)          # Ctrl+Shift+J = Show Logs
        $w = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $w -eq [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 400
            $w = @(Get-Tops $id | Where-Object { $knownTops -notcontains $_ -and [Drv098f]::IsWindowVisible($_) -and (Ctl $_ 661) }) | Select-Object -First 1
            if (-not $w) { $w = [IntPtr]::Zero }
        }
        if ($w -eq [IntPtr]::Zero) { Row 'SAVELOG' 'LIST' 'NOT DRIVEN' ("no Logs window (key {0}); panel at {1}" -f $k, (Tail $loc 60)); return }
        Start-Sleep -Milliseconds 1200
        $combo = Ctl $w 661
        $sel = [Drv134]::SendR($combo, 0x0147, 0, 0)
        $item = [Drv134]::ComboText($combo, [int][Math]::Max(0, $sel))
        Judge 'SAVELOG' 'LIST' $item @('127.0.0.1') 'item of the list of logs'
        $known = Dialogs $id
        Post-Cmd $w 1207                                             # Save log
        $fd = Wait-Dlg $id ($known + $w) 15
        if ($fd -eq [IntPtr]::Zero) { Row 'SAVELOG' 'FILE' 'NOT DRIVEN' 'no file dialog after Save log - person step: Save log, the file starts with EF BB BF'; return }
        $edit = @([Drv098f]::Kids($fd) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
        if (-not $edit) { Row 'SAVELOG' 'FILE' 'NOT DRIVEN' ('the file dialog has no name field: ' + (Tail (WinDesc $fd) 200)); Close-Win $fd; return }
        [void][Drv098f]::SetText($edit, $target, 5000)
        Start-Sleep -Milliseconds 400
        $b = BtnById $fd @(1); if ($b) { Click $b }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 10 -and -not [IO.File]::Exists($LP + $target)) { Start-Sleep -Milliseconds 300 }
        if (-not [IO.File]::Exists($LP + $target)) { Row 'SAVELOG' 'FILE' 'NOT DRIVEN' ('the file was not written; windows: ' + ((Dialogs $id | ForEach-Object { Tail (WinDesc $_) 120 }) -join ' || ')); [void](Drain $id 4); return }
        Start-Sleep -Milliseconds 500
        $bytes = [IO.File]::ReadAllBytes($LP + $target)
        $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $valid = $true; $text = ''
        try { $text = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes) } catch { $valid = $false; $text = [Text.Encoding]::GetEncoding(1250).GetString($bytes) }
        $ok = $bom -and $valid -and $text.Contains($AccDir) -and -not (Garbled $text)
        $tail = $text; if ($tail.Length -gt 260) { $tail = $tail.Substring($tail.Length - 260) }
        Row 'SAVELOG' 'FILE' (V $ok) ("the saved log: {0} bytes; starts with the UTF-8 mark {1}; valid UTF-8 {2}; holds the directory name {3}; mojibake {4}; end: '{5}'" -f $bytes.Length, $bom, $valid, $text.Contains($AccDir), (Garbled $text), (Esc $tail))
        [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 800
        [void](Drain $id 3)
    }
    catch { Row 'SAVELOG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row 'SAVELOG' $id $fatal $before } }
}

# LOG: enter the accented directory, open the Logs window (hot key), read its text
function Row-Log {
    if (-not (Want 'LOG')) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P
        $loc = Connect $id ('/' + $AccDir + '/')
        $knownTops = Get-Tops $id
        $k = [Drv134]::ModKey((Get-LeftList $id), 0x4A, 3)          # Ctrl+Shift+J = Show Logs
        $w = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $w -eq [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 400
            $w = @(Get-Tops $id | Where-Object { $knownTops -notcontains $_ -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
            if (-not $w) { $w = [IntPtr]::Zero }
        }
        if ($w -eq [IntPtr]::Zero) { Row 'LOG' 'TEXT' 'NOT DRIVEN' ("no Logs window after the hot key ({0}; key {1}); panel at {2}" -f $script:KeyNote, $k, (Tail $loc 60)); return }
        Start-Sleep -Milliseconds 1500
        $text = ''
        foreach ($e in @([Drv098f]::Kids($w) | Where-Object { @('Edit', 'RichEdit20W', 'RichEdit20A', 'RICHEDIT50W') -contains [Drv098f]::Cls($_) })) { $t = [Drv098f]::GetText($e, 60000); if ($t.Length -gt $text.Length) { $text = $t } }
        $combo = @([Drv098f]::Kids($w) | Where-Object { [Drv098f]::Cls($_) -eq 'ComboBox' }) | Select-Object -First 1
        $kids = (@([Drv098f]::Kids($w) | ForEach-Object { [Drv098f]::Cls($_) }) | Group-Object | ForEach-Object { $_.Name + 'x' + $_.Count }) -join ', '
        if (-not $text) { Row 'LOG' 'TEXT' 'NOT DRIVEN' ("the Logs window (class {0}, title '{1}') has no text control with text; children: {2}" -f [Drv098f]::Cls($w), (Esc ([Drv134]::Title($w))), $kids); return }
        $tail = $text; if ($tail.Length -gt 1500) { $tail = $tail.Substring($tail.Length - 1500) }
        Judge 'LOG' 'TEXT' $tail @($AccDir) ("the log (last {0} of {1} characters)" -f $tail.Length, $text.Length)
        [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 800
    }
    catch { Row 'LOG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row 'LOG' $id $fatal $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc134_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
$srvLog = Join-Path $env:TEMP 'tc134_server.log'
try {
    NewDir $StartDir
    Set-Config
    Set-Lang ($Lang + '.slg')
    $script:KeyNote = Set-PluginHotKey '\\ftp\.spl$' 5 0x1034A
    $script:ConnKeyNote = Set-PluginHotKey '\\ftp\.spl$' 1 0x1034B
    if (Test-Path -LiteralPath $srvLog) { Remove-Item -LiteralPath $srvLog -Force }
    $py = (Get-Command python -ErrorAction Stop).Source
    $Server = Start-Process -FilePath $py -ArgumentList @(('"' + (Join-Path $PSScriptRoot 'ftp134_server.py') + '"'), $Port, ('"' + $srvLog + '"')) -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 1500
    Out ("ftp134_probe (feature 134), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : python pid {0} on port {1} (alive {2}); hot key: {3}" -f $Server.Id, $Port, (-not $Server.HasExited), $script:KeyNote)
    Out ''
    Row-Mkd 'MKDU8' 'enc-utf8' $true
    Row-Mkd 'MKDCP' 'enc-cp' $true
    Row-Mkd 'MKDASCII' 'enc-ascii' $false
    Row-CwdErr
    Row-Copy
    Row-Delete
    Row-Log
    Row-Bmk
    Row-Login 'PWD' $UserName 623 @($UserName, '127.0.0.1') 'the "Connecting to ... as ..." line of the password prompt'
    Row-Login 'LOGINU8' 'refuse-u8:x' 633 @($Refused) 'the server reply (UTF-8) in the login error dialog'
    Row-Login 'LOGINCP' 'refuse-cp:x' 633 @($Refused) 'the server reply (code page 1250) in the login error dialog'
    Row-SaveLog
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    if ($Server -and -not $Server.HasExited) { Stop-Process -Id $Server.Id -Force }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if ($ServerLog -and (Test-Path -LiteralPath $srvLog)) { Copy-Item -LiteralPath $srvLog -Destination $ServerLog -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } }
    catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
if ($Expect -eq 'before') { exit 0 }
exit $nf
