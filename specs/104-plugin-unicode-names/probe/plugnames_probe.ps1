<#
.SYNOPSIS
    Feature 104 probe: plug-in routes that take a file or folder name from the user give the
    plug-in exactly that name - no '?', no best-fit look-alike ("voila" for "voil<U+00E0>"),
    so no other existing file is renamed, deleted, overwritten, opened or used as a folder.
    On the build of this feature (-Expect fixed) and on the build before it
    (-Expect before, Debug_x64_pre104, the control).

.DESCRIPTION
    Fixtures under %TEMP%\tc104_pn (removed at the end). Names from code points (pure ASCII
    script). Decoys: an existing file or folder with the best-fit look-alike name and a
    different content, so a route that reached it is visible on disk or in the result.

    Rows (names for -Only):
      ren-new   Renamer (Ctrl+Shift+R), mask "src.txt", New name = <name>: the file is renamed to
                exactly <name>; the look-alike decoy is untouched. Cases: cyr Zhaba (Cyrillic, typed
                as WM_CHAR through the renamer's message loop), cjk (set with WM_SETTEXT), emo (an
                emoji, typed), voila (voil<U+00E0>.txt, decoy voila.txt), fwab (fullwidth AB.txt,
                decoy AB.txt), lone (a lone surrogate, set). An "overwrite?" question is answered
                No and recorded (it names the decoy on the build before).
      ren-hist  The New name history after the rename (same instance, the dialog reopened):
                item 0 of the drop-down (CB_GETLBTEXT, UTF-16) is the name exactly.
      ren-mask  Mask "<U+0416>*.txt" over Zhaba1.txt and abcd.txt: the preview lists 1 file
                (the build before read the mask as "?*.txt" - a wildcard - and listed 2).
      ren-man   Manual mode (the "Manual" check box) over one file: the edit shows its name
                exactly (cl<U+00E1>nek.txt, CJK); the line is replaced (WM_SETTEXT, UTF-16) by a
                Cyrillic / CJK name and Rename renames to exactly it.
      ren-long  New name of 200 CJK characters (604 bytes, the field holds 520): the
                system's "too long" message, nothing renamed (before: a code-page re-read).
      dbv-open  Database Viewer (F3 on a .csv), Ctrl+O, the open dialog's file name field set to
                voil<U+00E0>.csv (decoy voila.csv with another first cell): the viewer's title
                names voil<U+00E0>.csv and shows its content.
      pv-copyto PictView (F3 on a .png), Copy To (X): line 1's field set (UTF-16) to the folder
                ...\voil<U+00E0> (decoy folder ...\voila exists), Browse, the folder dialog
                opens on the field's folder, OK: the field holds the folder exactly; OK copies the
                image there (not into the decoy).
      pv-saveas PictView Ctrl+S: the save dialog's name field set to voil<U+00E0>.bmp in a folder
                that holds the decoy voila.bmp: no "already exists" question about the decoy, the
                decoy is untouched. Answers No to every question. FINDING row (both builds):
                Save As onto an EXISTING file - "replace?" Yes - deletes the file, then the save
                fails (the WIC engine cannot write images).
      unc-next  CAB plug-in: a two-volume cabinet whose 2nd volume lies only in the decoy folder
                ...\voila; the first in ...\voil<U+00E0>\a.cab; extracting asks for the next
                volume: the dialog's folder field shows ...\voil<U+00E0>\ exactly, OK there gives
                "not found" (before: the field showed ...\voila\ and the decoy's volume was used)
      zip-pwd   ZIP plug-in: an encrypted ZIP with the item <U+0416><U+0430>.txt; extracting asks
                for the password: the dialog's file label (read as UTF-16) is the name exactly.
      und-image Undelete (Ctrl+Shift+U), "image file": the field set to ...\voil<U+00E0>.ima (does
                not exist; the decoy voila.ima does): "image file not found" (before: the decoy
                was opened). And the field's prefill for a focused image file named in Cyrillic.
      ftp-b1    FTP Connect dialog (Ctrl+Shift+F), a bookmark from a registry fixture, a local log
                server (ftplog_server.py, logs the bytes of USER/PASS): OK40 - a password of 40 x
                U+010D (80 bytes) is stored; LONGPWD / LONGUSER - 60 x U+010D (120 bytes, the buffers
                hold 101): Close refuses ("too long"), the dialog stays, after Cancel + exit the
                stored password / user name is unchanged; CONNECT - the same password and Connect:
                refused, the server receives nothing (review B1: the first 104 build stored an
                EMPTY password and connected with it; the build before stored code-page bytes)
    NOT DRIVEN (recorded): FTP file dialogs (save log / welcome text, server-type export and
    import, parser test - same helper as dbv-open, no FTP server on the hidden desktop), ZIP
    "change disk" browse, Undelete restore target and temp folder browse, regedt Find typing and
    external editor, SFTP field overflow, an installation folder outside the code page.

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while another tandemcommander.exe
    runs. HKCU\Software\Tandem Commander exported before, restored and SHA-256-verified after.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
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
$Root = $TempRoot + '\tc104_pn'
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

function Run-RenNew($c) {
    $d = $Root + '\ren\' + $c.Case; NewDir $d
    Put ($d + '\src.txt') 'SRC'
    if ($c.Decoy) { Put ($d + '\' + $c.Decoy) 'DECOY' }
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        $dlg = Open-Renamer $id
        if ($dlg -eq [IntPtr]::Zero) { Row ('ren-' + $c.Case) 'NEW' 'FAIL' ('the Renamer dialog did not open; ' + $script:LastOpenDiag); return }
        $uni = 'dlg ' + [Drv104]::IsWindowUnicode($dlg) + ', new-name edit ' + [Drv104]::IsWindowUnicode((Edit-Of (Kid $dlg 106 'ComboBox')))
        Set-Mask $dlg 'src.txt'
        $nn = Kid $dlg 106 'ComboBox'
        if ($c.Typed) { [void][Drv098f]::SetText($nn, '', 5000); Type-Into (Edit-Of $nn) $c.Name; $held = Wait-Text $nn $c.Name.Length; $how = 'typed' }
        else { [void][Drv098f]::SetText($nn, $c.Name, 5000); $held = [Drv098f]::GetText($nn, 5000); $how = 'set' }
        Start-Sleep -Milliseconds 1500   # the preview updates on idle
        $pc = Preview-Count $dlg
        Click (Kid $dlg 1 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 20 @(7, 2) @($dlg)
        Start-Sleep -Milliseconds 500
        $tgt = Get ($d + '\' + $c.Name); $src = Get ($d + '\src.txt'); $dec = $null; if ($c.Decoy) { $dec = Get ($d + '\' + $c.Decoy) }
        $exact = ($tgt -ceq 'SRC') -and ($null -eq $src) -and ((-not $c.Decoy) -or $dec -ceq 'DECOY')
        $decoyAsked = $c.Decoy -and ((Msgs2 $ans) -match [regex]::Escape($c.Decoy))
        if ($Fixed) { $v = V ($exact -and ($held -ceq $c.Name) -and -not $decoyAsked) } else { $v = V (-not $exact) }
        Row ('ren-' + $c.Case) 'NEW' $v ("{0} '{1}': field holds it exactly {2} ('{3}'); preview items {4}; {5}; boxes: {6}; folder: {7}" -f $how, (Esc $c.Name), ($held -ceq $c.Name), (Esc $held), $pc, $uni, (Msgs2 $ans), (Names $d))
        if ((Want 'ren-hist') -and [Drv098f]::IsWindow($dlg) -eq $false) { $dlg = Open-Renamer $id }
        if ((Want 'ren-hist') -and $dlg -ne [IntPtr]::Zero) {
            $h0 = [Drv104]::LbText((Kid $dlg 106 'ComboBox'), 0)
            if ($Fixed) { $v = V ($h0 -ceq $c.Name) } else { $v = V ($h0 -cne $c.Name) }
            Row ('ren-' + $c.Case) 'HIST' $v ("New name history item 0 '{0}' exact {1}" -f (Esc $h0), ($h0 -ceq $c.Name))
        }
        Close-Renamer $id $dlg
    }
    catch { Row ('ren-' + $c.Case) 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P ('ren-' + $c.Case) $id $before } }
}

function Run-RenMask {
    $d = $Root + '\ren\mask'; NewDir $d
    Put ($d + '\' + $Cyr + '1.txt') 'A'; Put ($d + '\abcd.txt') 'B'
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        $dlg = Open-Renamer $id
        if ($dlg -eq [IntPtr]::Zero) { Row 'ren-mask' 'MASK' 'FAIL' ('the Renamer dialog did not open; ' + $script:LastOpenDiag); return }
        $mask = ([string][char]0x0416) + '*.txt'
        $mc = Kid $dlg 101 'ComboBox'
        [void][Drv098f]::SetText($mc, '', 5000); Type-Into (Edit-Of $mc) $mask
        $held = Wait-Text $mc $mask.Length
        Start-Sleep -Milliseconds 2500
        $pc = Preview-Count $dlg
        if ($Fixed) { $v = V ($pc -eq 1 -and $held -ceq $mask) } else { $v = V ($pc -ne 1) }
        Row 'ren-mask' 'MASK' $v ("mask typed '{0}', field '{1}'; files in the preview {2} (expected 1: only {3}1.txt)" -f (Esc $mask), (Esc $held), $pc, (Esc $Cyr))
        Close-Renamer $id $dlg
    }
    catch { Row 'ren-mask' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'ren-mask' $id $before } }
}

function Run-RenManual([string]$Case, [string]$Old, [string]$New) {
    $d = $Root + '\ren\man-' + $Case; NewDir $d
    Put ($d + '\' + $Old) 'OLD'
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        $dlg = Open-Renamer $id
        if ($dlg -eq [IntPtr]::Zero) { Row ('ren-man-' + $Case) 'MAN' 'FAIL' ('the Renamer dialog did not open; ' + $script:LastOpenDiag); return }
        Set-Mask $dlg '*.*'
        Click (Kid $dlg 105 'Button')   # Manual
        Start-Sleep -Milliseconds 1500
        $ed = Kid $dlg 125 'Edit'
        $shown = ([Drv098f]::GetText($ed, 5000)).TrimEnd("`r", "`n")
        [void][Drv098f]::SetText($ed, $New, 5000)
        $held = [Drv098f]::GetText($ed, 5000)
        Start-Sleep -Milliseconds 1500
        Click (Kid $dlg 1 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 20 @(7, 2) @($dlg)
        $ok = ((Get ($d + '\' + $New)) -ceq 'OLD') -and ($null -eq (Get ($d + '\' + $Old)))
        if ($Fixed) { $v = V ($ok -and $shown -ceq $Old -and $held -ceq $New) } else { $v = V (-not ($ok -and $shown -ceq $Old)) }
        Row ('ren-man-' + $Case) 'MAN' $v ("manual edit showed '{0}' (exact {1}); set '{2}', field '{3}'; renamed exactly {4}; boxes: {5}; folder: {6}" -f (Esc $shown), ($shown -ceq $Old), (Esc $New), (Esc $held), $ok, (Msgs2 $ans), (Names $d))
        Close-Renamer $id $dlg
    }
    catch { Row ('ren-man-' + $Case) 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P ('ren-man-' + $Case) $id $before } }
}

function Run-RenLong {
    $d = $Root + '\ren\long'; NewDir $d
    Put ($d + '\src.txt') 'SRC'
    $name = ([string][char]0x65E5 * 200) + '.txt'
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        $dlg = Open-Renamer $id
        if ($dlg -eq [IntPtr]::Zero) { Row 'ren-long' 'LONG' 'FAIL' ('the Renamer dialog did not open; ' + $script:LastOpenDiag); return }
        Set-Mask $dlg 'src.txt'
        [void][Drv098f]::SetText((Kid $dlg 106 'ComboBox'), $name, 5000)
        Start-Sleep -Milliseconds 1500
        Click (Kid $dlg 1 'Button')
        Start-Sleep -Milliseconds 1200
        $ans = Answer $id 15 @(1, 7, 2) @($dlg)
        $renamed = $null -eq (Get ($d + '\src.txt'))
        $tooLong = (Msgs2 $ans).Contains((Esc $TooLongText))
        if ($Fixed) { $v = V ((-not $renamed) -and $tooLong) } else { $v = V (-not $tooLong) }
        Row 'ren-long' 'LONG' $v ("New name of {0} units / {1} UTF-8 bytes (the field's buffer: 520): renamed {2}; boxes: {3}; folder: {4}" -f $name.Length, (U8Len $name), $renamed, (Msgs2 $ans), (Names $d))
        Close-Renamer $id $dlg
    }
    catch { Row 'ren-long' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'ren-long' $id $before } }
}

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
# ---- common: F3 viewers, the file dialogs ------------------------------------------------
# a key posted to the left panel's list (the 096/097 method: Enter into an archive needs it posted)
function PostKey([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv104]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv104]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L)
}
function Focus-File([int]$Id, [string]$Full) { [void](Do-ChangeDir $Id $Full); [void](Serve $Id 8); Sync $Id }
# F3 on the focused file: the new top-level window (a viewer) or zero
function Open-Viewer([int]$Id, [double]$Seconds = 20) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 742
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -ne '#32770' }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 1500; return $w }
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}
function Close-Viewer([int]$Id, [IntPtr]$W) {
    if ($W -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($W)) { return }
    [void][Drv098f]::PostMessageW($W, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($W)) { Start-Sleep -Milliseconds 100 }
    [void](Answer $Id 3 @(6, 1))
}
# the common open/save dialog that appears after $Action: its file name field set to $Full, Open/Save
function Drive-FileDialog([int]$Id, [scriptblock]$Action, [string]$Full) {
    $known = Get-Tops $Id
    & $Action
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $pre = @()
    while ($sw.Elapsed.TotalSeconds -lt 15 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($c) {
            Start-Sleep -Milliseconds 1200
            if (@([Drv098f]::Kids($c) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1148 -or [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148 }).Count) { $od = $c; break }
            $pre += (WinDesc $c)   # a question before the dialog (PictView's alpha channel): Yes
            $y = Buttons $c | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($y) { Click $y } else { Close-Win $c }
            $known = @($known) + @($c); Start-Sleep -Milliseconds 800; continue
        }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) { return ('no file dialog appeared; before it: ' + ($pre -join ' || ')) }
    Start-Sleep -Milliseconds 300
    $edits = @([Drv098f]::Kids($od) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) })
    $fn = @($edits | Where-Object { [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148 -or [Drv098f]::GetDlgCtrlID($_) -eq 1148 }) | Select-Object -First 1
    if (-not $fn -and $edits.Count) { $fn = $edits[-1] }
    if (-not $fn) { $t = 'no file name field in ' + (WinDesc $od); Close-Win $od; return $t }
    [void][Drv098f]::SetText($fn, $Full, 5000)
    $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
    if ($ok) { Click $ok } else { Post-Cmd $od 1 }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
    return ('file dialog unicode ' + [Drv104]::IsWindowUnicode($od))
}

