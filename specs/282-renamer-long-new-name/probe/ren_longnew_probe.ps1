<#
.SYNOPSIS
    Feature 282 probe: the Renamer builds a new name of any length the file system accepts (it was
    capped at 259 bytes of UTF-8), and an item found through "Include subdirectories" is taken at
    the same lengths as a selected one (it was refused at 260 bytes).

.DESCRIPTION
    L = 90 CJK letters (270 bytes of UTF-8, 90 UTF-16 units), M = 45 of them (the New name field
    itself holds 519 bytes - a pattern, refused when longer). Rows:
      long-new       a file "L.txt" renamed to "Lb.txt" (file-name mode). PASS = renamed, no box
      long-undo      the same, then Undo (CMD_UNDO 621): PASS = back under "L.txt"
      manual-long    manual mode (IDC_MANUAL 105, the edit IDE_MANUAL 125), "x.txt" -> "Lc.txt"
      long-rel       relative-path mode (CMD_RELATIVEPATH 608), "x.txt" -> "M\MM.txt" (a folder made)
      long-rel-deep  the same, "x.txt" -> 100 a \ 100 b \ 100 c ".txt": a path of 300+ UTF-16 units
      sub-long-file  a folder "sub" holding "L.txt", "Include subdirectories" (IDC_SUBDIRS 102)
                     ticked: PASS = no box on loading, 1 preview row, renamed to sub\a.txt
      sub-long-dir   a folder "L" holding "x.txt", subdirectories ticked: PASS = L\y.txt
      deep-guard     a folder "top" holding 1030 nested folders "d", subdirectories ticked: PASS =
                     the existing "too long path" refusal on loading, no crash, nothing renamed
      deep-ok        the same with 1020 levels (inside the guard): listed and renamed at the bottom
      over-comp      "x.txt" -> 300 x "a" + ".txt" (one component over 255): PASS = an error box,
                     x.txt unchanged, nothing else made (refused, never cut)
      short-ctl      the control: "x.txt" -> "a.txt", then Undo
    Driver of 199's / 209's probes. MUST run through tools\\run_on_hidden_desktop.ps1. Registry exported,
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
. (Join-Path $PSScriptRoot '..\..\127-mixed-template-texts\probe\lvtext_lib.ps1')   # the preview's cells
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
$Root = $TempRoot + '\tc282_ren'
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
function Is-Renamer([IntPtr]$H) { return ([Drv098f]::Cls($H) -eq '#32770') -and ((Kid $H 101 'ComboBox') -ne $null) -and ((Kid $H 106 'ComboBox') -ne $null) }
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
function Preview-Count([IntPtr]$Dlg) { $lv = Kid $Dlg 104 $null; if (-not $lv) { return -1 }; return [Drv104]::SendR($lv, 0x1004 <#LVM_GETITEMCOUNT#>, 0, 0) }
function Wait-Renamer([int]$Id, $Known) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $w = @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and (Is-Renamer $_) }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 1200; return $w }
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}
# one row: $Setup returns @{ Folder; Source; SourceIsDir; NewName; RelPath; Manual; Subdirs; Undo;
# Answers; Want (regex of the boxes, $null = none); Check = { -> @(ok, facts) } }
function Run-Ren([string]$Case, [scriptblock]$Setup) {
    if (-not (Want $Case)) { return }
    $c = & $Setup
    if ($c.Skip) { Row $Case 'RUN' 'NOT DRIVEN' $c.Skip; return }
    foreach ($p in @($c.Typed)) { if ($p -and -not $p.StartsWith($Root + '\')) { Row $Case 'RUN' 'FAIL' ('a typed path outside the fixture: ' + $p); return } }
    $id = 0; $before = Reports
    try {
        $id = Start-P $c.Folder
        $known = Get-Tops $id
        if ($c.SourceIsDir) {   # a folder: Change Directory would enter it - its parent, End, Insert
            [void](Do-ChangeDir $id $c.Folder); Start-Sleep -Milliseconds 400; Sync $id
            Key $id 0x23; Start-Sleep -Milliseconds 300
        }
        else { [void](Do-ChangeDir $id ($c.Folder + '\' + $c.Source)); Start-Sleep -Milliseconds 400; Sync $id }
        Key $id 0x2D; Start-Sleep -Milliseconds 300; Sync $id   # Insert: select it alone
        [void][Drv104]::ModKey((Get-LeftList $id), 0x52, 3)     # Ctrl+Shift+R
        $dlg = Wait-Renamer $id $known
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'RUN' 'FAIL' 'the Renamer dialog did not open'; return }
        $texts = ''
        $loadBoxes = $false
        if ($c.Subdirs) {   # tick "Include subdirectories" (102): BM_CLICK checks it and notifies the dialog
            $sb = Kid $dlg 102 'Button'
            [void][Drv098f]::PostMessageW($sb, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)
            Start-Sleep -Milliseconds 2500
            $ans0 = Answer $id 10 @(2) @($dlg)   # a refusal on loading: Cancel
            $loadBoxes = ($ans0.Messages.Count -gt 0)
            $texts = 'loading: ' + (Msgs2 $ans0) + '; checkbox ' + [Drv104]::SendR($sb, 0x00F0, 0, 0) + ' || '
        }
        $preview = Preview-Count $dlg
        if ($c.RelPath) { [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]608, [IntPtr]::Zero); Start-Sleep -Milliseconds 1000 }   # CMD_RELATIVEPATH
        if ($c.Manual) {
            Click (Kid $dlg 105 'Button'); Start-Sleep -Milliseconds 1500   # IDC_MANUAL
            [void][Drv098f]::SetText((Kid $dlg 125 'Edit'), $c.NewName, 5000)
            Start-Sleep -Milliseconds 800
        }
        else {
            # all but the last character set, the last one typed: the edit's change notification marks
            # the preview for an update (WM_SETTEXT alone does not)
            $nc = Kid $dlg 106 'ComboBox'
            [void][Drv098f]::SetText($nc, $c.NewName.Substring(0, $c.NewName.Length - 1), 5000)
            $ne = Edit-Of $nc
            [void][Drv104]::SendR($ne, 0x00B1 <#EM_SETSEL#>, $c.NewName.Length - 1, $c.NewName.Length - 1)   # the caret at the end
            Type-Into $ne $c.NewName.Substring($c.NewName.Length - 1)
            Start-Sleep -Milliseconds 2000
        }
        $cellNew = $null; $cellPath = $null; $cellsOk = $true
        if ($c.PreviewNew -or $c.PreviewPath) {   # the preview's first row: New name (1), Path (5)
            $lv = Kid $dlg 104 $null
            $cellNew = [LvText127]::Cell($lv, 0, 1); $cellPath = [LvText127]::Cell($lv, 0, 5)
            if ($c.PreviewNew -and $cellNew -cne $c.PreviewNew) { $cellsOk = $false }
            if ($c.PreviewPath -and $cellPath -cne $c.PreviewPath) { $cellsOk = $false }
            $texts = 'preview new name: ' + (Short-L $cellNew) + '; path: ' + (Short-L ($cellPath -replace [regex]::Escape($Root), '<fixture>')) + ' || ' + $texts
        }
        if ($loadBoxes) {   # refused on loading (the subdirectories were dropped): never rename the folder itself
            $ans = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null }
            $texts += 'not renamed (refused on loading)'
        }
        else {
            Click (Kid $dlg 1 'Button')
            Start-Sleep -Milliseconds 1500
            $ans = Answer $id 20 $c.Answers @($dlg)
            $texts += Msgs2 $ans
        }
        $res1 = & $c.Check
        if ($c.Undo -and -not $ans.Fatal -and -not $loadBoxes) {   # CMD_UNDO, its question answered Yes
            [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]621, [IntPtr]::Zero)
            Start-Sleep -Milliseconds 1500
            $ans2 = Answer $id 20 @(6, 1) @($dlg)
            $texts = $texts + ' || undo: ' + (Msgs2 $ans2)
            if ($ans2.Fatal) { $ans = $ans2 }
            $res2 = & $c.CheckUndo
            $res1 = @(($res1[0] -and $res2[0]), ('after the rename: ' + $res1[1] + '; after Undo: ' + $res2[1]))
        }
        $asked = $(if ($c.Want) { $texts -match $c.Want } else { -not ($texts -match '#32770') })
        if ($c.NotWant -and $texts -match $c.NotWant) { $asked = $false }
        $rowsOk = (-not $c.Rows) -or ($preview -eq $c.Rows)
        Row $Case 'RUN' (V ($res1[0] -and $asked -and $rowsOk -and $cellsOk -and -not $ans.Fatal)) ("preview rows {0}; boxes as expected: {1}; on disk: {2}; boxes: {3}{4}" -f $preview, $asked, $res1[1], $texts, $(if ($ans.Fatal) { '; FATAL ' + $ans.Fatal } else { '' }))
        Close-Renamer $id $dlg
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}
$L = ([string][char]0x4E2D) * 90
$M = ([string][char]0x4E2D) * 45   # the New name field holds 519 bytes: two M fit
# global: the checks are closures (GetNewClosure) - a script function is not seen there ("Ls" was
# the alias of Get-ChildItem)
function global:Short-L([string]$s) {
    $rxL = '[' + [char]0x4E2D + ']{90}'; $rxM = '[' + [char]0x4E2D + ']{45}'
    return (($s -replace $rxL, '<L>') -replace $rxM, '<M>')
}
function global:List-Tree([string]$d) {
    $lp = '\\?\'
    if (-not [IO.Directory]::Exists($lp + $d)) { return '(gone)' }
    $out = @()
    foreach ($e in [IO.Directory]::GetFileSystemEntries($lp + $d, '*', [IO.SearchOption]::AllDirectories)) {
        $rel = $e.Substring(($lp + $d).Length + 1)
        if ([IO.File]::Exists($e)) { $out += ($rel + '=' + [IO.File]::ReadAllText($e)) } else { $out += ($rel + '\') }
    }
    return (($out | Sort-Object) -join ',')
}
function Run-RenCases {
    Run-Ren 'long-new' {
        $d = $Root + '\long-new'; NewDir $d; Put "$d\$L.txt" 'LN'
        $want = "${L}b.txt=LN"
        @{ Folder = $d; Source = "$L.txt"; NewName = "${L}b.txt"; PreviewNew = "${L}b.txt"; PreviewPath = $d; Answers = @(6, 1); Want = $null; Rows = 1
           Check = { $n = List-Tree $d; @(($n -ceq $want), (Short-L $n)) }.GetNewClosure() }
    }
    Run-Ren 'long-undo' {
        $d = $Root + '\long-undo'; NewDir $d; Put "$d\$L.txt" 'LU'
        $want = "${L}b.txt=LU"; $wantU = "$L.txt=LU"
        @{ Folder = $d; Source = "$L.txt"; NewName = "${L}b.txt"; PreviewNew = "${L}b.txt"; PreviewPath = $d; Answers = @(6, 1); Want = 'undo'; Undo = $true; Rows = 1
           Check = { $n = List-Tree $d; @(($n -ceq $want), (Short-L $n)) }.GetNewClosure()
           CheckUndo = { $n = List-Tree $d; @(($n -ceq $wantU), (Short-L $n)) }.GetNewClosure() }
    }
    Run-Ren 'manual-long' {
        $d = $Root + '\manual-long'; NewDir $d; Put "$d\x.txt" 'ML'
        $want = "${L}c.txt=ML"
        @{ Folder = $d; Source = 'x.txt'; NewName = "${L}c.txt"; Manual = $true; Answers = @(6, 1); Want = $null; Rows = 1
           Check = { $n = List-Tree $d; @(($n -ceq $want), (Short-L $n)) }.GetNewClosure() }
    }
    Run-Ren 'long-rel' {
        $d = $Root + '\long-rel'; NewDir $d; Put "$d\x.txt" 'LR'
        $want = "$M\,$M\$M$M.txt=LR"
        @{ Folder = $d; Source = 'x.txt'; NewName = "$M\$M$M.txt"; PreviewNew = "$M\$M$M.txt"; RelPath = $true; Answers = @(6, 1); Want = $null; Rows = 1
           Check = { $n = List-Tree $d; @(($n -ceq $want), (Short-L $n)) }.GetNewClosure() }
    }
    Run-Ren 'long-rel-deep' {
        $d = $Root + '\long-rel-deep'; NewDir $d; Put "$d\x.txt" 'LD'
        $a = 'a' * 100; $b = 'b' * 100; $cc = 'c' * 100
        $want = "$a\,$a\$b\,$a\$b\$cc.txt=LD"
        @{ Folder = $d; Source = 'x.txt'; NewName = "$a\$b\$cc.txt"; PreviewNew = "$a\$b\$cc.txt"; RelPath = $true; Answers = @(6, 1); Want = $null; Rows = 1
           Check = { $n = List-Tree $d; @(($n -ceq $want), (Short-L $n)) }.GetNewClosure() }
    }
    Run-Ren 'sub-long-file' {
        $d = $Root + '\sub-long-file'; NewDir "$d\sub"; Put "$d\sub\$L.txt" 'SF'
        @{ Folder = $d; Source = 'sub'; SourceIsDir = $true; Subdirs = $true; NewName = 'a.txt'; PreviewNew = 'a.txt'; PreviewPath = "$d\sub"; Answers = @(6, 1); Want = $null; Rows = 1
           Check = { $n = List-Tree $d; @(($n -ceq 'sub\,sub\a.txt=SF'), (Short-L $n)) }.GetNewClosure() }
    }
    Run-Ren 'sub-long-dir' {
        $d = $Root + '\sub-long-dir'; NewDir "$d\$L"; Put "$d\$L\x.txt" 'SD'
        $want = "$L\,$L\y.txt=SD"
        @{ Folder = $d; Source = $L; SourceIsDir = $true; Subdirs = $true; NewName = 'y.txt'; PreviewNew = 'y.txt'; PreviewPath = "$d\$L"; Answers = @(6, 1); Want = $null; Rows = 1
           Check = { $n = List-Tree $d; @(($n -ceq $want), (Short-L $n)) }.GetNewClosure() }
    }
    Run-Ren 'deep-guard' {
        # 1030 folders "d" below "top": deeper than the listing's guard (1024 levels) - refused, never a crash
        $d = $Root + '\deep-guard'; $bottom = $d + '\top' + ('\d' * 1030); NewDir $bottom; Put "$bottom\x.txt" 'DG'
        @{ Folder = $d; Source = 'top'; SourceIsDir = $true; Subdirs = $true; NewName = 'z.txt'; Answers = @(2, 7); Want = 'too long path'; Rows = 1
           Check = { $lp = '\\?\'; $ok = [IO.File]::Exists($lp + $bottom + '\x.txt') -and [IO.Directory]::Exists($lp + $d + '\top'); @($ok, ('the bottom file in place, "top" kept: ' + $ok)) }.GetNewClosure() }
    }
    Run-Ren 'deep-ok' {
        # 1020 folders "d" below "top": inside the guard - listed and renamed (the stack holds that deep)
        $d = $Root + '\deep-ok'; $bottom = $d + '\top' + ('\d' * 1020); NewDir $bottom; Put "$bottom\x.txt" 'DO'
        @{ Folder = $d; Source = 'top'; SourceIsDir = $true; Subdirs = $true; NewName = 'z.txt'; PreviewNew = 'z.txt'; Answers = @(6, 1); Want = $null; Rows = 1
           Check = { $lp = '\\?\'; $ok = [IO.File]::Exists($lp + $bottom + '\z.txt') -and -not [IO.File]::Exists($lp + $bottom + '\x.txt'); @($ok, ('renamed at the bottom to z.txt: ' + $ok)) }.GetNewClosure() }
    }
    Run-Ren 'over-comp' {
        $d = $Root + '\over-comp'; NewDir $d; Put "$d\x.txt" 'OC'
        @{ Folder = $d; Source = 'x.txt'; NewName = ('a' * 300) + '.txt'; PreviewNew = ('a' * 300) + '.txt'; Answers = @(2, 7); Want = '#32770'; Rows = 1
           Check = { $n = List-Tree $d; @(($n -ceq 'x.txt=OC'), $n) }.GetNewClosure() }
    }
    Run-Ren 'short-ctl' {
        $d = $Root + '\short-ctl'; NewDir $d; Put "$d\x.txt" 'SC'
        @{ Folder = $d; Source = 'x.txt'; NewName = 'a.txt'; Answers = @(6, 1); Want = 'undo'; Undo = $true; Rows = 1
           Check = { $n = List-Tree $d; @(($n -ceq 'a.txt=SC'), $n) }.GetNewClosure()
           CheckUndo = { $n = List-Tree $d; @(($n -ceq 'x.txt=SC'), $n) }.GetNewClosure() }
    }
}

$backup = Join-Path $env:TEMP 'tc282_ren_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    Make-Fixtures
    Set-Config
    Out ("ren_longnew_probe (feature 282), expect: {0}" -f $Expect)
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

