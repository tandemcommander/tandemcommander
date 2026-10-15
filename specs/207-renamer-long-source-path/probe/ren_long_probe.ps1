<#
.SYNOPSIS
    Feature 207 probe: the Renamer never overruns a MAX_PATH buffer with a selected item whose path
    has 260+ bytes of UTF-8 (90 CJK letters: an ordinary 98-unit Windows path).

.DESCRIPTION
    Rows (the Renamer on one file "<90 CJK letters>.txt" in the fixture, the new name "a.txt"):
      undo-long   rename, then Undo (CMD_UNDO 621, the question answered Yes): MoveFile copied the
                  original full name into char dir[MAX_PATH] - PASS = no failure, the file back
                  under its long name
      rmsrc-long  "Remove source path" on (CMD_RMSOURCEPATH 620), rename: the source's full name was
                  copied into char dir[MAX_PATH] - PASS = no failure, renamed to a.txt
      short-ctl   the control: an ordinary name, rename and Undo
      long-root   the panel IN a folder whose path has 260+ bytes of UTF-8 (a folder of 90 CJK letters
                  in the fixture), a file tc207uniq.txt renamed to tc207uniq-b.txt: GetPanelPath
                  failed, Root stayed empty and the items became "\tc207uniq.txt" - in the root of
                  the current drive (C:\). PASS = refused ("too long path") before the dialog, the
                  file unchanged, nothing in C:\ (rows NOT DRIVEN when such names exist in C:\)
    Driver of 199's probe. MUST run through tools\\run_on_hidden_desktop.ps1. Registry exported,
    restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',   # fixed = the texts of 155
    [string]$OutFile,
    [string[]]$Only,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe',
    [string]$Python = 'python',
    [string]$OldExe   # ftp-b1 LEGACY: the build before, to store a password in its code-page form
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Drv104' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv104
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int InternalGetWindowText(IntPtr h, StringBuilder s, int n);
    public static string Internal(IntPtr h) { var s = new StringBuilder(70000); InternalGetWindowText(h, s, 70000); return s.ToString(); }
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendGetBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 5000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    public static string LbText(IntPtr combo, int index)
    {
        long len = SendR(combo, 0x0149 /*CB_GETLBTEXTLEN*/, index, 0);
        if (len < 0) return null;
        var buf = new char[len + 2]; IntPtr r;
        SendGetBuf(combo, 0x0148 /*CB_GETLBTEXT*/, (IntPtr)index, buf, 0, 5000, out r);
        long n = r.ToInt64(); if (n < 0) return null; if (n > len) n = len;
        return new string(buf, 0, (int)n);
    }
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift): the probe thread shares the target thread's
    // input state and sets the key-state table - no real key press (the 100/102 method)
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

$Fixed = ($Expect -eq 'fixed')
$Root = $TempRoot + '\tc199_ren'
$StartDir = $Root + '\start'
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }
$Cyr = S 0x0416, 0x0430, 0x0431, 0x0430          # Zhaba
$Cjk = S 0x65E5, 0x672C, 0x8A9E                  # nihongo
$Emo = S 0x1F4C1
$Lone = 'lone' + [char]0xD800 + 'x'
$Voila = 'voil' + [char]0x00E0
$FwAB = S 0xFF21, 0xFF22
$Clanek = 'cl' + [char]0x00E1 + 'nek'
# the system's text for ERROR_FILENAME_EXCED_RANGE (206), in the language of Windows
$TooLongText = (New-Object ComponentModel.Win32Exception 206).Message.Trim()