# ---- Database Viewer: File > Open ---------------------------------------------------------
function Run-DbvOpen {
    $d = $Root + '\dbv'; NewDir $d
    Put ($d + '\start.csv') "a,b`r`nstart,1`r`n"
    Put ($d + '\' + $Voila + '.csv') "a,b`r`nNAMED,1`r`n"
    Put ($d + '\voila.csv') "a,b`r`nDECOY,1`r`n"
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id ($d + '\start.csv')
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'dbv-open' 'OPEN' 'FAIL' 'F3 on start.csv opened no viewer'; return }
        $t0 = [Drv104]::Internal($w)
        $how = Drive-FileDialog $id { Post-Cmd $w 10001 } ($d + '\' + $Voila + '.csv')
        Start-Sleep -Milliseconds 2000
        $ans = Answer $id 5 @(1) @()
        $t = [Drv104]::Internal($w)
        $named = $t.Contains($Voila + '.csv'); $decoy = $t.Contains('voila.csv')
        if ($Fixed) { $v = V ($named -and -not $decoy) } else { $v = V (-not $named) }
        Row 'dbv-open' 'OPEN' $v ("viewer '{0}' -> Open '{1}': {2}; title now '{3}'; names the file {4}, the decoy {5}; boxes: {6}" -f (Esc $t0), (Esc ($Voila + '.csv')), $how, (Esc $t), $named, $decoy, (Msgs2 $ans))
        Close-Viewer $id $w
    }
    catch { Row 'dbv-open' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'dbv-open' $id $before } }
}

