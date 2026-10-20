<#
.SYNOPSIS
    Feature 262 probe: the Code Viewer reads a single-byte file through the product's conversion
    tables - its Encoding menu lists them, a choice re-decodes the open file and is remembered.

.DESCRIPTION
    Fixture under %TEMP%\tc262\files: a_cp852.bat (the codeview corpus file cp852.bat, "Příliš
    žluťoučký kůň" in CP852), b_utf8.cpp (UTF-8 without BOM, non-ASCII). F3 (742) opens the Code
    Viewer; the probe reads the viewer's status bar (a STATIC child, WM_GETTEXT) and its Encoding
    menu (GetMenu / GetMenuStringW / GetMenuState from outside the process) and posts the encoding
    commands (4000 + position, 3990 F8, 3991 Shift+F8). The decoded letters live in a WebView2 page
    and are not read here - saltests TestCodeTable262 checks the same table pass on the same bytes.
      MENU      a_cp852.bat, default settings: PASS = status "ANSI" (as before), the Encoding menu
                holds the five entries and after them the tables, one named "CP852 - CP1250" (a
                CP1250 machine: convert\centeuro), "System code page" checked (before: 5 entries)
      CHOOSE    WM_COMMAND of that item: PASS = status names "CP852 - CP1250", it is checked, 4004 not
      CYCLE     F8 (3990) then Shift+F8 (3991): PASS = status names the next table of the menu, then
                "CP852 - CP1250" again
      REMEMBER  close the viewer, F3 on a_cp852.bat again: PASS = status "CP852 - CP1250" at once
      UTF8      F3 on b_utf8.cpp: PASS = status "UTF-8" (a remembered table plays no role)
      KEEP      there Shift+F8 (wraps to the last table), close, F3 on a_cp852.bat: PASS = the status
                still names "CP852 - CP1250" - cycling does not change the remembered table (review 1)
      SAVED     the program ends (WM_CLOSE): PASS = HKCU\...\Plugins Configuration\CODEVIEW
                DefaultConvert = "CP852 - CP1250"
      RESTART   start again, F3 on a_cp852.bat: PASS = status "CP852 - CP1250"
      FORGET    WM_COMMAND 4004 (System code page), close, F3 again: PASS = status "ANSI" both times
      NONASCII  start again, choose the first table whose name is not ASCII (convert\centeuro
                "Kameni... - CP1250", code-page bytes): PASS = the status names it
      NASAVED   the program ends: PASS = DefaultConvert holds exactly that name (stored as UTF-8)
      NARESTART start again, F3 on a_cp852.bat: PASS = the status names that table
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Menu262' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class Menu262
{
    [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr m, int pos);
    [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr m);
    [DllImport("user32.dll")] public static extern uint GetMenuItemID(IntPtr m, int pos);
    [DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr m, uint id, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetMenuStringW(IntPtr m, uint id, StringBuilder s, int n, uint flags);
    public static string Str(IntPtr m, uint id) { var s = new StringBuilder(512); GetMenuStringW(m, id, s, 512, 0); return s.ToString(); }
    // the popup holding command 4000 (the Encoding menu), searched through the menu bar
    public static IntPtr EncodingMenu(IntPtr wnd)
    {
        IntPtr bar = GetMenu(wnd);
        if (bar == IntPtr.Zero) return IntPtr.Zero;
        for (int i = 0; i < GetMenuItemCount(bar); i++)
        {
            IntPtr top = GetSubMenu(bar, i);
            if (top == IntPtr.Zero) continue;
            for (int j = 0; j < GetMenuItemCount(top); j++)
            {
                IntPtr sub = GetSubMenu(top, j);
                if (sub != IntPtr.Zero && GetMenuItemCount(sub) > 0 && GetMenuItemID(sub, 0) == 4000) return sub;
            }
        }
        return IntPtr.Zero;
    }
}
'@
}
$Root = $TempRoot + '\tc262'
$StartDir = $Root + '\start'
$Files = $Root + '\files'
$CvKey = 'HKCU\Software\Tandem Commander\0.1\Plugins Configuration\CODEVIEW'
$Corpus = Join-Path $PSScriptRoot '..\..\..\src\plugins\codeview\test\corpus\encodings'

function Put-Bytes([string]$Path, [byte[]]$Bytes) {
    if (-not $Path.StartsWith($Root + '\')) { throw "outside the fixture: $Path" }
    [IO.File]::WriteAllBytes($LP + $Path, $Bytes)
}
function Status-Of([IntPtr]$W) {
    $s = @([Drv098f]::Kids($W) | Where-Object { [Drv098f]::Cls($_) -eq 'Static' })
    if (-not $s.Count) { return '<no status bar>' }
    return [Drv098f]::GetText($s[0], 5000)
}
function Wait-Status([IntPtr]$W, [string]$Like, [double]$Seconds = 6) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $t = Status-Of $W
        if ($t -like $Like) { return $t }
        Start-Sleep -Milliseconds 150
    }
    return (Status-Of $W)
}
# the command id of the item named $Name in menu $M (0 = none) and the id of the next item after it
function Find-Item([IntPtr]$M, [string]$Name) {
    $ids = @(); for ($i = 0; $i -lt [Menu262]::GetMenuItemCount($M); $i++) { $x = [int][Menu262]::GetMenuItemID($M, $i); if ($x -ge 4000) { $ids += $x } }
    for ($i = 0; $i -lt $ids.Count; $i++) { if ([Menu262]::Str($M, [uint32]$ids[$i]) -ceq $Name) { $n = 0; if ($i + 1 -lt $ids.Count) { $n = $ids[$i + 1] }; return @($ids[$i], $n) } }
    return @(0, 0)
}
function Checked([IntPtr]$M, [int]$Id) { return (([Menu262]::GetMenuState($M, [uint32]$Id, 0) -band 0x8) -ne 0) }
# F3 on the item 'Downs' rows below ".." - the Code Viewer window, or zero
function Open-View([int]$Id, [int]$Downs) {
    Key $Id 0x24
    for ($i = 0; $i -lt $Downs; $i++) { Key $Id 0x28 }
    Start-Sleep -Milliseconds 400
    $w = Open-ByCmd $Id 742 20
    if ($w -eq [IntPtr]::Zero) { return $w }
    Start-Sleep -Milliseconds 1500
    if ([Drv098f]::Txt($w) -notlike '*Code Viewer*') { $script:NotCv = WinDesc $w; Close-Win $w; return [IntPtr]::Zero }
    return $w
}
function Close-View([IntPtr]$W) {
    [void][Drv098f]::PostMessageW($W, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($W)) { Start-Sleep -Milliseconds 150 }
}
function Reg-Convert {   # the stored value, exactly (UTF-16 from the registry)
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Tandem Commander\0.1\Plugins Configuration\CODEVIEW')
    if (-not $k) { return '<no key>' }
    try { return [string]$k.GetValue('DefaultConvert', '<no value>') } finally { $k.Close() }
}

$Ansi = '* | ANSI | *'
$Cp852 = '* | CP852 - CP1250 | *'
$backup = Join-Path $env:TEMP 'tc262_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Files
    Set-Config
    # the run starts with nothing remembered (a value of an earlier run would hide the default row)
    & cmd.exe /c "reg delete `"$CvKey`" /v DefaultConvert /f >nul 2>&1"
    Put-Bytes "$Files\a_cp852.bat" ([IO.File]::ReadAllBytes((Join-Path $Corpus 'cp852.bat')))
    Put-Bytes "$Files\b_utf8.cpp" ($Utf8.GetBytes("// P" + $Rz + "íliš " + $Cc + "ervený`r`nint main() { return 0; }`r`n"))
    Out ("cvtab262_probe (feature 262) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    if ([Drv098f]::GetACP() -ne 1250) { Out 'NOTE: the expected table names are those of convert\centeuro (a CP1250 machine)' }

    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        $w = Open-View $id 1
        if ($w -eq [IntPtr]::Zero) { Row 'MENU' 'RUN' 'NOT DRIVEN' ('F3 opened no Code Viewer: ' + $script:NotCv) }
        else {
            $st = Status-Of $w
            $m = [Menu262]::EncodingMenu($w)
            $n = 0; $c4 = $false; $f = @(0, 0)
            if ($m -ne [IntPtr]::Zero) { $n = [Menu262]::GetMenuItemCount($m); $f = Find-Item $m 'CP852 - CP1250'; $c4 = Checked $m 4004 }
            $IdCp852 = $f[0]; $IdNext = $f[1]; $NextName = ''; if ($IdNext) { $NextName = [Menu262]::Str($m, [uint32]$IdNext) }
            $NextLike = '* | ' + $NextName + ' | *'
            Row 'MENU' 'RUN' (V (($st -like $Ansi) -and $n -gt 6 -and $IdCp852 -gt 4004 -and $IdNext -gt $IdCp852 -and $c4)) ("status '{0}'; Encoding menu {1} items; 4004 '{2}', 4005 '{3}'; 'CP852 - CP1250' = {4}, next {5} '{6}'; System code page checked {7}" -f (Esc $st), $n, (Esc ([Menu262]::Str($m, 4004))), (Esc ([Menu262]::Str($m, 4005))), $IdCp852, $IdNext, (Esc $NextName), $c4)
            if (-not $IdCp852) { throw 'no CP852 - CP1250 item' }

            Post-Cmd $w $IdCp852
            $st = Wait-Status $w $Cp852
            [void](Serve $id 3)
            Row 'CHOOSE' 'RUN' (V (($st -like $Cp852) -and (Checked $m $IdCp852) -and -not (Checked $m 4004))) ("status '{0}'; {1} checked {2}; 4004 checked {3}" -f (Esc $st), $IdCp852, (Checked $m $IdCp852), (Checked $m 4004))

            Post-Cmd $w 3990
            $s1 = Wait-Status $w $NextLike
            Post-Cmd $w 3991
            $s2 = Wait-Status $w $Cp852
            Row 'CYCLE' 'RUN' (V (($s1 -like $NextLike) -and ($s2 -like $Cp852))) ("F8 -> '{0}'; Shift+F8 -> '{1}'" -f (Esc $s1), (Esc $s2))
            Close-View $w

            $w = Open-View $id 1
            if ($w -eq [IntPtr]::Zero) { Row 'REMEMBER' 'RUN' 'NOT DRIVEN' 'F3 opened no Code Viewer' }
            else { $st = Status-Of $w; Row 'REMEMBER' 'RUN' (V ($st -like $Cp852)) ("status '{0}'" -f (Esc $st)); Close-View $w }

            $w = Open-View $id 2
            if ($w -eq [IntPtr]::Zero) { Row 'UTF8' 'RUN' 'NOT DRIVEN' 'F3 opened no Code Viewer' }
            else {
                $st = Status-Of $w; Row 'UTF8' 'RUN' (V ($st -like '* | UTF-8 | *')) ("status '{0}'" -f (Esc $st))
                # review 1 (S1): Shift+F8 here wraps to the last table - it must not become the remembered one
                Post-Cmd $w 3991
                $s1 = Wait-Status $w '* | UTF-8 | *' 2
                [void](Serve $id 3)
                Close-View $w
                $w = Open-View $id 1
                $s2 = '<no viewer>'; if ($w -ne [IntPtr]::Zero) { $s2 = Status-Of $w; Close-View $w }
                Row 'KEEP' 'RUN' (V (($s1 -notlike '* | UTF-8 | *') -and ($s2 -like $Cp852))) ("Shift+F8 on b_utf8.cpp -> '{0}'; a_cp852.bat reopened '{1}'" -f (Esc $s1), (Esc $s2))
            }
        }
    }
    catch { Row 'FIRST' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'FIRST' $id $null $before } }

    $v = Reg-Convert
    Row 'SAVED' 'RUN' (V ($v -eq 'CP852 - CP1250')) ("DefaultConvert = '{0}'" -f (Esc $v))

    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        $w = Open-View $id 1
        if ($w -eq [IntPtr]::Zero) { Row 'RESTART' 'RUN' 'NOT DRIVEN' 'F3 opened no Code Viewer' }
        else {
            $st = Status-Of $w
            Row 'RESTART' 'RUN' (V ($st -like $Cp852)) ("status '{0}'" -f (Esc $st))
            Post-Cmd $w 4004
            $s1 = Wait-Status $w $Ansi
            Close-View $w
            $w = Open-View $id 1
            $s2 = '<no viewer>'; if ($w -ne [IntPtr]::Zero) { $s2 = Status-Of $w; Close-View $w }
            Row 'FORGET' 'RUN' (V (($s1 -like $Ansi) -and ($s2 -like $Ansi))) ("after System code page '{0}'; reopened '{1}'" -f (Esc $s1), (Esc $s2))
        }
    }
    catch { Row 'SECOND' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'SECOND' $id $null $before } }
    Out ("DefaultConvert after the second run: '{0}'" -f (Esc (Reg-Convert)))

    # a table whose name is not ASCII (convert\centeuro "Kameni... - CP1250", code-page bytes):
    # remembered, stored as UTF-8, read back after a restart
    $kName = ''
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        $w = Open-View $id 1
        if ($w -eq [IntPtr]::Zero) { Row 'NONASCII' 'RUN' 'NOT DRIVEN' 'F3 opened no Code Viewer' }
        else {
            $m = [Menu262]::EncodingMenu($w)
            $kId = 0
            for ($i = 0; $i -lt [Menu262]::GetMenuItemCount($m); $i++) {
                $x = [int][Menu262]::GetMenuItemID($m, $i)
                if ($x -gt 4004) { $t = [Menu262]::Str($m, [uint32]$x); if ($t -match '[^\x00-\x7F]' -and $t -like '* - CP1250*') { $kId = $x; $kName = $t; break } }
            }
            if (-not $kId) { Row 'NONASCII' 'RUN' 'NOT DRIVEN' 'no table with a non-ASCII name in the menu' }
            else {
                Post-Cmd $w $kId
                $st = Wait-Status $w ('* | ' + $kName + ' | *')
                [void](Serve $id 3)
                Row 'NONASCII' 'RUN' (V ($st -like ('* | ' + $kName + ' | *'))) ("chose {0} '{1}'; status '{2}'" -f $kId, (Esc $kName), (Esc $st))
                Close-View $w
            }
        }
    }
    catch { Row 'THIRD' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'THIRD' $id $null $before } }
    if ($kName) {
        $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Tandem Commander\0.1\Plugins Configuration\CODEVIEW')
        $v = '<no key>'; if ($k) { $v = [string]$k.GetValue('DefaultConvert', '<no value>'); $k.Close() }
        Row 'NASAVED' 'RUN' (V ($v -ceq $kName)) ("DefaultConvert = '{0}' (want '{1}')" -f (Esc $v), (Esc $kName))
        $id = 0; $before = Reports
        try {
            $id = Start-Tc $Files
            [void](Serve $id 10)
            $w = Open-View $id 1
            $st = '<no viewer>'; if ($w -ne [IntPtr]::Zero) { $st = Status-Of $w; Close-View $w }
            Row 'NARESTART' 'RUN' (V ($st -like ('* | ' + $kName + ' | *'))) ("status '{0}'" -f (Esc $st))
        }
        catch { Row 'FOURTH' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { End-Row 'FOURTH' $id $null $before } }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