function Put([string]$p, [string]$text) { [IO.File]::WriteAllText($LP + $p, $text, (New-Object Text.ASCIIEncoding)) }
function Get([string]$p) { if ([IO.File]::Exists($LP + $p)) { return [IO.File]::ReadAllText($LP + $p) } else { return $null } }
function Names([string]$dir) {
    if (-not [IO.Directory]::Exists($LP + $dir)) { return '(gone)' }
    $n = @(); foreach ($e in [IO.Directory]::GetFileSystemEntries($LP + $dir)) { $nm = [IO.Path]::GetFileName($e); if ([IO.File]::Exists($e)) { $len = (New-Object IO.FileInfo $e).Length; if ($len -le 40) { $n += ((Esc $nm) + '=' + (Esc ([IO.File]::ReadAllText($e)))) } else { $n += ((Esc $nm) + '=(' + $len + ' bytes)') } } else { $n += ((Esc $nm) + '/') } }
    return (($n | Sort-Object) -join '; ')
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left, [string]$Right) {
    if (-not $Right) { $Right = $StartDir }
    $a = @('-t', 'T104', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Edit-Of([IntPtr]$Combo) { return @([Drv098f]::Kids($Combo) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' }) | Select-Object -First 1 }
function Type-Into([IntPtr]$Edit, [string]$Text) { foreach ($ch in $Text.ToCharArray()) { [void][Drv104]::PostMessageW($Edit, 0x0102, [IntPtr][int]$ch, [IntPtr]1) } }
function Wait-Text([IntPtr]$H, [int]$Len, [double]$Seconds = 6) {
    $sw = [Diagnostics.Stopwatch]::StartNew(); $t = ''
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { Start-Sleep -Milliseconds 250; $t2 = [Drv098f]::GetText($H, 5000); if ($t2.Length -ge $Len -or ($t2 -ceq $t -and $sw.Elapsed.TotalSeconds -gt 2)) { return $t2 }; $t = $t2 }
    return $t
}
# answers every box of the instance: the ids in $Want, else No (7) / Cancel (2) / close; records
# the texts; stops when no box is shown for 2 s (windows in $Ignore are not boxes)
function Answer([int]$Id, [double]$Seconds = 20, [int[]]$WantIds = @(7, 2), $Ignore = @()) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not (Test-Alive $Id)) { break }
        $boxes = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $Ignore -notcontains $_ -and [Drv098f]::IsWindowEnabled($_) })
        if (-not $boxes.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 150; continue
        }
        $idleSince = $null
        foreach ($b in $boxes) {
            $key = $b.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - $seen[$key] -lt 0.7) { continue }
            $seen.Remove($key)
            $d = WinDesc $b
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            [void]$r.Messages.Add($d)
            $btn = $null
            foreach ($w in $WantIds) { $btn = Buttons $b | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($btn) { break } }
            if ($btn) { Click $btn } else { Close-Win $b }
            Start-Sleep -Milliseconds 600
        }
    }
    return $r
}
function Msgs2($r) { if ($r.Messages.Count) { return ($r.Messages -join ' || ') } else { return 'no box' } }
function End-P([string]$Case, [int]$Id, $Before) {
    # close the plug-ins' own windows first (renamer, viewers): WM_CLOSE, boxes answered Yes
    foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    Start-Sleep -Milliseconds 800
    [void](Answer $Id 6 @(6, 1))
    End-Row $Case $Id $null $Before
}

# ---- fixtures -----------------------------------------------------------------------------
function Make-Fixtures {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
}

# ---- Renamer ------------------------------------------------------------------------------
$RenCases = @(
    @{ Case = 'cyr'; Name = $Cyr + '.txt'; Decoy = $null; Typed = $true },
    @{ Case = 'cjk'; Name = $Cjk + '.txt'; Decoy = $null; Typed = $false },
    @{ Case = 'emo'; Name = $Emo + 'ok.txt'; Decoy = $null; Typed = $true },
    @{ Case = 'voila'; Name = $Voila + '.txt'; Decoy = 'voila.txt'; Typed = $false },
    @{ Case = 'fwab'; Name = $FwAB + '.txt'; Decoy = 'AB.txt'; Typed = $true },
    @{ Case = 'lone'; Name = $Lone + '.txt'; Decoy = $null; Typed = $false })
