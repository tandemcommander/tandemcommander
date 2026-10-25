<#
.SYNOPSIS
    Feature 314 probe: the Markdown Viewer's View > Page Width submenu - four levels, the one in
    use checked, a choice rebuilds the page with the level and is stored as PageWidth.

.DESCRIPTION
    Fixture under %TEMP%\tc314\files: a_doc.md (a heading, a long paragraph that wraps at the
    column width, a wide table). F3 (742) opens the Markdown Viewer; the probe reads its menu from
    outside the process (GetMenu / GetMenuStringW / GetMenuState), posts the menu commands
    (220..223) and measures the text column in a PrintWindow(PW_RENDERFULLCONTENT) capture of the
    viewer: the horizontal extent of the pixels that differ from the page background. The window
    is made 2300 x 1000 so every level has room.
      MENU      default settings (no PageWidth value): PASS = View holds a "Page Width" popup with
                commands 220..223 "Normal", "Wide", "Wider", "Full Window", 220 checked
                (before: no such popup)
      W-NORMAL  PASS = the text extent fits 46rem minus the padding (and fills most of it)
      W-WIDE / W-WIDER / W-FULL  WM_COMMAND 221 / 222 / 223: PASS = that item checked, the others
                not, the extent fits that level (Full: the client width minus padding/scroll bar)
                and is wider than the level before; NOT DRIVEN when the capture holds no page
      BACK      WM_COMMAND 222 (Wider) last: PASS = 222 checked
      SAVED     the program ends: PASS = ...\Plugins Configuration\MDVIEW PageWidth = 2
      RESTART   start again, F3: PASS = 222 checked (and the extent of Wider when measured)
      UNKNOWN   PageWidth = 7 written before the start: PASS = 220 checked
      WRONGTYPE PageWidth = "2" (REG_SZ) written before the start: PASS = 220 checked
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
if (-not ('Pw314' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Pw314
{
    [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr m, int pos);
    [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr m);
    [DllImport("user32.dll")] public static extern uint GetMenuItemID(IntPtr m, int pos);
    [DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr m, uint id, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetMenuStringW(IntPtr m, uint id, StringBuilder s, int n, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "GetMenuStringW")] public static extern int GetMenuStringPos(IntPtr m, uint pos, StringBuilder s, int n, uint flags);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    public static string Str(IntPtr m, uint id) { var s = new StringBuilder(512); GetMenuStringW(m, id, s, 512, 0); return s.ToString(); }
    public static string PosStr(IntPtr m, int pos) { var s = new StringBuilder(512); GetMenuStringPos(m, (uint)pos, s, 512, 0x400); return s.ToString(); }
    // the popup whose first command is 'firstId', searched through the menu bar's popups and their popups
    public static IntPtr PopupWith(IntPtr wnd, uint firstId)
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
                if (sub != IntPtr.Zero && GetMenuItemCount(sub) > 0 && GetMenuItemID(sub, 0) == firstId) return sub;
            }
        }
        return IntPtr.Zero;
    }
    // the text of the View menu item that opens 'popup' (its position in its parent)
    public static string PopupTitle(IntPtr wnd, IntPtr popup)
    {
        IntPtr bar = GetMenu(wnd);
        for (int i = 0; i < GetMenuItemCount(bar); i++)
        {
            IntPtr top = GetSubMenu(bar, i);
            if (top == IntPtr.Zero) continue;
            for (int j = 0; j < GetMenuItemCount(top); j++)
                if (GetSubMenu(top, j) == popup) return PosStr(top, j) + " @" + j + " after '" + (j > 0 ? PosStr(top, j - 1) : "") + "'";
        }
        return "";
    }
    // PrintWindow(PW_RENDERFULLCONTENT) of the window, cropped to its client area; then the
    // horizontal extent of the columns holding pixels unlike the background (sampled at a
    // left-margin point). Returns "-1" when nothing differs (no page in the capture).
    public static string Measure(IntPtr wnd, string saveAs)
    {
        RECT wr; GetWindowRect(wnd, out wr);
        RECT cr; GetClientRect(wnd, out cr);
        POINT o = new POINT(); ClientToScreen(wnd, ref o);
        int w = wr.Right - wr.Left, h = wr.Bottom - wr.Top;
        using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(bmp))
            {
                IntPtr dc = g.GetHdc();
                PrintWindow(wnd, dc, 2);
                g.ReleaseHdc(dc);
            }
            int ox = o.X - wr.Left, oy = o.Y - wr.Top, cw = cr.Right, ch = cr.Bottom;
            if (saveAs != null) { try { bmp.Save(saveAs, ImageFormat.Png); } catch { } }
            Color bg = bmp.GetPixel(ox + 6, oy + ch / 2);
            int minX = int.MaxValue, maxX = -1, rows = 0;
            // skip the right 24 px (scroll bar) and the top 4 px
            for (int y = oy + 4; y < oy + ch - 4; y += 2)
            {
                bool any = false;
                for (int x = ox; x < ox + cw - 24; x++)
                {
                    Color c = bmp.GetPixel(x, y);
                    if (Math.Abs(c.R - bg.R) + Math.Abs(c.G - bg.G) + Math.Abs(c.B - bg.B) > 90)
                    {
                        any = true;
                        if (x < minX) minX = x;
                        if (x > maxX) maxX = x;
                    }
                }
                if (any) rows++;
            }
            if (maxX < 0) return "-1;bg=" + bg.R + "," + bg.G + "," + bg.B + ";client=" + cw + "x" + ch;
            return (maxX - minX + 1) + ";left=" + (minX - ox) + ";right=" + (maxX - ox) + ";rows=" + rows + ";client=" + cw + "x" + ch + ";bg=" + bg.R + "," + bg.G + "," + bg.B;
        }
    }
}
'@
}

