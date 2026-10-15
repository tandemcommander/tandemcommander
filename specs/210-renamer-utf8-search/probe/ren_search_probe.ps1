<#
.SYNOPSIS
    Feature 210 probe: the Renamer's search / replace, whole words and cut arguments work on the
    letters of UTF-8 names - the code-page byte tables never match or cut another letter.

.DESCRIPTION
    Rows (the Renamer on one file; new name $(OriginalName) unless said; Search 108, Replace 109,
    the check boxes Case sensitive 112, Whole words 113, Regular expression 115 set per row):
      bm-wrong  "C-dot x.txt" (U+010A), search "E-caron" (U+011A) -> "E", case-insensitive: the
                code-page fold made the continuation bytes 8A / 9A equal - PASS = the name unchanged
      bm-cz     "z-caron l u t-caron.txt", search "Z-caron" -> "Z", case-insensitive: "Zlut-caron.txt"
      re-cz     the same with a regular expression
      re-wrong  bm-wrong with a regular expression
      re-sub    "Z-caron l u t-caron.txt", expression "^(z-caron)" -> "[$1]", case-insensitive: the
                subexpression is the NAME's letter ("[Z-caron]..."), not its folded copy
      bm-cs     the control: case-sensitive "z-caron" -> "Z"
      ww        "z-l-u-t-y k-u-ring-n-caron.txt", whole words "k-u-ring-n-caron" -> "pes"
      cut       new name "$(OriginalName:0,1)_.txt" on "Z-caron l u t-caron.txt": "Z-caron_.txt" (the
                first LETTER, not its first byte)
    Expected names are spelled with code points (the probe is ASCII). Driver of 199's probe.
    MUST run through tools\\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
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
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'RUN' 'FAIL' ('the Renamer dialog did not open; ' + $script:LastOpenDiag); return }
        $preview = Preview-Count $dlg
        if ($c.RelPath) { [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]608, [IntPtr]::Zero); Start-Sleep -Milliseconds 1000 }   # CMD_RELATIVEPATH: a new name with folders
        if ($c.Search) {
            foreach ($k in @($c.Checks.Keys)) {   # the check boxes to the wanted state
                $cb = Kid $dlg ([int]$k) 'Button'
                if ([Drv104]::SendR($cb, 0x00F0, 0, 0) -ne [int][bool]$c.Checks[$k]) { [void][Drv098f]::PostMessageW($cb, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 400 }
            }
            [void][Drv098f]::SetText((Kid $dlg 108 'ComboBox'), $c.Search, 5000)
            [void][Drv098f]::SetText((Kid $dlg 109 'ComboBox'), $c.Replace, 5000)
            Start-Sleep -Milliseconds 600
        }
        if ($c.CaseCombos) {   # the name's case "lower" (item 1), the extension's "upper" (item 2), CBN_SELENDOK
            foreach ($cb in @(@(116, 1), @(117, 2))) {
                $h = Find-Ctl $dlg $cb[0]
                [void][Drv098f]::Send($h, 0x014E, $cb[1], 0, 5000)
                [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]((9 -shl 16) -bor $cb[0]), $h)
            }
            Start-Sleep -Milliseconds 800
        }
        $nn = Kid $dlg 106 'ComboBox'
        [void][Drv098f]::SetText($nn, $c.NewName, 5000)
        Start-Sleep -Milliseconds 1500
        Click (Kid $dlg 1 'Button')
        Start-Sleep -Milliseconds 1500
        $ans = Answer $id 20 $c.Answers @($dlg)
        $texts = Msgs2 $ans
        $res = & $c.Check
        $asked = $(if ($c.Want) { $texts -match $c.Want } else { $texts -eq 'no box' })
        if ($c.NotWant -and $texts -match $c.NotWant) { $asked = $false }
        Row $Case 'RUN' (V ($res[0] -and $asked -and -not $ans.Fatal)) ("preview rows {0}; boxes as expected: {1}; on disk: {2}; boxes: {3}{4}" -f $preview, $asked, $res[1], $texts, $(if ($ans.Fatal) { '; FATAL ' + $ans.Fatal } else { '' }))
        Close-Renamer $id $dlg
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}
function U([int[]]$Cp) { return (-join ($Cp | ForEach-Object { [string][char]$_ })) }
# "Zlutoucky kun" with its Czech letters in the given forms: Z-caron, t-caron, c-caron, y-acute, u-ring, n-caron
function Kun([string]$Form) {
    switch ($Form) {
        'orig'  { return (U @(0x17D)) + 'lu' + (U @(0x165)) + 'ou' + (U @(0x10D)) + 'k' + (U @(0xFD)) + ' k' + (U @(0x16F)) + (U @(0x148)) + '.txt' }
        'lower' { return (U @(0x17E)) + 'lu' + (U @(0x165)) + 'ou' + (U @(0x10D)) + 'k' + (U @(0xFD)) + ' k' + (U @(0x16F)) + (U @(0x148)) + '.txt' }
        'upper' { return (U @(0x17D)) + 'LU' + (U @(0x164)) + 'OU' + (U @(0x10C)) + 'K' + (U @(0xDD)) + ' K' + (U @(0x16E)) + (U @(0x147)) + '.TXT' }
        'mixed' { return (U @(0x17D)) + 'lu' + (U @(0x165)) + 'ou' + (U @(0x10D)) + 'k' + (U @(0xFD)) + ' K' + (U @(0x16F)) + (U @(0x148)) + '.Txt' }
        'dia'   { return 'Zlutoucky kun.txt' }
    }
}
function Names([string]$d) { return ((@(Get-ChildItem -LiteralPath ($LP + $d) -Force | ForEach-Object { $_.Name })) -join ',') }
function Hex([string]$t) { return ((@([Text.Encoding]::UTF8.GetBytes($t) | ForEach-Object { $_.ToString('X2') })) -join '') }
function S-Row([string]$Case, [string]$Source, [string]$Pattern, [string]$Want, [string]$Search, [string]$Replace, [hashtable]$Checks) {
    Run-Ren $Case {
        $d = $Root + '\' + $Case; NewDir $d
        Put "$d\$Source" 'SEARCH'
        $w = $Want; $pre = Hex (Names $d)
        @{ Folder = $d; Source = $Source; NewName = $Pattern; Answers = @(6, 1); Want = '.'; Search = $Search; Replace = $Replace; Checks = $Checks
           Check = { $n = Names $d; @(($n -ceq $w), ('before ' + $pre + ' got ' + (Hex $n) + ' want ' + (Hex $w))) }.GetNewClosure() }
    }
}
function Run-RenCases {
    $zlut = (U @(0x17E)) + 'lu' + (U @(0x165)) + '.txt'         # z-caron l u t-caron
    $capZlut = (U @(0x17D)) + 'lu' + (U @(0x165)) + '.txt'   # (PowerShell names ignore case: not $Zlut)
    $plain = @{ 112 = $false; 113 = $false; 115 = $false }
    S-Row 'bm-wrong' ((U @(0x10A)) + 'x.txt') '$(OriginalName)' ((U @(0x10A)) + 'x.txt') (U @(0x11A)) 'E' $plain
    S-Row 'bm-cz' $zlut '$(OriginalName)' ('Z' + 'lu' + (U @(0x165)) + '.txt') (U @(0x17D)) 'Z' $plain
    S-Row 're-cz' $zlut '$(OriginalName)' ('Z' + 'lu' + (U @(0x165)) + '.txt') (U @(0x17D)) 'Z' @{ 112 = $false; 113 = $false; 115 = $true }
    $reOn = @{ 112 = $false; 113 = $false; 115 = $true }
    S-Row 're-wrong' ((U @(0x10A)) + 'x.txt') '$(OriginalName)' ((U @(0x10A)) + 'x.txt') (U @(0x11A)) 'E' $reOn
    S-Row 're-sub' ((U @(0x17D)) + 'lu' + (U @(0x165)) + '.txt') '$(OriginalName)' ('[' + (U @(0x17D)) + ']lu' + (U @(0x165)) + '.txt') ('^(' + (U @(0x17E)) + ')') '[$1]' $reOn
    S-Row 'bm-cs' $zlut '$(OriginalName)' ('Z' + 'lu' + (U @(0x165)) + '.txt') (U @(0x17E)) 'Z' @{ 112 = $true; 113 = $false; 115 = $false }
    $kun = (U @(0x17E)) + 'lut' + (U @(0xFD)) + ' k' + (U @(0x16F, 0x148)) + '.txt'   # z-caron l u t y-acute  k u-ring n-caron
    S-Row 'ww' $kun '$(OriginalName)' ((U @(0x17E)) + 'lut' + (U @(0xFD)) + ' pes.txt') ('k' + (U @(0x16F, 0x148))) 'pes' @{ 112 = $true; 113 = $true; 115 = $false }
    S-Row 'cut' $capZlut '$(OriginalName:0,1)_.txt' ((U @(0x17D)) + '_.txt') '' '' @{}
}

$backup = Join-Path $env:TEMP 'tc210_ren_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    Make-Fixtures
    Set-Config
    Out ("ren_search_probe (feature 210), expect: {0}" -f $Expect)
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