function Is-Renamer([IntPtr]$H) { return ([Drv098f]::Cls($H) -eq '#32770') -and ((Kid $H 101 'ComboBox') -ne $null) -and ((Kid $H 106 'ComboBox') -ne $null) }
function Open-Renamer([int]$Id) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 842   # select all: the Renamer works on the selection (the cursor is on '..')
    Start-Sleep -Milliseconds 400; Sync $Id
    $k = [Drv104]::ModKey((Get-LeftList $Id), 0x52, 3)   # Ctrl+Shift+R
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and (Is-Renamer $_) }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 1200; return $w }
        Start-Sleep -Milliseconds 200
    }
    $script:LastOpenDiag = ('key: ' + $k + '; new windows: ' + ((@(Get-Tops $Id | Where-Object { $known -notcontains $_ }) | ForEach-Object { WinDesc $_ }) -join ' || '))
    return [IntPtr]::Zero
}
function Close-Renamer([int]$Id, [IntPtr]$Dlg) {
    if (-not [Drv098f]::IsWindow($Dlg)) { return }
    Post-Cmd $Dlg 2
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($Dlg)) {
        $q = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $_ -ne $Dlg -and [Drv098f]::IsWindowEnabled($_) })
        foreach ($b in $q) { $y = Buttons $b | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($y) { Click $y } }
        Start-Sleep -Milliseconds 300
    }
}
# the mask is typed (WM_CHAR): the Renamer re-reads the files on the edit's change notification,
# which WM_SETTEXT does not send
function Set-Mask([IntPtr]$Dlg, [string]$Mask) {
    $mc = Kid $Dlg 101 'ComboBox'
    [void][Drv098f]::SetText($mc, '', 5000); Type-Into (Edit-Of $mc) $Mask
    [void](Wait-Text $mc $Mask.Length)
    Start-Sleep -Milliseconds 2000
}
function Preview-Count([IntPtr]$Dlg) { $lv = Kid $Dlg 104 $null; if (-not $lv) { return -1 }; return [Drv104]::SendR($lv, 0x1004 <#LVM_GETITEMCOUNT#>, 0, 0) }

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}

# ---- Renamer in a case-sensitive folder --------------------------------------------------
function CS-Dir([string]$Case) {
    $d = $Root + '\' + $Case; NewDir "$d\cs"
    $r = Cmd ("fsutil file setCaseSensitiveInfo `"{0}`" enable" -f "$d\cs")
    if ($r.Rc -ne 0) { return @($d, ('case sensitivity refused: ' + $r.Text)) }
    return @($d, '')
}
function Open-RenamerOn([int]$Id, [string]$File) {
    $known = Get-Tops $Id
    [void](Do-ChangeDir $Id $File)        # focus the file
    Start-Sleep -Milliseconds 400; Sync $Id
    Key $Id 0x2D                          # Insert: select it alone
    Start-Sleep -Milliseconds 300; Sync $Id
    $k = [Drv104]::ModKey((Get-LeftList $Id), 0x52, 3)   # Ctrl+Shift+R
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and (Is-Renamer $_) }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 1200; return $w }
        Start-Sleep -Milliseconds 200
    }
    $script:LastOpenDiag = ('key: ' + $k)
    return [IntPtr]::Zero
}
# one row: $Setup returns @{ Dir; Folder; Answers; Want (regex of the boxes); Check = { -> @(ok, facts) } }
function Run-Ren([string]$Case, [scriptblock]$Setup) {
    if (-not (Want $Case)) { return }
    $c = & $Setup
    if ($c.Skip) { Row $Case 'RUN' 'NOT DRIVEN' $c.Skip; return }
    $id = 0; $before = Reports
    try {
        $id = Start-P $c.Folder
        $dlg = Open-RenamerOn $id ($c.Folder + '\' + $c.Source)
        if ($dlg -eq [IntPtr]::Zero) {
            if ($c.MayRefuse) {   # the Renamer refused to open: its box
                $ans = Answer $id 10 @(1) @()
                $texts = Msgs2 $ans
                $res = & $c.Check
                $asked = $texts -match $c.Want
                Row $Case 'RUN' (V ($res[0] -and $asked -and -not $ans.Fatal)) ("refused before the dialog; boxes as expected: {0}; on disk: {1}; boxes: {2}" -f $asked, $res[1], $texts)
                return
            }
            Row $Case 'RUN' 'FAIL' ('the Renamer dialog did not open; ' + $script:LastOpenDiag); return
        }
        $preview = Preview-Count $dlg
        if ($c.RmSource) { [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]620, [IntPtr]::Zero); Start-Sleep -Milliseconds 800 }   # CMD_RMSOURCEPATH
        if ($c.RelPath) { [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]608, [IntPtr]::Zero); Start-Sleep -Milliseconds 1000 }   # CMD_RELATIVEPATH: a new name with folders
        $nn = Kid $dlg 106 'ComboBox'
        [void][Drv098f]::SetText($nn, $c.NewName, 5000)
        Start-Sleep -Milliseconds 1500
        Click (Kid $dlg 1 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 20 $c.Answers @($dlg)
        $texts = Msgs2 $ans
        if ($c.Undo -and -not $ans.Fatal) {   # CMD_UNDO on the Renamer's dialog, its question answered Yes
            [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]621, [IntPtr]::Zero)
            Start-Sleep -Milliseconds 1500
            $ans2 = Answer $id 20 @(6, 1) @($dlg)
            $texts = $texts + ' || undo: ' + (Msgs2 $ans2)
            if ($ans2.Fatal) { $ans = $ans2 }
        }
        $res = & $c.Check
        $asked = $(if ($c.Want) { $texts -match $c.Want } else { $texts -eq 'no box' })
        if ($c.NotWant -and $texts -match $c.NotWant) { $asked = $false }
        Row $Case 'RUN' (V ($res[0] -and $asked -and -not $ans.Fatal)) ("preview rows {0}; boxes as expected: {1}; on disk: {2}; boxes: {3}{4}" -f $preview, $asked, $res[1], $texts, $(if ($ans.Fatal) { '; FATAL ' + $ans.Fatal } else { '' }))
        Close-Renamer $id $dlg
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}
function Dirs([string]$d) { return ((@(Get-ChildItem -LiteralPath ($LP + $d) -Force -Directory | ForEach-Object { $_.Name + '/(' + ((@(Get-ChildItem -LiteralPath $_.FullName -Force | ForEach-Object { $_.Name } | Sort-Object)) -join ',') + ')' })) -join '; ') }
function Run-RenCases {
    $cjk = ([string][char]0x4E2D) * 90 + '.txt'   # 274 bytes of UTF-8
    Run-Ren 'undo-long' {
        $d = $Root + '\undo-long'; NewDir $d
        Put "$d\$cjk" 'LONG-1'
        $want = $cjk   # a local of this scope: the closure below keeps it
        @{ Folder = $d; Source = $cjk; NewName = 'a.txt'; Answers = @(6, 1); Want = 'undo'; Undo = $true
           Check = { $n = (@(Get-ChildItem -LiteralPath ($LP + $d) -Force | ForEach-Object { $_.Name }) -join ','); @(($n -ceq $want), ($n -replace ([string][char]0x4E2D) + '{10,}', '<90 CJK>')) }.GetNewClosure() }
    }
    Run-Ren 'rmsrc-long' {
        $d = $Root + '\rmsrc-long'; NewDir $d
        Put "$d\$cjk" 'LONG-2'; Put "$d\keep.txt" 'KEEP'
        @{ Folder = $d; Source = $cjk; NewName = 'a.txt'; Answers = @(6, 1); Want = $null; RmSource = $true
           Check = { $n = (@(Get-ChildItem -LiteralPath ($LP + $d) -Force | ForEach-Object { $_.Name } | Sort-Object) -join ','); @(($n -ceq 'a.txt,keep.txt'), $n) }.GetNewClosure() }
    }
    Run-Ren 'long-root' {
        if ((Test-Path -LiteralPath 'C:\tc207uniq.txt') -or (Test-Path -LiteralPath 'C:\tc207uniq-b.txt')) { return @{ Skip = 'C:\tc207uniq*.txt exists - the row would act on it' } }
        $d = $Root + '\long-root\' + (([string][char]0x4E2D) * 90); NewDir ($Root + '\long-root'); NewDir $d
        Put "$d\tc207uniq.txt" 'LONGROOT'
        @{ Folder = $d; Source = 'tc207uniq.txt'; NewName = 'tc207uniq-b.txt'; Answers = @(173, 2); Want = 'too long'; MayRefuse = $true
           Check = { $n = (@(Get-ChildItem -LiteralPath ($LP + $d) -Force | ForEach-Object { $_.Name }) -join ','); $c1 = Test-Path -LiteralPath 'C:\tc207uniq.txt'; $c2 = Test-Path -LiteralPath 'C:\tc207uniq-b.txt'; @((($n -ceq 'tc207uniq.txt') -and -not $c1 -and -not $c2), ("in the folder: {0}; C:\tc207uniq.txt {1}, C:\tc207uniq-b.txt {2}" -f $n, $c1, $c2)) }.GetNewClosure() }
    }
    Run-Ren 'short-ctl' {
        $d = $Root + '\short-ctl'; NewDir $d
        Put "$d\x.txt" 'SHORT'
        @{ Folder = $d; Source = 'x.txt'; NewName = 'a.txt'; Answers = @(6, 1); Want = 'undo'; Undo = $true
           Check = { $n = (@(Get-ChildItem -LiteralPath ($LP + $d) -Force | ForEach-Object { $_.Name }) -join ','); @(($n -ceq 'x.txt'), $n) }.GetNewClosure() }
    }
}

$backup = Join-Path $env:TEMP 'tc207_ren_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    Make-Fixtures
    Set-Config
    Out ("ren_long_probe (feature 207), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ''
    Run-RenCases
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