$Root = $TempRoot + '\tc314'
$StartDir = $Root + '\start'
$Files = $Root + '\files'
$MdKey = 'HKCU\Software\Tandem Commander\Settings\Plugins Configuration\MDVIEW'
$Names = @('Normal', 'Wide', 'Wider', 'Full Window')
$Rems = @(46, 64, 90, 0)

function Put-Text([string]$Path, [string]$Text) {
    if (-not $Path.StartsWith($Root + '\')) { throw "outside the fixture: $Path" }
    [IO.File]::WriteAllBytes($LP + $Path, $Utf8.GetBytes($Text))
}
function Checked([IntPtr]$M, [int]$Id) { return (([Pw314]::GetMenuState($M, [uint32]$Id, 0) -band 0x8) -ne 0) }
function CheckedIds([IntPtr]$M) { $c = @(); for ($i = 220; $i -le 223; $i++) { if (Checked $M $i) { $c += $i } }; return ($c -join ',') }
# F3 on the first file below ".." - the Markdown Viewer window, or zero
function Open-View([int]$Id) {
    Key $Id 0x24
    Key $Id 0x28
    Start-Sleep -Milliseconds 400
    $known = Get-Tops $Id
    $w = Open-ByCmd $Id 742 20
    if ($w -eq [IntPtr]::Zero) { return $w }
    if ([Drv098f]::Txt($w) -eq 'Error Loading Configuration') {
        # the core's answer to a configuration value of the wrong type (any value, any plug-in):
        # recorded, confirmed, then the viewer is expected
        $script:CfgError = WinDesc $w
        $known = @($known) + @($w)
        Click-Ok $w
        $w = Wait-NewWin $Id $known 20
        if ($w -eq [IntPtr]::Zero) { return $w }
    }
    Start-Sleep -Milliseconds 1500
    if ([Drv098f]::Txt($w) -notlike '*Markdown Viewer*') { $script:NotMd = WinDesc $w; Close-Win $w; return [IntPtr]::Zero }
    [void][Pw314]::SetWindowPos($w, [IntPtr]::Zero, 0, 0, 2300, 1000, 0x0014)   # SWP_NOZORDER | SWP_NOACTIVATE
    Start-Sleep -Milliseconds 4000
    return $w
}
function Close-View([IntPtr]$W) {
    [void][Drv098f]::PostMessageW($W, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($W)) { Start-Sleep -Milliseconds 150 }
}
function Shot([IntPtr]$W, [string]$Tag) {
    $png = $null; if ($OutFile) { $png = [IO.Path]::Combine([IO.Path]::GetDirectoryName($OutFile), ('shot_{0}_{1}.png' -f $Label, $Tag)) }
    return [Pw314]::Measure($W, $png)
}
function Extent([string]$m) { return [int]($m.Split(';')[0]) }
function ClientW([string]$m) { $c = ($m.Split(';') | Where-Object { $_ -like 'client=*' }); return [int](($c -replace 'client=', '').Split('x')[0]) }
# the inner width (CSS px * scale) a level allows: max-width minus the 28 px padding each side
function Inner([int]$Level, [double]$Scale, [int]$ClientW) {
    # Full Window: the client width minus the padding (the fixture needs no vertical scroll bar)
    if ($Rems[$Level] -eq 0) { return [int]($ClientW - 56 * $Scale) }
    return [int](($Rems[$Level] * 16 - 56) * $Scale)
}
function Width-Verdict([int]$Level, [string]$m, [double]$Scale, [int]$Prev) {
    $e = Extent $m
    if ($e -lt 0) { return 'NOT DRIVEN' }
    $in = Inner $Level $Scale (ClientW $m)
    return (V (($e -le $in + 3) -and ($e -ge 0.8 * $in) -and ($e -gt $Prev)))
}
function Reg-Width {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Tandem Commander\Settings\Plugins Configuration\MDVIEW')
    if (-not $k) { return '<no key>' }
    try { $v = $k.GetValue('PageWidth', '<no value>'); return ('{0} ({1})' -f $v, $(if ($v -is [int]) { 'DWORD' } else { $v.GetType().Name })) } finally { $k.Close() }
}
function Set-Md([string]$Type, [string]$Data) {
    & cmd.exe /c "reg delete `"$MdKey`" /v PageWidth /f >nul 2>&1"
    if ($Type) { & reg.exe add $MdKey /v PageWidth /t $Type /d $Data /f | Out-Null }
    & reg.exe add $MdKey /v ZoomPercent /t REG_DWORD /d 100 /f | Out-Null
}
# one start: open the document, read the Page Width popup; returns @(window, popup) or @(0, 0)
function Open-Doc([int]$Id, [string]$Case) {
    $w = Open-View $Id
    if ($w -eq [IntPtr]::Zero) { Row $Case 'RUN' 'NOT DRIVEN' ('F3 opened no Markdown Viewer: ' + $script:NotMd); return @([IntPtr]::Zero, [IntPtr]::Zero) }
    return @($w, [Pw314]::PopupWith($w, 220))
}

$backup = Join-Path $env:TEMP 'tc314_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $Files
    Set-Config
    $para = (1..60 | ForEach-Object { 'Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor.' }) -join ' '
    $hdr = '| ' + ((1..24 | ForEach-Object { "Column $_" }) -join ' | ') + " |`n"
    $sep = '|' + ((1..24 | ForEach-Object { '---' }) -join '|') + "|`n"
    $row = '| ' + ((1..24 | ForEach-Object { "value $_" }) -join ' | ') + " |`n"
    Put-Text "$Files\a_doc.md" ("# Page width probe`n`n" + $para + "`n`n" + $hdr + $sep + $row + $row)
    Set-Md $null $null
    Out ("pw314_probe (feature 314) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; desktop {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [DeskLib098]::Name())
    Out ''

    $id = 0; $before = Reports; $wider = -1
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        $o = Open-Doc $id 'MENU'; $w = $o[0]; $m = $o[1]
        if ($w -ne [IntPtr]::Zero) {
            $scale = [Pw314]::GetDpiForWindow($w) / 96.0
            $texts = @(); if ($m -ne [IntPtr]::Zero) { $texts = @(220..223 | ForEach-Object { [Pw314]::Str($m, [uint32]$_) -replace '&', '' }) }
            $title = ''; if ($m -ne [IntPtr]::Zero) { $title = [Pw314]::PopupTitle($w, $m) -replace '&', '' }
            $okMenu = ($m -ne [IntPtr]::Zero) -and ([Pw314]::GetMenuItemCount($m) -eq 4) -and (($texts -join '|') -eq ($Names -join '|')) -and ((CheckedIds $m) -eq '220') -and ($title -like 'Page Width @1*')
            Row 'MENU' 'RUN' (V $okMenu) ("popup {0}; title '{1}'; items '{2}'; checked {3}; window '{4}'; scale {5}" -f ($m -ne [IntPtr]::Zero), (Esc ($title -replace '&', '')), (Esc ($texts -join '|')), $(if ($m -ne [IntPtr]::Zero) { CheckedIds $m } else { '-' }), (Esc ([Drv098f]::Txt($w))), $scale)
            $prev = 0
            $ms = Shot $w 'normal'
            $vd = Width-Verdict 0 $ms $scale 0
            Row 'W-NORMAL' 'RUN' $vd ("extent {0}; allowed {1}" -f $ms, (Inner 0 $scale (ClientW $ms)))
            if ((Extent $ms) -gt 0) { $prev = Extent $ms }
            if ($m -ne [IntPtr]::Zero) {
                foreach ($lv in 1..3) {
                    Post-Cmd $w (220 + $lv)
                    Start-Sleep -Milliseconds 3500
                    [void](Serve $id 3)
                    $ms = Shot $w ($Names[$lv] -replace ' ', '')
                    $vd = Width-Verdict $lv $ms $scale $prev
                    $ck = CheckedIds $m
                    if ($ck -ne ('' + (220 + $lv))) { $vd = 'FAIL' }
                    Row ('W-' + ($Names[$lv].Split(' ')[0].ToUpper())) 'RUN' $vd ("checked {0}; extent {1}; allowed {2}" -f $ck, $ms, (Inner $lv $scale (ClientW $ms)))
                    if ((Extent $ms) -gt 0) { $prev = Extent $ms }
                    if ($lv -eq 2) { $wider = Extent $ms }
                }
                Post-Cmd $w 222
                Start-Sleep -Milliseconds 3000
                Row 'BACK' 'RUN' (V ((CheckedIds $m) -eq '222')) ("checked {0}" -f (CheckedIds $m))
            }
            Close-View $w
        }
    }
    catch { Row 'FIRST' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'FIRST' $id $null $before } }

    $v = Reg-Width
    Row 'SAVED' 'RUN' (V ($v -eq '2 (DWORD)')) ("PageWidth = {0}" -f $v)

    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        $o = Open-Doc $id 'RESTART'; $w = $o[0]; $m = $o[1]
        if ($w -ne [IntPtr]::Zero) {
            $ms = Shot $w 'restart'
            $ok = ($m -ne [IntPtr]::Zero) -and ((CheckedIds $m) -eq '222')
            # review 1: the page itself must have the Wider column, not only the menu check
            $scale = [Pw314]::GetDpiForWindow($w) / 96.0
            if ((Extent $ms) -gt 0) { $ok = $ok -and ((Width-Verdict 2 $ms $scale (Inner 1 $scale (ClientW $ms))) -eq 'PASS') }
            if ($wider -gt 0 -and (Extent $ms) -gt 0) { $ok = $ok -and ([Math]::Abs((Extent $ms) - $wider) -le 4) }
            Row 'RESTART' 'RUN' (V $ok) ("checked {0}; extent {1}; Wider before {2}" -f $(if ($m -ne [IntPtr]::Zero) { CheckedIds $m } else { '-' }), $ms, $wider)
            Close-View $w
        }
    }
    catch { Row 'SECOND' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'SECOND' $id $null $before } }

    # review 1 (S1): two windows A and B at Normal; A chooses Wide (stored Wide), then B chooses
    # Normal - already its level, so B is not rebuilt, but Normal is the last choice and is stored
    Set-Md 'REG_DWORD' '0'
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Files
        [void](Serve $id 10)
        $a = Open-View $id
        $b = [IntPtr]::Zero; if ($a -ne [IntPtr]::Zero) { $b = Open-View $id }
        if ($a -eq [IntPtr]::Zero -or $b -eq [IntPtr]::Zero -or $a -eq $b) { Row 'TWOWIN' 'RUN' 'NOT DRIVEN' ('two viewer windows not opened: ' + $script:NotMd) }
        else {
            $ma = [Pw314]::PopupWith($a, 220); $mb = [Pw314]::PopupWith($b, 220)
            Post-Cmd $a 221
            Start-Sleep -Milliseconds 2500
            Post-Cmd $b 220
            Start-Sleep -Milliseconds 1500
            $ca = CheckedIds $ma; $cb = CheckedIds $mb
            Close-View $b; Close-View $a
            $script:TwoWin = ("A checked {0}; B checked {1}" -f $ca, $cb)
        }
    }
    catch { Row 'TWOWIN-RUN' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'TWOWIN-RUN' $id $null $before } }
    if ($script:TwoWin) {
        $v = Reg-Width
        Row 'TWOWIN' 'RUN' (V (($v -eq '0 (DWORD)') -and ($script:TwoWin -eq 'A checked 221; B checked 220'))) ("{0}; stored after exit PageWidth = {1} (want 0: the last choice)" -f $script:TwoWin, $v)
    }

    foreach ($case in @(@('UNKNOWN', 'REG_DWORD', '7'), @('WRONGTYPE', 'REG_SZ', '2'))) {
        Set-Md $case[1] $case[2]
        $id = 0; $before = Reports; $script:CfgError = ''
        try {
            $id = Start-Tc $Files
            [void](Serve $id 10)
            $o = Open-Doc $id $case[0]; $w = $o[0]; $m = $o[1]
            if ($w -ne [IntPtr]::Zero) {
                Row $case[0] 'RUN' (V (($m -ne [IntPtr]::Zero) -and ((CheckedIds $m) -eq '220'))) ("stored {0} {1}; checked {2}; core message before the viewer: {3}" -f $case[1], $case[2], $(if ($m -ne [IntPtr]::Zero) { CheckedIds $m } else { '-' }), $(if ($script:CfgError) { $script:CfgError } else { 'none' }))
                Close-View $w
            }
        }
        catch { Row ($case[0] + '-RUN') 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { End-Row ($case[0] + '-RUN') $id $null $before } }
        Out ("PageWidth after {0}: {1}" -f $case[0], (Reg-Width))
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
