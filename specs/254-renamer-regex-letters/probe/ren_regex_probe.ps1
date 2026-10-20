<#
.SYNOPSIS
    Feature 254 probe: the Renamer's regular expressions judge '.', classes, \w, \b, quantifiers,
    look-behind and \x escapes by whole UTF-8 letters - no letter is split, no rename refused.

.DESCRIPTION
    Rows (the Renamer on one file; new name $(OriginalName); Search 108, Replace 109, the check
    boxes Case sensitive 112, Whole words 113, Global 114, Regular expression 115, Exclude
    extension 123 set per row). Letters by code point (the probe is ASCII): z = U+017E z-caron,
    Z = U+017D, t' = U+0165, Zh-a-b-a = U+0416 U+0430 U+0431 U+0430:
      dot       "z lut'.txt", "^." -> "X": "Xlut'.txt" (before: '.' took the lead byte - refused)
      w-cyr     "Zhaba.txt", "^\w+" -> "W": "W.txt"
      class     "z lut'.txt", "[z]" -> "z" (ASCII): "zlut'.txt"
      negclass  "z lut'.txt", "^[^l]" -> "N": "Nlut'.txt"
      range     "z lut'.txt", "^[a-grave - z-caron]" -> "R": "Rlut'.txt"
      quant     "z z lut'.txt", "^z+" (z-caron) -> "Z": "Zlut'.txt" (the run of letters, not one)
      wordb     "Zhaba.txt", "a\b" (Cyrillic a) -> "A": "ZhabA.txt"
      lookb     "z lut'.txt", "(?<=^.)l" -> "L": "z Lut'.txt"
      esc       "z lut'.txt", "\xC5\xBD" (the bytes of Z-caron), case-insensitive -> "Z": "Zlut'.txt"
      sigma     "logos.txt" (Greek, final sigma), "Sigma" case-insensitive -> "s": "logos" with "s"
      bm-sigma  the same without a regular expression
      mark      "Cafe + U+0301 x.txt", "^\w+" -> "W": "W x.txt" (a combining mark is part of a word)
      nonbmp    "U+20000 U+20001 x.txt", "^\w+" -> "W": "W x.txt" (letters outside the BMP)
      posix     "Zhaba.txt", "^[[:alpha:]]+" -> "P": "P.txt"
      ci-class  "Z lut'.txt", "^[z-caron]", case-insensitive -> "z": "zlut'.txt"
      empty     "z l.txt", "l*" -> "-", Global + Exclude extension: "-z-.txt" (an empty match
                after a letter skips the whole letter)
      ww-mark   "Cafe + U+0301 x.txt", plain search "Cafe" -> "Tea" with Whole words: nothing renamed
                (the combining mark belongs to the word)
      bs-lit    "z lut'.txt", "\" + z-caron -> "Z": "Zlut'.txt" (review M1: the escaped letter whole)
      bs-class  "A-ring lut'.txt", "[\" + z-caron + "]" -> "Z": nothing renamed (M1: not U+00C5)
      esc-ci-cls "Z lut'.txt", "[\xC5\xBD]" case-insensitive -> "Z": "Zlut'.txt" (review S1)
      ungreedy  "z lut'.txt", "^.+?l" -> "X": "Xut'.txt"
      asc-wb    control "abc def.txt", "\b\w" Global -> "X": "Xbc Xef.Xxt"
      asc-dot   control "abc.txt", "^.." -> "Y": "Yc.txt"
    Driver of 210's probe. MUST run through tools\\run_on_hidden_desktop.ps1. Registry exported,
    restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib   # default: 098's probe library
)
$ErrorActionPreference = 'Stop'
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. $Lib
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
$Root = $TempRoot + '\tc254_ren'
$StartDir = $Root + '\start'
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]::ConvertFromUtf32($_) }) }

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
# the mask is typed (WM_CHAR): the Renamer re-reads the files on the edit's change notification,
# which WM_SETTEXT does not send
function Preview-Count([IntPtr]$Dlg) { $lv = Kid $Dlg 104 $null; if (-not $lv) { return -1 }; return [Drv104]::SendR($lv, 0x1004 <#LVM_GETITEMCOUNT#>, 0, 0) }

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
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
# every check box set on every row - the Renamer keeps its options between runs
function Ck([bool]$Cs = $true, [bool]$Re = $true, [bool]$Gl = $false, [bool]$Ex = $false) { return @{ 112 = $Cs; 113 = $false; 114 = (-not $Gl); 115 = $Re; 123 = $Ex } }   # 114 is "Only once in each name" (not Global)
function Run-RenCases {
    $zl = (S 0x17E) + 'lu' + (S 0x165)                      # z-caron l u t-caron
    $capZl = (S 0x17D) + 'lu' + (S 0x165)                   # Z-caron... (PowerShell names ignore case)
    $tail = 'lu' + (S 0x165) + '.txt'
    $zhaba = S 0x416, 0x430, 0x431, 0x430
    $logos = S 0x3BB, 0x3CC, 0x3B3, 0x3BF, 0x3C2           # lambda omicron-tonos gamma omicron final-sigma
    $nm = '$(OriginalName)'
    S-Row 'dot' ($zl + '.txt') $nm ('X' + $tail) '^.' 'X' (Ck)
    S-Row 'w-cyr' ($zhaba + '.txt') $nm 'W.txt' '^\w+' 'W' (Ck)
    S-Row 'class' ($zl + '.txt') $nm ('z' + $tail) ('[' + (S 0x17E) + ']') 'z' (Ck)
    S-Row 'negclass' ($zl + '.txt') $nm ('N' + $tail) '^[^l]' 'N' (Ck)
    S-Row 'range' ($zl + '.txt') $nm ('R' + $tail) ('^[' + (S 0xE0) + '-' + (S 0x17E) + ']') 'R' (Ck)
    S-Row 'quant' ((S 0x17E) + $zl + '.txt') $nm ('Z' + $tail) ('^' + (S 0x17E) + '+') 'Z' (Ck)
    S-Row 'wordb' ($zhaba + '.txt') $nm ((S 0x416, 0x430, 0x431) + 'A.txt') ((S 0x430) + '\b') 'A' (Ck)
    S-Row 'lookb' ($zl + '.txt') $nm ((S 0x17E) + 'Lu' + (S 0x165) + '.txt') '(?<=^.)l' 'L' (Ck)
    S-Row 'esc' ($zl + '.txt') $nm ('Z' + $tail) '\xC5\xBD' 'Z' (Ck $false)
    S-Row 'sigma' ($logos + '.txt') $nm ((S 0x3BB, 0x3CC, 0x3B3, 0x3BF) + 's.txt') (S 0x3A3) 's' (Ck $false)
    S-Row 'bm-sigma' ($logos + '.txt') $nm ((S 0x3BB, 0x3CC, 0x3B3, 0x3BF) + 's.txt') (S 0x3A3) 's' (Ck $false $false)
    S-Row 'mark' ('Cafe' + (S 0x301) + ' x.txt') $nm 'W x.txt' '^\w+' 'W' (Ck)
    S-Row 'nonbmp' ((S 0x20000, 0x20001) + ' x.txt') $nm 'W x.txt' '^\w+' 'W' (Ck)
    S-Row 'posix' ($zhaba + '.txt') $nm 'P.txt' '^[[:alpha:]]+' 'P' (Ck)
    S-Row 'ci-class' ($capZl + '.txt') $nm ('z' + $tail) ('^[' + (S 0x17E) + ']') 'z' (Ck $false)
    S-Row 'empty' ((S 0x17E) + 'l.txt') $nm ('-' + (S 0x17E) + '-.txt') 'l*' '-' (Ck $true $true $true $true)
    S-Row 'ww-mark' ('Cafe' + (S 0x301) + ' x.txt') $nm ('Cafe' + (S 0x301) + ' x.txt') 'Cafe' 'Tea' @{ 112 = $true; 113 = $true; 114 = $true; 115 = $false; 123 = $false }
    # review findings (M1, S1, S2): a backslash before a letter, a case-insensitive escape in a class, ungreedy
    S-Row 'bs-lit' ($zl + '.txt') $nm ('Z' + $tail) ('\' + (S 0x17E)) 'Z' (Ck)
    S-Row 'bs-class' ((S 0xC5) + $tail) $nm ((S 0xC5) + $tail) ('[\' + (S 0x17E) + ']') 'Z' (Ck)
    S-Row 'esc-ci-cls' ($capZl + '.txt') $nm ('Z' + $tail) '[\xC5\xBD]' 'Z' (Ck $false)
    S-Row 'ungreedy' ($zl + '.txt') $nm ('X' + 'u' + (S 0x165) + '.txt') '^.+?l' 'X' (Ck)
    S-Row 'asc-wb' 'abc def.txt' $nm 'Xbc Xef.Xxt' '\b\w' 'X' (Ck $true $true $true)
    S-Row 'asc-dot' 'abc.txt' $nm 'Yc.txt' '^..' 'Y' (Ck)
}

$backup = Join-Path $env:TEMP 'tc254_ren_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    Make-Fixtures
    Set-Config
    Out ("ren_regex_probe (feature 254), expect: {0}" -f $Expect)
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