# ---- PictView: Copy To + Browse, Save As ---------------------------------------------------
function Put-Png([string]$p, [int]$Seed) {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object Drawing.Bitmap 16, 16, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
    for ($x = 0; $x -lt 16; $x++) { for ($y = 0; $y -lt 16; $y++) { $bmp.SetPixel($x, $y, [Drawing.Color]::FromArgb(($x * 16 + $Seed) % 256, ($y * 16) % 256, $Seed % 256)) } }
    $ms = New-Object IO.MemoryStream
    $fmt = [Drawing.Imaging.ImageFormat]::Png; if ($p.EndsWith('.bmp')) { $fmt = [Drawing.Imaging.ImageFormat]::Bmp }
    $bmp.Save($ms, $fmt); $bmp.Dispose()
    [IO.File]::WriteAllBytes($LP + $p, $ms.ToArray())
}
function Run-PvCopyTo {
    $d = $Root + '\pv'; NewDir $d
    $tgt = $d + '\' + $Voila; $dec = $d + '\voila'
    NewDir $tgt; NewDir $dec
    Put-Png ($d + '\img.png') 7
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id ($d + '\img.png')
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'pv-copyto' 'COPYTO' 'FAIL' 'F3 on img.png opened no viewer'; return }
        $known = Get-Tops $id
        Post-Cmd $w 194   # CMD_IMG_COPYTO
        $cd = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 10 -and $cd -eq [IntPtr]::Zero) { $cd = @(Get-Tops $id | Where-Object { $known -notcontains $_ -and ((Kid $_ 2406 'Edit') -ne $null) }) | Select-Object -First 1; if (-not $cd) { $cd = [IntPtr]::Zero; Start-Sleep -Milliseconds 200 } }
        if ($cd -eq [IntPtr]::Zero) { Row 'pv-copyto' 'COPYTO' 'FAIL' ('the Copy To dialog did not open; new windows: ' + ((@(Get-Tops $id | Where-Object { $known -notcontains $_ }) | ForEach-Object { WinDesc $_ }) -join ' || ')); Close-Viewer $id $w; return }
        Click (Kid $cd 2401 'Button'); Start-Sleep -Milliseconds 300
        $el = Kid $cd 2406 'Edit'
        [void][Drv098f]::SetText($el, $tgt, 5000)
        $known2 = Get-Tops $id
        Click (Kid $cd 2411 'Button')   # Browse
        $bd = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 10 -and $bd -eq [IntPtr]::Zero) { $bd = @(Get-Tops $id | Where-Object { $known2 -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1; if (-not $bd) { $bd = [IntPtr]::Zero; Start-Sleep -Milliseconds 200 } }
        $browse = 'no folder dialog'
        if ($bd -ne [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 2000
            $browse = 'folder dialog unicode ' + [Drv104]::IsWindowUnicode($bd) + " '" + (Esc ([Drv104]::Internal($bd))) + "'"
            $ok = Buttons $bd | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
            if ($ok) { Click $ok } else { Post-Cmd $bd 1 }
            $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($bd)) { Start-Sleep -Milliseconds 100 }
        }
        Start-Sleep -Milliseconds 500
        $field = [Drv098f]::GetText($el, 5000)
        Click (Kid $cd 1 'Button')
        Start-Sleep -Milliseconds 2500
        $ans = Answer $id 10 @(6, 1) @($w)
        $inT = [IO.File]::Exists($LP + $tgt + '\img.png'); $inD = [IO.File]::Exists($LP + $dec + '\img.png')
        $fieldOk = $field.TrimEnd('\') -ceq $tgt
        if ($Fixed) { $v = V ($fieldOk -and $inT -and -not $inD) } else { $v = V (-not ($fieldOk -and $inT -and -not $inD)) }
        Row 'pv-copyto' 'COPYTO' $v ("field set to ...\{0}; Browse: {1}; field after Browse '{2}' (exact {3}); copied into ...\{0}: {4}, into the decoy ...\voila: {5}; boxes: {6}" -f (Esc $Voila), $browse, (Tail $field 30), $fieldOk, $inT, $inD, (Msgs2 $ans))
        Close-Viewer $id $w
    }
    catch { Row 'pv-copyto' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'pv-copyto' $id $before } }
}
function Run-PvSaveAs {
    $d = $Root + '\pvs'; NewDir $d
    Put-Png ($d + '\img.png') 9
    Put ($d + '\voila.bmp') 'DECOY'
    Put ($d + '\exist.bmp') 'EXISTING'
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id ($d + '\img.png')
        $w = Open-Viewer $id
        if ($w -eq [IntPtr]::Zero) { Row 'pv-saveas' 'SAVEAS' 'FAIL' 'F3 on img.png opened no viewer'; return }
        # 1) a new name whose best-fit look-alike exists: no question about the decoy; every answer No
        $how = Drive-FileDialog $id { Post-Cmd $w 124 } ($d + '\' + $Voila + '.bmp')
        $ans = Answer $id 12 @(7, 2, 1) @($w)
        Start-Sleep -Milliseconds 500
        foreach ($x in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 500 }   # a reopened save dialog: Cancel
        $askedDecoy = (Msgs2 $ans) -match 'voila\.bmp'
        $decOk = (Get ($d + '\voila.bmp')) -ceq 'DECOY'
        if ($Fixed) { $v = V ((-not $askedDecoy) -and $decOk) } else { $v = V ($askedDecoy) }
        Row 'pv-saveas' 'SAVEAS' $v ("Save As '{0}': {1}; a question about the decoy voila.bmp {2}; decoy intact {3}; boxes: {4}; folder: {5}" -f (Esc ($Voila + '.bmp')), $how, $askedDecoy, $decOk, (Msgs2 $ans), (Names $d))
        # 2) FINDING: Save As onto an existing file, "replace?" answered Yes
        $how = Drive-FileDialog $id { Post-Cmd $w 124 } ($d + '\exist.bmp')
        $ans = Answer $id 12 @(6, 1) @($w)
        Start-Sleep -Milliseconds 500
        foreach ($x in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 500 }
        $ex = Get ($d + '\exist.bmp')
        Row 'pv-saveas' 'FINDING' 'INFO' ("Save As onto the existing exist.bmp, 'replace?' Yes: exist.bmp {0}; boxes: {1}" -f $(if ($null -eq $ex) { 'DELETED' } elseif ($ex -ceq 'EXISTING') { 'unchanged' } else { 'rewritten (' + $ex.Length + ' chars)' }), (Msgs2 $ans))
        Close-Viewer $id $w
    }
    catch { Row 'pv-saveas' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'pv-saveas' $id $before } }
}

