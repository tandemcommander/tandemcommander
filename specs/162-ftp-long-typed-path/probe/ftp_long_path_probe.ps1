<#
.SYNOPSIS
    Feature 162 probe: can a typed FTP path reach the plug-in's cut at FTP_MAX_PATH (300 bytes),
    which would send the panel into ANOTHER folder? (NEXT-WORK item 13; measured: no.)

.DESCRIPTION
    134's FTP server (specs/134-ftp-mixed-templates/probe/ftp134_server.py, 127.0.0.1) and helpers;
    the server's log of received lines decides. An ASCII path "/d/xxxx..." of N bytes is typed with
    a trailing slash, as the first address (the connection opens) or with a connection open (the
    "path change" branch of ChangePath). The core hands a plug-in at most 259 bytes of user part
    (ChangePathToPluginFS refuses longer, ChangeAndListPathOnFS copies into user[MAX_PATH]); the
    plug-in's path buffer holds 300 bytes (FTP_MAX_PATH). Rows:
      FIT          200 bytes: CWD of the whole path reaches the server
      EDGE[-OPEN]  the largest path the core passes on: whole
      OVER[-OPEN]  one byte more: the core refuses ("too long"), nothing of it is sent
      FTPMAX       299 bytes, LONG[-OPEN] 400 bytes: the same
    PASS = no received CWD / LIST names a strict prefix of the typed path; FIT / EDGE reached the
    server whole; the longer rows: a "too long" message and no CWD / LIST of the path.

    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored, verified.
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
    if ($last.Verdict -eq 'FAIL' -and $line -match 'exit 0x00000000' -and $line -match 'stray 1 \(at exit: \[#32770 ''FTP[^'']*''\] \[Static id=2477\]' -and $line -match 'new reports 0') {
        $last.Verdict = 'PASS'
        $script:Lines[$script:Lines.Count - 1] = $line.Replace(' FAIL ', ' PASS ') + ' [the queue question at exit is expected here]'
    }
}

# sets a DWORD of the FTP plug-in's configuration for this run (the registry key is restored)
function Set-FtpConfig([string]$Name, [int]$Value) {
    & reg.exe add "$RegKey\0.1\Plugins Configuration\FTP" /v $Name /t REG_DWORD /d $Value /f | Out-Null
    return ("'" + $Name + "' = " + $Value + ' (reg exit ' + $LASTEXITCODE + ')')
}

# MKD rows: Create Directory with an accented name in a directory whose refusals have a set encoding

# the CWD / LIST arguments the server received since 'mark' (lines of the log)
function Server-Paths([int]$From) {
    $l = @(Get-Content -LiteralPath $srvLog -ErrorAction SilentlyContinue)
    $out = @()
    for ($k = $From; $k -lt $l.Count; $k++) {
        if ($l[$k] -match '^RECV ([0-9a-f]+)$') {
            $hex = $Matches[1]; $b = New-Object byte[] ($hex.Length / 2)
            for ($x = 0; $x -lt $b.Length; $x++) { $b[$x] = [Convert]::ToByte($hex.Substring(2 * $x, 2), 16) }
            $t = [Text.Encoding]::ASCII.GetString($b).Trim()
            if ($t -match '^(CWD|LIST|NLST|MLSD|STAT) (.*)$') { $out += ($Matches[1] + ' ' + $Matches[2]) }
        }
    }
    return , $out
}
function LogLines { return @(Get-Content -LiteralPath $srvLog -ErrorAction SilentlyContinue).Count }
function Run-Long([string]$Case, [int]$Len, [bool]$Open) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $p = '/d/' + ('x' * ($Len - 3))
    try {
        $id = Start-P
        if ($Open) { [void](Connect $id '/plain/') }
        $mark = LogLines
        $known = Dialogs $id
        [void](Do-ChangeDir $id ($Addr + $p + '/'))
        Start-Sleep -Milliseconds 2500
        $boxes = @(Dialogs $id | Where-Object { $known -notcontains $_ })
        $texts = @($boxes | ForEach-Object { (Esc ([Drv098f]::Txt($_))) + ': ' + (StaticText $_) }) -join ' || '
        [void](Drain $id 6)
        $got = Server-Paths $mark
        $cut = @($got | Where-Object { $_ -match '^\S+ (/d/x+)/?$' -and $Matches[1].Length -lt $p.Length -and $p.StartsWith($Matches[1]) })
        $whole = @($got | Where-Object { $_ -match '^\S+ (/d/x+)/?$' -and $Matches[1] -ceq $p })
        if ($Len -le $script:MaxWhole) { $ok = ($cut.Count -eq 0) -and ($whole.Count -gt 0) }
        else { $ok = ($cut.Count -eq 0) -and ($whole.Count -eq 0) -and ($texts -match 'long|dlouh') }
        $show = ($got | ForEach-Object { $s = $_; if ($s.Length -gt 40) { $s.Substring(0, 12) + '...(' + ($s.Length - 5) + ' bytes)' } else { $s } }) -join '; '
        Row $Case 'PATH' (V $ok) ("typed {0} bytes{1}; the server got: {2}; cut ones {3}, whole {4}; boxes: {5}" -f $Len, $(if ($Open) { ' (connection open)' } else { '' }), $(if ($show) { $show } else { 'no CWD/LIST of it' }), $cut.Count, $whole.Count, $(if ($texts) { $texts } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc162_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
$srvLog = Join-Path $env:TEMP 'tc162_server.log'
try {
    NewDir $StartDir
    Set-Config
    Set-Lang ($Lang + '.slg')
    $script:KeyNote = Set-PluginHotKey '\\ftp\.spl$' 5 0x1034A
    $script:AutoRenNote = Set-FtpConfig 'If Cannot Create File' 1
    $script:ConnKeyNote = Set-PluginHotKey '\\ftp\.spl$' 1 0x1034B
    if (Test-Path -LiteralPath $srvLog) { Remove-Item -LiteralPath $srvLog -Force }
    $py = (Get-Command python -ErrorAction Stop).Source
    $Server = Start-Process -FilePath $py -ArgumentList @(('"' + (Join-Path $PSScriptRoot '..\..\134-ftp-mixed-templates\probe\ftp134_server.py') + '"'), $Port, ('"' + $srvLog + '"')) -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 1500
    Out ("ftp_long_path_probe (feature 162), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Server  : python pid {0} on port {1} (alive {2}); hot key: {3}" -f $Server.Id, $Port, (-not $Server.HasExited), $script:KeyNote)
    Out ("Config  : {0}" -f $script:AutoRenNote)
    Out ''
    # the core hands a plug-in at most MAX_PATH - 1 bytes of user part ("//127.0.0.1:<port>" + path)
    $script:MaxWhole = 258 - ('//127.0.0.1:' + $Port).Length   # + the typed trailing '/'
    Out ("Boundary: the largest path the core passes on = {0} bytes (user part 259 with the trailing slash)" -f $script:MaxWhole)
    Run-Long 'FIT' 200 $false
    Run-Long 'EDGE' $script:MaxWhole $false
    Run-Long 'EDGE-OPEN' $script:MaxWhole $true
    Run-Long 'OVER' ($script:MaxWhole + 1) $false
    Run-Long 'OVER-OPEN' ($script:MaxWhole + 1) $true
    Run-Long 'FTPMAX' 299 $false
    Run-Long 'LONG' 400 $false
    Run-Long 'LONG-OPEN' 400 $true
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