# ---- archives: CAB next volume, ZIP password label ----------------------------------------
function Run-UncNext {
    $d = $Root + '\cab'; $src = $d + '\src'; $tgt = $d + '\' + $Voila; $dec = $d + '\voila'; $out = $d + '\out'
    foreach ($x in @($src, $tgt, $dec, $out)) { NewDir $x }
    $rnd = New-Object Random 104
    $bytes = New-Object byte[] 150000; $rnd.NextBytes($bytes); [IO.File]::WriteAllBytes($LP + $src + '\big.bin', $bytes)
    $ddf = @('.Set CabinetNameTemplate=a*.cab', ('.Set DiskDirectoryTemplate=' + $src), '.Set MaxDiskSize=61440', '.Set Cabinet=on', '.Set Compress=off', '.Set RptFileName=nul', '.Set InfFileName=nul', ('"' + $src + '\big.bin"'))
    [IO.File]::WriteAllLines($src + '\x.ddf', $ddf)
    $mc = Cmd ('cd /d "' + $src + '" && makecab /f "' + $src + '\x.ddf"')
    $cabs = @([IO.Directory]::GetFiles($src, 'a*.cab') | Sort-Object)
    if ($cabs.Count -lt 2) { Row 'unc-next' 'NEXT' 'FAIL' ('makecab made ' + $cabs.Count + ' cabinets: ' + $mc.Text); return }
    [IO.File]::Copy($cabs[0], $tgt + '\a1.cab')
    for ($i = 1; $i -lt $cabs.Count; $i++) { [IO.File]::Copy($cabs[$i], $dec + '\' + [IO.Path]::GetFileName($cabs[$i])) }
    $id = 0; $before = Reports
    try {
        $id = Start-P $tgt $out
        Key $id 0x23   # End: a1.cab, the only file
        PostKey $id 0x0D; Start-Sleep -Milliseconds 1500; [void](Serve $id 8); Sync $id   # Enter: into the cabinet
        $inside = Get-Loc $id
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 1500; Sync $id   # select all; the enablers refresh on idle (101)
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 727   # Copy (F5)
        $nv = [IntPtr]::Zero; $fieldNow = $null; $msgs = New-Object System.Collections.ArrayList
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30) {
            foreach ($h in @(Get-Tops $id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) })) {
                if ((Kid $h 101 'Edit') -ne $null -and (Kid $h 102 'Button') -ne $null) { $nv = $h; break }
                $d2 = WinDesc $h
                if ($msgs -notcontains $d2) { [void]$msgs.Add($d2) }
                $ok = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
                if ($ok) { Click $ok; Start-Sleep -Milliseconds 800 }
            }
            if ($nv -ne [IntPtr]::Zero) { break }
            Start-Sleep -Milliseconds 300
        }
        if ($nv -eq [IntPtr]::Zero) { Row 'unc-next' 'NEXT' 'FAIL' ('the next-volume dialog did not appear; panel after Enter: ' + (Esc $inside) + '; boxes: ' + ($msgs -join ' || ')); return }
        Start-Sleep -Milliseconds 800
        $fieldNow = [Drv098f]::GetText((Kid $nv 101 'Edit'), 5000)
        Click (Kid $nv 1 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 10 @(1) @($nv)
        foreach ($x in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) { Post-Cmd $x 2; Start-Sleep -Milliseconds 600 }
        [void](Answer $id 6 @(2, 7, 1))
        $got = [IO.File]::Exists($LP + $out + '\big.bin')
        $exact = $fieldNow.TrimEnd('\') -ceq $tgt
        $notFound = (Msgs2 $ans) -match 'not found'
        if ($Fixed) { $v = V ($exact -and $notFound -and -not $got) } else { $v = V (-not $exact) }
        Row 'unc-next' 'NEXT' $v ("{0} cabinets; the folder field '{1}' (exact {2}); OK: boxes {3}; extracted from the decoy's volumes: {4}" -f $cabs.Count, (Tail $fieldNow 30), $exact, (Msgs2 $ans), $got)
    }
    catch { Row 'unc-next' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'unc-next' $id $before } }
}
function Run-ZipPwd {
    if (-not (Test-Path -LiteralPath $SevenZip)) { Row 'zip-pwd' 'LABEL' 'NOT DRIVEN' ('7-Zip not found: ' + $SevenZip); return }
    $d = $Root + '\zip'; $src = $d + '\src'; $out = $d + '\out'; $arcDir = $d + '\arc'; NewDir $src; NewDir $out; NewDir $arcDir
    $item = $Cyr + '.txt'
    Put ($src + '\' + $item) 'SECRET'
    $r = Cmd ('cd /d "' + $src + '" && "' + $SevenZip + '" a -tzip -pTest104 -mem=ZipCrypto "' + $arcDir + '\enc.zip" *')
    if (-not [IO.File]::Exists($arcDir + '\enc.zip')) { Row 'zip-pwd' 'LABEL' 'FAIL' ('7z failed: ' + $r.Text); return }
    $id = 0; $before = Reports
    try {
        $id = Start-P $arcDir $out
        Key $id 0x23   # End: enc.zip, the only file
        PostKey $id 0x0D; Start-Sleep -Milliseconds 1500; [void](Serve $id 8); Sync $id   # Enter: into the archive
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 1500; Sync $id
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 727   # Copy (F5)
        $pd = [IntPtr]::Zero; $msgs = New-Object System.Collections.ArrayList
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 30 -and $pd -eq [IntPtr]::Zero) {
            foreach ($h in @(Get-Tops $id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) })) {
                if ((Kid $h 120 'Edit') -ne $null -and (Kid $h 121 $null) -ne $null) { $pd = $h; break }
                $d2 = WinDesc $h; if ($msgs -notcontains $d2) { [void]$msgs.Add($d2) }
                $ok = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
                if ($ok) { Click $ok; Start-Sleep -Milliseconds 800 }
            }
            Start-Sleep -Milliseconds 300
        }
        if ($pd -eq [IntPtr]::Zero) { Row 'zip-pwd' 'LABEL' 'FAIL' ('no password dialog; boxes: ' + ($msgs -join ' || ') + '; panel: ' + (Esc (Get-Loc $id)) + '; new windows: ' + ((@(Get-Tops $id | Where-Object { $known -notcontains $_ }) | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        Start-Sleep -Milliseconds 600
        $lbl = Kid $pd 121 $null
        $t = [Drv098f]::GetText($lbl, 5000)
        $uni = [Drv104]::IsWindowUnicode($lbl)
        Post-Cmd $pd 2
        Start-Sleep -Milliseconds 800
        [void](Answer $id 8 @(2, 7, 1))
        $exact = $t -ceq $item
        if ($Fixed) { $v = V ($exact -and $uni) } else { $v = V (-not $exact) }
        Row 'zip-pwd' 'LABEL' $v ("password dialog label '{0}' (exact {1}; label window Unicode {2})" -f (Esc $t), $exact, $uni)
    }
    catch { Row 'zip-pwd' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'zip-pwd' $id $before } }
}

# ---- Undelete: Connect, image file ---------------------------------------------------------
function Run-UndImage {
    $d = $Root + '\und'; NewDir $d
    Put ($d + '\voila.ima') ('DECOY' * 1000)   # .ima: .img files are opened as disk images by another plug-in
    Put ($d + '\' + $Cyr + '.ima') ('X' * 5000)
    $id = 0; $before = Reports
    try {
        $id = Start-P $d
        Focus-File $id ($d + '\' + $Cyr + '.ima')
        $known = Get-Tops $id
        [void][Drv104]::ModKey((Get-LeftList $id), 0x55, 3)   # Ctrl+Shift+U
        $cd = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15 -and $cd -eq [IntPtr]::Zero) { $cd = @(Get-Tops $id | Where-Object { $known -notcontains $_ -and ((Kid $_ 1105 'Edit') -ne $null) }) | Select-Object -First 1; if (-not $cd) { $cd = [IntPtr]::Zero; Start-Sleep -Milliseconds 200 } }
        if ($cd -eq [IntPtr]::Zero) { Row 'und-image' 'IMAGE' 'FAIL' ('the Undelete connect dialog did not open; new windows: ' + ((@(Get-Tops $id | Where-Object { $known -notcontains $_ }) | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        Start-Sleep -Milliseconds 800
        $ed = Kid $cd 1105 'Edit'
        $pre = [Drv098f]::GetText($ed, 5000)
        $preOk = $pre -ceq ($d + '\' + $Cyr + '.ima')
        if ($Fixed) { $v = V $preOk } else { $v = V (-not $preOk) }
        Row 'und-image' 'PREFILL' $v ("the image field filled from the focused file: '{0}' (exact {1})" -f (Tail $pre 40), $preOk)
        $cb = Kid $cd 1104 'Button'
        if ([Drv104]::SendR($cb, 0x00F0, 0, 0) -ne 1) { Click $cb; Start-Sleep -Milliseconds 300 }   # BM_GETCHECK
        [void][Drv098f]::SetText($ed, ($d + '\' + $Voila + '.ima'), 5000)
        Click (Kid $cd 1 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 10 @(1, 2) @($cd)
        if ([Drv098f]::IsWindow($cd)) { Post-Cmd $cd 2; Start-Sleep -Milliseconds 600 }
        [void](Answer $id 5 @(1, 2))
        $nf = (Msgs2 $ans) -match 'was not found'
        if ($Fixed) { $v = V $nf } else { $v = V (-not $nf) }
        Row 'und-image' 'IMAGE' $v ("image field set to ...\{0}.ima (missing; the decoy voila.ima exists): boxes {1}" -f (Esc $Voila), (Msgs2 $ans))
    }
    catch { Row 'und-image' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'und-image' $id $before } }
}

# ---- FTP Connect dialog: a refused field (review B1) ----------------------------------------
$FtpBm = 'HKCU:\Software\Tandem Commander\0.1\Plugins Configuration\FTP\Bookmarks\1'
function Ftp-Fixture([int]$Port) {
    if (-not (Test-Path $FtpBm)) { [void](New-Item -Path $FtpBm -Force) }
    Set-ItemProperty -Path $FtpBm -Name 'Name' -Value 'B104' -Type String
    Set-ItemProperty -Path $FtpBm -Name 'Address' -Value '127.0.0.1' -Type String
    Set-ItemProperty -Path $FtpBm -Name 'User' -Value 'olduser' -Type String
    Set-ItemProperty -Path $FtpBm -Name 'Anonymous' -Value 0 -Type DWord
    Set-ItemProperty -Path $FtpBm -Name 'Save Password' -Value 1 -Type DWord
    Set-ItemProperty -Path $FtpBm -Name 'Port' -Value $Port -Type DWord
}
function Ftp-Stored {
    $k = Get-Item -LiteralPath $FtpBm -ErrorAction SilentlyContinue
    if (-not $k) { return [pscustomobject]@{ User = '<no bookmark>'; Pwd = '<no bookmark>' } }
    $p = $k.GetValue('PasswordS'); $e = $k.GetValue('PasswordE')
    $ph = '<none>'
    if ($p) { $ph = 'S:' + (($p | ForEach-Object { '{0:x2}' -f $_ }) -join '') } elseif ($e) { $ph = 'E:' + (($e | ForEach-Object { '{0:x2}' -f $_ }) -join '') }
    return [pscustomobject]@{ User = [string]$k.GetValue('User'); Pwd = $ph }
}
function Open-FtpConnect([int]$Id) {
    $known = Get-Tops $Id
    [void][Drv104]::ModKey((Get-LeftList $Id), 0x46, 3)   # Ctrl+Shift+F
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and ((Kid $_ 561 $null) -ne $null) }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 1000; return $w }
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}
# selects bookmark 1, focuses field $Ctl, sets $Text, presses $Button; returns what happened
function Ftp-Step([int]$Id, [int]$Ctl, [string]$Text, [int]$Button, [switch]$KeepOpen) {
    $dlg = Open-FtpConnect $Id
    if ($dlg -eq [IntPtr]::Zero) { return [pscustomobject]@{ Ok = $false; Facts = 'the FTP Connect dialog did not open'; Stayed = $false; Boxes = '' } }
    $lb = Kid $dlg 561 $null
    [void][Drv104]::SendR($lb, 0x0186, 1, 0)                                   # LB_SETCURSEL 1
    [void][Drv104]::SendR($dlg, 0x0111, ((1 -shl 16) -bor 561), $lb.ToInt64())  # LBN_SELCHANGE
    Start-Sleep -Milliseconds 500
    $ed = Kid $dlg $Ctl 'Edit'
    [void][Drv104]::SendR($dlg, 0x0028, $ed.ToInt64(), 1)                       # WM_NEXTDLGCTL: focus the field
    [void][Drv098f]::SetText($ed, $Text, 5000)
    $held = [Drv098f]::GetText($ed, 5000)
    Start-Sleep -Milliseconds 300
    Click (Kid $dlg $Button 'Button')
    Start-Sleep -Milliseconds 1500
    $ans = Answer $Id 15 @(1, 2, 7) @($dlg)
    $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
    $fieldAfter = ''; if ($stayed) { $fieldAfter = [Drv098f]::GetText($ed, 5000) }
    if ($stayed -and -not $KeepOpen) { Post-Cmd $dlg 2; Start-Sleep -Milliseconds 800; [void](Answer $Id 5 @(6, 1, 2)) }
    return [pscustomobject]@{ Ok = $true; Stayed = $stayed; Boxes = (Msgs2 $ans); Held = ($held -ceq $Text); FieldKept = ($fieldAfter -ceq $Text) }
}
function Run-FtpB1 {
    $port = 18104
    $log = $Root + '\ftplog.txt'
    NewDir $Root
    $srv = Start-Process -FilePath $Python -ArgumentList @(('"' + (Join-Path $PSScriptRoot 'ftplog_server.py') + '"'), $port, ('"' + $log + '"')) -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 1500
    $c40 = [string][char]0x010D * 40; $c60 = [string][char]0x010D * 60
    try {
        Ftp-Fixture $port
        # OK40: 40 x U+010D (80 bytes) fits the 101-byte buffer - stored
        $id = 0; $before = Reports
        try {
            $id = Start-P $StartDir
            $r = Ftp-Step $id 568 $c40 575
            End-P 'ftp-b1' $id $before; $id = 0
            $s40 = Ftp-Stored
            if (-not $r.Ok) { Row 'ftp-b1' 'OK40' 'FAIL' $r.Facts }
            else { Row 'ftp-b1' 'OK40' (V ((-not $r.Stayed) -and $s40.Pwd -ne '<none>')) ("password 40 x U+010D (80 bytes), Close: dialog stayed {0}; boxes: {1}; stored password {2} bytes" -f $r.Stayed, $r.Boxes, $(if ($s40.Pwd -eq '<none>') { 'NONE' } else { ($s40.Pwd.Length - 2) / 2 })) }
        }
        finally { if ($id) { End-P 'ftp-b1' $id $before } }
        # LONGPWD: 60 x U+010D (120 bytes) does not fit: refused, the stored password stays
        $id = 0; $before = Reports
        try {
            $id = Start-P $StartDir
            $r = Ftp-Step $id 568 $c60 575
            End-P 'ftp-b1' $id $before; $id = 0
            $s = Ftp-Stored
            $same = $s.Pwd -ceq $s40.Pwd
            $refused = $r.Boxes.Contains((Esc $TooLongText))
            if ($Fixed) { $v = V ($r.Stayed -and $refused -and $same) } else { $v = V (-not $same) }
            Row 'ftp-b1' 'LONGPWD' $v ("password 60 x U+010D (120 bytes), Close: dialog stayed {0} (a password field's text cannot be read from another process: {1}); boxes: {2}; after Cancel + exit the stored password is unchanged {3} ({4})" -f $r.Stayed, $r.FieldKept, $r.Boxes, $same, $(if ($s.Pwd -eq '<none>') { 'NONE STORED' } else { '' + (($s.Pwd.Length - 2) / 2) + ' bytes' }))
        }
        finally { if ($id) { End-P 'ftp-b1' $id $before } }
        # LONGUSER: a user name of 60 x U+010D: refused, the stored user name stays
        $id = 0; $before = Reports
        try {
            $id = Start-P $StartDir
            $r = Ftp-Step $id 567 $c60 575
            End-P 'ftp-b1' $id $before; $id = 0
            $s = Ftp-Stored
            $refused = $r.Boxes.Contains((Esc $TooLongText))
            if ($Fixed) { $v = V ($r.Stayed -and $refused -and $s.User -ceq 'olduser') } else { $v = V ($s.User -cne 'olduser') }
            Row 'ftp-b1' 'LONGUSER' $v ("user name 60 x U+010D, Close: dialog stayed {0}; boxes: {1}; stored user name '{2}'" -f $r.Stayed, $r.Boxes, (Tail $s.User 30))
        }
        finally { if ($id) { End-P 'ftp-b1' $id $before } }
        # CONNECT: the 60-character password and Connect: no connection with an empty / old value
        Ftp-Fixture $port
        $id = 0; $before = Reports
        try {
            $id = Start-P $StartDir
            $n0 = 0; if (Test-Path -LiteralPath $log) { $n0 = @(Get-Content -LiteralPath $log).Count }
            $r = Ftp-Step $id 568 $c60 1
            Start-Sleep -Milliseconds 1500
            [void](Answer $id 8 @(2, 7, 1))
            $lines = @(); if (Test-Path -LiteralPath $log) { $lines = @(Get-Content -LiteralPath $log | Select-Object -Skip $n0) }
            $pass = @($lines | Where-Object { $_ -like 'PASS*' })
            $refused = $r.Boxes.Contains((Esc $TooLongText))
            if ($Fixed) { $v = V ($r.Stayed -and $refused -and $pass.Count -eq 0) } else { $v = V ($pass.Count -gt 0) }
            Row 'ftp-b1' 'CONNECT' $v ("password 60 x U+010D, Connect: dialog stayed {0}; boxes: {1}; the server received: {2}" -f $r.Stayed, (Tail $r.Boxes 200), $(if ($lines.Count) { $lines -join ' / ' } else { 'nothing (no connection)' }))
        }
        finally { if ($id) { End-P 'ftp-b1' $id $before } }
        # LEGACY (re-review NIT 1): a password the build before stored in code-page form (60 bytes
        # 0xE8 for 60 x U+010D - over 100 bytes as UTF-8) is used unchanged: the field is only
        # tabbed through, Connect sends the stored bytes, no "too long"
        if ($OldExe -and $Fixed) {
            Ftp-Fixture $port
            $id = 0; $before = Reports; $exeSaved = $Exe
            try {
                $script:Exe = (Resolve-Path -LiteralPath $OldExe).Path
                $id = Start-P $StartDir
                $r0 = Ftp-Step $id 568 $c60 575
                End-P 'ftp-b1' $id $before; $id = 0
            }
            finally { if ($id) { End-P 'ftp-b1' $id $before }; $script:Exe = $exeSaved }
            $sOld = Ftp-Stored
            $id = 0; $before = Reports
            try {
                $id = Start-P $StartDir
                $n0 = 0; if (Test-Path -LiteralPath $log) { $n0 = @(Get-Content -LiteralPath $log).Count }
                $dlg = Open-FtpConnect $id
                $lb = Kid $dlg 561 $null
                [void][Drv104]::SendR($lb, 0x0186, 1, 0)
                [void][Drv104]::SendR($dlg, 0x0111, ((1 -shl 16) -bor 561), $lb.ToInt64())
                Start-Sleep -Milliseconds 500
                [void][Drv104]::SendR($dlg, 0x0028, (Kid $dlg 568 'Edit').ToInt64(), 1)   # into the password field
                [void][Drv104]::SendR($dlg, 0x0028, (Kid $dlg 567 'Edit').ToInt64(), 1)   # and out of it
                Start-Sleep -Milliseconds 300
                Click (Kid $dlg 1 'Button')
                Start-Sleep -Milliseconds 2500
                $ans = Answer $id 10 @(2, 7, 1) @($dlg)
                $lines = @(); if (Test-Path -LiteralPath $log) { $lines = @(Get-Content -LiteralPath $log | Select-Object -Skip $n0) }
                $pass = @($lines | Where-Object { $_ -like 'PASS*' })
                $sent60 = @($pass | Where-Object { $_ -like ('PASS len=60 hex=' + ('e8' * 60) + '*') }).Count -gt 0
                $noRefusal = -not (Msgs2 $ans).Contains((Esc $TooLongText))
                Row 'ftp-b1' 'LEGACY' (V ($sent60 -and $noRefusal)) ("a password stored by the build before (code-page form, {0} bytes stored), field tabbed through, Connect: refused {1}; the server received: {2}" -f $(if ($sOld.Pwd -eq '<none>') { 'NONE' } else { ($sOld.Pwd.Length - 2) / 2 }), (-not $noRefusal), $(if ($lines.Count) { (($lines | Select-Object -First 2) -join ' / ') } else { 'nothing' }))
            }
            finally { if ($id) { End-P 'ftp-b1' $id $before } }
        }
        elseif ($Fixed) { Row 'ftp-b1' 'LEGACY' 'NOT DRIVEN' 'no -OldExe given (the build before stores the code-page form)' }
    }
    catch { Row 'ftp-b1' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($srv -and -not $srv.HasExited) { Stop-Process -Id $srv.Id -Force } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc104_pn_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    Make-Fixtures
    Set-Config
    Out ("plugnames_probe (feature 104), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ''
    if (Want 'ren-new') { foreach ($c in $RenCases) { Run-RenNew $c } }
    if (Want 'ren-mask') { Run-RenMask }
    if (Want 'ren-man') { Run-RenManual 'cz' ($Clanek + '.txt') ($Cyr + '-2.txt'); Run-RenManual 'cjk' ($Cjk + '.txt') ($Cjk + '-2.txt') }
    if (Want 'ren-long') { Run-RenLong }
    if (Want 'dbv-open') { Run-DbvOpen }
    if (Want 'pv-copyto') { Run-PvCopyTo }
    if (Want 'pv-saveas') { Run-PvSaveAs }
    if (Want 'unc-next') { Run-UncNext }
    if (Want 'zip-pwd') { Run-ZipPwd }
    if (Want 'und-image') { Run-UndImage }
    if (Want 'ftp-b1') { Run-FtpB1 }
    if (-not $Only) {
        foreach ($nd in @('FTP file dialogs (save log / welcome text, server-type export and import, parser test): no FTP server on the hidden desktop; the same SplGetFileNameU8 as dbv-open',
                          'ZIP change-disk Browse (multi-volume ZIP on removable media): the same SplGetFileNameU8',
                          'Undelete restore target and temp folder Browse: the same SplBrowseForFolderU8 as pv-copyto; restore needs EFS-encrypted deleted files',
                          'regedt Find typing and the external editor (needs a configured editor), renamer editor $(SalDir)',
                          'SFTP field overflow (ConnectReadFields): needs the SFTP container',
                          'an installation folder outside the code page (exif.dll, $(SalDir))')) { Row 'nd' 'ROUTE' 'NOT DRIVEN' $nd }
    }
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
